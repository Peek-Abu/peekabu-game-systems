"""Look render for the radio and shift bell v2 (Office procedure: scanned textures, then the model). Imports the baked
*_tt.glb files from HUB_OUT, hangs the bell from the post's yoke pin (0, -0.85, 4.1), puts the radio on a little table
beside it, and renders a 3/4 and a front view under warm hub light.

  blender --background --python radio_bell_look.py -- <hub_out_dir> <out.png>
"""

import math
import os
import sys

import bpy
from mathutils import Vector

src, out = sys.argv[sys.argv.index("--") + 1:][:2]
bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene
scene.render.resolution_x, scene.render.resolution_y = 1600, 1000
world = bpy.data.worlds.new("w")
scene.world = world
world.use_nodes = True
world.node_tree.nodes["Background"].inputs[0].default_value = (0.06, 0.05, 0.08, 1)
world.node_tree.nodes["Background"].inputs[1].default_value = 0.7


def load(name, at, yaw=0.0):
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=os.path.join(src, name + "_tt.glb"))
    new = [o for o in bpy.data.objects if o not in before]
    for o in new:
        if o.parent is None:
            o.location = Vector(at)
            o.rotation_euler[2] += yaw
    return new


load("hb_bellpost_v2", (0, 0, 0))
bell = load("hb_bell_v2", (0, -0.85, 4.1))
load("hb_radio_v2", (2.6, -0.6, 1.2), math.radians(-20))

bpy.ops.mesh.primitive_plane_add(size=20, location=(0, 0, 0))
floor = bpy.context.active_object
fm = bpy.data.materials.new("floor")
fm.use_nodes = True
fm.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (0.20, 0.19, 0.18, 1)
fm.node_tree.nodes["Principled BSDF"].inputs["Roughness"].default_value = 0.85
floor.data.materials.append(fm)
bpy.ops.mesh.primitive_cube_add(size=1, location=(2.6, -0.6, 0.6))
table = bpy.context.active_object
table.scale = (1.4, 0.8, 0.6)
tm = bpy.data.materials.new("table")
tm.use_nodes = True
tm.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (0.30, 0.17, 0.08, 1)
table.data.materials.append(tm)

for name, kind, energy, loc, rot in (
    ("key", "AREA", 450, (3, -5, 7), (50, 0, 30)),
    ("fill", "AREA", 160, (-5, -4, 4), (60, 0, -50)),
    ("rim", "AREA", 220, (0, 5, 6), (-50, 0, 180)),
):
    light = bpy.data.objects.new(name, bpy.data.lights.new(name, kind))
    light.data.energy = energy
    light.data.size = 4
    light.data.color = (1.0, 0.86, 0.7) if name == "key" else (0.8, 0.85, 1.0)
    light.location = loc
    light.rotation_euler = tuple(math.radians(v) for v in rot)
    scene.collection.objects.link(light)

cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
scene.collection.objects.link(cam)
scene.camera = cam
for label, loc, target, lens in (
    ("tq", (5.0, -8.5, 4.6), (1.2, -0.5, 2.4), 36),
    ("close", (1.2, -3.6, 4.0), (0.6, -0.8, 3.0), 45),
):
    cam.location = loc
    cam.rotation_euler = (Vector(target) - Vector(loc)).to_track_quat("-Z", "Y").to_euler()
    cam.data.lens = lens
    scene.render.filepath = out.replace(".png", f"_{label}.png")
    bpy.ops.render.render(write_still=True)
print("done")
