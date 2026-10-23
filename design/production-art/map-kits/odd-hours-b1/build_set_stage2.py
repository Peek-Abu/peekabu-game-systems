# Odd Hours office map, stage 2: new hand-built props (serverRack, doorLeaf, doorLeafGlass, supplyCabinet, stairwellSign).
#
# HOW TO RUN (Blender 5.1 headless; needs the texture-pipeline working set next to hardlib.py:
#   ../texlab/out/oak_scan_color.png, ../cc0/Wood049, ../cc0/PaintedPlaster017, as in the mock-room test):
#   "C:/Program Files/Blender Foundation/Blender 5.1/blender.exe" --background --python build_set_stage2.py -- serverRack doorLeaf doorLeafGlass supplyCabinet stairwellSign
# Env STAGE2_OUT = output folder (default ../real/stage2). Per prop it writes:
#   <name>_color.png (colour x AO), <name>_normal.png (tangent, OpenGL), <name>_rough.png,
#   <name>_parts.glb (separate objects: LED_* / Glass kept apart), <name>_tt.glb (one joined mesh, for turntable.py)
# Then: blender --background --python to_fbx_multi.py -- <outdir> <name>_parts.glb ...   (FBX, materials stripped, 1 unit = 1 stud).
#
# Conventions (same as the mock-room props): 1 Blender unit = 1 stud, Blender Z up, front faces -Y, stands on z=0, centred on x/y.
# Roblox axes after export are (x, z, -y); the FBX export turns the mesh 180 deg about Y (see the texture-pipeline ship notes).
# Separate objects for the Studio assembly: serverRack -> LED_Green / LED_Amber / LED_Blue (make them Neon); doorLeafGlass -> Glass.
# Door hinge side is the leaf's -X edge (three drawn hinge leaves sit on it); the lever/latch side is +X.
import bpy, bmesh, math, os, sys
import numpy as np
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import hardlib as H
from hardlib import box, cyl, cylx, sphere, rot, cone, _new, _noise_tint, _painted, TEXLAB
from mathutils import Vector

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.environ.get("STAGE2_OUT", os.path.join(HERE, "..", "real", "stage2"))
PROPS = {}


def prop(fn):
    PROPS[fn.__name__] = fn
    return fn


# ---------------------------------------------------------------- materials ---
def _perf(name, rgb, axes, scale=4.0):
    """Drawn perforation: dark slots on steel, with a matching bump. `axes` picks the two object axes the pattern runs along
    (the pattern must follow the face it is drawn on): 'xz' front/back, 'yz' sides, 'xy' top."""
    m, N, L, b = _new(name)
    tc = N.new("ShaderNodeTexCoord"); sep = N.new("ShaderNodeSeparateXYZ"); com = N.new("ShaderNodeCombineXYZ")
    L.new(tc.outputs["Object"], sep.inputs["Vector"])
    ia, ib = {"xz": ("X", "Z"), "yz": ("Y", "Z"), "xy": ("X", "Y")}[axes]
    L.new(sep.outputs[ia], com.inputs["X"]); L.new(sep.outputs[ib], com.inputs["Y"])
    br = N.new("ShaderNodeTexBrick")
    br.offset = 0.5; br.squash = 1.0
    br.inputs["Scale"].default_value = scale
    br.inputs["Brick Width"].default_value = 1.7; br.inputs["Row Height"].default_value = 0.42
    br.inputs["Mortar Size"].default_value = 0.1; br.inputs["Mortar Smooth"].default_value = 0.2
    br.inputs["Color1"].default_value = (0.004, 0.004, 0.005, 1); br.inputs["Color2"].default_value = (0.006, 0.006, 0.007, 1)
    br.inputs["Mortar"].default_value = (*rgb, 1)
    L.new(com.outputs["Vector"], br.inputs["Vector"]); L.new(br.outputs["Color"], b.inputs["Base Color"])
    bp = N.new("ShaderNodeBump"); bp.invert = False; bp.inputs["Strength"].default_value = 0.9; bp.inputs["Distance"].default_value = 0.02
    L.new(br.outputs["Fac"], bp.inputs["Height"]); L.new(bp.outputs["Normal"], b.inputs["Normal"])
    b.inputs["Roughness"].default_value = 0.65
    return m


def _glass():
    m = _noise_tint("glassmat", (0.46, 0.58, 0.62), 0.0, 10, mottle=0.0)
    next(n for n in m.node_tree.nodes if n.type == "BSDF_PRINCIPLED").inputs["Roughness"].default_value = 0.06
    return m


def _rough(key, fn, r):
    def make():
        m = fn(); next(n for n in m.node_tree.nodes if n.type == "BSDF_PRINCIPLED").inputs["Roughness"].default_value = r
        return m
    H._SPEC[key] = make


H._SPEC.update({
    "perf_f": lambda: _perf("perf_f", (0.050, 0.052, 0.058), "xz"),
    "perf_s": lambda: _perf("perf_s", (0.050, 0.052, 0.058), "yz"),
    "perf_t": lambda: _perf("perf_t", (0.050, 0.052, 0.058), "xy"),
    "glassmat": _glass,
})
H._SPEC["charcoal"] = lambda: _painted("charcoal", (0.050, 0.052, 0.058), 0.72, 0.18)
H._SPEC["graysteel"] = lambda: _painted("graysteel", (0.34, 0.37, 0.37), 0.45, 0.1)
H._SPEC["led_green"] = lambda: _noise_tint("led_green", (0.10, 0.80, 0.22), 0.0, 10, mottle=0.0)
H._SPEC["led_amber"] = lambda: _noise_tint("led_amber", (0.95, 0.52, 0.04), 0.0, 10, mottle=0.0)
H._SPEC["led_blue"] = lambda: _noise_tint("led_blue", (0.10, 0.35, 0.95), 0.0, 10, mottle=0.0)
H._SPEC["labelplate"] = lambda: _painted("labelplate", (0.78, 0.78, 0.72), 0.5, 0.03)

SPECIAL = {"led_green": "LED_Green", "led_amber": "LED_Amber", "led_blue": "LED_Blue", "glassmat": "Glass"}


# ------------------------------------------------------------------ finish ---
def finish2(name, tex=1024, ao_mix=0.7, smooth_angle=35):
    """Like hardlib.finish, but: writes colour/normal/roughness PNGs, and keeps LED_* / Glass material pieces as separate objects."""
    os.makedirs(OUT, exist_ok=True)
    sc = bpy.context.scene
    for ob in H.parts:
        bpy.context.view_layer.objects.active = ob
        for md in list(ob.modifiers):
            bpy.ops.object.modifier_apply(modifier=md.name)
    bpy.ops.object.select_all(action="DESELECT")
    for ob in H.parts:
        ob.select_set(True)
    bpy.context.view_layer.objects.active = H.parts[0]
    bpy.ops.object.join()
    ob = bpy.context.active_object; ob.name = name
    bpy.ops.object.shade_smooth_by_angle(angle=math.radians(smooth_angle))
    bpy.ops.object.mode_set(mode="EDIT"); bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.mesh.quads_convert_to_tris()
    bpy.ops.uv.smart_project(angle_limit=math.radians(50), island_margin=0.006)
    bpy.ops.object.mode_set(mode="OBJECT")
    dims = [round(x, 3) for x in ob.dimensions]
    sc.render.engine = "CYCLES"; sc.cycles.device = "CPU"
    img_c = bpy.data.images.new("bake_c", tex, tex); img_ao = bpy.data.images.new("bake_ao", tex, tex)

    def target(img):
        for m in ob.data.materials:
            N = m.node_tree.nodes; n = N.get("BAKE") or N.new("ShaderNodeTexImage")
            n.name = "BAKE"; n.image = img; N.active = n
    target(img_c); sc.cycles.samples = 16
    bpy.ops.object.bake(type="DIFFUSE", pass_filter={"COLOR"}, margin=24, margin_type="EXTEND")
    target(img_ao); sc.cycles.samples = 96
    bpy.ops.object.bake(type="AO", margin=24, margin_type="EXTEND")
    c = np.array(img_c.pixels[:]).reshape(tex, tex, 4)
    ao = np.array(img_ao.pixels[:]).reshape(tex, tex, 4)[..., :1]
    rgb = np.clip(c[..., :3] * ((1 - ao_mix) + ao_mix * ao), 0, 1)
    used = c[..., :3].sum(-1) > 0           # unbaked atlas space is pure black: fill it with the mean surface colour (no mip bleed to black)
    rgb[~used] = rgb[used].mean(0)
    png = bpy.data.images.new("out", tex, tex)
    px = np.ones((tex, tex, 4)); px[..., :3] = rgb
    png.pixels = px.reshape(-1).tolist(); png.filepath_raw = os.path.join(OUT, name + "_color.png"); png.file_format = "PNG"; png.save()
    img_n = bpy.data.images.new("bake_n", tex, tex); img_n.colorspace_settings.name = "Non-Color"
    target(img_n); sc.cycles.samples = 8
    bpy.ops.object.bake(type="NORMAL", normal_space="TANGENT", margin=24, margin_type="EXTEND")
    nn = np.array(img_n.pixels[:]).reshape(tex, tex, 4)
    nn[nn[..., :3].sum(-1) == 0] = (0.5, 0.5, 1.0, 1.0)
    img_n.pixels = nn.reshape(-1).tolist()
    img_n.filepath_raw = os.path.join(OUT, name + "_normal.png"); img_n.file_format = "PNG"; img_n.save()
    rtex = tex // 2
    img_r = bpy.data.images.new("bake_r", rtex, rtex); img_r.colorspace_settings.name = "Non-Color"
    target(img_r)
    bpy.ops.object.bake(type="ROUGHNESS", margin=8, margin_type="EXTEND")
    rr = np.array(img_r.pixels[:]).reshape(rtex, rtex, 4)
    z = rr[..., :3].sum(-1) == 0
    if z.any() and (~z).any():
        rr[z] = (*(rr[~z][:, :3].mean(0)), 1.0)
    img_r.pixels = rr.reshape(-1).tolist()
    img_r.filepath_raw = os.path.join(OUT, name + "_rough.png"); img_r.file_format = "PNG"; img_r.save()
    # split the special pieces (LED_*, Glass) into their own objects, keeping the shared UV atlas
    mats = list(ob.data.materials)
    made = []
    for idx, m in enumerate(mats):
        base = SPECIAL.get(m.name.split(".")[0])
        if not base:
            continue
        bpy.ops.object.select_all(action="DESELECT"); ob.select_set(True); bpy.context.view_layer.objects.active = ob
        bpy.ops.object.mode_set(mode="EDIT"); bpy.ops.mesh.select_all(action="DESELECT")
        ob.active_material_index = idx; bpy.ops.object.material_slot_select()
        before = set(bpy.context.scene.objects)
        bpy.ops.mesh.separate(type="SELECTED")
        bpy.ops.object.mode_set(mode="OBJECT")
        piece = [o for o in bpy.context.scene.objects if o not in before][0]
        if base.startswith("LED_"):
            bpy.ops.object.select_all(action="DESELECT"); piece.select_set(True); bpy.context.view_layer.objects.active = piece
            bpy.ops.object.mode_set(mode="EDIT"); bpy.ops.mesh.select_all(action="SELECT")
            b2 = set(bpy.context.scene.objects)
            bpy.ops.mesh.separate(type="LOOSE")
            bpy.ops.object.mode_set(mode="OBJECT")
            pcs = [piece] + [o for o in bpy.context.scene.objects if o not in b2 and o is not piece]
            pcs.sort(key=lambda o: -sum(v.co.z for v in o.data.vertices) / len(o.data.vertices))
            for i, o in enumerate(pcs):
                o.name = base if len(pcs) == 1 else f"{base}_{i + 1}"; made.append(o)
        else:
            piece.name = base; made.append(piece)
    allobs = [o for o in bpy.context.scene.objects if o.type == "MESH"]
    bm_ = bpy.data.materials.new("baked"); bm_.use_nodes = True
    t = bm_.node_tree.nodes.new("ShaderNodeTexImage"); t.image = png
    bm_.node_tree.links.new(t.outputs["Color"], next(n for n in bm_.node_tree.nodes if n.type == "BSDF_PRINCIPLED").inputs["Base Color"])
    for o in allobs:
        o.data.materials.clear(); o.data.materials.append(bm_)
    bpy.ops.object.select_all(action="DESELECT")
    for o in allobs:
        o.select_set(True)
    bpy.ops.export_scene.gltf(filepath=os.path.join(OUT, name + "_parts.glb"), use_selection=True, export_format="GLB")
    names = sorted(o.name for o in allobs)
    tris = sum(len(o.data.polygons) for o in allobs)
    bpy.context.view_layer.objects.active = allobs[0]
    bpy.ops.object.join()
    j = bpy.context.active_object; j.name = name + "_tt"
    bpy.ops.object.select_all(action="DESELECT"); j.select_set(True)
    bpy.ops.export_scene.gltf(filepath=os.path.join(OUT, name + "_tt.glb"), use_selection=True, export_format="GLB")
    print("DONE", name, "tris", tris, "size", dims, "objects", names)


# ----------------------------------------------------------------- serverRack ---
@prop
def serverRack():
    """2 W x 7 H x 3.5 D. Matte charcoal; perforated front door, three LED strips (separate LED_* objects), side + top vents."""
    X, Y0, Y1, Hh = 1.0, -1.75, 1.75, 7.0
    box("feet", -0.9, 0.9, -1.55, 1.65, 0.0, 0.3, "charcoal", bevel=0.02)
    box("body", -X, X, -1.6, Y1, 0.3, 6.9, "charcoal", r=0.06, corners=("fl", "fr", "bl", "br"), bevel=0.03)
    box("cap", -X, X, -1.65, Y1, 6.88, 6.99, "charcoal", bevel=0.03)
    # front door, set slightly proud of the body
    box("door", -0.95, 0.95, -1.70, -1.58, 0.4, 6.8, "charcoal", bevel=0.025)
    box("seam", -0.96, 0.96, -1.585, -1.55, 0.37, 6.83, "gap", bevel=0)
    # drawn perforation: two panels (upper + lower), front face flush with y=-1.74
    box("perf_up", -0.78, 0.78, -1.74, -1.69, 3.65, 6.6, "perf_f", bevel=0)
    box("perf_lo", -0.78, 0.78, -1.74, -1.69, 0.6, 2.45, "perf_f", bevel=0)
    # mid band: label plate + three LED strips (activity bars)
    box("label", -0.72, -0.1, -1.715, -1.69, 3.3, 3.5, "labelplate", bevel=0)
    box("LED_g", -0.72, 0.2, -1.745, -1.70, 2.98, 3.06, "led_green", bevel=0)
    box("LED_a", -0.72, -0.1, -1.745, -1.70, 2.82, 2.90, "led_amber", bevel=0)
    box("LED_b", -0.72, 0.5, -1.745, -1.70, 2.66, 2.74, "led_blue", bevel=0)
    # vertical handle + lock
    for z in (3.0, 4.2):
        box(f"stand{z}", 0.74, 0.82, -1.745, -1.69, z - 0.04, z + 0.04, "metal", bevel=0)
    box("handle", 0.74, 0.82, -1.75, -1.72, 2.96, 4.24, "metal", bevel=0.01)
    cyl("lock", 0.5, 3.5, -1.72, -1.69, 0.07, "metal", verts=12, axis="Y")
    # side vents + top vent
    for sx in (-1, 1):
        x0, x1 = (X - 0.04, X) if sx > 0 else (-X, -X + 0.04)
        box(f"side{sx}", x0, x1, -1.0, 1.3, 1.0, 6.2, "perf_s", bevel=0)
    box("top_vent", -0.65, 0.65, -0.9, 1.1, 6.96, 7.0, "perf_t", bevel=0)
    # back: cable gland plate and two small connectors
    box("gland", -0.6, 0.6, Y1 - 0.02, Y1, 0.8, 1.4, "gap", bevel=0)
    for i in range(4):
        cyl(f"port{i}", -0.45 + i * 0.3, 1.2, Y1 - 0.05, Y1, 0.09, "metal", verts=10, axis="Y")
    box("back_perf", -0.7, 0.7, Y1 - 0.04, Y1, 2.0, 6.2, "perf_f", bevel=0)
    finish2("serverRack")


# ---------------------------------------------------------------------- doors ---
def _door_hardware(lever_x, lever_z, rose_r):
    """Kick plate, rose + lever (both faces), screws, hinges (-X edge). Everything stays inside y +-0.15."""
    for s in (-1, 1):
        ya, yb = (0.09, 0.105) if s > 0 else (-0.105, -0.09)
        box(f"kick{s}", -2.8, 2.8, ya, yb, 0.05, 1.2, "alu", bevel=0.005, segs=1)
        for sx in (-2.55, 2.55):
            for sz in (0.25, 1.0):
                cyl(f"scr{s}{sx}{sz}", sx, sz, yb if s > 0 else ya - 0.012, yb + 0.012 if s > 0 else ya, 0.05, "metal", verts=8, bevel=0, axis="Y")
        r0, r1 = (0.105, 0.125) if s > 0 else (-0.125, -0.105)
        cyl(f"rose{s}", lever_x, lever_z, r0, r1, rose_r, "alu", verts=20, axis="Y")
        l0, l1 = (0.125, 0.15) if s > 0 else (-0.15, -0.125)
        box(f"neck{s}", lever_x - 0.11, lever_x + 0.11, l0, l1, lever_z - 0.11, lever_z + 0.11, "alu", bevel=0.01, segs=1)
        box(f"lever{s}", lever_x - 1.15, lever_x + 0.08, l0, l1, lever_z - 0.08, lever_z + 0.08, "alu", r=0.05, corners=("tl", "bl", "tr", "br"), axis="Y", bevel=0.008, segs=1)
    for hz in (1.4, 4.4, 7.4):    # hinge leaves on the -X edge
        box(f"hinge{hz}", -2.95, -2.78, -0.1, 0.1, hz, hz + 0.65, "metal", bevel=0.01, segs=1)
        cyl(f"pin{hz}", -2.88, hz + 0.325, -0.1, 0.1, 0.06, "metal", verts=10, axis="Y")


def _panel_lines(x0, x1, z0, z1, w=0.05):
    """A drawn rectangular panel outline on both faces (dark thin strips)."""
    for s in (-1, 1):
        ya, yb = (0.09, 0.096) if s > 0 else (-0.096, -0.09)
        box(f"pl_t{s}{z1}", x0, x1, ya, yb, z1 - w, z1, "gap", bevel=0)
        box(f"pl_b{s}{z0}", x0, x1, ya, yb, z0, z0 + w, "gap", bevel=0)
        box(f"pl_l{s}{z0}", x0, x0 + w, ya, yb, z0, z1, "gap", bevel=0)
        box(f"pl_r{s}{z0}", x1 - w, x1, ya, yb, z0, z1, "gap", bevel=0)


@prop
def doorLeaf():
    """5.9 W x 9 H x 0.3 D oak-veneer office door. Hinge side = -X edge. Steel kick plate, lever on both faces."""
    box("slab", -2.95, 2.95, -0.09, 0.09, 0.0, 9.0, "wood_v", bevel=0.03)
    box("edge_l", -2.95, -2.93, -0.092, 0.092, 0.0, 9.0, "gap", bevel=0)
    _panel_lines(-2.25, 2.0, 5.0, 8.4)
    _panel_lines(-2.25, 2.0, 1.75, 4.5)
    _door_hardware(2.5, 4.7, 0.27)
    finish2("doorLeaf")


@prop
def doorLeafGlass():
    """Same outer frame as doorLeaf (oak stiles 0.6 wide). Centre glass panel is the separate object `Glass`."""
    box("stile_l", -2.95, -2.35, -0.09, 0.09, 0.0, 9.0, "wood_v", bevel=0.03)
    box("stile_r", 2.35, 2.95, -0.09, 0.09, 0.0, 9.0, "wood_v", bevel=0.03)
    box("rail_t", -2.35, 2.35, -0.09, 0.09, 8.4, 9.0, "wood", bevel=0.03)
    box("rail_b", -2.35, 2.35, -0.09, 0.09, 0.0, 1.8, "wood", bevel=0.03)
    box("Glass", -2.3, 2.3, -0.03, 0.03, 1.8, 8.4, "glassmat", bevel=0)
    for s in (-1, 1):   # beads framing the glass
        ya, yb = (0.03, 0.105) if s > 0 else (-0.105, -0.03)
        box(f"bead_t{s}", -2.35, 2.35, ya, yb, 8.3, 8.4, "wood", bevel=0.01, segs=1)
        box(f"bead_b{s}", -2.35, 2.35, ya, yb, 1.8, 1.9, "wood", bevel=0.01, segs=1)
        box(f"bead_l{s}", -2.35, -2.25, ya, yb, 1.8, 8.4, "wood", bevel=0.01, segs=1)
        box(f"bead_r{s}", 2.25, 2.35, ya, yb, 1.8, 8.4, "wood", bevel=0.01, segs=1)
    box("edge_l", -2.95, -2.93, -0.092, 0.092, 0.0, 9.0, "gap", bevel=0)
    _door_hardware(2.65, 4.7, 0.22)
    finish2("doorLeafGlass")


# -------------------------------------------------------------- supplyCabinet ---
@prop
def supplyCabinet():
    """4.32 W x 8 H x 3.45 D closed steel cabinet (a hide spot; the Hide system handles the inside). Two doors, vent slots, label plate."""
    W, D, Hh = 4.32, 3.45, 8.0
    x = W / 2; yf = -D / 2
    box("kick", -x + 0.1, x - 0.1, yf + 0.3, D / 2 - 0.05, 0.0, 0.35, "gap", bevel=0.01)
    box("body", -x, x, yf + 0.26, D / 2, 0.3, Hh - 0.1, "graysteel", r=0.07, corners=("fl", "fr", "bl", "br"), bevel=0.03)
    box("crown", -x, x, yf + 0.2, D / 2, Hh - 0.12, Hh, "graysteel", bevel=0.04)
    gap = 0.06; fy = yf + 0.12            # door front plane
    for i, (a, b) in enumerate(((-x + 0.06, -gap / 2), (gap / 2, x - 0.06))):
        box(f"door{i}", a, b, fy, yf + 0.27, 0.42, Hh - 0.18, "graysteel", bevel=0.035)
        w = 0.04                          # drawn recessed-panel outline
        box(f"pnl_t{i}", a + 0.25, b - 0.25, fy - 0.01, fy + 0.02, 6.3, 6.3 + w, "gap", bevel=0)
        box(f"pnl_b{i}", a + 0.25, b - 0.25, fy - 0.01, fy + 0.02, 1.0, 1.0 + w, "gap", bevel=0)
        box(f"pnl_l{i}", a + 0.25, a + 0.25 + w, fy - 0.01, fy + 0.02, 1.0, 6.34, "gap", bevel=0)
        box(f"pnl_r{i}", b - 0.25 - w, b - 0.25, fy - 0.01, fy + 0.02, 1.0, 6.34, "gap", bevel=0)
        for k in range(6):                # vent slots near the top
            zz = 7.0 + k * 0.12
            box(f"vent{i}{k}", a + 0.5, b - 0.5, fy - 0.01, fy + 0.03, zz, zz + 0.06, "gap", bevel=0)
        hx = b - 0.32 if i == 0 else a + 0.32
        for hz in (3.4, 4.9):
            box(f"hs{i}{hz}", hx - 0.04, hx + 0.04, yf, fy + 0.03, hz - 0.04, hz + 0.04, "alu", bevel=0)
        box(f"handle{i}", hx - 0.05, hx + 0.05, yf, yf + 0.06, 3.3, 5.0, "alu", r=0.04, corners=("tl", "tr", "bl", "br"), axis="Y", bevel=0.01, segs=1)
    box("label_f", -x + 0.4, -x + 1.5, fy - 0.012, fy + 0.02, 5.35, 5.95, "alu", bevel=0)
    box("label", -x + 0.46, -x + 1.44, fy - 0.02, fy + 0.0, 5.41, 5.89, "labelplate", bevel=0)
    finish2("supplyCabinet")


# --------------------------------------------------------------- stairwellSign ---
def _sign_images():
    """PIL is not in Blender's Python, so the sign art is drawn by sign_images.py under `py -3.9 -I`."""
    import subprocess
    subprocess.check_call(["py", "-3.9", "-I", os.path.join(HERE, "sign_images.py"), OUT])


@prop
def stairwellSign():
    """2 W x 1 H x 0.1 D plate, "FLOORS 2-14" + stair pictogram drawn with PIL into the colour map (hand-set UVs: face = top half of the atlas)."""
    os.makedirs(OUT, exist_ok=True)
    _sign_images()
    W, D, Hh = 2.0, 0.1, 1.0
    me = bpy.data.meshes.new("sign")
    bm = bmesh.new()
    x0, x1, y0, y1, z0, z1 = -W / 2, W / 2, -D / 2, D / 2, 0.0, Hh
    v = {(i, j, k): bm.verts.new((x1 if i else x0, y1 if j else y0, z1 if k else z0)) for i in (0, 1) for j in (0, 1) for k in (0, 1)}
    uvl = bm.loops.layers.uv.new("UVMap")

    def face(vs, uvfn):
        f = bm.faces.new(vs)
        for lp in f.loops:
            lp[uvl].uv = uvfn(lp.vert.co)
    # front (-Y): u from x, v in 0.5..1 from z; windings give outward normals
    face([v[0, 0, 0], v[1, 0, 0], v[1, 0, 1], v[0, 0, 1]], lambda p: ((p.x - x0) / W, 0.5 + 0.5 * (p.z - z0) / Hh))
    flat = lambda p: (0.05 + 0.1 * ((p.x - x0) / W), 0.1 + 0.1 * (p.z / Hh))
    face([v[1, 1, 0], v[0, 1, 0], v[0, 1, 1], v[1, 1, 1]], flat)
    face([v[0, 1, 0], v[0, 0, 0], v[0, 0, 1], v[0, 1, 1]], lambda p: (0.3 + 0.05 * p.y, 0.1 + 0.1 * p.z))
    face([v[1, 0, 0], v[1, 1, 0], v[1, 1, 1], v[1, 0, 1]], lambda p: (0.5 + 0.05 * p.y, 0.1 + 0.1 * p.z))
    face([v[0, 0, 1], v[1, 0, 1], v[1, 1, 1], v[0, 1, 1]], lambda p: (0.6 + 0.2 * ((p.x - x0) / W), 0.1 + 0.05 * p.y))
    face([v[0, 1, 0], v[1, 1, 0], v[1, 0, 0], v[0, 0, 0]], lambda p: (0.6 + 0.2 * ((p.x - x0) / W), 0.3 + 0.05 * p.y))
    bm.to_mesh(me); bm.free()
    ob = bpy.data.objects.new("stairwellSign", me); bpy.context.scene.collection.objects.link(ob)
    mat = bpy.data.materials.new("sign"); mat.use_nodes = True
    t = mat.node_tree.nodes.new("ShaderNodeTexImage"); t.image = bpy.data.images.load(os.path.join(OUT, "stairwellSign_color.png"))
    mat.node_tree.links.new(t.outputs["Color"], next(n for n in mat.node_tree.nodes if n.type == "BSDF_PRINCIPLED").inputs["Base Color"])
    me.materials.append(mat)
    bpy.ops.object.select_all(action="DESELECT"); ob.select_set(True); bpy.context.view_layer.objects.active = ob
    bpy.ops.object.mode_set(mode="EDIT"); bpy.ops.mesh.select_all(action="SELECT"); bpy.ops.mesh.quads_convert_to_tris(); bpy.ops.object.mode_set(mode="OBJECT")
    for nm in ("_parts.glb", "_tt.glb"):
        bpy.ops.export_scene.gltf(filepath=os.path.join(OUT, "stairwellSign" + nm), use_selection=True, export_format="GLB")
    print("DONE stairwellSign tris", len(me.polygons), "size", [round(x, 3) for x in ob.dimensions], "objects", ["stairwellSign"])


# ------------------------------------------------------------- c_desk_nodivider ---
def _drawer_stack(x0, x1, y_front, z0, z1, n, handle_w=1.0, mat="drawer"):
    gap = 0.06
    h = (z1 - z0 - (n - 1) * gap) / n
    for i in range(n):
        a = z0 + i * (h + gap)
        box(f"dr{x0}{i}", x0 + 0.05, x1 - 0.05, y_front - 0.03, y_front + 0.14, a, a + h, mat, bevel=0.035)
        hz = a + h * 0.62; cx = (x0 + x1) / 2
        cylx(f"hd{x0}{i}", cx - handle_w / 2, cx + handle_w / 2, y_front - 0.2, hz, 0.05, "metal", 12)
        for sx in (-handle_w / 2 + 0.08, handle_w / 2 - 0.08):
            box(f"hp{x0}{i}{sx}", cx + sx - 0.035, cx + sx + 0.035, y_front - 0.2, y_front - 0.02, hz - 0.03, hz + 0.03, "metal", bevel=0)
    box(f"sh{x0}", x0 + 0.04, x1 - 0.04, y_front + 0.1, y_front + 0.16, z0, z1, "gap", bevel=0)


@prop
def c_desk_nodivider():
    """The mock-room desk (c_desk) without the green privacy divider: the mesh top is the worktop at 4.95. 8.8 W x 4.6 D x 4.95 H."""
    W, D, TOP, T = 8.8, 4.6, 4.95, 0.28
    U = TOP - T
    box("top", -W / 2, W / 2, -D / 2, D / 2, U, TOP, "wood", r=0.35, corners=("fl", "fr"), bevel=0.09)
    box("ped", -4.25, -1.75, -1.95, 2.05, 0.22, U, "laminate", r=0.12, corners=("fl", "fr"))
    box("plinth", -4.17, -1.83, -1.85, 1.95, 0.0, 0.24, "gap", bevel=0.02)
    _drawer_stack(-4.25, -1.75, -2.05, 0.3, U - 0.08, 3, 1.2)
    box("leg", 3.85, 4.25, -2.05, 2.05, 0.0, U, "laminate", r=0.18, corners=("fl", "fr"), bevel=0.03)
    box("modesty", -1.75, 3.85, 2.1, 2.22, 1.1, U, "laminate", bevel=0.03)
    finish2("c_desk_nodivider")


if __name__ == "__main__":
    for w in sys.argv[sys.argv.index("--") + 1:]:
        H.reset()
        PROPS[w]()
