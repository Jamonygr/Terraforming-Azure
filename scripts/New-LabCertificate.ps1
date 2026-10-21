[CmdletBinding()]
param(
  [string]$OutputDirectory = './.secrets',
  [string]$DnsName = 'app.terraforming-azure.test',
  [securestring]$Password,
  [switch]$SetTerraformEnvironment
)
$ErrorActionPreference = 'Stop'
if (-not $IsWindows) { throw 'Generate the training PFX on Windows with the PKI module, or supply your own PFX.' }
if (-not $Password) { $Password = Read-Host 'Training PFX password (not printed or saved)' -AsSecureString }
New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null
$certificatePath = Join-Path (Resolve-Path -LiteralPath $OutputDirectory).Path 'lab.pfx'
$cert = New-SelfSignedCertificate -DnsName $DnsName -CertStoreLocation 'Cert:\CurrentUser\My' -KeyAlgorithm RSA -KeyLength 2048 -NotAfter (Get-Date).AddDays(30)
try {
  Export-PfxCertificate -Cert $cert -FilePath $certificatePath -Password $Password | Out-Null
} finally {
  Remove-Item -LiteralPath "Cert:\CurrentUser\My\$($cert.Thumbprint)" -Force
}
if ($SetTerraformEnvironment) {
  $env:TF_VAR_certificate_path = $certificatePath
  $env:TF_VAR_certificate_password = [System.Net.NetworkCredential]::new('', $Password).Password
}
Write-Output "Created training certificate: $certificatePath"
Write-Output "Hostname: $DnsName. Self-signed; use the lesson's explicit test-client trust instructions."
