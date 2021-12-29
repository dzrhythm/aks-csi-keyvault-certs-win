
Write-Host "Importing HTTPS Certificate"

# Base64 decode the mounted certificate to a PFX file
# $decodedCertPath = "$PSScriptRoot\locahost.decoded.pfx"
# Write-Host "Getting cert content from $($env:HTTPS_CERTIFICATE_PATH)"
# $content = Get-Content $env:HTTPS_CERTIFICATE_PATH -Raw
# Write-Host "Converting cert and writing to $decodedCertPath"
# [System.Convert]::FromBase64String($content) | Set-Content $decodedCertPath -Encoding Byte

# Import the PFX to the Windows certificate store
$decodedCertPath = $env:HTTPS_CERTIFICATE_PATH
Write-Host "Importing certificate $decodedCertPath"
$cert = Import-PfxCertificate -FilePath $decodedCertPath -CertStoreLocation Cert:\LocalMachine\My

Write-Host "Creating HTTPS Binding"
New-WebBinding -Name "Default Web Site" -IP "*" -Port 443 -Protocol https

Write-Host "Binding Certificate to HTTPS Binding"
Set-Location IIS:\SslBindings
$cert | New-Item 0.0.0.0!443

Write-Host "Starting Service Monitor"
C:\\ServiceMonitor.exe w3svc
