[CmdletBinding()]
param()
$ErrorActionPreference = 'Stop'
if ($PSVersionTable.PSVersion -lt [version]'7.4') { throw 'Use the supported PowerShell 7.4 or later baseline.' }
$root = Split-Path $PSScriptRoot -Parent
$temporaryRoot = [System.IO.Path]::GetFullPath([System.IO.Path]::GetTempPath())
$caseRoot = Join-Path $temporaryRoot ('tfa-local-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $caseRoot | Out-Null
$previousLocation = Get-Location
try {
    Copy-Item -LiteralPath (Join-Path $root 'labs/TFA-014/main.tf') -Destination $caseRoot
    Copy-Item -LiteralPath (Join-Path $root 'labs/TFA-014/versions.tf') -Destination $caseRoot
    Set-Location $caseRoot
    terraform init -backend=false -input=false | Out-Null
    if ($LASTEXITCODE -ne 0) { throw 'Local init failed.' }
    terraform apply -auto-approve -input=false | Out-Null
    if ($LASTEXITCODE -ne 0) { throw 'Local apply failed.' }
    $readme = Get-Content (Join-Path $root 'labs/TFA-014/README.md') -Raw
    $blocks = [regex]::Matches($readme, '(?ms)^```powershell\r?\n(.*?)^```')
    $line = @($blocks | ForEach-Object { $_.Groups[1].Value -split '\r?\n' } | Where-Object { $_ -like 'terraform state show *' })
    $expected = 'terraform state show ''terraform_data.service["web"]'''
    if (@($line).Count -ne 1 -or $line -cne $expected) { throw 'README keyed-address command changed; review its quoting before executing.' }
    # Only the exact allowlisted, local state-show command above can execute.
    $state = & ([scriptblock]::Create($line))
    if ($LASTEXITCODE -ne 0 -or ($state -join "`n") -notmatch 'terraform_data.service\["web"\]') { throw 'README native quoting did not retrieve the web instance.' }
    terraform plan -detailed-exitcode -input=false | Out-Null
    if ($LASTEXITCODE -ne 0) { throw 'Local repeat plan was not empty.' }
    terraform destroy -auto-approve -input=false | Out-Null
    if ($LASTEXITCODE -ne 0) { throw 'Local destroy failed.' }
    $remaining = @(terraform state list)
    if ($LASTEXITCODE -ne 0 -or $remaining.Count) { throw 'Local cleanup left managed resources.' }
    Write-Output 'PASS TFA-014: copied README state lookup, repeat plan and local cleanup.'
}
finally {
    Set-Location $previousLocation
    $resolved = [System.IO.Path]::GetFullPath($caseRoot)
    if ($resolved.StartsWith($temporaryRoot, [System.StringComparison]::OrdinalIgnoreCase) -and (Split-Path $resolved -Leaf) -match '^tfa-local-[a-f0-9]{32}$') {
        Remove-Item -LiteralPath $resolved -Recurse -Force
    }
}
