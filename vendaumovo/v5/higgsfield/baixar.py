"""Baixa os 21 modelos 3D (GLB) gerados no Higgsfield para a pasta "modelos" aqui dentro.
Uso (no seu PC, com Python 3): python baixar.py
"""
import json
import pathlib
import urllib.request

here = pathlib.Path(__file__).parent
dest = here / "modelos"
dest.mkdir(exist_ok=True)
for name, url in json.loads((here / "links.json").read_text(encoding="utf-8")).items():
    out = dest / f"{name}.glb"
    if out.exists():
        print("já tem", out.name)
        continue
    print("baixando", out.name)
    urllib.request.urlretrieve(url, out)
print("pronto")
