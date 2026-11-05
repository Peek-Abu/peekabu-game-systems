# Odd Hours yard set dressing (Y3a) and critters (Y4): hand-built props on the texture-pipeline hard-surface kit.
#
# HOW TO RUN (Blender 5.1 headless, one heavy job at a time):
#   "C:/Program Files/Blender Foundation/Blender 5.1/blender.exe" --background --python build_yard.py -- dumpster wheeliebin:green ...
# A prop name may carry a paint variant after a colon (wheeliebin:green|blue|grey, car:taupe|slate|red).
# Env YARD_OUT = output folder (default ./out). Per prop it writes (via build_set_stage2.finish2):
#   <name>_color.png (colour x AO), <name>_normal.png (tangent, OpenGL), <name>_rough.png,
#   <name>_parts.glb (special pieces kept apart: Glass, Glow, Hazard), <name>_tt.glb (one joined mesh, for turntable.py)
# Then: blender --background --python ../map-kits/odd-hours-b1/to_fbx_multi.py -- <outdir> <name>_parts.glb ...
#
# Conventions (as the office props): 1 Blender unit = 1 stud, Z up, front faces -Y, stands on z=0, centred on x/y.
# Materials are procedural (noise colour + noise bump + ground grime). Wood uses the Wood049 scan when the texture-pipeline
# work folder has it (TEXPIPE_WORK/cc0, TEXPIPE_WORK/textures/oak_scan_color.png), else hardlib's procedural wood.
import bpy, bmesh, math, os, sys, random
from mathutils import Vector, Matrix

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "map-kits", "odd-hours-b1"))
sys.path.insert(0, "C:/Users/Bruk Abu/.claude/skills/texture-pipeline/scripts")
import hardlib as H
from hardlib import box, cyl, cylx, sphere, rot, cone, _new
import build_set_stage2 as S2

S2.OUT = os.environ.get("YARD_OUT", os.path.join(HERE, "out"))
S2.SPECIAL.update({"glassmat": "Glass", "glow": "Glow", "hazard": "Hazard"})
PROPS = {}
PAINT = {"v": None}


def prop(fn):
    PROPS[fn.__name__] = fn
    return fn


# ---------------------------------------------------------------- materials ---
def _paint(name, rgb, rough=0.5, bump=0.2, scale=6.0, grime=0.0, grime_h=1.5):
    """Painted / moulded finish: soft colour mottle, a fine noise bump, and optional grime rising from the ground."""
    m, N, L, b = _new(name)
    tc = N.new("ShaderNodeTexCoord")
    nz = N.new("ShaderNodeTexNoise"); nz.inputs["Scale"].default_value = scale; nz.inputs["Detail"].default_value = 5
    L.new(tc.outputs["Object"], nz.inputs["Vector"])
    base = N.new("ShaderNodeMixRGB"); base.blend_type = "MULTIPLY"; base.inputs["Fac"].default_value = 0.14
    base.inputs[1].default_value = (*rgb, 1); L.new(nz.outputs["Color"], base.inputs[2])
    out = base.outputs["Color"]
    if grime > 0:
        sep = N.new("ShaderNodeSeparateXYZ"); L.new(tc.outputs["Object"], sep.inputs["Vector"])
        mr = N.new("ShaderNodeMapRange"); mr.inputs["From Min"].default_value = 0.0; mr.inputs["From Max"].default_value = grime_h
        mr.inputs["To Min"].default_value = 1.0; mr.inputs["To Max"].default_value = 0.0
        L.new(sep.outputs["Z"], mr.inputs["Value"])
        n2 = N.new("ShaderNodeTexNoise"); n2.inputs["Scale"].default_value = 2.2; n2.inputs["Detail"].default_value = 6
        L.new(tc.outputs["Object"], n2.inputs["Vector"])
        streak = N.new("ShaderNodeTexNoise"); streak.inputs["Scale"].default_value = 3.0; streak.inputs["Detail"].default_value = 4
        mp = N.new("ShaderNodeMapping"); mp.inputs["Scale"].default_value = (6.0, 6.0, 0.4)
        L.new(tc.outputs["Object"], mp.inputs["Vector"]); L.new(mp.outputs["Vector"], streak.inputs["Vector"])
        a = N.new("ShaderNodeMath"); a.operation = "MULTIPLY"; L.new(mr.outputs["Result"], a.inputs[0]); L.new(n2.outputs["Fac"], a.inputs[1])
        s = N.new("ShaderNodeMath"); s.operation = "MULTIPLY"; s.inputs[1].default_value = 0.35; L.new(streak.outputs["Fac"], s.inputs[0])
        c = N.new("ShaderNodeMath"); c.operation = "ADD"; L.new(a.outputs[0], c.inputs[0]); L.new(s.outputs[0], c.inputs[1])
        k = N.new("ShaderNodeMath"); k.operation = "MULTIPLY"; k.use_clamp = True; k.inputs[1].default_value = grime
        L.new(c.outputs[0], k.inputs[0])
        mix = N.new("ShaderNodeMixRGB"); mix.blend_type = "MIX"
        mix.inputs[2].default_value = (rgb[0] * 0.35 + 0.03, rgb[1] * 0.3 + 0.02, rgb[2] * 0.25 + 0.01, 1)
        L.new(k.outputs[0], mix.inputs["Fac"]); L.new(out, mix.inputs[1]); out = mix.outputs["Color"]
    L.new(out, b.inputs["Base Color"])
    n3 = N.new("ShaderNodeTexNoise"); n3.inputs["Scale"].default_value = 45; n3.inputs["Detail"].default_value = 3
    L.new(tc.outputs["Object"], n3.inputs["Vector"])
    bp = N.new("ShaderNodeBump"); bp.inputs["Strength"].default_value = bump; bp.inputs["Distance"].default_value = 0.01
    L.new(n3.outputs["Fac"], bp.inputs["Height"]); L.new(bp.outputs["Normal"], b.inputs["Normal"])
    b.inputs["Roughness"].default_value = rough
    return m


def _flat(name, rgb, rough=0.4):
    m, N, L, b = _new(name)
    b.inputs["Base Color"].default_value = (*rgb, 1); b.inputs["Roughness"].default_value = rough
    return m


def _woodmat(name, along):
    color = os.path.join(H.TEXLAB, "oak_scan_color.png")
    height = os.path.join(H.CC0, "Wood049", "Wood049_2K-JPG_Displacement.jpg")
    if os.path.exists(color) and os.path.exists(height):
        return H._scan(name, color, height, studs=6, bump=0.45, rough=0.7, tint=(0.82, 0.68, 0.52), along="Z" if along == "Z" else "X")
    return H._wood(name, (0.16, 0.085, 0.04), (0.42, 0.25, 0.12), along)


BIN = {"green": (0.06, 0.20, 0.07), "blue": (0.05, 0.10, 0.30), "grey": (0.20, 0.21, 0.22)}
CAR = {"taupe": (0.52, 0.43, 0.30), "slate": (0.17, 0.27, 0.42), "red": (0.56, 0.10, 0.07)}

H._SPEC.update({
    "dump_green": lambda: _paint("dump_green", (0.05, 0.16, 0.07), 0.55, 0.3, grime=0.9, grime_h=2.5),
    "dump_inner": lambda: _paint("dump_inner", (0.02, 0.05, 0.025), 0.8, 0.2),
    "lidplas": lambda: _paint("lidplas", (0.025, 0.025, 0.03), 0.45, 0.15),
    "bagplas": lambda: _paint("bagplas", (0.012, 0.012, 0.015), 0.25, 0.6, scale=3),
    "cardboard": lambda: _paint("cardboard", (0.40, 0.25, 0.12), 0.85, 0.3),
    "rubber": lambda: _paint("rubber", (0.02, 0.02, 0.022), 0.9, 0.1),
    "galv": lambda: _paint("galv", (0.40, 0.41, 0.42), 0.4, 0.15, scale=12),
    "binpaint": lambda: _paint("binpaint", BIN[PAINT["v"] or "green"], 0.5, 0.2, grime=0.7, grime_h=1.6),
    "wood_x": lambda: _woodmat("wood_x", "X"),
    "wood_y": lambda: _woodmat("wood_y", "Y"),
    "wood_z": lambda: _woodmat("wood_z", "Z"),
    "crate_red": lambda: _paint("crate_red", (0.42, 0.06, 0.05), 0.5, 0.2, grime=0.4, grime_h=0.6),
    "cone_orange": lambda: _paint("cone_orange", (0.85, 0.22, 0.03), 0.45, 0.15, grime=0.5, grime_h=0.8),
    "reflect_white": lambda: _paint("reflect_white", (0.80, 0.80, 0.76), 0.3, 0.1, grime=0.3, grime_h=1.2),
    "barrier_wood": lambda: _paint("barrier_wood", (0.62, 0.58, 0.50), 0.6, 0.25, grime=0.6, grime_h=1.5),
    "chrome": lambda: _paint("chrome", (0.55, 0.56, 0.58), 0.25, 0.05, scale=20),
    "handle_red": lambda: _paint("handle_red", (0.55, 0.06, 0.05), 0.45, 0.1),
    "vend_body": lambda: _paint("vend_body", (0.07, 0.07, 0.16), 0.45, 0.15, grime=0.4, grime_h=1.2),
    "vend_trim": lambda: _paint("vend_trim", (0.02, 0.02, 0.03), 0.5, 0.1),
    "glassmat": lambda: _flat("glassmat", (0.46, 0.58, 0.62), 0.06),
    "glow": lambda: _flat("glow", (0.85, 0.80, 0.62), 0.5),
    "hazard": lambda: _flat("hazard", (0.95, 0.52, 0.04), 0.3),
    "prod_a": lambda: _paint("prod_a", (0.60, 0.08, 0.10), 0.3, 0.05),
    "prod_b": lambda: _paint("prod_b", (0.08, 0.30, 0.60), 0.3, 0.05),
    "prod_c": lambda: _paint("prod_c", (0.10, 0.50, 0.15), 0.3, 0.05),
    "prod_d": lambda: _paint("prod_d", (0.85, 0.55, 0.05), 0.3, 0.05),
    "litter_grey": lambda: _paint("litter_grey", (0.22, 0.23, 0.24), 0.5, 0.2, grime=0.6, grime_h=1.2),
    "slot_dark": lambda: _flat("slot_dark", (0.01, 0.01, 0.012), 0.9),
    "carpaint": lambda: _paint("carpaint", CAR[PAINT["v"] or "taupe"], 0.3, 0.08, scale=4, grime=0.7, grime_h=1.8),
    "carglass": lambda: _paint("carglass", (0.03, 0.05, 0.09), 0.08, 0.02, scale=2),
    "trim_plas": lambda: _paint("trim_plas", (0.04, 0.04, 0.045), 0.6, 0.15),
    "headlamp": lambda: _paint("headlamp", (0.80, 0.76, 0.58), 0.2, 0.02),
    "taillamp": lambda: _paint("taillamp", (0.45, 0.03, 0.03), 0.2, 0.02),
    "plate": lambda: _paint("plate", (0.75, 0.74, 0.68), 0.5, 0.05),
    "leaf": lambda: _paint("leaf", (0.05, 0.13, 0.05), 0.8, 0.8, scale=14),
    "leaf_light": lambda: _paint("leaf_light", (0.10, 0.22, 0.07), 0.8, 0.6, scale=14),
    "bark": lambda: _paint("bark", (0.10, 0.06, 0.035), 0.9, 0.6, scale=20),
    "petal_yel": lambda: _paint("petal_yel", (0.85, 0.62, 0.04), 0.6, 0.1),
    "seed_white": lambda: _paint("seed_white", (0.85, 0.85, 0.82), 0.8, 0.3, scale=30),
    "catfur": lambda: _paint("catfur", (0.025, 0.022, 0.03), 0.75, 0.5, scale=25),
    "crowfeather": lambda: _paint("crowfeather", (0.02, 0.022, 0.035), 0.4, 0.4, scale=30),
    "beak": lambda: _paint("beak", (0.08, 0.08, 0.085), 0.4, 0.05),
    "eye_glow": lambda: _flat("eye_glow", (0.75, 0.80, 0.18), 0.1),
    "catfur_l": lambda: _paint("catfur_l", (0.05, 0.045, 0.06), 0.8, 0.6, scale=25),
    "crowfeather_l": lambda: _paint("crowfeather_l", (0.035, 0.04, 0.06), 0.35, 0.4, scale=30),
    "pink": lambda: _flat("pink", (0.55, 0.22, 0.25), 0.5),
    "coon_belly": lambda: _flat("coon_belly", (0.60, 0.58, 0.54), 0.85),
    "white": lambda: _flat("white", (0.85, 0.85, 0.82), 0.3),
    "glint": lambda: _flat("glint", (1.0, 1.0, 1.0), 0.1),
    "eye_dark": lambda: _flat("eye_dark", (0.01, 0.01, 0.01), 0.05),
    "coon_fur": lambda: _paint("coon_fur", (0.22, 0.21, 0.20), 0.8, 0.5, scale=25),
    "coon_light": lambda: _paint("coon_light", (0.62, 0.60, 0.56), 0.8, 0.15, scale=25),
    "coon_mask": lambda: _paint("coon_mask", (0.025, 0.025, 0.03), 0.8, 0.4, scale=25),
})


# ------------------------------------------------------------------ helpers ---
def strut(name, a, b, t, mat, tw=None, bevel=0.03):
    """A square beam from point a to point b, t thick (tw wide across, if given)."""
    a, b = Vector(a), Vector(b); d = b - a
    bm = bmesh.new(); bmesh.ops.create_cube(bm, size=1.0)
    for v in bm.verts:
        v.co = Vector((v.co.x * (tw or t), v.co.y * t, v.co.z * d.length))
    up = "X" if abs(d.normalized().y) > 0.9 else "Y"
    M3 = d.normalized().to_track_quat("Z", up).to_matrix()
    for v in bm.verts:
        v.co = M3 @ v.co + (a + b) / 2
    return H._add(name, bm, mat, bevel, segs=2)


def rod(name, a, b, r, mat, verts=8):
    """A round bar from point a to point b."""
    a, b = Vector(a), Vector(b); d = b - a
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, segments=verts, radius1=r, radius2=r, depth=d.length)
    up = "X" if abs(d.normalized().y) > 0.9 else "Y"
    M3 = d.normalized().to_track_quat("Z", up).to_matrix()
    for v in bm.verts:
        v.co = M3 @ v.co + (a + b) / 2
    return H._add(name, bm, mat, 0)


def taper(ob, z_split, k):
    """Pull the verts below z_split toward the object's vertical axis by factor k (a bin narrower at the base)."""
    for v in ob.data.vertices:
        if v.co.z < z_split:
            v.co.x *= k; v.co.y *= k


def wheel(name, x, y, z, r, w, hub="galv"):
    cylx(name + "_tyre", x - w / 2, x + w / 2, y, z, r, "rubber", 20)
    side = 1 if x > 0 else -1
    cylx(name + "_hub", x + side * (w / 2 - 0.02), x + side * (w / 2 + 0.03), y, z, r * 0.55, hub, 16)


# -------------------------------------------------------------------- props ---
@prop
def dumpster():
    """Front-load dumpster, 9 W x 5.5 D x 5.7 H, green, one lid half propped open on bags (the concept's 'lid ajar')."""
    W, D, T, Z0, Z1 = 4.5, 2.75, 0.18, 0.75, 5.2
    box("front", -W, W, -D, -D + T, Z0, Z1, "dump_green", bevel=0.05)
    box("back", -W, W, D - T, D, Z0, Z1, "dump_green", bevel=0.05)
    box("sideL", -W, -W + T, -D, D, Z0, Z1, "dump_green", bevel=0.05)
    box("sideR", W - T, W, -D, D, Z0, Z1, "dump_green", bevel=0.05)
    box("floor", -W, W, -D, D, Z0 - 0.1, Z0 + 0.1, "dump_green", r=0.3, corners=("fl", "fr", "bl", "br"), bevel=0.04)
    box("inner", -W + T, W - T, -D + T, D - T, Z0 + 0.1, Z1 - 0.2, "dump_inner", bevel=0)
    for nm, x0, x1, y0, y1 in (("rimF", -W - 0.1, W + 0.1, -D - 0.12, -D + T), ("rimB", -W - 0.1, W + 0.1, D - T, D + 0.12),
                               ("rimL", -W - 0.12, -W + T, -D, D), ("rimR", W - T, W + 0.12, -D, D)):
        box(nm, x0, x1, y0, y1, Z1 - 0.05, Z1 + 0.22, "dump_green", bevel=0.06)
    for x in (-3.0, 0.0, 3.0):
        box(f"rib{x}", x - 0.22, x + 0.22, -D - 0.2, -D, Z0 + 0.3, Z1 - 0.3, "dump_green", bevel=0.05)
    for s in (-1, 1):
        box(f"pocket{s}", min(s * W, s * (W + 0.35)), max(s * W, s * (W + 0.35)), -1.9, 1.9, 2.3, 3.0, "lidplas", bevel=0.05)
        for y in (-2.0, 2.0):
            box(f"caster_br{s}{y}", s * 3.8 - 0.3, s * 3.8 + 0.3, y - 0.3, y + 0.3, 0.55, Z0 - 0.08, "galv", bevel=0.03)
            cylx(f"caster{s}{y}", s * 3.8 - 0.14, s * 3.8 + 0.14, y, 0.3, 0.3, "rubber", 14)
    # lids: left half closed, right half propped open on the bags
    box("lidL", -W - 0.1, -0.05, -D - 0.1, D + 0.1, Z1 + 0.22, Z1 + 0.42, "lidplas", r=0.15, corners=("fl", "fr", "bl", "br"), bevel=0.05)
    lid = box("lidR", 0.05, W + 0.1, -D - 0.1, D + 0.1, Z1 + 0.22, Z1 + 0.42, "lidplas", r=0.15, corners=("fl", "fr", "bl", "br"), bevel=0.05)
    rot(lid, -24, "X", (0, D + 0.1, Z1 + 0.32))
    for x in (-3.4, -1.2, 1.2, 3.4):
        cylx(f"hinge{x}", x - 0.35, x + 0.35, D + 0.14, Z1 + 0.32, 0.12, "galv", 10)
    sphere("bag1", 2.4, -0.4, Z1 + 0.05, 1.05, "bagplas", 1.1, 1.0, 0.85)
    sphere("bag2", 1.0, 0.8, Z1 - 0.1, 0.95, "bagplas", 1.0, 1.1, 0.8)
    cone("bagtie", 2.4, -0.4, Z1 + 0.85, Z1 + 1.15, 0.12, 0.02, "bagplas", 8)
    box("carton", 3.0, 4.15, 0.4, 1.9, Z1 - 0.6, Z1 + 0.35, "cardboard", bevel=0.03)
    S2.finish2("yd_dumpster")


@prop
def wheeliebin():
    """Wheelie bin, 2.4 W x 2.7 D x 4.2 H, paint variant green|blue|grey, wheels and handle at the back (+Y)."""
    body = box("body", -1.1, 1.1, -1.2, 1.2, 0.35, 3.9, "binpaint", r=0.28, corners=("fl", "fr", "bl", "br"), bevel=0.06)
    taper(body, 1.0, 0.86)
    box("lip", -1.2, 1.2, -1.32, 1.25, 3.72, 3.92, "binpaint", r=0.3, corners=("fl", "fr", "bl", "br"), bevel=0.05)
    box("lid", -1.22, 1.22, -1.4, 1.3, 3.92, 4.18, "binpaint", r=0.3, corners=("fl", "fr", "bl", "br"), bevel=0.07)
    box("lidgrip", -0.5, 0.5, -1.5, -1.3, 3.85, 4.1, "binpaint", bevel=0.05)
    for z in (1.6, 2.6):
        box(f"band{z}", -1.02, 1.02, -1.22, -1.12, z, z + 0.18, "binpaint", bevel=0.04)
    box("rearblock", -1.0, 1.0, 1.0, 1.42, 0.3, 1.2, "binpaint", bevel=0.06)
    cylx("handle", -0.95, 0.95, 1.42, 3.72, 0.12, "binpaint", 12)
    cylx("axle", -1.15, 1.15, 1.1, 0.42, 0.08, "galv", 10)
    for s in (-1, 1):
        wheel(f"w{s}", s * 1.05, 1.1, 0.42, 0.42, 0.28)
    S2.finish2("yd_wheeliebin_" + (PAINT["v"] or "green"), tex=512)


@prop
def pallet():
    """Wooden pallet, 4 x 4 x 0.62. Stack copies for the dock's pallet stacks."""
    for i, y in enumerate((-1.75, 0.0, 1.75)):
        box(f"bot{i}", -2.0, 2.0, y - 0.28, y + 0.28, 0.0, 0.1, "wood_x", bevel=0.02)
        for j, x in enumerate((-1.75, 0.0, 1.75)):
            box(f"blk{i}{j}", x - 0.26, x + 0.26, y - 0.26, y + 0.26, 0.1, 0.42, "wood_z", bevel=0.03)
    for j, x in enumerate((-1.75, 0.0, 1.75)):
        box(f"str{j}", x - 0.28, x + 0.28, -2.0, 2.0, 0.42, 0.5, "wood_y", bevel=0.02)
    rng = random.Random(3)
    for k in range(7):
        y = -1.8 + k * 0.6
        lift = rng.uniform(-0.01, 0.02)
        box(f"deck{k}", -2.0, 2.0, y - 0.21, y + 0.21, 0.5 + lift, 0.61 + lift, "wood_x", bevel=0.025)
    S2.finish2("yd_pallet", tex=512)


@prop
def crate():
    """Plastic milk crate, 1.7 x 1.7 x 1.15: solid moulded walls with two rows of slots and a hand hole."""
    a, h, t = 0.85, 1.15, 0.1
    box("floor", -a, a, -a, a, 0, 0.1, "crate_red", bevel=0.02)
    for nm, x0, x1, y0, y1 in (("f", -a, a, -a, -a + t), ("b", -a, a, a - t, a), ("l", -a, -a + t, -a + t, a - t), ("r", a - t, a, -a + t, a - t)):
        box(f"wall{nm}", x0, x1, y0, y1, 0, h, "crate_red", bevel=0.03)
        box(f"rim{nm}", x0 - (0.04 if nm == "l" else 0), x1 + (0.04 if nm == "r" else 0), y0 - (0.04 if nm == "f" else 0),
            y1 + (0.04 if nm == "b" else 0), h - 0.12, h, "crate_red", bevel=0.03)
    for zc in (0.32, 0.62):
        for i in range(4):
            u = -0.6 + i * 0.4
            box(f"slF{zc}{i}", u - 0.13, u + 0.13, -a - 0.01, -a + 0.04, zc - 0.1, zc + 0.1, "slot_dark", bevel=0)
            box(f"slB{zc}{i}", u - 0.13, u + 0.13, a - 0.04, a + 0.01, zc - 0.1, zc + 0.1, "slot_dark", bevel=0)
            box(f"slL{zc}{i}", -a - 0.01, -a + 0.04, u - 0.13, u + 0.13, zc - 0.1, zc + 0.1, "slot_dark", bevel=0)
            box(f"slR{zc}{i}", a - 0.04, a + 0.01, u - 0.13, u + 0.13, zc - 0.1, zc + 0.1, "slot_dark", bevel=0)
    for nm, x0, x1, y0, y1 in (("F", -0.35, 0.35, -a - 0.01, -a + 0.04), ("B", -0.35, 0.35, a - 0.04, a + 0.01)):
        box(f"hand{nm}", x0, x1, y0, y1, 0.86, 0.98, "slot_dark", bevel=0)
    S2.finish2("yd_crate", tex=512)


@prop
def trafficcone():
    """Traffic cone, 1.5 x 1.5 base, 2.6 H, two reflective bands."""
    box("base", -0.75, 0.75, -0.75, 0.75, 0, 0.16, "trim_plas", r=0.18, corners=("fl", "fr", "bl", "br"), bevel=0.04)
    R0, R1, Z0, Z1 = 0.6, 0.11, 0.16, 2.6
    rr = lambda z: R0 + (R1 - R0) * (z - Z0) / (Z1 - Z0)
    for i, (z0, z1, m) in enumerate(((Z0, 0.95, "cone_orange"), (0.95, 1.35, "reflect_white"), (1.35, 1.7, "cone_orange"),
                                    (1.7, 2.0, "reflect_white"), (2.0, Z1, "cone_orange"))):
        cone(f"seg{i}", 0, 0, z0, z1, rr(z0), rr(z1), m, 24)
    sphere("tip", 0, 0, Z1, R1, "cone_orange", 1, 1, 0.5)
    S2.finish2("yd_cone", tex=512)


@prop
def barrier():
    """A-frame barricade, 5 W x 2.6 D x 3.7 H, two striped boards on the front (-Y)."""
    for s in (-1, 1):
        x = s * 2.1
        strut(f"legF{s}", (x, -0.15, 3.5), (x, -1.2, 0.05), 0.28, "barrier_wood", tw=0.32)
        strut(f"legB{s}", (x, 0.15, 3.5), (x, 1.2, 0.05), 0.28, "barrier_wood", tw=0.32)
        box(f"cap{s}", x - 0.22, x + 0.22, -0.3, 0.3, 3.4, 3.7, "galv", bevel=0.04)
        cylx(f"pin{s}", x - 0.3, x + 0.3, 0, 3.5, 0.08, "galv", 10)
    for z0, z1, yc in ((2.55, 3.2, -0.42), (1.35, 2.0, -0.76)):
        n, w = 8, 5.0 / 8
        for i in range(n):
            box(f"stripe{z0}{i}", -2.5 + i * w, -2.5 + (i + 1) * w, yc - 0.18, yc, z0, z1,
                "cone_orange" if i % 2 == 0 else "reflect_white", bevel=0.015)
        for x in (-2.1, 2.1):
            box(f"bolt{z0}{x}", x - 0.08, x + 0.08, yc - 0.22, yc - 0.17, (z0 + z1) / 2 - 0.08, (z0 + z1) / 2 + 0.08, "galv", bevel=0)
    S2.finish2("yd_barrier", tex=512)


@prop
def trolley():
    """Shopping trolley, 2.3 W x 3.9 L x 3.7 H, wire basket, red handle at the back (+Y)."""
    yF, yB, z0, z1 = -1.8, 1.5, 1.9, 3.3
    wF, wB = 0.85, 1.1                  # half widths: the nose is narrower
    hw = lambda y: wF + (wB - wF) * (y - yF) / (yB - yF)
    r = 0.045
    for z in (z0, (z0 + z1) / 2, z1):
        for s in (-1, 1):
            rod(f"side{z}{s}", (s * hw(yF), yF, z), (s * hw(yB), yB, z), r if z != z1 else 0.07, "chrome")
        rod(f"nose{z}", (-wF, yF, z), (wF, yF, z), r if z != z1 else 0.07, "chrome")
        rod(f"rear{z}", (-wB, yB, z), (wB, yB, z), r if z != z1 else 0.07, "chrome")
    n = 9
    for i in range(n + 1):
        y = yF + (yB - yF) * i / n
        for s in (-1, 1):
            rod(f"vs{i}{s}", (s * hw(y), y, z0), (s * hw(y), y, z1), r, "chrome")
        rod(f"fl{i}", (-hw(y), y, z0), (hw(y), y, z0), r, "chrome")
    for i in range(7):
        x = -wF + 2 * wF * i / 6
        rod(f"vn{i}", (x, yF, z0), (x, yF, z1), r, "chrome")
        xb = -wB + 2 * wB * i / 6
        rod(f"vb{i}", (xb, yB, z0), (xb, yB + 0.1, z1), r, "chrome")
    for s in (-1, 1):
        rod(f"hpost{s}", (s * wB, yB, z1), (s * wB, yB + 0.45, z1 + 0.35), 0.07, "chrome")
        rod(f"frameS{s}", (s * 0.75, -1.6, 0.6), (s * 0.95, 1.35, 0.6), 0.07, "chrome")
        rod(f"legB{s}", (s * 0.95, 1.35, 0.6), (s * wB, yB, z0), 0.07, "chrome")
        rod(f"legF{s}", (s * 0.75, -1.6, 0.6), (s * wF, yF + 0.2, z0), 0.07, "chrome")
    rod("frameF", (-0.75, -1.6, 0.6), (0.75, -1.6, 0.6), 0.07, "chrome")
    rod("frameB", (-0.95, 1.35, 0.6), (0.95, 1.35, 0.6), 0.07, "chrome")
    for i in range(5):
        y = -1.3 + i * 0.6
        rod(f"tray{i}", (-0.8, y, 0.62), (0.8, y, 0.62), r, "chrome")
    cylx("handle", -wB - 0.05, wB + 0.05, yB + 0.45, z1 + 0.35, 0.11, "handle_red", 14)
    for s in (-1, 1):
        box(f"hcap{s}", s * (wB + 0.05) - 0.12, s * (wB + 0.05) + 0.12, yB + 0.33, yB + 0.57, z1 + 0.23, z1 + 0.47, "handle_red", bevel=0.04)
    for (x, y) in ((-0.75, -1.6), (0.75, -1.6), (-0.95, 1.35), (0.95, 1.35)):
        box(f"fork{x}{y}", x - 0.1, x + 0.1, y - 0.12, y + 0.12, 0.3, 0.6, "galv", bevel=0.02)
        cylx(f"cast{x}{y}", x - 0.08, x + 0.08, y, 0.25, 0.25, "rubber", 12)
    S2.finish2("yd_trolley", tex=512)


@prop
def vending():
    """Drinks machine, 3.6 W x 3 D x 7.4 H. Glass, a lit back panel (Glow) and no brand: a plain blank header."""
    W, D, Hh = 1.8, 1.5, 7.4
    box("body", -W, W, -D + 0.62, D, 0.25, Hh, "vend_body", r=0.18, corners=("bl", "br"), bevel=0.05)
    box("kick", -W + 0.1, W - 0.1, -D + 0.3, D - 0.1, 0, 0.25, "vend_trim", bevel=0.02)
    # the door is a frame round the window, so the lit shelves behind the glass show
    for nm, x0, x1, z0, z1 in (("doorL", -W, -1.62, 0.25, Hh), ("doorR", 0.62, W, 0.25, Hh), ("doorB", -1.62, 0.62, 0.25, 1.95),
                               ("doorT", -1.62, 0.62, 6.85, Hh)):
        box(nm, x0, x1, -D, -D + 0.64, z0, z1, "vend_body", bevel=0.04)
    box("Glass", -1.5, 0.5, -D - 0.08, -D - 0.04, 2.05, 6.75, "glassmat", bevel=0)
    box("Glow", -1.5, 0.5, -D + 0.56, -D + 0.6, 2.05, 6.75, "glow", bevel=0)
    box("cavL", -1.56, -1.5, -D + 0.02, -D + 0.62, 2.05, 6.75, "vend_trim", bevel=0)
    box("cavR", 0.5, 0.56, -D + 0.02, -D + 0.62, 2.05, 6.75, "vend_trim", bevel=0)
    box("cavT", -1.56, 0.56, -D + 0.02, -D + 0.62, 6.75, 6.81, "vend_trim", bevel=0)
    prods = ["prod_a", "prod_b", "prod_c", "prod_d"]
    for row, z in enumerate((2.2, 3.35, 4.5, 5.65)):
        box(f"shelf{row}", -1.5, 0.5, -D + 0.05, -D + 0.6, z - 0.06, z, "galv", bevel=0)
        for i in range(5):
            x = -1.25 + i * 0.4
            m = prods[(row + i) % 4]
            if row < 2:
                cyl(f"can{row}{i}", x, -D + 0.3, z, z + 0.62, 0.14, m, verts=12, bevel=0.01)
            else:
                cyl(f"btl{row}{i}", x, -D + 0.3, z, z + 0.7, 0.13, m, verts=12, bevel=0.01)
                cone(f"neck{row}{i}", x, -D + 0.3, z + 0.7, z + 0.95, 0.13, 0.05, m, 12)
    box("header", -1.62, 1.62, -D - 0.06, -D + 0.02, 6.95, 7.2, "vend_trim", bevel=0.02)
    box("panel", 0.75, 1.65, -D - 0.06, -D + 0.02, 2.0, 6.8, "vend_trim", bevel=0.03)
    for k in range(6):
        z = 5.9 - k * 0.42
        box(f"btn{k}", 0.95, 1.45, -D - 0.12, -D - 0.04, z, z + 0.26, "glow" if k == 0 else "galv", r=0.06, corners=("tl", "tr", "bl", "br"), axis="Y", bevel=0)
    box("coin", 1.1, 1.3, -D - 0.12, -D - 0.04, 3.1, 3.6, "slot_dark", bevel=0)
    box("flap", -1.4, 0.5, -D - 0.08, -D + 0.02, 0.75, 1.65, "vend_trim", r=0.08, corners=("tl", "tr", "bl", "br"), axis="Y", bevel=0.02)
    box("flapgap", -1.2, 0.3, -D - 0.1, -D - 0.06, 1.25, 1.4, "slot_dark", bevel=0)
    S2.finish2("yd_vending")


@prop
def bench():
    """Picnic table with fixed benches, 6.4 L x 5.4 W x 2.8 H."""
    L = 3.2
    for k in range(5):
        y = -1.1 + k * 0.55
        box(f"top{k}", -L, L, y - 0.25, y + 0.25, 2.55, 2.8, "wood_x", bevel=0.04)
    for s in (-1, 1):
        for k in range(2):
            y = s * (2.05 + (k - 0.5) * 0.5)
            box(f"seat{s}{k}", -L, L, y - 0.23, y + 0.23, 1.55, 1.75, "wood_x", bevel=0.04)
    for x in (-2.3, 2.3):
        for s in (-1, 1):
            strut(f"leg{x}{s}", (x, s * 0.55, 2.55), (x, s * 2.4, 0.03), 0.3, "wood_z", tw=0.24)
        box(f"cleatT{x}", x - 0.14, x + 0.14, -1.35, 1.35, 2.3, 2.55, "wood_y", bevel=0.03)
        box(f"cleatS{x}", x - 0.14, x + 0.14, -2.7, 2.7, 1.3, 1.55, "wood_y", bevel=0.03)
        for s in (-1, 1):
            cylx(f"bolt{x}{s}", x - 0.2, x + 0.2, s * 1.9, 1.42, 0.06, "galv", 8)
    S2.finish2("yd_bench")


@prop
def litterbin():
    """Plain round litter bin, 1.7 dia x 3.1 H, domed lid with a front opening."""
    cyl("base", 0, 0, 0, 0.18, 0.86, "trim_plas", verts=28, bevel=0.03)
    cyl("body", 0, 0, 0.18, 2.75, 0.8, "litter_grey", verts=28, bevel=0.03)
    for z in (0.9, 2.0):
        cyl(f"hoop{z}", 0, 0, z, z + 0.12, 0.83, "trim_plas", verts=28, bevel=0.02)
    cyl("rim", 0, 0, 2.75, 2.85, 0.86, "trim_plas", verts=28, bevel=0.02)
    sphere("dome", 0, 0, 2.85, 0.84, "litter_grey", 1, 1, 0.32)
    box("mouth", -0.42, 0.42, -0.84, -0.55, 2.86, 3.02, "slot_dark", bevel=0)
    S2.finish2("yd_litterbin", tex=512)


@prop
def car():
    """Toy-like hatchback, about 6.9 W x 11.4 L x 5.8 H: chunky rounded body, a short bonnet, a raked rounded cabin, big
    wheels in dark flared arches and round lamps. Paint variant taupe|slate|red. The amber corner lights are kept apart
    (Hazard) so one parked car can blink; no badge or plate text."""
    Y0, Y1, Z0, Z1 = -5.3, 4.9, 0.95, 3.15
    box("body", -3.15, 3.15, Y0, Y1, Z0, Z1, "carpaint", r=1.05, corners=("tf", "tb", "bf", "bb"), axis="X", bevel=0.45, segs=4)
    cy0, cy1, cz1 = -1.5, 4.5, 5.75
    cab = box("cabin", -2.8, 2.8, cy0, cy1, Z1 - 0.3, cz1, "carpaint", r=1.25, corners=("tf", "tb"), axis="X", bevel=0.5, segs=4)
    shear_cabin(cab, cy0, cy1, Z1 - 0.3, cz1)
    ws = box("wsh", -2.3, 2.3, cy0 - 0.08, cy0 + 0.02, Z1 + 0.15, cz1 - 0.45, "carglass", r=0.45, corners=("tl", "tr", "bl", "br"), axis="Y", bevel=0)
    shear_cabin(ws, cy0, cy1, Z1 - 0.3, cz1)
    box("rearw", -2.2, 2.2, cy1 - 0.02, cy1 + 0.08, Z1 + 0.25, cz1 - 0.5, "carglass", r=0.45, corners=("tl", "tr", "bl", "br"), axis="Y", bevel=0)
    for s in (-1, 1):
        w = box(f"sidew{s}", s * 2.82 - 0.05, s * 2.82 + 0.05, cy0 + 0.35, cy1 - 0.6, Z1 + 0.2, cz1 - 0.5, "carglass", r=0.4, corners=("tf", "tb", "bf", "bb"), axis="X", bevel=0)
        shear_cabin(w, cy0, cy1, Z1 - 0.3, cz1)
        box(f"pillar{s}", s * 2.84 - 0.07, s * 2.84 + 0.07, 1.25, 1.6, Z1 + 0.1, cz1 - 0.35, "carpaint", bevel=0.04)
        box(f"seam{s}", s * 3.18 - 0.03, s * 3.18 + 0.03, 1.38, 1.46, 1.35, Z1 - 0.2, "trim_plas", bevel=0)
        box(f"handle{s}", s * 3.2 - 0.06, s * 3.2 + 0.06, 0.4, 1.0, 2.55, 2.72, "galv", bevel=0.02)
        sphere(f"mirror{s}", s * 3.25, -1.25, Z1 + 0.35, 0.32, "carpaint", 1.0, 0.7, 0.75)
        for y in (-3.3, 3.0):
            arch = cylx(f"arch{s}{y}", s * 3.08 - 0.22, s * 3.08 + 0.22, y, 1.45, 1.85, "trim_plas", 28)
            for v in arch.data.vertices:
                v.co.z = max(v.co.z, Z0 - 0.15)
            wheel(f"wh{s}{y}", s * 2.75, y, 1.45, 1.45, 1.2)
            sphere(f"cap{s}{y}", s * 3.38, y, 1.45, 0.35, "galv", 0.45, 1, 1)
        cyl(f"head{s}", s * 1.95, 2.15, Y0 - 0.22, Y0 + 0.4, 0.58, "headlamp", verts=24, bevel=0.06, axis="Y")
        cyl(f"headring{s}", s * 1.95, 2.15, Y0 - 0.12, Y0 + 0.4, 0.7, "trim_plas", verts=24, bevel=0.05, axis="Y")
        cyl(f"Hazard_f{s}", s * 2.85, 1.65, Y0 - 0.05, Y0 + 0.45, 0.24, "hazard", verts=16, bevel=0, axis="Y")
        box(f"tail{s}", s * 2.2 - 0.45, s * 2.2 + 0.45, Y1 - 0.15, Y1 + 0.12, 2.15, 2.95, "taillamp", r=0.25, corners=("tl", "tr", "bl", "br"), axis="Y", bevel=0.03)
        cyl(f"Hazard_b{s}", s * 2.2, 1.7, Y1 - 0.15, Y1 + 0.14, 0.22, "hazard", verts=16, bevel=0, axis="Y")
    box("grille", -1.0, 1.0, Y0 - 0.12, Y0 + 0.3, 1.45, 1.95, "trim_plas", r=0.25, corners=("tl", "tr", "bl", "br"), axis="Y", bevel=0.04)
    box("bumpF", -3.2, 3.2, Y0 - 0.35, Y0 + 0.6, 0.7, 1.35, "trim_plas", r=0.35, corners=("tf", "bf"), axis="X", bevel=0.2)
    box("bumpB", -3.2, 3.2, Y1 - 0.6, Y1 + 0.35, 0.7, 1.35, "trim_plas", r=0.35, corners=("tb", "bb"), axis="X", bevel=0.2)
    box("plateF", -0.6, 0.6, Y0 - 0.4, Y0 - 0.3, 0.8, 1.2, "plate", bevel=0)
    box("plateB", -0.6, 0.6, Y1 + 0.3, Y1 + 0.4, 0.8, 1.2, "plate", bevel=0)
    box("under", -2.9, 2.9, Y0 + 0.4, Y1 - 0.4, 0.55, Z0 + 0.1, "trim_plas", bevel=0.02)
    S2.finish2("yd_car_" + (PAINT["v"] or "taupe"))


def shear_cabin(ob, y0, y1, z0, z1, rake_f=1.15, rake_b=0.35):
    """Rake a cabin (and the glass on it) back at the top: the front half leans back rake_f, the back half rake_b."""
    yc = (y0 + y1) / 2
    for v in ob.data.vertices:
        t = max(0.0, min(1.0, (v.co.z - z0) / (z1 - z0)))
        if v.co.y < yc:
            v.co.y += rake_f * t
        else:
            v.co.y -= rake_b * t


@prop
def bush():
    """Crooked bush, about 4.5 W x 4 D x 4.2 H: a lumpy crown of leaf balls on a bent trunk."""
    rng = random.Random(7)
    strut("trunk1", (0, 0, 0), (0.4, 0.2, 1.4), 0.32, "bark")
    strut("trunk2", (0.4, 0.2, 1.4), (-0.3, 0.1, 2.4), 0.26, "bark")
    strut("branch", (0.4, 0.2, 1.4), (1.3, -0.2, 2.2), 0.18, "bark")
    for i, (x, y, z, r) in enumerate(((-0.3, 0.1, 2.9, 1.25), (1.3, -0.2, 2.6, 1.0), (-1.3, 0.3, 2.3, 0.95), (0.4, 0.9, 3.0, 1.0),
                                       (0.3, -0.8, 3.2, 0.9), (-0.8, -0.6, 3.5, 0.75), (0.9, 0.3, 3.6, 0.7))):
        sphere(f"leaf{i}", x, y, z, r * rng.uniform(0.95, 1.05), "leaf" if i % 3 else "leaf_light", 1.1, 1.0, 0.85)
    for i in range(6):
        a = i / 6 * math.tau + 0.4
        sphere(f"low{i}", math.cos(a) * 0.9, math.sin(a) * 0.7, 0.3, rng.uniform(0.35, 0.5), "leaf_light" if i % 2 else "leaf", 1.2, 1.0, 0.8)
    S2.finish2("yd_bush", tex=512)


@prop
def grasstuft():
    """Verge tuft with two dandelions and a seed clock, about 2 x 2 x 1.8."""
    rng = random.Random(11)
    for i in range(16):
        a = rng.uniform(0, math.tau); d = rng.uniform(0, 0.7)
        x, y = math.cos(a) * d, math.sin(a) * d
        tip = (x + rng.uniform(-0.3, 0.3), y + rng.uniform(-0.3, 0.3), rng.uniform(0.7, 1.3))
        bm_ob = cone(f"blade{i}", 0, 0, 0, 1, 0.09, 0.0, "leaf_light" if i % 2 else "leaf", 4)
        for v in bm_ob.data.vertices:
            t = v.co.z
            v.co = Vector((x + (tip[0] - x) * t + v.co.x, y + (tip[1] - y) * t + v.co.y, tip[2] * t))
    for i, (x, y, h, m) in enumerate(((0.3, -0.2, 1.4, "petal_yel"), (-0.4, 0.3, 1.1, "petal_yel"), (0.1, 0.5, 1.7, "seed_white"))):
        rod(f"stem{i}", (x, y, 0), (x, y, h), 0.035, "leaf_light", 6)
        sphere(f"head{i}", x, y, h + 0.1, 0.16 if m == "petal_yel" else 0.22, m, 1, 1, 0.6 if m == "petal_yel" else 1)
    S2.finish2("yd_grasstuft", tex=512)


@prop
def cat():
    """Fluffy black cat sitting, toy-like: big round head and cheek fluff, chunky paws, a thick tail curled round its
    feet, big glowing eyes (an animal, never Gloom). About 2 W x 1.9 D x 2.75 H, facing -Y."""
    sphere("body", 0, 0.1, 0.78, 0.72, "catfur", 1.0, 1.05, 1.05)
    sphere("chest", 0, -0.3, 1.05, 0.48, "catfur_l", 1.0, 0.7, 1.1)
    for s in (-1, 1):
        sphere(f"haunch{s}", s * 0.5, 0.3, 0.45, 0.42, "catfur", 0.9, 1.15, 0.95)
        sphere(f"leg{s}", s * 0.26, -0.48, 0.42, 0.21, "catfur", 1, 1, 1.9)
        sphere(f"paw{s}", s * 0.27, -0.62, 0.13, 0.22, "catfur", 1.1, 1.3, 0.62)
        sphere(f"cheek{s}", s * 0.42, -0.35, 1.78, 0.32, "catfur", 1.0, 0.8, 0.8)
        ear = cone(f"ear{s}", s * 0.36, -0.15, 2.18, 2.72, 0.26, 0.04, "catfur", 12)
        rot(ear, s * -16, "Y", (s * 0.36, -0.15, 2.18))
        inner = cone(f"earin{s}", s * 0.35, -0.24, 2.24, 2.6, 0.15, 0.02, "pink", 10)
        rot(inner, s * -16, "Y", (s * 0.35, -0.24, 2.24))
        sphere(f"eye{s}", s * 0.25, -0.79, 1.98, 0.17, "eye_glow", 1, 0.45, 1.15)
        sphere(f"pupil{s}", s * 0.25, -0.85, 1.98, 0.05, "eye_dark", 1, 0.5, 2.6)
        sphere(f"glint{s}", s * 0.21, -0.87, 2.07, 0.035, "glint")
    sphere("head", 0, -0.18, 1.98, 0.66, "catfur", 1.1, 1.0, 0.92)
    sphere("muzzle", 0, -0.8, 1.74, 0.2, "catfur_l", 1.35, 0.7, 0.75)
    sphere("nose", 0, -0.93, 1.83, 0.07, "pink", 1.3, 1, 0.8)
    # the tail: from behind, round the right side, curling up in front of the paws
    pts = [(0.35, 0.75, 0.2), (0.85, 0.55, 0.18), (1.05, 0.05, 0.18), (0.9, -0.5, 0.2), (0.55, -0.85, 0.28), (0.28, -0.9, 0.5)]
    prev = (0.0, 0.8, 0.3)
    for i, p in enumerate(pts):
        r = 0.2 - i * 0.012
        rod(f"tail{i}", prev, p, r, "catfur", 12)
        sphere(f"tj{i}", *p, r, "catfur")
        prev = p
    S2.finish2("yd_cat", tex=512)


@prop
def crow():
    """Round crow perched, toy-like: a ball body, a big round head, a chunky readable beak, white-ringed eyes, a fan
    tail and stubby feet. About 0.9 W x 1.6 D x 1.45 H, facing -Y."""
    sphere("body", 0, 0.12, 0.62, 0.48, "crowfeather", 0.95, 1.15, 0.9)
    sphere("head", 0, -0.32, 1.08, 0.36, "crowfeather")
    beak = cone("beak", 0, -0.62, 0.0, 0.5, 0.15, 0.02, "beak", 14)
    rot(beak, 84, "X", (0, -0.62, 0.0))
    for v in beak.data.vertices:
        v.co.z += 1.02
    for s in (-1, 1):
        sphere(f"wing{s}", s * 0.4, 0.22, 0.66, 0.36, "crowfeather_l", 0.4, 1.35, 0.8)
        sphere(f"eyew{s}", s * 0.2, -0.56, 1.17, 0.1, "white", 1, 0.5, 1)
        sphere(f"eye{s}", s * 0.21, -0.61, 1.17, 0.055, "eye_dark")
        sphere(f"glint{s}", s * 0.19, -0.64, 1.2, 0.02, "glint")
        cyl(f"leg{s}", s * 0.16, 0.0, 0.08, 0.25, 0.06, "beak", verts=10, bevel=0)
        sphere(f"foot{s}", s * 0.16, -0.08, 0.06, 0.13, "beak", 0.9, 1.4, 0.45)
    tail = sphere("tail", 0, 0.75, 0.48, 0.3, "crowfeather", 0.9, 1.2, 0.3)
    rot(tail, 22, "X", (0, 0.5, 0.55))
    S2.finish2("yd_crow", tex=512)


@prop
def raccoon():
    """Raccoon sitting, toy-like: round grey body and pale belly, a proper black mask with white brows, round ears, a
    pointed pale snout, and a big fluffy ringed tail curling up behind. About 1.9 W x 2.2 D x 2.1 H, facing -Y."""
    sphere("body", 0, 0.1, 0.72, 0.68, "coon_fur", 1.0, 1.0, 1.05)
    sphere("belly", 0, -0.3, 0.72, 0.46, "coon_belly", 1.0, 0.6, 1.1)
    for s in (-1, 1):
        sphere(f"haunch{s}", s * 0.48, 0.25, 0.4, 0.38, "coon_fur", 0.9, 1.15, 0.95)
        sphere(f"arm{s}", s * 0.4, -0.42, 0.75, 0.17, "coon_fur", 1, 1, 1.8)
        sphere(f"hand{s}", s * 0.36, -0.58, 0.42, 0.17, "coon_mask", 1.1, 1.2, 0.8)
        sphere(f"foot{s}", s * 0.3, -0.55, 0.1, 0.2, "coon_mask", 1.1, 1.35, 0.55)
        sphere(f"ear{s}", s * 0.45, -0.05, 2.0, 0.2, "coon_fur", 1, 0.55, 1.05)
        sphere(f"earin{s}", s * 0.45, -0.12, 2.0, 0.13, "coon_light", 1, 0.4, 1)
        sphere(f"brow{s}", s * 0.24, -0.76, 1.86, 0.16, "coon_light", 1.4, 0.6, 0.55)
        sphere(f"cheek{s}", s * 0.36, -0.66, 1.42, 0.2, "coon_light", 1.2, 0.7, 0.8)
        sphere(f"eye{s}", s * 0.24, -0.86, 1.64, 0.11, "eye_glow", 1, 0.5, 1.05)
        sphere(f"pupil{s}", s * 0.24, -0.92, 1.64, 0.055, "eye_dark")
        sphere(f"glint{s}", s * 0.21, -0.95, 1.69, 0.025, "glint")
    sphere("head", 0, -0.2, 1.62, 0.56, "coon_fur", 1.15, 1.0, 0.92)
    sphere("mask", 0, -0.55, 1.63, 0.42, "coon_mask", 1.5, 0.78, 0.42)
    snout = cone("snout", 0, -0.6, 0, 0.42, 0.22, 0.07, "coon_light", 16)
    rot(snout, 90, "X", (0, -0.6, 0))
    for v in snout.data.vertices:
        v.co.z += 1.38
    sphere("nose", 0, -1.02, 1.4, 0.08, "eye_dark", 1.2, 1, 0.9)
    # the ringed tail: alternating dark and grey segments curling up behind
    pts = [(-0.55, 0.55, 0.25), (-0.95, 0.65, 0.35), (-1.2, 0.6, 0.6), (-1.3, 0.45, 0.92), (-1.22, 0.25, 1.22), (-1.05, 0.1, 1.45)]
    for i, p in enumerate(pts):
        sphere(f"ring{i}", *p, 0.3 - i * 0.02, "coon_mask" if i % 2 else "coon_fur")
    S2.finish2("yd_raccoon", tex=512)


if __name__ == "__main__":
    for w in sys.argv[sys.argv.index("--") + 1:]:
        name, _, variant = w.partition(":")
        H.reset()
        PAINT["v"] = variant or None
        PROPS[name]()
