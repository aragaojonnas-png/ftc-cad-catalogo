# FTC_CAD - guia para o Claude Code

Catalogo de pecas STEP (goBILDA, REV, AndyMark) para FTC. Usuario: Jonnas (Aracaju, escreve em portugues, digita no celular: interprete com tolerancia).
Preferencias dele: resposta objetiva e proporcional, perguntar quando houver duvida (pedir print em vez de chutar visual), pesquisar antes de afirmar, nao acrescentar extras nao pedidos, admitir erros.

## Como funciona
- `FTC_CAD.exe` (codigo: `src/FtcCad.cs`, C# 5, .NET Framework 4.5+, WinForms, sem dependencias): abre o catalogo (`catalogo.html`) como app no Edge/Chrome (`--app`), atualiza sozinho, baixa pecas sob demanda, gerencia pecas da equipe.
- Modos: sem argumento = abrir (na 1a vez mostra o instalador); `--instalar`; `ftccad://baixar?arquivo=<pasta/nome>`, `ftccad://remover?arquivo=<caminho>`, `ftccad://adicionar`, `ftccad://editar?arquivo=<caminho do .step da equipe>`, `ftccad://estoque?arquivo=<chave>&tem=0|1&qtd=<n>` (o catalogo chama esses enderecos; o app os registra em HKCU\Software\Classes\ftccad).
- Arquivos que o app le/gera ao lado do .exe (pasta do usuario): `catalogo.html`, `manifesto.json` (d=destino, u=url, c=cadeia de entradas zip, s=tamanho), `versao.txt`, `config.json` (pastaEquipe, modo=tudo|demanda), `extras.js` (pecas da equipe), `baixadas.js` (pecas ja baixadas), `estoque.js` (pecas disponiveis na equipe).
- Estoque da equipe ("disponivel", quantidade opcional): `estoque.json` na raiz da pasta da equipe (Drive), `{"<pasta/nome da peca em minusculas, sem .step>": {"q": quantidade}}`. O catalogo mostra o botao "+ tenho" em cada cartao e o filtro "so as disponiveis"; o app grava via `ftccad://estoque` (le o arquivo na hora, nunca sobrescreve se estiver ilegivel, guarda `estoque.json.bak`) e gera `estoque.js` ao abrir. A chave e `pasta/nome` do cartao, entao renomear/mover uma peca no catalogo perde a marcacao dela. Editar uma peca da equipe (`Editar.Aplicar`: nome, codigo, fabricante, tipo, grupo, link, foto; mudar o tipo move o .step/.json para a pasta do novo tipo) leva a marcacao junto (`EstoqueEquipe.Mover`). O campo `dn` das linhas do catalogo e o titulo diferenciado (nao confundir com `v`, que e o fabricante nas pecas da equipe).
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
- `tools/catalogo/` gerador do `catalogo.html` **e do `manifesto.json`** (`python3 build_catalog.py`; roda fora da sessao original, usa so `dados/`). Dados:
  - `manifesto_full.json` (goBILDA/REV raspados), `andymark_manifesto.json` + `andymark_rows.json` (AndyMark Stealth/Sushi), `stemos.json.gz` (catalogo da loja stemOS).
  - `rev_variantes.json`: nome de cada codigo REV (gerado por `buscar_variantes_rev.py`, precisa de internet). Usado para o campo `dn`: nome diferenciado que o cartao mostra como titulo quando varias pecas tem o mesmo (REV: nome da variante; goBILDA: titulo + serie). O arquivo/caminho continua com o nome original.
  - `stemos_extras.json`: pecas que a stemOS vende com STEP e que nao estavam no manifesto (WCP, AndyMark, CTR, Axon, SDS...), sem kits (gerado por `adicionar_stemos.py`, precisa de internet; confere cada link baixando). Pecas FRC vao em pastas `... (FRC)` e o app nao as baixa sozinho no modo "tudo".
  - `andymark_links.json`: o dominio `cdn.andymark.com` (links antigos da stemOS) nao existe mais; este arquivo troca cada link antigo pelo atual (s3 docusync, achado na pagina do produto em andymark.com por `buscar_andymark.py`). `adicionar_stemos.py` aplica a troca sozinho.
  - Para atualizar a stemOS: trocar `stemos.json.gz`, rodar `buscar_andymark.py`, `adicionar_stemos.py` e depois `build_catalog.py`. Antes de publicar, conferir que o total de entradas novas nao diminuiu (rede bloqueada faz o script gravar menos; desfazer com `git checkout tools/catalogo/dados/stemos_extras.json`).

## Limites conhecidos
O site da WCP responde 406 se o User-Agent for so "Mozilla/5.0": o app usa um User-Agent de navegador completo (`Rede.Agente`). Alguns links da stemOS ficam de fora por estarem fora do ar ou bloqueados (ver saida de `adicionar_stemos.py`).
Janelas, atalhos, registro do `ftccad://`, download real e troca do .exe foram testados so parcialmente (logica com Mono e janelas em Xvfb; nao no Windows). O exe nao e assinado (SmartScreen avisa). Navegador pede permissao na 1a vez que abre `ftccad://`.
