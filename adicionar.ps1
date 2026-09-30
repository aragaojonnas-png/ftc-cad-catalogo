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
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[System.Windows.Forms.Application]::EnableVisualStyles()

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
$f.Text = 'Adicionar peca - FTC_CAD'; $f.ClientSize = New-Object Drawing.Size(560, 430)
$f.StartPosition = 'CenterScreen'; $f.FormBorderStyle = 'FixedDialog'; $f.MaximizeBox = $false
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

Add-Rotulo 'Link da pagina do produto (opcional)' 254
$txtLink = Add-Caixa 276 520

Add-Rotulo 'Foto da peca (opcional, .jpg ou .png)' 314
$txtFoto = Add-Caixa 336 400; $txtFoto.ReadOnly = $true
$btnFoto = New-Botao 'Procurar...' 430 335 110

$lblPasta = New-Object Windows.Forms.Label; $lblPasta.ForeColor = [Drawing.Color]::FromArgb(170, 160, 200)
$lblPasta.Text = 'Pasta da equipe: ' + $pasta; $lblPasta.SetBounds(20, 374, 520, 20); $f.Controls.Add($lblPasta)
$btnOk = New-Botao 'Adicionar' 300 392 120
$btnCancel = New-Botao 'Cancelar' 430 392 110
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
            fab = $cmbFab.Text.Trim(); tipo = $tipo; link = $txtLink.Text.Trim(); foto = $foto
            por = $env:USERNAME; data = (Get-Date -Format 'yyyy-MM-dd')
        }
        [IO.File]::WriteAllText(($dest + '.json'), ($meta | ConvertTo-Json), (New-Object Text.UTF8Encoding($true)))
        $feitas++
    }
    [void](Update-Extras $root)
    $msg = ("{0} peca(s) adicionada(s) em:`r`n{1}`r`n`r`nAperte F5 no catalogo para ver. O Google Drive envia para a equipe em alguns instantes." -f $feitas, $dirTipo)
    if ($puladas.Count -gt 0) { $msg += ("`r`n`r`nNao substituidas: " + ($puladas -join ', ')) }
    [void][System.Windows.Forms.MessageBox]::Show($msg, 'Adicionar peca', 'OK', 'Information')
    $f.Close()
})

[void]$f.ShowDialog()
