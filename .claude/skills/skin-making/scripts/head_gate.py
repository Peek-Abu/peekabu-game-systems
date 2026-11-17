# Head clearance gate: for every outfit piece, counts vertices that sit inside the head (above the head's underside
# at that point, below its top). The hat sits ON the head and is skipped.
#   blender -b --disable-autoexec -P head_gate.py -- <out_dir>
import bpy, sys, os, json
from mathutils import Vector
from mathutils.bvhtree import BVHTree
D = os.path.abspath(sys.argv[sys.argv.index('--') + 1]).replace(chr(92), '/')
bpy.ops.wm.open_mainfile(filepath=f'{D}/finished.blend')
dg = bpy.context.evaluated_depsgraph_get()
h = bpy.data.objects['Head'].evaluated_get(dg); hm = h.to_mesh()
HB = BVHTree.FromPolygons([h.matrix_world @ v.co for v in hm.vertices], [list(p.vertices) for p in hm.polygons])
SKIP = ('Head', 'FacePlate', 'Flower', 'ShowHat', 'HardHat', 'LeftHand', 'RightHand', 'Upper', 'Lower', 'Left', 'Right')
out = {}
for o in bpy.data.objects:
    if o.type != 'MESH' or o.hide_render or o.name.startswith(SKIP): continue
    e = o.evaluated_get(dg); me = e.to_mesh(); n = 0; deep = 0.0
    for v in me.vertices:
        p = e.matrix_world @ v.co
        hit = HB.ray_cast(Vector((p.x, p.y, 1.5)), Vector((0, 0, 1)), 5)
        if hit[0] and p.z > hit[0].z: n += 1; deep = max(deep, p.z - hit[0].z)
    out[o.name] = {'inside_head_verts': n, 'deepest': round(deep, 3)}
    e.to_mesh_clear()
json.dump(out, open(f'{D}/head_gate.json', 'w'), indent=1)
print('HEAD GATE', {k: v for k, v in out.items() if v['inside_head_verts']})
