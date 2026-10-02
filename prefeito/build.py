#!/usr/bin/env python3
"""
Gera o lugar do Prefeito Tycoon (.rbxlx) sem abrir o Roblox Studio.

    python3 prefeito/build.py                 -> place/PrefeitoTycoon-v1.rbxlx
    python3 prefeito/build.py saida.rbxlx

O que vai no arquivo:
  * o chão do mundo, o hub central (praça, spawn, placares, postes) e a iluminação de fim de tarde
  * todos os scripts de prefeito/src (ReplicatedStorage, ServerScriptService, StarterPlayerScripts)
Os terrenos dos jogadores (chão, Avenida, Prefeitura, Cofre, caminhos) são montados pelo servidor
quando o jogo começa (ServerScriptService/Game/Lots), a partir de Shared/Config.
"""
import math
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
sys.path.insert(0, os.path.join(ROOT, "tools"))

from rbxlx import CF, Color, Inst, Int, Token, V3, scripts_from_dir, write_place  # noqa: E402

SRC = os.path.join(HERE, "src")
DEFAULT_OUT = os.path.join(ROOT, "place", "PrefeitoTycoon-v1.rbxlx")

# Enum.Material (valores do Roblox)
MAT = {
    "Plastic": 256, "SmoothPlastic": 272, "Neon": 288, "Wood": 512, "Marble": 784, "Slate": 800,
    "Concrete": 816, "Granite": 832, "Brick": 1040, "Cobblestone": 880, "Metal": 1088,
    "Grass": 1280, "Ground": 1360, "Asphalt": 1376,
}
SHAPE_BALL, SHAPE_CYLINDER = 0, 2


def part(name, size, cf, color, material="SmoothPlastic", shape=None, children=None, **extra):
    props = dict(
        Anchored=True,
        size=V3(*size),
        CFrame=cf,
        Color=color,
        Material=Token(MAT[material]),
        TopSurface=Token(0),
        BottomSurface=Token(0),
    )
    if shape is not None:
        props["shape"] = Token(shape)
    props.update(extra)
    return Inst("Part", name, children=children, **props)


def light(range_, brightness, color):
    return Inst("PointLight", "Light", Range=float(range_), Brightness=float(brightness), Color=color)


def offset(cf, x, y, z):
    """Igual a cf * CFrame.new(x, y, z) (anda no espaço local do cf)."""
    r = cf.r
    px, py, pz = cf.p
    return CF(
        px + r[0] * x + r[1] * y + r[2] * z,
        py + r[3] * x + r[4] * y + r[5] * z,
        pz + r[6] * x + r[7] * y + r[8] * z,
        r,
    )


def facing_center(radius, angle, y):
    """CFrame no círculo de raio `radius` (ângulo em graus, 0 = +Z) olhando para o centro do hub."""
    a = math.radians(angle)
    x, z = math.sin(a) * radius, math.cos(a) * radius
    # olhar para o centro: o -Z local aponta para (0, y, 0)
    yaw = math.atan2(x, z)  # girar em Y para que o -Z aponte para o centro
    return CF.angles(x, y, z, 0, yaw, 0)


def build_hub():
    hub = Inst("Model", "Hub")
    stone = Color.rgb(176, 170, 160)
    dark = Color.rgb(36, 38, 44)
    # praça redonda (cilindro deitado em pé: o eixo do cilindro é o X)
    hub.add(part("Plaza", (0.4, 250, 250), CF.angles(0, 0, 0, 0, 0, math.pi / 2), stone, "Cobblestone", SHAPE_CYLINDER))
    hub.add(part("Ring", (0.42, 70, 70), CF.angles(0, 0.01, 0, 0, 0, math.pi / 2), Color.rgb(120, 116, 110), "Marble", SHAPE_CYLINDER))
    hub.add(Inst(
        "SpawnLocation", "Spawn",
        Anchored=True, size=V3(14, 1, 14), CFrame=CF(0, 0.5, 26), Color=Color.rgb(255, 196, 70),
        Material=Token(MAT["Neon"]), TopSurface=Token(0), BottomSurface=Token(0), Neutral=True, Duration=Int(0),
        Transparency=0.6,
    ))
    # Marco Zero: obelisco com anel de neon
    hub.add(part("MonumentBase", (14, 2, 14), CF(0, 1, 0), Color.rgb(200, 196, 188), "Marble"))
    hub.add(part("Monument", (4, 36, 4), CF(0, 20, 0), Color.rgb(230, 226, 218), "Marble"))
    hub.add(part("MonumentTip", (2.5, 2.5, 2.5), CF(0, 39, 0), Color.rgb(255, 196, 70), "Neon", SHAPE_BALL,
                 children=[light(40, 2, Color.rgb(255, 200, 120))]))
    hub.add(part("MonumentRing", (0.6, 9, 9), CF.angles(0, 14, 0, 0, 0, math.pi / 2), Color.rgb(70, 214, 190), "Neon", SHAPE_CYLINDER))
    # placares e título (o texto é colocado pelo servidor: Leaderboards)
    for name, angle in (("BoardStars", 22.5), ("BoardPopulation", -22.5), ("Title", 180)):
        cf = facing_center(70, angle, 12)
        hub.add(part(name, (30, 18, 1), cf, Color.rgb(16, 20, 30), "SmoothPlastic"))
        hub.add(part(name + "Frame", (31.5, 19.5, 0.8), offset(cf, 0, 0, 0.3), dark, "Metal"))
        for side in (-1, 1):
            hub.add(part(name + "Leg", (1, 4, 1), offset(cf, side * 12, -10.5, 0), dark, "Metal"))
    # postes entre os caminhos
    for i in range(8):
        angle = 22.5 + i * 45
        a = math.radians(angle)
        x, z = math.sin(a) * 104, math.cos(a) * 104
        hub.add(part("LampPost", (0.6, 14, 0.6), CF(x, 7, z), dark, "Metal"))
        hub.add(part("LampBulb", (1.6, 1.6, 1.6), CF(x, 14.6, z), Color.rgb(255, 214, 150), "Neon", SHAPE_BALL,
                     children=[light(30, 1.4, Color.rgb(255, 200, 140))]))
        # árvores e bancos
        for k, off in enumerate((-12, 12)):
            b = math.radians(angle + off)
            tx, tz = math.sin(b) * 88, math.cos(b) * 88
            hub.add(part("TreeTrunk", (1.2, 6, 1.2), CF(tx, 3, tz), Color.rgb(100, 70, 45), "Wood"))
            hub.add(part("TreeTop", (7, 7, 7), CF(tx, 8, tz), Color.rgb(55, 110, 58), "Grass", SHAPE_BALL))
        hub.add(part("Bench", (6, 1, 2), facing_center(96, angle, 1.5), Color.rgb(110, 80, 55), "Wood"))
    return hub


def build_workspace():
    ground = part("WorldGround", (1600, 1, 1600), CF(0, -0.7, 0), Color.rgb(48, 62, 46), "Grass", CastShadow=False)
    return Inst(
        "Workspace", "Workspace",
        children=[Inst("Terrain", "Terrain"), ground, build_hub()],
        StreamingEnabled=False,
    )


def build_lighting():
    return Inst(
        "Lighting", "Lighting",
        children=[
            Inst("Atmosphere", "Atmosphere", Color=Color.rgb(196, 170, 200), Decay=Color.rgb(92, 76, 120),
                 Density=0.3, Glare=0.25, Haze=1.4, Offset=0.15),
            Inst("BloomEffect", "Bloom", Intensity=0.9, Size=26.0, Threshold=0.95),
            Inst("ColorCorrectionEffect", "ColorCorrection", Brightness=0.02, Contrast=0.14, Saturation=0.12,
                 TintColor=Color.rgb(255, 244, 236)),
            Inst("Sky", "Sky", StarCount=Int(4000), SunAngularSize=14.0, MoonAngularSize=11.0),
        ],
        ClockTime=18.6,
        Brightness=1.6,
        Ambient=Color.rgb(70, 72, 92),
        OutdoorAmbient=Color.rgb(110, 104, 130),
        EnvironmentDiffuseScale=0.6,
        EnvironmentSpecularScale=0.8,
        ExposureCompensation=0.1,
        GlobalShadows=True,
        ShadowSoftness=0.3,
        Technology=Token(4),  # Future: as luzes dos postes e o neon das janelas ficam bonitos
    )


def build():
    replicated = Inst("ReplicatedStorage", "ReplicatedStorage", children=scripts_from_dir(os.path.join(SRC, "ReplicatedStorage")))
    server = Inst("ServerScriptService", "ServerScriptService", children=scripts_from_dir(os.path.join(SRC, "ServerScriptService")))
    player_scripts = Inst(
        "StarterPlayerScripts", "StarterPlayerScripts",
        children=scripts_from_dir(os.path.join(SRC, "StarterPlayer", "StarterPlayerScripts")),
    )
    starter_player = Inst(
        "StarterPlayer", "StarterPlayer",
        children=[player_scripts],
        CameraMaxZoomDistance=450.0,  # dá para ver a cidade inteira de cima
        CharacterWalkSpeed=24.0,
    )
    return [
        build_workspace(),
        build_lighting(),
        replicated,
        server,
        starter_player,
        Inst("SoundService", "SoundService"),
    ]


def main():
    out = sys.argv[1] if len(sys.argv) > 1 else DEFAULT_OUT
    os.makedirs(os.path.dirname(out), exist_ok=True)
    count = write_place(out, build())
    print(f"{out}: {count} instâncias")


if __name__ == "__main__":
    main()
