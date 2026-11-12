"""Look render for round 5 (owner 11-12): the new snack machine stocked with the four snacks, and the bare pumpkins
wearing the separate pumpkin-leaf props. Imports the baked *_tt.glb files from HUB_OUT and renders a wide 3/4 view and
two close views under warm hub light.

  blender --background --python r5_look.py -- <hub_out_dir> <out.png>
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


def load(name, at, yaw=0.0, scale=1.0):
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=os.path.join(src, name + "_tt.glb"))
    new = [o for o in bpy.data.objects if o not in before]
    for o in new:
        if o.parent is None:
            o.location = Vector(at)
            o.rotation_euler[2] += yaw
            o.scale = (scale, scale, scale)
    return new


# the machine (front = -Y), stocked: 4 shelves x 4 slots (matches build_hub.vending)
load("hb_vending", (0, 0, 0))
x0, z0 = -1.5, 2.05
kinds = ["hb_snack_bar", "hb_snack_chips", "hb_snack_bottle", "hb_snack_can"]
for i in range(4):
    z = z0 + 0.12 + i * 1.15
    for k in range(4):
        load(kinds[i], (x0 + 0.25 + k * 0.5, -1.0, z), math.radians(-6 + k * 4))

# pumpkins with their leaves (the leaf prop's pivot sits at the stem base: the bare pumpkin's skin top, measured)
def top_of(objs, at):
    """The skin's top near the stem: the highest skin point 0.55-0.7 studs from the axis (clear of the bent stem), raised
    by the shoulder's drop there."""
    bpy.context.view_layer.update()
    best = 0.0
    for o in objs:
        if o.type != "MESH":
            continue
        for v in o.data.vertices:
            w = o.matrix_world @ v.co
            r = math.hypot(w.x - at[0], w.y - at[1])
            if 0.55 < r < 0.7:
                best = max(best, w.z)
    return best + 0.06


for name, leaf, at, scale in (("hb_pumpkin_round_bare", "hb_pumpkinleaf_a", (4.2, -1.2, 0), 1.0),
                              ("hb_pumpkin_tall_bare", "hb_pumpkinleaf_b", (6.4, 0.6, 0), 0.8)):
    body = load(name, at, scale=scale)
    load(leaf, (at[0], at[1], top_of(body, at) - 0.05), scale=scale)
load("hb_pumpkin_squat_bare", (2.6, -2.6, 0), scale=0.8)

bpy.ops.mesh.primitive_plane_add(size=30, location=(0, 0, 0))
floor = bpy.context.active_object
fm = bpy.data.materials.new("floor")
fm.use_nodes = True
fm.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (0.20, 0.19, 0.18, 1)
fm.node_tree.nodes["Principled BSDF"].inputs["Roughness"].default_value = 0.85
floor.data.materials.append(fm)

for name, kind, energy, loc, rot in (
    ("key", "AREA", 900, (4, -7, 8), (50, 0, 30)),
    ("fill", "AREA", 300, (-6, -5, 5), (60, 0, -50)),
    ("rim", "AREA", 400, (0, 6, 7), (-50, 0, 180)),
):
    light = bpy.data.objects.new(name, bpy.data.lights.new(name, kind))
    light.data.energy = energy
    light.data.size = 5
    light.data.color = (1.0, 0.86, 0.7) if name == "key" else (0.8, 0.85, 1.0)
    light.location = loc
    light.rotation_euler = tuple(math.radians(v) for v in rot)
    scene.collection.objects.link(light)

cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
scene.collection.objects.link(cam)
scene.camera = cam
for label, loc, target, lens in (
    ("wide", (5.5, -13.0, 5.5), (2.4, -0.5, 2.8), 32),
    ("machine", (1.6, -6.0, 5.0), (-0.4, -0.8, 4.2), 40),
    ("pumpkins", (6.6, -6.2, 4.4), (5.0, -0.6, 1.6), 45),
):
    cam.location = loc
    cam.rotation_euler = (Vector(target) - Vector(loc)).to_track_quat("-Z", "Y").to_euler()
    cam.data.lens = lens
    scene.render.filepath = out.replace(".png", f"_{label}.png")
    bpy.ops.render.render(write_still=True)
print("done")
