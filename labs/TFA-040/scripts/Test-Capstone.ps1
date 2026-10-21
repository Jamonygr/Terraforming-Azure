[CmdletBinding()]
param([switch]$SkipPublicIngress)
$ErrorActionPreference = 'Stop'
$raw = terraform output -json
if ($LASTEXITCODE -ne 0) { throw 'terraform output failed. Run from labs/TFA-040 after apply.' }
$values = $raw | ConvertFrom-Json
$rg = $values.resource_group_name.value
$stage = $values.stage.value
Write-Output "Capstone stage: $stage; resource group: $rg"

if ($stage -in @('applications', 'hybrid')) {
    if (-not $SkipPublicIngress) {
        $address = $values.app_gateway_public_ip.value
        $hostName = $values.app_host.value
        # Self-signed demonstration certificate: -k is deliberate for this lab only.
        $normal = & curl.exe --silent --show-error --insecure --resolve "${hostName}:443:$address" -o NUL -w '%{http_code}' "https://$hostName/"
        if ($LASTEXITCODE -ne 0 -or $normal -ne '200') { throw "Expected HTTPS 200, received $normal" }
        $blocked = & curl.exe --silent --show-error --insecure --resolve "${hostName}:443:$address" -H 'X-Lab-Block: true' -o NUL -w '%{http_code}' "https://$hostName/"
        if ($LASTEXITCODE -ne 0 -or $blocked -ne '403') { throw "Expected WAF 403, received $blocked" }
        Write-Output 'PASS: public HTTPS 200 and deterministic WAF 403.'
    }
    $appGateway = $values.app_gateway_name.value
    $backend = az network application-gateway show-backend-health --resource-group $rg --name $appGateway --output json | ConvertFrom-Json
    if ($LASTEXITCODE -ne 0) { throw 'Backend health query failed.' }
    $servers = @($backend.backendAddressPools.backendHttpSettingsCollection.servers)
    if ($servers.Count -ne 2 -or @($servers | Where-Object health -ne 'Healthy').Count -ne 0) {
        throw "Expected two Healthy IIS backends. Inspect show-backend-health: $($servers | ConvertTo-Json -Compress)"
    }
    Write-Output 'PASS: both IIS backends Healthy.'
    foreach ($property in $values.nic_names.value.PSObject.Properties) {
        $nic = az network nic show --resource-group $rg --name $property.Value --output json | ConvertFrom-Json
        if ($LASTEXITCODE -ne 0) { throw "NIC lookup failed: $($property.Value)" }
        if ($nic.ipConfigurations.publicIPAddress.id) { throw "VM $($property.Name) unexpectedly has a public IP." }
    }
    Write-Output 'PASS: no workload NIC public IPs.'
}
if ($stage -eq 'hybrid') {
    foreach ($connection in $values.vpn_connection_names.value.PSObject.Properties) {
        $status = az network vpn-connection show --resource-group $rg --name $connection.Value --query connectionStatus --output tsv
        if ($LASTEXITCODE -ne 0 -or $status -ne 'Connected') { throw "VPN $($connection.Name) is $status, expected Connected. Wait and inspect gateway diagnostics." }
    }
    Write-Output 'PASS: both IPsec connections Connected. Complete private traffic/DNS probes and inspect logs separately.'
}
Write-Output 'Control-plane checks complete. A live pass also requires the README traffic matrix, effective-route checks, private probes, and Log Analytics evidence.'
