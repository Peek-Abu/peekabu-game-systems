# Showstopper REMAKE, round 3 (owner 11-16): the coat is ONE robe. One mesh from the collar to the hem: coat top, coat
# skirt, cream lapels, cream collar and gold edges are zones of the same surface (the lapels raised a little). No
# separate skirt piece, no seam at the waist, no goo, no drips. The skirt part hangs by cloth simulation (top pinned)
# over the bloomers and boots, then gets skirt bone chains in that same mesh. Sleeves are single closed meshes (the
# gold band and the cuff are parts of the sleeve, not loose rings). Nothing may go into the head's underside.
#   blender -b --disable-autoexec -P ss_robe.py -- <out_dir> [k=v ...]    (reads <out_dir>/pieces.blend,
#   writes <out_dir>/finished.blend and robe.json)
import bpy, bmesh, sys, math, os, json
import numpy as np
from mathutils import Vector, Quaternion
from mathutils.bvhtree import BVHTree
sys.path.insert(0, 'E:/Projects/peekabu-game-systems/characters/skins/release/gloom_carnival/blockout')
import common as C

A = sys.argv[sys.argv.index('--') + 1:]
OUT = os.path.abspath(A[0]).replace(chr(92), '/')
P = dict(ZW=1.32, L=0.80, FLARE=0.60, SLIT_Z=0.80, BACK_OPEN=28.0, NS=44, NT=16, NK=18, FRAMES=70, THICK=0.035,
         LAPEL_W=0.30, RAISE=0.03, COLLAR=0.13, FLARE_COLLAR=0.07, HEAD_GAP=0.05)
for kv in A[1:]:
    k, v = kv.split('='); P[k] = type(P[k])(float(v))
bpy.ops.wm.open_mainfile(filepath=f'{OUT}/pieces.blend')
sc = bpy.context.scene


def sst(a, b, x):
    t = min(max((x - a) / (b - a), 0.0), 1.0); return t * t * (3 - 2 * t)


def lerp(a, b, t): return a + (b - a) * t


PLUM = C.mat('plum', '#683256', .75)          # same values as ss_blockout.py (unused materials are not saved)
CREAM = C.mat('cream', '#F3D4C2', .6)
GOLD = C.mat('gold', '#D9AA68', .35, .7)
dg = bpy.context.evaluated_depsgraph_get()
o = bpy.data.objects['Head'].evaluated_get(dg); hm = o.to_mesh()
HEAD = BVHTree.FromPolygons([o.matrix_world @ v.co for v in hm.vertices], [list(p.vertices) for p in hm.polygons])
o.to_mesh_clear()


def head_bottom(x, y):
    h = HEAD.ray_cast(Vector((x, y, 1.5)), Vector((0, 0, 1)), 5)
    return h[0].z if h[0] else 9.0


# ---------------- the robe's shape (front is -Y, his left is +X) ---------------------------------------------------
ZW, L = P['ZW'], P['L']
ZH = ZW - L * 0.92                                       # hem height before the drape
TOP = [(1.32, .58, .52), (1.60, .56, .50), (1.90, .55, .49), (2.10, .52, .47), (2.30, .50, .45)]   # z, rx, ry


def rxy(z):
    zs = [t[0] for t in TOP]
    return float(np.interp(z, zs, [t[1] for t in TOP])), float(np.interp(z, zs, [t[2] for t in TOP]))


def gap(z):            # half-opening at the front, degrees from the front centre line
    if z >= ZW: return 16 + 29 * sst(ZW, 2.25, z) ** 1.3
    return 16 + 48 * sst(0, 1, (ZW - z) / (ZW - ZH)) ** 0.8


def ztop(th):          # neckline: lower at the front, where the head hangs lower (2.19 front .. 2.31 back at r .5)
    return 2.14 + 0.13 * (1 + math.sin(math.radians(th))) / 2


def vent(z):
    return P['BACK_OPEN'] * sst(0, 1, (P['SLIT_Z'] - z) / (P['SLIT_Z'] - ZH)) if z < P['SLIT_Z'] else 0.0


def theta(k, s, z):    # k 0 = his right half (-X), 1 = left half; s 0 = front edge .. 1 = back centre
    g, vt = gap(z), vent(z)
    return (-90 - g - s * (180 - g - vt)) if k == 0 else (-90 + g + s * (180 - g - vt))


def lapel_w(z): return P['LAPEL_W'] * sst(ZW + 0.04, 1.95, z)


NS, NT, NK = int(P['NS']), int(P['NT']), int(P['NK'])
NR = NT + NK + 1
cell = {}              # (k, i, j) -> (s, z, v, skirt?)
IB = 10                # columns 0..IB cover the lapel, IB..IB+1 its gold piping: the lapel edge is a clean grid line
CB = 3                 # rows 0..CB cover the collar, CB..CB+1 the gold line under it


def s_of(k, i, z):
    """column i -> position across the half (0 front edge .. 1 back centre), warped so that column IB lies exactly on
    the lapel's outer edge at this height and column IB+1 on the edge of its gold piping"""
    g, vt = gap(z), vent(z)
    rx, ry = rxy(min(z, 2.3)); total = (rx + ry) / 2 * math.radians(180 - g - vt)
    w = max(lapel_w(z), 0.04)
    if i <= IB: arc = w * i / IB
    elif i == IB + 1: arc = w + 0.03
    else: arc = w + 0.03 + (total - w - 0.03) * (i - IB - 1) / (NS - IB - 1)
    return arc / total


for k in (0, 1):
    for i in range(NS + 1):
        zt = ztop(theta(k, i / NS, 2.2))
        top = [zt, zt - 0.045, zt - 0.09, zt - P['COLLAR'], zt - P['COLLAR'] - 0.03]
        top += [lerp(top[-1], ZW, (j + 1) / (NT - len(top) + 1)) for j in range(NT - len(top))]
        rows = top + [ZW - L * 0.92 * (j / NK) for j in range(NK + 1)]
        for j, z in enumerate(rows):
            cell[(k, i, j)] = (s_of(k, i, z), z, (j - NT) / NK if j >= NT else 0.0, j >= NT)


def arc_from_edge(k, s, z):
    rx, ry = rxy(min(z, 2.3))
    return (rx + ry) / 2 * math.radians(abs(theta(k, s, z) - theta(k, 0, z)))


def rest_pos(k, i, j):
    s, z, v, sk = cell[(k, i, j)]
    a = math.radians(theta(k, s, z))
    if sk:
        rx, ry = rxy(ZW); rx += P['FLARE'] * v; ry += P['FLARE'] * v
        return Vector((rx * math.cos(a), ry * math.sin(a), z))
    rx, ry = rxy(z)
    zt = cell[(k, i, 0)][1]
    fl = P['FLARE_COLLAR'] * sst(zt - P['COLLAR'], zt, z)          # top band flares into a turned-down collar
    w = lapel_w(z)                                                 # lapels sit a little proud of the coat
    up = P['RAISE'] * (1.0 - sst(w - 0.03, w + 0.02, arc_from_edge(k, s, z))) if w > 0.02 else 0.0
    return Vector(((rx + fl + up) * math.cos(a), (ry + fl + up) * math.sin(a), z))


# vertices: the two halves share the back-centre column from the collar down to the vent (one surface, no seam)
index, verts, key_of = {}, [], []
for k in (0, 1):
    for i in range(NS + 1):
        for j in range(NR):
            if k == 1 and i == NS and cell[(1, i, j)][1] >= P['SLIT_Z'] - 1e-6:
                index[(1, i, j)] = index[(0, i, j)]
                continue
            index[(k, i, j)] = len(verts); verts.append(rest_pos(k, i, j)); key_of.append((k, i, j))


def zone(k, i, j):
    s, z, v, sk = cell[(k, i, j)]
    zc = 0.5 * (z + cell[(k, i, j + 1)][1])
    if i == 0 or j == NR - 2: return 2                           # gold front edge, gold hem
    if i == NS - 1 and zc < P['SLIT_Z']: return 2                # gold vent edges
    if sk: return 0
    if j < CB: return 1                                          # collar
    lap = lapel_w(zc) > 0.0
    if lap and i < IB: return 1                                  # lapel
    if lap and i == IB: return 2                                 # gold piping round the lapel
    if j == CB: return 2                                         # gold line under the collar
    return 0


faces, mats = [], []
for k in (0, 1):
    for j in range(NR - 1):
        for i in range(NS):
            q = [index[(k, i, j)], index[(k, i + 1, j)], index[(k, i + 1, j + 1)], index[(k, i, j + 1)]]
            faces.append(q if k == 0 else q[::-1]); mats.append(zone(k, i, j))
me = bpy.data.meshes.new('Robe'); me.from_pydata([v[:] for v in verts], [], faces); me.update()
for m in (PLUM, CREAM, GOLD): me.materials.append(m)
for p, m in zip(me.polygons, mats): p.material_index = m; p.use_smooth = True
R = bpy.data.objects.new('Robe', me); sc.collection.objects.link(R)
pin = R.vertex_groups.new(name='Pin')
for n, (k, i, j) in enumerate(key_of):
    w = 1.0 if j <= NT else (0.7 if j == NT + 1 else 0.0)
    if w > 0: pin.add([n], w, 'REPLACE')
print('ROBE verts', len(verts), 'faces', len(faces))

# ---------------- hang the skirt part by cloth, against the bloomers and boots -------------------------------------
def joined(prefixes, name):
    bm_ = bmesh.new()
    for ob in bpy.data.objects:
        if ob.type == 'MESH' and any(ob.name.startswith(p) for p in prefixes):
            m_ = ob.data.copy(); m_.transform(ob.matrix_world); bm_.from_mesh(m_); bpy.data.meshes.remove(m_)
    bmesh.ops.recalc_face_normals(bm_, faces=bm_.faces)   # lofted pieces come out inward: cloth would go inside
    m_ = bpy.data.meshes.new(name); bm_.to_mesh(m_); bm_.free()
    ob = bpy.data.objects.new(name, m_); sc.collection.objects.link(ob); ob.hide_render = True
    ob.modifiers.new('Collision', 'COLLISION'); ob.collision.thickness_outer = 0.02; ob.collision.cloth_friction = 5.0
    return ob


COL = [joined(('Bloomer_',), 'Collide_Bloomers'), joined(('Boot_',), 'Collide_Boots')]
cl = R.modifiers.new('Cloth', 'CLOTH'); cs = cl.settings
cs.quality = 10; cs.mass = 0.25; cs.tension_stiffness = cs.compression_stiffness = 25.0
cs.shear_stiffness = 8.0; cs.bending_stiffness = 4.0; cs.air_damping = 2.0
cs.vertex_group_mass = 'Pin'; cs.pin_stiffness = 1.0
cl.collision_settings.use_self_collision = False; cl.collision_settings.distance_min = 0.012
cl.point_cache.frame_start, cl.point_cache.frame_end = 1, int(P['FRAMES'])
sc.frame_start, sc.frame_end = 1, int(P['FRAMES'])
for f in range(1, int(P['FRAMES']) + 1): sc.frame_set(f)
dg = bpy.context.evaluated_depsgraph_get()
me2 = bpy.data.meshes.new_from_object(R.evaluated_get(dg))
R.modifiers.clear(); R.data = me2
for ob in COL: bpy.data.objects.remove(ob, do_unlink=True)
sc.frame_set(1)
R.vertex_groups.clear()
co = np.array([v.co[:] for v in R.data.vertices])
print('DRAPED z %.3f..%.3f  r max %.3f' % (co[:, 2].min(), co[:, 2].max(), np.hypot(co[:, 0], co[:, 1]).max()))

# ---------------- weights: torso above the waist, skirt bone chains below (same mesh, vertex order kept) -----------
CH_S, CH_N, NB = (0.12, 0.50, 0.88), ('F', 'S', 'B'), 3


def hat(x, xs):
    out = []
    for n, c in enumerate(xs):
        if x <= c: out.append(1.0 if n == 0 else max(0.0, (x - xs[n - 1]) / (c - xs[n - 1])))
        else: out.append(1.0 if n == len(xs) - 1 else max(0.0, (xs[n + 1] - x) / (xs[n + 1] - c)))
    return out


VG = {}
def vg(n):
    if n not in VG: VG[n] = R.vertex_groups.new(name=n)
    return VG[n]


for n, (k, i, j) in enumerate(key_of):
    s, z, v, sk = cell[(k, i, j)]
    side = 'R' if k == 0 else 'L'
    if not sk:
        t = sst(ZW, ZW + 0.25, z)
        if t > 1e-3: vg('UpperTorso').add([n], t, 'REPLACE')
        if t < 1 - 1e-3: vg('LowerTorso').add([n], 1 - t, 'REPLACE')
        continue
    top = 1.0 - sst(0.0, 0.12, v)                        # the waist row stays with the hips
    if top > 1e-3: vg('LowerTorso').add([n], top, 'REPLACE')
    seg = v * NB; b0 = min(int(seg), NB - 1); f = seg - b0
    wb = [0.0] * NB; wb[b0] = 1.0
    if b0 < NB - 1 and f > 0.5: wb[b0] = 1.5 - f; wb[b0 + 1] = f - 0.5
    for c, wc in enumerate(hat(s, CH_S)):
        for b, w_ in enumerate(wb):
            w = (1 - top) * wc * w_
            if w > 1e-3: vg(f'Skirt{side}{CH_N[c]}{b + 1}').add([n], w, 'REPLACE')

# bones: each chain runs down its column of the DRAPED skirt
arm = bpy.data.armatures.new('RobeRig'); AR = bpy.data.objects.new('RobeRig', arm); sc.collection.objects.link(AR)
for ob in bpy.context.view_layer.objects: ob.select_set(False)
bpy.context.view_layer.objects.active = AR; bpy.ops.object.mode_set(mode='EDIT')
eb = arm.edit_bones
lt = eb.new('LowerTorso'); lt.head, lt.tail = (0, 0, 0.95), (0, 0, ZW)
ut = eb.new('UpperTorso'); ut.head, ut.tail = (0, 0, ZW), (0, 0, 2.3); ut.parent = lt
inward = 0.06
for k, side in ((0, 'R'), (1, 'L')):
    for c, cs_ in enumerate(CH_S):
        i = min(range(NS + 1), key=lambda ii: abs(cell[(k, ii, NT)][0] - cs_))   # columns are warped: pick by position
        pts = []
        for b in range(NB + 1):
            p = Vector(co[index[(k, i, NT + int(round(b / NB * NK)))]])
            r = p.xy.length; p.xy = p.xy * ((r - inward) / r)
            pts.append(p)
        prev = lt
        for b in range(NB):
            e = eb.new(f'Skirt{side}{CH_N[c]}{b + 1}'); e.head, e.tail = pts[b], pts[b + 1]; e.parent = prev
            e.use_connect = b > 0; prev = e
bpy.ops.object.mode_set(mode='OBJECT')

# ---------------- thickness, smoothing, head clearance --------------------------------------------------------------
so = R.modifiers.new('thick', 'SOLIDIFY'); so.thickness = P['THICK']; so.offset = 0; so.use_rim = True
so.material_offset_rim = 2                          # cut edges show as gold piping
sd = R.modifiers.new('sub', 'SUBSURF'); sd.levels = sd.render_levels = 1
dg = bpy.context.evaluated_depsgraph_get()
me3 = bpy.data.meshes.new_from_object(R.evaluated_get(dg))
R.modifiers.clear(); R.data = me3
clamped = 0
for vtx in R.data.vertices:
    hb = head_bottom(vtx.co.x, vtx.co.y)
    if vtx.co.z > hb - P['HEAD_GAP']:
        vtx.co.z = hb - P['HEAD_GAP']; clamped += 1
print('HEAD CLAMP verts', clamped)
R.parent = AR
am = R.modifiers.new('rig', 'ARMATURE'); am.object = AR
AR.hide_render = True


# ---------------- sleeves: one closed mesh each (sleeve, gold band, flared cuff, rolled lip) -----------------------
def ring_x(x, ry, rz, cy, cz, n=40):
    return [(x, cy + ry * math.cos(2 * math.pi * t / n), cz + rz * math.sin(2 * math.pi * t / n)) for t in range(n)]


#           x     r     material
SLEEVE = [(0.22, 0.26, 0), (0.45, 0.29, 0), (0.70, 0.28, 0), (0.93, 0.26, 0), (0.96, 0.27, 2), (0.99, 0.29, 2),
          (1.03, 0.29, 2), (1.05, 0.275, 0), (1.09, 0.31, 0), (1.14, 0.34, 0), (1.18, 0.33, 0), (1.18, 0.27, 0),
          (1.14, 0.23, 0)]
for s, side in ((1, 'L'), (-1, 'R')):
    rings = [ring_x(s * x, r, r * 0.95, 0.03, 2.05) for x, r, m in SLEEVE]
    n = len(rings[0]); vs = [p for rg in rings for p in rg]; fs, ms = [], []
    for j in range(len(rings) - 1):
        for t in range(n):
            a, b = j * n + t, j * n + (t + 1) % n
            fs.append((a, b, b + n, a + n)); ms.append(2 if SLEEVE[j][2] == SLEEVE[j + 1][2] == 2 else 0)
    fs.append(tuple(range(n))); ms.append(0)
    k0 = (len(rings) - 1) * n; fs.append(tuple(range(k0, k0 + n))); ms.append(0)
    m_ = bpy.data.meshes.new(f'Sleeve_{side}'); m_.from_pydata(vs, [], fs); m_.update()
    bm_ = bmesh.new(); bm_.from_mesh(m_); bmesh.ops.recalc_face_normals(bm_, faces=bm_.faces); bm_.to_mesh(m_); bm_.free()
    m_.materials.append(PLUM); m_.materials.append(CREAM); m_.materials.append(GOLD)
    for p, mi in zip(m_.polygons, ms): p.material_index = mi; p.use_smooth = True
    so_ = bpy.data.objects.new(f'Sleeve_{side}', m_); sc.collection.objects.link(so_)
    sd_ = so_.modifiers.new('sub', 'SUBSURF'); sd_.levels = sd_.render_levels = 1
    so_['mount_bone'] = ('Left' if s > 0 else 'Right') + 'UpperArm'

# every other piece near the neck keeps the same gap under the head (sleeve tops and waistcoat corners went into it)
dg = bpy.context.evaluated_depsgraph_get()
for ob in [bpy.data.objects[n] for n in ('Sleeve_L', 'Sleeve_R', 'Waistcoat', 'Shirt_collar') if n in bpy.data.objects]:
    if ob.modifiers:
        m_ = bpy.data.meshes.new_from_object(ob.evaluated_get(dg)); ob.modifiers.clear(); ob.data = m_
    for vtx in ob.data.vertices:
        p_ = ob.matrix_world @ vtx.co
        hb = head_bottom(p_.x, p_.y)
        if p_.z > hb - P['HEAD_GAP']:
            vtx.co.z -= p_.z - (hb - P['HEAD_GAP']); clamped += 1
print('HEAD CLAMP all pieces', clamped)
json.dump({'params': P, 'verts': len(R.data.vertices), 'head_clamped': clamped,
           'bones': [b.name for b in arm.bones]}, open(f'{OUT}/robe.json', 'w'), indent=1)
bpy.ops.wm.save_as_mainfile(filepath=f'{OUT}/finished.blend')
print('ROBE OK')
