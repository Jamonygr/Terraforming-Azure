[CmdletBinding()]
param()
$ErrorActionPreference = 'Continue'
foreach ($uri in @('https://www.microsoft.com/', 'https://example.org/')) {
    Write-Output "Request destination: $uri"
    try {
        $response = Invoke-WebRequest -Uri $uri -UseBasicParsing -TimeoutSec 20 -MaximumRedirection 0
        Write-Output "Origin HTTP response: $([int]$response.StatusCode)"
    } catch {
        if ($_.Exception.Response) { Write-Output "HTTP error/redirect status: $([int]$_.Exception.Response.StatusCode)" }
        Write-Output "Details: $($_.Exception.Message)"
    }
}
