# ftc-cad-catalogo

Catálogo visual e instalador da biblioteca de modelos STEP para FTC (goBILDA, REV e AndyMark), só peças.

Este repositório contém apenas o catálogo (`catalogo.html`), a lista de peças (`manifesto.json`) e os scripts.
Os modelos STEP **não** estão aqui: o instalador baixa cada um direto do site do fabricante.

- `Instalar.bat` / `Instalar-tudo.bat`: baixam e organizam a biblioteca e criam o atalho "Catalogo FTC_CAD".
- `abrir.ps1`: usado pelo atalho; confere `versao.txt` e atualiza o catálogo sozinho antes de abrir.
