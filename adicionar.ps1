<#
  Adiciona pecas (.step) a pasta compartilhada da equipe (sincronizada pelo Google Drive).
  Abre pelo botao "+ Adicionar peca" do catalogo. Depois de adicionar, aperte F5 no catalogo.
#>
param([string]$Url = '')
$ErrorActionPreference = 'Stop'
$root = $PSScriptRoot
if (-not $root) { $root = (Get-Location).Path }
trap {
    try { Add-Type -AssemblyName System.Windows.Forms
          [void][System.Windows.Forms.MessageBox]::Show(("Erro ao adicionar a peca:`r`n`r`n" + $_.Exception.Message), 'Adicionar peca - FTC_CAD', 'OK', 'Error') } catch {}
    exit 1
}
. (Join-Path $root 'equipe.ps1')
Initialize-FtcUi

# ---- modo "remover" (botao "remover" do catalogo: ftccad://remover?arquivo=...) ----
$icoApp = Ensure-Icon $root
if ($Url -match '^ftccad://remover') {
    $arq = $null
    if ($Url -match '[?&]arquivo=([^&]+)') { $arq = [Uri]::UnescapeDataString($Matches[1]) }
    if (-not $arq) { exit 0 }
    try { $info = Get-InfoPeca $root $arq }
    catch {
        [void][System.Windows.Forms.MessageBox]::Show($_.Exception.Message, 'Remover peca - FTC_CAD', 'OK', 'Warning')
        exit 0
    }
    $txt = ("Remover a peca '{0}'?`r`n`r`nO arquivo vai para a Lixeira e some do catalogo de toda a equipe quando o Google Drive sincronizar." -f $info.nome)
    $r = [System.Windows.Forms.MessageBox]::Show($txt, 'Remover peca - FTC_CAD', 'YesNo', 'Warning', 'Button2')
    if ($r -eq 'Yes') {
        Remove-Peca $root $info
        [void][System.Windows.Forms.MessageBox]::Show('Peca removida. O catalogo se atualiza sozinho ao voltar para a janela dele (ou aperte F5).', 'Remover peca - FTC_CAD', 'OK', 'Information')
    }
    exit 0
}

# ---- modo "baixar" (clique numa peca ainda nao baixada: ftccad://baixar?arquivo=<pasta/nome>) ----
if ($Url -match '^ftccad://baixar') {
    $arq = $null
    if ($Url -match '[?&]arquivo=([^&]+)') { $arq = [Uri]::UnescapeDataString($Matches[1]) }
    if (-not $arq) { exit 0 }
    $it = Find-ItemManifesto $root $arq
    if (-not $it) { [void][System.Windows.Forms.MessageBox]::Show('Nao encontrei essa peca na lista do catalogo.', 'Baixar peca - FTC_CAD', 'OK', 'Warning'); exit 0 }
    $destino = Join-Path $root ($it.d -replace '/', '\')
    $nomePeca = [IO.Path]::GetFileNameWithoutExtension($destino)

    $bg = [Drawing.Color]::FromArgb(19, 14, 34); $fg = [Drawing.Color]::FromArgb(236, 230, 250)
    $w = New-Object Windows.Forms.Form
    Set-FtcScale $w
    $w.Text = 'Baixar peca - FTC_CAD'; $w.ClientSize = New-Object Drawing.Size(520, 160); $w.StartPosition = 'CenterScreen'
    $w.FormBorderStyle = 'FixedDialog'; $w.MaximizeBox = $false; $w.BackColor = $bg; $w.ForeColor = $fg
    $w.Font = New-Object Drawing.Font('Segoe UI', 10)
    try { if ($icoApp) { $w.Icon = New-Object Drawing.Icon($icoApp) } } catch {}
    $lN = New-Object Windows.Forms.Label; $lN.Text = $nomePeca; $lN.Font = New-Object Drawing.Font('Segoe UI Semibold', 11)
    $lN.ForeColor = [Drawing.Color]::FromArgb(182, 146, 246); $lN.AutoEllipsis = $true; $lN.SetBounds(20, 14, 480, 26)
    $lS = New-Object Windows.Forms.Label; $lS.Text = 'Conectando...'; $lS.SetBounds(20, 46, 480, 22)
    $bar = New-Object Windows.Forms.ProgressBar; $bar.SetBounds(20, 74, 480, 22); $bar.Minimum = 0; $bar.Maximum = 1000
    $bC = New-Object Windows.Forms.Button; $bC.Text = 'Cancelar'; $bC.SetBounds(380, 112, 120, 32); $bC.FlatStyle = 'Flat'
    $bC.BackColor = [Drawing.Color]::FromArgb(124, 58, 237); $bC.ForeColor = [Drawing.Color]::White; $bC.FlatAppearance.BorderSize = 0
    $w.Controls.AddRange(@($lN, $lS, $bar, $bC))
    $script:cancelou = $false
    $bC.Add_Click({ $script:cancelou = $true; $bC.Enabled = $false; $lS.Text = 'Cancelando...' })
    $w.Add_FormClosing({ $script:cancelou = $true })
    $w.Show(); [System.Windows.Forms.Application]::DoEvents()

    $ok = $false; $erro = $null; $tmp = Join-Path ([IO.Path]::GetTempPath()) ([Guid]::NewGuid().ToString() + '.bin')
    try {
        if ([IO.File]::Exists($destino) -and ([IO.FileInfo]$destino).Length -gt 0) {
            $ok = $true
        } else {
            $prog = {
                param($lido, $total)
                if ($total -gt 0) {
                    $bar.Value = [math]::Min(1000, [int](1000 * $lido / $total))
                    $lS.Text = ('Baixando... {0} de {1} MB' -f [math]::Round($lido / 1MB, 1), [math]::Round($total / 1MB, 1))
                } else { $lS.Text = ('Baixando... {0} MB' -f [math]::Round($lido / 1MB, 1)) }
                [System.Windows.Forms.Application]::DoEvents()
                return $script:cancelou
            }
            $fim = Receber-Arquivo $it.u $tmp $prog
            if ($fim) {
                $bar.Style = 'Marquee'; $lS.Text = 'Extraindo e conferindo o arquivo...'; [System.Windows.Forms.Application]::DoEvents()
                [void](Instalar-PecaBaixada $root $it $tmp)
                $ok = $true
            }
        }
    } catch { $erro = $_.Exception.Message }
    finally { if ([IO.File]::Exists($tmp)) { try { [IO.File]::Delete($tmp) } catch {} } }

    if ($ok) {
        try { Set-Clipboard -Value $destino } catch {}
        try { [void](Update-Baixadas $root) } catch {}
        $bar.Style = 'Blocks'; $bar.Value = 1000
        $lS.Text = 'Pronto! O caminho do arquivo foi copiado.'; $bC.Text = 'Fechar'; $bC.Enabled = $true
        $script:cancelou = $false
        $bC.Add_Click({ $w.Close() })
        [System.Windows.Forms.Application]::DoEvents()
        for ($t = 0; $t -lt 15 -and $w.Visible; $t++) { Start-Sleep -Milliseconds 100; [System.Windows.Forms.Application]::DoEvents() }
        if ($w.Visible) { $w.Close() }
    } else {
        $w.Hide()
        if ($erro) { [void][System.Windows.Forms.MessageBox]::Show(("Nao consegui baixar:`r`n`r`n" + $erro + "`r`n`r`nConfira a internet e tente de novo."), 'Baixar peca - FTC_CAD', 'OK', 'Error') }
        $w.Close()
    }
    exit 0
}

# ---- 1) pasta compartilhada (so na primeira vez) ----
$pasta = Get-PastaEquipe $root
if (-not $pasta) {
    [void][System.Windows.Forms.MessageBox]::Show("Escolha a pasta compartilhada da equipe.`r`n`r`nEla precisa ser uma pasta do seu computador que o Google Drive para computador sincroniza (por exemplo dentro de 'Meu Drive' ou 'Drives compartilhados'). Todos da equipe escolhem a mesma pasta do Drive.", 'Adicionar peca - FTC_CAD', 'OK', 'Information')
    $fb = New-Object Windows.Forms.FolderBrowserDialog
    $fb.Description = 'Pasta compartilhada da equipe (sincronizada pelo Google Drive)'
    if ($fb.ShowDialog() -ne 'OK') { exit 0 }
    $pasta = $fb.SelectedPath
    Set-PastaEquipe $root $pasta
}

# ---- 2) janela ----
$bg = [Drawing.Color]::FromArgb(19, 14, 34); $fg = [Drawing.Color]::FromArgb(236, 230, 250)
$campo = [Drawing.Color]::FromArgb(30, 22, 55)
$f = New-Object Windows.Forms.Form
Set-FtcScale $f
$f.Text = 'Adicionar peca - FTC_CAD'; $f.ClientSize = New-Object Drawing.Size(560, 492)
$f.StartPosition = 'CenterScreen'; $f.FormBorderStyle = 'FixedDialog'; $f.MaximizeBox = $false
try { if ($icoApp) { $f.Icon = New-Object Drawing.Icon($icoApp) } } catch {}
$f.BackColor = $bg; $f.ForeColor = $fg; $f.Font = New-Object Drawing.Font('Segoe UI', 10)

function Add-Rotulo($txt, $y) { $l = New-Object Windows.Forms.Label; $l.Text = $txt; $l.SetBounds(20, $y, 520, 20); $f.Controls.Add($l) }
function Add-Caixa($y, $w) { $t = New-Object Windows.Forms.TextBox; $t.SetBounds(20, $y, $w, 26); $t.BackColor = $campo; $t.ForeColor = $fg; $t.BorderStyle = 'FixedSingle'; $f.Controls.Add($t); return $t }
function New-Botao($txt, $x, $y, $w) { $b = New-Object Windows.Forms.Button; $b.Text = $txt; $b.SetBounds($x, $y, $w, 28); $b.FlatStyle = 'Flat'
    $b.BackColor = [Drawing.Color]::FromArgb(124, 58, 237); $b.ForeColor = [Drawing.Color]::White; $b.FlatAppearance.BorderSize = 0; $f.Controls.Add($b); return $b }

Add-Rotulo 'Arquivo(s) .step (pode escolher varios)' 14
$txtArq = Add-Caixa 36 400; $txtArq.ReadOnly = $true
$btnArq = New-Botao 'Procurar...' 430 35 110

Add-Rotulo 'Nome da peca (com varios arquivos, usa o nome de cada arquivo)' 74
$txtNome = Add-Caixa 96 520

Add-Rotulo 'Codigo (opcional, ex.: 2101-0006-0001)' 134
$txtCod = Add-Caixa 156 520

Add-Rotulo 'Fabricante' 194
$cmbFab = New-Object Windows.Forms.ComboBox; $cmbFab.SetBounds(20, 216, 250, 26); $cmbFab.DropDownStyle = 'DropDown'
$cmbFab.BackColor = $campo; $cmbFab.ForeColor = $fg; [void]$cmbFab.Items.AddRange(@('goBILDA', 'REV', 'AndyMark', 'Outro')); $cmbFab.Text = 'Outro'; $f.Controls.Add($cmbFab)
$l2 = New-Object Windows.Forms.Label; $l2.Text = 'Tipo de peca'; $l2.SetBounds(290, 194, 250, 20); $f.Controls.Add($l2)
$cmbTipo = New-Object Windows.Forms.ComboBox; $cmbTipo.SetBounds(290, 216, 250, 26); $cmbTipo.DropDownStyle = 'DropDownList'
$cmbTipo.BackColor = $campo; $cmbTipo.ForeColor = $fg; [void]$cmbTipo.Items.AddRange($script:TiposFtc); $cmbTipo.SelectedItem = 'Outros'; $f.Controls.Add($cmbTipo)

Add-Rotulo 'Grupo personalizado (opcional): aparece junto dos fabricantes e como etiqueta na peca' 254
$cmbGrupo = New-Object Windows.Forms.ComboBox; $cmbGrupo.SetBounds(20, 276, 520, 26); $cmbGrupo.DropDownStyle = 'DropDown'
$cmbGrupo.BackColor = $campo; $cmbGrupo.ForeColor = $fg
try { foreach ($g in (Get-Grupos $pasta)) { [void]$cmbGrupo.Items.Add($g) } } catch {}
$f.Controls.Add($cmbGrupo)

Add-Rotulo 'Link da pagina do produto (opcional)' 314
$txtLink = Add-Caixa 336 520

Add-Rotulo 'Foto da peca (opcional, .jpg ou .png)' 374
$txtFoto = Add-Caixa 396 400; $txtFoto.ReadOnly = $true
$btnFoto = New-Botao 'Procurar...' 430 395 110

$lblPasta = New-Object Windows.Forms.Label; $lblPasta.ForeColor = [Drawing.Color]::FromArgb(170, 160, 200)
$lblPasta.Text = 'Pasta da equipe: ' + $pasta; $lblPasta.SetBounds(20, 434, 520, 20); $f.Controls.Add($lblPasta)
$btnOk = New-Botao 'Adicionar' 300 456 120
$btnCancel = New-Botao 'Cancelar' 430 456 110
$btnCancel.BackColor = [Drawing.Color]::FromArgb(60, 48, 92)
$btnCancel.Add_Click({ $f.Close() })

$script:arquivos = @()
$btnArq.Add_Click({
    $d = New-Object Windows.Forms.OpenFileDialog
    $d.Filter = 'Modelos STEP (*.step;*.stp)|*.step;*.stp'; $d.Multiselect = $true
    if ($d.ShowDialog() -eq 'OK') {
        $script:arquivos = @($d.FileNames)
        if ($script:arquivos.Count -eq 1) {
            $txtArq.Text = $script:arquivos[0]
            if (-not $txtNome.Text) { $txtNome.Text = [IO.Path]::GetFileNameWithoutExtension($script:arquivos[0]) }
            $txtNome.Enabled = $true; $txtCod.Enabled = $true
        } else {
            $txtArq.Text = ('{0} arquivos selecionados' -f $script:arquivos.Count)
            $txtNome.Text = ''; $txtNome.Enabled = $false; $txtCod.Text = ''; $txtCod.Enabled = $false
        }
    }
})
$btnFoto.Add_Click({
    $d = New-Object Windows.Forms.OpenFileDialog
    $d.Filter = 'Imagens (*.jpg;*.jpeg;*.png)|*.jpg;*.jpeg;*.png'
    if ($d.ShowDialog() -eq 'OK') { $txtFoto.Text = $d.FileName }
})

$btnOk.Add_Click({
    if ($script:arquivos.Count -eq 0) { [void][System.Windows.Forms.MessageBox]::Show('Escolha pelo menos um arquivo .step.', 'Adicionar peca', 'OK', 'Warning'); return }
    if ($script:arquivos.Count -eq 1 -and -not $txtNome.Text.Trim()) { [void][System.Windows.Forms.MessageBox]::Show('Digite o nome da peca.', 'Adicionar peca', 'OK', 'Warning'); return }
    $tipo = [string]$cmbTipo.SelectedItem
    $dirTipo = Join-Path (Join-Path $pasta 'Pecas') $tipo
    [void][IO.Directory]::CreateDirectory($dirTipo)
    $feitas = 0; $puladas = New-Object System.Collections.ArrayList
    foreach ($arq in $script:arquivos) {
        $nomeArq = [IO.Path]::GetFileName($arq)
        if ($nomeArq -match '\.stp$') { $nomeArq = [IO.Path]::GetFileNameWithoutExtension($nomeArq) + '.step' }
        $dest = Join-Path $dirTipo $nomeArq
        if (Test-Path -LiteralPath $dest) {
            $r = [System.Windows.Forms.MessageBox]::Show(("Ja existe uma peca com o arquivo '{0}' nessa pasta. Substituir?" -f $nomeArq), 'Adicionar peca', 'YesNo', 'Question')
            if ($r -ne 'Yes') { [void]$puladas.Add($nomeArq); continue }
        }
        Copy-Item -LiteralPath $arq -Destination $dest -Force
        $foto = ''
        if ($txtFoto.Text -and (Test-Path -LiteralPath $txtFoto.Text) -and $script:arquivos.Count -eq 1) {
            $dirFotos = Join-Path (Join-Path $pasta 'Pecas') '_fotos'
            [void][IO.Directory]::CreateDirectory($dirFotos)
            $fn = [IO.Path]::GetFileNameWithoutExtension($nomeArq) + [IO.Path]::GetExtension($txtFoto.Text)
            Copy-Item -LiteralPath $txtFoto.Text -Destination (Join-Path $dirFotos $fn) -Force
            $foto = '_fotos\' + $fn
        }
        $nome = if ($script:arquivos.Count -eq 1) { $txtNome.Text.Trim() } else { [IO.Path]::GetFileNameWithoutExtension($nomeArq) }
        $meta = [ordered]@{
            nome = $nome; codigo = $(if ($script:arquivos.Count -eq 1) { $txtCod.Text.Trim() } else { '' })
            fab = $cmbFab.Text.Trim(); grupo = $cmbGrupo.Text.Trim(); tipo = $tipo; link = $txtLink.Text.Trim(); foto = $foto
            por = $env:USERNAME; data = (Get-Date -Format 'yyyy-MM-dd')
        }
        [IO.File]::WriteAllText(($dest + '.json'), ($meta | ConvertTo-Json), (New-Object Text.UTF8Encoding($true)))
        $feitas++
    }
    [void](Update-Extras $root)
    $msg = ("{0} peca(s) adicionada(s) em:`r`n{1}`r`n`r`nO catalogo se atualiza sozinho ao voltar para ele (ou aperte F5). O Google Drive envia para a equipe em alguns instantes." -f $feitas, $dirTipo)
    if ($puladas.Count -gt 0) { $msg += ("`r`n`r`nNao substituidas: " + ($puladas -join ', ')) }
    [void][System.Windows.Forms.MessageBox]::Show($msg, 'Adicionar peca', 'OK', 'Information')
    $f.Close()
})

[void]$f.ShowDialog()
