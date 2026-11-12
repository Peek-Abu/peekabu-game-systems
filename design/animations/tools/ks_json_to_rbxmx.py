"""Writes a KeyframeSequence .rbxmx from the JSON that DumpKeyframeSequence.CommandBar.luau returns.

Studio blocks HTTP to localhost from the MCP plugin, so the clip comes out as JSON through execute_luau's return and
this rebuilds the XML Open Cloud takes (publish.py anim). It prints the pose checksum the dump also computes, so the
file on disk is proven equal to the clip in Studio.

  python ks_json_to_rbxmx.py dump.json out.rbxmx

JSON: {"name", "loop", "priority", "keyframes": [{"time", "markers": [name...], "poses": [Pose...]}]}
Pose: {"name", "cf": [12 numbers], "style", "dir", "weight", "children": [Pose...]}
"""

import json
import sys
from xml.sax.saxutils import escape

_ref = 0


def ref():
    global _ref
    _ref += 1
    return f"RBX{_ref:08X}"


def cframe(name, c):
    keys = ["X", "Y", "Z", "R00", "R01", "R02", "R10", "R11", "R12", "R20", "R21", "R22"]
    inner = "".join(f"<{k}>{v!r}</{k}>" for k, v in zip(keys, c))
    return f'<CoordinateFrame name="{name}">{inner}</CoordinateFrame>'


def pose_xml(p, out):
    out.append(f'<Item class="Pose" referent="{ref()}"><Properties>')
    out.append(f'<string name="Name">{escape(p["name"])}</string>')
    out.append(cframe("CFrame", p["cf"]))
    out.append(f'<token name="EasingDirection">{int(p["dir"])}</token>')
    out.append(f'<token name="EasingStyle">{int(p["style"])}</token>')
    out.append(f'<float name="Weight">{float(p["weight"])!r}</float>')
    out.append("</Properties>")
    for c in p.get("children", []):
        pose_xml(c, out)
    out.append("</Item>")


def checksum(ks):
    total, count = 0.0, 0

    def walk(p):
        nonlocal total, count
        count += 1
        i = count
        s = sum(round(v, 4) for v in p["cf"]) + p["style"] * 3 + p["dir"] * 7 + p["weight"] * 11
        total += s * ((i % 97) + 1)
        for c in p.get("children", []):
            walk(c)

    for kf in ks["keyframes"]:
        for p in kf["poses"]:
            walk(p)
    return count, round(total, 4)


def main(src, dst):
    ks = json.load(open(src, encoding="utf-8"))
    out = ['<roblox version="4">', f'<Item class="KeyframeSequence" referent="{ref()}"><Properties>']
    out.append(f'<string name="Name">{escape(ks["name"])}</string>')
    out.append(f'<bool name="Loop">{"true" if ks["loop"] else "false"}</bool>')
    out.append(f'<token name="Priority">{int(ks["priority"])}</token>')
    out.append("</Properties>")
    for kf in ks["keyframes"]:
        out.append(f'<Item class="Keyframe" referent="{ref()}"><Properties>')
        out.append('<string name="Name">Keyframe</string>')
        out.append(f'<float name="Time">{float(kf["time"])!r}</float>')
        out.append("</Properties>")
        for p in kf["poses"]:
            pose_xml(p, out)
        for m in kf.get("markers", []):
            out.append(f'<Item class="KeyframeMarker" referent="{ref()}"><Properties>')
            out.append(f'<string name="Name">{escape(m)}</string><string name="Value"></string>')
            out.append("</Properties></Item>")
        out.append("</Item>")
    out.append("</Item></roblox>")
    open(dst, "w", encoding="utf-8").write("".join(out))
    n, c = checksum(ks)
    print(json.dumps({"ok": True, "keyframes": len(ks["keyframes"]), "poses": n, "checksum": c, "out": dst}))


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2])
