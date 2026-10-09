# Adaptador: encaminha os botoes do catalogo para o aplicativo FTC_CAD.exe (instalacoes antigas).
param([string]$Url = '')
$exe = Join-Path $PSScriptRoot 'FTC_CAD.exe'
if (Test-Path -LiteralPath $exe) { Start-Process -FilePath $exe -ArgumentList ('"' + $Url + '"') }
