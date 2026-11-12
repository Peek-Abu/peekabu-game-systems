"""The Supply Counter clerk, v6 (owner 11-11: Pippa stands on the floor behind a lowered counter, the parcel on the
counter; "the stamp ... looks more like a fidget than a constant loop: we need an active idle that fades into that
fidget, and toss another fidget into the pool"). Generic clips on the shared kit rig (clipkit conventions), so any
employee can play them, though the clerk is Pippa.

- ClerkIdle (4.0 s loop): the base the fidgets leave from and return to. Hands loose in front, a slight lean over the
  counter; weight shifts right then left (the hips drop a touch on each shift), she glances right at the room, then
  down-left at the counter, breathing through it. The seam is the base pose at rest.
- ClerkStamp v6 (2.4 s, one-shot from the base and back): the stamp beat of v5 refitted to the lowered counter. The
  contact pose was found by FK on Pippa at the clerk spot with the stamp grip: Waist -10, shoulder (0, 60, 20), elbow
  0 puts the stamp face 1.84-1.90 above her feet, 1.17 in front and 0.85 to her right, nearly flat: a 0.25-0.3 parcel
  on the 1.6-stud counter. Markers Thunk (contact) and Lift.
- ClerkStretch (2.8 s, one-shot): a night-shift stretch and yawn. A dip, then both arms up and out in a V (not
  overhead: the kit's heads are 2 studs wide), back arched, head tipped back for the yawn; a sway to each side; the
  arms come down out to the sides; a little head shake; back to the base.

  python clerk_v6.py export_dir     -> ClerkIdle_v6.rbxmx, ClerkStamp_v6.rbxmx, ClerkStretch_v6.rbxmx + build.luau
"""

import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))
from clipkit import f, luau_builder, mirror, with_legs, write  # noqa: E402

BASE_ARMS = {
    "RightShoulder": [0, 22, -62], "RightElbow": [0, 0, 32],
    "LeftShoulder": mirror([0, 22, -62]), "LeftElbow": mirror([0, 0, 32]),
}


def base(extra=None):
    t = {"Root": 0, "Waist": [-4, 0, 0], "Neck": [-2, 0, 0], **BASE_ARMS}
    t.update(extra or {})
    return with_legs(t)


IDLE = {
    0: base(),
    f(30): with_legs({"Root": -0.02, "Waist": [-3, -4, -4], "Neck": [2, 18, 3],
                      "RightShoulder": [0, 20, -64], "RightElbow": [0, 0, 28],
                      "LeftShoulder": mirror([0, 24, -60]), "LeftElbow": mirror([0, 0, 36])}),
    f(60): base({"Waist": [-5, 0, 0], "Neck": [-3, 2, 0]}),
    f(90): with_legs({"Root": -0.02, "Waist": [-6, 4, 4], "Neck": [-10, -14, -3],
                      "RightShoulder": [0, 24, -60], "RightElbow": [0, 0, 36],
                      "LeftShoulder": mirror([0, 20, -64]), "LeftElbow": mirror([0, 0, 28])}),
    f(120): base(),
}

CONTACT_ARM = {"RightShoulder": [0, 60, 20], "RightElbow": [0, 0, 0]}
STAMP = {
    0: base({"ease": "in", "easeJ": {"Root": "inout", "RightShoulder": "inout", "RightElbow": "inout"}}),
    f(4): {"ease": "in", "RightShoulder": BASE_ARMS["RightShoulder"], "RightElbow": BASE_ARMS["RightElbow"]},
    f(8): with_legs({"Root": -0.04}),
    # the wind-up's pass-through, then a braking arrival at the peak
    f(14): {"ease": "out", "Waist": [6, -8, 12], "Neck": [4, -6, -3], "RightShoulder": [0, 30, 30],
            "RightElbow": [0, 0, 40]},
    # PEAK: up on her toes of the knees, back arched and rolled away, the stamp raised beside the head
    f(19): with_legs({"ease": "in", "Root": 0, "Waist": [12, -12, 18], "Neck": [8, -8, -4],
                      "RightShoulder": [0, 40, 55], "RightElbow": [0, 0, 50]}),
    # CONTACT (Thunk): the stamp lands on the parcel and locks; the body keeps sinking
    f(24): with_legs({"ease": "out", "easeJ": {"RightShoulder": "const", "RightElbow": "const"}, "Root": -0.1,
                      "Waist": [-10, 0, 0], "Neck": [-14, 0, 0], **CONTACT_ARM}),
    f(27): with_legs({"Root": -0.13, "Waist": [-12, 2, 0], "Neck": [-22, 2, 0]}),
    # LIFT: the stamp leaves the parcel
    f(29): dict(CONTACT_ARM),
    f(37): with_legs({"Root": -0.02, "Waist": [4, 0, 0], "Neck": [2, 6, 0], "RightShoulder": [0, 45, -10],
                      "RightElbow": [0, 0, 40]}),
    # CHECK the stamped parcel, a satisfied nod
    f(48): with_legs({"Root": -0.03, "Waist": [-8, -14, 0], "Neck": [-16, -14, 4], "RightShoulder": [0, 35, -40],
                      "RightElbow": [0, 0, 40]}),
    f(56): {"Neck": [-22, -10, 2]},
    f(72): base(),
}
STAMP_MARKERS = {f(24): ["Thunk"], f(29): ["Lift"]}

STRETCH = {
    0: base(),
    # a dip, shoulders drawn in
    f(8): with_legs({"Root": -0.05, "Waist": [-8, 0, 0], "Neck": [-6, 0, 0], "RightShoulder": [0, 30, -70],
                     "RightElbow": [0, 0, 50], "LeftShoulder": mirror([0, 30, -70]), "LeftElbow": mirror([0, 0, 50])}),
    # the stretch: arms up and out in a V, back arched, head back (the yawn)
    f(22): with_legs({"ease": "out", "Root": 0, "Waist": [14, 0, 0], "Neck": [20, 0, 0],
                      "RightShoulder": [0, -5, 68], "RightElbow": [0, 0, 22],
                      "LeftShoulder": mirror([0, -5, 68]), "LeftElbow": mirror([0, 0, 22])}),
    f(34): with_legs({"Root": 0, "Waist": [14, 0, 7], "Neck": [22, 0, -4], "RightShoulder": [0, -5, 74],
                      "RightElbow": [0, 0, 16], "LeftShoulder": mirror([0, -5, 62]), "LeftElbow": mirror([0, 0, 28])}),
    f(46): with_legs({"Root": 0, "Waist": [12, 0, -7], "Neck": [18, 0, 4], "RightShoulder": [0, -5, 62],
                      "RightElbow": [0, 0, 28], "LeftShoulder": mirror([0, -5, 74]), "LeftElbow": mirror([0, 0, 16])}),
    # arms come down out to the sides, a shake of the head
    f(58): with_legs({"Root": -0.03, "Waist": [-2, 0, 0], "Neck": [-4, 10, 0], "RightShoulder": [0, 8, -30],
                      "RightElbow": [0, 0, 18], "LeftShoulder": mirror([0, 8, -30]), "LeftElbow": mirror([0, 0, 18])}),
    f(66): {"Neck": [-4, -10, 0]},
    f(84): base(),
}

CLIPS = {
    "ClerkIdle": (IDLE, True, None),
    "ClerkStamp": (STAMP, False, STAMP_MARKERS),
    "ClerkStretch": (STRETCH, False, None),
}

if __name__ == "__main__":
    out = sys.argv[1]
    os.makedirs(out, exist_ok=True)
    for name, (frames, loop, markers) in CLIPS.items():
        print(name, write(name, frames, loop, markers, os.path.join(out, f"{name}_v6.rbxmx")))
    open(os.path.join(out, "build_v6.luau"), "w", encoding="utf-8").write(luau_builder(CLIPS, "ClaudeClerkV6"))
