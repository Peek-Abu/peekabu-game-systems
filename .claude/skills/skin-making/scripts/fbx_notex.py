# Re-export <dir>/export/export_final.blend as an FBX with NO embedded textures (texture round: the maps ship as
# separate images on a SurfaceAppearance; embedding made the FBX 15 MB).
#   blender -b --disable-autoexec <dir>/export/export_final.blend -P fbx_notex.py -- <out.fbx>
import bpy, sys, os
out = sys.argv[sys.argv.index('--') + 1]
objs = [o for o in bpy.data.objects if o.name.startswith('SSR_') or o.type == 'ARMATURE']
for o in bpy.context.view_layer.objects: o.select_set(o in objs)
bpy.ops.export_scene.fbx(filepath=out, use_selection=True, object_types={'MESH', 'ARMATURE'}, add_leaf_bones=False,
                         bake_anim=False, use_armature_deform_only=True, path_mode='STRIP', embed_textures=False,
                         use_mesh_modifiers=False)
print('WROTE', out, os.path.getsize(out))
