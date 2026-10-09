"""Busca nas paginas da REV o nome de cada codigo (ex.: REV-41-1740 -> "45mm U Channel - 1m").
Grava dados/rev_variantes.json, usado por build_catalog.py para diferenciar pecas que tem o mesmo titulo.
Precisa de internet. Uso: python3 buscar_variantes_rev.py"""
import json, os, re, html, urllib.request, concurrent.futures as cf

AQUI = os.path.join(os.path.dirname(os.path.abspath(__file__)), "dados")
CODE = r"REV-\d\d-\d{4}"
LINHA = re.compile(r"<tr[^>]*>(.*?)</tr>", re.S)
CELULA = re.compile(r"<td[^>]*>(.*?)</td>", re.S)
ROTULO = re.compile(r"\((" + CODE + r"[-\w]*)\)\s*([^<]+?)\s*</label>")           # (CODIGO) Nome
ROTULO2 = re.compile(r">\s*([^<>]*?)\s*\((" + CODE + r"[-\w]*)\)\s*</label>")      # Nome (CODIGO)
ITEM = re.compile(r"<li>\s*([^<]*?)\s*-?\s*\((" + CODE + r"[-\w]*)\)\s*</li>")    # 440mm - (CODIGO)
LINK = re.compile(r'<a href="[^"]*/(' + CODE + r'[-\w]*)\.STEP"[^>]*>\s*([^<]*?)\s*STEP File', re.I)  # Nome (CODIGO) STEP File


def limpa(s):
    return re.sub(r"\s+", " ", html.unescape(re.sub(r"<[^>]+>", "", s)).replace("\xa0", " ")).strip()


def extrai(t):
    achados = {}
    def poe(cod, nome):
        nome = limpa(nome).strip(" -")
        nome = re.sub(r"\s*\(" + CODE + r"[-\w]*\)\s*$", "", nome).strip(" -")
        if nome and not re.fullmatch(CODE + r"[-\w]*", nome):
            achados.setdefault(cod, nome)
            achados.setdefault(re.match(CODE, cod).group(0), nome)
    for lin in LINHA.findall(t):
        cel = CELULA.findall(lin)
        if len(cel) >= 2:
            m = re.fullmatch(CODE + r"[-\w]*", limpa(cel[0]))
            if m:
                poe(m.group(0), cel[1])
    for cod, nome in ROTULO.findall(t):
        poe(cod, nome)
    for nome, cod in ROTULO2.findall(t) + ITEM.findall(t):
        poe(cod, nome)
    for cod, nome in LINK.findall(t):
        poe(cod, nome)
    return achados


def baixa(u):
    rq = urllib.request.Request(u, headers={"User-Agent": "Mozilla/5.0"})
    try:
        return u, urllib.request.urlopen(rq, timeout=40).read().decode("utf-8", "replace")
    except Exception as e:
        print("falhou", u, e)
        return u, ""


if __name__ == "__main__":
    paginas = json.load(open(os.path.join(AQUI, "manifest.json")))
    urls = sorted({p["url"] for p in paginas if "revrobotics" in p["url"]})
    out = {}
    with cf.ThreadPoolExecutor(6) as ex:
        for u, t in ex.map(baixa, urls):
            for c, n in extrai(t).items():
                out.setdefault(c, n)
    json.dump(out, open(os.path.join(AQUI, "rev_variantes.json"), "w", encoding="utf-8"), ensure_ascii=False, indent=0, sort_keys=True)
    print(len(urls), "paginas,", len(out), "codigos")
