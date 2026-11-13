"""The enemies' model pipeline (WO-013), headless in Blender. It runs tools/cast_build.py's stages on the enemy roster:

    blender -b --python tools/enemy_build.py -- <stage> [body ...]     (no bodies = all of ENEMIES)

Stages, in order: prep, chains, fight (fighters only), clips, seams, export. Then face if wanted.
    fight   Meshy's library fight clips (`<body>_fight.glb`, one file with a clip per action, in FIGHT_ACTIONS order)
            become the actions combat_idle, jab, hit, knockdown on the body's rig.
Sources: .wip/enemies/raw/<body>_walk.glb, _run.glb, _fight.glb (Meshy auto-rig and animate; task ids in
.wip/meshy/wo013_*.json). Work files: .wip/enemies/build/<body>.blend. Output: assets/enemies/<who>/<body>.glb, where
<who> is the species (the body's first word).
"""
import os
import sys

import bpy

TOOLS = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, TOOLS)
import cast_build as cb  # noqa: E402

ROOT = os.path.join(TOOLS, "..")
cb.RAW = os.path.join(ROOT, ".wip", "enemies", "raw")
cb.WIP = os.path.join(ROOT, ".wip", "enemies", "build")
cb.OUT = os.path.join(ROOT, "assets", "enemies")

## Per body, as cast_build.BODIES: tail bones (0 = none worth rigging), ear bones, and whether it fights.
## The club's clients (WO-014b): Meshy library clips for a session and aftercare, as (action_id, our name, Meshy key).
## "kneel" is a kneel-and-stand transition: the game holds it at the kneel (EnemyModel.hold).
CLIENT_ACTIONS = [(365, "kneel", "Kneel_on_One_Knee_and_Stand"), (343, "drink", "Sit_and_Drink"),
                  (32, "sit", "Chair_Sit_Idle")]

ENEMIES = {
    "weasel_goon": {"tail": 0, "ears": False, "fights": True},       # the concept shows no tail; small round ears
    "badger_bouncer": {"tail": 0, "ears": False, "fights": True},
    "gull_lookout": {"tail": 0, "ears": False, "fights": False, "rope_low": True},
    "laffer": {"tail": 0, "ears": False, "fights": True},     # the ear search found his boater's brim
    "stoat_courier": {"tail": 5, "ears": True, "fights": False},
    # Primrose Close (batch 2).
    "bulldog_goon": {"tail": 0, "ears": False, "fights": True},
    "meerkat_watch": {"tail": 0, "ears": False, "fights": False},   # the search found 6 cm of tail on the floor
    "gander": {"tail": 0, "ears": False, "fights": True, "rope_low": True},   # the long neck rides Meshy's neck and head bones
    # The Docks (batch 3). All T-pose from the start.
    "rat_goon": {"tail": 7, "ears": False, "fights": True},
    "cormorant_lookout": {"tail": 0, "ears": False, "fights": False, "rope_low": True},
    "tusk": {"tail": 0, "ears": False, "fights": True},
    "stoat_customs": {"tail": 5, "ears": False, "fights": False, "rope_low": True},   # long neck: tie low
    # The Retreat (batch 4). Concepts drawn in a T-pose.
    "sheep_orderly": {"tail": 0, "ears": False, "fights": True},
    "heron_staff": {"tail": 0, "ears": False, "fights": False, "rope_low": True, "no_tape": True},
    "strix": {"tail": 0, "ears": False, "fights": True},
    # The Decency Press (batch 5). The Engine isn't a character: it's built separately.
    "mole_goon": {"tail": 0, "ears": False, "fights": True, "tape_taut": True},   # the star nose tore the tape
    "doberman_guard": {"tail": 0, "ears": False, "fights": True},
    "magpie_qc": {"tail": 0, "ears": False, "fights": False, "rope_low": True},
    "grubb": {"tail": 0, "ears": False, "fights": True, "tape_taut": True, "tape_drop": 0.2},   # his grin sits low
    # The Pier's people (WO-014 step 6): Madame Pearl and four civilians (the crowd, the prize winners, the prologue's
    # guest). Never bound (`never_bound`: no bound clip, no ropes); tails as cast_build finds them.
    "pearl_parrot": {"tail": 0, "ears": False, "fights": False, "never_bound": True},
    "otter_civilian": {"tris": 30000, "tail": 6, "ears": False, "fights": False, "never_bound": True, "tail_skip": 10},   # a thick tail that widens all the way to its root
    "hare_civilian": {"tris": 30000, "tail": 0, "ears": True, "fights": False, "never_bound": True},
    "fox_civilian": {"tris": 30000, "tail": 7, "ears": True, "fights": False, "never_bound": True, "tail_skip": 10},   # the white tuft is wider than the tail
    "hedgehog_civilian": {"tris": 30000, "tail": 0, "ears": False, "fights": False, "never_bound": True},
    # The club's clients in swimwear (WO-014b): the same four, with a kneel, sitting with tea, and sitting.
    "otter_swim": {"tris": 30000, "tail": 6, "ears": False, "fights": False, "never_bound": True, "tail_skip": 10,
                   "extra": CLIENT_ACTIONS},
    "fox_swim": {"tris": 30000, "tail": 7, "ears": True, "fights": False, "never_bound": True, "tail_skip": 10,
                 "extra": CLIENT_ACTIONS},
    "hare_swim": {"tris": 30000, "tail": 0, "ears": True, "fights": False, "never_bound": True, "extra": CLIENT_ACTIONS},
    "hedgehog_swim": {"tris": 30000, "tail": 0, "ears": False, "fights": False, "never_bound": True,
                      "extra": CLIENT_ACTIONS},
}
cb.BODIES = ENEMIES
cb.TAIL_SWAY["bound"] = 3.0      # a twitch, tied up

## Meshy library actions for a fighter (meshy_animate action_ids, in this order) and the names they get.
FIGHT_ACTIONS = [(89, "combat_idle"), (192, "jab"), (178, "hit"), (187, "knockdown")]
BASE_CLIPS = ["idle", "talk", "walk", "run", "bound"]


def _clips_for(body):
    base = [c for c in BASE_CLIPS if c != "bound"] if ENEMIES[body].get("never_bound") else BASE_CLIPS
    extra = [n for _, n, _ in ENEMIES[body].get("extra", [])]
    return base + ([n for _, n in FIGHT_ACTIONS] if ENEMIES[body]["fights"] else []) + extra


def extra(body):
    """A body's extra library clips (ENEMIES[body]["extra"]), from <body>_extra.glb (one meshy_animate file, one clip
    per action), matched by Meshy's key and renamed onto the body's rig."""
    want = ENEMIES[body].get("extra", [])
    if not want:
        return "no extra clips"
    arm, mesh = cb._open(body)
    before = set(bpy.data.actions)
    new = cb._import(os.path.join(cb.RAW, "%s_extra.glb" % body))
    acts = [a for a in bpy.data.actions if a not in before]
    got = {}
    for _, name, key in want:
        hit = [a for a in acts if key.lower() in a.name.lower()]
        if not hit:
            raise RuntimeError("extra clip %s not found in %s" % (key, [a.name for a in acts]))
        act = hit[0]
        old = bpy.data.actions.get(name)
        if old and old not in acts:
            bpy.data.actions.remove(old)
        got[name] = act.name
        act.name = name
        act.use_fake_user = True
    for o in new:
        bpy.data.objects.remove(o)
    bpy.ops.outliner.orphans_purge(do_recursive=True)
    cb._save(body)
    return {"clips": got, "ranges": {n: [round(f, 1) for f in bpy.data.actions[n].frame_range] for n in got}}


def fight(body):
    """Meshy's fight file: one armature, one action per library clip. Its actions move onto the body's rig (same
    skeleton and bone names: both come from the same rigging task)."""
    if not ENEMIES[body]["fights"]:
        return "not a fighter"
    arm, mesh = cb._open(body)
    before = set(bpy.data.actions)
    new = cb._import(os.path.join(cb.RAW, "%s_fight.glb" % body))
    acts = [a for a in bpy.data.actions if a not in before]
    # glTF names each action after its clip; keep Meshy's order (the order the ids were sent in).
    acts.sort(key=lambda a: a.name)
    got = {}
    for (aid, name), act in zip(FIGHT_ACTIONS, _ordered(acts)):
        old = bpy.data.actions.get(name)
        if old and old not in acts:
            bpy.data.actions.remove(old)
        got[name] = act.name
        act.name = name
        act.use_fake_user = True
    for o in new:
        bpy.data.objects.remove(o)
    bpy.ops.outliner.orphans_purge(do_recursive=True)
    cb._save(body)
    return {"clips": got, "ranges": {n: [round(f, 1) for f in bpy.data.actions[n].frame_range] for n in got}}


def _ordered(acts):
    """Meshy names multi-clip actions with the action key (Combat_Stance, Right_Jab_from_Guard, ...): order them
    to match FIGHT_ACTIONS by key."""
    keys = ["Combat_Stance", "Right_Jab_from_Guard", "Hit_Reaction", "Knock_Down"]
    out = []
    for k in keys:
        hit = [a for a in acts if k.lower() in a.name.lower() and not (k == "Hit_Reaction" and "_1" in a.name)]
        out.append(hit[0] if hit else None)
    if None in out:
        raise RuntimeError("fight clips not matched by key: %s" % [a.name for a in acts])
    return out


# --- armpits: Meshy's weights web the sleeve to the side when an arm goes overhead -----------------------------------
## Owner, on the Deck: "The under arms of the sleeves have some odd vertex weight that make them stretch out when the
## goons arms go up overhead." The armpit's vertices are split between the top spine bone and the arm with a hard
## edge between them, so a raised arm drags a web of shirt. Round each shoulder joint, the shoulder-area weights
## (Spine, the shoulder, the upper arm) are smoothed across the surface; each vertex keeps its total in those groups,
## so the rest of the skin is untouched.
ARMPIT_REACH = 1.0        # the region's radius, as a fraction of the upper arm's length
ARMPIT_PASSES = 200
ARMPIT_LAMBDA = 0.7


def armpits(body):
    import numpy as np
    arm, mesh = cb._open(body)
    arm.data.pose_position = "REST"
    bpy.context.view_layer.update()
    me = mesh.data
    n = len(me.vertices)
    co = np.array([mesh.matrix_world @ v.co for v in me.vertices])
    edges = np.array([e.vertices[:] for e in me.edges])
    rep = {}
    for side in ("Left", "Right"):
        names = ["Spine", side + "Shoulder", side + "Arm"]
        idx = {g.name: g.index for g in mesh.vertex_groups}
        if not all(nm in idx for nm in names):
            rep[side] = "missing groups"
            continue
        joint = np.array(cb._bone_world(arm, side + "Arm")[0])
        elbow = np.array(cb._bone_world(arm, side + "ForeArm")[0])
        reach = ARMPIT_REACH * np.linalg.norm(elbow - joint)
        d = np.linalg.norm(co - joint, axis=1)
        region = d < reach
        W = np.zeros((n, len(names)))
        for v in me.vertices:
            for g in v.groups:
                for k, nm in enumerate(names):
                    if g.group == idx[nm]:
                        W[v.index, k] = g.weight
        total = W.sum(1)
        active = region & (total > 1e-4)
        # Smooth inside the region; the boundary holds, so the result blends into the untouched skin. The falloff
        # keeps the full effect near the joint and none at the edge.
        fall = np.clip(1.0 - d / reach, 0.0, 1.0) ** 0.5
        a, b = edges[:, 0], edges[:, 1]
        for _ in range(ARMPIT_PASSES):
            acc = np.zeros_like(W)
            cnt = np.zeros(n)
            np.add.at(acc, a, W[b])
            np.add.at(acc, b, W[a])
            np.add.at(cnt, a, 1)
            np.add.at(cnt, b, 1)
            avg = acc / np.maximum(cnt, 1)[:, None]
            step = (ARMPIT_LAMBDA * fall)[:, None]
            Wn = W + step * (avg - W)
            W = np.where(active[:, None], Wn, W)
        # Each vertex keeps its old total in these groups.
        s = W.sum(1)
        W = np.where(s[:, None] > 1e-6, W * (total / np.maximum(s, 1e-6))[:, None], W)
        groups = [mesh.vertex_groups[nm] for nm in names]
        changed = 0
        for i in np.nonzero(active)[0]:
            for k, g in enumerate(groups):
                w = float(W[i, k])
                if w > 1e-3:
                    g.add([int(i)], w, "REPLACE")
                else:
                    g.remove([int(i)])
            changed += 1
        rep[side] = {"verts": changed, "reach": round(float(reach), 3)}
    arm.data.pose_position = "POSE"
    cb._save(body)
    return rep


# --- unbleed: arm weights on the hips and legs, leg weights on the arms ----------------------------------------------
## The real cause of the stretching sleeves (owner's Deck clip, 2026-11-12): Meshy's auto-rig weights the forearms
## and hands into the thighs and hips (and back), because in its A-pose the hands hang beside the hips. An arm going
## up then drags hip and waist vertices with it, and the hip drags the sleeve. Each vertex is classed by its nearest
## limb (distance to the bone chain over that limb's thickness): arm vertices lose leg weights, leg and torso
## vertices lose forearm and hand weights. What's left is renormalised. Run after `prep` (and `chains`).
ARMS = ["Arm", "ForeArm", "Hand"]
LEGS = ["UpLeg", "Leg", "Foot", "ToeBase"]


## Each vertex goes with its dominant limb, decided by its own weights (no geometry, which the hand fused to the hip
## defeats): mostly-arm vertices (Arm + ForeArm + Hand over half) drop their leg and hip weights; mostly-leg-or-hip
## vertices drop their forearm and hand weights. Anything in between (the shoulder, the waist) is left as it is.
## (Tried and rejected, 2026-11-12: smoothing the shoulder weights did nothing; classing by distance to the bones and
## by surface distance from the fingertip both tore the mesh far worse; Blender's bone heat finds no solution here.)


def unbleed(body):
    arm, mesh = cb._open(body)
    arm.data.pose_position = "REST"
    bpy.context.view_layer.update()
    me = mesh.data
    gname = {g.index: g.name for g in mesh.vertex_groups}
    groups = {g.name: g for g in mesh.vertex_groups}
    arms = {s + n for s in ("Left", "Right") for n in ARMS}
    hips_like = {"Hips"} | {s + n for s in ("Left", "Right") for n in LEGS}
    rep = {}
    fixed = {"arm_lost_hip_leg": 0, "body_lost_arm": 0}
    for v in me.vertices:
        ws = {gname[g.group]: g.weight for g in v.groups}
        a = sum(w for n, w in ws.items() if n in arms)
        lg = sum(w for n, w in ws.items() if n in hips_like)
        if a > 0.5 and lg > 0:
            drop = [n for n in ws if n in hips_like]
            tag = "arm_lost_hip_leg"
        elif lg > 0.5 and a > 0:
            drop = [n for n in ws if n.endswith(("ForeArm", "Hand"))]
            tag = "body_lost_arm"
        else:
            continue
        if not drop:
            continue
        keep = {n: w for n, w in ws.items() if n not in drop}
        tot = sum(keep.values())
        if tot < 1e-4:
            continue          # nothing else holds it: leave it rather than orphan it
        for n in drop:
            groups[n].remove([v.index])
        for n, w in keep.items():
            groups[n].add([v.index], w / tot, "REPLACE")
        fixed[tag] += 1
    rep.update(fixed)
    arm.data.pose_position = "POSE"
    cb._save(body)
    return rep


# --- bound: the tied-up pose and its ropes (owner: "we need bound variants of each of the goons") ---------------------
## A `bound` clip: sat on the ground, legs straight out and together, arms pulled behind the back, head down, a small
## struggle in a loop. Keyed with cast_build's world-axis rotations, so it works on any of Meshy's rigs. Then the
## Rope's red cord, built for this body in that pose and parented to its bones so it rides along: two turns round the
## chest pinning the arms, one round the ankles. They're exported in the GLB as `<body>_Ropes_*` (EnemyModel shows
## them only while he's bound).
import math  # noqa: E402

from mathutils import Matrix, Vector  # noqa: E402

ROPE_RED = (0.48, 0.08, 0.16, 1.0)       # Look.VELVET
ROPE_THICK = 0.022                        # the cord's radius (m)
ROPE_GAP = 0.012                          # clear of the body
ROPE_SNUG = 0.002                         # the ankle turn: cinched tight


def _translate(arm, name, v_world):
    bpy.context.view_layer.update()
    pb = arm.pose.bones[name]
    v = arm.matrix_world.inverted().to_3x3() @ v_world
    pb.matrix = Matrix.Translation(v) @ pb.matrix
    bpy.context.view_layer.update()


def _aim(arm, name, end_bone, want):
    """Swing a bone (about world axes, through its head) so the direction head->end_bone's head points along want."""
    bpy.context.view_layer.update()
    a = arm.matrix_world @ arm.pose.bones[name].head
    b = arm.matrix_world @ arm.pose.bones[end_bone].head
    axis, ang = (b - a).normalized().rotation_difference(want.normalized()).to_axis_angle()
    cb._rotate(arm, name, axis, math.degrees(ang))


def _bound_pose(arm, f, height):
    ph = 2 * math.pi * f / cb.LOOP
    hips = arm.matrix_world @ arm.pose.bones["Hips"].head
    _translate(arm, "Hips", Vector((0, 0.0, 0.16 * height - hips.z)))
    for s, side in (("Left", 1), ("Right", -1)):
        # Legs straight out in front (-Y), together.
        # Knees and ankles pressed together (tied, they touch): the thighs angle in, the shins come in further.
        _aim(arm, s + "UpLeg", s + "Leg", Vector((-side * 0.10, -1.0, -0.12)))
        _aim(arm, s + "Leg", s + "Foot", Vector((-side * 0.12, -1.0, -0.05)))
        # Arms pulled behind the back: the upper arm down and back, the forearm across behind the spine.
        _aim(arm, s + "Arm", s + "ForeArm", Vector((side * 0.25, 0.55, -0.8)))
        _aim(arm, s + "ForeArm", s + "Hand", Vector((-side * 0.9, 0.35, 0.05)))
    # The struggle: the shoulders twist, the head shakes and droops.
    cb._rotate(arm, "Spine01", Vector((0, 0, 1)), 4.0 * math.sin(ph))
    cb._rotate(arm, "Spine", Vector((1, 0, 0)), -6.0)
    cb._rotate(arm, "Head", Vector((1, 0, 0)), -12.0 + 3.0 * math.sin(2 * ph))
    cb._rotate(arm, "Head", Vector((0, 0, 1)), 9.0 * math.sin(2 * ph + 0.6))


## The cord (owner: "make the ropes Velvet and have some rope like texturing to them"): three strands twisted
## round each other, modelled into the surface (each strand bulges, with a groove between) so the twist shows in
## silhouette and in the toon light, and a small velvet texture lined up with the same twist: crimson crowns, dark
## grooves. ROPE_LAY is how far along the cord one strand takes to go once round it.
ROPE_STRANDS = 3
ROPE_LAY = 0.05             # metres per full turn of a strand
ROPE_BULGE = 0.22           # strand crown vs groove, as a fraction of the cord's radius
ROPE_TEX = 128
## Velvet: the Rope's crimson (Look.VELVET, #7a1428) on the strand crowns, near-black wine in the grooves.
ROPE_CROWN = (0x9c, 0x22, 0x3a)
ROPE_MID = (0x7a, 0x14, 0x28)
ROPE_GROOVE = (0x2e, 0x05, 0x0e)


def _rope_image():
    """The twist texture, made once per file: u runs along the cord (one tile per strand turn), v round it, so each
    strand is a slanting band. Packed into the .blend and exported in the GLB."""
    import numpy as np
    img = bpy.data.images.get("rope_velvet")
    if img:
        return img
    n = ROPE_TEX
    u, v = np.meshgrid(np.arange(n) / n, np.arange(n) / n)
    phase = (ROPE_STRANDS * v + u) % 1.0                  # one band per strand, slanting with the lay
    crown = np.cos(2 * np.pi * phase) * 0.5 + 0.5         # 1 on a strand's crown, 0 in the groove
    t = crown ** 0.7
    # Fine fibres along each strand: a little velvet nap.
    nap = 0.06 * np.sin(2 * np.pi * (ROPE_STRANDS * 8 * v + 9 * u))
    col = np.zeros((n, n, 3))
    for k in range(3):
        lo, mid, hi = ROPE_GROOVE[k] / 255, ROPE_MID[k] / 255, ROPE_CROWN[k] / 255
        c = np.where(t < 0.5, lo + (mid - lo) * (t / 0.5), mid + (hi - mid) * ((t - 0.5) / 0.5))
        col[..., k] = np.clip(c * (1.0 + nap), 0, 1)
    # sRGB in, the image's pixels are linear floats: convert.
    lin = np.where(col <= 0.04045, col / 12.92, ((col + 0.055) / 1.055) ** 2.4)
    rgba = np.concatenate([lin, np.ones((n, n, 1))], axis=2).astype(np.float32)
    img = bpy.data.images.new("rope_velvet", n, n, alpha=False)
    img.pixels.foreach_set(rgba.ravel())
    img.pack()
    return img


def _profile_at(profile, phi):
    """The loop's radius at angle phi, interpolated round the sectors (closed)."""
    n = len(profile)
    x = (phi / (2 * math.pi)) * n
    i = int(math.floor(x)) % n
    f = x - math.floor(x)
    return profile[i] * (1 - f) + profile[(i + 1) % n] * f


def _rope_mesh(name, profile):
    """A twisted three-strand loop in its own frame (centre at the origin, axis +Z), its centreline at
    `profile[sector]` from the axis (so it follows the body's outline), with UVs that tile the twist texture so its
    bands sit on the modelled strands."""
    import bmesh as bm_
    n_sec = len(profile)
    length = sum(2 * math.pi / n_sec * r for r in profile)
    turns = max(1, round(length / ROPE_LAY))               # whole turns, so the twist closes on itself
    # 6 rings per strand turn and 9 round (3 per strand) carry the twist; 10 x 12 put the big goons over budget.
    seg_major = max(48, turns * 6)
    seg_minor = 9
    me = bpy.data.meshes.new(name)
    bm = bm_.new()
    uv = bm.loops.layers.uv.new("UVMap")
    # The centreline and its frame: tangent along the loop, "out" in the loop's plane, +Z across it.
    centre = [Vector((_profile_at(profile, 2 * math.pi * i / seg_major) * math.cos(2 * math.pi * i / seg_major),
                      _profile_at(profile, 2 * math.pi * i / seg_major) * math.sin(2 * math.pi * i / seg_major), 0))
              for i in range(seg_major)]
    grid = []
    for i in range(seg_major + 1):
        p0 = centre[i % seg_major]
        tangent = (centre[(i + 1) % seg_major] - centre[(i - 1) % seg_major]).normalized()
        z = Vector((0, 0, 1))
        out = tangent.cross(z).normalized()
        if out.dot(p0) < 0:
            out = -out
        row = []
        for j in range(seg_minor + 1):
            th = 2 * math.pi * j / seg_minor
            along = turns * i / seg_major                   # strand turns so far
            phase = ROPE_STRANDS * th / (2 * math.pi) + along
            r = ROPE_THICK * (1.0 + ROPE_BULGE * math.cos(2 * math.pi * phase))
            p = p0 + out * (r * math.cos(th)) + z * (r * math.sin(th))
            row.append((p, (along, j / seg_minor)))
        grid.append(row)
    verts = [[bm.verts.new(p) if (i < seg_major and j < seg_minor) else None for j, (p, _) in enumerate(row)]
             for i, row in enumerate(grid)]
    for i in range(seg_major):
        for j in range(seg_minor):
            a = verts[i][j]
            b = verts[(i + 1) % seg_major][j]
            c = verts[(i + 1) % seg_major][(j + 1) % seg_minor]
            d = verts[i][(j + 1) % seg_minor]
            f = bm.faces.new((a, b, c, d))
            f.smooth = True
            for loop, (ii, jj) in zip(f.loops, ((i, j), (i + 1, j), (i + 1, j + 1), (i, j + 1))):
                loop[uv].uv = grid[ii][jj][1]
    bm.to_mesh(me)
    bm.free()
    return me


ROPE_SECTORS = 48
ROPE_SMOOTH = 2            # sectors either side averaged, so the cord runs smooth over lumps
ROPE_REACH = 1.6           # no sector past this times the loop's median radius


def _frame(axis):
    return Vector((0, 0, 1)).rotation_difference(axis.normalized())


def _profile(vs, centre, axis, half, near, pct=95, gap=ROPE_GAP):
    """The body's outline round `axis` through `centre`: per angular sector (in the loop's own frame), a high
    percentile of the distance of the posed vertices within `half` of the plane and `near` of the axis; empty sectors
    borrow their neighbours; then smoothed round the loop."""
    import numpy as np
    q = _frame(axis).inverted()
    buckets = [[] for _ in range(ROPE_SECTORS)]
    axis = axis.normalized()
    for v in vs:
        d = v - centre
        h = d.dot(axis)
        if abs(h) >= half:
            continue
        local = q @ (d - axis * h)
        r = local.length
        if r >= near:
            continue
        a = math.atan2(local.y, local.x) % (2 * math.pi)
        buckets[int(a / (2 * math.pi) * ROPE_SECTORS) % ROPE_SECTORS].append(r)
    raw = [float(np.percentile(b, pct)) if len(b) >= 3 else None for b in buckets]
    known = [r for r in raw if r is not None] or [0.1]
    # A limb that isn't part of the turn (Gander's feet, up at belly height with her legs out) mustn't drag the
    # cord out to it: no sector reaches past ROPE_REACH times the loop's median.
    cap = ROPE_REACH * float(np.median(known))
    raw = [min(r, cap) if r is not None else None for r in raw]
    known = [min(r, cap) for r in known]
    filled = []
    for i, r in enumerate(raw):
        if r is None:
            for k in range(1, ROPE_SECTORS):
                a, b = raw[(i - k) % ROPE_SECTORS], raw[(i + k) % ROPE_SECTORS]
                if a is not None or b is not None:
                    r = max(x for x in (a, b) if x is not None)
                    break
        filled.append(r if r is not None else max(known))
    sm = []
    for i in range(ROPE_SECTORS):
        w = [filled[(i + k) % ROPE_SECTORS] for k in range(-ROPE_SMOOTH, ROPE_SMOOTH + 1)]
        sm.append(max(filled[i], sum(w) / len(w)))     # never inside the body: smooth outward only
    return [r + gap + ROPE_THICK for r in sm]


def _ring(name, centre, axis, profile, parent_arm, bone, scale_obj):
    """A turn of twisted velvet cord following `profile` round the body: centre and axis in world space, parented
    to a bone, keeping its world transform."""
    ob = bpy.data.objects.new(name, _rope_mesh(name, profile))
    bpy.context.scene.collection.objects.link(ob)
    ob.location = centre
    ob.rotation_mode = "QUATERNION"
    ob.rotation_quaternion = _frame(axis)
    mat = bpy.data.materials.get("Rope") or bpy.data.materials.new("Rope")
    mat.diffuse_color = ROPE_RED
    mat.use_nodes = True
    nt = mat.node_tree
    bsdf = nt.nodes["Principled BSDF"]
    bsdf.inputs["Roughness"].default_value = 0.95
    tex = next((n for n in nt.nodes if n.type == "TEX_IMAGE"), None) or nt.nodes.new("ShaderNodeTexImage")
    tex.image = _rope_image()
    tex.interpolation = "Linear"
    nt.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
    ob.data.materials.append(mat)
    bpy.context.view_layer.update()
    mw = ob.matrix_world.copy()
    ob.parent = parent_arm
    ob.parent_type = "BONE"
    ob.parent_bone = bone
    ob.matrix_world = mw
    return ob


def _slab_radius(vs, centre, axis, half, near=0.35, pct=80):
    """The body's radius round `axis` through `centre`: a high percentile (not the max: one stray elbow or toe made
    the first rings hoops) of the posed vertices within `half` of that plane and `near` of the axis."""
    import numpy as np
    axis = axis.normalized()
    ds = []
    for v in vs:
        d = v - centre
        h = d.dot(axis)
        if abs(h) < half:
            r = (d - axis * h).length
            if r < near:
                ds.append(r)
    return float(np.percentile(ds, pct)) if ds else 0.1


## The velvet tape (owner, 2026-11-12: "to pair with the Kink and Velvet nature... I want them to also have their
## mouths wrapped in velvet 'tape' when they get tied up", then "Option 2... and keep the tape velvet"). The classic
## cartoon X: two short strips of the Rope's velvet crossed over the mouth, laid onto the face (each point projected
## straight back onto the skin from the front, so it follows the face without wrapping anything), skinned with the
## face's own weights, shown only while bound. (A band wrapped round the whole snout tore on whiskers and jowls.)
## It's the goons' comeuppance; the Rope's own masks never cover a mouth (ART_DIRECTION §1).
TAPE_LEN = 0.55            # each strip's length, as a fraction of the head's width
TAPE_WIDTH = 0.11          # each strip's width, as a fraction of the head's width
TAPE_ANGLE = 32.0          # degrees each strip leans off horizontal
TAPE_DROP = 0.10           # the X's centre below the nose tip, as a fraction of the head's width
TAPE_THICK = 0.003
TAPE_GAP = 0.004           # the first strip off the skin; the second sits on the first
TAPE_RED = (0.40, 0.05, 0.12, 1.0)


def _tape(arm, mesh, body):
    import numpy as np
    import bmesh as bm_
    from mathutils.bvhtree import BVHTree
    arm.data.pose_position = "REST"
    bpy.context.view_layer.update()
    joint = np.array(cb._bone_world(arm, "Head")[0])
    allv = [mesh.matrix_world @ v.co for v in mesh.data.vertices]
    P = np.array([p for p in allv if p.z > joint[2] and abs(p.x - joint[0]) < 0.3])
    if len(P) < 50:
        arm.data.pose_position = "POSE"
        return "no head"
    # The nose tip: the foremost point (front is -Y) of the head's lower 60% (a cap's peak juts further).
    top = P[:, 2].max()
    lower = P[P[:, 2] < joint[2] + 0.6 * (top - joint[2])]
    lower = lower if len(lower) >= 50 else P
    tip = lower[np.argmin(lower[:, 1])]
    width = float(np.percentile(lower[:, 0], 97) - np.percentile(lower[:, 0], 3))
    centre_x, centre_z = float(tip[0]), float(tip[2]) - TAPE_DROP * width
    dg = bpy.context.evaluated_depsgraph_get()
    be = mesh.evaluated_get(dg)
    bme = be.to_mesh()
    tree = BVHTree.FromPolygons([be.matrix_world @ v.co for v in bme.vertices], [pp.vertices for pp in bme.polygons])
    be.to_mesh_clear()
    front_y = float(tip[1]) - 0.3

    def onto_face(x, z, lift):
        """The skin under (x, z) seen from the front, lifted off it by `lift` along its normal."""
        hit, nor, _, _ = tree.ray_cast(Vector((x, front_y, z)), Vector((0, 1, 0)), 0.8)
        if hit is None:
            return None
        return hit + nor * lift

    n_len, n_wid = 12, 3
    old = bpy.data.meshes.get(body + "_Ropes_tape")
    if old and old.users == 0:
        bpy.data.meshes.remove(old)
    me = bpy.data.meshes.new(body + "_Ropes_tape")
    # A narrow beak (the birds) can't take the full-size X: try smaller and at the beak's own height until both
    # strips land.
    for scale, drop in ((1.0, ENEMIES[body].get("tape_drop", TAPE_DROP)), (0.8, 0.0), (0.55, 0.0), (0.4, -0.03)):
        bm = bm_.new()
        placed = _x_strips(bm, onto_face, centre_x, float(tip[2]) - drop * width, TAPE_LEN * width * scale,
                           TAPE_WIDTH * width * max(scale, 0.7), n_len, n_wid, ENEMIES[body].get("tape_taut", False))
        if placed == 2:
            break
        bm.free()
    else:
        arm.data.pose_position = "POSE"
        return "missed the face"
    L = TAPE_LEN * width * scale
    bm_.ops.recalc_face_normals(bm, faces=bm.faces)
    for f in bm.faces:
        f.smooth = True                   # flat shading showed the ray grid as stair steps
    bm.to_mesh(me)
    bm.free()
    return _tape_finish(arm, mesh, body, me, {"strips": placed, "head_w": round(width, 3), "len": round(L, 3),
                                                 "scale": scale})


def _taut(rows):
    """Stretch a strip over a bumpy muzzle (the mole's star nose, Grubb's snout) the way real tape goes: each row sits
    at its front-most hit across the width, and along the length the strip follows the front convex envelope, bridging
    the hollows instead of diving into them. Front is -Y, so the envelope is the lower hull of (row, y)."""
    ys = [min(p.y for p in r) for r in rows]
    hull = []
    for i, y in enumerate(ys):
        while len(hull) >= 2:
            (i0, y0), (i1, y1) = hull[-2], hull[-1]
            if (i1 - i0) * (y - y0) - (y1 - y0) * (i - i0) <= 0:
                hull.pop()
            else:
                break
        hull.append((i, y))
    env = []
    for i in range(len(rows)):
        for (i0, y0), (i1, y1) in zip(hull, hull[1:]):
            if i0 <= i <= i1:
                env.append(y0 + (y1 - y0) * (i - i0) / max(i1 - i0, 1))
                break
    return [[Vector((p.x, env[k], p.z)) for p in r] for k, r in enumerate(rows)]


def _x_strips(bm, onto_face, centre_x, centre_z, L, W, n_len, n_wid, taut=False):
    placed = 0
    for s, (sign, lift) in enumerate(((1.0, TAPE_GAP), (-1.0, TAPE_GAP + TAPE_THICK * 1.5))):
        ang = math.radians(sign * TAPE_ANGLE)
        u = (math.cos(ang), math.sin(ang))          # along the strip, in (x, z)
        v = (-math.sin(ang), math.cos(ang))         # across it
        grid = []
        for i in range(n_len + 1):
            row = []
            for j in range(n_wid + 1):
                a = (i / n_len - 0.5) * L
                b = (j / n_wid - 0.5) * W
                x = centre_x + a * u[0] + b * v[0]
                z = centre_z + a * u[1] + b * v[1]
                p = onto_face(x, z, lift)
                row.append(p)
            grid.append(row)
        # A strip end that runs off the face (past a narrow muzzle): trim it rather than leave it hanging.
        rows = [r for r in grid if all(p is not None for p in r)]
        if len(rows) < 6:
            continue
        if taut:
            rows = _taut(rows)
        outer = [[bm.verts.new(p) for p in r] for r in rows]
        # Thickness: a second skin along the view axis (toward the camera, i.e. -Y), closed at the edges.
        inner = [[bm.verts.new(p + Vector((0, TAPE_THICK, 0))) for p in r] for r in rows]
        for i in range(len(rows) - 1):
            for j in range(n_wid):
                bm.faces.new((outer[i][j], outer[i][j + 1], outer[i + 1][j + 1], outer[i + 1][j]))
                bm.faces.new((inner[i][j], inner[i + 1][j], inner[i + 1][j + 1], inner[i][j + 1]))
        for i in range(len(rows) - 1):
            for j in (0, n_wid):
                bm.faces.new((outer[i][j], outer[i + 1][j], inner[i + 1][j], inner[i][j]))
        for i in (0, len(rows) - 1):
            for j in range(n_wid):
                bm.faces.new((outer[i][j], inner[i][j], inner[i][j + 1], outer[i][j + 1]))
        placed += 1
    return placed


def _tape_finish(arm, mesh, body, me, rep):
    ob = bpy.data.objects.new(body + "_Ropes_tape", me)
    bpy.context.scene.collection.objects.link(ob)
    mat = bpy.data.materials.get("Tape") or bpy.data.materials.new("Tape")
    mat.diffuse_color = TAPE_RED
    mat.use_nodes = True
    mat.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = TAPE_RED
    mat.node_tree.nodes["Principled BSDF"].inputs["Roughness"].default_value = 0.95
    me.materials.append(mat)
    bpy.context.view_layer.update()
    mw = ob.matrix_world.copy()
    # Skinned with the face's own weights (copied from the nearest face of the body), so it moves with the skin.
    for g in mesh.vertex_groups:
        if g.name not in ob.vertex_groups:
            ob.vertex_groups.new(name=g.name)
    dt = ob.modifiers.new("weights", "DATA_TRANSFER")
    dt.object = mesh
    dt.use_vert_data = True
    dt.data_types_verts = {"VGROUP_WEIGHTS"}
    dt.vert_mapping = "POLYINTERP_NEAREST"
    dt.layers_vgroup_select_src = "ALL"
    dt.layers_vgroup_select_dst = "NAME"
    bpy.ops.object.select_all(action="DESELECT")
    ob.select_set(True)
    bpy.context.view_layer.objects.active = ob
    bpy.ops.object.modifier_apply(modifier="weights")
    ob.parent = arm
    ob.parent_type = "OBJECT"
    ob.matrix_world = mw
    am = ob.modifiers.new("Armature", "ARMATURE")
    am.object = arm
    arm.data.pose_position = "POSE"
    bpy.context.view_layer.update()
    return rep


def bound(body):
    arm, mesh = cb._open(body)
    for o in [o for o in bpy.data.objects if o.name.startswith(body + "_Ropes")]:
        bpy.data.objects.remove(o)
    arm.data.pose_position = "POSE"
    if arm.animation_data:
        arm.animation_data.action = None
    cb._reset_pose(arm)
    vs0 = cb._world_verts(mesh)
    height = max(v.z for v in vs0) - min(v.z for v in vs0)
    cfg = ENEMIES[body]
    cb._make_clip(arm, "bound", lambda a, f: _bound_pose(a, f, height), cfg["ears"])
    # Build the ropes on frame 0 of the clip, in the posed body.
    arm.animation_data.action = bpy.data.actions["bound"]
    bpy.context.scene.frame_set(0)
    bpy.context.view_layer.update()
    dg = bpy.context.evaluated_depsgraph_get()
    ev = mesh.evaluated_get(dg)
    me = ev.to_mesh()
    vs = [ev.matrix_world @ v.co for v in me.vertices]
    ev.to_mesh_clear()
    rep = {"height": round(height, 3)}
    # Chest: two turns between the two upper spine joints, axis along the spine, wrapping the pinned arms.
    s_lo = arm.matrix_world @ arm.pose.bones["Spine01"].head
    s_hi = arm.matrix_world @ arm.pose.bones["Spine"].head
    up = (s_hi - s_lo).normalized()
    neck = arm.matrix_world @ arm.pose.bones["neck"].head
    # Long-necked bodies (the birds) carry their neck joint low: their turns go round the belly instead, never
    # round the base of the neck (a rope at the throat reads as menace, not comedy).
    if cfg.get("rope_low"):
        s_lo = arm.matrix_world @ arm.pose.bones["Spine02"].head
        neck = s_hi
    for k, t in enumerate((0.35, 0.8)):
        c = s_lo + (neck - s_lo) * t * 0.85
        prof = _profile(vs, c, up, 0.03, near=0.7)
        _ring("%s_Ropes_chest%d" % (body, k), c, up, prof, arm, "Spine", mesh)
        rep["chest%d_r" % k] = [round(min(prof), 3), round(max(prof), 3)]
    # Ankles: one turn round both, axis along the legs.
    fl = arm.matrix_world @ arm.pose.bones["LeftFoot"].head
    fr = arm.matrix_world @ arm.pose.bones["RightFoot"].head
    kl = arm.matrix_world @ arm.pose.bones["LeftLeg"].head
    along = ((fl - kl) + (fr - arm.matrix_world @ arm.pose.bones["RightLeg"].head)).normalized()
    # Owner (badger clip): "the ropes around the ankles have a massive gap in them, they could be more snug". Tied at
    # the foot joint, the loop took in the boots' wide shafts. Instead: walk up the shins and tie at the slimmest
    # section, hugging it (a lower percentile, almost no clearance).
    knees = (kl + arm.matrix_world @ arm.pose.bones["RightLeg"].head) / 2
    feet = (fl + fr) / 2
    best = None
    for k in range(9):
        t = 0.06 + 0.05 * k                                  # 6% to 46% of the way from the feet to the knees
        cc = feet + (knees - feet) * t
        pp = _profile(vs, cc, along, 0.02, near=0.22, pct=85, gap=ROPE_SNUG)
        girth = sum(pp) / len(pp)
        if best is None or girth < best[0]:
            best = (girth, cc, pp)
    _, c, prof = best
    _ring("%s_Ropes_ankles" % body, c, along, prof, arm, "LeftLeg", mesh)
    rep["ankles_r"] = [round(min(prof), 3), round(max(prof), 3)]
    # Long thin bills (the heron's) have no face for the X: the rays land on the neck. Those bodies go without.
    rep["tape"] = "none (no_tape)" if cfg.get("no_tape") else _tape(arm, mesh, body)
    bpy.context.scene.frame_set(0)
    bpy.context.view_layer.update()
    # A check render: the bound pose, three-quarter.
    nb_ = cb.nb
    nb_.WIP = cb.WIP
    ws = vs
    lo = Vector((min(v.x for v in ws), min(v.y for v in ws), min(v.z for v in ws)))
    hi = Vector((max(v.x for v in ws), max(v.y for v in ws), max(v.z for v in ws)))
    nb_.closeup((lo + hi) / 2, Vector((0.7, -1.0, 0.45)).normalized(), max(hi - lo) * 1.2,
                "bound_%s.png" % body, 600)
    # And the cord close up (the twist and the velvet), at the front of the upper chest turn.
    ring = bpy.data.objects["%s_Ropes_chest1" % body]
    front = ring.matrix_world.translation + Vector((0, -1, 0)) * rep["chest1_r"][0]
    nb_.closeup(front, Vector((0.5, -1.0, 0.3)).normalized(), 0.3, "bound_%s_rope.png" % body, 500)
    arm.animation_data.action = None
    cb._reset_pose(arm)
    cb._save(body)
    return rep


def export(body):
    """cast_build's export, plus the rope objects."""
    arm, mesh = cb._open(body)
    folder = os.path.join(cb.OUT, cb._who(body))
    os.makedirs(folder, exist_ok=True)
    cb._set_nla(arm, cb.CLIPS)
    for o in bpy.context.scene.objects:
        o.select_set(o in (arm, mesh) or o.name.startswith(body + "_Ropes"))
    bpy.context.view_layer.objects.active = arm
    path = os.path.join(folder, "%s.glb" % body)
    bpy.ops.export_scene.gltf(filepath=path, export_format="GLB", use_selection=True, export_animations=True,
                              export_animation_mode="NLA_TRACKS", export_skins=True, export_morph=True,
                              export_yup=True, export_apply=False, export_force_sampling=True,
                              export_image_format="AUTO")
    return round(os.path.getsize(path) / 1e6, 1)


def run_stage(stage, body):
    if stage == "bound":
        cb.CLIPS = _clips_for(body)
        return bound(body)
    if stage == "export":
        cb.CLIPS = _clips_for(body)
        return export(body)
    if stage == "armpits":
        return armpits(body)
    if stage == "unbleed":
        return unbleed(body)
    cb.CLIPS = _clips_for(body)
    if stage == "fight":
        return fight(body)
    if stage == "extra":
        return extra(body)
    if stage == "clips":
        rep = cb.STAGES["clips"](body)
        # cast_build's clips stage keys idle and talk and layers walk and run; the fight clips are Meshy's own, kept
        # as they are. Re-set the NLA so the export carries every clip.
        arm, mesh = cb._open(body)
        cb._set_nla(arm, cb.CLIPS)
        cb._save(body)
        return rep
    return cb.STAGES[stage](body)


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    stage = argv[0] if argv else "prep"
    for body in argv[1:] or list(ENEMIES):
        print("ENEMY", stage, body, run_stage(stage, body), flush=True)


if __name__ == "__main__":
    main()
