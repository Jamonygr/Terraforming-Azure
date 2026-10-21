#requires -Version 7.2
[CmdletBinding()]
param([Parameter(Mandatory)][switch]$AzureReadOnly,[switch]$SkipPublicIngress)
$ErrorActionPreference='Stop'
if (-not $AzureReadOnly) { throw 'Azure collection requires an explicit -AzureReadOnly switch.' }
Import-Module (Join-Path $PSScriptRoot '../../../scripts/Infrastructure.Common.psm1') -Force
function JsonCommand([string]$Command,[string[]]$Arguments) {
    $result=Invoke-InfrastructureNative -Command $Command -Arguments $Arguments -TimeoutSeconds 45
    if ($result.exit_code -ne 0) { throw 'Native command failed or timed out; details suppressed.' }
    return ConvertFrom-Json -InputObject $result.output -AsHashtable -ErrorAction Stop
}
$raw=JsonCommand 'terraform' @('output','-json'); $o=@{}
foreach ($key in $raw.Keys) { $o[$key]=$raw[$key].value }
$seen=@{}; $rg=$o.resource_group_name
function Observe([string]$Key,[scriptblock]$Action) { try { $seen[$Key]=& $Action } catch { $seen[$Key]=@{_error='collection failed or timed out'} } }
Observe 'vnets' { @(JsonCommand 'az' @('network','vnet','list','-g',$rg,'-o','json','--only-show-errors')) }
Observe 'peerings' {
    $all=@()
    foreach ($key in $o.evidence_targets.virtual_networks.Keys) {
        $vnet=$o.evidence_targets.virtual_networks[$key]
        foreach ($peer in @(JsonCommand 'az' @('network','vnet','peering','list','-g',$rg,'--vnet-name',$vnet.name,'-o','json','--only-show-errors'))) {
            $peer.source=$key; $peer.destination='unknown'
            foreach ($other in $o.evidence_targets.virtual_networks.Keys) { if ($o.evidence_targets.virtual_networks[$other].id -eq $peer.remoteVirtualNetwork.id) { $peer.destination=$other } }
            $all+=,$peer
        }
    }; $all
}
Observe 'zone_links' { $links=@{}; foreach ($zone in $o.evidence_targets.private_zones) { $links[$zone]=@(JsonCommand 'az' @('network','private-dns','link','vnet','list','-g',$rg,'-z',$zone,'-o','json','--only-show-errors')) }; $links }
Observe 'workspace' { JsonCommand 'az' @('monitor','log-analytics','workspace','show','-g',$rg,'-n',$o.workspace_name,'-o','json','--only-show-errors') }
if ($o.stage -ne 'foundation') {
    Observe 'firewall' { JsonCommand 'az' @('network','firewall','show','-g',$rg,'-n',$o.evidence_targets.firewall_name,'-o','json','--only-show-errors') }
    Observe 'firewall_policy' { JsonCommand 'az' @('network','firewall','policy','show','-g',$rg,'-n',$o.evidence_targets.firewall_policy_name,'-o','json','--only-show-errors') }
    Observe 'bastion' { JsonCommand 'az' @('network','bastion','show','-g',$rg,'-n',$o.bastion_name,'-o','json','--only-show-errors') }
    Observe 'route_tables' { $tables=@{}; foreach ($key in $o.evidence_targets.route_tables.Keys) { $tables[$key]=JsonCommand 'az' @('network','route-table','show','-g',$rg,'-n',$o.evidence_targets.route_tables[$key],'-o','json','--only-show-errors') }; $tables }
}
if ($o.stage -in @('applications','hybrid')) {
    Observe 'nics' { @(JsonCommand 'az' @('network','nic','list','-g',$rg,'-o','json','--only-show-errors') | Where-Object {$_.name -in @($o.nic_names.Values)}) }
    Observe 'data_services' { @{storage=(JsonCommand 'az' @('storage','account','show','-g',$rg,'-n',$o.storage_account_name,'-o','json','--only-show-errors'));vault=(JsonCommand 'az' @('keyvault','show','-g',$rg,'-n',$o.key_vault_name,'-o','json','--only-show-errors'))} }
    Observe 'private_endpoints' {
        $endpoints=@{}
        foreach ($key in $o.evidence_targets.private_endpoint_names.Keys) {
            $pe=JsonCommand 'az' @('network','private-endpoint','show','-g',$rg,'-n',$o.evidence_targets.private_endpoint_names[$key],'-o','json','--only-show-errors')
            $nic=JsonCommand 'az' @('network','nic','show','--ids',$pe.networkInterfaces[0].id,'-o','json','--only-show-errors')
            $endpoints[$key]=@{status=$pe.privateLinkServiceConnections[0].privateLinkServiceConnectionState.status;addresses=@($nic.ipConfigurations | ForEach-Object {$_.privateIPAddress})}
        }; $endpoints
    }
    Observe 'backends' { $health=JsonCommand 'az' @('network','application-gateway','show-backend-health','-g',$rg,'-n',$o.app_gateway_name,'-o','json','--only-show-errors'); @($health.backendAddressPools | ForEach-Object {$_.backendHttpSettingsCollection} | ForEach-Object {$_.servers}) }
    if (-not $SkipPublicIngress) {
        Observe 'public_http' {
            $discard=if ($IsWindows) {'NUL'} else {'/dev/null'}
            $common=@('--silent','--show-error','--insecure','--connect-timeout','10','--max-time','30','--resolve',"$($o.app_host):443:$($o.app_gateway_public_ip)",'-o',$discard,'-w','%{http_code}')
            $normal=Invoke-InfrastructureNative -Command curl.exe -Arguments ($common+@("https://$($o.app_host)/")) -TimeoutSeconds 40
            $blocked=Invoke-InfrastructureNative -Command curl.exe -Arguments ($common+@('-H','X-Lab-Block: true',"https://$($o.app_host)/")) -TimeoutSeconds 40
            @{normal_exit=$normal.exit_code;normal_status=$normal.output;blocked_exit=$blocked.exit_code;blocked_status=$blocked.output}
        }
    }
}
if ($o.stage -eq 'hybrid') { Observe 'vpn' { @(JsonCommand 'az' @('network','vpn-connection','list','-g',$rg,'-o','json','--only-show-errors')) } }
# Guest probes, token exchange, alert injection and log acceptance are not inferred
# from control-plane state. Those checks remain SKIP without observations.
@{schema_version=1;evidence_kind='azure-read-only';collected_at=[datetimeoffset]::UtcNow.ToString('o');outputs=$o;observations=$seen}
