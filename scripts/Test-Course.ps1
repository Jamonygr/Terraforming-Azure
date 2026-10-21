[CmdletBinding()]
param(
  [switch]$DocsOnly,
  [switch]$SkipTests,
  [switch]$WindowsOnly,
  [string]$Python = 'python',
  [ValidateRange(1,8)][int]$Jobs = 1
)
$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path $PSScriptRoot -Parent
function Invoke-Check {
  param([string]$Program, [string[]]$Arguments)
  $global:LASTEXITCODE = 0
  & $Program @Arguments
  if ($LASTEXITCODE -ne 0) { throw "Check failed: $Program $($Arguments -join ' ')" }
}
Push-Location $repoRoot
try {
  foreach ($check in @('check_course.py','sync_catalog.py','sync_lesson_metadata.py','cost_estimate.py')) {
    $argsForCheck = @("tools/$check")
    if ($check -ne 'check_course.py') { $argsForCheck += '--check' }
    Invoke-Check $Python $argsForCheck
  }
  if ($DocsOnly) {
    Invoke-Check $Python @('tools/build_site.py')
    Invoke-Check $Python @('-m','mkdocs','build','--strict')
    Invoke-Check $Python @('tools/check_built_site.py')
    Write-Output 'PASS documentation checks only; Terraform/browser behavior checks were skipped.'
    return
  }
  Invoke-Check $Python @('tools/check_security.py')
  Invoke-Check $Python @('tools/check_offline_tests.py')
  $parseErrorsFound = @()
  Get-ChildItem labs,modules,scripts,tests -Recurse -File -Include *.ps1,*.psm1 |
    Where-Object { $_.FullName -notmatch '[\\/](\.terraform|node_modules)[\\/]' } | ForEach-Object {
      $tokens = $null; $parseErrors = $null
      [System.Management.Automation.Language.Parser]::ParseFile($_.FullName,[ref]$tokens,[ref]$parseErrors) | Out-Null
      $parseErrorsFound += $parseErrors
    }
  if ($parseErrorsFound.Count) { $parseErrorsFound | Format-List; throw 'PowerShell syntax errors.' }
  if (-not $SkipTests) {
    Invoke-Check $Python @('-m','unittest','discover','-s','tests','-v')
    Invoke-Check node @('--test','tools/test_progress.cjs')
    foreach ($test in @('tests/Test-LessonLocal.ps1','tests/Test-LessonEvidence.ps1','labs/TFA-040/tests/Test-InfrastructureBehavior.ps1')) {
      Invoke-Check pwsh @('-NoProfile','-File',$test)
    }
  }
  if ($WindowsOnly) {
    if ($SkipTests) { throw '-WindowsOnly requires behavior tests; remove -SkipTests.' }
    Write-Output 'PASS focused Windows/local behavior checks. Full Terraform/browser checks run in the Linux lane.'
    return
  }
  Invoke-Check terraform @('fmt','-check','-recursive')
  Invoke-Check tflint @('--recursive','--format','compact')
  Invoke-Check actionlint @('-shellcheck=')
  $terraformArgs = @('tools/check_terraform.py','--jobs',$Jobs.ToString())
  if ($SkipTests) { $terraformArgs += '--skip-tests' }
  Invoke-Check $Python $terraformArgs
  if (-not $SkipTests) { Invoke-Check $Python @('tools/test_capstone_mutations.py') }
  $configBefore = (Get-FileHash -LiteralPath mkdocs.yml -Algorithm SHA256).Hash
  Invoke-Check $Python @('tools/build_site.py')
  if ($configBefore -ne (Get-FileHash -LiteralPath mkdocs.yml -Algorithm SHA256).Hash) { throw 'Generated MkDocs config drifted; rebuild and review mkdocs.yml before committing.' }
  Invoke-Check $Python @('-m','mkdocs','build','--strict')
  Invoke-Check $Python @('tools/check_built_site.py')
  if (-not $SkipTests) { Invoke-Check node @('node_modules/@playwright/test/cli.js','test') }
  Write-Output "PASS selected local checks (SkipTests=$SkipTests). Azure runtime unverified; no Azure pass was run."
} finally { Pop-Location }