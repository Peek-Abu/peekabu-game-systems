# Renders one keyframe of an idle rbxmx on Prickles' real meshes (FK as idle_arms.py), plain or wearing the Showstopper
# remake test outfit (export_final.blend, linear-blend skinned with the same part matrices).
#   blender -b --disable-autoexec -P render_idle.py -- <clip.rbxmx> <frame> <out_prefix> [outfit]
import bpy, sys, os, json, math
import numpy as np
import xml.etree.ElementTree as ET
from mathutils import Matrix
sys.path.insert(0, 'E:/Projects/peekabu-game-systems/characters/skins/release/gloom_carnival/blockout')
import common as C

A = sys.argv[sys.argv.index('--') + 1:]
CLIP, FRAME, OUTP = A[0], int(A[1]), A[2]
OUTFIT = 'outfit' in A[3:]
CH = 'E:/Projects/peekabu-game-systems/characters'
EXP = 'E:/Projects/peekabu-game-systems/characters/skins/release/gloom_carnival/showstopper_remake/r19/export/export_final.blend'
M = np.array([[-1., 0, 0], [0, 0, 1], [0, 1, 0]]); M4 = np.eye(4); M4[:3, :3] = M
PARENT = {'LowerTorso': None, 'UpperTorso': 'LowerTorso', 'Head': 'UpperTorso'}
for side in ['Left', 'Right']:
    for part, parent in [('UpperArm', 'UpperTorso'), ('LowerArm', side + 'UpperArm'), ('Hand', side + 'LowerArm'),
                         ('UpperLeg', 'LowerTorso'), ('LowerLeg', side + 'UpperLeg'), ('Foot', side + 'LowerLeg')]:
        PARENT[side + part] = parent
rig = json.load(open(f'{CH}/prickles/v4/Prickles_rig.json'))
piv = {j['part1']: np.array([-j['pos'][0], j['pos'][1], -j['pos'][2]]) for j in rig['joints'].values()}
keys = sorted([e for e in ET.parse(CLIP).getroot().iter('Item') if e.get('class') == 'Keyframe'],
              key=lambda e: float(e.find('./Properties/float[@name="Time"]').text))
loc = {}
for e in keys[FRAME].iter('Item'):
    if e.get('class') != 'Pose': continue
    name = e.find('./Properties/string[@name="Name"]').text; cf = e.find('./Properties/CoordinateFrame')
    if name not in PARENT or cf is None: continue
    t = np.eye(4); t[:3, 3] = [float(cf.find(a).text) for a in 'XYZ']
    t[:3, :3] = [[float(cf.find(f'R{a}{b}').text) for b in range(3)] for a in range(3)]; loc[name] = t
native, skin = {}, {}
for part, parent in PARENT.items():
    a = np.eye(4); a[:3, 3] = piv[part]; b = np.eye(4); b[:3, 3] = -piv[part]
    native[part] = (native[parent] if parent else np.eye(4)) @ a @ loc.get(part, np.eye(4)) @ b
    skin[part] = M4.T @ native[part] @ M4

rigob = C.open_src('prickles')
rigob.data.pose_position = 'REST'; bpy.context.view_layer.update()
HEADISH = ('Head', 'FacePlate', 'Flower', 'HardHat')
for o in list(bpy.data.objects):
    if o.type != 'MESH': continue
    part = 'Head' if o.name.startswith(HEADISH) else (o.name if o.name in skin else None)
    if part is None: continue
    mw = o.matrix_world.copy()
    o.parent = None
    o.matrix_world = Matrix(skin[part].tolist()) @ mw
if OUTFIT:
    C.hide(['HardHat_Head', 'UpperTorso', 'LowerTorso', 'LeftUpperArm', 'RightUpperArm', 'LeftLowerArm', 'RightLowerArm',
            'LeftUpperLeg', 'RightUpperLeg', 'LeftLowerLeg', 'RightLowerLeg', 'LeftFoot', 'RightFoot'])
    with bpy.data.libraries.load(EXP) as (s, d):
        d.objects = [n for n in s.objects if n.startswith('SSR_')]
    for o in d.objects:
        bpy.context.scene.collection.objects.link(o)
        o.modifiers.clear(); o.parent = None; o.matrix_world = Matrix.Identity(4)
        gn = [g.name[:-4] for g in o.vertex_groups]
        for v in o.data.vertices:
            p = np.array([*v.co, 1.0]); q = np.zeros(3)
            for g in v.groups:
                part = gn[g.group]
                q += g.weight * (skin[part] @ p)[:3] if part in skin else g.weight * p[:3]
            v.co = q
cam = C.setup_render()
C.render_views(cam, OUTP, cz=2.4, scale=5.2, views={'front': 0, 'three_quarter': -35, 'side': -90})
print('IDLE RENDER OK')
