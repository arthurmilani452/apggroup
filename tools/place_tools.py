#!/usr/bin/env python3
"""
Ferramentas para trabalhar com o arquivo .rbxlx do Steal a Critter fora do Roblox Studio.

  python3 tools/place_tools.py extract place/StealACritter-v27.rbxlx src
      Copia o código de todos os scripts do lugar para a pasta src/
      (um arquivo por script, no mesmo caminho do Explorer).

  python3 tools/place_tools.py build place/StealACritter-v27.rbxlx src place/StealACritter-v28.rbxlx
      Cria um novo .rbxlx igual ao original, mas com o código dos scripts
      trocado pelo que está em src/. Nada além do "Source" dos scripts muda.

Tipos de arquivo em src/:
  *.server.luau  -> Script
  *.client.luau  -> LocalScript
  *.luau         -> ModuleScript
"""
import os
import sys
import xml.etree.ElementTree as ET

SCRIPT_CLASSES = {"Script": ".server.luau", "LocalScript": ".client.luau", "ModuleScript": ".luau"}


def _prop(item, name):
    props = item.find("Properties")
    if props is None:
        return None
    for p in props:
        if p.get("name") == name:
            return p.text or ""
    return None


def list_scripts(place_path):
    """Returns [(path, class, referent, source)] for every script in the place."""
    root = ET.parse(place_path).getroot()
    found = []

    def walk(item, parts):
        cls = item.get("class")
        parts = parts + [_prop(item, "Name") or "?"]
        if cls in SCRIPT_CLASSES:
            found.append(("/".join(parts), cls, item.get("referent"), _prop(item, "Source") or ""))
        for child in item.findall("Item"):
            walk(child, parts)

    for top in root.findall("Item"):
        walk(top, [])
    paths = [f[0] for f in found]
    dupes = {p for p in paths if paths.count(p) > 1}
    if dupes:
        raise SystemExit(f"scripts with the same path (rename one in Studio): {sorted(dupes)}")
    return found


def file_for(src_dir, path, cls):
    return os.path.join(src_dir, *path.split("/")) + SCRIPT_CLASSES[cls]


def extract(place_path, src_dir):
    scripts = list_scripts(place_path)
    for path, cls, _, source in scripts:
        target = file_for(src_dir, path, cls)
        os.makedirs(os.path.dirname(target), exist_ok=True)
        with open(target, "w", encoding="utf-8", newline="") as f:
            f.write(source)
    print(f"extracted {len(scripts)} scripts to {src_dir}")


def _cdata(text):
    return "<![CDATA[" + text.replace("]]>", "]]]]><![CDATA[>") + "]]>"


def _source_span(data, item_start):
    """Finds the (start, end) of the inner text of <string name="Source"> for the item at item_start."""
    props = data.index("<Properties>", item_start)
    props_end = data.index("</Properties>", props)
    open_tag = '<string name="Source">'
    tag = data.find(open_tag, props, props_end)
    if tag < 0:
        raise ValueError("script without Source property")
    start = tag + len(open_tag)
    pos = start
    while True:
        if data.startswith("<![CDATA[", pos):
            pos = data.index("]]>", pos + 9) + 3
        elif data.startswith("</string>", pos):
            return start, pos
        else:
            nxt = data.find("<", pos)
            if nxt < 0:
                raise ValueError("unterminated Source")
            if nxt == pos:
                raise ValueError(f"unexpected markup in Source at {pos}")
            pos = nxt


def build(place_path, src_dir, out_path):
    scripts = list_scripts(place_path)
    with open(place_path, encoding="utf-8", newline="") as f:
        data = f.read()
    edits = []
    changed = []
    for path, cls, ref, old_source in scripts:
        target = file_for(src_dir, path, cls)
        if not os.path.exists(target):
            raise SystemExit(f"missing {target} (script {path} would lose its code)")
        with open(target, encoding="utf-8", newline="") as f:
            new_source = f.read()
        if new_source == old_source:
            continue
        marker = f'<Item class="{cls}" referent="{ref}">'
        item_start = data.index(marker)
        if data.find(marker, item_start + 1) >= 0:
            raise SystemExit(f"referent {ref} is not unique")
        start, end = _source_span(data, item_start)
        edits.append((start, end, _cdata(new_source)))
        changed.append(path)
    # extra files in src/ that are not in the place would silently do nothing: warn about them
    known = {os.path.normpath(file_for(src_dir, p, c)) for p, c, _, _ in scripts}
    for dirpath, _, files in os.walk(src_dir):
        for name in files:
            full = os.path.normpath(os.path.join(dirpath, name))
            if name.endswith(".luau") and full not in known:
                print(f"WARNING: {full} is not a script in the place; create it in Studio first")
    for start, end, text in sorted(edits, reverse=True):
        data = data[:start] + text + data[end:]
    with open(out_path, "w", encoding="utf-8", newline="") as f:
        f.write(data)
    # checagem: o arquivo novo abre e tem exatamente o código de src/
    for path, cls, _, source in list_scripts(out_path):
        with open(file_for(src_dir, path, cls), encoding="utf-8", newline="") as f:
            if f.read() != source:
                raise SystemExit(f"verification failed for {path}")
    print(f"built {out_path}: {len(changed)} scripts changed")
    for path in changed:
        print("  ", path)


if __name__ == "__main__":
    if len(sys.argv) == 4 and sys.argv[1] == "extract":
        extract(sys.argv[2], sys.argv[3])
    elif len(sys.argv) == 5 and sys.argv[1] == "build":
        build(sys.argv[2], sys.argv[3], sys.argv[4])
    else:
        print(__doc__)
        sys.exit(1)
