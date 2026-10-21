[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$EffectiveRoutesPath,
    [Parameter(Mandatory)][string]$NextHopPath,
    [Parameter(Mandatory)][ipaddress]$Destination,
    [Parameter(Mandatory)][ValidateSet('None','VnetLocal','Internet','VirtualAppliance','VirtualNetworkGateway')][string]$ExpectedNextHop
)
$ErrorActionPreference = 'Stop'
function ConvertTo-IPv4Number([ipaddress]$Address) {
    if ($Address.AddressFamily -ne [Net.Sockets.AddressFamily]::InterNetwork) { throw 'This lesson evaluates IPv4 routes only.' }
    $bytes = $Address.GetAddressBytes()
    return [uint64]$bytes[0]*16777216 + [uint64]$bytes[1]*65536 + [uint64]$bytes[2]*256 + [uint64]$bytes[3]
}
$destinationNumber = ConvertTo-IPv4Number $Destination
$routes = Get-Content -LiteralPath $EffectiveRoutesPath -Raw | ConvertFrom-Json
$nextHop = Get-Content -LiteralPath $NextHopPath -Raw | ConvertFrom-Json
$routeMatches = @(
    foreach ($route in $routes.value) {
        if ($route.state -cne 'Active') { continue }
        foreach ($prefix in $route.addressPrefix) {
            $parts = $prefix -split '/'
            if ($parts.Count -ne 2 -or [int]$parts[1] -lt 0 -or [int]$parts[1] -gt 32) { throw 'Invalid prefix in route evidence.' }
            $bits = [int]$parts[1]
            $mask = if ($bits -eq 0) { [uint64]0 } else { ([uint64]4294967295 -shl (32-$bits)) -band [uint64]4294967295 }
            $network = ConvertTo-IPv4Number ([ipaddress]$parts[0])
            if (($destinationNumber -band $mask) -ne ($network -band $mask)) { continue }
            $priority = switch ($route.source) { 'User' { 3 } 'VirtualNetworkGateway' { 2 } 'Default' { 1 } default { throw 'Unknown route source; inspect the response.' } }
            [pscustomobject]@{ prefix=$prefix; bits=$bits; priority=$priority; next_hop=$route.nextHopType; source=$route.source }
        }
    }
)
$selected = $routeMatches | Sort-Object -Property @{Expression='bits';Descending=$true},@{Expression='priority';Descending=$true} | Select-Object -First 1
if (-not $selected) { throw 'No active route covers the destination.' }
if ($selected.next_hop -cne $nextHop.nextHopType -or $selected.next_hop -cne $ExpectedNextHop) { throw 'Effective route, Network Watcher response and expected next hop disagree.' }
[pscustomobject]@{ evidence_mode='saved_response'; destination=$Destination.ToString(); selected_prefix=$selected.prefix; next_hop=$selected.next_hop; discards_traffic=($selected.next_hop -ceq 'None') }
