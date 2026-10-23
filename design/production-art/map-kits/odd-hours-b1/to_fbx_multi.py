# <name>_parts.glb (several objects) -> FBX, mesh only. blender --background --python to_fbx_multi.py -- <outdir> <a_parts.glb> ...
# Main object is renamed <name>; LED_* / Glass keep their names. 1 unit = 1 stud; materials stripped; axis -Z/Y (the Roblox 180-yaw trap still applies).
import bpy, sys, os
args = sys.argv[sys.argv.index("--") + 1:]
for src in args[1:]:
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=src)
    ms = [o for o in bpy.context.scene.objects if o.type == "MESH"]
    bpy.ops.object.select_all(action="DESELECT")
    for o in ms:
        o.select_set(True)
    bpy.context.view_layer.objects.active = ms[0]
    bpy.ops.object.parent_clear(type="CLEAR_KEEP_TRANSFORM")
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    for o in ms:
        o.data.materials.clear()
    name = os.path.basename(src).replace("_parts.glb", "")
    for o in ms:
        if not (o.name.startswith("LED_") or o.name.startswith("Glass")):
            o.name = name
    out = os.path.join(args[0], name + ".fbx")
    bpy.ops.export_scene.fbx(filepath=out, use_selection=True, apply_unit_scale=True, apply_scale_options="FBX_SCALE_UNITS",
                             axis_forward="-Z", axis_up="Y", path_mode="STRIP", mesh_smooth_type="FACE", use_tspace=True)
    print("FBX", name, [(o.name, [round(x, 3) for x in o.dimensions], len(o.data.polygons)) for o in ms])
