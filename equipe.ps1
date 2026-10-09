# Funcoes da pasta compartilhada da equipe (pecas adicionadas por qualquer pessoa, sincronizadas pelo Google Drive).
# Usado por adicionar.ps1 e abrir.ps1. Cada peca = um .step + um .json com os dados, dentro de <pasta>\Pecas\<Tipo>\.

# nomes com acento exatamente como o catalogo usa
$script:TiposFtc = @(
 'Colares e acopladores','Correias e polias','Correntes e coroas','Cubos',
 ('Dobradi' + [char]0xE7 + 'as e molas'), 'Eixos e tubos', ('Eletr' + [char]0xF4 + 'nica'), 'Engrenagens',
 ('Espa' + [char]0xE7 + 'adores e arruelas'), 'Esteiras', 'Ferramentas', ('Guias, slides e articula' + [char]0xE7 + [char]0xF5 + 'es'),
 ('Motores e caixas de redu' + [char]0xE7 + [char]0xE3 + 'o'), 'Parafusos', ('Placas e pain' + [char]0xE9 + 'is'), 'Porcas',
 'Rodas e pneus', 'Rolamentos', 'Servos', 'Suportes e bases', 'Vigas e perfis', 'Outros')

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

function Get-ConfigPath($root) { Join-Path $root 'config.json' }

function Get-Cfg($root) {
    $h = @{}
    $p = Get-ConfigPath $root
    if (Test-Path -LiteralPath $p) {
        try { $o = Get-Content -LiteralPath $p -Raw -Encoding UTF8 | ConvertFrom-Json
              foreach ($pr in $o.PSObject.Properties) { $h[$pr.Name] = $pr.Value } } catch {}
    }
    return $h
}

function Set-Cfg($root, $chave, $valor) {
    $h = Get-Cfg $root
    $h[$chave] = $valor
    $o = New-Object psobject
    foreach ($k in $h.Keys) { Add-Member -InputObject $o -NotePropertyName $k -NotePropertyValue $h[$k] }
    [IO.File]::WriteAllText((Get-ConfigPath $root), ($o | ConvertTo-Json), (New-Object Text.UTF8Encoding($true)))
}

function Get-PastaEquipe($root) {
    $c = Get-Cfg $root
    if ($c['pastaEquipe'] -and (Test-Path -LiteralPath $c['pastaEquipe'])) { return [string]$c['pastaEquipe'] }
    return $null
}

function Set-PastaEquipe($root, $pasta) { Set-Cfg $root 'pastaEquipe' $pasta }

# 'tudo' = o abrir.ps1 baixa pecas novas sozinho; qualquer outra coisa = so baixa quando voce clica na peca
function Get-Modo($root) { $c = Get-Cfg $root; if ($c['modo'] -eq 'tudo') { return 'tudo' } else { return 'demanda' } }

# ---- aparencia de aplicativo: lancador sem janela de terminal e icone proprio ----
$script:LauncherVbs = @'
' Abre um script do FTC_CAD sem mostrar janela de terminal.
' Uso: wscript ftc.vbs <script.ps1> [argumentos...]
Set sh = CreateObject("WScript.Shell")
Set fso = CreateObject("Scripting.FileSystemObject")
If WScript.Arguments.Count = 0 Then WScript.Quit
dir = fso.GetParentFolderName(WScript.ScriptFullName)
cmd = "powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File """ & dir & "\" & WScript.Arguments(0) & """"
For i = 1 To WScript.Arguments.Count - 1
  cmd = cmd & " """ & WScript.Arguments(i) & """"
Next
sh.Run cmd, 0, False
'@
$script:IconB64 = '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'

function Ensure-Launcher($root) {
    try {
        $p = Join-Path $root 'ftc.vbs'
        $txt = ($script:LauncherVbs -replace "`r?`n", "`r`n") + "`r`n"
        if (-not (Test-Path -LiteralPath $p) -or ([IO.File]::ReadAllText($p) -ne $txt)) { [IO.File]::WriteAllText($p, $txt, [Text.Encoding]::ASCII) }
        return $p
    } catch { return $null }
}

function Ensure-Icon($root) {
    try {
        $p = Join-Path $root 'ftc.ico'
        $bytes = [Convert]::FromBase64String($script:IconB64)
        $igual = $false
        if (Test-Path -LiteralPath $p) { try { $igual = ([Convert]::ToBase64String([IO.File]::ReadAllBytes($p)) -eq $script:IconB64) } catch {} }
        if (-not $igual) { [IO.File]::WriteAllBytes($p, $bytes) }
        return $p
    } catch { return $null }
}

# Cria/atualiza os atalhos "Catalogo FTC_CAD" (area de trabalho e menu Iniciar) para abrir sem terminal.
# Com -SoExistentes, so corrige os atalhos que ja existem.
function Set-FtcShortcuts($root, [switch]$SoExistentes) {
    $vbs = Ensure-Launcher $root
    if (-not $vbs -or -not (Test-Path -LiteralPath (Join-Path $root 'abrir.ps1'))) { return $false }
    $ico = Ensure-Icon $root
    $sh = New-Object -ComObject WScript.Shell
    $destinos = @(
        (Join-Path ([Environment]::GetFolderPath('Desktop')) 'Catalogo FTC_CAD.lnk'),
        (Join-Path ([Environment]::GetFolderPath('Programs')) 'Catalogo FTC_CAD.lnk')
    )
    foreach ($lnk in $destinos) {
        if ($SoExistentes -and -not (Test-Path -LiteralPath $lnk)) { continue }
        $sc = $sh.CreateShortcut($lnk)
        $sc.TargetPath = (Join-Path $env:SystemRoot 'System32\wscript.exe')
        $sc.Arguments = '"' + $vbs + '" abrir.ps1'
        if ($ico) { $sc.IconLocation = $ico + ',0' }
        $sc.Description = 'Catalogo de pecas FTC_CAD'
        $sc.WorkingDirectory = $root
        $sc.Save()
    }
    return $true
}

# Registra o endereco ftccad:// (so para o usuario atual, sem precisar de administrador)
# para os botoes "+ Adicionar peca" e "remover" do catalogo abrirem a janela certa.
function Register-FtcProtocol($root) {
    try {
        $script = Join-Path $root 'adicionar.ps1'
        if (-not (Test-Path -LiteralPath $script)) { return }
        $vbs = Ensure-Launcher $root
        if ($vbs) {
            $cmd = '"' + (Join-Path $env:SystemRoot 'System32\wscript.exe') + '" "' + $vbs + '" adicionar.ps1 "%1"'
        } else {
            $exe = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
            $cmd = '"' + $exe + '" -NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File "' + $script + '" "%1"'
        }
        $k = 'HKCU:\Software\Classes\ftccad'
        New-Item -Path $k -Force | Out-Null
        Set-ItemProperty -Path $k -Name '(default)' -Value 'URL:FTC CAD'
        Set-ItemProperty -Path $k -Name 'URL Protocol' -Value ''
        New-Item -Path ($k + '\shell\open\command') -Force | Out-Null
        Set-ItemProperty -Path ($k + '\shell\open\command') -Name '(default)' -Value $cmd
    } catch {}
}

# Remove uma peca adicionada pela equipe (o .step, o .json e a foto). Manda para a Lixeira.
# So aceita arquivos .step que estejam DENTRO da pasta da equipe e que tenham o .json de uma peca adicionada.
function Get-InfoPeca($root, $arquivo) {
    $pasta = Get-PastaEquipe $root
    if (-not $pasta) { throw 'A pasta da equipe nao esta configurada.' }
    $base = [IO.Path]::GetFullPath((Join-Path $pasta 'Pecas')).TrimEnd('\', '/')
    $full = [IO.Path]::GetFullPath($arquivo)
    $sep = [string][IO.Path]::DirectorySeparatorChar
    if (-not $full.StartsWith($base + $sep, [StringComparison]::OrdinalIgnoreCase)) { throw 'Esse arquivo nao esta na pasta da equipe.' }
    if (-not $full.EndsWith('.step', [StringComparison]::OrdinalIgnoreCase)) { throw 'Esse nao e um arquivo .step.' }
    $json = $full + '.json'
    if (-not (Test-Path -LiteralPath $json)) { throw 'Esse arquivo nao e uma peca adicionada pela equipe (nao tem o .json).' }
    $m = Get-Content -LiteralPath $json -Raw -Encoding UTF8 | ConvertFrom-Json
    $nome = [string]$m.nome; if (-not $nome) { $nome = [IO.Path]::GetFileNameWithoutExtension($full) }
    $foto = $null
    if ($m.foto) { $fp = Join-Path (Join-Path $pasta 'Pecas') ([string]$m.foto); if (Test-Path -LiteralPath $fp) { $foto = $fp } }
    return [pscustomobject]@{ nome = $nome; step = $full; json = $json; foto = $foto; existe = (Test-Path -LiteralPath $full) }
}

function Remove-ParaLixeira($p) {
    if (-not (Test-Path -LiteralPath $p)) { return }
    try {
        Add-Type -AssemblyName Microsoft.VisualBasic
        [Microsoft.VisualBasic.FileIO.FileSystem]::DeleteFile($p, 'OnlyErrorDialogs', 'SendToRecycleBin')
    } catch { Remove-Item -LiteralPath $p -Force }
}

function Remove-Peca($root, $info) {
    Remove-ParaLixeira $info.step
    Remove-ParaLixeira $info.json
    if ($info.foto) { Remove-ParaLixeira $info.foto }
    [void](Update-Extras $root)
}

# Le as pecas da pasta da equipe e gera extras.js ao lado do catalogo.
function Update-Extras($root) {
    $saida = Join-Path $root 'extras.js'
    $pasta = Get-PastaEquipe $root
    $lista = New-Object System.Collections.ArrayList
    if ($pasta) {
        $base = Join-Path $pasta 'Pecas'
        if (Test-Path -LiteralPath $base) {
            foreach ($j in Get-ChildItem -LiteralPath $base -Recurse -Filter '*.json' -ErrorAction SilentlyContinue) {
                try {
                    $m = Get-Content -LiteralPath $j.FullName -Raw -Encoding UTF8 | ConvertFrom-Json
                    $step = $j.FullName.Substring(0, $j.FullName.Length - 5)   # tira o ".json"
                    if (-not (Test-Path -LiteralPath $step)) { continue }
                    $tipo = [string]$m.tipo; if (-not $tipo) { $tipo = 'Outros' }
                    $fab = [string]$m.fab; if (-not $fab) { $fab = 'Outro' }
                    $grupo = ([string]$m.grupo).Trim()
                    $nome = [string]$m.nome; if (-not $nome) { $nome = [IO.Path]::GetFileNameWithoutExtension($step) }
                    if ($m.codigo) { $nome = ([string]$m.codigo) + ' - ' + $nome }
                    $foto = ''
                    if ($m.foto) {
                        $fp = Join-Path $base ([string]$m.foto)
                        if (Test-Path -LiteralPath $fp) {
                            $u = ''
                            try { $u = ([Uri]$fp).AbsoluteUri } catch {}
                            if (-not $u) {
                                $u = ($fp -replace '\\', '/') -replace ' ', '%20'
                                if ($u.StartsWith('/')) { $u = 'file://' + $u } else { $u = 'file:///' + $u }
                            }
                            $foto = $u
                        }
                    }
                    [void]$lista.Add([ordered]@{
                        n = $nome
                        p = 'Equipe/' + $tipo
                        s = [math]::Round((Get-Item -LiteralPath $step).Length / 1MB, 1)
                        i = $foto
                        t = ($nome + ' ' + $fab + ' ' + $grupo + ' equipe ' + [string]$m.por)
                        u = [string]$m.link
                        f = 0
                        m = $(if ($grupo) { $grupo } else { $fab })
                        gr = $grupo
                        v = $fab
                        g = $tipo
                        x = 1
                        b = [string]$m.por
                        a = $step
                    })
                } catch {}
            }
        }
    }
    $json = if ($lista.Count -gt 0) { ConvertTo-Json -InputObject @($lista.ToArray()) -Compress -Depth 4 } else { '[]' }
    [IO.File]::WriteAllText($saida, ('window.EXTRAS = ' + $json + ';'), (New-Object Text.UTF8Encoding($false)))
    return $lista.Count
}

# grupos personalizados ja usados (para sugerir na janela de adicionar)
function Get-Grupos($pasta) {
    $g = New-Object System.Collections.ArrayList
    $base = Join-Path $pasta 'Pecas'
    if (Test-Path -LiteralPath $base) {
        foreach ($j in Get-ChildItem -LiteralPath $base -Recurse -Filter '*.json' -ErrorAction SilentlyContinue) {
            try { $m = Get-Content -LiteralPath $j.FullName -Raw -Encoding UTF8 | ConvertFrom-Json
                  $x = ([string]$m.grupo).Trim(); if ($x -and -not $g.Contains($x)) { [void]$g.Add($x) } } catch {}
        }
    }
    return @($g | Sort-Object)
}

# ---- pecas baixadas no PC (para o catalogo mostrar "no PC" / "baixar") ----
function Update-Baixadas($root) {
    $saida = Join-Path $root 'baixadas.js'
    $raiz = ([IO.Path]::GetFullPath($root)).TrimEnd('\', '/')
    $lista = New-Object System.Collections.ArrayList
    foreach ($f in Get-ChildItem -LiteralPath $raiz -Recurse -File -ErrorAction SilentlyContinue) {
        if ($f.Extension -notmatch '^\.(step|stp)$') { continue }
        $rel = $f.FullName.Substring($raiz.Length + 1).Replace('\', '/')
        if ($rel.StartsWith('_KITS', [StringComparison]::OrdinalIgnoreCase)) { continue }
        [void]$lista.Add(($rel -replace '\.(step|stp)$', '').ToLowerInvariant())
    }
    $json = if ($lista.Count -gt 0) { ConvertTo-Json -InputObject @($lista.ToArray()) -Compress } else { '[]' }
    [IO.File]::WriteAllText($saida, ('window.BAIXADAS = ' + $json + ';'), (New-Object Text.UTF8Encoding($false)))
    return $lista.Count
}

# ---- baixa UMA peca (sob demanda). $aoProgresso recebe (bytesLidos, bytesTotal) e devolve $true para cancelar. ----
function Receber-Arquivo($url, $tmp, $aoProgresso) {
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    $req = [Net.HttpWebRequest]::Create($url)
    $req.UserAgent = 'Mozilla/5.0'; $req.Timeout = 30000; $req.ReadWriteTimeout = 30000
    $resp = $req.GetResponse()
    $entrada = $null; $saida = $null
    try {
        $len = $resp.ContentLength
        $entrada = $resp.GetResponseStream()
        $saida = [IO.File]::Create($tmp)
        $buf = New-Object byte[] 65536
        $tot = [int64]0
        while (($n = $entrada.Read($buf, 0, $buf.Length)) -gt 0) {
            $saida.Write($buf, 0, $n); $tot += $n
            if (& $aoProgresso $tot $len) { return $false }
        }
        return $true
    } finally {
        if ($saida) { $saida.Close() }
        if ($entrada) { $entrada.Close() }
        $resp.Close()
    }
}

# Extrai (se for ZIP, inclusive ZIP dentro de ZIP) e confere o cabecalho STEP. $item vem do manifesto.json (d, u, c).
function Instalar-PecaBaixada($root, $item, $tmp) {
    Add-Type -AssemblyName System.IO.Compression
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $final = Join-Path $root ($item.d -replace '/', '\')
    $dir = Split-Path -Parent $final
    if (-not [IO.Directory]::Exists($dir)) { [void][IO.Directory]::CreateDirectory($dir) }
    $parcial = $final + '.part'
    $chain = @($item.c | Where-Object { $_ })
    try {
        if ($chain.Count -eq 0) {
            [IO.File]::Copy($tmp, $parcial, $true)
        } else {
            $fileStream = [IO.File]::OpenRead($tmp)
            $zip = New-Object System.IO.Compression.ZipArchive($fileStream, [System.IO.Compression.ZipArchiveMode]::Read)
            for ($i = 0; $i -lt $chain.Count; $i++) {
                $name = ([string]$chain[$i]).Replace('\', '/')
                $entry = $null
                foreach ($en in $zip.Entries) { if ($en.FullName.Replace('\', '/') -eq $name) { $entry = $en; break } }
                if ($null -eq $entry) { throw "entrada nao achada no zip: $name" }
                if ($i -lt $chain.Count - 1) {
                    $ms = New-Object System.IO.MemoryStream
                    $es = $entry.Open(); $es.CopyTo($ms); $es.Close(); $ms.Position = 0
                    $zip = New-Object System.IO.Compression.ZipArchive($ms, [System.IO.Compression.ZipArchiveMode]::Read)
                } else {
                    $es = $entry.Open(); $fs = [IO.File]::Create($parcial)
                    $es.CopyTo($fs); $fs.Close(); $es.Close()
                }
            }
            $fileStream.Close()
        }
        $fs2 = [IO.File]::OpenRead($parcial); $b = New-Object byte[] 40; $n = $fs2.Read($b, 0, 40); $fs2.Close()
        if ([Text.Encoding]::ASCII.GetString($b, 0, $n) -notmatch 'ISO-10303') { throw 'o arquivo baixado nao e um STEP' }
        if ([IO.File]::Exists($final)) { [IO.File]::Delete($final) }
        [IO.File]::Move($parcial, $final)
    } finally {
        if ([IO.File]::Exists($parcial)) { try { [IO.File]::Delete($parcial) } catch {} }
    }
    return $final
}

function Find-ItemManifesto($root, $chave) {
    $lista = Get-Content -LiteralPath (Join-Path $root 'manifesto.json') -Raw -Encoding UTF8 | ConvertFrom-Json
    $k = $chave.ToLowerInvariant() -replace '\.(step|stp)$', ''
    foreach ($e in $lista) { if ((([string]$e.d).ToLowerInvariant() -replace '\.(step|stp)$', '') -eq $k) { return $e } }
    return $null
}
