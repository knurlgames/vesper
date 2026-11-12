"""Nim's paint pass (WO-011; owner's brief in ART_DIRECTION, hero pipeline step 4). Imported by nim_build.py:
`-- paint [garb|suit]`, run after `-- meshymask` and instead of `-- seams` (it pads too).

Works on the pristine bakes (`nim_<outfit>_color_preseams.png`), never on an already-padded map:
  1. bakes each texel's position on her body (rest pose), so the clouds are made in 3D and cross UV seams whole;
  2. finds her fur (light grey and cream) and the small dark dots inside it, and paints the dots out from the fur
     around them;
  3. paints clouded-leopard clouds on the grey fur: big irregular blotches, darker rims, lighter centres (3D
     cell noise, warped). Off the eyes, brows, muzzle front, cream fur, hands and the tail (its rings stay);
  4. garb only: flattens the clouds printed on the back of the bodysuit to plain cloth (the harness stays);
  5. the mask: removes light flecks on its dark velvet;
then pads the seams (tools/seams.py) and saves the PNGs. Everything that would be packed is reloaded from those PNGs
and packed fresh (repacking an edited image put the old pixels back: HANDOFF).
"""
import math
import os

import bpy
import numpy as np

import seams

LUMA = np.array([0.3, 0.59, 0.11])
FUR_LUM = 0.33          # grey fur and cream are lighter than this; her dots are darker
WARM = 0.022            # fur: red exceeds blue by this much (the cloth is cool grey)
FUR_SAT = 0.12
CREAM_LUM = 0.6
CLOSE_R = 6             # texels: a dot this small or smaller inside fur is part of the fur region
CELL = 0.1              # metres between cloud centres
WARP = 0.025            # metres of warp, so the clouds are irregular
GAP = 0.013             # metres of fur between neighbouring clouds
RIM = 0.007             # metres of dark rim inside each cloud's edge
KEEP = 0.8              # fraction of cells that get a cloud
CLOUD_RIM = np.array([0.15, 0.14, 0.13])
CLOUD_FILL = np.array([0.30, 0.285, 0.26])


def _px(img):
    w, h = img.size
    a = np.empty(w * h * 4, np.float32)
    img.pixels.foreach_get(a)
    return a.reshape(h, w, 4)


def bake_positions(obj, size):
    """Float image: each used texel's object-space position (rest pose)."""
    w, h = size
    pos = bpy.data.images.new("_pos", w, h, alpha=False, float_buffer=True)
    sc = bpy.context.scene
    sc.render.engine = "CYCLES"
    sc.cycles.device = "CPU"
    sc.cycles.samples = 1
    tmp = bpy.data.materials.new("_posmat")
    tmp.use_nodes = True
    nt = tmp.node_tree
    for n in list(nt.nodes):
        nt.nodes.remove(n)
    geo = nt.nodes.new("ShaderNodeNewGeometry")
    em = nt.nodes.new("ShaderNodeEmission")
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    nt.links.new(geo.outputs["Position"], em.inputs["Color"])
    nt.links.new(em.outputs[0], out.inputs[0])
    tex = nt.nodes.new("ShaderNodeTexImage")
    tex.image = pos
    nt.nodes.active = tex
    saved = [s.material for s in obj.material_slots]
    for s in obj.material_slots:
        s.material = tmp
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.bake(type="EMIT", margin=0, use_clear=True)
    for s, m in zip(obj.material_slots, saved):
        s.material = m
    p = _px(pos)[..., :3].copy()
    bpy.data.images.remove(pos)
    bpy.data.materials.remove(tmp)
    return p


def _box(a, r):
    """Box mean over (2r+1)^2, via an integral image."""
    c = np.pad(a, ((r + 1, r), (r + 1, r))).cumsum(0).cumsum(1)
    s = c[2 * r + 1:, 2 * r + 1:] - c[:-2 * r - 1, 2 * r + 1:] - c[2 * r + 1:, :-2 * r - 1] + c[:-2 * r - 1, :-2 * r - 1]
    return s / float((2 * r + 1) ** 2)


def _close(mask, r):
    """Morphological closing (dilate then erode) with a square of radius r."""
    d = _box(mask.astype(np.float32), r) > 0.0
    return _box(d.astype(np.float32), r) > 0.999


def _worley(p, seed=7):
    """F1, F2 distances to jittered cell points around each point p (n,3), and the kept flag of the nearest cell."""
    rng = np.random.default_rng(seed)
    table = rng.random((64, 64, 64, 4)).astype(np.float32)   # jitter xyz + keep, hashed by cell modulo 64
    cell = np.floor(p / CELL).astype(np.int64)
    f1 = np.full(len(p), 1e9, np.float32)
    f2 = np.full(len(p), 1e9, np.float32)
    keep = np.zeros(len(p), bool)
    size = np.zeros(len(p), np.float32)
    for dx in (-1, 0, 1):
        for dy in (-1, 0, 1):
            for dz in (-1, 0, 1):
                c = cell + np.array([dx, dy, dz])
                t = table[c[:, 0] % 64, c[:, 1] % 64, c[:, 2] % 64]
                fp = (c + t[:, :3]) * CELL
                d = np.linalg.norm(p - fp, axis=1).astype(np.float32)
                closer = d < f1
                f2 = np.where(closer, f1, np.minimum(f2, d))
                keep = np.where(closer, t[:, 3] < KEEP, keep)
                size = np.where(closer, (t[:, 0] * 7.3 + t[:, 2] * 3.1) % 1.0, size)
                f1 = np.where(closer, d, f1)
    return f1, f2, keep, size


def _warp(p):
    q = p.copy()
    for k, (a, b) in enumerate(((1, 2), (2, 0), (0, 1))):
        q[:, k] += WARP * np.sin(p[:, a] * 29.0 + 1.3 * k) * np.cos(p[:, b] * 23.0 - 0.7 * k)
    return q


EAR_R = 0.1       # metres around each ear's midline that count as ear (its dark back stays as painted)
EAR_DEPTH = 0.06  # how far behind the ear bone its midline runs


def _seg_dist(p, a, b):
    ab = b - a
    t = np.clip(((p - a) @ ab) / (ab @ ab), 0.0, 1.0)
    return np.linalg.norm(p - (a + t[:, None] * ab), axis=1)


def _features(pos, F, ears):
    """Painted features that must never be touched: eyes, lids and liner, brows, nose and mouth (all on the face's
    front only), and the ears (around their bones). `ears`: [(head, tail)] of the ear bones, as numpy arrays."""
    x, y, z = pos[:, 0], pos[:, 1], pos[:, 2]
    front = y < F["face_y"][0] + 0.18
    eye_z = (F["eye_top"] + F["eye_bottom"]) / 2
    bz = (F["brow"][0] + F["brow"][1]) / 2
    keep = np.zeros(len(pos), bool)
    for x0, a in F["eyes"].values():
        keep |= front & (((x - x0) / (a * 1.4)) ** 2 + ((z - eye_z) / 0.042) ** 2 < 1.0)     # eye, lids, liner
        keep |= front & (np.abs(x - x0) < a * 1.35) & (np.abs(z - bz) < 0.017)             # brow
    keep |= front & (np.abs(x) < 0.075) & (z < F["eye_bottom"]) & (z > F["chin"] - 0.03)   # nose, mouth
    for h, t in ears:
        down = h - (t - h) * 0.9                     # the ear runs well below its bone (the bone sits in its top)
        back = np.array([0.0, EAR_DEPTH, 0.0])          # the bone runs along the ear's front; its middle is behind
        keep |= _seg_dist(pos, down + back, t + (t - h) * 0.2 + back) < EAR_R
    return keep


def _no_cloud(pos, F, ears):
    """Where new clouds never go: the features, the face's front (around them), the hands, the tail."""
    x, y, z = pos[:, 0], pos[:, 1], pos[:, 2]
    face = (y < F["face_y"][0] + 0.2) & (np.abs(x) < 0.1) & (z < F["eye_top"])     # muzzle only: cheeks get clouds
    hands = (np.abs(x) > 0.3) & (z < 1.05) & (z > 0.7)
    tail = (z < 0.95) & ~((np.abs(x) < 0.2) & (y < 0.05))
    return _features(pos, F, ears) | face | hands | tail


NECK_Z = 1.37            # above this, everything on the body mesh is her head (the mask is its own object)
LOCAL_R = 14             # texels: the neighbourhood a spot is judged against
SPOT_DROP = 0.12        # a spot is this much darker than the fur around it
DOT_GROW = 3             # texels: an erased spot takes its soft edge with it
BACK_Z = (0.9, 1.42)    # the garb's upper back, where the clouds were printed on the cloth
PRINTED = (0.118, 0.245)  # luminance of the printed clouds: measured cloth ~0.26, harness 0.08-0.12


def _grow(mask, r):
    return _box(mask.astype(np.float32), r) > 0.0


def paint_body(obj, outfit, F, src_path, ears, tail=()):
    """Zones by baked position, not by colour (colour misreads: the cloth is as light as her fur, the printed
    clouds as warm). Head and the suit's neckline: spots out, clouds in. Garb's upper back: printed clouds out.
    Everything else (tail, hands, cord, boots) is left as Meshy painted it."""
    img = bpy.data.images.load(src_path, check_existing=False)
    w, h = img.size
    px = _px(img)
    rgb = px[..., :3].copy()
    used = seams.coverage(obj, img)
    pos = bake_positions(obj, (w, h))
    P = pos.reshape(-1, 3)
    x, y, z = P[:, 0], P[:, 1], P[:, 2]
    lum = rgb @ LUMA
    sat = rgb.max(axis=2) - rgb.min(axis=2)
    U = used.ravel()
    head = U & (z > NECK_Z)
    chest = U & (outfit == "suit") & (y < -0.05) & (z > 1.08) & (z < NECK_Z) & (np.abs(x) < 0.21)
    zone = (head | chest).reshape(lum.shape)
    protected = _features(P, F, ears).reshape(lum.shape)
    warm_t = (rgb[..., 0] - rgb[..., 2]) > 0.005
    # A spot is darker than the fur around it (grey fur ~0.45, cream ~0.7: one cutoff can't serve both).
    furish = zone & warm_t & (lum > 0.06)
    lit = (furish & (lum > FUR_LUM)).astype(np.float32)
    local = _box(lum * lit, LOCAL_R) / np.maximum(_box(lit, LOCAL_R), 1e-4)
    dark = furish & (sat < 0.15) & ((lum < local - SPOT_DROP) | (lum <= FUR_LUM))   # big spots have no fur nearby
    # Flecks: small specks of any colour (latex baked onto fur triangles) with fur all round them.
    fleck = zone & (lum < local - SPOT_DROP) & (_box(lit, 3) > 0.55) & ~(sat > 0.25)
    dark |= fleck
    grown = _grow(dark, DOT_GROW) & zone & ~protected
    light = zone & (lum > FUR_LUM) & ~protected & ~grown           # the fill source: clean fur only
    dots = grown
    rep = {"dots_px": int(dots.sum())}
    # 1. Spots out: fill from her light fur in the same zone.
    tmp = bpy.data.images.new("_tmp", w, h, alpha=True, float_buffer=True)
    tmp.pixels.foreach_set(px.ravel())
    seams.pad(tmp, light, grow_used=1)
    filled = _px(tmp)[..., :3]
    bpy.data.images.remove(tmp)
    rgb[dots] = filled[dots]
    # 2. Clouds in, on the grey fur of the zone (not cream, not the features, not the face's front).
    flat = rgb.reshape(-1, 3)
    grey = zone.ravel() & (flat @ LUMA < CREAM_LUM) & (flat @ LUMA > FUR_LUM - 0.05)
    ids = np.nonzero(grey)[0]
    p = P[ids]
    allowed = ~_no_cloud(p, F, ears)
    ids, p = ids[allowed], p[allowed]
    f1, f2, keep, size = _worley(_warp(p))
    radius = CELL * (0.3 + 0.15 * size)
    radius = np.minimum(radius, (f1 + f2) / 2 - GAP / 2)
    inside = keep & (f1 < radius)
    depth = radius - f1
    t = np.clip(depth / RIM, 0.0, 1.0)[:, None]
    soft = np.clip(depth / 0.0015, 0.0, 1.0)[:, None]
    col = CLOUD_RIM * (1 - t) + CLOUD_FILL * t
    sel = ids[inside]
    flat[sel] = flat[sel] * (1 - soft[inside]) + col[inside] * soft[inside]
    rep["cloud_px"] = int(inside.sum())
    # 3. Garb: printed clouds on the upper back become cloth (cloth ~0.40, clouds 0.19-0.26, harness under 0.1).
    if outfit == "garb":
        L = flat @ LUMA
        S = flat.max(axis=1) - flat.min(axis=1)
        # Behind her torso's centre (y = -0.09: her front is -Y).
        back = U & (y > -0.09) & (z > BACK_Z[0]) & (z < BACK_Z[1]) & (np.abs(x) < 0.24) & (S < 0.1)
        cloth = back & (L > 0.245) & (L < 0.30)
        med = np.median(flat[cloth], axis=0) if cloth.any() else np.array([0.4, 0.4, 0.4])
        hist = np.histogram(L[back], bins=12, range=(0.0, 0.48))[0].tolist()
        rep["back_hist_0_to_048"] = hist
        warm = flat[:, 0] - flat[:, 2]
        # The printed clouds are warm (Meshy painted her fur spots on the cloth); the harness is cool. Not the tail.
        near_tail = np.zeros(len(P), bool)
        for th, tt in tail:
            near_tail |= (_seg_dist(P, th, tt) < 0.06) & (P[:, 2] < 0.98)   # the tail starts below the belt
        core = back & (L > PRINTED[0]) & (L < PRINTED[1]) & (warm > 0.012) & (warm < 0.08) & ~near_tail
        # Take their soft edges too (less warm): grow 3 texels, never onto the harness or the tail.
        printed = _grow(core.reshape(lum.shape), 3).ravel() & back & (L > PRINTED[0]) & ~near_tail
        flat[printed] = med
        rep["cloth_med"] = [round(float(c), 3) for c in med]
        rep["printed_px"] = int(printed.sum())
    px[..., :3] = rgb
    img.pixels.foreach_set(px.ravel())
    rep["padded"] = seams.pad(img, used)[0]
    return img, rep


def clean_mask(mask_obj):
    """Light flecks on the dark velvet become velvet. Red piping (saturated) and brass (a big bright area) stay."""
    img = seams._image_of(mask_obj)
    px = _px(img)
    rgb = px[..., :3]
    lum = rgb @ LUMA
    sat = rgb.max(axis=2) - rgb.min(axis=2)
    dark = (lum < 0.12) & (sat < 0.15)
    around = _box(dark.astype(np.float32), 4)
    fleck = (~dark) & (around > 0.6) & (sat < 0.2) & (lum < 0.7)
    velvet = np.median(rgb[dark], axis=0)
    rgb[fleck] = velvet
    px[..., :3] = rgb
    img.pixels.foreach_set(px.ravel())
    return img, {"flecks_px": int(fleck.sum())}


def save_and_swap(obj, edited, path, replaces):
    """Save the edited pixels to path, load that file fresh, pack it, and put it in every texture node of obj that
    used `replaces`. (Repacking an edited image keeps the old pixels; a fresh load can't.)"""
    edited.filepath_raw = path
    edited.file_format = "PNG"
    edited.save()
    new = bpy.data.images.load(path, check_existing=False)
    new.pack()
    n_swapped = 0
    for mat in obj.data.materials:
        if mat and mat.use_nodes:
            for n in mat.node_tree.nodes:
                if n.type == "TEX_IMAGE" and n.image == replaces:
                    n.image = new
                    n_swapped += 1
    return new, n_swapped
