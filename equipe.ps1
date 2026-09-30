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

# Registra o endereco ftccad:// (so para o usuario atual, sem precisar de administrador)
# para o botao "+ Adicionar peca" do catalogo abrir a janela de adicionar.
function Register-FtcProtocol($root) {
    try {
        $script = Join-Path $root 'adicionar.ps1'
        if (-not (Test-Path -LiteralPath $script)) { return }
        $exe = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
        $cmd = '"' + $exe + '" -NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File "' + $script + '" "%1"'
        $k = 'HKCU:\Software\Classes\ftccad'
        New-Item -Path $k -Force | Out-Null
        Set-ItemProperty -Path $k -Name '(default)' -Value 'URL:FTC CAD'
        Set-ItemProperty -Path $k -Name 'URL Protocol' -Value ''
        New-Item -Path ($k + '\shell\open\command') -Force | Out-Null
        Set-ItemProperty -Path ($k + '\shell\open\command') -Name '(default)' -Value $cmd
    } catch {}
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
                        t = ($nome + ' ' + $fab + ' equipe ' + [string]$m.por)
                        u = [string]$m.link
                        f = 0
                        m = $fab
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
