"""Gera catalogo.html: foto + nome + caminho de cada STEP, com busca e filtros."""
import json, os, re, html, gzip, urllib.parse
os.chdir(os.path.join(os.path.dirname(os.path.abspath(__file__)), "dados"))

man = json.load(open("manifesto_full.json"))          # d (relativo a FTC_CAD), u, c, s
pages = json.load(open("manifest.json"))               # url, title, bc, links, site
photos = json.load(open("photos.json"))                # url da pagina -> foto

by_link = {}
for pg in pages:
    for l in pg["links"]:
        by_link[l.replace("/content/cad/#", "/content/cad/")] = pg

def _ukq(u):
    return re.sub(r"\.(step|stp|zip)", "", urllib.parse.unquote(u.split("?")[0].split("#")[0].rstrip("/").rsplit("/", 1)[-1]), flags=re.I).upper()
EXCL = re.compile(r"kit|bundle|starter|chassis|platform|resource guide|everybot|strafer|starter bot|robot-in", re.I)
# ---- stemOS: indice por URL do STEP e por codigo da peca ----
_st = json.load(gzip.open("stemos.json.gz", "rt", encoding="utf-8"))
_CODE = re.compile(r"\b(\d{4}-\d{4}-\d{4}|REV-\d\d-\d{4})\b", re.I)
_byurl, _bycode = {}, {}
def _ukey(u):
    return re.sub(r"\.(step|stp|zip)", "", u.split("?")[0].split("#")[0].rstrip("/").rsplit("/", 1)[-1], flags=re.I).upper()
for _x in _st:
    for _l in set(re.findall(r'href=\\?"([^"\\]+)"', _x["description"])):
        if re.search(r"/content/(cad|step_files)/", _l): _byurl.setdefault(_ukey(_l), _x)
    _txt = _x["name"] + " " + _x["sku"]
    for _c in {m.upper() for m in _CODE.findall(_txt)}: _bycode.setdefault(_c, _x)
# pecas que a stemOS vende (fora da categoria Kits) entram mesmo que o STEP esteja numa pasta de "Starter Bot"/"Everybot"/"kit" da REV:
# o filtro EXCL e para tirar robos e kits inteiros, nao as pecas soltas que moram dentro deles
_alinks = json.load(open("andymark_links.json", encoding="utf-8"))
_liberados = set()
for _x in _st:
    if any(c["name"] == "Kits" for c in _x["categories"]): continue
    for _l in set(re.findall(r'href=\\?"([^"\\]+)"', _x["description"])):
        _l = html.unescape(_l); _l = _alinks.get(_l, _l)
        if re.search(r"\.(step|stp|zip)$", _l.split("?")[0], re.I): _liberados.add(_ukq(_l))
def _loja(e, name):
    x = _byurl.get(_ukey(e["u"]))
    if not x:
        for c in _CODE.findall(name):
            x = _bycode.get(c.upper())
            if x: break
    if not x: return {}
    return {"l": 1}
rows = []
man_ok = []        # entradas do manifesto que viram pecas do catalogo (vai para ../../../manifesto.json)
excl = 0
for e in man:
    if EXCL.search(e["d"]) and _ukq(e["u"]) not in _liberados:
        excl += 1
        continue
    man_ok.append(e)
    pg = by_link.get(e["u"])
    d = e["d"]
    folder, fname = d.rsplit("/", 1)
    name = fname[:-5] if fname.lower().endswith(".step") else fname
    frc = d.startswith("REV/ION") or "Robotics Competition" in d
    rows.append({
        "n": name,
        "p": folder,
        "s": round(e["s"] / 1048576, 1),
        "i": (photos.get(pg["url"]) or "") if pg else "",
        "t": pg["title"] if pg else "",
        "u": pg["url"] if pg else "",
        "f": 1 if frc else 0,
        "m": d.split("/")[0],
        **_loja(e, fname),
    })
man_ok += json.load(open("andymark_manifesto.json", encoding="utf-8"))
_estemos = json.load(open("stemos_extras.json", encoding="utf-8"))       # gerado por adicionar_stemos.py
for e in _estemos:
    folder, fname = e["d"].rsplit("/", 1)
    man_ok.append({"u": e["u"], "c": e["c"], "d": e["d"], "s": e["s"]})
    rows.append({"n": fname[:-5], "p": folder, "s": round(e["s"] / 1048576, 1) or 0.1, "i": e["i"], "t": e["t"] + " " + " ".join(e["tags"]),
                 "u": e["w"], "f": e["f"], "m": e["m"], "l": 1, "_e": 1})
rows += json.load(open("andymark_rows.json", encoding="utf-8"))   # fotos da AndyMark (Stealth e Sushi), guardadas em dados/
from tipos import tipo, tipo_stemos
for r in rows: r["g"] = tipo_stemos(r["p"], r["n"]) if r.pop("_e", 0) else tipo(r["p"], r["n"])
# ---- pecas com o mesmo titulo: "dn" e o nome diferenciado, mostrado como titulo do cartao (REV: nome da variante; goBILDA: titulo + serie) ----
_rev = json.load(open("rev_variantes.json", encoding="utf-8"))   # gerado por buscar_variantes_rev.py
def _cod_tit(n):
    m = re.match(r"^(.+?) - (.+)$", n)
    c, t = (m.group(1), m.group(2)) if m else ("", n)
    return c, re.sub(r" \[([^\]]+)\]$", lambda x: "" if x.group(1) == c else x.group(0), t)
_grupos = {}
for r in rows:
    _grupos.setdefault((r["m"], _cod_tit(r["n"])[1].lower()), []).append(r)
for g in _grupos.values():
    if len(g) < 2: continue
    for r in g:
        cod = _cod_tit(r["n"])[0]
        if r["m"] == "REV" and _rev.get(cod): r["dn"] = _rev[cod]
        elif r["m"] == "goBILDA" and re.match(r"\d{4}-", cod): r["dn"] = "%s (Série %s)" % (_cod_tit(r["n"])[1], cod[:4])
    vs = [r.get("dn") for r in g]
    if len(set(vs)) < len(vs):                      # nao diferenciou: melhor nao mostrar nada
        for r in g: r.pop("dn", None)
rows.sort(key=lambda r: (r["p"].lower(), r["n"].lower()))
cats = sorted({"/".join(r["p"].split("/")[:2]) for r in rows})
print("removidas (kits/robos):", excl)
print("entradas:", len(rows), "| com foto:", sum(1 for r in rows if r["i"]), "| categorias:", len(cats))

data = json.dumps({"rows": rows, "cats": cats, "mfrs": sorted({r["m"] for r in rows}), "tipos": sorted({r["g"] for r in rows}, key=lambda t: (t == "Outros", t))}, ensure_ascii=False).replace("</", "<\\/")

page = """<!doctype html>
<html lang="pt-BR">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Catálogo FTC_CAD</title>
<link rel="icon" href="data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 64 64'%3E%3Crect width='64' height='64' rx='14' fill='%237c3aed'/%3E%3Ctext x='32' y='47' font-family='Segoe UI,Arial,sans-serif' font-weight='700' font-size='44' text-anchor='middle' fill='white'%3EF%3C/text%3E%3C/svg%3E">
<style>
:root{color-scheme:dark;--bg:#130e22;--bg2:#1a1330;--card:#1e1637;--ink:#eee9fa;--mute:#a79dc8;--line:#33285a;--acc:#b692f6;--accbg:#2c2050;--btn:#7c3aed;--shop:#8af0ac;--shopbg:#1a3a2a;--img:#fff}
*{box-sizing:border-box}
body{margin:0;background:var(--bg);color:var(--ink);font:14px/1.45 system-ui,"Segoe UI",Roboto,sans-serif}
header{background:linear-gradient(180deg,#21163f 0%,var(--bg2) 100%);border-bottom:1px solid var(--line);padding:12px 16px 10px}
@media (min-width:700px){header{position:sticky;top:0;z-index:5}}
.top{display:flex;gap:12px;align-items:center;flex-wrap:wrap}
h1{font-size:16px;margin:0;font-weight:650;white-space:nowrap;color:#fff}
#count{color:var(--mute);font-size:13px;margin-left:auto;white-space:nowrap}
input[type=search],select{height:36px;padding:0 10px;border:1px solid var(--line);border-radius:8px;background:var(--bg);color:var(--ink);font:inherit;font-size:13px}
input[type=search]{flex:1 1 280px;min-width:0}
input[type=search]::placeholder{color:#8479ab}
input[type=checkbox]{accent-color:var(--btn)}
:focus-visible{outline:2px solid var(--acc);outline-offset:1px}
.filters{display:flex;flex-wrap:wrap;gap:8px;align-items:center;margin-top:8px}
.filters select{flex:0 1 auto;max-width:100%}
label{display:flex;gap:6px;align-items:center;color:var(--mute);white-space:nowrap;font-size:13px}
#tabs{display:flex;gap:6px;overflow-x:auto;padding:10px 0 4px;scrollbar-width:thin;scrollbar-color:#3a2d68 transparent}
.tab{flex:0 0 auto;border:1px solid var(--line);background:var(--card);color:var(--ink);border-radius:999px;padding:4px 12px;cursor:pointer;font:inherit;font-size:13px;white-space:nowrap}
.tab:hover{border-color:var(--acc)}
.tab small{color:var(--mute);margin-left:5px;font-size:12px}
.tab.on{background:var(--btn);border-color:var(--btn);color:#fff}
.tab.on small{color:#e6dcff}
main{padding:16px;display:grid;grid-template-columns:repeat(auto-fill,minmax(200px,1fr));gap:12px}
@media (max-width:520px){.filters select{flex:1 1 140px}main{grid-template-columns:repeat(2,1fr);gap:8px;padding:10px}}
.card{background:var(--card);border:1px solid var(--line);border-radius:12px;overflow:hidden;cursor:pointer;display:flex;flex-direction:column;transition:border-color .12s,box-shadow .12s,transform .12s}
.card:hover,.card:focus-visible{border-color:var(--btn);box-shadow:0 4px 18px rgba(124,58,237,.30);transform:translateY(-1px)}
.ph{aspect-ratio:4/3;display:flex;align-items:center;justify-content:center;background:var(--img);border-bottom:1px solid var(--line)}
.ph img{width:100%;height:100%;object-fit:contain;padding:8px}
.ph.none{color:#8b8aa0;font-size:12px}
.b{padding:10px 12px 11px;display:flex;flex-direction:column;gap:2px;flex:1}
.code{font:600 12px/1.3 ui-monospace,SFMono-Regular,Consolas,monospace;color:var(--acc);word-break:break-all}
.name{font-size:13.5px;font-weight:500;line-height:1.35;display:-webkit-box;-webkit-line-clamp:3;-webkit-box-orient:vertical;overflow:hidden;min-height:3.9em}
.path{color:var(--mute);font-size:12px;margin-top:4px;white-space:nowrap;overflow:hidden;text-overflow:ellipsis}
.meta{display:flex;flex-wrap:wrap;gap:6px;align-items:center;margin-top:auto;padding-top:8px;color:var(--mute);font-size:12px}
.meta .sz{margin-left:auto}
#add{background:var(--btn);color:#fff;text-decoration:none;border-radius:8px;padding:6px 12px;font-size:13px;font-weight:600;white-space:nowrap}
#add:hover{filter:brightness(1.15)}
.tag{background:var(--accbg);color:var(--acc);border-radius:6px;padding:1px 7px;font-size:11.5px;font-weight:600}
.dl{font-size:11.5px;border-radius:6px;padding:1px 7px;font-weight:600}
.dl.ok{color:#8af0ac;border:1px solid #2c5a42}
.dl.no{color:#d6c2ff;border:1px solid #5b3fa0}
.rm{margin-left:4px;font-size:11.5px;color:#ff9db0;text-decoration:none;border:1px solid #5a2a3a;border-radius:6px;padding:1px 8px}
.rm:hover{background:#4a1f2e;color:#ffc2cf}
.ed{margin-left:4px;font-size:11.5px;color:var(--acc);text-decoration:none;border:1px solid #4a3a80;border-radius:6px;padding:1px 8px}
.ed:hover{background:var(--accbg);color:#fff}
.es{margin-left:4px;font:inherit;font-size:11.5px;border-radius:6px;padding:1px 8px;cursor:pointer;background:transparent;color:var(--mute);border:1px dashed #5b4a8f}
.es:hover{border-color:var(--acc);color:var(--ink)}
.es.on{background:var(--shopbg);color:var(--shop);border:1px solid #2c5a42}
.tag.eq{background:#2a1f4d;color:#d6c2ff}
.tag.shop{background:var(--shopbg);color:var(--shop)}
#more{display:block;margin:4px auto 28px;padding:9px 20px;border-radius:8px;border:1px solid var(--line);background:var(--card);color:var(--ink);cursor:pointer;font:inherit}
#more[hidden]{display:none}
#more:hover{border-color:var(--btn)}
#toast{position:fixed;bottom:16px;left:50%;transform:translateX(-50%);background:var(--btn);color:#fff;padding:8px 14px;border-radius:8px;opacity:0;transition:.2s;pointer-events:none;max-width:90vw}
#toast.on{opacity:.97}
.empty{grid-column:1/-1;color:var(--mute);text-align:center;padding:48px 16px}
[hidden]{display:none!important}
.views{display:flex;gap:4px;background:var(--bg);border:1px solid var(--line);border-radius:10px;padding:3px}
.vw{border:0;background:transparent;color:var(--mute);font:inherit;font-size:13px;font-weight:600;border-radius:8px;padding:5px 12px;cursor:pointer;white-space:nowrap}
.vw:hover{color:var(--ink)}
.vw.on{background:var(--btn);color:#fff}
.vw small{margin-left:5px;font-size:12px;opacity:.8}
.tag.ex{background:#1e2a4d;color:#a9c4ff}
.tag.n{background:transparent;border:1px solid var(--line);color:var(--mute)}
#dlg{position:fixed;inset:0;background:rgba(8,5,18,.72);display:flex;align-items:center;justify-content:center;padding:16px;z-index:20}
#dlg .box{background:var(--card);border:1px solid var(--line);border-radius:14px;max-width:560px;width:100%;max-height:85vh;display:flex;flex-direction:column;overflow:hidden}
#dlg h2{font-size:15px;margin:0;padding:14px 16px 4px;color:#fff}
#dlg .sub{padding:0 16px 10px;color:var(--mute);font-size:12.5px}
#dlg .files{overflow:auto;padding:0 8px;border-top:1px solid var(--line)}
.fl{display:flex;gap:8px;align-items:center;padding:8px;border-bottom:1px solid var(--line)}
.fl .fn{flex:1 1 auto;min-width:0;overflow:hidden;text-overflow:ellipsis;white-space:nowrap}
.fl .fz{color:var(--mute);font-size:12px;white-space:nowrap}
.btn2{font:inherit;font-size:12px;color:var(--ink);background:var(--accbg);border:1px solid #4a3a80;border-radius:6px;padding:3px 9px;cursor:pointer;text-decoration:none;white-space:nowrap}
.btn2:hover{background:#3a2a6a}
#dlg .foot{display:flex;gap:8px;flex-wrap:wrap;justify-content:flex-end;padding:12px 16px;border-top:1px solid var(--line)}
</style>
</head>
<body>
<header>
  <div class="top">
    <h1>Catálogo FTC_CAD</h1>
    <nav class="views" id="views" aria-label="Visão"><button type="button" class="vw on" data-v="cat">Catálogo</button><button type="button" class="vw" data-v="eq">Peças da equipe<small id="eqcount"></small></button></nav>
    <input id="q" type="search" placeholder="Buscar por nome ou código (ex.: servo, 2101-0006, hub 8mm)" aria-label="Buscar" autofocus>
    <span id="count" aria-live="polite"></span>
    <a id="add" href="ftccad://adicionar" hidden title="Adicionar uma peça nova à pasta compartilhada da equipe">+ Adicionar peça</a>
  </div>
  <div class="filters">
    <select id="mfr" aria-label="Fabricante ou loja"></select>
    <select id="cat" aria-label="Categoria"></select>
    <select id="sz" aria-label="Tamanho do arquivo"><option value="0">qualquer tamanho</option><option value="5">até 5 MB</option><option value="20">até 20 MB</option></select>
    <select id="ft" hidden aria-label="Tipo de arquivo"></select>
    <label id="frcbox"><input id="frc" type="checkbox"> mostrar FRC</label>
    <label id="dlbox" hidden><input id="onlydl" type="checkbox"> só as que já estão no PC</label>
    <label id="estbox" hidden><input id="onlyest" type="checkbox"> só as disponíveis na equipe</label>
  </div>
  <div id="tabs" role="tablist" aria-label="Tipo de peça"></div>
</header>
<main id="grid"></main>
<button id="more" hidden>Mostrar mais</button>
<div id="toast"></div>
<div id="dlg" hidden></div>
<script src="extras.js"></script>
<script src="baixadas.js"></script>
<script src="estoque.js"></script>
<script id="data" type="application/json">__DATA__</script>
<script>
const D = JSON.parse(document.getElementById('data').textContent);
const $ = id => document.getElementById(id);
const BASE = {rows: D.rows.slice(), tipos: D.tipos.slice()};
const norm = s => s.toLowerCase().normalize('NFD').replace(/[\\u0300-\\u036f]/g, '');
const mfrOk = (r, m) => !m || (m === 'stemOS' ? r.l : r.m === m);
// duas visoes: "cat" = catalogo (goBILDA, REV, WCP...) e "eq" = pecas da equipe (pasta compartilhada, varios arquivos de qualquer tipo)
let VIEW = 'cat';
const inView = r => VIEW === 'eq' ? !!r.x : !r.x;
const exts = r => r.ex && r.ex.length ? r.ex : ['STEP'];
const nf = r => (r.fs && r.fs.length) || 1;
let EXJ = '';
function buildFilters(){   // fabricantes, categorias e tipos de arquivo so da visao atual
  const rows = D.rows.filter(inView), eq = VIEW === 'eq';
  const m0 = $('mfr').value, c0 = $('cat').value, f0 = $('ft').value;
  const uniq = a => Array.from(new Set(a)).sort();
  const mfrs = uniq(rows.map(r => r.m)), cats = uniq(rows.map(r => r.p.split('/').slice(0, 2).join('/'))), fts = uniq([].concat(...rows.map(exts)));
  const opts = (first, a) => '<option value="">' + first + '</option>' + a.map(c => `<option value="${esc(c)}">${esc(c)}</option>`).join('');
  $('mfr').innerHTML = opts(eq ? 'todos os grupos e fabricantes' : 'todos os fabricantes e lojas', eq ? mfrs : mfrs.concat(['stemOS']));
  $('cat').innerHTML = opts('todas as categorias', cats);
  $('ft').innerHTML = opts('todos os tipos de arquivo', fts);
  $('mfr').value = m0; $('cat').value = c0; $('ft').value = f0;
  ['mfr', 'cat', 'ft'].forEach(id => { if ($(id).selectedIndex < 0) $(id).value = ''; });
}
function chrome(){   // o que aparece em cada visao
  const eq = VIEW === 'eq';
  $('add').hidden = !eq; $('ft').hidden = !eq; $('frcbox').hidden = eq; $('dlbox').hidden = eq || !dlMode(); $('estbox').hidden = !estMode();
  $('q').placeholder = eq ? 'Buscar nas peças da equipe (nome, código, tipo de arquivo)' : 'Buscar por nome ou código (ex.: servo, 2101-0006, hub 8mm)';
}
function setView(v){ VIEW = v; TIPO = ''; document.querySelectorAll('.vw').forEach(b => b.classList.toggle('on', b.dataset.v === v)); buildFilters(); chrome(); filter(); }
function mergeExtras(){
  const ex = window.EXTRAS || []; EXJ = JSON.stringify(ex);
  D.rows = BASE.rows.concat(ex); D.tipos = BASE.tipos.slice();
  ex.forEach(e => { if (!D.tipos.includes(e.g)) D.tipos.splice(Math.max(0, D.tipos.length - 1), 0, e.g); });
  D.rows.forEach(r => { if (!r.k) r.k = norm(r.n + ' ' + r.p + ' ' + r.t + ' ' + r.g + ' ' + (r.dn || '') + ' ' + (r.x ? exts(r).join(' ') : '')); });
  $('eqcount').textContent = ex.length || '';
  buildFilters();
}
// pecas baixadas no PC (baixadas.js gerado pelo instalador); sem esse arquivo o catalogo age como antes
const DL = new Set();
const dlMode = () => Array.isArray(window.BAIXADAS);
const keyOf = r => (r.p + '/' + r.n).toLowerCase().replace(/\.(step|stp)$/, '');
const isDL = r => r.x || !dlMode() || DL.has(keyOf(r));
// estoque da equipe (estoque.js gerado pelo app a partir do estoque.json da pasta compartilhada): chave -> quantidade (0 = sem quantidade)
const EST = new Map();
const estMode = () => !!window.ESTOQUE && typeof window.ESTOQUE === 'object';
let ESTJ = '';
function loadEst(){ EST.clear(); const o = window.ESTOQUE || {}; Object.keys(o).forEach(k => EST.set(k, (o[k] && o[k].q) || 0)); ESTJ = JSON.stringify(window.ESTOQUE || null);
  chrome(); }
let DLJ = '';
function loadDL(){ DL.clear(); (window.BAIXADAS || []).forEach(x => DL.add(String(x).toLowerCase())); DLJ = JSON.stringify(window.BAIXADAS || null);
  chrome(); }
// ao voltar para a janela (depois de adicionar/remover/baixar uma peca), recarrega as listas sozinho
let _ex = 0;
function loadScript(src){ return new Promise(ok => { const sc = document.createElement('script'); sc.src = src + '?t=' + Date.now();
  sc.onload = () => { sc.remove(); ok(); }; sc.onerror = () => { sc.remove(); ok(); }; document.head.appendChild(sc); }); }
window.addEventListener('focus', async () => {
  if (Date.now() - _ex < 1500) return; _ex = Date.now();
  await Promise.all([loadScript('extras.js'), loadScript('baixadas.js'), loadScript('estoque.js')]);
  let mudou = false;
  if (JSON.stringify(window.EXTRAS || []) !== EXJ) { mergeExtras(); mudou = true; }
  if (JSON.stringify(window.BAIXADAS || null) !== DLJ) { loadDL(); mudou = true; }
  if (JSON.stringify(window.ESTOQUE || null) !== ESTJ) { loadEst(); mudou = true; }
  if (mudou) filter();
});
const PAGE = 200; let shown = PAGE, list = [];
let TIPO = '';
function buildTabs(){
  const cnt = {}; D.rows.forEach(r => { if (inView(r) && (frcOn() || !r.f) && mfrOk(r, $('mfr').value)) cnt[r.g] = (cnt[r.g] || 0) + 1; });
  if (TIPO && !cnt[TIPO]) { TIPO = ''; filter(); return; }
  const total = Object.values(cnt).reduce((a, b) => a + b, 0);
  $('tabs').innerHTML = [['', 'Todos', total]].concat(D.tipos.filter(t => cnt[t]).map(t => [t, t, cnt[t]]))
    .map(([v, n, c]) => `<button class="tab ${v === TIPO ? 'on' : ''}" role="tab" data-t="${v}">${n}<small>${c}</small></button>`).join('');
}
function frcOn(){ return $('frc').checked; }
$('tabs').addEventListener('click', ev => { const t = ev.target.closest('.tab'); if (!t) return; TIPO = t.dataset.t; filter(); });
function esc(s){return s.replace(/[&<>"]/g, c => ({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;'}[c]))}
function filter(){
  const terms = norm($('q').value).split(/\\s+/).filter(Boolean), cat = $('cat').value, mfr = $('mfr').value, tp = TIPO, frc = $('frc').checked, sz = +$('sz').value, ft = $('ft').value, eq = VIEW === 'eq';
  list = D.rows.filter(r => inView(r) && (frc || !r.f) && mfrOk(r, mfr) && (!tp || r.g === tp) && (!cat || r.p.startsWith(cat)) && (!ft || exts(r).includes(ft)) && (!sz || r.s <= sz) && (eq || !$('onlydl').checked || isDL(r)) && (!$('onlyest').checked || EST.has(keyOf(r))) && terms.every(t => r.k.includes(t)));
  shown = PAGE; buildTabs(); draw();
}
function split(n){ const m = n.match(/^(.+?) - (.+)$/); let code = m ? m[1] : '', t = m ? m[2] : n;
  t = t.replace(/ \[([^\]]+)\]$/, (s, x) => x === code ? '' : s); return [code, t]; }
function estChip(r){ const k = keyOf(r), has = EST.has(k), q = EST.get(k);
  return '<button type="button" class="es' + (has ? ' on' : '') + '" title="' + (has ? 'A equipe tem esta peça. Clique para mudar a quantidade ou tirar.' : 'Marcar como disponível na equipe') + '">'
    + (has ? '✓ disponível' + (q ? ' · ' + q : '') : '+ tenho') + '</button>'; }
// marcar/desmarcar como disponivel (quantidade opcional); mostra na hora e o app grava no estoque.json da pasta da equipe
function setEst(c){
  if (!c) return;
  const r = list[+c.dataset.i], k = keyOf(r), has = EST.has(k), q = EST.get(k) || 0;
  const t = window.prompt(has ? 'Quantas a equipe tem? Deixe vazio para só marcar como disponível. Digite 0 para tirar da lista de disponíveis.'
                              : 'Marcar como disponível na equipe. Quantas a equipe tem? (pode deixar vazio)', has && q ? String(q) : '');
  if (t === null) return;
  const s = t.trim(), n = parseInt(s, 10);
  if (s !== '' && (!/^[0-9]+$/.test(s) || n > 999999)) { toast('Digite só números.'); return; }
  const tem = !(s !== '' && n === 0), qtd = tem && s !== '' ? n : 0;
  if (tem) EST.set(k, qtd); else EST.delete(k);
  if ($('onlyest').checked) filter(); else draw();
  toast(tem ? 'Marcada como disponível' + (qtd ? ' (' + qtd + ')' : '') + '. Salvando para a equipe...' : 'Tirada da lista de disponíveis. Salvando...');
  location.href = 'ftccad://estoque?arquivo=' + encodeURIComponent(k) + '&tem=' + (tem ? 1 : 0) + '&qtd=' + qtd;
}
function draw(){
  const part = list.slice(0, shown);
  $('grid').innerHTML = part.length ? part.map((r, i) => { const [code, title] = split(r.n), last = r.p.split('/').pop();
    return `<div class="card" data-i="${i}" tabindex="0" role="button" title="${r.x && nf(r) > 1 ? 'Clique para ver os arquivos da peça' : 'Clique para copiar o caminho do arquivo'}">
      <div class="ph ${r.i ? '' : 'none'}">${r.i ? `<img loading="lazy" referrerpolicy="no-referrer" src="${esc(r.i)}" alt="">` : 'sem foto'}</div>
      <div class="b">${code ? `<div class="code">${esc(code)}</div>` : ''}<div class="name">${esc(r.dn || title)}</div>
      <div class="path">${esc(r.m)} · ${esc(r.g === last ? r.p.split('/').slice(-2).join(' / ') : last)}</div>
      <div class="meta">${r.l ? '<span class="tag shop">stemOS</span>' : ''}${r.x ? '<span class="tag eq" title="Adicionada por ' + esc(r.b || 'alguém da equipe') + '">' + esc(r.gr || 'Equipe') + '</span>' + exts(r).map(e => '<span class="tag ex">' + esc(e) + '</span>').join('') + (nf(r) > 1 ? '<span class="tag n">' + nf(r) + ' arquivos</span>' : '') : ''}${r.f ? '<span class="tag">FRC</span>' : ''}${dlMode() && !r.x ? (isDL(r) ? '<span class="dl ok" title="Este arquivo já está na sua pasta">no PC</span>' : '<span class="dl no" title="Clique no cartão para baixar só esta peça">baixar</span>') : ''}${r.x ? '<a class="ed" href="ftccad://editar?arquivo=' + encodeURIComponent(r.o || r.a) + '" title="Editar nome, tipo, foto etc. desta peça da equipe">editar</a>' : ''}${r.x ? '<a class="rm" href="ftccad://remover?arquivo=' + encodeURIComponent(r.o || r.a) + '" title="Remover esta peça da pasta da equipe">remover</a>' : ''}${estMode() ? estChip(r) : ''}<span class="sz">${r.s ? r.s + ' MB' : ''}</span></div></div>
    </div>`; }).join('') : '<div class="empty">' + (VIEW === 'eq' && !D.rows.some(inView) ? 'Nenhuma peça da equipe ainda.<br>Use <b>+ Adicionar peça</b> para guardar arquivos (STEP, F3D, STL, PDF...) que ficam compartilhados com a equipe.' : 'Nenhuma peça encontrada. Tente outra palavra ou limpe os filtros.') + '</div>';
  $('count').textContent = list.length.toLocaleString('pt-BR') + ' peças';
  $('more').hidden = shown >= list.length;
  const on = document.querySelector('.tab.on'); if (on) on.scrollIntoView({inline:'nearest', block:'nearest'});
}
function baseDir(){
  try { const u = decodeURIComponent(location.href.split('?')[0].split('#')[0]);
    if (u.startsWith('file:///')) return u.slice(8, u.lastIndexOf('/') + 1).replace(/\//g, '\\\\'); } catch (e) {}
  return '';
}
function copyText(t){
  if (navigator.clipboard && window.isSecureContext) return navigator.clipboard.writeText(t);
  return new Promise((ok, no) => { try { const a = document.createElement('textarea'); a.value = t; a.style.position = 'fixed'; a.style.opacity = '0';
    document.body.appendChild(a); a.select(); const r = document.execCommand('copy'); a.remove(); r ? ok() : no(); } catch (e) { no(); } });
}
let FILES = null;
function showFiles(r){   // peca da equipe com varios arquivos: lista, copiar caminho de cada um, abrir a pasta
  const [code, title] = split(r.n), dir = r.fs[0].a.replace(/[\\\\/][^\\\\/]*$/, '');
  FILES = {r: r, dir: dir};
  $('dlg').innerHTML = '<div class="box" role="dialog" aria-label="Arquivos da peça"><h2>' + esc(code ? code + ' - ' + title : title) + '</h2><div class="sub">' + r.fs.length + ' arquivos' + (r.s ? ' · ' + r.s + ' MB no total' : '') + '</div><div class="files">'
    + r.fs.map((f, i) => '<div class="fl"><span class="tag ex">' + esc(f.e || '?') + '</span><span class="fn" title="' + esc(f.n) + '">' + esc(f.n) + '</span><span class="fz">' + f.s + ' MB</span><button type="button" class="btn2" data-cp="' + i + '">copiar caminho</button></div>').join('')
    + '</div><div class="foot"><a class="btn2" href="ftccad://abrir?arquivo=' + encodeURIComponent(r.o || r.a) + '">Abrir pasta</a><button type="button" class="btn2" data-dir="1">Copiar caminho da pasta</button><button type="button" class="btn2" data-x="1">Fechar</button></div></div>';
  $('dlg').hidden = false;
}
$('dlg').addEventListener('click', ev => {
  if (ev.target === $('dlg') || ev.target.closest('[data-x]')) { $('dlg').hidden = true; return; }
  const cp = ev.target.closest('[data-cp]'), dr = ev.target.closest('[data-dir]');
  const path = cp ? FILES.r.fs[+cp.dataset.cp].a : dr ? FILES.dir : null;
  if (path) copyText(path).then(() => toast('Caminho copiado: ' + path), () => { window.prompt('Copie o caminho (Ctrl+C):', path); });
});
document.addEventListener('keydown', ev => { if (ev.key === 'Escape') $('dlg').hidden = true; });
$('views').addEventListener('click', ev => { const b = ev.target.closest('.vw'); if (b && b.dataset.v !== VIEW) setView(b.dataset.v); });
function copyCard(c){
  if (!c) return;
  const r = list[+c.dataset.i];
  if (r.x && nf(r) > 1) { showFiles(r); return; }
  if (!isDL(r)) { toast('Baixando ' + (r.s ? r.s + ' MB' : 'a peça') + '... uma janela vai abrir e o caminho é copiado no fim'); location.href = 'ftccad://baixar?arquivo=' + encodeURIComponent(r.p + '/' + r.n); return; }
  const path = r.a ? r.a : baseDir() + r.p.replace(/\//g, '\\\\') + '\\\\' + r.n + '.step';
  copyText(path).then(() => toast('Caminho copiado: ' + path), () => { window.prompt('Copie o caminho (Ctrl+C):', path); });
}
$('grid').addEventListener('click', ev => { if (ev.target.closest('.rm, .ed')) return; const es = ev.target.closest('.es'); if (es) { setEst(es.closest('.card')); return; } copyCard(ev.target.closest('.card')); });
$('grid').addEventListener('keydown', ev => { if (ev.target.closest('.es, .rm, .ed')) return; if (ev.key === 'Enter' || ev.key === ' ') { ev.preventDefault(); copyCard(ev.target.closest('.card')); } });
function toast(t){const e=$('toast');e.textContent=t;e.classList.add('on');setTimeout(()=>e.classList.remove('on'),3500)}
$('more').onclick = () => { shown += PAGE; draw(); };
['q','mfr','cat','ft','frc','sz','onlydl','onlyest'].forEach(id => $(id).addEventListener(id === 'q' ? 'input' : 'change', filter));
loadDL();
loadEst();
mergeExtras();
chrome();
filter();
</script>
</body>
</html>
"""
open(os.path.abspath("../../../manifesto.json"), "w", encoding="utf-8").write(json.dumps(man_ok, ensure_ascii=False, separators=(",", ":")))
OUT = os.path.abspath("../../../catalogo.html")
open(OUT, "w", encoding="utf-8").write(page.replace("__DATA__", data))
print("catalogo.html: %.2f MB" % (os.path.getsize(OUT) / 1e6))
