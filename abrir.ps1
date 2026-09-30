<#
  Abre o Catalogo FTC_CAD como aplicativo. Antes de abrir, confere se ha versao nova
  (catalogo, lista de pecas e instalador) no repositorio e atualiza sozinho.
  Se a atualizacao trouxer pecas novas, abre a janela do instalador para baixa-las.
  Sem internet, ele apenas abre a versao que ja esta na pasta.
#>
$ErrorActionPreference = 'SilentlyContinue'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$root = $PSScriptRoot
$base = 'https://raw.githubusercontent.com/aragaojonnas-png/ftc-cad-catalogo/main/'
$verFile = Join-Path $root 'versao.txt'
$log = Join-Path $root 'atualizacao.log'

function Get-Text($url) {
    $wc = New-Object System.Net.WebClient
    $wc.Headers.Add('User-Agent', 'Mozilla/5.0')
    $wc.Encoding = [Text.Encoding]::UTF8
    return $wc.DownloadString($url + '?t=' + [Guid]::NewGuid().ToString('N'))
}
function Get-File($url, $dest) {
    $tmp = $dest + '.novo'
    $wc = New-Object System.Net.WebClient
    $wc.Headers.Add('User-Agent', 'Mozilla/5.0')
    $wc.DownloadFile($url + '?t=' + [Guid]::NewGuid().ToString('N'), $tmp)
    if ((Get-Item -LiteralPath $tmp).Length -lt 100) { Remove-Item -LiteralPath $tmp; throw 'arquivo invalido' }
    Move-Item -LiteralPath $tmp -Destination $dest -Force
}

$novas = 0
try {
    $remoto = (Get-Text ($base + 'versao.txt')).Trim()
    $local = ''
    if (Test-Path -LiteralPath $verFile) { $local = (Get-Content -LiteralPath $verFile -Raw).Trim() }
    if ($remoto -and $remoto -ne $local) {
        foreach ($f in 'catalogo.html', 'manifesto.json', 'instalar.ps1') { Get-File ($base + $f) (Join-Path $root $f) }
        [IO.File]::WriteAllText($verFile, $remoto)
        Add-Content -LiteralPath $log -Value ("{0}  atualizado para {1}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm'), $remoto)
        # pecas novas (respeita o limite de 20 MB e ignora FRC, como o instalador)
        $lista = Get-Content -LiteralPath (Join-Path $root 'manifesto.json') -Raw -Encoding UTF8 | ConvertFrom-Json
        foreach ($e in $lista) {
            if ($e.d.StartsWith('REV/ION') -or $e.d.Contains('Robotics Competition')) { continue }
            if ($e.s -gt 20MB) { continue }
            if (-not [IO.File]::Exists((Join-Path $root ($e.d -replace '/', '\')))) { $novas++ }
        }
    }
} catch {
    Add-Content -LiteralPath $log -Value ("{0}  sem atualizacao ({1})" -f (Get-Date -Format 'yyyy-MM-dd HH:mm'), $_.Exception.Message)
}

if ($novas -gt 0) {
    $argsInst = @('-NoProfile', '-WindowStyle', 'Hidden', '-ExecutionPolicy', 'Bypass', '-File', ('"' + (Join-Path $root 'instalar.ps1') + '"'), '-SemAtalho')
    Start-Process powershell -ArgumentList $argsInst
}

# ---- abre o catalogo como aplicativo ----
$cat = Join-Path $root 'catalogo.html'
$uri = ([Uri]$cat).AbsoluteUri
$cands = @(
    "${env:ProgramFiles(x86)}\Microsoft\Edge\Application\msedge.exe",
    "$env:ProgramFiles\Microsoft\Edge\Application\msedge.exe",
    "$env:ProgramFiles\Google\Chrome\Application\chrome.exe",
    "${env:ProgramFiles(x86)}\Google\Chrome\Application\chrome.exe",
    "$env:LOCALAPPDATA\Google\Chrome\Application\chrome.exe"
)
$browser = $cands | Where-Object { $_ -and (Test-Path -LiteralPath $_) } | Select-Object -First 1
if ($browser) { Start-Process -FilePath $browser -ArgumentList ('--app="' + $uri + '"') }
else { Start-Process -FilePath $cat }
