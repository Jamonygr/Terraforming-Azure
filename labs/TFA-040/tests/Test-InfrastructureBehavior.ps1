#requires -Version 7.4
$ErrorActionPreference='Stop'
$root=Resolve-Path (Join-Path $PSScriptRoot '../../..')
Import-Module (Join-Path $PSScriptRoot '../scripts/Capstone.Evidence.psm1') -Force
Import-Module (Join-Path $root 'scripts/Infrastructure.Readiness.psm1') -Force
Import-Module (Join-Path $root 'scripts/Infrastructure.Common.psm1') -Force
$count=0
function Assert($Condition,[string]$Message) { if (-not $Condition) { throw $Message } }
function Case([string]$CaseName,[scriptblock]$Body) { & $Body; $script:count++; Write-Output "PASS $CaseName" }
function Snapshot([string]$Stage='hybrid') { & (Join-Path $PSScriptRoot 'New-SyntheticSnapshot.ps1') -Stage $Stage }
foreach ($stage in @('foundation','secure','applications','hybrid')) {
    Case "stage-$stage" { $report=Test-CapstoneSnapshot (Snapshot $stage); Assert ($report.summary.fail -eq 0 -and $report.summary.skip -eq 0 -and $report.summary.pass -ge 4) ($report|ConvertTo-Json -Depth 10); Assert (-not $report.azure_runtime_certified -and $report.evidence_kind -eq 'synthetic') 'Synthetic fixture falsely certified Azure.' }
}
$mutations=@{
    duplicate_backend={param($s) $s.observations.backends[1]=$s.observations.backends[0]}
    empty_nic={param($s) $s.observations.nics[0].ipConfigurations=@()}
    duplicate_vpn={param($s) $s.observations.vpn[1]=$s.observations.vpn[0]}
    missing_gateway_route={param($s) $s.observations.route_tables.gateway.routes=$s.observations.route_tables.gateway.routes[0..1]}
    bastion_ip_connect_disabled={param($s) $s.observations.bastion.enableIpConnect=$false}
    public_nic={param($s) $s.observations.nics[0].ipConfigurations[0].publicIPAddress=@{id='/unexpected/publicIP'}}
    missing_network={param($s) $s.observations.vnets=$s.observations.vnets[0..3]}
    unhealthy_backend={param($s) $s.observations.backends[0].health='Unhealthy'}
    wrong_dns_proxy={param($s) $s.observations.firewall_policy.dnsSettings.servers=@('10.0.1.99')}
    wrong_pe_dns={param($s) $s.observations.private_dns.blob=@('10.20.0.99')}
    removed_return_route={param($s) $s.observations.route_tables.operations.routes=$s.observations.route_tables.operations.routes[0..2]}
    uninspected_ingress={param($s) $s.observations.route_tables.app.subnets[0].id='/fixture/subnets/ingress'}
    failed_vpn={param($s) $s.observations.vpn[0].connectionStatus='Disconnected'}
    unauthorized_success={param($s) $s.observations.private_data.unauthorized_status=200}
    stale_telemetry={param($s) $s.observations.telemetry.Heartbeat.last_seen='2026-10-20T12:00:00Z'}
    malformed_response={param($s) $s.observations.backends='not an API object'}
    cli_failure={param($s) $s.observations.firewall=@{_error='SYNTHETIC-PRIVATE-DIAGNOSTIC'}}
}
foreach ($name in $mutations.Keys) { Case "reject-$name" { $s=Snapshot; & $mutations[$name] $s; $report=Test-CapstoneSnapshot $s; Assert ($report.summary.fail -gt 0) "Missed $name"; Assert (($report|ConvertTo-Json -Depth 10) -notmatch 'SYNTHETIC-PRIVATE-DIAGNOSTIC') 'Raw failure text escaped.' } }
Case 'missing-observation-is-skip' { $s=Snapshot; $s.observations.Remove('public_http'); $r=Test-CapstoneSnapshot $s; Assert ($r.summary.skip -eq 1 -and $r.summary.fail -eq 0) 'Absent evidence was treated as success or failure.' }
Case 'invalid-snapshot-metadata-rejected' {
    foreach ($field in @('observations','collected_at')) {
        $s=Snapshot; $s[$field]='invalid'; $failed=$false
        try { Test-CapstoneSnapshot $s | Out-Null } catch { $failed=$true }
        Assert $failed 'Malformed snapshot metadata was accepted.'
    }
}
Case 'unlabelled-snapshot-rejected' { $s=Snapshot; $s.evidence_kind='real-success'; $failed=$false; try { Test-CapstoneSnapshot $s | Out-Null } catch { $failed=$true }; Assert $failed 'Unlabelled snapshot accepted.' }
function New-PrivateAdapter([string]$DnsScenario='eventual',[string]$RequestScenario='eventual') {
    $state=@{dns=0;requests=0;tokens=0;sleeps=0}
    $adapter=@{
        Resolve={param($name)
            if ($name -like '*.vault.azure.net') { return '10.20.0.5' }
            $state.dns++
            if ($DnsScenario -eq 'wrong') { return '10.20.0.99' }
            if ($DnsScenario -eq 'mixed') { return @('10.20.0.4','20.1.2.3') }
            if ($DnsScenario -eq 'eventual' -and $state.dns -eq 1) { throw 'DNS temporarily absent' }
            if ($DnsScenario -eq 'eventual' -and $state.dns -eq 2) { return '20.1.2.3' }
            return '10.20.0.4'
        }.GetNewClosure()
        Token={param($resource) $state.tokens++; 'SYNTHETIC-PROBE-TOKEN'}.GetNewClosure()
        Sleep={param($seconds) $state.sleeps++}.GetNewClosure()
        Request={param($request)
            $state.requests++
            if ($RequestScenario -eq 'fatal' -or ($RequestScenario -eq 'eventual' -and $state.requests -eq 1)) {
                $e=[Exception]::new('SYNTHETIC-PROBE-TOKEN private response body'); $e.Data['StatusCode']=if ($RequestScenario -eq 'fatal') {401} else {403}; throw $e
            }
            @{StatusCode=200;Content='SYNTHETIC-SECRET-BODY'}
        }.GetNewClosure()
    }
    @{state=$state;adapter=$adapter}
}
$seed=Join-Path $PSScriptRoot '../scripts/Initialize-PrivateData.ps1'
Case 'dns-and-rbac-retry-without-secret-output' {
    $fake=New-PrivateAdapter
    $output=& $seed -StorageAccountName syntheticstore -KeyVaultName syntheticvault -ExpectedBlobIp '10.20.0.4' -ExpectedVaultIp '10.20.0.5' -MaxAttempts 4 -RetryDelaySeconds 0 -Adapter $fake.adapter
    Assert ($fake.state.dns -eq 3 -and $fake.state.requests -eq 3 -and $fake.state.tokens -eq 2) 'DNS/RBAC retry sequence was wrong.'
    Assert (($output -join ' ') -notmatch 'SYNTHETIC-PROBE-TOKEN|SYNTHETIC-SECRET-BODY') 'Sensitive fixture content escaped.'
    Assert (($output -join ' ') -match 'SYNTHETIC FIXTURE') 'Synthetic success was not labelled.'
}
foreach ($scenario in @('wrong','mixed')) {
    Case "bounded-$scenario-dns" { $fake=New-PrivateAdapter $scenario 'ok'; $failed=$false; try { & $seed -StorageAccountName syntheticstore -KeyVaultName syntheticvault -ExpectedBlobIp '10.20.0.4' -ExpectedVaultIp '10.20.0.5' -MaxAttempts 3 -RetryDelaySeconds 0 -Adapter $fake.adapter | Out-Null } catch { $failed=$true }; Assert ($failed -and $fake.state.dns -eq 3 -and $fake.state.tokens -eq 0 -and $fake.state.requests -eq 0) 'Wrong DNS was not bounded before identity/data access.' }
}
Case 'fatal-http-error-is-sanitized' { $fake=New-PrivateAdapter 'ok' 'fatal'; $message=''; try { & $seed -StorageAccountName syntheticstore -KeyVaultName syntheticvault -ExpectedBlobIp '10.20.0.4' -ExpectedVaultIp '10.20.0.5' -MaxAttempts 3 -RetryDelaySeconds 0 -Adapter $fake.adapter | Out-Null } catch { $message=$_.Exception.Message }; Assert ($fake.state.requests -eq 1 -and $message -match 'HTTP 401' -and $message -notmatch 'TOKEN|private response body') 'Fatal request handling leaked or retried.' }
Case 'incomplete-adapter-never-uses-real-fallback' { $failed=$false; try { & $seed -StorageAccountName syntheticstore -KeyVaultName syntheticvault -ExpectedBlobIp '10.20.0.4' -ExpectedVaultIp '10.20.0.5' -Adapter @{Resolve={@()}} | Out-Null } catch { $failed=$true }; Assert $failed 'Partial adapter accepted.' }
$versions=@{pwsh='7.4.0';terraform='1.15.8';az='2.80.0';git='2.50.0';code='1.100.0'}
$subscription='22222222-2222-2222-2222-222222222222'
$cloud=@{account=@{id=$subscription;state='Enabled'};providers=@{};network_types=@();vm_skus=@(@{name='Standard_B2s';locations=@('westeurope');restrictions=@()});usage=@(@{name=@{value='cores'};limit=20;currentValue=0},@{name=@{value='standardBSFamily'};limit=20;currentValue=0})}
foreach ($provider in @('Microsoft.Resources','Microsoft.Network','Microsoft.OperationalInsights','Microsoft.Insights','Microsoft.Compute','Microsoft.Storage','Microsoft.KeyVault','Microsoft.ManagedIdentity')) {$cloud.providers[$provider]='Registered'}
foreach ($kind in @('virtualNetworks','azureFirewalls','bastionHosts','dnsResolvers','applicationGateways','virtualNetworkGateways')) {$cloud.network_types+=,@{resourceType=$kind;locations=@('West Europe')}}
Case 'readiness-local-is-not-cloud-success' { $r=Test-InfrastructureReadiness -Tools $versions; Assert ($r.summary.fail -eq 0 -and $r.summary.skip -eq 1 -and -not $r.azure_runtime_certified) 'Local readiness made a cloud claim.' }
Case 'readiness-valid-fixture-keeps-permissions-unresolved' { $r=Test-InfrastructureReadiness -Tools $versions -Cloud $cloud -Stage hybrid -SubscriptionId $subscription -Source synthetic; Assert ($r.summary.fail -eq 0 -and $r.summary.skip -eq 2 -and $r.requirements.additional_vcpus -eq 8) ($r|ConvertTo-Json -Depth 10) }
Case 'readiness-rejects-unpinned-terraform' { $bad=$versions.Clone();$bad.terraform='1.16.0';$r=Test-InfrastructureReadiness -Tools $bad;Assert ($r.summary.fail -eq 1) 'Unsupported Terraform was accepted.' }
Case 'readiness-insufficient-quota' { $cloud.usage[0].limit=4;$r=Test-InfrastructureReadiness -Tools $versions -Cloud $cloud -Stage hybrid -SubscriptionId $subscription -Source synthetic;Assert ($r.summary.fail -eq 1) 'Insufficient quota accepted.';$cloud.usage[0].limit=20 }
Case 'readiness-restricted-sku' { $cloud.vm_skus[0].restrictions=@(@{reasonCode='NotAvailableForSubscription'});$r=Test-InfrastructureReadiness -Tools $versions -Cloud $cloud -Stage applications -SubscriptionId $subscription -Source synthetic;Assert ($r.summary.fail -eq 1) 'Restricted SKU accepted.';$cloud.vm_skus[0].restrictions=@() }
Case 'readiness-missing-provider' { $cloud.providers['Microsoft.Network']='NotRegistered';$r=Test-InfrastructureReadiness -Tools $versions -Cloud $cloud -Stage secure -SubscriptionId $subscription -Source synthetic;Assert ($r.summary.fail -eq 1) 'Missing provider accepted.';$cloud.providers['Microsoft.Network']='Registered' }
Case 'native-json-arguments-and-exit-code' { $r=Invoke-InfrastructureNative -Command terraform -Arguments @('version','-json');Assert ($r.exit_code -eq 0 -and ($r.output|ConvertFrom-Json).terraform_version) 'Local native adapter failed.' }
Case 'native-timeout-is-bounded' { $r=Invoke-InfrastructureNative -Command pwsh -Arguments @('-NoProfile','-Command','Start-Sleep -Seconds 5') -TimeoutSeconds 1;Assert ($r.timed_out -and $r.exit_code -eq 124) 'Timeout was not enforced.' }
Case 'fixture-cli-roundtrip-and-failure' {
    $temporary=New-TemporaryFile
    try {
        Snapshot | ConvertTo-Json -Depth 30 | Set-Content -LiteralPath $temporary.FullName
        $driver=Join-Path $PSScriptRoot '../scripts/Test-Capstone.ps1'
        $arguments=@('-NoProfile','-File',$driver,'-Mode','Fixture','-FixturePath',$temporary.FullName)
        $ok=Invoke-InfrastructureNative -Command pwsh -Arguments $arguments
        Assert ($ok.exit_code -eq 0 -and ($ok.output|ConvertFrom-Json).evidence_kind -eq 'synthetic') 'Fixture CLI roundtrip failed.'
        $bad=Snapshot; $bad.observations.nics[0].ipConfigurations[0].publicIPAddress=@{id='/fixture/public'}
        $bad|ConvertTo-Json -Depth 30|Set-Content -LiteralPath $temporary.FullName
        $failed=Invoke-InfrastructureNative -Command pwsh -Arguments $arguments
        Assert ($failed.exit_code -ne 0) 'CLI returned success despite a failing assertion.'
        '{malformed'|Set-Content -LiteralPath $temporary.FullName
        $malformed=Invoke-InfrastructureNative -Command pwsh -Arguments $arguments
        Assert ($malformed.exit_code -ne 0) 'Malformed fixture accepted.'
    } finally { Remove-Item -LiteralPath $temporary.FullName -ErrorAction SilentlyContinue }
}
Case 'default-runner-has-no-azure-fallback' {
    $driver=Join-Path $PSScriptRoot '../scripts/Test-Capstone.ps1'
    $r=Invoke-InfrastructureNative -Command pwsh -Arguments @('-NoProfile','-File',$driver)
    Assert ($r.exit_code -ne 0) 'Default runner should require a fixture.'
}
Write-Output "$count infrastructure behavior cases passed. Only synthetic responses and local native commands were used; Azure runtime is unverified."
