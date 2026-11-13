"""Odd Hours crew truck v4 "Night Bakery Van" (owner pick 2026-11-13, p1-truck-lore: look A, no company name, a
painted-over old sign as a lore find, no side line). Target look: design/production-art/truck-lore/truck_A.jpg: a round
1950s bakery van: a bubble teal cab with round headlights and a bar grille, a cream box with soft loaf corners, a wavy
grape swoosh, a row of glowing round portholes along the top, a mint roof beacon, gold hubs. Built on v3's size B
"Moving Van" (characters/truck/build_truck_v3.py: 16 x 24 floor, 10 ceiling, tandem rear wheels), same gameplay
contract, paint slots and sockets; the Luton is gone (the cab roof is open for the beacon).
Texture pass (texture-pipeline, style class vehicle_paint): every paint-slot piece gets box-projected UVs at
PAINT_STUDS per tile for one shared satin paint set (truck_paint_color/normal/rough, a tintable near-white), so a slot's
colour is a SurfaceAppearance tint and a skin still needs no upload.

Hand-built (no AI mesh), the hard-surface prop kit's way (texture-pipeline: hardlib.py): bevelled boxes with chosen
rounded edges, cylinders and swept arcs. Unlike hardlib.finish(), nothing is joined into one baked prop: every piece
stays its own mesh in one PAINT SLOT, so a skin is a palette (MeshPart Color/Material per slot) and needs no upload.

  cab    cab body, roof pod, mirror arms, fenders          box    box shell, roof, roll-door lip
  band   the box-side band strip                          trim   back frame, bumpers, corner caps, ramp rails, rails
  metal  hubs, pinstripes, door handles                   fixed  tyres, glass, lamps, ramp, chassis, the box inside

Run headless (Blender 5.1):
  blender -b --factory-startup -P build_truck_v4.py -- <out_dir> [livery.png] [characters_dir] [--no-render]

Coordinates: the game's DECK SPACE (Roblox axes, studs): origin = the middle of the bed's top face, +Y up, +Z toward
the cab, -Z the open back and ramp, the ground at y = -DECK. Blender = (-x, z, y) (the FBX export turns it back).

Gameplay contract (DepotTruckVisualConstants, derived from HB / LH / CEIL below): the bed 16 x 3 x 24 is the floor;
box walls sit in x = +-HB..HB+0.5, the lining at +-(HB-0.07); the front wall z LH..LH+0.5; the ceiling lining at CEIL,
the roof CEIL+0.045..CEIL+0.795; the back frame's posts x +-HB..HB+1.2; the doorway 2*HB wide under the roll drum; the
ramp from (z -LH, y 0) to the ground RAMP_LEN further out; the cab scaled S from v2's.

Outputs in <out_dir>: Truck_v4.fbx (one mesh per piece), Truck_v4.json (each piece's centre/size in deck space, slot,
colour, material, triangles; the slot palette; every socket and interior attachment), Truck_v4.blend, render_*.png.
"""

import json
import math
import sys

import bmesh
import bpy
from mathutils import Matrix, Vector

argv = sys.argv[sys.argv.index("--") + 1 :]
RENDER = "--no-render" not in argv
argv = [a for a in argv if not a.startswith("--")]
OUT = argv[0]
LIVERY = argv[1] if len(argv) > 1 and argv[1] else None
CHARS = argv[2] if len(argv) > 2 and argv[2] else None

DECK = 3.0
RAMP_LEN = 4.0
G = -DECK

# ---- paint slots: the default skin (look A) --------------------------------------------------------
SLOTS = {
    "cab": {"colour": "#1F6E66", "material": "SmoothPlastic"},
    "box": {"colour": "#FFF7E8", "material": "SmoothPlastic"},
    "band": {"colour": "#7B3FF2", "material": "SmoothPlastic"},
    "trim": {"colour": "#B9AFA6", "material": "SmoothPlastic"},
    "metal": {"colour": "#FFC93A", "material": "SmoothPlastic"},
}
# fixed pieces keep their own colour and material in every skin
TYRE = "#2B2A30"
GLASS = "#3E5E66"
LAMP = "#FFF1C8"
AMBER = "#FFB43A"
RED = "#E5483B"
SCANNER = "#24704C"  # DepotTruckVisualConstants.SCANNER_IDLE (the game sets it anyway)
MINT = "#7DF2D0"
PORTHOLE = "#FFD27A"  # the portholes' warm glow
RAMP = "#A39AA5"
CHASSIS = "#34343A"
LINING = "#F4E7C6"
FLOOR = "#D9C391"
FLOOR_SEAM = "#C4AC78"
INNER_TRIM = "#E2D0A2"
GRILLE_BACK = "#3A3A40"
CEILING_LAMP = "#FFF4D6"

bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene
COLL = bpy.data.collections.new("Truck_v4")
scene.collection.children.link(COLL)
MATS = {}
PIECES = {}  # name -> object
INFO = {}  # name -> {slot, colour, material}


def lin(c):
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def mat(hexv):
    if hexv not in MATS:
        h = hexv.lstrip("#")
        m = bpy.data.materials.new(f"M_{h}")
        m.diffuse_color = (*[lin(int(h[i : i + 2], 16) / 255) for i in (0, 2, 4)], 1.0)
        MATS[hexv] = m
    return MATS[hexv]


def B(p):
    """Deck space (Roblox axes) -> Blender."""
    return Vector((-p[0], p[2], p[1]))


def D(v):
    """Blender -> deck space."""
    return Vector((-v.x, v.z, v.y))


# deck axis -> the Blender axis it lies on (deck x is mirrored, which only flips a rotation's sign)
BAXIS = {"x": "X", "y": "Z", "z": "Y"}


def new_obj(bm):
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    me = bpy.data.meshes.new("tmp")
    bm.to_mesh(me)
    bm.free()
    ob = bpy.data.objects.new("tmp", me)
    COLL.objects.link(ob)
    return ob


def finish(ob, bev, segs=2, angle=35, clamp=True):
    """A small bevel on every sharp edge (the kit's 'never a razor edge' rule), applied."""
    if bev > 0:
        md = ob.modifiers.new("bevel", "BEVEL")
        md.width = bev
        md.segments = segs
        md.limit_method = "ANGLE"
        md.angle_limit = math.radians(angle)
        md.harden_normals = False
        md.use_clamp_overlap = clamp
    bpy.context.view_layer.objects.active = ob
    for md in list(ob.modifiers):
        bpy.ops.object.modifier_apply(modifier=md.name)
    return ob


def spin(bm, axis, angle, pivot):
    """Rotates bm about a deck-space axis through a deck-space pivot. For 'x', +angle lifts the +Z end."""
    m = Matrix.Translation(B(pivot)) @ Matrix.Rotation(angle, 4, BAXIS[axis]) @ Matrix.Translation(-B(pivot))
    bmesh.ops.transform(bm, matrix=m, verts=bm.verts)


def rbox(x0, x1, y0, y1, z0, z1, bev=0.06, r=0.0, edges=(), rsegs=6, segs=2, tilt=None):
    """A deck-space box. `edges`: which edges to round with radius r, each (axis, s1, s2): the edges parallel to
    `axis` on the s1/s2 sides (-1, +1, or 0 for both) of the other two axes in xyz order (y edges: (x, z) sides;
    x edges: (y, z); z edges: (x, y)). `tilt`: (axis, angle[, pivot]) turns the finished box."""
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    for v in bm.verts:
        v.co = B((x0 if v.co.x < 0 else x1, y0 if v.co.y < 0 else y1, z0 if v.co.z < 0 else z1))
    # deck -> Blender mirrors x, which turns the faces inside out; the rounding needs outward normals
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    if r > 0 and edges:
        mid = Vector(((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2))
        want = []
        for e in bm.edges:
            a, b = D(e.verts[0].co), D(e.verts[1].co)
            d = a - b
            axis = max(range(3), key=lambda i: abs(d[i]))
            others = [i for i in range(3) if i != axis]
            sides = [1 if a[i] > mid[i] else -1 for i in others]
            for ax, s1, s2 in edges:
                if "xyz".index(ax) == axis and s1 in (0, sides[0]) and s2 in (0, sides[1]):
                    want.append(e)
                    break
        bmesh.ops.bevel(bm, geom=want, offset=r, segments=rsegs, affect="EDGES", profile=0.5, clamp_overlap=True)
    if tilt:
        spin(bm, tilt[0], tilt[1], tilt[2] if len(tilt) > 2 else ((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2))
    return finish(new_obj(bm), bev, segs)


def rounded(x0, x1, y0, y1, z0, z1, r, axis, bev=0.05, rsegs=6, tilt=None):
    """A box with all four edges along `axis` rounded (a pill / rounded slab)."""
    return rbox(x0, x1, y0, y1, z0, z1, bev, r, ((axis, 0, 0),), rsegs, tilt=tilt)


def cyl(axis, centre, radius, depth, bev=0.0, segs=24, r2=None):
    """A cylinder (or a cone with r2) along a deck axis."""
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, segments=segs, radius1=radius, radius2=radius if r2 is None else r2, depth=depth)
    # create_cone runs along Blender Z = deck y
    if axis == "x":
        bmesh.ops.transform(bm, matrix=Matrix.Rotation(-math.pi / 2, 4, "Y"), verts=bm.verts)
    elif axis == "z":
        bmesh.ops.transform(bm, matrix=Matrix.Rotation(-math.pi / 2, 4, "X"), verts=bm.verts)
    bmesh.ops.translate(bm, vec=B(centre), verts=bm.verts)
    return finish(new_obj(bm), bev, 2, 50)


def dome(centre, radius, scale=(1, 1, 1), useg=16, vseg=8):
    """A sphere scaled per deck axis (rivets, bolts, hub caps)."""
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=useg, v_segments=vseg, radius=radius)
    s = BS(scale)
    for v in bm.verts:
        v.co = Vector((v.co.x * s.x, v.co.y * s.y, v.co.z * s.z)) + B(centre)
    return finish(new_obj(bm), 0)


def BS(s):
    return Vector((s[0], s[2], s[1]))


def arc_x(centre, r_in, r_out, x0, x1, a0=0.0, a1=math.pi, segs=16, bev=0.06):
    """A fender: a ring sector round a deck-space X axis from x0 to x1, a0..a1 from +Z toward +Y."""
    bm = bmesh.new()
    rings = []
    for i in range(segs + 1):
        a = a0 + (a1 - a0) * i / segs
        dz, dy = math.cos(a), math.sin(a)
        rings.append(
            [bm.verts.new(B((x, centre[1] + dy * r, centre[2] + dz * r))) for r in (r_in, r_out) for x in (x0, x1)]
        )
    for i in range(segs):
        a, b = rings[i], rings[i + 1]
        bm.faces.new((a[2], a[3], b[3], b[2]))
        bm.faces.new((a[1], a[0], b[0], b[1]))
        bm.faces.new((a[0], a[2], b[2], b[0]))
        bm.faces.new((a[3], a[1], b[1], b[3]))
    for ring in (rings[0], rings[-1]):
        bm.faces.new((ring[0], ring[1], ring[3], ring[2]))
    return finish(new_obj(bm), bev, 2, 30)


def round_profile(points, radii, segs=8):
    """A 2D polygon [(z, y), ...] with each corner i replaced by an arc of radius radii[i] (0 keeps the corner)."""
    out = []
    n = len(points)
    for i, p in enumerate(points):
        r = radii[i]
        if r <= 0:
            out.append(p)
            continue
        P = Vector(p)
        u1 = (Vector(points[i - 1]) - P).normalized()
        u2 = (Vector(points[(i + 1) % n]) - P).normalized()
        half = u1.angle(u2) / 2
        t = r / math.tan(half)
        t1, t2 = P + u1 * t, P + u2 * t
        c = P + (u1 + u2).normalized() * (r / math.sin(half))
        a1 = math.atan2(t1.y - c.y, t1.x - c.x)
        a2 = math.atan2(t2.y - c.y, t2.x - c.x)
        da = (a2 - a1 + math.pi) % (2 * math.pi) - math.pi
        for k in range(segs + 1):
            a = a1 + da * k / segs
            out.append((c.x + r * math.cos(a), c.y + r * math.sin(a)))
    return out


def prism_x(profile, x0, x1, bev=0.0, segs=4, clamp=True):
    """A side profile [(z, y), ...] (counter-clockwise seen from +X) extruded along deck X from x0 to x1."""
    bm = bmesh.new()
    left = [bm.verts.new(B((x0, y, z))) for z, y in profile]
    right = [bm.verts.new(B((x1, y, z))) for z, y in profile]
    bm.faces.new(left)
    bm.faces.new(list(reversed(right)))
    n = len(profile)
    for i in range(n):
        j = (i + 1) % n
        bm.faces.new((left[i], left[j], right[j], right[i]))
    return finish(new_obj(bm), bev, segs, 30, clamp)


def piece(name, slot, parts, colour=None, material=None):
    """Joins `parts` into one named mesh in a paint slot (fixed pieces give their own colour/material)."""
    for o in bpy.context.selected_objects:
        o.select_set(False)
    for o in parts:
        o.select_set(True)
    bpy.context.view_layer.objects.active = parts[0]
    if len(parts) > 1:
        bpy.ops.object.join()
    ob = bpy.context.view_layer.objects.active
    ob.name = name
    ob.data.name = name
    bpy.ops.object.shade_smooth_by_angle(angle=math.radians(35))
    if slot != "fixed":
        colour = SLOTS[slot]["colour"]
        material = SLOTS[slot]["material"]
    ob.data.materials.clear()
    ob.data.materials.append(mat(colour))
    box_uv(ob)
    PIECES[name] = ob
    INFO[name] = {"slot": slot, "colour": colour, "material": material or "SmoothPlastic"}
    return ob


PAINT_STUDS = 4.0  # the paint set's tile (style.json vehicle_paint "studs")


def box_uv(ob):
    """Box-projected UVs in studs / PAINT_STUDS (each face takes the plane across its strongest normal axis), so the
    shared tiling paint set lands at the same scale on every piece."""
    me = ob.data
    uv = me.uv_layers.new(name="UVMap") if not me.uv_layers else me.uv_layers[0]
    for poly in me.polygons:
        n = poly.normal
        ax = max(range(3), key=lambda i: abs(n[i]))
        u_ax, v_ax = {0: (1, 2), 1: (0, 2), 2: (0, 1)}[ax]
        flip = -1 if n[ax] < 0 else 1
        for li in poly.loop_indices:
            co = me.vertices[me.loops[li].vertex_index].co
            uv.data[li].uv = (flip * co[u_ax] / PAINT_STUDS, co[v_ax] / PAINT_STUDS)


def mirrored(fn):
    """fn(side) for side -1 and +1."""
    return [fn(-1), fn(1)]


def sx(side, a, b):
    """The x range a..b (a, b >= 0) on one side."""
    return (min(side * a, side * b), max(side * a, side * b))



# ===================================================================================================
# Size B "Moving Van" (owner pick 2026-11-04, docs/superpowers/specs/2026-11-04-truck-size-design.md): the inside is
# BED_W x BED_L with a CEIL ceiling. HB / LH are the bed's half width / half length: the box's inner walls.
# ===================================================================================================
BED_W, BED_L, CEIL = 16.0, 24.0, 10.0
HB, LH = BED_W / 2, BED_L / 2
S = 1.2  # the cab's scale (v2's cab, built at v2's numbers, then scaled from the ground at its back)
CZ = LH + 0.6  # where the cab's back now starts (v2: 8.6)
CAB_TOP = -3 + 9.7 * S
ROOF_Y0, ROOF_Y1 = CEIL + 0.045, CEIL + 0.795
BOX_FRONT = LH + 0.5


def cab_pt(p):
    """A v2 cab point in this truck's deck space."""
    return (p[0] * S, -3 + (p[1] + 3) * S, CZ + (p[2] - 8.6) * S)


CAB_M = Matrix.Translation((0, CZ - 8.6 * S, -3 + 3 * S)) @ Matrix.Diagonal((S, S, S, 1))


def cab(parts):
    """v2's cab parts (built at v2's numbers), scaled and moved onto this truck. Blender = (-x, z, y)."""
    for ob in parts:
        ob.data.transform(CAB_M)
    return parts


# ---- the box ---------------------------------------------------------------------------------------
BOX_Y0, BOX_Y1 = -0.3, CEIL + 0.07
WALL_Z0 = -(LH - 0.1)
piece(
    "BoxShell",
    "box",
    [
        *mirrored(lambda s: rbox(*sx(s, HB, HB + 0.5), BOX_Y0, BOX_Y1, WALL_Z0, BOX_FRONT, 0.06, 0.45, (("y", s, 1),))),
        rbox(-HB - 0.5, HB + 0.5, BOX_Y0, BOX_Y1, LH, BOX_FRONT, 0.06),
    ],
)
# The roof is the loaf's crust: a thick cap whose long and end edges are rounded right over (all of it above the
# ceiling lining, so nothing hangs into the bed).
ROOF_TOP = ROOF_Y0 + 1.6
piece(
    "BoxRoof",
    "box",
    [rbox(-HB - 0.5, HB + 0.5, ROOF_Y0, ROOF_TOP, -(LH + 0.2), BOX_FRONT, 0.06, 0.85, (("z", 0, 1), ("x", 0, 1)), 12)],
)
# The swoosh: a wave of grape that rises toward the cab, one strip on each side (BAND_PIECE; no line on it, owner Q6).
WAVE_MID, WAVE_AMP, WAVE_HALF = 4.9, 0.95, 0.85
BAND_Z0, BAND_Z1 = -(LH - 0.25), LH + 0.05


def wave_y(z):
    t = (z - BAND_Z0) / (BAND_Z1 - BAND_Z0)
    return WAVE_MID + WAVE_AMP * math.sin(2 * math.pi * 1.15 * t - 0.6)


def wave_profile():
    zs = [BAND_Z0 + (BAND_Z1 - BAND_Z0) * i / 48 for i in range(49)]
    return [(z, wave_y(z) - WAVE_HALF) for z in zs] + [(z, wave_y(z) + WAVE_HALF) for z in reversed(zs)]


piece("BoxBand", "band", mirrored(lambda s: prism_x(wave_profile(), *sx(s, HB + 0.49, HB + 0.57), 0.02, 2)))
BAND_Y0 = round(min(wave_y(BAND_Z0 + (BAND_Z1 - BAND_Z0) * i / 48) for i in range(49)) - WAVE_HALF, 3)
BAND_Y1 = round(max(wave_y(BAND_Z0 + (BAND_Z1 - BAND_Z0) * i / 48) for i in range(49)) + WAVE_HALF, 3)
# The portholes: a row of round windows along the top of each side, glowing warm (the bakery's ovens).
PORT_Y, PORT_ZS = CEIL - 1.55, (-9.0, -4.5, 0.0, 4.5, 9.0)
piece(
    "PortholeRims",
    "metal",
    [cyl("x", (s * (HB + 0.53), PORT_Y, z), 0.8, 0.14, 0.05, 32) for s in (-1, 1) for z in PORT_ZS],
)
piece(
    "PortholeGlass",
    "fixed",
    [dome((s * (HB + 0.6), PORT_Y, z), 0.62, (0.22, 1, 1), 28, 10) for s in (-1, 1) for z in PORT_ZS],
    PORTHOLE,
    "Neon",
)
piece(
    "BoxCorners",
    "trim",
    [
        # chunky caps: the box's front bottom corners
        *[rbox(*sx(s, HB - 0.05, HB + 0.75), -0.55, 0.45, LH - 0.15, LH + 0.85, 0.08, 0.28, (("y", s, 1),)) for s in (-1, 1)],
    ],
)
# The lore find (owner Q5): the faded, painted-over old company sign (lore_sign.png) low on the right wall toward the
# back, under the swoosh. The game draws it on BoxShell's Right face (whose box is the wall's outer surface): the
# rectangle in that face's SurfaceGui is in the JSON's "loreSign".
LORE_X, LORE_Y0, LORE_Y1, LORE_Z0, LORE_Z1 = HB + 0.5, 1.2, 3.0, -10.9, -4.9
piece("BoxRail", "trim", mirrored(lambda s: rbox(*sx(s, HB + 0.3, HB + 0.75), -0.6, 0.15, -(LH - 0.3), LH - 0.05, 0.12)))

# ---- back frame (the scanner arch) ------------------------------------------------------------------------------
AZ0, AZ1 = -(LH + 0.95), -(LH - 0.35)  # the posts' depth (v2: -8.95..-7.65)
piece(
    "ScannerArch",
    "trim",
    [
        *mirrored(lambda s: rbox(*sx(s, HB, HB + 1.2), -0.75, CEIL + 0.47, AZ0, AZ1, 0.12)),
        rbox(-HB - 1.2, HB + 1.2, CEIL + 0.07, CEIL + 1.77, AZ0 - 0.1, AZ1 + 0.1, 0.12, 1.4, (("z", 0, 1),), 8),
        *mirrored(lambda s: rbox(*sx(s, HB - 0.1, HB + 1.3), -0.95, -0.45, AZ0 - 0.1, AZ1 + 0.1, 0.1)),
        *[dome((s * (HB + 0.6), y, AZ0 - 0.03), 0.16, (1, 1, 0.5), 12, 6) for s in (-1, 1) for y in (0.0, CEIL - 0.43)],
        *[dome((s * (HB - 0.4), CEIL + 1.37, AZ0 - 0.13), 0.16, (1, 1, 0.5), 12, 6) for s in (-1, 1)],
    ],
)
piece(
    "ScannerLight",
    "fixed",
    [
        rounded(-4.8, 4.8, CEIL + 0.69, CEIL + 1.19, AZ0 - 0.18, AZ0 - 0.05, 0.24, "z", 0.02),
        *mirrored(lambda s: rounded(*sx(s, HB + 0.42, HB + 0.78), 1.6, CEIL - 1.2, AZ0 - 0.09, AZ0 + 0.03, 0.17, "z", 0.02)),
    ],
    SCANNER,
    "Neon",
)

# ---- roll-up door -------------------------------------------------------------------------------------------------
DRUM_Y, DRUM_Z = CEIL - 0.38, -(LH - 0.55)
piece(
    "RollDrum",
    "trim",
    [
        cyl("x", (0, DRUM_Y, DRUM_Z), 0.45, 2 * HB - 0.2, 0.06, 28),
        *mirrored(lambda s: rbox(*sx(s, HB - 0.25, HB), CEIL - 0.93, CEIL + 0.02, -(LH - 0.15), -(LH - 0.95), 0.06)),
    ],
)
piece(
    "RollDoor",
    "box",
    [
        rbox(-HB + 0.25, HB - 0.25, CEIL - 1.07, CEIL - 0.81, -(LH - 0.34), -(LH - 0.48), 0.03),
        rbox(-0.8, 0.8, CEIL - 1.19, CEIL - 1.07, -(LH - 0.3), -(LH - 0.42), 0.03),
    ],
)

# ---- the box inside (fixed) -----------------------------------------------------------------------------------
piece(
    "BoxLining",
    "fixed",
    [
        *mirrored(lambda s: rbox(*sx(s, HB - 0.07, HB - 0.01), 0.0, CEIL + 0.06, -(LH - 0.05), LH - 0.03, 0)),
        rbox(-HB + 0.01, HB - 0.01, 0.0, CEIL + 0.06, LH - 0.06, LH, 0),
        rbox(-HB + 0.01, HB - 0.01, CEIL, CEIL + 0.06, -(LH - 0.05), LH, 0),
    ],
    LINING,
)
piece("BoxFloor", "fixed", [rbox(-HB + 0.05, HB - 0.05, 0.0, 0.06, -(LH - 0.05), LH - 0.05, 0)], FLOOR)
piece(
    "FloorSeams",
    "fixed",
    [rbox(-HB + 0.1, HB - 0.1, 0.06, 0.07, z - 0.03, z + 0.03, 0) for z in range(-int(LH) + 2, int(LH) - 1, 2)]
    + [rbox(x - 0.03, x + 0.03, 0.06, 0.07, -(LH - 0.1), LH - 0.1, 0) for x in range(-int(HB) + 2, int(HB) - 1, 2)],
    FLOOR_SEAM,
)
piece(
    "InteriorTrim",
    "fixed",
    [
        *mirrored(lambda s: rbox(*sx(s, HB - 0.22, HB - 0.07), 0.06, CEIL, LH - 0.4, LH - 0.06, 0.03)),
        *mirrored(lambda s: rbox(*sx(s, HB - 0.15, HB - 0.07), 0.06, 0.5, -(LH - 0.1), LH - 0.06, 0.02)),
        *mirrored(lambda s: rbox(*sx(s, HB - 0.15, HB - 0.07), CEIL - 0.23, CEIL, -(LH - 0.1), LH - 0.06, 0.02)),
        rbox(-HB + 0.15, HB - 0.15, 0.06, 0.5, LH - 0.14, LH - 0.06, 0.02),
    ],
    INNER_TRIM,
)
piece(
    "CeilingLamp",
    "fixed",
    [rounded(-1.6, 1.6, CEIL - 0.09, CEIL, z0, z1, 0.35, "y", 0.02) for z0, z1 in ((-7.0, -3.0), (2.0, 6.0))],
    CEILING_LAMP,
    "Neon",
)

# ===================================================================================================
# The cab: a round 1950s bubble cab, built at v2's numbers (x +-CAB_X, ground y -3, back z 8.6) and scaled S onto
# this truck (cab()). Its hood and roof are one rounded side profile, its sides rounded over by a fat bevel.
# ===================================================================================================
CAB_X = 5.2
CAB_FRONT = 14.5  # the face under the windscreen (v2: 14.1)
WS_Y0, WS_Y1, WS_TOP_Z = 2.6, 6.9, 13.3
WS_SLOPE = math.atan2(CAB_FRONT - WS_TOP_Z, WS_Y1 - WS_Y0)
piece(
    "CabBody",
    "cab",
    cab(
        [
            prism_x(
                round_profile(
                    [(8.6, 0.1), (12.85, 0.1), (12.85, -0.9), (CAB_FRONT - 0.2, -0.9), (CAB_FRONT, WS_Y0), (WS_TOP_Z, WS_Y1), (8.6, WS_Y1)],
                    (0.3, 0.25, 0.3, 0.9, 1.6, 2.4, 1.6),
                    10,
                ),
                -CAB_X,
                CAB_X,
                0.95,
                7,
                False,
            ),
        ]
    ),
)
# The mint beacon on the cab roof (the pod in the cab's colour carries Socket_Roof).
POD = cab_pt((0, WS_Y1 - 0.05, 10.6))
piece("CabRoofPod", "cab", [cyl("y", (POD[0], POD[1] + 0.12, POD[2]), 0.85, 0.3, 0.06, 28)])
piece(
    "RoofBeacon",
    "fixed",
    [
        cyl("y", (POD[0], POD[1] + 0.55, POD[2]), 0.58, 0.6, 0.04, 24),
        dome((POD[0], POD[1] + 0.85, POD[2]), 0.58, (1, 0.75, 1), 24, 10),
    ],
    MINT,
    "Neon",
)
POD_TOP = (POD[0], POD[1] + 0.27, POD[2])


def on_ws(y, out):
    z = CAB_FRONT - (y - WS_Y0) * math.tan(WS_SLOPE)
    return (y + out * math.sin(WS_SLOPE), z + out * math.cos(WS_SLOPE))


wy, wz = on_ws(4.6, 0.04)
piece(
    "CabWindows",
    "fixed",
    cab(
        [
            *mirrored(lambda s: rbox(*sx(s, 0.22, 4.2), wy - 1.3, wy + 1.3, wz - 0.04, wz + 0.04, 0.02, 0.6, (("z", 0, 0),), tilt=("x", WS_SLOPE))),
            *mirrored(lambda s: rbox(*sx(s, CAB_X - 0.03, CAB_X + 0.04), 3.4, 5.7, 10.0, 12.6, 0.02, 0.6, (("x", 0, 0),))),
        ]
    ),
    GLASS,
    "Glass",
)
# the split windscreen's middle bar, in the cab's colour
piece("CabPillar", "cab", cab([rbox(-0.25, 0.25, wy - 1.45, wy + 1.45, wz - 0.02, wz + 0.1, 0.04, tilt=("x", WS_SLOPE))]))
piece(
    "Wipers",
    "fixed",
    cab(
        [
            rbox(x - 1.1, x + 1.1, wy - 1.27, wy - 1.17, wz + 0.04, wz + 0.14, 0.02, tilt=("z", math.radians(14) * (1 if x < 0 else -1)))
            for x in (-2.2, 2.0)
        ]
    ),
    CHASSIS,
)
piece(
    "MirrorArms",
    "cab",
    cab(
        [
            *mirrored(lambda s: cyl("x", (s * 5.75, 4.05, 12.6), 0.1, 1.1, 0.0, 10)),
            *mirrored(lambda s: cyl("y", (s * 6.3, 4.5, 12.6), 0.1, 0.95, 0.0, 10)),
        ]
    ),
)
# round mirrors (a cream back, like the bumper)
piece("MirrorHeads", "trim", cab(mirrored(lambda s: cyl("z", (s * 6.3, 5.25, 12.6), 0.55, 0.3, 0.08, 28))))
piece("Handles", "metal", cab(mirrored(lambda s: rbox(*sx(s, CAB_X - 0.02, CAB_X + 0.1), 2.75, 2.97, 9.15, 9.95, 0.04))))
# big round headlights high on the front corners, in deep cream bezels
HL = (3.75, 1.5)
piece("LampBezels", "trim", cab(mirrored(lambda s: cyl("z", (s * HL[0], HL[1], CAB_FRONT + 0.02), 1.22, 0.32, 0.1, 32))))
piece("Headlights", "fixed", cab(mirrored(lambda s: dome((s * HL[0], HL[1], CAB_FRONT + 0.18), 0.98, (1, 1, 0.3), 28, 10))), LAMP, "Neon")
# the bar grille: a rounded frame with four round bars across
piece(
    "Grille",
    "trim",
    cab(
        [
            rbox(-1.95, 1.95, -0.55, 2.35, CAB_FRONT - 0.1, CAB_FRONT + 0.16, 0.05, 0.75, (("z", 0, 0),), 8),
            *[cyl("x", (0, y, CAB_FRONT + 0.2), 0.16, 3.1, 0.0, 14) for y in (0.0, 0.55, 1.1, 1.65)],
        ]
    ),
)
piece("GrilleBack", "fixed", cab([rbox(-1.65, 1.65, -0.3, 2.1, CAB_FRONT + 0.15, CAB_FRONT + 0.19, 0, 0.55, (("z", 0, 0),))]), GRILLE_BACK)
piece(
    "Bumpers",
    "trim",
    [
        # one fat rounded bar across the front
        *cab([rounded(-5.5, 5.5, -1.95, -0.85, CAB_FRONT - 0.3, CAB_FRONT + 0.45, 0.5, "x", 0.06)]),
        # the back: blocks under the frame that carry the tail lights
        *mirrored(lambda s: rbox(*sx(s, HB - 1.8, HB + 0.05), -1.65, -0.55, -(LH + 0.8), -(LH - 0.25), 0.2, segs=3)),
    ],
)
piece(
    "MarkerLights",
    "fixed",
    [
        *cab(mirrored(lambda s: dome((s * 3.75, -0.1, CAB_FRONT + 0.02), 0.32, (1, 0.7, 0.4), 16, 8))),
        *mirrored(lambda s: rbox(*sx(s, HB + 1.19, HB + 1.26), CEIL + 0.62, CEIL + 1.12, AZ0 + 0.3, AZ1 - 0.3, 0.02)),
    ],
    AMBER,
    "Neon",
)
piece(
    "TailLights",
    "fixed",
    mirrored(lambda s: rounded(*sx(s, HB - 1.45, HB - 0.3), -1.35, -0.85, -(LH + 0.86), -(LH + 0.78), 0.2, "z", 0.02)),
    RED,
    "Neon",
)

# ===================================================================================================
# Running gear: v2's wheels; the front pair under the scaled cab, a tandem pair under the box's back
# ===================================================================================================
WHEEL_R = 1.5
WHEEL_Y = G + WHEEL_R
TYRE_W = 1.6
WHEEL_X_REAR = HB - 0.3  # the tyre's outer face sits flush with the box's wall
WHEEL_X_FRONT = 5.75 * S
FRONT_Z = cab_pt((0, 0, 11.2))[2]
AXLES = ((-6.0, WHEEL_X_REAR), (-9.3, WHEEL_X_REAR), (FRONT_Z, WHEEL_X_FRONT))
tyres, hubs, fenders = [], [], []
for z, wx in AXLES:
    for s in (-1, 1):
        c = (s * wx, WHEEL_Y, z)
        tyres.append(cyl("x", c, WHEEL_R - 0.08, TYRE_W, 0.3, 28))
        n = 18
        for i in range(n):
            bm = bmesh.new()
            bmesh.ops.create_cube(bm, size=1.0)
            hw = TYRE_W / 2 - 0.12
            for v in bm.verts:
                v.co = B((c[0] + (hw if v.co.x > 0 else -hw), c[1] + (WHEEL_R if v.co.y > 0 else WHEEL_R - 0.2), z + (0.22 if v.co.z > 0 else -0.22)))
            spin(bm, "x", 2 * math.pi * i / n, c)
            tyres.append(finish(new_obj(bm), 0.05, 1))
        out = s * (wx + TYRE_W / 2)
        hubs.append(cyl("x", (out - s * 0.02, WHEEL_Y, z), 1.02, 0.14, 0.04, 24))
        hubs.append(dome((out + s * 0.05, WHEEL_Y, z), 0.55, (0.42, 1, 1), 16, 8))
        if z > 0:
            fenders.append(arc_x((0, WHEEL_Y, z), WHEEL_R + 0.15, WHEEL_R + 0.75, *sx(s, 4.6 * S, 6.85 * S), segs=20, bev=0.14))
        else:
            # under the box: the flare stays outside the lining (x > HB), so it never shows inside the bed
            fenders.append(arc_x((0, WHEEL_Y, z), WHEEL_R + 0.15, WHEEL_R + 0.7, *sx(s, HB, HB + 0.95), segs=20, bev=0.12))
piece("Tires", "fixed", tyres, TYRE)
piece("Hubs", "metal", hubs)
piece("Fenders", "cab", fenders)
piece(
    "Chassis",
    "fixed",
    [
        *mirrored(lambda s: rbox(*sx(s, 4.4, 5.2), -1.6, -0.45, -(LH - 0.1), cab_pt((0, 0, 13.9))[2], 0.08)),
        rbox(-HB + 0.05, HB - 0.05, -0.45, -0.05, -(LH - 0.1), LH + 0.45, 0),
        rbox(-HB - 0.1, HB + 0.1, -1.5, -0.6, -(LH + 0.3), -(LH - 0.3), 0.1),
        *cab([rbox(-4.6, 4.6, -1.0, 0.1, 8.5, 12.85, 0.1)]),
        *[cyl("x", (0, WHEEL_Y, z), 0.28, 2 * wx - 1.2, 0.0, 10) for z, wx in AXLES],
    ],
    CHASSIS,
)
piece(
    "SideBoxes",
    "trim",
    mirrored(lambda s: rbox(*sx(s, HB - 1.1, HB + 0.15), -2.05, -0.7, -2.6, 9.4, 0.15, segs=3)),
)

# ===================================================================================================
# The ramp: v2's ramp, wider for the wider doorway; same slope (the deck stays at 3)
# ===================================================================================================
RAMP_W = 9.4
slope = math.atan2(DECK, RAMP_LEN)
length = math.hypot(DECK, RAMP_LEN)
up = Vector((0, math.sin(slope), math.cos(slope)))
normal = Vector((0, math.cos(slope), -math.sin(slope)))
mid = Vector((0, -DECK / 2, -LH - RAMP_LEN / 2))
T = 0.3


def on_ramp(u, v, x=0.0):
    p = mid + up * u + normal * v
    return (x, p.y, p.z)


def ramp_box(u, v, x, size, bev):
    c = on_ramp(u, v, x)
    return rbox(c[0] - size[0] / 2, c[0] + size[0] / 2, c[1] - size[1] / 2, c[1] + size[1] / 2, c[2] - size[2] / 2, c[2] + size[2] / 2, bev, tilt=("x", slope))


ribs = [ramp_box(-length / 2 + 0.55 + i * (length - 1.1) / 6, 0.07, 0, (RAMP_W - 1.0, 0.14, 0.24), 0.05) for i in range(7)]
piece("Ramp", "fixed", [ramp_box(0, -T / 2, 0, (RAMP_W, T, length), 0.08)] + ribs, RAMP)
piece(
    "RampRails",
    "trim",
    [
        ramp_box(0, 0.08, -(RAMP_W / 2 + 0.05), (0.36, 0.46, length + 0.05), 0.12),
        ramp_box(0, 0.08, RAMP_W / 2 + 0.05, (0.36, 0.46, length + 0.05), 0.12),
        ramp_box(-length / 2 + 0.18, 0.02, 0, (RAMP_W + 0.4, 0.24, 0.36), 0.08),
        rbox(-RAMP_W / 2 - 0.4, RAMP_W / 2 + 0.4, -0.08, 0.04, -(LH + 0.25), -(LH - 0.25), 0.04),
        *mirrored(lambda s: rbox(*sx(s, RAMP_W / 2 - 0.2, RAMP_W / 2 + 0.4), -0.3, 0.12, -(LH + 0.35), -(LH - 0.15), 0.06)),
    ],
)

# ===================================================================================================
# Sockets (accessories, batch 6) and interior slots: attachments, deck space. Parented to a piece on import.
# ===================================================================================================
ATTACHMENTS = {
    "Socket_Roof": ("CabRoofPod", POD_TOP, (0, 0, 1), (0, 1, 0)),
    "Socket_Front": ("Bumpers", cab_pt((0, -1.4, CAB_FRONT + 0.45)), (0, 0, 1), (0, 1, 0)),
    "Socket_SideL": ("BoxBand", (-(HB + 0.56), (BAND_Y0 + BAND_Y1) / 2, (BAND_Z0 + BAND_Z1) / 2), (-1, 0, 0), (0, 1, 0)),
    "Socket_SideR": ("BoxBand", (HB + 0.56, (BAND_Y0 + BAND_Y1) / 2, (BAND_Z0 + BAND_Z1) / 2), (1, 0, 0), (0, 1, 0)),
    "Socket_Mirror": ("MirrorHeads", cab_pt((-6.3, 4.7, 12.6)), (0, 0, 1), (0, 1, 0)),
    "Socket_Horn": ("Bumpers", cab_pt((0, -0.6, CAB_FRONT + 0.2)), (0, 0, 1), (0, 1, 0)),
    # interior: inert, within 1.2 of a wall, above the deck; never on the floor
    "Interior_Ceiling": ("BoxLining", (0, CEIL, 0), (0, -1, 0), (0, 0, 1)),
    "Interior_WallL": ("BoxLining", (-(HB - 0.07), CEIL * 0.6, 0), (1, 0, 0), (0, 1, 0)),
    "Interior_WallR": ("BoxLining", (HB - 0.07, CEIL * 0.6, 0), (-1, 0, 0), (0, 1, 0)),
}
ATTACHMENTS = {k: (p, tuple(round(c, 4) for c in pos), lk, u) for k, (p, pos, lk, u) in ATTACHMENTS.items()}
for name, (parent, pos, look, upv) in ATTACHMENTS.items():
    e = bpy.data.objects.new(name, None)
    e.empty_display_type = "ARROWS"
    e.empty_display_size = 0.6
    e.location = B(pos)
    e.rotation_euler = B(look).to_track_quat("Z", "Y" if abs(look[1]) < 0.9 else "X").to_euler()
    e["parent_piece"] = parent
    COLL.objects.link(e)


# ===================================================================================================
# Metadata
# ===================================================================================================
meta = {
    "deck": DECK,
    "bed": [BED_W, DECK, BED_L],
    "ceiling": CEIL,
    "rampLength": RAMP_LEN,
    "slots": SLOTS,
    "pieces": {},
    "attachments": {},
    "triangles": 0,
}
for name, ob in PIECES.items():
    vs = [ob.matrix_world @ v.co for v in ob.data.vertices]
    mn = [min(v[i] for v in vs) for i in range(3)]
    mx = [max(v[i] for v in vs) for i in range(3)]
    centre = [-(mn[0] + mx[0]) / 2, (mn[2] + mx[2]) / 2, (mn[1] + mx[1]) / 2]
    size = [mx[0] - mn[0], mx[2] - mn[2], mx[1] - mn[1]]
    tris = sum(len(p.vertices) - 2 for p in ob.data.polygons)
    assert tris < 20000, (name, tris)
    meta["pieces"][name] = {
        "centre": [round(c, 4) for c in centre],
        "size": [round(s, 4) for s in size],
        **INFO[name],
        "triangles": tris,
    }
    meta["triangles"] += tris
shell = meta["pieces"]["BoxShell"]
sz0, sz1 = shell["centre"][2] - shell["size"][2] / 2, shell["centre"][2] + shell["size"][2] / 2
sy0, sy1 = shell["centre"][1] - shell["size"][1] / 2, shell["centre"][1] + shell["size"][1] / 2
assert abs(shell["centre"][0] + shell["size"][0] / 2 - LORE_X) < 0.01, "BoxShell's Right face must be the wall's surface"
# Seen from +X (the Right face) the left edge is toward +Z; UDim2 scales within that face.
meta["loreSign"] = {
    "piece": "BoxShell",
    "face": "Right",
    "position": [round((sz1 - LORE_Z1) / (sz1 - sz0), 4), round((sy1 - LORE_Y1) / (sy1 - sy0), 4)],
    "size": [round((LORE_Z1 - LORE_Z0) / (sz1 - sz0), 4), round((LORE_Y1 - LORE_Y0) / (sy1 - sy0), 4)],
}
for name, (parent, pos, look, upv) in ATTACHMENTS.items():
    meta["attachments"][name] = {"parent": parent, "position": list(pos), "look": list(look), "up": list(upv)}
with open(f"{OUT}/Truck_v4.json", "w", encoding="utf-8") as f:
    json.dump(meta, f, indent=1)
print("TRIS", meta["triangles"], "PIECES", len(PIECES))

for o in bpy.context.selected_objects:
    o.select_set(False)
for o in PIECES.values():
    o.select_set(True)
bpy.ops.export_scene.fbx(
    filepath=f"{OUT}/Truck_v4.fbx",
    use_selection=True,
    object_types={"MESH"},
    apply_unit_scale=True,
    apply_scale_options="FBX_SCALE_UNITS",
    axis_forward="-Z",
    axis_up="Y",
    use_mesh_modifiers=True,
    mesh_smooth_type="FACE",
    use_custom_props=False,
    path_mode="STRIP",
)
bpy.ops.wm.save_as_mainfile(filepath=f"{OUT}/Truck_v4.blend")
if not RENDER:
    sys.exit(0)

# ===================================================================================================
# Renders (EEVEE): a night yard look, the box lamp on
# ===================================================================================================
scene.render.engine = "BLENDER_EEVEE"
world = bpy.data.worlds.new("w")
scene.world = world
world.use_nodes = True
world.node_tree.nodes["Background"].inputs[0].default_value = (0.36, 0.33, 0.40, 1)
world.node_tree.nodes["Background"].inputs[1].default_value = 0.9
for nm, rot, en in (("key", (50, 10, -35), 3.0), ("rim", (60, 0, 160), 1.5)):
    ld = bpy.data.lights.new(nm, "SUN")
    ld.energy = en
    ld.angle = math.radians(25)
    lo = bpy.data.objects.new(nm, ld)
    lo.rotation_euler = [math.radians(v) for v in rot]
    scene.collection.objects.link(lo)
lamp = bpy.data.lights.new("box_lamp", "AREA")
lamp.energy = 1000
lamp.size = 9
lamp.color = (1.0, 0.88, 0.65)
lo = bpy.data.objects.new("box_lamp", lamp)
lo.location = B((0, CEIL - 0.4, 0))
scene.collection.objects.link(lo)

GLOWS = {MINT: 2.0, LAMP: 1.6, AMBER: 1.5, RED: 1.5, SCANNER: 1.5, CEILING_LAMP: 1.5, PORTHOLE: 1.4}
for hexv, m in list(MATS.items()):
    m.use_nodes = True
    bsdf = m.node_tree.nodes["Principled BSDF"]
    bsdf.inputs["Base Color"].default_value = m.diffuse_color
    bsdf.inputs["Roughness"].default_value = 0.5
    if hexv in GLOWS:
        bsdf.inputs["Emission Color"].default_value = m.diffuse_color
        bsdf.inputs["Emission Strength"].default_value = GLOWS[hexv]
    if hexv == GLASS:
        bsdf.inputs["Alpha"].default_value = 0.8
        bsdf.inputs["Roughness"].default_value = 0.1
        m.surface_render_method = "BLENDED"
    if hexv == SLOTS["metal"]["colour"]:
        bsdf.inputs["Metallic"].default_value = 0.6
        bsdf.inputs["Roughness"].default_value = 0.35

# The texture pass in the renders: every paint-slot material is the shared paint set tinted by its slot colour.
import os

TEX = os.path.join(os.environ.get("TEXPIPE_WORK", "F:/Dev/temp/claude/texwork"), "textures")
SLOT_HEX = {v["colour"] for v in SLOTS.values()}
paint = {k: bpy.data.images.load(os.path.join(TEX, f"truck_paint_{k}.png")) for k in ("color", "normal", "rough")}
paint["normal"].colorspace_settings.name = "Non-Color"
paint["rough"].colorspace_settings.name = "Non-Color"
for hexv, m in list(MATS.items()):
    if hexv not in SLOT_HEX:
        continue
    nt = m.node_tree
    bsdf = nt.nodes["Principled BSDF"]
    col = nt.nodes.new("ShaderNodeTexImage")
    col.image = paint["color"]
    mix = nt.nodes.new("ShaderNodeMix")
    mix.data_type = "RGBA"
    mix.blend_type = "MULTIPLY"
    mix.inputs["Factor"].default_value = 1.0
    mix.inputs["A"].default_value = m.diffuse_color
    nt.links.new(col.outputs["Color"], mix.inputs["B"])
    nt.links.new(mix.outputs["Result"], bsdf.inputs["Base Color"])
    nrm = nt.nodes.new("ShaderNodeTexImage")
    nrm.image = paint["normal"]
    nmap = nt.nodes.new("ShaderNodeNormalMap")
    nt.links.new(nrm.outputs["Color"], nmap.inputs["Color"])
    nt.links.new(nmap.outputs["Normal"], bsdf.inputs["Normal"])
    rgh = nt.nodes.new("ShaderNodeTexImage")
    rgh.image = paint["rough"]
    nt.links.new(rgh.outputs["Color"], bsdf.inputs["Roughness"])

# the lore sign: the decal over LoreSign's outer face (+X), as the game's Decal on its Right face draws it
LORE = os.path.join(os.path.dirname(os.path.abspath(__file__)), "lore_sign.png")
if os.path.exists(LORE):
    img = bpy.data.images.load(LORE)
    lm = bpy.data.materials.new("Lore")
    lm.use_nodes = True
    nt = lm.node_tree
    tex = nt.nodes.new("ShaderNodeTexImage")
    tex.image = img
    bsdf = nt.nodes["Principled BSDF"]
    nt.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
    nt.links.new(tex.outputs["Alpha"], bsdf.inputs["Alpha"])
    bsdf.inputs["Roughness"].default_value = 0.5
    lm.surface_render_method = "BLENDED"
    lb = bmesh.new()
    uv = lb.loops.layers.uv.new()
    x = LORE_X + 0.03
    # seen from +X the image's left edge is toward +Z (the cab)
    corners = [(LORE_Z1, LORE_Y0, 0, 0), (LORE_Z0, LORE_Y0, 1, 0), (LORE_Z0, LORE_Y1, 1, 1), (LORE_Z1, LORE_Y1, 0, 1)]
    vs = [lb.verts.new(B((x, y, z))) for z, y, _, _ in corners]
    face = lb.faces.new(vs)
    for loop, (_, _, u, v) in zip(face.loops, corners):
        loop[uv].uv = (u, v)
    bmesh.ops.recalc_face_normals(lb, faces=lb.faces)
    me = bpy.data.meshes.new("lore")
    lb.to_mesh(me)
    lb.free()
    lob = bpy.data.objects.new("LoreDecal", me)
    scene.collection.objects.link(lob)
    lob.data.materials.append(lm)

gb = bmesh.new()
bmesh.ops.create_grid(gb, x_segments=1, y_segments=1, size=60)
bmesh.ops.translate(gb, vec=Vector((0, 0, G)), verts=gb.verts)
ground = new_obj(gb)
ground.data.materials.append(mat("#55525C"))
m = MATS["#55525C"]
m.use_nodes = True
m.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = m.diffuse_color

if LIVERY:
    # the game's SurfaceGui on BoxBand's Left/Right faces: the band's outer face, its whole height and length
    img = bpy.data.images.load(LIVERY)
    lm = bpy.data.materials.new("Livery")
    lm.use_nodes = True
    nt = lm.node_tree
    tex = nt.nodes.new("ShaderNodeTexImage")
    tex.image = img
    bsdf = nt.nodes["Principled BSDF"]
    nt.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
    nt.links.new(tex.outputs["Alpha"], bsdf.inputs["Alpha"])
    lm.surface_render_method = "BLENDED"
    for side in (-1, 1):
        lb = bmesh.new()
        uv = lb.loops.layers.uv.new()
        x = side * (HB + 0.565)
        z0, z1, y0, y1 = BAND_Z0, BAND_Z1, BAND_Y0, BAND_Y1
        if side < 0:  # Left face: seen from -X, its left edge is toward +Z (the cab)
            corners = [(z1, y0, 1, 0), (z0, y0, 0, 0), (z0, y1, 0, 1), (z1, y1, 1, 1)]
        else:  # Right face: seen from +X, its left edge is toward -Z
            corners = [(z0, y0, 1, 0), (z1, y0, 0, 0), (z1, y1, 0, 1), (z0, y1, 1, 1)]
        vs = [lb.verts.new(B((x, y, z))) for z, y, _, _ in corners]
        face = lb.faces.new(vs)
        for loop, (_, _, u, v) in zip(face.loops, corners):
            loop[uv].uv = (u, v)
        me = bpy.data.meshes.new("liv")
        lb.to_mesh(me)
        lb.free()
        lob = bpy.data.objects.new(f"Livery{side}", me)
        scene.collection.objects.link(lob)
        lob.data.materials.append(lm)

scene.view_settings.view_transform = "Standard"
scene.render.resolution_x = 1400
scene.render.resolution_y = 1000
scene.render.film_transparent = False
cam_data = bpy.data.cameras.new("cam")
cam_data.lens = 40
cam = bpy.data.objects.new("cam", cam_data)
scene.collection.objects.link(cam)
scene.camera = cam


def shoot(name, loc, target):
    cam.location = B(loc)
    cam.rotation_euler = (B(target) - B(loc)).to_track_quat("-Z", "Y").to_euler()
    scene.render.filepath = f"{OUT}/render_{name}.png"
    bpy.ops.render.render(write_still=True)



QUICK = "--quick" in sys.argv
if QUICK:
    scene.render.resolution_percentage = 50
shoot("front34", (34, 12, 42), (0, 2.5, 3))
shoot("back34", (-26, 10, -40), (0, 3, -6))
if QUICK:
    sys.exit(0)
shoot("side", (46, 6, 2), (0, 3, 2))
# the lore find: from the yard (a patchy panel) and up close (the old name)
shoot("lore_far", (HB + 16, 4, -12), (HB, 3, -7.9))
cam_data.lens = 50
shoot("lore_close", (HB + 4.2, 2.3, -7.9), (HB + 0.5, 2.1, -7.9))
cam_data.lens = 40
scene.render.resolution_x, scene.render.resolution_y = 700, 500
for i in range(8):
    a = 2 * math.pi * i / 8
    shoot(f"turn{i}", (50 * math.sin(a), 13, 50 * math.cos(a) + 2), (0, 3, 2))
scene.render.resolution_x, scene.render.resolution_y = 1400, 1000
if CHARS:
    # the crew inside at game scale (1.25): Pippa, Cappy, Prickles, plus a second row
    CREW = [
        ("pippa/v10/Pippa.blend", (-4.2, 0.0, -3.0)),
        ("cappy/v6_sneakers/Cappy.blend", (0.0, 0.0, 1.0)),
        ("prickles/v4/Prickles.blend", (4.2, 0.0, -5.0)),
    ]
    for path, at in CREW:
        with bpy.data.libraries.load(f"{CHARS}/{path}", link=False) as (src, dst):
            dst.objects = list(src.objects)
        objs = [o for o in dst.objects if o is not None and o.type in ("MESH", "ARMATURE")]
        rig = bpy.data.objects.new("crew", None)
        scene.collection.objects.link(rig)
        for o in objs:
            scene.collection.objects.link(o)
        bpy.context.view_layer.update()
        for o in objs:
            if o.parent is None:
                wm = o.matrix_world.copy()
                o.parent = rig
                o.matrix_world = wm
        rig.scale = (1.25, 1.25, 1.25)
        rig.location = B(at)
    shoot("crew_back", (-12, 10, -42), (0, 3.5, -4))
    cam_data.lens = 22
    shoot("crew_inside", (0, 5.2, -LH - 2.5), (0, 3.4, LH))
