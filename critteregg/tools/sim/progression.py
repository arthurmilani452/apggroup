#!/usr/bin/env python3
"""
SIMULADOR DE PROGRESSÃO do Steal a Critter Egg (só Python 3, sem bibliotecas de fora).

    python3 tools/sim/progression.py                  # tabelas: tempo JOGADO até cada zona, v65 x candidatas x NOVA
    python3 tools/sim/progression.py --runs 30        # mais sementes (mais lento, mais estável)
    python3 tools/sim/progression.py --continuous     # jogando sem parar (sem sessões de 1 h por dia)
    python3 tools/sim/progression.py --no-rebirth     # só a tabela de quem nunca faz rebirth
    python3 tools/sim/progression.py --scenarios v65,new --verbose   # + de onde veio a velocidade em cada portão
    python3 tools/sim/progression.py --weekly         # chance do Bicho da Semana na zona dele (com/sem o boost)

CENÁRIOS (colunas)
  v65        números da v65 (antes): Index = IndexSpeed * Mult^0.75, esteira 5,5x por nível, zona 9 em 620M,
             RebirthTread 0.25. São os números ATUAIS do Config com estes 5 itens trocados pelos antigos
             (V65 abaixo), para a comparação continuar valendo se outras coisas do Config mudarem.
  v65+exp    v65 trocando só o expoente do Index (Mult^0.6): a "menor mudança possível".
  v65+share  v65 trocando só a fórmula do Index pela nova (fatia do caminho até o próximo portão).
  new        o Config.luau como está (a proposta).

DE ONDE VÊM OS NÚMEROS
  * LIDOS do src/shared/Config.luau (parser de tabelas Luau abaixo): Rarities, Mutations, Zones (Speed, MinSpeed,
    Mult, Pool, Rarities), RarityIncome, IndexSpeed, IndexShare, Trails, Gifts, Daily, Quests, PenStartSlots,
    StartSpeed, WalkCap, Cycle/Night/NightGrowth, FirstEggSeconds, TreadmillUnlockPen, TreadmillRamp, Treadmill
    (sequência da esteira), StealStreak, Rebirth*, Offline*, Lucky*, Weekly*, Map.LaneLength/PlotZ, e os números das
    fórmulas da esteira e do cercado (lidos das linhas "Gain = ..." / "Cost = ..." dos loops).
  * LIDOS do src/shared/Critters.luau: Id, Rarity e World de cada bichinho (Soon = fora; os do WEEKLY = mundo "weekly").
  * DUPLICADOS aqui (mudou a fórmula no Luau? mude aqui também): RollScale, SizeFactor, BaseIncome (hash do Id),
    PetIncome, GrowSeconds, WalkSpeed, EscapeSpeed, RebirthCost, NextGate, IndexReward (v65 e a nova), rollEgg,
    WeeklyCritter/WeeklyBoostFor. O tests/config_spec.luau confere os números do IndexReward novo com os de cá.

O "JOGADOR TÍPICO" (criança no celular), passo de 1 segundo:
  * rouba 1 ovo a cada 60-90 s da MELHOR zona liberada (Speed >= portão), escolhendo o melhor dos --nests ovos que
    vê e que consegue levar (EscapeSpeed); 10% das vezes leva bastão/armadilha e perde o ovo;
  * o resto do tempo fica em casa: --duty dele correndo na esteira (o resto é olhar o cercado, chocar, menus).
    A sequência da esteira (Config.Treadmill) zera quando ela sai da esteira por mais de StreakGrace s;
  * ovo cresce Config.GrowSeconds (noite: últimos Night s de cada ciclo, x NightGrowth); choca na hora;
  * bichinho novo -> Index -> resgata o prêmio na hora (dinheiro + velocidade);
  * compra sempre a coisa mais barata que dá (cercado, esteira, trilha); cercado cheio = vende o pior bichinho;
  * a cada StealStreak.Every roubos seguidos ganha StealStreak.Minutes da renda;
  * joga 1 sessão de --session minutos por dia: presentes por tempo (zeram depois de 3 h fora), prêmio diário
    (sequência de 7 dias + calendário de 28 dias da v67: boosts 2x e bichinhos exclusivos que ficam no rebirth e
    rendem pela zona de agora), missões do dia (menos a de PvP) e dinheiro offline. O tempo das tabelas é tempo JOGADO
    (minutos de tela), não dias de calendário. Sem baú do grupo, sem Robux, sem amigos, sem fim de semana x2.
  * rebirth: "nunca" ou "assim que tem o dinheiro" (o que a criança faz quando o botão acende).
"""
import argparse
import copy
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
    num = lambda s: float(s.replace("_", ""))
    # esteira: Gain = math.floor(A * B ^ (level - 1) + 0.5)
    #          Cost = if level == 1 then 0 else math.floor(C * D ^ (level - 2) [* Config.TreadmillRamp ^ math.max(0, level - K)])
    gain = need(re.search(r"Gain = math\.floor\(([\d_.]+) \* ([\d_.]+) \^ \(level - 1\) \+ 0\.5\)", src), "treadmill Gain")
    cost = need(re.search(r"Cost = if level == 1 then 0 else math\.floor\(([\d_.]+) \* ([\d_.]+) \^ \(level - 2\)"
                          r"(?: \* Config\.TreadmillRamp \^ math\.max\(0, level - (\d+)\))?\)", src), "treadmill Cost")
    names = env.get("TREAD_NAMES")
    need(isinstance(names, list), "TREAD_NAMES")
    cfg["_TreadFormula"] = (num(gain.group(1)), num(gain.group(2)), num(cost.group(1)), num(cost.group(2)),
                            int(cost.group(3)) if cost.group(3) else None, len(names))
    pen = need(re.search(r"for level = 1, (\d+) do\s*\n\s*table\.insert\(Config\.PenLevels, \{ Cost = math\.floor\(([\d_.]+) \* ([\d_.]+) \^ \(level - 1\)\) \}\)", src), "PenLevels loop")
    pens = [math.floor(num(pen.group(2)) * num(pen.group(3)) ** (lv - 1)) for lv in range(1, int(pen.group(1)) + 1)]
    first = re.search(r"Config\.PenLevels\[1\]\.Cost = ([\d_]+)", src)
    if first:
        pens[0] = int(num(first.group(1)))
    cfg["_PenCosts"] = pens
    for key in ("Rarities", "Zones", "RarityIncome", "IndexSpeed", "Trails", "Mutations", "StartSpeed", "PenStartSlots", "NightGrowth"):
        need(key in cfg, "Config." + key)
    return cfg


def treadmills(cfg):
    """Config.Treadmills: [(Gain, Cost)] por nível."""
    ga, gb, ca, cb, knee, levels = cfg["_TreadFormula"]
    ramp = cfg.get("TreadmillRamp", 1) if knee else 1
    out = []
    for lv in range(1, levels + 1):
        g = math.floor(ga * gb ** (lv - 1) + 0.5)
        c = 0 if lv == 1 else math.floor(ca * cb ** (lv - 2) * ramp ** max(0, lv - (knee or 0)))
        out.append((g, c))
    return out


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
        name = re.search(r"Name = \"([^\"]+)\"", line)
        out.append({"Id": m.group(1), "Rarity": rarity.group(1), "World": world, "Name": name.group(1) if name else m.group(1)})
    return out


# ---------------------------------------------------------------------------------------------------------
# Fórmulas (DUPLICADAS do Config.luau / Game.luau)
# ---------------------------------------------------------------------------------------------------------
class Econ:
    def __init__(self, cfg, critters):
        self.cfg = cfg
        self.rarities = cfg["Rarities"]
        self.rarity_index = {r["Name"]: i + 1 for i, r in enumerate(self.rarities)}
        self.rarity = {r["Name"]: r for r in self.rarities}
        self.zones = cfg["Zones"]
        self.treads = treadmills(cfg)
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

    @staticmethod
    def roll_scale(rng):  # Config.RollScale
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

    def zone_index(self, z):
        return z if z and 1 <= z <= len(self.zones) else 1

    def base_income(self, cid, z):
        zone = self.zones[self.zone_index(z) - 1]
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

    def next_gate(self, z):  # Config.NextGate
        z = self.zone_index(z)
        if z < len(self.zones):
            return self.zones[z]["Speed"]
        return self.zones[z - 1]["Speed"] * 3

    def roll_mut(self, rng):
        m = rng.random() * 100
        for name, chance, _ in self.muts:
            if m < chance:
                return name
            m -= chance
        return None

    def rarity_weights(self, z, lucky=False, min_rarity=1, weekly=None):
        """Pesos das raridades no rollEgg. weekly = (id, multiplicador da raridade) ou None."""
        pool = self.pools[z - 1]
        options = []
        for rarity in self.zones[z - 1]["Rarities"]:
            if rarity in pool and self.rarity_index[rarity] >= min_rarity:
                w = self.rarity[rarity]["Weight"]
                if lucky and self.rarity_index[rarity] >= self.rarity_index["Legendary"]:
                    w *= self.cfg.get("LuckyMult", 3)
                if weekly and weekly[0] in pool[rarity]:
                    w *= weekly[1]
                options.append((rarity, w))
        return options

    def roll_egg(self, z, rng, lucky=False, min_rarity=1, weekly=None, weekly_mult=1):
        """rollEgg do Game.luau (sem Festão/Halloween/admin)."""
        options = self.rarity_weights(z, lucky, min_rarity, weekly)
        roll = rng.random() * sum(w for _, w in options)
        chosen = options[-1][0]
        for rarity, w in options:
            roll -= w
            if roll <= 0:
                chosen = rarity
                break
        ids = self.pools[z - 1][chosen]
        weights = [weekly_mult if weekly and i == weekly[0] else 1 for i in ids]
        pick = rng.random() * sum(weights)
        cid = ids[-1]
        for i, w in zip(ids, weights):
            pick -= w
            if pick <= 0:
                cid = i
                break
        return cid, self.roll_mut(rng)


# ---------------------------------------------------------------------------------------------------------
# Prêmio de VELOCIDADE do Index (o que está em teste)
# ---------------------------------------------------------------------------------------------------------
def reward_v65(econ, cid, z):
    rarity = econ.by_id[cid]["Rarity"]
    return math.floor(econ.cfg["IndexSpeed"].get(rarity, 100) * max(1, econ.zones[econ.zone_index(z) - 1]["Mult"] ** 0.75))


def reward_exp(e):
    def fn(econ, cid, z):
        rarity = econ.by_id[cid]["Rarity"]
        return math.floor(econ.cfg["IndexSpeed"].get(rarity, 100) * max(1, econ.zones[econ.zone_index(z) - 1]["Mult"] ** e))
    return fn


def reward_new(econ, cid, z):
    """Config.IndexSpeedReward (v66): max(IndexSpeed[r], IndexShare[r] * (NextGate(z) - portão da zona z))."""
    rarity = econ.by_id[cid]["Rarity"]
    share = econ.cfg["IndexShare"]
    base = econ.cfg["IndexSpeed"]
    path = econ.next_gate(z) - econ.zones[econ.zone_index(z) - 1]["Speed"]
    return math.floor(max(base.get(rarity, base["Common"]), share.get(rarity, share["Common"]) * path))


# números da v65 (antes) que a proposta mudou; o resto vem do Config atual
V65 = {
    "IndexSpeed": {"Common": 120, "Uncommon": 260, "Rare": 420, "Epic": 720, "Legendary": 1500, "Mythic": 4000, "Secret": 12000, "Divine": 40000, "Celestial": 150000},
    "TreadmillRamp": 1,
    "RebirthTread": 0.25,
    "_zones": {"cosmic": {"Speed": 620e6, "MinSpeed": 245e6}},
}


def make_econ(cfg, critters, overrides=None):
    cfg = copy.deepcopy(cfg)
    for key, value in (overrides or {}).items():
        if key == "_zones":
            for zone in cfg["Zones"]:
                zone.update(value.get(zone["Id"], {}))
        else:
            cfg[key] = value
    return Econ(cfg, critters)


def scenarios(cfg, critters):
    v65 = make_econ(cfg, critters, V65)
    out = {
        "v65": ("v65 (before)", v65, reward_v65),
        "v65+exp": ("v65 + Mult^0.6", v65, reward_exp(0.6)),
        "new": ("NEW (Config)", make_econ(cfg, critters), reward_new),
    }
    if "IndexShare" in cfg:
        out["v65+share"] = ("v65 + new Index only", make_econ(cfg, critters, dict(V65, IndexSpeed=cfg["IndexSpeed"])), reward_new)
    return out


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
    hours = 100  # tempo máximo jogado


def simulate(econ, reward, kid, seed):
    cfg = econ.cfg
    rng = random.Random(seed)
    zones = econ.zones
    nz = len(zones)
    cycle, night_len, night_mult = cfg.get("Cycle", 300), cfg.get("Night", 10), cfg["NightGrowth"]
    lane, plot_z = cfg["Map"]["LaneLength"], abs(cfg["Map"]["PlotZ"])
    lucky_every, lucky_len = cfg.get("LuckyEvery", 1800), cfg.get("LuckyLength", 180)
    streak_cfg = cfg.get("Treadmill") if isinstance(cfg.get("Treadmill"), dict) else None
    steal_streak = cfg.get("StealStreak") if isinstance(cfg.get("StealStreak"), dict) else None
    gifts, daily, quests = cfg.get("Gifts", []), cfg.get("Daily", []), cfg.get("Quests", [])
    unlock_pen = cfg.get("TreadmillUnlockPen", 1)

    st = {"money": 0.0, "speed": float(cfg["StartSpeed"]), "pen": 0, "tread": 1, "trail": 0, "reb": 0}
    slots = []
    index, claimed = {}, set()
    reached, snaps, log = {1: 0}, {}, []
    t = 0  # segundos JOGADOS
    clock = 6 * 3600  # relógio de verdade (noite, evento da sorte, troca de dia)
    session_t = 0
    phase, left, run_part, trip, trip_len = "home", 3, 0, None, 0
    run_streak, off_belt, steals_in_row = 0, 0, 0
    today = {"steal": 0, "hatch": 0, "steps": 0}
    quest_done, gift_done = set(), set()
    day = clock // 86400
    daily_streak = 0
    # v67 calendário de 28 dias (Config.Calendar): boosts (relógio de verdade) e bichinhos exclusivos (Keep)
    calendar = {int(k): v for k, v in (cfg.get("Calendar") or {}).items()} if kid.extras else {}
    cal_days = int(cfg.get("CalendarDays", 28))
    gold_after = int(cfg.get("CalendarGoldAfter", 1))
    daily_total = 0
    boost_until = {"Money2": 0, "Tread2": 0}
    first_keep_day = min([d for d, v in calendar.items() if v.get("Critter")] or [10 ** 9])
    first_egg = True
    from_index = from_tread = 0.0

    def slot_cap():
        return cfg["PenStartSlots"] + st["pen"]

    def income():
        return sum(s["inc"] for s in slots if s["left"] <= 0) * (1 + cfg["RebirthMoney"] * st["reb"])

    def best_zone():
        best = 1
        for z, zone in enumerate(zones, 1):
            if st["speed"] >= zone["Speed"]:
                best = z
        return best

    def add_ready_egg(z, scale=None):  # addEggSlot(..., ready = true) com ovo Raro+ da melhor zona
        cid, mut = econ.roll_egg(z, rng, min_rarity=econ.rarity_index["Rare"])
        s = econ.roll_scale(rng) if scale is None else scale
        if len(slots) >= slot_cap():
            st["money"] += math.floor(econ.pet_income(cid, s, mut, z) * 100) * 10
        else:
            slots.append({"id": cid, "s": s, "mut": mut, "z": z, "left": 0, "inc": econ.pet_income(cid, s, mut, z), "fresh": True})

    def minutes_cash(minutes, min_cash):
        return max(min_cash, math.floor(income() * 60 * minutes))

    def claim_daily():
        nonlocal daily_streak, daily_total
        daily_streak = daily_streak % len(daily) + 1
        info = daily[daily_streak - 1]
        st["money"] += minutes_cash(info["Minutes"], info["MinCash"])
        st["speed"] += info["Speed"]
        if info.get("Egg"):
            add_ready_egg(best_zone())
        # v67 calendário (claimDaily do Game.luau): conta todos os dias pegos
        daily_total += 1
        cal = calendar.get((daily_total - 1) % cal_days + 1)
        if cal:
            for bid, minutes in (cal.get("Boost") or {}).items():
                if bid in boost_until:
                    boost_until[bid] = max(clock, boost_until[bid]) + minutes * 60
            cid = cal.get("Critter")
            if cid in econ.by_id:
                mut = "Gold" if (daily_total - 1) // cal_days >= gold_after else None
                if len(slots) >= slot_cap():  # cercado cheio: no jogo ele espera vaga; aqui a criança vende o pior
                    pets = [x for x in slots if x["left"] <= 0 and not x.get("keep")]
                    if pets:
                        worst = min(pets, key=lambda x: x["inc"])
                        slots.remove(worst)
                        st["money"] += math.floor(worst["inc"] * 100)
                if len(slots) < slot_cap():
                    z = best_zone()
                    slots.append({"id": cid, "s": 1, "mut": mut, "z": z, "left": 0, "inc": econ.pet_income(cid, 1, mut, z), "keep": True})

    def discover(slot):
        nonlocal from_index
        cid, z = slot["id"], slot["z"]
        if cid not in index:
            index[cid] = min(econ.natural.get(cid, z), z)
        if cid not in claimed:
            claimed.add(cid)
            sp = reward(econ, cid, index[cid])
            st["money"] += math.floor(econ.base_income(cid, index[cid]) * 100)
            st["speed"] += sp
            from_index += sp

    if kid.extras and daily:
        claim_daily()

    limit = int(kid.hours * 3600)
    while t < limit and len(reached) < nz:
        t += 1
        clock += 1
        session_t += 1
        # ovos crescem e chocam (os prontos de presente chocam na hora)
        growth = night_mult if clock % cycle >= cycle - night_len else 1
        for slot in slots:
            if slot["left"] > 0:
                slot["left"] -= growth
                if slot["left"] <= 0:
                    today["hatch"] += 1
                    discover(slot)
            elif slot.get("fresh"):
                slot["fresh"] = False
                today["hatch"] += 1
                discover(slot)
        st["money"] += income() * (2 if boost_until["Money2"] > clock else 1)
        # atividade: em casa (esteira) ou numa viagem de roubo
        left -= 1
        on_belt = phase == "home" and left < run_part and st["pen"] >= unlock_pen
        if on_belt:
            run_streak += 1
            off_belt = 0
            gain, _ = econ.treads[st["tread"] - 1]
            mult = econ.trails[st["trail"] - 1][0] if st["trail"] else 1
            gain = math.floor(gain * mult * (2 if boost_until["Tread2"] > clock else 1) * (1 + cfg["RebirthTread"] * st["reb"]))  # computeGain
            if streak_cfg:
                gain = math.floor(gain * (1 + min((run_streak // streak_cfg["StreakEvery"]) * streak_cfg["StreakStep"], streak_cfg["StreakMax"])))
            st["speed"] += gain
            from_tread += gain
            today["steps"] += 1
        else:
            off_belt += 1
            if streak_cfg and off_belt > streak_cfg["StreakGrace"]:
                run_streak = 0
        if left <= 0:
            if phase == "trip":
                z, (cid, s, mut) = trip
                if rng.random() < kid.success:
                    inc = econ.pet_income(cid, s, mut, z)
                    if len(slots) >= slot_cap():
                        pets = [x for x in slots if x["left"] <= 0 and not x.get("keep")]
                        worst = min(pets, key=lambda x: x["inc"]) if pets else None
                        if worst and worst["inc"] < inc:
                            slots.remove(worst)
                            st["money"] += math.floor(worst["inc"] * 100)
                    if len(slots) < slot_cap():
                        grow = econ.grow_seconds(cid, s)
                        if first_egg:
                            grow = min(grow, cfg.get("FirstEggSeconds", 5))
                            first_egg = False
                        slots.append({"id": cid, "s": s, "mut": mut, "z": z, "left": max(grow, 1), "inc": inc})
                        today["steal"] += 1
                        steals_in_row += 1
                        if steal_streak and steals_in_row % steal_streak["Every"] == 0:
                            st["money"] += minutes_cash(steal_streak["Minutes"], steal_streak["MinCash"])
                else:
                    steals_in_row = 0
                phase = "home"
                left = max(3, int(rng.uniform(*kid.period) - trip_len))
                run_part = int(left * kid.duty)
            else:
                z = best_zone()
                lucky = clock % lucky_every < lucky_len
                options = []
                for _ in range(kid.nests):
                    cid, mut = econ.roll_egg(z, rng, lucky)
                    s = econ.roll_scale(rng)
                    if z == 1 or econ.escape(z, s) <= st["speed"]:
                        options.append((econ.pet_income(cid, s, mut, z), cid, s, mut))
                eggs_only = sum(1 for x in slots if x["left"] > 0) >= slot_cap()
                if options and not eggs_only:
                    _, cid, s, mut = max(options)
                    trip = (z, (cid, s, mut))
                    trip_len = 2 * (plot_z + (z - 0.5) * lane) / econ.walk(st["speed"]) + 8
                    phase, left = "trip", max(1, int(trip_len))
                else:
                    phase, left, trip_len = "home", int(rng.uniform(*kid.period)), 0
                    run_part = int(left * kid.duty)
        # presentes por tempo jogado na sessão + missões do dia
        if kid.extras:
            for gi, info in enumerate(gifts):
                if gi not in gift_done and session_t >= info["Minutes"] * 60:
                    gift_done.add(gi)
                    st["money"] += minutes_cash(info["Cash"], info["MinCash"])
                    st["speed"] += info["Speed"]
                    if info.get("Egg"):
                        add_ready_egg(best_zone())
            for q in quests:
                done = {"Steal": today["steal"], "Hatch": today["hatch"], "Steps": today["steps"]}.get(q["Key"])
                if done is not None and q["Key"] not in quest_done and done >= q["Goal"]:
                    quest_done.add(q["Key"])
                    st["money"] += minutes_cash(q["Minutes"], q["MinCash"])
                    st["speed"] += q["Speed"]
        # compras: sempre a mais barata que dá
        while True:
            options = []
            if st["pen"] < len(econ.pens):
                options.append((econ.pens[st["pen"]], "pen"))
            if st["pen"] >= unlock_pen and st["tread"] < len(econ.treads):
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
        # rebirth assim que dá (zera dinheiro, velocidade, esteira, trilhas e bichinhos; ganha 1 ovo Raro+ pronto)
        if kid.rebirth and st["money"] >= econ.rebirth_cost(st["reb"]):
            gz = best_zone()
            log.append((t, "rebirth %d at zone %d" % (st["reb"] + 1, gz)))
            st.update(money=0.0, speed=float(cfg["StartSpeed"]), tread=1, trail=0, reb=st["reb"] + 1)
            slots[:] = [x for x in slots if x.get("keep")]  # (v67: exclusivos do calendário ficam)
            add_ready_egg(gz, 1)
        # v67: exclusivo do calendário rende pela zona que a velocidade de agora alcança (slotZone do Game.luau)
        if daily_total >= first_keep_day:
            bz = best_zone()
            for x in slots:
                if x.get("keep") and x["z"] != bz:
                    x["z"], x["inc"] = bz, econ.pet_income(x["id"], x["s"], x["mut"], bz)
        for z in range(2, nz + 1):
            if z not in reached and st["speed"] >= zones[z - 1]["Speed"]:
                reached[z] = t
                snaps[z] = {"index": from_index, "tread": from_tread, "level": st["tread"], "trail": st["trail"],
                            "pen": st["pen"], "income": income(), "reb": st["reb"]}
        # fim da sessão: offline até o dia seguinte (presentes zeram, dia novo)
        if kid.session and session_t >= kid.session * 60:
            away = 86400 - session_t
            if kid.extras:
                st["money"] += math.floor(income() * min(away, cfg.get("OfflineMaxHours", 12) * 3600) * cfg.get("OfflineRate", 0.15))
            clock += away
            session_t = 0
            gift_done.clear()
            phase, left, run_part, run_streak = "home", 3, 0, 0
        if clock // 86400 != day:
            day = clock // 86400
            today = {"steal": 0, "hatch": 0, "steps": 0}
            quest_done.clear()
            if kid.extras and daily:
                claim_daily()
    return {"reached": reached, "snaps": snaps, "log": log, "rebirths": st["reb"], "t": t}


# ---------------------------------------------------------------------------------------------------------
# Bicho da Semana (Config.WeeklyCritter / WeeklyBoostFor + rollEgg)
# ---------------------------------------------------------------------------------------------------------
def weekly_chance(econ, cid, rarity_mult, pick_mult):
    """Chance de 1 ovo da zona do bichinho ser ele (sem evento da sorte)."""
    z = econ.natural.get(cid)
    if not z:
        return None, 0.0
    options = econ.rarity_weights(z, weekly=(cid, rarity_mult))
    total = sum(w for _, w in options)
    rarity = econ.by_id[cid]["Rarity"]
    w = dict(options).get(rarity, 0)
    ids = econ.pools[z - 1][rarity]
    return z, (w / total) * (pick_mult / (len(ids) - 1 + pick_mult))


V65_WEEKLY = ["divineunicorn", "celestialdragon", "cosmoking", "goldengoober", "solarking"]


def weekly_report(econ):
    cfg = econ.cfg
    pick = cfg.get("WeeklyMult", 5)
    boost = cfg.get("WeeklyRarityMult", 1)
    print("CRITTER OF THE WEEK - chance that ONE egg in its zone is the weekly critter")
    print("  normal = no event; v65 rule = x%g inside its rarity only; NEW = also x%g on its rarity (WeeklyBoostFor)" % (pick, boost))
    print("%-4s %-18s %-10s %-14s %9s %9s %9s %6s" % ("week", "critter", "rarity", "zone", "normal", "v65 rule", "NEW", "gain"))

    def row(week, cid, rarity_mult):
        if cid not in econ.by_id:
            print("%-4s %-18s MISSING in Critters.luau" % (week, cid))
            return
        z, normal = weekly_chance(econ, cid, 1, 1)
        _, old = weekly_chance(econ, cid, 1, pick)
        _, new = weekly_chance(econ, cid, rarity_mult, pick)
        zone = econ.zones[z - 1]["Name"] if z else "(no zone!)"
        print("%-4s %-18s %-10s %-14s %8.3f%% %8.3f%% %8.3f%% %5.1fx" % (week, econ.by_id[cid]["Name"][:18], econ.by_id[cid]["Rarity"], zone[:14],
                                                                 normal * 100, old * 100, new * 100, new / normal if normal else 0))

    for week, cid in enumerate(cfg.get("WeeklyCritters", []), 1):
        row(week, cid, boost)
    print("v65 list (zone 1, alone in their rarity, so the x%g did nothing):" % pick)
    for cid in V65_WEEKLY:
        row("old", cid, 1)


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


def short(n):
    for div, suf in ((1e12, "T"), (1e9, "B"), (1e6, "M"), (1e3, "K")):
        if abs(n) >= div:
            return "%.3g%s" % (n / div, suf)
    return "%.0f" % n


def run_many(econ, reward, kid, runs):
    results = [simulate(econ, reward, kid, seed) for seed in range(1, runs + 1)]
    times = []
    for z in range(1, len(econ.zones) + 1):
        done = [r["reached"][z] for r in results if z in r["reached"]]
        times.append(statistics.median(done) if len(done) * 2 > len(results) else None)
    return times, results


def segments(times):
    return [None] + [times[i] - times[i - 1] if times[i] is not None and times[i - 1] is not None else None for i in range(1, len(times))]


def worst_ratio(times, first=3):
    """Maior (tempo da zona k) / (tempo da zona k-1), para k >= first."""
    segs = segments(times)
    worst, where = 0.0, None
    for k in range(first - 1, len(segs)):
        if segs[k] and segs[k - 1]:
            r = segs[k] / max(segs[k - 1], 1)
            if r > worst:
                worst, where = r, k + 1
    return worst, where


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--config", default=os.path.join(ROOT, "src", "shared", "Config.luau"))
    ap.add_argument("--critters", default=os.path.join(ROOT, "src", "shared", "Critters.luau"))
    ap.add_argument("--runs", type=int, default=10)
    ap.add_argument("--hours", type=float, default=100, help="para de simular depois disso (tempo jogado)")
    ap.add_argument("--session", type=float, default=60, help="minutos jogados por dia (0 = sem parar)")
    ap.add_argument("--continuous", action="store_true", help="igual a --session 0")
    ap.add_argument("--duty", type=float, default=Kid.duty)
    ap.add_argument("--nests", type=int, default=Kid.nests)
    ap.add_argument("--no-extras", action="store_true", help="sem presentes/diário/missões/offline")
    ap.add_argument("--no-rebirth", action="store_true", help="não roda a tabela de quem faz rebirth")
    ap.add_argument("--scenarios", default="v65,v65+exp,v65+share,new")
    ap.add_argument("--weekly", action="store_true", help="só a tabela do Bicho da Semana")
    ap.add_argument("--verbose", action="store_true")
    args = ap.parse_args()

    cfg = load_config(args.config)
    critters = load_critters(args.critters)
    if args.weekly:
        weekly_report(make_econ(cfg, critters))
        return 0
    table = scenarios(cfg, critters)
    chosen = [table[name] for name in args.scenarios.split(",") if name in table]
    kid = Kid()
    kid.session = 0 if args.continuous else args.session
    kid.duty, kid.nests, kid.extras, kid.hours = args.duty, args.nests, not args.no_extras, args.hours

    print("Steal a Critter Egg - progression sim: median of %d kids, %s, treadmill %d%% of home time, best of %d nests%s" % (
        args.runs, "non-stop" if not kid.session else "%g min/day" % kid.session, kid.duty * 100, kid.nests, "" if kid.extras else ", no gifts/daily"))
    finals = {}
    for rebirth in ([False] if args.no_rebirth else [False, True]):
        kid.rebirth = rebirth
        cols = []
        for label, econ, fn in chosen:
            times, results = run_many(econ, fn, kid, args.runs)
            cols.append((label, econ, times, results))
            finals[(label, rebirth)] = times[-1]
        print()
        print(("REBIRTH AS SOON AS AFFORDABLE" if rebirth else "NEVER REBIRTHS") + " - played time to reach each zone gate (+time since the previous zone)")
        header = "%-3s %-14s" % ("#", "zone") + "".join(" | %-22s" % label[:22] for label, _, _, _ in cols)
        print(header)
        print("-" * len(header))
        for z in range(1, len(cols[0][1].zones) + 1):
            row = "%-3d %-14s" % (z, cols[0][1].zones[z - 1]["Name"][:14])
            for label, econ, times, _ in cols:
                seg = segments(times)[z - 1]
                gate = short(econ.zones[z - 1]["Speed"])
                row += " | %-5s %6s %-9s" % (gate, fmt_time(times[z - 1]), ("+%s" % fmt_time(seg)) if seg is not None else "")
            print(row)
        row = "%-18s" % "worst zone/prev."
        for _, _, times, _ in cols:
            worst, where = worst_ratio(times)
            row += " | %-22s" % ("x%.1f (zone %s)" % (worst, where) if where else "-")
        print(row)
        if args.verbose:
            for label, _, times, results in cols:
                r = results[0]
                print("\n[%s] kid #1: where the speed came from at each gate" % label)
                for z in sorted(r["snaps"]):
                    s = r["snaps"][z]
                    print("  zone %2d %7s  Index %8s  treadmill %8s  tread L%-2d trail %d pen %-2d income %8s/s  rebirths %d" % (
                        z, fmt_time(r["reached"][z]), short(s["index"]), short(s["tread"]), s["level"], s["trail"], s["pen"], short(s["income"]), s["reb"]))
                for when, what in r["log"]:
                    print("  %8s  %s" % (fmt_time(when), what))
    if not args.no_rebirth:
        print()
        print("Rebirth worth it? time to the LAST zone, rebirth-asap vs never:")
        for label, _, _ in chosen:
            a, b = finals.get((label, True)), finals.get((label, False))
            if a and b:
                print("  %-22s %7s vs %7s  (%+.0f%%)" % (label, fmt_time(a), fmt_time(b), (a / b - 1) * 100))
    print()
    print("Index speed for ONE new critter (Uncommon / Legendary), and as % of the NEXT zone's gate in that scenario:")
    print("%-3s" % "#" + "".join(" | %-30s" % label[:30] for label, _, _ in chosen))
    for z in range(1, len(chosen[0][1].zones) + 1):
        row = "%-3d" % z
        for _, econ, fn in chosen:
            values = []
            for rarity in ("Uncommon", "Legendary"):
                ids = econ.pools[z - 1].get(rarity)
                values.append(fn(econ, ids[0], z) if ids else None)
            gate = econ.next_gate(z)
            text = " / ".join(short(v) if v is not None else "-" for v in values)
            pct = " / ".join("%.0f%%" % (v / gate * 100) if v is not None else "-" for v in values)
            row += " | %-30s" % ("%s (%s)" % (text, pct))
        print(row)
    return 0


if __name__ == "__main__":
    sys.exit(main())
