#!/usr/bin/env python3
"""
Monta o arquivo do jogo ZONA ZERO (zonazero/place/ZonaZero.rbxlx) sem abrir o Studio:
serviços, iluminação, o mapa (ilha com cidade, fazenda, armazém, posto, torre, florestas),
o lobby, os pontos de loot e todos os scripts de zonazero/src.

    python3 zonazero/builder/build.py
"""
import math
import os
import random
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
sys.path.insert(0, os.path.join(os.path.dirname(ROOT), "tools"))

from rbxlx import CF, Color, Color8, Inst, Int, Token, UDim2, V3, scripts_from_dir, write_place  # noqa: E402

rng = random.Random(20261002)  # mapa sempre igual (mude o número para outro mapa)

# Materiais (Enum.Material.*.Value)
M = {
    "Plastic": 256, "Smooth": 272, "Neon": 288, "Wood": 512, "WoodPlanks": 528, "Marble": 784,
    "Slate": 800, "Concrete": 816, "Granite": 832, "Brick": 848, "Pebble": 864, "Cobblestone": 880,
    "Rock": 896, "Sandstone": 912, "CorrodedMetal": 1040, "DiamondPlate": 1056, "Metal": 1088,
    "Grass": 1280, "LeafyGrass": 1284, "Sand": 1296, "Fabric": 1312, "Ground": 1360,
    "Asphalt": 1376, "Glass": 1568,
}
CYL, BALL = 2, 0
FONT_BLACK, FONT_FRONT, SIZING_PPS = 20, 5, 1  # Enum.Font.GothamBlack, Enum.NormalId.Front, Enum.SurfaceGuiSizingMode.PixelsPerStud

part_count = 0


def part(name, size, cframe, color, material="Smooth", cls="Part", shape=None, collide=True, transparency=0.0, **extra):
    global part_count
    part_count += 1
    props = dict(
        Anchored=True,
        Size=V3(*size),
        CFrame=cframe,
        Color=Color8(*color),
        Material=Token(M[material]),
        TopSurface=Token(0),
        BottomSurface=Token(0),
    )
    if shape is not None:
        props["Shape"] = Token(shape)
    if not collide:
        props["CanCollide"] = False
    if transparency:
        props["Transparency"] = float(transparency)
    props.update(extra)
    return Inst(cls, name, **props)


def box(name, cx, cy, cz, sx, sy, sz, color, material="Smooth", ry=0.0, **kw):
    """Peça com centro (cx, cy, cz), tamanho (sx, sy, sz) e giro ry (graus) em volta do eixo Y."""
    return part(name, (sx, sy, sz), CF.angles(cx, cy, cz, 0, math.radians(ry), 0), color, material, **kw)


def rot_point(ox, oz, x, z, ry):
    """Gira o ponto local (x, z) em volta da origem (ox, oz) pelo ângulo ry (graus)."""
    a = math.radians(ry)
    # mesma convenção do CFrame.Angles(0, a, 0): x' = x cos + z sin ; z' = -x sin + z cos
    return ox + x * math.cos(a) + z * math.sin(a), oz - x * math.sin(a) + z * math.cos(a)


loot_spots = []


def loot(x, y, z):
    loot_spots.append((x, y, z))


# ---------------------------------------------------------------------------
# Construções
# ---------------------------------------------------------------------------
WALL_COLORS = [(214, 204, 186), (190, 120, 95), (150, 160, 170), (226, 214, 160), (140, 170, 150), (205, 185, 170)]
ROOF_COLORS = [(120, 60, 50), (70, 75, 85), (95, 70, 55), (60, 90, 80)]


def wall_with_openings(model, name, ox, oz, ry, x0, x1, zline, y0, h, thick, color, material, openings):
    """Parede ao longo de x (local) de x0 a x1 na linha zline, com vãos [(centro, largura, base, altura)]."""
    segments = []
    cursor = x0
    for (c, w, base, oh) in sorted(openings):
        a, b = c - w / 2, c + w / 2
        if a > cursor:
            segments.append((cursor, a, y0, h))
        # em cima e embaixo do vão
        if base > 0:
            segments.append((a, b, y0, base))
        top = base + oh
        if top < h:
            segments.append((a, b, y0 + top, h - top))
        cursor = b
    if cursor < x1:
        segments.append((cursor, x1, y0, h))
    for i, (a, b, sy, sh) in enumerate(segments):
        if b - a < 0.05 or sh < 0.05:
            continue
        lx = (a + b) / 2
        wx, wz = rot_point(ox, oz, lx, zline, ry)
        model.add(box(f"{name}{i}", wx, sy + sh / 2, wz, b - a, sh, thick, color, material, ry))


def house(ox, oz, ry, w, d, floors=1, color=None, roof=None, name="House"):
    """Casa de w x d com 1 ou 2 andares, porta, janelas, telhado e escada interna."""
    color = color or rng.choice(WALL_COLORS)
    roof = roof or rng.choice(ROOF_COLORS)
    material = rng.choice(["Concrete", "Brick", "Smooth", "WoodPlanks"])
    m = Inst("Model", name)
    H = 12.0
    T = 1.0
    hx, hz = w / 2, d / 2
    for f in range(floors):
        y0 = f * H
        # chão do andar
        fx, fz = rot_point(ox, oz, 0, 0, ry)
        if f == 0:
            m.add(box("Floor", fx, 0.25, fz, w, 0.5, d, (110, 100, 90), "WoodPlanks", ry))
        else:
            # laje com buraco da escada (escada no canto x>0)
            stair_w = 6
            sx0 = hx - stair_w - T
            lx, lz = rot_point(ox, oz, (-hx + sx0) / 2, 0, ry)
            m.add(box("Slab", lx, y0, lz, sx0 + hx, 1, d, (120, 110, 100), "WoodPlanks", ry))
            lx, lz = rot_point(ox, oz, sx0 + stair_w / 2, -hz / 2 - 1, ry)
            m.add(box("SlabB", lx, y0, lz, stair_w, 1, hz - 2, (120, 110, 100), "WoodPlanks", ry))
        door = (0.0 if f == 0 else 99, 5, 0, 8)
        win = lambda c: (c, 4, 4, 4)  # noqa: E731
        front_open = [win(-w / 4), win(w / 4)] if f > 0 else [door, win(-w / 3), win(w / 3)]
        if f == 0:
            front_open = [o for o in front_open if abs(o[0]) < hx - 2]
        else:
            front_open = [o for o in front_open if abs(o[0]) < hx - 2]
        wall_with_openings(m, f"Front{f}_", ox, oz, ry, -hx, hx, -hz, y0 + (0.5 if f == 0 else 0.5), H - 0.5, T, color, material, front_open)
        wall_with_openings(m, f"Back{f}_", ox, oz, ry, -hx, hx, hz, y0 + 0.5, H - 0.5, T, color, material, [win(0)] if w > 14 else [])
        # paredes laterais (giradas 90°)
        side_open = [win(0)] if d > 14 else []
        if f == 0 and d > 20:
            side_open = [(d / 4, 5, 0, 8)]  # porta lateral
        wall_with_openings(m, f"Left{f}_", ox, oz, ry + 90, -hz + T, hz - T, -hx, y0 + 0.5, H - 0.5, T, color, material, side_open)
        wall_with_openings(m, f"Right{f}_", ox, oz, ry + 90, -hz + T, hz - T, hx, y0 + 0.5, H - 0.5, T, color, material, [win(0)] if d > 14 else [])
        # loot no andar
        for _ in range(2 if w * d > 300 else 1):
            lx, lz = rot_point(ox, oz, rng.uniform(-hx + 3, hx - 9), rng.uniform(-hz + 3, hz - 3), ry)
            loot(lx, y0 + 1, lz)
    if floors > 1:
        # rampa/escada até o 2º andar, no canto x>0 encostada na parede de trás... da frente para trás
        stair_w = 6
        run = d - 4
        rise = H
        sx = hx - T - stair_w / 2
        steps = 10
        for s in range(steps):
            sz = -hz + 2 + run * (s + 0.5) / steps
            sy = rise * (s + 1) / steps
            lx, lz = rot_point(ox, oz, sx, sz, ry)
            m.add(box(f"Step{s}", lx, sy / 2, lz, stair_w, sy, run / steps, (100, 90, 80), "WoodPlanks", ry))
    # telhado (laje com beiral) e loot em cima
    top = floors * H
    fx, fz = rot_point(ox, oz, 0, 0, ry)
    m.add(box("Roof", fx, top + 0.5, fz, w + 2, 1, d + 2, roof, "Slate", ry))
    m.add(box("RoofTrim", fx, top + 1.3, fz, w + 2.4, 0.6, d + 2.4, roof, "Slate", ry, transparency=0))
    return m


def warehouse(ox, oz, ry, w=70, d=44):
    m = Inst("Model", "Warehouse")
    H = 22
    col = (120, 125, 130)
    hx, hz = w / 2, d / 2
    fx, fz = rot_point(ox, oz, 0, 0, ry)
    m.add(box("Floor", fx, 0.25, fz, w, 0.5, d, (90, 90, 90), "Concrete", ry))
    wall_with_openings(m, "Front", ox, oz, ry, -hx, hx, -hz, 0.5, H, 1.2, col, "CorrodedMetal", [(-w / 4, 14, 0, 14), (w / 4, 14, 0, 14)])
    wall_with_openings(m, "Back", ox, oz, ry, -hx, hx, hz, 0.5, H, 1.2, col, "CorrodedMetal", [(0, 10, 0, 10)])
    wall_with_openings(m, "Left", ox, oz, ry + 90, -hz, hz, -hx, 0.5, H, 1.2, col, "CorrodedMetal", [(0, 8, 0, 9)])
    wall_with_openings(m, "Right", ox, oz, ry + 90, -hz, hz, hx, 0.5, H, 1.2, col, "CorrodedMetal", [])
    m.add(box("Roof", fx, H + 1, fz, w + 2, 1, d + 2, (80, 85, 90), "CorrodedMetal", ry))
    # passarela interna (2º nível) com rampa
    lx, lz = rot_point(ox, oz, 0, hz - 5, ry)
    m.add(box("Catwalk", lx, 11, lz, w - 4, 1, 8, (70, 70, 75), "DiamondPlate", ry))
    for s in range(12):
        lx, lz = rot_point(ox, oz, -hx + 6 + s * 2.2, hz - 14, ry)
        m.add(box(f"RampStep{s}", lx, (s + 1) * 11 / 12 / 2, lz, 2.2, (s + 1) * 11 / 12, 6, (70, 70, 75), "DiamondPlate", ry))
    # contêineres e caixas
    for i in range(5):
        lx, lz = rot_point(ox, oz, -hx + 10 + i * 12, rng.uniform(-hz + 6, 0), ry)
        c = rng.choice([(180, 60, 50), (50, 110, 170), (60, 140, 80), (200, 150, 50)])
        m.add(box(f"Crate{i}", lx, 4.5, lz, 6, 8, 10, c, "CorrodedMetal", ry + rng.choice([0, 90])))
        lx2, lz2 = rot_point(ox, oz, -hx + 10 + i * 12, -hz + 4, ry)
        loot(lx2, 1, lz2)
    for i in range(3):
        lx, lz = rot_point(ox, oz, -hx + 12 + i * 20, hz - 5, ry)
        loot(lx, 12, lz)
    return m


def tree(x, z, scale=1.0):
    m = Inst("Model", "Tree")
    h = rng.uniform(10, 16) * scale
    m.add(part("Trunk", (h, 1.6 * scale, 1.6 * scale), CF.angles(x, h / 2, z, 0, 0, math.radians(90)), (100, 70, 45), "Wood", shape=CYL))
    green = rng.choice([(60, 120, 55), (75, 135, 60), (50, 105, 60), (90, 140, 70)])
    for i in range(rng.randint(2, 3)):
        r = rng.uniform(7, 10) * scale
        m.add(part(f"Leaves{i}", (r, r, r), CF(x + rng.uniform(-2, 2), h + i * 2.5, z + rng.uniform(-2, 2)), green, "LeafyGrass", shape=BALL))
    return m


def pine(x, z):
    m = Inst("Model", "Pine")
    h = rng.uniform(16, 24)
    m.add(part("Trunk", (h, 1.4, 1.4), CF.angles(x, h / 2, z, 0, 0, math.radians(90)), (90, 65, 45), "Wood", shape=CYL))
    for i in range(3):
        s = 10 - i * 3
        m.add(box(f"Cone{i}", x, h * 0.45 + i * 4.5, z, s, 5, s, (40, 90, 55), "LeafyGrass", ry=rng.uniform(0, 90)))
        m.add(box(f"Cone{i}b", x, h * 0.45 + i * 4.5, z, s, 5, s, (40, 90, 55), "LeafyGrass", ry=45 + rng.uniform(0, 30)))
    return m


def rock(x, z, s):
    c = rng.choice([(120, 120, 115), (105, 100, 95), (135, 130, 120)])
    return box("Rock", x, s * 0.35, z, s * rng.uniform(1.0, 1.6), s * 0.9, s * rng.uniform(0.9, 1.4), c, "Rock", ry=rng.uniform(0, 90))


def hill(x, z, w, d, h, ry):
    """Morro: um platô com duas rampas (WedgeParts)."""
    m = Inst("Model", "Hill")
    green = (95, 140, 70)
    m.add(box("Top", x, h / 2, z, w, h, d, green, "Grass", ry))
    # rampa da frente e de trás
    for side in (-1, 1):
        ramp_len = h * 2.5
        lx, lz = rot_point(x, z, 0, side * (d / 2 + ramp_len / 2), ry)
        yaw = ry + (180 if side < 0 else 0)
        m.add(part("Ramp", (w, h, ramp_len), CF.angles(lx, h / 2, lz, 0, math.radians(yaw), 0), green, "Grass", cls="WedgePart"))
    return m


# ---------------------------------------------------------------------------
# O mapa
# ---------------------------------------------------------------------------
def build_map():
    MAP = 1400
    mp = Inst("Model", "Map")
    ground = Inst("Folder", "Ground")
    mp.add(ground)
    # chão em blocos com tons diferentes (fica menos "liso")
    tile = 350
    for ix in range(4):
        for iz in range(4):
            cx = -MAP / 2 + tile / 2 + ix * tile
            cz = -MAP / 2 + tile / 2 + iz * tile
            g = rng.choice([(95, 140, 70), (100, 145, 72), (90, 135, 68), (104, 140, 76)])
            ground.add(box("Grass", cx, -2, cz, tile, 4, tile, g, "Grass"))
    # bordas: penhascos altos
    for i, (cx, cz, sx, sz) in enumerate([(0, MAP / 2 + 10, MAP + 40, 20), (0, -MAP / 2 - 10, MAP + 40, 20), (MAP / 2 + 10, 0, 20, MAP + 40), (-MAP / 2 - 10, 0, 20, MAP + 40)]):
        ground.add(box(f"Cliff{i}", cx, 40, cz, sx, 84, sz, (110, 105, 95), "Rock"))
    # mar/areia perto das bordas (faixa de areia)
    for i, (cx, cz, sx, sz) in enumerate([(0, MAP / 2 - 20, MAP, 40), (0, -MAP / 2 + 20, MAP, 40), (MAP / 2 - 20, 0, 40, MAP), (-MAP / 2 + 20, 0, 40, MAP)]):
        ground.add(box(f"Sand{i}", cx, 0.05, cz, sx, 0.2, sz, (215, 200, 150), "Sand"))

    roads = Inst("Folder", "Roads")
    mp.add(roads)
    asphalt = (55, 55, 60)
    roads.add(box("RoadNS", 0, 0.1, 0, 22, 0.25, MAP - 80, asphalt, "Asphalt"))
    roads.add(box("RoadEW", 0, 0.1, 0, MAP - 80, 0.25, 22, asphalt, "Asphalt"))
    for i in range(-14, 15):
        if abs(i) > 1:
            roads.add(box(f"LineNS{i}", 0, 0.25, i * 45, 0.8, 0.05, 14, (240, 220, 120), "Smooth", collide=False))
            roads.add(box(f"LineEW{i}", i * 45, 0.25, 0, 14, 0.05, 0.8, (240, 220, 120), "Smooth", collide=False))

    # --- CIDADE (centro) ---
    town = Inst("Folder", "Town")
    mp.add(town)
    town.add(box("Plaza", 0, 0.15, 0, 60, 0.3, 60, (170, 165, 155), "Cobblestone"))
    town.add(part("Fountain", (2, 14, 14), CF.angles(0, 1, 0, 0, 0, math.radians(90)), (160, 160, 165), "Marble", shape=CYL))
    town.add(part("FountainTop", (6, 3, 3), CF.angles(0, 4, 0, 0, 0, math.radians(90)), (160, 160, 165), "Marble", shape=CYL))
    loot(0, 2.5, 0)
    blocks = [(-60, -60), (60, -60), (-60, 60), (60, 60), (-120, -55), (120, -55), (-120, 55), (120, 55), (-55, -120), (55, -120), (-55, 120), (55, 120), (-125, -125), (125, 125), (-125, 125), (125, -125)]
    for i, (bx, bz) in enumerate(blocks):
        floors = 2 if i % 3 == 0 else 1
        ry = 0 if abs(bx) > abs(bz) else 90
        ry += 180 if (bx > 0 if ry == 0 else bz > 0) else 0
        town.add(house(bx, bz, ry, rng.choice([20, 24, 28]), rng.choice([18, 22, 26]), floors, name=f"House{i}"))
    # carros abandonados (cobertura)
    for i in range(8):
        cx = rng.choice([-1, 1]) * rng.uniform(30, 300)
        cz = rng.uniform(-6, 6)
        if i % 2:
            cx, cz = cz, cx
        town.add(car(cx, cz, rng.choice([0, 90]) + rng.uniform(-15, 15)))

    # --- FAZENDA (nordeste) ---
    farm = Inst("Folder", "Farm")
    mp.add(farm)
    fx, fz = 380, -380
    farm.add(barn(fx, fz))
    for i in range(2):
        farm.add(part(f"Silo{i}", (40, 14, 14), CF.angles(fx + 40, 20, fz - 30 + i * 18, 0, 0, math.radians(90)), (200, 200, 205), "Metal", shape=CYL))
        loot(fx + 40, 1, fz - 22 + i * 18)
    for i in range(12):
        hx, hz = fx - 70 + rng.uniform(-40, 40), fz + 50 + rng.uniform(-40, 40)
        farm.add(part(f"Hay{i}", (5, 5, 5), CF.angles(hx, 2.5, hz, 0, rng.uniform(0, 3), math.radians(90)), (220, 190, 90), "Fabric", shape=CYL))
    for i in range(4):
        loot(fx - 70 + rng.uniform(-30, 30), 1, fz + 50 + rng.uniform(-30, 30))
    # plantação
    for i in range(8):
        farm.add(box(f"Field{i}", fx - 60 + i * 9, 0.4, fz - 70, 6, 0.8, 70, (110, 85, 55), "Ground"))
    for i in range(3):
        farm.add(house(fx + rng.uniform(-90, 60), fz + rng.uniform(90, 150), rng.choice([0, 90, 180, 270]), 20, 18, 1, name=f"FarmHouse{i}"))

    # --- ARMAZÉM / PORTO (sudoeste) ---
    port = Inst("Folder", "Docks")
    mp.add(port)
    px, pz = -380, 380
    port.add(warehouse(px, pz, 0))
    port.add(warehouse(px + 95, pz + 20, 90, 54, 36))
    for i in range(14):
        cx, cz = px - 80 + (i % 7) * 16, pz - 80 - (i // 7) * 14
        c = rng.choice([(180, 60, 50), (50, 110, 170), (60, 140, 80), (200, 150, 50), (120, 120, 125)])
        stack = rng.choice([1, 1, 2])
        for s in range(stack):
            port.add(box(f"Container{i}_{s}", cx, 4.5 + s * 9, cz, 12, 9, 26 if i % 3 else 13, c, "CorrodedMetal"))
        loot(cx + 8, 1, cz)
    # guindaste
    port.add(box("CraneLeg1", px - 120, 30, pz - 40, 3, 60, 3, (230, 180, 40), "Metal"))
    port.add(box("CraneLeg2", px - 120, 30, pz - 10, 3, 60, 3, (230, 180, 40), "Metal"))
    port.add(box("CraneArm", px - 100, 61, pz - 25, 60, 3, 3, (230, 180, 40), "Metal"))

    # --- POSTO DE GASOLINA (noroeste) ---
    gas = Inst("Folder", "GasStation")
    mp.add(gas)
    gx, gz = -360, -330
    gas.add(box("Lot", gx, 0.15, gz, 80, 0.3, 60, (70, 70, 75), "Asphalt"))
    gas.add(box("Canopy", gx, 14, gz - 8, 44, 1.5, 22, (220, 60, 50), "Smooth"))
    gas.add(box("CanopyStripe", gx, 13.1, gz - 8, 44.2, 0.4, 22.2, (250, 250, 250), "Neon", collide=False))
    for i, px2 in enumerate([-14, 0, 14]):
        gas.add(box(f"Pillar{i}", gx + px2, 7, gz - 8, 1.5, 14, 1.5, (230, 230, 230), "Metal"))
        gas.add(box(f"Pump{i}", gx + px2, 2.5, gz - 4, 2.5, 5, 1.5, (60, 60, 65), "Metal"))
        loot(gx + px2 + 3, 1, gz - 12)
    gas.add(house(gx, gz + 22, 180, 30, 16, 1, color=(230, 230, 225), roof=(200, 60, 50), name="Shop"))

    # --- TORRE DE RÁDIO (sudeste, em cima do morro) ---
    radio = Inst("Folder", "RadioHill")
    mp.add(radio)
    rx, rz = 360, 360
    radio.add(hill(rx, rz, 80, 70, 18, 0))
    radio.add(box("Bunker", rx, 22, rz, 22, 8, 16, (110, 115, 105), "Concrete"))
    loot(rx - 14, 19, rz + 10)
    loot(rx + 14, 19, rz - 10)
    loot(rx, 26.5, rz)
    for i in range(4):
        a = i * math.pi / 2
        radio.add(box(f"TowerLeg{i}", rx + math.cos(a) * 4, 18 + 35, rz + math.sin(a) * 4 + 20, 1, 70, 1, (200, 60, 50) if i % 2 else (230, 230, 230), "Metal"))
    radio.add(box("TowerLight", rx, 18 + 71, rz + 20, 2, 2, 2, (255, 40, 30), "Neon"))

    # --- MORROS E FLORESTA ---
    nature = Inst("Folder", "Nature")
    mp.add(nature)
    for (hx, hz, w, d, h, ry) in [(-200, -420, 90, 60, 14, 20), (220, -200, 70, 50, 10, 70), (-430, 140, 80, 60, 16, 0), (100, 470, 70, 60, 12, 40), (-240, 220, 60, 50, 10, 110)]:
        nature.add(hill(hx, hz, w, d, h, ry))
        loot(hx, h + 1, hz)
    occupied = [(0, 0, 160), (380, -380, 130), (-380, 380, 150), (-360, -330, 70), (360, 360, 90)]

    def free(x, z, margin=6):
        if abs(x) < 16 + margin or abs(z) < 16 + margin:  # estradas
            return False
        for (ox, oz, r) in occupied:
            if (x - ox) ** 2 + (z - oz) ** 2 < r * r:
                return False
        return abs(x) < MAP / 2 - 50 and abs(z) < MAP / 2 - 50

    # florestas em grupos
    for (fx2, fz2, n) in [(-420, -150, 26), (200, 150, 22), (-150, 450, 20), (480, 60, 22), (-80, -300, 18), (300, -520, 14), (-520, 520, 12)]:
        for _ in range(n):
            x, z = fx2 + rng.uniform(-90, 90), fz2 + rng.uniform(-90, 90)
            if free(x, z):
                nature.add(pine(x, z) if rng.random() < 0.5 else tree(x, z, rng.uniform(0.9, 1.3)))
        for _ in range(3):
            x, z = fx2 + rng.uniform(-60, 60), fz2 + rng.uniform(-60, 60)
            if free(x, z):
                loot(x, 1, z)
    # árvores e pedras soltas
    for _ in range(90):
        x, z = rng.uniform(-640, 640), rng.uniform(-640, 640)
        if free(x, z):
            nature.add(tree(x, z, rng.uniform(0.8, 1.2)))
    for _ in range(70):
        x, z = rng.uniform(-640, 640), rng.uniform(-640, 640)
        if free(x, z, 2):
            nature.add(rock(x, z, rng.uniform(4, 10)))
            if rng.random() < 0.35:
                loot(x + 6, 1, z)
    # casinhas espalhadas
    for i in range(10):
        for _ in range(20):
            x, z = rng.uniform(-600, 600), rng.uniform(-600, 600)
            if free(x, z, 20):
                nature.add(house(x, z, rng.choice([0, 90, 180, 270]), rng.choice([18, 22]), rng.choice([16, 20]), rng.choice([1, 1, 2]), name=f"Cabin{i}"))
                occupied.append((x, z, 30))
                break

    # pontos de loot (peças invisíveis)
    spots = Inst("Folder", "LootSpots")
    for i, (x, y, z) in enumerate(loot_spots):
        spots.add(part(f"LootSpot{i}", (1, 1, 1), CF(x, y, z), (255, 255, 0), "Smooth", collide=False, transparency=1, CanQuery=False, CanTouch=False))
    mp.add(spots)
    return mp


def car(x, z, ry):
    m = Inst("Model", "Car")
    c = rng.choice([(180, 40, 40), (40, 80, 160), (220, 220, 220), (40, 40, 45), (200, 170, 60)])
    m.add(box("Body", x, 2.2, z, 7, 2.6, 14, c, "Metal", ry))
    lx, lz = rot_point(x, z, 0, 1, ry)
    m.add(box("Cabin", lx, 4.4, lz, 6.4, 2, 7, (60, 70, 80), "Glass", ry, transparency=0.2))
    for i, (wx, wz) in enumerate([(-3.4, -4.5), (3.4, -4.5), (-3.4, 4.5), (3.4, 4.5)]):
        px, pz = rot_point(x, z, wx, wz, ry)
        m.add(part(f"Wheel{i}", (1.2, 2.6, 2.6), CF.angles(px, 1.3, pz, 0, math.radians(ry), 0), (25, 25, 25), "Plastic", shape=CYL))
    return m


def barn(x, z):
    m = Inst("Model", "Barn")
    red = (160, 45, 40)
    w, d, H = 40, 30, 16
    hx, hz = w / 2, d / 2
    m.add(box("Floor", x, 0.25, z, w, 0.5, d, (110, 85, 60), "WoodPlanks"))
    wall_with_openings(m, "Front", x, z, 0, -hx, hx, -hz, 0.5, H, 1, red, "WoodPlanks", [(0, 12, 0, 12)])
    wall_with_openings(m, "Back", x, z, 0, -hx, hx, hz, 0.5, H, 1, red, "WoodPlanks", [(0, 8, 0, 9)])
    wall_with_openings(m, "Left", x, z, 90, -hz, hz, -hx, 0.5, H, 1, red, "WoodPlanks", [(0, 4, 5, 4)])
    wall_with_openings(m, "Right", x, z, 90, -hz, hz, hx, 0.5, H, 1, red, "WoodPlanks", [(0, 4, 5, 4)])
    # telhado em V (duas peças inclinadas)
    for side in (-1, 1):
        m.add(part("Roof", (w + 2, 1, d / 2 + 4), CF.angles(x, H + 4, z + side * d / 4, side * math.radians(-28), 0, 0), (90, 40, 35), "WoodPlanks"))
    # mezanino com feno
    m.add(box("Loft", x, 8, z + hz - 6, w - 2, 1, 10, (120, 95, 65), "WoodPlanks"))
    for s in range(8):
        m.add(box(f"LoftStep{s}", x - hx + 3 + s * 2, (s + 1) / 2, z + hz - 14, 2, s + 1, 5, (120, 95, 65), "WoodPlanks"))
    loot(x - 10, 1, z)
    loot(x + 10, 1, z - 5)
    loot(x, 9, z + hz - 6)
    return m


# ---------------------------------------------------------------------------
# Lobby (longe do mapa)
# ---------------------------------------------------------------------------
def build_lobby():
    lx, ly, lz = 2600, 20, 0
    lob = Inst("Model", "Lobby")
    lob.add(box("Floor", lx, ly, lz, 120, 2, 120, (60, 62, 68), "DiamondPlate"))
    for i, (cx, cz, sx, sz) in enumerate([(0, 61, 124, 2), (0, -61, 124, 2), (61, 0, 2, 124), (-61, 0, 2, 124)]):
        lob.add(box(f"Wall{i}", lx + cx, ly + 10, lz + cz, sx, 20, sz, (45, 48, 55), "Metal"))
        lob.add(box(f"Stripe{i}", lx + cx, ly + 2, lz + cz, sx + 0.2, 0.6, sz + 0.2, (255, 190, 40), "Neon", collide=False))
    sign = box("Sign", lx, ly + 16, lz + 59.5, 60, 10, 1, (25, 25, 30), "Smooth")
    sign.add(Inst("SurfaceGui", "Title", Face=Token(FONT_FRONT), SizingMode=Token(SIZING_PPS), PixelsPerStud=20.0, LightInfluence=0.0, AutoLocalize=False, children=[
        Inst("TextLabel", "Text", Size=UDim2(1, 0, 1, 0), BackgroundTransparency=1.0, Text="ZONA ZERO", TextScaled=True, Font=Token(FONT_BLACK), TextColor3=Color.rgb(255, 200, 60)),
    ]))
    lob.add(sign)
    # avião de exibição (feito de peças)
    lob.add(part("PlaneBody", (40, 6, 6), CF.angles(lx, ly + 8, lz - 25, 0, 0, 0), (180, 185, 190), "Metal", shape=CYL))
    lob.add(box("PlaneWing", lx, ly + 8, lz - 25, 8, 1, 46, (160, 165, 170), "Metal"))
    lob.add(box("PlaneTail", lx + 18, ly + 12, lz - 25, 4, 7, 1, (200, 60, 50), "Metal"))
    lob.add(box("PlaneStand", lx, ly + 3, lz - 25, 2, 4, 2, (40, 40, 40), "Metal"))
    # alvos para treinar a mira
    for i in range(5):
        lob.add(part(f"Target{i}", (0.5, 6, 6), CF.angles(lx - 40 + i * 20, ly + 5, lz + 50, 0, math.radians(90), math.radians(90)), (230, 230, 230), "Smooth", shape=CYL))
        lob.add(part(f"TargetDot{i}", (0.6, 2, 2), CF.angles(lx - 40 + i * 20, ly + 5, lz + 49.9, 0, math.radians(90), math.radians(90)), (220, 40, 40), "Neon", shape=CYL))
    lob.add(part("SpawnLocation", (12, 1, 12), CF(lx, ly + 1.5, lz + 15), (255, 200, 60), "Neon", cls="SpawnLocation", Neutral=True, Duration=Int(0)))
    return lob


# ---------------------------------------------------------------------------
# Serviços e scripts
# ---------------------------------------------------------------------------
def build():
    src = os.path.join(ROOT, "src")

    lighting = Inst(
        "Lighting", "Lighting",
        Technology=Token(4),  # Future
        Brightness=2.4,
        ClockTime=15.2,
        GeographicLatitude=35.0,
        GlobalShadows=True,
        Ambient=Color.rgb(70, 70, 80),
        OutdoorAmbient=Color.rgb(140, 140, 150),
        EnvironmentDiffuseScale=0.8,
        EnvironmentSpecularScale=0.6,
        ShadowSoftness=0.25,
        children=[
            Inst("Atmosphere", "Atmosphere", Density=0.32, Offset=0.15, Haze=1.4, Glare=0.4, Color=Color.rgb(210, 215, 225), Decay=Color.rgb(140, 150, 170)),
            Inst("ColorCorrectionEffect", "ColorCorrection", Contrast=0.12, Saturation=0.08, Brightness=0.02, TintColor=Color.rgb(255, 246, 236)),
            Inst("BloomEffect", "Bloom", Intensity=0.6, Size=24, Threshold=1.4),
            Inst("SunRaysEffect", "SunRays", Intensity=0.06, Spread=0.6),
        ],
    )

    workspace = Inst(
        "Workspace", "Workspace",
        StreamingEnabled=False,
        children=[build_map(), build_lobby(), Inst("Terrain", "Terrain")],
    )

    shared = Inst("Folder", "Shared", children=scripts_from_dir(os.path.join(src, "ReplicatedStorage", "Shared")))
    models3d = Inst("Folder", "Models3D")  # coloque aqui modelos 3D com o nome da arma/item
    replicated = Inst("ReplicatedStorage", "ReplicatedStorage", children=[shared, models3d])

    sss = Inst("ServerScriptService", "ServerScriptService", children=scripts_from_dir(os.path.join(src, "ServerScriptService")))

    starter_player = Inst(
        "StarterPlayer", "StarterPlayer",
        CameraMaxZoomDistance=30.0,
        CameraMinZoomDistance=0.5,
        CharacterWalkSpeed=18.0,
        EnableMouseLockOption=True,
        children=[
            Inst("StarterPlayerScripts", "StarterPlayerScripts", children=scripts_from_dir(os.path.join(src, "StarterPlayer", "StarterPlayerScripts"))),
            # "Health" vazio tira a regeneração automática de vida (aqui vida só volta com cura)
            Inst("StarterCharacterScripts", "StarterCharacterScripts", children=[Inst("Script", "Health", Source="-- Zona Zero: sem regeneração automática de vida (só curas).\n")]),
        ],
    )

    players = Inst("Players", "Players", CharacterAutoLoads=False)
    sound = Inst("SoundService", "SoundService")
    chat = Inst("TextChatService", "TextChatService", ChatVersion=Token(1))

    out_dir = os.path.join(ROOT, "place")
    os.makedirs(out_dir, exist_ok=True)
    out = os.path.join(out_dir, "ZonaZero.rbxlx")
    count = write_place(out, [lighting, replicated, sss, sound, starter_player, players, chat, workspace])
    print(f"wrote {out}: {count} instances, {part_count} parts, {len(loot_spots)} loot spots")


if __name__ == "__main__":
    build()
