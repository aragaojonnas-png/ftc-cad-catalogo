import re
FOLDER = {  # 3º nível das pastas goBILDA -> tipo
 "Batteries":"Eletrônica","Cameras":"Eletrônica","Controllers":"Eletrônica","Lights":"Eletrônica","Odometry":"Eletrônica",
 "Power":"Eletrônica","Power Distribution Boards":"Eletrônica","Sensors":"Eletrônica","Signal Mixers":"Eletrônica","Switches":"Eletrônica",
 "Transmitters & Receivers":"Eletrônica","Voltage Regulators (BECs)":"Eletrônica","Wiring":"Eletrônica",
 "Collars":"Colares e acopladores","Couplers":"Colares e acopladores",
 "Debris-Shields":"Outros","Hinges":"Dobradiças e molas","Springs":"Dobradiças e molas","Shocks":"Dobradiças e molas",
 "Hole Reducers":"Espaçadores e arruelas","Magnets":"Outros","Nuts":"Porcas","Rubber Feet":"Outros",
 "Screws":"Parafusos","Threaded Plates":"Placas e painéis","Tools":"Ferramentas","Washers":"Espaçadores e arruelas",
 "Bearings":"Rolamentos","Belts":"Correias e polias","Cable & Pulleys":"Correias e polias","Pulleys":"Correias e polias",
 "Round Belts & Pulleys":"Correias e polias","Timing Belts & Pulleys":"Correias e polias",
 "CV & Universal Joints":"Acopladores e juntas" ,"Control-Arms":"Guias, slides e articulações","Gearboxes":"Motores e caixas de redução",
 "Gears":"Engrenagens","Hubs":"Cubos","Lead Screws":"Guias, slides e articulações","Linear Motion Guides":"Guias, slides e articulações",
 "Linear Slides":"Guias, slides e articulações","Linkages & Threaded Rods":"Guias, slides e articulações","Motors":"Motores e caixas de redução",
 "Servos":"Servos","Shaft Spacers & Shims":"Espaçadores e arruelas","Shafting":"Eixos e tubos","Shafting & Tubing":"Eixos e tubos",
 "Sprockets":"Correntes e coroas","Sprockets & Chain":"Correntes e coroas","Tracks":"Esteiras","Wheels":"Rodas e pneus","Wheels & Tires":"Rodas e pneus",
 "Beams":"Vigas e perfis","Brackets":"Suportes e bases","Channel":"Vigas e perfis","Clamping Mounts":"Suportes e bases","Grid Plates":"Placas e painéis",
 "Mounts":"Suportes e bases","Panels":"Placas e painéis","Pattern Adaptors":"Suportes e bases","Pattern Plates":"Placas e painéis",
 "Pattern Spacers":"Espaçadores e arruelas","Plates":"Placas e painéis","Spacers":"Espaçadores e arruelas","Standoffs & Spacers":"Espaçadores e arruelas",
 "Tubing":"Vigas e perfis","goRAIL":"Vigas e perfis",
}
FOLDER["CV & Universal Joints"]="Colares e acopladores"
KW = [  # (regex, tipo) em ordem de prioridade
 (r"servo","Servos"),(r"control hub|expansion hub","Eletrônica"),(r"wheels?\b|tires?\b|omni|mecanum|roller","Rodas e pneus"),
 (r"\b(gears?|pinion|miter|rack|worm)\b","Engrenagens"),(r"sprocket|chain","Correntes e coroas"),
 (r"belt|pulley|cable|spool","Correias e polias"),(r"bearing|pillow block","Rolamentos"),(r"\bhub\b|maxhub","Cubos"),
 (r"collar|coupler|coupling","Colares e acopladores"),(r"screw|bolt|rivet","Parafusos"),(r"\bnut\b|nuts","Porcas"),
 (r"washer|spacer|shim|standoff","Espaçadores e arruelas"),(r"shaft|tube|tubing|axle","Eixos e tubos"),
 (r"bracket|corner cube|mount|adapter|adaptor|clamp","Suportes e bases"),(r"plate|panel","Placas e painéis"),
 (r"beam|channel|rail|extrusion|angle|gusset","Vigas e perfis"),(r"slide|guide|linear|lead|linkage|arm","Guias, slides e articulações"),
 (r"motor|gearbox|planetary|neo|vortex|brushless|encoder","Motores e caixas de redução"),
 (r"battery|sensor|camera|switch|wire|light|hub|controller|electronic|power|breaker|sparkmax|radio|bec|led","Eletrônica"),
 (r"spring|hinge|shock","Dobradiças e molas"),(r"tool|wrench|driver","Ferramentas"),
]
def tipo(path, name):
    parts = path.split("/")
    if parts[0] == "goBILDA" and len(parts) > 2 and parts[2] in FOLDER: return FOLDER[parts[2]]
    if parts[0] == "AndyMark" and "Rodas" in path: return "Rodas e pneus"
    s = (path.split("/",1)[-1] + " " + name).lower()
    for rx, t in KW:
        if re.search(rx, s): return t
    return "Outros"

# ---- pecas vindas da stemOS: categorias em portugues ----
CAT_PT = {
 "Rodas":"Rodas e pneus","Hubs":"Cubos","Eixos":"Eixos e tubos","Rolamentos":"Rolamentos","Extrusões":"Vigas e perfis","Extrusões e Chapas":"Vigas e perfis",
 "Fixação":"Parafusos","Espaçadores":"Espaçadores e arruelas","Gussets e Brackets":"Suportes e bases","Motores":"Motores e caixas de redução",
 "Motores e Servos":"Motores e caixas de redução","Caixas de Redução":"Motores e caixas de redução","Sensores":"Eletrônica","Sistema de Controle":"Eletrônica",
 "Energia":"Eletrônica","Cabos":"Eletrônica","Cabos e Terminais":"Eletrônica","Elétrica e Eletrônica":"Eletrônica","Acessórios para Servos":"Servos",
 "Movimentação Linear":"Guias, slides e articulações","Ferramentas":"Ferramentas","Sistemas Swerve":"Módulos swerve",
 "Pneumática":"Pneumática","Atuadores Pneumáticos":"Pneumática","Válvulas, Reguladores e medidores":"Pneumática",
 "Conectores e Mangueiras":"Pneumática","Compressores e Acumuladores":"Pneumática","Arenas e Elementos do Jogo":"Outros",
}
KW_PT = [  # nomes em portugues (categoria "Transmissao" e outras amplas)
 (r"engrenagem|pinh[aã]o|gear|pinion","Engrenagens"),(r"coroa|corrente|sprocket|chain","Correntes e coroas"),
 (r"correia|polia|belt|pulley","Correias e polias"),(r"colar|acoplador|coupler|collar","Colares e acopladores"),
 (r"rolamento|bearing","Rolamentos"),(r"eixo|shaft|axle","Eixos e tubos"),(r"roda|wheel|pneu|tire","Rodas e pneus"),
 (r"cubo|hub","Cubos"),(r"parafuso|screw|bolt","Parafusos"),(r"porca|nut\b","Porcas"),
 (r"espa[cç]ador|arruela|spacer|washer","Espaçadores e arruelas"),(r"caixa de redu|gearbox|planet","Motores e caixas de redução"),
]
def tipo_stemos(path, name):
    parts = path.split("/")
    cat = re.sub(r" \(FRC\)$", "", parts[1]) if len(parts) > 1 else ""
    if cat in CAT_PT: return CAT_PT[cat]
    s = name.lower()
    for rx, t in KW_PT:
        if re.search(rx, s): return t
    return tipo(path, name)
