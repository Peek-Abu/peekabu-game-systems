# Texture round (owner 11-16: "loads of seams or areas of clipping", "pants aren't colored the same the whole way (section
# of black)"): the bloomers become ONE closed shell in ONE colour.
#   Before: Bloomer_seat + Bloomer_leg_L/R, three closed pieces; the seat overlapped the leg tops (dark intersection
#   lines), the pleat valleys read as more seams, and each leg had a bloom_dk cuff band above the boot (the black band).
#   Now: union of the three (voxel remesh = one surface, the crotch/hip joins become a smooth blended skin), a light
#   volume-preserving smooth that softens the pleats, decimated to a budget, all faces GC_bloom.
#   blender -b --disable-autoexec -P ss_bloomer_shell.py -- <src_dir> <dst_dir> [VOXEL=0.008] [SMOOTH=6] [TRIS=9000]
#   -> <dst_dir>/finished.blend (the same scene with Bloomer_shell instead of the three pieces)
import bpy, bmesh, sys, os

A = sys.argv[sys.argv.index('--') + 1:]
SRC = os.path.abspath(A[0]).replace(chr(92), '/')
DST = os.path.abspath(A[1]).replace(chr(92), '/')
KV = dict(VOXEL=0.008, SMOOTH=6.0, FACTOR=0.5, TRIS=9000.0)
for kv in A[2:]:
    k, _, v = kv.partition('=')
    if k in KV: KV[k] = float(v)
print('SHELL PARAMS', KV)
bpy.ops.wm.open_mainfile(filepath=f'{SRC}/finished.blend')
names = ['Bloomer_seat', 'Bloomer_leg_L', 'Bloomer_leg_R']
parts = [bpy.data.objects[n] for n in names]
bloom = bpy.data.materials['GC_bloom']

for o in parts:
    if o.modifiers:
        dg = bpy.context.evaluated_depsgraph_get()
        me = bpy.data.meshes.new_from_object(o.evaluated_get(dg)); o.modifiers.clear(); o.data = me
for o in bpy.context.view_layer.objects: o.select_set(o in parts)
bpy.context.view_layer.objects.active = parts[0]
bpy.ops.object.join()
sh = bpy.context.view_layer.objects.active
mw = sh.matrix_world.copy(); sh.parent = None
sh.data.transform(mw); sh.matrix_world.identity()
sh.name = sh.data.name = 'Bloomer_shell'
before = len(sh.data.polygons)


def apply(o):
    dg = bpy.context.evaluated_depsgraph_get()
    me = bpy.data.meshes.new_from_object(o.evaluated_get(dg)); o.modifiers.clear(); o.data = me
    return me


rm = sh.modifiers.new('remesh', 'REMESH'); rm.mode = 'VOXEL'; rm.voxel_size = KV['VOXEL']; rm.adaptivity = 0.0
me = apply(sh)
sm = sh.modifiers.new('smooth', 'CORRECTIVE_SMOOTH')       # smooths the joins and pleat valleys, keeps the volume
sm.factor = KV['FACTOR']; sm.iterations = int(KV['SMOOTH']); sm.smooth_type = 'SIMPLE'; sm.use_only_smooth = True
me = apply(sh)
tris = sum(len(p.vertices) - 2 for p in me.polygons)
dm = sh.modifiers.new('dec', 'DECIMATE'); dm.ratio = min(1.0, KV['TRIS'] / max(tris, 1))
me = apply(sh)

bm = bmesh.new(); bm.from_mesh(me)
bmesh.ops.triangulate(bm, faces=bm.faces[:])
bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
oe = sum(1 for e in bm.edges if not e.is_manifold)
bm.to_mesh(me); bm.free()
me.materials.clear(); me.materials.append(bloom)
for p in me.polygons: p.material_index = 0; p.use_smooth = True
print('SHELL', dict(pieces_polys=before, remesh_tris=tris, tris=len(me.polygons), open_edges=oe))
os.makedirs(DST, exist_ok=True)
bpy.ops.wm.save_as_mainfile(filepath=f'{DST}/finished.blend')
print('WROTE', f'{DST}/finished.blend')
