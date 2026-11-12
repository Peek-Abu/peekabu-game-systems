"""CoachWave v2 as a clipkit module: the same keys as BuildCoachWave.CommandBar.luau (see its header for the beats).

  python coach_wave.py out.rbxmx
"""

import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))
from clipkit import f, mirror, with_legs, write  # noqa: E402

SIDE = {"shoulder": [0, 8, -72], "elbow": [0, 0, 12]}
LEFT_SIDE = {"shoulder": mirror(SIDE["shoulder"]), "elbow": mirror(SIDE["elbow"])}
WAVE = {
    "outElbow": [0, 0, 25], "inElbow": [0, 0, 70],
    "outShoulder": [-10, 45, -6], "inShoulder": [-10, 45, 4],
    "outWrist": [0, 0, -15], "inWrist": [0, 0, 15],
}

FRAMES = {
    0: with_legs({"Root": 0, "Waist": [0, 0, 0], "Neck": [0, 0, 0], "RightShoulder": SIDE["shoulder"],
                  "RightElbow": SIDE["elbow"], "LeftShoulder": LEFT_SIDE["shoulder"], "LeftElbow": LEFT_SIDE["elbow"]}),
    f(5): with_legs({"Root": -0.05, "Waist": [-6, -6, -5], "Neck": [-4, 0, 0], "RightShoulder": [0, 25, -45],
                     "RightElbow": [0, 0, 45], "LeftShoulder": mirror([0, 0, -66]), "LeftElbow": LEFT_SIDE["elbow"]}),
    f(12): with_legs({"ease": "out", "Root": 0, "Waist": [6, 6, 9], "Neck": [6, -4, -10],
                      "RightShoulder": [-10, 45, 0], "RightElbow": [0, 0, 45], "RightWrist": [0, 0, 0],
                      "LeftShoulder": mirror([0, -10, -60]), "LeftElbow": mirror([0, 0, 30])}),
    f(52): with_legs({"Root": -0.02, "Waist": [-2, 2, 2], "Neck": [-4, -2, -4], "RightShoulder": [0, 18, -30],
                      "RightElbow": [0, 0, 40], "RightWrist": [0, 0, 0], "LeftShoulder": LEFT_SIDE["shoulder"],
                      "LeftElbow": LEFT_SIDE["elbow"]}),
    f(63): with_legs({"Root": 0, "Waist": [0, 0, 0], "Neck": [0, 0, 0], "RightShoulder": SIDE["shoulder"],
                      "RightElbow": SIDE["elbow"], "LeftShoulder": LEFT_SIDE["shoulder"],
                      "LeftElbow": LEFT_SIDE["elbow"]}),
}
for i, n in enumerate([16, 21, 26, 31, 36, 41, 46], start=1):
    out = i % 2 == 1
    key = FRAMES.get(f(n), {})
    key["RightElbow"] = WAVE["outElbow" if out else "inElbow"]
    key["RightWrist"] = WAVE["outWrist" if out else "inWrist"]
    key["Root"] = -0.035 if out else 0
    key["Waist"] = [4, 6, 12] if out else [6, 4, 6]
    key["Neck"] = [6, -6, -12] if out else [4, -2, -6]
    key["LeftShoulder"] = mirror([0, -14, -58]) if out else mirror([0, -6, -62])
    key["LeftElbow"] = mirror([0, 0, 30])
    FRAMES[f(n)] = with_legs(key)
    lag = FRAMES.get(f(n + 2), {})
    lag["RightShoulder"] = WAVE["outShoulder" if out else "inShoulder"]
    FRAMES[f(n + 2)] = lag

if __name__ == "__main__":
    print(write("CoachWave", FRAMES, False, None, sys.argv[1]))
