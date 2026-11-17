# Mock for the owner's "hard to see where the arm / hand starts": the posed scene with the sleeve's flared cuff (rest
# |x| > 1.045) in CREAM instead of plum, so a pale ring separates the plum sleeve from his green hand. Render only.
#   blender -b --disable-autoexec -P variant_cuff.py -- <dir> <posed_scene_dir>
import bpy, sys, os
sys.path.insert(0, 'E:/Projects/peekabu-game-systems/characters/skins/release/gloom_carnival/blockout')
import common as C
A = sys.argv[sys.argv.index('--') + 1:]
D, S = [os.path.abspath(x).replace(chr(92), '/') for x in A[:2]]
bpy.ops.wm.open_mainfile(filepath=f'{D}/export/export_final.blend')
me = bpy.data.objects['SSR_Upper'].data
cuff = [p.index for p in me.polygons if abs(p.center.x) > 1.045 and 1.6 < p.center.z < 2.5]
bpy.ops.wm.open_mainfile(filepath=f'{S}/finished.blend')
me = bpy.data.objects['SSR_Upper'].data
uv = me.uv_layers.active
CREAM = ((1 + 0.5) / 4, (0 + 0.5) / 4)       # swatch block 1 = GC_cream (ss_export_remake.py SW order)
for i in cuff:
    for li in me.polygons[i].loop_indices: uv.data[li].uv = CREAM
C.hide(['UpperTorso', 'LowerTorso', 'LeftUpperArm', 'RightUpperArm', 'LeftLowerArm', 'RightLowerArm',
        'LeftUpperLeg', 'RightUpperLeg', 'LeftLowerLeg', 'RightLowerLeg', 'LeftFoot', 'RightFoot'])
cam = C.setup_render()
C.render_views(cam, f'{S}/cuff', cz=2.4, scale=5.2, views={'front': 0, 'three_quarter': -35})
print('CUFF OK', len(cuff))
