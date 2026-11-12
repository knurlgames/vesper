"""The supporting cast's model pipeline (WO-012, ART_DIRECTION.md "The supporting cast"), headless in Blender:

    blender -b --python tools/cast_build.py -- <stage> [body ...]     (no bodies = all of BODIES)

Stages, in order:
    prep    the Meshy rig (walk + run clips), stray parts and floor discs removed, decimated to budget, 2K textures,
            feet centred on the origin. Renders build/prep_<body>_*.png.
    chains  tail and ear bones added to Meshy's 24-bone humanoid, with their weights. Renders a test pose.
    clips   idle and talk made here (Meshy gives walk and run); the tail and ears sway in every clip.
    mask    the garb bodies' masks (Meshy mask-only models), fitted to the face in the rest pose.
    seams   pads every texture's unused texels (tools/seams.py).
    export  assets/characters/<who>/<who>_<outfit>.glb (+ the mask as <Body>_Mask on the head bone).

Sources: .wip/cast/raw/<body>_rigged.glb, _walk.glb, _run.glb (Meshy auto-rig, task ids in
.wip/meshy/wo012_cast_3d.json) and <who>_mask.glb. Work files: .wip/cast/build/<body>.blend.
Meshy's rig keeps its own bone names (Hips, Spine02, Spine01, Spine, neck, Head, LeftArm...) and its weights, which
deform cleanly through the walk; this adds what it lacks. Blender -Y is the front, +Z up, as for Nim.
"""
import heapq
import math
import os
import sys

import bmesh
import bpy
import numpy as np
from mathutils import Matrix, Vector

TOOLS = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, TOOLS)
import nim_build as nb  # noqa: E402  (render helpers, the mask fit's brass recolour)
import seams  # noqa: E402

ROOT = os.path.join(TOOLS, "..")
RAW = os.path.join(ROOT, ".wip", "cast", "raw")
WIP = os.path.join(ROOT, ".wip", "cast", "build")
OUT = os.path.join(ROOT, "assets", "characters")

## Per body: tail bones (0 = none worth rigging), whether the ears get bones, which mask (garb only).
BODIES = {
    # Pinned tails (x, y, z, after prep's centring), read off prep_<body>_side.png where the search found a boot or
    # a calf: Vesper's garb has a bobcat stub, Augusta's suit a tuft that hangs to the knee.
    "vesper_garb": {"tail": 3, "ears": True, "tail_tip": (0.0, 0.19, 1.03)},
    "vesper_suit": {"tail": 3, "ears": True},
    "augusta_garb": {"tail": 6, "ears": True, "mask": "augusta"},
    "augusta_suit": {"tail": 6, "ears": True, "tail_tip": (0.03, 0.33, 0.45), "tail_skip": 6},
    "silke_garb": {"tail": 8, "ears": True, "mask": "silke"},
    "silke_suit": {"tail": 8, "ears": True},
    "dash_garb": {"tail": 8, "ears": True, "mask": "dash"},
    "dash_suit": {"tail": 8, "ears": True},
    "rivet_garb": {"tail": 5, "ears": True, "mask": "rivet"},
    "rivet_suit": {"tail": 5, "ears": True},
    "lull_garb": {"tail": 6, "ears": True, "mask": "lull", "floor_disc": True},
    "lull_suit": {"tail": 6, "ears": True, "floor_disc": True},
    "grizelda_garb": {"tail": 6, "ears": True, "mask": "grizelda"},
    "grizelda_suit": {"tail": 6, "ears": True},
    "bastion_garb": {"tail": 0, "ears": True, "mask": "bastion"},   # Meshy's model has no tail (nor rosettes)
    "bastion_suit": {"tail": 7, "ears": True},
    "swyne": {"tail": 0, "ears": False},
}

TARGET_TRIS = 60000     # ART_DIRECTION: the supporting cast is 30-80k triangles, 2K textures
TEX = 2048


def _who(body):
    return body.split("_")[0]


def _blend(body):
    return os.path.join(WIP, "%s.blend" % body)


def _open(body):
    bpy.ops.wm.open_mainfile(filepath=_blend(body))
    arm = next(o for o in bpy.data.objects if o.type == "ARMATURE")
    mesh = bpy.data.objects[body]
    return arm, mesh


def _save(body):
    os.makedirs(WIP, exist_ok=True)
    bpy.ops.file.pack_all()
    bpy.ops.wm.save_as_mainfile(filepath=_blend(body))


def _world_verts(mesh):
    mw = mesh.matrix_world
    return [mw @ v.co for v in mesh.data.vertices]


def _bone_world(arm, name):
    b = arm.data.bones[name]
    return arm.matrix_world @ b.head_local, arm.matrix_world @ b.tail_local


# --- prep -----------------------------------------------------------------------------------------------------------
def _import(path):
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=path)
    return [o for o in bpy.data.objects if o not in before]


def _islands(me):
    """Connected vertex islands, as lists of vertex indices."""
    parent = list(range(len(me.vertices)))

    def find(i):
        while parent[i] != i:
            parent[i] = parent[parent[i]]
            i = parent[i]
        return i
    for e in me.edges:
        a, b = find(e.vertices[0]), find(e.vertices[1])
        if a != b:
            parent[a] = b
    groups = {}
    for i in range(len(parent)):
        groups.setdefault(find(i), []).append(i)
    return list(groups.values())


FLOOR_Z = 0.035         # a floor disc lies this low (Lull's: 1.5-2.8 cm, a plate 57 cm across)
FLOOR_UP_Z = 0.015      # face-up vertices go only this low (a boot's welt can face up just above it)
FOOT_REACH = 0.06       # boot soles stay this close (in plan) to the ankle-to-toe line


def _remove_floor(mesh, arm, height):
    """Concept ground shadows come through Meshy as a flat disc round the feet (Lull), welded to the boot soles.
    Floor-level vertices go if they lie beyond the boots in plan or face up (a sole faces down or out)."""
    me = mesh.data
    mw = mesh.matrix_world
    ws = [mw @ v.co for v in me.vertices]
    floor = min(w.z for w in ws)
    feet = []
    for s in ("Left", "Right"):
        a = _bone_world(arm, s + "Foot")[0]
        b = _bone_world(arm, s + "ToeBase")[1]
        feet.append((Vector((a.x, a.y, 0)), Vector((b.x, b.y, 0))))
    nmat = mw.to_3x3()
    far, up, low = set(), set(), set()
    for i, w in enumerate(ws):
        if w.z - floor > FLOOR_Z:
            continue
        low.add(i)
        p = Vector((w.x, w.y, 0))
        if min(_seg_dist(p, a, b) for a, b in feet) > FOOT_REACH:
            far.add(i)
        elif w.z - floor < FLOOR_UP_Z and (nmat @ me.vertices[i].normal).normalized().z > 0.5:
            up.add(i)
    # What's left of a disc under the boots is the shadow's light grey; the soles are dark.
    img = _base_image(mesh)
    bright = set()
    if img is not None and me.uv_layers.active:
        w_, h_ = img.size
        px = np.empty(w_ * h_ * 4, np.float32)
        img.pixels.foreach_get(px)
        px = px.reshape(h_, w_, 4)
        uvs = me.uv_layers.active.data
        for loop in me.loops:
            if loop.vertex_index in low:
                u, v = uvs[loop.index].uv
                c = px[int(v * h_) % h_, int(u * w_) % w_]
                if 0.3 * c[0] + 0.59 * c[1] + 0.11 * c[2] > 0.45:
                    bright.add(loop.vertex_index)
    drop = far | up | bright
    if drop:
        bm = bmesh.new()
        bm.from_mesh(me)
        bm.verts.ensure_lookup_table()
        bmesh.ops.delete(bm, geom=[bm.verts[i] for i in drop], context="VERTS")
        bm.to_mesh(me)
        bm.free()
        me.update()
    return len(drop)


def _base_image(obj):
    """The image feeding the Principled BSDF's Base Color (Meshy materials carry normal and metal maps too)."""
    for mat in obj.data.materials:
        if not (mat and mat.use_nodes):
            continue
        bsdf = next((n for n in mat.node_tree.nodes if n.type == "BSDF_PRINCIPLED"), None)
        node = bsdf.inputs["Base Color"].links[0].from_node if bsdf and bsdf.inputs["Base Color"].links else None
        while node is not None and node.type != "TEX_IMAGE":
            ins = [link.from_node for i in node.inputs for link in i.links]
            node = ins[0] if ins else None
        if node is not None:
            return node.image
    return None


def prep(body):
    nb.clear()
    new = _import(os.path.join(RAW, "%s_walk.glb" % body))
    arm = next(o for o in new if o.type == "ARMATURE")
    meshes = [o for o in new if o.type == "MESH" and o.parent == arm]
    mesh = max(meshes, key=lambda o: len(o.data.vertices))
    for o in new:
        if o not in (arm, mesh):
            bpy.data.objects.remove(o)
    arm.name = "%s_Rig" % body
    mesh.name = body
    walk = arm.animation_data.action
    walk.name = "walk"
    # The run: same skeleton, same bone names; keep only its action.
    new = _import(os.path.join(RAW, "%s_run.glb" % body))
    run_arm = next(o for o in new if o.type == "ARMATURE")
    run = run_arm.animation_data.action
    run.name = "run"
    run.use_fake_user = True
    walk.use_fake_user = True
    for o in new:
        bpy.data.objects.remove(o)
    bpy.ops.outliner.orphans_purge(do_recursive=True)
    arm.data.pose_position = "REST"
    bpy.context.view_layer.update()
    t = _Timer()
    # glTF splits every vertex on a UV seam: weld them back so the surface is one piece (the UVs stay per corner,
    # so the seams survive), or nothing can walk along it and the floor test mistakes boot soles for a disc.
    bm = bmesh.new()
    bm.from_mesh(mesh.data)
    before = len(bm.verts)
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-5)
    welded = before - len(bm.verts)
    bm.to_mesh(mesh.data)
    bm.free()
    mesh.data.update()
    t("weld")
    ws = _world_verts(mesh)
    height = max(w.z for w in ws) - min(w.z for w in ws)
    # Only where the walk renders showed a concept's ground shadow came through (Lull): wide boots and heels reach
    # past any "beyond the feet" line, and an automatic test clipped their soles.
    dropped = _remove_floor(mesh, arm, height) if BODIES[body].get("floor_disc") else 0
    t("floor")
    # Decimate to budget, never across a UV seam; the vertex groups interpolate with it.
    tris = sum(len(p.vertices) - 2 for p in mesh.data.polygons)
    if tris > TARGET_TRIS:
        dec = seams.decimate_safe(mesh, TARGET_TRIS / tris)
        bpy.ops.object.select_all(action="DESELECT")
        mesh.select_set(True)
        bpy.context.view_layer.objects.active = mesh
        bpy.ops.object.modifier_move_to_index(modifier=dec.name, index=0)
        bpy.ops.object.modifier_apply(modifier=dec.name)
    t("decimate")
    for img in {n.image for m in mesh.data.materials if m and m.use_nodes for n in m.node_tree.nodes
                if n.type == "TEX_IMAGE" and n.image}:
        if img.size[0] > TEX:
            img.scale(TEX, TEX)
            img.pack()
    t("textures")
    # Feet centred on the origin: the soles' middle (x, y) moves to 0, the floor to z 0.
    ws = _world_verts(mesh)
    low = [w for w in ws if w.z < min(x.z for x in ws) + 0.08]
    shift = Vector((-(min(w.x for w in low) + max(w.x for w in low)) / 2,
                    -(min(w.y for w in low) + max(w.y for w in low)) / 2, -min(w.z for w in ws)))
    arm.location += shift
    bpy.context.view_layer.update()
    rep = {"height": round(height, 3), "welded": welded, "floor_dropped": dropped,
           "islands": len(_islands(mesh.data)),
           "tris": sum(len(p.vertices) - 2 for p in mesh.data.polygons), "shift": [round(c, 3) for c in shift],
           "rot_mode": arm.pose.bones["Hips"].rotation_mode,
           "walk": [round(f, 1) for f in walk.frame_range], "run": [round(f, 1) for f in run.frame_range],
           "fps": bpy.context.scene.render.fps}
    nb.WIP = WIP
    os.makedirs(WIP, exist_ok=True)
    nb.render_views(mesh, "prep_%s" % body, size=600)
    t("renders")
    arm.data.pose_position = "POSE"
    _save(body)
    t("save")
    rep["seconds"] = t.laps
    return rep


class _Timer:
    def __init__(self):
        import time
        self._time = time.time
        self._t = time.time()
        self.laps = {}

    def __call__(self, name):
        now = self._time()
        self.laps[name] = round(now - self._t, 1)
        self._t = now


# --- chains: tail and ears ------------------------------------------------------------------------------------------
## The tail and ears are found on the surface, not configured: the tail tip is the lower body's furthest point
## along the surface from the head (away from the hands and feet); an ear tip is the head's highest point out to
## each side. From a tip, rings of equal surface distance walk up the limb, and the walk stops where a ring opens
## out into the body. A body can pin a tip with "tail_tip" / "ear_tip.L" / "ear_tip.R" (x, z) in BODIES.
TAIL_STEP = 0.02         # ring spacing along a tail
LEG_CLEAR = 0.14         # a tail tip is at least this far from every leg bone
TAIL_WIDEN = 1.6         # a ring this much wider than the tail's typical ring is the body
TAIL_ROOT_R = 0.17       # a tail's centreline that comes this close to the Hips joint has reached its root
TAIL_NEAR = 2.2          # tail vertices lie within this many girths of the centreline
EAR_STEP = 0.006
EAR_FRAC = 0.35          # an ear's reach down from its tip, as a fraction of the tip's height above the head joint
BLEND_LEN = 0.06         # the last few cm of a chain blend into Meshy's own weights
TEST_CURL = 22.0         # degrees per tail bone in the check render


def _adjacency(me, vs):
    adj = [[] for _ in vs]
    for e in me.edges:
        a, b = e.vertices
        w = (vs[a] - vs[b]).length
        adj[a].append((b, w))
        adj[b].append((a, w))
    return adj


def _geodesic(adj, start, limit=float("inf")):
    dist = {start: 0.0}
    heap = [(0.0, start)]
    while heap:
        d, i = heapq.heappop(heap)
        if d > dist.get(i, float("inf")) or d > limit:
            continue
        for j, w in adj[i]:
            nd = d + w
            if nd < dist.get(j, float("inf")):
                dist[j] = nd
                heapq.heappush(heap, (nd, j))
    return dist


def _centre(points):
    return sum(points, Vector()) / len(points)


def _walk(vs, adj, tip, step, stop, max_len, radii_out=None):
    """Rings of equal surface distance from `tip`. Returns the centreline (root first), the cut distance and the
    distances, for the weights. `radii_out` collects each kept ring's radius, tip first."""
    dist = _geodesic(adj, tip, max_len + step)
    rings = {}
    for i, d in dist.items():
        rings.setdefault(int(d / step), []).append(vs[i])
    pts, radii, cut = [vs[tip].copy()], [], 0.0
    for k in sorted(rings):
        if k * step > max_len:
            break
        c = _centre(rings[k])
        r = sum((v - c).length for v in rings[k]) / len(rings[k])
        if stop(k, r, radii, (k + 0.5) * step, c):
            break
        radii.append(r)
        pts.append(c)
        cut = (k + 1) * step
    pts.reverse()
    if radii_out is not None:
        radii_out.extend(radii)
    return pts, cut, dist


def _resample(pts, n):
    lengths = [0.0]
    for a, b in zip(pts, pts[1:]):
        lengths.append(lengths[-1] + (b - a).length)
    total = lengths[-1]
    out = []
    for i in range(n + 1):
        s = total * i / n
        j = min(max(k for k in range(len(lengths)) if lengths[k] <= s + 1e-9), len(pts) - 2)
        f = 0.0 if lengths[j + 1] == lengths[j] else (s - lengths[j]) / (lengths[j + 1] - lengths[j])
        out.append(pts[j].lerp(pts[j + 1], min(max(f, 0.0), 1.0)))
    return out, total


def _nearest(vs, *p):
    """The vertex nearest a pinned point: (x, y, z), or (x, z) for an ear seen from the front."""
    if len(p) == 3:
        q = Vector(p)
        return min(range(len(vs)), key=lambda i: (vs[i] - q).length_squared)
    x, z = p
    return min(range(len(vs)), key=lambda i: (vs[i].x - x) ** 2 + (vs[i].z - z) ** 2 - 0.001 * vs[i].y)


def _tail_tip(arm, vs, adj, cfg):
    if "tail_tip" in cfg:
        return _nearest(vs, *cfg["tail_tip"])
    head = _bone_world(arm, "Head")[0]
    top = max(range(len(vs)), key=lambda i: vs[i].z - 4 * abs(vs[i].x - head.x))
    from_head = _geodesic(adj, top)
    hips = _bone_world(arm, "Hips")[0]
    # Keep the hands and the whole of each leg out: fencing off only the feet makes the fence's edge (a calf) the
    # furthest point.
    hands = [_bone_world(arm, b)[0] for b in ("LeftHand", "RightHand")]
    legs = [_bone_world(arm, s + b) for s in ("Left", "Right") for b in ("UpLeg", "Leg", "Foot", "ToeBase")]
    legs = [(a, b) for a, b in legs]
    # The Leg bone ends at the Foot's head, the Foot at the ToeBase: chain them so each segment is a real limb part.
    for s in ("Left", "Right"):
        legs += [(_bone_world(arm, s + a)[0], _bone_world(arm, s + b)[0])
                 for a, b in (("UpLeg", "Leg"), ("Leg", "Foot"), ("Foot", "ToeBase"))]
    cands = [i for i, d in from_head.items() if 0.06 < vs[i].z < hips.z
             and all((vs[i] - p).length > 0.24 for p in hands)
             and all(_seg_dist(vs[i], a, b) > LEG_CLEAR for a, b in legs)]
    return max(cands, key=lambda i: from_head[i])


def _ear_tip(arm, vs, side, cfg):
    key = "ear_tip." + ("L" if side > 0 else "R")
    if key in cfg:
        return _nearest(vs, *cfg[key])
    head, crown = _bone_world(arm, "Head")[0], _bone_world(arm, "head_end")[0]
    band = [i for i, v in enumerate(vs) if v.z > head.z]
    half = max(abs(vs[i].x - head.x) for i in band)
    cands = [i for i in band if side * (vs[i].x - head.x) > 0.3 * half]
    return max(cands, key=lambda i: vs[i].z + 0.35 * side * (vs[i].x - head.x))


def _add_chain(arm, names, pts, parent):
    inv = arm.matrix_world.inverted()
    bpy.ops.object.select_all(action="DESELECT")
    arm.select_set(True)
    bpy.context.view_layer.objects.active = arm
    bpy.ops.object.mode_set(mode="EDIT")
    eb_prev = arm.data.edit_bones[parent]
    for name, a, b in zip(names, pts, pts[1:]):
        if name in arm.data.edit_bones:
            arm.data.edit_bones.remove(arm.data.edit_bones[name])
        eb = arm.data.edit_bones.new(name)
        eb.head = inv @ a
        eb.tail = inv @ b
        eb.parent = eb_prev
        eb.use_connect = eb_prev.name != parent
        eb_prev = eb
    bpy.ops.object.mode_set(mode="OBJECT")


def _seg_dist(p, a, b):
    ab = b - a
    t = max(0.0, min(1.0, (p - a).dot(ab) / max(ab.length_squared, 1e-12)))
    return (p - (a + ab * t)).length


def _reweight(mesh, vs, dist, cut, segs, blend_len):
    """Vertices within `cut` of the tip follow `segs` ({bone: (a, b)}, nearest two by inverse distance); the last
    `blend_len` before the cut fades back into the weights Meshy gave them."""
    groups = {g.name: g for g in mesh.vertex_groups}
    for name in segs:
        if name not in groups:
            groups[name] = mesh.vertex_groups.new(name=name)
    index = {g.index: g.name for g in mesh.vertex_groups}
    n = 0
    for i, d in dist.items():
        if d >= cut:
            continue
        t = min(1.0, (cut - d) / blend_len)
        v = mesh.data.vertices[i]
        old = {index[g.group]: g.weight for g in v.groups}
        cands = sorted((_seg_dist(vs[i], a, b), name) for name, (a, b) in segs.items())[:2]
        ws = [1.0 / (dd + 0.005) ** 4 for dd, _ in cands]
        tot = sum(ws)
        new = {name: w / tot for (_, name), w in zip(cands, ws)}
        mix = {}
        for name, w in old.items():
            mix[name] = mix.get(name, 0.0) + w * (1 - t)
        for name, w in new.items():
            mix[name] = mix.get(name, 0.0) + w * t
        top = sorted(mix.items(), key=lambda kv: -kv[1])[:4]
        tot = sum(w for _, w in top)
        for name in old:
            groups[name].remove([i])
        for name, w in top:
            if w / tot > 0.01:
                groups[name].add([i], w / tot, "REPLACE")
        n += 1
    return n


def _rotate(arm, name, axis, deg):
    """Rotate a pose bone about an axis (world directions) through its head; children follow."""
    bpy.context.view_layer.update()
    pb = arm.pose.bones[name]
    h = pb.head.copy()
    pb.matrix = Matrix.Translation(h) @ Matrix.Rotation(math.radians(deg), 4, axis) @ Matrix.Translation(-h) @ pb.matrix
    bpy.context.view_layer.update()


def _reset_pose(arm):
    for pb in arm.pose.bones:
        pb.location = (0, 0, 0)
        pb.rotation_quaternion = (1, 0, 0, 0)
        pb.rotation_euler = (0, 0, 0)
        pb.scale = (1, 1, 1)
    bpy.context.view_layer.update()


def chains(body):
    arm, mesh = _open(body)
    cfg = BODIES[body]
    arm.data.pose_position = "REST"
    if arm.animation_data:
        arm.animation_data.action = None
    bpy.context.view_layer.update()
    vs = _world_verts(mesh)
    adj = _adjacency(mesh.data, vs)
    rep = {}
    if cfg["tail"]:
        tip = _tail_tip(arm, vs, adj, cfg)

        skip = cfg.get("tail_skip", 0)     # rings of a wide tuft at the tip, left out of the widening test

        hips = _bone_world(arm, "Hips")[0]

        def typical(radii):
            body = radii[2 + skip:]
            return sorted(body)[len(body) // 2]

        def tail_stop(k, r, radii, d, c):
            # Two ways a tail ends: its centre reaches the hips (where a tail starts), or a ring opens out wider
            # than the tail has been (it ran onto the body).
            if k >= 3 and (c - hips).length < TAIL_ROOT_R:
                return True
            return k >= 6 + skip and r > typical(radii) * TAIL_WIDEN
        radii_out = []
        pts, cut, dist = _walk(vs, adj, tip, TAIL_STEP, tail_stop, 1.6, radii_out)
        # A vertex follows the tail only if it lies near the centreline: a tail lying against a leg or a seat
        # shares rings with it (Augusta's suit took part of her seat).
        girth = typical(radii_out) if len(radii_out) > 4 + skip else 0.03
        near = TAIL_NEAR * girth + 0.01
        dist = {i: d for i, d in dist.items()
                if d >= cut or min(_seg_dist(vs[i], a, b) for a, b in zip(pts, pts[1:])) <= near}
        n = cfg["tail"]
        line, length = _resample(pts, n)
        names = ["tail.%d" % (k + 1) for k in range(n)]
        _add_chain(arm, names, line, "Hips")
        segs = {name: (a, b) for name, a, b in zip(names, line, line[1:])}
        segs["Hips"] = _bone_world(arm, "Hips")
        rep["tail"] = {"tip": [round(c, 3) for c in vs[tip]], "root": [round(c, 3) for c in line[0]],
                       "length": round(length, 3), "verts": _reweight(mesh, vs, dist, cut, segs, BLEND_LEN)}
    if cfg["ears"]:
        for side, s in ((1, "L"), (-1, "R")):
            tip = _ear_tip(arm, vs, side, cfg)

            # An ear reaches EAR_FRAC of its tip's height above the head joint, along the surface (rounded ears
            # defeat any ring test: their tip already opens out like a skull).
            reach = EAR_FRAC * (vs[tip].z - _bone_world(arm, "Head")[0].z)
            pts, cut, dist = _walk(vs, adj, tip, EAR_STEP, lambda *a: False, reach)
            line = [pts[0], pts[-1]]
            _add_chain(arm, ["ear." + s], line, "Head")
            segs = {"ear." + s: (line[0], line[1]), "Head": _bone_world(arm, "Head")}
            rep["ear." + s] = {"tip": [round(c, 3) for c in vs[tip]], "length": round(cut, 3),
                               "verts": _reweight(mesh, vs, dist, cut, segs, cut * 0.5)}
    # The check: tail curled, ears flicked back, in the rest pose otherwise.
    arm.data.pose_position = "POSE"
    _reset_pose(arm)
    for k in range(cfg["tail"]):
        _rotate(arm, "tail.%d" % (k + 1), Vector((1, 0, 0)), TEST_CURL)
    if cfg["ears"]:
        _rotate(arm, "ear.L", Vector((1, 0, 0)), -30)
        _rotate(arm, "ear.R", Vector((0, 1, 0)), 30)
    nb.WIP = WIP
    nb.render_views(mesh, "chains_%s" % body, size=600)
    _reset_pose(arm)
    _save(body)
    return rep


# --- clips ----------------------------------------------------------------------------------------------------------
## Meshy gives walk and run. Idle and talk are keyed here as rotations about world axes, so they work on any of
## Meshy's rigs whatever its bone rolls. Every clip loops over LOOP frames; the tail sways and an ear twitches.
LOOP = 48                # frames (2 s at 24 fps)
ARM_DOWN = 9.0           # degrees off vertical for the arms at rest (Meshy's rest pose is an A-pose)
TAIL_SWAY = {"idle": 5.0, "talk": 6.0, "walk": 9.0, "run": 12.0}   # degrees per tail bone
X, Y, Z = Vector((1, 0, 0)), Vector((0, 1, 0)), Vector((0, 0, 1))


def _key(arm, names):
    for name in names:
        pb = arm.pose.bones[name]
        prop = "rotation_quaternion" if pb.rotation_mode == "QUATERNION" else "rotation_euler"
        pb.keyframe_insert(prop, group=name)
        pb.keyframe_insert("location", group=name)


def _arms_down(arm):
    for s, side in (("Left", 1), ("Right", -1)):
        a = _bone_world(arm, s + "Arm")[0]
        hb = arm.pose.bones[s + "Hand"]
        hand = arm.matrix_world @ hb.head
        a = arm.matrix_world @ arm.pose.bones[s + "Arm"].head
        cur = (hand - a).normalized()
        want = Vector((side * math.sin(math.radians(ARM_DOWN)), -0.04, -math.cos(math.radians(ARM_DOWN)))).normalized()
        axis, ang = cur.rotation_difference(want).to_axis_angle()
        _rotate(arm, s + "Arm", axis, math.degrees(ang))
        # A soft elbow: the forearm swings a little forward.
        _rotate(arm, s + "ForeArm", Vector((side, 0, 0)).cross(Vector((0, -1, 0))).normalized() * side, 0)
        _rotate(arm, s + "ForeArm", X, -12)


def _sway(arm, f, name, amp, ears):
    """Tail sway (a travelling wave from the root) and an ear twitch at a fixed frame, on top of the pose at `f`."""
    n = sum(1 for b in arm.pose.bones if b.name.startswith("tail."))
    ph = 2 * math.pi * f / LOOP
    for k in range(n):
        _rotate(arm, "tail.%d" % (k + 1), Z, amp * math.sin(ph - 0.7 * k))
        _rotate(arm, "tail.%d" % (k + 1), X, 0.4 * amp * math.sin(2 * ph - 0.7 * k))
    if ears:
        tw = max(0.0, 1.0 - abs(f - 30) / 4.0)
        _rotate(arm, "ear.L", X, -18 * tw)
        _rotate(arm, "ear.R", X, -10 * tw)


def _chain_bones(arm):
    return [b.name for b in arm.pose.bones if b.name.startswith(("tail.", "ear."))]


def _make_clip(arm, name, pose_fn, ears):
    act = bpy.data.actions.get(name) or bpy.data.actions.new(name)
    act.use_fake_user = True
    arm.animation_data_create()
    arm.animation_data.action = act
    every = [b.name for b in arm.pose.bones]
    for f in range(0, LOOP + 1, 4):
        bpy.context.scene.frame_set(f)
        _reset_pose(arm)
        pose_fn(arm, f)
        _sway(arm, f, name, TAIL_SWAY[name], ears)
        bpy.context.scene.frame_current = f
        for n in every:
            pb = arm.pose.bones[n]
            prop = "rotation_quaternion" if pb.rotation_mode == "QUATERNION" else "rotation_euler"
            pb.keyframe_insert(prop, frame=f, group=n)
            pb.keyframe_insert("location", frame=f, group=n)
    return act


def _idle_pose(arm, f):
    ph = 2 * math.pi * f / LOOP
    _arms_down(arm)
    _rotate(arm, "Spine01", X, 1.5 * math.sin(ph))            # breathing
    _rotate(arm, "Head", Y, 2.0 * math.sin(ph * 0.5))
    _rotate(arm, "LeftArm", Y, 1.5 * math.sin(ph))
    _rotate(arm, "RightArm", Y, -1.5 * math.sin(ph))


def _talk_pose(arm, f):
    ph = 2 * math.pi * f / LOOP
    _arms_down(arm)
    _rotate(arm, "Spine01", X, 1.5 * math.sin(ph))
    # The right hand comes up and forward, open, and beats twice a loop; the head nods with it.
    _rotate(arm, "RightArm", X, -32)
    _rotate(arm, "RightForeArm", X, -55 - 12 * math.sin(2 * ph))
    _rotate(arm, "RightHand", X, 10 * math.sin(2 * ph))
    _rotate(arm, "Head", X, 4 * math.sin(2 * ph))
    _rotate(arm, "Head", Y, 3 * math.sin(ph))


def _layer(arm, act, name, ears):
    """Add tail sway and the ear twitch to one of Meshy's clips: only the chain bones are keyed."""
    arm.animation_data.action = act
    f0, f1 = int(act.frame_range[0]), int(math.ceil(act.frame_range[1]))
    chain = _chain_bones(arm)
    span = max(1, f1 - f0)
    for f in range(f0, f1 + 1, 2):
        bpy.context.scene.frame_set(f)
        for n in chain:
            pb = arm.pose.bones[n]
            pb.rotation_quaternion = (1, 0, 0, 0)
            pb.rotation_euler = (0, 0, 0)
        g = (f - f0) * LOOP / span     # one sway cycle per Meshy loop
        n_tail = sum(1 for b in chain if b.startswith("tail."))
        ph = 2 * math.pi * g / LOOP
        for k in range(n_tail):
            _rotate(arm, "tail.%d" % (k + 1), Z, TAIL_SWAY[name] * math.sin(2 * ph - 0.7 * k))
        for n in chain:
            pb = arm.pose.bones[n]
            prop = "rotation_quaternion" if pb.rotation_mode == "QUATERNION" else "rotation_euler"
            pb.keyframe_insert(prop, frame=f, group=n)


def _set_nla(arm, names):
    ad = arm.animation_data
    for t in list(ad.nla_tracks):
        ad.nla_tracks.remove(t)
    for name in names:
        act = bpy.data.actions[name]
        tr = ad.nla_tracks.new()
        tr.name = name
        strip = tr.strips.new(name, int(act.frame_range[0]), act)
        strip.name = name
        tr.mute = False
    ad.action = None


CLIPS = ["idle", "talk", "walk", "run"]


def clip_sheet(arm, mesh, body):
    """Three frames of each clip in a row, three-quarter view: build/clips_<body>.png."""
    sc = bpy.context.scene
    tmp = os.path.join(WIP, "_cell.png")
    h = max(v.z for v in _world_verts(mesh))
    rows = []
    for name in CLIPS:
        act = bpy.data.actions[name]
        arm.animation_data.action = act
        f0, f1 = act.frame_range
        cells = []
        for k in range(3):
            sc.frame_set(int(f0 + (f1 - f0) * k / 3))
            nb.WIP = WIP
            nb.closeup(Vector((0, 0, h / 2)), Vector((0.7, -1.0, 0.15)).normalized(), h * 1.15, "_cell.png", 360)
            im = bpy.data.images.load(tmp)
            cells.append(np.array(im.pixels[:], np.float32).reshape(360, 360, 4))
            bpy.data.images.remove(im)
        rows.append(np.concatenate(cells, axis=1))
    sheet = np.concatenate(rows[::-1], axis=0)
    out = bpy.data.images.new("sheet", sheet.shape[1], sheet.shape[0], alpha=True)
    out.pixels[:] = sheet.ravel()
    out.filepath_raw = os.path.join(WIP, "clips_%s.png" % body)
    out.file_format = "PNG"
    out.save()
    bpy.data.images.remove(out)
    os.remove(tmp)


def clips(body):
    arm, mesh = _open(body)
    cfg = BODIES[body]
    arm.data.pose_position = "POSE"
    bpy.context.scene.render.fps = 24
    arm.animation_data_create()
    if arm.animation_data.nla_tracks:
        for t in list(arm.animation_data.nla_tracks):
            arm.animation_data.nla_tracks.remove(t)
    _make_clip(arm, "idle", _idle_pose, cfg["ears"])
    _make_clip(arm, "talk", _talk_pose, cfg["ears"])
    for name in ("walk", "run"):
        _layer(arm, bpy.data.actions[name], name, cfg["ears"])
    clip_sheet(arm, mesh, body)
    arm.animation_data.action = None
    _reset_pose(arm)
    _set_nla(arm, CLIPS)
    _save(body)
    return {name: [round(x, 1) for x in bpy.data.actions[name].frame_range] for name in CLIPS}


# --- measure: gridded headshots for the mask fit ---------------------------------------------------------------------
GRID_PX = 800


def _gridded(centre, d, scale, name):
    """An ortho render with a grid: thin lines every 1 cm, thick every 5 cm, a red line through each 10 cm. The
    first line of the report gives the frame so a pixel converts to metres."""
    nb.WIP = WIP
    nb.closeup(centre, d, scale, name, GRID_PX)
    path = os.path.join(WIP, name)
    im = bpy.data.images.load(path)
    px = np.array(im.pixels[:], np.float32).reshape(GRID_PX, GRID_PX, 4)
    # Screen right: +x in a front view; +y in a side view from +x (the face, at -y, is on the left).
    across = Vector((1, 0, 0)) if abs(d.y) > 0.5 else Vector((0, 1, 0)) if d.x > 0 else Vector((0, -1, 0))
    c_h = centre.dot(across)
    for axis, c0 in ((1, c_h), (0, centre.z)):
        lo = c0 - scale / 2
        for k in range(int(math.floor(lo * 100)), int(math.ceil((lo + scale) * 100)) + 1):
            p = int(round((k / 100 - lo) / scale * GRID_PX))
            if not 0 <= p < GRID_PX:
                continue
            col = (1, 0.1, 0.1) if k % 10 == 0 else (0.1, 0.3, 1.0) if k % 5 == 0 else (0.9, 0.9, 0.9)
            a = 0.9 if k % 5 == 0 else 0.35
            if axis == 1:
                px[:, p, :3] = px[:, p, :3] * (1 - a) + np.array(col) * a
            else:
                px[p, :, :3] = px[p, :, :3] * (1 - a) + np.array(col) * a
    im.pixels[:] = px.ravel()
    im.save()
    bpy.data.images.remove(im)
    return {"file": name, "h_axis": [round(c, 2) for c in across], "h_from": round(c_h - scale / 2, 3),
            "z_from": round(centre.z - scale / 2, 3), "m_per_px": scale / GRID_PX}


def measure(body):
    arm, mesh = _open(body)
    arm.data.pose_position = "REST"
    bpy.context.view_layer.update()
    head, crown = _bone_world(arm, "Head")[0], _bone_world(arm, "head_end")[0]
    vs = [v for v in _world_verts(mesh) if v.z > head.z - 0.05]
    c = Vector((0.0, (min(v.y for v in vs) + max(v.y for v in vs)) / 2, (head.z + max(v.z for v in vs)) / 2))
    s = max(max(v.z for v in vs) - head.z + 0.1, max(v.x for v in vs) - min(v.x for v in vs) + 0.06)
    return {"front": _gridded(c, Vector((0, -1, 0)), s, "measure_%s_front.png" % body),
            "side": _gridded(c, Vector((1, 0, 0)), s, "measure_%s_side.png" % body)}


def measure_mask(who):
    nb.clear()
    objs = [o for o in _import(os.path.join(RAW, "%s_mask.glb" % who)) if o.type == "MESH"]
    m = objs[0]
    vs = _world_verts(m)
    lo = Vector((min(v.x for v in vs), min(v.y for v in vs), min(v.z for v in vs)))
    hi = Vector((max(v.x for v in vs), max(v.y for v in vs), max(v.z for v in vs)))
    c = (lo + hi) / 2
    s = max(hi - lo) * 1.1
    return {"bbox": [[round(x, 3) for x in lo], [round(x, 3) for x in hi]],
            "front": _gridded(c, Vector((0, -1, 0)), s, "measure_mask_%s_front.png" % who),
            "side": _gridded(c, Vector((1, 0, 0)), s, "measure_mask_%s_side.png" % who)}


# --- mask: each sister's Meshy mask, fitted to her garb's face -------------------------------------------------------
## Measured on the gridded headshots (`-- measure`), rest pose, after `prep` centred the feet: the eyes' centre
## height and half-spacing, the nose tip's front (y) and height, the chin.
FACE = {
    "silke_garb": {"eye_z": 1.697, "eye_x": 0.060, "nose_y": -0.141, "chin": 1.585},
    "lull_garb": {"eye_z": 1.488, "eye_x": 0.059, "nose_y": -0.189, "chin": 1.378},
    "augusta_garb": {"eye_z": 1.491, "eye_x": 0.066, "nose_y": -0.185, "chin": 1.345},
    "dash_garb": {"eye_z": 1.589, "eye_x": 0.075, "nose_y": -0.150, "chin": 1.460},
    "rivet_garb": {"eye_z": 1.212, "eye_x": 0.056, "nose_y": -0.154, "chin": 1.098},
    "grizelda_garb": {"eye_z": 1.311, "eye_x": 0.078, "nose_y": -0.210, "chin": 1.180},
    "bastion_garb": {"eye_z": 1.695, "eye_x": 0.073, "nose_y": -0.223, "chin": 1.520},
}
## Measured on the masks as imported (`-- measure_mask`). Every mask scales by width, as the concepts size them:
## its face-covering part (`m_width`: no filigree, canisters or straps) spans `frac` of her face's width at the
## anchor height. The cartoon heads defeat eye-spacing and face-height rules: big heads, close eyes, tiny muzzles.
## "eyes" masks put their eye line (`m_eye_z`: holes, lens or band) on hers; "muzzle" masks hang their top edge
## (`m_top`) just under her eyes and may squash in height (never below MUZZLE_SQUASH) to end near her chin
## (`m_bot`). `m_front` is the mask's front on its centre line; `ahead` how far it stands before her nose tip.
MASK_FIT = {
    "augusta": {"anchor": "eyes", "m_width": 1.59, "frac": 1.0, "m_eye_z": 0.0, "m_front": -0.74},
    "silke": {"anchor": "eyes", "m_width": 1.355, "frac": 0.9, "squash": 0.75, "m_eye_z": 0.547,
              "m_front": -0.71},
    "dash": {"anchor": "eyes", "m_width": 1.855, "frac": 1.12, "m_eye_z": 0.047, "m_front": -0.95},
    # Rivet's head harness has a top strap that stands off as a flat plate over her tall ears: cropped.
    "rivet": {"anchor": "eyes", "m_width": 1.46, "frac": 1.0, "m_eye_z": 0.099, "m_front": -0.83, "ahead": 0.04,
              "crop_top": 0.62},
    "bastion": {"anchor": "eyes", "m_width": 1.63, "frac": 1.0, "m_eye_z": -0.128, "m_front": -0.949},
    "lull": {"anchor": "muzzle", "m_width": 1.70, "frac": 0.85, "m_top": 0.586, "m_bot": -0.602, "m_front": -0.94,
             "ahead": 0.02, "warm": 0.0},
    # Grizelda's face width is mostly cheek ruff: a smaller fraction.
    "grizelda": {"anchor": "muzzle", "m_width": 1.72, "frac": 0.6, "m_top": 0.558, "m_bot": -0.548,
                 "m_front": -0.70, "warm": 0.0},
}
MUZZLE_SQUASH = 0.75
## Deeper than Nim's: on the masks, Nim's values still read cream under the night lighting.
BRASS_LIGHT = np.array([0.95, 0.70, 0.28])
BRASS_DARK = np.array([0.40, 0.24, 0.06])
MASK_TRIS = 15000          # a mask is small on screen; body 60k + mask stays inside the 80k budget
MASK_GAP = 0.006
MASK_PUSH_R = 0.012


def _brass(m, warm=0.06):
    """Meshy paints brass cream: warm, bright, unsaturated texels become brass, keeping their brightness. `warm`
    is how much redder than blue a texel must be: Lull's spiral and Grizelda's bell came out nearly neutral white,
    while Silke's grey veil must stay grey."""
    img = _base_image(m)
    w, h = img.size
    px = np.empty(w * h * 4, np.float32)
    img.pixels.foreach_get(px)
    px = px.reshape(-1, 4)
    rgb = px[:, :3]
    lum = rgb @ np.array([0.3, 0.59, 0.11])
    sat = rgb.max(axis=1) - rgb.min(axis=1)
    cream = (lum > 0.35) & (sat < 0.3) & (rgb[:, 0] - rgb[:, 2] > warm) & (rgb[:, 0] - rgb[:, 1] < 0.12)
    t = np.clip((lum[cream] - 0.35) / 0.55, 0.0, 1.0)[:, None]
    rgb[cream] = BRASS_DARK * (1 - t) + BRASS_LIGHT * t
    px[:, :3] = rgb
    img.pixels.foreach_set(px.ravel())
    img.update()
    img.pack()
    return int(cream.sum())


def _push_out(m, body_vs, polys, cy):
    """Nim's radial push (nim_build.fit_meshy_mask): every mask vertex stays MASK_GAP off her surface, measured
    outward from the vertical axis through her head; behind her ears (the straps) it may also pull in onto her skull."""
    from mathutils.bvhtree import BVHTree
    from mathutils.kdtree import KDTree
    bvh = BVHTree.FromPolygons(body_vs, polys)
    mv = [v.co.copy() for v in m.data.vertices]
    n = len(mv)

    def radial(p):
        d = Vector((p.x, p.y - cy, 0.0))
        return d.normalized() if d.length > 1e-6 else Vector((0.0, -1.0, 0.0))
    dirs = [radial(p) for p in mv]
    need = [0.0] * n
    for i, p in enumerate(mv):
        axis = Vector((0.0, cy, p.z))
        hit, _, _, _ = bvh.ray_cast(axis + dirs[i] * 0.6, -dirs[i], 0.6)
        if hit is None:
            continue
        r_surf = Vector((hit.x, hit.y - cy, 0.0)).length
        r_now = Vector((p.x, p.y - cy, 0.0)).length
        signed = r_surf + MASK_GAP - r_now
        need[i] = signed if p.y > cy + 0.01 else max(0.0, signed)
    kd = KDTree(n)
    for i, p in enumerate(mv):
        kd.insert(p, i)
    kd.balance()
    spread = need[:]
    for i in [i for i in range(n) if need[i] > 0.0]:
        for _, j, _ in kd.find_range(mv[i], MASK_PUSH_R):
            if need[i] > spread[j]:
                spread[j] = need[i]
    adj = [[] for _ in range(n)]
    for e in m.data.edges:
        a, b = e.vertices
        adj[a].append(b)
        adj[b].append(a)
    for _ in range(20):
        spread = [(spread[i] + sum(spread[j] for j in adj[i]) / len(adj[i])) / 2 if adj[i] else spread[i]
                  for i in range(n)]
    moved = 0
    for i in range(n):
        e = max(spread[i], need[i]) if need[i] >= 0.0 else spread[i]
        if abs(e) > 1e-5:
            mv[i] = mv[i] + dirs[i] * e
            moved += 1
    for v, p in zip(m.data.vertices, mv):
        v.co = p
    m.data.update()
    return moved


def mask(body):
    cfg = BODIES[body]
    who = cfg.get("mask")
    if not who:
        return "no mask"
    if body not in FACE or who not in MASK_FIT:
        return "not measured"
    arm, mesh = _open(body)
    arm.data.pose_position = "REST"
    if arm.animation_data:
        arm.animation_data.action = None
    bpy.context.view_layer.update()
    old = bpy.data.objects.get(body + "_Mask")
    if old:
        bpy.data.objects.remove(old)
    F, M = FACE[body], MASK_FIT[who]
    new = _import(os.path.join(RAW, "%s_mask.glb" % who))
    m = next(o for o in new if o.type == "MESH")
    for o in new:
        if o is not m:
            bpy.data.objects.remove(o)
    m.parent = None
    bpy.ops.object.select_all(action="DESELECT")
    m.select_set(True)
    bpy.context.view_layer.objects.active = m
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    tris = sum(len(p.vertices) - 2 for p in m.data.polygons)
    if tris > MASK_TRIS:
        seams.decimate_safe(m, MASK_TRIS / tris)
        bpy.ops.object.modifier_apply(modifier="Decimate")
    for img in {n.image for mat in m.data.materials if mat and mat.use_nodes for n in mat.node_tree.nodes
                if n.type == "TEX_IMAGE" and n.image}:
        if img.size[0] > TEX:
            img.scale(TEX, TEX)
    m.name = body + "_Mask"
    if "crop_top" in M:
        bm = bmesh.new()
        bm.from_mesh(m.data)
        bmesh.ops.delete(bm, geom=[v for v in bm.verts if v.co.z > M["crop_top"]], context="VERTS")
        bm.to_mesh(m.data)
        bm.free()
        m.data.update()
    body_vs = _world_verts(mesh)
    az = F["eye_z"] if M["anchor"] == "eyes" else (F["eye_z"] + F["chin"]) / 2
    band = [v.x for v in body_vs if abs(v.z - az) < 0.004]
    face_w = max(band) - min(band)
    s = M["frac"] * face_w / M["m_width"]
    sz = s * M.get("squash", 1.0)
    if M["anchor"] == "eyes":
        dz = F["eye_z"] - M["m_eye_z"] * sz
    else:
        top, bot = F["eye_z"] - F.get("under_eye", 0.035), F["chin"] - 0.01
        sz = max(min(s, (top - bot) / (M["m_top"] - M["m_bot"])), MUZZLE_SQUASH * s)
        dz = top - M["m_top"] * sz
    dy = F["nose_y"] - M.get("ahead", 0.012) - M["m_front"] * s
    m.data.transform(Matrix.Diagonal((s, s, sz, 1.0)))
    m.data.transform(Matrix.Translation((0.0, dy, dz)))
    m.data.update()
    ring = [v for v in body_vs if abs(v.z - F["eye_z"]) < 0.01]
    cy = (min(v.y for v in ring) + max(v.y for v in ring)) / 2
    moved = _push_out(m, body_vs, [tuple(p.vertices) for p in mesh.data.polygons], cy)
    for p in m.data.polygons:
        p.use_smooth = True
    brass = _brass(m, M.get("warm", 0.06))
    mw = m.matrix_world.copy()
    m.parent = arm
    m.parent_type = "BONE"
    m.parent_bone = "Head"
    m.matrix_world = mw
    # Check renders: front, side, three-quarter of the head.
    head = _bone_world(arm, "Head")[0]
    c = Vector((0.0, cy, F["eye_z"] - 0.02))
    nb.WIP = WIP
    for tag, d in (("front", Vector((0, -1, 0))), ("side", Vector((1, 0, 0))),
                   ("three", Vector((0.7, -1.0, 0.15)).normalized())):
        nb.closeup(c, d, 0.42, "mask_%s_%s.png" % (body, tag), 600)
    arm.data.pose_position = "POSE"
    _save(body)
    return {"scale": [round(s, 3), round(sz, 3)], "face_w": round(face_w, 3),
            "tris": sum(len(p.vertices) - 2 for p in m.data.polygons), "pushed": moved,
            "brass_px": brass}


# --- seams and export -----------------------------------------------------------------------------------------------
def seam_fix(body):
    arm, mesh = _open(body)
    arm.data.pose_position = "REST"
    rep = {}
    for o in (mesh, bpy.data.objects.get(body + "_Mask")):
        if o is None:
            continue
        imgs = {n.image for mat in o.data.materials if mat and mat.use_nodes
                for n in mat.node_tree.nodes if n.type == "TEX_IMAGE" and n.image}
        cov = seams.coverage(o, next(iter(imgs)))
        for img in imgs:
            filled, edge = seams.pad(img, cov)
            img.pack()
            rep["%s/%s" % (o.name, img.name)] = filled
    arm.data.pose_position = "POSE"
    _save(body)
    return rep


def export(body):
    arm, mesh = _open(body)
    who = _who(body)
    folder = os.path.join(OUT, who)
    os.makedirs(folder, exist_ok=True)
    _set_nla(arm, CLIPS)
    for o in bpy.context.scene.objects:
        o.select_set(o in (arm, mesh) or o.name == body + "_Mask")
    bpy.context.view_layer.objects.active = arm
    name = "swyne" if body == "swyne" else body
    path = os.path.join(folder, "%s.glb" % name)
    bpy.ops.export_scene.gltf(filepath=path, export_format="GLB", use_selection=True, export_animations=True,
                              export_animation_mode="NLA_TRACKS", export_skins=True, export_morph=False,
                              export_yup=True, export_apply=False, export_force_sampling=True,
                              export_image_format="AUTO")
    return round(os.path.getsize(path) / 1e6, 1)


# --- main -----------------------------------------------------------------------------------------------------------
STAGES = {"prep": prep, "chains": chains, "clips": clips, "measure": measure, "measure_mask": measure_mask,
          "mask": mask, "seams": seam_fix, "export": export}
MASKS = ["augusta", "silke", "dash", "rivet", "lull", "grizelda", "bastion"]


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    stage = argv[0] if argv else "prep"
    default = MASKS if stage == "measure_mask" else list(BODIES)
    bodies = argv[1:] or default
    report = {}
    for body in bodies:
        report[body] = STAGES[stage](body)
        print("CAST", stage, body, report[body], flush=True)


if __name__ == "__main__":
    main()
