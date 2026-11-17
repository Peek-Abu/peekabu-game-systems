# Showstopper Prickles REMAKE coat skirt (copy of ../showstopper_tails/ss_skirt.py, 2026-11-16), draped over the remake pieces.
# Original header: Showstopper Prickles, long coat tails (skin workflow test, 2026-11-15).
# NEW vs revs 1-17: the skirt is NOT a shell pushed out from the body. It is cut as two flat pattern pieces (cone
# sectors: a developable surface, so each is exactly a flat paper pattern) with a curved cutaway front edge, joined at
# the back seam from the waist to the slit, pinned at the waist under the approved rev-29 jacket hem, and HUNG by
# Blender's cloth simulation against the real bloomers and boots. Folds and flare come from the sim, not formulas.
#   blender -b --disable-autoexec -P ss_skirt.py -- <out_dir>
import bpy, bmesh, sys, math, json, os
import numpy as np
from mathutils import Vector

A = sys.argv[sys.argv.index('--') + 1:]
OUT = os.path.abspath(A[0]).replace(chr(92), '/')
os.makedirs(OUT, exist_ok=True)
# REMAKE: drapes over the remake's own pieces (pieces.blend in the out dir from ss_blockout.py): the waist row tucks
# under the new coat top's hem, and the cloth collides with the new puffy bloomers and boots.
bpy.ops.wm.open_mainfile(filepath=f'{OUT}/pieces.blend')
J = bpy.data.objects['Coat_top']
def joined(prefixes, name):
    import bmesh as _b
    bm_ = _b.new()
    for o in bpy.data.objects:
        if o.type == 'MESH' and any(o.name.startswith(p) for p in prefixes):
            me_ = o.data.copy(); me_.transform(o.matrix_world); bm_.from_mesh(me_); bpy.data.meshes.remove(me_)
    _b.ops.recalc_face_normals(bm_, faces=bm_.faces)  # lofted pieces come out with inward normals: cloth would be pushed inside
    me_ = bpy.data.meshes.new(name); bm_.to_mesh(me_); bm_.free()
    ob = bpy.data.objects.new(name, me_); bpy.context.scene.collection.objects.link(ob); ob.hide_render = True
    return ob
T = joined(('Bloomer_',), 'Collide_Bloomers')
B = joined(('Boot_',), 'Collide_Boots')

P = dict(COLL=0.02, Z0=1.37, L=0.86, FLARE=0.30, OPEN_TOP=26.0, OPEN_HEM=64.0, TUCK=0.045, SLIT_Z=1.02, BACK_OPEN=0.0,
         NU=40, NV=24, FRAMES=70, BEND=4.0, TENSION=25.0, MASS=0.25)
for kv in A[1:]:
    k, v = kv.split('='); P[k] = type(P[k])(float(v))

# Jacket hem radius per angle (deg bins of 5) just above its bottom edge: the skirt's waist row tucks under it.
jw = np.array([J.matrix_world @ v.co for v in J.data.vertices])
band = jw[(jw[:, 2] > 1.30) & (jw[:, 2] < 1.40)]
ang = np.degrees(np.arctan2(band[:, 1], band[:, 0]))
rad = np.hypot(band[:, 0], band[:, 1])
bins = np.full(72, np.nan)
for i in range(72):
    m = (ang >= -180 + i * 5) & (ang < -175 + i * 5)
    if m.any(): bins[i] = rad[m].max()
good = ~np.isnan(bins)
bins = np.interp(np.arange(72), np.arange(72)[good], bins[good], period=72)
bins = np.convolve(np.r_[bins[-3:], bins, bins[:3]], np.ones(7) / 7, 'valid')

def r_top(deg):
    x = ((deg + 180) % 360) / 5
    i = int(x) % 72; f = x - int(x)
    return bins[i] * (1 - f) + bins[(i + 1) % 72] * f - P['TUCK']

def sst(a, b, x):
    t = min(max((x - a) / (b - a), 0.0), 1.0); return t * t * (3 - 2 * t)

# Pattern: tail k (0 = character's right, +X side ... both sweep from the back seam (+90 deg, +Y = back) to the front
# edge). Front = -Y = -90 deg. Column s 0 at the back seam, 1 at the front edge; row v 0 at the waist, 1 at the hem.
NU, NV = int(P['NU']), int(P['NV'])
bm = bmesh.new()
pin = bm.verts.layers.deform.verify()
uvl = bm.loops.layers.uv.new('UVMap')
grid = {}
for k, sign in ((0, 1), (1, -1)):
    for j in range(NV + 1):
        v = j / NV
        # cutaway: the front edge swings back as it goes down (concept: curved gold edge from the waistcoat to the hem)
        open_deg = P['OPEN_TOP'] + (P['OPEN_HEM'] - P['OPEN_TOP']) * sst(0.0, 1.0, v) ** 0.8
        for i in range(NU + 1):
            s = i / NU
            # right tail (sign +1): back seam 90 deg, sweeping down through 0 (+X) to the front edge -90+open;
            # left tail (sign -1): 90 up through 180 (-X) to 270-open
            # back vent: below the slit each tail's back edge swings away from the centre seam, so the vent opens
            # into a clean inverted V (owner 11-16: the narrow slit 'is a little off on the back')
            zv = P['Z0'] - P['L'] * v * 0.92
            vent = P['BACK_OPEN'] * sst(P['SLIT_Z'], P['Z0'] - P['L'] * 0.92, zv) if zv < P['SLIT_Z'] else 0.0
            deg = 90.0 - sign * (vent + (180.0 - open_deg - vent) * s)
            # cone-sector pattern: radius grows linearly down the slant (flat pattern exactly)
            r = r_top(deg) + P['FLARE'] * v
            z = P['Z0'] - P['L'] * v * 0.92
            a = math.radians(deg)
            vert = bm.verts.new((r * math.cos(a), r * math.sin(a), z))
            vert[pin][0] = 1.0 if j == 0 else (0.7 if j == 1 else 0.0)
            grid[(k, i, j)] = vert
bm.verts.ensure_lookup_table()
for k in (0, 1):
    for j in range(NV):
        for i in range(NU):
            q = [grid[(k, i, j)], grid[(k, i + 1, j)], grid[(k, i + 1, j + 1)], grid[(k, i, j + 1)]]
            f = bm.faces.new(q if k == 0 else q[::-1])
            for lp, (ii, jj) in zip(f.loops, [(i, j), (i + 1, j), (i + 1, j + 1), (i, j + 1)] if k == 0 else
                                    [(i, j + 1), (i + 1, j + 1), (i + 1, j), (i, j)]):
                # outer UV: tail k on its half of the top region of the atlas
                lp[uvl].uv = ((ii / NU) * 0.5 + 0.5 * k, 0.5 + 0.5 * (1 - jj / NV))
# back seam: weld the two tails' s=0 columns from the waist down to the slit
seam = []
for j in range(NV + 1):
    zj = P['Z0'] - P['L'] * (j / NV) * 0.92
    if zj >= P['SLIT_Z']:
        seam.append((grid[(1, 0, j)], grid[(0, 0, j)]))
for a, b in seam:
    bmesh.ops.pointmerge(bm, verts=[a, b], merge_co=(a.co + b.co) / 2)
me = bpy.data.meshes.new('SS_Skirt')
bm.to_mesh(me); bm.free()
S = bpy.data.objects.new('SS_Skirt', me)
bpy.context.scene.collection.objects.link(S)
S.vertex_groups.new(name='Pin')   # index 0: the bmesh deform weights written above
print('PIN verts', sum(1 for v in me.vertices if len(v.groups) and v.groups[0].weight > 0.5))
print('SKIRT verts', len(me.vertices), 'faces', len(me.polygons), 'seam rows', len(seam))

# collisions: the real bloomers and boots (rest pose)
for o in (T, B):
    c = o.modifiers.new('Collision', 'COLLISION')
    o.collision.thickness_outer = P['COLL']
    o.collision.cloth_friction = 5.0
cl = S.modifiers.new('Cloth', 'CLOTH')
cs = cl.settings
cs.quality = 10
cs.mass = P['MASS']
cs.tension_stiffness = cs.compression_stiffness = P['TENSION']
cs.shear_stiffness = 8.0
cs.bending_stiffness = P['BEND']
cs.air_damping = 2.0
cs.vertex_group_mass = 'Pin'
cs.pin_stiffness = 1.0
cl.collision_settings.use_self_collision = False
cl.collision_settings.distance_min = 0.012
cl.point_cache.frame_start, cl.point_cache.frame_end = 1, int(P['FRAMES'])
sc = bpy.context.scene
sc.frame_start, sc.frame_end = 1, int(P['FRAMES'])
for f in range(1, int(P['FRAMES']) + 1):
    sc.frame_set(f)
dg = bpy.context.evaluated_depsgraph_get()
me2 = bpy.data.meshes.new_from_object(S.evaluated_get(dg))
S.modifiers.clear(); S.data = me2
for o in (T, B):
    for m in [m for m in o.modifiers if m.type == 'COLLISION']: o.modifiers.remove(m)

# penetration report: bloomer/boot points that end up OUTSIDE the skirt where the skirt covers them is checked later
co = np.array([v.co[:] for v in S.data.vertices])
print('DRAPED z %.3f..%.3f  r max %.3f' % (co[:, 2].min(), co[:, 2].max(), np.hypot(co[:, 0], co[:, 1]).max()))
json.dump({'params': P, 'verts': len(co)}, open(f'{OUT}/drape.json', 'w'), indent=1)
for o in (T, B): bpy.data.objects.remove(o, do_unlink=True)
bpy.ops.wm.save_as_mainfile(filepath=f'{OUT}/drape.blend')
print('DRAPE OK')
