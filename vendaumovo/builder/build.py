#!/usr/bin/env python3
"""
Monta o arquivo do jogo VENDA UM OVO (vendaumovo/place/VendaUmOvo.rbxlx) sem abrir o Studio:
  - ReplicatedStorage/Assets: um Model por objeto (ovos, aves, ninho, banca...), feitos de peças,
    seguindo as cores das referências em vendaumovo/arte/. Troque pelo 3D de verdade mantendo o nome.
  - O mapa: uma ilha flutuante. No centro o celeiro, o silo e o ovo dourado; em volta, dois anéis de
    estrada com as lojas no meio; 12 granjas em círculo (cada banca virada para a estrada, estilo
    barraquinha de limonada); na borda lagos com ponte, moinho no morro, rotatória e pinheiros.
  - Iluminação e todos os scripts de vendaumovo/src.

    python3 vendaumovo/builder/build.py
"""
import math
import os
import random
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
sys.path.insert(0, os.path.join(os.path.dirname(ROOT), "tools"))

from rbxlx import CF, Color, Color8, Inst, Int, Token, UDim2, V3, scripts_from_dir, write_place  # noqa: E402

rng = random.Random(20261005)  # mapa sempre igual (mude o número para outro sorteio de enfeites)

M = {
    "Plastic": 256, "Smooth": 272, "Neon": 288, "Wood": 512, "WoodPlanks": 528, "Marble": 784,
    "Slate": 800, "Concrete": 816, "Granite": 832, "Brick": 848, "Pebble": 864, "Cobblestone": 880,
    "Rock": 896, "Sandstone": 912, "Metal": 1088, "Grass": 1280, "LeafyGrass": 1284, "Sand": 1296,
    "Fabric": 1312, "Ground": 1360, "Asphalt": 1376, "Glass": 1568,
}
BALL, BLOCK, CYL = 0, 1, 2
FRONT, BACK = 5, 2  # Enum.NormalId
FONT_FREDOKA = 26  # Enum.Font.FredokaOne
SIZING_PPS = 1

part_count = 0


# ---------------------------------------------------------------------------
# Matemática de giro (mesma convenção do CFrame.Angles do Roblox)
# ---------------------------------------------------------------------------
def mat_angles(rx, ry, rz):
    return CF.angles(0, 0, 0, rx, ry, rz).r


def mat_mul(a, b):
    out = []
    for i in range(3):
        for j in range(3):
            out.append(sum(a[i * 3 + k] * b[k * 3 + j] for k in range(3)))
    return tuple(out)


def mat_vec(a, v):
    return tuple(sum(a[i * 3 + k] * v[k] for k in range(3)) for i in range(3))


class Xf:
    """Onde um modelo vai no mundo: base (x, y, z), giro em Y (graus) e escala."""

    def __init__(self, x=0.0, y=0.0, z=0.0, yaw=0.0, scale=1.0):
        self.p = (x, y, z)
        self.yaw = yaw
        self.s = scale
        self.r = mat_angles(0, math.radians(yaw), 0)

    def cf(self, lx, ly, lz, rx=0.0, ry=0.0, rz=0.0):
        local_r = mat_angles(math.radians(rx), math.radians(ry), math.radians(rz))
        wr = mat_mul(self.r, local_r)
        off = mat_vec(self.r, (lx * self.s, ly * self.s, lz * self.s))
        return CF(self.p[0] + off[0], self.p[1] + off[1], self.p[2] + off[2], wr)


class Builder:
    """Junta as peças de um modelo usando coordenadas locais (base no chão, frente para -Z)."""

    def __init__(self, model, xf, collide=True):
        self.model = model
        self.xf = xf
        self.collide = collide

    def add(self, name, size, pos, color, material="Smooth", shape=None, rot=(0, 0, 0), mesh=None,
            transparency=0.0, collide=None, reflect=0.0, neon=False, parent=None, **extra):
        global part_count
        part_count += 1
        s = self.xf.s
        props = dict(
            Anchored=True,
            Size=V3(size[0] * s, size[1] * s, size[2] * s),
            CFrame=self.xf.cf(pos[0], pos[1], pos[2], *rot),
            Color=Color8(*color),
            Material=Token(M["Neon" if neon else material]),
            TopSurface=Token(0),
            BottomSurface=Token(0),
        )
        if shape is not None:
            props["Shape"] = Token(shape)
        c = self.collide if collide is None else collide
        if not c:
            props["CanCollide"] = False
            props["CanTouch"] = False
        if transparency:
            props["Transparency"] = float(transparency)
        if reflect:
            props["Reflectance"] = float(reflect)
        attrs = {}
        if "Tex" in extra:
            attrs["Tex"] = extra.pop("Tex")  # textura do Config.Textures (aplicada pelo servidor)
        props.update(extra)
        children = []
        if mesh == "sphere":
            children.append(Inst("SpecialMesh", "Mesh", MeshType=Token(3)))
        p = Inst("Part", name, children=children, attributes=attrs, **props)
        (parent or self.model).add(p)
        return p

    def ball(self, name, d, pos, color, **kw):
        return self.add(name, (d, d, d), pos, color, shape=BALL, **kw)

    def egg(self, name, w, h, pos, color, **kw):
        return self.add(name, (w, h, w), pos, color, mesh="sphere", **kw)

    def cyl(self, name, length, d, pos, color, rot=(0, 0, 90), **kw):
        """Cilindro em pé por padrão (o eixo do cilindro do Roblox é X, então gira 90° em Z)."""
        return self.add(name, (length, d, d), pos, color, shape=CYL, rot=rot, **kw)


def surface_text(part, text, color=(255, 255, 255), bg=None, face=FRONT, pps=24, font=FONT_FREDOKA, name="Gui"):
    label_props = dict(
        Size=UDim2(1, 0, 1, 0),
        BackgroundTransparency=1.0 if bg is None else 0.0,
        Text=text,
        TextScaled=True,
        Font=Token(font),
        TextColor3=Color.rgb(*color),
        TextStrokeTransparency=0.0,
        TextStrokeColor3=Color.rgb(70, 38, 15),
    )
    if bg is not None:
        label_props["BackgroundColor3"] = Color.rgb(*bg)
    part.add(Inst("SurfaceGui", name, Face=Token(face), SizingMode=Token(SIZING_PPS), PixelsPerStud=float(pps),
                  LightInfluence=0.0, AutoLocalize=False, children=[Inst("TextLabel", "Text", **label_props)]))


# ---------------------------------------------------------------------------
# OVOS (base no chão, ~1.5 studs de altura)
# ---------------------------------------------------------------------------
EW, EH = 1.1, 1.5  # largura e altura do ovo


def egg_radius_at(y):
    """Raio do ovo (elipsoide) na altura y (0 = base)."""
    t = (y - EH / 2) / (EH / 2)
    return (EW / 2) * math.sqrt(max(0.0, 1 - t * t))


def surface_point(theta, y, inset=0.03):
    r = egg_radius_at(y) - inset
    return (r * math.cos(theta), y, r * math.sin(theta))


def egg_base(b, color, **kw):
    return b.egg("Shell", EW, EH, (0, EH / 2, 0), color, collide=False, **kw)


def dots(b, color, n, size, seed, flat=0.5, neon=False):
    r = random.Random(seed)
    for i in range(n):
        theta = r.uniform(0, math.pi * 2)
        y = r.uniform(0.25, EH - 0.25)
        b.egg(f"Dot{i}", size, size * flat + 0.05, surface_point(theta, y, 0.02), color, collide=False, neon=neon)


def asset_egg(kind):
    def build(b):
        if kind == "branco":
            egg_base(b, (250, 248, 240))
        elif kind == "caipira":
            egg_base(b, (196, 140, 92))
            dots(b, (150, 96, 58), 9, 0.14, 2)
        elif kind == "pata":
            egg_base(b, (170, 225, 210), reflect=0.05)
        elif kind == "codorna":
            egg_base(b, (235, 215, 180))
            dots(b, (60, 40, 30), 14, 0.26, 4, flat=0.4)
        elif kind == "dourado":
            egg_base(b, (255, 200, 40), reflect=0.35, material="Metal")
            for i in range(3):
                b.ball(f"Sparkle{i}", 0.12, surface_point(i * 2.1, 0.5 + i * 0.3, -0.02), (255, 255, 220), neon=True, collide=False)
        elif kind == "cristal":
            egg_base(b, (140, 220, 255), material="Glass", transparency=0.25, reflect=0.2)
            b.egg("Core", 0.5, 0.7, (0, EH / 2, 0), (180, 250, 255), neon=True, collide=False)
        elif kind == "arcoiris":
            egg_base(b, (255, 255, 255))
            colors = [(235, 70, 60), (255, 150, 40), (255, 220, 50), (90, 200, 90), (70, 150, 255), (170, 90, 230)]
            for i, col in enumerate(colors):
                y = 0.2 + i * (EH - 0.4) / 5
                r = egg_radius_at(y)
                b.cyl(f"Band{i}", 0.2, r * 2 + 0.04, (0, y, 0), col, collide=False)
        elif kind == "lunar":
            egg_base(b, (40, 50, 110))
            dots(b, (150, 160, 200), 7, 0.24, 7, flat=0.3)
            b.egg("Moon", 0.32, 0.32, surface_point(-math.pi / 2, EH * 0.6, -0.02), (230, 235, 255), neon=True, collide=False)
            dots(b, (255, 255, 230), 5, 0.08, 9, flat=1, neon=True)
        elif kind == "dragao":
            egg_base(b, (200, 40, 30))
            r = random.Random(11)
            for i in range(16):
                theta = r.uniform(0, math.pi * 2)
                y = r.uniform(0.2, EH - 0.3)
                b.egg(f"Scale{i}", 0.3, 0.22, surface_point(theta, y, 0.04), (255, 120, 30), collide=False)
            for i in range(4):
                b.add(f"Crack{i}", (0.05, 0.5, 0.05), surface_point(i * 1.6, 0.6 + (i % 2) * 0.25, 0.0), (255, 210, 60),
                      neon=True, collide=False, rot=(0, 0, 25 * (1 if i % 2 else -1)))
            for i in range(3):
                b.add(f"Horn{i}", (0.16, 0.3, 0.16), surface_point(i * 2.1, EH - 0.22, 0.05), (255, 220, 160),
                      collide=False, rot=(0, 0, 15))
    return build


EGGS = [
    ("branco", "Ovo_Branco"), ("caipira", "Ovo_Caipira"), ("pata", "Ovo_Pata"), ("codorna", "Ovo_Codorna"),
    ("dourado", "Ovo_Dourado"), ("cristal", "Ovo_Cristal"), ("arcoiris", "Ovo_ArcoIris"), ("lunar", "Ovo_Lunar"),
    ("dragao", "Ovo_Dragao"),
]


# ---------------------------------------------------------------------------
# AVES (~3 studs de altura, frente para -Z)
# ---------------------------------------------------------------------------
ORANGE = (255, 150, 30)
RED = (220, 45, 40)
BLACK = (25, 25, 25)


def bird(b, body, wing, comb=RED, beak=ORANGE, legs=ORANGE, mat="Smooth", neon_comb=False, size=1.0,
         reflect=0.0, transparency=0.0, bill=False, tail=None):
    s = size
    b.egg("Body", 2.0 * s, 1.8 * s, (0, 1.3 * s, 0.1 * s), body, material=mat, reflect=reflect, transparency=transparency, collide=False)
    b.ball("Head", 1.25 * s, (0, 2.35 * s, -0.75 * s), body, material=mat, reflect=reflect, transparency=transparency, collide=False)
    if bill:
        b.add("Bill", (0.75 * s, 0.22 * s, 0.7 * s), (0, 2.22 * s, -1.45 * s), beak, collide=False)
    else:
        b.add("Beak", (0.38 * s, 0.3 * s, 0.5 * s), (0, 2.25 * s, -1.45 * s), beak, collide=False, rot=(10, 0, 0))
    if comb:
        for i, (dz, h) in enumerate([(-0.95, 0.42), (-0.7, 0.52), (-0.45, 0.4)]):
            b.ball(f"Comb{i}", h * s, (0, 2.95 * s, dz * s), comb, neon=neon_comb, collide=False)
        b.egg("Wattle", 0.24 * s, 0.38 * s, (0, 1.95 * s, -1.25 * s), comb, collide=False)
    for i, side in enumerate((-1, 1)):
        b.ball(f"Eye{i}", 0.3 * s, (side * 0.42 * s, 2.5 * s, -1.25 * s), (255, 255, 255), collide=False)
        b.ball(f"Pupil{i}", 0.18 * s, (side * 0.45 * s, 2.52 * s, -1.37 * s), BLACK, collide=False)
        b.egg(f"Wing{i}", 0.35 * s, 1.0 * s, (side * 0.98 * s, 1.35 * s, 0.15 * s), wing, material=mat, reflect=reflect,
              transparency=transparency, collide=False, rot=(25, 0, side * -8))
        b.cyl(f"Leg{i}", 0.5 * s, 0.18 * s, (side * 0.4 * s, 0.3 * s, 0.05 * s), legs, collide=False)
        b.add(f"Foot{i}", (0.5 * s, 0.1 * s, 0.6 * s), (side * 0.4 * s, 0.05 * s, -0.12 * s), legs, collide=False)
    b.egg("Tail", 0.4 * s, 1.0 * s, (0, 1.95 * s, 1.15 * s), tail or wing, material=mat, reflect=reflect,
          transparency=transparency, collide=False, rot=(-30, 0, 0))


def asset_bird(kind):
    def build(b):
        if kind == "comum":
            bird(b, (250, 250, 245), (235, 235, 230))
        elif kind == "caipira":
            bird(b, (176, 92, 50), (130, 62, 32), tail=(60, 40, 30))
            b.egg("Neck", 1.0, 0.6, (0, 1.95, -0.65), (230, 170, 70), collide=False)
            dots_bird(b, (110, 55, 25), 7, 1)
        elif kind == "pata":
            bird(b, (250, 250, 245), (235, 235, 230), comb=None, bill=True)
        elif kind == "codorna":
            bird(b, (190, 150, 100), (150, 110, 70), comb=None, size=0.85, legs=(200, 130, 80), beak=(70, 60, 50))
            b.ball("Plume", 0.3, (0, 2.85, -0.95), BLACK, collide=False)
            b.add("PlumeStem", (0.08, 0.4, 0.08), (0, 2.65, -0.9), BLACK, collide=False, rot=(-20, 0, 0))
            dots_bird(b, (60, 45, 35), 10, 2, size=0.85)
            for i in range(3):
                b.add(f"Stripe{i}", (0.9, 0.06, 0.08), (0, 1.25 + i * 0.3, -0.72), (245, 235, 210), collide=False)
        elif kind == "dourada":
            bird(b, (255, 200, 40), (255, 170, 20), mat="Metal", reflect=0.3)
            b.add("Crown", (0.6, 0.3, 0.6), (0, 3.05, -0.75), (255, 220, 60), neon=True, collide=False)
        elif kind == "cristal":
            bird(b, (150, 220, 255), (190, 240, 255), comb=(80, 230, 255), mat="Glass", transparency=0.2, reflect=0.25, neon_comb=True)
            b.egg("Core", 0.9, 0.9, (0, 1.3, 0.1), (200, 250, 255), neon=True, collide=False)
        elif kind == "arcoiris":
            bird(b, (255, 120, 170), (120, 200, 255), tail=(255, 220, 60))
            for i, col in enumerate([(235, 70, 60), (255, 150, 40), (255, 220, 50), (90, 200, 90), (70, 150, 255), (170, 90, 230)]):
                b.egg(f"TailFan{i}", 0.25, 1.1, (-0.6 + i * 0.24, 2.2, 1.2), col, collide=False, rot=(-35, 0, -25 + i * 10))
        elif kind == "lunar":
            bird(b, (40, 50, 110), (200, 210, 240), comb=(230, 235, 255), beak=(210, 215, 235), legs=(210, 215, 235), neon_comb=True)
            dots_bird(b, (255, 255, 220), 9, 3, neon=True, size=1.0, d=0.12)
        elif kind == "dragao":
            red, belly = (215, 60, 35), (255, 220, 160)
            b.egg("Body", 2.0, 2.0, (0, 1.3, 0.1), red, collide=False)
            b.egg("Belly", 1.3, 1.5, (0, 1.2, -0.45), belly, collide=False)
            b.ball("Head", 1.45, (0, 2.6, -0.5), red, collide=False)
            b.egg("Snout", 0.9, 0.6, (0, 2.45, -1.15), red, collide=False)
            for i, side in enumerate((-1, 1)):
                b.ball(f"Eye{i}", 0.42, (side * 0.4, 2.8, -1.05), (255, 255, 255), collide=False)
                b.ball(f"Pupil{i}", 0.24, (side * 0.43, 2.82, -1.22), BLACK, collide=False)
                b.add(f"Horn{i}", (0.22, 0.6, 0.22), (side * 0.38, 3.35, -0.3), (255, 210, 90), collide=False, rot=(-20, 0, side * -15))
                b.add(f"Wing{i}", (0.12, 1.1, 1.4), (side * 1.1, 2.0, 0.5), (255, 140, 40), collide=False, rot=(30, side * 20, side * -35))
                b.cyl(f"Leg{i}", 0.6, 0.5, (side * 0.55, 0.3, 0.05), red, collide=False)
            for i in range(3):
                b.add(f"Spike{i}", (0.2, 0.35, 0.2), (0, 2.3 - i * 0.5, 0.95 + i * 0.12), (255, 210, 90), collide=False, rot=(30, 0, 0))
            b.egg("Tail", 0.5, 1.6, (0, 0.7, 1.3), red, collide=False, rot=(-65, 0, 0))
            b.add("TailTip", (0.5, 0.4, 0.1), (0, 0.45, 2.05), (255, 140, 40), collide=False, rot=(0, 0, 45))
    return build


def dots_bird(b, color, n, seed, neon=False, size=1.0, d=0.22):
    r = random.Random(seed)
    for i in range(n):
        theta = r.uniform(-math.pi * 0.2, math.pi * 1.2)
        y = r.uniform(0.9, 1.8) * size
        x = math.cos(theta) * 1.0 * size
        z = 0.1 * size + math.sin(theta) * 1.15 * size
        b.ball(f"Spot{i}", d, (x, y, z), color, neon=neon, collide=False)


BIRDS = [
    ("comum", "Galinha_Comum"), ("caipira", "Galinha_Caipira"), ("pata", "Pata"), ("codorna", "Codorna"),
    ("dourada", "Galinha_Dourada"), ("cristal", "Galinha_Cristal"), ("arcoiris", "Galinha_ArcoIris"),
    ("lunar", "Galinha_Lunar"), ("dragao", "Filhote_Dragao"),
]


# ---------------------------------------------------------------------------
# OBJETOS DE CENÁRIO
# ---------------------------------------------------------------------------
STRAW = (225, 185, 85)
WOOD = (170, 115, 65)
DARK_WOOD = (120, 78, 42)


def asset_ninho(b, **_):
    b.cyl("Base", 0.5, 3.0, (0, 0.25, 0), (200, 160, 70), material="Fabric", collide=False)
    for i in range(12):
        a = i * math.pi * 2 / 12
        b.add(f"Straw{i}", (0.9, 0.55, 0.7), (math.cos(a) * 1.25, 0.65, math.sin(a) * 1.25), STRAW, material="Fabric",
              rot=(rng.uniform(-15, 15), math.degrees(-a), rng.uniform(-12, 12)), collide=False)
    for i in range(5):
        a = rng.uniform(0, math.pi * 2)
        b.add(f"Loose{i}", (1.0, 0.06, 0.06), (math.cos(a) * 1.6, 0.9, math.sin(a) * 1.6), (240, 205, 110),
              rot=(0, rng.uniform(0, 180), rng.uniform(-30, 30)), collide=False)


def asset_galinheiro(b, wall=(205, 60, 50), roof=(140, 40, 35), **_):
    w, d, h = 10, 8, 6
    for i, (x, z) in enumerate([(-4.2, -3.2), (4.2, -3.2), (-4.2, 3.2), (4.2, 3.2)]):
        b.add(f"Leg{i}", (0.8, 1.5, 0.8), (x, 0.75, z), DARK_WOOD, material="Wood")
    b.add("Floor", (w, 0.5, d), (0, 1.75, 0), DARK_WOOD, material="WoodPlanks")
    b.add("Walls", (w, h, d), (0, 2 + h / 2, 0), wall, material="WoodPlanks", Tex="Madeira")
    for i, x in enumerate((-w / 2, w / 2)):
        b.add(f"Trim{i}", (0.4, h, d + 0.2), (x, 2 + h / 2, 0), (250, 245, 235))
    b.add("TrimTop", (w + 0.4, 0.4, d + 0.4), (0, 2 + h, 0), (250, 245, 235))
    for side in (-1, 1):
        b.add(f"Roof{side}", (w + 1.6, 0.6, d / 2 + 1.6), (0, 2 + h + 1.4, side * (d / 4 + 0.2)), roof, material="Slate",
              rot=(side * -32, 0, 0), Tex="Telha")
    b.add("RoofRidge", (w + 1.8, 0.5, 0.6), (0, 2 + h + 2.6, 0), (110, 30, 28))
    b.add("Door", (2.4, 3.2, 0.3), (0, 3.8, -d / 2 - 0.1), (90, 50, 25), material="Wood")
    b.cyl("Window", 0.3, 1.6, (2.8, 6.0, -d / 2 - 0.12), (255, 230, 150), rot=(0, 90, 0), material="Glass")
    b.cyl("WindowRim", 0.25, 1.9, (2.8, 6.0, -d / 2 - 0.05), (250, 245, 235), rot=(0, 90, 0))
    b.add("Ramp", (2.2, 0.3, 4.2), (0, 1.0, -d / 2 - 2.0), WOOD, material="WoodPlanks", rot=(-26, 0, 0))
    for i in range(4):
        b.add(f"Step{i}", (2.2, 0.15, 0.2), (0, 0.5 + i * 0.45, -d / 2 - 3.6 + i * 0.95), DARK_WOOD, rot=(-26, 0, 0))


def asset_cesta(b, **_):
    b.cyl("Body", 1.0, 1.8, (0, 0.5, 0), (200, 150, 80), material="Fabric", collide=False)
    b.cyl("Rim", 0.2, 1.95, (0, 1.0, 0), (170, 120, 60), material="Fabric", collide=False)
    b.cyl("Cloth", 0.15, 1.7, (0, 1.05, 0), (230, 70, 60), material="Fabric", collide=False)
    for i in range(7):
        a = math.radians(i * 30)
        b.add(f"Handle{i}", (0.15, 0.4, 0.15), (math.cos(a) * 0.8, 1.1 + math.sin(a) * 0.65, 0), (170, 120, 60),
              rot=(0, 0, i * 30 - 90), collide=False)


def asset_banca(b, awning=((235, 60, 55), (255, 255, 255)), top=(255, 220, 90), text="OVOS FRESQUINHOS", **_):
    # balcão (estilo barraquinha de limonada)
    b.add("Counter", (12, 3.4, 3), (0, 1.7, 0), (255, 240, 200), material="WoodPlanks", Tex="Madeira")
    b.add("CounterTop", (12.6, 0.35, 3.6), (0, 3.55, 0), top, material="Wood")
    b.add("FrontPanel", (11, 2.4, 0.2), (0, 1.8, -1.55), top)
    surface_text(b.add("FrontText", (10, 1.6, 0.1), (0, 1.9, -1.68), top), "🥚 OVOS 🥚", color=(255, 255, 255), pps=30)
    for i, (x, z) in enumerate([(-5.8, -1.4), (5.8, -1.4), (-5.8, 1.4), (5.8, 1.4)]):
        b.add(f"Post{i}", (0.45, 8.0, 0.45), (x, 4.0, z), DARK_WOOD, material="Wood")
    stripes = 8
    for i in range(stripes):
        x = -6.3 + (i + 0.5) * (12.6 / stripes)
        col = awning[i % 2]
        b.add(f"Awning{i}", (12.6 / stripes, 0.25, 4.6), (x, 8.2, -0.3), col, material="Fabric", rot=(-12, 0, 0))
        b.cyl(f"Scallop{i}", 12.6 / stripes, 0.8, (x, 7.8, -2.55), col, rot=(0, 0, 0), material="Fabric", collide=False)
    sign = b.add("SignBoard", (8, 1.8, 0.3), (0, 9.8, 0.4), (255, 250, 235), material="WoodPlanks")
    surface_text(sign, text, color=(200, 70, 40), pps=28)
    # caixas de ovo e caixinha de dinheiro
    for i, x in enumerate((-3.6, -1.6, 1.0)):
        b.add(f"Carton{i}", (1.8, 0.5, 1.1), (x, 3.98, -0.3), (200, 190, 175), material="Fabric", collide=False)
        for j in range(3):
            b.egg(f"CartonEgg{i}_{j}", 0.45, 0.55, (x - 0.55 + j * 0.55, 4.35, -0.3), (250, 245, 235) if (i + j) % 2 else (200, 145, 95), collide=False)
    b.add("CashBox", (1.4, 0.8, 1.0), (4.2, 4.1, 0.2), (80, 160, 90), collide=False)
    b.add("CashLid", (1.45, 0.15, 1.05), (4.2, 4.55, 0.2), (60, 130, 70), collide=False)
    b.add("Stool", (1.4, 2.0, 1.4), (2.5, 1.0, 3.2), WOOD, material="Wood")


def asset_esteira(b, **_):
    # segmento de 8 studs ao longo de Z
    b.add("Belt", (2.4, 0.3, 8), (0, 1.6, 0), (60, 60, 65), material="Fabric")
    for i in range(8):
        b.add(f"Ridge{i}", (2.3, 0.12, 0.15), (0, 1.8, -3.5 + i), (40, 40, 45))
    for i, x in enumerate((-1.35, 1.35)):
        b.add(f"Rail{i}", (0.3, 0.6, 8), (x, 1.75, 0), (255, 205, 40), material="Metal")
    for i, z in enumerate((-3.8, 3.8)):
        b.cyl(f"Roller{i}", 2.4, 0.5, (0, 1.5, z), (180, 180, 185), rot=(0, 0, 0), material="Metal")
    for i, (x, z) in enumerate([(-1.0, -3.2), (1.0, -3.2), (-1.0, 3.2), (1.0, 3.2)]):
        b.add(f"Leg{i}", (0.3, 1.5, 0.3), (x, 0.75, z), (255, 140, 40), material="Metal")


def asset_cerca(b, **_):
    # segmento de 10 studs ao longo de X
    for i, x in enumerate((-4.8, 4.8)):
        b.add(f"Post{i}", (0.6, 3.6, 0.6), (x, 1.8, 0), (150, 100, 55), material="Wood")
        b.ball(f"Cap{i}", 0.7, (x, 3.65, 0), (165, 112, 62), material="Wood")
    for i, y in enumerate((1.3, 2.7)):
        b.add(f"Rail{i}", (10, 0.45, 0.3), (0, y, 0), (200, 145, 85), material="WoodPlanks", rot=(0, 0, rng.uniform(-1.2, 1.2)))


def asset_placa(b, text="VENDA UM OVO", **_):
    for i, x in enumerate((-7, 7)):
        b.add(f"Post{i}", (0.9, 10, 0.9), (x, 5, 0), DARK_WOOD, material="Wood")
    board = b.add("Board", (17, 6, 0.8), (0, 8, 0), (255, 205, 50), material="WoodPlanks")
    b.add("Frame", (18, 6.8, 0.6), (0, 8, 0.25), (130, 75, 35), material="Wood")
    surface_text(board, text, color=(255, 255, 255), pps=20)
    b.egg("EggDeco", 2.0, 2.7, (8.6, 11.5, -0.4), (255, 250, 240))


def asset_arvore(b, leaf=(110, 200, 70), apples=True, **_):
    b.cyl("Trunk", 5, 1.6, (0, 2.5, 0), (125, 85, 50), material="Wood")
    for i, (x, y, z, d) in enumerate([(0, 7, 0, 7), (-2.2, 6, 1, 5), (2.3, 6.3, -0.6, 5.2), (0.3, 8.8, 0.4, 4.6)]):
        b.ball(f"Leaves{i}", d, (x, y, z), (leaf[0] + i * 6, leaf[1] - i * 5, leaf[2]), material="Grass")
    if apples:
        for i in range(5):
            a = rng.uniform(0, math.pi * 2)
            b.ball(f"Apple{i}", 0.6, (math.cos(a) * 3.2, rng.uniform(5.5, 8), math.sin(a) * 3.2), (220, 40, 40), collide=False)


def asset_feno(b, **_):
    b.add("Bale", (4, 2.4, 2.6), (0, 1.2, 0), STRAW, material="Fabric", Tex="Palha")
    for i, x in enumerate((-1.1, 1.1)):
        b.add(f"Twine{i}", (0.18, 2.5, 2.7), (x, 1.2, 0), (200, 50, 40), material="Fabric")
    for i in range(4):
        b.add(f"Loose{i}", (1.2, 0.08, 0.08), (rng.uniform(-1.8, 1.8), 2.45, rng.uniform(-1, 1)), (240, 205, 110),
              rot=(0, rng.uniform(0, 180), rng.uniform(-10, 10)), collide=False)


def asset_moinho(b, **_):
    for i in range(6):
        d = 12 - i * 1.1
        b.cyl(f"Tower{i}", 4, d, (0, 2 + i * 4, 0), (245, 235, 210), material="Sandstone")
    for i in range(5):
        d = 11 - i * 2.2
        b.cyl(f"Roof{i}", 1.4, d, (0, 25 + i * 1.3, 0), (205, 60, 45), material="Slate")
    b.add("Door", (3, 5, 0.4), (0, 2.5, -5.9), (70, 130, 200), material="Wood")
    b.add("Window", (1.6, 1.6, 0.4), (0, 13, -4.9), (70, 130, 200), material="Wood")
    b.cyl("Hub", 1.5, 1.6, (0, 22, -5.6), (110, 70, 40), rot=(0, 90, 0), material="Wood")
    for i in range(4):
        a = i * 90 + 15
        rad = math.radians(a)
        b.add(f"Blade{i}", (2.4, 11, 0.3), (math.cos(rad) * 6, 22 + math.sin(rad) * 6, -6.3), (255, 255, 255) if i % 2 else (230, 70, 60),
              material="Fabric", rot=(0, 0, a - 90))


PROPS = {
    "Ninho": asset_ninho, "Galinheiro": asset_galinheiro, "Cesta": asset_cesta, "Banca": asset_banca,
    "Esteira": asset_esteira, "Cerca": asset_cerca, "Placa": asset_placa, "Arvore": asset_arvore,
    "Feno": asset_feno, "Moinho": asset_moinho,
}


def make_model(name, build, xf=None, collide=True, **opts):
    model = Inst("Model", name)
    b = Builder(model, xf or Xf(), collide)
    build(b, **opts) if opts else build(b)
    return model


def scenery(parent, asset, x, y, z, yaw=0.0, scale=1.0, name=None, height=None, **opts):
    """Põe um objeto de cenário no mapa já desenhado, com os atributos para o jogo trocar pelo 3D depois."""
    build = PROPS[asset]
    model = make_model(name or asset, build, Xf(x, y, z, yaw, scale), **opts)
    model.attributes = {"Asset": asset, "BX": float(x), "BY": float(y), "BZ": float(z), "Yaw": float(yaw)}
    if height is not None:
        model.attributes["H"] = float(height)
    parent.add(model)
    return model


# ---------------------------------------------------------------------------
# MAPA
# ---------------------------------------------------------------------------
def box(parent, name, cx, cy, cz, sx, sy, sz, color, material="Smooth", yaw=0.0, collide=True, **kw):
    b = Builder(parent, Xf(cx, cy, cz, yaw), collide)
    return b.add(name, (sx, sy, sz), (0, 0, 0), color, material=material, **kw)


def marker(parent, name, x, y, z, size=(2, 1, 2), yaw=0.0, **attrs):
    p = box(parent, name, x, y, z, size[0], size[1], size[2], (255, 255, 255), transparency=1.0, collide=False, CanQuery=False)
    if attrs:
        p.attributes = dict(attrs)
    return p


def rot_point(ox, oz, x, z, yaw):
    a = math.radians(yaw)
    return ox + x * math.cos(a) + z * math.sin(a), oz - x * math.sin(a) + z * math.cos(a)


PLOT_W, PLOT_D = 110, 100
AWNINGS = [
    ((235, 60, 55), (255, 255, 255)), ((60, 140, 230), (255, 255, 255)), ((60, 170, 80), (255, 250, 230)),
    ((255, 140, 40), (255, 255, 255)), ((170, 90, 220), (255, 240, 255)), ((240, 90, 150), (255, 255, 255)),
]
COOP = [((205, 60, 50), (140, 40, 35)), ((230, 200, 120), (150, 60, 40)), ((110, 160, 210), (60, 80, 120)),
        ((240, 240, 230), (190, 70, 50)), ((120, 180, 110), (90, 70, 50)), ((210, 130, 80), (110, 50, 30))]
BANCA_TEXT = ["OVOS FRESQUINHOS", "OVO BOM É AQUI", "OVOS DA GRANJA", "OVOS DO DIA", "OLHA O OVO!", "OVO CAIPIRA"]

NEST_XS = [-30, -10, 10, 30]
NEST_ZS = [-20, -2, 16]


def build_plot(index, cx, cz, yaw):
    plot = Inst("Model", f"Plot{index}")
    plot.attributes = {"Index": index}

    def w(lx, lz):
        return rot_point(cx, cz, lx, lz, yaw)

    variant = (index - 1) % 6
    # chão da granja (um tom de verde diferente em cada uma)
    g = (96 + rng.randint(-8, 8), 190 + rng.randint(-10, 6), 70 + rng.randint(-8, 8))
    gx, gz = w(0, 0)
    box(plot, "Ground", gx, 0.15, gz, PLOT_W, 0.3, PLOT_D, g, "Grass", yaw, Tex="Grama")
    # caminhos de terra: portão → ninhos → galinheiro, e portão → banca
    for name, (lx, lz, sx, sz) in {"PathMain": (0, -10, 7, 80), "PathCross": (0, 7, 72, 6), "PathBanca": (10, -41, 20, 6)}.items():
        px, pz = w(lx, lz)
        box(plot, name, px, 0.34, pz, sx, 0.1, sz, (196, 150, 100), "Ground", yaw, Tex="Terra")

    # cerca em volta (com a entrada na frente)
    hw, hd = PLOT_W / 2, PLOT_D / 2
    fence = Inst("Model", "Fence")
    plot.add(fence)
    for i in range(-5, 6):
        x = i * 10
        if abs(x) < 8 or 13 <= x <= 27:  # entrada e o lugar da banca
            continue
        if abs(x) <= hw - 5:
            fx, fz = w(x, -hd)
            scenery(fence, "Cerca", fx, 0.3, fz, yaw, name=f"Front{i}")
            fx, fz = w(x, hd)
            scenery(fence, "Cerca", fx, 0.3, fz, yaw, name=f"Back{i}")
    for i in range(-4, 5):
        z = i * 10 + 5
        if abs(z) <= hd - 5:
            for side in (-1, 1):
                fx, fz = w(side * hw, z)
                scenery(fence, "Cerca", fx, 0.3, fz, yaw + 90, name=f"Side{side}_{i}")

    # placa com o nome do dono, no portão
    sx_, sz_ = w(-9, -hd - 1)
    box(plot, "SignPost", sx_, 3, sz_, 0.7, 6, 0.7, (120, 78, 42), "Wood", yaw)
    sign = box(plot, "Sign", sx_, 6.5, sz_, 9, 2.6, 0.5, (255, 248, 230), "WoodPlanks", yaw)
    surface_text(sign, "Granja livre", color=(110, 62, 28), pps=24)

    # banca de venda (na frente, virada para a rua)
    # a banca fica no limite da granja, de frente para a calçada (como barraquinha de limonada)
    bx, bz = w(20, -hd + 1.5)
    scenery(plot, "Banca", bx, 0.3, bz, yaw, name="Banca", awning=AWNINGS[variant], text=BANCA_TEXT[variant])
    marker(plot, "SellPoint", bx, 4, bz, (10, 1, 3), yaw)
    padx, padz = w(20, -hd + 7)
    box(plot, "SellPad", padx, 0.45, padz, 8, 0.2, 4, (80, 210, 100), "Neon", yaw, transparency=0.35, collide=False, CanTouch=True)

    # galinheiro no fundo
    cx2, cz2 = w(-6 + rng.uniform(-4, 4), hd - 14)
    scenery(plot, "Galinheiro", cx2, 0.3, cz2, yaw + rng.uniform(-6, 6), name="Galinheiro", wall=COOP[variant][0], roof=COOP[variant][1])

    # ninhos e aves (12 lugares; só os liberados aparecem)
    n = 0
    for zi, lz in enumerate(NEST_ZS):
        for xi, lx in enumerate(NEST_XS):
            n += 1
            jx, jz = lx + rng.uniform(-1.5, 1.5), lz + rng.uniform(-1.2, 1.2)
            nx, nz = w(jx, jz)
            scenery(plot, "Ninho", nx, 0.3, nz, yaw + rng.uniform(0, 360), name=f"NestLook{n}")
            marker(plot, f"Nest{n}", nx, 1.1, nz, (2.6, 0.4, 2.6), yaw)
            hx, hz = w(jx + 0.3, jz + 3.4)
            m = marker(plot, f"HenSpot{n}", hx, 0.8, hz, (2, 1, 2), yaw)
            m.attributes = {"Yaw": float(yaw + rng.uniform(-20, 20))}

    # esteira (escondida até comprar): ninhos → lateral → banca
    conveyor = Inst("Model", "Conveyor")
    plot.add(conveyor)
    path = [(-42, 16), (-42, -36), (10, -36), (10, -hd + 6)]
    for i, (lx, lz) in enumerate(path, start=1):
        x, z = w(lx, lz)
        marker(plot, f"ConvPath{i}", x, 2.2, z, (1, 1, 1), yaw)
    for leg in range(len(path) - 1):
        (ax, az), (bx2, bz2) = path[leg], path[leg + 1]
        length = math.hypot(bx2 - ax, bz2 - az)
        segs = max(1, int(round(length / 8)))
        local_yaw = math.degrees(math.atan2(bx2 - ax, bz2 - az))
        for s in range(segs):
            t = (s + 0.5) / segs
            lx, lz = ax + (bx2 - ax) * t, az + (bz2 - az) * t
            x, z = w(lx, lz)
            scenery(conveyor, "Esteira", x, 0.3, z, yaw + local_yaw, scale=length / segs / 8, name=f"Belt{leg}_{s}")

    # decorações compráveis (Decor1..6)
    decor_spots = [(-24, -44), (44, 32), (-47, 42), (44, -26), (28, 42), (-47, -46)]
    for i, (lx, lz) in enumerate(decor_spots, start=1):
        d = Inst("Model", f"Decor{i}")
        plot.add(d)
        x, z = w(lx + rng.uniform(-2, 2), lz + rng.uniform(-2, 2))
        if i in (1, 3, 5):
            scenery(d, "Arvore", x, 0.3, z, rng.uniform(0, 360), scale=rng.uniform(0.8, 1.15), name="Tree",
                    leaf=[(110, 200, 70), (240, 150, 190), (255, 190, 60)][i // 2])
        elif i == 2:
            scenery(d, "Feno", x, 0.3, z, rng.uniform(0, 360), name="Hay1")
            x2, z2 = w(lx + 3, lz + 1)
            scenery(d, "Feno", x2, 2.7, z2, rng.uniform(0, 360), scale=0.9, name="Hay2")
        elif i == 4:
            flowers(d, x, z)
        else:
            scenery(d, "Moinho", x, 0.3, z, yaw + 200, scale=0.45, name="MiniMill")

    # árvores e fenos fixos (fora da área dos ninhos), cada granja diferente
    for k in range(rng.randint(2, 4)):
        side = rng.choice((-1, 1))
        lx, lz = side * rng.uniform(47, 50), rng.uniform(-10, 40)
        x, z = w(lx, lz)
        scenery(plot, "Arvore", x, 0.3, z, rng.uniform(0, 360), scale=rng.uniform(0.7, 1.05), name=f"Tree{k}")
    for k in range(rng.randint(1, 3)):
        lx, lz = rng.choice((rng.uniform(-42, -22), rng.uniform(14, 40))), rng.uniform(34, 44)
        x, z = w(lx, lz)
        scenery(plot, "Feno", x, 0.3, z, rng.uniform(0, 360), name=f"Hay{k}")

    zx, zz = w(0, 0)
    marker(plot, "Zone", zx, 10, zz, (PLOT_W, 20, PLOT_D), yaw)
    spx, spz = w(0, -hd + 16)
    marker(plot, "Spawn", spx, 1, spz, (4, 1, 4), yaw)
    return plot


def flowers(parent, x, z):
    b = Builder(parent, Xf(x, 0.3, z, rng.uniform(0, 90)), collide=False)
    b.add("Bed", (8, 0.5, 4), (0, 0.25, 0), (120, 80, 50), material="Ground")
    cols = [(255, 90, 120), (255, 220, 60), (180, 120, 255), (255, 255, 255), (255, 140, 40)]
    for i in range(14):
        fx, fz = rng.uniform(-3.5, 3.5), rng.uniform(-1.6, 1.6)
        b.cyl(f"Stem{i}", 1.0, 0.15, (fx, 0.9, fz), (60, 150, 60))
        b.ball(f"Flower{i}", 0.6, (fx, 1.45, fz), rng.choice(cols))


def street_lamp(parent, x, z, yaw):
    b = Builder(parent, Xf(x, 0, z, yaw))
    b.cyl("Pole", 12, 0.6, (0, 6, 0), (60, 70, 80), material="Metal")
    b.add("Arm", (0.4, 0.4, 3), (0, 12, -1.3), (60, 70, 80), material="Metal")
    lamp = b.add("Lamp", (1.4, 0.8, 1.4), (0, 11.7, -2.6), (255, 240, 190), neon=True, collide=False)
    lamp.add(Inst("PointLight", "Light", Range=26.0, Brightness=1.2, Color=Color.rgb(255, 225, 170)))


def bench(parent, x, z, yaw):
    b = Builder(parent, Xf(x, 0, z, yaw))
    b.add("Seat", (6, 0.4, 1.8), (0, 1.6, 0), (190, 120, 70), material="WoodPlanks")
    b.add("Back", (6, 1.6, 0.3), (0, 2.6, 0.85), (190, 120, 70), material="WoodPlanks", rot=(-10, 0, 0))
    for i, xx in enumerate((-2.6, 2.6)):
        b.add(f"Leg{i}", (0.3, 1.6, 1.6), (xx, 0.8, 0), (50, 55, 60), material="Metal")


# ---------------------------------------------------------------------------
# ILHA FLUTUANTE (mapa inspirado na arte do jogo)
#   centro: celeiro + silo + cercadinho de galinhas + ovo dourado (placar)
#   anel de dentro (estrada de terra) e anel de fora (estrada asfaltada)
#   entre os anéis: Galinheiro do Seu Zé, Mercado, Oficina, Portão Arco-íris, Banco, Fábrica
#   12 granjas em círculo depois do anel de fora; borda com lagos, ponte, moinho, rotatória, pinheiros
# ---------------------------------------------------------------------------
ISLAND_R = 470
INNER_R, INNER_W = 140, 22
OUTER_R, OUTER_W = 232, 24
PLOT_R = OUTER_R + OUTER_W / 2 + 8 + PLOT_D / 2  # centro das granjas
SHOP_R = 186


def polar(r, deg):
    a = math.radians(deg)
    return r * math.cos(a), r * math.sin(a)


def yaw_facing_center(deg):
    """Giro para a frente (-Z local) apontar para o centro da ilha."""
    return 90.0 - deg


def yaw_facing_out(deg):
    return -90.0 - deg


def ring_road(parent, name, r, width, color, material, y=0.15, dash=None, segments=96, tex=None):
    m = Inst("Model", name)
    parent.add(m)
    seg_len = 2 * math.pi * r / segments * 1.03
    for i in range(segments):
        deg = (i + 0.5) * 360 / segments
        x, z = polar(r, deg)
        kw = {"Tex": tex} if tex else {}
        box(m, f"Seg{i}", x, y, z, seg_len, 0.3, width, color, material, yaw=-deg - 90, **kw)
        if dash and i % 2 == 0:
            box(m, f"Dash{i}", x, y + 0.17, z, seg_len * 0.55, 0.05, 0.7, dash, "Smooth", yaw=-deg - 90, collide=False)
    return m


def asset_pinheiro(b, **_):
    b.cyl("Trunk", 3, 1.2, (0, 1.5, 0), (115, 75, 45), material="Wood")
    for i, (y, d, h) in enumerate([(4.2, 7.5, 3.2), (6.6, 5.8, 3.0), (8.8, 4.0, 2.8), (10.6, 2.2, 2.2)]):
        b.cyl(f"Layer{i}", h, d, (0, y, 0), (45 + i * 8, 140 + i * 10, 70 + i * 4), material="Grass")
    b.ball("Top", 1.0, (0, 12.0, 0), (80, 180, 90), material="Grass")


def asset_carrinho(b, **_):
    b.add("Bed", (4.4, 1.6, 2.8), (0, 2.0, 0), (170, 110, 60), material="WoodPlanks")
    for i, x in enumerate((-2.2, 2.2)):
        b.add(f"Side{i}", (0.25, 1.2, 2.8), (x, 2.9, 0), (140, 88, 48), material="Wood")
    for i, z in enumerate((-1.5, 1.5)):
        b.cyl(f"Wheel{i}", 0.35, 2.4, (0.6, 1.2, z), (110, 70, 40), rot=(0, 90, 0), material="Wood")
    b.add("HandleL", (3.2, 0.25, 0.25), (-3.6, 2.2, -0.9), (120, 78, 42), rot=(0, 0, -12))
    b.add("HandleR", (3.2, 0.25, 0.25), (-3.6, 2.2, 0.9), (120, 78, 42), rot=(0, 0, -12))
    for i in range(10):
        b.egg(f"Egg{i}", 0.6, 0.8, (-1.6 + (i % 5) * 0.8, 3.1 + (i // 5) * 0.35, -0.5 + (i // 5) * 0.9),
              (250, 245, 235) if i % 3 else (200, 145, 95), collide=False)


PROPS["Pinheiro"] = asset_pinheiro
PROPS["Carrinho"] = asset_carrinho


def signpost(parent, x, z, yaw, text):
    b = Builder(parent, Xf(x, 0, z, yaw))
    b.add("Post", (0.6, 6, 0.6), (0, 3, 0), (120, 78, 42), material="Wood")
    arrow = b.add("Board", (5, 1.4, 0.3), (1.6, 5, 0), (200, 145, 85), material="WoodPlanks")
    b.add("Tip", (1, 1, 0.3), (4.3, 5, 0), (200, 145, 85), material="WoodPlanks", rot=(0, 0, 45))
    surface_text(arrow, text, color=(255, 255, 255), pps=30)


def coin(parent, name, x, y, z, size=2.4):
    b = Builder(parent, Xf(x, y, z, rng.uniform(0, 360)), collide=False)
    p = b.cyl(name, 0.4, size, (0, 0, 0), (255, 200, 40), rot=(0, 0, 0), material="Metal", reflect=0.3)
    p.add(Inst("PointLight", "Glow", Range=6.0, Brightness=0.8, Color=Color.rgb(255, 220, 120)))


def build_island():
    world = Inst("Model", "Map")
    b = Builder(world, Xf())
    # topo gramado + "terra" embaixo (ilha flutuante)
    b.cyl("Grass", 2, ISLAND_R * 2, (0, -1, 0), (100, 195, 75), material="Grass", Tex="Grama")
    b.cyl("GrassLip", 1.2, ISLAND_R * 2 + 3, (0, -2.2, 0), (85, 170, 65), material="Grass")
    # camadas de terra e pedra que vão afinando para baixo (o topo de cada uma fica abaixo da grama)
    top = -2.9
    for i, (h, r) in enumerate([(10, 466), (10, 448), (12, 420), (13, 380), (14, 320), (15, 240), (15, 150), (14, 70)]):
        col = (150 - i * 6, 100 - i * 4, 60 - i * 3)
        b.cyl(f"Cliff{i}", h, r * 2, (0, top - h / 2, 0), col, material="Ground" if i < 3 else "Rock")
        top -= h
    for i in range(36):
        deg = i * 10 + rng.uniform(-3, 3)
        x, z = polar(ISLAND_R - rng.uniform(4, 20), deg)
        b.add(f"Chunk{i}", (rng.uniform(10, 22), rng.uniform(10, 26), rng.uniform(10, 18)), (x, rng.uniform(-30, -10), z),
              (130 - rng.randint(0, 25), 85 - rng.randint(0, 15), 50), material="Rock", rot=(rng.uniform(-20, 20), rng.uniform(0, 360), rng.uniform(-20, 20)))
    # parede invisível na borda (ninguém cai da ilha)
    for i in range(48):
        deg = (i + 0.5) * 7.5
        x, z = polar(ISLAND_R - 2, deg)
        box(world, f"EdgeWall{i}", x, 15, z, 2 * math.pi * ISLAND_R / 48 * 1.05, 32, 2, (255, 255, 255), yaw=-deg - 90, transparency=1.0)
    # estradas
    ring_road(world, "InnerRoad", INNER_R, INNER_W, (215, 175, 120), "Ground", tex="Terra")
    ring_road(world, "OuterRoad", OUTER_R, OUTER_W, (80, 82, 90), "Asphalt", dash=(255, 220, 60))
    ring_road(world, "OuterSidewalk", OUTER_R + OUTER_W / 2 + 4, 8, (215, 210, 200), "Concrete", y=0.25)
    for i, deg in enumerate((30, 150, 270)):
        mid = (INNER_R + OUTER_R) / 2
        x, z = polar(mid, deg)
        box(world, f"Spoke{i}", x, 0.12, z, 10, 0.3, OUTER_R - INNER_R - 10, (215, 175, 120), "Ground", yaw=yaw_facing_center(deg), Tex="Terra")
    # postes no anel de fora
    for i in range(24):
        deg = i * 15 + 7.5
        x, z = polar(OUTER_R - OUTER_W / 2 - 2, deg)
        street_lamp(world, x, z, yaw_facing_out(deg) + 180)
    return world


def build_hub(plaza):
    hub = Inst("Model", "Hub")
    plaza.add(hub)
    b = Builder(hub, Xf())
    b.cyl("HubGrass", 0.4, (INNER_R - INNER_W / 2) * 2, (0, 0.1, 0), (120, 205, 85), material="Grass", Tex="Grama")
    # celeiro grande + silo
    bb = Builder(hub, Xf(-8, 0.3, 22, 0, 1.35))
    bb.add("Body", (36, 18, 26), (0, 9, 0), (200, 50, 45), material="WoodPlanks", Tex="Madeira")
    for side in (-1, 1):
        bb.add(f"RoofLow{side}", (38, 1, 9), (0, 19.5, side * 10.5), (130, 60, 45), material="Slate", rot=(side * -55, 0, 0), Tex="Telha")
        bb.add(f"RoofHigh{side}", (38, 1, 9), (0, 25.2, side * 4.0), (130, 60, 45), material="Slate", rot=(side * -22, 0, 0), Tex="Telha")
    bb.add("Ridge", (38.5, 0.8, 1.2), (0, 26.8, 0), (110, 45, 35))
    bb.add("Door", (12, 13, 0.5), (0, 6.5, -13.1), (245, 240, 230), material="WoodPlanks")
    for k, rz in enumerate((43, -43)):
        bb.add(f"DoorX{k}", (17, 0.9, 0.3), (0, 6.5, -13.4), (200, 50, 45), rot=(0, 0, rz))
    bb.add("Loft", (5, 4.5, 0.5), (0, 17, -13.1), (60, 35, 20))
    bb.add("LoftHay", (4, 1.5, 0.6), (0, 15.5, -13.3), (240, 200, 90), material="Fabric")
    for side in (-1, 1):
        bb.add(f"Trim{side}", (0.6, 18, 26.4), (side * 18, 9, 0), (245, 240, 230))
    sb = Builder(hub, Xf(24, 0.3, 34, 0, 1.3))
    sb.cyl("Silo", 30, 12, (0, 15, 0), (200, 50, 45), material="Metal")
    for i in range(5):
        sb.cyl(f"Band{i}", 0.6, 12.3, (0, 3 + i * 6, 0), (230, 225, 220), material="Metal")
    sb.ball("Dome", 12, (0, 30, 0), (210, 215, 220), material="Metal")
    sb.add("Ladder", (1.2, 28, 0.3), (0, 14, -6.1), (180, 180, 185), material="Metal")
    # mini galinheiro e fardos ao lado do celeiro
    scenery(hub, "Galinheiro", -42, 0.3, 18, 90, scale=0.9, name="HubCoop")
    for i in range(4):
        scenery(hub, "Feno", -30 + i * 3.4, 0.3, -2 + rng.uniform(-1, 1), rng.uniform(-20, 20), scale=0.7, name=f"HubHay{i}")
    # cercadinho redondo com galinhas soltas (com entrada virada para o sul)
    pen_r = 56
    for i in range(32):
        deg = (i + 0.5) * 360 / 32
        if 255 < deg < 285:
            continue
        x, z = polar(pen_r, deg)
        scenery(hub, "Cerca", x, 0.3, z, -deg - 90, scale=1.12, name=f"PenFence{i}")
    for i in range(14):
        while True:
            r, deg = rng.uniform(10, pen_r - 6), rng.uniform(0, 360)
            x, z = polar(r, deg)
            if not (-36 < x < 36 and 0 < z < 48):  # fora do celeiro e do silo
                break
        bird_model = make_model(f"PenHen{i}", asset_bird(rng.choice(["comum", "comum", "comum", "caipira"])), Xf(x, 0.3, z, rng.uniform(0, 360)), collide=False)
        hub.add(bird_model)
    # ovo dourado no pedestal + placar global
    pb = Builder(hub, Xf(30, 0.3, -24))
    pb.cyl("Pedestal", 4, 10, (0, 2, 0), (225, 220, 210), material="Marble")
    pb.cyl("PedestalTop", 1, 12, (0, 4.5, 0), (240, 235, 225), material="Marble")
    pb.egg("GoldenEgg", 7, 9.5, (0, 9.8, 0), (255, 200, 40), material="Metal", reflect=0.3)
    glow = pb.ball("Glow", 1, (0, 9.8, 0), (255, 230, 120), transparency=1.0, collide=False)
    glow.add(Inst("PointLight", "Light", Range=26.0, Brightness=2.5, Color=Color.rgb(255, 215, 110)))
    lb = Builder(hub, Xf(30, 0.3, -40, 0))
    for i, x in enumerate((-8, 8)):
        lb.add(f"LPost{i}", (1, 18, 1), (x, 9, 0), (120, 78, 42), material="Wood")
    board = lb.add("LeaderboardBoard", (16, 15, 0.6), (0, 10.5, 0), (255, 236, 190), material="WoodPlanks")
    board.add(Inst("SurfaceGui", "Gui", Face=Token(FRONT), SizingMode=Token(SIZING_PPS), PixelsPerStud=20.0, LightInfluence=0.0,
                   AutoLocalize=False, children=[
                       Inst("TextLabel", "Title", Size=UDim2(1, 0, 0.16, 0), BackgroundColor3=Color.rgb(255, 205, 50), Text="MAIORES VENDEDORES",
                            TextScaled=True, Font=Token(FONT_FREDOKA), TextColor3=Color.rgb(110, 62, 28)),
                   ]))
    # placa grande do jogo na entrada do cercadinho
    scenery(hub, "Placa", 0, 0.3, -70, 180, scale=1.4, name="BigSign")
    # gramado em volta do cercadinho: árvores, canteiros, bancos e postes (cada um num ângulo)
    for i in range(10):
        deg = i * 36 + rng.uniform(-8, 8)
        if 250 < deg < 290:
            continue  # caminho da entrada
        x, z = polar(rng.uniform(84, 108), deg)
        kind = i % 3
        if kind == 0:
            scenery(hub, "Arvore", x, 0.3, z, rng.uniform(0, 360), scale=rng.uniform(0.85, 1.1), name=f"HubTree{i}",
                    leaf=rng.choice([(110, 200, 70), (240, 150, 190)]))
        elif kind == 1:
            scenery(hub, "Pinheiro", x, 0.3, z, rng.uniform(0, 360), scale=rng.uniform(0.8, 1.0), name=f"HubPine{i}")
        else:
            flowers(hub, x, z)
    for i, deg in enumerate((15, 75, 135, 195, 330)):
        x, z = polar(70, deg)
        bench(hub, x, z, yaw_facing_center(deg) + 180)
    for i in range(8):
        deg = i * 45 + 22.5
        x, z = polar(INNER_R - INNER_W / 2 - 4, deg)
        street_lamp(hub, x, z, yaw_facing_out(deg))
    for i in range(6):
        x, z = polar(rng.uniform(64, 120), rng.uniform(0, 360))
        coin(hub, f"Coin{i}", x, 3.5, z)


def shop_building(parent, deg, name, wall, roof, sign_text, sign_color, point_name, extra=None):
    x, z = polar(SHOP_R, deg)
    yaw = yaw_facing_out(deg)
    m = Inst("Model", name)
    parent.add(m)
    b = Builder(m, Xf(x, 0.3, z, yaw))
    b.add("Body", (26, 12, 16), (0, 6, 0), wall, material="WoodPlanks", Tex="Madeira")
    b.add("Roof", (28, 1.2, 18), (0, 12.6, 0), roof, material="Slate")
    b.add("Counter", (16, 3.6, 3), (0, 1.8, -9.6), (255, 240, 205), material="WoodPlanks")
    b.add("Window", (15, 5, 0.4), (0, 6.5, -8.05), (60, 40, 25))
    stripes = 8
    for i in range(stripes):
        sx = -10 + (i + 0.5) * (20 / stripes)
        b.add(f"Awning{i}", (20 / stripes, 0.25, 4.5), (sx, 10.0, -10), [(235, 70, 60), (255, 255, 255)][i % 2] if extra != "blue" else [(70, 150, 230), (255, 255, 255)][i % 2],
              material="Fabric", rot=(-14, 0, 0))
    sign = b.add("Sign", (16, 3.4, 0.6), (0, 15.5, -6.5), (255, 248, 230), material="WoodPlanks")
    surface_text(sign, sign_text, color=sign_color, pps=22)
    px, pz = rot_point(x, z, 0, -12.5, yaw)
    marker(m, point_name, px, 3, pz, (6, 2, 2))
    return m, b


def build_ring_buildings(plaza):
    # Galinheiro do Seu Zé (aves) - 0°
    _, b = shop_building(plaza, 0, "HenShop", (205, 60, 50), (120, 35, 30), "GALINHEIRO DO SEU ZÉ", (200, 60, 40), "HenShopPoint")
    for i in range(3):
        b.add(f"Crate{i}", (3, 2.4, 3), (-11 + i * 3.4, 1.2, -13.5), (190, 140, 80), material="WoodPlanks")
    # Mercado com barracas e carrinhos (missões) - 60°
    mx, mz = polar(SHOP_R, 60)
    yaw = yaw_facing_out(60)
    market = Inst("Model", "Market")
    plaza.add(market)
    mb = Builder(market, Xf(mx, 0.2, mz, yaw))
    mb.add("Paving", (54, 0.3, 46), (0, 0.05, 0), (205, 200, 195), material="Concrete")
    stalls = [((60, 170, 80), (255, 230, 60)), ((170, 90, 220), (255, 255, 255)), ((60, 140, 230), (255, 255, 255)), ((235, 60, 55), (255, 255, 255))]
    for i, aw in enumerate(stalls):
        sx, sz = rot_point(mx, mz, -19 + i * 12.6, 8 + (i % 2) * 2, yaw)
        scenery(market, "Banca", sx, 0.4, sz, yaw + rng.uniform(-4, 4), scale=0.85, name=f"Stall{i}", awning=aw, text="OVOS")
    for i in range(4):
        cx, cz = rot_point(mx, mz, -18 + i * 11 + rng.uniform(-1, 1), -12 + rng.uniform(-2, 2), yaw)
        scenery(market, "Carrinho", cx, 0.4, cz, yaw + rng.uniform(-35, 35), name=f"Cart{i}")
    qx, qz = rot_point(mx, mz, 22, -16, yaw)
    qb = Builder(market, Xf(qx, 0.4, qz, yaw))
    for i, px in enumerate((-4, 4)):
        qb.add(f"Post{i}", (0.7, 9, 0.7), (px, 4.5, 0), (120, 78, 42), material="Wood")
    mboard = qb.add("MissionBoard", (9.5, 6, 0.5), (0, 6, 0), (110, 70, 40), material="WoodPlanks")
    surface_text(mboard, "MISSÕES DO DIA", color=(255, 230, 120), pps=18)
    px, pz = rot_point(mx, mz, 22, -19, yaw)
    marker(market, "MissionPoint", px, 3, pz, (6, 2, 2))
    # Oficina (melhorias) - 120°
    _, b = shop_building(plaza, 120, "UpgradeShop", (200, 140, 80), (110, 80, 60), "OFICINA", (40, 90, 170), "UpgradeShopPoint", extra="blue")
    b.add("GearSign", (6, 6, 0.6), (0, 18.5, -5), (90, 90, 95), material="Metal")
    b.cyl("Gear", 0.8, 4.6, (0, 18.5, -5.4), (230, 230, 235), rot=(0, 90, 0), material="Metal")
    for i in range(8):
        a = i * 45
        gx, gy = math.cos(math.radians(a)) * 2.6, math.sin(math.radians(a)) * 2.6
        b.add(f"Tooth{i}", (1, 1, 0.8), (gx, 18.5 + gy, -5.4), (230, 230, 235), material="Metal", rot=(0, 0, a))
    # Portão arco-íris trancado (rebirth) - 180°
    rx, rz = polar(SHOP_R, 180)
    yaw = yaw_facing_out(180)
    portal = Inst("Model", "RebirthGate")
    plaza.add(portal)
    pb = Builder(portal, Xf(rx, 0.3, rz, yaw))
    pb.cyl("Base", 1, 30, (0, 0.5, 0), (225, 220, 215), material="Marble")
    for i, px in enumerate((-9, 9)):
        pb.add(f"Pillar{i}", (3.2, 16, 3.2), (px, 8, 0), (215, 210, 220), material="Marble")
        pb.ball(f"PillarTop{i}", 3.6, (px, 16.6, 0), (225, 220, 230), material="Marble")
    for i in range(9):
        pb.add(f"Bar{i}", (0.4, 12, 0.4), (-7 + i * 1.75, 6.5, 0), (90, 90, 110), material="Metal")
    pb.add("BarTop", (16, 0.6, 0.5), (0, 12.6, 0), (90, 90, 110), material="Metal")
    pb.add("BarMid", (16, 0.5, 0.5), (0, 5, 0), (90, 90, 110), material="Metal")
    pb.add("Lock", (3, 3.2, 1.2), (0, 6.5, -0.6), (255, 200, 40), material="Metal", reflect=0.25)
    pb.cyl("Shackle", 0.6, 2.4, (0, 8.6, -0.6), (200, 200, 210), rot=(0, 90, 0), material="Metal")
    pb.cyl("Shield", 16, 26, (0, 8, 4), (200, 160, 255), material="Glass", transparency=0.75, collide=False)
    ex, ez = rot_point(rx, rz, 0, 4, yaw)
    portal.add(make_model("RainbowEgg", asset_egg("arcoiris"), Xf(ex, 14, ez, yaw, 5.0), collide=False))
    glow = Builder(portal, Xf(ex, 18, ez)).ball("RainbowGlow", 1, (0, 0, 0), (255, 255, 255), transparency=1.0, collide=False)
    glow.add(Inst("PointLight", "Light", Range=30.0, Brightness=2.0, Color=Color.rgb(230, 170, 255)))
    sign = pb.add("Sign", (12, 2.6, 0.5), (0, 20, 0), (110, 60, 170))
    surface_text(sign, "REBIRTH", color=(255, 230, 120), pps=24)
    px, pz = rot_point(rx, rz, 0, -6, yaw)
    marker(portal, "RebirthPoint", px, 3, pz, (8, 2, 4))
    # Banco (loja Robux) - 240°
    bx, bz = polar(SHOP_R, 240)
    yaw = yaw_facing_out(240)
    bank = Inst("Model", "Bank")
    plaza.add(bank)
    kb = Builder(bank, Xf(bx, 0.3, bz, yaw))
    kb.add("Steps", (28, 1.6, 20), (0, 0.8, 0), (220, 215, 205), material="Marble")
    kb.add("Body", (24, 12, 14), (0, 7.6, 2), (235, 230, 220), material="Marble")
    for i in range(5):
        kb.cyl(f"Column{i}", 11, 1.8, (-9.6 + i * 4.8, 7.1, -7), (245, 240, 235), material="Marble")
    kb.add("Beam", (26, 1.6, 4), (0, 13.4, -6), (225, 220, 210), material="Marble")
    for side in (-1, 1):
        kb.add(f"Roof{side}", (14.5, 1.2, 20), (side * 6.3, 16, 0), (80, 110, 170), material="Slate", rot=(0, 0, side * -22))
    kb.add("Door", (5, 8, 0.4), (0, 5.6, -5.1), (120, 80, 40), material="Wood")
    kb.cyl("BigCoin", 1.2, 7, (0, 22, -2), (255, 200, 40), rot=(0, 90, 0), material="Metal", reflect=0.3)
    sign = kb.add("Sign", (10, 2.2, 0.4), (0, 13.4, -8.1), (245, 240, 235))
    surface_text(sign, "BANCO", color=(200, 150, 30), pps=24)
    px, pz = rot_point(bx, bz, 0, -12, yaw)
    marker(bank, "StorePoint", px, 3, pz, (6, 2, 2))
    # Fábrica com esteiras (decoração) - 300°
    fx, fz = polar(SHOP_R, 300)
    yaw = yaw_facing_out(300)
    fac = Inst("Model", "Factory")
    plaza.add(fac)
    fb = Builder(fac, Xf(fx, 0.3, fz, yaw))
    fb.add("Body", (28, 14, 18), (0, 7, 4), (150, 160, 175), material="Concrete")
    fb.add("Roof", (29, 1, 19), (0, 14.5, 4), (90, 95, 110), material="Metal")
    for i, (cx, h) in enumerate([(-8, 12), (-3, 16), (8, 10)]):
        fb.cyl(f"Chimney{i}", h, 2.6, (cx, 15 + h / 2, 8), (200, 200, 205), material="Metal")
        fb.cyl(f"ChimneyBand{i}", 1, 2.8, (cx, 14 + h, 8), (220, 80, 50), material="Metal")
    for i in range(3):
        fb.add(f"Hatch{i}", (5, 5, 0.4), (-9 + i * 9, 3.5, -5.1), (40, 45, 55), material="Metal")
        cx2, cz2 = rot_point(fx, fz, -9 + i * 9, -10, yaw)
        scenery(fac, "Esteira", cx2, 0.3, cz2, yaw, name=f"Belt{i}")
        kx, kz = rot_point(fx, fz, -9 + i * 9, -11, yaw)
        coin(fac, f"BeltCoin{i}", kx, 2.2, kz, size=1.8)
    for i in range(2):
        fb.cyl(f"Pipe{i}", 8, 1.4, (15, 4, -1 + i * 3), (220, 90, 60), rot=(0, 0, 0), material="Metal")
    # placas com setas nas trilhas
    for i, deg in enumerate((30, 150, 270)):
        x, z = polar(INNER_R + 18, deg + 4)
        signpost(plaza, x, z, yaw_facing_center(deg) + 90, "GRANJAS")


def build_outskirts(world):
    def free_spot(r_lo, r_hi, avoid_deg=None):
        while True:
            r, deg = rng.uniform(r_lo, r_hi), rng.uniform(0, 360)
            if avoid_deg is not None and any(abs((deg - a + 180) % 360 - 180) < w for a, w in avoid_deg):
                continue
            return r, deg

    # lagos com ponte (entre as granjas, na borda)
    for k, deg in enumerate((15, 195)):
        x, z = polar(408, deg)
        m = Inst("Model", f"Pond{k}")
        world.add(m)
        b = Builder(m, Xf(x, 0, z, -deg))
        b.add("Shore", (70, 0.4, 44), (0, 0.1, 0), (225, 205, 150), material="Sand")
        b.add("Water", (64, 0.5, 38), (0, 0.25, 0), (70, 165, 225), material="Glass", transparency=0.15, collide=False)
        for i in range(8):
            b.add(f"Bridge{i}", (3, 0.6, 12), (-10 + i * 3, 2.2 + math.sin(i / 7 * math.pi) * 1.6, 0), (175, 115, 65), material="WoodPlanks")
        for i, (bx, bz) in enumerate([(-11, -6), (11, -6), (-11, 6), (11, 6)]):
            b.add(f"Rail{i}", (0.5, 3, 0.5), (bx, 3.2, bz), (130, 85, 45), material="Wood")
        b.add("RailL", (22, 0.4, 0.4), (0, 4.6, -6), (130, 85, 45), material="Wood")
        b.add("RailR", (22, 0.4, 0.4), (0, 4.6, 6), (130, 85, 45), material="Wood")
        for i in range(8):
            a = rng.uniform(0, math.pi * 2)
            b.add(f"Rock{i}", (rng.uniform(2, 4), rng.uniform(1, 2), rng.uniform(2, 3)), (math.cos(a) * 34, 0.6, math.sin(a) * 21),
                  (150, 150, 145), material="Rock", rot=(0, rng.uniform(0, 360), 0))
    # moinho num morrinho
    hx, hz = polar(415, 105)
    hill = Builder(world, Xf(hx, -14, hz))
    hill.ball("Hill", 52, (0, 0, 0), (110, 200, 80), material="Grass")
    scenery(world, "Moinho", hx, 9.5, hz, yaw_facing_center(105), scale=1.0, name="Windmill")
    # rotatória com caminhão de entrega
    rx, rz = polar(410, 285)
    rb = Builder(world, Xf(rx, 0, rz))
    rb.cyl("RoundRoad", 0.3, 46, (0, 0.15, 0), (80, 82, 90), material="Asphalt")
    rb.cyl("RoundGrass", 0.5, 24, (0, 0.2, 0), (110, 200, 80), material="Grass")
    scenery(world, "Pinheiro", rx, 0.4, rz, 0, scale=0.9, name="RoundTree")
    tb = Builder(world, Xf(rx + 17, 0.3, rz, 90))
    tb.add("Cargo", (5.5, 5.5, 9), (0, 3.6, 1.5), (245, 245, 240))
    tb.add("Cab", (5.5, 4.2, 4), (0, 2.9, -5), (255, 150, 40))
    tb.add("Windshield", (4.8, 1.8, 0.2), (0, 3.9, -7.05), (120, 180, 230), material="Glass")
    for i, (wx, wz) in enumerate([(-2.8, -4.5), (2.8, -4.5), (-2.8, 3.5), (2.8, 3.5)]):
        tb.cyl(f"Wheel{i}", 0.8, 2.2, (wx, 1.1, wz), (40, 40, 45), rot=(0, 0, 0))
    # pinheiros, árvores, fenos e flores na borda (fora das granjas)
    avoid = [(15, 9), (195, 9), (105, 8), (285, 6)]
    for i in range(70):
        r, deg = free_spot(362, 455, avoid)
        x, z = polar(r, deg)
        if rng.random() < 0.6:
            scenery(world, "Pinheiro", x, 0, z, rng.uniform(0, 360), scale=rng.uniform(0.8, 1.4), name=f"Pine{i}")
        else:
            scenery(world, "Arvore", x, 0, z, rng.uniform(0, 360), scale=rng.uniform(0.8, 1.2), name=f"Tree{i}",
                    leaf=rng.choice([(110, 200, 70), (130, 210, 80), (240, 150, 190)]), apples=rng.random() < 0.5)
    for i in range(16):
        r, deg = free_spot(360, 450, avoid)
        x, z = polar(r, deg)
        scenery(world, "Feno", x, 0, z, rng.uniform(0, 360), name=f"Hay{i}")
    for i in range(10):
        r, deg = free_spot(365, 445, avoid)
        flowers(world, *polar(r, deg))
    # árvores no anel do meio (entre os prédios)
    for i, deg in enumerate((88, 152, 208, 332, 30 + 8, 270 - 8)):
        x, z = polar(SHOP_R + rng.uniform(-14, 14), deg + rng.uniform(-3, 3))
        scenery(world, "Pinheiro" if i % 2 else "Arvore", x, 0.3, z, rng.uniform(0, 360), scale=rng.uniform(0.8, 1.0), name=f"MidTree{i}")


def build_plaza():
    plaza = Inst("Model", "Plaza")
    build_hub(plaza)
    build_ring_buildings(plaza)
    return plaza


def build_assets():
    folder = Inst("Folder", "Assets")
    for kind, name in EGGS:
        m = make_model(name, asset_egg(kind), collide=False)
        m.attributes = {"Placeholder": True}
        folder.add(m)
    for kind, name in BIRDS:
        m = make_model(name, asset_bird(kind), collide=False)
        m.attributes = {"Placeholder": True}
        folder.add(m)
    for name, build in PROPS.items():
        m = make_model(name, build)
        m.attributes = {"Placeholder": True}
        folder.add(m)
    return folder


def build():
    src = os.path.join(ROOT, "src")

    lighting = Inst(
        "Lighting", "Lighting",
        Technology=Token(3),  # ShadowMap (bonito e leve para celular)
        Brightness=2.6,
        ClockTime=14.3,
        GeographicLatitude=28.0,
        GlobalShadows=True,
        Ambient=Color.rgb(110, 100, 95),
        OutdoorAmbient=Color.rgb(165, 155, 150),
        EnvironmentDiffuseScale=1.0,
        EnvironmentSpecularScale=0.6,
        ShadowSoftness=0.35,
        children=[
            Inst("Atmosphere", "Atmosphere", Density=0.22, Offset=0.1, Haze=0.9, Glare=0.25, Color=Color.rgb(205, 225, 245), Decay=Color.rgb(150, 175, 210)),
            Inst("ColorCorrectionEffect", "ColorCorrection", Contrast=0.08, Saturation=0.18, Brightness=0.02, TintColor=Color.rgb(255, 248, 238)),
            Inst("BloomEffect", "Bloom", Intensity=0.4, Size=20, Threshold=1.6),
            Inst("SunRaysEffect", "SunRays", Intensity=0.04, Spread=0.5),
        ],
    )

    plots = Inst("Folder", "Plots")
    for index in range(1, 13):
        deg = (index - 1) * 30 + 15  # 12 granjas em volta da ilha
        cx, cz = polar(PLOT_R, deg)
        plots.add(build_plot(index, cx, cz, yaw_facing_center(deg)))

    spawn = Inst("SpawnLocation", "Spawn", Anchored=True, Size=V3(12, 1, 12), CFrame=CF(0, 0.6, -90), Color=Color8(255, 205, 50),
                 Material=Token(M["Smooth"]), Neutral=True, Duration=Int(0), Transparency=0.4, TopSurface=Token(0), BottomSurface=Token(0))

    world = build_island()
    build_outskirts(world)

    workspace = Inst(
        "Workspace", "Workspace",
        StreamingEnabled=False,
        children=[world, build_plaza(), plots, spawn, Inst("Terrain", "Terrain")],
    )

    shared = Inst("Folder", "Shared", children=scripts_from_dir(os.path.join(src, "ReplicatedStorage", "Shared")))
    replicated = Inst("ReplicatedStorage", "ReplicatedStorage", children=[shared, build_assets()])
    sss = Inst("ServerScriptService", "ServerScriptService", children=scripts_from_dir(os.path.join(src, "ServerScriptService")))
    starter_player = Inst(
        "StarterPlayer", "StarterPlayer",
        CameraMaxZoomDistance=60.0,
        CharacterWalkSpeed=16.0,
        children=[Inst("StarterPlayerScripts", "StarterPlayerScripts", children=scripts_from_dir(os.path.join(src, "StarterPlayer", "StarterPlayerScripts")))],
    )
    players = Inst("Players", "Players", CharacterAutoLoads=False)
    sound = Inst("SoundService", "SoundService")
    chat = Inst("TextChatService", "TextChatService", ChatVersion=Token(1))

    out_dir = os.path.join(ROOT, "place")
    os.makedirs(out_dir, exist_ok=True)
    out = os.path.join(out_dir, "VendaUmOvo.rbxlx")
    count = write_place(out, [lighting, replicated, sss, sound, starter_player, players, chat, workspace])
    print(f"wrote {out}: {count} instances, {part_count} parts")


if __name__ == "__main__":
    build()
