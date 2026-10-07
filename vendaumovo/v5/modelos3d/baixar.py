"""Baixa os 21 modelos 3D (GLB) gerados no Higgsfield para esta pasta.
Uso (no seu PC, com Python 3): python baixar.py
"""
import json
import pathlib
import urllib.request

here = pathlib.Path(__file__).parent
for name, url in json.loads((here / "links.json").read_text(encoding="utf-8")).items():
    out = here / f"{name}.glb"
    if out.exists():
        print("já tem", out.name)
        continue
    print("baixando", out.name)
    urllib.request.urlretrieve(url, out)
print("pronto")
