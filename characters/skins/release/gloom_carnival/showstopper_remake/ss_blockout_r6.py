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


# ---------------- Hat: short wide plum crown, one row of big cream diamonds, gold band, wide upturned brim -------------
HZ = 3.74
hat = []
CR0, CR1, CH = .60, .63, .84          # crown radius bottom/top, height
def cr(z):
    return CR0 + (CR1 - CR0) * (z - HZ) / CH
brim_rows = []
for rr, dz, lift in [(.56, 0, 0), (.80, .01, .06), (.97, .04, .14), (1.0, .08, .15)]:
    brim_rows.append([(rr * math.cos(a), .92 * rr * math.sin(a), HZ + dz + lift * math.cos(a) ** 2)
                      for a in [2 * math.pi * i / 72 for i in range(72)]])
b = C.loft('Hat_brim', brim_rows, plum_hat, 'Head')
C.solid(b, .05, -1); C.subd(b, 1); hat.append(b)
hat.append(C.tube('Hat_brim_gold', brim_rows[-1], .022, gold, closed=True))
crown = C.loft('Hat_crown', [C.ring(z, cr(z), .95 * cr(z), n=72) for z in [HZ, HZ + .3, HZ + .6, HZ + CH]], plum_hat, 'Head', cap_top=True)
hat.append(crown)
hat.append(C.tube('Hat_top_rim', C.ring(HZ + CH, CR1, .95 * CR1, n=72), .03, plum_hat, closed=True))
band = C.loft('Hat_band', [C.ring(z, cr(z) + .02, .95 * (cr(z) + .02), n=72) for z in (HZ + .02, HZ + .16)], gold, 'Head')
C.solid(band, .02, 1); hat.append(band)
# 8 big cream diamonds, touching tip to tip, filling the band between the gold band and the plum top.
D0, D1, ND = HZ + .17, HZ + .66, 8
for k in range(ND):
    a0 = 2 * math.pi * k / ND - math.pi / 2
    hw = math.pi / ND
    zc = (D0 + D1) / 2
    def P(da, z):
        r = (cr(z) + .008)
        return (r * math.cos(a0 + da), .95 * r * math.sin(a0 + da), z)
    # rings of points between the centre and the rim, each projected onto the crown (no flat chords cutting inside)
    rim = []
    corners = [(0, D1), (hw, zc), (0, D0), (-hw, zc)]
    for c in range(4):
        (aa, za), (ab, zb) = corners[c], corners[(c + 1) % 4]
        for t in range(6):
            f = t / 6
            rim.append((aa + (ab - aa) * f, za + (zb - za) * f))
    NR, M = 5, len(rim)
    vs, fs = [P(0, zc)], []
    for q in range(1, NR + 1):
        g = q / NR
        vs += [P(da * g, zc + (zz - zc) * g) for da, zz in rim]
    for i in range(M):
        fs.append((0, 1 + i, 1 + (i + 1) % M))
    for q in range(1, NR):
        o0, o1 = 1 + (q - 1) * M, 1 + q * M
        for i in range(M):
            fs.append((o0 + i, o1 + i, o1 + (i + 1) % M, o0 + (i + 1) % M))
    hat.append(C.mesh(f'Hat_diamond_{k}', vs, fs, cream, 'Head'))
# His own flower moves onto the hat: front of the crown on his left, over the band.
fl = bpy.data.objects['Flower_Head']
fl.data.transform(Matrix.Translation((.10, .02, .30)))
hat.append(fl)
# Tilt the whole hat down toward his left (+X), as in the concept.
T = Matrix.Translation((0, 0, HZ)) @ Matrix.Rotation(math.radians(9), 4, 'Y') @ Matrix.Translation((0, 0, -HZ))
for o in hat:
    o.matrix_world = T @ o.matrix_world

# ---------------- Shirt: dark collar and V ----------------
C.loft('Shirt_collar', [C.ring(z, r, r, n=48) for z, r in [(2.05, .43), (2.25, .40), (2.40, .33)]], shirt, 'UpperTorso')

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
C.wrap(w, body, .05); C.solid(w, .035, 1); C.subd(w, 1)
for k, z in enumerate([1.80, 1.52]):
    for s in (-1, 1):
        C.ell(f'Toggle_{k}_{s}', (s * .085, -.52, z), (.075, .045, .045), gold)
    C.cyl(f'Toggle_link_{k}', (0, -.52, z), .022, .12, gold, rot=(0, math.pi / 2, 0))

# ---------------- Coat (top half): plum, open front ----------------
def gap(z):  # front half-opening angle (rad) of the coat edge: narrow at the waist, a little wider at the chest
    t = min(max((z - 1.30) / (2.30 - 1.30), 0), 1)
    return math.radians(18 + 22 * t)
coat_rows = [front_arc(z, r, gap(z)) for z, r in [(1.28, .54), (1.45, .53), (1.70, .52), (1.95, .51), (2.15, .48), (2.32, .44)]]
coat = C.loft('Coat_top', coat_rows, plum, 'UpperTorso', closed=False)
C.wrap(coat, body, .085); C.solid(coat, .045, 1); C.subd(coat, 1)


def front(x, z, lift=0.0):
    """Point on the front of the coat seen from the front: an ellipse section in plan (wider over the shoulders)."""
    rx = .62 + .38 * min(max((z - 1.95) / .35, 0), 1)
    t = min(max((abs(x) - .35) / .45, 0), 1)
    ry = .50 - .20 * t * t * (3 - 2 * t)
    q = min(abs(x) / rx, .97)
    return (x, -(ry + lift) * math.sqrt(1 - q * q) - lift * q, z)


def sheet(name, outline, m, lift, thick, bone='UpperTorso'):
    """Flat outline (front view x,z) projected onto the coat front, fan-filled, thickened."""
    cx = sum(p[0] for p in outline) / len(outline); cz = sum(p[1] for p in outline) / len(outline)
    vs = [front(cx, cz, lift)] + [front(x, z, lift) for x, z in outline]
    fs = [(0, 1 + i, 1 + (i + 1) % len(outline)) for i in range(len(outline))]
    o = C.mesh(name, vs, fs, m, bone)
    C.solid(o, thick, 1)
    return o


def smooth_path(pts, n=8):
    """Catmull-Rom through the given (x,z) points, closed."""
    out = []
    N = len(pts)
    for i in range(N):
        p0, p1, p2, p3 = pts[i - 1], pts[i], pts[(i + 1) % N], pts[(i + 2) % N]
        for k in range(n):
            t = k / n
            out.append(tuple(.5 * ((2 * p1[j]) + (-p0[j] + p2[j]) * t + (2 * p0[j] - 5 * p1[j] + 4 * p2[j] - p3[j]) * t * t
                                   + (-p0[j] + 3 * p1[j] - 3 * p2[j] + p3[j]) * t ** 3) for j in (0, 1)))
    return out


# Big cream lapels, outline read off the concept front (his left; mirrored for the right): they start at the waist
# beside the waistcoat, widen up the chest with three goo lobes on the outer edge, and roll over the shoulder top.
LAPEL = [(.13, 1.36), (.20, 1.62), (.26, 1.88), (.28, 2.10), (.30, 2.30), (.40, 2.42), (.58, 2.38), (.74, 2.30),
         (.78, 2.20), (.66, 2.14), (.60, 2.04), (.63, 1.94), (.54, 1.86), (.47, 1.78), (.50, 1.68), (.40, 1.60),
         (.32, 1.50), (.30, 1.42)]
DRIPS = [  # magenta goo running down the coat front below the lapel lobes: (x, top z, length, width)
    (.64, 2.00, .42, .08), (.57, 1.74, .30, .07), (.46, 1.54, .18, .05)]
for s, side in [(1, 'L'), (-1, 'R')]:
    out = smooth_path([(s * x, z) for x, z in LAPEL], 6)
    if s < 0:
        out = out[::-1]
    sheet(f'Lapel_{side}', out, cream, .06, .05)
    pip = [front(x * 1.0, z, .115) for x, z in out]
    C.tube(f'Lapel_piping_{side}', pip + [pip[0]], .018, gold)
    for k, (x, z0, ln, w) in enumerate(DRIPS):
        d = smooth_path([(s * (x - w), z0), (s * (x + w), z0), (s * (x + w * .8), z0 - ln * .7), (s * x, z0 - ln),
                         (s * (x - w * .8), z0 - ln * .7)], 6)
        if s < 0:
            d = d[::-1]
        sheet(f'Coat_drip_{side}_{k}', d, drip, .04, .02)
    # gold piping down the coat's front edge, waist to the lapel
    C.tube(f'Coat_edge_piping_{side}', [front(s * x, z, .055) for x, z in [(.12, 1.28), (.13, 1.36)]], .02, gold)
# Rolled cream collar round the back of the neck, joining the two lapel tops.
roll = [(.52 * math.cos(a), .50 * math.sin(a), 2.30 + .05 * math.sin(a)) for a in
        [math.radians(-50 + 280 * i / 40) for i in range(41)]]
C.tube('Collar_roll', roll, .075, cream)
C.tube('Collar_roll_piping', [(x * 1.12, y * 1.12, z - .06) for x, y, z in roll], .018, gold)

# ---------------- Sleeves: plum, gold band, flared plum cuff ----------------
for s, side in [(1, 'L'), (-1, 'R')]:
    sl = C.loft(f'Sleeve_{side}', [C.ring_x(s * x, r, r * 1.05, cz=2.03) for x, r in [(.30, .33), (.50, .31), (.80, .28), (1.00, .27)]], plum, f'{side}UpperArm', cap_top=True)
    C.subd(sl, 1)
    gb = C.loft(f'Sleeve_gold_{side}', [C.ring_x(s * x, r, r, cz=2.03) for x, r in [(.98, .275), (1.01, .29), (1.04, .29), (1.06, .27)]], gold, f'{side}LowerArm', cap_top=True)
    cf = C.loft(f'Sleeve_cuff_{side}', [C.ring_x(s * x, r, r * 1.04, cz=2.03) for x, r in [(1.04, .27), (1.06, .30), (1.12, .33), (1.15, .32), (1.14, .22)]], plum, f'{side}LowerArm')
    C.subd(cf, 1)

# ---------------- Bloomers: very puffy, pleated, gathered into a knee cuff ----------------
def pleat(a):
    return 1 + .035 * math.cos(10 * a)
seat = C.loft('Bloomer_seat', [C.ring(z, rx, ry, n=64, fn=pleat) for z, rx, ry in [(1.38, .46, .40), (1.26, .50, .44), (1.10, .60, .50), (0.94, .60, .48), (0.86, .40, .30)]], bloom, 'LowerTorso', cap_bottom=True)
C.subd(seat, 1)
for s, side in [(1, 'L'), (-1, 'R')]:
    lg = C.loft(f'Bloomer_leg_{side}', [C.ring(z, r, r * .92, cx=.29 * s, n=48, fn=pleat) for z, r in
                                         [(1.10, .34), (0.98, .42), (0.84, .44), (0.72, .37), (0.65, .27)]], bloom, f'{side}UpperLeg')
    C.subd(lg, 1)
    cu = C.loft(f'Bloomer_cuff_{side}', [C.ring(z, .28, .27, cx=.27 * s, n=40) for z in (.60, .67)], bloom_dk, f'{side}LowerLeg')
    C.solid(cu, .03, 1)

# ---------------- Boots: chunky plum, cuff band, gold button on the outer side ----------------
for s, side in [(1, 'Left'), (-1, 'Right')]:
    C.fitted_copy(f'{side}Foot', .07, boot, f'Boot_{side}')
    sh = C.loft(f'Boot_shaft_{side}', [C.ring(z, r, r * .95, cx=.25 * s, n=40) for z, r in [(.30, .29), (.46, .28), (.56, .29)]], boot, f'{side}LowerLeg')
    C.solid(sh, .03, 1)
    cuf = C.loft(f'Boot_cuff_{side}', [C.ring(z, r, r * .95, cx=.25 * s, n=40) for z, r in [(.55, .31), (.62, .33), (.64, .32)]], boot, f'{side}LowerLeg')
    C.solid(cuf, .03, 1); C.subd(cuf, 1)
    C.ell(f'Boot_button_{side}', (.25 * s + .30 * s, -.10, .47), (.03, .06, .06), gold)

# Bake every modifier so the pieces are plain meshes (the skirt drape reads the coat hem and collides with the
# bloomers and boots), then save. The skirt is draped next by remake_skirt.py.
dg = bpy.context.evaluated_depsgraph_get()
for o in list(C.ADDED):
    if o.type == 'MESH' and len(o.modifiers):
        me = bpy.data.meshes.new_from_object(o.evaluated_get(dg))
        o.modifiers.clear(); o.data = me
bpy.data.objects.remove(body, do_unlink=True)
os.makedirs(OUT, exist_ok=True)
bpy.ops.wm.save_as_mainfile(filepath=OUT + '/pieces.blend')
print('BLOCKOUT OK', len(C.ADDED))