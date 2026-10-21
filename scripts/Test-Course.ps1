[CmdletBinding()]
param([switch]$DocsOnly, [switch]$SkipTests, [string]$Python = 'python', [ValidateRange(1,8)][int]$Jobs = 1)
$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path $PSScriptRoot -Parent
Push-Location $repoRoot
try {
  & $Python tools/check_course.py
  if ($LASTEXITCODE -ne 0) { throw 'Course documentation/assessment checks failed.' }
  if ($DocsOnly) { return }
  terraform fmt -check -recursive
  if ($LASTEXITCODE -ne 0) { throw 'Terraform formatting failed.' }
  $arguments = @('tools/check_terraform.py','--jobs',$Jobs.ToString())
  if ($SkipTests) { $arguments += '--skip-tests' }
  & $Python @arguments
  if ($LASTEXITCODE -ne 0) { throw 'Terraform validation/tests failed.' }
} finally { Pop-Location }
