# Moves the robe's skirt bones like a mid stride (left front swings back, right front forward, sides out a little), to
# show that the skirt is part of the one robe mesh and bends with its own bones (no seam, no separate piece).
#   blender -b --disable-autoexec -P pose_demo.py -- <out_dir>    -> <out_dir>/pose_*.png (lit)
import bpy, sys, os, math
from mathutils import Quaternion, Vector

SWING = {'SkirtLF': (18, 'X'), 'SkirtRF': (-14, 'X'), 'SkirtLS': (-12, 'Y'), 'SkirtRS': (12, 'Y'),
         'SkirtLB': (12, 'X'), 'SkirtRB': (8, 'X')}
# the lapel and collar flaps lift off a little (their own short bones)
FLAPS = {'Lapel_L': (-12, 'Z'), 'Lapel_R': (12, 'Z'), 'Collar': (10, 'X')}
AXIS = {'X': (1, 0, 0), 'Y': (0, 1, 0), 'Z': (0, 0, 1)}


def apply():
    ar = bpy.data.objects['RobeRig']
    for pb in ar.pose.bones:
        pre = pb.name[:-1]
        if pb.name in FLAPS:
            deg, ax = FLAPS[pb.name]
        elif pre in SWING:
            deg, ax = SWING[pre]
            deg = deg * (0.6 if pb.name.endswith('1') else 0.3)  # most of the swing at the top bone, a little more lower
        else:
            continue
        w = Quaternion(Vector(AXIS[ax]), math.radians(deg))
        m = pb.bone.matrix_local.to_3x3()
        pb.rotation_mode = 'QUATERNION'
        pb.rotation_quaternion = (m.inverted() @ w.to_matrix() @ m).to_quaternion()
    bpy.context.view_layer.update()


if __name__ == '__main__' and '--' in sys.argv:
    sys.path.insert(0, 'E:/Projects/peekabu-game-systems/characters/skins/release/gloom_carnival/blockout')
    import common as C
    D = os.path.abspath(sys.argv[sys.argv.index('--') + 1]).replace(chr(92), '/')
    bpy.ops.wm.open_mainfile(filepath=f'{D}/finished.blend')
    apply()
    # as in the game: the skin hides his whole body except head and hands
    C.hide(['UpperTorso', 'LowerTorso', 'LeftUpperArm', 'RightUpperArm', 'LeftLowerArm', 'RightLowerArm',
            'LeftUpperLeg', 'RightUpperLeg', 'LeftLowerLeg', 'RightLowerLeg', 'LeftFoot', 'RightFoot'])
    cam = C.setup_render()
    C.render_views(cam, f'{D}/pose', cz=2.4, scale=5.2)
    print('POSE OK')
