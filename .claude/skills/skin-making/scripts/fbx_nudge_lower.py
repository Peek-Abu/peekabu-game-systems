# SSR_Lower's mesh 93419803472157 fetched as Failure in the owner's lobby client (11-16) while the same asset loads
# elsewhere; a new mesh id forces a fresh fetch everywhere. Moves the lowest sole vertex down 0.0001 stud (invisible;
# weights and UVs untouched, so the baked maps still fit), saves export_final_r7.blend and writes the no-texture FBX.
#   blender -b --disable-autoexec <dir>/export/export_final.blend -P fbx_nudge_lower.py -- <out.fbx>
import bpy, sys, os
out = sys.argv[sys.argv.index('--') + 1]
o = bpy.data.objects['SSR_Lower']
v = min(o.data.vertices, key=lambda v: v.co.z)
v.co.z -= 0.0001
print('NUDGED', v.index)
objs = [x for x in bpy.data.objects if x.name.startswith('SSR_') or x.type == 'ARMATURE']
for x in bpy.context.view_layer.objects: x.select_set(x in objs)
bpy.ops.export_scene.fbx(filepath=out, use_selection=True, object_types={'MESH', 'ARMATURE'}, add_leaf_bones=False,
                         bake_anim=False, use_armature_deform_only=True, path_mode='STRIP', embed_textures=False,
                         use_mesh_modifiers=False)
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(os.path.dirname(out), 'export_final_r7.blend'))
print('WROTE', out, os.path.getsize(out))
