# Look-check sheet: props at REAL scale (studs), in a row, with a 5-stud grey figure for size, three-quarter and back views.
# blender --background --python present.py -- out.png a_parts.glb b_parts.glb ...
# Glass pieces render see-through, Glow and Hazard pieces glow (as they will in Studio).
import bpy, sys, math
from mathutils import Vector

args = sys.argv[sys.argv.index("--") + 1:]
out, files = args[0], args[1:]
bpy.ops.wm.read_factory_settings(use_empty=True)
sc = bpy.context.scene
x = 0.0
groups = []
import os
for f in files + ([] if os.environ.get("NOFIG") else ["FIGURE"]):
    before = set(sc.objects)
    if f == "FIGURE":
        bpy.ops.mesh.primitive_cylinder_add(radius=0.9, depth=4.2, location=(0, 0, 2.1))
        bpy.ops.mesh.primitive_uv_sphere_add(radius=0.9, location=(0, 0, 4.6))
        m = bpy.data.materials.new("fig"); m.use_nodes = True
        m.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (0.35, 0.35, 0.38, 1)
        for o in set(sc.objects) - before:
            o.data.materials.append(m)
    else:
        bpy.ops.import_scene.gltf(filepath=f)
    obs = [o for o in sc.objects if o not in before and o.type == "MESH"]
    for o in obs:
        nm = o.name.split(".")[0]
        if nm.startswith(("Glass", "Glow", "Hazard")):
            mat = bpy.data.materials.new(nm); mat.use_nodes = True
            b = mat.node_tree.nodes["Principled BSDF"]
            if nm.startswith("Glass"):
                o.hide_render = True  # see-through glass in Studio; hidden here so what is behind it shows
                b.inputs["Base Color"].default_value = (0.5, 0.65, 0.7, 1); b.inputs["Alpha"].default_value = 0.18
                b.inputs["Roughness"].default_value = 0.05; mat.surface_render_method = "BLENDED"
            else:
                col = (1.0, 0.85, 0.6, 1) if nm.startswith("Glow") else (1.0, 0.5, 0.05, 1)
                b.inputs["Emission Color"].default_value = col; b.inputs["Emission Strength"].default_value = 4.0
                b.inputs["Base Color"].default_value = col
            o.data.materials.clear(); o.data.materials.append(mat)
    bpy.context.view_layer.update()
    lo = Vector((min(min((o.matrix_world @ Vector(c)).x for c in o.bound_box) for o in obs), 0, 0))
    hi = max(max((o.matrix_world @ Vector(c)).x for c in o.bound_box) for o in obs)
    for o in obs:
        if o.parent is None:
            o.location.x += x - lo.x
    x += (hi - lo.x) + 2.0
groups_w = x - 2.0
bpy.ops.mesh.primitive_plane_add(size=1, location=(groups_w / 2, 0, 0))
g = bpy.context.active_object; g.scale = (groups_w + 40, 60, 1)
gm = bpy.data.materials.new("ground"); gm.use_nodes = True
gm.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (0.09, 0.085, 0.11, 1)
gm.node_tree.nodes["Principled BSDF"].inputs["Roughness"].default_value = 0.9
g.data.materials.append(gm)
sc.world = bpy.data.worlds.new("w"); sc.world.use_nodes = True
sc.world.node_tree.nodes["Background"].inputs["Color"].default_value = (0.10, 0.09, 0.16, 1)
sc.world.node_tree.nodes["Background"].inputs["Strength"].default_value = 0.9
sun = bpy.data.objects.new("sun", bpy.data.lights.new("sun", "SUN")); sc.collection.objects.link(sun)
sun.data.energy = 3.0; sun.rotation_euler = (math.radians(50), 0, math.radians(-35))
fill = bpy.data.objects.new("fill", bpy.data.lights.new("fill", "SUN")); sc.collection.objects.link(fill)
fill.data.energy = 1.0; fill.data.color = (0.7, 0.75, 1.0); fill.rotation_euler = (math.radians(60), 0, math.radians(150))
sc.render.engine = "BLENDER_EEVEE"
sc.render.resolution_x, sc.render.resolution_y = 1600, 560
sc.view_settings.view_transform = "AgX"
cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam")); sc.collection.objects.link(cam); sc.camera = cam
cam.data.type = "ORTHO"; cam.data.clip_end = 2000
pts = [o.matrix_world @ Vector(c) for o in sc.objects if o.type == "MESH" and o is not g and not o.hide_render for c in o.bound_box]
aspect = sc.render.resolution_x / sc.render.resolution_y
for name, d in (("tq", Vector((-0.45, -1, 0.55))), ("back", Vector((0.45, 1, 0.45)))):
    d = d.normalized()
    q = (-d).to_track_quat("-Z", "Y")
    right, up = q @ Vector((1, 0, 0)), q @ Vector((0, 1, 0))
    us = [p.dot(right) for p in pts]; vs = [p.dot(up) for p in pts]
    w, h = max(us) - min(us), max(vs) - min(vs)
    cam.data.ortho_scale = max(w, h * aspect) * 1.06
    c = right * (max(us) + min(us)) / 2 + up * (max(vs) + min(vs)) / 2
    cam.location = c + d * 120
    cam.rotation_euler = q.to_euler()
    sc.render.filepath = out.replace(".png", f"_{name}.png")
    bpy.ops.render.render(write_still=True)
print("DONE", out)
