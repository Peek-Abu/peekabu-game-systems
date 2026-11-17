# Renders the remake blockout (finished.blend in the out dir): front / three-quarter / side / back.
#   blender -b --disable-autoexec -P render_blockout.py -- <out_dir> [flat]
import sys, os
sys.path.insert(0, 'E:/Projects/peekabu-game-systems/characters/skins/release/gloom_carnival/blockout')
import bpy
import common as C

A = sys.argv[sys.argv.index('--') + 1:]
D = os.path.abspath(A[0]).replace(chr(92), '/')
FLAT = 'flat' in A[1:]
bpy.ops.wm.open_mainfile(filepath=f'{D}/finished.blend')
# as in the game: the skin hides his whole body except head and hands
C.hide(['UpperTorso', 'LowerTorso', 'LeftUpperArm', 'RightUpperArm', 'LeftLowerArm', 'RightLowerArm',
        'LeftUpperLeg', 'RightUpperLeg', 'LeftLowerLeg', 'RightLowerLeg', 'LeftFoot', 'RightFoot'])
cam = C.setup_render()
if FLAT:
    plum = C.mat('plum', '#683256', .75)
    gold = C.mat('gold', '#D9AA68', .35, .7)
    for o in bpy.data.objects:
        if o.name.startswith('SS_'):
            o.data.materials.clear(); o.data.materials.append(gold if 'Pipe' in o.name else plum)
    sc = bpy.context.scene
    sc.render.engine = 'BLENDER_WORKBENCH'
    sc.display.shading.light = 'FLAT'
    sc.display.shading.color_type = 'TEXTURE'
    sc.view_settings.view_transform = 'Standard'
C.render_views(cam, f'{D}/{"flat" if FLAT else "lit"}', cz=2.4, scale=5.2)
print('RENDER OK')
