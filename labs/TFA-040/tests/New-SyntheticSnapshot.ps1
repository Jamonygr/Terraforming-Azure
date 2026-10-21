#requires -Version 7.4
[CmdletBinding()]
param([ValidateSet('foundation','secure','applications','hybrid')][string]$Stage='hybrid')
# Fabricated response shapes, never a captured Azure success record.
$hybrid=$Stage -eq 'hybrid'; $apps=$Stage -in @('applications','hybrid')
$networks=@{}; $subnetIds=@{}
$prefixes=@{hub='10.0.0.0/16';app='10.10.0.0/16';data='10.20.0.0/16';operations='10.30.0.0/16';onprem='192.168.0.0/16'}
foreach ($key in $prefixes.Keys) { $networks[$key]=@{name="vnet-fixture-$key";id="/fixture/vnets/$key";prefixes=@($prefixes[$key])}; $subnetIds[$key]="/fixture/subnets/$key" }
$o=@{stage=$Stage;resource_group_name='rg-fixture';workspace_name='law-fixture';firewall_private_ip='10.0.0.4';resolver_inbound_ip='10.0.1.4';bastion_name='bas-fixture';app_gateway_name='agw-fixture';app_host='app.terraforming-azure.test';nic_names=@{};vm_names=@{};vm_private_ips=@{};private_endpoint_ips=@{blob='10.20.0.4';vault='10.20.0.5'};vpn_connection_names=@{hub='vpn-hub-to-onprem';onprem='vpn-onprem-to-hub'}}
$o.evidence_targets=@{virtual_networks=$networks;subnet_ids=$subnetIds;private_zones=@('privatelink.blob.core.windows.net','privatelink.vaultcore.azure.net','azure.terraforming-azure.test');firewall_name='afw-fixture';firewall_policy_name='policy-fixture';route_tables=@{app='rt-app';data='rt-data';operations='rt-operations'}}
$seen=@{vnets=@();peerings=@();zone_links=@{};workspace=@{name='law-fixture';provisioningState='Succeeded'}}
foreach ($key in $networks.Keys) { $seen.vnets+=,@{name=$networks[$key].name;addressSpace=@{addressPrefixes=$networks[$key].prefixes}} }
foreach ($spoke in @('app','data','operations')) {
    $seen.peerings+=,@{source='hub';destination=$spoke;peeringState='Connected';allowVirtualNetworkAccess=$true;allowForwardedTraffic=$true;allowGatewayTransit=$hybrid;useRemoteGateways=$false}
    $seen.peerings+=,@{source=$spoke;destination='hub';peeringState='Connected';allowVirtualNetworkAccess=$true;allowForwardedTraffic=$true;allowGatewayTransit=$false;useRemoteGateways=$hybrid}
}
foreach ($zone in $o.evidence_targets.private_zones) { $seen.zone_links[$zone]=@(@{virtualNetwork=@{id=$networks.hub.id};registrationEnabled=$false}) }
if ($Stage -ne 'foundation') {
    $seen.firewall=@{provisioningState='Succeeded';sku=@{tier='Standard'};ipConfigurations=@(@{privateIPAddress=$o.firewall_private_ip})}
    $seen.firewall_policy=@{dnsSettings=@{enableProxy=$true;servers=@($o.resolver_inbound_ip)}}
    $seen.bastion=@{provisioningState='Succeeded';sku=@{name='Standard'};enableTunneling=$true;enableIpConnect=$true}
    $seen.route_tables=@{}
    foreach ($key in @('app','data','operations')) {
        $routes=@(@{addressPrefix='0.0.0.0/0';nextHopType='VirtualAppliance';nextHopIpAddress=$o.firewall_private_ip})
        foreach ($other in @('app','data','operations','onprem')) { if ($key -ne $other) { $routes+=,@{addressPrefix=$prefixes[$other];nextHopType='VirtualAppliance';nextHopIpAddress=$o.firewall_private_ip} } }
        $seen.route_tables[$key]=@{disableBgpRoutePropagation=$true;routes=$routes;subnets=@(@{id=$subnetIds[$key]})}
    }
}
if ($apps) {
    $o.vm_private_ips=@{iis01='10.10.1.4';iis02='10.10.1.5';ops01='10.30.0.4'}
    if ($hybrid) { $o.vm_private_ips.corp01='192.168.1.4' }
    $seen.nics=@()
    foreach ($key in $o.vm_private_ips.Keys) { $o.vm_names[$key]="vm-fixture-$key"; $o.nic_names[$key]="nic-fixture-$key"; $seen.nics+=,@{name=$o.nic_names[$key];ipConfigurations=@(@{privateIPAddress=$o.vm_private_ips[$key];publicIPAddress=$null})} }
    $seen.data_services=@{storage=@{publicNetworkAccess='Disabled';allowSharedKeyAccess=$false};vault=@{properties=@{publicNetworkAccess='Disabled';enableRbacAuthorization=$true}}}
    $seen.private_endpoints=@{blob=@{status='Approved';addresses=@('10.20.0.4')};vault=@{status='Approved';addresses=@('10.20.0.5')}}
    $seen.backends=@(@{address='10.10.1.4';health='Healthy'},@{address='10.10.1.5';health='Healthy'})
    $seen.public_http=@{normal_exit=0;normal_status=200;blocked_exit=0;blocked_status=403}
    $seen.private_dns=@{blob=@('10.20.0.4');vault=@('10.20.0.5')}
    $seen.private_data=@{source_vm=$o.vm_names.iis01;blob_read_status=200;vault_read_status=200;unauthorized_status=403}
    $seen.traffic=@{allowed_status=200;denied_observed=$true;deny_source='AzureFirewall';next_hop=$o.firewall_private_ip;firewall_allow_records=1;firewall_deny_records=1}
    $seen.telemetry=@{}
    foreach ($table in @('Heartbeat','Event','Perf','W3CIISLog','AZFWApplicationRule','AGWFirewallLogs','StorageBlobLogs','AZKVAuditLogs')) { $seen.telemetry[$table]=@{records=1;last_seen='2026-10-21T12:00:00Z'} }
    $seen.alert=@{metric='UnhealthyHostCount';fired=$true;resolved=$true}
}
if ($hybrid) {
    $subnetIds.gateway='/fixture/subnets/GatewaySubnet'; $o.evidence_targets.route_tables.gateway='rt-gateway'
    $routes=@('app','data','operations' | ForEach-Object { @{addressPrefix=$prefixes[$_];nextHopType='VirtualAppliance';nextHopIpAddress=$o.firewall_private_ip} })
    $seen.route_tables.gateway=@{disableBgpRoutePropagation=$false;routes=$routes;subnets=@(@{id=$subnetIds.gateway})}
    $seen.vpn=@(@{name=$o.vpn_connection_names.hub;connectionStatus='Connected'},@{name=$o.vpn_connection_names.onprem;connectionStatus='Connected'}); $seen.hybrid_probes=@{corp_to_iis_status=200;azure_to_corp_dns='192.168.1.4';corp_to_azure_dns='10.10.1.4';tunnel_bytes_increased=$true;firewall_records=1} }
@{schema_version=1;evidence_kind='synthetic';collected_at='2026-10-21T12:01:00Z';outputs=$o;observations=$seen}
