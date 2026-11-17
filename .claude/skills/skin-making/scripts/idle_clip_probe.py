# Plain Prickles (no skin) in his own Idle clip: how far do his arms and hands go INTO his torso / head, frame by frame.
# Inside test: odd number of crossings along +X (closed-ish part meshes), depth = distance to that part's surface.
#   blender -b --disable-autoexec -P idle_clip_probe.py -- <out.json> [Clip]
import bpy, sys, json, os
import numpy as np
from mathutils import Vector, Matrix
from mathutils.bvhtree import BVHTree
sys.path.insert(0, 'E:/Projects/peekabu-game-systems/characters/skins/release/gloom_carnival/blockout')
import common as C
A = sys.argv[sys.argv.index('--') + 1:]
OUT = A[0]; CLIP = A[1] if len(A) > 1 else 'Idle'
HERE = os.path.dirname(os.path.abspath(__file__)).replace(chr(92), '/')
POSES = json.load(open(f'{HERE}/../showstopper_tails/pose_all.json'))
C.open_src('prickles')
dg = bpy.context.evaluated_depsgraph_get()
def rest(name):
    o = bpy.data.objects[name].evaluated_get(dg); me = o.to_mesh()
    P = np.array([(o.matrix_world @ v.co)[:] for v in me.vertices]); F = [list(p.vertices) for p in me.polygons]
    o.to_mesh_clear(); return P, F
BODY = {n: rest(n) for n in ('UpperTorso', 'LowerTorso', 'Head')}
ARMS = {n: rest(n) for n in ('LeftUpperArm', 'LeftLowerArm', 'LeftHand', 'RightUpperArm', 'RightLowerArm', 'RightHand')}
def xf(M, P): return (np.c_[P, np.ones(len(P))] @ np.array(M).T)[:, :3]
rows = []
for s in POSES[CLIP]['samples']:
    sk = s['skin']
    trees = {n: BVHTree.FromPolygons([Vector(p) for p in xf(sk[n], P)], F) for n, (P, F) in BODY.items()}
    worst = {}
    for an, (P, F) in ARMS.items():
        Q = xf(sk[an], P)
        for bn, t in trees.items():
            n_in, dmax = 0, 0.0
            for q in Q[::2]:
                v = Vector(q); hits = 0; o = v.copy()
                for _ in range(8):
                    h = t.ray_cast(o, Vector((1, 0, 0)), 10)
                    if h[0] is None: break
                    hits += 1; o = h[0] + Vector((1e-4, 0, 0))
                if hits % 2 == 1:
                    n_in += 1; d = t.find_nearest(v)[3]; dmax = max(dmax, d)
            if n_in: worst[f'{an}>{bn}'] = (n_in, round(dmax, 3))
    rows.append({'frame': s['frame'], 'inside': worst})
summary = {}
for r in rows:
    for k, (n, d) in r['inside'].items():
        a = summary.setdefault(k, {'frames': 0, 'max_points': 0, 'max_depth': 0.0})
        a['frames'] += 1; a['max_points'] = max(a['max_points'], n); a['max_depth'] = max(a['max_depth'], d)
json.dump({'clip': CLIP, 'frames': len(rows), 'summary': summary}, open(OUT, 'w'), indent=1)
print('CLIP', CLIP, len(rows), 'frames'); [print('  ', k, v) for k, v in sorted(summary.items(), key=lambda kv: -kv[1]['max_depth'])]
