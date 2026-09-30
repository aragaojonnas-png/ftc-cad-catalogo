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
    -SemAtalho       nao cria o atalho na area de trabalho
#>
param(
    [int]$MaxMB = 20,
    [switch]$IncluirFRC,
    [int]$Threads = 6,
    [switch]$SemAtalho
)

$ErrorActionPreference = 'Stop'
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
if ($nothing) { Write-Host 'Todos os arquivos ja estao na pasta.' }

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
                $ok++
            } catch {
                [void]$errs.Add(("{0} -> {1}" -f $it.d, $_.Exception.Message))
            }
        }
    } finally {
        if ([IO.File]::Exists($tmp)) { [IO.File]::Delete($tmp) }
    }
    return @{ ok = $ok; errs = @($errs) }
}

if (-not $nothing) {
# ---- executa em paralelo ----
$pool = [RunspaceFactory]::CreateRunspacePool(1, $Threads)
$pool.Open()
$jobs = New-Object System.Collections.ArrayList
foreach ($g in $groups) {
    $ps = [powershell]::Create()
    $ps.RunspacePool = $pool
    [void]$ps.AddScript($worker).AddArgument($g.Name).AddArgument(@($g.Group)).AddArgument($root)
    [void]$jobs.Add([pscustomobject]@{ ps = $ps; h = $ps.BeginInvoke(); fin = $false })
}

$total = $jobs.Count
$finished = 0; $created = 0
$failures = New-Object System.Collections.ArrayList
$start = Get-Date
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
        }
    }
    $pct = [int](100 * $finished / $total)
    Write-Progress -Activity 'Baixando modelos STEP' -Status ("{0}/{1} downloads | {2} arquivos criados | {3} falhas" -f $finished, $total, $created, $failures.Count) -PercentComplete $pct
    Start-Sleep -Milliseconds 500
}
$pool.Close()
Write-Progress -Activity 'Baixando modelos STEP' -Completed

}
if (-not $nothing) {
$mins = [math]::Round(((Get-Date) - $start).TotalMinutes, 1)
Write-Host ''
Write-Host ("Pronto em {0} min. Arquivos criados: {1} | falhas: {2}" -f $mins, $created, $failures.Count) -ForegroundColor Green
}
if ($failures.Count -gt 0) {
    $logPath = Join-Path $root 'falhas.txt'
    [IO.File]::WriteAllLines($logPath, [string[]]@($failures), (New-Object System.Text.UTF8Encoding($true)))
    Write-Host "Falhas listadas em: $logPath (rode o script de novo para tentar outra vez)" -ForegroundColor Yellow
}

# ---- atalho "Catalogo FTC_CAD" na area de trabalho (abre como aplicativo) ----
if (-not $SemAtalho) {
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
        $desk = [Environment]::GetFolderPath('Desktop')
        $lnk = Join-Path $desk 'Catalogo FTC_CAD.lnk'
        $sh = New-Object -ComObject WScript.Shell
        $sc = $sh.CreateShortcut($lnk)
        $abrir = Join-Path $root 'abrir.ps1'
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
        Write-Host "Atalho criado na area de trabalho: Catalogo FTC_CAD" -ForegroundColor Green
    } catch {
        Write-Host ("Nao consegui criar o atalho ({0}). Abra o catalogo.html direto da pasta." -f $_.Exception.Message) -ForegroundColor Yellow
    }
}
Write-Host ''
Write-Host "Biblioteca instalada em: $root" -ForegroundColor Cyan
