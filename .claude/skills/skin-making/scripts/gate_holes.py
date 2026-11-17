# Hole gate for the remake (owner 11-16: "holes all over the skin"). His body is hidden exactly as the game skin hides
# it (everything except head and hands), then the figure is rendered from 16 directions (8 round him at eye level, 8
# from 25 degrees above) with flat colours, background pure MAGENTA, and every garment's INSIDE (back faces) pure RED.
# Magenta shut inside the figure = a see-through hole; red = you can see into a garment (a gap, an open edge).
# Also counts open (non-manifold) edges per piece: every garment piece must be a closed shell.
#   blender -b --disable-autoexec -P gate_holes.py -- <out_dir> [pose]      -> <out_dir>/gate/*.png, gate_blend.json
import bpy, sys, os, math, json, bmesh
from mathutils import Vector, Quaternion
A = sys.argv[sys.argv.index('--') + 1:]
D = os.path.abspath(A[0]).replace(chr(92), '/')
POSE = 'pose' in A[1:]
bpy.ops.wm.open_mainfile(filepath=f'{D}/finished.blend')
sc = bpy.context.scene
COVER = ['UpperTorso', 'LowerTorso', 'LeftUpperArm', 'RightUpperArm', 'LeftLowerArm', 'RightLowerArm',
         'LeftUpperLeg', 'RightUpperLeg', 'LeftLowerLeg', 'RightLowerLeg', 'LeftFoot', 'RightFoot']
BASE = ['Head', 'FacePlate', 'Flower_Head', 'LeftHand', 'RightHand']        # his own parts: no inside check
for n in COVER:
    o = bpy.data.objects.get(n)
    if o: o.hide_render = True
if POSE:
    sys.path.insert(0, os.path.dirname(os.path.abspath(__file__))); import pose_demo
    pose_demo.apply()


def flat(src, inside_red):
    m = bpy.data.materials.new('GATE_' + src.name); m.use_nodes = True
    nt = m.node_tree; N = nt.nodes; Lk = nt.links
    for nd in list(N): N.remove(nd)
    out = N.new('ShaderNodeOutputMaterial')
    e1 = N.new('ShaderNodeEmission'); e1.inputs[0].default_value = tuple(src.diffuse_color[:3]) + (1,)
    if inside_red:
        e2 = N.new('ShaderNodeEmission'); e2.inputs[0].default_value = (1, 0, 0, 1)
        mx = N.new('ShaderNodeMixShader'); geo = N.new('ShaderNodeNewGeometry')
        Lk.new(geo.outputs['Backfacing'], mx.inputs[0]); Lk.new(e1.outputs[0], mx.inputs[1]); Lk.new(e2.outputs[0], mx.inputs[2])
        Lk.new(mx.outputs[0], out.inputs[0])
    else:
        Lk.new(e1.outputs[0], out.inputs[0])
    m.use_backface_culling = False
    return m


for o in bpy.data.objects:
    if o.type != 'MESH' or o.hide_render: continue
    red = not any(o.name.startswith(b) for b in BASE)
    for slot in o.material_slots:
        src = slot.material
        if src: slot.link = 'OBJECT'; slot.material = flat(src, red)
sc.render.engine = 'BLENDER_EEVEE'
sc.view_settings.view_transform = 'Standard'; sc.view_settings.look = 'None'
if sc.world is None: sc.world = bpy.data.worlds.new('w')
sc.world.use_nodes = True
bgn = sc.world.node_tree.nodes['Background']; bgn.inputs[0].default_value = (1, 0, 1, 1); bgn.inputs[1].default_value = 1
sc.render.resolution_x, sc.render.resolution_y, sc.render.resolution_percentage = 700, 900, 100
sc.render.film_transparent = False
for o in list(bpy.data.objects):
    if o.type in ('CAMERA', 'LIGHT'): bpy.data.objects.remove(o, do_unlink=True)
cd = bpy.data.cameras.new('cam'); cd.type = 'ORTHO'; cd.ortho_scale = 5.2
cam = bpy.data.objects.new('cam', cd); sc.collection.objects.link(cam); sc.camera = cam
os.makedirs(f'{D}/gate', exist_ok=True)
shots = []
for el in (0, 25):
    for az in range(0, 360, 45):
        a, e = math.radians(az), math.radians(el)
        cam.location = (-20 * math.sin(a) * math.cos(e), -20 * math.cos(a) * math.cos(e), 2.2 + 20 * math.sin(e))
        cam.rotation_euler = (Vector((0, 0, 2.2)) - cam.location).to_track_quat('-Z', 'Y').to_euler()
        f = f'{D}/gate/{"pose_" if POSE else ""}e{el}_a{az:03d}.png'
        sc.render.filepath = f; bpy.ops.render.render(write_still=True); shots.append(f)
openings = {}
for o in bpy.data.objects:
    if o.type != 'MESH' or o.hide_render or any(o.name.startswith(b) for b in BASE): continue
    dgo = o.evaluated_get(bpy.context.evaluated_depsgraph_get()); me = dgo.to_mesh()
    bm = bmesh.new(); bm.from_mesh(me)
    openings[o.name] = sum(1 for ed in bm.edges if not ed.is_manifold); bm.free(); dgo.to_mesh_clear()
json.dump({'shots': shots, 'open_edges': openings}, open(f'{D}/gate/{"pose_" if POSE else ""}gate_blend.json', 'w'), indent=1)
print('GATE RENDER OK')
