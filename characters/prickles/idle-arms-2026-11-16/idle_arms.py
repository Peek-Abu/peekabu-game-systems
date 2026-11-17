# Prickles idle, arms out of his body (owner OK 2026-11-16: "I permit it!"). DRAFT only: nothing is uploaded.
# The shipped idle (characters/prickles/anim/Prickles_Idle.rbxmx in the main checkout, asset 108680458550464) folds his
# arms high on the chest: his left hand sits up to 0.23 studs inside his chest and 0.09 inside his head, the right
# forearm 0.16 inside the chest, every frame. This keeps every keyframe's body, legs and head exactly and re-solves ONLY
# the six arm rotations (one pose relative to the torso, so the arms ride his stiff rock): the same grumpy crossed arms,
# lower and looser, forearms over the belly, elbows out, each hand on the other arm OUTSIDE the body, and clear of the
# Showstopper remake's robe, waistcoat and lapels.
#   blender -b --disable-autoexec -P idle_arms.py -- probe            (print where the arms are now)
#   blender -b --disable-autoexec -P idle_arms.py -- solve [k=v ...]  (solve, write draft rbxmx + report into out/)
import bpy, sys, os, json, math
import numpy as np
import xml.etree.ElementTree as ET
from mathutils import Vector
from mathutils.bvhtree import BVHTree

A = sys.argv[sys.argv.index('--') + 1:]
MODE = A[0]
HERE = os.path.dirname(os.path.abspath(__file__)).replace(chr(92), '/')
CH = 'E:/Projects/peekabu-game-systems/characters'          # main checkout: read only (sources are untracked there)
SRC = f'{CH}/prickles/anim/Prickles_Idle.rbxmx'
OUTFIT = 'E:/Projects/peekabu-game-systems/characters/skins/release/gloom_carnival/showstopper_remake/r19/export/export_final.blend'
P = dict(LZ=1.74, RZ=1.68, HY=-0.60, LX=-0.10, RX=0.10, W_BODY=60.0, W_OUT=25.0, W_TGT=4.0, W_REG=0.15, W_ORDER=20.0,
         ITERS=2400, W_HAND=80.0, W_WRIST=0.0, LY=0.0, RY=0.0,
         HEAD_GAP=0.0, W_HEADGAP=0.0, LFZ=0.0, W_LFZ=0.0, LH_ELEV=-99.0, W_ELEV=0.0,
         HAND_MARGIN=0.015, CROSS_X=0.0, W_CROSS=0.0, CONTACT=0.0, W_CONTACT=0.0, ELB_MIN=0.0, W_ELB=0.0, ELB_OUT=0.0, W_ELBOUT=0.0)
# A3 (owner on A2: "the hands should still touch / look like left hand is resting on right hand ... more bend on each elbow
# away from body"): CROSS_X = each hand past the centre line by this much; CONTACT = the left hand's nearest point to the
# right forearm/hand at most this far (touching wanted, only sinking in banned: HAND_MARGIN 0); ELB_MIN = elbow bend (deg);
# ELB_OUT = elbow joint at least this far out from the torso axis   # A2: head gap, left forearm height, left hand tilt (deg)   # W_WRIST: keep the solved joints near INIT (smallest bend that fixes it)
INIT = None
FREE = None   # 'wrists': solve ONLY the two hand rotations (indices 6-8, 15-17), everything else stays as INIT
for kv in A[1:]:
    k, v = kv.split('=')
    if k == 'INIT': INIT = v; continue
    if k == 'FREE': FREE = v; continue      # start from a saved draft's report.json (its 'x')
    P[k] = type(P[k])(float(v))

# ---------------------------------------------------------------- the shipped clip, FK (as showstopper_tails/gait_all.py)
M = np.array([[-1., 0, 0], [0, 0, 1], [0, 1, 0]]); M4 = np.eye(4); M4[:3, :3] = M
PARENT = {'LowerTorso': None, 'UpperTorso': 'LowerTorso', 'Head': 'UpperTorso'}
for side in ['Left', 'Right']:
    for part, parent in [('UpperArm', 'UpperTorso'), ('LowerArm', side + 'UpperArm'), ('Hand', side + 'LowerArm'),
                         ('UpperLeg', 'LowerTorso'), ('LowerLeg', side + 'UpperLeg'), ('Foot', side + 'LowerLeg')]:
        PARENT[side + part] = parent
rig = json.load(open(f'{CH}/prickles/v4/Prickles_rig.json'))
piv = {j['part1']: np.array([-j['pos'][0], j['pos'][1], -j['pos'][2]]) for j in rig['joints'].values()}
tree = ET.parse(SRC); root = tree.getroot()
keys = sorted([e for e in root.iter('Item') if e.get('class') == 'Keyframe'],
              key=lambda e: float(e.find('./Properties/float[@name="Time"]').text))
ARMS = ['LeftUpperArm', 'LeftLowerArm', 'LeftHand', 'RightUpperArm', 'RightLowerArm', 'RightHand']


def read_local(key):
    loc = {}
    for e in key.iter('Item'):
        if e.get('class') != 'Pose': continue
        name = e.find('./Properties/string[@name="Name"]').text; cf = e.find('./Properties/CoordinateFrame')
        if name not in PARENT or cf is None: continue
        t = np.eye(4); t[:3, 3] = [float(cf.find(a).text) for a in 'XYZ']
        t[:3, :3] = [[float(cf.find(f'R{a}{b}').text) for b in range(3)] for a in range(3)]
        loc[name] = t
    return loc


LOCAL = [read_local(k) for k in keys]


def fk(local):
    native, skin = {}, {}
    for part, parent in PARENT.items():
        a = np.eye(4); a[:3, 3] = piv[part]; b = np.eye(4); b[:3, 3] = -piv[part]
        native[part] = (native[parent] if parent else np.eye(4)) @ a @ local.get(part, np.eye(4)) @ b
        skin[part] = M4.T @ native[part] @ M4
    return skin


def rotmat(v):
    a = np.linalg.norm(v)
    if a < 1e-12: return np.eye(3)
    k = v / a; K = np.array([[0, -k[2], k[1]], [k[2], 0, -k[0]], [-k[1], k[0], 0]])
    return np.eye(3) + math.sin(a) * K + (1 - math.cos(a)) * K @ K


# ---------------------------------------------------------------- meshes (Blender rest frame)
bpy.ops.wm.open_mainfile(filepath=f'{CH}/launch/animation-workbench/workflow/output/prickles/Prickles_controls.blend')
for rig_ob in [o for o in bpy.data.objects if o.type == 'ARMATURE']:
    rig_ob.animation_data_clear()
    for pb in rig_ob.pose.bones:
        pb.location = (0, 0, 0); pb.rotation_quaternion = (1, 0, 0, 0); pb.rotation_euler = (0, 0, 0)
bpy.context.scene.frame_set(1)
dg = bpy.context.evaluated_depsgraph_get()


def mesh_pts(name):
    o = bpy.data.objects[name].evaluated_get(dg); me = o.to_mesh()
    Pp = np.array([(o.matrix_world @ v.co)[:] for v in me.vertices]); F = [list(p.vertices) for p in me.polygons]
    o.to_mesh_clear(); return Pp, F


BODY = {n: mesh_pts(n) for n in ('UpperTorso', 'LowerTorso', 'Head')}
ARMPTS = {}
ARMMESH = {n: mesh_pts(n) for n in ('LeftLowerArm', 'LeftHand', 'RightLowerArm', 'RightHand')}   # hand-vs-arm check
# head-gap points: every spike tip (the points farthest from the part's centre) plus a spread of the rest, so a spike can
# never slip between samples (owner on fixed A: "one of the spikes on left hand are clipping into prickles head")
GAPPTS = {}
for n in ('LeftLowerArm', 'LeftHand', 'RightLowerArm', 'RightHand', 'LeftUpperArm', 'RightUpperArm'):
    Pp, _ = mesh_pts(n); c = Pp.mean(0); dd = np.linalg.norm(Pp - c, axis=1)
    far = np.argsort(-dd)[:80]; rng = np.random.default_rng(1)
    GAPPTS[n] = Pp[np.unique(np.r_[far, rng.choice(len(Pp), min(len(Pp), 300), replace=False)])]
LWRIST = np.array([[1.16, 0.0, 2.02]])   # his left wrist joint at rest (Blender frame)
for n in ARMS:
    Pp, _ = mesh_pts(n); rng = np.random.default_rng(0)
    ARMPTS[n] = Pp[rng.choice(len(Pp), min(len(Pp), 220), replace=False)]


def xf(Mx, Pp): return (np.c_[Pp, np.ones(len(Pp))] @ np.asarray(Mx).T)[:, :3]


def bvh(Pp, F): return BVHTree.FromPolygons([Vector(p) for p in Pp], F)


OB_TORSO, OB_LOWER, OB_HEAD = bvh(*BODY['UpperTorso']), bvh(*BODY['LowerTorso']), bvh(*BODY['Head'])
OB_OUT = None
if os.path.exists(OUTFIT):
    with bpy.data.libraries.load(OUTFIT) as (s, d):
        d.objects = [n for n in s.objects if n in ('SSR_Robe', 'SSR_Upper')]
    pts, faces = [], []
    for o in d.objects:
        me = o.data
        gU = o.vertex_groups.get('UpperTorsoBone')
        idx = {}
        for v in me.vertices:
            w = next((g.weight for g in v.groups if gU and g.group == gU.index), 0.0)
            if w > 0.9 and abs(v.co.x) < 0.62 and v.co.z > 1.35:          # chest pieces: robe top, lapels, waistcoat
                idx[v.index] = len(pts); pts.append(v.co.copy())
        for p in me.polygons:
            if all(i in idx for i in p.vertices): faces.append([idx[i] for i in p.vertices])
    OB_OUT = BVHTree.FromPolygons(pts, faces)
    print('OUTFIT obstacle faces', len(faces))


def inside_depth(tree_, pts):
    """points (in the obstacle's rest frame) inside a round obstacle: an outward horizontal ray from the body's axis
    through the point hits it. Returns the depth per point (0 = outside)."""
    d = np.zeros(len(pts))
    for i, p in enumerate(pts):
        r = Vector((p[0], p[1], 0.0))
        if r.length < 1e-6: r = Vector((0, -1, 0))
        h = tree_.ray_cast(Vector(p), r.normalized(), 1.2)
        if h[0] is not None: d[i] = h[3]
    return d


BASE = LOCAL[0]


def arms_from(x):
    out = {}
    for k, n in enumerate(ARMS):
        t = np.eye(4); t[:3, :3] = rotmat(x[3 * k:3 * k + 3]) @ BASE[n][:3, :3]; out[n] = t
    return out


def eval_pose(x, frames=(0,), detail=False):
    arms = arms_from(x)
    cost = 0.0; rep = {}
    for f in frames:
        loc = dict(LOCAL[f]); loc.update(arms)
        sk = fk(loc)
        Ut, Ht, Lt = np.linalg.inv(sk['UpperTorso']), np.linalg.inv(sk['Head']), np.linalg.inv(sk['LowerTorso'])
        sh = {s: xf(sk['UpperTorso'], np.array([[(-1 if s == 'Right' else 1) * 0.36, 0, 2.02]]))[0] for s in ('Left', 'Right')}
        body = out = 0.0; nb = no = 0; dmax = 0.0
        for n in ARMS:
            W = xf(sk[n], ARMPTS[n])
            if 'UpperArm' in n:   # the shoulder joint overlaps the torso by design
                W = W[np.linalg.norm(W - sh['Left' if n.startswith('Left') else 'Right'], axis=1) > 0.24]
                if len(W) == 0: continue
            for tr, Tinv in ((OB_TORSO, Ut), (OB_LOWER, Lt), (OB_HEAD, Ht)):
                dd = inside_depth(tr, xf(Tinv, W))
                body += float(np.sum((dd + 0.02 * (dd > 0)) ** 2)); nb += int((dd > 0).sum()); dmax = max(dmax, float(dd.max(initial=0)))
            if OB_OUT is not None and 'UpperArm' not in n:
                dd = inside_depth(OB_OUT, xf(Ut, W))
                out += float(np.sum(dd ** 2)); no += int((dd > 0).sum())
        # hands vs the OTHER arm (owner on draft A: "left hand / wrist bend INTO the bottom right hand"): a point is inside
        # when it is on the back side of the nearest face of the other forearm / hand (outward normals)
        hand = 0.0; nh = 0; hmax = 0.0
        other = {}
        for n in ARMMESH:
            Pp, F = ARMMESH[n]
            other[n] = BVHTree.FromPolygons([Vector(q) for q in xf(sk[n], Pp)], F)
        for n, vs in (('LeftHand', ('RightLowerArm', 'RightHand')), ('LeftLowerArm', ('RightHand',)),
                      ('RightHand', ('LeftLowerArm', 'LeftHand')), ('RightLowerArm', ('LeftHand',))):
            W = xf(sk[n], ARMPTS[n])
            for vn in vs:
                tr = other[vn]
                for q in W:
                    hit = tr.find_nearest(Vector(q), 0.3)
                    if hit[0] is None: continue
                    d = (Vector(q) - hit[0]).dot(hit[1])
                    if d < P['HAND_MARGIN']:            # inside, or closer than HAND_MARGIN to the other arm's skin
                        pen = P['HAND_MARGIN'] - d; hand += pen * pen
                        if d < 0: nh += 1; hmax = max(hmax, -d)
        # visible gap to the head: every arm/hand point (spike tips included) at least HEAD_GAP from the head's surface
        hg = 0.0; gmin = 9.0; gpart = {}
        for n in GAPPTS:
            gpart[n] = 9.0
            for q in xf(Ht, xf(sk[n], GAPPTS[n])):
                hit = OB_HEAD.find_nearest(Vector(q), 0.5)
                if hit[0] is None: continue
                d = hit[3] if (Vector(q) - hit[0]).dot(hit[1]) >= 0 else -hit[3]
                gmin = min(gmin, d); gpart[n] = min(gpart[n], d)
                if d < P['HEAD_GAP'] and 'UpperArm' not in n: hg += (P['HEAD_GAP'] - d) ** 2   # shoulders sit under the head by the rig's design (shipped idle: 0.017); reported, not pushed
        # left hand resting on the right forearm / hand: its nearest point to them should be within CONTACT
        lmin = 9.0
        for q in xf(sk['LeftHand'], ARMPTS['LeftHand']):
            for vn in ('RightLowerArm', 'RightHand'):
                hit = other[vn].find_nearest(Vector(q), 0.6)
                if hit[0] is not None: lmin = min(lmin, (Vector(q) - hit[0]).dot(hit[1]))
        crossed = 0.0; elb = 0.0
        if P['W_CONTACT'] > 0 and lmin > P['CONTACT']: crossed += P['W_CONTACT'] * (lmin - P['CONTACT']) ** 2
        hcl = xf(Ut, xf(sk['LeftHand'], ARMPTS['LeftHand'])).mean(0); hcr = xf(Ut, xf(sk['RightHand'], ARMPTS['RightHand'])).mean(0)
        if P['W_CROSS'] > 0:   # his left hand ends on his right side (-X), the right hand on his left side (+X)
            crossed += P['W_CROSS'] * (max(0.0, hcl[0] + P['CROSS_X']) ** 2 + max(0.0, P['CROSS_X'] - hcr[0]) ** 2)
        for side, sg in (('Left', 1.0), ('Right', -1.0)):
            R = arms[side + 'LowerArm'][:3, :3]
            bend = math.degrees(math.acos(max(-1, min(1, (np.trace(R) - 1) / 2))))
            if P['W_ELB'] > 0 and bend < P['ELB_MIN']: elb += P['W_ELB'] * math.radians(P['ELB_MIN'] - bend) ** 2
            ep = xf(Ut, xf(sk[side + 'LowerArm'], np.array([[sg * 0.78, 0.0, 2.02]])))[0]
            if P['W_ELBOUT'] > 0: elb += P['W_ELBOUT'] * max(0.0, P['ELB_OUT'] - math.hypot(ep[0], ep[1])) ** 2
        wr = xf(Ut, xf(sk['LeftHand'], LWRIST))[0]
        hc = xf(Ut, xf(sk['LeftHand'], ARMPTS['LeftHand'])).mean(0)
        hd = hc - wr; elev = math.degrees(math.asin(max(-1, min(1, hd[2] / max(np.linalg.norm(hd), 1e-9)))))
        shape = 0.0
        if P['W_LFZ'] > 0: shape += P['W_LFZ'] * (xf(Ut, xf(sk['LeftLowerArm'], ARMPTS['LeftLowerArm'])).mean(0)[2] - P['LFZ']) ** 2
        if P['W_ELEV'] > 0: shape += P['W_ELEV'] * (math.radians(max(0.0, P['LH_ELEV'] - elev))) ** 2   # at least this much tilt up
        hl = xf(Ut, xf(sk['LeftHand'], ARMPTS['LeftHand'])).mean(0)
        hr = xf(Ut, xf(sk['RightHand'], ARMPTS['RightHand'])).mean(0)
        fl = xf(Ut, xf(sk['LeftLowerArm'], ARMPTS['LeftLowerArm'])).mean(0)
        fr = xf(Ut, xf(sk['RightLowerArm'], ARMPTS['RightLowerArm'])).mean(0)
        ly = P['LY'] if P['LY'] < 0 else P['HY']; ry = P['RY'] if P['RY'] < 0 else P['HY'] + 0.05   # LY / RY: separate depths
        tgt = np.sum((hl - [P['LX'], ly, P['LZ']]) ** 2) + np.sum((hr - [P['RX'], ry, P['RZ']]) ** 2)
        order = max(0.0, fl[1] - fr[1] + 0.06) ** 2     # his LEFT forearm lies over (in front of) the right, as now
        cost += P['W_BODY'] * body + P['W_OUT'] * out + P['W_TGT'] * tgt + P['W_ORDER'] * order + P['W_HAND'] * hand + P['W_HEADGAP'] * hg + shape + crossed + elb
        if detail:
            rep[f] = dict(lhand_to_right_arm=round(lmin, 3), lhand_x=round(float(hcl[0]), 2), rhand_x=round(float(hcr[0]), 2), head_gap_by_part={k: round(v, 3) for k, v in gpart.items()}, head_gap_min=round(gmin, 3), lhand_elev=round(elev, 1), body_pts=nb, body_depth=round(dmax, 3), outfit_pts=no, hand_pts=nh, hand_depth=round(hmax, 3), hand_L=np.round(hl, 2).tolist(),
                          hand_R=np.round(hr, 2).tolist(), fore_L=np.round(fl, 2).tolist(), fore_R=np.round(fr, 2).tolist())
    cost = cost / len(frames) + P['W_REG'] * float(np.sum(x ** 2))
    return (cost, rep) if detail else cost


if MODE == 'probe':
    x_probe = np.array(json.load(open(INIT))['x']) if INIT else np.zeros(18)
    c, rep = eval_pose(x_probe, frames=(0, 22, 45, 67), detail=True)
    print('PROBE cost %.2f' % c)
    for f, r in rep.items(): print('  ', f, r)
    sys.exit(0)


def nelder_mead(fn, x0, step=0.25, iters=2000):
    n = len(x0); pts = [x0] + [x0 + step * np.eye(n)[i] for i in range(n)]
    vals = [fn(p) for p in pts]
    for it in range(iters):
        o = np.argsort(vals); pts = [pts[i] for i in o]; vals = [vals[i] for i in o]
        c = np.mean(pts[:-1], 0)
        xr = c + (c - pts[-1]); fr = fn(xr)
        if fr < vals[0]:
            xe = c + 2 * (c - pts[-1]); fe = fn(xe)
            pts[-1], vals[-1] = (xe, fe) if fe < fr else (xr, fr)
        elif fr < vals[-2]:
            pts[-1], vals[-1] = xr, fr
        else:
            xc = c + 0.5 * (pts[-1] - c); fc = fn(xc)
            if fc < vals[-1]: pts[-1], vals[-1] = xc, fc
            else:
                pts = [pts[0]] + [pts[0] + 0.5 * (p - pts[0]) for p in pts[1:]]; vals = [vals[0]] + [fn(p) for p in pts[1:]]
        if it % 200 == 0: print('  it', it, 'cost %.4f' % vals[0], flush=True)
    i = int(np.argmin(vals)); return pts[i], vals[i]


FR = (0, 30, 60)
X_INIT = np.array(json.load(open(INIT))['x']) if INIT else np.zeros(18)
IDX = np.array([6, 7, 8, 15, 16, 17]) if FREE == 'wrists' else np.arange(18)


def full(sub):
    x_ = X_INIT.copy(); x_[IDX] = sub; return x_


best = None
for rnd in range(3):
    s0 = X_INIT[IDX] if best is None else best[0]
    sub, v = nelder_mead(lambda sub: eval_pose(full(sub), FR) + P['W_WRIST'] * float(np.sum((sub - X_INIT[IDX]) ** 2)), s0, step=(0.15 if INIT else 0.3) if best is None else 0.05,
                         iters=int(P['ITERS']) // 3)
    if best is None or v < best[1]: best = (sub, v)
    print('ROUND', rnd, 'cost %.4f' % best[1], flush=True)
best = (full(best[0]), best[1])
x = best[0]
allrep = eval_pose(x, frames=tuple(range(len(keys))), detail=True)[1]
n_body = max(r['body_pts'] for r in allrep.values()); worst_body = max(r['body_depth'] for r in allrep.values())
n_out = max(r['outfit_pts'] for r in allrep.values())
n_hand = max(r['hand_pts'] for r in allrep.values()); d_hand = max(r['hand_depth'] for r in allrep.values())
g_head = min(min(v for k, v in r['head_gap_by_part'].items() if 'UpperArm' not in k) for r in allrep.values())
g_sh = min(min(v for k, v in r['head_gap_by_part'].items() if 'UpperArm' in k) for r in allrep.values())
print('CHECK every frame: smallest gap to the head: forearms/hands (spikes included) %.3f, shoulders %.3f' % (g_head, g_sh))
print('CHECK every frame: body points inside max %d, depth max %.3f; outfit points inside max %d; hand-in-other-arm points max %d, depth %.3f' % (n_body, worst_body, n_out, n_hand, d_hand))
print('FRAME0', allrep[0])

arms = arms_from(x)
for key in keys:
    for e in key.iter('Item'):
        if e.get('class') != 'Pose': continue
        name = e.find('./Properties/string[@name="Name"]').text
        if name not in arms: continue
        cf = e.find('./Properties/CoordinateFrame'); R = arms[name][:3, :3]
        for a in range(3):
            for b in range(3): cf.find(f'R{a}{b}').text = repr(float(R[a, b]))
os.makedirs(f'{HERE}/out', exist_ok=True)
tree.write(f'{HERE}/out/Prickles_Idle_armsdown_draft.rbxmx', encoding='utf-8')
json.dump({'params': P, 'x': x.tolist(), 'cost': best[1], 'frame0': allrep[0], 'every_frame': {
    'body_points_inside_max': n_body, 'body_depth_max': worst_body, 'outfit_points_inside_max': n_out,
    'hand_points_inside_other_arm_max': n_hand, 'hand_depth_max': d_hand, 'head_gap_min_forearms_hands': g_head, 'head_gap_min_shoulders': g_sh}},
    open(f'{HERE}/out/report.json', 'w'), indent=1)
print('WROTE draft')
