"""Icon source renders of hub props (the game-ui-design pipeline: render the real model, then iconize.py). Each baked
*_tt.glb is rendered alone at 3/4 on a transparent background, flat warm key + cool rim, 1024 px.

  blender --background --python icon_renders.py -- <hub_out_dir> <out_dir> name[:yaw_degrees] ...
"""

import math
import os
import sys

import bpy
from mathutils import Vector

args = sys.argv[sys.argv.index("--") + 1:]
src, out = args[0], args[1]
os.makedirs(out, exist_ok=True)

for item in args[2:]:
    name, _, yaw = item.partition(":")
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene = bpy.context.scene
    scene.render.resolution_x = scene.render.resolution_y = 1024
    scene.render.film_transparent = True
    world = bpy.data.worlds.new("w")
    scene.world = world
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs[1].default_value = 0.9
    bpy.ops.import_scene.gltf(filepath=os.path.join(src, name + "_tt.glb"))
    objs = [o for o in scene.objects if o.type == "MESH"]
    for o in scene.objects:
        if o.parent is None:
            o.rotation_euler[2] += math.radians(float(yaw or 0))
    bpy.context.view_layer.update()
    lo = Vector((1e9, 1e9, 1e9))
    hi = -lo
    for o in objs:
        for c in o.bound_box:
            w = o.matrix_world @ Vector(c)
            lo = Vector(map(min, lo, w))
            hi = Vector(map(max, hi, w))
    centre = (lo + hi) / 2
    radius = (hi - lo).length / 2
    for nm, energy, loc in (("key", 600, (3, -4, 5)), ("rim", 400, (-3, 4, 4)), ("fill", 150, (-4, -3, 1))):
        light = bpy.data.objects.new(nm, bpy.data.lights.new(nm, "AREA"))
        light.data.energy = energy * radius ** 2
        light.data.size = radius * 3
        light.location = centre + Vector(loc) * radius
        light.rotation_euler = (centre - light.location).to_track_quat("-Z", "Y").to_euler()
        scene.collection.objects.link(light)
    cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
    scene.collection.objects.link(cam)
    scene.camera = cam
    cam.data.type = "ORTHO"
    cam.data.ortho_scale = radius * 2.3
    cam.location = centre + Vector((0.55, -1.0, 0.55)).normalized() * radius * 6
    cam.rotation_euler = (centre - cam.location).to_track_quat("-Z", "Y").to_euler()
    scene.render.filepath = os.path.join(out, f"{name}.png")
    bpy.ops.render.render(write_still=True)
print("done")
