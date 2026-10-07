#!/usr/bin/env python3
"""
Monta a versão nova do Venda um Ovo a partir do arquivo que você salvou no Studio.

  entrada: farmaraura/place/base-VendaUmOvo-v6.rbxlx  (mapa do Venda um Ovo v6, usado como esqueleto)
  scripts: farmaraura/src/... (um arquivo por script, na mesma árvore do Roblox)
  saída:   farmaraura/place/FarmarAura.rbxlx

Só o código dos scripts é trocado (e scripts novos são adicionados na pasta certa).
Todo o resto do arquivo (peças, MeshParts, imagens, mapa) fica exatamente como estava.

    python3 farmaraura/tools/repack.py           # monta o jogo
    python3 farmaraura/tools/repack.py --extract # (re)extrai os scripts da base
"""
import os
import re
import sys
import xml.etree.ElementTree as ET

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
SRC = os.path.join(ROOT, "src")
IN = os.path.join(ROOT, "place", "base-VendaUmOvo-v6.rbxlx")
OUT = os.path.join(ROOT, "place", "FarmarAura.rbxlx")

EXT = {"Script": ".server.luau", "LocalScript": ".client.luau", "ModuleScript": ".luau"}


def item_name(it):
    props = it.find("Properties")
    n = props.find("string[@name='Name']") if props is not None else None
    return n.text if n is not None else "?"


def scripts_in_place(root):
    """[(caminho, classe, referent, código)] de todos os scripts do arquivo."""
    out = []

    def walk(it, path):
        p = path + [item_name(it)]
        cls = it.get("class")
        if cls in EXT:
            props = it.find("Properties")
            src = props.find("ProtectedString[@name='Source']")
            if src is None:
                src = props.find("string[@name='Source']")
            out.append((p, cls, it.get("referent"), (src.text or "") if src is not None else ""))
        for k in it.findall("Item"):
            walk(k, p)

    for it in root.findall("Item"):
        walk(it, [])
    return out


def all_items(root):
    """caminho (tupla) -> referent, para achar a pasta onde vai um script novo."""
    out = {}

    def walk(it, path):
        p = path + [item_name(it)]
        out.setdefault(tuple(p), it.get("referent"))
        for k in it.findall("Item"):
            walk(k, p)

    for it in root.findall("Item"):
        walk(it, [])
    return out


def file_for(path, cls):
    return os.path.join(SRC, *path[:-1], path[-1] + EXT[cls])


def extract():
    root = ET.parse(IN).getroot()
    for path, cls, _, code in scripts_in_place(root):
        dest = file_for(path, cls)
        os.makedirs(os.path.dirname(dest), exist_ok=True)
        with open(dest, "w", encoding="utf-8") as f:
            f.write(code)
    print("extraído para", SRC)


def cdata(code):
    return "<![CDATA[" + code.replace("]]>", "]]]]><![CDATA[>") + "]]>"


def local_files():
    """[(caminho, classe, arquivo)] de todos os scripts em src/."""
    found = []
    for dirpath, _, files in os.walk(SRC):
        rel = os.path.relpath(dirpath, SRC)
        parts = [] if rel == "." else rel.split(os.sep)
        for f in files:
            for cls, ext in EXT.items():
                if f.endswith(ext) and (cls != "ModuleScript" or not (f.endswith(".server.luau") or f.endswith(".client.luau"))):
                    found.append((parts + [f[: -len(ext)]], cls, os.path.join(dirpath, f)))
                    break
    return found


def repack():
    with open(IN, encoding="utf-8") as f:
        text = f.read()
    root = ET.fromstring(text)
    existing = {tuple(p): (cls, ref) for p, cls, ref, _ in scripts_in_place(root)}
    items = all_items(root)
    changed = added = 0
    new_items = {}  # referent da pasta -> [xml]
    next_ref = 900000
    for path, cls, filename in local_files():
        with open(filename, encoding="utf-8") as f:
            code = f.read()
        key = tuple(path)
        if key in existing:
            _, ref = existing[key]
            start = text.index(f'referent="{ref}"')
            m = re.compile(r'(<ProtectedString name="Source">|<string name="Source">)(.*?)(</ProtectedString>|</string>)', re.S).search(text, start)
            text = text[: m.start(2)] + cdata(code) + text[m.end(2):]
            changed += 1
        else:
            parent_ref = items.get(tuple(path[:-1]))
            if parent_ref is None:
                sys.exit(f"pasta não existe no arquivo para {'/'.join(path)}")
            next_ref += 1
            xml = (f'<Item class="{cls}" referent="RNEW{next_ref}"><Properties>'
                   f'<string name="Name">{path[-1]}</string>'
                   f'<ProtectedString name="Source">{cdata(code)}</ProtectedString>'
                   f'</Properties></Item>')
            new_items.setdefault(parent_ref, []).append(xml)
            added += 1
    for parent_ref, xmls in new_items.items():
        start = text.index(f'referent="{parent_ref}"')
        end_props = text.index("</Properties>", start) + len("</Properties>")
        text = text[:end_props] + "".join(xmls) + text[end_props:]
    ET.fromstring(text)  # confere que o XML continua válido
    with open(OUT, "w", encoding="utf-8") as f:
        f.write(text)
    print(f"escrito {OUT}: {changed} scripts atualizados, {added} novos")


if __name__ == "__main__":
    extract() if "--extract" in sys.argv else repack()
