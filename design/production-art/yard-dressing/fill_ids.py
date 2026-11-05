# Fill PlaceYardDressing.CommandBar.luau's IDS and SPRITES tables from upload_log.jsonl (the last ok upload of each name).
#   py -3.9 -I fill_ids.py
# Rows: mesh name -> { meshModelId, colorDecalId, normalDecalId, roughDecalId }; a colour variant (wheeliebin_blue,
# car_slate, ...) is its own row with only its colour map (the placement reads the mesh's normal/rough).
import json, os, re

HERE = os.path.dirname(os.path.abspath(__file__))
ids = {}
for line in open(os.path.join(HERE, "upload_log.jsonl"), encoding="utf-8"):
    r = json.loads(line)
    if r.get("status") == "ok":
        ids[r["name"]] = r["assetId"].replace("rbxassetid://", "")

rows, sprites = {}, {}
for name, aid in ids.items():
    n = name.replace("OH yard ", "")
    if n.endswith(" sprite"):
        sprites[n.replace(" sprite", "")] = aid
        continue
    parts = n.rsplit(" ", 1)
    if len(parts) == 1:
        rows.setdefault(n, ["", "", "", ""])[0] = aid
        continue
    base, kind = parts
    row = rows.setdefault(base, ["", "", "", ""])
    row[{"color": 1, "normal": 2, "rough": 3}[kind]] = aid
# the first colour bake of a variant mesh is named after its variant; the mesh row takes it
for mesh, first in (("wheeliebin", "wheeliebin_green"), ("car", "car_taupe")):
    if first in rows:
        rows.setdefault(mesh, ["", "", "", ""])[1] = rows.pop(first)[1]

lua = "local IDS = {\n" + "".join(
    f'\t{k} = {{ "{v[0]}", "{v[1]}", "{v[2]}", "{v[3]}" }},\n' for k, v in sorted(rows.items())) + "}\n"
spr = "local SPRITES = { firefly = \"%s\", moth = \"%s\" } -- decal ids, resolved to images below\n" % (
    sprites.get("firefly", ""), sprites.get("moth", ""))
p = os.path.join(HERE, "PlaceYardDressing.CommandBar.luau")
s = open(p, encoding="utf-8").read()
s = re.sub(r"local IDS = \{.*?\n\}\n", lambda _: lua, s, count=1, flags=re.S)
s = re.sub(r"local SPRITES = \{[^\n]*\n", lambda _: spr, s, count=1)
open(p, "w", encoding="utf-8", newline="\n").write(s)
print(lua + spr)
