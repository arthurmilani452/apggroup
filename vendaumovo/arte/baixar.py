#!/usr/bin/env python3
"""Baixa todas as imagens do OpenArt listadas em manifest.json para as pastas desta pasta.

    python3 vendaumovo/arte/baixar.py
"""
import json
import os
import urllib.request

HERE = os.path.dirname(os.path.abspath(__file__))

with open(os.path.join(HERE, "manifest.json"), encoding="utf-8") as f:
    manifest = json.load(f)

ok = 0
for path, info in manifest.items():
    dest = os.path.join(HERE, path)
    os.makedirs(os.path.dirname(dest), exist_ok=True)
    if os.path.exists(dest) and os.path.getsize(dest) > 0:
        ok += 1
        continue
    try:
        urllib.request.urlretrieve(info["url"], dest)
        ok += 1
        print("ok  ", path)
    except Exception as e:  # noqa: BLE001
        print("ERRO", path, e)
print(f"{ok}/{len(manifest)} imagens na pasta")
