# Desk and Table Hiding Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** a player hiding under a desk or break table sits in the owner's knee-hug pose. To every client, they look like they're on the floor, back to the furniture, facing out, with nothing clipping. The furniture is enlarged to fit full-size employees.

**Architecture:**
- **Pose:** the owner's pose becomes shared data (`HideConstants.HUG_POSE`) that every client writes into the hider's joints, as the old tuck pose was.
- **Placement:** the server reads the hider's real rig and computes the posed body's extents. It then places the anchored root from the furniture's free-space box with pure formulas (`HideHugFormulas`). This replaces standing-height placement.
- **Furniture:** Office scales desks, break tables and chairs by one constant. Any desk or table that no longer fits is dropped.

**Tech Stack:** Luau `--!strict`, Rojo, TestEZ specs (run in Studio with the Workspace attribute `RunTests`), ServiceController services.

**Spec:** `docs/superpowers/specs/2026-10-20-odd-hours-desk-hiding-design.md`

## Global Constraints

- `--!strict`, no `any`, no casts. Follow `AGENTS.md`.
- Every new module gets a `.spec.luau` sibling, or a reason in `SpecRoots.EXEMPT_MODULES`.
- Commits: plain messages, **no trailers** (no Co-Authored-By). Stage files by name, never `git add -A` or `-a`. Never stage `src/ServerScriptService/Core/Testing/SpecRoots.luau` unless your task changes it; it carries someone else's uncommitted edit, and if you must change it, stage only your hunk.
- Do not push.
- Do not run `wally`, `rokit`, `rojo build` or `scripts/check.sh`. Run `selene <files>` and `stylua --check <files>` on the files you touch.
- Rojo serves this worktree live to Studio on ports 34872 and 34873. Never `git checkout`, `reset` or `stash` in it while working.
- Specs run only in Studio. Implementers write specs carefully; the controller runs the suite.
- Characters never shrink. The pose is the same for every employee, with no per-character animation.
- After adding a module, run `python3 scripts/python/module_map.py --write`.

## Review Focus

- **The Ear spring fighting the pose:** `EmployeeEarSystem` writes the ear joints every step. A hider's ears must hold the folded pose, not spring back up. Pinned in Task 1.
- **A turned break table:** `HideSpotUtils.spotFrame` turns tables π when the back is more open. Placement must face out of the side the player entered, with the back at the far edge. Pinned in Task 2 (`hugFrame` on a turned frame).
- **Gear on the body:** the backpack, vest and glasses are welded, not Motor6D-jointed. Extents that ignore them put the backpack through the desk's back panel. Pinned in Task 3.
- **A rig without ears or with missing joints:** a pose entry for a joint the rig lacks must be skipped, not error. Pinned in Tasks 1 and 3.
- **A dead or respawned hider:** exit and placement must not error on a character whose parts are gone. The MVP exit path already guards on Health; Task 4 must not add a path that indexes missing parts.

## New modules

| Feature | Realm | Subfolder | Name | Job (one line) |
|---|---|---|---|---|
| Hide | Shared | Utils | `HideHugFormulas` | Pure maths: the hug pose's joint CFrames, a posed rig's extents, and the hide frame from a free-space box |
| Hide | Server | Utils | `HideRigUtils` | Reads a live character into the plain `RigShape` the formulas take (joints, part sizes, welded gear) |
| Vacuum | Server | Systems | `VacuumHideSystem` | Puts the vacuum back on the backpack when its holder goes into a hiding spot |

---

### Task 1: The hug pose as data, written on every client

**Files:**
- Modify: `src/ReplicatedStorage/Shared/Features/Hide/Data/HideConstants.luau`. Add `HUG_POSE`; delete `TUCK_POSE` once nothing reads it.
- Create: `src/ReplicatedStorage/Shared/Features/Hide/Utils/HideHugFormulas.luau` (only `pose()` in this task) and its `.spec.luau`.
- Modify: `src/ReplicatedStorage/Client/Features/Hide/Utils/HidePoseFormulas.luau` (`targets` returns `HideHugFormulas.pose()`) and `HidePoseFormulas.spec.luau`.
- Modify: `src/ReplicatedStorage/Client/Features/Employee/Systems/EmployeeEarSystem.luau`. Skip the ear springs for a character whose Player has `HideConstants.PLAYER_SPOT_ATTRIBUTE` set, and leave its ear joints' Transform alone.

**Interfaces:**
- Produces: `HideConstants.HUG_POSE: { PoseJoint }`, reusing the existing `PoseJoint { joint, rotation: Vector3 (degrees, XYZ), offset: Vector3 }`, keyed by **Motor6D name**.
- Produces: `HideHugFormulas.pose(): { [string]: CFrame }`, with `CFrame.new(offset) * CFrame.fromEulerAnglesXYZ(rad x, rad y, rad z)` per entry.

`HUG_POSE` values are the owner's `HideHug2` pose, converted to joint names. Every `offset` is `Vector3.zero`, because placement, not the Root offset, puts the body on the floor:

```
Neck (25, 0, 0)            LeftEarBase (120, 0, 10)       RightEarBase (120, 0, -10)
Waist (-54.99, 0, 0)       Root (10, 0, 0)
LeftHip (105.40, 4.08, -11.29)                RightHip (105.40, -4.08, 11.29)
LeftKnee (-145, 0, 0)      RightKnee (-145, 0, 0)
LeftAnkle (35, 0, 0)       RightAnkle (35, 0, 0)
LeftShoulder (0, -75, 25)  RightShoulder (0, 75, -25)
LeftElbow (0, -45, 0)      RightElbow (0, 45, 0)
```

- [ ] **Step 1: Write the failing spec** `HideHugFormulas.spec.luau`. It has the following cases:
  - `pose()` has exactly the 17 joint names above.
  - `pose().LeftHip` is fuzzy-equal (each component within 1e-4) to `CFrame.fromEulerAnglesXYZ(math.rad(105.40), math.rad(4.08), math.rad(-11.29))`.
  - `pose().Root.Position` is `Vector3.zero`.
  - The left and right entries mirror each other: Hip, Shoulder, Elbow and EarBase have the same X, and negated Y and Z.

  Then update `HidePoseFormulas.spec`. Its old `targets.LeftHip` and `targets.Waist` values become the new ones, and "an entry for every `TUCK_POSE` joint" becomes every `HUG_POSE` joint.
- [ ] **Step 2: Run the specs in Studio** (the controller does this). Expected: the new cases fail, because `HideHugFormulas` doesn't exist yet.
- [ ] **Step 3: Implement** `HUG_POSE`, `HideHugFormulas.pose()` and `HidePoseFormulas.targets() = HideHugFormulas.pose()`. Then add the hider skip to `EmployeeEarSystem`. When the attribute clears, the springs resume from the current Transform, with no snap.
- [ ] **Step 4: The controller runs the specs.** Expected: all pass.
- [ ] **Step 5: Commit:** `Hide: the owner's knee-hug pose replaces the tuck pose; ear springs rest while hiding`.

### Task 2: Free space and the hide frame (pure)

**Files:**
- Modify: `src/ReplicatedStorage/Shared/Features/Hide/Data/HideTypes.luau`. Add the types below.
- Modify: `src/ReplicatedStorage/Shared/Features/Hide/Data/HideConstants.luau`:
  - add `free: FreeBox?` to `FurnitureDef`, filled for `desk` and `table`;
  - add `HUG_BACK_GAP = 0.05`;
  - add `HUG_FREE_MIN = Vector3.new(3.6, 4.2, 4.3)`.
- Modify: `HideHugFormulas.luau` and its spec.

**Interfaces:**
- Produces, in `HideTypes`:
  - `FreeBox = { min: Vector3, max: Vector3 }`. These are fractions of the furniture proxy's size, centred on the proxy, front = local −Z.
  - `RigJoint = { name: string, part0: string, part1: string, c0: CFrame, c1: CFrame }`.
  - `RigPiece = { part: string, base: string?, offset: CFrame, size: Vector3 }`. A piece with `base = nil` is a jointed body part; otherwise it is rigid on `base` at `offset`.
  - `RigShape = { root: string, joints: { RigJoint }, pieces: { RigPiece } }`.
- Produces: `HideHugFormulas.extents(rig: RigShape, pose: { [string]: CFrame }): (Vector3, Vector3)`.
  - It returns min and max in **root space**, over every piece's 8 corners. The root part itself is excluded.
  - A joint walk gives `world(part1) = world(part0) * c0 * (pose[name] or identity) * c1:Inverse()`, starting from the root at identity.
  - A joint whose `part0` is never reached is skipped.
- Produces: `HideHugFormulas.freeSize(free: FreeBox, size: Vector3): Vector3` returns `(free.max - free.min) * size`.
- Produces: `HideHugFormulas.hugFrame(spot: CFrame, size: Vector3, free: FreeBox, low: Vector3, high: Vector3, gap: number): CFrame`. It returns `spot * CFrame.new(p)`, where the free box in spot space is `free.min * size` to `free.max * size` and:
  - `p.X` = the free box's centre X minus `(low.X + high.X) / 2`;
  - `p.Y` = the free box's min Y minus `low.Y` (the body on the floor);
  - `p.Z` = the free box's max Z minus `gap` minus `high.Z` (the back to the furniture's back).

  The root keeps the spot's rotation, so the body faces −Z, out of the open side.

The free fractions were measured in Studio on 2026-10-20 against the proxy (desk 5×3×3, break table 5×3.1×3). Fractions scale with any furniture size:
- **desk:** `min = (-0.428, -0.5, -0.5)`, `max = (0.19, 0.4233, 0.3933)`. That is clear of the steel legs at x −2.14, the pedestal at x 0.95, the top's underside at y 1.27 and the modesty panel at z 1.18.
- **table:** `min = (-0.36, -0.5, -0.5)`, `max = (0.36, 0.3516, 0.5)`. The legs sit at about x ±2.0, the underside brace is at 2.64 above the floor, and the far edge is the back.

- [ ] **Step 1: Write the failing spec cases:**
  - `extents` of a two-piece rig, a root with one body part on a joint (`c0 = CFrame.new(0, 1, 0)`, `size = (1, 2, 1)`), with and without a 90° pose on that joint: the expected min and max are computed by hand in the spec.
  - A rigid piece (`base` set) follows its base through the pose.
  - A joint with an unknown `part0` is skipped without error.
  - `hugFrame` on an identity spot puts `low.Y` on `free.min.Y * size.Y` and `high.Z` at `free.max.Z * size.Z - gap`, and centres X.
  - On a spot turned π about Y, the same holds in the spot's own frame, and the returned LookVector equals the spot's.
  - `freeSize(FURNITURE.desk.free, Vector3.new(5, 3, 3))` is fuzzy-equal to `(3.09, 2.77, 2.68)` within 0.01.
- [ ] **Step 2: The controller runs the specs.** Expected: fail.
- [ ] **Step 3: Implement** the types, the constants, `extents`, `freeSize` and `hugFrame`.
- [ ] **Step 4: The controller runs the specs.** Expected: pass.
- [ ] **Step 5: Commit:** `Hide: free-space boxes for desks and tables and the hug placement formulas`.

### Task 3: Read a live character into a RigShape (server)

**Files:**
- Create: `src/ServerScriptService/Features/Hide/Utils/HideRigUtils.luau` and its `.spec.luau`.

**Interfaces:**
- Consumes: `HideTypes.RigShape` (Task 2).
- Produces: `HideRigUtils.read(character: Model): HideTypes.RigShape?`.
  - It returns `nil` when there is no `HumanoidRootPart`.
  - **joints:** every `Motor6D` in the character, using its `C0`, `C1` and the names of `Part0` and `Part1`.
  - **pieces:** every Motor6D `Part1` with `base = nil`, and every other visible `BasePart` (`Transparency < 1`) that is held by a `Weld`, `WeldConstraint` or `Motor6D`-free rigid joint to a jointed part. Each of those gets `base` set to that jointed part's name and `offset = base.CFrame:ToObjectSpace(part.CFrame)`. That offset is read from the current CFrames, which animation does not change for a rigid joint.
  - It skips a `Tool`'s parts: the vacuum goes to the backpack (Task 6). Pieces are keyed by part name, with a duplicate name suffixed by its order.

- [ ] **Step 1: Write the failing spec.** It builds a Model with a `HumanoidRootPart`, a `LowerTorso` on a `Root` Motor6D, an `UpperTorso` on a `Waist` Motor6D, and a `Backpack` part welded (WeldConstraint) to `UpperTorso` 1 stud behind it. It asserts:
  - 2 joints;
  - pieces include `Backpack` with `base == "UpperTorso"` and an offset Z of 1;
  - a model with no root returns `nil`;
  - a part inside a `Tool` is not a piece.
- [ ] **Step 2: The controller runs the specs.** Expected: fail.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: The controller runs the specs.** Expected: pass.
- [ ] **Step 5: Commit:** `Hide: read a character's joints and welded gear into a rig shape`.

### Task 4: Place hiders by the hug frame (server)

**Files:**
- Modify: `src/ServerScriptService/Features/Hide/HideServiceServer.luau`, at the entry (around lines 248-258).

**Interfaces:**
- Consumes: `HideRigUtils.read`, `HideHugFormulas.extents`, `HideHugFormulas.pose`, `HideHugFormulas.hugFrame`, `HideConstants.FURNITURE[kind].free` and `HUG_BACK_GAP`.

Behaviour:
- For a spot whose furniture def has `free` (desk, table), the tween target becomes:

  `hugFrame(spot.frame, spot.furniture.Size, def.free, extents(HideRigUtils.read(character), HideHugFormulas.pose()), HUG_BACK_GAP)`

  instead of `frames.hide`.
- If `read` returns `nil`, fall back to `frames.hide`.
- Everything else stays as it is: cabinets, the peek and exit frames, the anchoring, the tween, the attributes, and the exit path.
- Remove the `tuck` values for desk and table in `HideConstants` if nothing else reads them. Cabinet keeps its own.

- [ ] **Step 1: Implement the entry change.** The service is spec-exempt, and its maths is specced in Tasks 2 and 3. The existing `HideSpotUtils` and `HideRules` specs must still pass.
- [ ] **Step 2: The controller runs the full suite.** Expected: all pass.
- [ ] **Step 3: Commit:** `Hide: hiders sit on the floor, back to the furniture, from their posed size`.

### Task 5: Enlarge desks, break tables and chairs; drop what no longer fits (server, Office)

**Files:**
- Modify: `src/ServerScriptService/Features/Office/Data/OfficeConstants.luau`:
  - add `HIDE_FURNITURE_SCALE = 1.65`;
  - `DESK_SIZE = Vector3.new(5, 3, 3) * HIDE_FURNITURE_SCALE`;
  - `TABLE_SIZE = Vector3.new(5, 3.1, 3) * HIDE_FURNITURE_SCALE`;
  - `OFFICE_CHAIR_SIZE = Vector3.new(2.27, 3.562, 2.26) * HIDE_FURNITURE_SCALE`.
- Modify: `src/ServerScriptService/Features/Office/Systems/OfficeSearchedDressingSystem.luau`. Every hard-coded desk template position and size in `buildTemplate` (at 5×3×3) is multiplied by `DESK_SIZE / Vector3.new(5, 3, 3)`.
- Modify: `src/ServerScriptService/Features/Office/Systems/OfficeDeskVisualSystem.luau`. Monitor, keyboard and mouse positions scale the same way, so they sit on the bigger top.
- Modify: `src/ServerScriptService/Features/Office/Systems/OfficeDecorSystem.luau`. The chair candidate offsets (`±3.05`, `±4.05`, around lines 225-232) are derived from `DESK_SIZE` and `OFFICE_CHAIR_SIZE`: half the desk, plus half the chair, plus today's gap. A chair is never pushed under a desk.
- Modify: `src/ServerScriptService/Features/Office/Utils/OfficeLayoutUtils.luau` (and its spec). Add `dropUnfit`, described under Interfaces.
- Modify: `src/ServerScriptService/Features/Office/OfficeServiceServer.luau` (around line 125). Call `dropUnfit` between `generate` and `validate`, and log the dropped count once with `Logger`.
- Create the spec case in `OfficeLayoutUtils.spec.luau`, or a new `OfficeConstants`-adjacent spec in the Office feature: for desk and table, `HideHugFormulas.freeSize(HideConstants.FURNITURE[kind].free, size)` ≥ `HideConstants.HUG_FREE_MIN` on every axis.

**Interfaces:**
- Produces: `OfficeLayoutUtils.dropUnfit(layout, rules): (layout, number)`. It returns the layout without any desk or table marker that `OfficeLayoutRules` would reject at the current sizes (outside the room walls, or overlapping another marker or a door clearance), plus how many it dropped. Use the layout and marker types `OfficeLayoutRules.validate` already takes. Pure.
- Owner's rule: **remove, never rearrange or shrink.**

- [ ] **Step 1: Write the failing spec cases:**
  - the free-space floor for desk and table, as above;
  - `dropUnfit` on a two-marker layout where one desk crosses a wall returns one marker and a count of 1;
  - a layout where everything fits is returned unchanged with a count of 0.
- [ ] **Step 2: The controller runs the specs.** Expected: the free-space case fails at today's sizes.
- [ ] **Step 3: Implement** the scale, the template, the visuals, the chairs, `dropUnfit` and the call site.
- [ ] **Step 4: The controller runs the full suite.** Expected: all pass, including the existing layout, route and capacity checks on the generated office. If `checkRoute` or `checkCapacity` fails after the drop, stop and report. Do not move furniture.
- [ ] **Step 5: Commit:** `Office: desks, break tables and chairs 1.65x so employees fit underneath; drop any that no longer fit`.

### Task 6: The vacuum goes to the backpack on hiding (server, Vacuum)

**Files:**
- Create: `src/ServerScriptService/Features/Vacuum/Systems/VacuumHideSystem.luau` and its `.spec.luau`.
- Modify: `src/ServerScriptService/Features/Vacuum/VacuumServiceServer.luau`. Start the system in `start` and stop it in `stop`.

**Interfaces:**
- Produces: `VacuumHideSystem.new(deps: { unequip: (player: Player) -> () }): { watch: (player: Instance) -> (), stop: () -> () }`.
  - `watch` listens to the instance's `HideConstants.PLAYER_SPOT_ATTRIBUTE`. When it changes to a non-nil value, it calls `deps.unequip(player)` once.
  - The service passes `unequip = function(player) VacuumServiceServer:setEquipped(player, false) end`, without `resume`, so the vacuum stays on the backpack.
  - The service watches every player on join and stops on leave.

- [ ] **Step 1: Write the failing spec.** A `Configuration` instance stands in for the Player. Setting the attribute to `"desk.3"` calls `unequip` once; setting it back to `nil` calls nothing. After `stop`, nothing is called.
- [ ] **Step 2: The controller runs the specs.** Expected: fail.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: The controller runs the specs.** Expected: pass.
- [ ] **Step 5: Commit:** `Vacuum: hiding puts the vacuum back on the backpack`.

### Task 7: Verification in real play (controller and owner)

- [ ] **Step 1: Run the full suite in Studio** (hub, port 34872). Expected: 0 failures.
- [ ] **Step 2: Solo Play look check by the controller.** Hide under a desk and a break table with real key presses. From a pinned camera, screenshot the front and side. Measure that no visible part of the body goes below the floor or outside the furniture's free box.
- [ ] **Step 3: The owner's 2-player check** (Local Server, 2 players), watched from the second client, with the vacuum both in hand and on the back:
  - under a desk and under a break table;
  - face out, on the floor, nothing through anything;
  - ears folded;
  - the vacuum in hand goes to the backpack.

  **The plan is done only when the owner passes this.**
- [ ] **Step 4: Update the checklist artifact** (https://claude.ai/artifact/M84j26steQDLTxxNFYJ8TM) with the result.
