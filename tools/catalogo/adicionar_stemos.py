"""Acha pecas que a stemOS vende (dados/stemos.json.gz) com arquivo STEP e que ainda nao estao no manifesto,
confere cada link (baixa, abre zip e zip dentro de zip, olha o cabecalho STEP) e grava dados/stemos_extras.json
com as entradas novas (manifesto + dados do cartao). Kits ficam de fora. Precisa de internet.
Uso: python3 adicionar_stemos.py [pasta_temporaria]"""
import gzip, html, io, json, os, re, sys, tempfile, urllib.parse, urllib.request, zipfile, concurrent.futures as cf
from collections import defaultdict

AQUI = os.path.join(os.path.dirname(os.path.abspath(__file__)), "dados")
TMP = sys.argv[1] if len(sys.argv) > 1 else tempfile.gettempdir()
EXCL = re.compile(r"kit|bundle|starter|chassis|platform|resource guide|everybot|strafer|starter bot|robot-in", re.I)  # igual ao build_catalog.py
UA = {"User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0 Safari/537.36"}
MAX_STEPS_ZIP = 8   # zip com mais STEP que isso e uma biblioteca, nao uma peca: nao entra

def ukey(u):
    return re.sub(r"\.(step|stp|zip)", "", urllib.parse.unquote(u.split("?")[0].split("#")[0].rstrip("/").rsplit("/", 1)[-1]), flags=re.I).upper()

def marca(prod, url):
    h = urllib.parse.urlparse(url).netloc.lower(); f = urllib.parse.unquote(url.split("?")[0].rsplit("/", 1)[-1]).lower()
    if "wcproducts" in h: return "WCP"
    if "andymark" in h or f.startswith("am-"): return "AndyMark"
    if "revrobotics" in h: return "REV"
    if "gobilda" in h: return "goBILDA"
    if "studica" in h: return "Studica"
    if "limelight" in h: return "Limelight"
    if "dropbox" in h and f.startswith(("sds", "billet")): return "Swerve Drive Specialties"
    if "ctr" in h or "ctre" in h or "crosstheroad" in url.lower(): return "CTR Electronics"
    tags = {t["name"] for t in prod["tags"]}
    for t, m in (("West Coast Products", "WCP"), ("AndyMark", "AndyMark"), ("REV Robotics", "REV"), ("goBILDA", "goBILDA"),
                 ("Studica Robotics", "Studica"), ("Cross the Road Electronics", "CTR Electronics"),
                 ("Swerve Drive Specialties", "Swerve Drive Specialties"), ("Axon", "Axon"), ("stemOS", "stemOS")):
        if t in tags: return m
    return "Outros"

def categoria(prod):
    ok = [c for c in prod["categories"] if c["name"] not in ("Novidades", "Kits", "FIRST® Tech Challenge")]
    ftc = [c for c in ok if "first-tech-challenge" in c["link"]]
    pick = (ftc or ok or [{"name": "Outros"}])[0]["name"]
    return pick.replace("/", "-")

def frc(prod):
    l = " ".join(c["link"] for c in prod["categories"])
    return 1 if "first-robotics-competition" in l and "first-tech-challenge" not in l else 0

def baixa(url):
    """devolve (tamanho, bytes_do_inicio, caminho_do_arquivo_se_zip). Zip e baixado inteiro; o resto so o comeco."""
    rq = urllib.request.Request(url, headers=UA)
    with urllib.request.urlopen(rq, timeout=60) as rs:
        total = int(rs.headers.get("Content-Length") or 0)
        ini = rs.read(64)
        if ini[:2] == b"PK":
            fd, p = tempfile.mkstemp(dir=TMP, suffix=".zip"); n = len(ini)
            with os.fdopen(fd, "wb") as o:
                o.write(ini)
                while True:
                    b = rs.read(1 << 16)
                    if not b: break
                    o.write(b); n += len(b)
            return n, ini, p
        return total, ini, None

def steps_no_zip(zf, cadeia, prof=0):
    achados = []
    for e in zf.infolist():
        nome = e.filename
        if e.is_dir() or "__MACOSX" in nome or os.path.basename(nome).startswith("."): continue
        if re.search(r"\.(step|stp)$", nome, re.I): achados.append(cadeia + [nome])
        elif re.search(r"\.zip$", nome, re.I) and prof < 2:
            try: achados += steps_no_zip(zipfile.ZipFile(io.BytesIO(zf.read(e))), cadeia + [nome], prof + 1)
            except Exception: pass
    return achados

def confere(url):
    try:
        n, ini, p = baixa(url)
    except Exception as e:
        return url, {"erro": str(e)[:80]}
    try:
        if p:
            with zipfile.ZipFile(p) as zf: ch = steps_no_zip(zf, [])
            return url, {"s": n, "cadeias": ch}
        if b"ISO-10303" in ini: return url, {"s": n, "cadeias": [[]]}
        return url, {"erro": "nao e STEP"}
    except Exception as e:
        return url, {"erro": "zip: " + str(e)[:60]}
    finally:
        if p and os.path.exists(p): os.remove(p)

def limpa_nome(s):
    return re.sub(r"\s+", " ", re.sub(r'[<>:"/\\|?*]', " ", s)).strip(" .")

if __name__ == "__main__":
    st = json.load(gzip.open(os.path.join(AQUI, "stemos.json.gz"), "rt", encoding="utf-8"))
    man = json.load(open(os.path.join(AQUI, "manifesto_full.json")))
    rev = json.load(open(os.path.join(AQUI, "rev_variantes.json"), encoding="utf-8"))
    man += json.load(open(os.path.join(AQUI, "andymark_manifesto.json"), encoding="utf-8"))
    novos_links = json.load(open(os.path.join(AQUI, "andymark_links.json"), encoding="utf-8"))   # cdn.andymark.com saiu do ar (buscar_andymark.py)
    ja = {ukey(e["u"]) for e in man}
    cand = defaultdict(list)
    for s in st:
        if any(c["name"] == "Kits" for c in s["categories"]) or EXCL.search(html.unescape(s["name"])): continue
        for l in set(re.findall(r'href=\\?"([^"\\]+)"', s["description"])):
            l = novos_links.get(html.unescape(l), html.unescape(l))
            if re.search(r"\.(step|stp|zip)$", l.split("?")[0], re.I) and ukey(l) not in ja: cand[l].append(s)
    print(len(cand), "links para conferir")
    with cf.ThreadPoolExecutor(8) as ex: res = dict(ex.map(confere, sorted(cand)))
    erros = {u: r["erro"] for u, r in res.items() if "erro" in r}
    vistos, saida, ignorados = set(), [], []
    for u in sorted(cand):
        r = res[u]; prod = cand[u][0]
        if "erro" in r: continue
        if len(r["cadeias"]) > MAX_STEPS_ZIP or not r["cadeias"]:
            ignorados.append((u, len(r["cadeias"]))); continue
        for ch in r["cadeias"]:
            arq = urllib.parse.unquote((ch[-1] if ch else u.split("?")[0].rsplit("/", 1)[-1])).replace("\\", "/").rsplit("/", 1)[-1]
            stem = re.sub(r"\.(step|stp)$", "", arq, flags=re.I)
            if EXCL.search(stem): continue
            cod = re.match(r"REV-\d\d-\d{4}", stem)
            if cod:                                    # REV: "CODIGO - nome" como no resto do catalogo
                nome = rev.get(cod.group(0)) or html.unescape(prod["name"])
                stem = cod.group(0) + " - " + nome
            elif " " not in stem:                      # so um codigo (WCP-0178, Axon_MAX): junta o nome do produto
                stem = stem + " - " + html.unescape(prod["name"])
            m = marca(prod, u); cat = categoria(prod)
            pasta = cat + (" (FRC)" if frc(prod) else "")   # FRC separado, como "REV/ION (FRC)"; o app nao baixa sozinho
            d = "%s/%s/%s.step" % (m, pasta, limpa_nome(stem)[:120].strip())
            base, i = d, 2
            while d.lower() in vistos: d = base[:-5] + " (%d).step" % i; i += 1
            vistos.add(d.lower())
            img = (prod["images"] or [{}])[0].get("src", "")
            saida.append({"d": d, "u": u, "c": ch, "s": r["s"], "i": img, "t": html.unescape(prod["name"]), "w": prod["permalink"],
                          "f": frc(prod), "m": m, "cat": pasta, "tags": [t["name"] for t in prod["tags"]]})
    json.dump(saida, open(os.path.join(AQUI, "stemos_extras.json"), "w", encoding="utf-8"), ensure_ascii=False, indent=0)
    print(len(saida), "entradas novas |", len(erros), "links com erro |", len(ignorados), "zips grandes ignorados")
    for u, e in sorted(erros.items()): print("  erro:", e, u[:110])
    for u, n in ignorados: print("  ignorado (%d STEP):" % n, u[:110])
