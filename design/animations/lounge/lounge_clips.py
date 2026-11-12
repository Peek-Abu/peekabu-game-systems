"""The break-room sofa's sleepy employee (owner 11-11, ideas sheet #4: Cappy). Two generic clips on the shared kit rig
(clipkit conventions), so any employee can play them:

- SofaDoze (6.0 s loop): sitting (thighs level, shins down), leaned back into the sofa, hands in the lap, chin on the
  chest, breathing (chest and head rise and fall over 3 s); at 4.5 s the head droops further, at 4.9 s it jerks up
  (nodding off), then it settles back by 6.0 s so the loop seam is at rest.
- SeatedWave (2.0 s, played over the doze): the upper body only (no legs, no pelvis), so he waves without standing:
  the head comes up, the right arm rises with the forearm-led wave of CoachWave v2 (elbow 25-70 deg, shoulder two
  frames behind), then the arm goes back to the lap and the head sinks again.

  python lounge_clips.py <export_dir>   -> SofaDoze_v1.rbxmx, SeatedWave_v1.rbxmx, build_lounge.luau
"""

import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))
from clipkit import f, luau_builder, mirror, write  # noqa: E402

SIT_LEGS = {
    "RightHip": [-88, 0, 4], "LeftHip": [-88, 0, -4],
    "RightKnee": [86, 0, 0], "LeftKnee": [86, 0, 0],
    "RightAnkle": [0, 0, 0], "LeftAnkle": [0, 0, 0],
}
LAP = {
    "RightShoulder": [0, 38, -58], "RightElbow": [0, 0, 58],
    "LeftShoulder": mirror([0, 38, -58]), "LeftElbow": mirror([0, 0, 58]),
}


def doze(waist_x, neck_x, neck_z=0, ease=None):
    t = {"Waist": [waist_x, 0, 0], "Neck": [neck_x, 0, neck_z], **SIT_LEGS, **LAP}
    if ease:
        t["ease"] = ease
    return t


DOZE = {
    0: doze(10, -28),
    f(45): doze(12.5, -24, 3),              # breathe in
    f(90): doze(10, -28),                   # breathe out
    f(135): doze(10.5, -38, -4, "in"),      # nodding off: the head droops
    f(147): doze(11, -10, 2, "out"),        # the jerk awake
    f(165): doze(10, -20),
    f(180): doze(10, -28),
}

WAVE_ARM = {"outElbow": [0, 0, 25], "inElbow": [0, 0, 70], "outShoulder": [-10, 45, -6], "inShoulder": [-10, 45, 4]}
SEATED = {
    0: {"Neck": [-28, 0, 0], "RightShoulder": LAP["RightShoulder"], "RightElbow": LAP["RightElbow"]},
    f(8): {"ease": "out", "Neck": [0, 0, -8], "Waist": [6, 0, 6], "RightShoulder": [-10, 45, 0],
           "RightElbow": [0, 0, 45]},
    f(52): {"Neck": [-6, 0, 0], "Waist": [10, 0, 0], "RightShoulder": [0, 30, -40], "RightElbow": [0, 0, 50]},
    f(60): {"Neck": [-28, 0, 0], "Waist": [10, 0, 0], "RightShoulder": LAP["RightShoulder"],
            "RightElbow": LAP["RightElbow"]},
}
for i, n in enumerate([12, 17, 22, 27, 32, 37, 42], start=1):
    out = i % 2 == 1
    key = SEATED.get(f(n), {})
    key["RightElbow"] = WAVE_ARM["outElbow" if out else "inElbow"]
    key["Neck"] = [2, 0, -10] if out else [0, 0, -4]
    SEATED[f(n)] = key
    lag = SEATED.get(f(n + 2), {})
    lag["RightShoulder"] = WAVE_ARM["outShoulder" if out else "inShoulder"]
    SEATED[f(n + 2)] = lag

CLIPS = {"SofaDoze": (DOZE, True, None), "SeatedWave": (SEATED, False, None)}

if __name__ == "__main__":
    out = sys.argv[1]
    os.makedirs(out, exist_ok=True)
    for name, (frames, loop, markers) in CLIPS.items():
        print(name, write(name, frames, loop, markers, os.path.join(out, f"{name}_v1.rbxmx")))
    open(os.path.join(out, "build_lounge.luau"), "w", encoding="utf-8").write(luau_builder(CLIPS, "ClaudeLoungeClips"))
