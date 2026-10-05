#!/usr/bin/env python3
"""
Monta o arquivo do jogo VENDA UM OVO (vendaumovo/place/VendaUmOvo.rbxlx) sem abrir o Studio:
  - ReplicatedStorage/Assets: um Model por objeto (ovos, aves, ninho, banca...), feitos de peças,
    seguindo as cores das referências em vendaumovo/arte/. Troque pelo 3D de verdade mantendo o nome.
  - O mapa: rua comprida com calçada (estilo barraquinha de limonada), 12 granjas, praça com as lojas,
    moinhos, árvores, fardos de feno, postes e flores, tudo um pouco "torto" de propósito.
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


ROAD_HALF = 14
SIDEWALK = 8
PLOT_W, PLOT_D = 110, 100
PLOT_XS = [-420, -290, -160, 160, 290, 420]
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


def build_plaza():
    plaza = Inst("Model", "Plaza")
    # chão de pedrinhas
    box(plaza, "Paving", 0, 0.2, 0, 190, 0.4, 150, (225, 200, 160), "Pebble")
    box(plaza, "Ring", 0, 0.3, 0, 60, 0.3, 60, (205, 175, 135), "Cobblestone")
    # fonte no meio (no lugar da rua, que dá a volta)
    fb = Builder(plaza, Xf(0, 0.3, 0))
    fb.cyl("Basin", 2.4, 26, (0, 1.2, 0), (200, 195, 190), material="Concrete")
    fb.cyl("Water", 0.4, 24, (0, 2.3, 0), (90, 180, 240), material="Glass", transparency=0.25, collide=False)
    fb.cyl("Column", 6, 3, (0, 4, 0), (210, 205, 200), material="Concrete")
    fb.egg("BigEgg", 5, 6.6, (0, 10.2, 0), (255, 215, 70), material="Metal", reflect=0.25)
    fb.cyl("Spout", 0.6, 4, (0, 7.3, 0), (90, 180, 240), material="Glass", transparency=0.3, collide=False)

    # placa grande "VENDA UM OVO" na entrada da praça
    scenery(plaza, "Placa", 0, 0.4, -60, 180, scale=1.6, name="BigSign", height=None)
    scenery(plaza, "Placa", 0, 0.4, 60, 0, scale=1.6, name="BigSign2")

    # LOJA DE GALINHAS (Galinheiro do Seu Zé) - lado norte
    shop = Inst("Model", "HenShop")
    plaza.add(shop)
    b = Builder(shop, Xf(-45, 0.4, 38, 0))
    b.add("Body", (26, 12, 14), (0, 6, 0), (205, 60, 50), material="WoodPlanks", Tex="Madeira")
    for side in (-1, 1):
        b.add(f"Roof{side}", (28, 0.8, 9.5), (0, 14.2, side * 4), (120, 35, 30), material="Slate", rot=(side * -30, 0, 0), Tex="Telha")
    b.add("Window", (14, 5, 0.4), (0, 6.5, -7.05), (60, 35, 20))
    b.add("Counter", (16, 3.6, 3), (0, 1.8, -8.6), (255, 235, 190), material="WoodPlanks")
    b.add("Trim", (27, 0.6, 15), (0, 12, 0), (250, 245, 235))
    sign = b.add("Sign", (18, 3.4, 0.6), (0, 17.6, -2.5), (255, 248, 230), material="WoodPlanks")
    surface_text(sign, "GALINHEIRO DO SEU ZÉ", color=(200, 60, 40), pps=22)
    hx, hz = rot_point(-45, 38, 0, -10, 0)
    marker(shop, "HenShopPoint", hx, 3, hz, (6, 2, 2))
    for i, (lx, lz) in enumerate([(-15, 2), (-15.5, -3), (15, 4), (15.5, -1.5)]):
        bx, bz = rot_point(-45, 38, lx, lz, 0)
        scenery(shop, "Feno", bx, 0.4, bz, 90 + rng.uniform(-12, 12), scale=0.75, name=f"ShopHay{i}")

    # LOJA DE UPGRADES (Oficina) - lado norte, à direita
    up = Inst("Model", "UpgradeShop")
    plaza.add(up)
    b = Builder(up, Xf(45, 0.4, 38, 0))
    b.add("Body", (26, 12, 14), (0, 6, 0), (70, 130, 200), material="WoodPlanks", Tex="Madeira")
    b.add("Roof", (28, 1, 16), (0, 12.5, 0), (50, 60, 80), material="Metal")
    b.add("Door", (12, 8, 0.4), (0, 4, -7.05), (40, 45, 55), material="Metal")
    b.add("Counter", (16, 3.6, 3), (0, 1.8, -8.6), (255, 205, 50), material="Metal")
    sign = b.add("Sign", (16, 3.4, 0.6), (0, 15.2, -6.2), (255, 248, 230), material="WoodPlanks")
    surface_text(sign, "OFICINA", color=(40, 90, 170), pps=22)
    b.cyl("Gear", 0.6, 4.5, (9.5, 15.2, -6.4), (255, 205, 50), rot=(0, 90, 0), material="Metal")
    ux, uz = rot_point(45, 38, 0, -10, 0)
    marker(up, "UpgradeShopPoint", ux, 3, uz, (6, 2, 2))

    # ALTAR DO REBIRTH - lado sul, à esquerda
    alt = Inst("Model", "RebirthAltar")
    plaza.add(alt)
    b = Builder(alt, Xf(-45, 0.4, -40))
    b.cyl("Base", 1.6, 16, (0, 0.8, 0), (120, 70, 170), material="Marble")
    b.cyl("Top", 1, 10, (0, 2.1, 0), (160, 100, 220), material="Marble")
    star = b.add("Star", (2.4, 2.4, 0.6), (0, 7, 0), (255, 220, 80), neon=True, collide=False, rot=(0, 0, 45))
    star.add(Inst("PointLight", "Light", Range=18.0, Brightness=2.0, Color=Color.rgb(200, 140, 255)))
    b.add("Star2", (2.4, 2.4, 0.6), (0, 7, 0), (255, 220, 80), neon=True, collide=False)
    sign = b.add("Sign", (10, 2.4, 0.4), (0, 11, 0), (90, 50, 140))
    surface_text(sign, "REBIRTH", color=(255, 230, 120), pps=24)
    surface_text(sign, "REBIRTH", color=(255, 230, 120), pps=24, face=BACK, name="GuiBack")
    marker(alt, "RebirthPoint", -45, 3, -40, (6, 2, 6))

    # QUADRO DE MISSÕES e PLACAR - lado sul, à direita
    board = Inst("Model", "Boards")
    plaza.add(board)
    b = Builder(board, Xf(30, 0.4, -46))
    for i, x in enumerate((-6.5, 6.5)):
        b.add(f"Post{i}", (0.8, 12, 0.8), (x, 6, 0), (120, 78, 42), material="Wood")
    mb = b.add("MissionBoard", (13, 8, 0.6), (0, 8, 0), (110, 70, 40), material="WoodPlanks")
    surface_text(mb, "MISSÕES DO DIA", color=(255, 230, 120), pps=18, face=BACK)
    marker(board, "MissionPoint", 30, 3, -43, (6, 2, 2))
    b = Builder(board, Xf(58, 0.4, -40, -25))
    for i, x in enumerate((-8, 8)):
        b.add(f"LPost{i}", (1, 18, 1), (x, 9, 0), (120, 78, 42), material="Wood")
    lb = b.add("LeaderboardBoard", (16, 15, 0.6), (0, 10.5, 0), (255, 236, 190), material="WoodPlanks")
    lb.add(Inst("SurfaceGui", "Gui", Face=Token(BACK), SizingMode=Token(SIZING_PPS), PixelsPerStud=20.0, LightInfluence=0.0,
                AutoLocalize=False, children=[
                    Inst("TextLabel", "Title", Size=UDim2(1, 0, 0.16, 0), BackgroundColor3=Color.rgb(255, 205, 50), Text="🏆 MAIORES VENDEDORES",
                         TextScaled=True, Font=Token(FONT_FREDOKA), TextColor3=Color.rgb(110, 62, 28)),
                ]))

    # bancos, postes e canteiros
    for i, (x, z, yw) in enumerate([(-70, 15, 90), (70, -15, -90), (-20, 52, 180), (20, -52, 0)]):
        bench(plaza, x, z, yw)
    for i, (x, z) in enumerate([(-80, 60), (80, 60), (-80, -60), (80, -60)]):
        flowers(plaza, x, z)
    for i, (x, z) in enumerate([(-88, 30), (88, 30), (-88, -30), (88, -30), (-60, 70), (60, -70)]):
        scenery(plaza, "Arvore", x + rng.uniform(-2, 2), 0.4, z + rng.uniform(-2, 2), rng.uniform(0, 360),
                scale=rng.uniform(0.8, 1.1), name=f"PlazaTree{i}", leaf=rng.choice([(110, 200, 70), (240, 150, 190)]))
    return plaza


def build_world():
    world = Inst("Model", "Map")
    # chão gramado bem grande
    box(world, "Ground", 0, -0.5, 0, 1500, 1, 900, (100, 190, 75), "Grass", Tex="Grama")
    # rua principal (de ponta a ponta) com faixa e calçadas
    box(world, "Road", 0, 0.12, 0, 1100, 0.25, ROAD_HALF * 2, (85, 85, 92), "Asphalt")
    for x in range(-540, 541, 18):
        if abs(x) > 98:
            box(world, f"Dash{x}", x, 0.27, 0, 8, 0.05, 0.8, (255, 220, 60), "Smooth", collide=False)
    for side in (-1, 1):
        box(world, f"Sidewalk{side}", 0, 0.3, side * (ROAD_HALF + SIDEWALK / 2), 1100, 0.6, SIDEWALK, (215, 210, 200), "Concrete")
        box(world, f"Curb{side}", 0, 0.35, side * (ROAD_HALF + 0.3), 1100, 0.7, 0.6, (245, 245, 240), "Concrete")
        for i, x in enumerate(range(-520, 521, 65)):
            if abs(x) > 100:
                street_lamp(world, x + rng.uniform(-4, 4), side * (ROAD_HALF + SIDEWALK - 1.5), 0 if side < 0 else 180)
    # moinhos e árvores em volta (borda do mapa), com tamanhos e giros variados
    for i, (x, z) in enumerate([(-560, 200), (520, -230), (-300, -260), (360, 250), (0, 300), (-120, -320)]):
        scenery(world, "Moinho", x + rng.uniform(-15, 15), 0, z + rng.uniform(-10, 10), rng.uniform(-40, 40) + (0 if z < 0 else 180),
                scale=rng.uniform(0.85, 1.25), name=f"Windmill{i}")
    # plantações, lago com píer e um celeiro grande nas bordas (o mapa não fica só gramado)
    for i, (x, z, yw) in enumerate([(-420, 230, 8), (240, 240, -6), (-200, -250, 4), (430, -260, -10)]):
        crop_field(world, f"Field{i}", x, z, yw, rng.choice([(255, 210, 60), (110, 190, 60), (240, 120, 50)]))
    pond(world, 160, -270)
    barn(world, -560, -90, 75)
    for i in range(70):
        while True:
            x, z = rng.uniform(-700, 700), rng.uniform(-420, 420)
            if abs(z) > 145 or abs(x) > 500:
                break
        scenery(world, "Arvore", x, 0, z, rng.uniform(0, 360), scale=rng.uniform(0.7, 1.5), name=f"Tree{i}",
                leaf=rng.choice([(110, 200, 70), (95, 180, 60), (130, 210, 80), (240, 150, 190)]), apples=rng.random() < 0.5)
    for i in range(30):
        while True:
            x, z = rng.uniform(-650, 650), rng.uniform(-400, 400)
            if abs(z) > 140 or abs(x) > 500:
                break
        scenery(world, "Feno", x, 0, z, rng.uniform(0, 360), scale=rng.uniform(0.8, 1.2), name=f"Hay{i}")
    return world


def crop_field(parent, name, x, z, yaw, crop):
    field = Inst("Model", name)
    parent.add(field)
    b = Builder(field, Xf(x, 0, z, yaw), collide=False)
    b.add("Soil", (90, 0.6, 60), (0, 0.1, 0), (150, 100, 60), material="Ground", Tex="Terra")
    for row in range(10):
        lz = -26 + row * 5.8
        b.add(f"Row{row}", (84, 0.5, 2.2), (0, 0.55, lz), (120, 80, 45), material="Ground")
        for k in range(14):
            lx = -40 + k * 6 + rng.uniform(-0.8, 0.8)
            h = rng.uniform(2.0, 3.4)
            b.add(f"Stalk{row}_{k}", (0.4, h, 0.4), (lx, 0.6 + h / 2, lz), (80, 160, 60))
            b.ball(f"Crop{row}_{k}", rng.uniform(1.0, 1.5), (lx, 0.6 + h, lz), crop)
    for i, side in enumerate((-1, 1)):
        for k in range(10):
            fx, fz = rot_point(x, z, -45 + k * 10 + 5, side * 31, yaw)
            scenery(field, "Cerca", fx, 0, fz, yaw, name=f"Fence{i}_{k}")


def pond(parent, x, z):
    m = Inst("Model", "Pond")
    parent.add(m)
    b = Builder(m, Xf(x, 0, z, 12))
    b.cyl("Shore", 0.5, 92, (0, 0.05, 0), (225, 205, 150), material="Sand")
    b.cyl("Water", 0.4, 84, (0, 0.2, 0), (70, 165, 225), material="Glass", transparency=0.15, collide=False)
    b.cyl("Water2", 0.3, 50, (14, 0.25, 10), (90, 185, 240), material="Glass", transparency=0.2, collide=False)
    for i in range(6):
        b.add(f"Dock{i}", (6, 0.5, 3), (0, 1.2, -44 + i * 3.1), (170, 115, 65), material="WoodPlanks")
    for i, (lx, lz) in enumerate([(-3, -40), (3, -40), (-3, -30), (3, -30)]):
        b.add(f"DockPost{i}", (0.6, 3, 0.6), (lx, 0.6, lz), (120, 78, 42), material="Wood")
    for i in range(10):
        a = rng.uniform(0, math.pi * 2)
        r = rng.uniform(18, 36)
        b.cyl(f"Lily{i}", 0.15, rng.uniform(2, 3.5), (math.cos(a) * r, 0.45, math.sin(a) * r), (90, 175, 80), collide=False)
    for i in range(14):
        a = i * math.pi * 2 / 14 + rng.uniform(-0.1, 0.1)
        b.add(f"Rock{i}", (rng.uniform(2, 4), rng.uniform(1, 2), rng.uniform(2, 3.5)), (math.cos(a) * 45, 0.5, math.sin(a) * 45),
              (150, 150, 145), material="Rock", rot=(rng.uniform(-10, 10), rng.uniform(0, 360), rng.uniform(-10, 10)))


def barn(parent, x, z, yaw):
    m = Inst("Model", "Barn")
    parent.add(m)
    b = Builder(m, Xf(x, 0, z, yaw))
    b.add("Body", (40, 18, 30), (0, 9, 0), (190, 45, 40), material="WoodPlanks", Tex="Madeira")
    for side in (-1, 1):
        b.add(f"Roof{side}", (42, 1, 19), (0, 22.5, side * 8.2), (70, 70, 75), material="Metal", rot=(side * -33, 0, 0))
    b.add("Door", (14, 14, 0.5), (0, 7, -15.1), (240, 235, 225), material="WoodPlanks")
    for k, rz in enumerate((45, -45)):
        b.add(f"DoorX{k}", (19, 0.8, 0.3), (0, 7, -15.4), (190, 45, 40), rot=(0, 0, rz))
    b.add("Loft", (6, 5, 0.5), (0, 16, -15.1), (240, 235, 225))
    surface_text(b.add("BarnSign", (16, 3, 0.4), (0, 20.5, -12.4), (250, 245, 235), rot=(-33, 0, 0)), "FAZENDA", color=(190, 45, 40), pps=18)
    for i in range(6):
        hx, hz = rot_point(x, z, -18 + i * 6 + rng.uniform(-1, 1), -22 + rng.uniform(-2, 2), yaw)
        scenery(m, "Feno", hx, 0, hz, rng.uniform(0, 360), name=f"BarnHay{i}")


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
    index = 0
    for z_side, yaw in ((1, 0.0), (-1, 180.0)):
        for x in PLOT_XS:
            index += 1
            cz = z_side * (ROAD_HALF + SIDEWALK + 2 + PLOT_D / 2)
            plots.add(build_plot(index, x, cz, yaw))

    spawn = Inst("SpawnLocation", "Spawn", Anchored=True, Size=V3(12, 1, 12), CFrame=CF(0, 0.6, -40), Color=Color8(255, 205, 50),
                 Material=Token(M["Smooth"]), Neutral=True, Duration=Int(0), Transparency=0.4, TopSurface=Token(0), BottomSurface=Token(0))

    workspace = Inst(
        "Workspace", "Workspace",
        StreamingEnabled=False,
        children=[build_world(), build_plaza(), plots, spawn, Inst("Terrain", "Terrain")],
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
