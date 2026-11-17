# Odd Hours: vacuum hold, post-launch update (do not forget)

Owner, 2026-11-16: "Fine we'll leave vacuum until a post launch later update! JUST ENSURE THIS ISN'T FORGOTTEN!"
Launch List row `g-vacuum-ik` (status "later", POST-LAUNCH UPDATE). The owner's original report: hands go INSIDE the
body as the mouse moves (Cappy's right arm and whole hand practically inside his torso; others too).

## What shipped for launch
- **A, in:** every hold guard measures the body a player sees, worn clothing included (Cappy's hoodie is a separate
  piece round a thin torso part). `VacuumBodyFormulas.box`, `VacuumBodyUtils.wornOn` / `chestBox`,
  `VacuumVisualSystem.visibleBody` → `VacuumHoldFormulas.clearForward` (`hold.armClear` / `maxClear`).
- **B, off** (`VacuumMotionConstants.chestFollow = 0`): hands riding the chest's sway. Three variants failed the
  vacuum harness (left paw off its grip, or the floor head dipping), because the reach guard
  (`VacuumMotionFormulas.wand`) and the hold plan assume root-held hands. A working B needs the reach guard taught
  about the follow.
- **C, off** (`VacuumMotionConstants.turnAboutPaws = false`): turning the wand about the paws' midpoint. It broke
  the reach guard's promise that turns are about the left grip and took a 60° turn to aim ahead (25° before).
- Joint limits (`IKControlConstraintSupport`) were not used: they only clamp angles and pulled paws off the wand.
- TestEZ on 10371ea6: 7325 passed, 0 failed.

## How it was measured
Shift Play, builder-built employees (no profile writes), the camera swept through 84 looks (pitch -65..25 step
15 × heading -180..150 step 30). The visible-body probe: per frame, a point is inside a body piece when a ray from
it to the piece's centre (Include filter, `CanQuery` on a client copy) hits nothing; depth = distance back to the
surface. Body = torso parts + visible pieces welded to them (not character children, the Tool or the backpack).
About 0.1 stud of every reading is the probe's own slack. Probed points: the hands and forearms, and (second round)
every Vacuum part's centre and ends. "Normal camera" = heading 0, pitch -35. The vacuum harness
(`AnimationVacuumHarness`, `H.format(H.run({}))`) checks both paws on their grips and the floor head above the floor
across the animation layers (Pippa and Cappy, both vacuum skins).

## Every try and its numbers (2026-11-16)
Studs inside the visible body at the normal camera; in brackets, looks over 0.1 of 84.

| Try | Harness | Cappy paws / vacuum | Prickles paws / vacuum | Pippa paws / vacuum |
|---|---|---|---|---|
| Shipped hold (A in, yaw 65°, out 0.05, forward 0.6) | PASS | 0.16 (47) / 0.26 (58) | 0.38 (56) / 0.41 (53) | 0.12 (27) / 0.31 (46) |
| Rest aim: yaw 50°, out 0.10 | FAIL: Pippa's left paw 0.23-0.25 off its grip | 0.11 (42) / - | worse in front view | paws clasp at chest |
| Rest aim: yaw 65°, out 0.12 / yaw 59°, out 0.07 | FAIL: Pippa, same | - | - | - |
| Side grip: yaw 40°, out 0.20, left grip x0.4 | PASS | 0.02 (39) / 0.15 (41); worst steep-down 0.45 (was 0.37) | 0.17 (21) / 0.06 (6) | 0.22 (45) / 0.12 (39) |
| Middle grip: yaw 50°, out 0.15, left grip x0.6 | PASS | - | - | 0.51 (42) / 0.25 (42) |
| Push the vacuum out: forward 0.7 | FAIL: Pippa's left paw 0.24 off; Cappy's left grip not in its paw | - | - | - |

Front views (picks page https://claude.ai/artifact/PTfri4JM8J1DeNyJKXyvTq, cards ikgrip and ikrest2): with the side
grip Cappy's paws still cross on his chest; rest aim at 35° hid the wand behind his arms.

**Why nothing global works:** while aiming, the wand's yaw follows the aim, so the rest angle hardly shows. The paws
meet in front of the body's middle because of the two-hand grip (GripLower low and in front of the middle). Pippa's
left paw is at the edge of its reach in the shipped hold, so any move of the vacuum to the right or forward takes it
off the wand. A constraint that pushes the vacuum out (AlignPosition and the like) hits the same reach limit.

## The two next options
1. **Grip layout per body, chosen by measurement.** A generic planner rule (no per-character tuning): plan the
   shipped layout and the side layout (yaw 40°, out 0.20, left grip x0.4), score each against the body's visible
   slices (the same `BodySlice`s `clearForward` uses, forearms and wand), keep the one that clips less and still
   reaches. Prickles gains most; Pippa keeps the shipped one.
2. **The left paw lets go when it can't reach.** Free the vacuum to sit clear of the body (forward / out), and let the
   left paw drop to a rest pose when the wand leaves its reach (the plan already has `left = nil`). Needs an owner
   look check: a one-handed vacuum reads differently.

Either one must pass the vacuum harness, the probe sweep for Pippa, Cappy and Prickles, front views, and the owner's
real-play check (a second client too).

## Studio trial switches (already in the code)
Read only when `RunService:IsStudio()`, from number attributes on Workspace (prefix
`VacuumVisualConstants.HOLD_OVERRIDE_PREFIX`), for holds planned after they are set (re-equip or rebuild):
- `DevVacuumHoldYaw` (degrees), `DevVacuumHoldOut`, `DevVacuumHoldForward` (fractions of the arm's reach),
  `DevVacuumHoldLowerScale` (scales how far down the tube the left paw holds). In `VacuumVisualSystem.holdFor`.
- `DevVacuumTurnAboutPaws` (bool, `VacuumMotionConstants.TURN_ABOUT_PAWS_ATTRIBUTE`) turns C on in Studio.
Remove every Dev attribute after a lab session; never save the place with them.

Lab recipe that worked: a server Script in Workspace (RunContext Server) listening to a `LabCmd` attribute
(`"build|Cappy|40|0.20|-|0.4"` sets the switches, builds with `EmployeeCharacterSystem.build` + `assign`, then
`VacuumServiceServer:setCrew` / `setEquipped`; `"harness|..."` runs the harness), a client probe with a Scriptable
camera sweep, and `screen_capture` with `camera_position` for front views. Mute every Sound on the client first.
