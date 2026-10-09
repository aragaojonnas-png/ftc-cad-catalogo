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


def descricao(arquivo):
    """nome sem o codigo (am-3488) e sem a extensao, para achar o mesmo arquivo quando o codigo mudou"""
    d = re.sub(r"\.(step|stp)$", "", arquivo, flags=re.I)
    d = re.sub(r"^am-[0-9A-Za-z_]+\s+", "", d, flags=re.I)
    return re.sub(r"[\s_]+", " ", d).strip().lower()


def produtos(q):
    try:
        j = json.loads(get("https://andymark.com/search/suggest.json?q=%s&resources%%5Btype%%5D=product&resources%%5Blimit%%5D=6" % urllib.parse.quote(q)))
        return j["resources"]["results"]["products"]
    except Exception:
        return []


def acha(arquivo):
    """devolve (link_novo, como): como = 'igual' (mesmo nome), 'descricao' (mesmo nome sem o codigo) ou 'codigo'"""
    codigo = re.match(r"am-[0-9A-Za-z]+", arquivo, re.I)
    codigo = codigo.group(0).lower() if codigo else None
    desc = descricao(arquivo)
    consultas = ([codigo] if codigo else []) + ([desc] if len(desc) >= 8 else [])
    links = []
    for q in consultas:
        for p in produtos(q):
            for l in LINK_CAD.findall(pagina(p["url"].split("?")[0])):
                if l not in links: links.append(l)
    if not any(descricao(nome_arquivo(l)) == desc for l in links):       # nao achou: tenta pares de palavras da descricao
        pal = desc.split()
        for q in [" ".join(pal[i:i + 2]) for i in range(len(pal) - 1)]:
            for p in produtos(q):
                for l in LINK_CAD.findall(pagina(p["url"].split("?")[0])):
                    if l not in links: links.append(l)
    for pg in list(_paginas.values()):                                    # paginas ja lidas por outras buscas
        for l in LINK_CAD.findall(pg):
            if l not in links and descricao(nome_arquivo(l)) == desc: links.append(l)
    exato = [l for l in links if nome_arquivo(l).lower() == arquivo.lower()]
    if exato: return exato[0], "igual"
    mesma = [l for l in links if len(desc) >= 8 and descricao(nome_arquivo(l)) == desc]
    if len(mesma) == 1: return mesma[0], "descricao"
    if codigo:
        mesmo = [l for l in links if nome_arquivo(l).lower().startswith(codigo + " ")]
        if len(mesmo) == 1: return mesmo[0], "codigo"
    return None, None


if __name__ == "__main__":
    st = json.load(gzip.open(os.path.join(AQUI, "stemos.json.gz"), "rt", encoding="utf-8"))
    velhos = {}
    for s in st:
        for l in re.findall(r'href=\\?"([^"\\]+)"', s["description"]):
            l = html.unescape(l)
            if "cdn.andymark.com" in l and re.search(r"\.(step|stp)$", l.split("?")[0], re.I): velhos[l] = nome_arquivo(l)
    print(len(velhos), "links antigos")
    with cf.ThreadPoolExecutor(4) as ex: achados = list(ex.map(acha, velhos.values()))
    mapa = {l: urllib.parse.quote(n, safe=":/%") for l, (n, _) in zip(velhos, achados) if n}   # espacos viram %20
    json.dump(mapa, open(os.path.join(AQUI, "andymark_links.json"), "w", encoding="utf-8"), ensure_ascii=False, indent=0)
    print(len(mapa), "achados;", len(velhos) - len(mapa), "sem link novo")
    for (l, a), (n, como) in zip(velhos.items(), achados):
        if como in ("descricao", "codigo"): print("  conferir (%s):" % como, a, "->", nome_arquivo(n))
        if not n: print("  sem link novo:", a)
