"""The supporting cast's paint step (WO-012). Imported by cast_build.py: `-- paint [body ...]`, after `graft` and
before `export`. Each body in PAINT gets its own jobs; bodies not listed are left as Meshy painted them.

Like Nim's paint pass (tools/nim_paint.py), zones are chosen by each texel's baked 3D position (rest pose), not by
colour alone: cloth and fur share tones. Only the body's main texture is painted (a grafted tail keeps its own).
The edited map is re-padded with `grow_used=0`. Every run paints from `<body>_prepaint.png` (the map as it was
before the first paint, saved then), so reruns are safe.

Jobs:
  sleeves   Vesper's garb: the bare spotted fur on her outer shoulders becomes sleeve cloth (her concept's front has
            sleeves; Meshy's side drew bare shoulders).
  unprint   Silke's garb: the rosettes printed on her trousers become plain cloth. Markings live on fur only.
  rosettes  Bastion's garb: jaguar rosettes (broken dark rings round a darker centre, some with a dot) on the tan fur
            of her head. Not on the cream muzzle, the eyes, brows or inner ears.
"""
import os

import bpy
import numpy as np
from mathutils import Vector

import nim_paint as npaint
import seams

LUMA = npaint.LUMA

PAINT = {
    "vesper_garb": ["sleeves"],
    "silke_garb": ["unprint"],
    "bastion_garb": ["rosettes"],
}

# Rosettes (metres): one per cell, ring radius and width, the gap between neighbours.
ROS_CELL = 0.07
ROS_RING = 0.0085
ROS_GAP = 0.010
ROS_DARK = np.array([0.10, 0.065, 0.04])
ROS_CENTRE = 0.82          # the fur inside a ring is this much darker
ROS_KEEP = 0.85


def _bone(arm, name, end=0):
    b = arm.data.bones[name]
    return np.array(arm.matrix_world @ (b.tail_local if end else b.head_local))


def _main_only(obj, img):
    """A temporary copy of obj with only the faces whose material samples `img` (a grafted tail is UV-mapped to
    another texture and would overwrite the position bake where the two layouts overlap)."""
    import bmesh
    keep = {i for i, m in enumerate(obj.data.materials)
            if m and m.use_nodes and any(n.type == "TEX_IMAGE" and n.image == img for n in m.node_tree.nodes)}
    tmp = obj.copy()
    tmp.data = obj.data.copy()
    bpy.context.scene.collection.objects.link(tmp)
    bm = bmesh.new()
    bm.from_mesh(tmp.data)
    bmesh.ops.delete(bm, geom=[f for f in bm.faces if f.material_index not in keep], context="FACES_ONLY")
    bm.to_mesh(tmp.data)
    bm.free()
    return tmp


def _rosettes(P, size_hash):
    """Per point: on a ring (dark), inside one (centre), on a centre dot. Worley cells warped a little."""
    q = P.copy()
    for k, (a, b) in enumerate(((1, 2), (2, 0), (0, 1))):
        q[:, k] += 0.008 * np.sin(P[:, a] * 61.0 + 1.3 * k) * np.cos(P[:, b] * 47.0 - 0.7 * k)
    rng = np.random.default_rng(11)
    table = rng.random((64, 64, 64, 4)).astype(np.float32)
    cell = np.floor(q / ROS_CELL).astype(np.int64)
    f1 = np.full(len(q), 1e9, np.float32)
    f2 = np.full(len(q), 1e9, np.float32)
    near = np.zeros((len(q), 3), np.float32)
    keep = np.zeros(len(q), bool)
    size = np.zeros(len(q), np.float32)
    for dx in (-1, 0, 1):
        for dy in (-1, 0, 1):
            for dz in (-1, 0, 1):
                c = cell + np.array([dx, dy, dz])
                t = table[c[:, 0] % 64, c[:, 1] % 64, c[:, 2] % 64]
                fp = (c + 0.15 + 0.7 * t[:, :3]) * ROS_CELL
                d = np.linalg.norm(q - fp, axis=1).astype(np.float32)
                closer = d < f1
                f2 = np.where(closer, f1, np.minimum(f2, d))
                near = np.where(closer[:, None], q - fp, near)
                keep = np.where(closer, t[:, 3] < ROS_KEEP, keep)
                size = np.where(closer, (t[:, 0] * 7.3 + t[:, 2] * 3.1) % 1.0, size)
                f1 = np.where(closer, d, f1)
    r = ROS_CELL * (0.26 + 0.12 * size)
    r = np.minimum(r, (f1 + f2) / 2 - ROS_GAP / 2 - ROS_RING / 2)
    ring = keep & (np.abs(f1 - r) < ROS_RING / 2)
    # Break each ring into 3-5 blotches: gaps by the angle round the cell point.
    ang = np.arctan2(near[:, 2], near[:, 0] + near[:, 1])
    lobes = 3 + (size * 3).astype(int)
    ring &= np.cos(ang * lobes + size * 6.0) > -0.75
    inside = keep & (f1 < r - ROS_RING / 2)
    dot = inside & (size > 0.5) & (f1 < 0.006)
    return ring, inside, dot


def _sleeves(rgb, P, used, arm, rep):
    """The outer shoulder and upper arm: warm fur (and the spots inside it) become the sleeve's cloth."""
    h, w = used.shape
    flat = rgb.reshape(-1, 3)
    U = used.ravel()
    lum = flat @ LUMA
    sat = flat.max(1) - flat.min(1)
    warm = flat[:, 0] - flat[:, 2]
    zone = np.zeros(len(P), bool)
    for s in ("Left", "Right"):
        sh, el = _bone(arm, s + "Arm"), _bone(arm, s + "ForeArm")
        d = npaint._seg_dist(P, sh - (el - sh) * 0.25, el)
        zone |= U & (d < 0.10)
    # Keep the torso (harness, chest) out: only what lies outside her shoulders' inner edge.
    sx = abs(_bone(arm, "LeftArm")[0])
    zone &= np.abs(P[:, 0]) > sx * 0.80
    fur = zone & (warm > 0.06) & (sat > 0.10) & (lum > 0.25)
    patch = npaint._close(fur.reshape(h, w), 6).ravel() & zone
    cloth = zone & ~patch & (sat < 0.06) & (lum > 0.06) & (lum < 0.30)
    med = np.median(flat[cloth], axis=0)
    flat[patch] = med
    rep["sleeve_px"] = int(patch.sum())
    rep["sleeve_cloth"] = [round(float(c), 3) for c in med]


def _unprint(rgb, P, used, arm, rep):
    """The trousers, hips to boots: anything darker than the cloth but lighter than the knee pads and boots
    becomes cloth. Not near the tail (its rosettes are fur)."""
    h, w = used.shape
    flat = rgb.reshape(-1, 3)
    U = used.ravel()
    lum = flat @ LUMA
    sat = flat.max(1) - flat.min(1)
    hips = _bone(arm, "Hips")
    zone = U & (P[:, 2] < hips[2] + 0.02) & (P[:, 2] > 0.12) & (np.abs(P[:, 0]) < 0.30)
    tails = sorted(b.name for b in arm.data.bones if b.name.startswith("tail."))
    for t in tails:
        zone &= npaint._seg_dist(P, _bone(arm, t), _bone(arm, t, 1)) > 0.09
    cloth = zone & (sat < 0.06) & (lum > 0.22) & (lum < 0.45)
    med = np.median(flat[cloth], axis=0)
    ml = float(med @ LUMA)
    rep["cloth"] = [round(float(c), 3) for c in med]
    rep["hist_0_to_06"] = np.histogram(lum[zone], bins=12, range=(0.0, 0.6))[0].tolist()
    core = zone & (lum < ml - 0.05) & (lum > 0.11) & (sat < 0.10)
    printed = npaint._grow(core.reshape(h, w), 2).ravel() & zone & (lum > 0.09) & (sat < 0.10)
    flat[printed] = med
    rep["printed_px"] = int(printed.sum())


def _paint_rosettes(rgb, P, used, arm, rep, F):
    """Jaguar rosettes on the head's tan fur."""
    flat = rgb.reshape(-1, 3)
    U = used.ravel()
    lum = flat @ LUMA
    sat = flat.max(1) - flat.min(1)
    neck = _bone(arm, "neck")
    tan = U & (P[:, 2] > neck[2]) & (flat[:, 0] > flat[:, 1]) & (flat[:, 1] > flat[:, 2]) \
        & (sat > 0.14) & (lum > 0.30) & (lum < 0.85)
    # The face's features: a box round the eyes and brows, the muzzle front.
    ex, ez, ny = F["eye_x"], F["eye_z"], F["nose_y"]
    eyes = (np.abs(np.abs(P[:, 0]) - ex) < 0.075) & (np.abs(P[:, 2] - ez - 0.02) < 0.06) & (P[:, 1] < ny + 0.12)
    muzzle = (np.abs(P[:, 0]) < 0.07) & (P[:, 2] < ez - 0.02) & (P[:, 1] < ny + 0.08)
    ids = np.nonzero(tan & ~eyes & ~muzzle)[0]
    ring, inside, dot = _rosettes(P[ids], None)
    flat[ids[inside]] *= ROS_CENTRE
    flat[ids[ring | dot]] = ROS_DARK
    rep["rosette_px"] = int((ring | dot).sum())
    rep["tan_px"] = int(len(ids))


def paint(body, arm, mesh, face):
    jobs = PAINT.get(body)
    if not jobs:
        return {"skipped": True}
    arm.data.pose_position = "REST"
    if arm.animation_data:
        arm.animation_data.action = None
    bpy.context.view_layer.update()
    img = seams._image_of(mesh)
    w, h = img.size
    tmp = _main_only(mesh, img)
    used = seams.coverage(tmp, img)
    pos = npaint.bake_positions(tmp, (w, h))
    bpy.data.objects.remove(tmp)
    P = pos.reshape(-1, 3)      # Geometry > Position bakes world space (the mesh objects carry a 0.01 scale)
    # Always paint from the pristine map: the first run keeps it as <body>_prepaint.png, so a rerun replaces the
    # earlier paint instead of stacking on it.
    folder = os.path.dirname(bpy.data.filepath)
    pristine = os.path.join(folder, "%s_prepaint.png" % body)
    if not os.path.exists(pristine):
        keep = img.copy()
        keep.filepath_raw = pristine
        keep.file_format = "PNG"
        keep.save()
        bpy.data.images.remove(keep)
    src = bpy.data.images.load(pristine, check_existing=False)
    px = npaint._px(src).copy()
    bpy.data.images.remove(src)
    rgb = px[..., :3].copy()
    rep = {"used_px": int(used.sum()), "z_range": [round(float(P[:, 2].min()), 2), round(float(P[:, 2].max()), 2)]}
    for job in jobs:
        if job == "sleeves":
            _sleeves(rgb, P, used, arm, rep)
        elif job == "unprint":
            _unprint(rgb, P, used, arm, rep)
        elif job == "rosettes":
            _paint_rosettes(rgb, P, used, arm, rep, face)
    px[..., :3] = rgb
    edited = bpy.data.images.new("_painted", w, h, alpha=True)
    edited.pixels.foreach_set(px.ravel())
    seams.pad(edited, used, grow_used=0)
    path = os.path.join(os.path.dirname(bpy.data.filepath), "%s_painted.png" % body)
    _, rep["swapped"] = npaint.save_and_swap(mesh, edited, path, img)
    arm.data.pose_position = "POSE"
    return rep
