# FTC_CAD - guia para o Claude Code

Catalogo de pecas STEP (goBILDA, REV, AndyMark) para FTC. Usuario: Jonnas (Aracaju, escreve em portugues, digita no celular: interprete com tolerancia).
Preferencias dele: resposta objetiva e proporcional, perguntar quando houver duvida (pedir print em vez de chutar visual), pesquisar antes de afirmar, nao acrescentar extras nao pedidos, admitir erros.

## Como funciona
- `FTC_CAD.exe` (codigo: `src/FtcCad.cs`, C# 5, .NET Framework 4.5+, WinForms, sem dependencias): abre o catalogo (`catalogo.html`) como app no Edge/Chrome (`--app`), atualiza sozinho, baixa pecas sob demanda, gerencia pecas da equipe.
- Modos: sem argumento = abrir (na 1a vez mostra o instalador); `--instalar`; `ftccad://baixar?arquivo=<pasta/nome>`, `ftccad://remover?arquivo=<caminho>`, `ftccad://adicionar` (o catalogo chama esses enderecos; o app os registra em HKCU\Software\Classes\ftccad).
- Arquivos que o app le/gera ao lado do .exe (pasta do usuario): `catalogo.html`, `manifesto.json` (d=destino, u=url, c=cadeia de entradas zip, s=tamanho), `versao.txt`, `config.json` (pastaEquipe, modo=tudo|demanda), `extras.js` (pecas da equipe), `baixadas.js` (pecas ja baixadas).
- Pecas da equipe: pasta do Google Drive `Pecas\<Tipo>\arquivo.step` + `arquivo.step.json`; fotos em `Pecas\_fotos`.

## Atualizacao automatica (IMPORTANTE)
O app compara `versao.txt` local com `https://raw.githubusercontent.com/aragaojonnas-png/ftc-cad-catalogo/main/versao.txt`. Se diferir, baixa `catalogo.html`, `manifesto.json` e `FTC_CAD.exe` (como `.novo`, trocado na proxima abertura).
Por isso, **a raiz do repositorio precisa manter `FTC_CAD.exe`, `catalogo.html`, `manifesto.json` e `versao.txt`**, e **toda mudanca publicada exige aumentar `versao.txt`** (formato `AAAA.MM.DD.N`).
`abrir.ps1`, `adicionar.ps1`, `equipe.ps1`, `instalar.ps1` na raiz sao so adaptadores/stubs de instalacoes antigas (PowerShell); podem sair quando ninguem mais usar a versao antiga.

## Fluxo de release
1. Editar `src/FtcCad.cs` -> `./build.sh` (Mono: `apt install mono-mcs`; compila com `mcs`, roda no Windows).
2. Se mudou o catalogo: regenerar `catalogo.html` (ver abaixo) e/ou `manifesto.json`.
3. Aumentar `versao.txt`, commit, push na `main`.

## Pastas
- `src/` codigo-fonte do app e icone.
- `tools/catalogo/` gerador do `catalogo.html` (`build_catalog.py` + `dados/`). Ele ainda depende de arquivos locais (fotos da AndyMark em /mnt/user-data/... e da biblioteca STEP no PC), entao serve de referencia: pode precisar de ajuste de caminhos para rodar fora da sessao original.

## Limites conhecidos
Janelas, atalhos, registro do `ftccad://`, download real e troca do .exe foram testados so parcialmente (logica com Mono e janelas em Xvfb; nao no Windows). O exe nao e assinado (SmartScreen avisa). Navegador pede permissao na 1a vez que abre `ftccad://`.
