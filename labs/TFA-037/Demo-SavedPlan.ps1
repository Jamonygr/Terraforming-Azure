[CmdletBinding()]
param(
    [Parameter(Mandatory)][ValidateSet('Plan','Apply','PlanDestroy','Destroy')][string]$Operation,
    [switch]$AcknowledgeReviewedPlan,
    [string]$Directory = $PSScriptRoot
)
$ErrorActionPreference = 'Stop'
$Directory = (Resolve-Path -LiteralPath $Directory).Path
# This teaching runner accepts only the checked-in local contract's two Terraform source files.
$expected = @('main.tf','outputs.tf','variables.tf','versions.tf')
foreach ($file in $expected) {
    if ((Get-FileHash -LiteralPath (Join-Path $Directory $file)).Hash -ne (Get-FileHash -LiteralPath (Join-Path $PSScriptRoot $file)).Hash) {
        throw "Local rehearsal source differs: $file"
    }
}
if (@(Get-ChildItem -LiteralPath $Directory -Filter '*.tf' -File).Count -ne $expected.Count -or @(Get-ChildItem -LiteralPath $Directory -Filter '*.tf.json' -File).Count -ne 0) { throw 'Extra Terraform source is not allowed in the local rehearsal.' }
$previous = Get-Location
try {
    Set-Location -LiteralPath $Directory
    $planPath = Join-Path $Directory 'rehearsal.tfplan'
    $manifestPath = Join-Path $Directory 'rehearsal.manifest.json'
    $sourceHashes = @{}
    foreach ($file in $expected) { $sourceHashes[$file] = (Get-FileHash -LiteralPath $file -Algorithm SHA256).Hash }
    if ($Operation -in @('Plan','PlanDestroy')) {
        terraform init -input=false -backend=false | Out-Null
        if ($LASTEXITCODE -ne 0) { throw 'Local init failed.' }
        $arguments = @('plan','-input=false',"-out=$planPath")
        if ($Operation -eq 'PlanDestroy') { $arguments += '-destroy' }
        & terraform @arguments
        if ($LASTEXITCODE -ne 0) { throw 'Local plan failed.' }
        $kind = if ($Operation -eq 'PlanDestroy') { 'destroy' } else { 'apply' }
        @{ operation=$kind; created_utc=[DateTimeOffset]::UtcNow.ToString('o'); root=$Directory; sha256=(Get-FileHash -LiteralPath $planPath -Algorithm SHA256).Hash; source_hashes=$sourceHashes } | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $manifestPath -Encoding utf8
        Write-Output "Review: terraform show $planPath"
        return
    }
    if (-not $AcknowledgeReviewedPlan) { throw 'Read terraform show first, then explicitly acknowledge the reviewed plan.' }
    $manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json -AsHashtable
    $expectedKind = if ($Operation -eq 'Destroy') { 'destroy' } else { 'apply' }
    $age = [DateTimeOffset]::UtcNow - [DateTimeOffset]::Parse($manifest.created_utc)
    if ($age.TotalHours -gt 24 -or $age.TotalSeconds -lt -60) { throw 'Plan is stale or future-dated.' }
    if ($manifest.operation -cne $expectedKind -or $manifest.root -cne $Directory) { throw 'Plan operation or root does not match.' }
    if ((Get-FileHash -LiteralPath $planPath -Algorithm SHA256).Hash -cne $manifest.sha256) { throw 'Plan hash differs from the reviewed artifact.' }
    foreach ($file in $expected) { if ($sourceHashes[$file] -cne $manifest.source_hashes[$file]) { throw 'Source changed after planning.' } }
    terraform apply -input=false $planPath
    if ($LASTEXITCODE -ne 0) { throw 'Applying the saved local plan failed; retain state.' }
}
finally { Set-Location -LiteralPath $previous }
