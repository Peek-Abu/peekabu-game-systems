# SmartBone step (owner 11-17 "Yes lets do smartbone!"): the robe skirt gets 6 bone chains that ride ON TOP of the
# shipped weights. Only the share each skirt point gave the hips (LowerTorsoBone, i.e. 1 - its thigh-follow) moves
# onto the chains; the thigh-follow (front 0.95 / sides ~0.98 / back 0.40 at the hem, crouch weights EB) is untouched,
# so at rest and in crouch the skirt is exactly today's, and SmartBone only adds swing where the hips held it (most at
# the back). The waist stays on the hips (chain share fades in from z 1.30 to 1.12).
#   Chains: Tail<RF|RS|RB|LF|LS|LB><1..3>Bone under LowerTorsoBone, placed on the robe's own skirt bones (RobeRig
#   Skirt*), plus a zero-weight end marker <4> (Roblox drops it; place_remake adds it back).
#   Around the body a point blends the two nearest chains by angle; down a chain it blends the two nearest links
#   (centred on each link's middle). Limit 4 influences, normalised.
#   blender -b --disable-autoexec <dir>/export/export_final_r7.blend -P ride_chains.py -- <out_dir>
#   -> <out_dir>/Showstopper_SB.fbx (no textures), export_sb.blend, sb.json
import bpy, bmesh, sys, os, math, json
from mathutils import Vector
OUT = os.path.abspath(sys.argv[sys.argv.index('--') + 1]).replace(chr(92), '/'); os.makedirs(OUT, exist_ok=True)
KV = dict(KF=0.0, KS=0.0, KB=0.0)
for kv in sys.argv[sys.argv.index('--') + 2:]:
    k_, _, v_ = kv.partition('=')
    if k_ in KV: KV[k_] = float(v_)
KF, KS, KB = KV['KF'], KV['KS'], KV['KB']
LAPK = float(next((kv.split('=')[1] for kv in sys.argv if kv.startswith('LAPK=')), 0.6))
LAPEL_SRC = 'E:/Projects/peekabu-game-systems/characters/skins/release/gloom_carnival/showstopper_remake/cr/TX/finished.blend'
print('THIGH SHARE', KV)
ARM = bpy.data.objects['Showstopper_DeformSkeleton']; RIG = bpy.data.objects['RobeRig']; robe = bpy.data.objects['SSR_Robe']
SIDES = ['RF', 'RS', 'RB', 'LF', 'LS', 'LB']
links = {s: [(RIG.data.bones[f'Skirt{s}{n}'].head_local.copy(), RIG.data.bones[f'Skirt{s}{n}'].tail_local.copy()) for n in (1, 2, 3)] for s in SIDES}
# round 4 (SURFACE=1): the chain joints move OUT onto the draped cloth. The robe rig's skirt bones sit inside the cloth,
# so colliders (which act on bones) had to be smaller than the visible bloomers; on the surface they can be full size.
# Each joint keeps its height and angle; its distance from the body axis becomes the cloth's outer surface there
# (the 90th percentile of robe points within 10 degrees and 0.04 in height), minus half the cloth thickness.
SURFACE = 'SURFACE=1' in sys.argv
if SURFACE:
    import numpy as _np
    _R = _np.array([v.co[:] for v in robe.data.vertices])
    _ang = _np.arctan2(_R[:, 1], _R[:, 0]); _rad = _np.hypot(_R[:, 0], _R[:, 1])
    def _onto(pt):
        a = math.atan2(pt.y, pt.x)
        da = _np.abs((_ang - a + math.pi) % (2 * math.pi) - math.pi)
        sel = (da < math.radians(10)) & (_np.abs(_R[:, 2] - pt.z) < 0.04)
        if sel.sum() < 4: return pt.copy()
        r = float(_np.percentile(_rad[sel], 90)) - 0.02
        return Vector((r * math.cos(a), r * math.sin(a), pt.z))
    for s_ in SIDES:
        joints = [links[s_][0][0]] + [t for _, t in links[s_]]
        moved_j = [joints[0]] + [_onto(j) for j in joints[1:]]       # the root stays at the waist
        links[s_] = [(moved_j[k], moved_j[k + 1]) for k in range(3)]
    print('SURFACE joints moved out')

# ---- bones
for o in bpy.context.view_layer.objects: o.select_set(False)
bpy.context.view_layer.objects.active = ARM; bpy.ops.object.mode_set(mode='EDIT')
eb = ARM.data.edit_bones
for s in SIDES:
    prev = eb['LowerTorsoBone']
    for n, (h, t) in enumerate(links[s], 1):
        e = eb.new(f'Tail{s}{n}Bone'); e.head, e.tail = h, t; e.parent = prev; e.use_connect = n > 1; prev = e
    h, t = links[s][-1]
    tip = eb.new(f'Tail{s}4Bone'); tip.head = t; tip.tail = t + (t - h) * 0.2; tip.parent = prev; tip.use_connect = True
bpy.ops.object.mode_set(mode='OBJECT')


def sst(a, b, x):
    t = min(max((x - a) / (b - a), 0.0), 1.0); return t * t * (3 - 2 * t)


ang = {s: math.atan2(links[s][0][0].y, links[s][0][0].x) for s in SIDES}
order = sorted(SIDES, key=lambda s: ang[s])


def chain_mix(co):
    # round 3 (owner 11-17: "something rigid and weird about the back middle seam split"): below the vent top, a back
    # point rides only its own side's chains, so the two edges of the split swing apart like the panels beside them
    # (an even blend of both back chains held the split rigid); blended over 0.12 above the vent top.
    if co.y > 0.15 and co.z < VENTZ + 0.12:
        own = [s for s in order if s[0] == ('L' if co.x > 0 else 'R')]
        sided = _mix(co, own)
        if co.z <= VENTZ:
            return sided
        t = sst(VENTZ + 0.12, VENTZ, co.z)
        both = _mix(co, order)
        out = {}
        for s_, w in sided: out[s_] = out.get(s_, 0) + w * t
        for s_, w in both: out[s_] = out.get(s_, 0) + w * (1 - t)
        return list(out.items())
    return _mix(co, order)


def _mix(co, order):
    a = math.atan2(co.y, co.x)
    for i, s in enumerate(order):
        s2 = order[(i + 1) % len(order)]
        a1, a2 = ang[s], ang[s2] + (2 * math.pi if i == len(order) - 1 else 0)
        aa = a if a >= a1 else a + 2 * math.pi
        if a1 <= aa <= a2:
            t = (aa - a1) / (a2 - a1); return [(s, 1 - t), (s2, t)]
    return [(order[0], 1.0)]


def link_mix(s, z):
    mids = [(h.z + t.z) / 2 for h, t in links[s]]
    if z >= mids[0]: return [(1, 1.0)]
    if z <= mids[-1]: return [(3, 1.0)]
    for k in range(2):
        if mids[k] >= z >= mids[k + 1]:
            t = (mids[k] - z) / (mids[k] - mids[k + 1]); return [(k + 1, 1 - t), (k + 2, t)]


centre = [v.co.z for v in robe.data.vertices if abs(v.co.x) < 0.002 and v.co.y > 0.3 and v.co.z < 1.3]
VENTZ = min(centre) if centre else 0.75
print('VENT TOP', round(VENTZ, 3))
G = {g.name: g for g in robe.vertex_groups}
lt = G['LowerTorsoBone']
for s in SIDES:
    for n in (1, 2, 3):
        G[f'Tail{s}{n}Bone'] = robe.vertex_groups.new(name=f'Tail{s}{n}Bone')
moved = 0; total_share = 0.0
for v in robe.data.vertices:
    co = v.co
    if co.z >= 1.30: continue
    w_lt = next((g.weight for g in v.groups if g.group == lt.index), 0.0)
    share = w_lt * sst(1.30, 1.12, co.z)
    # round 2 (owner 11-17 "a little bit TOO rigid (more swing too!)", "is there sway on flaps in front too??"): part of
    # the THIGH weight moves onto the chains as well, most at the hem and the front flaps (FRONTK front, SIDEK sides,
    # BACKK back, ramping in from z 1.20 to the hem); the leg colliders keep those flaps off the legs.
    front = -co.y / max(math.hypot(co.x, co.y), 1e-6)
    k = (KF if front > 0 else KB) * abs(front) + KS * (1 - abs(front))
    thigh = [g for g in v.groups if robe.vertex_groups[g.group].name in ('LeftUpperLegBone', 'RightUpperLegBone')]
    take = k * sst(1.20, 0.55, co.z)
    for g in thigh:
        moved_w = g.weight * take
        robe.vertex_groups[g.group].add([v.index], g.weight - moved_w, 'REPLACE')
        share += moved_w
    if share <= 1e-4: continue
    lt.add([v.index], max(w_lt - w_lt * sst(1.30, 1.12, co.z), 0.0), 'REPLACE')
    for s, ws in chain_mix(co):
        for n, wn in link_mix(s, co.z):
            w = share * ws * wn
            if w > 1e-5: G[f'Tail{s}{n}Bone'].add([v.index], w, 'ADD')
    moved += 1; total_share += share
# round 3 (owner 11-17: "when jumping the whole robe sways and fringe doesnt... at least ends of fringe should sway"):
# each lapel flap gets a 2-link chain under UpperTorso from its top down to its tip; the flap's points (the robe's own
# Lapel_L / Lapel_R groups, read from finished.blend: same vertex order) move onto it, more toward the tips.
SRC = bpy.data.libraries.load(LAPEL_SRC)
with SRC as (src, dst):
    dst.objects = ['Robe']
srcRobe = dst.objects[0]
assert len(srcRobe.data.vertices) == len(robe.data.vertices), 'robe vertex order changed'
lap_info = {}
for side, gname in (('UL', 'Lapel_L'), ('UR', 'Lapel_R')):
    sg = srcRobe.vertex_groups[gname]
    pts = [(v.index, next(g.weight for g in v.groups if g.group == sg.index)) for v in srcRobe.data.vertices
           if any(g.group == sg.index and g.weight > 0.05 for g in v.groups)]
    zs = [robe.data.vertices[i].co.z for i, _ in pts]
    top, bot = max(zs), min(zs)
    def at(z):
        near = [robe.data.vertices[i].co for i, _ in pts if abs(robe.data.vertices[i].co.z - z) < 0.06]
        c = sum(near, Vector()) / len(near); return Vector((c.x, c.y, z))
    heads = [at(top - 0.04), at((top + bot) / 2), at(bot + 0.03)]
    lap_info[side] = [list(map(lambda q: round(q, 3), h)) for h in heads]
    bpy.context.view_layer.objects.active = ARM; bpy.ops.object.mode_set(mode='EDIT')
    eb = ARM.data.edit_bones
    prev = eb['UpperTorsoBone']
    for n in (1, 2):
        e = eb.new(f'Tail{side}{n}Bone'); e.head, e.tail = heads[n - 1], heads[n]; e.parent = prev; e.use_connect = n > 1; prev = e
    tip = eb.new(f'Tail{side}3Bone'); tip.head = heads[2]; tip.tail = heads[2] + (heads[2] - heads[1]) * 0.3; tip.parent = prev; tip.use_connect = True
    bpy.ops.object.mode_set(mode='OBJECT')
    g1 = robe.vertex_groups.new(name=f'Tail{side}1Bone'); g2 = robe.vertex_groups.new(name=f'Tail{side}2Bone')
    mid = heads[1].z
    for i, wl in pts:
        v = robe.data.vertices[i]
        f = min(1.0, wl) * LAPK * sst(top - 0.05, bot + 0.10, v.co.z)
        if f <= 1e-4: continue
        for g in v.groups: robe.vertex_groups[g.group].add([i], g.weight * (1 - f), 'REPLACE')
        t = sst(heads[0].z, mid, v.co.z) if v.co.z > mid else 1.0
        u = sst(mid, heads[2].z, v.co.z) if v.co.z <= mid else 0.0
        w1, w2 = f * (1 - u), f * u
        if w1 > 1e-5: g1.add([i], w1, 'ADD')
        if w2 > 1e-5: g2.add([i], w2, 'ADD')
print('LAPELS', lap_info)

# 3. colliders the size of what you SEE (bloomer puff, boots, chest), each shrunk so no chain bone touches it at rest
#    (a collider over a bone's rest spot would push the cloth out while he stands still)
BONE_R = 0.04
low = bpy.data.objects['SSR_Lower']
LP = [v.co.copy() for v in low.data.vertices]
RP = [v.co.copy() for v in robe.data.vertices]
# SmartBone collides each simulated bone's POSITION (its head) with its radius; a chain's root is pinned and never
# collides. So the points that must clear the colliders at rest are the non-root joints and the chain ends.
chain_pts, chain_names = [], []
for b in ARM.data.bones:
    if b.name.startswith('Tail') and not b.name.endswith('1Bone'):
        chain_pts.append(b.head_local.copy()); chain_names.append(b.name)


def seg_dist(p, a, b):
    ab = b - a; t = max(0.0, min(1.0, (p - a).dot(ab) / ab.length_squared)); return (p - (a + ab * t)).length


def pct(vals, q):
    vals = sorted(vals); return vals[min(len(vals) - 1, int(q * len(vals)))]


COLS = []
def collider(name, body, a, b, pts, zr):
    seen = [seg_dist(p, a, b) for p in pts if zr[0] < p.z < zr[1]]
    r_vis = pct(seen, 0.5) if seen else 0.3
    dists = [seg_dist(p, a, b) for p in chain_pts]
    k_min = min(range(len(dists)), key=lambda i: dists[i])
    r_bone = dists[k_min] - BONE_R - 0.02
    print('LIMIT', name, chain_names[k_min], round(dists[k_min], 3))
    r = max(0.08, min(r_vis, r_bone))
    COLS.append(dict(name=name, body=body, a=list(a), b=list(b), r=round(r, 3), r_visible=round(r_vis, 3), r_bone_limit=round(r_bone, 3)))


for sx, side in ((1, 'Left'), (-1, 'Right')):
    collider(f'{side}Thigh', f'{side}UpperLeg', Vector((0.29 * sx, 0, 1.0)), Vector((0.30 * sx, 0, 0.70)),
             [p for p in LP if p.x * sx > 0], (0.66, 1.06))
    collider(f'{side}Shin', f'{side}LowerLeg', Vector((0.30 * sx, 0.0, 0.60)), Vector((0.32 * sx, -0.02, 0.22)),
             [p for p in LP if p.x * sx > 0], (0.12, 0.62))
collider('Seat', 'LowerTorso', Vector((-0.30, 0, 1.08)), Vector((0.30, 0, 1.08)), LP, (0.95, 1.22))
collider('Chest', 'UpperTorso', Vector((0, 0, 1.40)), Vector((0, 0, 1.95)), RP, (1.38, 1.98))
print('COLLIDERS', [(c['name'], c['r'], c['r_visible'], c['r_bone_limit']) for c in COLS])
json.dump(dict(colliders=COLS, bone_radius=BONE_R, vent_top=VENTZ, lapels=lap_info), open(f'{OUT}/sb3.json', 'w'), indent=1)

for o in bpy.context.view_layer.objects: o.select_set(o == robe)
bpy.context.view_layer.objects.active = robe
bpy.ops.object.vertex_group_limit_total(group_select_mode='ALL', limit=4)
bpy.ops.object.vertex_group_normalize_all(group_select_mode='ALL', lock_active=False)
err = max(abs(sum(g.weight for g in v.groups) - 1) for v in robe.data.vertices)
mx = max(sum(1 for g in v.groups if g.weight > 1e-6) for v in robe.data.vertices)
info = dict(thigh_share=KV, points_moved=moved, mean_share=round(total_share / max(moved, 1), 3), weight_sum_error=round(err, 5), max_influences=mx,
            chains={s: [[round(c, 3) for c in links[s][0][0]], [round(c, 3) for c in links[s][-1][1]]] for s in SIDES})
print('SB', info)
fbx = f'{OUT}/Showstopper_SB.fbx'
objs = [x for x in bpy.data.objects if x.name.startswith('SSR_')] + [ARM]
for x in bpy.context.view_layer.objects: x.select_set(x in objs)
bpy.ops.export_scene.fbx(filepath=fbx, use_selection=True, object_types={'MESH', 'ARMATURE'}, add_leaf_bones=False, bake_anim=False,
                         use_armature_deform_only=True, path_mode='STRIP', embed_textures=False, use_mesh_modifiers=False)
os.makedirs(f'{OUT}/export', exist_ok=True)
bpy.ops.wm.save_as_mainfile(filepath=f'{OUT}/export/export_final.blend')
json.dump(info, open(f'{OUT}/sb.json', 'w'), indent=1)
print('WROTE', fbx, os.path.getsize(fbx))
