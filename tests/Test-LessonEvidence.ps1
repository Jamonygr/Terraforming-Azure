[CmdletBinding()]
param()
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$fixture = Join-Path $PSScriptRoot 'fixtures/lesson-evidence'
& (Join-Path $PSScriptRoot 'Test-IisBootstrap.ps1')
& (Join-Path $PSScriptRoot 'Test-RouteGovernanceFixtures.ps1')
$null = & (Join-Path $root 'labs/TFA-028/Test-AlertEvidence.ps1') -Path (Join-Path $fixture 'alert-lifecycle.json')
$null = & (Join-Path $root 'labs/TFA-031/Test-DnsEvidence.ps1') -Path (Join-Path $fixture 'dns-bidirectional.json') -ExpectedBlobIp '10.31.2.4' -ExpectedCorporateIp '10.131.2.4'
$null = & (Join-Path $root 'labs/TFA-034/Test-IncidentEvidence.ps1') -Path (Join-Path $fixture 'incidents.json')
$null = & (Join-Path $root 'labs/TFA-036/Test-FederationContract.ps1') -Path (Join-Path $fixture 'federation.json')
$rejected = $false
try { & (Join-Path $root 'labs/TFA-031/Test-DnsEvidence.ps1') -Path (Join-Path $fixture 'dns-bidirectional.json') -ExpectedBlobIp '10.31.2.99' -ExpectedCorporateIp '10.131.2.4' | Out-Null } catch { $rejected = $true }
if (-not $rejected) { throw 'A different private IP must not pass as the intended Blob endpoint.' }
$rejected = $false
try { & (Join-Path $root 'labs/TFA-036/Test-FederationContract.ps1') -Path (Join-Path $fixture 'federation-wrong-environment.json') | Out-Null } catch { $rejected = $true }
if (-not $rejected) { throw 'A mismatched environment must not satisfy the federation contract.' }
# Built-in Terraform only, in an isolated temporary directory.
$temporaryRoot = [IO.Path]::GetFullPath([IO.Path]::GetTempPath())
$directory = Join-Path $temporaryRoot ('tfa-plan-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $directory | Out-Null
try {
    foreach ($file in @('main.tf','outputs.tf','variables.tf','versions.tf')) { Copy-Item -LiteralPath (Join-Path $root "labs/TFA-037/$file") -Destination $directory }
    $runner = Join-Path $root 'labs/TFA-037/Demo-SavedPlan.ps1'
    & $runner -Directory $directory -Operation Plan | Out-Null
    $planPath = Join-Path $directory 'rehearsal.tfplan'
    $original = [IO.File]::ReadAllBytes($planPath)
    $changed = [byte[]]$original.Clone(); $changed[0] = $changed[0] -bxor 1
    [IO.File]::WriteAllBytes($planPath,$changed)
    $rejected = $false
    try { & $runner -Directory $directory -Operation Apply -AcknowledgeReviewedPlan | Out-Null } catch { $rejected = $true }
    if (-not $rejected) { throw 'Changed plan bytes were accepted.' }
    [IO.File]::WriteAllBytes($planPath,$original)
    $rejected = $false
    try { & $runner -Directory $directory -Operation Destroy -AcknowledgeReviewedPlan | Out-Null } catch { $rejected = $true }
    if (-not $rejected) { throw 'An apply plan was accepted as a destroy plan.' }
    & $runner -Directory $directory -Operation Apply -AcknowledgeReviewedPlan | Out-Null
    terraform "-chdir=$directory" plan -detailed-exitcode -input=false | Out-Null
    if ($LASTEXITCODE -ne 0) { throw 'Local saved-plan apply did not converge.' }
    & $runner -Directory $directory -Operation PlanDestroy | Out-Null
    & $runner -Directory $directory -Operation Destroy -AcknowledgeReviewedPlan | Out-Null
    $remaining = @(terraform "-chdir=$directory" state list)
    if ($LASTEXITCODE -ne 0 -or $remaining.Count) { throw 'Local saved-plan cleanup left resources.' }
}
finally {
    $resolved = [IO.Path]::GetFullPath($directory)
    if ($resolved.StartsWith($temporaryRoot,[StringComparison]::OrdinalIgnoreCase) -and (Split-Path $resolved -Leaf) -match '^tfa-plan-[a-f0-9]{32}$') { Remove-Item -LiteralPath $resolved -Recurse -Force }
}
Write-Output 'PASS lesson evidence: alert lifecycle, exact bidirectional DNS, five incident cases, federation rejection, local saved-plan apply/tamper/operation/cleanup. Azure was not contacted.'
