import bpy
bpy.ops.wm.open_mainfile(filepath='E:/Projects/peekabu-game-systems/characters/skins/release/gloom_carnival/route2_whole/export_r25/Showstopper_R2_final.blend')
A=bpy.data.objects['Showstopper_DeformSkeleton']
print('ARMMW', [round(x,3) for x in A.matrix_world.to_translation()], A.matrix_world.to_scale())
for b in A.data.bones: print('BONE', b.name, b.parent.name if b.parent else None, [round(x,3) for x in b.head_local], [round(x,3) for x in b.tail_local])
for o in bpy.data.objects:
    if o.type=='MESH': print('MESH', o.name, [g.name for g in o.vertex_groups][:30], [m.name for m in o.data.materials], o.matrix_world.to_scale())
