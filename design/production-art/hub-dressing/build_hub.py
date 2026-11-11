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
from hardlib import box, cyl, sphere, cone

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
    H._add("body", bm, mat, 0)
    # curved, faceted stem (6 sides), tapered, bent over
    pts = [Vector((0, 0, top - 0.25)), Vector((0.03, 0, top + 0.25 * r)), Vector((0.14, 0.02, top + 0.45 * r)), Vector((0.32, 0.05, top + 0.55 * r))]
    for i in range(len(pts) - 1):
        t = 0.17 * r * (1 - i * 0.22)
        strut(f"stem{i}", pts[i], pts[i + 1], t, "stem", bevel=0.02)
    # a curled vine leaf lying on the shoulder
    leaf = _leafmesh("vleaf", 0.75 * r, "vine_leaf", curl=0.35, seed=3)
    leaf.data.transform(Matrix.Rotation(math.radians(-25), 4, "Y"))
    leaf.data.transform(Matrix.Translation((-0.35 * r, 0.25 * r, top - 0.12 * r)))
    rod("vine", (0, 0.05, top - 0.05), (-0.55 * r, 0.6 * r, top - 0.35 * r), 0.035, "vine_leaf", 6)
    S2.finish2(f"hb_pumpkin_{v}", tex=512)


# --------------------------------------------------------------------- leaves ---
def _leafmesh(name, size, mat, curl=0.25, seed=0, lobes=5):
    """A flat maple-ish leaf (lobed outline fan) with a midrib fold and a curl, about `size` long, lying in XY."""
    rng = random.Random(seed)
    bm = bmesh.new()
    c = bm.verts.new((0, 0, 0))
    ring = []
    n = 40
    for i in range(n):
        a = i / n * math.tau
        # lobes: sharp points, deeper notches, a stalk notch at the bottom (a = -pi/2)
        lob = 0.55 + 0.45 * abs(math.cos(a * lobes / 2)) ** 0.6
        base = 1 - 0.55 * max(0.0, -math.sin(a)) ** 3
        rr = size * 0.5 * lob * base * rng.uniform(0.93, 1.05)
        x, y = math.cos(a) * rr, math.sin(a) * rr + size * 0.12
        ring.append(bm.verts.new((x, y, 0)))
    for i in range(n):
        bm.faces.new((c, ring[i], ring[(i + 1) % n]))
    bmesh.ops.subdivide_edges(bm, edges=[e for e in bm.edges if c in e.verts], cuts=2, use_grid_fill=False)
    for v in bm.verts:
        x, y, _ = v.co
        v.co.z = abs(x) * 0.25 + curl * (x * x + 0.5 * y * y) / max(size, 0.01)  # midrib fold + cupping
    # thickness so it reads from both sides
    ret = bmesh.ops.extrude_face_region(bm, geom=list(bm.faces))
    for v in [e for e in ret["geom"] if isinstance(e, bmesh.types.BMVert)]:
        v.co.z -= 0.03
    bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
    return H._add(name, bm, mat, 0)


@prop
def leafpile():
    """A drift of ~26 curled autumn leaves heaped against a wall (pile a: 5x3 studs; b: a loose 6x6 scatter)."""
    v = VAR["v"] or "a"
    rng = random.Random(41 if v == "a" else 77)
    mats = ["leaf_or", "leaf_red", "leaf_yel", "leaf_brn", "leaf_or"]
    count = 26 if v == "a" else 18
    for i in range(count):
        if v == "a":
            x = rng.gauss(0, 1.1); y = rng.uniform(-1.0, 1.0) * 0.9
            z = max(0.0, 0.35 * math.exp(-(x * x) / 2) * (1 - abs(y)) ) + 0.04 + i * 0.006
        else:
            x = rng.uniform(-2.8, 2.8); y = rng.uniform(-2.8, 2.8); z = 0.04 + rng.uniform(0, 0.05)
        size = rng.uniform(0.55, 0.85)
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


if __name__ == "__main__":
    for w in sys.argv[sys.argv.index("--") + 1:]:
        name, _, variant = w.partition(":")
        H.reset()
        VAR["v"] = variant or None
        PROPS[name]()
