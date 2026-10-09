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

# --- aparencia de app: janelas nitidas em telas com escala (DPI), identidade propria na barra de tarefas ---
function Initialize-FtcUi {
    try {
        Add-Type -AssemblyName System.Windows.Forms
        Add-Type -AssemblyName System.Drawing
        Add-Type -Namespace Ftc -Name Nat -MemberDefinition '[DllImport("user32.dll")] public static extern bool SetProcessDPIAware(); [DllImport("shell32.dll", CharSet=CharSet.Unicode)] public static extern int SetCurrentProcessExplicitAppUserModelID(string id);'
        [void][Ftc.Nat]::SetProcessDPIAware()
        [void][Ftc.Nat]::SetCurrentProcessExplicitAppUserModelID('FTC.CAD.Catalogo')
    } catch {}
    try { [System.Windows.Forms.Application]::EnableVisualStyles() } catch {}
    try { [System.Windows.Forms.Application]::SetCompatibleTextRenderingDefault($false) } catch {}
}
function Set-FtcScale($form) {
    try { $form.AutoScaleDimensions = New-Object Drawing.SizeF(96, 96); $form.AutoScaleMode = 'Dpi' } catch {}
}

# janelinha "Atualizando..." (so aparece quando ha versao nova)
$script:splash = $null
function Show-Splash($texto) {
    try {
        Initialize-FtcUi
        $f = New-Object Windows.Forms.Form
        Set-FtcScale $f
        $f.FormBorderStyle = 'None'; $f.StartPosition = 'CenterScreen'; $f.ClientSize = New-Object Drawing.Size(360, 96)
        $f.BackColor = [Drawing.Color]::FromArgb(30, 22, 55); $f.ForeColor = [Drawing.Color]::FromArgb(236, 230, 250)
        $f.TopMost = $true; $f.ShowInTaskbar = $false
        $l = New-Object Windows.Forms.Label; $l.Text = 'Catalogo FTC_CAD'; $l.Font = New-Object Drawing.Font('Segoe UI Semibold', 12)
        $l.ForeColor = [Drawing.Color]::FromArgb(182, 146, 246); $l.SetBounds(20, 14, 320, 26)
        $t = New-Object Windows.Forms.Label; $t.Text = $texto; $t.Font = New-Object Drawing.Font('Segoe UI', 10); $t.SetBounds(20, 44, 320, 22)
        $b = New-Object Windows.Forms.ProgressBar; $b.Style = 'Marquee'; $b.MarqueeAnimationSpeed = 30; $b.SetBounds(20, 72, 320, 8)
        $f.Controls.AddRange(@($l, $t, $b)); $f.Show(); [System.Windows.Forms.Application]::DoEvents()
        $script:splash = $f
    } catch {}
}
function Close-Splash { try { if ($script:splash) { $script:splash.Close(); $script:splash.Dispose(); $script:splash = $null } } catch {} }

$novas = 0
try {
    $remoto = (Get-Text ($base + 'versao.txt')).Trim()
    $local = ''
    if (Test-Path -LiteralPath $verFile) { $local = (Get-Content -LiteralPath $verFile -Raw).Trim() }
    if ($remoto -and $remoto -ne $local) {
        Show-Splash 'Atualizando o catalogo...'
        foreach ($f in 'catalogo.html', 'manifesto.json', 'instalar.ps1', 'equipe.ps1', 'adicionar.ps1') { Get-File ($base + $f) (Join-Path $root $f) }
        Get-File ($base + 'abrir.ps1') ($PSCommandPath + '.novo')   # troca no fim desta execucao
        [IO.File]::WriteAllText($verFile, $remoto)
        Add-Content -LiteralPath $log -Value ("{0}  atualizado para {1}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm'), $remoto)
        # so no modo "tudo" (instalado com Instalar-tudo): baixa as pecas novas sozinho. No modo normal, cada peca e baixada quando voce clica nela.
        $modo = ''
        try { $modo = [string](Get-Content -LiteralPath (Join-Path $root 'config.json') -Raw -Encoding UTF8 | ConvertFrom-Json).modo } catch {}
        if ($modo -eq 'tudo') {
            $lista = Get-Content -LiteralPath (Join-Path $root 'manifesto.json') -Raw -Encoding UTF8 | ConvertFrom-Json
            foreach ($e in $lista) {
                if ($e.d.StartsWith('REV/ION') -or $e.d.Contains('Robotics Competition')) { continue }
                if ($e.s -gt 20MB) { continue }
                if (-not [IO.File]::Exists((Join-Path $root ($e.d -replace '/', '\')))) { $novas++ }
            }

        }
    }
} catch {
    Add-Content -LiteralPath $log -Value ("{0}  sem atualizacao ({1})" -f (Get-Date -Format 'yyyy-MM-dd HH:mm'), $_.Exception.Message)
}

Close-Splash
if ($novas -gt 0) {
    $argsInst = @('-NoProfile', '-WindowStyle', 'Hidden', '-ExecutionPolicy', 'Bypass', '-File', ('"' + (Join-Path $root 'instalar.ps1') + '"'), '-SemAtalho')
    $vbs = Join-Path $root 'ftc.vbs'
    if (Test-Path -LiteralPath $vbs) { Start-Process -FilePath (Join-Path $env:SystemRoot 'System32\wscript.exe') -ArgumentList @(('"' + $vbs + '"'), 'instalar.ps1', '-SemAtalho') }
    else { Start-Process powershell -ArgumentList $argsInst }
}

# ---- pecas da equipe (pasta compartilhada): registra o botao do catalogo e atualiza a lista ----
try {
    $eq = Join-Path $root 'equipe.ps1'
    if (Test-Path -LiteralPath $eq) { . $eq; Register-FtcProtocol $root; [void](Update-Extras $root); [void](Update-Baixadas $root); [void](Set-FtcShortcuts $root -SoExistentes) }
} catch {
    Add-Content -LiteralPath $log -Value ("{0}  equipe: {1}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm'), $_.Exception.Message)
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

# troca este script pela versao nova baixada (vale na proxima abertura)
try { if ($PSCommandPath -and (Test-Path -LiteralPath ($PSCommandPath + '.novo'))) { Move-Item -LiteralPath ($PSCommandPath + '.novo') -Destination $PSCommandPath -Force } } catch {}
