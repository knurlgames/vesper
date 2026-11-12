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
    obj.data.transform(Matrix.Scale(spec["h"] / obj.dimensions.z, 4))
    # Bounds from the vertices themselves: obj.bound_box is cached and still holds the unscaled mesh here.
    vs = [v.co for v in obj.data.vertices]
    shift = Vector(((min(v.x for v in vs) + max(v.x for v in vs)) / -2,
                    (min(v.y for v in vs) + max(v.y for v in vs)) / -2, -min(v.z for v in vs)))
    obj.data.transform(Matrix.Translation(shift))
    obj.data.update()
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
        path = os.path.join(src, name + ".glb")
        report[name] = clean_meshy(name, path, out) if os.path.exists(path) else "missing"
    print("PROPS", report)


if __name__ == "__main__":
    main()
