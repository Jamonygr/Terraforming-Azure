Set-StrictMode -Version Latest
function Test-CapstoneSnapshot {
    [CmdletBinding()]
    param([Parameter(Mandatory)][System.Collections.IDictionary]$Snapshot)
    if ($Snapshot.schema_version -ne 1 -or $Snapshot.evidence_kind -notin @('synthetic','azure-read-only')) { throw 'Unsupported or unlabelled evidence snapshot.' }
    $timestamp=[datetimeoffset]::MinValue
    if ($Snapshot.outputs -isnot [System.Collections.IDictionary] -or $Snapshot.observations -isnot [System.Collections.IDictionary] -or -not [datetimeoffset]::TryParse([string]$Snapshot.collected_at,[ref]$timestamp)) { throw 'Snapshot requires output/observation maps and a valid collection timestamp.' }
    $o=$Snapshot.outputs; $seen=$Snapshot.observations
    $stage=$o.stage
    if ($stage -notin @('foundation','secure','applications','hybrid')) { throw 'Snapshot has an invalid stage.' }
    $secure=$stage -ne 'foundation'; $apps=$stage -in @('applications','hybrid'); $hybrid=$stage -eq 'hybrid'
    $results=[System.Collections.Generic.List[object]]::new()
    function Check([string]$Id,[string]$Observation,[string]$Target,[scriptblock]$Predicate) {
        $status='SKIP'; $detail='No observation supplied; this behavior is unverified.'
        if ($seen.Contains($Observation)) {
            try {
                $value=$seen[$Observation]
                if ($null -eq $value) { throw 'Missing value.' }
                if ($value -is [System.Collections.IDictionary] -and $value.Contains('_error')) { throw 'Adapter failed.' }
                $ok=& $Predicate $value
                $status=if ($ok -is [bool] -and $ok) {'PASS'} else {'FAIL'}
                $detail=if ($status -eq 'PASS') {'Observed fields match the expected contract.'} else {'Observed fields contradict the expected contract.'}
            } catch { $status='FAIL'; $detail='Observation missing required fields, malformed, or adapter failed. Raw response suppressed.' }
        }
        $results.Add([pscustomobject]@{id=$Id;stage=$stage;status=$status;target=$Target;source=$Snapshot.evidence_kind;observed_at=$Snapshot.collected_at;detail=$detail})
    }
    Check 'foundation.networks' 'vnets' $o.resource_group_name {
        param($v)
        if (@($v).Count -ne 5) { return $false }
        foreach ($target in $o.evidence_targets.virtual_networks.Values) {
            $matches=@($v | Where-Object name -eq $target.name)
            if ($matches.Count -ne 1 -or (@($matches[0].addressSpace.addressPrefixes) -join ',') -ne (@($target.prefixes) -join ',')) { return $false }
        }; return $true
    }
    Check 'foundation.peerings' 'peerings' 'six directional hub/spoke peerings' {
        param($v)
        if (@($v).Count -ne 6) { return $false }
        foreach ($peer in $v) {
            if ($peer.peeringState -ne 'Connected' -or -not $peer.allowVirtualNetworkAccess -or -not $peer.allowForwardedTraffic) { return $false }
            $isHub=$peer.source -eq 'hub'
            if ($peer.source -notin @('hub','app','data','operations') -or $peer.destination -notin @('hub','app','data','operations') -or ($peer.source -ne 'hub' -and $peer.destination -ne 'hub')) { return $false }
            if ($peer.allowGatewayTransit -ne ($hybrid -and $isHub) -or $peer.useRemoteGateways -ne ($hybrid -and -not $isHub)) { return $false }
        }
        return @($v | ForEach-Object { "$($_.source)/$($_.destination)" } | Sort-Object -Unique).Count -eq 6
    }
    Check 'foundation.private-zones' 'zone_links' 'three private zones linked only to hub' {
        param($v)
        if ($v.Count -ne 3) { return $false }
        foreach ($name in $o.evidence_targets.private_zones) {
            if (-not $v.Contains($name)) { return $false }
            $links=@($v[$name]); if ($links.Count -ne 1 -or $links[0].virtualNetwork.id -ne $o.evidence_targets.virtual_networks.hub.id -or $links[0].registrationEnabled) { return $false }
        }; return $true
    }
    Check 'foundation.monitoring' 'workspace' $o.workspace_name { param($v) return $v.name -eq $o.workspace_name -and $v.provisioningState -eq 'Succeeded' }
    if ($secure) {
        Check 'secure.firewall' 'firewall' $o.evidence_targets.firewall_name { param($v) return $v.provisioningState -eq 'Succeeded' -and $v.sku.tier -eq 'Standard' -and $v.ipConfigurations[0].privateIPAddress -eq $o.firewall_private_ip }
        Check 'secure.dns-proxy' 'firewall_policy' 'Firewall -> resolver inbound' { param($v) return $v.dnsSettings.enableProxy -and @($v.dnsSettings.servers).Count -eq 1 -and $v.dnsSettings.servers[0] -eq $o.resolver_inbound_ip }
        Check 'secure.bastion' 'bastion' $o.bastion_name { param($v) return $v.provisioningState -eq 'Succeeded' -and $v.sku.name -eq 'Standard' -and $v.enableTunneling -and $v.enableIpConnect }
        Check 'secure.routes' 'route_tables' 'workload prefix and return routes' {
            param($v)
            foreach ($key in @('app','data','operations')) {
                if (-not $v.Contains($key)) { return $false }
                $table=$v[$key]
                if (-not $table.disableBgpRoutePropagation) { return $false }
                $prefixes=@('0.0.0.0/0')+@('app','data','operations','onprem' | Where-Object {$_ -ne $key} | ForEach-Object {$o.evidence_targets.virtual_networks[$_].prefixes[0]})
                if (@($table.routes).Count -ne $prefixes.Count) { return $false }
                foreach ($prefix in $prefixes) {
                    $route=@($table.routes | Where-Object addressPrefix -eq $prefix)
                    if ($route.Count -ne 1 -or $route[0].nextHopType -ne 'VirtualAppliance' -or $route[0].nextHopIpAddress -ne $o.firewall_private_ip) { return $false }
                }
                if (@($table.subnets).Count -ne 1 -or $table.subnets[0].id -ne $o.evidence_targets.subnet_ids[$key]) { return $false }
            }; return $true
        }
    }
    if ($apps) {
        Check 'applications.private-nics' 'nics' 'all workload NICs' {
            param($v)
            $expected=if ($hybrid) {4} else {3}
            if (@($v).Count -ne $expected) { return $false }
            foreach ($key in $o.nic_names.Keys) {
                $nic=@($v | Where-Object name -eq $o.nic_names[$key]); if ($nic.Count -ne 1) { return $false }
                if (@($nic[0].ipConfigurations).Count -ne 1) { return $false }; foreach ($ip in $nic[0].ipConfigurations) { if ($ip.publicIPAddress -or $ip.privateIPAddress -ne $o.vm_private_ips[$key]) { return $false } }
            }; return $true
        }
        Check 'applications.data-boundary' 'data_services' 'Storage and Key Vault' { param($v) return $v.storage.publicNetworkAccess -eq 'Disabled' -and -not $v.storage.allowSharedKeyAccess -and $v.vault.properties.publicNetworkAccess -eq 'Disabled' -and $v.vault.properties.enableRbacAuthorization }
        Check 'applications.endpoints' 'private_endpoints' 'approved exact private endpoint targets' {
            param($v)
            foreach ($key in @('blob','vault')) { if (-not $v.Contains($key) -or $v[$key].status -ne 'Approved' -or @($v[$key].addresses).Count -ne 1 -or $v[$key].addresses[0] -ne $o.private_endpoint_ips[$key]) { return $false } }; return $true
        }
        Check 'applications.backends' 'backends' $o.app_gateway_name { param($v) return @($v).Count -eq 2 -and @($v | Where-Object health -ne 'Healthy').Count -eq 0 -and @($v | Where-Object {$_.address -in @($o.vm_private_ips.iis01,$o.vm_private_ips.iis02)} | ForEach-Object address | Sort-Object -Unique).Count -eq 2 }
        Check 'applications.https-waf' 'public_http' $o.app_host { param($v) return $v.normal_exit -eq 0 -and $v.normal_status -eq 200 -and $v.blocked_exit -eq 0 -and $v.blocked_status -eq 403 }
        Check 'applications.private-dns' 'private_dns' 'guest DNS to exact endpoint addresses' {
            param($v)
            foreach ($key in @('blob','vault')) { if (-not $v.Contains($key) -or @($v[$key]).Count -ne 1 -or $v[$key][0] -ne $o.private_endpoint_ips[$key]) { return $false } }; return $true
        }
        Check 'applications.identity' 'private_data' 'authorized reads and unauthorized denial' { param($v) return $v.blob_read_status -eq 200 -and $v.vault_read_status -eq 200 -and $v.unauthorized_status -eq 403 -and $v.source_vm -eq $o.vm_names.iis01 }
        Check 'applications.inspection' 'traffic' 'allowed/denied egress with Firewall evidence' { param($v) return $v.allowed_status -eq 200 -and $v.denied_observed -and $v.deny_source -eq 'AzureFirewall' -and $v.next_hop -eq $o.firewall_private_ip -and $v.firewall_allow_records -gt 0 -and $v.firewall_deny_records -gt 0 }
        Check 'applications.telemetry' 'telemetry' 'recent guest, IIS and service telemetry' {
            param($v)
            foreach ($table in @('Heartbeat','Event','Perf','W3CIISLog','AZFWApplicationRule','AGWFirewallLogs','StorageBlobLogs','AZKVAuditLogs')) { if (-not $v.Contains($table) -or $v[$table].records -le 0 -or ([datetimeoffset]$Snapshot.collected_at-[datetimeoffset]$v[$table].last_seen).TotalMinutes -gt 30 -or ([datetimeoffset]$Snapshot.collected_at-[datetimeoffset]$v[$table].last_seen).TotalMinutes -lt 0) { return $false } }; return $true
        }
        Check 'applications.alert-recovery' 'alert' 'backend unhealthy alert and resolution' { param($v) return $v.metric -eq 'UnhealthyHostCount' -and $v.fired -and $v.resolved }
    }
    if ($hybrid) {
        Check 'hybrid.gateway-routes' 'route_tables' 'GatewaySubnet specific routes and return inspection' {
            param($v)
            if (-not $v.Contains('gateway')) { return $false }
            $table=$v.gateway
            if ($table.disableBgpRoutePropagation -or @($table.routes).Count -ne 3 -or @($table.subnets).Count -ne 1 -or $table.subnets[0].id -ne $o.evidence_targets.subnet_ids.gateway) { return $false }
            foreach ($key in @('app','data','operations')) {
                $route=@($table.routes | Where-Object addressPrefix -eq $o.evidence_targets.virtual_networks[$key].prefixes[0])
                if ($route.Count -ne 1 -or $route[0].nextHopType -ne 'VirtualAppliance' -or $route[0].nextHopIpAddress -ne $o.firewall_private_ip) { return $false }
            }; return $true
        }
        Check 'hybrid.connections' 'vpn' 'both reciprocal VPN connections' { param($v) return @($v).Count -eq 2 -and @($v | Where-Object connectionStatus -ne 'Connected').Count -eq 0 -and @($v | Where-Object {$_.name -in @($o.vpn_connection_names.Values)} | ForEach-Object name | Sort-Object -Unique).Count -eq 2 }
        Check 'hybrid.traffic-dns' 'hybrid_probes' 'cross-tunnel application and both DNS directions' { param($v) return $v.corp_to_iis_status -eq 200 -and $v.azure_to_corp_dns -eq $o.vm_private_ips.corp01 -and $v.corp_to_azure_dns -eq $o.vm_private_ips.iis01 -and $v.tunnel_bytes_increased -and $v.firewall_records -gt 0 }
    }
    $fail=@($results | Where-Object status -eq 'FAIL').Count; $skip=@($results | Where-Object status -eq 'SKIP').Count
    return [pscustomobject]@{schema_version=1;stage=$stage;evidence_kind=$Snapshot.evidence_kind;collected_at=$Snapshot.collected_at;azure_runtime_certified=$false;summary=@{pass=$results.Count-$fail-$skip;fail=$fail;skip=$skip};results=$results.ToArray()}
}
Export-ModuleMember -Function Test-CapstoneSnapshot
