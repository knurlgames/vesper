"""Cleans Meshy prop downloads for the game (ART_DIRECTION.md, "Props"). Ported from Nine Lives' 3d/tools/intake_props.py
(the cleaning half, rewritten); none of its props or palette come with it.

For each prop in MESHY: import the raw GLB, join it into one mesh, scale it to its real height, put the origin at the
bottom centre, make it matte (Meshy's textures carry the paint; shine is only for what ART_DIRECTION.md says shines),
shrink the texture for small props, export it to assets/props/<name>.glb, and render a preview to .wip/props/previews.

Front is Blender -Y, which is +Z in Godot (Meshy's front already is -Y).

Run headless:
  blender --background --python tools/props.py -- <raw_dir> <out_dir> [names]
  e.g. blender -b --python tools/props.py -- .wip/props/meshy assets/props
Or exec() it through the Blender MCP with sys.argv set the same way.
"""
import math
import os
import sys

import bpy
from mathutils import Matrix, Vector

# Real height in metres; texture size (1K for small things); `shine` (metallic) only for latex, brass and wet things.
MESHY = {
    # The Old Quarter street corner (WO-002's style test).
    "gas_lamp": dict(h=3.6),
    "ad_column": dict(h=3.0),
    "bench": dict(h=0.95, tex=1024),
    # The Pier (WO-014 step 6). `l` scales by the longest side on the ground instead of the height.
    "arcade_cabinet": dict(h=1.85),
    "prize_box": dict(h=0.6, tex=1024),
    "crate": dict(h=0.9, tex=1024),
    "lifebuoy": dict(h=1.5, tex=1024),
    "deckchair": dict(h=0.95, tex=1024),
    "coaster_car": dict(l=2.3),
    "fortune_table": dict(h=1.15, tex=1024),
    "rowboat": dict(l=3.4),
    # The Velvet Rose (a Key, on screen), contraband in its box, and the toys the entranced hold (2026-11-12).
    "velvet_rose": dict(h=0.62, tex=1024),
    "contraband_box": dict(h=0.34, tex=1024),
    "toy_plush": dict(h=0.32, tex=512),
    "toy_wand": dict(h=0.34, tex=512),
    "toy_egg": dict(l=0.24, tex=512),
    "toy_tickler": dict(h=0.42, tex=512),
    # The Velvet Claw's vaults (WO-014b).
    "club_throne": dict(h=1.9),
    # Laffer's control desk on the Prize Hall's gallery (owner, 2026-11-14: "Fix the Laffer prop"; it was a red box).
    "laffer_desk": dict(h=1.2),
    "rope_frame": dict(h=2.6),
    "punch_bag": dict(h=2.2),
    "workbench": dict(h=1.6),
    "map_table": dict(h=1.7),   # with its lamp: the tabletop lands near 0.9 m
    "chaise": dict(l=2.0),
    "club_cross": dict(h=2.3),
    # Augusta's parlour (WO-014b, Deck review 3).
    "parlour_armchair": dict(h=1.2),
    "parlour_bookcase": dict(h=2.3),
    "parlour_cushion": dict(l=0.78, tex=1024),
    "parlour_mirror": dict(h=1.85),
    "parlour_tea_table": dict(h=0.9, tex=1024),   # the pot's lid at 0.9: the tabletop lands near 0.68
    "parlour_lamp": dict(h=1.75, tex=1024),
    # The Velvet Claw's lounge and front door (2026-11-13, owner: "the Velvet Claw also needs some art especially in
    # the lobby where you enter").
    "lounge_bar": dict(l=3.0),
    "bar_backshelf": dict(h=2.6),
    "bar_stool": dict(h=0.8, tex=1024),
    "lounge_sofa": dict(l=2.6),
    "cocktail_table": dict(h=0.75, tex=1024),
    "rope_stanchion": dict(h=1.0, tex=1024),
    "door_podium": dict(h=1.5, tex=1024),
    "chandelier": dict(h=1.3),
    "potted_palm": dict(h=2.0, tex=1024),
    # Primrose Close (WO-015 step 5).
    "garden_gnome": dict(h=0.55, tex=1024),
    "wheelie_bin": dict(h=1.07, tex=1024),
    "bird_bath": dict(h=0.85, tex=1024),
    "postbox": dict(h=1.6, tex=1024),
    "street_lamp": dict(h=5.0),
    "family_car": dict(l=4.2),
    "delivery_van": dict(l=5.0),
    "garden_shed": dict(h=2.4),
    "topiary_swan": dict(h=1.6, tex=1024),
    "garden_bench": dict(l=1.6, tex=1024),
    "prize_marrow": dict(l=1.1, tex=1024),
    "wheelbarrow": dict(l=1.5, tex=1024),
    "trestle_table": dict(l=2.0),
    "raffle_drum": dict(h=1.0, tex=1024),
    "folding_chair": dict(h=0.9, tex=512),
    "floral_sofa": dict(l=2.2),
    # The audit's buildings (2026-11-13, owner: "spruce up the houses and church hall ... so they aren't all just painted
    # boxes for the hub and first 2 levels"). Shells go over the greybox's collision; `fit` sizes them to it and `cut`
    # opens the doorways of the ones you walk into (frame: +Z the front, y up, origin on the ground at the middle).
    "pr_semi_render": dict(fit=(9.2, 9.6, 10.2)),
    "pr_semi_render_m": dict(fit=(9.2, 9.6, 10.2), mirror="pr_semi_render"),   # its door on its left
    # Mrs Gander's: 24 x 20, two storeys and the roof; her front door (x -1..1) and the conservatory door behind.
    # (Cuts run deep: a porch or bay stands proud of the wall the door's in.)
    # The walls just outside the game's (x ±12, z ±10.2 about its middle); the living room (ground floor) hollowed.
    "pr_show_home": dict(fit=(24.6, 10.6, 20.6), walls=(12.15, 10.35),
                         cut=[((0, 1.2, 10.35), (2.2, 2.4, 2.0)), ((0, 1.2, -10.35), (2.2, 2.4, 2.0))],
                         hollow=[((0, 1.7, 0), (21.6, 3.4, 12.0))]),
    # St. Prudence's hall: 28 x 28, its front (+Z) to Church Path (the world's -X). Its door is 8 m off the gable's
    # middle (world z -46), and the tower's door is in its north side (the model's -X, world x 64..66).
    # Its walls just outside the game's (±14.2 about the middle); the hall inside hollowed up to its ceiling (7 m).
    "pr_church_hall": dict(fit=(28.6, 10.8, 28.6), walls=(14.35, 14.35),
                           cut=[((-8.0, 1.6, 14.35), (3.6, 3.2, 3.0)), ((-14.35, 1.3, 3.0), (3.0, 2.6, 2.2))],
                           hollow=[((0, 3.5, 0), (27.6, 7.0, 27.6))]),
    "pr_spire": dict(h=10.0),
    "pr_vicarage": dict(fit=(12.2, 9.8, 10.2)),
    "pr_watch_hut": dict(fit=(2.8, 2.9, 2.4), tex=1024),
    "pr_greenhouse": dict(fit=(3.0, 3.2, 4.0), tex=1024),
    "pr_arch": dict(h=6.2),
    "hub_facade_brick": dict(h=12.0),
    "hub_facade_plaster": dict(h=12.0),
    "hub_facade_shop": dict(h=12.0),
    "padded_bench": dict(l=2.2, tex=1024),
    "rope_coil": dict(h=0.8, tex=512),
    "beach_hut": dict(h=3.6, tex=1024),
    "pier_booth": dict(l=8.0),
    "high_striker": dict(h=10.5, tex=1024),
    # Fitted to its walls (6 deep, 5 across), its plank door (the front, +Z) cut open over the game's doorway.
    "tackle_hut": dict(fit=(6.0, 3.6, 5.0), cut=[((0, 1.3, 2.5), (2.2, 2.6, 1.2))], hollow=[((0, 1.5, 0), (5.6, 2.9, 4.6))], tex=1024),
    "sea_railing": dict(l=2.0, tex=512),
    "pier_gate": dict(h=8.0),
    # Laffer's Fun Palace's front: 36 m across, over the front wall; the jester's mouth is its door (x -1.5..1.5).
    "pier_piling": dict(h=8.0, tex=512),
    # The Prize Hall's front over its front wall (44 x 16); its doorway (6 x 5) cut over the shutter.
    "prize_hall_front": dict(fit=(44.6, 19.0, 1.6), cut=[((0, 2.5, 0), (6.4, 5.1, 4.0))]),
    # The Velvet Claw: the whole club as a shell round its walls (22 x 22, 13.6 up), its walls just outside the game's,
    # the doorway (2 x 2.8) cut through. The game's walls stay, painted inside, hidden outside.
    "club_front": dict(fit=(23.0, 15.0, 23.0), walls=(11.08, 11.08), cut=[((0, 1.4, 11.08), (2.2, 2.85, 3.0))],
                       hollow=[((0, 7.0, 0), (21.6, 14.0, 21.6))]),   # nothing of it inside the game's walls
    "pr_semi_brick": dict(fit=(9.2, 9.6, 10.2)),
    "pr_semi_brick_m": dict(fit=(9.2, 9.6, 10.2), mirror="pr_semi_brick"),
    "funhouse_front": dict(fit=(36.4, 13.0, 1.4), cut=[((0, 1.6, 0), (3.2, 3.2, 4.0))]),
}

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
PREVIEWS = os.path.join(ROOT, ".wip", "props", "previews")


def clean_meshy(name, src, out_dir):
    spec = MESHY[name]
    _clear()
    for im in list(bpy.data.images):
        bpy.data.images.remove(im)
    bpy.ops.import_scene.gltf(filepath=src)
    meshes = [o for o in bpy.context.scene.objects if o.type == "MESH"]
    bpy.ops.object.select_all(action="DESELECT")
    for m in meshes:
        m.select_set(True)
    bpy.context.view_layer.objects.active = meshes[0]
    bpy.ops.object.parent_clear(type="CLEAR_KEEP_TRANSFORM")
    for o in [o for o in bpy.context.scene.objects if o.type != "MESH"]:
        bpy.data.objects.remove(o)
    if len(meshes) > 1:
        bpy.ops.object.join()
    obj = bpy.context.active_object
    obj.name = obj.data.name = name
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    if "fit" in spec:
        # Exactly this box (x, y up, z front; metres): a building shell fitted to its greybox, so `cut`s land on
        # the game's doorways.
        fx, fy, fz = spec["fit"]
        d = obj.dimensions
        obj.data.transform(Matrix.Diagonal((fx / d.x, fz / d.y, fy / d.z, 1.0)))
    elif "l" in spec:
        obj.data.transform(Matrix.Scale(spec["l"] / max(obj.dimensions.x, obj.dimensions.y), 4))
    else:
        obj.data.transform(Matrix.Scale(spec["h"] / obj.dimensions.z, 4))
    # Bounds from the vertices themselves: obj.bound_box is cached and still holds the unscaled mesh here.
    vs = [v.co for v in obj.data.vertices]
    shift = Vector(((min(v.x for v in vs) + max(v.x for v in vs)) / -2,
                    (min(v.y for v in vs) + max(v.y for v in vs)) / -2, -min(v.z for v in vs)))
    obj.data.transform(Matrix.Translation(shift))
    if spec.get("mirror"):
        obj.data.transform(Matrix.Diagonal((-1.0, 1.0, 1.0, 1.0)))
        obj.data.flip_normals()
    obj.data.update()
    # `walls`: (half x, half z) where the building's main walls must stand (game frame, +Z front). A porch, bays and
    # eaves stand proud of the walls, so fitting by the bounding box leaves the walls inset, inside the room the game
    # builds. The walls are found as the area-weighted commonest plane among faces turned to each side, and each axis
    # is scaled and shifted so they land where asked.
    if spec.get("walls"):
        _fit_walls(obj, spec["walls"])
    # `cut`: holes through a building shell where a doorway is, so the game's own door and the room behind show
    # through (an enterable building is a Meshy shell over the greybox walls). Each is (centre x, y up, z out front),
    # (width, height, depth) in metres in the game's frame (+Z the front); faces whose middle is inside go.
    if spec.get("cut"):
        import bmesh
        bm = bmesh.new()
        bm.from_mesh(obj.data)
        doomed = []
        for f in bm.faces:
            c = f.calc_center_median()
            gx, gy, gz = c.x, c.z, -c.y
            for (cx, cy, cz), (w, h, d) in spec["cut"]:
                if abs(gx - cx) < w / 2 and abs(gy - cy) < h / 2 and abs(gz - cz) < d / 2:
                    doomed.append(f)
                    break
        bmesh.ops.delete(bm, geom=doomed, context="FACES")
        bm.to_mesh(obj.data)
        bm.free()
        obj.data.update()
    # `hollow`: boxes (same form as `cut`) inside the building's rooms: whatever of the model reaches in there (window
    # reveals, the underside of a porch roof, inner faces) goes, so the game's own room shows.
    if spec.get("hollow"):
        _delete_in(obj, spec["hollow"])
    bpy.context.view_layer.update()
    for m in obj.data.materials:
        bsdf = next((n for n in m.node_tree.nodes if n.type == "BSDF_PRINCIPLED"), None)
        if bsdf:
            bsdf.inputs["Metallic"].default_value = spec.get("shine", 0.0)
            bsdf.inputs["Roughness"].default_value = 0.45 if spec.get("shine") else 0.85
        for n in m.node_tree.nodes:
            if n.type == "TEX_IMAGE" and n.image and spec.get("tex", 2048) < n.image.size[0]:
                n.image.scale(spec["tex"], spec["tex"])
                n.image.pack()
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.ops.export_scene.gltf(filepath=os.path.join(out_dir, name + ".glb"), use_selection=True, export_apply=True)
    preview(obj, os.path.join(PREVIEWS, name + ".png"))
    tris = sum(len(p.vertices) - 2 for p in obj.data.polygons)
    return {"tris": tris, "size": [round(d, 2) for d in obj.dimensions]}


def _plane(obj, axis, sign):
    """The area-weighted commonest coordinate (5 cm bins) of faces turned toward `sign` on `axis` (0 x, 1 y): a wall."""
    bins = {}
    for p in obj.data.polygons:
        if p.normal[axis] * sign > 0.85:
            c = p.center[axis]
            if c * sign > 0.0:
                k = round(c / 0.05)
                bins[k] = bins.get(k, 0.0) + p.area
    return max(bins, key=bins.get) * 0.05 if bins else None


def _fit_walls(obj, walls):
    hx, hz = walls
    # Game x is Blender x; game z is Blender -y.
    xl, xr = _plane(obj, 0, -1.0), _plane(obj, 0, 1.0)
    yb, yf = _plane(obj, 1, -1.0), _plane(obj, 1, 1.0)   # Blender -y is the front: yb (most negative) is game +z
    sx = 2.0 * hx / (xr - xl)
    sy = 2.0 * hz / (yf - yb)
    obj.data.transform(Matrix.Translation((-(xl + xr) / 2.0, -(yb + yf) / 2.0, 0.0)))
    obj.data.transform(Matrix.Diagonal((sx, sy, 1.0, 1.0)))
    obj.data.update()
    print("PROPS walls", obj.name, "found x", round(xl, 2), round(xr, 2), "y", round(yb, 2), round(yf, 2))


def _delete_in(obj, boxes):
    import bmesh
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    doomed = []
    for f in bm.faces:
        c = f.calc_center_median()
        gx, gy, gz = c.x, c.z, -c.y
        for (cx, cy, cz), (w, h, d) in boxes:
            if abs(gx - cx) < w / 2 and abs(gy - cy) < h / 2 and abs(gz - cz) < d / 2:
                doomed.append(f)
                break
    bmesh.ops.delete(bm, geom=doomed, context="FACES")
    bm.to_mesh(obj.data)
    bm.free()
    obj.data.update()


def preview(obj, path):
    sc = bpy.context.scene
    sc.render.engine = "BLENDER_EEVEE"
    sc.render.resolution_x = 700
    sc.render.resolution_y = 700
    world = sc.world or bpy.data.worlds.new("w")
    sc.world = world
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs["Color"].default_value = (0.6, 0.58, 0.55, 1)
    world.node_tree.nodes["Background"].inputs["Strength"].default_value = 0.9
    dims = obj.dimensions
    r = max(dims) * 1.9 + 0.6
    target = Vector((0, 0, dims.z * 0.5))
    cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
    sc.collection.objects.link(cam)
    cam.location = target + Vector((r * 0.6, -r * 0.85, r * 0.3))
    cam.rotation_euler = (target - cam.location).to_track_quat("-Z", "Y").to_euler()
    sc.camera = cam
    sun = bpy.data.objects.new("sun", bpy.data.lights.new("sun", "SUN"))
    sun.data.energy = 3.0
    sun.rotation_euler = (math.radians(50), 0, math.radians(30))
    sc.collection.objects.link(sun)
    sc.render.filepath = path
    bpy.ops.render.render(write_still=True)
    for o in (cam, sun):
        bpy.data.objects.remove(o)


def _clear():
    """Empty the scene without a factory reset, which would unload the MCP add-on in a live session."""
    if bpy.context.object and bpy.context.object.mode != "OBJECT":
        bpy.ops.object.mode_set(mode="OBJECT")
    for coll in (bpy.data.objects, bpy.data.meshes, bpy.data.materials, bpy.data.cameras, bpy.data.lights):
        for item in list(coll):
            coll.remove(item)
    bpy.context.scene.cursor.location = (0, 0, 0)


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    src = argv[0] if argv else os.path.join(ROOT, ".wip", "props", "meshy")
    out = argv[1] if len(argv) > 1 else os.path.join(ROOT, "assets", "props")
    os.makedirs(out, exist_ok=True)
    os.makedirs(PREVIEWS, exist_ok=True)
    report = {}
    for name in argv[2:] or list(MESHY):
        # `mirror`: a left-right mirror image of another prop's download (a house whose door must be on its other side).
        path = os.path.join(src, MESHY.get(name, {}).get("mirror", name) + ".glb")
        report[name] = clean_meshy(name, path, out) if os.path.exists(path) else "missing"
    print("PROPS", report)


if __name__ == "__main__":
    main()
