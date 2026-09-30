#!/usr/bin/env python3
"""
Pequena biblioteca para gerar arquivos .rbxlx (lugar do Roblox em XML) sem abrir o Studio.
Usa o mesmo formato do StealACritter-v27.rbxlx, que já abre no Studio.

Exemplo:
    from rbxlx import Inst, V3, CF, Color, Token, write_place, scripts_from_dir
    part = Inst("Part", "Floor", Anchored=True, size=V3(100, 1, 100), CFrame=CF(0, 0, 0))
    workspace = Inst("Workspace", "Workspace", children=[part])
    write_place("out.rbxlx", [workspace])
"""
import json
import math
import os
from xml.sax.saxutils import escape


class V3:
    def __init__(self, x, y, z):
        self.x, self.y, self.z = x, y, z


class V2:
    def __init__(self, x, y):
        self.x, self.y = x, y


class CF:
    """CFrame: posição + matriz de rotação (por padrão sem rotação). Use CF.angles para girar."""

    def __init__(self, x, y, z, r=(1, 0, 0, 0, 1, 0, 0, 0, 1)):
        self.p = (x, y, z)
        self.r = r

    @staticmethod
    def angles(x, y, z, rx=0.0, ry=0.0, rz=0.0):
        """Igual a CFrame.new(x, y, z) * CFrame.Angles(rx, ry, rz) (radianos)."""
        cx, sx = math.cos(rx), math.sin(rx)
        cy, sy = math.cos(ry), math.sin(ry)
        cz, sz = math.cos(rz), math.sin(rz)
        # R = Rx * Ry * Rz (mesma ordem do CFrame.Angles)
        r00 = cy * cz
        r01 = -cy * sz
        r02 = sy
        r10 = cz * sx * sy + cx * sz
        r11 = cx * cz - sx * sy * sz
        r12 = -cy * sx
        r20 = sx * sz - cx * cz * sy
        r21 = cz * sx + cx * sy * sz
        r22 = cx * cy
        return CF(x, y, z, (r00, r01, r02, r10, r11, r12, r20, r21, r22))


class Color:
    """Color3 com valores de 0 a 1."""

    def __init__(self, r, g, b):
        self.r, self.g, self.b = r, g, b

    @staticmethod
    def rgb(r, g, b):
        return Color(r / 255, g / 255, b / 255)


class Color8:
    """Color3uint8 (cor de Part/BasePart), valores 0-255."""

    def __init__(self, r, g, b):
        self.r, self.g, self.b = int(round(r)), int(round(g)), int(round(b))


class Token:
    """Valor de Enum (número do item do enum)."""

    def __init__(self, value):
        self.value = int(value)


class Int:
    def __init__(self, value):
        self.value = int(value)


class Int64:
    def __init__(self, value):
        self.value = int(value)


class Double:
    def __init__(self, value):
        self.value = float(value)


class UDim2:
    def __init__(self, xs, xo, ys, yo):
        self.v = (xs, int(xo), ys, int(yo))


class NumberRange:
    def __init__(self, lo, hi=None):
        self.lo, self.hi = lo, lo if hi is None else hi


class NumberSeq:
    """NumberSequence: lista de (tempo, valor, envelope)."""

    def __init__(self, *keys):
        self.keys = [k if len(k) == 3 else (k[0], k[1], 0) for k in keys]


class ColorSeq:
    """ColorSequence: lista de (tempo, Color)."""

    def __init__(self, *keys):
        self.keys = keys


class Content:
    def __init__(self, url):
        self.url = url


# Nomes das propriedades no XML que são diferentes do nome no Studio
XML_NAMES = {"Size": "size", "Shape": "shape", "Color": "Color3uint8"}
PART_CLASSES = {"Part", "WedgePart", "SpawnLocation", "Seat", "TrussPart", "CornerWedgePart", "MeshPart", "VehicleSeat"}


def _num(v):
    if isinstance(v, bool):
        raise TypeError("bool is not a number")
    if isinstance(v, float):
        v = round(v, 6) + 0.0  # + 0.0 tira o "-0"
        if v.is_integer() and abs(v) < 1e15:
            return str(int(v))
        return repr(v)
    return str(v)


def _prop_xml(name, value, cls):
    if cls in PART_CLASSES and name in XML_NAMES:
        name = XML_NAMES[name]
        if name == "Color3uint8" and isinstance(value, Color):
            value = Color8(value.r * 255, value.g * 255, value.b * 255)
    if isinstance(value, bool):
        return f'<bool name="{name}">{"true" if value else "false"}</bool>'
    if isinstance(value, Token):
        return f'<token name="{name}">{value.value}</token>'
    if isinstance(value, Int):
        return f'<int name="{name}">{value.value}</int>'
    if isinstance(value, Int64):
        return f'<int64 name="{name}">{value.value}</int64>'
    if isinstance(value, Double):
        return f'<double name="{name}">{_num(value.value)}</double>'
    if isinstance(value, (int, float)):
        return f'<float name="{name}">{_num(float(value))}</float>'
    if isinstance(value, str):
        if name == "Source":
            return f'<string name="Source"><![CDATA[{value.replace("]]>", "]]]]><![CDATA[>")}]]></string>'
        return f'<string name="{name}">{escape(value)}</string>'
    if isinstance(value, V3):
        return f'<Vector3 name="{name}"><X>{_num(value.x)}</X><Y>{_num(value.y)}</Y><Z>{_num(value.z)}</Z></Vector3>'
    if isinstance(value, V2):
        return f'<Vector2 name="{name}"><X>{_num(value.x)}</X><Y>{_num(value.y)}</Y></Vector2>'
    if isinstance(value, CF):
        x, y, z = value.p
        r = value.r
        inner = f"<X>{_num(x)}</X><Y>{_num(y)}</Y><Z>{_num(z)}</Z>" + "".join(
            f"<R{i // 3}{i % 3}>{_num(float(r[i]))}</R{i // 3}{i % 3}>" for i in range(9)
        )
        return f'<CoordinateFrame name="{name}">{inner}</CoordinateFrame>'
    if isinstance(value, Color8):
        packed = (value.r << 16) | (value.g << 8) | value.b
        return f'<Color3uint8 name="{name}">{packed}</Color3uint8>'
    if isinstance(value, Color):
        return f'<Color3 name="{name}"><R>{_num(float(value.r))}</R><G>{_num(float(value.g))}</G><B>{_num(float(value.b))}</B></Color3>'
    if isinstance(value, UDim2):
        xs, xo, ys, yo = value.v
        return f'<UDim2 name="{name}"><XS>{_num(float(xs))}</XS><XO>{xo}</XO><YS>{_num(float(ys))}</YS><YO>{yo}</YO></UDim2>'
    if isinstance(value, NumberRange):
        return f'<NumberRange name="{name}">{_num(float(value.lo))} {_num(float(value.hi))} </NumberRange>'
    if isinstance(value, NumberSeq):
        body = " ".join(f"{_num(float(t))} {_num(float(v))} {_num(float(e))}" for t, v, e in value.keys)
        return f'<NumberSequence name="{name}">{body} </NumberSequence>'
    if isinstance(value, ColorSeq):
        body = " ".join(f"{_num(float(t))} {_num(float(c.r))} {_num(float(c.g))} {_num(float(c.b))} 0" for t, c in value.keys)
        return f'<ColorSequence name="{name}">{body} </ColorSequence>'
    if isinstance(value, Content):
        return f'<Content name="{name}"><url>{escape(value.url)}</url></Content>'
    raise TypeError(f"unsupported property {name}={value!r}")


class Inst:
    def __init__(self, cls, name, children=None, attributes=None, **props):
        self.cls = cls
        self.name = name
        self.props = props
        self.children = list(children or [])
        self.attributes = attributes or {}

    def add(self, *children):
        self.children.extend(children)
        return self

    def find(self, name):
        for child in self.children:
            if child.name == name:
                return child
        return None


def _attributes_blob(attrs):
    """Serializa atributos (AttributesSerialize) em base64. Suporta string, bool, número."""
    import base64
    import struct

    out = bytearray(struct.pack("<I", len(attrs)))
    for key, value in attrs.items():
        kb = key.encode()
        out += struct.pack("<I", len(kb)) + kb
        if isinstance(value, bool):
            out += bytes([0x03, 1 if value else 0])
        elif isinstance(value, (int, float)):
            out += bytes([0x06]) + struct.pack("<d", float(value))
        elif isinstance(value, str):
            vb = value.encode()
            out += bytes([0x02]) + struct.pack("<I", len(vb)) + vb
        else:
            raise TypeError(f"unsupported attribute {key}={value!r}")
    return base64.b64encode(bytes(out)).decode()


def _write(inst, out, depth, counter):
    pad = "  " * depth
    ref = counter[0]
    counter[0] += 1
    out.append(f'{pad}<Item class="{inst.cls}" referent="{ref}">')
    out.append(f"{pad}  <Properties>")
    out.append(f'{pad}    <string name="Name">{escape(inst.name)}</string>')
    for key in sorted(inst.props):
        out.append(f"{pad}    {_prop_xml(key, inst.props[key], inst.cls)}")
    if inst.attributes:
        out.append(f'{pad}    <BinaryString name="AttributesSerialize">{_attributes_blob(inst.attributes)}</BinaryString>')
    out.append(f"{pad}  </Properties>")
    for child in inst.children:
        _write(child, out, depth + 1, counter)
    out.append(f"{pad}</Item>")


def write_place(path, top_level):
    out = ['<roblox version="4">']
    counter = [0]
    for inst in top_level:
        _write(inst, out, 1, counter)
    out.append("</roblox>")
    with open(path, "w", encoding="utf-8", newline="") as f:
        f.write("\n".join(out) + "\n")
    return counter[0]


def scripts_from_dir(directory):
    """
    Lê uma pasta no estilo Rojo e devolve a lista de Inst:
      pasta/            -> Folder (ou o script init.* de dentro dela)
      X.server.luau     -> Script
      X.client.luau     -> LocalScript
      X.luau            -> ModuleScript
      X.json            -> ModuleScript que devolve a tabela (útil para dados)
    """
    items = []
    for entry in sorted(os.listdir(directory)):
        full = os.path.join(directory, entry)
        if os.path.isdir(full):
            children = scripts_from_dir(full)
            init = next((c for c in children if c.name == "init"), None)
            if init:
                children.remove(init)
                init.name = entry
                init.children.extend(children)
                items.append(init)
            else:
                items.append(Inst("Folder", entry, children=children))
        elif entry.endswith(".luau") or entry.endswith(".lua"):
            with open(full, encoding="utf-8") as f:
                source = f.read()
            base = entry.rsplit(".", 1)[0]
            if base.endswith(".server"):
                items.append(Inst("Script", base[: -len(".server")], Source=source))
            elif base.endswith(".client"):
                items.append(Inst("LocalScript", base[: -len(".client")], Source=source))
            else:
                items.append(Inst("ModuleScript", base, Source=source))
        elif entry.endswith(".json"):
            with open(full, encoding="utf-8") as f:
                data = json.load(f)
            source = "return game:GetService(\"HttpService\"):JSONDecode([==[" + json.dumps(data, ensure_ascii=False) + "]==])\n"
            items.append(Inst("ModuleScript", entry[: -len(".json")], Source=source))
    return items
