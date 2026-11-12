"""Nim's physical clips through Cascadeur (pilot: jump, fall, land). Headless Blender, stage by stage:

    blender -b --python tools/nim_cascadeur.py -- export [garb|suit]    rig + body to .wip/nim/cascadeur/nim_<o>.fbx

Cascadeur (via its MCP) imports the FBX, quick-rigs it, and one continuous jump is authored there at real gravity:
takeoff, rise, apex, fall, landing, then AutoPhysics. It comes back as an FBX animation (later stage).

The game's arc is not a real one: JUMP_HEIGHT 2.2 m in APEX_TIME 0.35 s (player/nim.gd) is ~3.7 g. Real gravity
reaches 2.2 m in ~0.67 s, so the take is authored at real timing and sped up by TIME_SCALE when it's sliced. The
clips are in place (the game moves her along the arc), so only the body's timing changes, never the path.
"""
import math
import os
import sys

import bpy

TOOLS = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, TOOLS)
ROOT = os.path.join(TOOLS, "..")
NIM = os.path.join(ROOT, ".wip", "nim")
WIP = os.path.join(NIM, "cascadeur")

JUMP_HEIGHT = 2.2
APEX_TIME = 0.35
REAL_APEX = math.sqrt(2 * JUMP_HEIGHT / 9.81)       # ~0.67 s
TIME_SCALE = APEX_TIME / REAL_APEX                   # ~0.52


def export(outfit):
    bpy.ops.wm.open_mainfile(filepath=os.path.join(NIM, "nim_%s.blend" % outfit))
    rig = bpy.data.objects["Nim_%s_Rig" % outfit]
    body = bpy.data.objects["Nim_%s" % outfit]
    rig.data.pose_position = "REST"
    if rig.animation_data:
        rig.animation_data.action = None
        for t in rig.animation_data.nla_tracks:
            t.mute = True
    for o in bpy.context.scene.objects:
        o.select_set(o in (rig, body))
    bpy.context.view_layer.objects.active = rig
    os.makedirs(WIP, exist_ok=True)
    path = os.path.join(WIP, "nim_%s.fbx" % outfit)
    bpy.ops.export_scene.fbx(filepath=path, use_selection=True, object_types={"ARMATURE", "MESH"},
                             add_leaf_bones=False, bake_anim=False, use_armature_deform_only=True,
                             mesh_smooth_type="FACE", apply_unit_scale=True, axis_forward="-Z", axis_up="Y",
                             path_mode="COPY", embed_textures=True)
    bones = [b.name for b in rig.data.bones]
    return {"path": path, "bones": len(bones), "names": bones}


# --- bake: the Cascadeur take back onto Nim's rig, sliced into the game's clips ------------------------------------
## Ported from Nine Lives' tools/cascadeur/bake_clip.py (same bone names; its lessons hold):
## - body bones are rebuilt down Nim's own hierarchy, so nothing stretches;
## - limbs take only their DIRECTION from Cascadeur, with roll inherited from the parent (taking Cascadeur's roll
##   whole corkscrews the arms and legs: its roll comes from box controllers nobody keys);
## - hands and toes follow their parents; fingers, tail and ears come from nim_poses' own clip specs;
## - quaternions stay on one hemisphere frame to frame.
## The spine chain too: its Cascadeur boxes are unkeyed, and their roll flipped spine, chest and head 180 degrees.
SWING = {"shoulder.L", "upper_arm.L", "forearm.L", "shoulder.R", "upper_arm.R", "forearm.R",
         "thigh.L", "shin.L", "foot.L", "thigh.R", "shin.R", "foot.R", "spine", "chest", "neck", "head"}
## Head and neck follow the chest: the take's head (a fallback pose on several frames) snapped up to 170 degrees.
FOLLOW = {"hand.L", "hand.R", "toe.L", "toe.R", "neck", "head"}
BODY = {"root", "hips", "spine", "chest", "neck", "head"} | SWING | FOLLOW
SRC_FPS = 30.0
GAME_FPS = 24.0
## Slices of the take (Cascadeur frames, from tools/cascadeur/nim_jump_poses.py) and their speed. In the air the
## game's arc runs TIME_SCALE faster than real gravity; on the ground time is real.
SLICES = {
    # The game launches on the press, so the crouch can't play before it: the jump starts at the push.
    # From just after takeoff: the forearms flip between 9 and 11 (unkeyed elbows in the air).
    "jump": dict(start=11, end=30, speed=1.0 / TIME_SCALE, air=True),
    # Ends on the reach (47), not the contact: the game holds the fall's last frame for a long drop.
    "fall": dict(start=30, end=47, speed=1.0 / TIME_SCALE, air=True),
    "land": dict(start=50, end=64, speed=1.0, air=False),
}
SUFFIX = "_c"     # garb_jump_c etc.: the Cascadeur versions sit beside the scripted ones until the owner picks


def _fcurves(act):
    return [fc for lay in act.layers for s in lay.strips for cb in s.channelbags for fc in cb.fcurves]


def bake(outfit, fbx=None):
    import nim_poses
    from mathutils import Matrix, Quaternion, Vector
    fbx = fbx or os.path.join(WIP, "nim_jump_take.fbx")
    bpy.ops.wm.open_mainfile(filepath=os.path.join(NIM, "nim_%s.blend" % outfit))
    rig = bpy.data.objects["Nim_%s_Rig" % outfit]
    home = bpy.context.window.scene if bpy.context.window else bpy.context.scene
    before = set(bpy.data.objects)
    bpy.ops.import_scene.fbx(filepath=fbx, automatic_bone_orientation=False, ignore_leaf_bones=False)
    new = [o for o in bpy.data.objects if o not in before]
    src = next(o for o in new if o.type == "ARMATURE")
    sc = bpy.context.scene
    rest = {b.name: b.matrix_local.copy() for b in rig.data.bones}
    order = []

    def walk(b):
        order.append(b.name)
        for c in b.children:
            walk(c)
    for b in rig.data.bones:
        if b.parent is None:
            walk(b)
    to_rig = rig.matrix_world.inverted() @ src.matrix_world
    to_rig3 = to_rig.to_3x3().normalized()

    def src_head(n):
        return to_rig @ src.pose.bones[n].head

    R = to_rig3.to_quaternion()
    src_rest = {b.name: R @ b.matrix_local.to_quaternion() for b in src.data.bones}

    def src_delta(n):
        """The bone's rotation away from its own rest, in rig space. Cascadeur's FBX gives the bones other axes
        than Nim's, so only this delta carries over (copying the rotation whole flipped the spine 180 degrees)."""
        return (R @ src.pose.bones[n].matrix.to_quaternion()) @ src_rest[n].inverted()

    # The owner's hand-built rig (nim_ap.casc) puts the pelvis where it belongs, on `hips`.
    pelvis = "hips"
    sc.frame_set(0)
    pelvis0 = src_head(pelvis).copy()
    rest_pelvis = rest["hips"].translation.copy()
    rig.animation_data_create()
    ad = rig.animation_data
    for t in ad.nla_tracks:
        t.mute = True
    report = {"pelvis_joint": pelvis}
    for clip, sl in SLICES.items():
        name = "%s_%s%s" % (outfit, clip, SUFFIX)
        if name in bpy.data.actions:
            bpy.data.actions.remove(bpy.data.actions[name])
        act = bpy.data.actions.new(name)
        act.use_fake_user = True
        ad.action = act
        for pb in rig.pose.bones:
            pb.rotation_mode = "QUATERNION"
        dur = (sl["end"] - sl["start"]) / SRC_FPS / sl["speed"]
        n_frames = max(2, int(round(dur * GAME_FPS)) + 1)
        # In the air the game carries her: take out the pelvis's own flight, keep only how it moves against a
        # straight line between the slice's ends (the tuck's lift, the reach).
        sc.frame_set(sl["start"])
        p_a = src_head(pelvis).copy()
        sc.frame_set(sl["end"])
        p_b = src_head(pelvis).copy()
        last = {}
        for c in range(n_frames):
            u = c / (n_frames - 1)
            sf = sl["start"] + u * (sl["end"] - sl["start"])
            sc.frame_set(int(math.floor(sf)), subframe=sf - math.floor(sf))
            if sl["air"]:
                delta = Vector((0, 0, 0))
                body_off = src_head(pelvis) - p_a.lerp(p_b, u)
                delta.z = max(-0.15, min(0.15, body_off.z)) * 0.3
            else:
                delta = src_head(pelvis) - pelvis0
                delta.x = 0.0
            M = {}
            for n in order:
                if n not in BODY:
                    continue
                b = rig.data.bones[n]
                if b.parent is None:
                    M[n] = rest[n].copy()
                    continue
                follow = M[b.parent.name] @ (rest[b.parent.name].inverted() @ rest[n])
                head = follow.translation + (delta if n == "hips" else Vector())
                if n in FOLLOW or n not in src.pose.bones:
                    q = follow.to_quaternion()
                elif n in SWING:
                    y0 = follow.to_quaternion() @ Vector((0, 1, 0))
                    y1 = src_delta(n) @ (rest[n].to_quaternion() @ Vector((0, 1, 0)))
                    q = y0.rotation_difference(y1) @ follow.to_quaternion()
                else:
                    q = src_delta(n) @ rest[n].to_quaternion()
                M[n] = Matrix.Translation(head) @ q.to_matrix().to_4x4()
                basis = (rest[b.parent.name].inverted() @ rest[n]).inverted() @ M[b.parent.name].inverted() @ M[n]
                loc, rot, _ = basis.decompose()
                if n in last and last[n].dot(rot) < 0:
                    rot.negate()
                last[n] = rot.copy()
                pb = rig.pose.bones[n]
                pb.rotation_quaternion = rot
                pb.keyframe_insert("rotation_quaternion", frame=1 + c, group=n)
                if n == "hips":
                    pb.location = loc
                    pb.keyframe_insert("location", frame=1 + c, group=n)
        # Tail, ears and fingers from the scripted clip's own spec, over the new length.
        spec = nim_poses.CLIPS[clip]
        P = nim_poses.Poser(rig)
        for f in range(1, n_frames + 1):
            t = (f - 1) / max(n_frames - 1, 1)
            ph = t * 2.0 * math.pi
            for i in range(nim_poses.TAIL_BONES):
                n = "tail.%d" % (i + 1)
                B = P.rest[n].to_quaternion()
                q = B.inverted() @ spec["tail"](i, ph) @ B
                if n in last and last[n].dot(q) < 0:
                    q.negate()
                last[n] = q.copy()
                pb = rig.pose.bones[n]
                pb.rotation_quaternion = q
                pb.keyframe_insert("rotation_quaternion", frame=f, group=n)
            for s in nim_poses.SIDES:
                pb = rig.pose.bones["ear." + s]
                pb.rotation_quaternion = Quaternion((1, 0, 0), math.radians(-spec["ears"](s, t)))
                pb.keyframe_insert("rotation_quaternion", frame=f, group=pb.name)
        for f in (1, n_frames):
            nim_poses._key_fingers(rig, clip, f, {})
        for fc in _fcurves(act):
            for kp in fc.keyframe_points:
                kp.interpolation = "BEZIER"
        report[clip] = {"frames": n_frames, "seconds": round(dur, 3), "pop": nim_poses.max_steps(act)}
    ad.action = None
    for t in ad.nla_tracks:
        t.mute = False
    for pb in rig.pose.bones:
        pb.rotation_quaternion = (1, 0, 0, 0)
        pb.location = (0, 0, 0)
    for o in new:
        bpy.data.objects.remove(o)
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(NIM, "nim_%s.blend" % outfit))
    return report


def compare(outfit):
    """Side by side, three-quarter view: each clip's scripted version (top row) and the Cascadeur one (bottom),
    six frames across: .wip/nim/cascadeur/compare_<clip>.png."""
    import numpy as np
    from mathutils import Vector
    import nim_build as nb
    bpy.ops.wm.open_mainfile(filepath=os.path.join(NIM, "nim_%s.blend" % outfit))
    rig = bpy.data.objects["Nim_%s_Rig" % outfit]
    ad = rig.animation_data
    for t in ad.nla_tracks:
        t.mute = True
    nb.WIP = WIP
    sc = bpy.context.scene
    tmp = os.path.join(WIP, "_cell.png")
    out = {}
    for clip in SLICES:
        rows = []
        for name in ("%s_%s" % (outfit, clip), "%s_%s%s" % (outfit, clip, SUFFIX)):
            act = bpy.data.actions[name]
            ad.action = act
            f0, f1 = act.frame_range
            cells = []
            for k in range(6):
                sc.frame_set(int(round(f0 + (f1 - f0) * k / 5)))
                nb.closeup(Vector((0, -0.05, 0.85)), Vector((0.8, -1.0, 0.15)).normalized(), 2.2, "_cell.png", 300)
                im = bpy.data.images.load(tmp)
                cells.append(np.array(im.pixels[:], np.float32).reshape(300, 300, 4))
                bpy.data.images.remove(im)
            rows.append(np.concatenate(cells, axis=1))
        sheet = np.concatenate(rows[::-1], axis=0)
        img = bpy.data.images.new("s", sheet.shape[1], sheet.shape[0], alpha=True)
        img.pixels[:] = sheet.ravel()
        img.filepath_raw = os.path.join(WIP, "compare_%s.png" % clip)
        img.file_format = "PNG"
        img.save()
        out[clip] = img.filepath_raw
    os.remove(tmp)
    return out


def use(outfit, which="c"):
    """Make the shipping clips (<outfit>_jump etc., what nim_poses.set_nla exports) the Cascadeur ones ("c") or
    the scripted ones ("k"). Both stay in the file: <outfit>_<clip>_k and <outfit>_<clip>_c."""
    bpy.ops.wm.open_mainfile(filepath=os.path.join(NIM, "nim_%s.blend" % outfit))
    acts = bpy.data.actions
    done = {}
    for clip in SLICES:
        ship, k, c = "%s_%s" % (outfit, clip), "%s_%s_k" % (outfit, clip), "%s_%s%s" % (outfit, clip, SUFFIX)
        if k not in acts:          # first swap: the scripted clip becomes _k
            acts[ship].name = k
        elif ship in acts:
            acts.remove(acts[ship])
        src = acts[c if which == "c" else k]
        new = src.copy()
        new.name = ship
        new.use_fake_user = True
        done[clip] = src.name
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(NIM, "nim_%s.blend" % outfit))
    return done


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    stage = argv[0] if argv else "export"
    outfit = argv[1] if len(argv) > 1 else "garb"
    print("NIMC", stage, outfit, {"export": export, "bake": bake, "compare": compare, "use": use}[stage](outfit), flush=True)


if __name__ == "__main__":
    main()
