import sys, math, bpy, numpy as np
sys.path.insert(0, 'E:/Projects/peekabu-game-systems/characters/skins/release/gloom_carnival/blockout')
import common as C
from mathutils import Vector
from mathutils.bvhtree import BVHTree
C.open_src('prickles')
dg=bpy.context.evaluated_depsgraph_get()
for o in bpy.data.objects:
    if o.type=='MESH' and not o.hide_render:
        P=np.array([(o.matrix_world@v.co)[:] for v in o.data.vertices]); print('OBJ',o.name,P.min(0).round(2).tolist(),P.max(0).round(2).tolist())
def bvh(names):
    vs=[];fs=[]
    for n in names:
        o=bpy.data.objects[n].evaluated_get(dg); me=o.to_mesh(); b=len(vs)
        vs+=[(o.matrix_world@v.co) for v in me.vertices]; fs+=[[b+i for i in p.vertices] for p in me.polygons]
    return BVHTree.FromPolygons(vs,fs)
H=bvh(['Head'])
for r in (0.3,0.4,0.5,0.6,0.7,0.8):
    zs=[]
    for th in range(0,360,45):
        a=math.radians(th); o=Vector((r*math.cos(a),r*math.sin(a),1.5)); h=H.ray_cast(o,Vector((0,0,1)),5)
        zs.append(round(h[0].z,2) if h[0] else None)
    print('HEADBOTTOM r',r,zs)
T=bvh(['UpperTorso','LowerTorso'])
for z in (1.3,1.5,1.7,1.9,2.1,2.2,2.3):
    rs=[]
    for th in range(0,360,30):
        a=math.radians(th); best=None
        o=Vector((3*math.cos(a),3*math.sin(a),z)); h=T.ray_cast(o,Vector((-math.cos(a),-math.sin(a),0)),5)
        rs.append(round((h[0].xy).length,2) if h[0] else None)
    print('TORSO z',z,rs)
