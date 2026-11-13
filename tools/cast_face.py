"""The supporting cast's face keys (WO-012), ported from Nim's face stage (nim_build.py `-- face`). Imported by
cast_build.py: `-- face [body ...]`, after `paint` and before `export`.

Nim's face was measured by hand per outfit. The cast is 17 different Meshy heads, so each face is measured from its
own paint: every texel's rest-pose position is baked, and the eyes are the white of the sclera on the front of the
head, split left and right. The brows are the dark paint just above each eye (or a default band if none is painted).
Then Nim's `_blink` and `_brow` build the keys, unchanged:

    blink_L, blink_R    the upper lid slides down over the eye
    brow_up             both brows up (surprise, emphasis)
    brow_down           both brows down at the inner ends (a frown)

Renders build/face_<body>_{open,blink,brow_up,brow_down}.png check each one. The cast's meshes carry a 0.01 object
scale, so the keys are made in world space and converted to mesh space.
"""
import os

import bpy
import numpy as np
from mathutils import Vector

import nim_build as nb
import nim_paint as npaint
import seams

LUMA = npaint.LUMA
WINDOW = 0.06          # an eye's sclera lies within this of the side's median
GROW_X = 0.045         # the whole eye lies within this of its seed across...
GROW_Z = 0.032         # ...and up and down (the brows sit above that)
BROW = 0.012           # how far a brow travels (Nim's is 0.018 on a bigger, closer head)


def _bone(arm, name):
    return arm.matrix_world @ arm.data.bones[name].head_local


def measure(arm, mesh, seed=None, box=None):
    """`seed` (eye_x, eye_z): where the eyes are roughly, for heads whose fur is as white as a sclera."""
    img = seams._image_of(mesh)
    w, h = img.size
    import cast_paint
    tmp = cast_paint._main_only(mesh, img)
    used = seams.coverage(tmp, img).ravel()
    P = npaint.bake_positions(tmp, (w, h)).reshape(-1, 3)
    bpy.data.objects.remove(tmp)
    rgb = npaint._px(img)[..., :3].reshape(-1, 3)
    lum = rgb @ LUMA
    sat = rgb.max(1) - rgb.min(1)
    head = _bone(arm, "Head")
    vs = np.array([mesh.matrix_world @ v.co for v in mesh.data.vertices])
    hv = vs[vs[:, 2] > head.z]
    front = hv[:, 1].min()                        # the head's foremost point (her front is -Y)
    depth = hv[:, 1].max() - front
    # The front third of the head, above the head joint.
    zone = used & (P[:, 2] > head.z) & (P[:, 1] < front + depth * 0.4)
    white = zone & (lum > 0.70) & (sat < 0.13) & (rgb[:, 2] > rgb[:, 0] - 0.06)
    F = {"eyes": {}}
    rep = {}
    if box:
        # Measured by hand (white fur defeats the detector): {"L": (x, half), "R": (x, half), "z": (bottom, top),
        # optional "brow": (lo, hi)}.
        F["eyes"] = {"L": box["L"], "R": box["R"]}
        F["eye_bottom"], F["eye_top"] = box["z"]
        eh = F["eye_top"] - F["eye_bottom"]
        near = zone & (np.abs(np.abs(P[:, 0]) - box["L"][0]) < box["L"][1]) \
            & (P[:, 2] > F["eye_bottom"]) & (P[:, 2] < F["eye_top"])
        eye_y = float(np.median(P[near, 1]))
        F["face_y"] = (front - 0.05, eye_y + 0.05)
        F["brow"] = box.get("brow", (F["eye_top"] + 0.25 * eh, F["eye_top"] + 0.9 * eh))
        return F, {"box": "given", "eye_h": round(eh, 3), "brow_z": [round(c, 3) for c in F["brow"]]}
    # 1. A seed per eye: the sclera's cluster, if the two sides agree (white fur defeats it: Silke, Grizelda).
    seeds = {}
    for side, sign in (("L", 1), ("R", -1)):
        pts = P[white & (sign * P[:, 0] > 0.012)]
        for _ in range(3):                         # trim to the cluster round the median
            if len(pts) < 30:
                break
            m = np.median(pts, axis=0)
            pts = pts[np.linalg.norm(pts - m, axis=1) < WINDOW]
        if len(pts) >= 30:
            seeds[side] = np.median(pts, axis=0)
    ok = len(seeds) == 2 and abs(seeds["L"][0] + seeds["R"][0]) < 0.012 and abs(seeds["L"][2] - seeds["R"][2]) < 0.012
    if ok:
        rep["seed"] = "sclera"
    elif seed is not None:
        ex, ez = seed
        seeds = {"L": np.array([ex, 0, ez]), "R": np.array([-ex, 0, ez])}
        rep["seed"] = "given"
    else:
        return None, {"error": "no seed: sclera %s" % {k: [round(float(c), 3) for c in v] for k, v in seeds.items()}}
    # 2. The whole painted eye round each seed: white, the dark pupil and liner, the saturated iris.
    eyeish = zone & ((lum > 0.70) & (sat < 0.13) | (lum < 0.20) | (sat > 0.42))
    tops, bots, ys = [], [], []
    for side in ("L", "R"):
        s0 = seeds[side]
        win = eyeish & (np.abs(P[:, 0] - s0[0]) < GROW_X) & (np.abs(P[:, 2] - s0[2]) < GROW_Z)
        pts = P[win]
        if len(pts) < 30:
            return None, {"error": "no eye round the seed on side %s" % side}
        x0 = float(np.median(pts[:, 0]))
        lo, hi = np.percentile(pts[:, 0], [4, 96])
        a = float(max(hi - x0, x0 - lo)) * 1.05
        F["eyes"][side] = (x0, a)
        zb, zt = np.percentile(pts[:, 2], [4, 96])
        tops.append(zt)
        bots.append(zb)
        ys.append(np.median(pts[:, 1]))
        rep[side] = {"x": round(x0, 3), "half": round(a, 3), "z": [round(float(zb), 3), round(float(zt), 3)],
                     "texels": len(pts)}
    eh = float(np.mean(tops) - np.mean(bots))
    F["eye_top"] = float(np.mean(tops))
    F["eye_bottom"] = float(np.mean(bots))
    eye_y = float(np.mean(ys))
    F["face_y"] = (front - 0.05, eye_y + 0.05)
    # The brows: dark paint over each eye, up to 2.2 eye heights above its top.
    top = F["eye_top"]
    brow = np.zeros(len(P), bool)
    for side in ("L", "R"):
        x0, a = F["eyes"][side]
        brow |= zone & (np.abs(P[:, 0] - x0) < a) & (P[:, 2] > top + 0.003) & (P[:, 2] < top + 2.2 * eh) \
            & (lum < 0.22)
    if brow.sum() > 40:
        lo, hi = np.percentile(P[brow, 2], [5, 95])
        F["brow"] = (float(lo) - 0.004, float(hi) + 0.004)
        rep["brow"] = "painted"
    else:
        F["brow"] = (top + 0.25 * eh, top + 0.9 * eh)
        rep["brow"] = "default"
    rep["eye_h"] = round(eh, 3)
    rep["brow_z"] = [round(c, 3) for c in F["brow"]]
    return F, rep


def keys(mesh, F):
    """Shape keys from world-space deltas; mesh space is world / scale (the cast carries a uniform 0.01)."""
    M = mesh.matrix_world
    s = M.to_scale()[0]
    co = np.array([M @ v.co for v in mesh.data.vertices], np.float32)
    lid = nb.LID
    nb.LID = max(0.012, 0.6 * (F["eye_top"] - F["eye_bottom"]))   # the fur above the lid that slides with it
    try:
        k = {
            "blink_L": nb._blink(co, F, "L"), "blink_R": nb._blink(co, F, "R"),
            "brow_up": nb._brow(co, F, "L", BROW) + nb._brow(co, F, "R", BROW),
            "brow_down": nb._brow(co, F, "L", -BROW * 0.33, BROW * 0.8) + nb._brow(co, F, "R", -BROW * 0.33, BROW * 0.8),
        }
    finally:
        nb.LID = lid
    rep = {}
    me = mesh.data
    if me.shape_keys is None:
        mesh.shape_key_add(name="Basis", from_mix=False)
    base = np.empty(len(me.vertices) * 3, np.float32)
    me.vertices.foreach_get("co", base)
    for name, d in k.items():
        kb = me.shape_keys.key_blocks.get(name) or mesh.shape_key_add(name=name, from_mix=False)
        kb.data.foreach_set("co", (base + (d / s).ravel()).astype(np.float32))
        kb.value = 0.0
        rep[name] = int((np.abs(d).max(1) > 1e-5).sum())
    return rep


def renders(arm, mesh, body, F, folder):
    """Front close-ups of each key at full strength (the mask hidden)."""
    nb.WIP = folder
    mask = bpy.data.objects.get(body + "_Mask")
    if mask:
        mask.hide_render = True
    x = (F["eyes"]["L"][0] + F["eyes"]["R"][0]) / 2
    zc = (F["eye_top"] + F["brow"][1]) / 2
    c = Vector((x, 0.0, zc))
    width = (F["eyes"]["L"][0] - F["eyes"]["R"][0]) + 2 * F["eyes"]["L"][1] + 0.12
    kbs = mesh.data.shape_keys.key_blocks
    for name in ("open", "blink_L", "brow_up", "brow_down"):
        for kb in kbs[1:]:
            kb.value = 1.0 if kb.name == name or (name == "blink_L" and kb.name == "blink_R") else 0.0
        nb.closeup(c, Vector((0, -1, 0.05)).normalized(), width, "face_%s_%s.png" % (body, name), 400)
    for kb in kbs[1:]:
        kb.value = 0.0
    if mask:
        mask.hide_render = False
    return [os.path.join(folder, "face_%s_%s.png" % (body, n)) for n in ("open", "blink_L", "brow_up", "brow_down")]
