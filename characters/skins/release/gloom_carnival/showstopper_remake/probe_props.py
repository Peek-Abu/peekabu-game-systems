import bpy, sys, numpy as np
from mathutils import Vector
def bb(o):
    P=np.array([(o.matrix_world@v.co)[:] for v in o.data.vertices]); return P.min(0).round(3).tolist(), P.max(0).round(3).tolist()
R='E:/Projects/peekabu-game-systems/characters/skins/release/gloom_carnival/route2_whole/'
bpy.ops.wm.open_mainfile(filepath=R+'hat_r33/ShowHat_proj.blend')
for o in bpy.data.objects:
    if o.type=='MESH': print('HATFILE',o.name,len(o.data.vertices),bb(o), [m.name for m in o.data.materials])
    else: print('HATFILE other',o.name,o.type)
bpy.ops.wm.open_mainfile(filepath=R+'export_r25/Showstopper_R2_final.blend')
for o in bpy.data.objects:
    if o.type=='MESH': print('R2',o.name,len(o.data.vertices),bb(o))
    else: print('R2 other',o.name,o.type)
bpy.ops.wm.open_mainfile(filepath='r6/pieces.blend')
for o in bpy.data.objects:
    if o.type=='MESH' and any(k in o.name for k in ('Head','Hat','Boot','Foot','Flower','Lower','Bloomer')): print('R6',o.name,bb(o))
