"""Mesh optimisation post-process for an Employee Kit build: fewer triangles, same look.

  blender -b <build>/<Name>.blend --factory-startup -P kit/optimize_mesh.py -- <absolute out dir> [options]

Runs on a finished build (the .blend that kit/build_employee.py saves, at the T-pose) and never writes next to it.
Per MeshPart (every body part, the FacePlate and every accessory mesh):

1. Decimate: quadric edge collapse to the target (Blender's Decimate modifier, triangulated). Islands are never
   merged, and a palette mesh's islands (each colour region is its own island whose UVs all sit on one palette
   cell) keep that one UV, so no colour region can move off its cell. Mirrored collapse (--symmetry) is off by
   default: the builds are not vertex-exact mirrors, and forcing pairs pulled the centre line in by up to 0.008.
   Meshes with continuous UVs (the FacePlate's planar face-decal UVs) get their UVs re-sampled from the original
   surface at every new corner (step 3), so the face art lands on the same surface points as before; a vertex the
   collapse left in place keeps its original UV exactly.
2. Check the error: two-way sampled surface distance to the original. Where it strays over 3/4 of --max-error
   (thin folds, the FacePlate's rim flaps) the original faces within 0.04 studs are locked (kept exactly) and the
   collapse reruns on the rest, up to 4 rounds. Still over budget: the part backs off to a higher ratio (quality
   wins over the target; the report says so).
3. Transfer the shading (and continuous UVs): every corner normal of the new mesh is the original mesh's normal at that point
   (barycentric between the original corner normals of the nearest original triangle on the same island), set
   as custom split normals. The FBX carries them (mesh_smooth_type OFF exports corner normals) and Roblox keeps
   imported normals, so the light falls as on the dense mesh.
4. Export with the builder's FBX settings and names: <out>/<Name>.fbx (body + FacePlate), <out>/acc/<Acc>.fbx.
   Copies the rig JSON (joints come from the spec, not the meshes) and the palettes, regenerates
   <Name>_accessories.json from the new meshes' bounding boxes (as the builder computes it), saves
   <out>/<Name>.blend and writes <out>/optimize_report.json (per part: tris before/after, ratio, error).

Options:
  --ratio R       target triangle ratio per part (default 0.5)
  --max-tris N    also cap every part at N triangles (default 20000, Roblox's MeshPart limit)
  --max-error E   largest allowed sampled surface distance in studs (default 0.005: under the FacePlate's 0.008
                  offset and the 0.015 garment clearance, so nothing new pokes through)
  --symmetry      mirrored collapse about x = 0 for parts centred there
  --search        go lower than --ratio (down to --min-ratio) while the error stays within --max-error
  --min-ratio R   floor for --search (default 0.1)
  --only A,B      only these parts (the others are exported unchanged)
"""

import json
import os
import shutil
import sys

import bmesh
import bpy
import numpy as np
from mathutils import Vector
from mathutils.bvhtree import BVHTree
from mathutils.geometry import barycentric_transform

argv = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []
if not argv or argv[0].startswith("--"):
    raise SystemExit("usage: blender -b <Name>.blend -P kit/optimize_mesh.py -- <absolute out dir> [options]")
OUT = argv[0]
OPT = {"ratio": 0.5, "max-tris": 20000, "max-error": 0.005, "search": False, "symmetry": False, "min-ratio": 0.1, "only": ""}
i = 1
while i < len(argv):
    k = argv[i].lstrip("-")
    if k not in OPT:
        raise SystemExit(f"unknown option {argv[i]}")
    if isinstance(OPT[k], bool):
        OPT[k] = True
    else:
        i += 1
        OPT[k] = type(OPT[k])(argv[i])
    i += 1
ONLY = set(filter(None, OPT["only"].split(",")))

SRC = bpy.data.filepath
SRC_DIR = os.path.dirname(SRC)
NAME = os.path.splitext(os.path.basename(SRC))[0]
if os.path.normcase(os.path.abspath(OUT)) == os.path.normcase(os.path.abspath(SRC_DIR)):
    raise SystemExit("out dir must not be the build dir (the post-process never overwrites a build)")
os.makedirs(OUT, exist_ok=True)
GRID = 4
SAMPLES = 12000
LOCK_ROUNDS = 4
LOCK_RADIUS = 0.04


# ---- mesh helpers -----------------------------------------------------------------
def tri_count(me):
    return sum(len(p.vertices) - 2 for p in me.polygons)


def islands(me):
    """Vertex -> island id (connected by edges)."""
    parent = list(range(len(me.vertices)))
    ev = np.empty(len(me.edges) * 2, dtype=np.int32)
    me.edges.foreach_get("vertices", ev)

    def root(a):
        while parent[a] != a:
            parent[a] = parent[parent[a]]
            a = parent[a]
        return a

    for a, b in ev.reshape(-1, 2).tolist():
        ra, rb = root(a), root(b)
        if ra != rb:
            parent[ra] = rb
    return np.array([root(a) for a in range(len(parent))], dtype=np.int64)


def corner_array(me, layer, attr, width):
    out = np.empty(len(me.loops) * width, dtype=np.float64)
    layer.foreach_get(attr, out)
    return out.reshape(-1, width)


def continuous_uv(me):
    """True when some island has more than one UV value (a real texture mapping, not palette cells)."""
    uvl = me.uv_layers.active
    if not uvl:
        return False
    uv = corner_array(me, uvl.data, "uv", 2)
    lv = np.empty(len(me.loops), dtype=np.int32)
    me.loops.foreach_get("vertex_index", lv)
    isl = islands(me)[lv]
    order = np.argsort(isl, kind="stable")
    isl, uv = isl[order], uv[order]
    first = np.searchsorted(isl, isl)  # each corner's island's first corner
    return bool(np.any(np.abs(uv - uv[first]) > 1e-6))


class Surface:
    """World-space triangles of a mesh with corner normals, UVs and islands, for nearest-point queries."""

    def __init__(self, me, mw):
        me.calc_loop_triangles()
        self.me, self.mw = me, mw
        co = np.empty(len(me.vertices) * 3)
        me.vertices.foreach_get("co", co)
        m = np.array(mw)
        self.np_co = co.reshape(-1, 3) @ m[:3, :3].T + m[:3, 3]
        n = len(me.loop_triangles)
        t = np.empty(n * 3, dtype=np.int32)
        me.loop_triangles.foreach_get("vertices", t)
        self.np_tris = t.reshape(-1, 3)
        self.co = [Vector(c) for c in self.np_co.tolist()]
        self.tris = self.np_tris.tolist()
        lp = np.empty(n * 3, dtype=np.int32)
        me.loop_triangles.foreach_get("loops", lp)
        self.tloops = lp.reshape(-1, 3).tolist()
        pi = np.empty(n, dtype=np.int32)
        me.loop_triangles.foreach_get("polygon_index", pi)
        self.tri_poly = pi.tolist()
        a, b, c = (self.np_co[self.np_tris[:, k]] for k in range(3))
        self.area = 0.5 * np.linalg.norm(np.cross(b - a, c - a), axis=1)
        self.bvh = BVHTree.FromPolygons(self.co, self.tris)
        self._isl_bvh = {}
        self._cn = self._uv = self._tisl = None

    @property
    def cn(self):
        if self._cn is None:
            me = self.me
            src = me.attributes.get("_cn")  # a triangulated copy carries its quad mesh's corner normals
            arr = corner_array(me, src.data if src else me.corner_normals, "vector", 3)
            nm = np.array(self.mw.to_3x3().inverted_safe().transposed())
            self._cn = [Vector(v) for v in (arr @ nm.T).tolist()]
        return self._cn

    @property
    def uv(self):
        if self._uv is None and self.me.uv_layers.active:
            self._uv = [Vector(v) for v in corner_array(self.me, self.me.uv_layers.active.data, "uv", 2).tolist()]
        return self._uv

    @property
    def tisl(self):
        if self._tisl is None:
            self._tisl = islands(self.me)[self.np_tris[:, 0]].tolist()
        return self._tisl

    def island_bvh(self, isl):
        if isl not in self._isl_bvh:
            idx = [k for k, r in enumerate(self.tisl) if r == isl]
            self._isl_bvh[isl] = (BVHTree.FromPolygons(self.co, [self.tris[k] for k in idx]), idx)
        return self._isl_bvh[isl]

    def samples(self, n):
        """Every vertex of a triangle (loose vertices are not surface) plus n area-weighted random surface points
        (fixed seed)."""
        if not len(self.np_tris):
            return []
        rng = np.random.default_rng(1)
        k = rng.choice(len(self.area), size=n, p=self.area / self.area.sum())
        r = rng.random((n, 2))
        flip = r.sum(axis=1) > 1
        r[flip] = 1 - r[flip]
        a, b, c = (self.np_co[self.np_tris[k, j]] for j in range(3))
        pts = a + (b - a) * r[:, :1] + (c - a) * r[:, 1:]
        return np.vstack([self.np_co[np.unique(self.np_tris)], pts]).tolist()

    def weights(self, p, tri):
        a, b, c = (self.co[j] for j in self.tris[tri])
        w = barycentric_transform(p, a, b, c, Vector((1, 0, 0)), Vector((0, 1, 0)), Vector((0, 0, 1)))
        w = Vector((max(0.0, w.x), max(0.0, w.y), max(0.0, w.z)))
        return w / (w.x + w.y + w.z or 1.0)

    def normal_at(self, p, tri):
        w = self.weights(p, tri)
        na, nb, nc = (self.cn[j] for j in self.tloops[tri])
        return na * w.x + nb * w.y + nc * w.z

    def uv_at(self, p, tri):
        w = self.weights(p, tri)
        ua, ub, uc = (self.uv[j] for j in self.tloops[tri])
        return ua * w.x + ub * w.y + uc * w.z


def surface_error(a, b, flag=None):
    """(max, mean, bad) two-way distance between Surfaces a (original) and b over sampled points; bad = the points
    farther than `flag`, placed on the original (where to lock faces)."""
    worst, tot, n, bad = 0.0, 0.0, 0, []
    for src, dst in ((a, b), (b, a)):
        for p in src.samples(SAMPLES):
            loc = dst.bvh.find_nearest(p)[0]
            d = (loc - Vector(p)).length if loc is not None else 1e9
            worst, tot, n = max(worst, d), tot + d, n + 1
            if flag is not None and d > flag:
                bad.append(Vector(p) if src is a else loc)
    return worst, tot / max(n, 1), bad


def centred_x(ob):
    xs = [(ob.matrix_world @ v.co).x for v in ob.data.vertices]
    return abs(min(xs) + max(xs)) < 1e-3 * max(1.0, max(xs) - min(xs))


def triangulated(me):
    """A copy of `me` built from exactly the triangles Blender draws it with (mesh.loop_triangles), carrying the quad mesh's corner normals in a "_cn" corner attribute. The collapse works on
    this, so it never flips a bent quad's diagonal (that alone moved the surface by up to 0.007 studs)."""
    me.calc_loop_triangles()
    n = len(me.loop_triangles)
    tv = np.empty(n * 3, dtype=np.int32)
    me.loop_triangles.foreach_get("vertices", tv)
    src_loops = np.empty(n * 3, dtype=np.int32)  # new corner k*3+j = old corner loop_triangles[k].loops[j]
    me.loop_triangles.foreach_get("loops", src_loops)
    pi = np.empty(n, dtype=np.int32)
    me.loop_triangles.foreach_get("polygon_index", pi)
    co = np.empty(len(me.vertices) * 3, dtype=np.float32)
    me.vertices.foreach_get("co", co)
    tm = bpy.data.meshes.new(me.name + "_tri")
    tm.vertices.add(len(me.vertices))
    tm.vertices.foreach_set("co", co)
    tm.loops.add(n * 3)
    tm.loops.foreach_set("vertex_index", tv)
    tm.polygons.add(n)
    tm.polygons.foreach_set("loop_start", np.arange(0, n * 3, 3, dtype=np.int32))
    tm.update(calc_edges=True)
    for m in me.materials:
        tm.materials.append(m)
    for attr, dt in (("material_index", np.int32), ("use_smooth", bool)):
        src = np.empty(len(me.polygons), dtype=dt)
        me.polygons.foreach_get(attr, src)
        tm.polygons.foreach_set(attr, src[pi])
    for layer in me.uv_layers:
        nl = tm.uv_layers.new(name=layer.name)
        nl.data.foreach_set("uv", corner_array(me, layer.data, "uv", 2)[src_loops].ravel())
    cn = tm.attributes.new("_cn", "FLOAT_VECTOR", "CORNER")
    cn.data.foreach_set("vector", corner_array(me, me.corner_normals, "vector", 3)[src_loops].ravel())
    return tm


def decimated(tm, mw, ratio, locked):
    """A collapsed copy of the triangulated mesh `tm` at `ratio` of its triangles overall; faces in `locked` are
    left exactly as they are (edit-mode decimate only touches the selection)."""
    tmp = bpy.data.objects.new("_opt_tmp", tm.copy())
    tmp.matrix_world = mw
    bpy.context.scene.collection.objects.link(tmp)
    me = tmp.data
    total = tri_count(me)
    held = sum(len(me.polygons[k].vertices) - 2 for k in locked)
    r_sel = max(0.02, min(1.0, (ratio * total - held) / max(1, total - held)))
    for o in bpy.context.view_layer.objects:
        o.select_set(o is tmp)
    bpy.context.view_layer.objects.active = tmp
    bpy.ops.object.mode_set(mode="EDIT")
    bm = bmesh.from_edit_mesh(me)
    bm.select_mode = {"FACE"}
    for v in bm.verts:
        v.select_set(False)
    for f in bm.faces:
        f.select_set(f.index not in locked)
    bm.select_flush_mode()
    bmesh.update_edit_mesh(me)
    bpy.ops.mesh.decimate(ratio=r_sel, use_symmetry=OPT["symmetry"] and centred_x(tmp), symmetry_axis="X")
    bpy.ops.object.mode_set(mode="OBJECT")
    bpy.data.objects.remove(tmp)
    return me


def transfer(me, mw, orig, uvs):
    """Custom split normals of `me` = the original surface's interpolated corner normals at each corner (and, with
    `uvs`, its UVs too)."""
    co = [mw @ v.co for v in me.vertices]
    isl = islands(me)
    # each new island takes the original island most of its vertices are nearest to
    votes = {}
    for vi, p in enumerate(co):
        hit = orig.bvh.find_nearest(p)
        if hit[2] is not None:
            votes.setdefault(isl[vi], {}).setdefault(orig.tisl[hit[2]], 0)
            votes[isl[vi]][orig.tisl[hit[2]]] += 1
    match = {r: max(v, key=v.get) for r, v in votes.items()}
    inv = mw.to_3x3().transposed()  # world normal -> local (inverse transpose of the inverse)
    loops = []
    uvl = me.uv_layers.active if uvs else None
    for lp in me.loops:
        p = co[lp.vertex_index]
        tree, idx = orig.island_bvh(match[isl[lp.vertex_index]])
        loc, _, k, _ = tree.find_nearest(p)
        n = orig.normal_at(loc, idx[k])
        loops.append(tuple((inv @ n).normalized()))
        if uvl:
            uvl.data[lp.index].uv = orig.uv_at(loc, idx[k])
    for poly in me.polygons:
        poly.use_smooth = True
    me.normals_split_custom_set(loops)


# ---- per part -----------------------------------------------------------------------
report = {"source": SRC, "options": OPT, "parts": {}}
meshes = [o for o in bpy.data.objects if o.type == "MESH"]
for ob in meshes:
    if ONLY and ob.name not in ONLY:
        continue
    before = tri_count(ob.data)
    uvs = continuous_uv(ob.data)
    target = min(OPT["ratio"], OPT["max-tris"] / before)
    _budget = json.loads(os.environ.get("PART_TRIS", "{}"))
    if ob.name in _budget:
        target = min(1.0, _budget[ob.name] / before)
    tm = triangulated(ob.data)
    orig = Surface(tm, ob.matrix_world)
    tri_err = surface_error(Surface(ob.data, ob.matrix_world), orig)[0]
    if tri_err > 1e-4:
        raise SystemExit(f"{ob.name}: the triangulated copy is {tri_err} off the drawn mesh")
    budget = OPT["max-error"]

    def attempt(r, locked):
        me = decimated(tm, ob.matrix_world, r, locked)
        return me, surface_error(orig, Surface(me, ob.matrix_world), flag=0.75 * budget)

    # error-driven locking: where the collapse strays over 3/4 of the budget, the original faces around that spot
    # are kept as they are and the collapse runs again (the rest of the part takes the triangle cut)
    locked, ratio, note = set(), target, ""
    for it in range(LOCK_ROUNDS + 1):
        me, err = attempt(ratio, locked)
        if err[0] <= budget or it == LOCK_ROUNDS:
            break
        grow = set()
        for p in err[2]:
            for _, _, k, _ in orig.bvh.find_nearest_range(p, LOCK_RADIUS):
                grow.add(orig.tri_poly[k])
        if not grow - locked:
            break
        locked |= grow
        bpy.data.meshes.remove(me)
    if err[0] > budget:
        first = err[0]
        # quality wins: the smallest ratio above the target that fits the error budget
        lo, hi, best = ratio, 1.0, None
        for _ in range(6):
            mid = (lo + hi) / 2
            m2, e2 = attempt(mid, locked)
            if e2[0] <= budget:
                best, hi = (m2, e2, mid), mid
            else:
                lo = mid
        if best:
            me, err, ratio = best
        else:
            me, err, ratio = tm.copy(), (0.0, 0.0, []), 1.0
        note = f"error {first:.4f} over budget at ratio {target:.3f}: backed off to {ratio:.3f}"
    elif OPT["search"]:
        lo, hi = OPT["min-ratio"], ratio
        for _ in range(6):
            mid = (lo + hi) / 2
            m2, e2 = attempt(mid, locked)
            if e2[0] <= budget:
                me, err, ratio, hi = m2, e2, mid, mid
            else:
                lo = mid
    transfer(me, ob.matrix_world, orig, uvs)
    me.attributes.remove(me.attributes["_cn"])
    bpy.data.meshes.remove(tm)
    old = ob.data
    me.materials.clear()
    for m in old.materials:
        me.materials.append(m)
    me.name = old.name
    ob.data = me
    bpy.data.meshes.remove(old)
    report["parts"][ob.name] = {
        "uv": "resampled" if uvs else "palette cells", "tris_before": before, "tris_after": tri_count(me), "ratio": round(ratio, 4),
        "locked_faces": len(locked), "max_error": round(err[0], 5), "mean_error": round(err[1], 6), "note": note,
    }
    print(f"OPT {ob.name:24s} {'uv' if uvs else 'pal'} {before:6d} -> {tri_count(me):6d}  max err {err[0]:.5f}  locked {len(locked)}  {note}", flush=True)


# ---- export (the builder's settings and names) ----------------------------------------
def export_fbx(path, objs):
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
    bpy.ops.export_scene.fbx(
        filepath=path, use_selection=True, object_types={"MESH"}, apply_unit_scale=True,
        apply_scale_options="FBX_SCALE_UNITS", axis_forward="-Z", axis_up="Y", use_mesh_modifiers=True,
        mesh_smooth_type="OFF", use_custom_props=False, path_mode="STRIP",
    )


def bbox_centre(ob):
    co = [ob.matrix_world @ v.co for v in ob.data.vertices]
    return Vector([(min(p[k] for p in co) + max(p[k] for p in co)) / 2 for k in range(3)])


def rbx(v):
    return [round(v[0], 4), round(v[2], 4), round(-v[1], 4)]


def copy_if(src, dst):
    if os.path.exists(src):
        os.makedirs(os.path.dirname(dst), exist_ok=True)
        shutil.copyfile(src, dst)
        return True
    return False


acc_meshes = {}
for o in meshes:
    if "acc" in o.keys():
        acc_meshes.setdefault(o["acc"], []).append(o)
body = [o for o in meshes if "acc" not in o.keys()]
export_fbx(f"{OUT}/{NAME}.fbx", body)
for an, obs in acc_meshes.items():
    os.makedirs(f"{OUT}/acc", exist_ok=True)
    export_fbx(f"{OUT}/acc/{an}.fbx", obs)

rig_src = f"{SRC_DIR}/{NAME}_rig.json"
if os.path.exists(rig_src):
    copy_if(rig_src, f"{OUT}/{NAME}_rig.json")
    if not copy_if(f"{SRC_DIR}/{NAME}_palette.png", f"{OUT}/{NAME}_palette.png"):
        report["palette_note"] = f"{NAME}_palette.png is not in the build dir (it lives with the build's source)"
acc_src = f"{SRC_DIR}/{NAME}_accessories.json"
if os.path.exists(acc_src):
    with open(acc_src, encoding="utf-8") as f:
        acc_json = json.load(f)
    moved = 0.0
    for an, info in acc_json.items():
        copy_if(f"{SRC_DIR}/{info['palette']}", f"{OUT}/{info['palette']}")
        for pc in info["pieces"]:
            new = rbx(bbox_centre(bpy.data.objects[pc["mesh"]]) - bbox_centre(bpy.data.objects[pc["mount"]]))
            moved = max(moved, max(abs(a - b) for a, b in zip(new, pc["offset"])))
            pc["offset"] = new
    report["accessory_offset_max_change"] = round(moved, 4)
    with open(f"{OUT}/{NAME}_accessories.json", "w", encoding="utf-8") as f:
        json.dump(acc_json, f, indent=1)

with open(f"{OUT}/optimize_report.json", "w", encoding="utf-8") as f:
    json.dump(report, f, indent=1)
bpy.ops.wm.save_as_mainfile(filepath=f"{OUT}/{NAME}.blend", copy=True, relative_remap=False)
print("OPTIMIZE OK", NAME, sum(p["tris_before"] for p in report["parts"].values()), "->",
      sum(p["tris_after"] for p in report["parts"].values()), flush=True)
