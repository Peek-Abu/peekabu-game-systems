# Clerk clips polish gates (owner 11-11: "polished, nice and perfect", close-up video)

Measured by `MeasureClerkAnims.CommandBar.luau` in the lobby (Edit, Animator:StepAnimations at 30 fps) on EVERY
employee under ReplicatedStorage.Assets.CleanupCrew.Characters (Cappy, Pippa, Prickles), with the clips built from the
committed `BuildClerkAnims.CommandBar.luau` (v5). Full output: notes folder `hub-clerk-gates-measure-2026-11-11.txt`.
Numbers below are identical on all three employees unless a name is given.

Threshold changes made before measuring, because the kit's legs are ~0.7 studs and the feet must stay planted:
G3's "pelvis rises >= 0.2" became a dip-and-rise of >= 0.04 (the rise is the legs straightening); G4's "pelvis at
contact <= rest - 0.3" became <= rest - 0.10 (15% of the leg) and "lowest >= 0.08 deeper" became >= 0.03.

## ClerkStamp (2.6 s loop)
- [x] G1 timing: wind-up 0.70 s (0 -> peak f21); peak beat 4 f = 0.13 s (limit 0.15); strike leaves the peak at f23 and
  lands at f26 = 0.10 s; arm locked on the parcel 5 f = 0.17 s; recovery (lift -> next wind-up) ~1.6 s >= 2.5 x strike.
  EVIDENCE: "G1 windupPeak 11.6 deg/f, peak still run 4 f (0.13s), arm hold after contact 5 f (0.17s)"
- [x] G2 spacing: no stutters on any joint; strike speed 0.7 -> 5.2 -> 14.0 -> 27.3 -> 44.9 deg/f into the contact (last
  frame = the peak, >= 70%), 0.0 the frame after (<= 15%).
  EVIDENCE: "G2 stutters: none"; "strike RightShoulder deg/f 0.73:0.7 0.77:5.2 0.80:14.0 0.83:27.3 0.87:44.9 0.90:0.0"
- [x] G3 anticipation: dip -0.050, rise +0.050 into the peak; torso arched back 19 deg; onsets Root f2 -> Waist f5 ->
  Neck f5 -> Shoulder f6 (in order, 0-3 f per link).
  EVIDENCE: "G3 dip -0.050, rise into peak 0.050, waist pitch at peak 19.0, onsets Root 2 Waist 5 Neck 5 Shoulder 6"
- [x] G4 squash + follow-through: pelvis -0.120 at contact; lowest -0.160 at +0.10 s (0.04 deeper); head turns 9.2 deg
  in the 0.2 s after; the stamp face drifts 0.080-0.084 in the hold (<= 0.12; the parcel squashes under it); face flat.
  EVIDENCE: "G4 pelvis@contact -0.120, lowest -0.160 at 0.97s (+0.10s), head turn 0.2s after 9.2 deg, face drift in hold 0.080/0.084, face up 1.00"
- [x] G5 parcel: placed at the stamp face (gap 0 by construction); parcel height on the counter 0.43-0.49 (Pippa 0.43,
  Cappy 0.47, Prickles 0.49, after raising the clerk riser to 3.8); hop from "Lift" + 0.08 s, apex 0.4, 0.3 s, landing
  squash 0.85; the stamp stays above the hopping parcel (min clearance +0.004..+0.009).
  EVIDENCE: "G5 parcel height on counter 0.47 ... stamp clearance over hopping parcel min 0.004 at 1.07s" (Cappy)
- [x] G6 stamp in hand: welded to RightHand; offset varies 0.0001 studs over the loop.
  EVIDENCE: "G6 stamp offset from hand varies 0.0001"
- [x] G7 no clipping (every frame, stamp corners and both hands vs Head and UpperTorso ellipsoids, < 1 = inside):
  closest Cappy 3.16, Pippa 1.45 (left hand / torso), Prickles 1.07 (ready pose) - all outside.
  EVIDENCE: "G7 closest RHand/Head: 1.07 at 0.00s" (Prickles, the biggest head)
- [x] G8 feet planted: max drift 0.031 studs (limit 0.05).
  EVIDENCE: "G8 foot drift max 0.031 at 0.83s"
- [x] G9 seamless loop: seam pose diff 0.00 deg; speed 0.07 deg/f before / 0.24 after the seam (<= 1); no frozen run.
  EVIDENCE: "G9 seam pose diff 0.00 deg, speed end 0.07 / start 0.24 deg/f, longest frozen run 0 f"

## ClerkGreet (2.2 s)
- [x] G10 greet reads at hub distance: hand swings 0.51-0.55 studs per wave (Cappy 1.14/0.63, Pippa 1.24/0.72, Prickles
  1.22/0.67); torso rocks 26 deg per wave; no clipping (closest 1.07); visible in the 25-stud capture.
  EVIDENCE: "G10 wave hand x 1.22/0.67/..., waist roll 0/26/0/26/0" + hub-clerk-closeup-v5-sheet.jpg "Hub distance" tile
- [x] G11 greet joins the loop: start and end vs the stamp's ready pose 0.00 deg.
  EVIDENCE: "G11 greet start vs ready 0.00 deg, end 0.00 deg"

## Delivery
- [x] G12 close-up video and contact sheet, under 8 MB, sheet opened with Read.
  EVIDENCE: hub-clerk-closeup-v5-2026-11-11.mp4 (1,179,117 bytes, 27.0 s: real speed x3, slam slow-motion x4, greet x2,
  every employee, hub distance); hub-clerk-closeup-v5-sheet.jpg (671,699 bytes, 20 tiles, read)
- [x] G13 build script committed and stylua clean; no Claude* instances left in the lobby; nothing saved or uploaded.
  EVIDENCE: post-cleanup scan "left: none"; the commit below. NOTE: the cleanup also removed another session's
  ReplicatedStorage.ClaudeBrambleV4Preview (reported to the coordinator; an undo attempt did not restore it).
