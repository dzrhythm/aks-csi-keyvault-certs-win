
# NOTE: Earlier versions of the Secrets Provider for Azure mounted the
# certificate content as a base64-encoded text file.
# Newer versions of the driver now support the objectEncoding property
# which we can set so the driver decodes the file to binary for us.
#
# Base64 decode the mounted certificate to a PFX file
# $certFilePath = "$PSScriptRoot\locahost.decoded.pfx"
# Write-Host "Getting cert content from $($env:HTTPS_CERTIFICATE_PATH)"
# $content = Get-Content $env:HTTPS_CERTIFICATE_PATH -Raw
# Write-Host "Converting cert and writing to $certFilePath"
# [System.Convert]::FromBase64String($content) | Set-Content $certFilePath -Encoding Byte

# Import the PFX to the Windows certificate store
# Note that the mounted PFX certificate no longer has a password
# since we've already authenticated to Key Vault.
$certFilePath = $env:HTTPS_CERTIFICATE_PATH
Write-Host "Importing HTTPS certificate $certFilePath"
$cert = Import-PfxCertificate -FilePath $certFilePath -CertStoreLocation Cert:\LocalMachine\My

Write-Host "Creating HTTPS Binding"
New-WebBinding -Name "Default Web Site" -IP "*" -Port 443 -Protocol https

Write-Host "Binding Certificate to HTTPS Binding"
Set-Location IIS:\SslBindings
$cert | New-Item 0.0.0.0!443

Write-Host "Starting Service Monitor"
C:\\ServiceMonitor.exe w3svc
