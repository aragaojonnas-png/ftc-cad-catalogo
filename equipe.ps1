# Funcoes da pasta compartilhada da equipe (pecas adicionadas por qualquer pessoa, sincronizadas pelo Google Drive).
# Usado por adicionar.ps1 e abrir.ps1. Cada peca = um .step + um .json com os dados, dentro de <pasta>\Pecas\<Tipo>\.

# nomes com acento exatamente como o catalogo usa
$script:TiposFtc = @(
 'Colares e acopladores','Correias e polias','Correntes e coroas','Cubos',
 ('Dobradi' + [char]0xE7 + 'as e molas'), 'Eixos e tubos', ('Eletr' + [char]0xF4 + 'nica'), 'Engrenagens',
 ('Espa' + [char]0xE7 + 'adores e arruelas'), 'Esteiras', 'Ferramentas', ('Guias, slides e articula' + [char]0xE7 + [char]0xF5 + 'es'),
 ('Motores e caixas de redu' + [char]0xE7 + [char]0xE3 + 'o'), 'Parafusos', ('Placas e pain' + [char]0xE9 + 'is'), 'Porcas',
 'Rodas e pneus', 'Rolamentos', 'Servos', 'Suportes e bases', 'Vigas e perfis', 'Outros')

function Get-ConfigPath($root) { Join-Path $root 'config.json' }

function Get-PastaEquipe($root) {
    $p = Get-ConfigPath $root
    if (Test-Path -LiteralPath $p) {
        try {
            $c = Get-Content -LiteralPath $p -Raw -Encoding UTF8 | ConvertFrom-Json
            if ($c.pastaEquipe -and (Test-Path -LiteralPath $c.pastaEquipe)) { return [string]$c.pastaEquipe }
        } catch {}
    }
    return $null
}

function Set-PastaEquipe($root, $pasta) {
    $obj = New-Object psobject -Property @{ pastaEquipe = $pasta }
    [IO.File]::WriteAllText((Get-ConfigPath $root), ($obj | ConvertTo-Json), (New-Object Text.UTF8Encoding($true)))
}

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
        if (-not (Test-Path -LiteralPath $p)) { [IO.File]::WriteAllBytes($p, [Convert]::FromBase64String($script:IconB64)) }
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
