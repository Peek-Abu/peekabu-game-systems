import bpy, sys
sys.path.insert(0, 'E:/Projects/peekabu-game-systems/characters/skins/release/gloom_carnival/blockout')
import common as C
rig = C.open_src('prickles')
dg = bpy.context.evaluated_depsgraph_get()
for o in sorted([o for o in bpy.data.objects if o.type == 'MESH' and not o.name.startswith('Widget')], key=lambda o: o.name):
    me = o.evaluated_get(dg).to_mesh()
    ws = [o.matrix_world @ v.co for v in me.vertices]
    if not ws: continue
    mn = [min(w[i] for w in ws) for i in range(3)]; mx = [max(w[i] for w in ws) for i in range(3)]
    g = o.vertex_groups[0].name if o.vertex_groups else '-'
    print('PART %-22s grp %-14s x %.2f..%.2f y %.2f..%.2f z %.2f..%.2f verts %d' % (o.name, g, mn[0], mx[0], mn[1], mx[1], mn[2], mx[2], len(ws)))
for b in rig.data.bones:
    if b.use_deform: print('BONE %-14s head %s tail %s' % (b.name, tuple(round(x, 2) for x in b.head_local), tuple(round(x, 2) for x in b.tail_local)))
