# Week 1 Polish (hiding, crouching, voice, rehire portrait, hide prompt) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Hiding and crouching look right from other players' screens, voice chat works for eligible players, the rehire card shows a round head-and-shoulders portrait, and the hide prompt offers the spot the player is facing.

**Architecture:** Two items (hiding, voice) are diagnose-first: each opens with an observation task (superpowers:systematic-debugging) that confirms the root cause from a second client's view before any fix lands, and the fix tasks are written per candidate cause, applied only for the confirmed ones. Crouch, the portrait and the hide prompt are small changes to existing modules, each pinned by a pure spec (crouch, prompt) or a UI Labs story (portrait). One new presentational UI module (`PortraitRing`) is extracted from the hub's profile ring so both cards share it.

**Tech Stack:** Roblox Luau (`--!strict`), Rojo, React (UI tree), TestEZ `.spec.luau`, Studio MCP, UI Labs.

**Spec:** `docs/superpowers/specs/2026-10-18-odd-hours-build-week-1-design.md` §6 "Polish". Also read `docs/superpowers/handoffs/2026-10-18-first-launch-build-week-1.md` ("Studio MCP testing limits", "Playtests and Rojo").

## Approval needed

- **Module placement:** nothing approval-gated. The one new module (`PortraitRing`) sits in the UI tree's existing `Screens/Portrait/` folder under the UI naming convention (named for what it shows); no new subfolder kind, role word or second service.
- **Owner decisions (ask as pick-one, before the task that needs them):**
  1. Crouch fix (Task 4): A, B, C or D (options in Task 4, Step 1). Recommended: **C**.
  2. Portrait look (Task 6): yes/no on the UI Labs screenshot of the round ring.
  3. Hide and crouch look (Tasks 2, 3, 5): yes/no from the 2-player screenshots.
- **Owner actions (they click; never drive their screen):**
  - Start every 2-player session: Test → Clients and Servers → 2 players → Local Server; press Cleanup when told.
  - Voice (Task 7): Game Settings → Communication → microphone on; save and publish the place after the VoiceChatService properties are set; two 13+ ID-verified, voice-enabled accounts for a live test.

## Global Constraints

- `--!strict`, no `any`, no casts (AGENTS.md).
- Spec-first: logic changes get a failing `.spec.luau` test first; every new first-party module has a `.spec` or a `SpecRoots.EXEMPT_MODULES` entry with a reason.
- Server-authoritative: clients never write authoritative state. Client-side prompt preference only hides prompts locally; the server re-checks every entry (HideRules).
- Commits: plain messages, **no `Co-Authored-By:` or `Claude-Session:` trailer**.
- Tests: Studio only. Set Workspace attribute `RunTests = true`, press Play, read Output, stop, set it back to `false`. Last full count: **3828** passing; every run must show 0 failures and a count of 3828 plus the tests this plan adds.
- Lint and format **changed files only** (Git Bash, from the worktree root): `selene <files>` and `stylua --check <files>`. No `wally`/`rokit` install, no `rojo build`, no full `check.sh` while the owner is connected.
- Studio: only the window "Odd Hours (placeId: 113354563835664)" (`list_roblox_studios`; the Local Server's server and client windows show unnamed). Never use computer-use.
- Playtest lock: `E:/Projects/peekabu-game-systems/docs/superpowers/studio-playtest.lock`. Check it is absent, create it, delete it after the session. Never overwrite another agent's lock.
- Rojo: `rojo serve default.project.json --port 34872`; check with `curl -s localhost:34872/api/rojo`. Rojo does **not** apply service property changes (VoiceChatService, StarterPlayer) during live sync: set those in the Edit DataModel via MCP too.
- MCP limits: `InputHoldBegin()` never reaches the server for instant prompts (Hide). Use `character_navigation` plus a real `user_keyboard_input` press of **C**. No MCP screenshot or camera change during a catch.
- UI follows `game-ui-design` (profile `cleanup-crew.md`: V1 "Gloom & Gleam", violet `#B79CFF` selected) and reuses the Toon kit.
- Out of scope: the "Crew caught" label (coat plan) and the Whole-crew-out XP gate (currencies plan).

## Review Focus

1. **A player who joins (or streams in) while someone is already hiding** should see them tucked, not standing. Task 3's fix reads the kind from the Player and is checked in Task 2 Step 6 with a late join.
2. **A spot that is not streamed in on the watching client** (StreamingEnabled) must not change the hider's pose. Task 3a pins `HidePoseFormulas.tucks` to the replicated kind, not a tag lookup.
3. **Hiding with a pocketable item in hand** (tiny or light) must not let Carry's sway or the vacuum rig undo the tuck on others' screens. This is checked in Task 2 Step 5 (spot × hands matrix) and fixed in Task 3c.
4. **Two prompts at nearly equal distance** must not make the prompt flicker between them as the player turns slightly. Task 8 adds the hysteresis test.
5. **A loaded crouch** (carrying a light item) must not drop the crouch-walk rate under `minRate` and slide backwards. Task 4 adds the loaded-speed assertion.

---

## New modules

| Feature | Realm | Subfolder | Name | Job (one line) |
|---|---|---|---|---|
| UI tree (outside features) | client | `Client/UI/React/Screens/Portrait/` | `PortraitRing` | The round character portrait on the kit's ring (lilac fill, ink stroke, white inner ring), shared by the hub profile and the rehire card. |
| Hide | client | `Client/Features/Hide/Utils/` | `HideFitFormulas` | Fits the under-furniture tuck to any character: root offset, tuck depth and the parts that still overflow (Task 3h). |

No other module is created. After adding it, run `python3 scripts/python/module_map.py --write`.

## File map

| File | Change |
|---|---|
| `src/ReplicatedStorage/Client/Features/Hide/Systems/HidePoseSystem.luau` | Hide fixes (Task 3) |
| `src/ReplicatedStorage/Client/Features/Hide/Utils/HidePoseFormulas.luau` (+ spec) | `tucks(kind)` (Task 3a) |
| `src/ServerScriptService/Features/Hide/HideServiceServer.luau` | Replicate the spot kind on the Player (Task 3a); exit order (Task 3e) |
| `src/ReplicatedStorage/Shared/Features/Hide/Data/HideConstants.luau` | `PLAYER_KIND_ATTRIBUTE`, tuning, prompt preference constants |
| `src/ReplicatedStorage/Shared/Features/Hide/Data/HideTypes.luau` | `PromptCandidate` |
| `src/ReplicatedStorage/Shared/Features/Hide/Utils/HideSpotUtils.luau` (+ spec) | `preferred` (Task 8) |
| `src/ReplicatedStorage/Client/Features/Hide/HideServiceClient.luau` | Prompt preference wiring (Task 8) |
| `src/ReplicatedStorage/Client/Features/Carry/Systems/CarrySwaySystem.luau`, `src/ReplicatedStorage/Shared/Features/Vacuum/Systems/VacuumMotionRigSystem.luau` | Skip hidden bodies, only if Task 2 confirms they override the tuck (Task 3c) |
| `src/ReplicatedStorage/Shared/Features/Crouch/Data/CrouchConstants.luau`, `src/ReplicatedStorage/Shared/Features/Employee/Data/EmployeeRegistry.luau` | Crouch speed and rate (Task 4) |
| `src/ReplicatedStorage/Client/Features/Employee/Utils/EmployeeLocomotionUtils.spec.luau`, `src/ReplicatedStorage/Shared/Features/Crouch/Utils/CrouchSpeedFormulas.spec.luau` | Crouch invariants (Task 4) |
| `src/ServerScriptService/Features/Voice/VoiceServiceServer.luau`, `src/ReplicatedStorage/Client/Features/Voice/VoiceServiceClient.luau` | Voice diagnostics in `getState`, confirmed fixes (Task 7) |
| `src/ReplicatedStorage/Client/UI/React/Screens/Portrait/PortraitRing.luau` | New (Task 6) |
| `src/ReplicatedStorage/Client/UI/React/Screens/Depot/DepotHubPanel.luau`, `.../Catch/CatchRehiredPanel.luau`, `.../Catch/CatchRehiredPanel.story.luau` | Use `PortraitRing` (Task 6) |
| `src/ServerScriptService/Core/Testing/SpecRoots.luau` | Exemption for `PortraitRing` (Task 6) |

---

### Task 1: Observation harness and baseline run

**Files:** none changed (diagnosis notes go in this plan's "Diagnosis log" at the end).

**Interfaces:**
- Produces: a baseline test count and a confirmed Studio setup used by Tasks 2, 5 and 7.

- [ ] **Step 1: Take the playtest lock**

Check `E:/Projects/peekabu-game-systems/docs/superpowers/studio-playtest.lock` is absent, then create it with your session name and the time.

- [ ] **Step 2: Start Rojo and confirm the sync**

Run: `curl -s localhost:34872/api/rojo`
Expected: JSON with `"projectName"`. If it fails, start `rojo serve default.project.json --port 34872` in an auto-restart loop and ask the owner to click Connect in the Rojo plugin.

- [ ] **Step 3: Baseline test run**

Set Workspace `RunTests = true` via MCP in the Odd Hours window, press Play, read Output, stop, set `RunTests = false`.
Expected: 3828 passed, 0 failed. Record the count in the Diagnosis log. Any failure here stops the plan: report it.

- [ ] **Step 4: Release the lock** (delete the lock file).

---

### Owner clarification (2026-10-18) — read before Tasks 2–3

The owner's "crouching looks bad" was **this hiding issue**: a player hiding **under** furniture, seen by
other players, has their body clipping through the desk/table all over. Crouch speed (Task 4, option C:
`CROUCH_SPEED = 6.5`, `crouchWalkMaxRate = 4`, picked by the owner) is a separate small fix.

**Hard requirement:** the fix must work for **every** employee (Pippa today, four more on the shared rig
with different proportions, ears, tails) **without custom hide animations per character**. So the under-spot
tuck must be **fitted generically**: from the spot's free volume (the clearance under the furniture) and the
character's actual part extents, solve where the root sits and how far the body tucks so no part of the
posed body intersects the furniture; anything that still pokes through after the fit (long ears, accessories)
gets a generic fallback decided by the same pure rule (fold the joint further toward the free space, else
hide that part on watchers' screens). The fit math is a pure, specced rule over boxes and joints, not
per-character data. H1 below is the leading hypothesis; Task 3 gets sub-task **3h** for it.

**Done when:** from a second client, Pippa and at least one differently proportioned test rig (default R15
plus an Employee Kit variant with long ears) hide under a desk and a table with no visible part through the
furniture, from front, side and above, and the hider's own view is unchanged.

### Task 2: Diagnose hiding from a second client (owner-assisted)

REQUIRED SUB-SKILL: superpowers:systematic-debugging. No fix code in this task.

**Files:** temporary diagnostic code only (never committed; `git diff` must be empty at the end).

**Interfaces:**
- Produces: for each spot type (under-desk, under-table, cabinet), which of the candidate causes H1–H6 are **confirmed**, recorded in the Diagnosis log. Task 3 applies only the matching sub-tasks.

Candidate causes to test (from reading the code; each needs evidence, not belief):

| Id | Candidate | Evidence that confirms it |
|---|---|---|
| H1 | The local view is "fine" only because the hider's own body is hidden from their peek camera (HideServiceClient `setBodyShown(false)`): the tuck itself (TUCK_POSE + FURNITURE tuck) clips the furniture for **every** viewer. | Client 2 sees the body fully tucked (weight 1) and still clipping the desk/table top, legs or sides. |
| H2 | `HidePoseSystem.kindOf` reads the spot's tagged Attachment on the watching client. With StreamingEnabled the Attachment may not exist there yet: an unknown spot defaults to "under" (a cabinet hider gets folded), and the fold is decided once at the attribute change and never re-checked. | On client 2, `CollectionService:GetTagged("HideSpot")` lacks the hider's spot id at the moment of entry, or a cabinet hider shows the tuck when the door opens. |
| H3 | Another PreSimulation writer overrides the tucked joints after HidePoseSystem: CarrySwaySystem (shoulders/arms while carrying a pocketable item) or VacuumMotionRigSystem (arms on everyone with the backpack vacuum). | On client 2, a posed Motor6D's `Transform` read in `PostSimulation` differs from `HidePoseFormulas.blend(...)` at weight 1, and the difference goes away with the item/vacuum gone. |
| H4 | The hider's replicated animation tracks (the owner's Animate) are not idle while anchored (fall/walk/run), so unposed joints (ears, tail, head roll) and the blend in/out look wrong. | On client 2, the hider's `Animator:GetPlayingAnimationTracks()` shows a non-idle locomotion track during the stay. |
| H5 | The cached `fold.joints` hold Motor6Ds from a streamed-out/streamed-in copy of the character, so writes go to dead joints. | On client 2, a cached `posed.motor.Parent == nil` or not a descendant of `player.Character`. |
| H6 | The server's anchored tween in, and the instant exit move (`exitFrame` then unanchor) while client 2 is still untucking over UNTUCK_SECONDS, read as a teleport and a folded body standing in the aisle. | Recorded root positions on client 2 step (no interpolation) during the 0.25 s slide, or the exit frame shows the body still folded outside the furniture. |

- [ ] **Step 1: Ask the owner to start a 2-player Local Server**

Message: "Please start Test → Clients and Servers → 2 players → Local Server in the Odd Hours window, and tell me when both client windows are up." Take the playtest lock first (Task 1 Step 1). Then `list_roblox_studios` and identify Server, Player1 and Player2 windows (unnamed; tell them apart by `game.Players.LocalPlayer.Name` in a code run, or by the server having no LocalPlayer).

- [ ] **Step 2: Find one of each spot and put Player2 where it can see it**

In the server window, list the spots (temporary server Script calling `HideServiceServer:spots()`, kept alive until the step ends) with id, kind, noun and anchor world position. Pick one desk, one table and one cabinet. Move Player2 with `character_navigation` to about 8 studs in front of the spot, facing it.

- [ ] **Step 3: Hide Player1 in each spot**

Move Player1 with `character_navigation` to the spot's front and send a real `user_keyboard_input` press of **C** to the Player1 window. Confirm on the server: Player1's `HideSpotId` attribute equals the spot id.

- [ ] **Step 4: Capture what Player2 sees, per spot**

From Player2's window: screenshot (front and a 45° side view, by moving Player2, not the camera), then run on the Player2 client (MCP code run on that window; if it only reaches the server, add a temporary `print` block in `HidePoseSystem` behind `Workspace:GetAttribute("HideDebug")`, revert after) and record:
- `kindOf(spotId)` result and whether the spot's tagged Attachment exists (H2);
- each posed joint's `Transform` read in `RunService.PostSimulation` vs the expected `HidePoseFormulas.blend(_, target, 1)` (H3);
- Player1's `Animator:GetPlayingAnimationTracks()` names and weights (H4);
- each cached motor's `Parent` and `IsDescendantOf(player.Character)` (H5);
- Player1's root `CFrame` every frame for 0.5 s from the C press, and again from the exit press (Space) (H6).

- [ ] **Step 5: Repeat Step 3–4 holding a pocketable item and with the backpack vacuum** (for H3), and once with Player2 out of streaming range at the moment of entry (walk Player2 out of the room, hide Player1, walk back) (for H2, H5).

- [ ] **Step 6: Late join check**

Ask the owner to add a third player (Test → Clients and Servers → Add player, if available; otherwise stop and restart with 3) while Player1 is hidden; record whether the newcomer sees the tuck (Review Focus 1).

- [ ] **Step 7: Record and clean up**

Write the per-spot table (spot type × H1–H6: confirmed / ruled out / not seen, with the evidence) in the Diagnosis log. Ask the owner to press Cleanup. Revert any temporary code (`git diff` empty). Delete the lock.

- [ ] **Step 8: Commit the diagnosis log**

```bash
git add docs/superpowers/plans/2026-10-18-week1-polish.md
git commit -m "docs: record hiding diagnosis from a second client"
```

---

### Task 3: Fix hiding for the confirmed causes

Apply only the sub-tasks whose cause Task 2 confirmed, **plus 3h, which is always required**. Each sub-task is its own commit. If Task 2 found a cause not in H1–H6, stop and add a sub-task here before coding (systematic-debugging: one hypothesis, one fix).

**Files:** see each sub-task.

**Interfaces:**
- Consumes: Task 2's confirmed causes.
- Produces: `HideConstants.PLAYER_KIND_ATTRIBUTE = "HideSpotKind"` (Task 3a), set on the Player by the server whenever `PLAYER_SPOT_ATTRIBUTE` is set and cleared with it; `HidePoseFormulas.tucks(kind: unknown): boolean`.

#### 3h (H1): character-agnostic tuck fit (owner requirement — always required)

- [ ] **Step 1: Write the failing tests** in a new pure Utils module `HideFitFormulas` (Client realm, Hide
  feature, Utils; add it to the New modules table): `HideFitFormulas.fit(spot: { size: Vector3, cframe: CFrame }, parts: { { name: string, size: Vector3, cframe: CFrame } }) -> { rootOffset: CFrame, tuck: number, overflow: { string } }`.
  Specs: a 2×5×1 body fits a 4×3×6 clearance with `overflow` empty; a body taller than the clearance raises
  `tuck` to 1 and lists only the parts still crossing the top plane in `overflow`; a long-ears rig lists the
  ear parts and nothing else; the result never moves the root outside the spot's footprint.
- [ ] **Step 2: Run the suite** — Expected: FAIL (module missing).
- [ ] **Step 3: Implement** the fit (box-vs-plane tests per part after the tuck pose; solve root offset
  first, then tuck depth), then wire `HidePoseSystem` to apply `rootOffset`/`tuck` per watcher and the
  fallback for `overflow` parts (fold toward free space, else `LocalTransparencyModifier = 1` on watchers only;
  the hider's own view unchanged).
- [ ] **Step 4: Run the suite** — Expected: PASS.
- [ ] **Step 5: Verify from a second client** per the clarification's "Done when" (owner starts the
  Local Server); record screenshots in the Diagnosis log.
- [ ] **Step 6: Commit** — `git commit -m "Hide: fit the under-furniture tuck to any character's proportions"`

#### 3a (H2): read the spot kind from the hiding Player, not the spot's tag

- [ ] **Step 1: Write the failing test** in `src/ReplicatedStorage/Client/Features/Hide/Utils/HidePoseFormulas.spec.luau`

```lua
describe("tucks", function()
	it("tucks under furniture, stands inside a cabinet", function()
		expect(HidePoseFormulas.tucks("under")).to.equal(true)
		expect(HidePoseFormulas.tucks("inside")).to.equal(false)
	end)
	it("does not tuck for a missing or malformed kind (never a guess)", function()
		expect(HidePoseFormulas.tucks(nil)).to.equal(false)
		expect(HidePoseFormulas.tucks(3)).to.equal(false)
		expect(HidePoseFormulas.tucks("locker")).to.equal(false)
	end)
end)
```

- [ ] **Step 2: Run the suite (Studio, Global Constraints)** — Expected: FAIL, `tucks` is nil.

- [ ] **Step 3: Implement**
  - `HidePoseFormulas.tucks(kind: unknown): boolean` — true only for `"under"`.
  - `HideConstants.PLAYER_KIND_ATTRIBUTE = "HideSpotKind"` (with a one-line comment beside `PLAYER_SPOT_ATTRIBUTE`).
  - `HideServiceServer.enter`: set `PLAYER_KIND_ATTRIBUTE` to `spot.kind` **before** setting `PLAYER_SPOT_ATTRIBUTE`; the exit path clears both (kind after spot).
  - `HidePoseSystem`: delete `kindOf`; `update` decides `hiding = type(spotId) == "string" and HidePoseFormulas.tucks(player:GetAttribute(HideConstants.PLAYER_KIND_ATTRIBUTE))`, and also listens to the kind attribute's changed signal.

- [ ] **Step 4: Run the suite** — Expected: PASS, 0 failures.

- [ ] **Step 5: Lint, format, commit**

```bash
selene src/ReplicatedStorage/Client/Features/Hide src/ServerScriptService/Features/Hide/HideServiceServer.luau src/ReplicatedStorage/Shared/Features/Hide/Data/HideConstants.luau
stylua --check src/ReplicatedStorage/Client/Features/Hide src/ServerScriptService/Features/Hide/HideServiceServer.luau src/ReplicatedStorage/Shared/Features/Hide/Data/HideConstants.luau
git add src/ReplicatedStorage/Client/Features/Hide src/ServerScriptService/Features/Hide/HideServiceServer.luau src/ReplicatedStorage/Shared/Features/Hide/Data/HideConstants.luau
git commit -m "fix(hide): replicate the spot kind so every client poses hiders the same"
```

#### 3b (H5): re-find the posed joints when they leave the character

- [ ] **Step 1: Implement** in `HidePoseSystem`: re-scan `fold.joints` when `fold.character ~= character` **or** any cached `posed.motor.Parent == nil` (cheap check of the first entry plus a `character.DescendantAdded` flag set when a `Motor6D` is added). Shell change (spec-exempt module); no spec.
- [ ] **Step 2: Verify** with Task 2 Step 5's streaming scenario (owner-assisted session): client 2 shows the tuck after walking back into range.
- [ ] **Step 3: Lint, format, commit** — `git commit -m "fix(hide): re-find the tucked joints after a character streams back in"`

#### 3c (H3): other Transform writers leave a hidden body alone

- [ ] **Step 1: Write the failing test** for the rule the writers share. Add to `src/ReplicatedStorage/Shared/Features/Hide/Rules/HideRules.spec.luau`:

```lua
describe("bodyPosedByHide", function()
	it("is true while the player hides under furniture", function()
		expect(HideRules.bodyPosedByHide("desk.3", "under")).to.equal(true)
	end)
	it("is false inside a cabinet, or not hiding", function()
		expect(HideRules.bodyPosedByHide("cabinet.1", "inside")).to.equal(false)
		expect(HideRules.bodyPosedByHide(nil, nil)).to.equal(false)
	end)
end)
```

- [ ] **Step 2: Run the suite** — Expected: FAIL.
- [ ] **Step 3: Implement** `HideRules.bodyPosedByHide(spotId: unknown, kind: unknown): boolean` (`type(spotId) == "string" and kind == "under"`). In each writer Task 2 confirmed (CarrySwaySystem step, VacuumMotionRigSystem write), skip the character when `HideRules.bodyPosedByHide(player:GetAttribute(PLAYER_SPOT_ATTRIBUTE), player:GetAttribute(PLAYER_KIND_ATTRIBUTE))`, restoring the joint to `CFrame.identity` once (the writers' existing release path) so nothing stale stays on it. Depends on 3a's attribute; if 3a was not needed, still add `PLAYER_KIND_ATTRIBUTE` per 3a Step 3's server part.
- [ ] **Step 4: Run the suite** — Expected: PASS.
- [ ] **Step 5: Lint, format, commit** — `git commit -m "fix(hide): carry sway and the vacuum rig leave a tucked body alone"`

#### 3d (H1): retune the tuck so the body fits under each piece

- [ ] **Step 1: Measure** on client 2 (owner-assisted session) for desk and table: the tucked body's bounding box (`character:GetBoundingBox()` after the pose) vs the furniture's underside box (top's bottom face, legs, pedestal). Record overlaps in the Diagnosis log.
- [ ] **Step 2: Adjust** `HideConstants.FURNITURE.<noun>.tuck` (`along`, `back`, `yaw`) and, only if the pose itself overlaps, `TUCK_POSE` (Root offset Y, hip/knee/waist angles). Tuning values only (HideConstants is spec-exempt). If `HideSpotUtils.spec` pins a tuck value that changes, update that expectation in the same commit.
- [ ] **Step 3: Verify** from client 2: no part of the body crosses the desktop, the pedestal or a table leg, from front and 45° side; screenshots to the owner for a yes/no.
- [ ] **Step 4: Run the suite** — Expected: PASS.
- [ ] **Step 5: Commit** — `git commit -m "tune(hide): fit the tucked body under desks and tables"`

For the cabinet (spot "inside", standing): if Task 2 showed the head or ears through the cabinet top or sides, adjust `FURNITURE.cabinet.tuck.back` and, if the standing body is taller than the interior, make the cabinet use a shorter stand pose by adding `"inside"` handling to `HidePoseFormulas.tucks` only after the owner approves a crouched-in-cabinet look. Same verify/commit steps.

#### 3e (H6): smooth the way in and out for others

- [ ] **Step 1: Implement** in `HideServiceServer`:
  - exit: clear `PLAYER_SPOT_ATTRIBUTE` (so every client starts untucking) **then** wait `HideConstants.UNTUCK_SECONDS` before the exit move and unanchor (`task.delay`, re-checking the body still exists); the exit noise and `exited` signal keep their current timing.
  - in: no code change unless Task 2 recorded stepped root positions; then keep the server tween (authoritative) and note it in the Diagnosis log as accepted (engine property replication; a client-side visual smoothing layer is a later task, not this week).
- [ ] **Step 2: Verify** from client 2: coming out reads as unfold-then-step-out, no folded body in the aisle.
- [ ] **Step 3: Run the suite, lint, format, commit** — `git commit -m "fix(hide): unfold before stepping out so others see a clean exit"`

---

### Task 4: Crouch speed matched to the crouch walk

**Files:**
- Modify: `src/ReplicatedStorage/Shared/Features/Crouch/Data/CrouchConstants.luau:20` and its header comment
- Modify: `src/ReplicatedStorage/Shared/Features/Employee/Data/EmployeeRegistry.luau:172-185` (Pippa's `crouchWalkMaxRate` and its comment)
- Test: `src/ReplicatedStorage/Client/Features/Employee/Utils/EmployeeLocomotionUtils.spec.luau`, `src/ReplicatedStorage/Shared/Features/Crouch/Utils/CrouchSpeedFormulas.spec.luau`

**Interfaces:**
- Consumes: `EmployeeLocomotionUtils.forName("Pippa") -> Config?` (`crouchScale`, `crouchMaxRate`, `minRate`), `CrouchSpeedFormulas.speed(weight: number?) -> number`.

Today: Pippa's crouch walk plants 1.3 × 1.25 = 1.625 st/s at rate 1, capped at rate 2 → 3.25 st/s; `CROUCH_SPEED = 9` slides the feet 2.8×.

- [ ] **Step 1: Ask the owner to pick** (one message, pick-one):
  - **A.** Keep speed 9, raise `crouchWalkMaxRate` to 5.6 (feet plant; a fast, scurrying cadence).
  - **B.** Lower `CROUCH_SPEED` to 3.25 (feet plant; a very slow creep, 20 % of the walk).
  - **C. (recommended)** `CROUCH_SPEED = 6.5` and `crouchWalkMaxRate = 4` (6.5 st/s plants exactly; 40 % of the walk, still clearly a sneak; cadence about 6 steps a second).
  - **D.** Re-author the crouch walk with a longer stride (authoring skill, new clip upload) and keep 9: best look, most work, not this week.
  Record the pick in the Diagnosis log. The test below uses C's values; for A or B change only the constants.

- [ ] **Step 2: Write the failing tests**

In `EmployeeLocomotionUtils.spec.luau` (inside the existing `describe`):
```lua
it("plants Pippa's crouch walk at the crouch speed (feet slide under 10 %)", function()
	local config = EmployeeLocomotionUtils.forName("Pippa")
	local planted = config.crouchScale * config.crouchMaxRate
	expect(CrouchConstants.CROUCH_SPEED / planted <= 1.1).to.equal(true)
end)
it("keeps a loaded crouch above the minimum rate (no backward slide)", function()
	local config = EmployeeLocomotionUtils.forName("Pippa")
	-- The slowest any load makes a crouch: Carry's speed floor.
	local slowest = CrouchConstants.CROUCH_SPEED * CarryConstants.MIN_SPEED_MULTIPLIER
	expect(slowest / config.crouchScale >= config.minRate).to.equal(true)
end)
```
Requires at the top of the spec: `CrouchConstants` (`Shared.Features.Crouch.Data`) and `CarryConstants` (`Shared.Features.Carry.Data`). If the loaded rate falls under `minRate` with the picked option, report it in the Diagnosis log instead of changing `minRate`.

In `CrouchSpeedFormulas.spec.luau`, replace the "55-60 % of the walk" range with the picked option's range (C: `fraction >= 0.38 and fraction <= 0.42`), and rename the test to say so.

- [ ] **Step 3: Run the suite** — Expected: FAIL on the planting test (2.77 > 1.1) and the fraction test.

- [ ] **Step 4: Implement** — `CROUCH_SPEED = 6.5`, Pippa `crouchWalkMaxRate = 4`; rewrite both comments with the new numbers (the CrouchConstants header's "56 % of the walk" and the EmployeeRegistry note on sliding).

- [ ] **Step 5: Run the suite** — Expected: PASS, 0 failures.

- [ ] **Step 6: Lint, format, commit**

```bash
git add src/ReplicatedStorage/Shared/Features/Crouch src/ReplicatedStorage/Shared/Features/Employee/Data/EmployeeRegistry.luau src/ReplicatedStorage/Client/Features/Employee/Utils/EmployeeLocomotionUtils.spec.luau
git commit -m "fix(crouch): match the crouch speed to Pippa's crouch walk so the feet plant"
```

---

### Task 5: Crouch from both views (owner-assisted)

REQUIRED SUB-SKILL: superpowers:systematic-debugging for anything still wrong.

**Files:** none unless a cause is confirmed.

- [ ] **Step 1: 2-player Local Server** (owner starts it; take the lock). Player1 crouch-walks (hold Left Ctrl via `user_keyboard_input`, move with `character_navigation`) past Player2, empty-handed and with a light item.
- [ ] **Step 2: Record from both windows**: feet planting (screenshot sequence), on Player2 the replicated track (`GetPlayingAnimationTracks()` → crouch walk's `Speed`, compared with Player1's own), and whether the body drops on Player2 at the same moment as on Player1 (the `Crouching` attribute).
- [ ] **Step 3: Classify**. Known candidates: (C1) track speed not replicated, so Player2 plays the crouch walk at rate 1 → if confirmed, record it and set the clip's rate from the `Crouching` attribute and replicated root velocity on observers in a follow-up plan (no fix this week without the owner's yes); (C2) the crouch idle/walk poses clip the floor because HipHeight is unchanged → record with screenshots and ask the owner whether to re-author the clips (authoring skill) or lower HipHeight on crouch. Anything else: add a sub-task before coding.
- [ ] **Step 4: Owner look check**: send the screenshots, ask yes/no. Cleanup, delete the lock, record in the Diagnosis log, commit the log (`git commit -m "docs: record crouch check from both views"`).

---

### Task 6: Round rehire portrait

Follow `game-ui-design` (profile `cleanup-crew.md`): reuse the hub's ring exactly; the ring breaks the header band's corner like the render did.

**Files:**
- Create: `src/ReplicatedStorage/Client/UI/React/Screens/Portrait/PortraitRing.luau`
- Modify: `src/ReplicatedStorage/Client/UI/React/Screens/Depot/DepotHubPanel.luau:140-165` (use `PortraitRing`)
- Modify: `src/ReplicatedStorage/Client/UI/React/Screens/Catch/CatchRehiredPanel.luau:250-262`
- Modify: `src/ReplicatedStorage/Client/UI/React/Screens/Catch/CatchRehiredPanel.story.luau` (if it does not already render the header art)
- Modify: `src/ServerScriptService/Core/Testing/SpecRoots.luau` (exemption)

**Interfaces:**
- Produces:
```lua
export type PortraitRingProps = {
	userId: number?,
	model: Model?,
	context: EmployeePoseRegistry.PortraitContext,
	framing: PortraitViewModel.Framing,
	size: number, -- outer diameter, design px
	phone: boolean?, -- thinner strokes (4 / 2 instead of 6 / 4)
	position: UDim2?,
	anchor: Vector2?,
	zIndex: number?,
}
PortraitRing(props: PortraitRingProps): React.ReactNode
```

- [ ] **Step 1: Extract `PortraitRing`** from DepotHubPanel's `portrait` frame (lilac `shade("lilac").hi` fill, `UICorner` 0.5, ink `UIStroke` 6/4, inner white ring `UIStroke` 4/2 inset 10, `CharacterPortrait` inset 12 with `round = true`). DepotHubPanel renders `PortraitRing` with `context = "profile"`, `framing = "bust"` and its current size and phone flag; its look must not change.
- [ ] **Step 2: Add the exemption** in `SpecRoots.EXEMPT_MODULES`: `["ReplicatedStorage.Client.UI.React.Screens.Portrait.PortraitRing"] = "presentational React component (framing specced in PortraitViewModel; stories in DepotHubPanel.story and CatchRehiredPanel.story)"`.
- [ ] **Step 3: Use it on the rehire card**: the header `art(size)` returns `PortraitRing` with `context = "caught"`, `framing = "bust"` (head and shoulders), `size = size * 1.1`, centred, and the header's existing break-the-corner placement. Update the comment above it (round frame, head and shoulders).
- [ ] **Step 4: Check in UI Labs** (EDIT mode, no Play): `CatchRehiredPanel.story` desktop and phone, and `DepotHubPanel.story` unchanged. Run the profile's red-flag check from `game-ui-design` (ring attached, outline matches the kit, no cut ears showing outside the circle, readable at phone size). Screenshot both, send the rehire one to the owner for a yes/no on the look.
- [ ] **Step 5: Run the suite** (SpecRoots must stay green) — Expected: PASS, 0 failures.
- [ ] **Step 6: Module map, lint, format, commit**

```bash
python3 scripts/python/module_map.py --write
selene src/ReplicatedStorage/Client/UI/React/Screens/Portrait/PortraitRing.luau src/ReplicatedStorage/Client/UI/React/Screens/Depot/DepotHubPanel.luau src/ReplicatedStorage/Client/UI/React/Screens/Catch src/ServerScriptService/Core/Testing/SpecRoots.luau
stylua --check src/ReplicatedStorage/Client/UI/React/Screens/Portrait/PortraitRing.luau src/ReplicatedStorage/Client/UI/React/Screens/Depot/DepotHubPanel.luau src/ReplicatedStorage/Client/UI/React/Screens/Catch src/ServerScriptService/Core/Testing/SpecRoots.luau
git add src/ReplicatedStorage/Client/UI/React/Screens src/ServerScriptService/Core/Testing/SpecRoots.luau docs/project-structure.md
git commit -m "feat(ui): round head-and-shoulders portrait on the rehire card"
```
- [ ] **Step 7: After the owner's verdict**, append a row to the `cleanup-crew.md` taste log (date, "Rehire card round ring portrait", verdict, rule).

---

### Task 7: Voice check-and-fix (owner-assisted)

REQUIRED SUB-SKILL: superpowers:systematic-debugging. This is a check, not a feature: no new routing behaviour.

**Files:**
- Modify: `src/ServerScriptService/Features/Voice/VoiceServiceServer.luau` (`getState` only, plus confirmed fixes)
- Modify: `src/ReplicatedStorage/Client/Features/Voice/VoiceServiceClient.luau` (`getState` only, plus confirmed fixes)
- Test: `src/ReplicatedStorage/Shared/Features/Voice/Rules/VoiceRoutingRules.spec.luau` (only if V5 is confirmed)

**Interfaces:**
- Produces (debugger-visible, F4 → Services): server `getState()` adds `perInput = { [string userId]: { muted: boolean, player: boolean, accessList: string } }`; client `getState()` adds `voiceEnabled: boolean?` (`VoiceChatService:IsVoiceEnabledForUserIdAsync(localPlayer.UserId)`, fetched once at start in a `pcall`), `ownInput: { exists: boolean, muted: boolean? }`, `routes: { [string userId]: string }`.

Candidate causes:

| Id | Candidate | How to check |
|---|---|---|
| V1 | VoiceChatService properties never reached the place (Rojo live sync skips service properties). | MCP read in the Edit DataModel: `EnableDefaultVoice == false`, `UseAudioApi == Enum.AudioApiRollout.Enabled`. |
| V2 | The place's microphone setting is off (Game Settings → Communication). | Owner looks; a published-place setting, not in the file. |
| V3 | The testers are not eligible (13+, ID-verified, voice on in account settings) or Studio test players were used (negative ids never stream). | Client `voiceEnabled` in F4; live test only with real accounts. |
| V4 | The wiring is incomplete on a client: no `VoiceInput` under the speaker, no `VoiceEmitter` on their Head (streamed-out Head), or the `VoiceListener` is not wired to `VoiceOutput`. | F4 state + MCP instance tree in a Play Solo and in the live test. |
| V5 | The speaker's own client is outside their input's Allow list, which blocks capture (`listenersOf` excludes the speaker). | Check the Creator docs for `AudioDeviceInput.AccessType` / `SetUserIdAccessList` first; then live: the speaker's `ownInput.muted == false` yet no audio reaches anyone, and adding the speaker to the list fixes it. |
| V6 | The speaker's input is muted by the top-bar mic (with `EnableDefaultVoice = false` the top bar drives the local player's `AudioDeviceInput.Muted`). | F4 `ownInput.muted` before and after toggling the top-bar mic. |

- [ ] **Step 1: V1 in the Edit DataModel.** Read both properties via MCP. If either is wrong, set it via MCP in the Edit DataModel (matching `default.project.json`) and ask the owner to save and publish.
- [ ] **Step 2: V2.** Ask the owner: "In Game Settings → Communication, is Microphone on? If not, please turn it on and save." Record the answer.
- [ ] **Step 3: Add the diagnostics to both `getState`s** (shell modules, spec-exempt). Lint, format, run the suite (PASS), commit: `git commit -m "chore(voice): show voice wiring and eligibility in the debugger"`.
- [ ] **Step 4: Play Solo wiring check (V4 partial).** One Play Solo: server has `Players.<you>.VoiceInput` with `Player` set and `AccessType = Allow`; client has `Camera.VoiceListener` with a `Wire` to `Players.<you>.VoiceOutput`; F4 shows `voiceEnabled`. Note: a solo session cannot prove audibility.
- [ ] **Step 5: Live test (owner-assisted).** The owner publishes, then joins one live server with a second eligible account. Read both clients' F4 Voice state (the owner reads it out or screenshots it) and the server state via the Developer Console's server log. Record V3–V6 results.
- [ ] **Step 6: Fix only the confirmed causes:**
  - V5 confirmed: write the failing test first in `VoiceRoutingRules.spec.luau` — `it("lets the speaker's own client capture: the access list includes the speaker", ...)` expecting `listenersOf(1, infos, true)` to contain `1`; then change `listenersOf` to include the speaker and update its doc comment; run (FAIL → PASS).
  - V4 (Head streamed out and back in as a new part): in `VoiceServiceClient`'s character observer, also call `tracker:setHead(userId, headOf(character))` on `character.ChildAdded` / `ChildRemoved` of a part named `Head`, so the emitter follows the live Head (VoiceWiringTracker already rewires on a head change; add a tracker spec case only if its behaviour changes); verify live.
  - V6: no code; tell the owner the top-bar mic is the mute.
  - V1/V2/V3: owner settings only.
- [ ] **Step 7: Verify live**: two eligible players hear each other spatially (louder near, silent past 80 studs). Record in the Diagnosis log.
- [ ] **Step 8: Lint, format, run the suite, commit** — `git commit -m "fix(voice): <the confirmed cause, in words>"` (one commit per confirmed code cause).

---

### Task 8: Hide prompt prefers the nearest spot the player faces

**Files:**
- Modify: `src/ReplicatedStorage/Shared/Features/Hide/Data/HideTypes.luau` (add `PromptCandidate`)
- Modify: `src/ReplicatedStorage/Shared/Features/Hide/Data/HideConstants.luau` (add `FACING_DOT`, `PREFER_MARGIN`, `PREFER_INTERVAL`)
- Modify: `src/ReplicatedStorage/Shared/Features/Hide/Utils/HideSpotUtils.luau` (add `preferred`)
- Test: `src/ReplicatedStorage/Shared/Features/Hide/Utils/HideSpotUtils.spec.luau`
- Modify: `src/ReplicatedStorage/Client/Features/Hide/HideServiceClient.luau` (`settleRanges` + a throttled Heartbeat)

**Interfaces:**
- Produces:
```lua
-- HideTypes
export type PromptCandidate = { id: string, position: Vector3 }
-- HideConstants (tunable)
FACING_DOT = 0.3,       -- a spot is "faced" when the flat direction to it is within ~72° of the facing
PREFER_MARGIN = 0.75,   -- studs a challenger must be nearer to replace the current spot (no flicker)
PREFER_INTERVAL = 0.1,  -- seconds between re-picks on the client
-- HideSpotUtils
HideSpotUtils.preferred(from: Vector3, facing: Vector3, candidates: { HideTypes.PromptCandidate }, current: string?): string?
```
Rule (pure): distances are horizontal (XZ). Candidates further than `HideConstants.ENTER_RANGE` are out. The pool is the faced candidates (flat unit direction · flat unit facing ≥ `FACING_DOT`) if any, else all in-range candidates. The best is the nearest in the pool. If `current` is in the pool and the best is not nearer than `current` by more than `PREFER_MARGIN`, return `current`. A zero flat facing means no candidate is faced.

- [ ] **Step 1: Confirm the reported geometry (one Play Solo).** Find a cabinet with a table within `ENTER_RANGE` (temporary server Script over `HideServiceServer:spots()`), stand at the cabinet's front facing it, and record both anchors' positions, the root position and LookVector, and which prompt the engine shows. Record in the Diagnosis log; if the numbers would not pick the cabinet with the rule above, adjust `FACING_DOT` before Step 2.

- [ ] **Step 2: Write the failing tests** in `HideSpotUtils.spec.luau`:

```lua
describe("preferred", function()
	local FORWARD = Vector3.new(0, 0, -1)
	local function c(id, x, y, z) return { id = id, position = Vector3.new(x, y, z) } end

	it("offers nothing with no spot in ENTER_RANGE", function()
		expect(HideSpotUtils.preferred(Vector3.zero, FORWARD, { c("table.1", 0, 0, -(HideConstants.ENTER_RANGE + 1)) }, nil)).to.equal(nil)
	end)
	it("prefers the faced cabinet over a nearer table behind the player", function()
		expect(HideSpotUtils.preferred(Vector3.zero, FORWARD, { c("cabinet.1", 0, 2.5, -3), c("table.1", 0, 0, 2) }, nil)).to.equal("cabinet.1")
	end)
	it("among faced spots, picks the nearest (height ignored)", function()
		expect(HideSpotUtils.preferred(Vector3.zero, FORWARD, { c("cabinet.1", 0, 2.5, -3), c("table.1", 1, 0, -4.5) }, nil)).to.equal("cabinet.1")
	end)
	it("falls back to the nearest when none is faced", function()
		expect(HideSpotUtils.preferred(Vector3.zero, FORWARD, { c("desk.1", 0, 0, 4), c("table.1", 0, 0, 3) }, nil)).to.equal("table.1")
	end)
	it("keeps the current spot unless another is nearer by more than PREFER_MARGIN", function()
		local m = HideConstants.PREFER_MARGIN
		local spots = { c("table.1", 0, 0, -3), c("cabinet.1", 0.2, 0, -(3 - m / 2)) }
		expect(HideSpotUtils.preferred(Vector3.zero, FORWARD, spots, "table.1")).to.equal("table.1")
		spots[2] = c("cabinet.1", 0.2, 0, -(3 - m - 0.1))
		expect(HideSpotUtils.preferred(Vector3.zero, FORWARD, spots, "table.1")).to.equal("cabinet.1")
	end)
	it("drops the current spot once it is out of range or no longer faced while another is", function()
		expect(HideSpotUtils.preferred(Vector3.zero, FORWARD, { c("table.1", 0, 0, 3), c("cabinet.1", 0, 0, -3) }, "table.1")).to.equal("cabinet.1")
	end)
	it("treats a straight-up facing as facing nothing", function()
		expect(HideSpotUtils.preferred(Vector3.zero, Vector3.yAxis, { c("desk.1", 0, 0, -4), c("table.1", 0, 0, 3) }, nil)).to.equal("table.1")
	end)
end)
```

- [ ] **Step 3: Run the suite** — Expected: FAIL, `preferred` is nil.
- [ ] **Step 4: Implement** `HideTypes.PromptCandidate`, the three constants, and `HideSpotUtils.preferred` per the rule above; extend the module's header comment with one `preferred` bullet.
- [ ] **Step 5: Run the suite** — Expected: PASS, 0 failures.
- [ ] **Step 6: Wire the client** in `HideServiceClient`: keep a `preferredId: string?`; every `PREFER_INTERVAL` (a Heartbeat accumulator, added to `stoppers`) build candidates from the known prompts (`ids`) whose parent Attachment has a `SPOT_ID_ATTRIBUTE`, using `attachment.WorldPosition`, the local root's position and `root.CFrame.LookVector`, call `HideSpotUtils.preferred(..., preferredId)`, and when it changes call `settleRanges()`. In `settleRanges`, a prompt gets `ENTER_RANGE` only if it already qualifies today **and** (`preferredId == nil` or its spot id equals `preferredId`); otherwise 0. The server is unchanged (it re-checks every entry).
- [ ] **Step 7: Verify in Play Solo** at the Step 1 spot: facing the cabinet shows "Hide in cabinet"; turning to face the table switches to the table without flicker; a real **C** press enters the shown spot. Also tap path: the phone chip shows the same spot (HideStore follows PromptShown).
- [ ] **Step 8: Lint, format, commit**

```bash
selene src/ReplicatedStorage/Shared/Features/Hide src/ReplicatedStorage/Client/Features/Hide/HideServiceClient.luau
stylua --check src/ReplicatedStorage/Shared/Features/Hide src/ReplicatedStorage/Client/Features/Hide/HideServiceClient.luau
git add src/ReplicatedStorage/Shared/Features/Hide src/ReplicatedStorage/Client/Features/Hide/HideServiceClient.luau
git commit -m "fix(hide): offer the nearest spot the player faces"
```

---

### Task 9: Close out

- [ ] **Step 1: Full suite one last time** (Studio, Global Constraints). Expected: 0 failures; count = 3828 + tests added (record the number).
- [ ] **Step 2: Lint/format all files changed on the branch by this plan** (`git diff --name-only <first commit of this plan>^ -- '*.luau'` → `selene` and `stylua --check` on that list). Expected: clean.
- [ ] **Step 3: Launch Board**: move the polish scope items to "review" (never Done) with `ArtifactData` on the board.
- [ ] **Step 4: Report to the owner** in plain words: what changed, the look questions still open, what voice needs from them.

---

## Diagnosis log

(Filled during execution: baseline count; Task 2 per-spot H1–H6 table; Task 3d measurements; Task 4 pick; Task 5 findings; Task 7 V1–V6 results; Task 8 geometry.)

- **H6 entry (Task 3e, controller ruling, 2026-10-19):** the entry slide's 30 Hz stepping (anchored-root CFrame replication, no client interpolation) is kept on the server: the server tween stays authoritative. It is smoothed client-side by HideGlideSystem, which glides other players' anchored roots toward the last replicated value during the slide in or out (HidePoseFormulas.glide / gliding). The exit now slides the root out over UNTUCK_SECONDS (0.3) in step with the unfold (commits 0b7664a, f5d02d1, 690d587).
