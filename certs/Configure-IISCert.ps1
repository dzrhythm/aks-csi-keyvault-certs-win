
Write-Host "Importing cert"
#$mypwd = ConvertTo-SecureString -String "abcdefghijklmnopqrstuvwxyz0123456789" -Force –AsPlainText
#$cert = Import-PfxCertificate -FilePath C:\certs\localhost.pfx -CertStoreLocation Cert:\LocalMachine\My -Password $mypwd
#$cert = Import-PfxCertificate -FilePath C:\mypfx.pfx -CertStoreLocation Cert:\CurrentUser\My -Password $mypwd

$decodedCertPath = "$PSScriptRoot\locahost.decoded.pfx"
$content = Get-Content "$PSScriptRoot\locahost.pfx.base64" -Raw
[System.Convert]::FromBase64String($content) | Set-Content $decodedCertPath -Encoding Byte
$cert = Import-PfxCertificate -FilePath $decodedCertPath -CertStoreLocation Cert:\LocalMachine\My

Write-Host "Creating HTTPS Binding"
New-WebBinding -Name "Default Web Site" -IP "*" -Port 443 -Protocol https

Write-Host "Binding Certificate to HTTPS Binding"
Set-Location IIS:\SslBindings
$cert | New-Item 0.0.0.0!443
