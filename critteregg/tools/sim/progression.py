#!/usr/bin/env python3
"""
SIMULADOR DE PROGRESSÃO do Steal a Critter Egg (só Python 3, sem bibliotecas de fora).

    python3 tools/sim/progression.py                 # tabela: minutos até cada zona (antes x depois)
    python3 tools/sim/progression.py --runs 30       # mais sementes (mais lento, mais estável)
    python3 tools/sim/progression.py --continuous    # jogando sem parar (sem sessões de 1 h por dia)
    python3 tools/sim/progression.py --rebirth       # também simula quem faz REBIRTH assim que pode
    python3 tools/sim/progression.py --formulas v65,config --verbose

DE ONDE VÊM OS NÚMEROS
  * LIDOS do src/shared/Config.luau (parser de tabelas Luau abaixo): Rarities, Mutations, Zones (Speed,
    MinSpeed, Mult, Pool, Rarities), RarityIncome, IndexSpeed, Trails, Gifts, Daily, Quests, PenStartSlots,
    StartSpeed, WalkCap, Night/NightGrowth/Cycle, FirstEggSeconds, Rebirth*, Offline*, Lucky*, Treadmill
    (sequência da esteira, se existir), Map.LaneLength/PlotZ, IndexCap (se existir) e os números das fórmulas
    da esteira e do cercado (lidos das linhas "Gain = ..." / "Cost = ..." dos loops).
  * LIDOS do src/shared/Critters.luau: Id, Rarity, World de cada bichinho (Soon = fora; Weekly = mundo "weekly").
  * DUPLICADOS aqui (se mudar a fórmula no Luau, mude aqui também; o tests/config_spec.luau confere os números
    do IndexReward): RollScale, SizeFactor, BaseIncome (hash do Id), PetIncome, GrowSeconds, WalkSpeed,
    EscapeSpeed, RebirthCost, IndexReward (v65 e a nova, que lê Config.IndexCap).

O "JOGADOR TÍPICO" (criança no celular), um passo por segundo:
  * rouba 1 ovo a cada 60-90 s da MELHOR zona liberada (Speed >= portão), escolhendo o melhor dos ovos que
    vê (--nests) e que consegue levar (EscapeSpeed); 10% das vezes leva bastão/armadilha e perde o ovo;
  * o resto do tempo fica na esteira (--duty = parte do tempo que ela corre de verdade; o resto é olhar o
    cercado, chocar, menus). A sequência da esteira (Config.Treadmill) zera a cada roubo;
  * ovo cresce Config.GrowSeconds (noite: últimos Night s de cada ciclo, x NightGrowth); choca na hora;
  * bichinho novo -> Index -> resgata o prêmio na hora (dinheiro + velocidade);
  * compra sempre a coisa mais barata que dá (cercado, esteira, trilha); cercado cheio = vende o pior bichinho;
  * por padrão joga 1 sessão de --session minutos por dia: presentes por tempo (zeram depois de 3 h fora),
    prêmio diário (sequência), missões do dia (menos a de PvP) e dinheiro offline; o tempo da tabela é tempo
    JOGADO (minutos de tela), não dias de calendário. Sem baú do grupo, sem Robux, sem amigos, sem fim de semana.
"""
import argparse
import math
import os
import random
import re
import statistics
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))


# ---------------------------------------------------------------------------------------------------------
# Parser de tabelas Luau (o suficiente para "Config.X = <expressão>" com tabelas, contas e chamadas)
# ---------------------------------------------------------------------------------------------------------
TOKEN_RE = re.compile(
    r"""
    (?P<ws>\s+)
    |(?P<lcomment>--\[(?P<eq>=*)\[.*?\](?P=eq)\])
    |(?P<comment>--[^\n]*)
    |(?P<lstring>\[(?P<eq2>=*)\[.*?\](?P=eq2)\])
    |(?P<string>"(?:\\.|[^"\\\n])*"|'(?:\\.|[^'\\\n])*')
    |(?P<number>0x[0-9a-fA-F_]+|\d[\d_]*(?:\.[\d_]*)?(?:[eE][+-]?\d+)?|\.\d[\d_]*(?:[eE][+-]?\d+)?)
    |(?P<name>[A-Za-z_][A-Za-z0-9_]*)
    |(?P<op>\.\.\.|\.\.|==|~=|<=|>=|//|::|->|[-+*/%^#<>=(){}\[\];:,.?|&])
    """,
    re.S | re.X,
)


class Opaque:
    """Valor que o simulador não precisa (cor, chamada de função...)."""

    def __init__(self, text):
        self.text = text

    def __repr__(self):
        return "<%s>" % self.text


def tokenize(src):
    out = []
    pos = 0
    while pos < len(src):
        m = TOKEN_RE.match(src, pos)
        if not m:
            raise SyntaxError("Config parser: unexpected character %r at %d" % (src[pos], pos))
        pos = m.end()
        kind = m.lastgroup
        if kind in ("ws", "comment", "lcomment"):
            continue
        if kind in ("eq", "eq2"):
            kind = "lcomment" if m.group("lcomment") else "lstring"
            if kind == "lcomment":
                continue
        text = m.group(0)
        if kind == "number":
            clean = text.replace("_", "")
            value = int(clean, 16) if clean.lower().startswith("0x") else float(clean)
            out.append(("num", value))
        elif kind == "string":
            out.append(("str", text[1:-1]))
        elif kind == "lstring":
            out.append(("str", text))
        elif kind == "name":
            out.append(("name", text))
        else:
            out.append(("op", text))
    out.append(("eof", None))
    return out


class Parser:
    BIN = {"+": 1, "-": 1, "*": 2, "/": 2, "//": 2, "%": 2, "^": 4}

    def __init__(self, tokens, env):
        self.t = tokens
        self.i = 0
        self.env = env

    def peek(self, k=0):
        return self.t[self.i + k]

    def take(self):
        tok = self.t[self.i]
        self.i += 1
        return tok

    def expect(self, text):
        tok = self.take()
        if tok[1] != text:
            raise SyntaxError("Config parser: expected %r, got %r" % (text, tok))

    def expr(self, limit=0):
        tok = self.peek()
        if tok == ("op", "-"):
            self.take()
            left = self.expr(3)
            left = -left if isinstance(left, (int, float)) else Opaque("-")
        else:
            left = self.simple()
        while True:
            tok = self.peek()
            if tok[0] != "op" or tok[1] not in self.BIN:
                return left
            prec = self.BIN[tok[1]]
            if prec < limit or (prec == limit and tok[1] != "^"):
                return left
            self.take()
            right = self.expr(prec if tok[1] == "^" else prec + 1)
            left = self.arith(tok[1], left, right)

    @staticmethod
    def arith(op, a, b):
        if not isinstance(a, (int, float)) or not isinstance(b, (int, float)):
            return Opaque(op)
        if op == "+":
            return a + b
        if op == "-":
            return a - b
        if op == "*":
            return a * b
        if op == "/":
            return a / b
        if op == "//":
            return a // b
        if op == "%":
            return a % b
        return a ** b

    def simple(self):
        tok = self.take()
        if tok[0] in ("num", "str"):
            return tok[1]
        if tok == ("op", "{"):
            return self.table()
        if tok == ("op", "("):
            value = self.expr()
            self.expect(")")
            return value
        if tok[0] == "name":
            if tok[1] in ("true", "false", "nil"):
                return {"true": True, "false": False, "nil": None}[tok[1]]
            value = self.env.get(tok[1], Opaque(tok[1]))
            # sufixos: .campo, :metodo(...), (...)
            while True:
                nxt = self.peek()
                if nxt in (("op", "."), ("op", ":")):
                    self.take()
                    field = self.take()[1]
                    value = value.get(field, Opaque(field)) if isinstance(value, dict) else Opaque(field)
                elif nxt == ("op", "("):
                    self.take()
                    depth = 1
                    while depth:
                        t = self.take()
                        if t == ("op", "("):
                            depth += 1
                        elif t == ("op", ")"):
                            depth -= 1
                        elif t[0] == "eof":
                            raise SyntaxError("Config parser: unclosed call")
                    value = Opaque("call")
                else:
                    return value
        raise SyntaxError("Config parser: unexpected token %r" % (tok,))

    def table(self):
        items, keyed = [], {}
        while self.peek() != ("op", "}"):
            if self.peek()[0] == "name" and self.peek(1) == ("op", "="):
                key = self.take()[1]
                self.take()
                keyed[key] = self.expr()
            elif self.peek() == ("op", "["):
                self.take()
                key = self.expr()
                self.expect("]")
                self.expect("=")
                keyed[key] = self.expr()
            else:
                items.append(self.expr())
            if self.peek() in (("op", ","), ("op", ";")):
                self.take()
        self.take()
        if keyed and items:
            for n, v in enumerate(items, 1):
                keyed[n] = v
            return keyed
        return keyed if keyed else items


def parse_assignments(src, prefix="Config"):
    """Todas as linhas "Config.X = expr" (topo do arquivo). A última atribuição vence."""
    tokens = tokenize(src)
    env, out = {}, {}
    i = 0
    while i < len(tokens) - 4:
        a, b, c, d = tokens[i], tokens[i + 1], tokens[i + 2], tokens[i + 3]
        prev = tokens[i - 1] if i else ("op", ";")
        if a == ("name", prefix) and b == ("op", ".") and c[0] == "name" and d == ("op", "=") and prev[1] not in (".", ":", "function"):
            p = Parser(tokens, env)
            p.i = i + 4
            try:
                out[c[1]] = p.expr()
            except SyntaxError:
                out[c[1]] = Opaque("unparsed")
            i = p.i
            continue
        if a == ("name", "local") and b[0] == "name" and c == ("op", "="):
            p = Parser(tokens, env)
            p.i = i + 3
            try:
                env[b[1]] = p.expr()
            except SyntaxError:
                env[b[1]] = Opaque("unparsed")
            i = p.i
            continue
        i += 1
    return out, env


def need(match, what):
    if not match:
        raise SystemExit("Config.luau changed shape: could not find %s (update tools/sim/progression.py)" % what)
    return match


def load_config(path):
    src = open(path, encoding="utf-8").read()
    cfg, env = parse_assignments(src)
    # esteira: Gain = math.floor(A * B ^ (level - 1) + 0.5); Cost = ... math.floor(C * D ^ (level - 2))
    gain = need(re.search(r"Gain = math\.floor\(([\d_.]+) \* ([\d_.]+) \^ \(level - 1\) \+ 0\.5\)", src), "treadmill Gain")
    cost = need(re.search(r"Cost = if level == 1 then 0 else math\.floor\(([\d_.]+) \* ([\d_.]+) \^ \(level - 2\)\)", src), "treadmill Cost")
    names = env.get("TREAD_NAMES")
    need(isinstance(names, list), "TREAD_NAMES")
    num = lambda s: float(s.replace("_", ""))
    cfg["_Treadmills"] = [
        (math.floor(num(gain.group(1)) * num(gain.group(2)) ** (lv - 1) + 0.5),
         0 if lv == 1 else math.floor(num(cost.group(1)) * num(cost.group(2)) ** (lv - 2)))
        for lv in range(1, len(names) + 1)
    ]
    pen = need(re.search(r"for level = 1, (\d+) do\s*\n\s*table\.insert\(Config\.PenLevels, \{ Cost = math\.floor\(([\d_.]+) \* ([\d_.]+) \^ \(level - 1\)\) \}\)", src), "PenLevels loop")
    pens = [math.floor(num(pen.group(2)) * num(pen.group(3)) ** (lv - 1)) for lv in range(1, int(pen.group(1)) + 1)]
    first = re.search(r"Config\.PenLevels\[1\]\.Cost = ([\d_]+)", src)
    if first:
        pens[0] = int(num(first.group(1)))
    cfg["_PenCosts"] = pens
    for key in ("Rarities", "Zones", "RarityIncome", "IndexSpeed", "Trails", "Mutations", "StartSpeed", "PenStartSlots", "NightGrowth"):
        need(key in cfg, "Config." + key)
    return cfg


def load_critters(path):
    src = open(path, encoding="utf-8").read()
    weekly_at = src.find("local WEEKLY")
    out = []
    for m in re.finditer(r"\{[^{}\n]*\bId = \"(\w+)\"[^\n]*", src):
        line = m.group(0)
        rarity = re.search(r"Rarity = \"(\w+)\"", line)
        if not rarity or "Soon = true" in line:
            continue
        world = re.search(r"World = \"(\w+)\"", line)
        world = world.group(1) if world else "meadow"
        if weekly_at >= 0 and m.start() > weekly_at and "Week = " in line:
            world = "weekly"
        out.append({"Id": m.group(1), "Rarity": rarity.group(1), "World": world})
    return out


# ---------------------------------------------------------------------------------------------------------
# Fórmulas (DUPLICADAS do Config.luau)
# ---------------------------------------------------------------------------------------------------------
class Econ:
    def __init__(self, cfg, critters):
        self.cfg = cfg
        self.rarities = cfg["Rarities"]
        self.rarity_index = {r["Name"]: i + 1 for i, r in enumerate(self.rarities)}
        self.rarity = {r["Name"]: r for r in self.rarities}
        self.zones = cfg["Zones"]
        self.treads = cfg["_Treadmills"]
        self.pens = cfg["_PenCosts"]
        self.trails = [(t["Mult"], t["Cost"]) for t in cfg["Trails"]]
        self.muts = [(m["Name"], m["Chance"], m["Income"]) for m in cfg["Mutations"]]
        self.by_id = {c["Id"]: c for c in critters}
        # poolFor do Game.luau: bichinhos dos mundos da zona, por raridade, em ordem de Id
        self.pools = []
        for zone in self.zones:
            pool = {}
            for rarity in zone["Rarities"]:
                ids = sorted(c["Id"] for c in critters if c["World"] in zone["Pool"] and c["Rarity"] == rarity)
                if ids:
                    pool[rarity] = ids
            self.pools.append(pool)
        # zoneOfDef: primeira zona cujo Pool tem o mundo E cujo Rarities tem a raridade
        self.natural = {}
        for z, zone in enumerate(self.zones, 1):
            for c in critters:
                if c["Id"] not in self.natural and c["World"] in zone["Pool"] and c["Rarity"] in zone["Rarities"]:
                    self.natural[c["Id"]] = z
        self.hash = {}
        for c in critters:
            h = 0
            for ch in c["Id"]:
                h = (h * 31 + ord(ch)) % 1000
            self.hash[c["Id"]] = h

    # Config.RollScale
    @staticmethod
    def roll_scale(rng):
        u = rng.random()
        if u < 0.002:
            return rng.uniform(3.7, 6.7)
        if u < 0.017:
            return rng.uniform(2.15, 3.7)
        if u < 0.097:
            return rng.uniform(1.44, 2.15)
        g = math.sqrt(-2 * math.log(1 - rng.random() * 0.999)) * math.cos(2 * math.pi * rng.random())
        return min(max(math.exp(g * 0.15), 0.6), 1.4)

    @staticmethod
    def size_factor(s):
        return s ** 1.85 if s <= 5 else 19.637875755794113 * (s / 5) ** 1.2

    def base_income(self, cid, z):
        zone = self.zones[z - 1]
        rarity = self.by_id[cid]["Rarity"]
        return self.cfg["RarityIncome"].get(rarity, 1) * zone["Mult"] * (0.85 + (self.hash[cid] / 1000) * 0.3)

    def pet_income(self, cid, s, mut, z):
        mult = 1
        for name, _, income in self.muts:
            if name == mut:
                mult = income
        return max(1, math.floor(self.base_income(cid, z) * self.size_factor(s) * mult + 0.5))

    def grow_seconds(self, cid, s):
        grow = self.rarity[self.by_id[cid]["Rarity"]]["Grow"]
        return math.floor(grow * (s ** 1.95 if s >= 1 else s))

    def walk(self, speed):
        return min(16 + 9.5 * math.log10(1 + max(speed, 0)), self.cfg.get("WalkCap", 150))

    def escape(self, z, s):
        return self.zones[z - 1]["MinSpeed"] * max(s, 0.6) ** 1.8

    def rebirth_cost(self, n):
        return self.cfg["RebirthBase"] * self.cfg["RebirthGrowth"] ** n

    def roll_mut(self, rng):
        m = rng.random() * 100
        for name, chance, _ in self.muts:
            if m < chance:
                return name
            m -= chance
        return None

    def roll_egg(self, z, rng, lucky=False, min_rarity=1, weekly=None):
        """rollEgg do Game.luau (sem Festão/Halloween). weekly = (id, mult) ou None."""
        pool = self.pools[z - 1]
        options = []
        for rarity in self.zones[z - 1]["Rarities"]:
            if rarity in pool and self.rarity_index[rarity] >= min_rarity:
                w = self.rarity[rarity]["Weight"]
                if lucky and self.rarity_index[rarity] >= self.rarity_index["Legendary"]:
                    w *= self.cfg.get("LuckyMult", 3)
                if weekly and self.by_id[weekly[0]]["Rarity"] == rarity and weekly[0] in pool[rarity]:
                    w *= weekly[2]
                options.append((rarity, w))
        roll = rng.random() * sum(w for _, w in options)
        chosen = options[-1][0]
        for rarity, w in options:
            roll -= w
            if roll <= 0:
                chosen = rarity
                break
        ids = pool[chosen]
        weights = [weekly[1] if weekly and i == weekly[0] else 1 for i in ids]
        pick = rng.random() * sum(weights)
        cid = ids[-1]
        for i, w in zip(ids, weights):
            pick -= w
            if pick <= 0:
                cid = i
                break
        return cid, self.roll_mut(rng)


# ---------------------------------------------------------------------------------------------------------
# Fórmulas do prêmio de VELOCIDADE do Index (a que está em teste)
# ---------------------------------------------------------------------------------------------------------
def next_gate(econ, z):
    zones = econ.zones
    if z < len(zones):
        return zones[z]["Speed"]
    last, prev = zones[-1]["Speed"], zones[-2]["Speed"]
    return last * (last / prev)  # depois da última zona: o mesmo salto da anterior


def reward_v65(econ, cid, z):
    rarity = econ.by_id[cid]["Rarity"]
    return math.floor(econ.cfg["IndexSpeed"].get(rarity, 100) * max(1, econ.zones[z - 1]["Mult"] ** 0.75))


def reward_exponent(e):
    def fn(econ, cid, z):
        rarity = econ.by_id[cid]["Rarity"]
        return math.floor(econ.cfg["IndexSpeed"].get(rarity, 100) * max(1, econ.zones[z - 1]["Mult"] ** e))
    fn.label = "Mult^%.2f" % e
    return fn


def reward_cap(fracs, label):
    """v65, mas nunca mais que fracs[raridade] do portão da PRÓXIMA zona."""
    def fn(econ, cid, z):
        rarity = econ.by_id[cid]["Rarity"]
        return math.floor(min(reward_v65(econ, cid, z), fracs.get(rarity, 0.01) * next_gate(econ, z)))
    fn.label = label
    return fn


def reward_config(econ, cid, z):
    """Espelho do Config.IndexReward NOVO (lê Config.IndexCap). Sem IndexCap no Config = igual ao v65."""
    cap = econ.cfg.get("IndexCap")
    if not isinstance(cap, dict):
        return reward_v65(econ, cid, z)
    rarity = econ.by_id[cid]["Rarity"]
    zone = econ.zones[z - 1]
    raw = econ.cfg["IndexSpeed"].get(rarity, 100) * max(1, zone["Mult"] ** cap.get("Exponent", 0.75))
    frac = cap["Fraction"].get(rarity, cap["Fraction"].get("Common", 0.01))
    return math.floor(max(1, min(raw, frac * next_gate(econ, z))))


reward_v65.label = "v65 (Mult^0.75)"
reward_config.label = "NEW (Config)"


def reward_none(econ, cid, z):
    return 0


reward_none.label = "no Index speed"


# ---------------------------------------------------------------------------------------------------------
# O jogador
# ---------------------------------------------------------------------------------------------------------
class Kid:
    period = (60, 90)  # segundos entre um roubo e outro
    duty = 0.8  # parte do tempo em casa que ela corre na esteira
    nests = 3  # quantos ovos ela olha para escolher
    success = 0.9
    session = 60  # minutos por dia (0 = sem parar)
    extras = True  # presentes, diário, missões, offline
    rebirth = False  # faz rebirth assim que tem o dinheiro
    hours = 60  # tempo máximo jogado


def simulate(econ, reward, kid, seed):
    cfg = econ.cfg
    rng = random.Random(seed)
    zones = econ.zones
    nz = len(zones)
    cycle, night_len, night_mult = cfg.get("Cycle", 300), cfg.get("Night", 10), cfg["NightGrowth"]
    lane, plot_z = cfg["Map"]["LaneLength"], abs(cfg["Map"]["PlotZ"])
    lucky_every, lucky_len = cfg.get("LuckyEvery", 1800), cfg.get("LuckyLength", 180)
    streak_cfg = cfg.get("Treadmill") if isinstance(cfg.get("Treadmill"), dict) else None
    gifts, daily, quests = cfg.get("Gifts", []), cfg.get("Daily", []), cfg.get("Quests", [])

    st = {"money": 0.0, "speed": float(cfg["StartSpeed"]), "pen": 0, "tread": 1, "trail": 0, "reb": 0}
    slots = []  # dicts: egg (left > 0) ou pet
    index, claimed = {}, set()
    reached = {1: 0}
    reached_speed = {}
    log = []
    t = 0  # segundos JOGADOS
    clock = 6 * 3600  # relógio (sessões começam às 6h; noite/sorte/dia usam isso)
    session_t = 0
    phase, left, run_part = "home", 3, 0
    streak = 0
    steals_today = hatches_today = steps_today = 0
    quest_done = set()
    gift_done = set()
    day = clock // 86400
    daily_streak = 0
    first_egg = True
    index_speed_total = 0.0
    tread_speed_total = 0.0

    def income():
        return sum(s["inc"] for s in slots if s["left"] <= 0) * (1 + cfg["RebirthMoney"] * st["reb"])

    def best_zone(speed):
        best = 1
        for z, zone in enumerate(zones, 1):
            if speed >= zone["Speed"]:
                best = z
        return best

    def add_egg(cid, s, mut, z, ready):
        if len(slots) >= cfg["PenStartSlots"] + st["pen"]:
            st["money"] += math.floor(econ.pet_income(cid, s, mut, z) * 100) * 10
            return
        grow = 0 if ready else econ.grow_seconds(cid, s)
        slots.append({"id": cid, "s": s, "mut": mut, "z": z, "left": grow, "inc": econ.pet_income(cid, s, mut, z), "new": True})

    def reward_cash(info_minutes, min_cash):
        return max(min_cash, math.floor(income() * 60 * info_minutes))

    def claim_daily():
        nonlocal daily_streak
        daily_streak = daily_streak % len(daily) + 1
        info = daily[daily_streak - 1]
        st["money"] += reward_cash(info["Minutes"], info["MinCash"])
        st["speed"] += info["Speed"]
        if info.get("Egg"):
            z = best_zone(st["speed"])
            cid, mut = econ.roll_egg(z, rng, min_rarity=econ.rarity_index["Rare"])
            add_egg(cid, econ.roll_scale(rng), mut, z, True)

    if kid.extras and daily:
        claim_daily()

    limit = int(kid.hours * 3600)
    while t < limit and len(reached) < nz:
        t += 1
        clock += 1
        session_t += 1
        night = clock % cycle >= cycle - night_len
        # ovos crescem / chocam
        growth = night_mult if night else 1
        for slot in slots:
            if slot["left"] > 0:
                slot["left"] -= growth
                if slot["left"] <= 0:
                    hatches_today += 1
                    cid, z = slot["id"], slot["z"]
                    if cid not in index:
                        index[cid] = min(econ.natural.get(cid, z), z)
                    if cid not in claimed:
                        claimed.add(cid)
                        sp = reward(econ, cid, index[cid])
                        st["money"] += math.floor(econ.base_income(cid, index[cid]) * 100)
                        st["speed"] += sp
                        index_speed_total += sp
        # renda
        st["money"] += income()
        # atividade
        left -= 1
        on_belt = False
        if phase == "home":
            if left < run_part and st["pen"] >= cfg.get("TreadmillUnlockPen", 1):
                on_belt = True
        if on_belt:
            streak += 1
            gain, _ = econ.treads[st["tread"] - 1]
            mult = econ.trails[st["trail"] - 1][0] if st["trail"] else 1
            gain = math.floor(gain * mult * (1 + cfg["RebirthTread"] * st["reb"]))
            if streak_cfg:
                bonus = min(streak_cfg["StreakMax"], streak_cfg["StreakStep"] * (streak // streak_cfg["StreakEvery"]))
                gain = math.floor(gain * (1 + bonus))
            st["speed"] += gain
            tread_speed_total += gain
            steps_today += 1
        elif phase == "trip":
            streak = 0
        if left <= 0:
            if phase == "trip":
                z, egg = trip
                if egg and rng.random() < kid.success:
                    cid, s, mut = egg
                    cap = cfg["PenStartSlots"] + st["pen"]
                    inc = econ.pet_income(cid, s, mut, z)
                    if len(slots) >= cap:
                        pets = [x for x in slots if x["left"] <= 0]
                        worst = min(pets, key=lambda x: x["inc"]) if pets else None
                        if worst and worst["inc"] < inc:
                            slots.remove(worst)
                            st["money"] += math.floor(worst["inc"] * 100)
                    if len(slots) < cap:
                        grow = econ.grow_seconds(cid, s)
                        if first_egg:
                            grow = min(grow, cfg.get("FirstEggSeconds", 5))
                            first_egg = False
                        slots.append({"id": cid, "s": s, "mut": mut, "z": z, "left": grow, "inc": inc})
                        steals_today += 1
                period = rng.uniform(*kid.period)
                phase = "home"
                left = max(3, int(period - trip_len))
                run_part = int(left * kid.duty) if st["pen"] >= 1 else 0
            else:
                # sai para roubar (se tem vaga ou um bichinho pior para vender)
                z = best_zone(st["speed"])
                lucky = clock % lucky_every < lucky_len
                seen = [econ.roll_egg(z, rng, lucky) for _ in range(kid.nests)]
                options = []
                for cid, mut in seen:
                    s = econ.roll_scale(rng)
                    if z == 1 or econ.escape(z, s) <= st["speed"]:
                        options.append((econ.pet_income(cid, s, mut, z), cid, s, mut))
                cap = cfg["PenStartSlots"] + st["pen"]
                eggs_only = sum(1 for x in slots if x["left"] > 0) >= cap
                if options and not eggs_only:
                    _, cid, s, mut = max(options)
                    trip = (z, (cid, s, mut))
                    dist = plot_z + (z - 0.5) * lane
                    trip_len = 2 * dist / econ.walk(st["speed"]) + 8
                    phase, left = "trip", max(1, int(trip_len))
                else:
                    phase, left = "home", int(rng.uniform(*kid.period))
                    run_part = int(left * kid.duty)
                    trip_len = 0
        # presentes por tempo jogado na sessão
        if kid.extras:
            for gi, info in enumerate(gifts):
                if gi not in gift_done and session_t >= info["Minutes"] * 60:
                    gift_done.add(gi)
                    st["money"] += reward_cash(info["Cash"], info["MinCash"])
                    st["speed"] += info["Speed"]
                    if info.get("Egg"):
                        z = best_zone(st["speed"])
                        cid, mut = econ.roll_egg(z, rng, min_rarity=econ.rarity_index["Rare"])
                        add_egg(cid, econ.roll_scale(rng), mut, z, True)
            for q in quests:
                done = {"Steal": steals_today, "Hatch": hatches_today, "Steps": steps_today}.get(q["Key"])
                if done is not None and q["Key"] not in quest_done and done >= q["Goal"]:
                    quest_done.add(q["Key"])
                    st["money"] += reward_cash(q["Minutes"], q["MinCash"])
                    st["speed"] += q["Speed"]
        # compras: sempre a mais barata que dá
        while True:
            options = []
            if st["pen"] < len(econ.pens):
                options.append((econ.pens[st["pen"]], "pen"))
            if st["pen"] >= cfg.get("TreadmillUnlockPen", 1) and st["tread"] < len(econ.treads):
                options.append((econ.treads[st["tread"]][1], "tread"))
            if st["trail"] < len(econ.trails):
                options.append((econ.trails[st["trail"]][1], "trail"))
            if not options:
                break
            price, what = min(options)
            if st["money"] < price:
                break
            st["money"] -= price
            st[what] += 1
        # rebirth
        if kid.rebirth and st["money"] >= econ.rebirth_cost(st["reb"]):
            gz = best_zone(st["speed"])
            log.append((t, "rebirth %d at zone %d" % (st["reb"] + 1, gz)))
            st.update(money=0.0, speed=float(cfg["StartSpeed"]), tread=1, trail=0, reb=st["reb"] + 1)
            slots.clear()
            cid, mut = econ.roll_egg(gz, rng, min_rarity=econ.rarity_index["Rare"])
            add_egg(cid, 1, mut, gz, True)
        # portões
        for z in range(2, nz + 1):
            if z not in reached and st["speed"] >= zones[z - 1]["Speed"]:
                reached[z] = t
                reached_speed[z] = (index_speed_total, tread_speed_total)
        # fim da sessão: offline até o dia seguinte
        if kid.session and session_t >= kid.session * 60:
            away = 86400 - session_t
            if kid.extras:
                st["money"] += math.floor(income() * min(away, cfg.get("OfflineMaxHours", 12) * 3600) * cfg.get("OfflineRate", 0.15))
            clock += away
            session_t = 0
            gift_done.clear()
            phase, left, run_part, streak = "home", 3, 0, 0
        if clock // 86400 != day:
            day = clock // 86400
            steals_today = hatches_today = steps_today = 0
            quest_done.clear()
            if kid.extras and daily:
                claim_daily()
    return {"reached": reached, "split": reached_speed, "log": log, "rebirths": st["reb"], "t": t}


# ---------------------------------------------------------------------------------------------------------
# Tabelas
# ---------------------------------------------------------------------------------------------------------
def fmt_time(seconds):
    if seconds is None:
        return "-"
    m = seconds / 60
    if m < 100:
        return "%.0fm" % m
    return "%.1fh" % (m / 60)


def run_many(econ, reward, kid, runs):
    results = [simulate(econ, reward, kid, seed) for seed in range(1, runs + 1)]
    out = []
    for z in range(1, len(econ.zones) + 1):
        times = [r["reached"].get(z) for r in results]
        done = [x for x in times if x is not None]
        out.append(statistics.median(done) if len(done) * 2 > len(times) else None)
    return out, results


def check_curve(times):
    """Zona 2 <= 8 min, zona 3 <= 20 min, nenhum trecho > 3x o anterior, última zona em dezenas de horas."""
    segs = [None] + [(times[i] - times[i - 1]) if times[i] is not None and times[i - 1] is not None else None for i in range(1, len(times))]
    worst = 0
    for i in range(2, len(segs)):
        if segs[i] and segs[i - 1]:
            worst = max(worst, segs[i] / max(segs[i - 1], 1))
    return segs, worst


def short(n):
    for div, suf in ((1e12, "T"), (1e9, "B"), (1e6, "M"), (1e3, "K")):
        if abs(n) >= div:
            return "%.3g%s" % (n / div, suf)
    return "%.0f" % n


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--config", default=os.path.join(ROOT, "src", "shared", "Config.luau"))
    ap.add_argument("--critters", default=os.path.join(ROOT, "src", "shared", "Critters.luau"))
    ap.add_argument("--runs", type=int, default=12)
    ap.add_argument("--hours", type=float, default=80)
    ap.add_argument("--session", type=float, default=60, help="minutos por dia (0 = sem parar)")
    ap.add_argument("--continuous", action="store_true", help="igual a --session 0")
    ap.add_argument("--duty", type=float, default=0.8)
    ap.add_argument("--nests", type=int, default=3)
    ap.add_argument("--no-extras", action="store_true", help="sem presentes/diário/missões/offline")
    ap.add_argument("--rebirth", action="store_true", help="também roda quem faz rebirth assim que pode")
    ap.add_argument("--formulas", default="v65,none,exp0.6,cap,config")
    ap.add_argument("--verbose", action="store_true")
    args = ap.parse_args()

    cfg = load_config(args.config)
    econ = Econ(cfg, load_critters(args.critters))
    kid = Kid()
    kid.session = 0 if args.continuous else args.session
    kid.duty, kid.nests, kid.extras, kid.hours = args.duty, args.nests, not args.no_extras, args.hours

    table = {
        "v65": reward_v65,
        "none": reward_none,
        "config": reward_config,
        "cap": reward_cap({"Common": 0.02, "Uncommon": 0.03, "Rare": 0.05, "Epic": 0.08, "Legendary": 0.12, "Mythic": 0.18, "Secret": 0.25, "Divine": 0.35, "Celestial": 0.5}, "cap % next gate"),
    }
    chosen = []
    for name in args.formulas.split(","):
        if name.startswith("exp"):
            chosen.append(reward_exponent(float(name[3:])))
        else:
            chosen.append(table[name])

    print("Steal a Critter Egg - progression sim (%d runs, median; %s, duty %.0f%%, best of %d nests%s)" % (
        args.runs, "non-stop" if not kid.session else "%g min/day" % kid.session, kid.duty * 100, kid.nests, "" if kid.extras else ", no extras"))
    for rebirth in ([False, True] if args.rebirth else [False]):
        kid.rebirth = rebirth
        cols = []
        for fn in chosen:
            times, results = run_many(econ, fn, kid, args.runs)
            cols.append((fn.label, times, results))
        print()
        print("REBIRTH ASAP" if rebirth else "NO REBIRTH", "- played time to reach each zone gate (segment = time from previous zone)")
        header = "%-3s %-15s %9s" % ("#", "zone", "gate") + "".join(" | %-22s" % label[:22] for label, _, _ in cols)
        print(header)
        print("-" * len(header))
        segs_all = [check_curve(times) for _, times, _ in cols]
        for z, zone in enumerate(econ.zones, 1):
            row = "%-3d %-15s %9s" % (z, zone["Name"][:15], short(zone["Speed"]))
            for (label, times, _), (segs, _) in zip(cols, segs_all):
                seg = segs[z - 1]
                row += " | %8s %-13s" % (fmt_time(times[z - 1]), ("(+%s)" % fmt_time(seg)) if seg is not None else "")
            print(row)
        row = "%-29s" % "worst segment / previous"
        for _, worst in segs_all:
            row += " | %-22s" % ("x%.1f" % worst)
        print(row)
        if args.verbose:
            for label, times, results in cols:
                r = results[0]
                print("\n[%s] seed 1: speed from Index vs treadmill when each gate was reached" % label)
                for z in sorted(r["split"]):
                    idx, tr = r["split"][z]
                    print("  zone %2d  %8s  index %9s  treadmill %9s" % (z, fmt_time(r["reached"][z]), short(idx), short(tr)))
                for when, what in r["log"]:
                    print("  %8s  %s" % (fmt_time(when), what))
    print()
    print("Index speed per discovery (Uncommon / Legendary) vs the NEXT gate:")
    print("%-3s %9s" % ("#", "next") + "".join(" | %-22s" % fn.label[:22] for fn in chosen))
    probe = {}
    for z, pool in enumerate(econ.pools, 1):
        for rarity in ("Uncommon", "Legendary"):
            probe[(z, rarity)] = (pool.get(rarity) or [None])[0]
    for z in range(1, len(econ.zones) + 1):
        row = "%-3d %9s" % (z, short(next_gate(econ, z)))
        for fn in chosen:
            parts = []
            for rarity in ("Uncommon", "Legendary"):
                cid = probe[(z, rarity)]
                parts.append(short(fn(econ, cid, z)) if cid else "-")
            row += " | %-22s" % " / ".join(parts)
        print(row)


if __name__ == "__main__":
    sys.exit(main())
