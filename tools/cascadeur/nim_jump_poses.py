"""Nim's jump as Cascadeur main-point positions (cm, Y up, +Z her front, +X her left), for the Cascadeur pilot
(tools/nim_cascadeur.py). One continuous standing jump at REAL gravity, 30 fps:

    ready 0 > crouch 5 > push 9 > takeoff 10 > (air: the pelvis on a true parabola) > apex 30 > contact 50 >
    squash 54 > rebound 59 > ready 64

In the air every limb is placed relative to the pelvis and blends tuck (rising) > spread (apex, falling) > reach
(before contact); knees and elbows come from two-bone IK at her own bone lengths (ported from Nine Lives'
run_poses.py). Limb-direction points are set too, so elbows and knees never flip. Prints JSON {frame: {name: xyz}}.

    python tools/cascadeur/nim_jump_poses.py
"""
import json
import math

# Her rest pose in the Cascadeur rig (characters.controllers, frame 0 after import).
HIP_X, HIP_Y, HIP_Z = 9.1, 82.0, 10.9
KNEE = (9.9, 44.0, 13.3)
ANKLE = (10.7, 9.0, 10.8)
TOE = (10.7, 3.5, 23.1)
CLAV = (2.5, 128.1, 15.7)
SHOULDER = (17.0, 130.1, 14.7)
ELBOW = (28.9, 108.8, 12.3)
HAND = (40.8, 87.6, 14.8)
REST_PELVIS = 82.0


def sub(a, b): return [a[i] - b[i] for i in range(3)]
def add(a, b): return [a[i] + b[i] for i in range(3)]
def mul(a, s): return [x * s for x in a]
def dot(a, b): return sum(a[i] * b[i] for i in range(3))
def length(a): return math.sqrt(dot(a, a))
def norm(a):
    n = length(a)
    return [x / n for x in a]
def lerp(a, b, t): return [a[i] + (b[i] - a[i]) * t for i in range(3)]


THIGH = length(sub(KNEE, (HIP_X, HIP_Y, HIP_Z)))
SHIN = length(sub(ANKLE, KNEE))
UPPER = length(sub(ELBOW, SHOULDER))
FORE = length(sub(HAND, ELBOW))
TOE_OFF = sub(TOE, ANKLE)            # ankle to toe, foot flat


def ik(root, end, l1, l2, pole):
    """Middle joint of a two-bone chain bending toward pole; pulls the end in if it's out of reach."""
    d = sub(end, root)
    dist = length(d)
    reach = l1 + l2 - 0.5
    if dist > reach:
        end = add(root, mul(d, reach / dist))
        d = sub(end, root)
        dist = reach
    axis = norm(d)
    a = (l1 * l1 - l2 * l2 + dist * dist) / (2 * dist)
    h = math.sqrt(max(l1 * l1 - a * a, 0.0))
    p = norm(sub(pole, mul(axis, dot(pole, axis))))
    return add(add(root, mul(axis, a)), mul(p, h)), end


# A body shape: pelvis forward offset and chest lean (cm), and limb targets.
# legs: ankle (x, y, z) and toe drop (how far the toe hangs below a flat foot: 0 flat, ~9 pointed).
# In "planted" shapes the ankle y is world height; in air shapes it's relative to the pelvis.
# arms: hand (x, y relative to the pelvis, z).
SHAPES = {
    "ready": dict(pz=0, lean=1, planted=True, ankle=(10.7, 9.0, 10.8), toe_drop=0, hand=(27, 4, 20)),
    "crouch": dict(pz=-6, lean=16, planted=True, ankle=(10.7, 9.0, 10.8), toe_drop=0, hand=(24, 18, -26)),
    "push": dict(pz=2, lean=4, planted=True, ankle=(10.0, 17.0, 6.0), toe_drop=10, hand=(18, 92, 26)),
    "tuck": dict(pz=0, lean=8, planted=False, ankle=(12.0, -30.0, -2.0), toe_drop=7, hand=(34, 36, 22)),
    "spread": dict(pz=0, lean=2, planted=False, ankle=(16.0, -58.0, 4.0), toe_drop=8, hand=(46, 46, 8)),
    "reach": dict(pz=0, lean=-2, planted=False, ankle=(12.0, -78.0, 12.0), toe_drop=9, hand=(40, 40, 18)),
    "squash": dict(pz=-8, lean=22, planted=True, ankle=(11.5, 9.0, 10.8), toe_drop=0, hand=(22, -6, 34)),
}


def pose(pelvis_y, shape, pz=0.0):
    s = SHAPES[shape]
    out = {}
    pz = HIP_Z + s["pz"] + pz
    out["spine_MainPoint"] = [0.0, pelvis_y, pz]
    lean = s["lean"]
    # The chest point sits above the pelvis, leaning forward by `lean`.
    chest = [0.0, pelvis_y + 46.0, pz + lean + 4.8]
    out["spine_DirectionPoint"] = chest
    for side in (1, -1):
        L = "L" if side > 0 else "R"
        hip = [side * HIP_X, pelvis_y, pz]
        ax, ay, az = s["ankle"]
        ank = [side * ax, ay if s["planted"] else pelvis_y + ay, az if s["planted"] else pz + az]
        knee, ank = ik(hip, ank, THIGH, SHIN, [0, 0.2, 1])
        drop = s["toe_drop"]
        toe = add(ank, [0.0, TOE_OFF[1] - drop, TOE_OFF[2] - drop * 0.4])
        if s["planted"]:
            toe[1] = max(toe[1], TOE[1])
        out["thigh.%s_MainPoint" % L] = hip
        out["shin.%s_MainPoint" % L] = knee
        out["shin.%s_LimbDir" % L] = add(knee, [0, 0, 50])
        out["foot.%s_MainPoint" % L] = ank
        out["toe.%s_MainPoint" % L] = toe
        out["toe.%s_DirectionPoint" % L] = add(toe, mul(norm(sub(toe, ank)), 4.0))
        # Shoulders ride the chest.
        sh = [side * SHOULDER[0], pelvis_y + (SHOULDER[1] - REST_PELVIS), pz + lean + 3.8]
        hx, hy, hz = s["hand"]
        hand = [side * hx, pelvis_y + hy, pz + hz]
        elbow, hand = ik(sh, hand, UPPER, FORE, [side * 0.6, -0.3, -1.0])
        out["shoulder.%s_MainPoint" % L] = [side * CLAV[0], pelvis_y + (CLAV[1] - REST_PELVIS), pz + lean + 4.8]
        out["upper_arm.%s_MainPoint" % L] = sh
        out["forearm.%s_MainPoint" % L] = elbow
        out["forearm.%s_LimbDir" % L] = add(elbow, [side * 25, -10, -45])
        out["hand.%s_MainPoint" % L] = hand
    return out


def blend(a, b, t):
    return {k: lerp(a[k], b[k], t) for k in a}


G = 981.0            # cm/s^2
FPS = 30.0
HEIGHT = 220.0       # player/nim.gd JUMP_HEIGHT
TAKEOFF, TAKEOFF_Y = 10, 96.0
V0 = math.sqrt(2 * G * HEIGHT)
T_UP = V0 / G                                  # ~0.67 s
APEX = TAKEOFF + round(T_UP * FPS)             # 30
CONTACT_Y = 96.0
CONTACT = APEX + round(math.sqrt(2 * (TAKEOFF_Y + HEIGHT - CONTACT_Y) / G) * FPS)   # ~50


def pelvis_air(f):
    t = (f - TAKEOFF) / FPS
    return TAKEOFF_Y + V0 * t - 0.5 * G * t * t


def air_shape(f):
    """Rising: push > tuck. Apex: tuck > spread. Falling: spread > reach."""
    if f <= APEX:
        u = (f - TAKEOFF) / (APEX - TAKEOFF)
        return blend(pose(pelvis_air(f), "push"), pose(pelvis_air(f), "tuck"), min(1.0, u * 1.6))
    u = (f - APEX) / (CONTACT - APEX)
    if u < 0.6:
        return blend(pose(pelvis_air(f), "tuck"), pose(pelvis_air(f), "spread"), u / 0.6)
    return blend(pose(pelvis_air(f), "spread"), pose(pelvis_air(f), "reach"), (u - 0.6) / 0.4)


FRAMES = {
    0: pose(80.0, "ready"),
    5: pose(60.0, "crouch"),
    9: pose(94.0, "push"),
}
for f in range(TAKEOFF, CONTACT, 3):
    FRAMES[f] = air_shape(f)
FRAMES[APEX] = air_shape(APEX)
FRAMES[CONTACT] = blend(pose(CONTACT_Y, "reach"), pose(CONTACT_Y, "push"), 0.0)
FRAMES[CONTACT][ "foot.L_MainPoint"][1] = FRAMES[CONTACT]["foot.R_MainPoint"][1] = 13.0
FRAMES[CONTACT + 4] = pose(56.0, "squash")
FRAMES[CONTACT + 9] = pose(74.0, "ready")
FRAMES[CONTACT + 14] = pose(80.0, "ready")

if __name__ == "__main__":
    print(json.dumps({"apex": APEX, "contact": CONTACT, "end": CONTACT + 14,
                      "frames": {f: {k: [round(x, 2) for x in v] for k, v in p.items()}
                                 for f, p in sorted(FRAMES.items())}}))
