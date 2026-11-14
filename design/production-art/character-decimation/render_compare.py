"""Renders a character .blend from fixed cameras (front, 3/4, head close-up) for an old-vs-new comparison.
  blender -b <file.blend> -P render_compare.py -- <out_prefix>
Workbench-free: EEVEE with the file's own materials, a soft key + fill, plain background. The camera frames the
character's bounding box, so the old and new builds (same bounds) get identical shots."""
import math
import sys

import bpy
from mathutils import Vector

args = sys.argv[sys.argv.index("--") + 1 :]
out = args[0]
if len(args) > 1:
    # args[1]: the original .blend: point every image at the exact file the original uses (same image name)
    paths = {}
    with bpy.data.libraries.load(args[1], link=False) as (src, dst):
        dst.images = list(src.images)
    for im in dst.images:
        if im is not None:
            paths[im.name.split(".0")[0]] = bpy.path.abspath(im.filepath, library=im.library)
    for im in list(bpy.data.images):
        base = im.name.split(".0")[0]
        if im not in dst.images and base in paths:
            im.filepath = paths[base]
            im.reload()
scene = bpy.context.scene
scene.render.engine = "BLENDER_EEVEE"
scene.render.resolution_x, scene.render.resolution_y = 700, 800
scene.view_settings.view_transform = "Standard"
world = bpy.data.worlds.new("w")
scene.world = world
world.use_nodes = True
world.node_tree.nodes["Background"].inputs[0].default_value = (0.42, 0.40, 0.46, 1)
world.node_tree.nodes["Background"].inputs[1].default_value = 1.0
for nm, rot, en in (("key", (55, 0, -35), 3.2), ("fill", (70, 0, 140), 1.2)):
    ld = bpy.data.lights.new(nm, "SUN")
    ld.energy = en
    ld.angle = math.radians(20)
    lo = bpy.data.objects.new(nm, ld)
    lo.rotation_euler = [math.radians(v) for v in rot]
    scene.collection.objects.link(lo)
meshes = [o for o in scene.objects if o.type == "MESH" and o.visible_get()]
pts = [o.matrix_world @ Vector(c) for o in meshes for c in o.bound_box]
mn = Vector([min(p[i] for p in pts) for i in range(3)])
mx = Vector([max(p[i] for p in pts) for i in range(3)])
centre = (mn + mx) / 2
height = mx.z - mn.z
head = next((o for o in meshes if o.name == "Head"), None)
cam_data = bpy.data.cameras.new("cam")
cam = bpy.data.objects.new("cam", cam_data)
scene.collection.objects.link(cam)
scene.camera = cam


def shoot(name, direction, target, dist, lens):
    cam_data.lens = lens
    d = Vector(direction).normalized()
    cam.location = target + d * dist
    cam.rotation_euler = (target - cam.location).to_track_quat("-Z", "Y").to_euler()
    scene.render.filepath = f"{out}_{name}.png"
    bpy.ops.render.render(write_still=True)


# Blender: the builds face -Y (front), +Z up
shoot("front", (0, -1, 0.05), centre, height * 2.6, 50)
shoot("tq", (0.75, -1, 0.15), centre, height * 2.6, 50)
if head is not None:
    hp = [head.matrix_world @ Vector(c) for c in head.bound_box]
    hc = sum(hp, Vector()) / 8
    hs = max(max(p[i] for p in hp) - min(p[i] for p in hp) for i in range(3))
    shoot("head", (0.55, -1, 0.1), hc, hs * 2.8, 60)

# silhouette close-ups: the head from the side (the round head and ears against the sky) and a hand
if head is not None:
    shoot("headside", (1, 0, 0.05), hc, hs * 2.6, 60)
hand = next((o for o in meshes if o.name == "RightHand"), None)
if hand is not None:
    pp = [hand.matrix_world @ Vector(c) for c in hand.bound_box]
    pc = sum(pp, Vector()) / 8
    ps = max(max(p[i] for p in pp) - min(p[i] for p in pp) for i in range(3))
    shoot("hand", (0.4, -1, 0.5), pc, ps * 3.2, 60)
