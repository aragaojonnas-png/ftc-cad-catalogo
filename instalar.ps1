<#
  Instalador da biblioteca de modelos STEP (goBILDA, REV e AndyMark) - so pecas, sem kits e robos.
  Baixa tudo e organiza em pastas DENTRO da pasta onde este arquivo esta, e cria um atalho
  "Catalogo FTC_CAD" na area de trabalho que abre o catalogo como aplicativo
  e confere sozinho se ha versao nova (atualizacao automatica).
  Pode ser interrompido e rodado de novo: arquivos que ja existem sao pulados.

  Parametros:
    -MaxMB 20        ignora arquivos STEP maiores que 20 MB (use 0 para baixar TUDO)
    -IncluirFRC      inclui as pecas de FRC (REV ION e FIRST Robotics Competition)
    -Threads 6       downloads em paralelo
    -SemAtalho       nao cria os atalhos (area de trabalho e menu Iniciar)
    -SemJanela       usa o modo texto (console) em vez da janela
#>
param(
    [int]$MaxMB = 20,
    [switch]$IncluirFRC,
    [int]$Threads = 6,
    [switch]$SemAtalho,
    [switch]$SemJanela
)

$ErrorActionPreference = 'Stop'
trap {
    try {
        Add-Type -AssemblyName System.Windows.Forms
        [void][System.Windows.Forms.MessageBox]::Show(("O instalador encontrou um erro:`r`n`r`n" + $_.Exception.Message), 'Instalador FTC_CAD', 'OK', 'Error')
    } catch {}
    Write-Host $_.Exception.Message -ForegroundColor Red
    exit 1
}
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$root = $PSScriptRoot
if (-not $root) { $root = (Get-Location).Path }
$manifestPath = Join-Path $root 'manifesto.json'
if (-not (Test-Path -LiteralPath $manifestPath)) {
    Write-Host "manifesto.json nao encontrado em $root" -ForegroundColor Red
    exit 1
}

$all = Get-Content -LiteralPath $manifestPath -Raw -Encoding UTF8 | ConvertFrom-Json

# ---- filtra o que falta baixar ----
$limit = [int64]$MaxMB * 1048576
$todo = New-Object System.Collections.ArrayList
$skipExist = 0; $skipBig = 0; $skipFrc = 0
foreach ($e in $all) {
    if (-not $IncluirFRC) {
        if ($e.d.StartsWith('REV/ION') -or $e.d.Contains('Robotics Competition')) { $skipFrc++; continue }
    }
    if ($MaxMB -gt 0 -and $e.s -gt $limit) { $skipBig++; continue }
    $dest = Join-Path $root ($e.d -replace '/', '\')
    if ([IO.File]::Exists($dest) -and ([IO.FileInfo]$dest).Length -gt 0) { $skipExist++; continue }
    [void]$todo.Add($e)
}

$groups = @($todo | Group-Object -Property u)
$sumMB = [math]::Round((($todo | Measure-Object -Property s -Sum).Sum) / 1MB)
Write-Host ("Arquivos a criar: {0} (em {1} downloads, ~{2} MB depois de extraidos)" -f $todo.Count, $groups.Count, $sumMB)
Write-Host ("Ja existiam: {0} | acima de {1} MB (pulados): {2} | FRC (pulados): {3}" -f $skipExist, $MaxMB, $skipBig, $skipFrc)
$nothing = ($todo.Count -eq 0)

# ---- trabalho de cada download (roda em paralelo) ----
$worker = {
    param($url, $items, $root)
    Add-Type -AssemblyName System.IO.Compression
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $ok = 0
    $errs = New-Object System.Collections.ArrayList
    $tmp = Join-Path ([IO.Path]::GetTempPath()) ([Guid]::NewGuid().ToString() + '.bin')
    try {
        $done = $false
        for ($t = 1; $t -le 4 -and -not $done; $t++) {
            try {
                $wc = New-Object System.Net.WebClient
                $wc.Headers.Add('User-Agent', 'Mozilla/5.0')
                $wc.DownloadFile($url, $tmp)
                $done = $true
            } catch { Start-Sleep -Seconds (2 * $t) }
        }
        if (-not $done) {
            [void]$errs.Add("download falhou: $url")
            return @{ ok = 0; errs = @($errs) }
        }
        foreach ($it in $items) {
            $dest = Join-Path $root ($it.d -replace '/', '\')
            try {
                $dir = Split-Path -Parent $dest
                if (-not [IO.Directory]::Exists($dir)) { [void][IO.Directory]::CreateDirectory($dir) }
                $final = $dest
                $dest = $final + '.part'
                $chain = @($it.c)
                if ($chain.Count -eq 0) {
                    [IO.File]::Copy($tmp, $dest, $true)
                } else {
                    $fileStream = [IO.File]::OpenRead($tmp)
                    $zip = New-Object System.IO.Compression.ZipArchive($fileStream, [System.IO.Compression.ZipArchiveMode]::Read)
                    for ($i = 0; $i -lt $chain.Count; $i++) {
                        $name = ([string]$chain[$i]).Replace('\', '/')
                        $entry = $null
                        foreach ($en in $zip.Entries) {
                            if ($en.FullName.Replace('\', '/') -eq $name) { $entry = $en; break }
                        }
                        if ($null -eq $entry) { throw "entrada nao achada no zip: $name" }
                        if ($i -lt $chain.Count - 1) {
                            $ms = New-Object System.IO.MemoryStream
                            $es = $entry.Open(); $es.CopyTo($ms); $es.Close()
                            $ms.Position = 0
                            $zip = New-Object System.IO.Compression.ZipArchive($ms, [System.IO.Compression.ZipArchiveMode]::Read)
                        } else {
                            $es = $entry.Open()
                            $fs = [IO.File]::Create($dest)
                            $es.CopyTo($fs); $fs.Close(); $es.Close()
                        }
                    }
                    $fileStream.Close()
                }
                # confere se e mesmo um STEP (cabecalho ISO-10303)
                $fs2 = [IO.File]::OpenRead($dest)
                $buf = New-Object byte[] 40
                $n = $fs2.Read($buf, 0, 40); $fs2.Close()
                $head = [Text.Encoding]::ASCII.GetString($buf, 0, $n)
                if ($head -notmatch 'ISO-10303') {
                    [IO.File]::Delete($dest)
                    throw 'arquivo baixado nao e um STEP'
                }
                if ([IO.File]::Exists($final)) { [IO.File]::Delete($final) }
                [IO.File]::Move($dest, $final)
                $ok++
            } catch {
                if ($dest -and [IO.File]::Exists($dest) -and $dest.EndsWith('.part')) { try { [IO.File]::Delete($dest) } catch {} }
                [void]$errs.Add(("{0} -> {1}" -f $it.d, $_.Exception.Message))
            }
        }
    } finally {
        if ([IO.File]::Exists($tmp)) { [IO.File]::Delete($tmp) }
    }
    return @{ ok = $ok; errs = @($errs) }
}


# ---- janela (WinForms vem com o Windows, nada a instalar) ----
$gui = -not $SemJanela
$form = $null
if ($gui) {
    try {
        Add-Type -AssemblyName System.Windows.Forms
        Add-Type -AssemblyName System.Drawing
        [System.Windows.Forms.Application]::EnableVisualStyles()
        $bg = [Drawing.Color]::FromArgb(19, 14, 34)
        $fg = [Drawing.Color]::FromArgb(236, 230, 250)
        $form = New-Object Windows.Forms.Form
        $form.Text = 'Instalador FTC_CAD'
        $form.ClientSize = New-Object Drawing.Size(540, 230)
        $form.StartPosition = 'CenterScreen'
        $form.FormBorderStyle = 'FixedDialog'
        $form.MaximizeBox = $false
        $form.BackColor = $bg
        $form.ForeColor = $fg
        $form.Font = New-Object Drawing.Font('Segoe UI', 10)
        $lblTit = New-Object Windows.Forms.Label
        $lblTit.Text = 'Biblioteca de modelos STEP - FTC'
        $lblTit.Font = New-Object Drawing.Font('Segoe UI Semibold', 13)
        $lblTit.ForeColor = [Drawing.Color]::FromArgb(182, 146, 246)
        $lblTit.SetBounds(20, 14, 500, 28)
        $lblSt = New-Object Windows.Forms.Label
        $lblSt.Text = 'Preparando...'
        $lblSt.SetBounds(20, 52, 500, 24)
        $bar = New-Object Windows.Forms.ProgressBar
        $bar.SetBounds(20, 84, 500, 24)
        $bar.Minimum = 0; $bar.Maximum = 1000
        $lblDet = New-Object Windows.Forms.Label
        $lblDet.ForeColor = [Drawing.Color]::FromArgb(170, 160, 200)
        $lblDet.SetBounds(20, 116, 500, 44)
        $btn = New-Object Windows.Forms.Button
        $btn.Text = 'Cancelar'
        $btn.SetBounds(400, 180, 120, 34)
        $btn.FlatStyle = 'Flat'
        $btn.BackColor = [Drawing.Color]::FromArgb(124, 58, 237)
        $btn.ForeColor = [Drawing.Color]::White
        $btn.FlatAppearance.BorderSize = 0
        $form.Controls.AddRange(@($lblTit, $lblSt, $bar, $lblDet, $btn))
        $script:cancelado = $false
        $script:concluido = $false
        $btn.Add_Click({
            if ($script:concluido) { $form.Close() } else { $script:cancelado = $true; $btn.Enabled = $false; $lblSt.Text = 'Cancelando...' }
        })
        $form.Add_FormClosing({ if (-not $script:concluido) { $script:cancelado = $true } })
        $form.Show()
        [System.Windows.Forms.Application]::DoEvents()
    } catch { $gui = $false; $form = $null }
}
function Set-Ui($status, $detalhe, $pct) {
    if ($gui -and $form -and -not $form.IsDisposed) {
        $lblSt.Text = $status
        $lblDet.Text = $detalhe
        if ($pct -ge 0) { $bar.Value = [math]::Min(1000, [math]::Max(0, [int]($pct * 10))) }
        [System.Windows.Forms.Application]::DoEvents()
    }
}
function Show-Fim($texto, $icone) {
    if ($gui -and $form -and -not $form.IsDisposed) {
        $script:concluido = $true
        $btn.Enabled = $true; $btn.Text = 'Fechar'
        $lblSt.Text = $texto
        [System.Windows.Forms.Application]::DoEvents()
        $form.Hide()
        [void][System.Windows.Forms.MessageBox]::Show($texto, 'Instalador FTC_CAD', 'OK', $icone)
        $form.Close()
    }
}

$created = 0
$failures = New-Object System.Collections.ArrayList
$cancelou = $false
$start = Get-Date

if (-not $nothing) {
    $totalMB = [math]::Max(1, $sumMB)
    Set-Ui ("Baixando {0} arquivos (~{1} MB)" -f $todo.Count, $sumMB) 'Isto pode levar alguns minutos. Pode fechar e abrir de novo depois: o que ja foi baixado e mantido.' 0

    $pool = [RunspaceFactory]::CreateRunspacePool(1, $Threads)
    $pool.Open()
    $jobs = New-Object System.Collections.ArrayList
    foreach ($g in $groups) {
        $peso = [int64](($g.Group | Measure-Object -Property s -Sum).Sum)
        $ps = [powershell]::Create()
        $ps.RunspacePool = $pool
        [void]$ps.AddScript($worker).AddArgument($g.Name).AddArgument(@($g.Group)).AddArgument($root)
        [void]$jobs.Add([pscustomobject]@{ ps = $ps; h = $ps.BeginInvoke(); fin = $false; peso = $peso })
    }
    $total = $jobs.Count
    $pesoTotal = [double](($jobs | Measure-Object -Property peso -Sum).Sum)
    if ($pesoTotal -le 0) { $pesoTotal = 1 }
    $finished = 0; $pesoFeito = [double]0
    while ($finished -lt $total) {
        foreach ($j in $jobs) {
            if (-not $j.fin -and $j.h.IsCompleted) {
                try {
                    $r = @($j.ps.EndInvoke($j.h))[0]
                    if ($r) {
                        $created += [int]$r.ok
                        foreach ($m in @($r.errs)) { [void]$failures.Add($m) }
                    }
                } catch { [void]$failures.Add($_.Exception.Message) }
                $j.ps.Dispose()
                $j.fin = $true
                $finished++
                $pesoFeito += $j.peso
            }
        }
        $pct = 100 * $pesoFeito / $pesoTotal
        $feitoMB = [math]::Round($pesoFeito / 1MB)
        $st = ("Baixando... {0}%" -f [int]$pct)
        $det = ("{0} de {1} MB  |  {2} arquivos prontos  |  {3} falhas" -f $feitoMB, $sumMB, $created, $failures.Count)
        Set-Ui $st $det $pct
        if (-not $gui) { Write-Progress -Activity 'Baixando modelos STEP' -Status $det -PercentComplete ([int]$pct) }
        if ($script:cancelado) {
            $cancelou = $true
            foreach ($j in $jobs) { if (-not $j.fin) { try { $j.ps.Stop() } catch {} } }
            break
        }
        Start-Sleep -Milliseconds 300
    }
    try { $pool.Close() } catch {}
    if (-not $gui) { Write-Progress -Activity 'Baixando modelos STEP' -Completed }
    # limpa restos de arquivos parciais
    Get-ChildItem -LiteralPath $root -Recurse -Filter '*.part' -ErrorAction SilentlyContinue | ForEach-Object { try { $_.Delete() } catch {} }
    $mins = [math]::Round(((Get-Date) - $start).TotalMinutes, 1)
    Write-Host ("Terminou em {0} min. Arquivos criados: {1} | falhas: {2}" -f $mins, $created, $failures.Count)
}
if ($failures.Count -gt 0) {
    $logPath = Join-Path $root 'falhas.txt'
    [IO.File]::WriteAllLines($logPath, [string[]]@($failures), (New-Object System.Text.UTF8Encoding($true)))
    Write-Host "Falhas listadas em: $logPath" -ForegroundColor Yellow
}

# ---- botao "+ Adicionar peca" do catalogo (endereco ftccad://, so para este usuario) ----
try { $eq = Join-Path $root 'equipe.ps1'; if (Test-Path -LiteralPath $eq) { . $eq; Register-FtcProtocol $root; [void](Update-Extras $root) } } catch {}

# ---- atalhos: area de trabalho e menu Iniciar ----
$atalhoMsg = ''
if (-not $SemAtalho -and -not $cancelou) {
    try {
        $cat = Join-Path $root 'catalogo.html'
        if (-not (Test-Path -LiteralPath $cat)) { throw 'catalogo.html nao encontrado' }
        $uri = ([Uri]$cat).AbsoluteUri
        $cands = @(
            "${env:ProgramFiles(x86)}\Microsoft\Edge\Application\msedge.exe",
            "$env:ProgramFiles\Microsoft\Edge\Application\msedge.exe",
            "$env:ProgramFiles\Google\Chrome\Application\chrome.exe",
            "${env:ProgramFiles(x86)}\Google\Chrome\Application\chrome.exe",
            "$env:LOCALAPPDATA\Google\Chrome\Application\chrome.exe"
        )
        $browser = $cands | Where-Object { $_ -and (Test-Path -LiteralPath $_) } | Select-Object -First 1
        $abrir = Join-Path $root 'abrir.ps1'
        $sh = New-Object -ComObject WScript.Shell
        $destinos = @(
            (Join-Path ([Environment]::GetFolderPath('Desktop')) 'Catalogo FTC_CAD.lnk'),
            (Join-Path ([Environment]::GetFolderPath('Programs')) 'Catalogo FTC_CAD.lnk')
        )
        foreach ($lnk in $destinos) {
            $sc = $sh.CreateShortcut($lnk)
            if (Test-Path -LiteralPath $abrir) {
                $sc.TargetPath = (Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe')
                $sc.Arguments = '-NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File "' + $abrir + '"'
                if ($browser) { $sc.IconLocation = $browser + ',0' }
            } elseif ($browser) {
                $sc.TargetPath = $browser
                $sc.Arguments = '--app="' + $uri + '"'
                $sc.IconLocation = $browser + ',0'
            } else {
                $sc.TargetPath = $cat
            }
            $sc.WorkingDirectory = $root
            $sc.Save()
        }
        $atalhoMsg = "`r`n`r`nAtalho 'Catalogo FTC_CAD' criado na area de trabalho e no menu Iniciar."
    } catch {
        $atalhoMsg = "`r`n`r`nNao consegui criar os atalhos (" + $_.Exception.Message + "). Abra o catalogo.html direto da pasta."
    }
}

if ($cancelou) {
    Show-Fim ("Instalacao cancelada. {0} arquivos ja foram baixados.`r`nRode de novo quando quiser: o que ja esta na pasta e mantido." -f $created) 'Information'
} elseif ($failures.Count -gt 0) {
    Show-Fim ("Concluido com {0} falhas ({1} arquivos baixados).`r`nA lista esta em falhas.txt. Rode o instalador de novo para tentar outra vez.{2}" -f $failures.Count, $created, $atalhoMsg) 'Warning'
} elseif ($nothing) {
    Show-Fim ("Tudo certo: todas as pecas ja estao na pasta.$atalhoMsg") 'Information'
} else {
    Show-Fim ("Pronto! {0} arquivos baixados.$atalhoMsg`r`n`r`nPasta: {1}" -f $created, $root) 'Information'
}
Write-Host ''
Write-Host "Biblioteca instalada em: $root" -ForegroundColor Cyan
