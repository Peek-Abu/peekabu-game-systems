# Sleeve gate (2026-11-16, A3 era): the SSR_Upper sleeve points (arm-weighted, away from the shoulder seam), posed with
# every keyframe of POSESET, tested against the chest pieces at rest in the torso's frame: the robe top + lapels + collar
# and the waistcoat (UpperTorso-weighted > 0.9, |x| < 0.62, z > 1.25). A point is inside when an outward horizontal ray
# from the body axis through it hits a chest piece (idle_arms.py's test). Reports per clip: worst-frame count and depth.
#   POSESET=pose_a3.json blender -b --disable-autoexec -P sleeve_gate.py -- <build_dir>  -> <build_dir>/sleeve_gate.json
import bpy, sys, os, json
import numpy as np
from mathutils import Vector
from mathutils.bvhtree import BVHTree
A = sys.argv[sys.argv.index('--') + 1:]
D = os.path.abspath(A[0]).replace(chr(92), '/')
HERE = os.path.dirname(os.path.abspath(__file__)).replace(chr(92), '/')
POSES = json.load(open(os.environ.get('POSESET', f'{HERE}/pose_a3.json')))
bpy.ops.wm.open_mainfile(filepath=f'{D}/export/export_final.blend')


def weights(o):
    gn = [g.name for g in o.vertex_groups]
    W = np.zeros((len(o.data.vertices), len(gn)))
    for v in o.data.vertices:
        for g in v.groups: W[v.index, g.group] = g.weight
    return gn, W


pts, faces = [], []
for name in ('SSR_Robe', 'SSR_Upper'):
    o = bpy.data.objects[name]; gn, W = weights(o); iu = gn.index('UpperTorsoBone')
    idx = {}
    for v in o.data.vertices:
        if W[v.index, iu] > 0.9 and abs(v.co.x) < 0.62 and v.co.z > 1.25:
            idx[v.index] = len(pts); pts.append(v.co.copy())
    for p in o.data.polygons:
        if all(i in idx for i in p.vertices): faces.append([idx[i] for i in p.vertices])
CHEST = BVHTree.FromPolygons(pts, faces)
o = bpy.data.objects['SSR_Upper']; gn, W = weights(o)
co = np.array([v.co[:] for v in o.data.vertices])
arm = [k for k, g in enumerate(gn) if 'Arm' in g]
armw = W[:, arm].sum(1)
SH = {'Left': np.array([0.36, 0, 2.02]), 'Right': np.array([-0.36, 0, 2.02])}
sel = np.where((armw > 0.6) & (np.minimum(np.linalg.norm(co - SH['Left'], axis=1), np.linalg.norm(co - SH['Right'], axis=1)) > 0.3))[0]
rng = np.random.default_rng(0); sel = rng.choice(sel, min(len(sel), 900), replace=False)
P0 = np.c_[co[sel], np.ones(len(sel))]; Ws = W[sel]
print('SLEEVE points', len(sel), 'chest faces', len(faces))


def depth(p):
    r = Vector((p[0], p[1], 0.0)); r = r.normalized() if r.length > 1e-6 else Vector((0, -1, 0))
    h = CHEST.ray_cast(Vector(p), r, 1.2)
    return h[3] if h[0] is not None else 0.0


rep = {}
for role, clip in POSES.items():
    worst = (0, 0.0, -1); per = []
    for si, smp in enumerate(clip['samples']):
        sk = smp['skin']
        q = np.zeros((len(sel), 3))
        for k, g in enumerate(gn):
            part = g[:-4]
            if part not in sk: continue
            w = Ws[:, k]; nz = w > 0
            if nz.any(): q[nz] += w[nz, None] * (P0[nz] @ np.array(sk[part]).T)[:, :3]
        Ut = np.linalg.inv(np.array(sk['UpperTorso']))
        ql = (np.c_[q, np.ones(len(q))] @ Ut.T)[:, :3]
        d = np.array([depth(p) for p in ql])
        n = int((d > 0.01).sum()); per.append(n)
        if n > worst[0]: worst = (n, float(d.max()), si)
    rep[role] = dict(frames=len(per), worst_count=worst[0], worst_depth=round(worst[1], 3), worst_frame=worst[2], mean=round(float(np.mean(per)), 1))
    print('SLEEVE', role, rep[role], flush=True)
json.dump(dict(points=len(sel), clips=rep), open(f'{D}/sleeve_gate.json', 'w'), indent=1)
