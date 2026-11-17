# Illustration for the owner's "will SmartBone change how it looks?": the SAME round 5 mesh in a walk frame, with the
# skirt part swung back a little the way SmartBone's heavy-wool lag would carry it (more toward the hem, nothing at the
# waist). Not a simulation: a fixed lag of SWING degrees, to show what changes (motion only) and what does not (the model).
#   blender -b --disable-autoexec -P sway_demo.py -- <posed_scene_dir> [SWING=14]
import bpy, sys, os, math
import numpy as np
from mathutils import Matrix, Vector
sys.path.insert(0, 'E:/Projects/peekabu-game-systems/characters/skins/release/gloom_carnival/blockout')
import common as C
A = sys.argv[sys.argv.index('--') + 1:]
S = os.path.abspath(A[0]).replace(chr(92), '/')
SW = float(next((a[6:] for a in A if a.startswith('SWING=')), 14))
bpy.ops.wm.open_mainfile(filepath=f'{S}/finished.blend')
R = bpy.data.objects['SSR_Robe']
co = np.array([v.co[:] for v in R.data.vertices])
band = co[(co[:, 2] > 1.25) & (co[:, 2] < 1.35)]
piv = Vector((band[:, 0].mean(), band[:, 1].mean(), 1.30))
for v in R.data.vertices:
    if v.co.z >= 1.30: continue
    t = min(1.0, (1.30 - v.co.z) / 0.9)
    M = Matrix.Rotation(math.radians(SW) * t ** 1.5, 4, 'X')
    v.co = piv + M @ (v.co - piv)
C.hide(['UpperTorso', 'LowerTorso', 'LeftUpperArm', 'RightUpperArm', 'LeftLowerArm', 'RightLowerArm',
        'LeftUpperLeg', 'RightUpperLeg', 'LeftLowerLeg', 'RightLowerLeg', 'LeftFoot', 'RightFoot'])
cam = C.setup_render()
C.render_views(cam, f'{S}/sway', cz=2.4, scale=5.2, views={'three_quarter': -35, 'side': -90})
print('SWAY OK')
