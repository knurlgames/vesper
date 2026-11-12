"""Texture seam repair for Meshy-sourced meshes (owner, 2026-11-11: "Meshy's models have artifacting around the seams").

Two causes, two fixes:
  1. Texels between UV islands hold junk (black, or a neighbour's colour). Mipmaps and bilinear filtering blend it
     in along every seam. Fix: `coverage()` finds the texels the mesh actually uses (a Cycles bake of white onto
     black, no margin); `pad()` fills everything else outward from the islands' own edge colours (push-pull), so
     a seam can only ever blend with itself.
  2. A decimate that ignores UV seams collapses triangles across them, and a few faces end up sampling the wrong
     island. Fix: decimate with delimit {'SEAM', 'UV'} (see `decimate_safe`).

Used by nim_build.py (`-- seams [garb|suit|mask]`); importable for any Meshy prop or cast member.
"""
import bpy
import numpy as np


def _image_of(obj):
    for mat in obj.data.materials:
        if mat and mat.use_nodes:
            for n in mat.node_tree.nodes:
                if n.type == "TEX_IMAGE" and n.image:
                    return n.image
    return None


def decimate_safe(obj, ratio):
    """Collapse decimate that never merges across a UV seam or island border."""
    dec = obj.modifiers.new("Decimate", "DECIMATE")
    dec.ratio = ratio
    dec.delimit = {"SEAM", "UV"}
    return dec


def coverage(obj, img):
    """A bool array (h, w): True where some face of obj samples the texel. Bakes white emission, margin 0."""
    w, h = img.size
    cov = bpy.data.images.new("_cov", w, h, alpha=False, float_buffer=False)
    cov.generated_color = (0, 0, 0, 1)
    sc = bpy.context.scene
    sc.render.engine = "CYCLES"
    sc.cycles.device = "CPU"
    sc.cycles.samples = 1
    mats = [s.material for s in obj.material_slots]
    tmp = bpy.data.materials.new("_covmat")
    tmp.use_nodes = True
    nt = tmp.node_tree
    for n in list(nt.nodes):
        nt.nodes.remove(n)
    em = nt.nodes.new("ShaderNodeEmission")
    em.inputs["Color"].default_value = (1, 1, 1, 1)
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    nt.links.new(em.outputs[0], out.inputs[0])
    tex = nt.nodes.new("ShaderNodeTexImage")
    tex.image = cov
    nt.nodes.active = tex
    for s in obj.material_slots:
        s.material = tmp
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.bake(type="EMIT", margin=0, use_clear=True)
    for s, m in zip(obj.material_slots, mats):
        s.material = m
    px = np.empty(w * h * 4, np.float32)
    cov.pixels.foreach_get(px)
    mask = px.reshape(h, w, 4)[..., 0] > 0.5
    bpy.data.images.remove(cov)
    bpy.data.materials.remove(tmp)
    return mask


DILATE = 16      # texels each island grows by its own colour (covers the mip levels the game actually uses)


def pad(img, mask, grow_used=2):
    """Fill every texel outside `mask` from the nearest used texels (push-pull over a mip pyramid).
    `grow_used` first shrinks the trusted area by a couple of texels: the island's own edge texels are often
    half-sampled junk from the source bake, and are better replaced too."""
    w, h = img.size
    px = np.empty(w * h * 4, np.float32)
    img.pixels.foreach_get(px)
    px = px.reshape(h, w, 4)
    trust = mask.copy()
    for _ in range(grow_used):
        t = trust.copy()
        t[1:, :] &= trust[:-1, :]
        t[:-1, :] &= trust[1:, :]
        t[:, 1:] &= trust[:, :-1]
        t[:, :-1] &= trust[:, 1:]
        trust = t
    # First, grow each island outward texel by texel from its own edge: what a seam can blend with, mip by mip,
    # is its own colour, never a neighbouring island's.
    known = trust.copy()
    rgb = np.where(known[..., None], px[..., :3], 0.0)
    for _ in range(DILATE):
        acc = np.zeros_like(rgb)
        cnt = np.zeros(known.shape, np.float32)
        for dy, dx in ((-1, 0), (1, 0), (0, -1), (0, 1), (-1, -1), (-1, 1), (1, -1), (1, 1)):
            k = np.roll(np.roll(known, dy, 0), dx, 1)
            acc += np.roll(np.roll(rgb, dy, 0), dx, 1) * k[..., None]
            cnt += k
        grow = (~known) & (cnt > 0)
        rgb[grow] = acc[grow] / cnt[grow][:, None]
        known |= grow
    # Then push-pull for whatever is still empty (far from any island): average down a pyramid, fill back up.
    levels = []
    col = rgb * known[..., None]
    wt = known.astype(np.float32)
    while min(col.shape[:2]) > 1:
        levels.append((col, wt))
        hh, ww = col.shape[0] // 2 * 2, col.shape[1] // 2 * 2
        c = col[:hh, :ww]
        k = wt[:hh, :ww]
        col = c[0::2, 0::2] + c[1::2, 0::2] + c[0::2, 1::2] + c[1::2, 1::2]
        wt = k[0::2, 0::2] + k[1::2, 0::2] + k[0::2, 1::2] + k[1::2, 1::2]
    filled = col / np.maximum(wt, 1e-6)[..., None]
    for c, k in reversed(levels):
        up = np.repeat(np.repeat(filled, 2, axis=0), 2, axis=1)
        up = np.pad(up, ((0, c.shape[0] - up.shape[0]), (0, c.shape[1] - up.shape[1]), (0, 0)), mode="edge")
        own = c / np.maximum(k, 1e-6)[..., None]
        filled = np.where((k > 0)[..., None], own, up)
    out = px.copy()
    out[..., :3] = np.where(trust[..., None], px[..., :3], np.where(known[..., None], rgb, filled))
    img.pixels.foreach_set(out.ravel())
    img.update()
    return int((~trust).sum()), int((mask & ~trust).sum())


def report(obj):
    """How much of the texture is used, and how dark the unused texels are (dark = visible seams)."""
    img = _image_of(obj)
    mask = coverage(obj, img)
    w, h = img.size
    px = np.empty(w * h * 4, np.float32)
    img.pixels.foreach_get(px)
    rgb = px.reshape(h, w, 4)[..., :3]
    lum = rgb @ np.array([0.3, 0.59, 0.11])
    used = rgb[mask].mean(axis=0) if mask.any() else None
    unused = lum[~mask]
    return {"size": [w, h], "used_frac": round(float(mask.mean()), 3),
            "unused_mean_lum": round(float(unused.mean()), 3) if unused.size else None,
            "unused_black_frac": round(float((unused < 0.02).mean()), 3) if unused.size else None,
            "used_mean_rgb": [round(float(x), 3) for x in used] if used is not None else None}, img, mask
