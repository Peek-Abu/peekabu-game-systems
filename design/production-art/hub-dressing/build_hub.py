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


if __name__ == "__main__":
    for w in sys.argv[sys.argv.index("--") + 1:]:
        name, _, variant = w.partition(":")
        H.reset()
        VAR["v"] = variant or None
        PROPS[name]()
