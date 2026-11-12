"""Nim's model pipeline (WO-011, ART_DIRECTION.md "The hero"), run headless in Blender, stage by stage:

    blender -b --python tools/nim_build.py -- inspect     renders of the raw Meshy models (front, side, back) + stats
    blender -b --python tools/nim_build.py -- clean [garb|suit]   scale, voxel remesh, decimate, unwrap, bake 4K
    blender -b --python tools/nim_build.py -- rig [garb|suit]     skeleton from the mesh + overlay renders
    blender -b --python tools/nim_build.py -- weights [garb|suit] skin it + a test-pose render
    (later stages: poses, export)

Sources: .wip/nim/raw/nim_garb.glb and nim_suit.glb (Meshy multi-image, task ids in .wip/meshy/wo011_nim.json).
Work files and renders: .wip/nim/. Blender's -Y is her front (Godot +Z), +Z up.
"""
import heapq
import math
import os
import sys

import bmesh
import bpy
import numpy as np
from mathutils import Matrix, Vector

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
WIP = os.path.join(ROOT, ".wip", "nim")
RAW = os.path.join(WIP, "raw")
OUTFITS = ["garb", "suit"]


def clear():
    if bpy.context.object and bpy.context.object.mode != "OBJECT":
        bpy.ops.object.mode_set(mode="OBJECT")
    for coll in (bpy.data.objects, bpy.data.meshes, bpy.data.materials, bpy.data.cameras, bpy.data.lights,
                 bpy.data.armatures, bpy.data.actions):
        for item in list(coll):
            coll.remove(item)
    for im in list(bpy.data.images):
        bpy.data.images.remove(im)


def import_raw(outfit):
    """The raw Meshy GLB as one mesh object named Nim_<outfit>_raw, transforms applied."""
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=os.path.join(RAW, "nim_%s.glb" % outfit))
    new = [o for o in bpy.data.objects if o not in before]
    meshes = [o for o in new if o.type == "MESH"]
    bpy.ops.object.select_all(action="DESELECT")
    for m in meshes:
        m.select_set(True)
    bpy.context.view_layer.objects.active = meshes[0]
    bpy.ops.object.parent_clear(type="CLEAR_KEEP_TRANSFORM")
    for o in new:
        if o.type != "MESH":
            bpy.data.objects.remove(o)
    if len(meshes) > 1:
        bpy.ops.object.join()
    obj = bpy.context.active_object
    obj.name = "Nim_%s_raw" % outfit
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    return obj


def stats(obj):
    vs = [v.co for v in obj.data.vertices]
    lo = Vector((min(v.x for v in vs), min(v.y for v in vs), min(v.z for v in vs)))
    hi = Vector((max(v.x for v in vs), max(v.y for v in vs), max(v.z for v in vs)))
    tris = sum(len(p.vertices) - 2 for p in obj.data.polygons)
    return {"tris": tris, "verts": len(vs), "min": [round(c, 3) for c in lo], "max": [round(c, 3) for c in hi],
            "materials": len(obj.data.materials)}


def render_views(obj, prefix, size=900):
    """Front, side (her right) and back, orthographic, flat grey ground."""
    sc = bpy.context.scene
    sc.render.engine = "BLENDER_EEVEE"
    sc.render.resolution_x = size
    sc.render.resolution_y = size
    world = sc.world or bpy.data.worlds.new("w")
    sc.world = world
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs["Color"].default_value = (0.55, 0.53, 0.5, 1)
    world.node_tree.nodes["Background"].inputs["Strength"].default_value = 1.0
    vs = [obj.matrix_world @ v.co for v in obj.data.vertices]
    lo = Vector((min(v.x for v in vs), min(v.y for v in vs), min(v.z for v in vs)))
    hi = Vector((max(v.x for v in vs), max(v.y for v in vs), max(v.z for v in vs)))
    mid = (lo + hi) / 2
    span = max(hi - lo) * 1.1
    cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
    cam.data.type = "ORTHO"
    cam.data.ortho_scale = span
    sc.collection.objects.link(cam)
    sc.camera = cam
    sun = bpy.data.objects.new("sun", bpy.data.lights.new("sun", "SUN"))
    sun.data.energy = 2.5
    sc.collection.objects.link(sun)
    out = []
    for name, d in (("front", Vector((0, -1, 0))), ("side", Vector((1, 0, 0))), ("back", Vector((0, 1, 0)))):
        cam.location = mid + d * span * 2
        cam.rotation_euler = (-d).to_track_quat("-Z", "Y").to_euler()
        sun.rotation_euler = (-d + Vector((0, 0, -0.6))).to_track_quat("-Z", "Z").to_euler()
        sc.render.filepath = os.path.join(WIP, "%s_%s.png" % (prefix, name))
        bpy.ops.render.render(write_still=True)
        out.append(sc.render.filepath)
    bpy.data.objects.remove(cam)
    bpy.data.objects.remove(sun)
    return out


# --- clean: scale, remesh, decimate, unwrap, bake -------------------------------------------------------------------
## Her height, feet to ear tips (an upright adult, about seven heads; her capsule in game is 1.7 m).
HEIGHT = 1.8
## The Nine Lives recipe: a voxel remesh first (Meshy's raw mesh folds into blotches if collapsed directly), then a
## collapse to the hero budget (100-130k triangles).
VOXEL = 0.0035
TARGET_TRIS = 120000
TEX = 4096


def scale_to_height(obj):
    vs = [v.co for v in obj.data.vertices]
    h = max(v.z for v in vs) - min(v.z for v in vs)
    obj.data.transform(Matrix.Scale(HEIGHT / h, 4))
    vs = [v.co for v in obj.data.vertices]
    shift = Vector(((min(v.x for v in vs) + max(v.x for v in vs)) / -2,
                    (min(v.y for v in vs) + max(v.y for v in vs)) / -2, -min(v.z for v in vs)))
    obj.data.transform(Matrix.Translation(shift))
    obj.data.update()


def make_low(src, outfit):
    """A copy of the source, voxel-remeshed and collapsed to the budget, with fresh smart-projected UVs."""
    bpy.ops.object.select_all(action="DESELECT")
    src.select_set(True)
    bpy.context.view_layer.objects.active = src
    bpy.ops.object.duplicate()
    low = bpy.context.active_object
    low.name = low.data.name = "Nim_%s" % outfit
    low.data.materials.clear()
    rem = low.modifiers.new("remesh", "REMESH")
    rem.mode = "VOXEL"
    rem.voxel_size = VOXEL
    rem.use_smooth_shade = True
    bpy.ops.object.modifier_apply(modifier=rem.name)
    tris = sum(len(p.vertices) - 2 for p in low.data.polygons)
    dec = low.modifiers.new("decimate", "DECIMATE")
    dec.ratio = min(1.0, TARGET_TRIS / max(tris, 1))
    bpy.ops.object.modifier_apply(modifier=dec.name)
    bpy.ops.object.shade_smooth()
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.uv.smart_project(angle_limit=math.radians(66), island_margin=0.003)
    bpy.ops.object.mode_set(mode="OBJECT")
    return low, tris


def bake(src, low, outfit):
    """Colour and normals from the source onto the low mesh's new UVs (Cycles, selected to active)."""
    sc = bpy.context.scene
    sc.render.engine = "CYCLES"
    sc.cycles.samples = 1
    sc.cycles.device = "CPU"
    images = {}
    mat = bpy.data.materials.new("Nim_%s" % outfit)
    mat.use_nodes = True
    nt = mat.node_tree
    bsdf = nt.nodes["Principled BSDF"]
    for kind in ("color", "normal"):
        img = bpy.data.images.new("nim_%s_%s" % (outfit, kind), TEX, TEX, alpha=False)
        if kind == "normal":
            img.colorspace_settings.name = "Non-Color"
        images[kind] = img
    low.data.materials.append(mat)
    tex_node = nt.nodes.new("ShaderNodeTexImage")
    for kind in ("color", "normal"):
        tex_node.image = images[kind]
        nt.nodes.active = tex_node
        bpy.ops.object.select_all(action="DESELECT")
        src.select_set(True)
        low.select_set(True)
        bpy.context.view_layer.objects.active = low
        if kind == "color":
            sc.render.bake.use_pass_direct = False
            sc.render.bake.use_pass_indirect = False
            sc.render.bake.use_pass_color = True
            bpy.ops.object.bake(type="DIFFUSE", use_selected_to_active=True, cage_extrusion=0.01, max_ray_distance=0.03,
                                margin=8)
        else:
            bpy.ops.object.bake(type="NORMAL", use_selected_to_active=True, cage_extrusion=0.01, max_ray_distance=0.03,
                                margin=8)
        path = os.path.join(WIP, "nim_%s_%s.png" % (outfit, kind))
        images[kind].filepath_raw = path
        images[kind].file_format = "PNG"
        images[kind].save()
    # Wire the bakes into the low mesh's own material.
    nt.nodes.remove(tex_node)
    col = nt.nodes.new("ShaderNodeTexImage")
    col.image = images["color"]
    nt.links.new(col.outputs["Color"], bsdf.inputs["Base Color"])
    nrm = nt.nodes.new("ShaderNodeTexImage")
    nrm.image = images["normal"]
    nmap = nt.nodes.new("ShaderNodeNormalMap")
    nt.links.new(nrm.outputs["Color"], nmap.inputs["Color"])
    nt.links.new(nmap.outputs["Normal"], bsdf.inputs["Normal"])
    bsdf.inputs["Roughness"].default_value = 0.85
    return images


def clean(outfits=None):
    os.makedirs(WIP, exist_ok=True)
    report = {}
    for outfit in outfits or OUTFITS:
        clear()
        src = import_raw(outfit)
        scale_to_height(src)
        low, remeshed = make_low(src, outfit)
        bake(src, low, outfit)
        report[outfit] = {"remeshed_tris": remeshed, **stats(low)}
        bpy.data.objects.remove(src)
        render_views(low, "low_%s" % outfit)
        bpy.ops.wm.save_as_mainfile(filepath=os.path.join(WIP, "nim_%s.blend" % outfit))
    print("NIM", report)


def inspect():
    os.makedirs(WIP, exist_ok=True)
    report = {}
    for outfit in OUTFITS:
        clear()
        obj = import_raw(outfit)
        report[outfit] = stats(obj)
        render_views(obj, "raw_%s" % outfit)
    print("NIM", report)


# --- rig: landmarks from the mesh, then the skeleton -----------------------------------------------------------------
## Her stature to the crown (the ears stand above it), for the proportions that measuring can't settle.
STATURE = 1.76
## A-pose landmarks as fractions of her stature, refined by measuring the mesh where it can. Measured off the cartoon
## restyle's front render (owner, 2026-11-11: about 4.5 heads, so the head starts low, at 0.79 of her height).
## The seven-head sculpt's were ankle .055, knee .285, hip .52, spine .60, chest .70, shoulder .815, neck .845, head .885.
PROPORTION = {"ankle": 0.051, "knee": 0.25, "hip": 0.466, "spine": 0.557, "chest": 0.653, "shoulder": 0.739,
              "neck": 0.756, "head": 0.79, "crown": 1.0}
SHOULDER_X = 0.17
HAND_LEN = 0.14
TAIL_BONES = 7


def _verts(obj):
    return [obj.matrix_world @ v.co for v in obj.data.vertices]


def _centre(points):
    if not points:
        return None
    s = Vector((0, 0, 0))
    for p in points:
        s += p
    return s / len(points)


def landmarks(obj):
    """Joint positions for this outfit's mesh, in metres (Blender: +X her left, -Y her front, +Z up)."""
    vs = _verts(obj)
    z = {k: f * STATURE for k, f in PROPORTION.items()}
    L = {}

    def torso_y(at_z, band=0.03):
        pts = [v for v in vs if abs(v.z - at_z) < band and abs(v.x) < 0.12 and v.y < 0.12]
        c = _centre(pts)
        return c.y if c else 0.0

    # The tail first: its vertices must stay out of the leg sampling (a tail hangs right beside her shins).
    L["tail"] = tail_curve(obj, vs, L)
    tail = L["tail_verts"]
    for side, sx in (("L", 1.0), ("R", -1.0)):
        leg = [v for i, v in enumerate(vs) if z["ankle"] < v.z < z["knee"] and v.x * sx > 0.02 and abs(v.x) < 0.4
               and v.y < 0.15 and i not in tail]
        c = _centre(leg)
        lx = c.x if c else sx * 0.1
        ly = c.y if c else 0.0
        # The hip joint sits a little inside the knee: cartoon legs stand apart, so measure, don't assume.
        L["hip." + side] = Vector((lx * 0.85, torso_y(z["hip"]), z["hip"]))
        L["knee." + side] = Vector((lx, ly - 0.015, z["knee"]))
        L["ankle." + side] = Vector((lx, ly + 0.01, z["ankle"]))
        toes = [v for v in vs if v.z < 0.06 and v.x * sx > 0.02 and abs(v.x - lx) < 0.12]
        tip = min(toes, key=lambda v: v.y) if toes else Vector((lx, -0.18, 0.02))
        L["toe_tip." + side] = Vector((lx, tip.y, 0.02))
        L["ball." + side] = L["ankle." + side].lerp(L["toe_tip." + side], 0.68)
        L["ball." + side].z = 0.035
        # Arms: the fingertip is the furthest point out; the wrist a hand's length back toward the shoulder.
        sh = Vector((sx * SHOULDER_X, torso_y(z["shoulder"]), z["shoulder"]))
        # Only at hand height: a curled tail can reach further out than her fingers.
        out = max((v for v in vs if v.x * sx > 0 and z["hip"] - 0.15 < v.z < z["shoulder"]), key=lambda v: v.x * sx)
        wrist = out + (sh - out).normalized() * HAND_LEN
        elbow = sh.lerp(wrist, 0.5) + Vector((0, 0.025, 0))
        L["clavicle." + side] = Vector((sx * 0.025, sh.y - 0.01, z["shoulder"] - 0.02))
        L["shoulder." + side] = sh
        L["elbow." + side] = elbow
        L["wrist." + side] = wrist
        L["finger_tip." + side] = out
        # Ears: the highest point on each side of the head.
        ear = max((v for v in vs if v.x * sx > 0.03 and v.z > z["head"]), key=lambda v: v.z)
        L["ear_tip." + side] = ear
        L["ear_base." + side] = Vector((ear.x * 0.75, ear.y + 0.01, ear.z - 0.075))
    for k in ("hip", "spine", "chest", "neck", "head"):
        L[k] = Vector((0.0, torso_y(z[k]), z[k]))
    L["crown"] = Vector((0.0, L["head"].y, z["crown"]))
    return L


def recentre(obj):
    """Put her midline on x = 0. The clean stage centres the bounding box, but a tail swept out to one side drags the
    box. The head is symmetric, so its centre is her midline."""
    vs = [v.co for v in obj.data.vertices]
    head = [v for v in vs if PROPORTION["head"] * STATURE < v.z < STATURE]
    dx = -sum(v.x for v in head) / len(head)
    if abs(dx) > 0.002:
        obj.data.transform(Matrix.Translation((dx, 0.0, 0.0)))
        obj.data.update()
    return round(dx, 3)


## Roughly where each outfit's tail tip is (x, z), read off the inspect renders. The script snaps it to the mesh.
TAIL_TIP = {"Nim_garb": (0.56, 0.31), "Nim_suit": (0.53, 0.43)}   # cartoon restyle: tails sweep out to her left
TAIL_RING = 0.025      # geodesic step between tail cross-sections
TAIL_WIDEN = 1.6       # a cross-section this much wider than the tail so far is her body


_ADJ = {}


def _geodesic(obj, vs, start):
    """Distance along the surface from vertex `start` to every vertex (Dijkstra over the edges)."""
    adj = _ADJ.get(obj.name)
    if adj is None or len(adj) != len(vs):
        adj = [[] for _ in vs]
        for e in obj.data.edges:
            a, b = e.vertices
            w = (vs[a] - vs[b]).length
            adj[a].append((b, w))
            adj[b].append((a, w))
        _ADJ[obj.name] = adj
    dist = [float("inf")] * len(vs)
    dist[start] = 0.0
    heap = [(0.0, start)]
    while heap:
        d, i = heapq.heappop(heap)
        if d > dist[i]:
            continue
        for j, w in adj[i]:
            nd = d + w
            if nd < dist[j]:
                dist[j] = nd
                heapq.heappush(heap, (nd, j))
    return dist


def tail_curve(obj, vs, L):
    """The tail's centreline, walked from the tip: the vertices at each geodesic distance from the tip form a ring
    around the tail, and the ring's centre is a point on the line. The walk stops where the rings widen into her body.
    Works however the tail curls. TAIL_BONES + 1 points, root first."""
    hx, hz = TAIL_TIP[obj.name]
    near = [i for i, v in enumerate(vs) if (v.x - hx) ** 2 + (v.z - hz) ** 2 < 0.2 ** 2 and v.y > -0.05]
    # The true tip is the nearby vertex furthest along the surface from her head.
    head = max(range(len(vs)), key=lambda i: vs[i].z if abs(vs[i].x) < 0.03 else -1)
    from_head = _geodesic(obj, vs, head)
    tip = max((i for i in near if from_head[i] < 10.0), key=lambda i: from_head[i])
    dist = _geodesic(obj, vs, tip)
    rings = {}
    for i, d in enumerate(dist):
        if d < 2.0:
            rings.setdefault(int(d / TAIL_RING), []).append(vs[i])
    pts = [vs[tip].copy()]
    radii = []
    cut = 0.0
    for k in sorted(rings):
        c = _centre(rings[k])
        r = sum((v - c).length for v in rings[k]) / len(rings[k])
        if k >= 6:
            typical = sorted(radii[3:])[len(radii[3:]) // 2]
            if r > typical * TAIL_WIDEN:
                break
        radii.append(r)
        pts.append(c)
        cut = (k + 1) * TAIL_RING
    pts.reverse()
    # The tail's own vertices, for the weights: everything up the surface from the tip to where it meets her body.
    L["tail_verts"] = {i for i, d in enumerate(dist) if d < cut}
    # Resample to evenly spaced points along the marched line.
    lengths = [0.0]
    for a, b in zip(pts, pts[1:]):
        lengths.append(lengths[-1] + (b - a).length)
    total = lengths[-1]
    out = []
    for i in range(TAIL_BONES + 1):
        s = total * i / TAIL_BONES
        j = max(k for k in range(len(lengths)) if lengths[k] <= s + 1e-9)
        j = min(j, len(pts) - 2)
        f = 0.0 if lengths[j + 1] == lengths[j] else (s - lengths[j]) / (lengths[j + 1] - lengths[j])
        out.append(pts[j].lerp(pts[j + 1], min(max(f, 0.0), 1.0)))
    return out


## The skeleton: name, parent, head landmark, tail landmark (all bones deform).
def bone_specs(L):
    b = [("root", None, Vector((0, 0, 0)), Vector((0, 0, 0.2))),
         ("hips", "root", L["hip"], L["spine"]),
         ("spine", "hips", L["spine"], L["chest"]),
         ("chest", "spine", L["chest"], L["neck"]),
         ("neck", "chest", L["neck"], L["head"]),
         ("head", "neck", L["head"], L["crown"])]
    for s in ("L", "R"):
        b += [("thigh." + s, "hips", L["hip." + s], L["knee." + s]),
              ("shin." + s, "thigh." + s, L["knee." + s], L["ankle." + s]),
              ("foot." + s, "shin." + s, L["ankle." + s], L["ball." + s]),
              ("toe." + s, "foot." + s, L["ball." + s], L["toe_tip." + s]),
              ("shoulder." + s, "chest", L["clavicle." + s], L["shoulder." + s]),
              ("upper_arm." + s, "shoulder." + s, L["shoulder." + s], L["elbow." + s]),
              ("forearm." + s, "upper_arm." + s, L["elbow." + s], L["wrist." + s]),
              ("hand." + s, "forearm." + s, L["wrist." + s], L["finger_tip." + s]),
              ("ear." + s, "head", L["ear_base." + s], L["ear_tip." + s])]
    tail = L["tail"]
    for i in range(TAIL_BONES):
        b.append(("tail.%d" % (i + 1), "hips" if i == 0 else "tail.%d" % i, tail[i], tail[i + 1]))
    return b


def build_armature(obj, outfit):
    L = landmarks(obj)
    arm = bpy.data.armatures.new("Nim_%s_Rig" % outfit)
    rig = bpy.data.objects.new("Nim_%s_Rig" % outfit, arm)
    bpy.context.scene.collection.objects.link(rig)
    bpy.context.view_layer.objects.active = rig
    bpy.ops.object.mode_set(mode="EDIT")
    for name, parent, head, tail in bone_specs(L):
        eb = arm.edit_bones.new(name)
        eb.head = head
        eb.tail = tail if (tail - head).length > 0.005 else head + Vector((0, 0, 0.02))
        if parent:
            eb.parent = arm.edit_bones[parent]
            eb.use_connect = False
        # Roll: limbs and spine face her front (-Y), so a bend about local X is a forward bend.
        eb.align_roll(Vector((0, -1, 0)) if abs((eb.tail - eb.head).normalized().y) < 0.9 else Vector((0, 0, 1)))
    bpy.ops.object.mode_set(mode="OBJECT")
    return rig, L


def overlay(obj, rig, prefix):
    """Renders of the mesh, see-through, with the bones as red rods: the check that the landmarks sit right."""
    rods = []
    red = bpy.data.materials.new("rod")
    red.use_nodes = True
    em = red.node_tree.nodes.new("ShaderNodeEmission")
    em.inputs["Color"].default_value = (1, 0.1, 0.1, 1)
    em.inputs["Strength"].default_value = 3.0
    red.node_tree.links.new(em.outputs[0], red.node_tree.nodes["Material Output"].inputs["Surface"])
    for bone in rig.data.bones:
        h = rig.matrix_world @ bone.head_local
        t = rig.matrix_world @ bone.tail_local
        bpy.ops.mesh.primitive_cylinder_add(radius=0.006, depth=(t - h).length, location=(h + t) / 2, vertices=6)
        rod = bpy.context.active_object
        rod.rotation_euler = Vector((0, 0, 1)).rotation_difference(t - h).to_euler()
        rod.data.materials.append(red)
        rods.append(rod)
    mat = obj.data.materials[0]
    mat.blend_method = "BLEND" if hasattr(mat, "blend_method") else None
    bsdf = mat.node_tree.nodes["Principled BSDF"]
    bsdf.inputs["Alpha"].default_value = 0.35
    try:
        mat.surface_render_method = "BLENDED"
    except AttributeError:
        pass
    render_views(obj, prefix)
    bsdf.inputs["Alpha"].default_value = 1.0
    try:
        mat.surface_render_method = "DITHERED"
    except AttributeError:
        pass
    for r in rods:
        bpy.data.objects.remove(r)


def rig(outfits=None):
    report = {}
    for outfit in outfits or OUTFITS:
        bpy.ops.wm.open_mainfile(filepath=os.path.join(WIP, "nim_%s.blend" % outfit))
        obj = bpy.data.objects["Nim_%s" % outfit]
        for o in [o for o in bpy.data.objects if o.type == "ARMATURE"]:
            bpy.data.objects.remove(o)
        shift = recentre(obj)
        rig_obj, L = build_armature(obj, outfit)
        report[outfit] = {"shift_x": shift, "bones": len(rig_obj.data.bones), "tail_len": round(sum(
            (b - a).length for a, b in zip(L["tail"], L["tail"][1:])), 3),
            "hand_L": [round(c, 3) for c in L["wrist.L"]], "toe_L": [round(c, 3) for c in L["toe_tip.L"]]}
        overlay(obj, rig_obj, "rig_%s" % outfit)
        bpy.ops.wm.save_as_mainfile(filepath=os.path.join(WIP, "nim_%s.blend" % outfit))
    print("NIM", report)


# --- weights: distance to bone, inside regions found along the surface ----------------------------------------------
## Bone heat fails on Meshy meshes (Nine Lives), so each vertex takes weight from the bones nearest it, but only from
## bones its region allows. The regions come from distance along the surface, so a waist beside a hanging elbow never
## follows the arm: the surface path from the fingers to the waist runs round through the armpit.
ARM_REACH = 0.08       # beyond the fingertip-to-shoulder length, along the surface, still counts as arm
WEIGHT_POWER = 4.0
MAX_INFLUENCE = 4


def _seg_dist(p, a, b):
    ab = b - a
    t = max(0.0, min(1.0, (p - a).dot(ab) / max(ab.length_squared, 1e-12)))
    return (p - (a + ab * t)).length


def _allowed_bones(i, v, L, regions):
    """The bones vertex i may follow."""
    if i in L["tail_verts"]:
        return ["hips"] + ["tail.%d" % (k + 1) for k in range(TAIL_BONES)]
    for s in ("L", "R"):
        if i in regions["arm." + s]:
            return ["chest", "shoulder." + s, "upper_arm." + s, "forearm." + s, "hand." + s]
    if v.z > L["neck"].z - 0.03:
        bones = ["chest", "neck", "head"]
        for s, sx in (("L", 1.0), ("R", -1.0)):
            if v.x * sx > 0.02 and v.z > L["ear_base." + s].z - 0.015:
                bones.append("ear." + s)
        return bones
    if v.z < L["hip"].z + 0.03:
        # The leg it's nearer along the surface: a strap or cuff that crosses the midline still belongs to its leg.
        dl, dr = regions["toe.L"][i], regions["toe.R"][i]
        s = ("L" if v.x >= 0 else "R") if dl == dr else ("L" if dl < dr else "R")
        return ["hips", "spine", "thigh." + s, "shin." + s, "foot." + s, "toe." + s]
    return ["hips", "spine", "chest", "neck", "shoulder.L", "shoulder.R"]


def skin(obj, rig_obj, L):
    vs = _verts(obj)
    regions = {}
    for s in ("L", "R"):
        tip = min(range(len(vs)), key=lambda i: (vs[i] - L["finger_tip." + s]).length)
        reach = sum((L[b + "." + s] - L[a + "." + s]).length for a, b in
                    (("shoulder", "elbow"), ("elbow", "wrist"), ("wrist", "finger_tip"))) + ARM_REACH
        d = _geodesic(obj, vs, tip)
        regions["arm." + s] = {i for i, x in enumerate(d) if x < reach and i not in L["tail_verts"]}
        toe = min(range(len(vs)), key=lambda i: (vs[i] - L["toe_tip." + s]).length)
        regions["toe." + s] = _geodesic(obj, vs, toe)
    segs = {b.name: (rig_obj.matrix_world @ b.head_local, rig_obj.matrix_world @ b.tail_local)
            for b in rig_obj.data.bones}
    obj.vertex_groups.clear()
    groups = {name: obj.vertex_groups.new(name=name) for name in segs}
    for i, v in enumerate(vs):
        cands = []
        for name in _allowed_bones(i, v, L, regions):
            a, b = segs[name]
            cands.append((_seg_dist(v, a, b), name))
        cands.sort()
        cands = cands[:3]
        ws = [1.0 / (d + 0.01) ** WEIGHT_POWER for d, _ in cands]
        tot = sum(ws)
        for (d, name), w in zip(cands, ws):
            if w / tot > 0.02:
                groups[name].add([i], w / tot, "REPLACE")
    # Smooth across each joint, then tidy: at most four bones a vertex (Godot's limit), weights summing to one.
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.mode_set(mode="WEIGHT_PAINT")
    bpy.ops.object.vertex_group_smooth(group_select_mode="ALL", factor=0.5, repeat=4, expand=0.0)
    bpy.ops.object.vertex_group_limit_total(group_select_mode="ALL", limit=MAX_INFLUENCE)
    bpy.ops.object.vertex_group_normalize_all(group_select_mode="ALL", lock_active=False)
    bpy.ops.object.mode_set(mode="OBJECT")
    for m in [m for m in obj.modifiers if m.type == "ARMATURE"]:
        obj.modifiers.remove(m)
    mod = obj.modifiers.new("Armature", "ARMATURE")
    mod.object = rig_obj
    obj.parent = rig_obj
    unweighted = sum(1 for v in obj.data.vertices if not v.groups)
    return {"arm_L": len(regions["arm.L"]), "arm_R": len(regions["arm.R"]), "tail": len(L["tail_verts"]),
            "unweighted": unweighted}


## A test pose that bends every joint the clips will: arms down and bent, a knee up, head turned, the tail curled.
TEST_POSE = {"upper_arm.L": (0, 0, -45), "upper_arm.R": (0, 0, 45), "forearm.L": (70, 0, 0), "forearm.R": (70, 0, 0),
             "thigh.L": (60, 0, 0), "shin.L": (80, 0, 0), "foot.R": (25, 0, 0), "spine": (0, 20, 0),
             "head": (0, 30, 15), "ear.L": (30, 0, 0)}


def test_pose(rig_obj, on=True):
    for pb in rig_obj.pose.bones:
        pb.rotation_mode = "XYZ"
        pb.rotation_euler = (0, 0, 0)
        if on:
            if pb.name in TEST_POSE:
                pb.rotation_euler = [math.radians(a) for a in TEST_POSE[pb.name]]
            elif pb.name.startswith("tail."):
                pb.rotation_euler = (math.radians(18), 0, 0)
    bpy.context.view_layer.update()


## Head close-ups: orthographic, so a pixel (px, py) is x = (px - 450) / PX_PER_M (front), y = HEAD_FRAME y + (px - 450) /
## PX_PER_M (side, her front to the left), and
## z = HEAD_FRAME z - (py - 450) / PX_PER_M. Used to measure the eyes, brows and mouth for the face keys.
HEAD_FRAME = (-0.07, 1.58, 0.5)     # y centre (x is 0), z centre, ortho scale (metres across): the cartoon head
PX_PER_M = 900 / HEAD_FRAME[2]


def headshots(outfits=None, key=None):
    """head_<outfit>_front/side.png; with `key`, that shape key at full strength (head_<outfit>_<key>_...)."""
    for outfit in outfits or OUTFITS:
        bpy.ops.wm.open_mainfile(filepath=os.path.join(WIP, "nim_%s.blend" % outfit))
        tag = outfit
        if key:
            bpy.data.objects["Nim_%s" % outfit].data.shape_keys.key_blocks[key].value = 1.0
            tag = "%s_%s" % (outfit, key)
        sc = bpy.context.scene
        sc.render.engine = "BLENDER_EEVEE"
        sc.render.resolution_x = sc.render.resolution_y = 900
        cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
        cam.data.type = "ORTHO"
        cam.data.ortho_scale = HEAD_FRAME[2]
        sc.collection.objects.link(cam)
        sc.camera = cam
        sun = bpy.data.objects.new("sun", bpy.data.lights.new("sun", "SUN"))
        sun.data.energy = 2.5
        sc.collection.objects.link(sun)
        for name, d in (("front", Vector((0, -1, 0))), ("side", Vector((1, 0, 0)))):
            cam.location = Vector((0, HEAD_FRAME[0], HEAD_FRAME[1])) + d * 2.0
            cam.rotation_euler = (-d).to_track_quat("-Z", "Y").to_euler()
            sun.rotation_euler = (-d + Vector((0, 0, -0.6))).to_track_quat("-Z", "Z").to_euler()
            sc.render.filepath = os.path.join(WIP, "head_%s_%s.png" % (tag, name))
            bpy.ops.render.render(write_still=True)


# --- face: shape keys that slide her own sculpted lids, brows and chin (ported from Nine Lives' kiara_face.py) ------
## Measured per outfit from head_<outfit>_front/side.png (each Meshy head is its own sculpt). Eyes: centre x and
## half-width; the lid line top and bottom (z); the brow band (z); the face depth that may move (y, her front is -Y);
## the mouth line (z) and half-width; the chin's bottom; the jaw's hinge (y, z).
## Cartoon restyle (2026-11-11), re-measured after `rig` recentred the meshes (HEAD_FRAME: 1800 px/m).
FACE = {
    "garb": {"eyes": {"L": (0.111, 0.056), "R": (-0.117, 0.060)}, "eye_top": 1.586, "eye_bottom": 1.533,
             "brow": (1.645, 1.678), "face_y": (-0.40, -0.17), "mouth_z": 1.441, "mouth_half": 0.060,
             "chin": 1.391, "hinge": (-0.22, 1.451)},
    "suit": {"eyes": {"L": (0.100, 0.049), "R": (-0.103, 0.051)}, "eye_top": 1.597, "eye_bottom": 1.541,
             "brow": (1.650, 1.682), "face_y": (-0.36, -0.12), "mouth_z": 1.452, "mouth_half": 0.065,
             "chin": 1.408, "hinge": (-0.17, 1.462)},
}
LID = 0.035        # the fur above the lid line that slides down with it (the cartoon eyes are twice the size)
BROW = 0.018       # how far a brow travels: big, so it reads masked at gameplay distance (owner: strong brows)


def _smooth(e0, e1, x):
    t = np.clip((x - e0) / (e1 - e0), 0.0, 1.0)
    return t * t * (3 - 2 * t)


def _coords(me):
    co = np.empty(len(me.vertices) * 3, np.float32)
    me.vertices.foreach_get("co", co)
    return co.reshape(-1, 3)


def _face_mask(co, F):
    return (co[:, 1] > F["face_y"][0]) & (co[:, 1] < F["face_y"][1])


def _blink(co, F, side, amount=1.0):
    """The upper lid slides down and the eye folds into a line just under its lower edge."""
    x0, a = F["eyes"][side]
    d = np.zeros_like(co)
    dx = co[:, 0] - x0
    wx = 1.0 - _smooth(a * 1.1, a * 1.45, np.abs(dx))
    u = np.clip(dx / a, -1.0, 1.0) ** 2
    top = F["eye_top"] - 0.006 * u
    bottom = F["eye_bottom"] + 0.010 * u
    band = 0.010                       # the eye paint can run onto triangles just below the eye; fold those too
    floor_ = bottom - band
    shut = bottom - 0.004
    close = top + amount * (shut - top)
    z = co[:, 2]
    zn = z.copy()
    under = (z > floor_) & (z <= bottom)
    lo = np.minimum(close, bottom)
    zn[under] = (floor_ + (z - floor_) * (lo - floor_) / band)[under]
    eye = (z > bottom) & (z <= top)
    zn[eye] = (lo + (z - bottom) / (top - bottom) * (close - lo))[eye]
    lid = (z > top) & (z <= top + LID)
    zn[lid] = (close + (z - top) * (top + LID - close) / LID)[lid]
    d[:, 2] = (zn - z) * wx * _face_mask(co, F)
    return d


def _brow(co, F, side, up, inner_down=0.0):
    x0, a = F["eyes"][side]
    d = np.zeros_like(co)
    dx = co[:, 0] - x0
    wx = 1.0 - _smooth(a * 1.1, a * 1.5, np.abs(dx))
    lo, hi = F["brow"]
    wz = 1.0 - _smooth(0.0, (hi - lo) * 0.9, np.abs(co[:, 2] - 0.5 * (lo + hi)))
    inner = np.clip(-np.sign(x0) * dx / a * 0.5 + 0.5, 0.0, 1.0)     # the end nearer her nose
    d[:, 2] = (up - inner_down * inner) * wx * wz * _face_mask(co, F)
    return d


def _jaw(co, F, angle_deg=16.0):
    """The chin below the mouth line swings down about the hinge."""
    d = np.zeros_like(co)
    py, pz = F["hinge"]
    half = F["mouth_half"]
    front = co[:, 1] < py + 0.02
    wx = 1.0 - _smooth(half * 1.6, half * 2.8, np.abs(co[:, 0]))
    line = F["mouth_z"] - 0.006 * np.clip(co[:, 0] / half, -1.0, 1.0) ** 2
    wz = (1.0 - _smooth(line - 0.008, line, co[:, 2])) * (co[:, 2] > F["chin"] - 0.012)
    w = wx * wz * front
    t = math.radians(angle_deg)
    y, z = co[:, 1] - py, co[:, 2] - pz
    d[:, 1] = (y * math.cos(t) - z * math.sin(t) - y) * w
    d[:, 2] = (y * math.sin(t) + z * math.cos(t) - z) * w
    return d


def _set_key(obj, name, delta):
    me = obj.data
    if me.shape_keys is None:
        obj.shape_key_add(name="Basis", from_mix=False)
    kb = me.shape_keys.key_blocks.get(name) or obj.shape_key_add(name=name, from_mix=False)
    kb.data.foreach_set("co", (_coords(me) + delta).astype(np.float32).ravel())
    kb.value = 0.0
    return int((np.abs(delta).max(1) > 1e-5).sum())


def face(outfits=None):
    """Shape keys on each outfit's body: blink_L/R, squint, brow_up_L/R, brow_up (both), brow_down (both, inner
    ends), brow_narrow (brows down and in, lids half down: her masked glare), jaw_open.
    Renders head_<outfit>_<key>.png at full strength for checking."""
    report = {}
    for outfit in outfits or OUTFITS:
        bpy.ops.wm.open_mainfile(filepath=os.path.join(WIP, "nim_%s.blend" % outfit))
        obj = bpy.data.objects["Nim_%s" % outfit]
        F = FACE[outfit]
        co = _coords(obj.data)   # mesh space = world space here (transforms applied, rig at the origin)
        keys = {
            "blink_L": _blink(co, F, "L"), "blink_R": _blink(co, F, "R"),
            "squint": _blink(co, F, "L", 0.45) + _blink(co, F, "R", 0.45)
            + _brow(co, F, "L", 0.0, BROW * 0.66) + _brow(co, F, "R", 0.0, BROW * 0.66),
            "brow_up_L": _brow(co, F, "L", BROW), "brow_up_R": _brow(co, F, "R", BROW),
            "brow_up": _brow(co, F, "L", BROW) + _brow(co, F, "R", BROW),
            "brow_down": _brow(co, F, "L", -BROW * 0.33, BROW * 0.8) + _brow(co, F, "R", -BROW * 0.33, BROW * 0.8),
            # Narrowed: brows down and in, lids half down. Masked on missions, this is her glare (owner).
            "brow_narrow": _brow(co, F, "L", -BROW * 0.5, BROW * 1.2) + _brow(co, F, "R", -BROW * 0.5, BROW * 1.2)
            + _blink(co, F, "L", 0.35) + _blink(co, F, "R", 0.35),
            "jaw_open": _jaw(co, F),
        }
        report[outfit] = {k: _set_key(obj, k, v) for k, v in keys.items()}
        bpy.ops.wm.save_as_mainfile(filepath=os.path.join(WIP, "nim_%s.blend" % outfit))
    print("NIM", report)
    for outfit in outfits or OUTFITS:
        for k in ("blink_L", "brow_narrow", "brow_up", "brow_up_R", "jaw_open"):
            headshots([outfit], key=k)


# --- hands: Meshy fuses fingers into mittens, so each hand is rebuilt (owner, 2026-11-11) ---------------------------
## A chunky cartoon hand: palm, three fingers and a thumb, two segments each, with claws. Sizes in metres.
PALM = (0.062, 0.070, 0.030)          # length (along the arm), width (across the knuckles), thickness
FINGER_R = 0.0115
FINGER_SEG = (0.030, 0.024)
THUMB_SEG = (0.026, 0.022)
FINGER_SPREAD = (-0.022, 0.0, 0.022)  # knuckle offsets across the palm
CUT_PAST_WRIST = -0.01                # cut just behind the wrist: Meshy's thumb root starts there


def _hand_frame(rig_obj, side):
    """Wrist, and three axes: f along the hand, n out of the palm, w across the knuckles (toward the thumb)."""
    b = rig_obj.data.bones["hand." + side]
    wrist = rig_obj.matrix_world @ b.head_local
    tip = rig_obj.matrix_world @ b.tail_local
    f = (tip - wrist).normalized()
    sx = 1.0 if side == "L" else -1.0
    n = Vector((-sx, 0.0, 0.0))                 # A-pose: palms face her thighs
    n = (n - f * n.dot(f)).normalized()
    w = f.cross(n).normalized()
    if w.y > 0:                                  # the thumb is on her front (-Y) side
        w = -w
    return wrist, f, n, w


def _texture_colour(obj, vert_ids, percentile=50):
    """The mean colour of the baked texture under these vertices (for the new hands' fur and glove)."""
    me = obj.data
    img = me.materials[0].node_tree.nodes["Image Texture"].image if "Image Texture" in me.materials[0].node_tree.nodes \
        else next(n.image for n in me.materials[0].node_tree.nodes if n.type == "TEX_IMAGE")
    w, h = img.size
    px = np.empty(w * h * 4, np.float32)
    img.pixels.foreach_get(px)
    px = px.reshape(h, w, 4)
    uv = me.uv_layers.active.data
    ids = set(vert_ids)
    cols = []
    for loop in me.loops:
        if loop.vertex_index in ids:
            u, v = uv[loop.index].uv
            cols.append(px[min(int(v * h), h - 1), min(int(u * w), w - 1), :3])
    if not cols:
        return (0.5, 0.5, 0.5, 1.0)
    cols = np.array(cols)
    # Take the colours around a brightness percentile: a region mixes glove and fur, and the mean would be neither.
    lum = cols @ np.array([0.3, 0.59, 0.11])
    lo, hi = np.percentile(lum, max(percentile - 10, 0)), np.percentile(lum, min(percentile + 10, 100))
    c = cols[(lum >= lo) & (lum <= hi)].mean(axis=0)
    return (float(c[0]), float(c[1]), float(c[2]), 1.0)


def _darkest_uv(obj, vert_ids):
    """The UV of the darkest texel under these vertices: where a cap over a cut can point, so it reads as glove."""
    me = obj.data
    img = next(n.image for n in me.materials[0].node_tree.nodes if n.type == "TEX_IMAGE")
    w, h = img.size
    px = np.empty(w * h * 4, np.float32)
    img.pixels.foreach_get(px)
    px = px.reshape(h, w, 4)
    uv = me.uv_layers.active.data
    ids = set(vert_ids)
    best, best_l = (0.0, 0.0), 9.0
    for loop in me.loops:
        if loop.vertex_index in ids:
            u, v = uv[loop.index].uv
            c = px[min(int(v * h), h - 1), min(int(u * w), w - 1), :3]
            lum = float(c @ np.array([0.3, 0.59, 0.11]))
            if lum < best_l:
                best, best_l = (u, v), lum
    return best


def _flat_mat(name, colour, rough=0.8):
    m = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    m.use_nodes = True
    bsdf = m.node_tree.nodes["Principled BSDF"]
    bsdf.inputs["Base Color"].default_value = colour
    bsdf.inputs["Roughness"].default_value = rough
    return m


def _ellipsoid(centre, axes, radii, mat, segs=16):
    """A UV sphere scaled to radii along three axes (columns of a basis), smooth-shaded."""
    bpy.ops.mesh.primitive_uv_sphere_add(segments=segs, ring_count=segs // 2, radius=1.0, location=(0, 0, 0))
    o = bpy.context.active_object
    basis = Matrix((axes[0] * radii[0], axes[1] * radii[1], axes[2] * radii[2])).transposed().to_4x4()
    o.data.transform(basis)
    o.data.transform(Matrix.Translation(centre))
    o.data.materials.append(mat)
    for p in o.data.polygons:
        p.use_smooth = True
    return o


def build_hands(obj, rig_obj, outfit):
    """Cut the mitten hands off the body; build cartoon hands as their own skinned mesh with finger bones."""
    vs = _verts(obj)
    report = {}
    parts = []          # (object, bone name)
    bone_specs_f = []   # (name, parent, head, tail, roll_toward)
    for side in ("L", "R"):
        wrist0, f0, n, w = _hand_frame(rig_obj, side)
        cut0 = wrist0 + f0 * CUT_PAST_WRIST
        # The hand is everything joined to her fingertips on the far side of the wrist: flood-fill along the surface
        # from the old fingertip, never crossing back past the wrist. That takes a spread thumb, and leaves a hip or
        # a cord coil beside the hand alone.
        adj = {}
        for e in obj.data.edges:
            a, b = e.vertices
            adj.setdefault(a, []).append(b)
            adj.setdefault(b, []).append(a)
        tip_guess = rig_obj.matrix_world @ rig_obj.data.bones["hand." + side].tail_local
        seed = min(range(len(vs)), key=lambda i: (vs[i] - tip_guess).length)
        flood, stack = {seed}, [seed]
        while stack:
            i = stack.pop()
            for j in adj.get(i, ()):
                if j not in flood and (vs[j] - cut0).dot(f0) > -0.05 and (vs[j] - wrist0).length < 0.3:
                    flood.add(j)
                    stack.append(j)
        near = sorted(flood)
        gone = [i for i in near if (vs[i] - cut0).dot(f0) > 0]
        # The real hand axis, from the mesh: the ring at the cut to the centre of the old fingertips.
        ring = [vs[i] for i in near if abs((vs[i] - cut0).dot(f0)) < 0.006]
        ring_c = _centre(ring)
        far = sorted(gone, key=lambda i: (vs[i] - cut0).dot(f0))[-max(len(gone) // 5, 1):]
        tip_c = _centre([vs[i] for i in far])
        f = (tip_c - ring_c).normalized()
        n = (n - f * n.dot(f)).normalized()
        w = f.cross(n).normalized()
        if w.y > 0:
            w = -w
        ring_r = sum((v - ring_c - f * (v - ring_c).dot(f)).length for v in ring) / len(ring)
        fur_ids = [i for i in far]
        glove_ids = [i for i in gone if (vs[i] - cut0).dot(f) < 0.04]
        fur = _texture_colour(obj, fur_ids, 75)
        glove = _texture_colour(obj, glove_ids, 10)
        cap_uv = _darkest_uv(obj, glove_ids)
        m_fur = _flat_mat("hand_fur_%s" % outfit, fur)
        m_glove = _flat_mat("hand_glove_%s" % outfit, glove, 0.7)
        m_claw = _flat_mat("hand_claw", (0.86, 0.84, 0.78, 1.0), 0.5)
        # Cut the mitten off with a clean plane (only near this hand) and cap the hole.
        bm = bmesh.new()
        bm.from_mesh(obj.data)
        bm.verts.ensure_lookup_table()
        local_v = set(bm.verts[i] for i in near)
        local_f = [fc for fc in bm.faces if all(v in local_v for v in fc.verts)]
        geom = list(local_v) + list({e for fc in local_f for e in fc.edges}) + local_f
        res = bmesh.ops.bisect_plane(bm, geom=geom, plane_co=ring_c, plane_no=f, clear_outer=True)
        cut_edges = [e for e in res["geom_cut"] if isinstance(e, bmesh.types.BMEdge) and e.is_valid
                     and e.is_boundary]
        if cut_edges:
            filled = bmesh.ops.holes_fill(bm, edges=cut_edges, sides=0)
            # The cap reads as glove, not as whatever texel its new faces happen to land on.
            uv_layer = bm.loops.layers.uv.active
            for fc in filled["faces"]:
                for lp in fc.loops:
                    lp[uv_layer].uv = cap_uv
        bm.to_mesh(obj.data)
        bm.free()
        obj.data.update()
        vs = _verts(obj)
        report["cut_" + side] = len(gone)
        report["ring_r_" + side] = round(ring_r, 3)
        # The hand bone follows the real axis: it drives the arm's weights and the fingers hang off it.
        wrist = ring_c
        hand_len = (tip_c - ring_c).length
        bone_specs_f.append(("hand." + side, None, wrist.copy(), (wrist + f * hand_len).copy(), n.copy()))
        # The palm: sized to the cut ring, starting inside the cuff.
        pl, pw, pt = max(PALM[0], hand_len * 0.5), max(PALM[1], ring_r * 1.9), max(PALM[2], ring_r * 0.8)
        palm_c = wrist + f * (pl * 0.3)       # reaches back into the cuff, over the cap
        parts.append((_ellipsoid(palm_c, (f, w, n), (pl * 0.62, pw * 0.5, pt * 0.5), m_glove), "hand." + side))
        # Three fingers from the front edge of the palm, fanning slightly.
        for k, off in enumerate(FINGER_SPREAD):
            base = wrist + f * (pl * 0.9) + w * off * (pw / PALM[1])
            d = (f + w * off * 4.0).normalized()
            p = base
            for s, seg in enumerate(FINGER_SEG):
                name = "finger%d.%d.%s" % (k + 1, s + 1, side)
                parent = ("hand." + side) if s == 0 else "finger%d.%d.%s" % (k + 1, s, side)
                end = p + d * seg
                bone_specs_f.append((name, parent, p.copy(), end.copy(), n.copy()))
                r = FINGER_R * (1.0 if s == 0 else 0.9)
                parts.append((_ellipsoid((p + end) / 2, (d, w, n), (seg * 0.62, r, r * 0.95), m_fur), name))
                p = end
            claw = _ellipsoid(p + d * 0.004, (d, w, n), (0.008, 0.004, 0.004), m_claw, 8)
            parts.append((claw, "finger%d.2.%s" % (k + 1, side)))
        # The thumb, on her front side near the wrist, angled out and forward.
        base = wrist + f * (pl * 0.35) + w * (pw * 0.42)
        d = (f * 0.55 + w * 0.8 - n * 0.2).normalized()
        p = base
        for s, seg in enumerate(THUMB_SEG):
            name = "thumb.%d.%s" % (s + 1, side)
            parent = ("hand." + side) if s == 0 else "thumb.1.%s" % side
            end = p + d * seg
            bone_specs_f.append((name, parent, p.copy(), end.copy(), n.copy()))
            r = FINGER_R * 1.1
            parts.append((_ellipsoid((p + end) / 2, (d, w, n), (seg * 0.62, r, r), m_fur), name))
            p = end
        parts.append((_ellipsoid(p + d * 0.004, (d, w, n), (0.008, 0.004, 0.004), m_claw, 8), "thumb.2.%s" % side))
    # Finger bones under each hand bone. Roll: Z toward the palm, so +X rotation curls a finger in.
    bpy.ops.object.select_all(action="DESELECT")
    bpy.context.view_layer.objects.active = rig_obj
    rig_obj.select_set(True)
    bpy.ops.object.mode_set(mode="EDIT")
    eb = rig_obj.data.edit_bones
    for name, parent, head, tail, palm_n in bone_specs_f:
        b = eb.get(name) or eb.new(name)
        b.head, b.tail = head, tail
        if parent:
            b.parent = eb[parent]
        b.use_connect = False
        b.align_roll(palm_n)
    bpy.ops.object.mode_set(mode="OBJECT")
    # Rigid weights, then one object.
    for o, bone in parts:
        g = o.vertex_groups.new(name=bone)
        g.add(list(range(len(o.data.vertices))), 1.0, "REPLACE")
    bpy.ops.object.select_all(action="DESELECT")
    for o, _ in parts:
        o.select_set(True)
    bpy.context.view_layer.objects.active = parts[0][0]
    bpy.ops.object.join()
    hands = bpy.context.active_object
    hands.name = "Nim_%s_Hands" % outfit
    hands.parent = rig_obj
    mod = hands.modifiers.new("Armature", "ARMATURE")
    mod.object = rig_obj
    report["hand_tris"] = sum(len(p.vertices) - 2 for p in hands.data.polygons)
    report["finger_bones"] = len(bone_specs_f)
    return hands, report


def hands(outfits=None):
    """After rig and face: rebuild both hands, then render the A-pose and a grip test."""
    report = {}
    for outfit in outfits or OUTFITS:
        bpy.ops.wm.open_mainfile(filepath=os.path.join(WIP, "nim_%s.blend" % outfit))
        obj = bpy.data.objects["Nim_%s" % outfit]
        rig_obj = bpy.data.objects["Nim_%s_Rig" % outfit]
        old = bpy.data.objects.get("Nim_%s_Hands" % outfit)
        if old:
            raise SystemExit("hands already built for %s: rerun clean/rig/face first" % outfit)
        h, report[outfit] = build_hands(obj, rig_obj, outfit)
        bpy.ops.wm.save_as_mainfile(filepath=os.path.join(WIP, "nim_%s.blend" % outfit))
        # Close-ups of her left hand, relaxed and gripping (every finger bone curled 50 degrees).
        wrist, f, n, w = _hand_frame(rig_obj, "L")
        centre = wrist + f * 0.06
        for tag, curl in (("open", 0.0), ("grip", 50.0)):
            for pb in rig_obj.pose.bones:
                if pb.name.startswith(("finger", "thumb")):
                    pb.rotation_mode = "XYZ"
                    pb.rotation_euler = (math.radians(curl), 0, 0)
            bpy.context.view_layer.update()
            closeup(centre, Vector((0.5, -1.0, 0.1)).normalized(), 0.3, "hand_%s_%s.png" % (outfit, tag))
        for pb in rig_obj.pose.bones:
            pb.rotation_euler = (0, 0, 0)
    print("NIM", report)


def closeup(centre, d, scale, name, size=600):
    """An orthographic close render looking along -d at centre (scale: metres across)."""
    sc = bpy.context.scene
    sc.render.engine = "BLENDER_EEVEE"
    sc.render.resolution_x = sc.render.resolution_y = size
    cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
    cam.data.type = "ORTHO"
    cam.data.ortho_scale = scale
    sc.collection.objects.link(cam)
    sc.camera = cam
    cam.location = centre + d * 2.0
    cam.rotation_euler = (-d).to_track_quat("-Z", "Y").to_euler()
    sun = bpy.data.objects.new("sun", bpy.data.lights.new("sun", "SUN"))
    sun.data.energy = 2.5
    sun.rotation_euler = (-d + Vector((0, 0, -0.6))).to_track_quat("-Z", "Z").to_euler()
    sc.collection.objects.link(sun)
    sc.render.filepath = os.path.join(WIP, name)
    bpy.ops.render.render(write_still=True)
    bpy.data.objects.remove(cam)
    bpy.data.objects.remove(sun)


# --- fingers: Meshy's own hands, rigged along their grooves (owner, 2026-11-11: option 1) ---------------------------
## Her hands keep their sculpt and paint. Each claw tip is found on the mesh; a bone runs from its knuckle (where the
## fingers leave the glove) to the tip, and the vertices of each finger move to its bone. The grooves between fingers
## are where the weight changes hands, so a bend keeps the sculpt's own separation.
FINGER_LEN = 0.06        # knuckle to claw tip, measured on the renders
THUMB_LEN = 0.05
TIP_RADIUS = 0.009       # a claw tip is the furthest point (along the hand) within this radius
KNUCKLE_BLEND = (-0.008, 0.012)   # weight ramps from the hand bone to the finger across the knuckle


def _hand_region(obj, rig_obj, side, vs):
    wrist, f, n, w = _hand_frame(rig_obj, side)
    adj = {}
    for e in obj.data.edges:
        a, b = e.vertices
        adj.setdefault(a, []).append(b)
        adj.setdefault(b, []).append(a)
    tip_guess = rig_obj.matrix_world @ rig_obj.data.bones["hand." + side].tail_local
    seed = min(range(len(vs)), key=lambda i: (vs[i] - tip_guess).length)
    region, stack = {seed}, [seed]
    while stack:
        i = stack.pop()
        for j in adj.get(i, ()):
            if j not in region and (vs[j] - wrist).dot(f) > -0.03 and (vs[j] - wrist).length < 0.25:
                region.add(j)
                stack.append(j)
    return sorted(region), wrist, f, n, w


def _find_tips(vs, region, wrist, f):
    """Claw tips: vertices furthest along the hand within TIP_RADIUS, merged when closer than 1 cm."""
    from mathutils.kdtree import KDTree
    kd = KDTree(len(region))
    for k, i in enumerate(region):
        kd.insert(vs[i], k)
    kd.balance()
    t = {i: (vs[i] - wrist).dot(f) for i in region}
    tips = []
    for i in region:
        if all(t[region[k]] <= t[i] for _, k, _ in kd.find_range(vs[i], TIP_RADIUS)):
            if all((vs[i] - vs[j]).length > 0.01 for j in tips):
                tips.append(i)
    return tips, t


def rig_fingers(obj, rig_obj, outfit):
    vs = _verts(obj)
    report = {}
    new_bones = []        # (name, parent, head, tail, palm normal)
    plans = []            # per side: (region, t, fingers [(name, head, tail)], thumb (name, head, tail) | None)
    for side in ("L", "R"):
        region, wrist, f, n, w = _hand_region(obj, rig_obj, side, vs)
        tips, t = _find_tips(vs, region, wrist, f)
        tmax = max(t[i] for i in region)
        # Fingers: tips near the end of the hand. The thumb: the remaining tip furthest off the hand's axis.
        finger_tips = [i for i in tips if t[i] > tmax - 0.035]
        others = [i for i in tips if i not in finger_tips and t[i] > 0.03]

        def off_axis(i):
            r = vs[i] - wrist
            return (r - f * r.dot(f)).length
        thumb_tip = max(others, key=off_axis) if others else None
        finger_tips.sort(key=lambda i: (vs[i] - wrist).dot(w))
        fingers = []
        for k, i in enumerate(finger_tips):
            tip = vs[i].copy()
            head = tip - f * FINGER_LEN
            name = "finger%d.%s" % (k + 1, side)
            fingers.append((name, head, tip))
            new_bones.append((name, "hand." + side, head, tip, n.copy()))
        thumb = None
        if thumb_tip is not None:
            tip = vs[thumb_tip].copy()
            r = tip - wrist
            axis_pt = wrist + f * r.dot(f)
            d = (tip - (axis_pt + (tip - axis_pt) * 0.35)).normalized()
            d = (d + f * 1.2).normalized()
            head = tip - d * THUMB_LEN
            thumb = ("thumb.%s" % side, head, tip)
            new_bones.append((thumb[0], "hand." + side, head, tip, n.copy()))
        plans.append((side, region, f, fingers, thumb))
        report[side] = {"fingers": len(fingers), "thumb": thumb is not None,
                        "tips_t": sorted(round(t[i], 3) for i in tips)[-8:]}
    # Bones.
    bpy.ops.object.select_all(action="DESELECT")
    bpy.context.view_layer.objects.active = rig_obj
    rig_obj.select_set(True)
    bpy.ops.object.mode_set(mode="EDIT")
    eb = rig_obj.data.edit_bones
    for name, parent, head, tail, palm_n in new_bones:
        b = eb.get(name) or eb.new(name)
        b.head, b.tail = head, tail
        b.parent = eb[parent]
        b.use_connect = False
        b.align_roll(palm_n)       # Z toward the palm: +X rotation curls the finger in
    bpy.ops.object.mode_set(mode="OBJECT")
    # Weights: move each hand vertex's "hand" weight onto its finger, ramped across the knuckle.
    groups = {g.name: g for g in obj.vertex_groups}
    for name, *_ in new_bones:
        if name not in groups:
            groups[name] = obj.vertex_groups.new(name=name)
    for side, region, f, fingers, thumb in plans:
        gh = groups["hand." + side]
        segs = fingers + ([thumb] if thumb else [])
        moved = 0
        for i in region:
            v = obj.data.vertices[i]
            wh = next((g.weight for g in v.groups if g.group == gh.index), 0.0)
            if wh <= 0.0:
                continue
            p = vs[i]
            near = sorted((_seg_dist(p, h, tl), nm, h, tl) for nm, h, tl in segs)
            d, nm, h, tl = near[0]
            if d > 0.03:
                continue
            along = (p - h).dot((tl - h).normalized())
            s = min(max((along - KNUCKLE_BLEND[0]) / (KNUCKLE_BLEND[1] - KNUCKLE_BLEND[0]), 0.0), 1.0)
            s = s * s * (3 - 2 * s)
            if s <= 0.0:
                continue
            gh.add([i], wh * (1.0 - s), "REPLACE")
            groups[nm].add([i], wh * s, "REPLACE")
            moved += 1
        report[side]["verts_moved"] = moved
    return report


def fingers(outfits=None):
    """After weights: rig Meshy's own fingers, then render each hand open and curled from two sides."""
    report = {}
    for outfit in outfits or OUTFITS:
        bpy.ops.wm.open_mainfile(filepath=os.path.join(WIP, "nim_%s.blend" % outfit))
        obj = bpy.data.objects["Nim_%s" % outfit]
        rig_obj = bpy.data.objects["Nim_%s_Rig" % outfit]
        if any(b.name.startswith(("finger", "thumb")) for b in rig_obj.data.bones):
            raise SystemExit("fingers already rigged for %s: rerun weights first" % outfit)
        report[outfit] = rig_fingers(obj, rig_obj, outfit)
        bpy.ops.wm.save_as_mainfile(filepath=os.path.join(WIP, "nim_%s.blend" % outfit))
        wrist, f, n, w = _hand_frame(rig_obj, "L")
        c = wrist + f * 0.07
        for tag, curl in (("open", 0.0), ("grip", 70.0)):
            for pb in rig_obj.pose.bones:
                if pb.name.startswith(("finger", "thumb")):
                    pb.rotation_mode = "XYZ"
                    pb.rotation_euler = (math.radians(curl), 0, 0)
            bpy.context.view_layer.update()
            for view, d in (("back", -n), ("thumbside", w)):
                closeup(c, d.normalized(), 0.2, "fingers_%s_%s_%s.png" % (outfit, tag, view), 500)
        for pb in rig_obj.pose.bones:
            pb.rotation_euler = (0, 0, 0)
    print("NIM", report)


# --- the velvet muzzle: its own mesh on the head bone (owner, 2026-11-11; DESIGN.md "Her velvet muzzle") ------------
## Black velvet shell (snout plus the eye band, eye openings cut), red piping on every edge, a brass grille with the
## Rope's knot, straps round the head to a brass back buckle. Built from her face, so it fits; never part of the body.
MASK_LIFT = 0.004        # how far the shell stands off her fur
MASK_THICK = 0.004
PIPING_R = 0.0025


def _curve_from_points(name, pts, radius, mat, closed=True):
    cu = bpy.data.curves.new(name, "CURVE")
    cu.dimensions = "3D"
    cu.bevel_depth = radius
    cu.bevel_resolution = 2
    sp = cu.splines.new("POLY")
    sp.points.add(len(pts) - 1)
    for p, q in zip(sp.points, pts):
        p.co = (q.x, q.y, q.z, 1.0)
    sp.use_cyclic_u = closed
    o = bpy.data.objects.new(name, cu)
    bpy.context.scene.collection.objects.link(o)
    o.data.materials.append(mat)
    return o


def _to_mesh(o):
    bpy.ops.object.select_all(action="DESELECT")
    o.select_set(True)
    bpy.context.view_layer.objects.active = o
    bpy.ops.object.convert(target="MESH")
    return bpy.context.active_object


MASK_BAND_THETA = 1.2   # the eye band wraps this far round her head (radians from the front)
MASK_GRID = (0.010, 0.0025)   # the shell's sampling: radians around, metres up
STRAP_HALF = 0.011


def _ribbon(points, normals, half, mat, name):
    """A flat strap through points, lying on the surface (width along world Z), given a little thickness."""
    me = bpy.data.meshes.new(name)
    verts, faces = [], []
    up = Vector((0, 0, 1))
    for p, nrm in zip(points, normals):
        verts += [p + up * half, p - up * half]
    for k in range(len(points) - 1):
        a = 2 * k
        faces.append((a, a + 1, a + 3, a + 2))
    me.from_pydata([tuple(v) for v in verts], [], faces)
    o = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(o)
    o.data.materials.append(mat)
    so = o.modifiers.new("Solidify", "SOLIDIFY")
    so.thickness, so.offset = 0.003, 0.0
    return _apply_all(o)


def _oriented_box(centre, fwd, size, mat, bevel=0.002):
    """A bevelled box facing fwd (size: width along x-ish, height along z, depth along fwd)."""
    bpy.ops.mesh.primitive_cube_add(size=1.0)
    o = bpy.context.active_object
    o.scale = size
    bv = o.modifiers.new("Bevel", "BEVEL")
    bv.width, bv.segments = bevel, 3
    o = _apply_all(o)
    side = Vector((0, 0, 1)).cross(fwd).normalized()
    up = fwd.cross(side).normalized()

    m = Matrix((side, fwd, up)).transposed().to_4x4()
    o.data.transform(m)
    o.data.transform(Matrix.Translation(centre))
    o.data.materials.append(mat)
    return o


def build_mask(obj, rig_obj, outfit):
    """The muzzle and eye band as one clean shell over her face, piped in red, with the brass grille and knot,
    straps round the back of her head to a brass buckle, and a brass quick-release catch."""
    from mathutils.bvhtree import BVHTree
    F = FACE[outfit]
    vs = _verts(obj)
    bvh = BVHTree.FromPolygons(vs, [tuple(p.vertices) for p in obj.data.polygons])
    eye_z = (F["eye_top"] + F["eye_bottom"]) / 2
    ring = [v for v in vs if abs(v.z - eye_z) < 0.01 and abs(v.x) < 0.3]
    cy = (min(v.y for v in ring) + max(v.y for v in ring)) / 2

    def cast(theta, z):
        d = Vector((math.sin(theta), -math.cos(theta), 0.0))
        hit, nrm, _, _ = bvh.ray_cast(Vector((0.0, cy, z)) + d * 0.6, -d, 1.2)
        return hit, nrm

    # The outline, in (x, z) on her face plus the angle round her head.
    band_top, band_bot = F["eye_top"] + 0.022, F["eye_bottom"] - 0.02
    snout_bot = F["chin"] - 0.006
    sx = F["mouth_half"] * 1.75
    sz0, shz = (snout_bot + band_bot) / 2, (band_bot - snout_bot) / 2 + 0.006
    hole_top, hole_bot = F["eye_top"] + 0.012, F["eye_bottom"] - 0.006
    hzc, hh = (hole_top + hole_bot) / 2, (hole_top - hole_bot) / 2
    bzc, bh = (band_top + band_bot) / 2, (band_top - band_bot) / 2

    def inside(theta, p):
        in_band = (abs(theta) / MASK_BAND_THETA) ** 6 + ((p.z - bzc) / bh) ** 6 < 1.0
        in_snout = (abs(p.x) / sx) ** 4 + ((p.z - sz0) / shz) ** 4 < 1.0 and abs(theta) < 1.0
        hole = any(((p.x - x0) / (a * 1.1)) ** 2 + ((p.z - hzc) / hh) ** 2 < 1.0 for x0, a in F["eyes"].values())
        return (in_band or in_snout) and not hole

    dt, dz = MASK_GRID
    thetas = [-1.35 + k * dt for k in range(int(2.7 / dt) + 1)]
    zs = [snout_bot - 0.01 + k * dz for k in range(int((band_top + 0.012 - snout_bot) / dz) + 1)]
    grid = {}
    for a, th in enumerate(thetas):
        for b, z in enumerate(zs):
            hit, nrm = cast(th, z)
            if hit is not None and inside(th, hit):
                grid[(a, b)] = hit + nrm * MASK_LIFT
    bm = bmesh.new()
    vmap = {k: bm.verts.new(p) for k, p in grid.items()}
    for (a, b) in grid:
        quad = [(a, b), (a + 1, b), (a + 1, b + 1), (a, b + 1)]
        if all(q in vmap for q in quad):
            bm.faces.new([vmap[q] for q in quad])
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context="VERTS")
    # Smooth the stair-stepped rim along itself, so the edge reads as a cut line, not pixels.
    for _ in range(20):
        moves = {}
        for v in bm.verts:
            if not v.is_boundary:
                continue
            nb = [e.other_vert(v) for e in v.link_edges if e.is_boundary]
            if len(nb) == 2:
                moves[v] = v.co * 0.5 + (nb[0].co + nb[1].co) * 0.25
        for v, c in moves.items():
            v.co = c
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    me = bpy.data.meshes.new("mask")
    bm.to_mesh(me)
    bm.free()
    shell = bpy.data.objects.new("Nim_%s_Mask" % outfit, me)
    bpy.context.scene.collection.objects.link(shell)
    # Outward normals: compare with the face's normal straight ahead.
    _, front_n = cast(0.0, eye_z - 0.03)
    me.update()
    if front_n is not None and sum((p.normal.dot(front_n) for p in me.polygons)) < 0:
        me.flip_normals()
    # Re-seat on her fur after the rim smoothing.
    sw = shell.modifiers.new("Shrinkwrap", "SHRINKWRAP")
    sw.target, sw.wrap_method, sw.offset = obj, "NEAREST_SURFACEPOINT", MASK_LIFT
    sw.wrap_mode = "OUTSIDE_SURFACE"
    shell = _apply_all(shell)
    velvet = _flat_mat("mask_velvet", (0.03, 0.028, 0.034, 1.0), 0.95)
    red = _flat_mat("mask_velvet_red", (0.42, 0.02, 0.05, 1.0), 0.9)
    leather = _flat_mat("mask_leather", (0.035, 0.035, 0.035, 1.0), 0.6)
    brass = _flat_mat("mask_brass", (0.85, 0.62, 0.26, 1.0), 0.28)
    brass.node_tree.nodes["Principled BSDF"].inputs["Metallic"].default_value = 1.0
    shell.data.materials.append(velvet)
    # Piping on every rim (taken before the solidify closes them).
    bm = bmesh.new()
    bm.from_mesh(shell.data)
    rims, seen = [], set()
    for e in bm.edges:
        if not e.is_boundary or e in seen:
            continue
        seen.add(e)
        loop, cur, prev_e = [e.verts[0].co.copy()], e.verts[1], e
        while True:
            loop.append(cur.co.copy())
            nxt = [x for x in cur.link_edges if x.is_boundary and x not in seen]
            if not nxt:
                break
            seen.add(nxt[0])
            cur = nxt[0].other_vert(cur)
        if len(loop) > 10:
            rims.append(loop)
    bm.free()
    so = shell.modifiers.new("Solidify", "SOLIDIFY")
    so.thickness, so.offset = MASK_THICK, 1.0
    shell = _apply_all(shell)
    for p in shell.data.polygons:
        p.use_smooth = True
    parts = [shell]
    for k, loop in enumerate(rims):
        parts.append(_to_mesh(_curve_from_points("piping%d" % k, loop, PIPING_R, red)))
    # The grille on the front of the snout, the knot raised on it.
    gp, gn = cast(0.0, F["mouth_z"] + 0.004)
    gc = gp + gn * (MASK_LIFT + MASK_THICK + 0.009)
    parts.append(_oriented_box(gc, gn, (0.064, 0.016, 0.062), brass, 0.006))
    side = Vector((0, 0, 1)).cross(gn).normalized()
    up = gn.cross(side).normalized()
    for k, (off, sc) in enumerate(((up * 0.0095, (1.0, 1.0)), (-up * 0.0095, (1.0, 1.0)), (Vector(), (1.7, 0.6)))):
        bpy.ops.mesh.primitive_torus_add(major_radius=0.011, minor_radius=0.0028, major_segments=24,
                                         minor_segments=8)
        t = bpy.context.active_object
        t.scale = (sc[0], sc[1], 1.0)
        t = _apply_all(t)
        # Torus lies in its XY plane: put that plane on the grille (X = side, Y = up, Z = out).
        t.data.transform(Matrix((side, up, gn)).transposed().to_4x4())
        t.data.transform(Matrix.Translation(gc + gn * 0.0095 + off * 1.25))
        t.data.materials.append(brass)
        parts.append(t)
    # Straps: from each side of the eye band and of the snout, round the back of her head.
    strap_backs = []
    snout_theta = 0.0
    for k in range(1, 200):
        th = k * 0.01
        p, _ = cast(th, sz0)
        if p is None or abs(p.x) > sx * 0.97:
            snout_theta = th
            break
    for z, th0 in ((eye_z, MASK_BAND_THETA * 0.97), (sz0, snout_theta)):
        pts, nrms = [], []
        steps = 72
        for k in range(steps + 1):
            th = th0 + (2 * math.pi - 2 * th0) * k / steps
            p, nrm = cast(th, z)
            if p is None:
                continue
            pts.append(p + nrm * (MASK_LIFT + 0.002))
            nrms.append(nrm)
        if len(pts) > 4:
            parts.append(_ribbon(pts, nrms, STRAP_HALF, leather, "strap"))
            strap_backs.append(max(pts, key=lambda q: q.y))
    if strap_backs:
        b = max(strap_backs, key=lambda q: q.z)
        parts.append(_oriented_box(b + Vector((0, 0.004, 0)), Vector((0, 1, 0)), (0.03, 0.006, 0.022), brass))
    # The quick-release catch where the lower strap meets the snout, her right side.
    cp, cn = cast(-snout_theta - 0.04, sz0)
    if cp is not None:
        parts.append(_oriented_box(cp + cn * 0.006, cn, (0.014, 0.006, 0.018), brass, 0.003))
    bpy.ops.object.select_all(action="DESELECT")
    for p in parts:
        p.select_set(True)
    bpy.context.view_layer.objects.active = shell
    bpy.ops.object.join()
    mask_obj = bpy.context.active_object
    mask_obj.name = "Nim_%s_Mask" % outfit
    mw = mask_obj.matrix_world.copy()
    mask_obj.parent = rig_obj
    mask_obj.parent_type = "BONE"
    mask_obj.parent_bone = "head"
    mask_obj.matrix_world = mw
    return mask_obj, {"rims": len(rims), "snout_theta": round(snout_theta, 2),
                      "tris": sum(len(p.vertices) - 2 for p in mask_obj.data.polygons)}


# --- the Meshy muzzle (owner, 2026-11-11: "have Meshy supply the mask alone, then fit it") ------------------------
## Measured on .wip/nim/raw/nim_mask.glb as imported: the eye holes' centres and half-width, the chin, the front.
MESHY_MASK = {"eye_x": 0.41, "eye_z": 0.27, "hole_half": 0.21, "chin_z": -0.552, "front_y": -0.949}
MASK_TRIS = 60000
MASK_GAP = 0.007          # how far every part of the mask stays off her fur
MASK_PUSH_R = 0.014       # a push spreads this far, so the shell's back and front move together


def fit_meshy_mask(obj, rig_obj, outfit, push=True):
    from mathutils.bvhtree import BVHTree
    from mathutils.kdtree import KDTree
    F = FACE[outfit]
    # Fit and parent in the rest pose: after the clips are baked the rig plays its first track, and a mask fitted to
    # the rest face but parented to a posed head lands by her ear.
    rig_obj.data.pose_position = "REST"
    bpy.context.view_layer.update()
    m = import_raw("mask")
    m.name = "Nim_%s_Mask" % outfit
    tris = sum(len(p.vertices) - 2 for p in m.data.polygons)
    seams.decimate_safe(m, min(1.0, MASK_TRIS / tris))   # never across a UV seam (Meshy seam tears)
    m = _apply_all(m)
    # Scale: across from her eye spacing, down from her eye-to-chin height, depth with the across.
    her_eye_x = (abs(F["eyes"]["L"][0]) + abs(F["eyes"]["R"][0])) / 2
    her_eye_z = (F["eye_top"] + F["eye_bottom"]) / 2
    M = MESHY_MASK
    sx = her_eye_x / M["eye_x"]
    sz = (her_eye_z - (F["chin"] - 0.012)) / (M["eye_z"] - M["chin_z"])
    vs = _verts(obj)
    nose_y = min(v.y for v in vs if abs(v.x) < 0.03 and F["chin"] < v.z < F["eye_bottom"])
    m.data.transform(Matrix.Diagonal((sx, sx, sz, 1.0)))
    m.data.transform(Matrix.Translation((0.0, nose_y - 0.012 - M["front_y"] * sx, her_eye_z - M["eye_z"] * sz)))
    m.data.update()
    # Keep it off her fur by widening it outward from the middle of her head (never along the nearest normal: on a
    # thin shell that flips from side to side and shreds it). Each vertex finds her surface in its own direction;
    # the push spreads through the shell's thickness, is smoothed across the mesh, and never drops below its need.
    bvh = BVHTree.FromPolygons(vs, [tuple(p.vertices) for p in obj.data.polygons])
    ring = [v for v in vs if abs(v.z - her_eye_z) < 0.01 and abs(v.x) < 0.3]
    cy = (min(v.y for v in ring) + max(v.y for v in ring)) / 2
    mv = [v.co.copy() for v in m.data.vertices]
    n = len(mv)

    def radial(p):
        d = Vector((p.x, p.y - cy, 0.0))
        return d.normalized() if d.length > 1e-6 else Vector((0.0, -1.0, 0.0))

    need = [0.0] * n
    dirs = [radial(p) for p in mv]
    for i, p in enumerate(mv):
        if not push:
            break
        axis = Vector((0.0, cy, p.z))
        hit, _, _, _ = bvh.ray_cast(axis + dirs[i] * 0.6, -dirs[i], 0.6)
        if hit is None:
            continue
        r_surf = Vector((hit.x, hit.y - cy, 0.0)).length
        r_now = Vector((p.x, p.y - cy, 0.0)).length
        # In front of her ears, only ever outward. Behind (the straps), onto her head: in or out, so a strap that
        # hangs loose in the concept lies on her skull instead.
        signed = r_surf + MASK_GAP - r_now
        need[i] = signed if p.y > cy - 0.02 else max(0.0, signed)
    # Through the thickness: each vertex takes the largest need within MASK_PUSH_R.
    kd = KDTree(n)
    for i, p in enumerate(mv):
        kd.insert(p, i)
    kd.balance()
    hot = [i for i in range(n) if need[i] > 0.0]
    spread = need[:]
    for i in hot:
        for _, j, _ in kd.find_range(mv[i], MASK_PUSH_R):
            if need[i] > spread[j]:
                spread[j] = need[i]
    # Smooth along the mesh's edges, then never less than the vertex's own need.
    adj = [[] for _ in range(n)]
    for e in m.data.edges:
        a, b = e.vertices
        adj[a].append(b)
        adj[b].append(a)
    for _ in range(25):
        spread = [(spread[i] + sum(spread[j] for j in adj[i]) / len(adj[i])) / 2 if adj[i] else spread[i]
                  for i in range(n)]
    total = 0
    for i in range(n):
        e = max(spread[i], need[i]) if need[i] >= 0.0 else spread[i]
        if e != 0.0:
            mv[i] = mv[i] + dirs[i] * e
            total += 1
    for v, p in zip(m.data.vertices, mv):
        v.co = p
    m.data.update()
    for p in m.data.polygons:
        p.use_smooth = True
    brass_px = _brass_texture(m)
    mw = m.matrix_world.copy()
    m.parent = rig_obj
    m.parent_type = "BONE"
    m.parent_bone = "head"
    m.matrix_world = mw
    return m, {"tris": sum(len(p.vertices) - 2 for p in m.data.polygons), "scale": [round(sx, 3), round(sz, 3)],
               "pushed": total, "brass_px": brass_px}


BRASS_LIGHT = np.array([1.0, 0.82, 0.45])
BRASS_DARK = np.array([0.42, 0.27, 0.08])


def _brass_texture(m):
    """Meshy painted the grille and buckles cream. Those texels (bright, warm, unsaturated, not red) become brass,
    keeping their brightness as the shading."""
    img = next(n.image for mat in m.data.materials for n in mat.node_tree.nodes if n.type == "TEX_IMAGE")
    w, h = img.size
    px = np.empty(w * h * 4, np.float32)
    img.pixels.foreach_get(px)
    px = px.reshape(-1, 4)
    rgb = px[:, :3]
    lum = rgb @ np.array([0.3, 0.59, 0.11])
    sat = rgb.max(axis=1) - rgb.min(axis=1)
    cream = (lum > 0.35) & (sat < 0.25) & (rgb[:, 0] >= rgb[:, 2]) & (rgb[:, 0] - rgb[:, 1] < 0.12)
    t = np.clip((lum[cream] - 0.35) / 0.55, 0.0, 1.0)[:, None]
    rgb[cream] = BRASS_DARK * (1 - t) + BRASS_LIGHT * t
    px[:, :3] = rgb
    img.pixels.foreach_set(px.ravel())
    img.update()
    img.pack()
    return int(cream.sum())


def paint(outfits=None):
    """The paint pass (tools/nim_paint.py): clouds for spots, clean cloth, a clean mask, seams padded. From the
    pristine `_preseams` bakes, so it can be rerun."""
    import nim_paint
    report = {}
    for outfit in outfits or OUTFITS:
        bpy.ops.wm.open_mainfile(filepath=os.path.join(WIP, "nim_%s.blend" % outfit))
        rig_obj = bpy.data.objects["Nim_%s_Rig" % outfit]
        rig_obj.data.pose_position = "REST"
        bpy.context.view_layer.update()
        obj = bpy.data.objects["Nim_%s" % outfit]
        old = next(n.image for n in obj.data.materials[0].node_tree.nodes
                   if n.type == "TEX_IMAGE" and "color" in n.image.name)
        src = os.path.join(WIP, "nim_%s_color_preseams.png" % outfit)
        ears = [(np.array(rig_obj.data.bones[b].head_local[:]), np.array(rig_obj.data.bones[b].tail_local[:]))
                for b in ("ear.L", "ear.R")]
        tail = [(np.array(rig_obj.data.bones[b].head_local[:]), np.array(rig_obj.data.bones[b].tail_local[:]))
                for b in ("tail.1", "tail.2")]
        img, rep = nim_paint.paint_body(obj, outfit, FACE[outfit], src, ears, tail)
        _, rep["swapped"] = nim_paint.save_and_swap(obj, img, os.path.join(WIP, "nim_%s_color.png" % outfit), old)
        mask_obj = bpy.data.objects.get("Nim_%s_Mask" % outfit)
        if mask_obj:
            mold = seams._image_of(mask_obj)
            mimg, rep["mask"] = nim_paint.clean_mask(mask_obj)
            nim_paint.save_and_swap(mask_obj, mimg, os.path.join(WIP, "nim_mask_color.png"), mold)
        report[outfit] = rep
        # Check renders, then back to the pose and save.
        render_views(obj, "paint_%s" % outfit)
        head_c = Vector((0.0, HEAD_FRAME[0], HEAD_FRAME[1]))
        closeup(head_c, Vector((0.6, -1.0, 0.1)).normalized(), HEAD_FRAME[2], "paint_%s_head.png" % outfit, 700)
        rig_obj.data.pose_position = "POSE"
        bpy.ops.wm.save_as_mainfile(filepath=os.path.join(WIP, "nim_%s.blend" % outfit))
    print("NIM", report)


def seam_fix(outfits=None):
    """Fill every unused texel of each outfit's colour and normal maps (and the mask's) from the islands' edges,
    so mipmaps never blend black into a seam. Saves the PNGs and repacks packed images. Run before `-- export`."""
    report = {}
    for outfit in outfits or OUTFITS:
        bpy.ops.wm.open_mainfile(filepath=os.path.join(WIP, "nim_%s.blend" % outfit))
        rig_obj = bpy.data.objects.get("Nim_%s_Rig" % outfit)
        if rig_obj:
            rig_obj.data.pose_position = "REST"
        for name in ("Nim_%s" % outfit, "Nim_%s_Mask" % outfit):
            o = bpy.data.objects.get(name)
            if o is None:
                continue
            imgs = {n.image for mat in o.data.materials if mat and mat.use_nodes
                    for n in mat.node_tree.nodes if n.type == "TEX_IMAGE" and n.image}
            first = next(iter(imgs))
            mask = seams.coverage(o, first)
            for img in imgs:
                filled, edge = seams.pad(img, mask)
                # Packed images live in the .blend (that's what the export reads); keep the PNG on disk in step.
                if img.filepath:
                    img.save(filepath=bpy.path.abspath(img.filepath))
                if img.packed_file:
                    img.pack()
                report["%s/%s" % (name, img.name)] = {"filled": filled, "edge_replaced": edge}
        if rig_obj:
            rig_obj.data.pose_position = "POSE"
        bpy.ops.wm.save_as_mainfile(filepath=os.path.join(WIP, "nim_%s.blend" % outfit))
    print("NIM", report)


def meshymask(outfits=None):
    report = {}
    for outfit in outfits or ["garb"]:
        bpy.ops.wm.open_mainfile(filepath=os.path.join(WIP, "nim_%s.blend" % outfit))
        obj = bpy.data.objects["Nim_%s" % outfit]
        rig_obj = bpy.data.objects["Nim_%s_Rig" % outfit]
        old = bpy.data.objects.get("Nim_%s_Mask" % outfit)
        if old:
            bpy.data.objects.remove(old)
        mk, report[outfit] = fit_meshy_mask(obj, rig_obj, outfit)
        head_c = Vector((0.0, HEAD_FRAME[0], HEAD_FRAME[1]))
        for tag, d in (("front", Vector((0, -1, 0))), ("side", Vector((1, 0, 0))), ("back", Vector((0, 1, 0))),
                       ("three", Vector((0.7, -1.0, 0.15)).normalized())):
            closeup(head_c, d, HEAD_FRAME[2], "mmask_%s_%s.png" % (outfit, tag), 700)
        rig_obj.data.pose_position = "POSE"
        bpy.ops.file.pack_all()
        bpy.ops.wm.save_as_mainfile(filepath=os.path.join(WIP, "nim_%s.blend" % outfit))
    print("NIM", report)


def _apply_all(o):
    bpy.ops.object.select_all(action="DESELECT")
    o.select_set(True)
    bpy.context.view_layer.objects.active = o
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    for m in list(o.modifiers):
        bpy.ops.object.modifier_apply(modifier=m.name)
    return o


def mask(outfits=None):
    """The garb's velvet muzzle (the suit has none). Renders head_<outfit>_mask_front/side and a back view."""
    report = {}
    for outfit in outfits or ["garb"]:
        bpy.ops.wm.open_mainfile(filepath=os.path.join(WIP, "nim_%s.blend" % outfit))
        obj = bpy.data.objects["Nim_%s" % outfit]
        rig_obj = bpy.data.objects["Nim_%s_Rig" % outfit]
        old = bpy.data.objects.get("Nim_%s_Mask" % outfit)
        if old:
            bpy.data.objects.remove(old)
        m, report[outfit] = build_mask(obj, rig_obj, outfit)
        bpy.ops.wm.save_as_mainfile(filepath=os.path.join(WIP, "nim_%s.blend" % outfit))
        head_c = Vector((0.0, HEAD_FRAME[0], HEAD_FRAME[1]))
        for tag, d in (("front", Vector((0, -1, 0))), ("side", Vector((1, 0, 0))), ("back", Vector((0, 1, 0))),
                       ("three", Vector((0.7, -1.0, 0.15)).normalized())):
            closeup(head_c, d, HEAD_FRAME[2], "mask_%s_%s.png" % (outfit, tag), 700)
    print("NIM", report)


def weights(outfits=None):
    report = {}
    for outfit in outfits or OUTFITS:
        bpy.ops.wm.open_mainfile(filepath=os.path.join(WIP, "nim_%s.blend" % outfit))
        obj = bpy.data.objects["Nim_%s" % outfit]
        rig_obj = bpy.data.objects["Nim_%s_Rig" % outfit]
        L = landmarks(obj)
        report[outfit] = skin(obj, rig_obj, L)
        test_pose(rig_obj, True)
        render_views(obj, "pose_%s" % outfit)
        test_pose(rig_obj, False)
        bpy.ops.wm.save_as_mainfile(filepath=os.path.join(WIP, "nim_%s.blend" % outfit))
    print("NIM", report)


# --- clips and export --------------------------------------------------------------------------------------------------
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import nim_poses  # noqa: E402  (tools/nim_poses.py: the Poser and her clips)
import seams  # noqa: E402  (tools/seams.py: texture seam repair)

OUT = os.path.join(ROOT, "assets", "characters", "nim")
SHEET_CELL = 300


def _sheet_frame(spec):
    """The frame a clip is shown at on the contact sheet: its most telling key (the middle one)."""
    frames = sorted(spec["keys"])
    return frames[len(frames) // 2] if len(frames) > 2 else frames[0]


def contact_sheet(obj, rig_obj, outfit, clips):
    """One cell per clip, three-quarter view, all on one image: .wip/nim/clips_<outfit>.png."""
    sc = bpy.context.scene
    sc.render.engine = "BLENDER_EEVEE"
    sc.render.resolution_x = sc.render.resolution_y = SHEET_CELL
    world = sc.world or bpy.data.worlds.new("w")
    sc.world = world
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs["Color"].default_value = (0.55, 0.53, 0.5, 1)
    cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
    cam.data.type = "ORTHO"
    cam.data.ortho_scale = 2.6
    sc.collection.objects.link(cam)
    sc.camera = cam
    d = Vector((0.75, -1.0, 0.25)).normalized()
    cam.location = Vector((0, 0, 0.95)) + d * 5
    cam.rotation_euler = (-d).to_track_quat("-Z", "Y").to_euler()
    sun = bpy.data.objects.new("sun", bpy.data.lights.new("sun", "SUN"))
    sun.data.energy = 2.5
    sun.rotation_euler = (-d + Vector((0, 0, -0.8))).to_track_quat("-Z", "Z").to_euler()
    sc.collection.objects.link(sun)
    ad = rig_obj.animation_data
    cols = 8
    rows = (len(clips) + cols - 1) // cols
    sheet = np.ones((rows * SHEET_CELL, cols * SHEET_CELL, 4), np.float32)
    tmp = os.path.join(WIP, "_cell.png")
    for n, name in enumerate(clips):
        ad.action = bpy.data.actions["%s_%s" % (outfit, name)]
        sc.frame_set(_sheet_frame(nim_poses.CLIPS[name]))
        sc.render.filepath = tmp
        bpy.ops.render.render(write_still=True)
        im = bpy.data.images.load(tmp)
        px = np.array(im.pixels[:], np.float32).reshape(SHEET_CELL, SHEET_CELL, 4)
        bpy.data.images.remove(im)
        r, c = divmod(n, cols)
        y0 = (rows - 1 - r) * SHEET_CELL     # image rows run bottom-up
        sheet[y0:y0 + SHEET_CELL, c * SHEET_CELL:(c + 1) * SHEET_CELL] = px
    ad.action = None
    out = bpy.data.images.new("sheet", cols * SHEET_CELL, rows * SHEET_CELL, alpha=True)
    out.pixels[:] = sheet.ravel()
    out.filepath_raw = os.path.join(WIP, "clips_%s.png" % outfit)
    out.file_format = "PNG"
    out.save()
    os.remove(tmp)
    bpy.data.objects.remove(cam)
    bpy.data.objects.remove(sun)


def clips(outfits=None):
    report = {}
    for outfit in outfits or OUTFITS:
        bpy.ops.wm.open_mainfile(filepath=os.path.join(WIP, "nim_%s.blend" % outfit))
        obj = bpy.data.objects["Nim_%s" % outfit]
        rig_obj = bpy.data.objects["Nim_%s_Rig" % outfit]
        report[outfit] = nim_poses.make_all(rig_obj, outfit)
        contact_sheet(obj, rig_obj, outfit, list(nim_poses.CLIPS))
        bpy.ops.wm.save_as_mainfile(filepath=os.path.join(WIP, "nim_%s.blend" % outfit))
    print("NIM", report)


def export(outfits=None):
    """assets/characters/nim/nim_<outfit>.glb: the rig, the skinned body with its face keys, one animation per clip
    (same names in both outfits)."""
    os.makedirs(OUT, exist_ok=True)
    report = {}
    for outfit in outfits or OUTFITS:
        bpy.ops.wm.open_mainfile(filepath=os.path.join(WIP, "nim_%s.blend" % outfit))
        obj = bpy.data.objects["Nim_%s" % outfit]
        rig_obj = bpy.data.objects["Nim_%s_Rig" % outfit]
        nim_poses.set_nla(rig_obj, outfit)
        for o in bpy.context.scene.objects:
            o.select_set(False)
        rig_obj.select_set(True)
        obj.select_set(True)
        # The garb's velvet muzzle travels as its own node (Nim_garb_Mask, on the head bone) so the game can hide it.
        mask_obj = bpy.data.objects.get("Nim_%s_Mask" % outfit)
        if mask_obj:
            mask_obj.select_set(True)
        bpy.context.view_layer.objects.active = rig_obj
        path = os.path.join(OUT, "nim_%s.glb" % outfit)
        bpy.ops.export_scene.gltf(filepath=path, export_format="GLB", use_selection=True, export_animations=True,
                                  export_animation_mode="NLA_TRACKS", export_skins=True, export_morph=True,
                                  export_yup=True, export_apply=False, export_force_sampling=True,
                                  export_image_format="AUTO")
        report[outfit] = round(os.path.getsize(path) / 1e6, 1)
        bpy.ops.wm.save_as_mainfile(filepath=os.path.join(WIP, "nim_%s.blend" % outfit))
    print("NIM MB", report)


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    stage = argv[0] if argv else "inspect"
    if stage == "clips":
        clips(argv[1:] or None)
    elif stage == "export":
        export(argv[1:] or None)
    elif stage == "clean":
        clean(argv[1:] or None)
    elif stage == "face":
        face(argv[1:] or None)
    elif stage == "headshots":
        headshots(argv[1:] or None)
    elif stage == "fingers":
        fingers(argv[1:] or None)
    elif stage == "paint":
        paint(argv[1:] or None)
    elif stage == "seams":
        seam_fix(argv[1:] or None)
    elif stage == "meshymask":
        meshymask(argv[1:] or None)
    elif stage == "mask":
        mask(argv[1:] or None)
    elif stage == "hands":
        hands(argv[1:] or None)
    elif stage == "weights":
        weights(argv[1:] or None)
    elif stage == "rig":
        rig(argv[1:] or None)
    else:
        {"inspect": inspect}[stage]()


if __name__ == "__main__":
    main()
