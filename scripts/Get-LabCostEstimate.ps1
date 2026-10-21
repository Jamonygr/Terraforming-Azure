[CmdletBinding()]
param(
  [string]$Region = 'westeurope',
  [string]$Currency = 'USD',
  [string[]]$ServiceNames = @('Azure Firewall','Azure Bastion','Application Gateway','VPN Gateway','Azure DNS','Azure DNS Private Resolver'),
  [string]$SelectionFile
)
$ErrorActionPreference = 'Stop'
$items = @()
foreach ($service in $ServiceNames) {
  $filter = "armRegionName eq '$($Region.Replace("'","''"))' and serviceName eq '$($service.Replace("'","''"))' and priceType eq 'Consumption'"
  $uri = 'https://prices.azure.com/api/retail/prices?currencyCode=' + [uri]::EscapeDataString($Currency) + '&$filter=' + [uri]::EscapeDataString($filter)
  do {
    $page = Invoke-RestMethod -Uri $uri -Method Get
    $items += @($page.Items | Where-Object { $_.retailPrice -gt 0 })
    $uri = $page.NextPageLink
  } while ($uri)
}
if (-not $SelectionFile) {
  $items | Select-Object serviceName,productName,skuName,meterName,meterId,unitOfMeasure,retailPrice,currencyCode,effectiveStartDate | Sort-Object serviceName,meterName
  Write-Output 'Choose exact compatible meters and quantities in a selection JSON file. No automatic lowest-price selection is made.'
  return
}
$selection = Get-Content -LiteralPath $SelectionFile -Raw | ConvertFrom-Json
$four = 0.0; $day = 0.0
foreach ($line in $selection) {
  $meter = @($items | Where-Object { $_.meterId -eq $line.meter_id })
  if ($meter.Count -ne 1) { throw "Meter $($line.meter_id) missing or ambiguous; refine services/selection." }
  if ($meter[0].unitOfMeasure -notin @('1 Hour','1/Hour')) { throw "Meter $($line.meter_id) is not a simple hourly meter; estimate its unit separately." }
  if ([double]$line.quantity -le 0) { throw 'Every quantity must be positive.' }
  $rate = [double]$meter[0].retailPrice * [double]$line.quantity
  $four += $rate * 4; $day += $rate * 24
  [pscustomobject]@{Resource=$meter[0].meterName; Quantity=$line.quantity; FourHours=[math]::Round($rate*4,4); TwentyFourHours=[math]::Round($rate*24,4); Currency=$Currency}
}
Write-Output "Selected hourly meters only: 4h=$([math]::Round($four,2)), 24h=$([math]::Round($day,2)) $Currency; retrieved $([datetime]::UtcNow.ToString('yyyy-MM-dd')). Add capacity, traffic, disks, logs, queries, taxes and other unselected meters."
