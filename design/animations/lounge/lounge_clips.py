"""The break-room sofa's sleepy employee (owner 11-11, ideas sheet #4: Cappy; v2 owner 11-11: "look sleepier"). Two
generic clips on the shared kit rig (clipkit conventions: Hip +X swings the thigh forward, Knee -X folds the shin
back, Waist +X leans back, Neck -X looks down, Shoulder Z+ raises the arm, Elbow Z+ bends the forearm up), so any
employee can play them. Gates: GATES.md (lounge_check.py runs the numeric ones).

- SofaDoze (12.0 s loop): slouched deep into the sofa (waist leaned back 28 deg, knees fallen apart unevenly), the right
  hand in the lap, the left arm limp on the cushion beside him, the head drooped forward and to the side. Two slow
  breaths (4 s each: chest, shoulders and head rise and fall). Then he nods off: the head sinks slowly, then drops
  (accelerating) to his chest, and he catches himself (the head jerks up, the back straightens, the shoulders shrug),
  stays dazed a moment and sinks back into the doze by the loop seam.
- SeatedWave (4.2 s, played over the doze): the upper body only (no legs), so he waves without standing. A startle
  first (the head snaps up, the chest jerks forward, both arms twitch out of the lap), a blink, then a slow, lazy
  wave (smaller and slower than the coach's), the arm flops back into the lap and the head sinks again.

  python lounge_clips.py <export_dir>   -> SofaDoze_v2.rbxmx, SeatedWave_v2.rbxmx, build_lounge.luau
"""

import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))
from clipkit import f, luau_builder, mirror, write  # noqa: E402

VERSION = "v2"

# The slouch: the hips slide forward on the cushion (Pelvis dz) and tip back (Pelvis pitch), so the back reclines along
# the sofa back instead of sitting up against it.
PELVIS_TIP = 14
PELVIS = [-0.05, -0.35, PELVIS_TIP]
SIT_LEGS = {
    # thighs forward over the cushion (the hips take back the pelvis tip so they stay level), shins down; the knees
    # fall apart a little, unevenly (relaxed, not posed)
    "RightHip": [86 - PELVIS_TIP, 0, 7], "LeftHip": [88 - PELVIS_TIP, 0, -11],
    "RightKnee": [-84, 0, 0], "LeftKnee": [-88, 0, 0],
    "RightAnkle": [4, 0, 0], "LeftAnkle": [-2, 0, 0],
}
# The right hand resting on his belly, the left arm hanging limp by his hip (solved by FK on Cappy at player scale:
# the kit's short arms can't reach further down the lap with the back leaned in).
R_SHOULDER, R_ELBOW = [15, 0, -95], [0, 0, 10]
L_SHOULDER, L_ELBOW = mirror([-10, 0, -70]), mirror([0, 0, 12])


def neck(head, waist):
    """The neck key for a head pitched `head[0]` deg in the world (+ up, - down; turn head[1], tilt head[2]): the neck
    pitch adds to the pelvis tip and the waist lean."""
    return [head[0] - PELVIS_TIP - waist, head[1], head[2]]


def doze(waist, head, rise=0.0, shrug=0.0, ease=None):
    """The doze pose: `waist` lean back (deg), `head` [world pitch, turn, tilt], `rise` the breath (0 out .. 1 in),
    `shrug` the shoulders lifting (deg, the catch)."""
    lift = 2 * rise + shrug
    w = waist + 2.5 * rise
    n = neck(head, waist)
    t = {
        "Pelvis": PELVIS,
        "Waist": [w, 0, 0],
        "Neck": [n[0] + 0.5 * rise, n[1], n[2]],
        **SIT_LEGS,
        "RightShoulder": [R_SHOULDER[0], R_SHOULDER[1], R_SHOULDER[2] + lift],
        "RightElbow": R_ELBOW,
        "LeftShoulder": [L_SHOULDER[0], L_SHOULDER[1], L_SHOULDER[2] - lift],
        "LeftElbow": L_ELBOW,
    }
    if ease:
        t["ease"] = ease
    return t


REST_WAIST = 30
# the head hangs ~40 deg down onto the chest, turned and lolling to one side
REST_HEAD = [-40, 8, 14]
REST_NECK = neck(REST_HEAD, REST_WAIST)

DOZE = {
    0: doze(REST_WAIST, REST_HEAD),                       # breathed out
    f(60): doze(REST_WAIST, REST_HEAD, rise=1),           # breathe in (2 s)
    f(120): doze(REST_WAIST, REST_HEAD),                  # out (2 s)
    f(180): doze(REST_WAIST, REST_HEAD, rise=1),
    f(240): doze(REST_WAIST, REST_HEAD),
    # nodding off: the head sinks slowly, then drops (accelerating, "in") onto the chest
    f(285): doze(REST_WAIST, [-50, 6, 20], ease="in"),
    f(295): doze(REST_WAIST, [-62, 4, 24], ease="out"),
    # the catch: head jerks up nearly level, the back straightens, shoulders shrug (decelerating, "out")
    f(301): doze(23, [-8, 2, 4], shrug=6),
    f(312): doze(23.5, [-13, 4, 7], shrug=4),             # dazed
    f(330): doze(25.5, [-21, 6, 9], shrug=1.5),
    f(360): doze(REST_WAIST, REST_HEAD),                  # sunk back: the loop seam
}

# SeatedWave: every key carries the whole upper body (waist, neck, both arms), so nothing snaps when it fades in. It
# leaves the pelvis and legs to the doze (he waves without getting up).


def upper(waist, head, rs, re, ls=L_SHOULDER, le=L_ELBOW, ease=None):
    t = {"Waist": [waist, 0, 0], "Neck": neck(head, waist), "RightShoulder": rs, "RightElbow": re,
         "LeftShoulder": ls, "LeftElbow": le}
    if ease:
        t["ease"] = ease
    return t


WAVE_UP = [-10, 45, 0]
SEATED = {
    # the doze rest; the startle leaves it fast ("out")
    0: upper(REST_WAIST, REST_HEAD, R_SHOULDER, R_ELBOW, ease="out"),
    # startle: the head snaps up, the chest jerks forward, both arms twitch out of the lap
    f(4): upper(12, [12, 0, -4], [22, 0, -52], [0, 0, 48], mirror([-4, 0, -32]), mirror([0, 0, 42]), ease="out"),
    f(10): upper(18, [3, 0, 3], [18, 0, -80], [0, 0, 22], mirror([-7, 0, -58]), mirror([0, 0, 22])),
    # a blink: the head sags a little and tilts, still half asleep
    f(18): upper(21, [-6, 0, 9], R_SHOULDER, R_ELBOW),
    # the arm comes up, slowly
    f(32): upper(21, [-6, -4, 11], WAVE_UP, [0, 0, 40]),
}
# a lazy wave: forearm-led, smaller and slower than the coach's (elbow 32-58 deg, 0.33 s a swing), shoulder 2 f behind
for i, n in enumerate([42, 52, 62, 72, 82], start=1):
    out = i % 2 == 1
    key = upper(21, [-6, -4, 11] if out else [-8, -4, 12], WAVE_UP, [0, 0, 58 if out else 32])
    SEATED[f(n)] = key
    lag = dict(SEATED.get(f(n + 2), key))
    lag["RightShoulder"] = [-10, 45, -5] if out else [-10, 45, 4]
    SEATED[f(n + 2)] = lag
# the arm flops back into the lap (accelerating, "in"), then the head sinks back down
SEATED[f(84)]["ease"] = "in"
SEATED[f(96)] = upper(25, [-22, 4, 10], R_SHOULDER, R_ELBOW)
SEATED[f(126)] = upper(REST_WAIST, REST_HEAD, R_SHOULDER, R_ELBOW)

CLIPS = {"SofaDoze": (DOZE, True, None), "SeatedWave": (SEATED, False, None)}

if __name__ == "__main__":
    out = sys.argv[1]
    os.makedirs(out, exist_ok=True)
    for name, (frames, loop, markers) in CLIPS.items():
        print(name, write(name, frames, loop, markers, os.path.join(out, f"{name}_{VERSION}.rbxmx")))
    open(os.path.join(out, "build_lounge.luau"), "w", encoding="utf-8").write(luau_builder(CLIPS, "ClaudeLoungeClips"))
