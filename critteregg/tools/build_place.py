#!/usr/bin/env python3
"""
Coloca o código da pasta src/ dentro de um arquivo .rbxl (binário) do Studio.

    pip install lz4 zstandard
    python3 tools/build_place.py place/StealACritterEgg-v64.rbxl place/StealACritterEgg-v65.rbxl

Só o "Source" dos scripts que já existem no lugar muda; todo o resto (mapa, modelos 3D,
configurações) fica byte a byte igual. Scripts NOVOS não são criados aqui: use o Rojo para isso.
O mapa src/ <-> Explorer é o mesmo do default.project.json.
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from rbxbin import Place  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SCRIPT_EXT = {"Script": ".server.luau", "LocalScript": ".client.luau", "ModuleScript": ".luau"}
# caminho no Explorer (sem o nome do script) -> pasta em src/
FOLDERS = {
    ("ReplicatedStorage", "Shared"): "src/shared",
    ("ServerScriptService",): "src/server",
    ("ServerScriptService", "Game"): "src/server/Game",
    ("StarterPlayer", "StarterPlayerScripts"): "src/client",
}


def file_for(path, cls):
    folder = FOLDERS.get(tuple(path[:-1]))
    if not folder:
        return None
    return os.path.join(ROOT, folder, path[-1] + SCRIPT_EXT[cls])


def build(src_place, out_place, check_only=False):
    pl = Place(src_place)
    changed, same, missing, unmapped = [], [], [], []
    seen_files = set()
    for cid, info in pl.classes.items():
        if info["class"] not in SCRIPT_EXT:
            continue
        sources = pl.strings(cid, "Source")
        for ref in info["refs"]:
            path = pl.path_of(ref)
            target = file_for(path, info["class"])
            name = "/".join(path)
            if not target:
                unmapped.append(name)
                continue
            if not os.path.exists(target):
                missing.append(name)
                continue
            seen_files.add(os.path.normpath(target))
            text = open(target, "rb").read().decode("utf-8")
            if text.encode("utf-8") == sources[pl.ref_index[ref]]:
                same.append(name)
            else:
                pl.set_source(ref, text)
                changed.append(name)
    extra = []
    for folder in set(FOLDERS.values()):
        base = os.path.join(ROOT, folder)
        for entry in sorted(os.listdir(base)):
            full = os.path.normpath(os.path.join(base, entry))
            if os.path.isfile(full) and entry.endswith(".luau") and full not in seen_files:
                extra.append(os.path.relpath(full, ROOT))
    print("changed:", *changed, sep="\n  ") if changed else print("changed: none")
    print("unchanged:", len(same))
    for label, items in (("NOT IN src (kept as is)", missing), ("outside the Rojo folders (kept as is)", unmapped), ("NEW files in src (not in the place: sync with Rojo)", extra)):
        if items:
            print(label + ":", *items, sep="\n  ")
    if not check_only:
        pl.write(out_place)
        print("wrote", out_place)
    return changed, extra


if __name__ == "__main__":
    build(sys.argv[1], sys.argv[2] if len(sys.argv) > 2 else None, check_only=len(sys.argv) < 3)
