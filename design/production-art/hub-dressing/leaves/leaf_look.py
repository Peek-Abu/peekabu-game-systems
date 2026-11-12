# Blender look render: the leaf drift (a low mound wearing the drift card) and scatter cards on a dark floor.
import bpy, math, sys, random
argv = sys.argv[sys.argv.index("--") + 1:]
W, OUT = argv[0], argv[1]
bpy.ops.wm.read_factory_settings(use_empty=True)
sc = bpy.context.scene
sc.render.engine = "CYCLES"; sc.cycles.samples = 64; sc.cycles.use_denoising = True
sc.render.resolution_x, sc.render.resolution_y = 1280, 720
sc.world = bpy.data.worlds.new("w"); sc.world.use_nodes = True
sc.world.node_tree.nodes["Background"].inputs[0].default_value = (0.03, 0.03, 0.05, 1); sc.world.node_tree.nodes["Background"].inputs[1].default_value = 0.6

def mat(name, base, normal=None, rough=None, alpha=False, plain=None):
    m = bpy.data.materials.new(name); m.use_nodes = True
    nt = m.node_tree; b = nt.nodes["Principled BSDF"]
    if plain:
        b.inputs["Base Color"].default_value = plain; b.inputs["Roughness"].default_value = 0.85; return m
    t = nt.nodes.new("ShaderNodeTexImage"); t.image = bpy.data.images.load(f"{W}/{base}")
    nt.links.new(t.outputs["Color"], b.inputs["Base Color"])
    if alpha:
        nt.links.new(t.outputs["Alpha"], b.inputs["Alpha"])
        try: m.blend_method = "CLIP"
        except Exception: pass
    if normal:
        tn = nt.nodes.new("ShaderNodeTexImage"); tn.image = bpy.data.images.load(f"{W}/{normal}"); tn.image.colorspace_settings.name = "Non-Color"
        nm = nt.nodes.new("ShaderNodeNormalMap"); nt.links.new(tn.outputs["Color"], nm.inputs["Color"]); nt.links.new(nm.outputs["Normal"], b.inputs["Normal"])
    if rough:
        tr = nt.nodes.new("ShaderNodeTexImage"); tr.image = bpy.data.images.load(f"{W}/{rough}"); tr.image.colorspace_settings.name = "Non-Color"
        nt.links.new(tr.outputs["Color"], b.inputs["Roughness"])
    return m

# floor
bpy.ops.mesh.primitive_plane_add(size=40); fl = bpy.context.object; fl.data.materials.append(mat("floor", None, plain=(0.09, 0.085, 0.08, 1)))
# drift mound: 4.4 x 3.4 studs, 0.45 high
bpy.ops.mesh.primitive_grid_add(x_subdivisions=96, y_subdivisions=96, size=1)
d = bpy.context.object; d.scale = (4.4, 3.4, 1); bpy.ops.object.transform_apply(scale=True)
for v in d.data.vertices:
    x, y = v.co.x / 2.2, v.co.y / 1.7
    r = min(1.0, math.sqrt(x * x + y * y))
    v.co.z = 0.45 * (1 - r * r) ** 1.6 + 0.01
img = bpy.data.images.load(f"{W}/leaf_drift_height.png"); px = list(img.pixels); iw, ih = img.size
for v in d.data.vertices:
    u = v.co.x / 4.4 + 0.5; t = v.co.y / 3.4 + 0.5
    i = min(iw - 1, max(0, int(u * iw))); j = min(ih - 1, max(0, int(t * ih)))
    h = px[(j * iw + i) * 4]
    v.co.z += (h - 0.5) * 0.14 * (0.4 + 0.6 * min(1, v.co.z / 0.3))
d.data.materials.append(mat("drift", "leaf_drift_color.png", "leaf_drift_normal.png", "leaf_drift_rough.png", alpha=True))
bpy.ops.object.shade_smooth()
# scatter cards
random.seed(4)
for i, (x, y) in enumerate([(3.6, 0.9), (-3.4, -1.4), (2.6, -2.2), (-2.4, 2.0), (4.8, -0.6), (-4.6, 0.6)]):
    bpy.ops.mesh.primitive_plane_add(size=0.95, location=(x, y, 0.012), rotation=(0, 0, random.uniform(0, 6.28)))
    c = bpy.context.object; k = (i % 4) + 1
    c.data.materials.append(mat(f"s{k}", f"leaf_scatter{k}_color.png", f"leaf_scatter{k}_normal.png", f"leaf_scatter{k}_rough.png", alpha=True))
# a 4-stud figure for scale
bpy.ops.mesh.primitive_cylinder_add(radius=0.55, depth=2.4, location=(-1.2, 3.4, 1.2)); bpy.context.object.data.materials.append(mat("fig", None, plain=(0.8, 0.45, 0.3, 1)))
bpy.ops.mesh.primitive_uv_sphere_add(radius=0.85, location=(-1.2, 3.4, 3.2)); bpy.context.object.data.materials.append(mat("head", None, plain=(0.85, 0.5, 0.35, 1)))
# warm lamps + cool fill (hub-like)
for loc, e, col in [((3, -3, 9), 2400, (1.0, 0.78, 0.55)), ((-6, 5, 7), 700, (0.55, 0.6, 1.0))]:
    bpy.ops.object.light_add(type="POINT", location=loc); L = bpy.context.object; L.data.energy = e; L.data.color = col; L.data.shadow_soft_size = 1.5
cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam")); sc.collection.objects.link(cam); sc.camera = cam; cam.data.lens = 35
for name, loc, tgt in [("tq", (0, -9.5, 6.0), (0, 0, 0.2)), ("close", (2.6, -4.2, 2.2), (0.3, 0, 0.2)), ("side", (-7.5, -3.5, 3.2), (0, 0, 0.2))]:
    cam.location = loc
    dvec = [tgt[i] - loc[i] for i in range(3)]
    cam.rotation_euler = (math.atan2(math.hypot(dvec[0], dvec[1]), -dvec[2]), 0, math.atan2(dvec[1], dvec[0]) - math.pi / 2)
    sc.render.filepath = f"{OUT}/leaf_look_{name}.png"; bpy.ops.render.render(write_still=True)
print("rendered")
