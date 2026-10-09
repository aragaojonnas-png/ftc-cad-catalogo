"""Os links de STEP da AndyMark que a stemOS usa (cdn.andymark.com) sairam do ar: o dominio nao existe mais.
Este script acha o link atual de cada arquivo na pagina do produto em andymark.com (secao "CAD Files", no s3 docusync)
e grava dados/andymark_links.json ({link_antigo: link_novo}), usado por adicionar_stemos.py. Precisa de internet.
Uso: python3 buscar_andymark.py"""
import gzip, html, json, os, re, urllib.parse, urllib.request, concurrent.futures as cf

AQUI = os.path.join(os.path.dirname(os.path.abspath(__file__)), "dados")
UA = {"User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0 Safari/537.36"}
LINK_CAD = re.compile(r"<a href='(https://s3\.amazonaws\.com/docusync-files/[^']+?\.(?:step|stp))'>", re.I)
_paginas = {}


def get(url):
    return urllib.request.urlopen(urllib.request.Request(url, headers=UA), timeout=40).read().decode("utf-8", "replace")


def pagina(caminho):
    if caminho not in _paginas:
        try: _paginas[caminho] = get("https://andymark.com" + caminho)
        except Exception: _paginas[caminho] = ""
    return _paginas[caminho]


def nome_arquivo(url):
    return urllib.parse.unquote(url.split("?")[0].rsplit("/", 1)[-1])


def acha(arquivo):
    codigo = re.match(r"am-[0-9A-Za-z]+", arquivo, re.I)
    if not codigo: return None
    codigo = codigo.group(0).lower()
    try:
        j = json.loads(get("https://andymark.com/search/suggest.json?q=%s&resources%%5Btype%%5D=product&resources%%5Blimit%%5D=6" % urllib.parse.quote(codigo)))
    except Exception:
        return None
    for p in j["resources"]["results"]["products"]:
        links = LINK_CAD.findall(pagina(p["url"].split("?")[0]))
        exato = [l for l in links if nome_arquivo(l).lower() == arquivo.lower()]
        if exato: return exato[0]
        mesmo = [l for l in links if nome_arquivo(l).lower().startswith(codigo + " ")]
        if len(mesmo) == 1: return mesmo[0]
    return None


if __name__ == "__main__":
    st = json.load(gzip.open(os.path.join(AQUI, "stemos.json.gz"), "rt", encoding="utf-8"))
    velhos = {}
    for s in st:
        for l in re.findall(r'href=\\?"([^"\\]+)"', s["description"]):
            l = html.unescape(l)
            if "cdn.andymark.com" in l and re.search(r"\.(step|stp)$", l.split("?")[0], re.I): velhos[l] = nome_arquivo(l)
    print(len(velhos), "links antigos")
    with cf.ThreadPoolExecutor(4) as ex: novos = list(ex.map(acha, velhos.values()))
    mapa = {l: urllib.parse.quote(n, safe=":/%") for l, n in zip(velhos, novos) if n}   # espacos viram %20
    json.dump(mapa, open(os.path.join(AQUI, "andymark_links.json"), "w", encoding="utf-8"), ensure_ascii=False, indent=0)
    print(len(mapa), "achados;", len(velhos) - len(mapa), "sem link novo")
    for l, a in velhos.items():
        if l not in mapa: print("  sem link novo:", a)
