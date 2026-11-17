# Round 5 pose gate: poses the EXPORTED outfit (export/export_final.blend) with his real game clips and checks it.
# pose_all.json (../showstopper_tails, from gait_all.py) holds every keyframe of Idle / Walk / Run / CrouchIdle /
# CrouchWalk as one deform matrix per body part; each outfit vertex is skinned with its <Part>Bone weights (linear blend,
# what Roblox does). For every keyframe:
#   poke  = bloomer / boot / waistcoat points the robe covers at rest that end on the other side of that same piece of
#           robe in the pose (through the cloth, beyond 0.015)
#   frames chosen by the 'pick' list are also written as a posed scene (<dir>/pose/<role>_<i>/finished.blend) for the
#   hole gate (gate_holes.py) and the lit renders (render_blockout.py).
#   blender -b --disable-autoexec -P pose_gate.py -- <dir>        -> <dir>/pose/pose_gate.json
import bpy, sys, os, json, math
import numpy as np
from mathutils import Vector, Matrix
from mathutils.bvhtree import BVHTree

A = sys.argv[sys.argv.index('--') + 1:]
D = os.path.abspath(A[0]).replace(chr(92), '/')
HERE = os.path.dirname(os.path.abspath(__file__)).replace(chr(92), '/')
POSES = json.load(open(f'{HERE}/../showstopper_tails/pose_all.json'))
PICK = {'Idle': [0, 0.5], 'Walk': [0.25, 0.75], 'Run': [0.25], 'CrouchIdle': [0.5], 'CrouchWalk': [0.25, 0.75]}
BASE = ['Head', 'FacePlate', 'Flower_Head', 'LeftHand', 'RightHand']
COVER = ['UpperTorso', 'LowerTorso', 'LeftUpperArm', 'RightUpperArm', 'LeftLowerArm', 'RightLowerArm',
         'LeftUpperLeg', 'RightUpperLeg', 'LeftLowerLeg', 'RightLowerLeg', 'LeftFoot', 'RightFoot']
SRC = f'{D}/export/export_final.blend'
bpy.ops.wm.open_mainfile(filepath=SRC)


def rest_data(o):
    me = o.data
    co = np.array([v.co[:] for v in me.vertices])
    gn = [g.name for g in o.vertex_groups]
    W = np.zeros((len(co), len(gn)))
    for v in me.vertices:
        for g in v.groups: W[v.index, g.group] = g.weight
    return co, gn, W


MESHES = {o.name: rest_data(o) for o in bpy.data.objects if o.type == 'MESH' and o.name.startswith('SSR_')}


def posed(name, skin):
    co, gn, W = MESHES[name]
    out = np.zeros_like(co); h = np.c_[co, np.ones(len(co))]
    for k, g in enumerate(gn):
        part = g[:-4]
        M = np.array(skin[part]) if part in skin else np.eye(4)
        w = W[:, k]
        nz = w > 0
        if nz.any(): out[nz] += w[nz, None] * (h[nz] @ M.T)[:, :3]
    return out


def bvh(name, pts):
    me = bpy.data.objects[name].data
    return BVHTree.FromPolygons([Vector(p) for p in pts], [list(p.vertices) for p in me.polygons])


# covered points: Parts points below the chest (z < 1.45: bloomers, boots, waistcoat hem; the sleeves sit inside the
# robe at the shoulder and move with the arms, so they are not counted) whose outward horizontal ray hits the robe at rest
PN = 'SSR_Lower' if 'SSR_Lower' in MESHES else 'SSR_Parts'
pco = MESHES[PN][0]
rco = MESHES['SSR_Robe'][0]
rest_robe = bvh('SSR_Robe', rco)
def out_dir(p):
    d = Vector((p[0], p[1], 0.0)); return d.normalized() if d.length > 1e-6 else Vector((0, -1, 0))
RFACES = [list(pl.vertices) for pl in bpy.data.objects['SSR_Robe'].data.polygons]
covered = []          # (parts point, robe face it sits behind, its side of that face at rest)
for i, p in enumerate(pco):
    if p[2] >= 1.45: continue
    hit = rest_robe.ray_cast(Vector(p), out_dir(p), 3.0)
    if hit[0] is None: continue
    covered.append((i, hit[2]))


def face_frame(pts, f):
    vs = pts[RFACES[f]]; c = vs.mean(0)
    n = np.zeros(3)
    for k in range(len(vs)): n += np.cross(vs[k] - c, vs[(k + 1) % len(vs)] - c)
    return c, n / max(np.linalg.norm(n), 1e-9)


side0 = {}
for i, f in covered:
    c, n = face_frame(rco, f); side0[i] = np.sign(np.dot(pco[i] - c, n))
print('COVERED points', len(covered))
TOL = 0.015

report = {}
scenes = []
for role, clip in POSES.items():
    samples = clip['samples']
    worst = (0, -1)
    pokes = []
    where = {}
    for si, smp in enumerate(samples):
        skin = smp['skin']
        rp = posed('SSR_Robe', skin); pp = posed(PN, skin)
        n = 0
        for i, f in covered:      # a poke: the point ends on the OTHER side of the same piece of robe, beyond the tolerance
            c, nn = face_frame(rp, f)
            d = np.dot(pp[i] - c, nn)
            if np.sign(d) != side0[i] and abs(d) > TOL: n += 1; where.setdefault(si, []).append(i)
        pokes.append(n)
        if n > worst[0]: worst = (n, si)
    report[role] = {'frames': len(samples), 'poke_max': worst[0], 'poke_worst_frame': worst[1], 'poke_mean': round(float(np.mean(pokes)), 1)}
    if worst[1] >= 0:   # where the worst frame's pokes are, at rest: around him (front / side / back) and height
        bins = {}
        for i in where[worst[1]]:
            x, y, z = pco[i]; a = math.degrees(math.atan2(y, x))
            reg = 'front' if -135 < a < -45 else ('back' if 45 < a < 135 else 'side')
            key = f'{reg} z{round(z * 5) / 5:.1f}'; bins[key] = bins.get(key, 0) + 1
        report[role]['where'] = dict(sorted(bins.items(), key=lambda kv: -kv[1])[:6])
    print('POSE', role, report[role])
    for f in PICK.get(role, []):
        scenes.append((role, min(len(samples) - 1, int(round(f * (len(samples) - 1))))))
json.dump({'covered': len(covered), 'clips': report, 'scenes': scenes}, open(f'{D}/pose_gate.json', 'w'), indent=1)

# posed scenes for the hole gate and the renders
for role, si in scenes:
    bpy.ops.wm.open_mainfile(filepath=SRC)
    skin = POSES[role]['samples'][si]['skin']
    for name in MESHES:
        o = bpy.data.objects[name]
        pts = posed(name, skin)
        o.modifiers.clear(); o.parent = None; o.matrix_world = Matrix.Identity(4)
        for v, p in zip(o.data.vertices, pts): v.co = p
    for o in bpy.data.objects:
        part = next((b for b in BASE + COVER if o.name == b or (b == 'Flower_Head' and o.name.startswith('Flower'))), None)
        if part is None: continue
        key = 'Head' if part in ('Head', 'FacePlate', 'Flower_Head') else part
        if key in skin and o.type == 'MESH':
            o.matrix_world = Matrix(skin[key]) @ o.matrix_world
    for o in bpy.data.objects:
        if o.type == 'ARMATURE': o.hide_render = True
    out = f'{D}/pose/{role}_{si}'
    os.makedirs(out, exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=f'{out}/finished.blend')
print('POSE GATE OK', scenes)
