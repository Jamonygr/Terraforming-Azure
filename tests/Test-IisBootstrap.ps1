[CmdletBinding()]
param()
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$temporaryRoot = [IO.Path]::GetFullPath([IO.Path]::GetTempPath())
$directory = Join-Path $temporaryRoot ('tfa-iis-' + [guid]::NewGuid().ToString('N'))
$fixtureState = @{ feature_success=$true; restart='No'; status=200; content='Terraforming Azure TFA-010'; feature_calls=0; service_calls=0; web_calls=0 }
# These local functions shadow Windows/HTTP commands only within this test scope.
# No feature is installed, no service is started, and no network request is made.
function Install-WindowsFeature {
    [CmdletBinding()]param([string]$Name,[switch]$IncludeManagementTools)
    if ($Name -cne 'Web-Server' -or -not $IncludeManagementTools) { throw 'Unexpected feature request.' }
    $fixtureState.feature_calls++
    [pscustomobject]@{ Success=$fixtureState.feature_success; RestartNeeded=$fixtureState.restart }
}
function Start-Service {
    [CmdletBinding()]param([string]$Name)
    if ($Name -cne 'W3SVC') { throw 'Unexpected service request.' }
    $fixtureState.service_calls++
}
function Invoke-WebRequest {
    [CmdletBinding()]param([uri]$Uri,[switch]$UseBasicParsing,[int]$TimeoutSec)
    if ($Uri.AbsoluteUri -cne 'http://localhost/Default.htm' -or $TimeoutSec -ne 20) { throw 'Unexpected bootstrap verification target.' }
    $fixtureState.web_calls++
    [pscustomobject]@{StatusCode=$fixtureState.status;Content=$fixtureState.content}
}
New-Item -ItemType Directory -Path $directory | Out-Null
try {
    $bootstrap = Join-Path $root 'labs/TFA-010/Bootstrap-Iis.ps1'
    $webRoot = Join-Path $directory 'wwwroot'
    $fixtureState.feature_success=$false
    $rejected=$false
    try { & $bootstrap -WebRoot $webRoot | Out-Null } catch { $rejected=$_.Exception.Message -like '*feature installation reported failure*' }
    if (-not $rejected -or $fixtureState.feature_calls -ne 1 -or $fixtureState.service_calls -ne 0 -or $fixtureState.web_calls -ne 0 -or (Test-Path -LiteralPath $webRoot)) { throw 'An unsuccessful feature install did not stop before service/page/HTTP operations.' }
    $fixtureState.feature_success=$true
    $fixtureState.restart='Yes'
    $rejected=$false
    try { & $bootstrap -WebRoot $webRoot | Out-Null } catch { $rejected=$_.Exception.Message -like '*requires a restart*' }
    if (-not $rejected -or (Test-Path -LiteralPath $webRoot)) { throw 'A required restart was silently treated as a finished deployment.' }
    $fixtureState.restart='No'
    & $bootstrap -WebRoot $webRoot | Out-Null
    & $bootstrap -WebRoot $webRoot | Out-Null
    if ((Get-Content -LiteralPath (Join-Path $webRoot 'Default.htm') -Raw).Trim() -cne $fixtureState.content) { throw 'The actual bootstrap did not write the expected page idempotently.' }
    if ($fixtureState.service_calls -ne 2 -or $fixtureState.web_calls -ne 2) { throw 'A successful feature install skipped service or HTTP verification.' }
    foreach ($case in @(@{status=503;content='Terraforming Azure TFA-010'},@{status=200;content='An unrelated page'})) {
        $fixtureState.status=$case.status; $fixtureState.content=$case.content
        $rejected=$false
        try { & $bootstrap -WebRoot $webRoot | Out-Null } catch { $rejected=$_.Exception.Message -like '*did not return HTTP 200 with the expected training page*' }
        if (-not $rejected) { throw 'Bad HTTP status or wrong page body was accepted as successful IIS deployment.' }
    }
}
finally {
    $resolved = [IO.Path]::GetFullPath($directory)
    if ($resolved.StartsWith($temporaryRoot,[StringComparison]::OrdinalIgnoreCase) -and (Split-Path $resolved -Leaf) -match '^tfa-iis-[a-f0-9]{32}$') { Remove-Item -LiteralPath $resolved -Recurse -Force }
}
Write-Output 'PASS actual IIS bootstrap under stubs: unsuccessful install/restart stop; success/repeat writes one page; wrong status/body fail. No Windows features, services or HTTP were invoked.'
