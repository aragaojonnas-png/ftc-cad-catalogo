# Adaptador: o catalogo agora e o aplicativo FTC_CAD.exe (sem PowerShell). Este arquivo so existe para instalacoes antigas.
$ErrorActionPreference = 'SilentlyContinue'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$root = $PSScriptRoot
$exe = Join-Path $root 'FTC_CAD.exe'
if (-not (Test-Path -LiteralPath $exe)) {
    (New-Object System.Net.WebClient).DownloadFile('https://raw.githubusercontent.com/aragaojonnas-png/ftc-cad-catalogo/main/FTC_CAD.exe', $exe)
}
Start-Process -FilePath $exe
