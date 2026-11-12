"""Leaf piles from the approved single leaves (owner 11-11: "the leaves pass", combine them).

The four singles' 512 px maps are packed into one 1024 px atlas (2 x 2: maple orange, maple red / oak, beech), so a
pile is one mesh with one SurfaceAppearance (AlphaMode Transparency for the cut-out edges). Each leaf is the singles'
curled, midrib-folded grid (leaf_singles_blend.py), its UVs moved into its atlas quadrant, dropped at a random spot
and turn and stacked: later leaves sit on the ones under them (a heightfield), so nothing interpenetrates.

- drift: 5.6 x 2.4 studs heaped against a wall (+Y = the wall side), highest at the back, ~30 leaves.
- scatter: a loose 6 x 6 patch, ~16 leaves, a few overlapping.

  blender --background --python leaf_piles_blend.py -- <singles_maps_dir> <out_dir>
"""

import json
import math
import os
import random
import sys

import bmesh
import bpy
from mathutils import Matrix, Vector

args = sys.argv[sys.argv.index("--") + 1:]
MAPS, OUT = args[0], args[1]
os.makedirs(OUT, exist_ok=True)
meta = {m["name"]: m["outline"] for m in json.load(open(os.path.join(MAPS, "leaves.json")))}
ORDER = ["maple_orange", "maple_red", "oak_brown", "beech_gold"]
QUAD = {n: ((i % 2) * 0.5, (1 - i // 2) * 0.5) for i, n in enumerate(ORDER)}  # uv offset of each quadrant


def atlas():
    """The 2x2 atlas images (colour RGBA, normal, rough) from the singles' maps."""
    for kind, mode, fill in (("color", "RGBA", (0, 0, 0, 0)), ("normal", "RGB", (128, 128, 255)), ("rough", "L", 200)):
        from PIL import Image  # Blender's Python has no PIL: this branch only runs with --atlas from a system Python
        sheet = Image.new(mode, (1024, 1024), fill)
        for i, n in enumerate(ORDER):
            im = Image.open(os.path.join(MAPS, f"{n}_{kind}.png")).convert(mode)
            sheet.paste(im, ((i % 2) * 512, (i // 2) * 512))
        sheet.save(os.path.join(OUT, f"hb_leaves_atlas_{kind}.png"))


def inside(poly, x, y):
    c = False
    j = len(poly) - 1
    for i in range(len(poly)):
        xi, yi = poly[i]
        xj, yj = poly[j]
        if (yi > y) != (yj > y) and x < (xj - xi) * (y - yi) / (yj - yi + 1e-12) + xi:
            c = not c
        j = i
    return c


def leaf_into(bm, uv, name, size, at, yaw, tilt, heights, cap):
    """Adds one leaf (the singles' grid) into `bm`, resting on `heights` (a dict of grid cell -> top z)."""
    poly = meta[name]
    n = 13
    ou, ov = QUAD[name]
    rot = Matrix.Rotation(yaw, 3, "Z") @ Matrix.Rotation(tilt[0], 3, "X") @ Matrix.Rotation(tilt[1], 3, "Y")
    pts = {}
    for i in range(n + 1):
        for j in range(n + 1):
            x, y = -0.5 + i / n, j / n
            z = 0.10 * abs(x) + 0.14 * y * y + 0.04 * x * y
            pts[i, j] = (x, y, rot @ Vector((x * size, (y - 0.4) * size, z * size)))
    # rest on what is already there: lift the whole leaf so its lowest point clears the pile under it
    # rest on what is already there: the leaf rises to the pile's mean height under its middle (a leaf settles into
    # the pile, it does not balance on the highest tip), never above the pile's cap
    cell = 0.35
    under = []
    for (x, y, p) in pts.values():
        if abs(x) < 0.3 and 0.2 < y < 0.7:
            w = Vector(at) + p
            under.append(heights.get((round(w.x / cell), round(w.y / cell)), 0.0))
    need = min(cap, (sum(under) / len(under)) if under else 0.0) + 0.015
    verts = {}
    faces = 0
    for i in range(n):
        for j in range(n):
            corners = [(i, j), (i + 1, j), (i + 1, j + 1), (i, j + 1)]
            cx, cy = -0.5 + (i + 0.5) / n, (j + 0.5) / n
            if not inside(poly, cx, cy) and not any(inside(poly, pts[c][0], pts[c][1]) for c in corners):
                continue
            vs = []
            for c in corners:
                if c not in verts:
                    w = Vector(at) + pts[c][2] + Vector((0, 0, need))
                    verts[c] = bm.verts.new(w)
                vs.append(verts[c])
            f = bm.faces.new(vs)
            for loop, c in zip(f.loops, corners):
                x, y = pts[c][0], pts[c][1]
                loop[uv].uv = (ou + (x + 0.5) * 0.5, ov + y * 0.5)
            faces += 1
    mean = sum(v.co.z for v in verts.values()) / max(1, len(verts))
    for v in verts.values():
        key = (round(v.co.x / cell), round(v.co.y / cell))
        heights[key] = max(heights.get(key, 0.0), min(mean, v.co.z))
    return faces


def pile(kind, seed):
    rng = random.Random(seed)
    bm = bmesh.new()
    uv = bm.loops.layers.uv.new()
    heights = {}
    if kind == "drift":
        count = 28
        for k in range(count):
            x = rng.gauss(0, 1.3)
            y = abs(rng.gauss(0, 0.55)) * (1 if rng.random() < 0.8 else -0.6)
            x = max(-2.6, min(2.6, x))
            y = max(-1.0, min(1.1, y))
            # heaped toward the wall: the cap rises from 0.15 at the front to 0.7 at the back
            leaf_into(bm, uv, rng.choice(ORDER), rng.uniform(0.7, 1.0), (x, y, 0.0), rng.uniform(0, math.tau),
                      (rng.uniform(-0.2, 0.2) + 0.12 * (y + 1), rng.uniform(-0.2, 0.2)), heights,
                      0.15 + 0.55 * (y + 1.0) / 2.1)
    else:
        count = 16
        for k in range(count):
            r = 2.8 * math.sqrt(rng.random())
            a = rng.uniform(0, math.tau)
            leaf_into(bm, uv, rng.choice(ORDER), rng.uniform(0.65, 0.95), (math.cos(a) * r, math.sin(a) * r, 0.0),
                      rng.uniform(0, math.tau), (rng.uniform(-0.12, 0.12), rng.uniform(-0.12, 0.12)), heights, 0.12)
    me = bpy.data.meshes.new(f"hb_leaves_{kind}")
    bm.to_mesh(me)
    ob = bpy.data.objects.new(f"hb_leaves_{kind}", me)
    bpy.context.scene.collection.objects.link(ob)
    sol = ob.modifiers.new("thick", "SOLIDIFY")
    sol.thickness = 0.01
    return ob


if __name__ == "__main__":
    if "--atlas" in args:
        atlas()
        sys.exit(0)
    bpy.ops.wm.read_factory_settings(use_empty=True)
    m = bpy.data.materials.new("leaves")
    m.use_nodes = True
    N, L = m.node_tree.nodes, m.node_tree.links
    b = N["Principled BSDF"]
    t = N.new("ShaderNodeTexImage")
    t.image = bpy.data.images.load(os.path.join(OUT, "hb_leaves_atlas_color.png"))
    L.new(t.outputs["Color"], b.inputs["Base Color"])
    L.new(t.outputs["Alpha"], b.inputs["Alpha"])
    for kind, seed in (("drift", 11), ("scatter", 23)):
        ob = pile(kind, seed)
        ob.data.materials.append(m)
        bpy.ops.object.select_all(action="DESELECT")
        ob.select_set(True)
        bpy.context.view_layer.objects.active = ob
        bpy.ops.object.modifier_apply(modifier="thick")
        tris = sum(len(p.vertices) - 2 for p in ob.data.polygons)
        bpy.ops.export_scene.gltf(filepath=os.path.join(OUT, f"hb_leaves_{kind}_parts.glb"), use_selection=True)
        print("PILE", kind, [round(v, 2) for v in ob.dimensions], "tris", tris)
