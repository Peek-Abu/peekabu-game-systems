# Odd Hours depot hub (Night Garage) dressing: hand-built props on the yard kit (build_yard.py materials + helpers).
#
# HOW TO RUN (Blender 5.1 headless):
#   "C:/Program Files/Blender Foundation/Blender 5.1/blender.exe" --background --python build_hub.py -- pumpkin:round leafpile:a tree pendant wallpack
# Variants after a colon: pumpkin:round|tall|squat, leafpile:a|b.
# Env HUB_OUT = output folder (default ./out). Same outputs as build_yard (colour x AO, normal, rough, _parts.glb, _tt.glb).
# Conventions: 1 unit = 1 stud, Z up, front faces -Y, stands on z=0, centred on x/y.
import bpy, bmesh, math, os, sys, random
from mathutils import Vector, Matrix

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "yard-dressing"))
import build_yard as Y
from build_yard import H, S2, strut, rod, _paint, _flat
from hardlib import box, cyl, cylx, sphere, cone

S2.OUT = os.environ.get("HUB_OUT", os.path.join(HERE, "out"))
PROPS = {}
VAR = {"v": None}


def prop(fn):
    PROPS[fn.__name__] = fn
    return fn


H._SPEC.update({
    # pumpkin skin: warm orange, darker in the rib grooves (vertex-free: driven by the object's angle round Z)
    "pumpkin": lambda: _ribbed("pumpkin", (0.80, 0.30, 0.03), (0.42, 0.11, 0.01)),
    "pumpkin_pale": lambda: _ribbed("pumpkin_pale", (0.78, 0.62, 0.36), (0.45, 0.30, 0.14)),
    "stem": lambda: _paint("stem", (0.20, 0.17, 0.07), 0.85, 0.7, scale=25),
    "vine_leaf": lambda: _paint("vine_leaf", (0.12, 0.20, 0.05), 0.7, 0.3, scale=18),
    "leaf_or": lambda: _paint("leaf_or", (0.78, 0.30, 0.04), 0.65, 0.25, scale=16),
    "leaf_red": lambda: _paint("leaf_red", (0.50, 0.07, 0.03), 0.65, 0.25, scale=16),
    "leaf_yel": lambda: _paint("leaf_yel", (0.82, 0.55, 0.08), 0.65, 0.25, scale=16),
    "leaf_brn": lambda: _paint("leaf_brn", (0.30, 0.15, 0.05), 0.8, 0.3, scale=16),
    "leaf_vein": lambda: _paint("leaf_vein", (0.20, 0.07, 0.02), 0.8, 0.2, scale=30),
    "mug_white": lambda: _paint("mug_white", (0.82, 0.80, 0.74), 0.25, 0.05, scale=8),
    "mug_grape": lambda: _paint("mug_grape", (0.22, 0.10, 0.40), 0.3, 0.05, scale=8),
    "mug_mint": lambda: _paint("mug_mint", (0.18, 0.55, 0.42), 0.3, 0.05, scale=8),
    "coffee": lambda: _flat("coffee", (0.10, 0.05, 0.02), 0.15),
    "tape": lambda: _paint("tape", (0.62, 0.48, 0.28), 0.35, 0.05, scale=20),
    "label": lambda: _paint("label", (0.86, 0.84, 0.78), 0.6, 0.05, scale=40),
    "label_red": lambda: _paint("label_red", (0.62, 0.10, 0.08), 0.5, 0.05, scale=40),
    "seat_fabric": lambda: _paint("seat_fabric", (0.24, 0.10, 0.42), 0.9, 0.6, scale=60),
    "steel_dark": lambda: _paint("steel_dark", (0.10, 0.11, 0.13), 0.35, 0.08, scale=14),
    "steel_mid": lambda: _paint("steel_mid", (0.30, 0.32, 0.35), 0.3, 0.08, scale=14),
    "enamel_red": lambda: _paint("enamel_red", (0.55, 0.08, 0.06), 0.25, 0.05, scale=10),
    "brass": lambda: _paint("brass", (0.62, 0.42, 0.12), 0.25, 0.05, scale=12),
    "keycap": lambda: _paint("keycap", (0.80, 0.78, 0.72), 0.4, 0.05, scale=30),
    "screen_green": lambda: _flat("screen_green", (0.10, 0.45, 0.25), 0.2),
    "tin_a": lambda: _paint("tin_a", (0.85, 0.62, 0.10), 0.3, 0.05),
    "tin_b": lambda: _paint("tin_b", (0.12, 0.40, 0.65), 0.3, 0.05),
    "bottle_a": lambda: _paint("bottle_a", (0.20, 0.62, 0.48), 0.2, 0.05),
    "bottle_b": lambda: _paint("bottle_b", (0.70, 0.18, 0.40), 0.2, 0.05),
    "towel": lambda: _paint("towel", (0.82, 0.78, 0.66), 0.95, 0.7, scale=50),
    "bark_au": lambda: _paint("bark_au", (0.11, 0.075, 0.05), 0.9, 0.9, scale=9),
    "crown_or": lambda: _paint("crown_or", (0.72, 0.26, 0.03), 0.8, 1.2, scale=26),
    "crown_red": lambda: _paint("crown_red", (0.48, 0.07, 0.03), 0.8, 1.2, scale=26),
    "crown_yel": lambda: _paint("crown_yel", (0.82, 0.52, 0.06), 0.8, 1.2, scale=26),
    "lamp_green": lambda: _paint("lamp_green", (0.06, 0.20, 0.15), 0.4, 0.12, grime=0.3, grime_h=0.4),
    "lamp_inner": lambda: _flat("lamp_inner", (0.85, 0.82, 0.70), 0.4),
    "cage": lambda: _paint("cage", (0.05, 0.05, 0.055), 0.45, 0.05, scale=20),
    "pack_grey": lambda: _paint("pack_grey", (0.24, 0.25, 0.26), 0.5, 0.15, grime=0.4, grime_h=0.3),
})


def _ribbed(name, rgb, groove):
    """Skin with dark grooves every 1/10 turn: colour from the angle round the object's Z axis."""
    m, N, L, b = H._new(name)
    tc = N.new("ShaderNodeTexCoord")
    sep = N.new("ShaderNodeSeparateXYZ"); L.new(tc.outputs["Object"], sep.inputs["Vector"])
    at = N.new("ShaderNodeMath"); at.operation = "ARCTAN2"; L.new(sep.outputs["Y"], at.inputs[0]); L.new(sep.outputs["X"], at.inputs[1])
    mul = N.new("ShaderNodeMath"); mul.operation = "MULTIPLY"; mul.inputs[1].default_value = 10 / math.tau * math.tau
    L.new(at.outputs[0], mul.inputs[0])
    cs = N.new("ShaderNodeMath"); cs.operation = "COSINE"; L.new(mul.outputs[0], cs.inputs[0])
    # groove = 1 near cos=1 (the groove line), sharpened
    mr = N.new("ShaderNodeMapRange"); mr.inputs["From Min"].default_value = 0.75; mr.inputs["From Max"].default_value = 1.0
    L.new(cs.outputs[0], mr.inputs["Value"])
    nz = N.new("ShaderNodeTexNoise"); nz.inputs["Scale"].default_value = 5; nz.inputs["Detail"].default_value = 5
    L.new(tc.outputs["Object"], nz.inputs["Vector"])
    base = N.new("ShaderNodeMixRGB"); base.blend_type = "MULTIPLY"; base.inputs["Fac"].default_value = 0.22
    base.inputs[1].default_value = (*rgb, 1); L.new(nz.outputs["Color"], base.inputs[2])
    mix = N.new("ShaderNodeMixRGB"); mix.inputs[2].default_value = (*groove, 1)
    L.new(mr.outputs["Result"], mix.inputs["Fac"]); L.new(base.outputs["Color"], mix.inputs[1])
    # top/bottom go a bit greener-brown round the stem
    L.new(mix.outputs["Color"], b.inputs["Base Color"])
    n3 = N.new("ShaderNodeTexNoise"); n3.inputs["Scale"].default_value = 40; n3.inputs["Detail"].default_value = 4
    L.new(tc.outputs["Object"], n3.inputs["Vector"])
    bp = N.new("ShaderNodeBump"); bp.inputs["Strength"].default_value = 0.25; bp.inputs["Distance"].default_value = 0.01
    L.new(n3.outputs["Fac"], bp.inputs["Height"]); L.new(bp.outputs["Normal"], b.inputs["Normal"])
    b.inputs["Roughness"].default_value = 0.45
    return m


def lumpy(name, x, y, z, rad, mat, sx=1, sy=1, sz=1, seed=0, amp=0.18, segs=(18, 12)):
    """A sphere with low-frequency lumps (leaf masses, stones)."""
    rng = random.Random(seed)
    waves = [(Vector((rng.uniform(-1, 1), rng.uniform(-1, 1), rng.uniform(-1, 1))).normalized(), rng.uniform(2, 4), rng.uniform(0, 6)) for _ in range(5)]
    bm = bmesh.new(); bmesh.ops.create_uvsphere(bm, u_segments=segs[0], v_segments=segs[1], radius=rad)
    for v in bm.verts:
        n = v.co.normalized()
        k = 1 + amp * sum(math.sin(n.dot(d) * f + p) for d, f, p in waves) / len(waves)
        v.co = Vector((v.co.x * k * sx + x, v.co.y * k * sy + y, v.co.z * k * sz + z))
    return H._add(name, bm, mat, 0)


# ------------------------------------------------------------------ pumpkins ---
PUMP = {"round": (1.25, 0.95, "pumpkin"), "tall": (1.0, 1.25, "pumpkin"), "squat": (1.35, 0.7, "pumpkin_pale")}


@prop
def pumpkin():
    """A ribbed pumpkin (10 lobes) with a curved stem and a curled vine leaf. round ~2.5 wide, tall ~2.5 high."""
    v = VAR["v"] or "round"
    # "<variant>-bare": no leaf and no vine (owner 11-12: the leaves are their own prop, `pumpkinleaf`).
    bare = v.endswith("-bare")
    v = v.replace("-bare", "")
    r, hk, mat = PUMP[v]
    bm = bmesh.new(); bmesh.ops.create_uvsphere(bm, u_segments=60, v_segments=28, radius=1.0)
    for vt in bm.verts:
        x, y, z = vt.co
        a = math.atan2(y, x)
        lobe = 1 - 0.09 * (abs(math.cos(a * 5)) ** 0.5)  # 10 grooves (cos(5a) zero-crossings x2)
        lobe = 1 - 0.10 * (1 - abs(math.sin(a * 5))) ** 3
        flat = 1 - 0.28 * (abs(z) ** 2.2)  # squashed poles
        pole = -0.18 * max(0.0, z) ** 6     # dimple round the stem
        k = lobe
        vt.co = Vector((x * k * r, y * k * r, (z * flat * hk + pole) * r + r * hk))
    # sink the base dimple
    for vt in bm.verts:
        if vt.co.z < 0.08 * r:
            vt.co.z = 0.08 * r + (vt.co.z - 0.08 * r) * 0.3
    bmesh.ops.translate(bm, verts=bm.verts, vec=(0, 0, -min(v.co.z for v in bm.verts)))
    top = max(v.co.z for v in bm.verts)
    body = H._add("body", bm, mat, 0)
    # curved, faceted stem (6 sides), tapered, bent over
    pts = [Vector((0, 0, top - 0.25)), Vector((0.03, 0, top + 0.25 * r)), Vector((0.14, 0.02, top + 0.45 * r)), Vector((0.32, 0.05, top + 0.55 * r))]
    for i in range(len(pts) - 1):
        t = 0.17 * r * (1 - i * 0.22)
        strut(f"stem{i}", pts[i], pts[i + 1], t, "stem", bevel=0.02)
    if bare:
        S2.finish2(f"hb_pumpkin_{v}_bare", tex=512)
        return
    # a curled vine leaf lying on the shoulder
    leaf = _leafmesh("vleaf", 0.75 * r, "vine_leaf", curl=0.35, seed=3)
    # The veins and stalk are their own object: they move with the leaf (owner 11-11: they were left at the base,
    # inside the pumpkin), and both drape onto the ribbed skin instead of cutting into it.
    veins = bpy.data.objects[leaf.name + "_veins"]
    for ob in (leaf, veins):
        ob.data.transform(Matrix.Rotation(math.radians(-25), 4, "Y"))
        ob.data.transform(Matrix.Translation((-0.35 * r, 0.25 * r, top - 0.12 * r)))
    _drape(body, (leaf, veins), 0.02)
    rod("vine", (0, 0.05, top - 0.05), (-0.55 * r, 0.6 * r, top - 0.35 * r), 0.035, "vine_leaf", 6)
    S2.finish2(f"hb_pumpkin_{v}", tex=512)


# --------------------------------------------------------------------- leaves ---
# A maple leaf's right half, stem base at (0, 0), tip at (0, 1): five pointed lobes with deep notches.
MAPLE_HALF = [(0.0, 0.08), (0.10, 0.04), (0.26, 0.12), (0.47, 0.03), (0.36, 0.22), (0.50, 0.30), (0.88, 0.40),
              (0.64, 0.50), (0.70, 0.70), (0.47, 0.61), (0.38, 0.81), (0.24, 0.71), (0.11, 0.90), (0.0, 1.0)]
MAPLE_TIPS = [(0.0, 1.0), (0.88, 0.40), (-0.88, 0.40), (0.47, 0.03), (-0.47, 0.03)]


def _drape(body, obs, gap):
    """Seats `obs` (a leaf and its veins) on `body`: tilted to the skin's slope under the leaf's middle, then lifted as
    one rigid piece until no vertex is closer than `gap` above the surface straight below it, so the leaf keeps its
    shape (a per-vertex lift crumpled it) and nothing cuts into the ribs."""
    from mathutils.bvhtree import BVHTree
    bvh = BVHTree.FromObject(body, bpy.context.evaluated_depsgraph_get())
    verts = [v for ob in obs for v in ob.data.vertices]
    mid = sum((v.co for v in verts), Vector()) / len(verts)
    hit = bvh.ray_cast(Vector((mid.x, mid.y, mid.z + 50.0)), Vector((0, 0, -1)))
    if hit[0] is not None:
        tilt = Vector((0, 0, 1)).rotation_difference(hit[1].normalized()).to_matrix().to_4x4()
        about = Matrix.Translation(mid) @ tilt @ Matrix.Translation(-mid)
        for ob in obs:
            ob.data.transform(about)
    lift = 0.0
    for ob in obs:
        for v in ob.data.vertices:
            h = bvh.ray_cast(Vector((v.co.x, v.co.y, v.co.z + 50.0)), Vector((0, 0, -1)))
            if h[0] is not None:
                lift = max(lift, h[0].z + gap - v.co.z)
    for ob in obs:
        ob.data.transform(Matrix.Translation((0, 0, lift)))
        ob.data.update()


def _leafmesh(name, size, mat, curl=0.25, seed=0, lobes=5, veins="leaf_vein"):
    """A maple leaf about `size` long lying in XY: the five-lobed outline (pointed tips, deep notches), raised veins to
    each lobe tip, a stalk, a fold along the midrib and a curl. Veins and stalk are their own (darker) material."""
    rng = random.Random(seed)
    outline = MAPLE_HALF[:-1] + [(0.0, 1.0)] + [(-x, y) for (x, y) in reversed(MAPLE_HALF[1:-1])]
    jitter = [(x * rng.uniform(0.94, 1.06), y * rng.uniform(0.96, 1.04)) for (x, y) in outline]
    bm = bmesh.new()
    c = bm.verts.new((0, 0.42 * size, 0))
    ring = [bm.verts.new((x * size * 0.55, y * size, 0)) for (x, y) in jitter]
    for i in range(len(ring)):
        bm.faces.new((c, ring[i], ring[(i + 1) % len(ring)]))
    bmesh.ops.subdivide_edges(bm, edges=[e for e in bm.edges if c in e.verts], cuts=2, use_grid_fill=False)

    def bend(co):
        x, y, z = co
        return Vector((x, y, z + abs(x) * 0.22 + curl * (x * x + 0.4 * (y - 0.4 * size) ** 2) / max(size, 0.01)))

    for v in bm.verts:
        v.co = bend(v.co)
    ret = bmesh.ops.extrude_face_region(bm, geom=list(bm.faces))
    for v in [e for e in ret["geom"] if isinstance(e, bmesh.types.BMVert)]:
        v.co.z -= 0.025
    bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
    ob = H._add(name, bm, mat, 0)
    # veins: thin raised strips from the stem base to each lobe tip, plus the stalk
    vb = bmesh.new()
    base = Vector((0, 0.06 * size, 0))
    for (tx, ty) in MAPLE_TIPS + [(0, -0.3)]:
        tip = Vector((tx * size * 0.55 * 0.9, ty * size * 0.92, 0)) if ty > -0.2 else Vector((0, -0.28 * size, 0))
        d = (tip - base)
        w = (0.022 if ty > -0.2 else 0.035) * size
        perp = Vector((-d.y, d.x, 0)).normalized() * w
        steps = 4
        prev = None
        for s in range(steps + 1):
            p = base + d * (s / steps)
            a = bend(p + perp) + Vector((0, 0, 0.012)); b = bend(p - perp) + Vector((0, 0, 0.012))
            va, vb_ = vb.verts.new(a), vb.verts.new(b)
            if prev:
                vb.faces.new((prev[0], prev[1], vb_, va))
            prev = (va, vb_)
    H._add(name + "_veins", vb, veins, 0)
    return ob


@prop
def leafpile():
    """A drift of ~26 curled autumn leaves heaped against a wall (pile a: 5x3 studs; b: a loose 6x6 scatter)."""
    v = VAR["v"] or "a"
    rng = random.Random(41 if v == "a" else 77)
    mats = ["leaf_or", "leaf_red", "leaf_yel", "leaf_brn", "leaf_or"]
    count = 20 if v == "a" else 14
    for i in range(count):
        if v == "a":
            x = rng.gauss(0, 1.1); y = rng.uniform(-1.0, 1.0) * 0.9
            z = max(0.0, 0.35 * math.exp(-(x * x) / 2) * (1 - abs(y)) ) + 0.04 + i * 0.006
        else:
            x = rng.uniform(-2.8, 2.8); y = rng.uniform(-2.8, 2.8); z = 0.04 + rng.uniform(0, 0.05)
        size = rng.uniform(0.9, 1.35)
        ob = _leafmesh(f"leaf{i}", size, rng.choice(mats), curl=rng.uniform(0.15, 0.55), seed=i * 13 + 5, lobes=rng.choice((3, 5, 5)))
        ob.data.transform(Matrix.Rotation(rng.uniform(-0.45, 0.45), 4, "X") @ Matrix.Rotation(rng.uniform(-0.45, 0.45), 4, "Y"))
        ob.data.transform(Matrix.Rotation(rng.uniform(0, math.tau), 4, "Z"))
        ob.data.transform(Matrix.Translation((x, y, z)))
    S2.finish2(f"hb_leafpile_{v}", tex=512)


# ----------------------------------------------------------------------- tree ---
@prop
def tree():
    """A storybook autumn maple, ~24 tall x 18 wide: a leaning trunk that forks into crooked branches, carrying
    lumpy leaf masses in orange, red and yellow, with a few bare twigs poking out."""
    rng = random.Random(5)
    segs = []

    def limb(name, a, b, r0, r1, verts=10):
        """A tapered round limb from a (radius r0) to b (radius r1), with a slight bark wobble."""
        a, b = Vector(a), Vector(b); d = b - a
        bm = bmesh.new()
        bmesh.ops.create_cone(bm, cap_ends=True, segments=verts, radius1=r0, radius2=r1, depth=d.length)
        for v in bm.verts:
            ang = math.atan2(v.co.y, v.co.x)
            k = 1 + 0.08 * math.sin(ang * 3 + v.co.z * 1.7)
            v.co.x *= k; v.co.y *= k
        up = "X" if abs(d.normalized().y) > 0.9 else "Y"
        M3 = d.normalized().to_track_quat("Z", up).to_matrix()
        for v in bm.verts:
            v.co = M3 @ v.co + (a + b) / 2
        return H._add(name, bm, "bark_au", 0)

    def branch(a, d, length, r, depth):
        b = a + d * length
        limb(f"br{len(segs)}", a, b, r, r * 0.68, 8 if depth > 1 else 6)
        segs.append((b, d, depth))
        if depth == 0:
            return
        for k in range(2):
            nd = (d + Vector((rng.uniform(-1.0, 1.0), rng.uniform(-1.0, 1.0), rng.uniform(-0.1, 0.45)))).normalized()
            branch(b - d * 0.15, nd, length * rng.uniform(0.6, 0.75), r * 0.66, depth - 1)

    # root flare + a leaning, tapering trunk
    for i in range(5):
        a = i / 5 * math.tau + 0.3
        limb(f"root{i}", (math.cos(a) * 1.7, math.sin(a) * 1.7, -0.1), (0.1, 0, 2.6), 0.25, 0.75, 6)
    limb("trunk0", (0, 0, -0.1), (0.35, 0.15, 5.8), 1.05, 0.85, 12)
    limb("trunk1", (0.35, 0.15, 5.5), (0.7, -0.1, 9.4), 0.85, 0.62, 12)
    branch(Vector((0.7, -0.1, 9.2)), Vector((-0.6, 0.2, 1)).normalized(), 4.6, 0.55, 3)
    branch(Vector((0.7, -0.1, 9.2)), Vector((0.75, -0.25, 1)).normalized(), 4.4, 0.52, 3)
    branch(Vector((0.5, 0.05, 7.4)), Vector((0.15, 0.95, 0.55)).normalized(), 4.0, 0.42, 2)
    branch(Vector((0.45, 0.0, 6.8)), Vector((-0.2, -0.95, 0.5)).normalized(), 3.6, 0.38, 2)
    # foliage: clusters of small crumpled clumps round the branch ends (chunky, faceted, leafy silhouette);
    # a few ends stay bare so twigs poke out
    mats = ["crown_or", "crown_or", "crown_red", "crown_yel", "crown_or"]
    ends = [s for s in segs if s[2] <= 1]
    rng.shuffle(ends)
    n = 0
    for i, (p, d, dpt) in enumerate(ends):
        if i % 6 == 5 or n >= 44:
            continue
        for j in range(rng.choice((2, 3))):
            if n >= 44:
                break
            off = Vector((rng.uniform(-1.2, 1.2), rng.uniform(-1.2, 1.2), rng.uniform(-0.3, 1.0)))
            c = p + d * 0.6 + off
            r = rng.uniform(1.3, 2.1)
            bm = bmesh.new(); bmesh.ops.create_icosphere(bm, subdivisions=2, radius=r)
            for v in bm.verts:
                nrm = v.co.normalized()
                k = 1 + rng.uniform(-0.16, 0.16) + 0.12 * math.sin(nrm.x * 5 + i) * math.cos(nrm.y * 4 + j)
                v.co = Vector((v.co.x * k * 1.1, v.co.y * k * 1.1, v.co.z * k * 0.82)) + c
            H._add(f"clump{n}", bm, mats[(i + j) % len(mats)], 0)
            n += 1
    S2.finish2("hb_tree_maple", tex=1024, smooth_angle=20)


# --------------------------------------------------------------------- lights ---
@prop
def pendant():
    """Caged warehouse pendant: an enamel dome shade (green outside, white inside), a wire cage and a glowing bulb,
    on a drop rod with a ceiling canopy. ~2.4 wide x 3.2 tall (canopy at the top, z=3.2)."""
    H_ = 3.2
    cyl("canopy", 0, 0, H_ - 0.12, H_, 0.32, "cage", 16)
    rod("droprod", (0, 0, H_ - 0.1), (0, 0, 1.75), 0.05, "cage", 8)
    cyl("socket", 0, 0, 1.45, 1.8, 0.16, "cage", 12)
    # dome shade: a lathe profile with thickness
    prof = [(0.18, 1.75), (0.45, 1.68), (0.8, 1.45), (1.05, 1.1), (1.18, 0.82), (1.2, 0.75)]
    bm = bmesh.new()
    rings = []
    seg = 32
    for (r, z) in prof:
        rings.append([bm.verts.new((math.cos(i / seg * math.tau) * r, math.sin(i / seg * math.tau) * r, z)) for i in range(seg)])
    for a, b in zip(rings, rings[1:]):
        for i in range(seg):
            bm.faces.new((a[i], a[(i + 1) % seg], b[(i + 1) % seg], b[i]))
    sh = H._add("shade", bm, "lamp_green", 0)
    sh.modifiers.new("solid", "SOLIDIFY").thickness = 0.05
    # inner white liner (slightly smaller)
    bm = bmesh.new(); rings = []
    for (r, z) in prof:
        rings.append([bm.verts.new((math.cos(i / seg * math.tau) * (r - 0.06), math.sin(i / seg * math.tau) * (r - 0.06), z - 0.04)) for i in range(seg)])
    for a, b in zip(rings, rings[1:]):
        for i in range(seg):
            bm.faces.new((b[i], b[(i + 1) % seg], a[(i + 1) % seg], a[i]))
    H._add("liner", bm, "lamp_inner", 0)
    # rim bead
    bm = bmesh.new(); bmesh.ops.create_circle(bm, segments=32, radius=1.2)
    bm.free()
    bpy.ops.mesh.primitive_torus_add(major_radius=1.2, minor_radius=0.05, major_segments=32, minor_segments=6, location=(0, 0, 0.75))
    rimob = bpy.context.active_object; rimob.data.materials.append(H.M("lamp_green")); H.parts.append(rimob)
    # bulb
    sphere("bulb", 0, 0, 1.15, 0.32, "glow", 1, 1, 1.25)
    # wire cage under the shade: 6 hoops + a ring
    for i in range(6):
        a = i / 6 * math.pi
        pts = [(math.cos(a) * 1.0 * math.sin(t / 8 * math.pi), math.sin(a) * 1.0 * math.sin(t / 8 * math.pi), 0.8 - 0.55 * math.sin(t / 8 * math.pi) ** 0.5 * 1.0) for t in range(9)]
        pts = [(math.cos(a) * 1.0 * (1 - 2 * t / 8), math.sin(a) * 1.0 * (1 - 2 * t / 8), 0.8 - 0.6 * math.sqrt(max(0.0, 1 - (1 - 2 * t / 8) ** 2))) for t in range(9)]
        for k in range(8):
            rod(f"wire{i}_{k}", pts[k], pts[k + 1], 0.025, "cage", 5)
    bpy.ops.mesh.primitive_torus_add(major_radius=0.75, minor_radius=0.025, major_segments=24, minor_segments=5, location=(0, 0, 0.42))
    o = bpy.context.active_object; o.data.materials.append(H.M("cage")); H.parts.append(o)
    S2.finish2("hb_pendant", tex=512)


@prop
def wallpack():
    """Exterior wall-pack light: a die-cast box with cooling fins, a slanted prismatic lens (glowing) and a
    wall plate. Back on y=+0.0 (mounts on a wall facing -Y), ~1.8 wide x 1.4 tall x 1.1 deep, bottom at z=0."""
    box("plate", -0.95, 0.95, 0.0, 0.1, 0.0, 1.4, "pack_grey", r=0.08, corners=("tl", "tr", "bl", "br"), axis="Y")
    box("body", -0.85, 0.85, -0.9, 0.0, 0.25, 1.3, "pack_grey", r=0.15, corners=("tf",), axis="X")
    for i in range(7):
        x = -0.6 + i * 0.2
        box(f"fin{i}", x - 0.03, x + 0.03, -0.75, -0.05, 1.3, 1.42, "pack_grey", bevel=0.01)
    # slanted lens face
    bm = bmesh.new()
    vs = [bm.verts.new(p) for p in ((-0.75, -0.95, 0.3), (0.75, -0.95, 0.3), (0.75, -0.55, 0.95), (-0.75, -0.55, 0.95))]
    bm.faces.new(vs)
    ret = bmesh.ops.extrude_face_region(bm, geom=list(bm.faces))
    for v in [e for e in ret["geom"] if isinstance(e, bmesh.types.BMVert)]:
        v.co += Vector((0, 0.06, -0.04))
    bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
    H._add("lens", bm, "glow", 0)
    # lens frame
    box("frameB", -0.82, 0.82, -1.0, -0.85, 0.22, 0.32, "pack_grey", bevel=0.02)
    box("frameT", -0.82, 0.82, -0.62, -0.48, 0.92, 1.02, "pack_grey", bevel=0.02)
    for s in (-1, 1):
        strut(f"frameS{s}", (s * 0.8, -0.95, 0.27), (s * 0.8, -0.55, 0.97), 0.08, "pack_grey", bevel=0.01)
    cyl("conduit", 0, -0.3, -0.6, 0.25, 0.09, "galv", 10)
    S2.finish2("hb_wallpack", tex=512)


# ------------------------------------------------------------ hub props (round 3) ---

# Scanned materials for the radio and the shift bell (owner 11-11: the Office procedure, scans then model). The texture
# pass is texstyle.py `brass` (ambientCG Metal048C) and `paint` (PaintedMetal012, chipped paint kept, tinted per use);
# wood is the oak scan. Needs TEXPIPE_WORK with those textures and cc0 sets.
_TEX = os.path.join(H.WORK, "textures")
_CC0 = os.path.join(H.WORK, "cc0")
_BRASS = (os.path.join(_TEX, "brass_scan_color.png"), os.path.join(_CC0, "Metal048C", "Metal048C_2K-JPG_Displacement.jpg"))
_PAINT = (os.path.join(_TEX, "paint_scan_color.png"),
          os.path.join(_CC0, "PaintedMetal012", "PaintedMetal012_2K-JPG_Displacement.jpg"))
H._SPEC.update({
    "brass_scan": lambda: H._scan("brass_scan", *_BRASS, studs=1.2, bump=0.08, rough=0.3, tint=(0.96, 0.74, 0.40)),
    "wood_radio": lambda: H._scan("wood_radio", *H._OAK, studs=3, bump=0.1, rough=0.4, tint=(0.85, 0.62, 0.42)),
    "paint_teal": lambda: H._scan("paint_teal", *_PAINT, studs=2.5, bump=0.3, rough=0.5, tint=(0.16, 0.50, 0.46)),
    "paint_cream": lambda: H._scan("paint_cream", *_PAINT, studs=1.5, bump=0.25, rough=0.5, tint=(1.0, 0.94, 0.80)),
    "paint_coral": lambda: H._scan("paint_coral", *_PAINT, studs=1.5, bump=0.25, rough=0.45, tint=(0.95, 0.36, 0.30)),
    "paint_ink": lambda: H._scan("paint_ink", *_PAINT, studs=1.5, bump=0.2, rough=0.55, tint=(0.14, 0.12, 0.16)),
})


def lathe(name, prof, mat, seg=24):
    """A surface of revolution about Z from (radius, z) pairs."""
    bm = bmesh.new()
    rings = []
    for (r, z) in prof:
        rings.append([bm.verts.new((math.cos(i / seg * math.tau) * r, math.sin(i / seg * math.tau) * r, z)) for i in range(seg)])
    for a, b in zip(rings, rings[1:]):
        for i in range(seg):
            bm.faces.new((a[i], a[(i + 1) % seg], b[(i + 1) % seg], b[i]))
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-4)
    bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
    return H._add(name, bm, mat, 0)


@prop
def mug():
    """A diner mug, 0.55 tall, with a handle and coffee inside (variant colour: white | grape | mint)."""
    v = VAR["v"] or "white"
    mat = {"white": "mug_white", "grape": "mug_grape", "mint": "mug_mint"}[v]
    lathe("cup", [(0.0, 0.0), (0.24, 0.0), (0.27, 0.04), (0.28, 0.5), (0.31, 0.55), (0.26, 0.55), (0.24, 0.12), (0.0, 0.12)], mat, 28)
    cyl("coffee", 0, 0, 0.38, 0.44, 0.245, "coffee", 24)
    bpy.ops.mesh.primitive_torus_add(major_radius=0.14, minor_radius=0.035, major_segments=16, minor_segments=8,
                                     location=(0.3, 0, 0.29), rotation=(math.pi / 2, 0, 0))
    h = bpy.context.active_object
    h.data.materials.append(H.M(mat))
    H.parts.append(h)
    S2.finish2(f"hb_mug_{v}", tex=256)


@prop
def parcel():
    """A taped cardboard shipping box with a label and a red sticker (a: 2x1.4x1.4, b: 1.4 cube, c: 2.4x1.6x1)."""
    v = VAR["v"] or "a"
    w, d, h = {"a": (2.0, 1.4, 1.4), "b": (1.4, 1.4, 1.4), "c": (2.4, 1.6, 1.0)}[v]
    box("body", -w / 2, w / 2, -d / 2, d / 2, 0, h, "cardboard", bevel=0.03)
    box("tapeTop", -0.12, 0.12, -d / 2 - 0.005, d / 2 + 0.005, h - 0.002, h + 0.008, "tape", bevel=0.0)
    for s in (-1, 1):
        box(f"tapeEnd{s}", -0.12, 0.12, s * d / 2 - 0.005 if s > 0 else -d / 2 - 0.005, s * d / 2 + 0.005 if s > 0 else -d / 2 + 0.005,
            h - 0.35, h, "tape", bevel=0.0)
    box("seam", -w / 2, w / 2, -0.008, 0.008, h - 0.001, h + 0.004, "lidplas", bevel=0.0)
    box("label", -w * 0.3, w * 0.05, -d / 2 - 0.01, -d / 2, h * 0.35, h * 0.75, "label", bevel=0.0)
    for k in range(3):
        box(f"barcode{k}", -w * 0.27 + k * 0.08, -w * 0.25 + k * 0.08, -d / 2 - 0.014, -d / 2 - 0.009, h * 0.42, h * 0.55, "lidplas", bevel=0.0)
    box("sticker", w / 2, w / 2 + 0.01, -d * 0.2, d * 0.2, h * 0.3, h * 0.55, "label_red", bevel=0.0)
    S2.finish2(f"hb_parcel_{v}", tex=512)


@prop
def chair():
    """A diner cafe chair: padded grape fabric seat and back on a steel frame, 3.2 tall, seat top at 1.77."""
    sh = 1.55
    box("seat", -0.95, 0.95, -0.95, 0.95, sh - 0.1, sh + 0.22, "seat_fabric", r=0.25, corners=("fl", "fr", "bl", "br"), bevel=0.08)
    box("back", -0.9, 0.9, 0.78, 0.98, sh + 0.55, sh + 1.6, "seat_fabric", r=0.25, corners=("tl", "tr"), axis="Y", bevel=0.06)
    for x in (-0.8, 0.8):
        for y in (-0.8, 0.8):
            rod(f"leg{x}{y}", (x * 1.05, y * 1.05, 0), (x, y, sh - 0.1), 0.05, "steel_dark", 10)
        rod(f"post{x}", (x, 0.86, sh - 0.1), (x, 0.88, sh + 1.2), 0.045, "steel_dark", 10)
    for y in (-0.85, 0.85):
        rod(f"rail{y}", (-0.86, y * 1.03, 0.45), (0.86, y * 1.03, 0.45), 0.03, "steel_dark", 8)
    S2.finish2("hb_chair", tex=512)


@prop
def espresso():
    """A chunky diner espresso machine, 2.6 wide x 1.8 deep x 2.3 tall: red enamel body, steel top tray with a rail,
    two group heads with handles, a steam wand, a pressure gauge with a glowing face, a cup on the drip tray."""
    box("body", -1.3, 1.3, -0.8, 0.9, 0.0, 1.9, "enamel_red", r=0.25, corners=("tl", "tr"), axis="Y", bevel=0.06)
    box("top", -1.35, 1.35, -0.85, 0.95, 1.9, 2.05, "steel_mid", bevel=0.03)
    for x in (-0.9, 0.9):
        rod(f"rail{x}", (x, -0.8, 2.25), (x, 0.9, 2.25), 0.04, "chrome", 8)
    rod("railF", (-0.9, -0.8, 2.25), (0.9, -0.8, 2.25), 0.04, "chrome", 8)
    box("tray", -1.15, 1.15, -1.25, -0.75, 0.25, 0.35, "steel_mid", bevel=0.02)
    box("grate", -1.05, 1.05, -1.2, -0.8, 0.35, 0.37, "steel_dark", bevel=0.0)
    for x in (-0.55, 0.55):
        cyl(f"group{x}", x, -0.95, 1.05, 1.35, 0.22, "chrome", 16)
        rod(f"handle{x}", (x, -1.0, 1.0), (x, -1.65, 0.95), 0.06, "steel_dark", 10)
    rod("wand", (1.15, -0.85, 1.4), (1.3, -1.1, 0.7), 0.035, "chrome", 8)
    cyl("gauge", 0, 1.5, -0.86, -0.8, 0.26, "chrome", 20, axis="Y")
    cyl("gaugeFace", 0, 1.5, -0.88, -0.86, 0.2, "glow", 20, axis="Y")
    box("badge", -0.45, 0.45, -0.82, -0.79, 0.55, 0.8, "brass", bevel=0.01)
    cyl("cupE", 0.55, -1.0, 0.37, 0.62, 0.15, "mug_white", 16)
    S2.finish2("hb_espresso", tex=512)


@prop
def register():
    """An old cash register, 1.6 wide: brass body, a key bank, a number window and a drawer."""
    box("drawer", -0.8, 0.8, -0.7, 0.6, 0.0, 0.35, "steel_dark", bevel=0.03)
    box("body", -0.75, 0.75, -0.35, 0.6, 0.35, 1.05, "brass", r=0.12, corners=("tl", "tr"), axis="Y", bevel=0.03)
    box("keybank", -0.72, 0.72, -0.7, -0.35, 0.35, 0.6, "steel_dark", bevel=0.02)
    for row in range(3):
        for col in range(5):
            x = -0.55 + col * 0.27
            y = -0.62 + row * 0.1
            z = 0.6 + row * 0.07
            cyl(f"key{row}{col}", x, y, z, z + 0.05, 0.05, "keycap", 10)
    box("window", -0.4, 0.4, -0.1, 0.25, 1.05, 1.35, "steel_dark", r=0.08, corners=("tl", "tr"), axis="Y", bevel=0.02)
    box("display", -0.33, 0.33, -0.12, -0.1, 1.1, 1.3, "screen_green", bevel=0.0)
    S2.finish2("hb_register", tex=512)


@prop
def shelving():
    """Steel supply shelving 6 wide x 1.8 deep x 8 tall (4 shelves) stocked with labelled boxes, tins, spray bottles
    and rolled towels."""
    rng = random.Random(21)
    W, D, Hh = 6.0, 1.8, 8.0
    for x in (-W / 2, W / 2):
        for y in (-D / 2, D / 2):
            box(f"upright{x}{y}", x - 0.08, x + 0.08, y - 0.08, y + 0.08, 0, Hh, "steel_dark", bevel=0.02)
    levels = [0.3, 2.3, 4.3, 6.3]
    for i, z in enumerate(levels):
        box(f"shelf{i}", -W / 2, W / 2, -D / 2, D / 2, z, z + 0.12, "steel_mid", bevel=0.02)
        box(f"lip{i}", -W / 2, W / 2, -D / 2 - 0.04, -D / 2, z + 0.06, z + 0.22, "steel_mid", bevel=0.01)
        x = -W / 2 + 0.25
        while x < W / 2 - 0.6:
            kind = rng.choice(["box", "box", "tins", "bottles", "towels"])
            top = z + 0.12
            if kind == "box":
                w = rng.uniform(0.8, 1.3)
                h = rng.uniform(0.7, 1.4)
                box(f"b{i}_{x:.2f}", x, x + w, -D / 2 + 0.15, D / 2 - 0.2, top, top + h, "cardboard", bevel=0.02)
                box(f"bt{i}_{x:.2f}", x + w * 0.4, x + w * 0.6, -D / 2 + 0.14, D / 2 - 0.19, top + h - 0.01, top + h + 0.005, "tape", bevel=0.0)
                box(f"bl{i}_{x:.2f}", x + 0.1, x + w * 0.55, -D / 2 + 0.135, -D / 2 + 0.15, top + h * 0.3, top + h * 0.65, "label", bevel=0.0)
            elif kind == "tins":
                w = 1.0
                for k in range(3):
                    cyl(f"t{i}_{x:.2f}_{k}", x + 0.17 + k * 0.33, -0.3, top, top + 0.55, 0.15, "tin_a" if k % 2 else "tin_b", 14)
            elif kind == "bottles":
                w = 1.0
                for k in range(3):
                    bx = x + 0.17 + k * 0.33
                    cyl(f"s{i}_{x:.2f}_{k}", bx, -0.2, top, top + 0.75, 0.13, "bottle_a" if k % 2 else "bottle_b", 12)
                    box(f"sh{i}_{x:.2f}_{k}", bx - 0.06, bx + 0.06, -0.38, -0.1, top + 0.75, top + 0.95, "lidplas", bevel=0.01)
            else:
                w = 1.1
                for k in range(2):
                    cyl(f"w{i}_{x:.2f}_{k}", -0.4 + k * 0.6, top + 0.25, x, x + w - 0.05, 0.25, "towel", 14, axis="X")
            x += w + rng.uniform(0.08, 0.2)
    S2.finish2("hb_shelving", tex=1024)


@prop
def radio():
    """A chunky 1950s tabletop radio, 1.9 wide x 0.95 deep x 1.35 tall: an oak cabinet rounded over the top, a cream
    painted front, brass grille slats over a dark speaker cloth on the left, a round brass-rimmed dial with a coral
    needle and two brass knobs on the right, a brass carry handle and a telescoping antenna. Front = -Y."""
    w, d, h = 1.9, 0.95, 1.35
    box("cabinet", -w / 2, w / 2, -d / 2, d / 2, 0.06, h, "wood_radio", r=0.32, corners=("tl", "tr"), axis="Y", bevel=0.04)
    box("front", -w / 2 + 0.08, w / 2 - 0.08, -d / 2 - 0.02, -d / 2 + 0.02, 0.16, h - 0.16, "paint_cream",
        r=0.24, corners=("tl", "tr"), axis="Y", bevel=0.015)
    # the speaker: dark cloth panel with brass slats across it
    gx0, gx1 = -w / 2 + 0.18, 0.12
    box("cloth", gx0, gx1, -d / 2 - 0.03, -d / 2 - 0.01, 0.28, h - 0.3, "paint_ink", bevel=0.01)
    for k in range(6):
        z = 0.34 + k * (h - 0.68) / 5
        box(f"slat{k}", gx0 - 0.02, gx1 + 0.02, -d / 2 - 0.07, -d / 2 - 0.02, z - 0.03, z + 0.03, "brass_scan", bevel=0.01)
    # the dial: brass bezel, cream face, coral needle
    dx, dz = 0.52, h * 0.62
    cyl("bezel", dx, dz, -d / 2 - 0.08, -d / 2 - 0.01, 0.26, "brass_scan", 28, axis="Y")
    cyl("dialFace", dx, dz, -d / 2 - 0.09, -d / 2 - 0.08, 0.21, "paint_cream", 28, axis="Y")
    box("needle", dx - 0.012, dx + 0.012, -d / 2 - 0.1, -d / 2 - 0.09, dz - 0.02, dz + 0.17, "paint_coral", bevel=0.0)
    for k in range(9):
        a = math.radians(-60 + k * 15)
        cx, cz = dx + math.sin(a) * 0.17, dz + math.cos(a) * 0.17
        box(f"tick{k}", cx - 0.006, cx + 0.006, -d / 2 - 0.1, -d / 2 - 0.09, cz - 0.02, cz + 0.02, "paint_ink", bevel=0.0)
    for k, x in enumerate((dx - 0.17, dx + 0.17)):
        cyl(f"knob{k}", x, 0.32, -d / 2 - 0.14, -d / 2 - 0.01, 0.1, "brass_scan", 20, axis="Y")
        cyl(f"knobCap{k}", x, 0.32, -d / 2 - 0.15, -d / 2 - 0.14, 0.07, "paint_cream", 20, axis="Y")
    # carry handle and antenna
    for x in (-0.45, 0.45):
        rod(f"handlePost{x}", (x, 0, h - 0.06), (x, 0, h + 0.2), 0.035, "brass_scan", 10)
    rod("handleBar", (-0.47, 0, h + 0.2), (0.47, 0, h + 0.2), 0.04, "brass_scan", 10)
    rod("antenna", (0.75, 0.25, h - 0.1), (1.05, 0.35, h + 0.9), 0.018, "brass_scan", 8)
    sphere("antennaTip", 1.05, 0.35, h + 0.92, 0.04, "brass_scan")
    for x in (-w / 2 + 0.15, w / 2 - 0.15):
        for y in (-d / 2 + 0.15, d / 2 - 0.15):
            cyl(f"foot{x}{y}", x, y, 0.0, 0.07, 0.07, "paint_ink", 12)
    S2.finish2("hb_radio_v2", tex=1024)


@prop
def bellpost():
    """The shift bell's post (static part), 4.4 tall: a teal painted steel post on a round base plate with bolts, a
    brass collar, and an arm out to the front (-Y) ending in a yoke the bell hangs from (the bell is `bell`, which
    swings about the yoke pin at (0, -0.85, 4.1))."""
    cyl("plate", 0, 0, 0.0, 0.1, 0.62, "paint_teal", 32)
    for k in range(4):
        a = k * math.pi / 2 + math.pi / 4
        cyl(f"bolt{k}", math.cos(a) * 0.45, math.sin(a) * 0.45, 0.1, 0.16, 0.05, "brass_scan", 10)
    box("post", -0.14, 0.14, -0.14, 0.14, 0.1, 4.25, "paint_teal", bevel=0.03)
    cyl("collar", 0, 0, 3.75, 3.95, 0.2, "brass_scan", 20)
    cyl("cap", 0, 0, 4.25, 4.35, 0.2, "brass_scan", 20)
    box("arm", -0.07, 0.07, -0.95, 0.0, 4.02, 4.16, "paint_teal", bevel=0.02)
    for x in (-0.22, 0.22):
        box(f"yoke{x}", x - 0.03, x + 0.03, -0.92, -0.78, 3.95, 4.16, "brass_scan", bevel=0.01)
    S2.finish2("hb_bellpost_v2", tex=1024)


@prop
def bell():
    """The shift bell itself (the swinging part): a classic brass bell, 0.8 across the mouth, mouth down, with a
    crown loop, the pin through it, and a dark clapper inside. Its pivot (the pin) is at the origin; the bell hangs
    below it."""
    prof = [(0.0, -0.08), (0.08, -0.08), (0.14, -0.12), (0.2, -0.2), (0.24, -0.32), (0.29, -0.48), (0.36, -0.62),
            (0.42, -0.70), (0.40, -0.73), (0.33, -0.70), (0.27, -0.62), (0.21, -0.48), (0.17, -0.32), (0.13, -0.2),
            (0.07, -0.13), (0.0, -0.13)]
    lathe("bellBody", prof, "brass_scan", 36)
    cyl("crown", 0, 0, -0.1, 0.0, 0.07, "brass_scan", 16)
    cylx("pin", -0.25, 0.25, 0, 0, 0.03, "brass_scan", 10)
    rod("clapperRod", (0, 0, -0.12), (0, 0, -0.6), 0.02, "paint_ink", 8)
    sphere("clapper", 0, 0, -0.62, 0.07, "paint_ink")
    S2.finish2("hb_bell_v2", tex=1024)


# ------------------------------------------------------- hub props (round 5, 11-12) ---

H._SPEC.update({
    # pumpkin leaves: deep green, a little waxy; the veins a paler green
    "pk_leaf": lambda: _paint("pk_leaf", (0.11, 0.27, 0.07), 0.6, 0.35, scale=22),
    "pk_vein": lambda: _paint("pk_vein", (0.42, 0.56, 0.20), 0.6, 0.2, scale=30),
    "pk_vine": lambda: _paint("pk_vine", (0.20, 0.33, 0.10), 0.7, 0.4, scale=25),
    # the vending machine: grape painted steel (the game's palette), mint and gold trim, a cream lit back
    "paint_grape": lambda: _paint("paint_grape", (0.30, 0.16, 0.52), 0.4, 0.15, scale=18),
    "paint_mint": lambda: _paint("paint_mint", (0.18, 0.72, 0.52), 0.35, 0.1, scale=18),
    "paint_gold": lambda: _paint("paint_gold", (0.95, 0.66, 0.15), 0.3, 0.2, scale=18),
    # snacks: glossy printed wrappers and cans in the game's colours
    "wrap_coral": lambda: _paint("wrap_coral", (0.93, 0.28, 0.33), 0.25, 0.05, scale=12),
    "wrap_grape": lambda: _paint("wrap_grape", (0.45, 0.24, 0.85), 0.25, 0.05, scale=12),
    "wrap_mint": lambda: _paint("wrap_mint", (0.20, 0.82, 0.60), 0.25, 0.05, scale=12),
    "wrap_gold": lambda: _paint("wrap_gold", (1.0, 0.74, 0.18), 0.25, 0.05, scale=12),
    "wrap_sky": lambda: _paint("wrap_sky", (0.30, 0.72, 0.98), 0.25, 0.05, scale=12),
    "wrap_cream": lambda: _paint("wrap_cream", (0.98, 0.94, 0.84), 0.35, 0.05, scale=12),
    "wrap_ink": lambda: _paint("wrap_ink", (0.12, 0.07, 0.22), 0.4, 0.05, scale=12),
    "can_metal": lambda: _paint("can_metal", (0.72, 0.73, 0.76), 0.2, 0.05, scale=14),
    "soda_glass": lambda: _paint("soda_glass", (0.30, 0.55, 0.20), 0.08, 0.05, scale=10),
})


def _pkleaf(name, size, seed, cup=0.12):
    """A pumpkin leaf about `size` across lying in XY, its stalk end at the origin pointing -Y: broad, roughly round,
    five shallow rounded lobes with a fine toothed edge, a deep notch where the stalk joins, cupped and wavy, with
    raised pale veins from the stalk to each lobe. Returns (leaf, veins)."""
    rng = random.Random(seed)
    centre = Vector((0, 0.5 * size, 0))
    n = 90
    bm = bmesh.new()
    c = bm.verts.new(centre)
    ring = []
    for i in range(n):
        a = -math.pi + (i + 0.5) / n * math.tau  # a = 0 points +Y (the leaf's tip), +-pi the stalk notch
        lobes = 0.13 * math.cos(5 * a)
        teeth = 0.012 * math.cos(46 * a)
        notch = 0.55 * math.exp(-((abs(a) - math.pi) ** 2) / 0.05)
        rr = size * 0.5 * (0.86 + lobes + teeth - notch)
        ring.append(bm.verts.new(centre + Vector((math.sin(a) * rr, math.cos(a) * rr, 0))))
    for i in range(n):
        bm.faces.new((c, ring[i], ring[(i + 1) % n]))
    bmesh.ops.subdivide_edges(bm, edges=[e for e in bm.edges if c in e.verts], cuts=3, use_grid_fill=False)

    def shape(co):
        d = co - centre
        rad = d.length / (0.5 * size)
        ang = math.atan2(d.x, d.y)
        z = cup * size * rad * rad + 0.015 * size * math.sin(5 * ang) * rad
        return Vector((co.x, co.y, co.z + z))

    for v in bm.verts:
        v.co = shape(v.co)
    ret = bmesh.ops.extrude_face_region(bm, geom=list(bm.faces))
    for v in [e for e in ret["geom"] if isinstance(e, bmesh.types.BMVert)]:
        v.co.z -= 0.02
    bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
    leaf = H._add(name, bm, "pk_leaf", 0)
    vb = bmesh.new()
    base = centre + Vector((0, -0.42 * size, 0))
    for k in range(5):
        a = (k - 2) * math.radians(62)
        tip = centre + Vector((math.sin(a), math.cos(a), 0)) * size * 0.5 * 0.85
        d = tip - base
        perp = Vector((-d.y, d.x, 0)).normalized() * 0.018 * size
        prev = None
        for s_ in range(7):
            q = base + d * (s_ / 6)
            w = 1.0 - 0.7 * (s_ / 6)
            va = vb.verts.new(shape(q + perp * w) + Vector((0, 0, 0.012)))
            vbb = vb.verts.new(shape(q - perp * w) + Vector((0, 0, 0.012)))
            if prev:
                vb.faces.new((prev[0], prev[1], vbb, va))
            prev = (va, vbb)
    veins = H._add(name + "_veins", vb, "pk_vein", 0)
    return leaf, veins


@prop
def pumpkinleaf():
    """A pumpkin's leaves as their own prop (owner 11-12): two broad pumpkin leaves on short stalks off the stem, with a
    corkscrew tendril, shaped over a round pumpkin's shoulder so they sit on any pumpkin. The pivot (origin) is where
    the stalks leave the stem: place it at a pumpkin's stem base (scale with the pumpkin). Variant a | b."""
    v = VAR["v"] or "a"
    rng = random.Random(5 if v == "a" else 19)
    # a stand-in round pumpkin to drape onto (removed before export), its top at the origin
    r, hk = PUMP["round"][0], PUMP["round"][1]
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=48, v_segments=24, radius=1.0)
    for vt in bm.verts:
        x, y, z = vt.co
        flat = 1 - 0.28 * (abs(z) ** 2.2)
        vt.co = Vector((x * r, y * r, (z * flat * hk) * r))
    top = max(vv.co.z for vv in bm.verts)
    bmesh.ops.translate(bm, verts=bm.verts, vec=(0, 0, -top + 0.02))
    form = H._add("form", bm, "pumpkin", 0)
    # (leaf size, turn round the stem, how far out its stalk reaches) as shares of the pumpkin's radius: the leaves
    # lie on the shoulder, inside the pumpkin's outline, so the drape seats them on the skin.
    plan = [(0.72, -30, 0.12), (0.55, 115, 0.1)] if v == "a" else [(0.78, 160, 0.12), (0.5, 40, 0.1)]
    for k, (size, turn, out) in enumerate(plan):
        leaf, veins = _pkleaf(f"pkleaf{k}", size * r, seed=rng.randint(0, 999))
        # off its stalk, leaned a little, swung round the stem
        for ob in (leaf, veins):
            ob.data.transform(Matrix.Rotation(math.radians(rng.uniform(-8, 8)), 4, "Y"))
            ob.data.transform(Matrix.Translation((0, out * r, 0)))
            ob.data.transform(Matrix.Rotation(math.radians(turn), 4, "Z"))
        _drape(form, (leaf, veins), 0.03)
        notch = Vector((0, out * r, 0))
        notch.rotate(Matrix.Rotation(math.radians(turn), 3, "Z"))
        rod(f"stalk{k}", (0, 0, 0.12), (notch.x * 0.92, notch.y * 0.92, 0.0), 0.035, "pk_vine", 8)
    # the corkscrew tendril
    turn = math.radians(rng.uniform(60, 300))
    pts = []
    for i in range(36):
        t = i / 35
        ang = t * math.tau * 3
        rad = 0.09 * (1 - 0.5 * t)
        base = Vector((math.cos(turn) * 0.35 * t, math.sin(turn) * 0.35 * t, 0.15 + 0.45 * t))
        pts.append(base + Vector((math.cos(ang) * rad, math.sin(ang) * rad, 0)))
    for i in range(len(pts) - 1):
        rod(f"tendril{i}", tuple(pts[i]), tuple(pts[i + 1]), 0.018, "pk_vine", 6)
    if form in H.parts:
        H.parts.remove(form)
    bpy.data.objects.remove(form, do_unlink=True)
    S2.finish2(f"hb_pumpkinleaf_{v}", tex=512)


@prop
def vending():
    """A chunky snack machine, 3.6 wide x 3.12 deep x 7.4 tall (the hub machine's size): grape painted steel with mint
    and gold trim; on the left a window (2 x 4.7; the glass is its own part in the hub) onto four shelves with spiral
    coils and a lit cream back; on the right a panel of lit buttons, a coin slot and a card reader; a pickup tray with
    a flap across the bottom; a plain mint header (no words, no brand, no sparkle). Stocked with the `snack` props
    in the hub. Front = -Y."""
    W, D, Hh = 3.6, 3.12, 7.4
    fy = -D / 2
    x0, x1, z0, z1 = -1.5, 0.5, 2.05, 6.75
    back = 0.55
    box("left", -W / 2, x0, fy, D / 2, 0.0, Hh, "paint_grape", bevel=0.04)
    box("right", x1, W / 2, fy, D / 2, 0.0, Hh, "paint_grape", bevel=0.04)
    box("base", x0, x1, fy, D / 2, 0.0, z0, "paint_grape", bevel=0.03)
    box("head", x0, x1, fy, D / 2, z1, Hh, "paint_grape", bevel=0.03)
    box("backWall", x0, x1, back, D / 2, z0, z1, "paint_grape", bevel=0.0)
    box("backLit", x0 + 0.05, x1 - 0.05, back - 0.02, back, z0 + 0.05, z1 - 0.05, "paint_cream", bevel=0.0)
    t = 0.09
    box("frameL", x0 - t, x0, fy - 0.04, fy + 0.05, z0 - t, z1 + t, "paint_mint", bevel=0.02)
    box("frameR", x1, x1 + t, fy - 0.04, fy + 0.05, z0 - t, z1 + t, "paint_mint", bevel=0.02)
    box("frameB", x0, x1, fy - 0.04, fy + 0.05, z0 - t, z0, "paint_mint", bevel=0.02)
    box("frameT", x0, x1, fy - 0.04, fy + 0.05, z1, z1 + t, "paint_mint", bevel=0.02)
    # The shelves stand SET back from the glass, leaving a drop lane in front of them: a vended snack is nudged off
    # its coil into the lane and falls past the shelves below to the tray (DepotIdleRules.vend).
    sf = fy + 0.5
    for i in range(4):
        z = z0 + 0.12 + i * 1.15
        box(f"shelf{i}", x0, x1, sf, back, z - 0.05, z, "steel_mid", bevel=0.01)
        box(f"shelfLip{i}", x0, x1, sf - 0.03, sf + 0.03, z - 0.05, z + 0.08, "paint_gold", bevel=0.01)
        for k in range(4):
            cx = x0 + 0.25 + k * 0.5
            pts = []
            for j in range(31):
                tt = j / 30
                ang = tt * math.tau * 3.5
                pts.append((cx + math.cos(ang) * 0.17, sf + 0.1 + tt * (back - sf - 0.2), z + 0.17 + math.sin(ang) * 0.17))
            for j in range(len(pts) - 1):
                rod(f"coil{i}_{k}_{j}", pts[j], pts[j + 1], 0.022, "chrome", 6)
    px0, px1 = x1 + 0.2, W / 2 - 0.2
    box("panel", px0, px1, fy - 0.03, fy + 0.02, 3.2, 6.6, "paint_ink", bevel=0.01)
    for row in range(4):
        for col in range(2):
            bx = px0 + 0.22 + col * 0.42
            bz = 5.95 - row * 0.42
            box(f"btn{row}{col}", bx - 0.13, bx + 0.13, fy - 0.08, fy - 0.03, bz - 0.13, bz + 0.13,
                "glow" if (row, col) == (0, 0) else "paint_cream", bevel=0.02)
    box("coinPlate", px0 + 0.1, px1 - 0.1, fy - 0.07, fy - 0.03, 3.95, 4.35, "brass_scan", bevel=0.01)
    box("coinSlot", px0 + 0.38, px1 - 0.38, fy - 0.08, fy - 0.07, 4.05, 4.25, "paint_ink", bevel=0.0)
    box("cardReader", px0 + 0.15, px1 - 0.15, fy - 0.1, fy - 0.03, 3.35, 3.75, "steel_dark", bevel=0.02)
    box("cardLight", px0 + 0.3, px1 - 0.3, fy - 0.11, fy - 0.1, 3.62, 3.68, "glow", bevel=0.0)
    box("trayFrame", x0 - 0.05, x1 + 0.05, fy - 0.05, fy + 0.02, 0.45, 1.65, "paint_mint", bevel=0.02)
    box("trayHole", x0 + 0.1, x1 - 0.1, fy - 0.06, fy - 0.04, 0.6, 1.5, "paint_ink", bevel=0.0)
    box("flap", x0 + 0.12, x1 - 0.12, fy - 0.1, fy - 0.06, 0.95, 1.48, "steel_dark", bevel=0.02)
    box("flapHandle", x0 + 0.6, x1 - 0.6, fy - 0.14, fy - 0.1, 1.3, 1.4, "chrome", bevel=0.01)
    # A plain header (owner 11-16: the gold 4-point sparkle that sat in its middle read as a diamond; removed).
    box("header", -W / 2 + 0.15, W / 2 - 0.15, fy - 0.06, fy + 0.02, 6.85, 7.25, "paint_mint", bevel=0.02)
    for x in (-W / 2 + 0.25, W / 2 - 0.25):
        for y in (fy + 0.25, D / 2 - 0.25):
            cyl(f"foot{x}{y}", x, y, -0.06, 0.0, 0.12, "steel_dark", 10)
    S2.finish2("hb_vending", tex=1024)


@prop
def snack():
    """A vending machine snack, sized for a 0.5-wide coil slot (front = -Y, stands on z=0): can (a soda can, 0.62
    tall), bottle (a curvy soda bottle, 0.9 tall), chips (a puffy crimped chip bag, 0.78 tall), bar (a wrapped candy
    bar standing up, 0.72 tall)."""
    v = VAR["v"] or "can"
    if v == "can":
        lathe("can", [(0.0, 0.0), (0.13, 0.0), (0.16, 0.04), (0.165, 0.08), (0.165, 0.54), (0.14, 0.6), (0.13, 0.62), (0.0, 0.62)], "wrap_mint", 28)
        cyl("band", 0, 0, 0.22, 0.4, 0.168, "wrap_cream", 28)
        cyl("stripe", 0, 0, 0.29, 0.33, 0.17, "wrap_coral", 28)
        cyl("lid", 0, 0, 0.6, 0.625, 0.125, "can_metal", 24)
        box("tab", -0.04, 0.04, -0.08, 0.02, 0.625, 0.64, "can_metal", bevel=0.005)
        S2.finish2("hb_snack_can", tex=256)
    elif v == "bottle":
        prof = [(0.0, 0.0), (0.13, 0.0), (0.15, 0.04), (0.15, 0.2), (0.13, 0.27), (0.15, 0.36), (0.15, 0.52), (0.11, 0.66),
                (0.055, 0.76), (0.05, 0.82), (0.0, 0.82)]
        lathe("bottle", prof, "soda_glass", 28)
        cyl("label", 0, 0, 0.36, 0.52, 0.153, "wrap_gold", 28)
        cyl("labelStripe", 0, 0, 0.42, 0.46, 0.155, "wrap_coral", 28)
        cyl("cap", 0, 0, 0.8, 0.9, 0.062, "wrap_coral", 16)
        S2.finish2("hb_snack_bottle", tex=256)
    elif v == "chips":
        w, d, h = 0.44, 0.34, 0.78
        # a squashed sphere, pinched flat into crimped seams at the top and bottom
        bm = bmesh.new()
        bmesh.ops.create_uvsphere(bm, u_segments=24, v_segments=16, radius=1.0)
        for vt in bm.verts:
            x, y, z = vt.co
            pinch = 1.0 - min(1.0, abs(z) ** 6)
            vt.co = Vector((x * w / 2 * (0.75 + 0.25 * pinch), y * d / 2 * pinch, (z + 1) * h / 2))
        H._add("bag", bm, "wrap_gold", 0)
        for k, (za, zb) in enumerate(((0.0, 0.07), (h - 0.07, h))):
            box(f"crimp{k}", -w / 2 - 0.01, w / 2 + 0.01, -0.03, 0.03, za, zb, "wrap_coral", bevel=0.005)
        box("window", -0.12, 0.12, -d / 2 - 0.05, -d / 2 - 0.035, 0.28, 0.5, "wrap_cream", bevel=0.0)
        S2.finish2("hb_snack_chips", tex=256)
    else:  # bar
        w, d, h = 0.36, 0.1, 0.72
        box("wrapper", -w / 2, w / 2, -d / 2, d / 2, 0.04, h - 0.04, "wrap_grape", bevel=0.02)
        for k, (za, zb) in enumerate(((0.0, 0.05), (h - 0.05, h))):
            box(f"end{k}", -w / 2 + 0.02, w / 2 - 0.02, -d / 2 + 0.03, d / 2 - 0.03, za, zb, "wrap_grape", bevel=0.005)
        box("stripe", -w / 2 - 0.002, w / 2 + 0.002, -d / 2 - 0.004, d / 2 + 0.004, h * 0.42, h * 0.58, "wrap_gold", bevel=0.0)
        S2.finish2("hb_snack_bar", tex=256)


# ------------------------------------------------- Harvest Hours event (11-17) ---
# The Thanksgiving event's two hub props (owner A8/A9 11-17: "yes to banner and scarecrow!", from the concept in
# characters/concepts/event/harvest-props-2026-11-16/props.png). Placed by the owner, tagged EventProp, Event = harvest.
# Cloth, felt, burlap and patch are the Fabric036 scan; the pole and post are the oak scan. The banner's words are
# Luckiest Guy (the game's title font) turned into raised felt letters, so they are geometry, not a printed decal.
_FONT = os.environ.get("HUB_FONT", "E:/Projects/peekabu-game-systems/characters/identity/lanyards/fonts/LuckiestGuy-Regular.ttf")


def _plaid(name, base, band, scale=1.1, studs=1.2):
    """Shirt flannel: `band` stripes crossing in object X and Z over `base` (darker where they cross), on the fabric
    scan's weave bump."""
    m, N, L, b = H._new(name)
    tc = N.new("ShaderNodeTexCoord")
    sep = N.new("ShaderNodeSeparateXYZ"); L.new(tc.outputs["Object"], sep.inputs["Vector"])

    def stripes(out):
        mul = N.new("ShaderNodeMath"); mul.operation = "MULTIPLY"; mul.inputs[1].default_value = math.pi / scale
        L.new(out, mul.inputs[0])
        sn = N.new("ShaderNodeMath"); sn.operation = "SINE"; L.new(mul.outputs[0], sn.inputs[0])
        ab = N.new("ShaderNodeMath"); ab.operation = "ABSOLUTE"; L.new(sn.outputs[0], ab.inputs[0])
        mr = N.new("ShaderNodeMapRange"); mr.inputs["From Min"].default_value = 0.62; mr.inputs["From Max"].default_value = 0.72
        L.new(ab.outputs[0], mr.inputs["Value"])
        return mr.outputs["Result"]
    sx, sz = stripes(sep.outputs["X"]), stripes(sep.outputs["Z"])
    add = N.new("ShaderNodeMath"); add.operation = "ADD"; L.new(sx, add.inputs[0]); L.new(sz, add.inputs[1])
    mn = N.new("ShaderNodeMath"); mn.operation = "MINIMUM"; mn.inputs[1].default_value = 1.0
    L.new(add.outputs[0], mn.inputs[0])
    m1 = N.new("ShaderNodeMixRGB"); m1.inputs[1].default_value = (*base, 1); m1.inputs[2].default_value = (*band, 1)
    L.new(mn.outputs[0], m1.inputs["Fac"])
    both = N.new("ShaderNodeMath"); both.operation = "MULTIPLY"; L.new(sx, both.inputs[0]); L.new(sz, both.inputs[1])
    m2 = N.new("ShaderNodeMixRGB"); m2.blend_type = "MULTIPLY"; m2.inputs[2].default_value = (0.55, 0.5, 0.5, 1)
    L.new(both.outputs[0], m2.inputs["Fac"]); L.new(m1.outputs["Color"], m2.inputs[1])
    mp = N.new("ShaderNodeMapping"); k = 1.0 / studs; mp.inputs["Scale"].default_value = (k, k, k)
    L.new(tc.outputs["Object"], mp.inputs["Vector"])
    # the weave: the fabric scan's own colour multiplied under the plaid (as the burlap head), not flat maths colour
    sc = N.new("ShaderNodeTexImage"); sc.image = H._img(H._FABN[0]); sc.projection = "BOX"; sc.projection_blend = 0.15
    L.new(mp.outputs["Vector"], sc.inputs["Vector"])
    m3 = N.new("ShaderNodeMixRGB"); m3.blend_type = "MULTIPLY"; m3.inputs["Fac"].default_value = 1.0
    L.new(m2.outputs["Color"], m3.inputs[1]); L.new(sc.outputs["Color"], m3.inputs[2])
    L.new(m3.outputs["Color"], b.inputs["Base Color"])
    hi = N.new("ShaderNodeTexImage"); hi.image = H._img(H._FABN[1], False); hi.projection = "BOX"; hi.projection_blend = 0.15
    L.new(mp.outputs["Vector"], hi.inputs["Vector"])
    bp = N.new("ShaderNodeBump"); bp.inputs["Strength"].default_value = 0.7; bp.inputs["Distance"].default_value = 0.02
    L.new(hi.outputs["Color"], bp.inputs["Height"]); L.new(bp.outputs["Normal"], b.inputs["Normal"])
    b.inputs["Roughness"].default_value = 0.85
    return m


H._SPEC.update({
    "cloth_or": lambda: H._scan("cloth_or", *H._FABN, studs=2, bump=0.35, rough=0.85, tint=(1.0, 0.30, 0.02)),
    "cloth_rust": lambda: H._scan("cloth_rust", *H._FABN, studs=2, bump=0.35, rough=0.85, tint=(0.50, 0.10, 0.04)),
    "felt_cream": lambda: H._scan("felt_cream", *H._FABN, studs=1, bump=0.2, rough=0.9, tint=(1.0, 0.86, 0.58)),
    "pole_wood": lambda: H._scan("pole_wood", *H._OAK, studs=3, bump=0.25, rough=0.5, tint=(0.80, 0.50, 0.28)),
    "pole_wood_v": lambda: H._scan("pole_wood_v", *H._OAK, studs=3, bump=0.25, rough=0.5, tint=(0.70, 0.42, 0.24), along="Z"),
    "pole_band": lambda: _paint("pole_band", (0.32, 0.16, 0.07), 0.6, 0.3, scale=20),
    "rope": lambda: _paint("rope", (0.72, 0.58, 0.36), 0.9, 0.6, scale=45),
    "acorn_cap": lambda: _paint("acorn_cap", (0.28, 0.15, 0.06), 0.85, 0.9, scale=40),
    "acorn_nut": lambda: _paint("acorn_nut", (0.70, 0.43, 0.13), 0.55, 0.1, scale=10),
    "burlap": lambda: H._scan("burlap", *H._FABN, studs=0.8, bump=0.7, rough=0.9, tint=(0.95, 0.74, 0.45)),
    "patch": lambda: H._scan("patch", *H._FABN, studs=0.8, bump=0.5, rough=0.9, tint=(0.92, 0.76, 0.48)),
    "straw": lambda: _paint("straw", (0.86, 0.63, 0.16), 0.7, 0.4, scale=30),
    "straw_dk": lambda: _paint("straw_dk", (0.64, 0.44, 0.10), 0.75, 0.4, scale=30),
    "straw_hat": lambda: H._weave("straw_hat", (0.56, 0.37, 0.09), (0.90, 0.68, 0.24), 70),
    "hat_band": lambda: _paint("hat_band", (0.52, 0.08, 0.05), 0.6, 0.2, scale=20),
    "plaid": lambda: _plaid("plaid", (1.15, 0.45, 0.07), (0.55, 0.12, 0.05), scale=0.9, studs=0.8),
    "button_br": lambda: _paint("button_br", (0.30, 0.16, 0.07), 0.4, 0.05, scale=10),
    "button_blk": lambda: _paint("button_blk", (0.035, 0.03, 0.025), 0.35, 0.05, scale=10),
    "stitch": lambda: _paint("stitch", (0.20, 0.09, 0.04), 0.8, 0.2, scale=30),
    "corn_leaf": lambda: _paint("corn_leaf", (0.66, 0.56, 0.13), 0.6, 0.3, scale=18),
    "corn_leaf2": lambda: _paint("corn_leaf2", (0.46, 0.48, 0.10), 0.6, 0.3, scale=18),
    "corn_cob": lambda: _paint("corn_cob", (0.95, 0.68, 0.06), 0.35, 0.1, scale=12),
    "dirt": lambda: _paint("dirt", (0.15, 0.085, 0.045), 0.95, 0.9, scale=12),
})


def _blade(name, p0, p1, p2, w, mat, n=8, up=(0, 0, 1), tip=0.0, thick=0.03):
    """A tapered strip (a straw, a corn leaf, a husk) along the quadratic curve p0 -> p2 (pulled toward p1), `w` wide at
    the base narrowing to `tip` x w, given a little thickness so its back is not culled."""
    p0, p1, p2, up = Vector(p0), Vector(p1), Vector(p2), Vector(up)
    bm = bmesh.new()
    prev = None
    for i in range(n + 1):
        t = i / n
        p = (1 - t) ** 2 * p0 + 2 * (1 - t) * t * p1 + t * t * p2
        d = (2 * (1 - t) * (p1 - p0) + 2 * t * (p2 - p1)).normalized()
        side = d.cross(up)
        side = side.normalized() if side.length > 1e-4 else Vector((1, 0, 0))
        hw = w * 0.5 * ((1 - t) + tip * t) * (0.75 + 0.25 * math.sin(t * math.pi))
        a, b = bm.verts.new(p - side * hw), bm.verts.new(p + side * hw)
        if prev:
            bm.faces.new((prev[0], prev[1], b, a))
        prev = (a, b)
    ob = H._add(name, bm, mat, 0)
    ob.modifiers.new("solid", "SOLIDIFY").thickness = thick
    return ob


def _disc(name, centre, normal, r, depth, mat, verts=16):
    """A flat round button `depth` thick at `centre`, its face turned along `normal`."""
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, segments=verts, radius1=r, radius2=r, depth=depth)
    q = Vector(normal).normalized().to_track_quat("Z", "Y").to_matrix()
    for v in bm.verts:
        v.co = q @ v.co + Vector(centre)
    return H._add(name, bm, mat, 0)


def _text(name, body, width, height, depth=0.1):
    """Words in the title font as a mesh lying in XY (reading along +X), centred, scaled to fit inside width x height,
    about `depth` thick with a rounded bevel (puffy felt letters). Returns the bmesh, not yet added."""
    cu = bpy.data.curves.new(name, "FONT")
    cu.font = bpy.data.fonts.load(_FONT, check_existing=True)
    cu.body = body; cu.align_x = "CENTER"; cu.align_y = "CENTER"
    ob = bpy.data.objects.new(name, cu); bpy.context.scene.collection.objects.link(ob)
    bpy.context.view_layer.update()
    k = min(width / ob.dimensions.x, height / ob.dimensions.y)
    cu.size = k
    cu.extrude = depth * 0.3; cu.bevel_depth = depth * 0.2; cu.bevel_resolution = 0; cu.resolution_u = 3
    bpy.context.view_layer.update()
    me = bpy.data.meshes.new_from_object(ob.evaluated_get(bpy.context.evaluated_depsgraph_get()))
    bpy.data.objects.remove(ob); bpy.data.curves.remove(cu)
    bm = bmesh.new(); bm.from_mesh(me); bpy.data.meshes.remove(me)
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-5)
    xs = [v.co.x for v in bm.verts]; ys = [v.co.y for v in bm.verts]; zs = [v.co.z for v in bm.verts]
    cx, cy, z0 = (max(xs) + min(xs)) / 2, (max(ys) + min(ys)) / 2, min(zs)
    for v in bm.verts:
        v.co = Vector((v.co.x - cx, v.co.y - cy, v.co.z - z0))
    return bm


def _acorn(name, at, scale, tilt):
    """A little acorn: a tan nut under a scaly brown cap with a stub of stalk, its axis tipped `tilt` radians about Y."""
    nut = [(0.0, -0.62), (0.12, -0.6), (0.3, -0.48), (0.42, -0.28), (0.46, -0.05), (0.44, 0.08), (0.0, 0.08)]
    cap = [(0.0, 0.36), (0.12, 0.35), (0.34, 0.27), (0.5, 0.12), (0.52, 0.0), (0.46, -0.04), (0.0, -0.04)]
    place = Matrix.Translation(at) @ Matrix.Rotation(tilt, 4, "Y") @ Matrix.Scale(scale, 4)
    for nm, prof, mat in (("nut", nut, "acorn_nut"), ("cap", cap, "acorn_cap")):
        lathe(f"{name}_{nm}", prof, mat, 20).data.transform(place)
    rod(f"{name}_stalk", (0, 0, 0.3), (0.05, 0, 0.55), 0.06, "acorn_cap", 6).data.transform(place)


@prop
def banner():
    """The event's hanging banner: HAPPY HARVEST, CREW! in cream felt letters on orange cloth with a rust hem and a
    zigzag foot, a red and a yellow maple leaf at the top corners and an acorn at each bottom corner. The cloth hangs
    from two rope loops off a round wooden pole. 18 wide (pole) x ~9.1 tall; the cloth's points touch z=0, the pole is
    at the top. Front = -Y. Hung by the pole (the owner places it)."""
    W, top, notch, teeth = 15.0, 8.0, 2.0, 3

    def sway(x, z):
        """The cloth's depth at (x, z): soft folds that grow toward the foot and a slight belly between the loops."""
        drop = (top - z) / top
        return 0.18 * math.sin(x * 0.9 + 0.6) * drop + 0.1 * math.sin(x * 2.1) * drop * drop - 0.12 * (1 - (x / (W / 2)) ** 2)

    def shape(inset):
        """The outline, `inset` in from the hem: straight top, straight sides, and a foot of `teeth` points at z=0 (one
        at each corner, the rest between) with notches up to `notch` between them."""
        x0, x1 = -W / 2 + inset, W / 2 - inset
        pts = [(x0, top - inset * 0.6), (x1, top - inset * 0.6)]
        k = teeth - 1
        for i in range(k + 1):
            pts.append((x1 - (x1 - x0) * i / k, inset * 1.4))
            if i < k:
                pts.append((x1 - (x1 - x0) * (i + 0.5) / k, notch + inset * 0.3))
        return pts

    def cloth(name, inset, mat, y_off, thick):
        pts = shape(inset)
        dense = []
        for (a, b) in zip(pts, pts[1:] + pts[:1]):
            n = max(1, int(math.dist(a, b) / 0.35))
            dense += [(a[0] + (b[0] - a[0]) * j / n, a[1] + (b[1] - a[1]) * j / n) for j in range(n)]
        bm = bmesh.new()
        vs = [bm.verts.new((x, 0, z)) for (x, z) in dense]
        es = [bm.edges.new((vs[i], vs[(i + 1) % len(vs)])) for i in range(len(vs))]
        bmesh.ops.triangle_fill(bm, use_beauty=True, use_dissolve=False, edges=es)
        bmesh.ops.subdivide_edges(bm, edges=list(bm.edges), cuts=1, use_grid_fill=True)
        bmesh.ops.triangulate(bm, faces=list(bm.faces))
        for v in bm.verts:
            v.co.y = sway(v.co.x, v.co.z) + y_off
        ret = bmesh.ops.extrude_face_region(bm, geom=list(bm.faces))
        for v in [e for e in ret["geom"] if isinstance(e, bmesh.types.BMVert)]:
            v.co.y += thick
        bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
        return H._add(name, bm, mat, 0)

    cloth("hem", 0.0, "cloth_rust", 0.12, 0.08)  # set back so the coarser cloth in front never lets it through
    cloth("cloth", 0.32, "cloth_or", -0.04, 0.06)
    front = -0.045  # the orange cloth's front face sits at sway(x, z) + front

    def stand(bm, cx, cz, lift=0.0):
        """Stands a flat XY mesh (z = its thickness) up on the cloth's front at (cx, cz), facing -Y, on the folds."""
        for v in bm.verts:
            x, z, d = v.co.x + cx, v.co.y + cz, v.co.z
            v.co = Vector((x, sway(x, z) + front - d - lift, z))
        bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))

    for i, (line, cz, w, h) in enumerate((("HAPPY", 6.05, 7.0, 1.85), ("HARVEST, CREW!", 3.9, 12.0, 1.85))):
        bm = _text(f"words{i}", line, w, h, depth=0.12)
        stand(bm, 0.0, cz)
        H._add(f"words{i}", bm, "felt_cream", 0)
    # maple leaves at the top corners, lying on the cloth
    for k, (cx, mat, seed) in enumerate(((-5.9, "leaf_red", 3), (5.9, "leaf_yel", 9))):
        leaf = _leafmesh(f"mleaf{k}", 1.5, mat, curl=0.0, seed=seed, lobes=5)
        for ob in (leaf, H.parts[-1]):
            bm = bmesh.new(); bm.from_mesh(ob.data)
            bm.transform(Matrix.Translation((cx, 5.6, 0)) @ Matrix.Rotation(math.radians(-25 if k == 0 else 25), 4, "Z"))
            for v in bm.verts:
                x, z, d = v.co.x, v.co.y, v.co.z
                v.co = Vector((x, sway(x, z) + front - 0.04 - d, z))
            bm.to_mesh(ob.data); bm.free()
    # acorns at the bottom corners, lying on the cloth
    for k, cx in enumerate((-6.0, 6.0)):
        cz = 2.7
        _acorn(f"acorn{k}", (cx, sway(cx, cz) + front - 0.34, cz), 0.85, math.radians(20 if k == 0 else -20))
    # the pole with its end bands; two rope loops round it, down through brass grommets in the hem
    pz = top + 0.75
    cylx("pole", -9.0, 9.0, 0.0, pz, 0.32, "pole_wood", 20)
    for s in (-1, 1):
        cylx(f"band{s}", s * 8.6 - 0.18, s * 8.6 + 0.18, 0.0, pz, 0.345, "pole_band", 20)
        cylx(f"bandin{s}", s * 7.6 - 0.12, s * 7.6 + 0.12, 0.0, pz, 0.34, "pole_band", 20)
        gx, gz = s * W * 0.36, top - 0.55
        gy = sway(gx, gz) + front
        bpy.ops.mesh.primitive_torus_add(major_radius=0.2, minor_radius=0.06, major_segments=16, minor_segments=6,
                                         location=(gx, gy - 0.02, gz), rotation=(math.pi / 2, 0, 0))
        g = bpy.context.active_object; g.data.materials.append(H.M("brass_scan")); H.parts.append(g)
        cz, rz, ry = (pz + gz) / 2, (pz - gz) / 2 + 0.38, 0.5
        pts = [(gx, math.sin(a) * ry, cz + math.cos(a) * rz) for a in (i / 24 * math.tau for i in range(25))]
        for j in range(24):
            rod(f"rope{s}_{j}", pts[j], pts[j + 1], 0.09, "rope", 8)
    S2.finish2("hb_banner_harvest", tex=2048)


H._SPEC.update({
    # rework 11-17: straw and corn get the oak scan's long grain (they were flat noise paint)
    "straw": lambda: H._scan("straw", *H._OAK, studs=0.9, bump=0.5, rough=0.75, tint=(1.75, 1.45, 0.62), along="Z"),
    "straw_dk": lambda: H._scan("straw_dk", *H._OAK, studs=0.9, bump=0.5, rough=0.8, tint=(1.35, 1.05, 0.42), along="Z"),
    "corn_leaf": lambda: H._scan("corn_leaf", *H._OAK, studs=0.7, bump=0.35, rough=0.6, tint=(0.95, 1.05, 0.30), along="Z"),
    "corn_leaf2": lambda: H._scan("corn_leaf2", *H._OAK, studs=0.7, bump=0.35, rough=0.6, tint=(0.62, 0.85, 0.22), along="Z"),
    "corn_dry": lambda: H._scan("corn_dry", *H._OAK, studs=0.7, bump=0.4, rough=0.75, tint=(1.45, 1.08, 0.55), along="Z"),
    "corn_stalk": lambda: H._scan("corn_stalk", *H._OAK, studs=1.2, bump=0.3, rough=0.6, tint=(0.95, 1.05, 0.42), along="Z"),
    "corn_silk": lambda: _paint("corn_silk", (0.45, 0.22, 0.07), 0.7, 0.3, scale=40),
    "dirt": lambda: H._scan("dirt", *H._FABN, studs=1.6, bump=1.2, rough=0.95, tint=(0.22, 0.13, 0.07)),
    "felt_dark": lambda: H._scan("felt_dark", *H._FABN, studs=0.6, bump=0.3, rough=0.95, tint=(0.025, 0.02, 0.02)),
    "felt_eye": lambda: H._scan("felt_eye", *H._FABN, studs=0.6, bump=0.3, rough=0.95, tint=(1.45, 1.38, 1.18)),
})


def _kernels(name, rgb, gap):
    """Corn kernels: Voronoi cells in object space, each a slightly different gold, with dark gaps between."""
    m, N, L, b = H._new(name)
    tc = N.new("ShaderNodeTexCoord")
    vo = N.new("ShaderNodeTexVoronoi"); vo.feature = "DISTANCE_TO_EDGE"; vo.inputs["Scale"].default_value = 22
    L.new(tc.outputs["Object"], vo.inputs["Vector"])
    vc = N.new("ShaderNodeTexVoronoi"); vc.inputs["Scale"].default_value = 22; L.new(tc.outputs["Object"], vc.inputs["Vector"])
    mr = N.new("ShaderNodeMapRange"); mr.inputs["From Min"].default_value = 0.02; mr.inputs["From Max"].default_value = 0.12
    L.new(vo.outputs["Distance"], mr.inputs["Value"])
    var = N.new("ShaderNodeMixRGB"); var.blend_type = "MULTIPLY"; var.inputs["Fac"].default_value = 0.25
    var.inputs[1].default_value = (*rgb, 1); L.new(vc.outputs["Color"], var.inputs[2])
    mix = N.new("ShaderNodeMixRGB"); mix.inputs[1].default_value = (*gap, 1)
    L.new(mr.outputs["Result"], mix.inputs["Fac"]); L.new(var.outputs["Color"], mix.inputs[2])
    L.new(mix.outputs["Color"], b.inputs["Base Color"])
    bp = N.new("ShaderNodeBump"); bp.inputs["Strength"].default_value = 0.8; bp.inputs["Distance"].default_value = 0.03
    L.new(mr.outputs["Result"], bp.inputs["Height"]); L.new(bp.outputs["Normal"], b.inputs["Normal"])
    b.inputs["Roughness"].default_value = 0.35
    return m


H._SPEC["corn_cob"] = lambda: _kernels("corn_cob", (1.0, 0.72, 0.08), (0.35, 0.18, 0.03))


def _cornleaf(name, p0, p1, p2, w, mat, n=10, up=(0, 0, 1), fold=0.22, wave=0.05):
    """A corn leaf along the curve p0 -> p2 (pulled toward p1): narrow at the stalk, widest a third along, a long point,
    folded into a shallow V along its midrib, with a little ripple along the edges."""
    p0, p1, p2, up = Vector(p0), Vector(p1), Vector(p2), Vector(up)
    bm = bmesh.new()
    prev = None
    for i in range(n + 1):
        t = i / n
        p = (1 - t) ** 2 * p0 + 2 * (1 - t) * t * p1 + t * t * p2
        d = (2 * (1 - t) * (p1 - p0) + 2 * t * (p2 - p1)).normalized()
        side = d.cross(up)
        side = side.normalized() if side.length > 1e-4 else Vector((1, 0, 0))
        nrm = side.cross(d).normalized()
        hw = w * 0.5 * (0.45 + 1.6 * t) if t < 0.3 else w * 0.5 * (0.93 * (1 - t) / 0.7 + 0.04)
        rip = wave * w * math.sin(t * 23)
        mid = p + nrm * fold * hw
        a, c = p - side * hw + nrm * rip, p + side * hw - nrm * rip
        row = (bm.verts.new(a), bm.verts.new(mid), bm.verts.new(c))
        if prev:
            bm.faces.new((prev[0], prev[1], row[1], row[0]))
            bm.faces.new((prev[1], prev[2], row[2], row[1]))
        prev = row
    ob = H._add(name, bm, mat, 0)
    ob.modifiers.new("solid", "SOLIDIFY").thickness = 0.02
    return ob


def _cornplant(name, base, height, rng, face):
    """A hand-built autumn corn plant standing in the soil at `base`: a jointed stalk that thins and leans a little,
    brace roots into the dirt, long leaves from alternate joints (dry tan low, green-gold higher), a tassel, and one ear
    angled up from a middle joint toward `face`, its husk peeled back over the kernels with a tuft of silk."""
    base = Vector(base)
    lean = Vector((rng.uniform(-0.12, 0.12), rng.uniform(-0.1, 0.1), 1.0)).normalized()
    nodes = 6
    pts = [base + lean * height * (k / nodes) + Vector((0, 0, 0)) for k in range(nodes + 1)]
    for k in range(nodes):
        r0 = 0.16 * (1 - 0.55 * k / nodes)
        rod(f"{name}_st{k}", pts[k] - lean * 0.02, pts[k + 1], r0, "corn_stalk", 8)
    for j in range(4):  # brace roots
        a = j / 4 * math.tau + rng.uniform(-0.3, 0.3)
        rod(f"{name}_rt{j}", base + lean * 0.35, base + Vector((math.cos(a) * 0.3, math.sin(a) * 0.3, -0.12)), 0.045, "corn_stalk", 5)
    phase = rng.uniform(0, math.tau)
    for k in range(1, nodes):
        a = phase + k * math.pi + rng.uniform(-0.35, 0.35)
        out = Vector((math.cos(a), math.sin(a) * 0.75, 0)).normalized()
        ln = height * rng.uniform(0.42, 0.55) * (1.0 - 0.1 * k / nodes)
        p0 = pts[k]
        p1 = p0 + out * ln * 0.3 + Vector((0, 0, ln * 0.55))
        p2 = p0 + out * ln * 0.95 + Vector((0, 0, ln * (0.05 if k > 2 else -0.3)))
        mat = "corn_dry" if k <= 1 else ("corn_leaf" if k % 2 else "corn_leaf2")
        _cornleaf(f"{name}_lf{k}", p0, p1, p2, 0.58, mat, n=8, up=Vector((0, 0, 1)))
    top = pts[-1]
    rod(f"{name}_tasselstem", top, top + lean * 0.7, 0.04, "corn_dry", 5)
    for j in range(6):  # tassel: thin spikes arching out and down
        a = j / 6 * math.tau + rng.uniform(-0.2, 0.2)
        o = Vector((math.cos(a), math.sin(a), 0))
        t0 = top + lean * (0.35 + 0.06 * j)
        _blade(f"{name}_ts{j}", t0, t0 + o * 0.3 + Vector((0, 0, 0.3)), t0 + o * 0.6 + Vector((0, 0, -0.05)),
               0.06, "corn_dry", n=4, up=(0, 0, 1), tip=0.3, thick=0.015)
    # the ear, from the middle joint, tipped up and out toward the viewer
    k = 3
    fo = Vector(face).normalized()
    tilt = (fo * 0.75 + Vector((0, 0, 1))).normalized()
    q = tilt.to_track_quat("Z", "Y").to_matrix().to_4x4()
    at = pts[k] + fo * 0.18
    bm = bmesh.new(); bmesh.ops.create_uvsphere(bm, u_segments=20, v_segments=14, radius=1.0)
    for v in bm.verts:  # a fat, round-ended ear with rows of kernels, not a smooth lemon
        x, y, z = v.co
        kern = 1 + 0.14 * abs(math.sin(math.atan2(y, x) * 10)) * abs(math.sin(z * 14))
        sq = min(1.0, (1 - abs(z)) * 3.5) ** 0.3 if abs(z) < 1 else 0.0
        tp = 1.0 - 0.25 * max(0.0, z)
        rr = (x * x + y * y) ** 0.5
        k = (0.24 * sq * kern * tp / rr) if rr > 1e-4 else 0.0
        v.co = Vector((x * k, y * k, (z + 1) * 0.45))
    M = Matrix.Translation(at) @ q
    bm.transform(M)
    H._add(f"{name}_cob", bm, "corn_cob", 0)
    for h in range(3):  # husk leaves peeled back
        a = h / 3 * math.tau + 0.4
        o = Vector((math.cos(a), math.sin(a), 0))
        _cornleaf(f"{name}_hk{h}", M @ Vector((0, 0, 0.05)), M @ (o * 0.32 + Vector((0, 0, 0.3))),
                  M @ (o * 0.55 + Vector((0, 0, 0.55))), 0.36, "corn_dry", n=6, up=M.to_3x3() @ Vector((0, 0, 1)), fold=0.35)
    for j in range(3):  # silk out of the tip
        o = Vector((math.cos(j * 1.3), math.sin(j * 1.3), 0))
        _blade(f"{name}_sk{j}", M @ Vector((0, 0, 0.82)), M @ (o * 0.12 + Vector((0, 0, 0.98))), M @ (o * 0.3 + Vector((0, 0, 0.9))),
               0.035, "corn_silk", n=3, up=(0, 0, 1), tip=0.4, thick=0.01)


def _crop_row(rng):
    """The scarecrow stands in a tilled crop row running across the front: a raised ridge of soil (furrowed, with clods)
    9 studs long, the post planted in its middle, two corn plants growing out of the ridge on each side."""
    bm = bmesh.new()
    nx, prof = 28, [(-1.5, -0.05), (-1.15, 0.12), (-0.75, 0.42), (-0.3, 0.58), (0.3, 0.58), (0.75, 0.42), (1.15, 0.12), (1.5, -0.05)]
    grid = []
    for i in range(nx + 1):
        x = -4.6 + 9.2 * i / nx
        endk = min(1.0, (4.6 - abs(x)) / 0.6)  # rounded ends
        row = []
        for y, z in prof:
            jit = rng.uniform(-0.04, 0.04)
            row.append(bm.verts.new((x, y * (0.6 + 0.4 * endk) + 0.6, (z * endk) + jit if z > 0 else z)))
        grid.append(row)
    for a, b in zip(grid, grid[1:]):
        for j in range(len(prof) - 1):
            bm.faces.new((a[j], b[j], b[j + 1], a[j + 1]))
    H._add("ridge", bm, "dirt", 0)
    for j in range(8):  # clods on the ridge
        x = rng.uniform(-4.2, 4.2)
        lumpy(f"clod{j}", x, 0.6 + rng.uniform(-1.0, 1.0), 0.35, rng.uniform(0.12, 0.22), "dirt", sz=0.7, seed=j, amp=0.3, segs=(8, 6))
    for k, (x, h) in enumerate(((-3.7, 5.2), (-2.2, 5.9), (2.3, 6.1), (3.75, 5.0))):
        _cornplant(f"corn{k}", (x, 0.6 + rng.uniform(-0.25, 0.25), 0.45), h, rng, (-0.35 * (1 if x > 0 else -1), -1, 0))


def _eyes(kind, onhead, hz):
    """Sewn-on eyes, never buttons (owner 11-17). `onhead(ax, az, out)` is a point on the sack's front.
    felt: cream felt rounds with dark felt pupils, running-stitched on. happy: stitched closed arcs that match the smile.
    x: cross-stitched Xs. tri: dark felt triangles (like a jack-o'-lantern) stitched round the edge."""
    centre = Vector((0, 0, hz))
    for s in (-1, 1):
        ax, az = s * 0.36, 0.0
        c = onhead(ax, az, 0.0)
        n = (c - centre).normalized()

        def at(u, v, out=0.02):
            return onhead(ax + u / 1.28, az + v / 1.28, out)
        if kind == "felt":
            _disc(f"eye{s}", at(0, 0, 0.0), n, 0.3, 0.03, "felt_eye", 20)
            _disc(f"pupil{s}", at(s * -0.05, 0.02, 0.025), n, 0.19, 0.03, "felt_dark", 18)
            _disc(f"shine{s}", at(s * -0.05 + 0.07, 0.1, 0.045), n, 0.05, 0.02, "felt_eye", 10)
            for i in range(8):  # running stitch round the felt
                t0, t1 = i / 8 * math.tau, (i + 0.45) / 8 * math.tau
                rod(f"es{s}_{i}", at(math.cos(t0) * 0.27, math.sin(t0) * 0.27, 0.03), at(math.cos(t1) * 0.27, math.sin(t1) * 0.27, 0.03),
                    0.016, "stitch", 4)
        elif kind == "happy":
            arc = [at(-0.3 + 0.6 * i / 6, 0.2 * math.sin(math.pi * i / 6) - 0.06, 0.01) for i in range(7)]
            for i in range(6):
                rod(f"ea{s}_{i}", arc[i], arc[i + 1], 0.05, "stitch", 6)
            for i in (1, 3, 5):
                p = arc[i]
                across = (arc[i + 1] - arc[i - 1]).normalized().cross(n).normalized() * 0.09
                rod(f"ex{s}_{i}", p - across, p + across, 0.03, "stitch", 6)
        elif kind == "x":
            for d in (1, -1):
                rod(f"ex{s}_{d}", at(-0.17, -0.17 * d, 0.01), at(0.17, 0.17 * d, 0.01), 0.05, "stitch", 6)
        elif kind == "tri":
            bm = bmesh.new()
            cs = ((-0.24, -0.15), (0.24, -0.15), (s * -0.03, 0.24))
            mid = (sum(u for u, _ in cs) / 3, sum(v for _, v in cs) / 3)
            ring = []
            for i in range(3):
                (u0, v0), (u1, v1) = cs[i], cs[(i + 1) % 3]
                for k in range(3):
                    t = k / 3
                    ring.append(bm.verts.new(at(u0 + (u1 - u0) * t, v0 + (v1 - v0) * t, 0.015)))
            cv = bm.verts.new(at(*mid, 0.03))
            for i in range(len(ring)):
                bm.faces.new((cv, ring[i], ring[(i + 1) % len(ring)]))
            ob = H._add(f"tri{s}", bm, "felt_dark", 0)
            ob.modifiers.new("solid", "SOLIDIFY").thickness = 0.04
            corners = ((-0.24, -0.15), (0.24, -0.15), (s * -0.03, 0.24))
            for i in range(3):
                (u0, v0), (u1, v1) = corners[i], corners[(i + 1) % 3]
                for k in range(3):
                    t = (k + 0.3) / 3
                    u, v = u0 + (u1 - u0) * t, v0 + (v1 - v0) * t
                    rod(f"ts{s}_{i}{k}", at(u * 1.25, v * 1.25, 0.02), at(u * 0.8, v * 0.8, 0.06), 0.017, "stitch", 4)


@prop
def scarecrow():
    """A friendly scarecrow on a wooden post, ~9 tall x 7.4 wide (arms): a burlap head with sewn eyes (variant felt|happy|x|tri) and a stitched
    smile, a floppy straw hat with a red band, a too-big orange plaid shirt with two buttons and a patch, straw at the
    neck, cuffs and hem, arms on a crossbar, and a corn plant with a cob either side, on a small mound of dirt.
    Front = -Y, stands on z=0."""
    rng = random.Random(11)
    eyes = VAR["v"] or "felt"
    _crop_row(rng)
    cyl("post", 0, 0, -0.3, 6.4, 0.28, "pole_wood_v", 12)
    cylx("crossbar", -3.7, 3.7, 0.0, 5.45, 0.22, "pole_wood", 12)
    # shirt: ONE garment (owner 11-17: "obvious seams where they connect arms to torso"). A box body, its upper side
    # faces extruded out along the crossbar into the sleeves, hollow open cuffs, then smoothed, so there is no join.
    bm = bmesh.new(); bmesh.ops.create_cube(bm, size=1.0)
    bmesh.ops.subdivide_edges(bm, edges=list(bm.edges), cuts=2, use_grid_fill=True)
    for v in bm.verts:
        x, y, z = v.co  # each -0.5..0.5
        flare = 1.0 + 0.2 * (0.5 - z)
        v.co = Vector((x * 2.7 * flare, y * 1.6 * flare, 3.15 + (z + 0.5) * 2.85))
    bm.normal_update()
    for s in (-1, 1):
        faces = [f for f in bm.faces if f.normal.x * s > 0.7 and f.calc_center_median().z > 5.0]
        for step, (dx, ky, kz) in enumerate(((0.55, 0.72, 1.0), (0.65, 0.95, 0.94), (0.65, 0.97, 0.97))):
            r = bmesh.ops.extrude_face_region(bm, geom=faces)
            bmesh.ops.delete(bm, geom=faces, context="FACES")
            faces = [g for g in r["geom"] if isinstance(g, bmesh.types.BMFace)]
            for v in {v for f in faces for v in f.verts}:
                v.co = Vector((v.co.x + s * dx, v.co.y * ky, 5.47 + (v.co.z - 5.47) * kz - 0.04 * step))
        bmesh.ops.inset_region(bm, faces=faces, thickness=0.09)  # the cuff hem
        for v in {v for f in faces for v in f.verts}:
            v.co.x -= s * 0.45  # open cuff: the end pushed back inside the sleeve
    bm.normal_update()
    sh = H._add("shirt", bm, "plaid", 0)
    sh.modifiers.new("sub", "SUBSURF").levels = 2
    for s in (-1, 1):
        for j in range(9):  # straw fanning out of the open cuff, round the crossbar
            a = j / 9 * math.tau + rng.uniform(-0.2, 0.2)
            base = Vector((s * 2.85, math.sin(a) * 0.3, 5.42 + math.cos(a) * 0.3))
            tipv = base + Vector((s * rng.uniform(0.55, 0.85), math.sin(a) * 0.35, math.cos(a) * 0.4 - 0.15))
            _blade(f"cuff{s}_{j}", base, (base + tipv) / 2 + Vector((0, 0, 0.08)), tipv, 0.2,
                   "straw" if j % 3 else "straw_dk", n=4, up=(1, 0, 0), tip=0.3)
    for j in range(30):  # straw poking out under the shirt
        x = -1.45 + j * (2.9 / 29) + rng.uniform(-0.05, 0.05)
        y = -0.85 if j % 2 == 0 else 0.85
        base = Vector((x, y, 3.3))
        tipv = base + Vector((rng.uniform(-0.2, 0.2), y * 0.3, -rng.uniform(0.35, 0.8)))
        _blade(f"hem{j}", base, (base + tipv) / 2, tipv, 0.1, "straw" if j % 3 else "straw_dk", n=3, up=(0, 1, 0), tip=0.3)
    for s in (-1, 1):  # collar flaps
        bm = bmesh.new()
        vs = [bm.verts.new(p) for p in ((s * 0.1, -0.86, 5.95), (s * 0.85, -0.78, 5.95), (s * 0.45, -0.98, 5.35))]
        bm.faces.new(vs if s > 0 else list(reversed(vs)))
        H._add(f"collar{s}", bm, "plaid", 0).modifiers.new("solid", "SOLIDIFY").thickness = 0.06
    for k, z in enumerate((4.9, 4.0)):  # two buttons with their four holes
        y = -0.9 - 0.02 * k
        _disc(f"button{k}", (0.15, y, z), (0, -1, 0), 0.2, 0.07, "button_br")
        for hx, hz in ((-0.06, -0.06), (0.06, -0.06), (-0.06, 0.06), (0.06, 0.06)):
            _disc(f"bhole{k}{hx}{hz}", (0.15 + hx, y - 0.035, z + hz), (0, -1, 0), 0.03, 0.02, "button_blk", 6)
    box("patch", 0.55, 1.15, -0.93, -0.86, 3.75, 4.35, "patch", bevel=0.02)
    for j in range(6):
        x = 0.58 + j / 6 * 0.54
        for nm, zz in (("pst", 4.3), ("psb", 3.8)):
            box(f"{nm}{j}", x, x + 0.06, -0.945, -0.925, zz - 0.012, zz + 0.012, "stitch", bevel=0.0)
    for j in range(16):  # neck straw ruff
        a = j / 16 * math.tau
        base = Vector((math.cos(a) * 0.5, math.sin(a) * 0.45, 6.0))
        tipv = base + Vector((math.cos(a) * 0.45, math.sin(a) * 0.4, -0.35))
        _blade(f"ruff{j}", base, base + Vector((math.cos(a) * 0.3, math.sin(a) * 0.3, 0.05)), tipv, 0.24,
               "straw" if j % 3 else "straw_dk", n=3, up=(0, 0, 1), tip=0.3)
    # head: a burlap sack ball, gathered at the neck
    hz, hr = 7.2, 1.28
    sphere("head", 0, 0, hz, hr, "burlap", 1.0, 0.95, 1.0)
    cyl("neck", 0, 0, 5.9, 6.3, 0.42, "burlap", 16)

    def onhead(ax, az, out=0.0):
        """A point on the head's front, `ax` across and `az` up (radians), `out` beyond the skin."""
        r = hr + out
        return Vector((math.sin(ax) * math.cos(az) * r, -math.cos(ax) * math.cos(az) * r * 0.95, hz + math.sin(az) * r))
    _eyes(eyes, onhead, hz)
    smile = [onhead(-0.55 + 1.1 * i / 10, -0.36 - 0.16 * math.sin(math.pi * i / 10), 0.01) for i in range(11)]
    for i in range(10):  # the stitched smile and its cross stitches
        rod(f"smile{i}", smile[i], smile[i + 1], 0.035, "stitch", 6)
    for i in range(1, 10, 2):
        p = smile[i]
        across = (smile[i + 1] - smile[i - 1]).normalized().cross((p - Vector((0, 0, hz))).normalized()).normalized() * 0.14
        rod(f"cross{i}", p - across, p + across, 0.03, "stitch", 6)
    for j in range(22):  # straw hair under the brim, round the sides and back, clear of the face
        a = math.radians(-160 + j * (320 / 21)) - math.pi / 2
        base = Vector((math.cos(a) * hr * 0.9, math.sin(a) * hr * 0.87, hz + 0.75))
        if base.y < -0.5 and abs(base.x) < 0.75:
            continue
        tipv = base + Vector((math.cos(a) * 0.35, math.sin(a) * 0.35, -rng.uniform(0.6, 0.95)))
        _blade(f"hair{j}", base, base + Vector((math.cos(a) * 0.35, math.sin(a) * 0.35, -0.1)), tipv, 0.22,
               "straw" if j % 3 else "straw_dk", n=4, up=(0, 0, 1), tip=0.35)
    # the hat: a floppy wavy brim, a dome crown, a red band and a straw fringe, tipped a little
    hat = []
    bm = bmesh.new()
    rings = []
    seg = 40
    for k, (r, dz) in enumerate(((0.95, 0.0), (1.4, -0.05), (1.9, -0.18), (2.1, -0.32))):
        ring = []
        for i in range(seg):
            a = i / seg * math.tau
            rr = r + (0.08 * math.sin(a * 7) if k == 3 else 0.0)
            ring.append(bm.verts.new((math.cos(a) * rr, math.sin(a) * rr, dz + 0.12 * math.sin(a * 3 + 1) * (k / 3))))
        rings.append(ring)
    for a_, b_ in zip(rings, rings[1:]):
        for i in range(seg):
            bm.faces.new((a_[i], a_[(i + 1) % seg], b_[(i + 1) % seg], b_[i]))
    ob = H._add("brim", bm, "straw_hat", 0)
    ob.modifiers.new("solid", "SOLIDIFY").thickness = 0.1
    hat.append(ob)
    hat.append(lathe("crown", [(0.0, 0.95), (0.4, 0.92), (0.72, 0.8), (0.9, 0.5), (0.98, 0.1), (1.0, -0.05), (0.0, -0.05)], "straw_hat", 32))
    hat.append(lathe("hatband", [(0.995, 0.08), (1.03, 0.1), (1.04, 0.3), (1.0, 0.36)], "hat_band", 32))
    for j in range(26):
        a = j / 26 * math.tau
        base = Vector((math.cos(a) * 2.05, math.sin(a) * 2.05, -0.3 + 0.12 * math.sin(a * 3 + 1)))
        tipv = base + Vector((math.cos(a) * 0.3, math.sin(a) * 0.3, -0.12))
        hat.append(_blade(f"fringe{j}", base, (base + tipv) / 2, tipv, 0.16, "straw_dk" if j % 2 else "straw", n=2, up=(0, 0, 1), tip=0.4))
    place = (Matrix.Translation((0.05, 0.25, hz + 1.2)) @ Matrix.Rotation(math.radians(-8), 4, "Y")
             @ Matrix.Rotation(math.radians(10), 4, "X") @ Matrix.Scale(1.22, 4))
    for ob in hat:
        ob.data.transform(place)
    S2.finish2("hb_scarecrow_harvest" + ("" if eyes == "felt" and not VAR["v"] else "_" + eyes), tex=2048, smooth_angle=50)


if __name__ == "__main__":
    for w in sys.argv[sys.argv.index("--") + 1:]:
        name, _, variant = w.partition(":")
        H.reset()
        VAR["v"] = variant or None
        PROPS[name]()
