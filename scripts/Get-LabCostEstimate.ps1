[CmdletBinding()]
param(
  [string]$Region = 'westeurope',
  [string]$Currency = 'USD',
  [ValidatePattern('^TFA-0[0-4][0-9]$')][string]$Lab,
  [ValidateSet('foundation','secure','applications','hybrid')][string]$Stage,
  [ValidateRange(0.01,87600)][decimal]$Hours = 4,
  [switch]$OptionalProbes,
  [switch]$Refresh,
  [string[]]$ServiceNames = @('Azure Firewall','Azure Bastion','Application Gateway','VPN Gateway','Azure DNS','Azure DNS Private Resolver'),
  [string]$SelectionFile
)
$ErrorActionPreference = 'Stop'
if (-not $Refresh -and -not $SelectionFile) {
  $repo = Split-Path $PSScriptRoot -Parent
  $snapshot = Get-Content -LiteralPath (Join-Path $repo 'docs/cost-snapshot.json') -Raw | ConvertFrom-Json -AsHashtable
  $inventory = Get-Content -LiteralPath (Join-Path $repo 'curriculum/costs.json') -Raw | ConvertFrom-Json -AsHashtable
  if ($Region -ne $snapshot.region -or $Currency -ne $snapshot.currency) { throw 'The saved estimate covers West Europe/USD only. Use -Refresh to inspect other public prices.' }
  if ($Lab -and $Stage) { throw 'Choose either -Lab or -Stage.' }
  if ($Lab -eq 'TFA-040') { throw 'Choose -Stage foundation, secure, applications or hybrid for TFA-040.' }
  if (-not $Lab -and -not $Stage) { $Stage = 'hybrid' }
  $key = if ($Lab) { $Lab } else { $Stage }
  $entry = if ($Lab) { $inventory.labs[$Lab] } else { $inventory.stages[$Stage] }
  if (-not $entry) { throw "Unknown inventory $key" }
  $quantities = $entry.resources.Clone()
  if ($OptionalProbes -and $entry.optional_resources) {
    foreach ($name in $entry.optional_resources.Keys) { $quantities[$name] = [decimal]$quantities[$name] + [decimal]$entry.optional_resources[$name] }
  }
  $total = [decimal]0
  foreach ($name in $quantities.Keys | Sort-Object) {
    $meter = $snapshot.meters[$name]
    $factor = switch ($meter.basis) {
      'hour' { $Hours }
      'month' { $Hours / [decimal]$snapshot.monthly_hours }
      'month_daily' { [decimal][math]::Ceiling($Hours / 24) / [decimal]$snapshot.monthly_days }
      'usage_daily' { $Hours / 24 }
      default { throw "Unsupported billing basis for $name" }
    }
    $amount = [decimal]$meter.retailPrice * [decimal]$quantities[$name] * $factor
    $total += $amount
    [pscustomobject]@{ Resource=$name; Quantity=$quantities[$name]; Hours=$Hours; USD=[math]::Round($amount,4); Snapshot=$snapshot.date }
  }
  Write-Output "$key : $Hours hours = USD $([math]::Round($total,2)); public price snapshot $($snapshot.date)."
  Write-Output $entry.note
  Write-Output 'Additional usage charges excluded. Read docs/cost-estimates.md assumptions. No Azure login or network call was made.'
  return
}
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
