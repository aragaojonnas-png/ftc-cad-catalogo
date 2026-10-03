# ftc-cad-catalogo

Catálogo visual e instalador da biblioteca de modelos STEP para FTC (goBILDA, REV e AndyMark), só peças.

Este repositório contém apenas o catálogo (`catalogo.html`), a lista de peças (`manifesto.json`) e os scripts.
Os modelos STEP **não** estão aqui: o instalador baixa cada um direto do site do fabricante.

- `Instalar.bat`: instala só o catálogo; cada peça é baixada quando você clica nela. `Instalar-tudo.bat`: baixa e organiza a biblioteca inteira e abrem a janela do instalador (progresso, cancelar) e criam o atalho "Catalogo FTC_CAD" na área de trabalho e no menu Iniciar.
- `abrir.ps1`: usado pelo atalho; confere `versao.txt` e atualiza o catálogo sozinho antes de abrir.

## Peças da equipe

O botão **+ Adicionar peça** do catálogo abre `adicionar.ps1`, que copia um `.step` (e um `.json` com nome, tipo, fabricante, link e foto) para uma pasta compartilhada sincronizada pelo Google Drive. `equipe.ps1` lê essa pasta e gera o `extras.js` que o catálogo carrega.

Para parecer um aplicativo, os atalhos e botões abrem os scripts pelo `ftc.vbs` (sem janela de terminal) e usam o ícone `ftc.ico`. O botão **remover** (só nas peças da equipe) abre `adicionar.ps1` em modo remover: pede confirmação, só aceita arquivos dentro da pasta da equipe que tenham o `.json` da peça, e manda tudo para a Lixeira.


## Download sob demanda

No modo normal, clicar numa peça que ainda não está no PC abre `ftccad://baixar?...` (tratado por `adicionar.ps1`): baixa só aquele arquivo, mostra o progresso, copia o caminho e atualiza `baixadas.js`, que o catálogo usa para marcar "no PC" / "baixar".
