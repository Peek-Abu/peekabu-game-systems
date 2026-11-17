# Showstopper Prickles REMAKE, step 1: blockout of every piece on the real Prickles body (T rest pose), sized from the
# concept (carnival-skins.png front, about 124 px per template unit: head 2.4 wide, ground to head top 3.96).
# Flat concept colours (sampled), no detail. Pipeline: ss_blockout.py (pieces) -> remake_skirt.py (coat skirt, cloth-
# draped over the new bloomers) -> ../showstopper_tails/ss_finish.py (skirt atlas + hem piping) -> render_blockout.py.
#   blender -b --disable-autoexec -P ss_blockout.py -- <out_dir>
import sys, math, os
sys.path.insert(0, 'E:/Projects/peekabu-game-systems/characters/skins/release/gloom_carnival/blockout')
import bpy
from mathutils import Vector, Matrix
import common as C

A = sys.argv[sys.argv.index('--') + 1:]
OUT = os.path.abspath(A[0]).replace(chr(92), '/')

rig = C.open_src('prickles')
body = C.proxy(['UpperTorso', 'LowerTorso', 'LeftUpperLeg', 'RightUpperLeg', 'LeftLowerLeg', 'RightLowerLeg',
                'LeftUpperArm', 'RightUpperArm', 'LeftLowerArm', 'RightLowerArm'])
C.hide(['HardHat_Head'])
# the outfit hides his own feet and shins, as the game skin does (HideParts): the earlier boots are slimmer than his legs
C.hide(['LeftFoot', 'RightFoot', 'LeftLowerLeg', 'RightLowerLeg', 'LeftUpperLeg', 'RightUpperLeg'])

# Concept colours (sampled from the concept render, sRGB).
plum = C.mat('plum', '#683256', .75)          # coat, sleeves (same plum as the skirt atlas)
plum_hat = C.mat('plum_hat', '#5A2A45', .7)   # hat crown + brim
drip = C.mat('drip', '#963E70', .6)           # lighter magenta goo drips (same as the skirt atlas drips)
cream = C.mat('cream', '#F3D4C2', .6)         # collar, lapels, hat diamonds
vest = C.mat('vest', '#E8C8A1', .6)           # waistcoat
gold = C.mat('gold', '#D9AA68', .35, .7)      # piping, toggles, cuffs, hat band, boot button
shirt = C.mat('shirt', '#2B2328', .7)
bloom = C.mat('bloom', '#54414A', .8)
bloom_dk = C.mat('bloom_dk', '#3D2E35', .8)
boot = C.mat('boot', '#5A2A3D', .6)


def front_arc(z, r, gap, n=64):
    """Ring at height z open at the front: from -90 deg + gap round the back to -90 deg - gap."""
    return [(r * math.cos(a), r * math.sin(a), z) for a in
            [-math.pi / 2 + gap + (2 * math.pi - 2 * gap) * i / (n - 1) for i in range(n)]]


def on_cyl(theta, z, r):
    return (r * math.cos(theta), r * math.sin(theta), z)


# ---------------- Hat: the EARLIER hat, unchanged (owner 11-16: "earlier hat was better"; props stay) ----------------
# route2_whole/hat_r33 (hat asset rev 7, no flower): already placed on his head in this same rest frame, at its game
# mount. His own flower stays where base Prickles wears it.
R2 = 'E:/Projects/peekabu-game-systems/characters/skins/release/gloom_carnival/route2_whole/'
with bpy.data.libraries.load(R2 + 'hat_r33/ShowHat_proj.blend') as (src, dst):
    dst.objects = ['ShowHat']
for o in dst.objects:
    bpy.context.scene.collection.objects.link(o); C.ADDED.append(o)

# ---------------- Shirt: dark collar and V ----------------
# kept under the head: the head's underside is at z 2.16-2.21 inside r 0.3 (it clipped at 2.40 before)
C.loft('Shirt_collar', [C.ring(z, r, r, n=48) for z, r in [(1.95, .43), (2.08, .38), (2.13, .33)]], shirt, 'UpperTorso', cap_top=True, cap_bottom=True)

# ---------------- Waistcoat: cream front panel, V neck, pointed hem, two gold double toggles ----------------
rows = []
NP, SPAN = 33, math.radians(72)
for j in range(9):
    t = j / 8
    row = []
    for i in range(NP):
        u = -1 + 2 * i / (NP - 1)
        bot = 1.20 + .14 * abs(u)                       # pointed at the centre
        top = 2.02 + .30 * abs(u) ** .8                 # V neck
        z = bot + (top - bot) * t
        row.append(on_cyl(-math.pi / 2 + u * SPAN, z, .5))
    rows.append(row)
w = C.loft('Waistcoat', rows, vest, 'UpperTorso', closed=False)
C.wrap(w, body, .02); C.solid(w, .03, 1); C.subd(w, 1)   # round 5: 0.05 under the robe's front edge (it sat level with it and clipped)
for k, z in enumerate([1.80, 1.52]):
    for s in (-1, 1):
        C.ell(f'Toggle_{k}_{s}', (s * .085, -.52, z), (.075, .045, .045), gold)
    C.cyl(f'Toggle_link_{k}', (0, -.52, z), .022, .12, gold, rot=(0, math.pi / 2, 0))

# Coat, lapels, collar and sleeves: built by ss_robe.py as ONE robe mesh (owner 11-16). No goo, no drips.

# ---------------- Bloomers: very puffy, pleated, gathered into a knee cuff ----------------
def pleat(a):
    return 1 + .035 * math.cos(10 * a)
seat = C.loft('Bloomer_seat', [C.ring(z, rx, ry, n=64, fn=pleat) for z, rx, ry in [(1.38, .46, .40), (1.26, .50, .44), (1.10, .60, .50), (0.94, .60, .48), (0.86, .40, .30)]], bloom, 'LowerTorso', cap_top=True, cap_bottom=True)
C.subd(seat, 1)
for s, side in [(1, 'L'), (-1, 'R')]:
    # round 5 (owner: holes at the bottom near the boots): ONE closed leg from the hip down INTO the boot shaft (shaft
    # radius 0.205, top 0.60), so a bent knee can never open a gap; the dark gathered cuff is a band of the same mesh,
    # not a loose ring (the old ring + flat cap opened at the knee in his idle).
    rows = [(1.10, .34), (0.98, .42), (0.84, .44), (0.74, .40), (0.66, .32), (0.61, .27), (0.56, .23), (0.50, .19), (0.44, .17)]
    lg = C.loft(f'Bloomer_leg_{side}', [C.ring(z, r, r * .92, cx=(.29 + (.31 - .29) * (1 - min(1, max(0, (z - .56) / .2)))) * s, n=48, fn=pleat)
                                         for z, r in rows], bloom, f'{side}UpperLeg', cap_top=True, cap_bottom=True)
    lg.data.materials.append(bloom_dk)
    for poly in lg.data.polygons:                     # the gathered cuff: dark band just above the boot top
        if .585 <= poly.center.z <= .665: poly.material_index = 1
    C.subd(lg, 1)

# ---------------- Boots: the EARLIER built boots, unchanged (owner 11-16: "more like socks than boots like earlier") --
# route2_whole/r2_built.boots(): straight shaft with a rolled rim, rounded toe box, sole, gold button, short cream sock
# band. Fitted to this same body. Renamed Boot_* so the skirt drape collides with them.
sys.path.insert(0, R2)
import r2_built
for o in r2_built.boots(boot, 'UVMap'):
    kind = next(k for k in ('Shaft', 'Boot', 'Button', 'Sock') if o.name.endswith(k))
    o.name = 'Boot_' + o.name[4:]
    o.data.materials.clear(); o.data.materials.append({'Button': gold, 'Sock': cream}.get(kind, boot))
    C.ADDED.append(o)

# Bake every modifier so the pieces are plain meshes (the skirt drape reads the coat hem and collides with the
# bloomers and boots), then save. The skirt is draped next by remake_skirt.py.
dg = bpy.context.evaluated_depsgraph_get()
for o in list(C.ADDED):
    if o.type == 'MESH' and len(o.modifiers):
        me = bpy.data.meshes.new_from_object(o.evaluated_get(dg))
        o.modifiers.clear(); o.data = me
# every closed piece faces OUTWARD (lofts come out inward; Roblox culls back faces, so an inward piece is see-through)
import bmesh
for o in list(C.ADDED):
    if o.type != 'MESH': continue
    bm = bmesh.new(); bm.from_mesh(o.data)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:]); bm.to_mesh(o.data); bm.free()
bpy.data.objects.remove(body, do_unlink=True)
os.makedirs(OUT, exist_ok=True)
bpy.ops.wm.save_as_mainfile(filepath=OUT + '/pieces.blend')
print('BLOCKOUT OK', len(C.ADDED))