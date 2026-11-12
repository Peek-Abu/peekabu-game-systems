"""Model pass for the single leaves (see leaf_singles.py): each leaf is a 40 x 40 grid over its texture, trimmed to the
outline (alpha-clipped at the edge), folded along the midrib, curled toward the tip and given a little twist, with a
thin tapered stalk. Renders a look sheet on a concrete-grey floor: the four leaves top-down and at 3/4, one stud = the
grid. Writes each leaf as <name>.glb too (for the FBX export after the owner's OK).

  blender --background --python leaf_singles_blend.py -- <maps_dir> <out.png> [size_studs]
"""

import json
import math
import os
import sys

import bmesh
import bpy
from mathutils import Vector

args = sys.argv[sys.argv.index("--") + 1:]
MAPS, OUT = args[0], args[1]
SIZE = float(args[2]) if len(args) > 2 else 0.9
meta = json.load(open(os.path.join(MAPS, "leaves.json")))

bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene
scene.render.engine = "BLENDER_EEVEE_NEXT" if "BLENDER_EEVEE_NEXT" in [e.identifier for e in bpy.types.RenderSettings.bl_rna.properties["engine"].enum_items] else "BLENDER_EEVEE"
scene.render.resolution_x, scene.render.resolution_y = 1600, 900
scene.render.film_transparent = False
world = bpy.data.worlds.new("w")
scene.world = world
world.use_nodes = True
world.node_tree.nodes["Background"].inputs[0].default_value = (0.05, 0.05, 0.07, 1)
world.node_tree.nodes["Background"].inputs[1].default_value = 0.6


def inside(poly, x, y):
    c = False
    j = len(poly) - 1
    for i in range(len(poly)):
        xi, yi = poly[i]
        xj, yj = poly[j]
        if (yi > y) != (yj > y) and x < (xj - xi) * (y - yi) / (yj - yi + 1e-12) + xi:
            c = not c
        j = i
    return c


def material(name):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    N, L = m.node_tree.nodes, m.node_tree.links
    b = N["Principled BSDF"]
    tex = N.new("ShaderNodeTexImage")
    tex.image = bpy.data.images.load(os.path.join(MAPS, f"{name}_color.png"))
    L.new(tex.outputs["Color"], b.inputs["Base Color"])
    L.new(tex.outputs["Alpha"], b.inputs["Alpha"])
    nt = N.new("ShaderNodeTexImage")
    nt.image = bpy.data.images.load(os.path.join(MAPS, f"{name}_normal.png"))
    nt.image.colorspace_settings.name = "Non-Color"
    nm = N.new("ShaderNodeNormalMap")
    L.new(nt.outputs["Color"], nm.inputs["Color"])
    L.new(nm.outputs["Normal"], b.inputs["Normal"])
    rt = N.new("ShaderNodeTexImage")
    rt.image = bpy.data.images.load(os.path.join(MAPS, f"{name}_rough.png"))
    rt.image.colorspace_settings.name = "Non-Color"
    L.new(rt.outputs["Color"], b.inputs["Roughness"])
    try:
        m.surface_render_method = "DITHERED"
    except AttributeError:
        m.blend_method = "CLIP"
    return m


def leaf(entry, at, yaw, seed):
    name, poly = entry["name"], entry["outline"]
    n = 40
    bm = bmesh.new()
    uv = bm.loops.layers.uv.new()
    grid = {}
    for i in range(n + 1):
        for j in range(n + 1):
            x, y = -0.5 + i / n, j / n
            grid[i, j] = (x, y)
    verts = {}
    for i in range(n):
        for j in range(n):
            corners = [(i, j), (i + 1, j), (i + 1, j + 1), (i, j + 1)]
            cx, cy = -0.5 + (i + 0.5) / n, (j + 0.5) / n
            if not any(inside(poly, *grid[c]) for c in corners) and not inside(poly, cx, cy):
                continue
            vs = []
            for c in corners:
                if c not in verts:
                    x, y = grid[c]
                    fold = 0.10 * abs(x)                      # folded up along the midrib
                    curl = 0.16 * (y ** 2)                    # the tip curls up
                    twist = 0.05 * x * y
                    verts[c] = bm.verts.new((x * SIZE, (y - 0.4) * SIZE, (fold + curl + twist) * SIZE))
                vs.append(verts[c])
            f = bm.faces.new(vs)
            for loop, c in zip(f.loops, corners):
                loop[uv].uv = (grid[c][0] + 0.5, grid[c][1])
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    ob = bpy.data.objects.new(name, me)
    scene.collection.objects.link(ob)
    ob.data.materials.append(material(name))
    sol = ob.modifiers.new("thick", "SOLIDIFY")
    sol.thickness = 0.012 * SIZE
    # the stalk: a thin tapered rod out of the base, bending down
    bpy.ops.mesh.primitive_cone_add(vertices=6, radius1=0.012 * SIZE, radius2=0.006 * SIZE, depth=0.16 * SIZE)
    st = bpy.context.active_object
    st.name = name + "_stalk"
    st.rotation_euler = (math.radians(80), 0, 0)
    st.location = (0, (0.10 - 0.4 - 0.07) * SIZE, 0.01 * SIZE)
    sm = bpy.data.materials.new(name + "_stalk")
    sm.use_nodes = True
    sm.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (0.25, 0.14, 0.05, 1)
    st.data.materials.append(sm)
    st.parent = ob
    ob.location = at
    ob.rotation_euler = (0, 0, yaw)
    return ob


# floor
bpy.ops.mesh.primitive_plane_add(size=12, location=(0, 0, -0.02))
floor = bpy.context.active_object
fm = bpy.data.materials.new("floor")
fm.use_nodes = True
fb = fm.node_tree.nodes["Principled BSDF"]
noise = fm.node_tree.nodes.new("ShaderNodeTexNoise")
noise.inputs["Scale"].default_value = 40
ramp = fm.node_tree.nodes.new("ShaderNodeValToRGB")
ramp.color_ramp.elements[0].color = (0.16, 0.15, 0.14, 1)
ramp.color_ramp.elements[1].color = (0.24, 0.23, 0.21, 1)
fm.node_tree.links.new(noise.outputs["Fac"], ramp.inputs["Fac"])
fm.node_tree.links.new(ramp.outputs["Color"], fb.inputs["Base Color"])
fb.inputs["Roughness"].default_value = 0.85
floor.data.materials.append(fm)

objs = []
for k, entry in enumerate(meta):
    objs.append(leaf(entry, (-1.8 + k * 1.2, 0.6, 0.0), math.radians([-12, 18, -6, 10][k]), k))
    # the same leaf again, lower row, turned over the other way and angled, as it would lie in the hub
    o2 = leaf(entry, (-1.8 + k * 1.2, -0.8, 0.0), math.radians([140, -120, 160, -150][k]), k + 9)
    o2.rotation_euler[0] = math.radians(8)

sun = bpy.data.objects.new("sun", bpy.data.lights.new("sun", "SUN"))
sun.data.energy = 3.2
sun.rotation_euler = (math.radians(45), math.radians(10), math.radians(30))
scene.collection.objects.link(sun)
fill = bpy.data.objects.new("fill", bpy.data.lights.new("fill", "AREA"))
fill.data.energy = 120
fill.data.size = 6
fill.location = (0, -4, 4)
fill.rotation_euler = (math.radians(45), 0, 0)
scene.collection.objects.link(fill)

cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
scene.collection.objects.link(cam)
scene.camera = cam
views = {"top": ((0, -0.1, 6.0), (0, -0.1, 0)), "tq": ((0, -5.6, 3.6), (0, -0.2, 0))}
for label, (loc, target) in views.items():
    cam.location = loc
    d = Vector(target) - Vector(loc)
    cam.rotation_euler = d.to_track_quat("-Z", "Y").to_euler()
    cam.data.lens = 40 if label == "top" else 45
    scene.render.filepath = OUT.replace(".png", f"_{label}.png")
    bpy.ops.render.render(write_still=True)

for entry in meta:
    ob = bpy.data.objects[entry["name"]]
    bpy.ops.object.select_all(action="DESELECT")
    ob.select_set(True)
    for c in ob.children:
        c.select_set(True)
    bpy.context.view_layer.objects.active = ob
    bpy.ops.export_scene.gltf(filepath=os.path.join(MAPS, entry["name"] + ".glb"), use_selection=True)
print("done")
