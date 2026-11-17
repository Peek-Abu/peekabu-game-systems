# Texture round (2026-11-16): real UVs + baked colour / tangent normal / roughness per outfit mesh. Imported by
# ss_export_tex.py (Blender). Owner: "the texture just looks bland", "coat and boots also seem to have no textures",
# "make it as similar to concept texture".
#   colour    = the garment's flat concept colour x its scan detail (lum/mean of the styled CC0 scan, tex_prep.py) x a
#               soft local AO (only this mesh, so pieces never darken each other into "seams")
#   normal    = bump from the scan's height, tangent space, OpenGL (+Y), what SurfaceAppearance.NormalMap expects
#   roughness = the styled scan roughness (style.json class targets), gold 0.35
# The detail is box-projected in stud space (every mesh is baked in world = object space), so the weave has the same
# size on every piece and does not depend on the UV layout. Baked at 2x RES, scaled down.
import bpy, os, math
import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__)).replace(chr(92), '/')
TEX = f'{HERE}/tex/textures'
CC0 = f'{HERE}/tex/cc0'
SCAN = {'ss_velvet': 'Fabric084', 'ss_weave': 'Fabric036', 'ss_cotton': 'Fabric082A', 'ss_leather': 'Leather038',
        'ss_felt': 'Fabric034'}
# zone: detail class, tile size in studs, colour-detail strength, bump distance (studs), AO strength
ZONES = {
    'GC_plum': dict(det='ss_velvet', studs=1.2, k=1.0, bump=0.004, ao=0.45),
    'GC_cream': dict(det='ss_weave', studs=0.8, k=1.0, bump=0.003, ao=0.35),
    'GC_vest': dict(det='ss_weave', studs=0.8, k=1.0, bump=0.003, ao=0.35),
    'GC_shirt': dict(det='ss_cotton', studs=1.0, k=1.0, bump=0.002, ao=0.3),
    'GC_bloom': dict(det='ss_cotton', studs=1.0, k=1.0, bump=0.003, ao=0.45),
    'GC_bloom_dk': dict(det='ss_cotton', studs=1.0, k=1.0, bump=0.003, ao=0.45),
    'GC_boot': dict(det='ss_leather', studs=0.6, k=1.0, bump=0.002, ao=0.35),
    'GC_gold': dict(det=None, rough=0.35, ao=0.25),
}
HAT = dict(det='ss_felt', studs=0.7, k=1.0, bump=0.004, ao=0.3)
AO_DIST = 0.06
for kv in os.environ.get('TEXKV', '').split():           # quick tuning: TEXKV="GC_plum.bump=0.006 HAT.k=0.8"
    k, _, v = kv.partition('='); zn, _, f = k.partition('.')
    (HAT if zn == 'HAT' else ZONES[zn])[f] = float(v)


def _img(path, noncolor=True):
    im = bpy.data.images.load(path, check_existing=True)
    if noncolor: im.colorspace_settings.name = 'Non-Color'
    return im


def _box(N, path, noncolor=True):
    t = N.new('ShaderNodeTexImage'); t.image = _img(path, noncolor); t.projection = 'BOX'; t.projection_blend = 0.3
    t.interpolation = 'Cubic'
    return t


def _build(mat, base_lin, z, target, hat_img=None, gold_mask=None):
    """Rebuild mat's nodes for baking. Returns (out_node, emission_node, principled_node, target_node)."""
    mat.use_nodes = True
    nt = mat.node_tree; N = nt.nodes; L = nt.links
    for n in list(N): N.remove(n)
    out = N.new('ShaderNodeOutputMaterial')
    em = N.new('ShaderNodeEmission'); pr = N.new('ShaderNodeBsdfPrincipled')
    pr.inputs['Metallic'].default_value = 0.0
    tc = N.new('ShaderNodeTexCoord')
    if hat_img:                                           # the hat's own (violet) texture on its own UVs
        ht = N.new('ShaderNodeTexImage'); ht.image = _img(hat_img, False)
        uvn = N.new('ShaderNodeUVMap'); uvn.uv_map = 'UVMap'; L.new(uvn.outputs['UV'], ht.inputs['Vector'])
        base = ht.outputs['Color']
    else:
        rgb = N.new('ShaderNodeRGB'); rgb.outputs[0].default_value = (*base_lin, 1.0); base = rgb.outputs[0]
    gm = None
    if gold_mask:
        g = N.new('ShaderNodeTexImage'); g.image = _img(gold_mask)
        uvg = N.new('ShaderNodeUVMap'); uvg.uv_map = 'UVMap'; L.new(uvg.outputs['UV'], g.inputs['Vector'])
        gm = g.outputs['Color']
    ao = N.new('ShaderNodeAmbientOcclusion'); ao.only_local = True; ao.samples = 16
    ao.inputs['Distance'].default_value = AO_DIST
    s = z.get('ao', 0.3)
    aof = N.new('ShaderNodeMath'); aof.operation = 'MULTIPLY_ADD'               # 1 - s + s*ao
    aof.inputs[1].default_value = s; aof.inputs[2].default_value = 1 - s
    L.new(ao.outputs['AO'], aof.inputs[0])
    col = base
    if z.get('det'):
        mp = N.new('ShaderNodeMapping'); mp.inputs['Scale'].default_value = (1 / z['studs'],) * 3
        L.new(tc.outputs['Object'], mp.inputs['Vector'])
        rt = _box(N, f"{TEX}/{z['det']}_ratio.png"); L.new(mp.outputs[0], rt.inputs['Vector'])
        f = N.new('ShaderNodeMath'); f.operation = 'MULTIPLY_ADD'               # 1 + (2r - 1) k
        f.inputs[1].default_value = 2 * z['k']; f.inputs[2].default_value = 1 - z['k']
        L.new(rt.outputs['Color'], f.inputs[0])
        fo = f.outputs[0]
        if gm is not None:                                                       # no felt on the gold band
            fm = N.new('ShaderNodeMix'); fm.data_type = 'FLOAT'
            L.new(gm, fm.inputs['Factor']); L.new(f.outputs[0], fm.inputs[2]); fm.inputs[3].default_value = 1.0
            fo = fm.outputs[0]
        m1 = N.new('ShaderNodeVectorMath'); m1.operation = 'SCALE'
        L.new(col, m1.inputs[0]); L.new(fo, m1.inputs['Scale']); col = m1.outputs[0]
        ro = _box(N, f"{TEX}/{z['det']}_rough.png"); L.new(mp.outputs[0], ro.inputs['Vector'])
        rough = ro.outputs['Color']
        if gm is not None:
            rm = N.new('ShaderNodeMix'); rm.data_type = 'FLOAT'
            L.new(gm, rm.inputs['Factor']); L.new(ro.outputs['Color'], rm.inputs[2]); rm.inputs[3].default_value = 0.35
            rough = rm.outputs[0]
        L.new(rough, pr.inputs['Roughness'])
        sid = SCAN[z['det']]
        hi = _box(N, f'{CC0}/{sid}/{sid}_2K-JPG_Displacement.jpg'); L.new(mp.outputs[0], hi.inputs['Vector'])
        bp = N.new('ShaderNodeBump'); bp.inputs['Distance'].default_value = z['bump']; bp.inputs['Strength'].default_value = 1.0
        hsrc = hi.outputs['Color']
        if gm is not None:
            hm = N.new('ShaderNodeMath'); hm.operation = 'MULTIPLY'
            inv = N.new('ShaderNodeMath'); inv.operation = 'SUBTRACT'; inv.inputs[0].default_value = 1.0
            L.new(gm, inv.inputs[1]); L.new(hi.outputs['Color'], hm.inputs[0]); L.new(inv.outputs[0], hm.inputs[1])
            hsrc = hm.outputs[0]
        L.new(hsrc, bp.inputs['Height']); L.new(bp.outputs['Normal'], pr.inputs['Normal'])
    else:
        pr.inputs['Roughness'].default_value = z.get('rough', 0.5)
    m2 = N.new('ShaderNodeVectorMath'); m2.operation = 'SCALE'
    L.new(col, m2.inputs[0]); L.new(aof.outputs[0], m2.inputs['Scale'])
    L.new(m2.outputs[0], em.inputs['Color']); em.inputs['Strength'].default_value = 1.0
    tgt = N.new('ShaderNodeTexImage'); tgt.image = target; N.active = tgt
    return out, em, pr, tgt


def _new_img(name, res, fill, noncolor):
    im = bpy.data.images.get(name)
    if im: bpy.data.images.remove(im)
    im = bpy.data.images.new(name, res, res, alpha=True)
    if noncolor: im.colorspace_settings.name = 'Non-Color'
    im.pixels = np.tile(np.array(fill, np.float32), res * res)
    return im


def _unwrap(o):
    me = o.data
    while me.uv_layers: me.uv_layers.remove(me.uv_layers[0])
    me.uv_layers.new(name='UVMap')
    for x in bpy.context.view_layer.objects: x.select_set(x == o)
    bpy.context.view_layer.objects.active = o
    bpy.ops.object.mode_set(mode='EDIT'); bpy.ops.mesh.select_all(action='SELECT')
    bpy.ops.uv.smart_project(angle_limit=math.radians(66), island_margin=0.002, area_weight=0.0, correct_aspect=True,
                             scale_to_bounds=False)
    bpy.ops.uv.pack_islands(rotate=True, margin=0.004)
    bpy.ops.object.mode_set(mode='OBJECT')


def _bake_one(o, out_dir, res, hat=False):
    big = res * 2
    col = _new_img(f'{o.name}_color', big, (0, 0, 0, 0), False)
    nrm = _new_img(f'{o.name}_normal', big, (0.5, 0.5, 1, 1), True)
    rgh = _new_img(f'{o.name}_rough', big, (0.8, 0.8, 0.8, 1), True)
    trip = []
    for m in o.data.materials:
        if hat:
            trip.append(_build(m, None, HAT, col, hat_img=f'{TEX}/ShowHat_violet.png', gold_mask=f'{TEX}/ShowHat_gold.png'))
        else:
            z = ZONES.get(m.name.split('.')[0], ZONES['GC_plum'])
            trip.append(_build(m, tuple(m.diffuse_color[:3]), z, col))
    for x in bpy.context.view_layer.objects: x.select_set(x == o)
    bpy.context.view_layer.objects.active = o
    sc = bpy.context.scene; bk = sc.render.bake
    bk.margin = 16; bk.margin_type = 'EXTEND'; bk.use_clear = False; bk.target = 'IMAGE_TEXTURES'
    for kind, img, samples in (('EMIT', col, 32), ('NORMAL', nrm, 4), ('ROUGHNESS', rgh, 4)):
        for out, em, pr, tgt in trip:
            L = out.id_data.node_tree.links if hasattr(out.id_data, 'node_tree') else out.id_data.links
            for l in list(out.inputs['Surface'].links): L.remove(l)
            L.new((em if kind == 'EMIT' else pr).outputs[0], out.inputs['Surface'])
            tgt.image = img; tgt.id_data.nodes.active = tgt
        sc.cycles.samples = samples
        if kind == 'NORMAL': bk.normal_space = 'TANGENT'
        bpy.ops.object.bake(type=kind, uv_layer='UVMap')
    info = {}
    cover = None
    for img, tag in ((col, 'color'), (nrm, 'normal'), (rgh, 'rough')):
        a = np.array(img.pixels[:], np.float32).reshape(big, big, 4)
        if tag == 'color': cover = a[..., 3] > 0.5
        if tag == 'normal':
            v = a[..., :3][cover] * 2 - 1
            info['normal_tilt_mean_deg'] = round(float(np.degrees(np.arccos(np.clip(v[:, 2], -1, 1))).mean()), 2)
        if tag == 'rough': info['rough_mean'] = round(float(a[..., 0][cover].mean()), 3)
        img.scale(res, res)
        p = f'{out_dir}/{o.name}_{tag}.png'
        img.filepath_raw = p; img.file_format = 'PNG'; img.save()
    info['uv_coverage'] = round(float(cover.mean()), 3)
    fm = bpy.data.materials.new(f'{o.name}_PBR'); fm.use_nodes = True
    N = fm.node_tree.nodes; L = fm.node_tree.links; pb = N['Principled BSDF']
    tc = N.new('ShaderNodeTexImage'); tc.image = col; L.new(tc.outputs['Color'], pb.inputs['Base Color'])
    tn = N.new('ShaderNodeTexImage'); tn.image = nrm
    nm = N.new('ShaderNodeNormalMap'); nm.uv_map = 'UVMap'; L.new(tn.outputs['Color'], nm.inputs['Color'])
    L.new(nm.outputs['Normal'], pb.inputs['Normal'])
    tr = N.new('ShaderNodeTexImage'); tr.image = rgh; L.new(tr.outputs['Color'], pb.inputs['Roughness'])
    o.data.materials.clear(); o.data.materials.append(fm)
    print('BAKED', o.name, info)
    return info


def bake_all(meshes, hat, out_dir, res=1024):
    sc = bpy.context.scene
    sc.render.engine = 'CYCLES'; sc.cycles.device = 'CPU'
    sc.view_settings.view_transform = 'Standard'
    info = {}
    for o in meshes:
        _unwrap(o)
        info[o.name] = _bake_one(o, out_dir, res)
    info[hat.name] = _bake_one(hat, out_dir, res, hat=True)
    return info
