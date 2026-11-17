# TEXTURE ROUND (2026-11-16, ss_export_tex.py): as ss_export_remake.py, but every mesh gets real UVs and baked colour /
# normal / roughness maps (tex_bake.py) instead of the flat swatch, and the bloomers are ONE shell (ss_bloomer_shell.py).
#   blender -b --disable-autoexec -P ss_export_tex.py -- <dir> [weights k=v] [PLUM=hex] [RES=1024]
# Showstopper REMAKE -> one Roblox skinned outfit FBX for the Studio test (owner 11-16: "Let's see this in studio now!").
# Uses the game's deform skeleton (route2 Showstopper_DeformSkeleton: <Part>Bone at the template joints). The robe's six
# skirt chains become Tail<side><n>Bone chains under LowerTorsoBone (the game's EmployeeTailSystem swings any
# Tail<side><n>Bone chain; n = 4 is the zero-weight end marker). The lapel/collar bones have no game driver yet, so for
# this test their weights go to UpperTorsoBone (the fold itself stays). Flat colours go into one small swatch texture
# (one texture per MeshPart). Meshes: SSR_Robe (robe), SSR_Upper (sleeves, waistcoat, shirt, toggles), SSR_Lower (bloomers, boots),
# SSR_Hat (the earlier hat, own texture, rides the head).
#   blender -b --disable-autoexec -P ss_export_remake.py -- <dir>    -> <dir>/export/Showstopper_Remake.fbx, export.json
import bpy, bmesh, sys, os, json, math
import numpy as np
from mathutils import Vector

A = sys.argv[sys.argv.index('--') + 1:]
D = os.path.abspath(A[0]).replace(chr(92), '/')
OUT = f'{D}/export'; os.makedirs(OUT, exist_ok=True)
MAX_TRIS = 16000
# round 5 (owner: skirt edges twitch, clip, flip over on jump): the skirt is SKINNED to the hips and thighs, no tail
# chains (TAILS=1 keeps the round 4 chains for the game's tail spring).
TAILS = 'TAILS=1' in A[1:]
# crouch round (2026-11-16, A3 era): the weights that decide the crouch pokes, as k=v arguments (defaults = round 5)
KV = dict(UP0=0.98, UP1=1.12, FBACK=0.40, FSPAN=0.55, SIDEB=0.0, T1=0.55)
for kv in A[1:]:
    if '=' in kv and kv.split('=')[0] in KV: KV[kv.split('=')[0]] = float(kv.split('=')[1])
print('WEIGHT PARAMS', KV)
bpy.ops.wm.open_mainfile(filepath=f'{D}/finished.blend')
R2 = 'E:/Projects/peekabu-game-systems/characters/skins/release/gloom_carnival/route2_whole/export_r25/Showstopper_R2_final.blend'
with bpy.data.libraries.load(R2) as (src, dst):
    dst.objects = ['Showstopper_DeformSkeleton']
ARM = dst.objects[0]; bpy.context.scene.collection.objects.link(ARM)
RIG = bpy.data.objects['RobeRig']


def sst(a, b, x):
    t = min(max((x - a) / (b - a), 0.0), 1.0); return t * t * (3 - 2 * t)


# ---- tail chains on the deform skeleton (positions from the robe's own skirt bones)
for o in bpy.context.view_layer.objects: o.select_set(False)
bpy.context.view_layer.objects.active = ARM; bpy.ops.object.mode_set(mode='EDIT')
eb = ARM.data.edit_bones
chains = {}
for b in RIG.data.bones:
    if not b.name.startswith('Skirt'): continue
    side, n = b.name[5:7], int(b.name[7:])
    chains.setdefault(side, {})[n] = (b.head_local.copy(), b.tail_local.copy())
for side, links in (chains.items() if TAILS else []):
    prev = eb['LowerTorsoBone']
    for n in sorted(links):
        h, t = links[n]
        e = eb.new(f'Tail{side}{n}Bone'); e.head, e.tail = h, t; e.parent = prev; e.use_connect = n > 1; prev = e
    tip = eb.new(f'Tail{side}{len(links) + 1}Bone'); d = prev.tail - prev.head
    tip.head = prev.tail; tip.tail = prev.tail + d * 0.2; tip.parent = prev; tip.use_connect = True
bpy.ops.object.mode_set(mode='OBJECT')

# colour pass (2026-11-16): PLUM=<hex> recolours the coat/sleeve plum before the swatch is made (hat keeps its own texture)
for kv in A[1:]:
    if kv.startswith('PLUM='):
        hx = kv[5:].lstrip('#'); srgb = [int(hx[i:i + 2], 16) / 255 for i in (0, 2, 4)]
        lin = [c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4 for c in srgb]
        bpy.data.materials['GC_plum'].diffuse_color = (*lin, 1.0); print('PLUM', hx)
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import tex_bake
RES = int(next((kv.split('=')[1] for kv in A[1:] if kv.startswith('RES=')), 1024))


def to_swatch(o):
    pass                      # texture round: zone materials stay on the faces until the bake


def bake(o):
    dg = bpy.context.evaluated_depsgraph_get()
    if o.modifiers:
        me = bpy.data.meshes.new_from_object(o.evaluated_get(dg)); o.modifiers.clear(); o.data = me
    if o.parent:
        mw = o.matrix_world.copy(); o.parent = None; o.matrix_world = mw
    o.data.transform(o.matrix_world); o.matrix_world.identity()


def set_w(o, fn):
    """fn(co) -> {bone: weight}"""
    o.vertex_groups.clear(); G = {}
    for v in o.data.vertices:
        for bn, w in fn(v.co).items():
            if w <= 1e-4: continue
            if bn not in G: G[bn] = o.vertex_groups.new(name=bn)
            G[bn].add([v.index], w, 'REPLACE')


# ---- the robe: its own weights, renamed onto the skeleton
robe = bpy.data.objects['Robe']
for m in list(robe.modifiers):
    if m.type == 'ARMATURE': robe.modifiers.remove(m)
bake(robe)
ren = {'UpperTorso': 'UpperTorsoBone', 'LowerTorso': 'LowerTorsoBone'}
if not TAILS:
    # skirt weights from where each point hangs: front panels follow their own thigh most (0.95 at the hem), the back
    # least (0.40); the centre back splits between both thighs; the waist stays with the hips.
    ZW_, ZH_ = 1.32, 0.43
    for g in [g for g in robe.vertex_groups if g.name.startswith('Skirt')]: robe.vertex_groups.remove(g)
    for nm in ('LowerTorso', 'LeftUpperLegBone', 'RightUpperLegBone'):
        if nm not in robe.vertex_groups: robe.vertex_groups.new(name=nm)
    gl, gL, gR = robe.vertex_groups['LowerTorso'], robe.vertex_groups['LeftUpperLegBone'], robe.vertex_groups['RightUpperLegBone']
    gU = robe.vertex_groups.get('UpperTorso')
    for v in robe.data.vertices:
        co = v.co
        if co.z >= 1.30: continue
        for g in list(robe.vertex_groups):
            g.remove([v.index])
        t = min(max((ZW_ - co.z) / (ZW_ - ZH_), 0.0), 1.0)
        front = -co.y / max(math.hypot(co.x, co.y), 1e-6)
        side_ = 1 - abs(front)                                          # 1 at the sides, 0 front and back
        follow = min(1.0, (KV['FBACK'] + KV['FSPAN'] * (front + 1) / 2 + KV['SIDEB'] * side_) * sst(0.0, KV['T1'], t))   # r5: front 0.95, sides 0.68, back 0.40
        wl = sst(-0.12, 0.12, co.x)
        gl.add([v.index], 1 - follow, 'REPLACE')
        if follow * wl > 1e-4: gL.add([v.index], follow * wl, 'REPLACE')
        if follow * (1 - wl) > 1e-4: gR.add([v.index], follow * (1 - wl), 'REPLACE')
for g in list(robe.vertex_groups):
    if g.name.startswith('Skirt'):
        g.name = f'Tail{g.name[5:7]}{g.name[7:]}Bone'
    elif g.name in ren:
        g.name = ren[g.name]
# lapel/collar bones -> UpperTorsoBone for this test (no game driver for them yet)
ut = robe.vertex_groups['UpperTorsoBone']
for g in [g for g in robe.vertex_groups if g.name in ('Lapel_L', 'Lapel_R', 'Collar')]:
    for v in robe.data.vertices:
        for vg in v.groups:
            if vg.group == g.index and vg.weight > 0:
                cur = next((x.weight for x in v.groups if x.group == ut.index), 0.0)
                ut.add([v.index], cur + vg.weight, 'REPLACE')
    robe.vertex_groups.remove(g)
to_swatch(robe)
tris = sum(len(p.vertices) - 2 for p in robe.data.polygons)
if tris > MAX_TRIS:
    dm = robe.modifiers.new('dec', 'DECIMATE'); dm.ratio = MAX_TRIS / tris * 0.97
    bake(robe)
robe.name = robe.data.name = 'SSR_Robe'

# ---- the other pieces: weights by where they sit
def arm_w(side):
    sgn = 1 if side == 'Left' else -1
    return lambda co: {f'{side}UpperArmBone': 1 - sst(0.70, 0.86, sgn * co.x), f'{side}LowerArmBone': sst(0.70, 0.86, sgn * co.x)}


def leg_w(side):
    def f(co):
        up = sst(KV['UP0'], KV['UP1'], co.z)            # top of the bloomer leg blends into the hips (r5: 0.98..1.12)
        low = 1 - sst(0.56, 0.72, co.z)                 # below the knee the leg rides the shin, into the boot
        lt, ll = up, low * (1 - up)
        return {'LowerTorsoBone': lt, f'{side}LowerLegBone': ll, f'{side}UpperLegBone': max(0.0, 1 - lt - ll)}
    return f


def seat_w(co):
    side = 'Left' if co.x > 0 else 'Right'
    leg = (1 - sst(0.92, 1.10, co.z)) * sst(0.08, 0.25, abs(co.x))
    return {'LowerTorsoBone': 1 - leg, f'{side}UpperLegBone': leg}


def shell_w(co):
    """the one-shell bloomers: each side's leg weights, split across the crotch like the robe's skirt (+-0.10)"""
    wl = sst(-0.10, 0.10, co.x); out = {}
    for side, f in (('Left', wl), ('Right', 1 - wl)):
        if f <= 1e-4: continue
        for bn, w in leg_w(side)(co).items(): out[bn] = out.get(bn, 0.0) + w * f
    return out


rules = []
for o in list(bpy.data.objects):
    if o.type != 'MESH' or o.hide_render: continue
    n = o.name
    if n.startswith('Sleeve_'): rules.append((o, arm_w('Left' if n.endswith('L') else 'Right')))
    elif n in ('Waistcoat', 'Shirt_collar') or n.startswith('Toggle'): rules.append((o, lambda co: {'UpperTorsoBone': 1.0}))
    elif n == 'Bloomer_seat': rules.append((o, seat_w))
    elif n == 'Bloomer_shell': rules.append((o, shell_w))
    elif n.startswith('Bloomer_leg_'): rules.append((o, leg_w('Left' if n.endswith('L') else 'Right')))
    elif n.startswith('Bloomer_cuff_'): rules.append((o, (lambda s: lambda co: {f'{s}LowerLegBone': 1.0})('Left' if n.endswith('L') else 'Right')))
    elif n.startswith('Boot_'):
        side = 'Left' if 'Left' in n else 'Right'
        bone = f'{side}FootBone' if n.endswith('Boot') else f'{side}LowerLegBone'
        rules.append((o, (lambda b: lambda co: {b: 1.0})(bone)))
# round 5: TWO joined meshes, no decimation (decimating across the swatch colours broke the dark cuff band into shards)
groups = {'SSR_Upper': [], 'SSR_Lower': []}
for o, fn in rules:
    bake(o); set_w(o, fn); to_swatch(o)
    groups['SSR_Lower' if o.name.startswith(('Bloomer_', 'Boot_')) else 'SSR_Upper'].append(o)
PARTS = []
for nm, objs in groups.items():
    for o in bpy.context.view_layer.objects: o.select_set(o in objs)
    bpy.context.view_layer.objects.active = objs[0]; bpy.ops.object.join()
    J_ = bpy.context.view_layer.objects.active; J_.name = J_.data.name = nm; PARTS.append(J_)

# ---- the earlier hat rides the head
hat = bpy.data.objects['ShowHat']; bake(hat); set_w(hat, lambda co: {'HeadBone': 1.0}); hat.name = 'SSR_Hat'

TEXINFO = tex_bake.bake_all([robe, *PARTS], hat, OUT, RES)
info = {'_tex': TEXINFO}
for o in (robe, *PARTS, hat):
    o.parent = ARM
    m = o.modifiers.new('Armature', 'ARMATURE'); m.object = ARM
    for o2 in bpy.context.view_layer.objects: o2.select_set(o2 == o)
    bpy.context.view_layer.objects.active = o
    bpy.ops.object.vertex_group_limit_total(group_select_mode='ALL', limit=4)
    bpy.ops.object.vertex_group_normalize_all(group_select_mode='ALL', lock_active=False)
    for g in o.vertex_groups: assert g.name in ARM.data.bones, (o.name, g.name)
    err = max(abs(sum(g.weight for g in v.groups) - 1) for v in o.data.vertices)
    mx = max(sum(1 for g in v.groups if g.weight > 1e-6) for v in o.data.vertices)
    bm = bmesh.new(); bm.from_mesh(o.data); oe = sum(1 for e in bm.edges if not e.is_manifold); bm.free()
    info[o.name] = dict(tris=sum(len(p.vertices) - 2 for p in o.data.polygons), weight_sum_error=round(err, 5), max_influences=mx,
                        open_edges=oe, groups=sorted(g.name for g in o.vertex_groups))
    print('MESH', o.name, {k: v for k, v in info[o.name].items() if k != 'groups'})
    assert info[o.name]['tris'] <= 20000, o.name
fbx = f'{OUT}/Showstopper_Remake.fbx'
for o in bpy.context.view_layer.objects: o.select_set(o in (robe, *PARTS, hat, ARM))
bpy.ops.export_scene.fbx(filepath=fbx, use_selection=True, object_types={'MESH', 'ARMATURE'}, add_leaf_bones=False,
                         bake_anim=False, use_armature_deform_only=True, path_mode='COPY', embed_textures=True, use_mesh_modifiers=False)
bpy.ops.wm.save_as_mainfile(filepath=f'{OUT}/export_final.blend')
info['_bones'] = [b.name for b in ARM.data.bones]
json.dump(info, open(f'{OUT}/export.json', 'w'), indent=1)
print('WROTE', fbx, os.path.getsize(fbx))
