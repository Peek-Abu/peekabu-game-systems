# Odd Hours office map, stage 4 Task 9: the office desk with drawers that open in place.
# Same look and size as c_desk_nodivider (build_set_stage2.py): oak top, cream laminate pedestal / leg panel / modesty
# panel, steel bar pulls, no divider. 8.8 W x 4.6 D x 4.95 H. Here the pedestal is a HOLLOW shell and the three drawers
# (front + pull + box) are SEPARATE meshes, so OfficeSearchedDressingSystem can slide them (SearchComponent = "drawer").
#
# HOW TO RUN (Blender 5.1 headless; needs the texture-pipeline kit hardlib.py with its working set next to it:
#   <HARDLIB_DIR>/../texlab/out/oak_scan_color.png, <HARDLIB_DIR>/../cc0/Wood049, <HARDLIB_DIR>/../cc0/PaintedPlaster017):
#   set HARDLIB_DIR=<folder with hardlib.py>   (default: the session scratchpad's hard/ folder used for stage 2)
#   "C:/Program Files/Blender Foundation/Blender 5.1/blender.exe" --background --python build_desk_drawers.py
# Env DESK_OUT = output folder (default: this folder). It writes:
#   textures/desk_body_{color,normal,rough}.png, textures/desk_drawers_{color,normal,rough}.png (one atlas shared by the 3 drawers)
#   export/desk_drawers.fbx (all 4 meshes), export/<mesh>.fbx + .obj per mesh, export/desk_drawers_parts.glb (preview)
#   renders/*.png (flat turntables + shaded close-ups, closed and open), stats.json (sizes, tris, bbox centres, hide space)
#
# Conventions (as stage 2): 1 Blender unit = 1 stud, Z up, front faces -Y, stands on z=0, centred on x/y.
# Roblox axes after export are (x, z, -y), and the FBX export turns the mesh 180 deg about Y (texture-pipeline ship notes),
# so the pedestal at Blender -X ends up at Roblox +X with the front at -Z, exactly like c_desk_nodivider.
import bpy, bmesh, json, math, os, sys
import numpy as np
from mathutils import Vector
from mathutils.bvhtree import BVHTree

HERE = os.path.dirname(os.path.abspath(__file__))
HARDLIB = os.environ.get("HARDLIB_DIR", "F:/Dev/temp/claude/E--Projects/d1f6cb33-c53e-4180-8ef7-e885b69020d8/scratchpad/hard")
sys.path.insert(0, HARDLIB)
import hardlib as H
from hardlib import box, cylx

OUT = os.environ.get("DESK_OUT", HERE)
TEX, EXP, REN = (os.path.join(OUT, d) for d in ("textures", "export", "renders"))
for d in (TEX, EXP, REN):
    os.makedirs(d, exist_ok=True)

# ------------------------------------------------------------------ geometry ---
W, D, TOP, T = 8.8, 4.6, 4.95, 0.28
U = TOP - T                       # underside of the worktop, 4.67
PX0, PX1 = -4.25, -1.75           # pedestal outer x
PY0, PY1 = -1.95, 2.05            # pedestal shell y (front edge .. back)
PANEL = 0.1
FRONT_Y = -2.05                   # drawer fronts sit proud of the shell, as on c_desk_nodivider
DZ0, DZ1, NDR, GAP = 0.3, U - 0.08, 3, 0.06
DH = (DZ1 - DZ0 - (NDR - 1) * GAP) / NDR
BOX_BACK = 1.6                    # drawer box back face (y); box depth from the front = 3.68
SLIDE_MESH = 4.95 * 0.45 / (4.95 / D)   # the game slides drawers root.Size.Z * 0.45 = 2.2275 at DESK_SIZE.Z 4.95 -> 2.07 mesh units
HUG = (3.6, 4.2, 4.3)             # HUG_FREE_MIN W x H x D

groups = {"desk_body": [], "desk_drawer_1": [], "desk_drawer_2": [], "desk_drawer_3": []}


def grab(group, fn):
    n = len(H.parts); fn(); groups[group].extend(H.parts[n:])


def body():
    box("top", -W / 2, W / 2, -D / 2, D / 2, U, TOP, "wood", r=0.35, corners=("fl", "fr"), bevel=0.09)
    # hollow pedestal shell: two sides, back, floor; front rails between the drawers (seen when the drawers are out)
    box("ped_l", PX0, PX0 + PANEL, PY0, PY1, 0.22, U, "laminate", r=0.12, corners=("fl",), bevel=0.03)
    box("ped_r", PX1 - PANEL, PX1, PY0, PY1, 0.22, U, "laminate", r=0.12, corners=("fr",), bevel=0.03)
    box("ped_back", PX0 + PANEL, PX1 - PANEL, PY1 - PANEL, PY1, 0.22, U, "laminate", bevel=0.02)
    box("ped_floor", PX0 + PANEL, PX1 - PANEL, PY0, PY1 - PANEL, 0.22, 0.32, "laminate", bevel=0.02)
    box("ped_cap", PX0 + PANEL, PX1 - PANEL, PY0, PY1 - PANEL, U - 0.06, U, "laminate", bevel=0.0)
    for i in range(1, NDR):
        zc = DZ0 + i * (DH + GAP) - GAP / 2
        box(f"rail{i}", PX0 + PANEL, PX1 - PANEL, PY0, PY0 + 0.1, zc - 0.11, zc + 0.11, "laminate", bevel=0.015)
    box("plinth", -4.17, -1.83, -1.85, 1.95, 0.0, 0.24, "gap", bevel=0.02)
    box("leg", 3.85, 4.25, -2.05, 2.05, 0.0, U, "laminate", r=0.18, corners=("fl", "fr"), bevel=0.03)
    box("modesty", PX1, 3.85, 2.1, 2.22, 1.1, U, "laminate", bevel=0.03)


def drawer(i):
    a = DZ0 + i * (DH + GAP)
    x0, x1 = PX0, PX1
    box(f"dr{i}", x0 + 0.05, x1 - 0.05, FRONT_Y - 0.03, FRONT_Y + 0.14, a, a + DH, "drawer", bevel=0.035)
    hz = a + DH * 0.62; cx = (x0 + x1) / 2; hw = 1.2
    cylx(f"hd{i}", cx - hw / 2, cx + hw / 2, FRONT_Y - 0.2, hz, 0.05, "metal", 12)
    for sx in (-hw / 2 + 0.08, hw / 2 - 0.08):
        box(f"hp{i}{sx}", cx + sx - 0.035, cx + sx + 0.035, FRONT_Y - 0.2, FRONT_Y - 0.02, hz - 0.03, hz + 0.03, "metal", bevel=0)
    # the box behind the front: sides, back, bottom (oak), clear of the shell (inner faces at x -4.15 / -1.85)
    ix0, ix1 = x0 + PANEL + 0.02, x1 - PANEL - 0.02
    yb0 = FRONT_Y + 0.14
    zb0, zb1 = a + 0.1, a + DH - 0.16
    box(f"ds{i}a", ix0, ix0 + 0.06, yb0, BOX_BACK, zb0, zb1, "wood", bevel=0.01)
    box(f"ds{i}b", ix1 - 0.06, ix1, yb0, BOX_BACK, zb0, zb1, "wood", bevel=0.01)
    box(f"db{i}", ix0 + 0.06, ix1 - 0.06, BOX_BACK - 0.06, BOX_BACK, zb0, zb1, "wood", bevel=0.01)
    box(f"df{i}", ix0 + 0.06, ix1 - 0.06, yb0, BOX_BACK - 0.06, zb0, zb0 + 0.06, "wood", bevel=0.0)


# -------------------------------------------------------------------- finish ---
def apply_and_join(name, obs, smooth_angle=35):
    for ob in obs:
        bpy.context.view_layer.objects.active = ob
        for md in list(ob.modifiers):
            bpy.ops.object.modifier_apply(modifier=md.name)
    bpy.ops.object.select_all(action="DESELECT")
    for ob in obs:
        ob.select_set(True)
    bpy.context.view_layer.objects.active = obs[0]
    bpy.ops.object.join()
    ob = bpy.context.active_object; ob.name = name; ob.data.name = name
    bpy.ops.object.shade_smooth_by_angle(angle=math.radians(smooth_angle))
    bpy.ops.object.mode_set(mode="EDIT"); bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.mesh.quads_convert_to_tris()
    bpy.ops.object.mode_set(mode="OBJECT")
    return ob


def unwrap(obs):
    bpy.ops.object.select_all(action="DESELECT")
    for o in obs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = obs[0]
    bpy.ops.object.mode_set(mode="EDIT"); bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.uv.smart_project(angle_limit=math.radians(50), island_margin=0.006)   # multi-object: one shared atlas
    bpy.ops.object.mode_set(mode="OBJECT")


def bake_set(setname, obs, everything, tex=1024, ao_mix=0.7):
    """Bake colour x AO, tangent normal and roughness for `obs` into one atlas; the other meshes are hidden from the bake."""
    sc = bpy.context.scene
    for o in everything:
        o.hide_render = o not in obs
    bpy.ops.object.select_all(action="DESELECT")
    for o in obs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = obs[0]
    mats = {m for o in obs for m in o.data.materials}

    def target(img):
        for m in mats:
            N = m.node_tree.nodes; n = N.get("BAKE") or N.new("ShaderNodeTexImage")
            n.name = "BAKE"; n.image = img; N.active = n

    img_c = bpy.data.images.new(setname + "_c", tex, tex); img_ao = bpy.data.images.new(setname + "_ao", tex, tex)
    target(img_c); sc.cycles.samples = 16
    bpy.ops.object.bake(type="DIFFUSE", pass_filter={"COLOR"}, margin=24, margin_type="EXTEND")
    target(img_ao); sc.cycles.samples = 96
    bpy.ops.object.bake(type="AO", margin=24, margin_type="EXTEND")
    c = np.array(img_c.pixels[:]).reshape(tex, tex, 4)
    ao = np.array(img_ao.pixels[:]).reshape(tex, tex, 4)[..., :1]
    rgb = np.clip(c[..., :3] * ((1 - ao_mix) + ao_mix * ao), 0, 1)
    used = c[..., :3].sum(-1) > 0
    rgb[~used] = rgb[used].mean(0)
    png = bpy.data.images.new(setname + "_color", tex, tex)
    px = np.ones((tex, tex, 4)); px[..., :3] = rgb
    png.pixels = px.reshape(-1).tolist(); png.filepath_raw = os.path.join(TEX, setname + "_color.png"); png.file_format = "PNG"; png.save()
    img_n = bpy.data.images.new(setname + "_normal", tex, tex); img_n.colorspace_settings.name = "Non-Color"
    target(img_n); sc.cycles.samples = 8
    bpy.ops.object.bake(type="NORMAL", normal_space="TANGENT", margin=24, margin_type="EXTEND")
    nn = np.array(img_n.pixels[:]).reshape(tex, tex, 4)
    nn[nn[..., :3].sum(-1) == 0] = (0.5, 0.5, 1.0, 1.0)
    img_n.pixels = nn.reshape(-1).tolist()
    img_n.filepath_raw = os.path.join(TEX, setname + "_normal.png"); img_n.file_format = "PNG"; img_n.save()
    rtex = tex // 2
    img_r = bpy.data.images.new(setname + "_rough", rtex, rtex); img_r.colorspace_settings.name = "Non-Color"
    target(img_r)
    bpy.ops.object.bake(type="ROUGHNESS", margin=8, margin_type="EXTEND")
    rr = np.array(img_r.pixels[:]).reshape(rtex, rtex, 4)
    z = rr[..., :3].sum(-1) == 0
    if z.any() and (~z).any():
        rr[z] = (*(rr[~z][:, :3].mean(0)), 1.0)
    img_r.pixels = rr.reshape(-1).tolist()
    img_r.filepath_raw = os.path.join(TEX, setname + "_rough.png"); img_r.file_format = "PNG"; img_r.save()
    for o in everything:
        o.hide_render = False
    stats = {"color_std": float(rgb[used].std()), "normal_dev": float(np.abs(nn[..., :3] - (0.5, 0.5, 1.0)).mean()),
             "rough_mean": float(rr[..., 0].mean()), "rough_std": float(rr[..., 0].std())}
    return png, img_n, img_r, stats


def pbr_material(name, col, nrm, rgh):
    m = bpy.data.materials.new(name); m.use_nodes = True
    N, L = m.node_tree.nodes, m.node_tree.links
    b = next(n for n in N if n.type == "BSDF_PRINCIPLED")
    tc = N.new("ShaderNodeTexImage"); tc.image = col; L.new(tc.outputs["Color"], b.inputs["Base Color"])
    tn = N.new("ShaderNodeTexImage"); tn.image = nrm
    nm = N.new("ShaderNodeNormalMap"); L.new(tn.outputs["Color"], nm.inputs["Color"]); L.new(nm.outputs["Normal"], b.inputs["Normal"])
    tr = N.new("ShaderNodeTexImage"); tr.image = rgh; L.new(tr.outputs["Color"], b.inputs["Roughness"])
    N.active = tc       # Workbench "texture" colour shows the colour map
    return m


# ---------------------------------------------------------------- hide space ---
def hide_space(meshes):
    """Knee-hole checks on the final mesh (closed drawers): clear extents by ray casts, and a HUG_FREE_MIN box placed
    against the front edge on the floor tested for any triangle overlap or vertex inside."""
    deps = bpy.context.evaluated_depsgraph_get()
    vs, fs = [], []
    for o in meshes:
        base = len(vs)
        vs += [o.matrix_world @ v.co for v in o.data.vertices]
        fs += [[base + i for i in p.vertices] for p in o.data.polygons]
    tree = BVHTree.FromPolygons(vs, fs)
    allv = np.array([tuple(v) for v in vs])

    def ray(origin, d):
        hit = tree.ray_cast(Vector(origin), Vector(d))
        return hit[3] if hit[0] is not None else None

    # probe the knee-hole centre line at a few heights / depths
    probe = []
    for zz in (0.5, 2.0, 3.5, 4.4):
        for yy in (-1.5, 0.0, 1.5):
            left = ray((1.0, yy, zz), (-1, 0, 0)); right = ray((1.0, yy, zz), (1, 0, 0))
            probe.append({"y": yy, "z": zz, "x_from": round(1.0 - left, 3), "x_to": round(1.0 + right, 3)})
    up = ray((1.0, 0.0, 0.01), (0, 0, 1))
    back = ray((1.0, -2.29, 2.5), (0, 1, 0))
    clear_w = min(p["x_to"] - p["x_from"] for p in probe)
    # HUG_FREE_MIN box: front face at the worktop's front edge (-D/2), on the floor, centred in the knee-hole
    xc = (PX1 + 3.85) / 2
    bx0, bx1 = xc - HUG[0] / 2, xc + HUG[0] / 2
    by0, by1 = -D / 2, -D / 2 + HUG[2]
    bz0, bz1 = 0.0, HUG[1]
    bm = bmesh.new(); bmesh.ops.create_cube(bm, size=1.0)
    for v in bm.verts:
        v.co = Vector((bx0 if v.co.x < 0 else bx1, by0 if v.co.y < 0 else by1, bz0 if v.co.z < 0 else bz1))
    btree = BVHTree.FromBMesh(bm); bm.free()
    overlaps = len(tree.overlap(btree))
    inside = int(((allv[:, 0] > bx0) & (allv[:, 0] < bx1) & (allv[:, 1] > by0) & (allv[:, 1] < by1) & (allv[:, 2] > bz0) & (allv[:, 2] < bz1)).sum())
    return {
        "knee_clear_width": round(clear_w, 3), "knee_clear_height": round(up + 0.01, 3), "knee_clear_depth_from_front_edge": round(back, 3),
        "knee_probe": probe,
        "hug_box": {"x": [round(bx0, 3), round(bx1, 3)], "y": [round(by0, 3), round(by1, 3)], "z": [bz0, bz1],
                    "triangle_overlaps": overlaps, "vertices_inside": inside, "free": overlaps == 0 and inside == 0},
    }


# ------------------------------------------------------------------- renders ---
def look_setup():
    sc = bpy.context.scene
    cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam")); sc.collection.objects.link(cam); sc.camera = cam
    return cam


def aim(cam, target, d, dist):
    d = Vector(d).normalized()
    cam.location = Vector(target) + d * dist
    cam.rotation_euler = (-d).to_track_quat("-Z", "Y").to_euler()


def render_flat(cam, name, views):
    sc = bpy.context.scene
    sc.render.engine = "BLENDER_WORKBENCH"
    sh = sc.display.shading; sh.light = "FLAT"; sh.color_type = "TEXTURE"
    sc.world.color = (0.55, 0.6, 0.65)
    sc.render.resolution_x, sc.render.resolution_y = 900, 620
    cam.data.type = "ORTHO"
    out = []
    for v, d in views.items():
        cam.data.ortho_scale = 10.5
        aim(cam, (0, 0, 2.3), d, 20)
        p = os.path.join(REN, f"{name}_{v}.png"); sc.render.filepath = p
        bpy.ops.render.render(write_still=True); out.append(p)
    return out


def render_shaded(cam, name, target, d, dist, lens=40, res=(1200, 800)):
    sc = bpy.context.scene
    sc.render.engine = "CYCLES"; sc.cycles.device = "CPU"; sc.cycles.samples = 96
    try:
        sc.cycles.use_denoising = True
    except Exception:
        pass
    sc.render.resolution_x, sc.render.resolution_y = res
    cam.data.type = "PERSP"; cam.data.lens = lens
    aim(cam, target, d, dist)
    p = os.path.join(REN, name + ".png"); sc.render.filepath = p
    bpy.ops.render.render(write_still=True)
    return p


def main():
    H.reset()
    sc = bpy.context.scene
    sc.render.engine = "CYCLES"; sc.cycles.device = "CPU"
    grab("desk_body", body)
    for i in range(NDR):
        grab(f"desk_drawer_{NDR - i}", lambda i=i: drawer(i))     # desk_drawer_1 = top drawer
    meshes = {g: apply_and_join(g, obs) for g, obs in groups.items()}
    body_ob = meshes["desk_body"]
    # the three drawers share one atlas: join them (tagged by vertex group), unwrap + bake once, then split them again
    dnames = [f"desk_drawer_{k}" for k in (1, 2, 3)]
    for n in dnames:
        o = meshes[n]; vg = o.vertex_groups.new(name=n); vg.add(list(range(len(o.data.vertices))), 1.0, "REPLACE")
    bpy.ops.object.select_all(action="DESELECT")
    for n in dnames:
        meshes[n].select_set(True)
    bpy.context.view_layer.objects.active = meshes[dnames[0]]
    bpy.ops.object.join()
    dj = bpy.context.active_object; dj.name = "desk_drawers_joined"
    unwrap([body_ob]); unwrap([dj])
    b_col, b_nrm, b_rgh, b_st = bake_set("desk_body", [body_ob], [body_ob, dj])
    d_col, d_nrm, d_rgh, d_st = bake_set("desk_drawers", [dj], [body_ob, dj])
    drawers = []
    for n in dnames[1:]:
        bpy.ops.object.select_all(action="DESELECT"); dj.select_set(True); bpy.context.view_layer.objects.active = dj
        bpy.ops.object.mode_set(mode="EDIT"); bpy.ops.mesh.select_all(action="DESELECT")
        dj.vertex_groups.active_index = dj.vertex_groups[n].index; bpy.ops.object.vertex_group_select()
        before = set(bpy.context.scene.objects)
        bpy.ops.mesh.separate(type="SELECTED"); bpy.ops.object.mode_set(mode="OBJECT")
        piece = [o for o in bpy.context.scene.objects if o not in before][0]; piece.name = n; piece.data.name = n
        drawers.append(piece)
    dj.name = dnames[0]; dj.data.name = dnames[0]
    drawers.insert(0, dj)
    for o in drawers:
        o.vertex_groups.clear()
    everything = [body_ob] + drawers
    mb = pbr_material("desk_body_pbr", b_col, b_nrm, b_rgh); md = pbr_material("desk_drawers_pbr", d_col, d_nrm, d_rgh)
    for o in everything:
        o.data.materials.clear(); o.data.materials.append(mb if o is body_ob else md)

    # stats: sizes, tris, bbox centres (Blender and Roblox axes after the FBX 180-yaw: (x, z, -y) then x,z negated -> (-x, z, y))
    def bbox(o):
        vs = np.array([tuple(o.matrix_world @ v.co) for v in o.data.vertices])
        return vs.min(0), vs.max(0)
    allv = np.vstack([np.array([tuple(v.co) for v in o.data.vertices]) for o in everything])
    stats = {"overall_size_WxHxD": [round(float(np.ptp(allv[:, 0])), 3), round(float(np.ptp(allv[:, 2])), 3), round(float(np.ptp(allv[:, 1])), 3)],
             "slide_mesh_units": round(SLIDE_MESH, 3), "drawer_box_depth": round(BOX_BACK - (FRONT_Y - 0.03), 3), "meshes": {},
             "tex_stats": {"desk_body": b_st, "desk_drawers": d_st}}
    for o in everything:
        lo, hi = bbox(o); c = (lo + hi) / 2
        stats["meshes"][o.name] = {"tris": len(o.data.polygons), "size_WxHxD": [round(float(hi[0] - lo[0]), 3), round(float(hi[2] - lo[2]), 3), round(float(hi[1] - lo[1]), 3)],
                                  "bbox_centre_blender": [round(float(x), 3) for x in c],
                                  "bbox_centre_roblox_after_fbx": [round(float(-c[0]), 3), round(float(c[2]), 3), round(float(c[1]), 3)],
                                  "search_component": "drawer" if o is not body_ob else None}
    stats["hide_space"] = hide_space(everything)

    # exports: preview glb, then FBX (materials stripped, as to_fbx_multi.py) per mesh + combined, and OBJ per mesh
    bpy.ops.object.select_all(action="DESELECT")
    for o in everything:
        o.select_set(True)
    bpy.ops.export_scene.gltf(filepath=os.path.join(EXP, "desk_drawers_parts.glb"), use_selection=True, export_format="GLB")
    saved = {o: list(o.data.materials) for o in everything}
    for o in everything:
        o.data.materials.clear()
    fbx = dict(apply_unit_scale=True, apply_scale_options="FBX_SCALE_UNITS", axis_forward="-Z", axis_up="Y", path_mode="STRIP",
               mesh_smooth_type="FACE", use_tspace=True, use_selection=True)
    bpy.ops.export_scene.fbx(filepath=os.path.join(EXP, "desk_drawers.fbx"), **fbx)
    for o in everything:
        bpy.ops.object.select_all(action="DESELECT"); o.select_set(True); bpy.context.view_layer.objects.active = o
        bpy.ops.export_scene.fbx(filepath=os.path.join(EXP, o.name + ".fbx"), **fbx)
        bpy.ops.wm.obj_export(filepath=os.path.join(EXP, o.name + ".obj"), export_selected_objects=True, export_materials=False,
                              forward_axis="NEGATIVE_Z", up_axis="Y")
    for o, ms in saved.items():
        for m in ms:
            o.data.materials.append(m)

    # renders
    if sc.world is None:
        sc.world = bpy.data.worlds.new("w")
    cam = look_setup()
    views = {"front": (0, -1, 0.15), "back": (0, 1, 0.15), "side": (-1, 0, 0.1), "below": (0.2, -0.4, -1), "tq": (0.6, -1, 0.5)}
    renders = render_flat(cam, "flat_closed", views)
    for o in drawers:
        o.location.y -= SLIDE_MESH
    renders += render_flat(cam, "flat_open", {"tq": (0.6, -1, 0.5), "front": (0, -1, 0.15)})
    # shaded close-ups (Cycles, colour + normal + roughness): a soft key light, a fill and a grey world
    sc.world.use_nodes = True
    bg = next(n for n in sc.world.node_tree.nodes if n.type == "BACKGROUND")
    bg.inputs["Color"].default_value = (0.35, 0.37, 0.4, 1); bg.inputs["Strength"].default_value = 0.6
    for nm, loc, en, sz in (("key", (-6, -8, 10), 2500, 6), ("fill", (8, -6, 5), 700, 8), ("rim", (2, 8, 8), 600, 6)):
        L = bpy.data.objects.new(nm, bpy.data.lights.new(nm, "AREA")); L.data.energy = en; L.data.size = sz
        L.location = loc; L.rotation_euler = (-Vector(loc)).to_track_quat("-Z", "Y").to_euler(); sc.collection.objects.link(L)
    floor_me = bpy.data.meshes.new("floor"); floor_me.from_pydata([(-30, -30, 0), (30, -30, 0), (30, 30, 0), (-30, 30, 0)], [], [(0, 1, 2, 3)])
    floor = bpy.data.objects.new("floor", floor_me); sc.collection.objects.link(floor)
    fm = bpy.data.materials.new("floor"); fm.use_nodes = True
    next(n for n in fm.node_tree.nodes if n.type == "BSDF_PRINCIPLED").inputs["Base Color"].default_value = (0.18, 0.18, 0.19, 1)
    floor.data.materials.append(fm)
    renders.append(render_shaded(cam, "shaded_open_closeup", (-3.0, -2.6, 2.6), (0.35, -1, 0.55), 9.0))
    renders.append(render_shaded(cam, "shaded_open_tq", (0, -0.5, 2.3), (0.6, -1, 0.5), 16.0))
    for o in drawers:
        o.location.y += SLIDE_MESH
    renders.append(render_shaded(cam, "shaded_closed_tq", (0, -0.5, 2.3), (0.6, -1, 0.5), 16.0))
    renders.append(render_shaded(cam, "shaded_kneehole", (1.0, -1.0, 2.0), (0.15, -1, 0.25), 11.0))
    stats["renders"] = [os.path.relpath(p, OUT).replace("\\", "/") for p in renders]
    with open(os.path.join(OUT, "stats.json"), "w") as f:
        json.dump(stats, f, indent=1)
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(EXP, "desk_drawers.blend"))
    print("DONE", json.dumps({k: v for k, v in stats.items() if k != "renders"}))


main()
