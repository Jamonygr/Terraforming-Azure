function Test-InfrastructureReadiness {
    [CmdletBinding()]
    param([System.Collections.IDictionary]$Tools,[System.Collections.IDictionary]$Cloud,[ValidateSet('foundation','secure','applications','hybrid')][string]$Stage='foundation',[string]$SubscriptionId,[string]$Location='westeurope',[ValidateSet('local','synthetic','azure-read-only')][string]$Source='local')
    $rows=[Collections.Generic.List[object]]::new()
    function Row($id,$status,$detail) { $rows.Add([pscustomobject]@{id=$id;status=$status;source=$Source;detail=$detail}) }
    $ranges=@{pwsh=@([version]'7.4',[version]'8.0');terraform=@([version]'1.15.8',[version]'1.15.9');az=@([version]'2.60',[version]'3.0');git=@([version]'2.40',[version]'3.0');code=@([version]'1.90',[version]'2.0')}
    foreach ($name in @('pwsh','terraform','az','git','code')) {
        $version=$null
        $valid=$Tools.Contains($name) -and [version]::TryParse([string]$Tools[$name],[ref]$version)
        if (-not $valid) { Row "tool.$name" 'FAIL' 'Missing tool or unparsable version.' }
        elseif ($version -lt $ranges[$name][0] -or $version -ge $ranges[$name][1]) { Row "tool.$name" 'FAIL' "Version $version is outside $($ranges[$name][0]) <= version < $($ranges[$name][1])." }
        else { Row "tool.$name" 'PASS' "Supported local version $version." }
    }
    $vmCount=if ($Stage -eq 'hybrid') {4} elseif ($Stage -eq 'applications') {3} else {0}
    $requirements=@{stage=$Stage;location=$Location;windows_vm_sku='Standard_B2s';windows_vm_count=$vmCount;additional_vcpus=2*$vmCount;vpn_gateways=$(if ($Stage -eq 'hybrid') {2} else {0});network_types=@('virtualNetworks')}
    if ($Stage -ne 'foundation') { $requirements.network_types+=@('azureFirewalls','bastionHosts','dnsResolvers') }
    if ($vmCount) { $requirements.network_types+='applicationGateways' }
    if ($Stage -eq 'hybrid') { $requirements.network_types+='virtualNetworkGateways' }
    $providers=@('Microsoft.Resources','Microsoft.Network','Microsoft.OperationalInsights','Microsoft.Insights')
    if ($vmCount) { $providers+=@('Microsoft.Compute','Microsoft.Storage','Microsoft.KeyVault','Microsoft.ManagedIdentity') }
    $requirements.providers=$providers
    if ($null -eq $Cloud) { Row 'azure.readiness' 'SKIP' 'Azure inspection was not requested. Local tool checks do not establish deployment permissions, quotas or availability.' }
    else {
        if ($Cloud.Contains('_error')) { Row 'azure.collection' 'FAIL' 'Azure adapter failed, timed out or returned malformed JSON. Raw responses suppressed.' }
        else {
            if (-not $Cloud.Contains('account') -or $Cloud.account.id -ne $SubscriptionId -or $Cloud.account.state -ne 'Enabled') { Row 'azure.subscription' 'FAIL' 'An enabled explicitly selected subscription was not verified.' }
            else { Row 'azure.subscription' 'PASS' 'Explicit enabled subscription matches. This does not establish authorization.' }
            foreach ($provider in $providers) {
                if (-not $Cloud.Contains('providers') -or -not $Cloud.providers.Contains($provider) -or $Cloud.providers[$provider] -ne 'Registered') { Row "provider.$provider" 'FAIL' 'Required provider is not verified Registered for this stage.' }
                else { Row "provider.$provider" 'PASS' 'Required provider is registered.' }
            }
            foreach ($kind in $requirements.network_types) {
                if (-not $Cloud.Contains('network_types')) { Row "region.$kind" 'SKIP' 'Regional resource-type availability is unavailable.'; continue }
                $types=@($Cloud.network_types | Where-Object resourceType -eq $kind)
                if ($types.Count -eq 1 -and $Location.ToLowerInvariant() -in @($types[0].locations | ForEach-Object {($_ -replace ' ','').ToLowerInvariant()})) { Row "region.$kind" 'PASS' 'Resource type lists this region; this does not guarantee SKU capacity.' }
                else { Row "region.$kind" 'FAIL' 'Selected region is not listed for this resource type.' }
            }
            if ($vmCount) {
                if (-not $Cloud.Contains('vm_skus')) { Row 'azure.vm-sku' 'SKIP' 'VM SKU response unavailable.' }
                else {
                    $skus=@($Cloud.vm_skus | Where-Object {$_.name -eq $requirements.windows_vm_sku -and $Location -in @($_.locations)})
                    if ($skus.Count -eq 1 -and @($skus[0].restrictions).Count -eq 0) { Row 'azure.vm-sku' 'PASS' 'Selected VM SKU has no reported restriction in this region.' }
                    else { Row 'azure.vm-sku' 'FAIL' 'Selected VM SKU is absent or restricted.' }
                }
                foreach ($quota in @('cores','standardBSFamily')) {
                    if (-not $Cloud.Contains('usage')) { Row "quota.$quota" 'SKIP' 'Quota response unavailable.'; continue }
                    $usage=@($Cloud.usage | Where-Object {$_.name.value -eq $quota})
                    if ($usage.Count -ne 1) { Row "quota.$quota" 'SKIP' 'Required quota meter is absent; review it explicitly.' }
                    elseif (($usage[0].limit-$usage[0].currentValue) -lt $requirements.additional_vcpus) { Row "quota.$quota" 'FAIL' 'Insufficient reported free vCPU quota for a fresh stage deployment.' }
                    else { Row "quota.$quota" 'PASS' 'Reported free vCPU quota covers a fresh stage deployment.' }
                }
            }
            Row 'azure.policy-permissions' 'SKIP' 'Effective deployment/role-assignment permissions, deny assignments and applicable policy require scoped review. Sign-in never proves them.'
            Row 'azure.managed-service-capacity' 'SKIP' 'VPN/Firewall/WAF/Bastion/Resolver SKU capacity and service-specific quotas are unresolved by these public resource-type/VM APIs.'
        }
    }
    $failed=@($rows | Where-Object status -eq 'FAIL').Count; $skipped=@($rows | Where-Object status -eq 'SKIP').Count
    [pscustomobject]@{schema_version=1;source=$Source;observed_at=[datetimeoffset]::UtcNow.ToString('o');requirements=$requirements;azure_runtime_certified=$false;summary=@{pass=$rows.Count-$failed-$skipped;fail=$failed;skip=$skipped};results=$rows.ToArray()}
}
Export-ModuleMember -Function Test-InfrastructureReadiness
