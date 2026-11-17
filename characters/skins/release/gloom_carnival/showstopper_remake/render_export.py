# Renders the export file (export/export_final.blend) front and three-quarter, to check swatch colours and decimation.
import sys, os, bpy
sys.path.insert(0, 'E:/Projects/peekabu-game-systems/characters/skins/release/gloom_carnival/blockout')
import common as C
D = os.path.abspath(sys.argv[sys.argv.index('--') + 1]).replace(chr(92), '/')
bpy.ops.wm.open_mainfile(filepath=f'{D}/export/export_final.blend')
for o in bpy.data.objects:
    if o.type == 'MESH' and not o.name.startswith('SSR_') and o.name not in ('Head', 'FacePlate', 'Flower_Head', 'LeftHand', 'RightHand'):
        o.hide_render = True
cam = C.setup_render()
C.render_views(cam, f'{D}/export/exp', cz=2.4, scale=5.2, views={'front': 0, 'three_quarter': -35, 'back': 180})
print('EXPORT RENDER OK')
