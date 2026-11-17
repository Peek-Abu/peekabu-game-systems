"""Look renders for the Harvest Hours banner and scarecrow (owner A8/A9 11-17). Imports the baked *_tt.glb files from
HUB_OUT and renders each prop front-on and at a 3/4 angle under warm hub light, beside a grey 5-stud figure for scale.
Prints each prop's size and triangle count (a Roblox MeshPart takes at most 20,000).

  blender --background --python harvest_look.py -- <hub_out_dir> <out_prefix>
"""

import math
import os
import sys

import bpy
from mathutils import Vector

src, out = sys.argv[sys.argv.index("--") + 1:][:2]
bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene
scene.render.engine = "CYCLES"
scene.cycles.samples = 64
scene.render.resolution_x, scene.render.resolution_y = 1400, 1000
world = bpy.data.worlds.new("w")
scene.world = world
world.use_nodes = True
world.node_tree.nodes["Background"].inputs[0].default_value = (0.10, 0.09, 0.12, 1)
world.node_tree.nodes["Background"].inputs[1].default_value = 0.8


def load(name):
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=os.path.join(src, name + "_tt.glb"))
    new = [o for o in bpy.data.objects if o not in before]
    tris = sum(sum(len(p.vertices) - 2 for p in o.data.polygons) for o in new if o.type == "MESH")
    bpy.context.view_layer.update()
    lo = Vector((min(min((o.matrix_world @ Vector(c)).x for c in o.bound_box) for o in new if o.type == "MESH"),
                 min(min((o.matrix_world @ Vector(c)).y for c in o.bound_box) for o in new if o.type == "MESH"),
                 min(min((o.matrix_world @ Vector(c)).z for c in o.bound_box) for o in new if o.type == "MESH")))
    hi = Vector((max(max((o.matrix_world @ Vector(c)).x for c in o.bound_box) for o in new if o.type == "MESH"),
                 max(max((o.matrix_world @ Vector(c)).y for c in o.bound_box) for o in new if o.type == "MESH"),
                 max(max((o.matrix_world @ Vector(c)).z for c in o.bound_box) for o in new if o.type == "MESH")))
    print("PROP", name, "size", [round(v, 2) for v in hi - lo], "tris", tris)
    return new, lo, hi


def scale_figure(x):
    """A plain grey stand-in for a player, 5 studs tall, so the owner can judge size."""
    bpy.ops.mesh.primitive_cylinder_add(radius=0.9, depth=3.2, location=(x, 0, 1.6))
    body = bpy.context.active_object
    bpy.ops.mesh.primitive_uv_sphere_add(radius=0.95, location=(x, 0, 4.1))
    head = bpy.context.active_object
    m = bpy.data.materials.new("fig")
    m.use_nodes = True
    m.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (0.35, 0.36, 0.40, 1)
    for o in (body, head):
        o.data.materials.append(m)
    return [body, head]


bpy.ops.mesh.primitive_plane_add(size=80, location=(0, 0, 0))
floor = bpy.context.active_object
fm = bpy.data.materials.new("floor")
fm.use_nodes = True
fm.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (0.20, 0.19, 0.18, 1)
fm.node_tree.nodes["Principled BSDF"].inputs["Roughness"].default_value = 0.85
floor.data.materials.append(fm)
for name, energy, loc, rot in (("key", 2400, (8, -14, 14), (50, 0, 30)), ("fill", 800, (-12, -10, 8), (60, 0, -50)),
                               ("rim", 900, (0, 12, 12), (-50, 0, 180))):
    light = bpy.data.objects.new(name, bpy.data.lights.new(name, "AREA"))
    light.data.energy = energy
    light.data.size = 8
    light.data.color = (1.0, 0.86, 0.7) if name == "key" else (0.8, 0.85, 1.0)
    light.location = loc
    light.rotation_euler = tuple(math.radians(v) for v in rot)
    scene.collection.objects.link(light)
cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
scene.collection.objects.link(cam)
scene.camera = cam


def shoot(label, loc, target, lens):
    cam.location = loc
    cam.rotation_euler = (Vector(target) - Vector(loc)).to_track_quat("-Z", "Y").to_euler()
    cam.data.lens = lens
    scene.render.filepath = f"{out}_{label}.png"
    bpy.ops.render.render(write_still=True)


def hide(objs, state):
    for o in objs:
        o.hide_render = state


banner, blo, bhi = load("hb_banner_harvest")
# the banner hangs: lift it so its points are 5 studs up (as over a truck bay)
for o in banner:
    if o.parent is None:
        o.location.z += 5.0
fig_b = scale_figure(11.5)
shoot("banner_front", (1.5, -30, 9), (1.5, 0, 8.5), 40)
shoot("banner_34", (16, -20, 6), (2, 0, 9), 38)
hide(banner + fig_b, True)

crow, clo, chi = load("hb_scarecrow_harvest")
fig_c = scale_figure(5.5)
shoot("scarecrow_front", (2.5, -19, 5), (2.5, 0, 4.4), 45)
shoot("scarecrow_34", (10, -13, 6), (1.0, 0, 4.6), 42)
shoot("scarecrow_face", (1.2, -6.5, 7.6), (0, 0, 7.1), 55)
print("done")
