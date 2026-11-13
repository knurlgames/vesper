"""Nim's clips (WO-011), posed by script on each outfit's rig. Imported by nim_build.py (`-- clips`, `-- export`).

The Poser is ported from Nine Lives (3d/tools/kiara_poses.py): knees and elbows come from two-bone IK, and every limb
only swings toward its target, keeping the roll it inherits from its parent (that stopped the corkscrewing there). The
poses themselves are Nim's own, authored here; none of Kiara's are reused.

A pose names where things go, not bone angles:
  pelvis      (dx, dy, dz) m, armature space (Blender: +X her left, -Y forward, +Z up)
  hips        (pitch, roll, yaw) deg about the hip joint; pitch + leans forward
  spine/chest/neck/head   (pitch, roll, yaw) deg on top of the parent
  ankle.L/R   offset from the rest ankle (m)
  foot.L/R    extra toe-down, deg, on top of the rest angle (negative lifts the toe: a heel strike)
  hand.L/R    wrist relative to the shoulder joint (m), mirrored: x is "outward"
  elbow.L/R   pole direction (outward, back, up), mirrored
  curl.L/R    the wrist bent forward (deg); shrug.L/R the shoulder up (deg)
  air         feet ride with the pelvis offset
  turn        deg: the whole body yaws about the vertical (+ turns her to her left), legs and arms with it
  grip.L/R    finger curl for this key (deg), over the clip's CLIP_GRIP
  frame       body frame: ankles, feet and hands are given as if she stood upright, and turn with her hips and
              chest. For the clips where she's on her back under a ceiling or head down on a wall.
The tail and ears are procedural (`tail`, `ears` per clip).
"""
import math

import bpy
from mathutils import Matrix, Quaternion, Vector

SIDES = {"L": 1.0, "R": -1.0}
TAIL_BONES = 7
FPS = 24
HAND_REST = (0.07, 0.01, -0.38)     # arms hanging, a soft bend (her reach, shoulder to wrist, is 0.42 m)
ELBOW_REST = (0.6, 1.0, -0.2)


def _q(pitch=0.0, roll=0.0, yaw=0.0):
    """Armature-space rotation: pitch about +X (forward lean), roll about -Y, yaw about +Z."""
    return (Quaternion((0, 0, 1), math.radians(yaw)) @ Quaternion((0, -1, 0), math.radians(roll))
            @ Quaternion((1, 0, 0), math.radians(pitch)))


def _ik(root, end, l1, l2, pole):
    d = end - root
    dist = d.length
    reach = l1 + l2 - 0.002
    if dist > reach:
        end = root + d * (reach / dist)
        d = end - root
        dist = reach
    dist = max(dist, abs(l1 - l2) + 0.01)
    axis = d.normalized()
    a = (l1 * l1 - l2 * l2 + dist * dist) / (2 * dist)
    h = math.sqrt(max(l1 * l1 - a * a, 0.0))
    p = (pole - axis * pole.dot(axis)).normalized()
    return root + axis * a + p * h, end


def _fcurves(act):
    return [fc for lay in act.layers for s in lay.strips for cb in s.channelbags for fc in cb.fcurves]


def _mat(t, q):
    return Matrix.Translation(t) @ q.to_matrix().to_4x4()


class Poser:
    def __init__(self, rig):
        self.k = rig
        self.rest = {b.name: b.matrix_local.copy() for b in rig.data.bones}
        self.len = {b.name: b.length for b in rig.data.bones}
        self.order = []

        def walk(b):
            self.order.append(b.name)
            for c in b.children:
                walk(c)
        for b in rig.data.bones:
            if b.parent is None:
                walk(b)
        # Each rig's own foot angle at rest (the suit stands in heels), so a pose's foot angle is on top of it.
        self.foot_rest = {}
        for s in SIDES:
            b = rig.data.bones["foot." + s]
            d = b.tail_local - b.head_local
            self.foot_rest[s] = math.degrees(math.atan2(-d.z, -d.y))

    def _follow(self, M, n):
        p = self.k.data.bones[n].parent.name
        return M[p] @ (self.rest[p].inverted() @ self.rest[n])

    def _swing(self, follow, target_dir):
        y0 = follow.to_quaternion() @ Vector((0, 1, 0))
        q = y0.rotation_difference(target_dir.normalized()) @ follow.to_quaternion()
        return _mat(follow.translation, q)

    def solve(self, pose):
        """Armature-space matrices for every body bone (not the tail or ears)."""
        M = {}
        rest = self.rest
        M["root"] = rest["root"].copy()
        f = self._follow(M, "hips")
        # `turn`: the whole body yaws about the vertical through her pelvis (feet, knees and hands with it), so a spin
        # pivots her instead of twisting the pelvis over planted feet. The pelvis offset is in the turned frame.
        qt = Quaternion((0, 0, 1), math.radians(pose.get("turn", 0.0)))
        pivot = Vector((f.translation.x, f.translation.y, 0.0))
        off = qt @ Vector(pose.get("pelvis", (0, 0, 0)))
        qh = qt @ _q(*pose.get("hips", (0, 0, 0)))
        M["hips"] = _mat(f.translation + off, qh @ f.to_quaternion())
        for n in ("spine", "chest", "neck", "head"):
            f = self._follow(M, n)
            M[n] = _mat(f.translation, _q(*pose.get(n, (0, 0, 0))) @ f.to_quaternion())
        frame = pose.get("frame", False)
        T = M["hips"] @ rest["hips"].inverted()                  # the pelvis's rigid move from rest
        Tc = (M["chest"] @ rest["chest"].inverted()).to_quaternion()
        for s, sign in SIDES.items():
            # Legs: the hip joint to an ankle target, the knee bending forward.
            M["thigh." + s] = f_th = self._follow(M, "thigh." + s)
            hip = f_th.translation
            rest_ankle = rest["foot." + s].translation
            o = Vector(pose.get("ankle." + s, (0, 0, 0)))
            knee_pole = Vector((sign * 0.12, -1.0, 0.0))
            if frame:
                ankle = T @ (rest_ankle + o)
                knee_pole = T.to_quaternion() @ knee_pole
            else:
                ankle = pivot + qt @ (rest_ankle + o - pivot) + (off if pose.get("air") else Vector())
                knee_pole = qh @ knee_pole
            knee, ankle = _ik(hip, ankle, self.len["thigh." + s], self.len["shin." + s], knee_pole)
            M["thigh." + s] = self._swing(f_th, knee - hip)
            M["shin." + s] = self._swing(self._follow(M, "shin." + s), ankle - knee)
            down = math.radians(self.foot_rest[s] + pose.get("foot." + s, 0.0))
            fwd = Vector((0, -math.cos(down), -math.sin(down)))
            if frame:
                fwd = T.to_quaternion() @ fwd
            else:
                fwd = qt @ fwd
            M["foot." + s] = self._swing(self._follow(M, "foot." + s), fwd)
            M["toe." + s] = self._follow(M, "toe." + s)
            # Arms: the shoulder rides the chest; the wrist target is relative to the shoulder joint, mirrored.
            sh = self._follow(M, "shoulder." + s)
            if pose.get("shrug." + s):
                sh = _mat(sh.translation, _q(0, -sign * pose["shrug." + s], 0) @ sh.to_quaternion())
            M["shoulder." + s] = sh
            f_ua = self._follow(M, "upper_arm." + s)
            S = f_ua.translation
            hx, hy, hz = pose.get("hand." + s, HAND_REST)
            ex, ey, ez = pose.get("elbow." + s, ELBOW_REST)
            v, pole = Vector((sign * hx, hy, hz)), Vector((sign * ex, ey, ez))
            if frame:
                v, pole = Tc @ v, Tc @ pole
            else:
                v, pole = qt @ v, qt @ pole
            elbow, H = _ik(S, S + v, self.len["upper_arm." + s], self.len["forearm." + s], pole)
            M["upper_arm." + s] = self._swing(f_ua, elbow - S)
            M["forearm." + s] = self._swing(self._follow(M, "forearm." + s), H - elbow)
            fh = self._follow(M, "hand." + s)
            curl = pose.get("curl." + s, 0.0)
            if curl:
                fh = _mat(fh.translation, fh.to_quaternion() @ Quaternion((1, 0, 0), math.radians(curl)))
            M["hand." + s] = fh
        return M

    def basis(self, M, n):
        b = self.k.data.bones[n]
        if b.parent is None:
            return self.rest[n].inverted() @ M[n]
        p = b.parent.name
        return (self.rest[p].inverted() @ self.rest[n]).inverted() @ M[p].inverted() @ M[n]


# --- the tail and ears -----------------------------------------------------------------------------------------------
def tail_fn(lift=30.0, curl=6.0, sway=8.0, bob=2.0, cycles=1.0, whip=0.0):
    """Armature-space rotation per tail segment (0 = the root): lifted back off her legs, each segment curled a little
    more toward the tip, and a sway that lags down the tail. `whip` adds a lash that runs out to the tip once."""
    def f(i, ph):
        if i == 0:
            return Quaternion((0, 0, 1), math.radians(4.0 * math.sin(ph * cycles))) @ \
                Quaternion((1, 0, 0), math.radians(lift + bob * math.sin(2 * ph * cycles)))
        taper = 0.6 + 0.4 * i / (TAIL_BONES - 1)
        lash = whip * math.sin(min(max(ph * 1.5 - 0.5 * i, 0.0), math.pi))
        return Quaternion((0, 0, 1), math.radians(sway * math.sin(ph * cycles - 0.6 * i) + lash)) @ \
            Quaternion((1, 0, 0), math.radians(curl * taper))
    return f


def ears_fn(back=0.0, flick=6.0, at=0.3):
    """Ear fold (deg, + folds back) and one quick flick of the left ear at `at` (0..1 through the clip)."""
    def f(side, t):
        a = back
        if side == "L" and flick:
            a += flick * max(0.0, 1.0 - abs(t - at) / 0.06)
        return a
    return f


# --- building blocks -------------------------------------------------------------------------------------------------
def _with(base, **kw):
    p = dict(base)
    for key, v in kw.items():
        p[key.replace("_L", ".L").replace("_R", ".R")] = v
    return p


def _mirror(pose):
    """The same pose on the other side (yaw and roll flip, x offsets flip)."""
    out = {}
    for k, v in pose.items():
        if k.endswith(".L") or k.endswith(".R"):
            k2 = k[:-1] + ("R" if k.endswith(".L") else "L")
            if k2.split(".")[0] in ("ankle",):
                v = (-v[0], v[1], v[2])
            out[k2] = v
        elif k in ("hips", "spine", "chest", "neck", "head"):
            out[k] = (v[0], -v[1], -v[2])
        elif k == "pelvis":
            out[k] = (-v[0], v[1], v[2])
        elif k == "turn":
            out[k] = -v
        else:
            out[k] = v
    return out


def _add(a, b):
    return tuple(x + y for x, y in zip(a, b))


def gait(frames, stride, lift, bob, lean=0.0, crouch=0.0, swing=0.12, sway=0.0, twist=0.0, cross=0.0,
         hand=HAND_REST, elbow=ELBOW_REST, curl=15.0, chest=0.0, head=0.0, run=False, extra=None):
    """A looping walk or run: two steps, the right foot striking at frame 1, the left halfway.
    A walk has contact and passing keys; a run adds a flight key between steps."""
    keys = {}
    step = frames // 2
    for half, (lead, back) in enumerate((("R", "L"), ("L", "R"))):
        f0 = 1 + half * step
        sl = SIDES[lead]
        sb = SIDES[back]
        base = {"hips": (lean, sway * sl, twist * sl), "chest": (chest, 0, -twist * sl * 1.5), "head": (head, 0, 0),
                "elbow.L": elbow, "elbow.R": elbow, "curl.L": curl, "curl.R": curl}
        if extra:
            base.update(extra)
        # The arm opposite the leading leg swings forward.
        fore, aft = _add(hand, (0, -swing, swing * 0.35)), _add(hand, (0, swing * 0.8, 0))
        contact = dict(base, **{
            "pelvis": (0.012 * sl if sway else 0.0, 0, -crouch - (bob * 0.4 if run else bob)),
            "ankle." + lead: (-sl * cross, -stride, 0.02), "foot." + lead: -18,
            "ankle." + back: (-sb * cross, stride * 0.75, 0.22 if run else 0.07), "foot." + back: 40,
            "hand." + back: fore, "hand." + lead: aft})
        passing = dict(base, **{
            "pelvis": (0.018 * sl if sway else 0.0, 0, -crouch + (-bob if run else bob)),
            "ankle." + lead: (-sl * cross, 0.04, 0.0), "foot." + lead: 0,
            "ankle." + back: (-sb * cross * 0.5, 0.02 if not run else 0.10, lift), "foot." + back: 20,
            "hand." + back: _add(hand, (0, -swing * 0.2, 0)), "hand." + lead: _add(hand, (0, swing * 0.2, 0))})
        if run:
            flight = dict(base, **{
                "pelvis": (0, 0, -crouch + bob),
                "ankle." + lead: (-sl * cross, stride * 0.6, 0.18), "foot." + lead: 45,
                "ankle." + back: (-sb * cross, -stride * 0.7, lift * 0.7), "foot." + back: 0,
                "hand." + back: _add(fore, (0, 0.03, 0)), "hand." + lead: aft})
            keys[f0] = contact
            keys[f0 + step // 3] = passing
            keys[f0 + 2 * step // 3] = flight
        else:
            keys[f0] = contact
            keys[f0 + step // 2] = passing
    keys[frames + 1] = None
    return keys


def _smooth01(e0, e1, x):
    t = min(max((x - e0) / (e1 - e0), 0.0), 1.0)
    return t * t * (3 - 2 * t)


def run_cycle(frames=14, reach=0.24, duty=0.30, crouch=0.06, bob=0.018, lift=0.26, kick=0.18, drive=0.10,
              lean=8.0, twist=6.0, arm=0.20, hand=(0.05, -0.02, -0.20), elbow=(0.3, 1.0, -0.4), curl=25.0,
              head=-6.0):
    """A run keyed on every frame from continuous curves (the gait() run was three keys a step, and its planted foot
    moved back at uneven speeds: owner, on the Deck, "Nim's running is way jerky").
    Per leg, phase 0..1 (the right leg half a cycle behind the left):
      stance (the first `duty`): the foot slides back from `reach` ahead to `reach` behind at a constant speed, so
        it stays put on the ground (ground speed 2*reach / (duty * cycle));
      swing: the leg trails out behind and the heel kicks up (`kick`), the foot tucks (`lift`), the knee drives
        through and the foot reaches past the landing spot (`drive`) before it comes back to land.
    The pelvis is lowest at each mid-stance and highest in the flight between; the hips twist with the legs, the
    chest against them, and the arms swing opposite the legs.
    Deck review 2 (owner, beside Dash's Meshy run: "still jittery"): the first version ran crouched with short,
    fast, small steps (it read as scurrying). This one is more upright, bobs half as much, cycles slower, and makes
    its stride big in the swing, where the leg isn't held to the ground: a long trail behind, a knee drive in front."""
    keys = {}
    tau = 2 * math.pi
    for k in range(frames):
        ph = k / frames
        pose = {"hips": (lean, 0.0, -twist * math.cos(tau * ph)), "chest": (4.0, 0.0, 1.4 * twist * math.cos(tau * ph)),
                "neck": (-4.0, 0.0, 0.0), "head": (head, 0.0, -0.4 * twist * math.cos(tau * ph)),
                "pelvis": (0.0, 0.0, -crouch - bob * math.cos(tau * (2 * ph - duty)))}
        for side, off in (("L", 0.0), ("R", 0.5)):
            p = (ph + off) % 1.0
            x = 0.0
            if p < duty:
                u = p / duty
                y, z = -reach + 2 * reach * u, 0.0
                foot = -5.0 + 45.0 * u * u               # flat on landing, rolling to the toe-off
            else:
                u = (p - duty) / (1.0 - duty)
                y = reach - 2 * reach * _smooth01(0.15, 0.95, u) + kick * math.sin(math.pi * min(u / 0.6, 1.0)) \
                    - drive * math.sin(math.pi * min(max((u - 0.4) / 0.6, 0.0), 1.0))
                # Peaks early (the tuck) and comes down gradually: a plain sine dropped 14 cm in the last frame.
                z = lift * math.sin(math.pi * u ** 0.65) ** 1.2
                foot = 50.0 * (1.0 - u) - 5.0 * u        # toe pointed off the ground, flat again to land
            pose["ankle." + side] = (x, y, z)
            pose["foot." + side] = foot
        # Arms opposite the legs: the right hand forward as the left foot reaches (phase 0).
        sw = math.cos(tau * ph)
        for side, sgn in (("R", -1.0), ("L", 1.0)):
            fwd = sgn * sw                              # -1: fully forward
            pose["hand." + side] = (hand[0], hand[1] + arm * fwd, hand[2] + 0.06 * max(0.0, -fwd))
            pose["elbow." + side] = elbow
            pose["curl." + side] = curl
        keys[k + 1] = pose
    keys[frames + 1] = None
    return keys


# --- her poses -------------------------------------------------------------------------------------------------------
# The night garb: a trainee's ready stance, weight forward on the balls of her feet, hands loose and near.
READY = {"pelvis": (0, 0.0, -0.03), "hips": (5, 0, 0), "spine": (2, 0, 0), "chest": (1, 0, 0), "neck": (-2, 0, 0),
         "head": (-3, 0, 4), "ankle.L": (0.04, -0.05, 0), "ankle.R": (-0.03, 0.05, 0),
         "hand.L": (0.06, -0.03, -0.36), "hand.R": (0.07, 0.0, -0.36), "curl.L": 18, "curl.R": 12}
# The suit: poised, a hip out, her right hand on her hip.
POISE = {"pelvis": (0.025, 0.0, -0.005), "hips": (0, 5, -4), "spine": (-1, -3, 0), "chest": (-3, -3, 6),
         "neck": (0, 2, 0), "head": (2, 4, -6), "ankle.L": (0.02, 0.02, 0), "ankle.R": (0.07, -0.08, 0.0),
         "foot.R": 6, "hand.R": (-0.04, 0.03, -0.29), "elbow.R": (1.0, 0.4, 0.0), "curl.R": -35,
         "hand.L": (0.08, 0.02, -0.38), "curl.L": 10}
AIR = {"air": True}
TUCK = {**AIR, "spine": (6, 0, 0), "head": (-6, 0, 0), "ankle.L": (0, -0.10, 0.34), "foot.L": 30,
        "ankle.R": (0, 0.02, 0.24), "foot.R": 35, "hand.L": (0.20, -0.14, 0.02), "hand.R": (0.22, -0.06, -0.06),
        "elbow.L": (0.6, 0.5, -0.8), "elbow.R": (0.6, 0.5, -0.8), "curl.L": 10, "curl.R": 10}
SPREAD = {**AIR, "spine": (-4, 0, 0), "head": (8, 0, 0), "ankle.L": (0.04, -0.06, 0.08), "foot.L": 30,
          "ankle.R": (-0.03, 0.08, 0.14), "foot.R": 35, "hand.L": (0.32, 0.02, 0.10), "hand.R": (0.30, 0.04, 0.14),
          "elbow.L": (0.2, 0.5, -1.0), "elbow.R": (0.2, 0.5, -1.0), "curl.L": 20, "curl.R": 20}
WALL = {"hips": (-4, 0, 0), "chest": (-6, 0, 0), "head": (-14, 0, 0)}     # on a wall: chest to it, looking up
# Under a ceiling, on her back: lying forward and rolled belly up, gripping above with hands and feet.
CEIL = {"frame": True, "pelvis": (0, 0.0, 0.55), "hips": (90, 180, 0), "head": (-30, 0, 0), "neck": (-20, 0, 0)}
# Head down a wall, chest to it.
HEADDOWN = {"frame": True, "pelvis": (0, 0.0, 0.25), "hips": (180, 0, 180), "head": (-25, 0, 0)}

CLIPS = {
    # --- standing ---
    "idle_garb": dict(loop=True, tail=tail_fn(lift=18, curl=8, sway=7, bob=2), ears=ears_fn(0, 8, 0.55), keys={
        1: READY,
        25: _with(READY, chest=(3, 0, 0), head=(-4, 0, -6), pelvis=(0, 0, -0.035), hand_L=(0.06, -0.04, -0.355)),
        49: _with(READY, chest=(1, 0, 0), head=(-2, 0, 8), hand_R=(0.07, 0.01, -0.365)),
        73: None}),
    "idle_suit": dict(loop=True, tail=tail_fn(lift=10, curl=10, sway=6, bob=1), ears=ears_fn(-2, 6, 0.7), keys={
        1: POISE,
        25: _with(POISE, chest=(-4, -3, 6), head=(1, 5, -10)),
        49: _with(POISE, chest=(-3, -2, 5), head=(3, 3, -2), hips=(0, 6, -4)),
        73: None}),
    # --- getting about ---
    "walk": dict(loop=True, tail=tail_fn(lift=20, curl=8, sway=5, bob=3, cycles=1), ears=ears_fn(0, 0),
                 keys=gait(24, 0.26, 0.10, 0.015, lean=3, swing=0.10, chest=1)),
    "prowl": dict(loop=True, tail=tail_fn(lift=8, curl=4, sway=6, bob=1, cycles=1), ears=ears_fn(-12, 0),
                  keys=gait(20, 0.30, 0.14, 0.01, lean=24, crouch=0.30, swing=0.06, hand=(0.12, -0.16, -0.27),
                            elbow=(0.8, 0.6, -0.3), curl=30, chest=6, head=-22, twist=4)),
    # Owner, on the Deck: "her hips jar back and forth and her knees look buckled to the side". The feet crossed 7 cm
    # past the midline (the IK could only reach it by bending the knees in), and the hips rocked 7 deg and twisted
    # 6 deg a step. Now a narrow line (2.5 cm), and half the rock and twist: poised, not knock-kneed.
    "strut": dict(loop=True, tail=tail_fn(lift=14, curl=10, sway=14, bob=2, cycles=1), ears=ears_fn(-3, 0),
                  keys=gait(24, 0.24, 0.09, 0.012, lean=-2, swing=0.07, sway=3.5, twist=3, cross=0.025, chest=-3,
                            head=2, extra={"hand.R": (-0.04, 0.03, -0.29), "elbow.R": (1.0, 0.4, 0.0),
                                           "curl.R": -35})),
    # Ground speed of the planted foot: 2 * 0.24 / (0.30 * 14/24 s) = 2.7 m/s (her leg is 0.73 m: a longer reach
    # locks the knee straight at touchdown and it snaps). nim_model's CLIP_SPEED["run"] is a little above it and
    # its playback is capped (RUN_SCALE_MAX), so at her top speed the cadence stays sane and the feet slide.
    # The tail's sway is per segment and adds up down its 7 bones: 9 deg twice a cycle swung the tip ~60 deg, which
    # flailed (owner, Deck review 2). Now 3 deg once a cycle: it streams out behind and drifts.
    "run": dict(loop=True, tail=tail_fn(lift=32, curl=3, sway=3, bob=2, cycles=1), ears=ears_fn(-15, 0),
                keys=run_cycle()),
    # --- the air ---
    "jump": dict(loop=True, tail=tail_fn(lift=55, curl=10, sway=6, bob=4, cycles=2), ears=ears_fn(-20, 0), keys={
        1: TUCK, 7: _with(TUCK, spine=(8, 0, 0), ankle_L=(0, -0.12, 0.36)), 13: None}),
    "fall": dict(loop=True, tail=tail_fn(lift=80, curl=10, sway=14, bob=4, cycles=2), ears=ears_fn(-25, 0), keys={
        1: SPREAD, 7: _with(SPREAD, hand_L=(0.30, 0.05, 0.16), hand_R=(0.33, 0.0, 0.08), ankle_L=(0.04, 0.0, 0.12),
                            ankle_R=(-0.03, 0.03, 0.08)), 13: None}),
    "land": dict(loop=False, tail=tail_fn(lift=30, curl=14, sway=6, bob=6), ears=ears_fn(-10, 0), keys={
        1: {"pelvis": (0, -0.02, -0.14), "hips": (14, 0, 0), "chest": (4, 0, 0), "head": (-8, 0, 0),
            "ankle.L": (0.04, -0.04, 0), "ankle.R": (-0.04, 0.04, 0),
            "hand.L": (0.24, -0.06, -0.26), "hand.R": (0.24, -0.06, -0.26), "curl.L": 20, "curl.R": 20},
        3: {"pelvis": (0, -0.04, -0.30), "hips": (28, 0, 0), "chest": (10, 0, 0), "neck": (-10, 0, 0),
            "head": (-10, 0, 0), "ankle.L": (0.04, -0.04, 0), "ankle.R": (-0.04, 0.04, 0),
            "hand.L": (0.16, -0.24, -0.34), "hand.R": (0.16, -0.22, -0.36), "elbow.L": (1.0, 0.3, 0.0),
            "elbow.R": (1.0, 0.3, 0.0), "curl.L": 35, "curl.R": 35, "shrug.L": 8, "shrug.R": 8},
        6: _with(READY, pelvis=(0, -0.02, -0.10), hips=(12, 0, 0)),
        9: READY}),
    # The pounce: she's already moving at full speed on the press (POUNCE_TIME 0.25 s = 6 frames), so there's no
    # crouch: frame 1 is the push-off, then a full stretch, claws out, a rake down, and she lands on him low.
    "pounce": dict(loop=False, tail=tail_fn(lift=-6, curl=2, sway=3, bob=1, cycles=1), ears=ears_fn(-35, 0),
                   ease={3: "out"}, keys={
        1: {"pelvis": (0, -0.08, -0.14), "hips": (50, 0, 0), "chest": (2, 0, 0), "neck": (-30, 0, 0),
            "head": (-18, 0, 0), "ankle.L": (0.04, 0.04, 0.02), "foot.L": 25, "ankle.R": (-0.04, 0.36, 0.08),
            "foot.R": 60, "hand.L": (0.12, -0.36, -0.04), "hand.R": (0.12, -0.34, -0.08),
            "elbow.L": (1.0, 0.2, 0.2), "elbow.R": (1.0, 0.2, 0.2), "curl.L": -30, "curl.R": -30,
            "grip.L": 0, "grip.R": 0},
        3: {**AIR, "pelvis": (0, -0.10, 0.04), "hips": (76, 0, 0), "chest": (0, 0, 0), "neck": (-38, 0, 0),
            "head": (-24, 0, 0), "ankle.L": (0.05, 0.52, 0.30), "foot.L": 55, "ankle.R": (-0.05, 0.56, 0.24),
            "foot.R": 58, "hand.L": (0.14, -0.44, 0.12), "hand.R": (0.12, -0.44, 0.10),
            "elbow.L": (1.0, 0.0, 0.6), "elbow.R": (1.0, 0.0, 0.6), "curl.L": -45, "curl.R": -45,
            "grip.L": 0, "grip.R": 0, "shrug.L": 10, "shrug.R": 10},
        5: {**AIR, "pelvis": (0, -0.08, 0.0), "hips": (60, 0, 0), "chest": (4, 0, 0), "neck": (-30, 0, 0),
            "head": (-16, 0, 0), "ankle.L": (0.05, 0.20, 0.22), "foot.L": 30, "ankle.R": (-0.05, 0.26, 0.18),
            "foot.R": 35, "hand.L": (0.14, -0.38, -0.16), "hand.R": (0.13, -0.38, -0.18),
            "elbow.L": (1.0, 0.2, 0.3), "elbow.R": (1.0, 0.2, 0.3), "curl.L": 10, "curl.R": 10,
            "grip.L": 60, "grip.R": 60},
        7: {"pelvis": (0, -0.06, -0.22), "hips": (36, 0, 0), "chest": (8, 0, 0), "neck": (-20, 0, 0),
            "head": (-10, 0, 0), "ankle.L": (0.05, -0.10, 0), "ankle.R": (-0.05, 0.14, 0), "foot.R": 40,
            "hand.L": (0.14, -0.30, -0.34), "hand.R": (0.13, -0.28, -0.35), "elbow.L": (1.0, 0.4, 0.0),
            "elbow.R": (1.0, 0.4, 0.0), "curl.L": 20, "curl.R": 20, "grip.L": 70, "grip.R": 70},
        9: {"pelvis": (0, -0.04, -0.16), "hips": (28, 0, 0), "chest": (6, 0, 0), "neck": (-14, 0, 0),
            "head": (-8, 0, 0), "ankle.L": (0.05, -0.08, 0), "ankle.R": (-0.05, 0.12, 0), "foot.R": 30,
            "hand.L": (0.14, -0.26, -0.32), "hand.R": (0.13, -0.24, -0.33), "curl.L": 20, "curl.R": 20,
            "grip.L": 60, "grip.R": 60}}),
    # --- walls, ledges, beams, ceilings, ropes ---
    "climb_up": dict(loop=True, tail=tail_fn(lift=-5, curl=6, sway=8, bob=2, cycles=1), ears=ears_fn(-5, 0), keys={
        1: _with(WALL, hand_L=(0.10, -0.22, 0.30), hand_R=(0.12, -0.24, 0.02), ankle_L=(0.02, -0.18, 0.12),
                 ankle_R=(-0.02, -0.16, 0.40), foot_L=10, foot_R=10, elbow_L=(1, 0.6, -0.4), elbow_R=(1, 0.6, -0.4),
                 curl_L=-10, curl_R=-10),
        13: _with(WALL, hand_L=(0.12, -0.24, 0.02), hand_R=(0.10, -0.22, 0.30), ankle_L=(0.02, -0.16, 0.40),
                  ankle_R=(-0.02, -0.18, 0.12), foot_L=10, foot_R=10, elbow_L=(1, 0.6, -0.4),
                  elbow_R=(1, 0.6, -0.4), curl_L=-10, curl_R=-10, pelvis=(0, 0, 0.02)),
        25: None}),
    "climb_side": dict(loop=True, tail=tail_fn(lift=-5, curl=6, sway=12, bob=2, cycles=1), ears=ears_fn(-5, 0),
                       keys={
        1: _with(WALL, hand_L=(0.30, -0.24, 0.12), hand_R=(0.06, -0.24, 0.14), ankle_L=(0.18, -0.16, 0.20),
                 ankle_R=(-0.02, -0.16, 0.20), elbow_L=(1, 0.6, -0.4), elbow_R=(1, 0.6, -0.4)),
        13: _with(WALL, hand_L=(0.10, -0.24, 0.14), hand_R=(0.20, -0.24, 0.12), ankle_L=(0.04, -0.16, 0.20),
                  ankle_R=(-0.14, -0.16, 0.20), elbow_L=(1, 0.6, -0.4), elbow_R=(1, 0.6, -0.4),
                  pelvis=(0.06, 0, 0)),
        25: None}),
    "hang": dict(loop=True, tail=tail_fn(lift=-10, curl=8, sway=12, bob=4, cycles=1), ears=ears_fn(-5, 0), keys={
        # Hands up on the ledge, feet against the wall below it (HANG_DROP puts the ledge 1.95 m above her feet).
        1: {**AIR, "pelvis": (0, 0, 0.08), "chest": (-4, 0, 0), "head": (-16, 0, 0),
            "hand.L": (0.04, -0.20, 0.38), "hand.R": (0.04, -0.20, 0.38), "elbow.L": (1, 0.4, -0.2),
            "elbow.R": (1, 0.4, -0.2), "curl.L": 40, "curl.R": 40, "shrug.L": 10, "shrug.R": 10,
            "ankle.L": (0.03, -0.14, 0.18), "ankle.R": (-0.03, -0.12, 0.10), "foot.L": 15, "foot.R": 15},
        13: {**AIR, "pelvis": (0, 0, 0.07), "chest": (-3, 0, 0), "head": (-14, 0, 4),
             "hand.L": (0.04, -0.20, 0.38), "hand.R": (0.04, -0.20, 0.38), "elbow.L": (1, 0.4, -0.2),
             "elbow.R": (1, 0.4, -0.2), "curl.L": 40, "curl.R": 40, "shrug.L": 10, "shrug.R": 10,
             "ankle.L": (0.03, -0.12, 0.12), "ankle.R": (-0.03, -0.14, 0.16), "foot.L": 15, "foot.R": 15},
        25: None}),
    "mantle": dict(loop=False, tail=tail_fn(lift=20, curl=8, sway=6, bob=4), ears=ears_fn(-8, 0), keys={
        1: {**AIR, "pelvis": (0, 0, 0.08), "head": (-16, 0, 0), "hand.L": (0.04, -0.20, 0.38),
            "hand.R": (0.04, -0.20, 0.38), "curl.L": 40, "curl.R": 40, "ankle.L": (0.03, -0.14, 0.18),
            "ankle.R": (-0.03, -0.12, 0.10)},
        4: {**AIR, "pelvis": (0, -0.08, 0.40), "hips": (20, 0, 0), "head": (-10, 0, 0),
            "hand.L": (0.06, -0.10, -0.05), "hand.R": (0.06, -0.10, -0.05), "elbow.L": (0.4, 1.0, 0.2),
            "elbow.R": (0.4, 1.0, 0.2), "curl.L": -60, "curl.R": -60, "ankle.L": (0.03, -0.20, 0.55),
            "ankle.R": (-0.03, 0.0, 0.30)},
        9: _with(READY, pelvis=(0, -0.04, -0.12), hips=(16, 0, 0))}),
    "balance": dict(loop=True, tail=tail_fn(lift=45, curl=4, sway=18, bob=3, cycles=1), ears=ears_fn(0, 0),
                    keys=gait(32, 0.20, 0.08, 0.01, lean=4, swing=0.03, hand=(0.36, 0.02, 0.06),
                              elbow=(0.2, 0.6, -1.0), curl=0, cross=0.09, sway=4, head=8)),
    "ceiling": dict(loop=True, tail=tail_fn(lift=-60, curl=6, sway=10, bob=2, cycles=1), ears=ears_fn(-10, 0), keys={
        1: _with(CEIL, hand_L=(0.10, -0.26, 0.22), hand_R=(0.14, -0.28, 0.04), ankle_L=(0.04, -0.30, 0.20),
                 ankle_R=(-0.04, -0.30, 0.34), foot_L=-30, foot_R=-30, curl_L=-30, curl_R=-30),
        13: _with(CEIL, hand_L=(0.14, -0.28, 0.04), hand_R=(0.10, -0.26, 0.22), ankle_L=(0.04, -0.30, 0.34),
                  ankle_R=(-0.04, -0.30, 0.20), foot_L=-30, foot_R=-30, curl_L=-30, curl_R=-30),
        25: None}),
    "descend": dict(loop=True, tail=tail_fn(lift=-30, curl=4, sway=10, bob=2, cycles=1), ears=ears_fn(-15, 0), keys={
        1: _with(HEADDOWN, hand_L=(0.10, -0.24, 0.26), hand_R=(0.12, -0.24, 0.02), ankle_L=(0.02, -0.18, 0.12),
                 ankle_R=(-0.02, -0.16, 0.36), foot_L=10, foot_R=10, curl_L=-10, curl_R=-10),
        11: _with(HEADDOWN, hand_L=(0.12, -0.24, 0.02), hand_R=(0.10, -0.24, 0.26), ankle_L=(0.02, -0.16, 0.36),
                  ankle_R=(-0.02, -0.18, 0.12), foot_L=10, foot_R=10, curl_L=-10, curl_R=-10),
        21: None}),
    "swing": dict(loop=True, tail=tail_fn(lift=30, curl=10, sway=20, bob=6, cycles=1), ears=ears_fn(-10, 0), keys={
        1: {**AIR, "pelvis": (0, 0, 0.10), "head": (-12, 0, 0), "hand.L": (-0.10, -0.04, 0.39),
            "hand.R": (-0.10, -0.02, 0.37), "elbow.L": (1, 0.3, 0), "elbow.R": (1, 0.3, 0), "curl.L": 50,
            "curl.R": 50, "hips": (-12, 0, 0), "ankle.L": (0.03, -0.30, 0.20), "ankle.R": (-0.03, -0.26, 0.26)},
        13: {**AIR, "pelvis": (0, 0, 0.10), "head": (-18, 0, 0), "hand.L": (-0.10, -0.04, 0.39),
             "hand.R": (-0.10, -0.02, 0.37), "elbow.L": (1, 0.3, 0), "elbow.R": (1, 0.3, 0), "curl.L": 50,
             "curl.R": 50, "hips": (14, 0, 0), "ankle.L": (0.03, 0.26, 0.20), "ankle.R": (-0.03, 0.22, 0.14)},
        25: None}),
    # --- the fight ---
    # The combo is timed to nim_combat.HITS (wind-up, active, recover; 24 fps): strikes 1 and 2 are 0.07/0.08/0.22 s,
    # so the wind-up is frame 1, the hit lands at 3 (inside the active window), and she's back by 10. The wind-up key
    # eases in (slow, then a snap into the hit) and the hit eases out into an overshoot. Hips yaw + turns her to her
    # left, so a right-hand blow winds up at - and lands at +. The head counter-turns to keep her eyes on him.
    "strike1": dict(loop=False, tail=tail_fn(lift=30, curl=8, sway=10, bob=4, whip=25), ears=ears_fn(-25, 0),
                    ease={1: "in", 3: "out"}, keys={
        # A right-hand claw rake: shoulder back, then the whole side drives through, a step in on the left foot.
        1: _with(READY, pelvis=(0, 0.03, -0.05), hips=(4, 0, -20), chest=(2, 0, -14), head=(-4, 0, 26),
                 hand_R=(0.14, 0.10, -0.08), elbow_R=(0.7, 1.0, 0.1), curl_R=-25, grip_R=10, shrug_R=6,
                 hand_L=(0.02, -0.20, -0.16), elbow_L=(1.0, 0.2, -0.2), curl_L=10,
                 ankle_L=(0.04, -0.06, 0), ankle_R=(-0.04, 0.10, 0), foot_R=10),
        3: _with(READY, pelvis=(0, -0.08, -0.08), hips=(12, 0, 22), chest=(8, 0, 18), neck=(-4, 0, 0),
                 head=(-8, 0, -30), hand_R=(-0.02, -0.41, 0.05), elbow_R=(1.0, 0.3, -0.3), curl_R=-35, grip_R=0,
                 shrug_R=10, hand_L=(0.06, 0.06, -0.20), elbow_L=(0.6, 1.0, 0.0),
                 ankle_L=(0.04, -0.24, 0), foot_L=-6, ankle_R=(-0.04, 0.18, 0.03), foot_R=35),
        4: _with(READY, pelvis=(0, -0.10, -0.09), hips=(13, 0, 28), chest=(9, 0, 24), neck=(-4, 0, 0),
                 head=(-8, 0, -36), hand_R=(-0.10, -0.38, -0.04), elbow_R=(1.0, 0.3, -0.3), curl_R=-10, grip_R=30,
                 shrug_R=8, hand_L=(0.06, 0.06, -0.20), elbow_L=(0.6, 1.0, 0.0),
                 ankle_L=(0.04, -0.24, 0), foot_L=-6, ankle_R=(-0.04, 0.18, 0.03), foot_R=35),
        6: _with(READY, pelvis=(0, -0.08, -0.07), hips=(10, 0, 16), chest=(6, 0, 12), head=(-6, 0, -20),
                 hand_R=(-0.12, -0.24, -0.22), elbow_R=(1.0, 0.5, -0.2), curl_R=20, grip_R=55,
                 hand_L=(0.06, 0.0, -0.24), ankle_L=(0.04, -0.20, 0), ankle_R=(-0.04, 0.14, 0), foot_R=20),
        10: READY}),
    "strike2": dict(loop=False, tail=tail_fn(lift=30, curl=8, sway=12, bob=4, whip=-30), ears=ears_fn(-25, 0),
                    ease={1: "in", 3: "out"}, keys={
        # The left hand back the other way: wound wide, a flat swipe across, the right foot stepping in.
        1: _with(READY, pelvis=(0, 0.03, -0.05), hips=(4, 0, 18), chest=(2, 0, 16), head=(-4, 0, -28),
                 hand_L=(0.34, 0.04, -0.02), elbow_L=(0.6, 1.0, 0.5), curl_L=-30, grip_L=10, shrug_L=6,
                 hand_R=(0.0, -0.22, -0.14), elbow_R=(1.0, 0.2, -0.2), curl_R=10,
                 ankle_R=(-0.04, -0.06, 0), ankle_L=(0.04, 0.10, 0), foot_L=10),
        3: _with(READY, pelvis=(0, -0.07, -0.08), hips=(12, 0, -20), chest=(8, 0, -22), neck=(-4, 0, 0),
                 head=(-8, 0, 34), hand_L=(0.0, -0.42, 0.02), elbow_L=(1.0, 0.2, 0.4), curl_L=-35, grip_L=0,
                 shrug_L=10, hand_R=(0.06, 0.06, -0.20), elbow_R=(0.6, 1.0, 0.0),
                 ankle_R=(-0.04, -0.22, 0), foot_R=-6, ankle_L=(0.04, 0.16, 0.03), foot_L=35),
        4: _with(READY, pelvis=(0, -0.08, -0.09), hips=(13, 0, -28), chest=(9, 0, -30), neck=(-4, 0, 0),
                 head=(-8, 0, 44), hand_L=(-0.16, -0.36, -0.02), elbow_L=(1.0, 0.2, 0.4), curl_L=-15, grip_L=30,
                 shrug_L=8, hand_R=(0.06, 0.06, -0.20), elbow_R=(0.6, 1.0, 0.0),
                 ankle_R=(-0.04, -0.22, 0), foot_R=-6, ankle_L=(0.04, 0.16, 0.03), foot_L=35),
        6: _with(READY, pelvis=(0, -0.06, -0.07), hips=(10, 0, -16), chest=(6, 0, -18), head=(-6, 0, 26),
                 hand_L=(-0.18, -0.22, -0.18), elbow_L=(1.0, 0.5, 0.2), curl_L=20, grip_L=55,
                 hand_R=(0.06, 0.0, -0.24), ankle_R=(-0.04, -0.18, 0), ankle_L=(0.04, 0.12, 0), foot_L=20),
        10: READY}),
    "strike3": dict(loop=False, tail=tail_fn(lift=40, curl=4, sway=4, bob=4, whip=70), ears=ears_fn(-30, 0),
                    ease={5: "out"}, keys={
        # The finisher (0.1/0.1/0.4 s): a spinning back-kick. The whole body pivots on the left foot (`turn`), her
        # back comes round to him at frame 5 inside the hit window, and the right heel drives straight back into
        # him while she looks over her shoulder. Then the leg folds and she spins on round to face him.
        1: _with(READY, pelvis=(0, 0, -0.07), hips=(8, 0, 0), chest=(4, 0, -10), head=(-4, 0, 8),
                 hand_L=(0.10, -0.18, -0.16), hand_R=(0.10, -0.10, -0.20), curl_L=20, curl_R=20,
                 ankle_L=(0.03, -0.04, 0), ankle_R=(-0.03, 0.06, 0)),
        3: _with(READY, turn=110, pelvis=(0, 0.02, -0.06), hips=(10, 0, 0), chest=(4, 0, 20), neck=(0, 0, -15),
                 head=(-6, 0, -45), hand_L=(0.16, -0.10, -0.12), hand_R=(0.16, -0.08, -0.10),
                 elbow_L=(1.0, 0.4, 0.2), elbow_R=(1.0, 0.4, 0.2), curl_L=25, curl_R=25,
                 ankle_L=(0.03, 0.0, 0), ankle_R=(-0.02, 0.0, 0.30), foot_R=20),
        5: _with(READY, turn=180, pelvis=(0, 0.08, -0.05), hips=(50, 0, 0), chest=(6, 0, 0), neck=(-14, 0, -20),
                 head=(-16, 0, -55), hand_L=(0.18, -0.28, -0.22), hand_R=(0.18, -0.26, -0.24),
                 elbow_L=(1.0, 0.3, 0.0), elbow_R=(1.0, 0.3, 0.0), curl_L=10, curl_R=10,
                 ankle_L=(0.03, 0.02, 0), foot_L=0, ankle_R=(-0.02, 0.70, 0.80), foot_R=-20),
        6: _with(READY, turn=186, pelvis=(0, 0.09, -0.05), hips=(54, 0, 0), chest=(6, 0, 0), neck=(-14, 0, -20),
                 head=(-16, 0, -55), hand_L=(0.18, -0.30, -0.24), hand_R=(0.18, -0.28, -0.26),
                 elbow_L=(1.0, 0.3, 0.0), elbow_R=(1.0, 0.3, 0.0), curl_L=10, curl_R=10,
                 ankle_L=(0.03, 0.02, 0), foot_L=0, ankle_R=(-0.02, 0.72, 0.86), foot_R=-20),
        9: _with(READY, turn=250, pelvis=(0, 0.02, -0.06), hips=(14, 0, 0), chest=(4, 0, 0), head=(-6, 0, -30),
                 hand_L=(0.14, -0.12, -0.14), hand_R=(0.14, -0.10, -0.16), curl_L=20, curl_R=20,
                 ankle_L=(0.03, 0.0, 0), ankle_R=(-0.03, 0.06, 0.26), foot_R=20),
        12: _with(READY, turn=330, pelvis=(0, -0.02, -0.10), hips=(12, 0, 0), chest=(4, 0, 0), head=(-6, 0, -8),
                  hand_L=(0.08, -0.18, -0.20), hand_R=(0.10, -0.12, -0.22), curl_L=20, curl_R=20,
                  ankle_L=(0.04, -0.06, 0), ankle_R=(-0.04, 0.08, 0)),
        16: _with(READY, turn=360)}),     # 0.625 s, just past the 0.6 s the hit lasts, so it never replays
    "bind": dict(loop=True, tail=tail_fn(lift=20, curl=10, sway=8, bob=2, cycles=2), ears=ears_fn(-6, 8, 0.4), keys={
        # Kneeling over a downed goon, working the rope.
        1: {"pelvis": (0, -0.10, -0.46), "hips": (30, 0, 0), "chest": (14, 0, 0), "neck": (6, 0, 0),
            "head": (14, 0, 0), "ankle.L": (0.06, -0.30, 0.0), "foot.L": 0, "ankle.R": (-0.06, 0.32, 0.02),
            "foot.R": 60, "hand.L": (-0.02, -0.34, -0.22), "hand.R": (-0.04, -0.30, -0.28),
            "elbow.L": (1, 0.5, 0), "elbow.R": (1, 0.5, 0), "curl.L": 30, "curl.R": 30},
        7: {"pelvis": (0, -0.10, -0.46), "hips": (30, 0, 0), "chest": (14, 0, 6), "neck": (6, 0, 0),
            "head": (14, 0, 6), "ankle.L": (0.06, -0.30, 0.0), "foot.L": 0, "ankle.R": (-0.06, 0.32, 0.02),
            "foot.R": 60, "hand.L": (-0.06, -0.30, -0.26), "hand.R": (0.02, -0.36, -0.20),
            "elbow.L": (1, 0.5, 0), "elbow.R": (1, 0.5, 0), "curl.L": 40, "curl.R": 20},
        13: None}),
    "takedown": dict(loop=False, tail=tail_fn(lift=60, curl=10, sway=6, bob=8), ears=ears_fn(-30, 0), keys={
        # Dropping onto a goon from above: knees first, hands driving down.
        1: _with(TUCK, hips=(20, 0, 0), hand_L=(0.16, -0.16, 0.20), hand_R=(0.16, -0.16, 0.20)),
        4: {"pelvis": (0, -0.08, -0.40), "hips": (34, 0, 0), "chest": (12, 0, 0), "head": (-6, 0, 0),
            "ankle.L": (0.08, -0.06, 0), "ankle.R": (-0.08, 0.10, 0), "foot.R": 30,
            "hand.L": (0.06, -0.34, -0.36), "hand.R": (0.06, -0.34, -0.36), "curl.L": -30, "curl.R": -30},
        10: {"pelvis": (0, -0.06, -0.36), "hips": (30, 0, 0), "chest": (10, 0, 0), "head": (-10, 0, 0),
             "ankle.L": (0.08, -0.06, 0), "ankle.R": (-0.08, 0.10, 0), "foot.R": 30,
             "hand.L": (0.08, -0.30, -0.34), "hand.R": (0.08, -0.30, -0.34), "curl.L": -20, "curl.R": -20},
        18: READY}),
    "hurt": dict(loop=False, tail=tail_fn(lift=70, curl=18, sway=12, bob=6, cycles=2), ears=ears_fn(-45, 0), keys={
        1: READY,
        3: {"pelvis": (0, 0.08, -0.06), "hips": (-12, 4, 0), "spine": (-6, 0, 0), "chest": (-8, 0, 6),
            "head": (-14, 10, 10), "ankle.L": (0.04, 0.0, 0), "ankle.R": (-0.04, 0.12, 0),
            "hand.L": (0.24, -0.10, 0.0), "hand.R": (0.26, -0.06, 0.06), "elbow.L": (1, 0, -0.5),
            "elbow.R": (1, 0, -0.5), "curl.L": -20, "curl.R": -20, "shrug.L": 12, "shrug.R": 12},
        7: _with(READY, pelvis=(0, 0.04, -0.05), hips=(-4, 2, 0), head=(-6, 4, 4)),
        12: READY}),
    "knockdown": dict(loop=False, tail=tail_fn(lift=20, curl=4, sway=4, bob=0, cycles=0.5), ears=ears_fn(-35, 0),
                      keys={
        # Knocked flat on her back, and she stays down (NimCombat's downed; revive plays idle).
        1: READY,
        4: {"pelvis": (0, 0.14, -0.20), "hips": (-24, 0, 0), "chest": (-10, 0, 0), "head": (16, 0, 0),
            "ankle.L": (0.04, -0.10, 0.10), "ankle.R": (-0.04, -0.04, 0.0), "hand.L": (0.30, 0.0, 0.10),
            "hand.R": (0.32, 0.02, 0.06), "elbow.L": (1, 0, -0.5), "elbow.R": (1, 0, -0.5)},
        9: {"pelvis": (0, 0.42, -0.62), "hips": (-70, 0, 0), "chest": (-4, 0, 0), "head": (24, 0, 0),
            "ankle.L": (0.06, -0.24, 0.24), "ankle.R": (-0.06, -0.10, 0.08), "foot.L": 20, "foot.R": 30,
            "hand.L": (0.34, 0.06, 0.08), "hand.R": (0.32, 0.04, 0.12), "elbow.L": (1, 0, -0.5),
            "elbow.R": (1, 0, -0.5)},
        16: {"pelvis": (0, 0.56, -0.74), "hips": (-86, 0, 0), "chest": (-2, 0, 0), "head": (10, 0, 14),
             "ankle.L": (0.08, 0.06, 0.16), "ankle.R": (-0.08, 0.10, 0.10), "foot.L": 40, "foot.R": 40,
             "hand.L": (0.34, 0.08, 0.02), "hand.R": (0.36, 0.06, 0.04), "elbow.L": (1, 0, -0.5),
             "elbow.R": (1, 0, -0.5), "curl.L": 20, "curl.R": 20},
        24: {"pelvis": (0, 0.56, -0.75), "hips": (-86, 0, 0), "chest": (-2, 0, 0), "head": (8, 0, 18),
             "ankle.L": (0.08, 0.08, 0.15), "ankle.R": (-0.08, 0.10, 0.09), "foot.L": 40, "foot.R": 40,
             "hand.L": (0.34, 0.08, 0.02), "hand.R": (0.36, 0.06, 0.04), "elbow.L": (1, 0, -0.5),
             "elbow.R": (1, 0, -0.5), "curl.L": 25, "curl.R": 25}}),
    # --- the suit ---
    "cmd_kneel": dict(loop=False, tail=tail_fn(lift=15, curl=12, sway=4, bob=2), ears=ears_fn(-4, 0), keys={
        # Two fingers to the floor, chin up: down.
        1: POISE,
        6: _with(POISE, chest=(-6, -3, 0), head=(-8, 2, 0), hand_L=(0.10, -0.30, -0.12), elbow_L=(1, 0.4, -0.4),
                 curl_L=-10),
        10: _with(POISE, chest=(-6, -3, 0), head=(-10, 2, 0), hand_L=(0.08, -0.26, -0.32),
                  elbow_L=(1, 0.4, -0.4), curl_L=30),
        20: POISE}),
    "cmd_fetch": dict(loop=False, tail=tail_fn(lift=15, curl=12, sway=4, bob=2), ears=ears_fn(-4, 0), keys={
        # A point, then a crook of the finger: bring it here.
        1: POISE,
        5: _with(POISE, chest=(-2, -3, 10), hand_L=(0.08, -0.38, 0.10), elbow_L=(1, 0.4, -0.4), curl_L=-5),
        11: _with(POISE, chest=(-3, -3, 4), hand_L=(0.10, -0.24, 0.02), elbow_L=(1, 0.4, -0.4), curl_L=45),
        20: POISE}),
    "cmd_open": dict(loop=False, tail=tail_fn(lift=15, curl=12, sway=4, bob=2), ears=ears_fn(-4, 0), keys={
        # An open palm swept out to the side: let me through.
        1: POISE,
        6: _with(POISE, chest=(-3, -3, -8), hand_L=(-0.06, -0.30, -0.06), elbow_L=(1, 0.5, -0.2), curl_L=-20),
        12: _with(POISE, chest=(-4, -3, 10), hand_L=(0.36, -0.10, -0.04), elbow_L=(0.6, 1, -0.2), curl_L=-30),
        20: POISE}),
    "hold_room": dict(loop=False, tail=tail_fn(lift=50, curl=14, sway=6, bob=2), ears=ears_fn(-8, 0), keys={
        # Hold the Room: chest up, arms opening wide, every eye on her.
        1: POISE,
        8: {"pelvis": (0, 0, 0.0), "hips": (-2, 0, 0), "chest": (-10, 0, 0), "neck": (2, 0, 0), "head": (-6, 0, 0),
            "ankle.L": (0.06, 0.0, 0), "ankle.R": (-0.06, 0.02, 0), "hand.L": (0.34, -0.12, 0.10),
            "hand.R": (0.34, -0.12, 0.10), "elbow.L": (0.3, 1, -0.6), "elbow.R": (0.3, 1, -0.6), "curl.L": -30,
            "curl.R": -30},
        24: {"pelvis": (0, 0, 0.0), "hips": (-2, 0, 0), "chest": (-11, 0, 0), "neck": (2, 0, 0), "head": (-7, 0, 4),
             "ankle.L": (0.06, 0.0, 0), "ankle.R": (-0.06, 0.02, 0), "hand.L": (0.36, -0.10, 0.12),
             "hand.R": (0.36, -0.10, 0.12), "elbow.L": (0.3, 1, -0.6), "elbow.R": (0.3, 1, -0.6), "curl.L": -35,
             "curl.R": -35}}),
    "trance": dict(loop=True, tail=tail_fn(lift=0, curl=2, sway=5, bob=1, cycles=1), ears=ears_fn(10, 0), keys={
        # The fake trance: slack, swaying, head lolling (and the face's squint, set by the game).
        1: {"pelvis": (0, 0.02, -0.03), "hips": (-3, 2, 0), "spine": (4, 0, 0), "chest": (6, 0, 0), "neck": (8, 0, 0),
            "head": (14, 8, 0), "hand.L": (0.02, 0.0, -0.40), "hand.R": (0.02, 0.02, -0.40), "curl.L": 5,
            "curl.R": 5, "elbow.L": (0.6, 1, 0), "elbow.R": (0.6, 1, 0)},
        25: {"pelvis": (0, 0.02, -0.035), "hips": (-3, -2, 0), "spine": (4, 0, 0), "chest": (6, 0, 0),
             "neck": (8, 0, 0), "head": (16, -8, 0), "hand.L": (0.02, 0.01, -0.40), "hand.R": (0.02, 0.0, -0.40),
             "curl.L": 5, "curl.R": 5, "elbow.L": (0.6, 1, 0), "elbow.R": (0.6, 1, 0)},
        49: None}),
    "change": dict(loop=False, tail=tail_fn(lift=40, curl=16, sway=10, bob=4, cycles=2), ears=ears_fn(-6, 0), keys={
        # A spin behind the wardrobe door: one full turn, arms up and in.
        1: READY,
        5: _with(READY, hips=(0, 0, 90), hand_L=(0.0, -0.06, 0.20), hand_R=(0.0, -0.06, 0.20), elbow_L=(1, 0, 0),
                 elbow_R=(1, 0, 0), pelvis=(0, 0, 0.02), ankle_R=(-0.04, 0.0, 0.10)),
        9: _with(READY, hips=(0, 0, 180), hand_L=(-0.04, -0.04, 0.34), hand_R=(-0.04, -0.04, 0.34), elbow_L=(1, 0, 0),
                 elbow_R=(1, 0, 0), pelvis=(0, 0, 0.03), ankle_R=(-0.04, 0.0, 0.12)),
        13: _with(READY, hips=(0, 0, 270), hand_L=(0.0, -0.06, 0.20), hand_R=(0.0, -0.06, 0.20), elbow_L=(1, 0, 0),
                  elbow_R=(1, 0, 0), pelvis=(0, 0, 0.02)),
        18: _with(POISE, hips=(0, 5, 356))}),
    # --- the velvet muzzle (DESIGN.md): her right hand to the catch on the right of her snout, a click ---
    "mask_on": dict(loop=False, tail=tail_fn(lift=18, curl=8, sway=5, bob=2), ears=ears_fn(-12, 0), keys={
        1: READY,
        6: _with(READY, hand_R=(-0.02, -0.17, 0.17), elbow_R=(1.0, 0.3, -0.4), curl_R=-30, grip_R=40,
                 head=(4, 0, 8)),
        9: _with(READY, hand_R=(-0.03, -0.15, 0.15), elbow_R=(1.0, 0.3, -0.4), curl_R=-35, grip_R=65,
                 head=(8, 0, 10)),
        11: _with(READY, hand_R=(-0.03, -0.15, 0.15), elbow_R=(1.0, 0.3, -0.4), curl_R=-35, grip_R=65,
                  head=(2, 0, 6)),
        18: READY}),
    "mask_off": dict(loop=False, tail=tail_fn(lift=14, curl=8, sway=5, bob=2), ears=ears_fn(4, 6, 0.7), keys={
        1: READY,
        5: _with(READY, hand_R=(-0.03, -0.15, 0.15), elbow_R=(1.0, 0.3, -0.4), curl_R=-35, grip_R=65,
                 head=(6, 0, 10)),
        9: _with(READY, hand_R=(0.06, -0.24, 0.10), elbow_R=(1.0, 0.4, -0.4), curl_R=-20, grip_R=55,
                 head=(-4, 0, 4)),
        16: READY}),
}

## Finger curl (deg) per clip, used for every key that doesn't set grip.L/R itself. 0 is the sculpt's open hand,
## about 75 a full grip. A key may also set point.L/R: the finger on the thumb side stays straight.
CLIP_GRIP = {"idle_garb": 18, "idle_suit": 12, "walk": 20, "prowl": 30, "strut": 12, "run": 40, "jump": 15,
             "fall": 5, "land": 25, "pounce": 0, "climb_up": 75, "climb_side": 75, "hang": 80, "mantle": 70,
             "balance": 0, "ceiling": 75, "descend": 75, "swing": 85, "strike1": 5, "strike2": 5, "strike3": 40,
             "bind": 60, "takedown": 45, "hurt": 0, "knockdown": 15, "cmd_kneel": 30, "cmd_fetch": 30,
             "cmd_open": 0, "hold_room": 0, "trance": 8, "change": 30, "mask_on": 20, "mask_off": 20}
## Gestures that point: (clip, frame) -> side.
POINTS = {("cmd_kneel", 6): "L", ("cmd_kneel", 10): "L", ("cmd_fetch", 5): "L"}
## Gestures that grip harder than the clip's base: (clip, frame) -> {side: deg}.
GRIPS = {("cmd_fetch", 11): {"L": 70}, ("mantle", 4): {"L": 0, "R": 0}}


# --- baking ------------------------------------------------------------------------------------------------------------
def _key_fingers(rig, clip, frame, pose):
    """Curl each finger bone about its X (the bones' Z faces the palm, so +X closes the hand)."""
    for side in SIDES:
        bones = [b.name for b in rig.data.bones if b.name.endswith("." + side)
                 and b.name.startswith(("finger", "thumb"))]
        if not bones:
            continue
        grip = pose.get("grip." + side, GRIPS.get((clip, frame), {}).get(side, CLIP_GRIP.get(clip, 15)))
        pointing = pose.get("point." + side) or POINTS.get((clip, frame)) == side
        fingers = sorted(b for b in bones if b.startswith("finger"))
        pointer = fingers[-1] if fingers else None      # the highest number is on the thumb side
        for b in bones:
            a = grip * (0.6 if b.startswith("thumb") else 1.0)
            if pointing:
                a = 0.0 if b == pointer else max(a, 80.0)
            pb = rig.pose.bones[b]
            pb.rotation_quaternion = Quaternion((1, 0, 0), math.radians(a))
            pb.keyframe_insert("rotation_quaternion", frame=frame, group=b)


def make(rig, prefix, name):
    """One clip as an action named <prefix>_<name> (actions are global in a .blend; Nine Lives' gotcha)."""
    spec = CLIPS[name]
    P = Poser(rig)
    act_name = "%s_%s" % (prefix, name)
    if act_name in bpy.data.actions:
        bpy.data.actions.remove(bpy.data.actions[act_name])
    act = bpy.data.actions.new(act_name)
    act.use_fake_user = True
    if rig.animation_data is None:
        rig.animation_data_create()
    ad = rig.animation_data
    ad.action = act
    for pb in rig.pose.bones:
        pb.rotation_mode = "QUATERNION"
    keys = dict(spec["keys"])
    frames = sorted(keys)
    for f in frames:
        if keys[f] is None:
            keys[f] = keys[frames[0]]
    last = {}
    for f in frames:
        M = P.solve(keys[f])
        for n in P.order:
            if n not in M:
                continue
            loc, rot, _ = P.basis(M, n).decompose()
            if n in last and last[n].dot(rot) < 0:
                rot.negate()
            last[n] = rot.copy()
            pb = rig.pose.bones[n]
            pb.rotation_quaternion = rot
            pb.keyframe_insert("rotation_quaternion", frame=f, group=n)
            if n == "hips":
                pb.location = loc
                pb.keyframe_insert("location", frame=f, group=n)
        _key_fingers(rig, name, f, keys[f])
    end = frames[-1]
    tf, ef = spec["tail"], spec["ears"]
    for f in range(1, end + 1):
        t = (f - 1) / max(end - 1, 1)
        ph = t * 2.0 * math.pi
        for i in range(TAIL_BONES):
            n = "tail.%d" % (i + 1)
            B = P.rest[n].to_quaternion()
            q = B.inverted() @ tf(i, ph) @ B
            if n in last and last[n].dot(q) < 0:
                q.negate()
            last[n] = q.copy()
            pb = rig.pose.bones[n]
            pb.rotation_quaternion = q
            pb.keyframe_insert("rotation_quaternion", frame=f, group=n)
        for s in SIDES:
            pb = rig.pose.bones["ear." + s]
            pb.rotation_quaternion = Quaternion((1, 0, 0), math.radians(-ef(s, t)))
            pb.keyframe_insert("rotation_quaternion", frame=f, group=pb.name)
    # `ease` {frame: "in" | "out"}: the body's move out of that key accelerates (a strike leaving its wind-up) or
    # decelerates (settling past the hit). Everything else is Bezier. The tail and ears are keyed every frame.
    ease = spec.get("ease", {})
    for fc in _fcurves(act):
        procedural = fc.data_path.startswith(('pose.bones["tail.', 'pose.bones["ear.'))
        for kp in fc.keyframe_points:
            kind = None if procedural else ease.get(int(round(kp.co.x)))
            if kind:
                kp.interpolation = "CUBIC"
                kp.easing = "EASE_IN" if kind == "in" else "EASE_OUT"
            else:
                kp.interpolation = "BEZIER"
    ad.action = None
    for pb in rig.pose.bones:
        pb.rotation_quaternion = (1, 0, 0, 0)
        pb.location = (0, 0, 0)
    return act


def max_steps(act):
    """The biggest frame-to-frame rotation of any bone (deg): a pop check."""
    by = {}
    for fc in _fcurves(act):
        if fc.data_path.endswith("rotation_quaternion"):
            by.setdefault(fc.data_path.split('"')[1], [None] * 4)[fc.array_index] = fc
    f0, f1 = act.frame_range
    worst = (0.0, "", 0)
    for bone, q in by.items():
        prev = None
        f = f0
        while f <= f1:
            v = Quaternion([q[i].evaluate(f) for i in range(4)]).normalized()
            if prev is not None:
                worst = max(worst, (math.degrees(prev.rotation_difference(v).angle), bone, int(f)))
            prev = v
            f += 1
    return (round(worst[0], 1), worst[1], worst[2])


def make_all(rig, prefix):
    return {n: max_steps(make(rig, prefix, n)) for n in CLIPS}


def set_nla(rig, prefix):
    """One NLA track per clip, named by the clip, for the glTF export."""
    ad = rig.animation_data or rig.animation_data_create()
    for t in list(ad.nla_tracks):
        ad.nla_tracks.remove(t)
    ad.action = None
    for name in CLIPS:
        act = bpy.data.actions["%s_%s" % (prefix, name)]
        tr = ad.nla_tracks.new()
        tr.name = name
        st = tr.strips.new(name, int(act.frame_range[0]), act)
        if act.slots:
            st.action_slot = act.slots[0]
