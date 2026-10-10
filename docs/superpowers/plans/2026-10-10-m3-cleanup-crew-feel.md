# M3: Cleanup Crew, Feel (everything except the final UI screens) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace M2's placeholder presentation with the finished "polished feel on graybox" of spec §7 (every sound, particle, ring, floater, stamp, sticky note, light, atmosphere, camera kick, Harlow's voice, footsteps, scare and animation hooks), with every asset id a placeholder that degrades to silence until the developer uploads it. The final React screens (HUD, contract board, queue pad, catch overlay, performance review) are **not** in this plan: they wait for the developer's Figma approval.

**Architecture:** Feel lives in the feature whose job it is (spec §6.2: "vacuum feedback" in Vacuum, "the client ripple ring" in Noise, "atmosphere presets" in Office, "tells, voice bubbles" in Occupant). Each feature gets one `Data/<Feature>Assets` module holding its asset-id slots (`""` = pending, never registered, so playing it is a silent no-op), one specced pure module that makes every decision (which cue just happened, ring size, which lights are broken, which gibberish clip, floater text, atmosphere preset), and one spec-exempt client `Systems/<Feature>FeedbackSystem`-style shell that reads replicated state (ShiftStore's snapshot, public player fields, pile attributes, Harlow's model attributes and speech billboard) and plays it through the base Sound, Vfx, Camera and Toast services. Two small server seams are added: Cargo sends one `Banked` packet (the swoop and floater need the item and the credited amount) and plays drop/rattle/search sounds positionally; Office builds the night dressing (exit signs, blue monitors, elevator doors, ambience emitters). Harlow's animations are an Animation registry domain built from Occupant's slots, used only when uploaded (base idle/walk/run otherwise).

**Tech Stack:** Luau `--!strict`, Rojo, ByteNetMax (`struct`, `array`, `vec3`, `uint16`), Charm + charm-sync (ShiftStore snapshot, public player fields), SignalTyped, Observers (`observeTag`), base SoundServiceClient (`play` / `playMusic` / `setAmbience`, handles with `sound` and `stop(fade)`), SoundServiceServer (`playAt`), SoundRegistry, VfxServiceClient (`requestScreen` / `releaseScreen` / `setAtmosphere`), VfxAtmosphereRegistry, CameraServiceClient (`kickFov` / `addTrauma`), ToastRegistry styles, AnimationRegistry domains + `AnimationServiceServer:playOnRig`, CylinderHandleAdornment (`Radius` / `InnerRadius`), ParticleEmitter, BillboardGui, TestEZ (Studio, `RunTests = true`).

**Spec:** `docs/superpowers/specs/2026-10-10-cleanup-crew-design.md` (§7 "Feedback and presentation" in full: identity, the feedback table, ambient dread, Harlow's body, the asset pipeline table, "Asset id literals live only in each feature's `Data/<Feature>Assets`"; §4 "Tells" and "Voice"; §6.1 Toast "Cleanup Crew registers 'sticky note' and 'stamp'"; §6.2 feature jobs; §6.3 "bank popup"). Builds on `docs/superpowers/plans/2026-10-10-m1-cleanup-crew-graybox.md` (+ `.superpowers/sdd/2026-10-10-m1-cleanup-crew-graybox/amendments.md`) and `overnight-handoff/2026-10-10-m2-cleanup-crew-harlow.md` (M2: Noise, Occupant, pacing, catch; every M2 module this plan edits is quoted there).

**Branch / PR:** same branch `game/cleanup-crew`, continuing after M2's and M4's commits (handoff order: M2 → M4 → M3); same PR #3 (the controller updates its description in Task 10; never merge).

## Global Constraints

- `--!strict` everywhere except `*.spec.luau`. No `any`, no `::` casts (none are planned; a cast needs a commented justification and developer sign-off).
- Service shape: lean annotated literal (`export type X = {...}` + `local X: X = {...}`, methods as fields, callers use colon syntax). Systems are module-level tables of functions (the M2 `OccupantTellSystem` precedent).
- Every new first-party module has a `<Name>.spec.luau` sibling or an `EXEMPT_MODULES` entry with a reason in `src/ServerScriptService/Core/Testing/SpecRoots.luau`.
- Module names `<Feature><What><RoleWord>` in an allowed subfolder (`docs/project-structure.md`); requires use full addresses; a feature folder required from 3+ times in one file gets a `<Feature><Realm>` variable.
- ≤ 400 code lines per module (`scripts/python/check_file_length.py`; comments and blanks do not count).
- Commits: plain messages exactly as given, **no `Co-Authored-By:` / `Claude-Session:` trailers** (AGENTS.md; `check_pr_rules` rejects them).
- **Rojo safety:** the developer may be connected to `rojo serve`. Implementers never run `rokit install`, `wally install`, `install.sh`, `wally-package-types` or `scripts/check.sh` (with or without `--skip-install`), and never start `rojo serve`. The per-task gate is `bash .superpowers/sdd/gate.sh` (must end `==> All checks passed.`; the ruff line is advisory).
- **Module-map and commit order (every task):** `git add src` → `python3 scripts/python/module_map.py --write` → `git add docs/project-structure.md` → `stylua <each new or edited .luau file>` (re-`git add` them) → `bash .superpowers/sdd/gate.sh` → `git commit -m "<message as given>"` → `python3 scripts/python/module_map.py --check` (must print no FAIL). Never run `stylua src` wholesale.
- **Tests run only in Studio, by the controller.** Implementers write the spec first, then the code, and report "Studio TestEZ pending with the controller". "Controller: Studio TestEZ" = set the Workspace attribute `RunTests = true`, Play, read Output. "Controller: Studio verification" = a fresh Play Solo with `RunTests = false`, using temporary server `Script` / client `LocalScript` the controller injects (the plugin VM cannot reach live services) and MCP screenshots; only a solo player is available. Implementers skip both.
- Server-authoritative: nothing in this plan writes gameplay state from a client. All feel is client-local (instances parented under the camera, `Workspace.Terrain` attachments or client-made parts; client-side property changes on replicated parts), except the server's positional sounds and the Office's static decor.
- **Spec §7: "Asset id literals live only in each feature's `Data/<Feature>Assets`."** (The CI asset-id gate also allows any `Data/` folder; this plan uses only `<Feature>Assets`.)
- **Asset gates (binding):** no Roblox uploads in this plan; every id slot is the pending value `""` until the developer uploads the staged file and pastes the id (a one-line edit in that Assets module). **A pending id must degrade gracefully:** a pending sound is never registered, every caller checks `SoundRegistry.has(id)` first (silent no-op, counted as `pending`), so Output shows no "unknown sound" warning; a pending image falls back to a code-built look; a pending animation falls back to the base locomotion clip. No paid services, no ElevenLabs, no TTS (spec §10). Generation is not a code task: it is the optional appendix "Asset staging (controller, optional)" (local Stable Audio 3 / Flux in `F:\AI\ComfyUI_windows_portable`, Kimodo/MoMask), staged under `assets/` in the repo; **never run GPU jobs during a Studio playtest.** Free Creator Store sounds may be inserted through the Studio MCP `search_asset` / `insert_asset`, listed by search term.
- **No final React screens and no ScreenGui:** `Instance.new("ScreenGui")` is allowed only in `UILayerHost` (whole-tree CI rule). In scope: in-world/HUD-adjacent feedback built from BillboardGuis, SurfaceGuis, parts, particles, handle adornments, lighting, atmosphere, camera kicks, sounds and ToastRegistry styles.
- Kid-safe horror-comedy (spec §2): cartoon grin, no gore, no real-person likeness.
- **Spec numbers and words used verbatim (spec §4, §6.1, §7):**
  - Identity: "corporate after hours" — "sticky-note toasts, rubber-stamp announcements, typewriter type"; "dim, buzzing fluorescents (some flickering), emergency-exit glow, monitors glowing blue"; ambient dread: "phones ringing in empty rooms, an elevator dinging on its own, typing that stops when you enter".
  - Vacuuming: "suction particles into the nozzle, pile shrinks, rising whine, pop + sparkle, canister fills". Canister full: "chime, dust bag pops out". Any noise: "faint ripple ring on the floor at the radius Harlow hears it". Banking: "item swoops into the truck, cha-ching, '+15' floater, clearance bar fills". Quota met: "'QUOTA MET' stamp, truck horn". Tier up: "lights flicker, sticky note". Overtime: "lighting shifts dim red, ticking music layer". Clock out: "horn honks, large countdown". Caught: "camera snaps to his face ~0.6 s, nearby lights die, distorted sting, stretched-grin face".
  - Tells: "lights within ~20 studs of him flicker; heartbeat when he is near but hasn't seen you; 3D footsteps and muttering through walls; '?' over his head investigating; '!' + sting + chase music when he spots you; a sigh when he gives up". Voice: "pitched, distorted gibberish (Stable Audio) plus a speech bubble with the line ('Those are COMPANY ASSETS.', 'Per my last email…', 'You're FIRED!'). No TTS."
  - Harlow's animations (asset pipeline table): "lurch walk, look-around, grab and throw".
  - Toast: "Cleanup Crew registers 'sticky note' and 'stamp'".

## Review Focus

1. **A fresh checkout with every asset id pending** → the whole loop plays silently with the visuals intact (particles, rings, floaters, swoops, grin, decor, atmosphere, typewriter bubble), zero "unknown sound" / "unknown atmosphere" / "unknown vfx" warnings, zero errors, and Harlow animates with the base idle/walk/run. (Task 7 `OccupantAnimationUtils` spec "falls back to the base locomotion clips while Harlow's are pending" and `AnimationOccupantRegistry` spec "holds only uploaded slots"; every task's Studio checklist has a "no warnings with ids pending" item; Task 10 Step 5 item 1.)
2. **Another shift or a mid-run reset while feedback is running** → the whine loops, suction emitters, chase music, overtime ticking layer, red lights and tint, leaves, typing loops and grin are all gone, and the reset itself plays no canister chime and no pop. (Task 3 `VacuumFeedbackFormulas` spec "never chimes outside a running shift (a reset empties the canister)" and "does not pop a pile removed by a reset"; Task 2 `ShiftCueUtils` "turns the ticking off when the run ends"; Task 8 `OfficeAtmosphereUtils` "drops overtime when the run ends"; Task 10 Step 5 item 6.)
3. **A player joins mid-shift (their first snapshot is already in overtime with the quota met)** → no burst of horns and stingers on arrival, but the ticking layer, hum, red atmosphere and lights match the current state. (Task 2 `ShiftCueUtils` spec "stays quiet on the first snapshot it sees" and "ticks in overtime only"; Task 8 `OfficeAtmosphereUtils` "picks overtime over the tier"; Task 2 Step 11 item 6.)
4. **Two players finish one pile together, or the Interaction system clears the progress attributes in the same frame it destroys the pile** → exactly one pop + sparkle (the decision uses the pile's peak progress and how recently it was vacuumed, not the last attribute value), and the whine stops. (Task 3 `VacuumFeedbackFormulas` spec "pops a pile that was being vacuumed past half, even after its progress was cleared"; Task 3 Step 11 item 2.)
5. **A pockets-only Load, a Load in overtime, or a Load worth 0 clearance** → the swoop starts at the player, the floater shows the bonus actually credited (×1.5 in overtime, rounded like the review), and a zero amount shows no "+0". (Task 5 `CargoFeedbackUtils` spec "omits a zero amount" and "rounds like the review"; Task 5 Step 13 items 2-3.)

---

## New modules

| Feature | Realm | Subfolder | Name | Job (one line) |
|---|---|---|---|---|
| Shift | shared | Data | ShiftAssets | Shift's sound-id slots (horns, stings, ticking, countdown, toast sounds) and which cue plays which |
| Shift | client | Utils | ShiftCueUtils | Which shift moments just happened between two snapshots; the clock-out second; the ticking layer |
| Shift | client | Systems | ShiftFeedbackSystem | Plays the shift's cues, ticking layer, countdown ticks and camera kicks |
| Vacuum | shared | Data | VacuumAssets | Vacuum's sound-id slots (whine, pop, canister tick and chime, bag pop) |
| Vacuum | client | Utils | VacuumFeedbackFormulas | Whine pitch/volume from progress, pop-or-reset, canister cue, nearest vacuumer |
| Vacuum | client | Systems | VacuumFeedbackSystem | Suction particles, rising whine, pop + sparkle, canister sounds |
| Noise | client | Utils | NoiseRippleFormulas | The ripple ring's radius, band and fade over time; whether it is drawn |
| Cargo | shared | Data | CargoAssets | Cargo's sound-id slots (cha-ching, swoosh, pickup, pocket, drops, rattle, rummage) |
| Cargo | shared | Utils | CargoFeedbackUtils | Floater text, the swoop arc, which drop/noise sound, pickup/pocket/leaves cues |
| Cargo | client | Systems | CargoFeedbackSystem | Swoop, cha-ching and floaters on `Banked`; pickup/pocket sounds; the plant's leaves |
| Occupant | shared | Data | OccupantAssets | Harlow's sound, image and animation slots |
| Occupant | shared | Utils | OccupantFeedbackUtils | Line pick, gibberish clip, typewriter reveal, voiced lines, mode-change cues, footstep pace |
| Occupant | shared | Utils | OccupantAnimationUtils | Harlow's animation domain from his uploaded slots; his NPC poses with base fallbacks |
| Occupant | client | Systems | OccupantPresenceSystem | Footsteps, mutter, heartbeat sound, mode cues, chase music, gibberish + typewriter |
| Occupant | client | Systems | OccupantScareSystem | The catch sting and stretched grin; the lights-out power-down and grab |
| Animation | shared | Data | AnimationOccupantRegistry | The `occupant` animation domain (Harlow's uploaded clips only) |
| Office | shared | Data | OfficeDecorConstants | Night decor look and the ambience emitters' tag, kinds and placement |
| Office | server | Systems | OfficeDecorSystem | Builds exit signs, blue monitors, elevator doors and ambience emitters once |
| Office | client | (root) | OfficeServiceClient | Starts the office's atmosphere and ambience on the client |
| Office | client | Data | OfficeAssets | Office's sound-id slots (hum, light zap, phone, elevator, typing) |
| Office | client | Data | OfficeAtmosphereConstants | Atmosphere presets, overtime tint and light colour, broken-light and ambience timing |
| Office | client | Utils | OfficeAtmosphereUtils | Which atmosphere preset, overtime, hum for the shift's phase/stage/tier |
| Office | client | Utils | OfficeLightUtils | Which lights are broken (stable per light) within a radius; a broken light's glow |
| Office | client | Utils | OfficeAmbienceUtils | Which emitter rings (empty rooms), when typing stops, the next delay |
| Office | client | Systems | OfficeAtmosphereSystem | Applies the preset, overtime tint and red lights, broken flicker and the hum |
| Office | client | Systems | OfficeAmbienceSystem | Phones in empty rooms, the elevator, typing that stops when you come close |

26 new modules. **No new subfolder kind, no new role word, no second service** (Office gains its first client service; one per realm). Office gains a shared and a client realm folder. Modified: Shift (Constants, NoticeUtils + spec, ServiceServer, ServiceClient), Vacuum (Constants, ServiceClient), Noise (Constants, ServiceClient), Cargo (Constants, Types, Events, ServiceServer, ServiceClient), Occupant (Constants, ServiceServer, RigSystem, CatchSystem, ServiceClient), Animation (Registry), Office (ServiceServer), `SpecRoots`, `docs/project-structure.md` (module map), `docs/ROADMAP.md`.

## Open questions for the developer

Designed around; none blocks M3. Each is a reversible game-side choice.

1. **Toast style look** follows the not-yet-approved Figma style page (decisions 1-2 in `overnight-handoff/m3-figma-summary.md`): sticky = yellow paper, Permanent Marker; stamp = cream paper, red Oswald. Both live in `ShiftConstants.TOAST_STYLES`; a Figma change is a data edit. ToastStack draws colours and font only (no rotation or texture): the real stamp graphic comes with the approved HUD.
2. **"Large countdown" on clock out** is part of the gated HUD (Figma 1c). M3 adds the horn, a tick every second (louder for the last 3) and keeps M1's placeholder `CLOCKING OUT m:ss` line until the approved HUD replaces it.
3. **"Rehired." card** (Figma 4c) is gated; M3 shows it as a sticky note.
4. **Atmosphere in the lobby phase** stays the place's own lighting (so the Studio depot is not darkened); night begins with the arrival countdown and stays through results. Tiers darken it a step each; the break lifts it a little; overtime is dim red.
5. **One standing clip for Harlow:** the look-around clip is his idle pose (investigating, searching, on break, over a catch), on top of M2's root sweep. His run stays the base run until a Harlow run clip is uploaded (the spec names only the lurch walk).
6. **Chase music only for the chased player;** everyone else hears the "!" sting positionally from him.
7. **Ambient dread is per client** (each player hears their own phones, elevator and typists; no packets). "Typing that stops when you enter" = a typist within 20 studs of you stops and stays quiet ~25 s.
8. **The bank floater shows clearance and bonus separately** ("+15" green, "+45" blue; overtime bonus already ×1.5). This needs Cargo's banking handler to return the credited bonus: `BankHandler` becomes `(player, deposit) -> (boolean, number?)` (game-side contract change; M1's "Loaded: …" toast is removed in favour of the floater).
9. **Broken fluorescents:** about 18 % of the ceiling lights (stable per light) blink now and then with a zap, only within 80 studs of your camera. Their flicker is a slow blink, distinct from the fast flicker that means Harlow is near.
10. **Base wish (not built):** a SoundRegistry notion of "pending" would remove the four-line registration loop each Assets module carries.

---

### Task 0: Preflight

**Files:** none.

- [ ] **Step 1: Confirm the branch and that M2 and M4 landed**

```bash
git branch --show-current
git log --oneline -40
```
Expected: `game/cleanup-crew`; the log contains M2's "docs: record Cleanup Crew M2 on the roadmap" and M4's final commit. If either is missing, stop and tell the controller (M3 runs after both).

- [ ] **Step 2: Confirm the M2 interfaces this plan edits or calls** (every grep prints at least one line; if one prints nothing, stop and report which):

```bash
grep -n "TOAST\|NOTICE_SECONDS\|BREAK_SECONDS\|WARNING_SECONDS\|OVERTIME_SALVAGE_MULTIPLIER" src/ReplicatedStorage/Shared/Features/Shift/Data/ShiftConstants.luau
grep -n "stage\|tier" src/ReplicatedStorage/Shared/Features/Shift/Data/ShiftTypes.luau
grep -n "function ShiftNoticeUtils.notices" src/ServerScriptService/Features/Shift/Utils/ShiftNoticeUtils.luau
grep -n "local function onBanked\|Loaded: \|ShiftConstants.CLOCK_OUT_SECONDS} s\|clear {state.quota} of trash" src/ServerScriptService/Features/Shift/ShiftServiceServer.luau
grep -n "Charm.subscribe(ShiftStore.snapshot" src/ReplicatedStorage/Client/Features/Shift/ShiftServiceClient.luau
grep -n "Ripple.listen\|RIPPLE_" src/ReplicatedStorage/Client/Features/Noise/NoiseServiceClient.luau
grep -rn "NoiseConstants\." src --include=*.luau
grep -n "noiseMade:Fire(position, CargoHandlingRules.dropNoise(def), \"drop\")\|pcall(handler, player, deposit)\|counters.banked += 1" src/ServerScriptService/Features/Cargo/CargoServiceServer.luau
grep -n "export type BankHandler" src/ReplicatedStorage/Shared/Features/Cargo/Data/CargoTypes.luau
grep -n "LINES = table.freeze(LINES)\|LIGHT_TAG\|SPEECH_NAME\|HEARTBEAT_RANGE" src/ReplicatedStorage/Shared/Features/Occupant/Data/OccupantConstants.luau
grep -n "animations = { idle = \"idle\", walk = \"walk\", run = \"run\" }\|local function show\|OccupantTellRules.lineFor(cue)\|REHIRED_TEXT, duration\|was caught by" src/ServerScriptService/Features/Occupant/OccupantServiceServer.luau
grep -n "speech.Font = Enum.Font.SourceSansSemibold" src/ServerScriptService/Features/Occupant/Systems/OccupantRigSystem.luau
grep -n "OccupantRigSystem.say(rig, OccupantConstants.LINES.caught)\|DeathServiceServer:kill(humanoid, \"caught\"" src/ServerScriptService/Features/Occupant/Systems/OccupantCatchSystem.luau
grep -n "CatchCam.listen\|LightsOut.listen\|OccupantTellSystem.start()" src/ReplicatedStorage/Client/Features/Occupant/OccupantServiceClient.luau
grep -n "built = OfficeBuildSystem.build(LAYOUT, OfficeConstants.ORIGIN)" src/ServerScriptService/Features/Office/OfficeServiceServer.luau
grep -n "DOMAIN_MODULES: { \[string\]: AnimationDomain } = table.freeze" src/ReplicatedStorage/Shared/Features/Animation/Data/AnimationRegistry.luau
```
Notes for later tasks: if M4 renamed or moved any line above (for example the Shift vote or the depot reset), adapt the anchor and report it; M3 touches no Depot or Queue module.

- [ ] **Step 3: Confirm no module name this plan creates already exists**

```bash
for name in ShiftAssets ShiftCueUtils ShiftFeedbackSystem VacuumAssets VacuumFeedbackFormulas VacuumFeedbackSystem NoiseRippleFormulas CargoAssets CargoFeedbackUtils CargoFeedbackSystem OccupantAssets OccupantFeedbackUtils OccupantAnimationUtils OccupantPresenceSystem OccupantScareSystem AnimationOccupantRegistry OfficeDecorConstants OfficeDecorSystem OfficeServiceClient OfficeAssets OfficeAtmosphereConstants OfficeAtmosphereUtils OfficeLightUtils OfficeAmbienceUtils OfficeAtmosphereSystem OfficeAmbienceSystem; do find src -name "$name.luau"; done
```
Expected: no output.

- [ ] **Step 4: Baseline gate**

```bash
bash .superpowers/sdd/gate.sh
```
Expected: `==> All checks passed.` If anything fails here, stop and report: it is not ours.

---

### Task 1: Sticky-note and stamp toasts

**Files:**
- Modify: `src/ReplicatedStorage/Shared/Features/Shift/Data/ShiftConstants.luau`
- Modify (full replacement): `src/ServerScriptService/Features/Shift/Utils/ShiftNoticeUtils.luau` + `ShiftNoticeUtils.spec.luau`
- Modify: `src/ServerScriptService/Features/Shift/ShiftServiceServer.luau`
- Modify: `src/ReplicatedStorage/Client/Features/Shift/ShiftServiceClient.luau`
- Modify: `src/ServerScriptService/Features/Occupant/OccupantServiceServer.luau` (two toast calls)

**Interfaces:**
- Consumes: `ToastTypes.ToastStyle = { background: Color3, text: Color3, accent: Color3, font: Enum.Font, sound: string? }`, `ToastTypes.ToastRequest = { text, style?, duration? }`, `ToastRegistry.register(name, style) / has(name)` (the client plays a style's `sound` only when `SoundRegistry.has` it, so a pending sound is silent); M2's `ShiftConstants.NOTICE_SECONDS / BREAK_SECONDS / WARNING_SECONDS / OVERTIME_SALVAGE_MULTIPLIER`, `ShiftTypes.ShiftState.stage / tier`.
- Produces (ShiftConstants, new keys): `TOAST_STICKY = "sticky"`, `TOAST_STAMP = "stamp"`, `TOAST_STYLES: { [string]: ToastStyle }` (sounds `"shiftStickyNote"`, `"shiftStamp"`, slots in Task 2's ShiftAssets), `STAMP_SECONDS = 3`.
- Produces (ShiftNoticeUtils): `notices(before, after) -> { ToastRequest }`, now styled: quota met = stamp "QUOTA MET" + sticky break note; warning = sticky; overtime = stamp "OVERTIME" + sticky; tier = sticky.
- Both Shift services register `TOAST_STYLES` at load (guarded), so the server's ToastRules accepts the style and the client can draw it.

- [ ] **Step 1: Write the failing spec.** Replace `src/ServerScriptService/Features/Shift/Utils/ShiftNoticeUtils.spec.luau` with:

```lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local ShiftNoticeUtils = require(script.Parent.ShiftNoticeUtils)
local ShiftConstants = require(ReplicatedStorage.Shared.Features.Shift.Data.ShiftConstants)
local ShiftPhaseRules = require(ServerScriptService.Features.Shift.Rules.ShiftPhaseRules)

local function running()
	return ShiftPhaseRules.follow(ShiftPhaseRules.initial(350, "B"), { phase = "running", round = 1, endsAt = 520 }, 100)
end

local function onBreak()
	return ShiftPhaseRules.markQuota(running(), 350, 150)
end

local function warning()
	return ShiftPhaseRules.advance(onBreak(), 180)
end

return function()
	it("says nothing when nothing changed", function()
		expect(#ShiftNoticeUtils.notices(running(), running())).to.equal(0)
	end)

	it("stamps QUOTA MET, then a sticky note about Harlow's break", function()
		local list = ShiftNoticeUtils.notices(running(), onBreak())
		expect(#list).to.equal(2)
		expect(list[1].text).to.equal("QUOTA MET")
		expect(list[1].style).to.equal(ShiftConstants.TOAST_STAMP)
		expect(list[1].duration).to.equal(ShiftConstants.STAMP_SECONDS)
		expect(list[2].style).to.equal(ShiftConstants.TOAST_STICKY)
		expect(list[2].text).to.equal("Mr. Harlow is on his break for 0:30. Regroup and bank.")
		expect(list[2].duration).to.equal(ShiftConstants.NOTICE_SECONDS)
	end)

	it("warns before overtime on a sticky note, in the spec's words", function()
		local list = ShiftNoticeUtils.notices(onBreak(), warning())
		expect(#list).to.equal(1)
		expect(list[1].text).to.equal("Overtime in 0:30, salvage ×1.5")
		expect(list[1].style).to.equal(ShiftConstants.TOAST_STICKY)
	end)

	it("stamps OVERTIME once, with its note and without a tier note", function()
		local list = ShiftNoticeUtils.notices(warning(), ShiftPhaseRules.advance(warning(), 210))
		expect(#list).to.equal(2)
		expect(list[1].text).to.equal("OVERTIME")
		expect(list[1].style).to.equal(ShiftConstants.TOAST_STAMP)
		expect(list[2].style).to.equal(ShiftConstants.TOAST_STICKY)
		expect(string.find(list[2].text, "×1.5", 1, true) ~= nil).to.equal(true)
	end)

	it("notes each pressure tier on a sticky note", function()
		local list = ShiftNoticeUtils.notices(running(), ShiftPhaseRules.advance(running(), 220))
		expect(#list).to.equal(1)
		expect(list[1].text).to.equal("You hear Harlow pacing faster…")
		expect(list[1].style).to.equal(ShiftConstants.TOAST_STICKY)
	end)

	it("stays quiet outside a running shift", function()
		expect(#ShiftNoticeUtils.notices(ShiftPhaseRules.initial(350, "B"), running())).to.equal(0)
	end)

	it("only names styles the game registers", function()
		expect(ShiftConstants.TOAST_STYLES[ShiftConstants.TOAST_STICKY]).to.be.ok()
		expect(ShiftConstants.TOAST_STYLES[ShiftConstants.TOAST_STAMP]).to.be.ok()
	end)
end
```

- [ ] **Step 2: Controller: Studio TestEZ.** Expected: the new cases fail (`TOAST_STAMP` nil, one toast instead of two).

- [ ] **Step 3: Constants.** In `src/ReplicatedStorage/Shared/Features/Shift/Data/ShiftConstants.luau`:
  - After `local ShiftTypes = require(...)`, add `local ToastTypes = require(ReplicatedStorage.Shared.Features.Toast.Data.ToastTypes)`.
  - After `local VARIANT: ShiftTypes.Variant = "B"`, add:

```lua
-- Cleanup Crew's two toast styles (spec §6.1 "sticky note" and "stamp"; §7 "sticky-note toasts, rubber-stamp
-- announcements"). Look from the Figma style page, pending the developer's approval; each `sound` is a
-- ShiftAssets slot (silent while pending).
local TOAST_STYLES: { [string]: ToastTypes.ToastStyle } = {
	sticky = {
		background = Color3.fromRGB(255, 226, 102),
		text = Color3.fromRGB(46, 38, 20),
		accent = Color3.fromRGB(232, 160, 40),
		font = Enum.Font.PermanentMarker,
		sound = "shiftStickyNote",
	},
	stamp = {
		background = Color3.fromRGB(244, 236, 216),
		text = Color3.fromRGB(196, 38, 38),
		accent = Color3.fromRGB(196, 38, 38),
		font = Enum.Font.Oswald,
		sound = "shiftStamp",
	},
}
```
  - In the returned table, after `HUD_ORDER = 10,`, add:

```lua
	-- Toast styles (registered by both Shift services at load) and how long a stamp stays up.
	TOAST_STICKY = "sticky",
	TOAST_STAMP = "stamp",
	TOAST_STYLES = table.freeze(TOAST_STYLES),
	STAMP_SECONDS = 3,
```

- [ ] **Step 4: Notices.** Replace `src/ServerScriptService/Features/Shift/Utils/ShiftNoticeUtils.luau` with:

```lua
--!strict
--[=[
	ShiftNoticeUtils: what the crew is told when the pacing moves (Cleanup Crew spec §3 step 5, §4 "Pacing", §7):
	the quota met and Harlow's break; "Overtime in 0:30, salvage ×1.5"; overtime itself; and each pressure tier
	("You hear Harlow pacing faster…"). The two big moments are a rubber stamp (QUOTA MET, OVERTIME) followed by a
	sticky note with the detail; the rest are sticky notes (spec §6.1, §7 "sticky-note toasts, rubber-stamp
	announcements"). Pure: the service sends what this returns.

	@class ShiftNoticeUtils
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ShiftConstants = require(ReplicatedStorage.Shared.Features.Shift.Data.ShiftConstants)
local ShiftTypes = require(ReplicatedStorage.Shared.Features.Shift.Data.ShiftTypes)
local ToastTypes = require(ReplicatedStorage.Shared.Features.Toast.Data.ToastTypes)

type ToastRequest = ToastTypes.ToastRequest

-- "m:ss", seconds rounded up.
local function clock(seconds: number): string
	local whole = math.max(0, math.ceil(seconds))
	return string.format("%d:%02d", whole // 60, whole % 60)
end

local function stamp(text: string): ToastRequest
	return { text = text, style = ShiftConstants.TOAST_STAMP, duration = ShiftConstants.STAMP_SECONDS }
end

local function note(text: string): ToastRequest
	return { text = text, style = ShiftConstants.TOAST_STICKY, duration = ShiftConstants.NOTICE_SECONDS }
end

local ShiftNoticeUtils = {}

--[=[
	The toasts for the step from `before` to `after` (both running; otherwise none), in the order they happen.
]=]
function ShiftNoticeUtils.notices(before: ShiftTypes.ShiftState, after: ShiftTypes.ShiftState): { ToastRequest }
	local list: { ToastRequest } = {}
	if before.phase ~= "running" or after.phase ~= "running" then
		return list
	end
	local multiplier = ShiftConstants.OVERTIME_SALVAGE_MULTIPLIER
	if after.quotaMet and not before.quotaMet then
		table.insert(list, stamp("QUOTA MET"))
		table.insert(
			list,
			note(`Mr. Harlow is on his break for {clock(ShiftConstants.BREAK_SECONDS)}. Regroup and bank.`)
		)
	end
	if after.stage == "warning" and before.stage ~= "warning" then
		table.insert(list, note(`Overtime in {clock(ShiftConstants.WARNING_SECONDS)}, salvage ×{multiplier}`))
	end
	if after.stage == "overtime" and before.stage ~= "overtime" then
		table.insert(list, stamp("OVERTIME"))
		table.insert(list, note(`Salvage ×{multiplier} until the clock runs out. Harlow is back, and faster.`))
	elseif after.tier > before.tier then
		table.insert(list, note("You hear Harlow pacing faster…"))
	end
	return list
end

return ShiftNoticeUtils
```

- [ ] **Step 5: Register the styles in the server.** In `src/ServerScriptService/Features/Shift/ShiftServiceServer.luau`:
  - Add the require `local ToastRegistry = require(ReplicatedStorage.Shared.Features.Toast.Data.ToastRegistry)` beside the other shared requires.
  - After the `CLOCK_OUT_KIND` registration block (`if not InteractionRegistry.has(...) ... end`), add:

```lua
-- Registered at load, before any toast names them (the server's ToastRules falls back to "info" otherwise).
for name, style in ShiftConstants.TOAST_STYLES do
	if not ToastRegistry.has(name) then
		ToastRegistry.register(name, style)
	end
end
```
  - In `beginRun`, the `ToastServiceServer:send("all", { text = \`Shift {state.shift}: clear …\`, duration = 6 })` table gains `style = ShiftConstants.TOAST_STICKY,`.
  - In `clockOut`, the `ToastServiceServer:send("all", { text = \`{who} clocked out. …\`, duration = ShiftConstants.CLOCK_OUT_SECONDS })` table gains `style = ShiftConstants.TOAST_STICKY,`.

- [ ] **Step 6: Register the styles in the client.** In `src/ReplicatedStorage/Client/Features/Shift/ShiftServiceClient.luau`:
  - Add the require `local ToastRegistry = require(ReplicatedStorage.Shared.Features.Toast.Data.ToastRegistry)` after the `ShiftEvents` require.
  - After `local unsubscribers: { () -> () } = {}`, add:

```lua
-- Registered at load (before the first toast arrives) so ToastStack can draw them.
for name, style in ShiftConstants.TOAST_STYLES do
	if not ToastRegistry.has(name) then
		ToastRegistry.register(name, style)
	end
end
```

- [ ] **Step 7: Harlow's toasts.** In `src/ServerScriptService/Features/Occupant/OccupantServiceServer.luau`:
  - Add `local ShiftConstants = require(ReplicatedStorage.Shared.Features.Shift.Data.ShiftConstants)` beside the `ShiftTypes` require.
  - In `catchHooks.onCaught`, the "`{player.DisplayName} was caught by …`" toast table gains `style = ShiftConstants.TOAST_STICKY,`.
  - In the `observeCharacter` rehire handler, `{ text = OccupantConstants.REHIRED_TEXT, duration = 3 }` becomes `{ text = OccupantConstants.REHIRED_TEXT, style = ShiftConstants.TOAST_STICKY, duration = 3 }`.

- [ ] **Step 8: Module map, format and gate** (Global Constraints order). Expected: `==> All checks passed.`

- [ ] **Step 9: Controller: Studio TestEZ.** Expected: ShiftNoticeUtils passes; everything else still passes.

- [ ] **Step 10: Controller: Studio verification** (Play Solo, `RunTests = false`). Inject a temporary server Script:

```lua
local S = require(game.ServerScriptService.Features.Shift.ShiftServiceServer)
local R = require(game.ServerScriptService.Features.Round.RoundServiceServer)
_G.S, _G.R = S, R
```
Checklist (screenshot each toast):
1. The shift's first toast ("Shift 1: clear 350 of trash …") is a yellow sticky note in a marker font.
2. `_G.R:addTeam("clearance", 345)`, Load a rubbish bag: a cream "QUOTA MET" toast in red condensed type, then the sticky "Mr. Harlow is on his break for 0:30. Regroup and bank."
3. 30 s later the sticky "Overtime in 0:30, salvage ×1.5"; 30 s after that a stamp "OVERTIME" and its sticky note. At 2:00 / 4:00 (or by waiting) the tier note is a sticky.
4. Get caught: "<name> was caught by Mr. Harlow." and, after respawn, "Rehired." are sticky notes.
5. Clock out: the "clocked out" toast is a sticky note.
6. Output (client and server): no "toast refused", no "unknown sound" warning (the style sounds are pending and silent).

- [ ] **Step 11: Commit**

```bash
git commit -m "feat(shift): sticky-note and stamp toast styles for the shift's notices"
python3 scripts/python/module_map.py --check
```

---
### Task 2: The shift's sounds (horns, stings, ticking layer, countdown, camera kicks)

**Files:**
- Create: `src/ReplicatedStorage/Shared/Features/Shift/Data/ShiftAssets.luau`
- Create: `src/ReplicatedStorage/Client/Features/Shift/Utils/ShiftCueUtils.luau` (+ `ShiftCueUtils.spec.luau`)
- Create: `src/ReplicatedStorage/Client/Features/Shift/Systems/ShiftFeedbackSystem.luau`
- Modify: `src/ReplicatedStorage/Shared/Features/Shift/Data/ShiftConstants.luau`
- Modify: `src/ReplicatedStorage/Client/Features/Shift/ShiftServiceClient.luau`
- Modify: `src/ServerScriptService/Core/Testing/SpecRoots.luau`

**Interfaces:**
- Consumes: `ShiftStore.snapshot` (Charm computed `ShiftTypes.ShiftSnapshot?`; M2 adds `stage: ShiftStage`, `stageEndsAt: number?`, `tier: number`; times are server time); `SoundRegistry.has / get / register`; `SoundServiceClient:play(id, { at?, volumeScale? }) -> SoundHandle?`, `:setAmbience(layer, id?, fade?)`; `CameraServiceClient:kickFov(amount, duration)`, `:addTrauma(amount)`.
- Produces (ShiftAssets): `PENDING = ""`; `SOUNDS: { [string]: SoundDef }` (ids `shiftPunchIn`, `shiftTruckHorn`, `shiftTierSting`, `shiftWarningChime`, `shiftOvertimeSting`, `shiftTicking`, `shiftClockOutHorn`, `shiftCountdownTick`, `shiftStickyNote`, `shiftStamp`), registered at load when uploaded; `CUE_SOUNDS: { [string]: string }` (cue → sound id); `TICKING = "shiftTicking"`; `COUNTDOWN_TICK = "shiftCountdownTick"`.
- Produces (ShiftCueUtils): `type Cue = "shiftStart" | "quotaMet" | "tierUp" | "warning" | "overtime" | "clockOut" | "shiftEnd"`; `cues(before: ShiftSnapshot?, after: ShiftSnapshot?) -> { Cue }`; `countdown(snapshot: ShiftSnapshot?, now: number) -> number?`; `ticking(snapshot: ShiftSnapshot?) -> boolean`.
- Produces (ShiftFeedbackSystem, client module-level): `start()`, `stop()`, `getState() -> { [string]: any }`.
- Produces (ShiftConstants, new keys): `QUOTA_FOV_KICK = 8`, `QUOTA_FOV_SECONDS = 0.6`, `TIER_TRAUMA = 0.2`, `OVERTIME_TRAUMA = 0.3`, `TICKING_LAYER = "shiftOvertime"`, `COUNTDOWN_LOUD = 3`, `COUNTDOWN_LOUD_SCALE = 1.6`, `FEEDBACK_INTERVAL = 0.1`.

- [ ] **Step 1: Write the failing spec** `src/ReplicatedStorage/Client/Features/Shift/Utils/ShiftCueUtils.spec.luau`:

```lua
local ShiftCueUtils = require(script.Parent.ShiftCueUtils)

local function snapshot(overrides)
	local base = {
		phase = "running",
		sub = "normal",
		stage = "normal",
		tier = 0,
		shift = 1,
		endsAt = 520,
		quota = 350,
		cleared = 0,
		bonus = 0,
		quotaMet = false,
		variant = "B",
		votesAnother = 0,
		votesDepot = 0,
	}
	for key, value in overrides or {} do
		base[key] = value
	end
	return base
end

return function()
	describe("cues", function()
		it("stays quiet on the first snapshot it sees", function()
			expect(#ShiftCueUtils.cues(nil, snapshot({ stage = "overtime", quotaMet = true, tier = 2 }))).to.equal(0)
			expect(#ShiftCueUtils.cues(snapshot(), nil)).to.equal(0)
		end)

		it("punches in when a run starts, and nothing else", function()
			local list = ShiftCueUtils.cues(snapshot({ phase = "starting" }), snapshot())
			expect(#list).to.equal(1)
			expect(list[1]).to.equal("shiftStart")
		end)

		it("honks when the run ends", function()
			local list = ShiftCueUtils.cues(snapshot(), snapshot({ phase = "results" }))
			expect(#list).to.equal(1)
			expect(list[1]).to.equal("shiftEnd")
		end)

		it("cues the quota once", function()
			local list = ShiftCueUtils.cues(snapshot(), snapshot({ quotaMet = true, stage = "break" }))
			expect(#list).to.equal(1)
			expect(list[1]).to.equal("quotaMet")
			local met = snapshot({ quotaMet = true, stage = "break" })
			expect(#ShiftCueUtils.cues(met, met)).to.equal(0)
		end)

		it("cues a tier, the warning and overtime (overtime swallows its tier step)", function()
			expect(ShiftCueUtils.cues(snapshot(), snapshot({ tier = 1 }))[1]).to.equal("tierUp")
			local warning = ShiftCueUtils.cues(snapshot({ stage = "break" }), snapshot({ stage = "warning" }))
			expect(#warning).to.equal(1)
			expect(warning[1]).to.equal("warning")
			local overtime =
				ShiftCueUtils.cues(snapshot({ stage = "warning", tier = 1 }), snapshot({ stage = "overtime", tier = 2 }))
			expect(#overtime).to.equal(1)
			expect(overtime[1]).to.equal("overtime")
		end)

		it("honks the clock out", function()
			local list = ShiftCueUtils.cues(snapshot(), snapshot({ sub = "clockout", clockOutAt = 110 }))
			expect(#list).to.equal(1)
			expect(list[1]).to.equal("clockOut")
		end)

		it("says nothing between two lobby snapshots", function()
			expect(#ShiftCueUtils.cues(snapshot({ phase = "lobby" }), snapshot({ phase = "lobby", shift = 2 }))).to.equal(0)
		end)
	end)

	describe("countdown", function()
		it("counts the clock out down in whole seconds, rounded up", function()
			local clocking = snapshot({ sub = "clockout", clockOutAt = 110 })
			expect(ShiftCueUtils.countdown(clocking, 100.2)).to.equal(10)
			expect(ShiftCueUtils.countdown(clocking, 109.5)).to.equal(1)
			expect(ShiftCueUtils.countdown(clocking, 111)).to.equal(0)
		end)

		it("is nil without a running clock out", function()
			expect(ShiftCueUtils.countdown(snapshot(), 100)).to.equal(nil)
			expect(ShiftCueUtils.countdown(snapshot({ phase = "results", sub = "clockout", clockOutAt = 110 }), 100)).to.equal(nil)
			expect(ShiftCueUtils.countdown(nil, 100)).to.equal(nil)
		end)
	end)

	describe("ticking", function()
		it("ticks in overtime only", function()
			expect(ShiftCueUtils.ticking(snapshot({ stage = "overtime" }))).to.equal(true)
			expect(ShiftCueUtils.ticking(snapshot({ stage = "warning" }))).to.equal(false)
			expect(ShiftCueUtils.ticking(nil)).to.equal(false)
		end)

		it("turns the ticking off when the run ends", function()
			expect(ShiftCueUtils.ticking(snapshot({ phase = "results", stage = "overtime" }))).to.equal(false)
		end)
	end)
end
```

- [ ] **Step 2: Controller: Studio TestEZ.** Expected: `ShiftCueUtils.spec` errors (module missing).

- [ ] **Step 3: Cue rules** `src/ReplicatedStorage/Client/Features/Shift/Utils/ShiftCueUtils.luau`:

```lua
--!strict
--[=[
	ShiftCueUtils: which shift moments just happened, for the sounds and kicks (Cleanup Crew spec §7 table: quota
	met, tier up, overtime, clock out; the shift's start and end). Compares two snapshots of the `shift` world
	entry: the first snapshot a client sees (a late joiner's included) cues nothing, so nobody arrives to a burst
	of horns. Also the clock-out countdown's whole second and whether the overtime ticking layer plays. Pure.

	@class ShiftCueUtils
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ShiftTypes = require(ReplicatedStorage.Shared.Features.Shift.Data.ShiftTypes)

type ShiftSnapshot = ShiftTypes.ShiftSnapshot

export type Cue = "shiftStart" | "quotaMet" | "tierUp" | "warning" | "overtime" | "clockOut" | "shiftEnd"

local ShiftCueUtils = {}

--[=[
	The moments between `before` and `after`, in the order they happen. None when either is nil.
]=]
function ShiftCueUtils.cues(before: ShiftSnapshot?, after: ShiftSnapshot?): { Cue }
	local list: { Cue } = {}
	if before == nil or after == nil then
		return list
	end
	local wasRunning = before.phase == "running"
	local isRunning = after.phase == "running"
	if isRunning and not wasRunning then
		table.insert(list, "shiftStart")
		return list
	end
	if wasRunning and not isRunning then
		table.insert(list, "shiftEnd")
		return list
	end
	if not isRunning then
		return list
	end
	if after.quotaMet and not before.quotaMet then
		table.insert(list, "quotaMet")
	end
	if after.stage == "warning" and before.stage ~= "warning" then
		table.insert(list, "warning")
	end
	if after.stage == "overtime" and before.stage ~= "overtime" then
		table.insert(list, "overtime")
	elseif after.tier > before.tier then
		table.insert(list, "tierUp")
	end
	if after.sub == "clockout" and before.sub ~= "clockout" then
		table.insert(list, "clockOut")
	end
	return list
end

--[=[
	Whole seconds left on a running clock-out countdown (rounded up, never negative); nil without one.
]=]
function ShiftCueUtils.countdown(snapshot: ShiftSnapshot?, now: number): number?
	if snapshot == nil or snapshot.phase ~= "running" or snapshot.sub ~= "clockout" then
		return nil
	end
	local at = snapshot.clockOutAt
	if at == nil then
		return nil
	end
	return math.max(0, math.ceil(at - now))
end

--[=[
	Whether the overtime ticking layer plays (spec §7 "Overtime: … ticking music layer").
]=]
function ShiftCueUtils.ticking(snapshot: ShiftSnapshot?): boolean
	return snapshot ~= nil and snapshot.phase == "running" and snapshot.stage == "overtime"
end

return ShiftCueUtils
```

If luau-lsp widens the string literals inside `table.insert(list, "...")`, write `local cue: Cue = "..."` and insert `cue` (same behaviour, no cast).

- [ ] **Step 4: Assets** `src/ReplicatedStorage/Shared/Features/Shift/Data/ShiftAssets.luau`:

```lua
--!strict
--[=[
	ShiftAssets: every asset id the Shift feature uses (Cleanup Crew spec §7: "Asset id literals live only in each
	feature's Data/<Feature>Assets"). An id is PENDING ("") until the developer uploads the staged file (the M3
	plan's "Asset staging" appendix) and pastes `rbxassetid://<n>` here. A pending sound is never registered, so
	every player of it (they all check SoundRegistry.has) stays silent. Registers the uploaded sounds at load on
	whichever realm requires this first (guarded). CUE_SOUNDS says which sound each shift moment plays
	(ShiftCueUtils.Cue → id).

	Static data + registration (spec-exempt).

	@class ShiftAssets
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SoundRegistry = require(ReplicatedStorage.Shared.Features.Sound.Data.SoundRegistry)
local SoundTypes = require(ReplicatedStorage.Shared.Features.Sound.Data.SoundTypes)

local PENDING = ""

local SOUNDS: { [string]: SoundTypes.SoundDef } = {
	-- A punch-clock "ka-chunk" when the shift starts.
	shiftPunchIn = { assetId = PENDING, group = "SFX", volume = 0.8 },
	-- The truck's horn: quota met, and the shift's end.
	shiftTruckHorn = { assetId = PENDING, group = "SFX", volume = 1 },
	-- A low brass sting when the pressure tier rises.
	shiftTierSting = { assetId = PENDING, group = "SFX", volume = 0.7 },
	-- An office PA chime before overtime.
	shiftWarningChime = { assetId = PENDING, group = "UI", volume = 0.8 },
	shiftOvertimeSting = { assetId = PENDING, group = "SFX", volume = 0.9 },
	-- The overtime layer: a clock ticking under everything (looped).
	shiftTicking = { assetId = PENDING, group = "Music", volume = 0.5, looped = true },
	-- Two honks: someone clocked out.
	shiftClockOutHorn = { assetId = PENDING, group = "SFX", volume = 1 },
	shiftCountdownTick = { assetId = PENDING, group = "UI", volume = 0.6, maxConcurrent = 2 },
	-- The toast styles' sounds (ShiftConstants.TOAST_STYLES): a paper rustle and a rubber stamp.
	shiftStickyNote = { assetId = PENDING, group = "UI", volume = 0.6 },
	shiftStamp = { assetId = PENDING, group = "UI", volume = 0.9 },
}

local CUE_SOUNDS: { [string]: string } = {
	shiftStart = "shiftPunchIn",
	quotaMet = "shiftTruckHorn",
	tierUp = "shiftTierSting",
	warning = "shiftWarningChime",
	overtime = "shiftOvertimeSting",
	clockOut = "shiftClockOutHorn",
	shiftEnd = "shiftTruckHorn",
}

for id, def in SOUNDS do
	if def.assetId ~= PENDING and not SoundRegistry.has(id) then
		SoundRegistry.register(id, def)
	end
end

return table.freeze({
	PENDING = PENDING,
	SOUNDS = table.freeze(SOUNDS),
	CUE_SOUNDS = table.freeze(CUE_SOUNDS),
	TICKING = "shiftTicking",
	COUNTDOWN_TICK = "shiftCountdownTick",
})
```

- [ ] **Step 5: Constants.** In `src/ReplicatedStorage/Shared/Features/Shift/Data/ShiftConstants.luau`, in the returned table after `STAMP_SECONDS = 3,`, add:

```lua
	-- Feel (spec §7): the quota's FOV kick, the camera shake of a tier rise and of overtime, the overtime ticking
	-- layer's ambience slot, and the clock-out countdown's louder last seconds. The client re-checks every
	-- FEEDBACK_INTERVAL seconds.
	QUOTA_FOV_KICK = 8,
	QUOTA_FOV_SECONDS = 0.6,
	TIER_TRAUMA = 0.2,
	OVERTIME_TRAUMA = 0.3,
	TICKING_LAYER = "shiftOvertime",
	COUNTDOWN_LOUD = 3,
	COUNTDOWN_LOUD_SCALE = 1.6,
	FEEDBACK_INTERVAL = 0.1,
```

- [ ] **Step 6: System** `src/ReplicatedStorage/Client/Features/Shift/Systems/ShiftFeedbackSystem.luau`:

```lua
--!strict
--[=[
	ShiftFeedbackSystem: how the shift sounds and feels on this client (Cleanup Crew spec §7 table: quota met
	"truck horn", tier up, overtime "ticking music layer", clock out "horn honks"; the shift's start and end). It
	watches ShiftStore's snapshot: ShiftCueUtils says which moments just happened, and each plays its sound
	(ShiftAssets.CUE_SOUNDS) and camera kick. Overtime keeps the ticking layer on (a SoundServiceClient ambience
	slot); a clock-out countdown ticks every second, louder for the last COUNTDOWN_LOUD. The stamps and sticky
	notes are toasts the server sends (ShiftNoticeUtils); the lights' flicker is Harlow's tells. A pending sound
	(ShiftAssets) is skipped silently and counted.

	Spec-exempt shell (Sound, Camera, Charm, RunService); the choices are the specced ShiftCueUtils.

	@class ShiftFeedbackSystem
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local ShiftShared = ReplicatedStorage.Shared.Features.Shift
local Charm = require(ReplicatedStorage.Packages.Charm)
local Logger = require(ReplicatedStorage.Shared.Core.Logger)
local ShiftAssets = require(ShiftShared.Data.ShiftAssets)
local ShiftConstants = require(ShiftShared.Data.ShiftConstants)
local ShiftTypes = require(ShiftShared.Data.ShiftTypes)
local SoundRegistry = require(ReplicatedStorage.Shared.Features.Sound.Data.SoundRegistry)
local ShiftCueUtils = require(ReplicatedStorage.Client.Features.Shift.Utils.ShiftCueUtils)
local ShiftStore = require(ReplicatedStorage.Client.Features.Shift.State.ShiftStore)
local CameraServiceClient = require(ReplicatedStorage.Client.Features.Camera.CameraServiceClient)
local SoundServiceClient = require(ReplicatedStorage.Client.Features.Sound.SoundServiceClient)

local log = Logger.new("ShiftFeedbackSystem")

local counters = { cues = 0, played = 0, pending = 0, ticks = 0 }
local stoppers: { () -> () } = {}
local last: ShiftTypes.ShiftSnapshot? = nil
local ticking = false
local lastSecond: number? = nil

-- Plays a Shift sound if it is uploaded; a pending one is counted, an undeclared one is a developer error.
local function play(id: string, volumeScale: number?)
	if ShiftAssets.SOUNDS[id] == nil then
		log:warn(`"{id}" is not a ShiftAssets sound`)
		return
	end
	if not SoundRegistry.has(id) then
		counters.pending += 1
		return
	end
	counters.played += 1
	SoundServiceClient:play(id, { volumeScale = volumeScale })
end

local function kick(cue: ShiftCueUtils.Cue)
	if cue == "quotaMet" then
		CameraServiceClient:kickFov(ShiftConstants.QUOTA_FOV_KICK, ShiftConstants.QUOTA_FOV_SECONDS)
	elseif cue == "tierUp" then
		CameraServiceClient:addTrauma(ShiftConstants.TIER_TRAUMA)
	elseif cue == "overtime" then
		CameraServiceClient:addTrauma(ShiftConstants.OVERTIME_TRAUMA)
	end
end

local function setTicking(on: boolean)
	if on == ticking then
		return
	end
	ticking = on
	if not on then
		SoundServiceClient:setAmbience(ShiftConstants.TICKING_LAYER, nil)
	elseif SoundRegistry.has(ShiftAssets.TICKING) then
		SoundServiceClient:setAmbience(ShiftConstants.TICKING_LAYER, ShiftAssets.TICKING)
	else
		counters.pending += 1
	end
end

local function onSnapshot(current: ShiftTypes.ShiftSnapshot?)
	for _, cue in ShiftCueUtils.cues(last, current) do
		counters.cues += 1
		local id = ShiftAssets.CUE_SOUNDS[cue]
		if id ~= nil then
			play(id)
		end
		kick(cue)
	end
	last = current
	setTicking(ShiftCueUtils.ticking(current))
end

-- The clock-out countdown: one tick per whole second, louder at the end.
local function stepCountdown()
	local second = ShiftCueUtils.countdown(ShiftStore.snapshot(), Workspace:GetServerTimeNow())
	if second == lastSecond then
		return
	end
	lastSecond = second
	if second ~= nil and second > 0 then
		counters.ticks += 1
		local loud = second <= ShiftConstants.COUNTDOWN_LOUD
		play(ShiftAssets.COUNTDOWN_TICK, if loud then ShiftConstants.COUNTDOWN_LOUD_SCALE else 1)
	end
end

local ShiftFeedbackSystem = {}

function ShiftFeedbackSystem.start()
	if #stoppers > 0 then
		return
	end
	-- The first snapshot is the baseline: it cues nothing, but the ticking layer matches it.
	last = ShiftStore.snapshot()
	setTicking(ShiftCueUtils.ticking(last))
	table.insert(stoppers, Charm.subscribe(ShiftStore.snapshot, onSnapshot))
	local elapsed = 0
	local connection = RunService.Heartbeat:Connect(function(deltaTime: number)
		elapsed += deltaTime
		if elapsed >= ShiftConstants.FEEDBACK_INTERVAL then
			elapsed = 0
			stepCountdown()
		end
	end)
	table.insert(stoppers, function()
		connection:Disconnect()
	end)
end

function ShiftFeedbackSystem.stop()
	for _, stop in stoppers do
		stop()
	end
	table.clear(stoppers)
	setTicking(false)
	last = nil
	lastSecond = nil
end

function ShiftFeedbackSystem.getState(): { [string]: any }
	return { ticking = ticking, counters = table.clone(counters) }
end

return ShiftFeedbackSystem
```

- [ ] **Step 7: Wire it.** In `src/ReplicatedStorage/Client/Features/Shift/ShiftServiceClient.luau`:
  - Require `local ShiftFeedbackSystem = require(ReplicatedStorage.Client.Features.Shift.Systems.ShiftFeedbackSystem)` after the `ShiftStore` require.
  - Add `"SoundServiceClient", "CameraServiceClient"` to `dependencies`.
  - At the end of `start`: `ShiftFeedbackSystem.start()`. At the start of `stop`: `ShiftFeedbackSystem.stop()`.
  - Header comment: add "Starts ShiftFeedbackSystem (the shift's horns, stings, ticking layer and countdown) and registers the sticky-note and stamp toast styles."

- [ ] **Step 8: Exemptions.** In `SpecRoots.luau` `EXEMPT_MODULES`, under `-- Cleanup Crew: Shift`, add:

```lua
	["ReplicatedStorage.Shared.Features.Shift.Data.ShiftAssets"] = "asset id slots; registers the uploaded sounds at load (no decisions)",
	["ReplicatedStorage.Client.Features.Shift.Systems.ShiftFeedbackSystem"] = "Sound/Camera/Charm shell (cue choices are specced in ShiftCueUtils)",
```

- [ ] **Step 9: Module map, format and gate** (Global Constraints order). Expected: `==> All checks passed.`

- [ ] **Step 10: Controller: Studio TestEZ.** Expected: ShiftCueUtils passes; `assertAllModulesSpecced` passes.

- [ ] **Step 11: Controller: Studio verification** (Play Solo, `RunTests = false`). Inject the Task 1 server Script (`_G.S`, `_G.R`) and a temporary client LocalScript:

```lua
local F = require(game.ReplicatedStorage.Client.Features.Shift.Systems.ShiftFeedbackSystem)
task.spawn(function()
	while true do
		task.wait(1)
		local s = F.getState()
		print("SHIFTFEEL", s.ticking, s.counters.cues, s.counters.played, s.counters.pending, s.counters.ticks)
	end
end)
```
Checklist, first with every id pending:
1. Shift start: `cues` goes to 1 (shiftStart), `pending` rises, `played` stays 0; no "unknown sound" and no "is not a ShiftAssets sound" warning in Output.
2. Quota met (`_G.R:addTeam("clearance", 345)` + Load): the camera FOV kicks out and back; `cues` +1.
3. Tier rise at 2:00 and the overtime start: a camera shake each; in overtime `ticking = true`.
4. Clock out in overtime: `ticks` grows by 10 over the 10 s; at results `ticking = false`.

Then with test sounds: at the top of the client LocalScript register two free Creator Store sounds found with the Studio MCP (`search_asset` "truck horn" and "clock ticking"; take each id from `insert_asset`):
```lua
local SR = require(game.ReplicatedStorage.Shared.Features.Sound.Data.SoundRegistry)
SR.register("shiftTruckHorn", { assetId = "rbxassetid://<horn id>", group = "SFX", volume = 1 })
SR.register("shiftTicking", { assetId = "rbxassetid://<tick id>", group = "Music", volume = 0.5, looped = true })
```
5. Quota met: one horn. Overtime: the ticking fades in and keeps going; at results it fades out.
6. `_G.S:resetShift()` mid-overtime: the ticking stops; the next shift cues only `shiftStart`.

- [ ] **Step 12: Commit**

```bash
git commit -m "feat(shift): horns, stings, overtime ticking layer and clock-out countdown ticks"
python3 scripts/python/module_map.py --check
```

---
### Task 3: Vacuum feel (suction particles, rising whine, pop + sparkle, canister sounds)

**Files:**
- Create: `src/ReplicatedStorage/Shared/Features/Vacuum/Data/VacuumAssets.luau`
- Create: `src/ReplicatedStorage/Client/Features/Vacuum/Utils/VacuumFeedbackFormulas.luau` (+ `VacuumFeedbackFormulas.spec.luau`)
- Create: `src/ReplicatedStorage/Client/Features/Vacuum/Systems/VacuumFeedbackSystem.luau`
- Modify: `src/ReplicatedStorage/Shared/Features/Vacuum/Data/VacuumConstants.luau`
- Modify: `src/ReplicatedStorage/Client/Features/Vacuum/VacuumServiceClient.luau`
- Modify: `src/ServerScriptService/Core/Testing/SpecRoots.luau`

**Interfaces:**
- Consumes: piles tagged `VacuumConstants.PILE_TAG` carrying `InteractionConstants.CHANNEL_PROGRESS_ATTRIBUTE` (0..1, set to nil when the channel completes, in the same frame the pile is destroyed) and `CHANNEL_COUNT_ATTRIBUTE` (channelers; nil when none); the server shrinks piles itself (M1). The local public field `VacuumConstants.PUBLIC_FIELD` ("canister") in `StateSyncClientStore.publicPlayers()[StateSyncConstants.publicEntryKey(userId)]`; a pile that fills the canister makes it 0 (`VacuumCanisterUtils.add`). `ShiftStore.snapshot()` (phase). `Observers.observeTag(tag, fn(instance) -> cleanup?) -> stop`.
- Produces (VacuumAssets): `PENDING`, `SOUNDS` (`vacuumWhine` looped, `vacuumPop`, `canisterTick`, `canisterChime`, `dustBagPop`), `WHINE = "vacuumWhine"`, `POP = "vacuumPop"`.
- Produces (VacuumFeedbackFormulas): `type CanisterCue = "fill" | "full"`; `whine(progress: number) -> (number, number)` (PlaybackSpeed, volume factor); `cleared(peakProgress: number, secondsSinceActive: number) -> boolean`; `canisterCue(before: number, after: number, capacity: number, running: boolean) -> CanisterCue?`; `nearest(origin: Vector3, positions: { Vector3 }, range: number) -> number?`.
- Produces (VacuumFeedbackSystem, client module-level): `start()`, `stop()`, `getState()`.
- Produces (VacuumConstants, new keys): `WHINE_PITCH_MIN = 0.85`, `WHINE_PITCH_MAX = 1.6`, `WHINE_VOLUME_MIN = 0.6`, `WHINE_VOLUME_MAX = 1.25`, `POP_PROGRESS = 0.5`, `POP_WINDOW = 0.6`, `VACUUMER_RANGE = 10`, `SUCTION_RATE = 40`, `SUCTION_LIFETIME = 0.4`, `SUCTION_SIZE = 0.35`, `SUCTION_COLOR`, `SPARKLE_COUNT = 24`, `SPARKLE_LIFETIME = 0.6`, `SPARKLE_SPEED = 10`, `SPARKLE_COLOR`.

- [ ] **Step 1: Write the failing spec** `src/ReplicatedStorage/Client/Features/Vacuum/Utils/VacuumFeedbackFormulas.spec.luau`:

```lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local VacuumFeedbackFormulas = require(script.Parent.VacuumFeedbackFormulas)
local VacuumConstants = require(ReplicatedStorage.Shared.Features.Vacuum.Data.VacuumConstants)

return function()
	describe("whine", function()
		it("rises from the low pitch and volume to the high ones as the pile empties", function()
			local lowPitch, lowVolume = VacuumFeedbackFormulas.whine(0)
			local highPitch, highVolume = VacuumFeedbackFormulas.whine(1)
			expect(lowPitch).to.be.near(VacuumConstants.WHINE_PITCH_MIN, 1e-6)
			expect(lowVolume).to.be.near(VacuumConstants.WHINE_VOLUME_MIN, 1e-6)
			expect(highPitch).to.be.near(VacuumConstants.WHINE_PITCH_MAX, 1e-6)
			expect(highVolume).to.be.near(VacuumConstants.WHINE_VOLUME_MAX, 1e-6)
			local midPitch = VacuumFeedbackFormulas.whine(0.5)
			expect(midPitch > lowPitch and midPitch < highPitch).to.equal(true)
		end)

		it("clamps progress outside 0..1", function()
			expect(VacuumFeedbackFormulas.whine(-1)).to.be.near(VacuumConstants.WHINE_PITCH_MIN, 1e-6)
			expect(VacuumFeedbackFormulas.whine(3)).to.be.near(VacuumConstants.WHINE_PITCH_MAX, 1e-6)
		end)
	end)

	describe("cleared", function()
		it("pops a pile that was being vacuumed past half, even after its progress was cleared", function()
			expect(VacuumFeedbackFormulas.cleared(0.97, 0)).to.equal(true)
			expect(VacuumFeedbackFormulas.cleared(VacuumConstants.POP_PROGRESS, VacuumConstants.POP_WINDOW)).to.equal(true)
		end)

		it("does not pop a pile removed by a reset", function()
			expect(VacuumFeedbackFormulas.cleared(0, 100)).to.equal(false)
			expect(VacuumFeedbackFormulas.cleared(0.8, 30)).to.equal(false)
		end)

		it("does not pop a barely-touched pile", function()
			expect(VacuumFeedbackFormulas.cleared(0.2, 0)).to.equal(false)
		end)
	end)

	describe("canisterCue", function()
		it("ticks when a pile goes in", function()
			expect(VacuumFeedbackFormulas.canisterCue(0, 1, 3, true)).to.equal("fill")
			expect(VacuumFeedbackFormulas.canisterCue(1, 2, 3, true)).to.equal("fill")
		end)

		it("chimes when the last pile pops a dust bag", function()
			expect(VacuumFeedbackFormulas.canisterCue(2, 0, 3, true)).to.equal("full")
		end)

		it("never chimes outside a running shift (a reset empties the canister)", function()
			expect(VacuumFeedbackFormulas.canisterCue(2, 0, 3, false)).to.equal(nil)
			expect(VacuumFeedbackFormulas.canisterCue(0, 1, 3, false)).to.equal(nil)
		end)

		it("says nothing for an emptied canister that was not about to pop", function()
			expect(VacuumFeedbackFormulas.canisterCue(1, 0, 3, true)).to.equal(nil)
			expect(VacuumFeedbackFormulas.canisterCue(1, 1, 3, true)).to.equal(nil)
		end)
	end)

	describe("nearest", function()
		it("picks the closest point within range", function()
			local points = { Vector3.new(9, 0, 0), Vector3.new(3, 0, 0), Vector3.new(0, 0, 20) }
			expect(VacuumFeedbackFormulas.nearest(Vector3.zero, points, 10)).to.equal(2)
		end)

		it("is nil when nobody is in range", function()
			expect(VacuumFeedbackFormulas.nearest(Vector3.zero, { Vector3.new(50, 0, 0) }, 10)).to.equal(nil)
			expect(VacuumFeedbackFormulas.nearest(Vector3.zero, {}, 10)).to.equal(nil)
		end)
	end)
end
```

- [ ] **Step 2: Controller: Studio TestEZ.** Expected: the spec errors (module missing).

- [ ] **Step 3: Constants.** In `src/ReplicatedStorage/Shared/Features/Vacuum/Data/VacuumConstants.luau`, in the returned table after `BAG_OFFSET = ...,`, add:

```lua
	-- Feel (spec §7 "Vacuuming: suction particles into the nozzle, pile shrinks, rising whine, pop + sparkle,
	-- canister fills"; "Canister full: chime, dust bag pops out"). The whine rises with the pile's progress.
	WHINE_PITCH_MIN = 0.85,
	WHINE_PITCH_MAX = 1.6,
	WHINE_VOLUME_MIN = 0.6,
	WHINE_VOLUME_MAX = 1.25,
	-- A pile that disappears after being vacuumed past POP_PROGRESS within the last POP_WINDOW seconds was
	-- cleared (pop + sparkle); anything else (a reset) vanishes quietly.
	POP_PROGRESS = 0.5,
	POP_WINDOW = 0.6,
	-- How far from a pile its vacuumer's hand is looked for (a little past RANGE).
	VACUUMER_RANGE = 10,
	SUCTION_RATE = 40,
	SUCTION_LIFETIME = 0.4,
	SUCTION_SIZE = 0.35,
	SUCTION_COLOR = Color3.fromRGB(190, 180, 160),
	SPARKLE_COUNT = 24,
	SPARKLE_LIFETIME = 0.6,
	SPARKLE_SPEED = 10,
	SPARKLE_COLOR = Color3.fromRGB(255, 240, 170),
```

- [ ] **Step 4: Formulas** `src/ReplicatedStorage/Client/Features/Vacuum/Utils/VacuumFeedbackFormulas.luau`:

```lua
--!strict
--[=[
	VacuumFeedbackFormulas: the vacuum's feel maths (Cleanup Crew spec §7 "Vacuuming", "Canister full"). The
	whine's pitch and volume rise with the pile's progress; a pile that vanished was cleared (pop + sparkle) only
	if it was vacuumed past POP_PROGRESS within POP_WINDOW seconds, judged on its peak progress because the
	Interaction system clears the progress attribute in the same frame it completes the pile; the canister ticks
	as it fills and chimes when its last pile pops a dust bag, never outside a running shift (a reset empties it);
	the vacuumer is the nearest hand within range. Pure.

	@class VacuumFeedbackFormulas
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local VacuumConstants = require(ReplicatedStorage.Shared.Features.Vacuum.Data.VacuumConstants)

export type CanisterCue = "fill" | "full"

local VacuumFeedbackFormulas = {}

--[=[
	The whine's PlaybackSpeed and volume factor at `progress` (clamped to 0..1).
]=]
function VacuumFeedbackFormulas.whine(progress: number): (number, number)
	local fraction = math.clamp(progress, 0, 1)
	local pitch = VacuumConstants.WHINE_PITCH_MIN
		+ (VacuumConstants.WHINE_PITCH_MAX - VacuumConstants.WHINE_PITCH_MIN) * fraction
	local volume = VacuumConstants.WHINE_VOLUME_MIN
		+ (VacuumConstants.WHINE_VOLUME_MAX - VacuumConstants.WHINE_VOLUME_MIN) * fraction
	return pitch, volume
end

--[=[
	Whether a pile that just disappeared was vacuumed away (true) or removed some other way.
]=]
function VacuumFeedbackFormulas.cleared(peakProgress: number, secondsSinceActive: number): boolean
	return peakProgress >= VacuumConstants.POP_PROGRESS and secondsSinceActive <= VacuumConstants.POP_WINDOW
end

--[=[
	The canister sound for a fill change: "fill" when it rose, "full" when its last pile popped a dust bag
	(capacity - 1 → 0), nil otherwise or outside a running shift.
]=]
function VacuumFeedbackFormulas.canisterCue(before: number, after: number, capacity: number, running: boolean): CanisterCue?
	if not running then
		return nil
	end
	if after > before then
		return "fill"
	end
	if after == 0 and before == capacity - 1 then
		return "full"
	end
	return nil
end

--[=[
	The index of the point nearest `origin` within `range`, or nil.
]=]
function VacuumFeedbackFormulas.nearest(origin: Vector3, positions: { Vector3 }, range: number): number?
	local best: number? = nil
	local bestDistance = math.huge
	for index, position in positions do
		local distance = (position - origin).Magnitude
		if distance <= range and distance < bestDistance then
			best = index
			bestDistance = distance
		end
	end
	return best
end

return VacuumFeedbackFormulas
```

- [ ] **Step 5: Assets** `src/ReplicatedStorage/Shared/Features/Vacuum/Data/VacuumAssets.luau`:

```lua
--!strict
--[=[
	VacuumAssets: every asset id the Vacuum feature uses (Cleanup Crew spec §7: "Asset id literals live only in each
	feature's Data/<Feature>Assets"). An id is PENDING ("") until the developer uploads the staged file (the M3
	plan's "Asset staging" appendix); a pending sound is never registered, so playing it is silent. Registers the
	uploaded sounds at load on whichever realm requires this first (guarded).

	Static data + registration (spec-exempt).

	@class VacuumAssets
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SoundRegistry = require(ReplicatedStorage.Shared.Features.Sound.Data.SoundRegistry)
local SoundTypes = require(ReplicatedStorage.Shared.Features.Sound.Data.SoundTypes)

local PENDING = ""

local SOUNDS: { [string]: SoundTypes.SoundDef } = {
	-- A vacuum motor's whine (looped at the pile; its pitch rises with the pile's progress).
	vacuumWhine = { assetId = PENDING, group = "SFX", volume = 0.45, looped = true, rollOffMaxDistance = 60 },
	-- The pile's last bit going up the hose: a soft pop.
	vacuumPop = { assetId = PENDING, group = "SFX", volume = 0.8, pitch = { min = 0.95, max = 1.1 }, rollOffMaxDistance = 60 },
	-- Your canister taking a pile, and the chime when it is full.
	canisterTick = { assetId = PENDING, group = "UI", volume = 0.5 },
	canisterChime = { assetId = PENDING, group = "UI", volume = 0.8 },
	-- The dust bag popping out at your feet.
	dustBagPop = { assetId = PENDING, group = "SFX", volume = 0.8, rollOffMaxDistance = 40 },
}

for id, def in SOUNDS do
	if def.assetId ~= PENDING and not SoundRegistry.has(id) then
		SoundRegistry.register(id, def)
	end
end

return table.freeze({
	PENDING = PENDING,
	SOUNDS = table.freeze(SOUNDS),
	WHINE = "vacuumWhine",
	POP = "vacuumPop",
})
```

- [ ] **Step 6: System** `src/ReplicatedStorage/Client/Features/Vacuum/Systems/VacuumFeedbackSystem.luau`:

```lua
--!strict
--[=[
	VacuumFeedbackSystem: how vacuuming feels on this client (Cleanup Crew spec §7 "Vacuuming: suction particles
	into the nozzle, pile shrinks, rising whine, pop + sparkle, canister fills"; "Canister full: chime, dust bag
	pops out"). For every pile (Observers on PILE_TAG):
	- while anyone channels it (ChannelCount > 0): dust particles stream from the pile to the nearest vacuumer's
	  hand (re-aimed every frame) and a whine loops at the pile, its pitch and volume rising with ChannelProgress
	  (VacuumFeedbackFormulas.whine);
	- when it disappears after being vacuumed (VacuumFeedbackFormulas.cleared on its peak progress): a pop and a
	  sparkle burst where it was. The pile's shrinking is the server's (M1).
	Your own canister field ticks as it fills and chimes, with a pop at your feet, when it empties into a dust bag
	(VacuumFeedbackFormulas.canisterCue; only while a shift runs). Client-local instances; pending sounds
	(VacuumAssets) are skipped silently and counted.

	Spec-exempt shell (Instances, particles, Sound, Charm, RunService); the decisions are the specced
	VacuumFeedbackFormulas.

	@class VacuumFeedbackSystem
]=]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Charm = require(ReplicatedStorage.Packages.Charm)
local Observers = require(ReplicatedStorage.Packages.Observers)
local Logger = require(ReplicatedStorage.Shared.Core.Logger)
local InteractionConstants = require(ReplicatedStorage.Shared.Features.Interaction.Data.InteractionConstants)
local PublicPlayerTypes = require(ReplicatedStorage.Shared.Data.PublicPlayerTypes)
local SoundRegistry = require(ReplicatedStorage.Shared.Features.Sound.Data.SoundRegistry)
local SoundTypes = require(ReplicatedStorage.Shared.Features.Sound.Data.SoundTypes)
local StateSyncConstants = require(ReplicatedStorage.Shared.Features.StateSync.Data.StateSyncConstants)
local VacuumAssets = require(ReplicatedStorage.Shared.Features.Vacuum.Data.VacuumAssets)
local VacuumConstants = require(ReplicatedStorage.Shared.Features.Vacuum.Data.VacuumConstants)
local VacuumFeedbackFormulas = require(ReplicatedStorage.Client.Features.Vacuum.Utils.VacuumFeedbackFormulas)
local ShiftStore = require(ReplicatedStorage.Client.Features.Shift.State.ShiftStore)
local SoundServiceClient = require(ReplicatedStorage.Client.Features.Sound.SoundServiceClient)
local StateSyncClientStore = require(ReplicatedStorage.Client.Features.StateSync.State.StateSyncClientStore)

type PileFeel = {
	pile: BasePart,
	position: Vector3,
	progress: number,
	peak: number,
	count: number,
	activeAt: number,
	whine: SoundServiceClient.SoundHandle?,
	anchor: Attachment?,
	emitter: ParticleEmitter?,
}

local log = Logger.new("VacuumFeedbackSystem")

local active: { [BasePart]: PileFeel } = {}
local counters = { pops = 0, fills = 0, fulls = 0, played = 0, pending = 0 }
local stoppers: { () -> () } = {}
local lastFill: number? = nil

local function play(id: string, options: SoundTypes.PlayOptions?): SoundServiceClient.SoundHandle?
	if VacuumAssets.SOUNDS[id] == nil then
		log:warn(`"{id}" is not a VacuumAssets sound`)
		return nil
	end
	if not SoundRegistry.has(id) then
		counters.pending += 1
		return nil
	end
	counters.played += 1
	return SoundServiceClient:play(id, options)
end

local function readNumber(instance: Instance, name: string): number
	local value = instance:GetAttribute(name)
	return if type(value) == "number" then value else 0
end

-- The nearest vacuumer's hand (or root) to a pile, or nil.
local function vacuumerPoint(origin: Vector3): Vector3?
	local points: { Vector3 } = {}
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local hand = if character ~= nil
			then character:FindFirstChild("RightHand") or character:FindFirstChild("HumanoidRootPart")
			else nil
		if hand ~= nil and hand:IsA("BasePart") then
			table.insert(points, hand.Position)
		end
	end
	local index = VacuumFeedbackFormulas.nearest(origin, points, VacuumConstants.VACUUMER_RANGE)
	return if index ~= nil then points[index] else nil
end

local function startSuction(feel: PileFeel)
	if feel.emitter ~= nil then
		return
	end
	local anchor = Instance.new("Attachment")
	anchor.Name = "VacuumSuction"
	anchor.Parent = Workspace.Terrain
	anchor.WorldPosition = feel.position
	local emitter = Instance.new("ParticleEmitter")
	emitter.Color = ColorSequence.new(VacuumConstants.SUCTION_COLOR)
	emitter.Size = NumberSequence.new(VacuumConstants.SUCTION_SIZE, 0)
	emitter.Transparency = NumberSequence.new(0.2, 1)
	emitter.Lifetime = NumberRange.new(VacuumConstants.SUCTION_LIFETIME)
	emitter.Rate = VacuumConstants.SUCTION_RATE
	emitter.SpreadAngle = Vector2.new(20, 20)
	emitter.EmissionDirection = Enum.NormalId.Top
	emitter.LightEmission = 0.2
	emitter.Parent = anchor
	feel.anchor = anchor
	feel.emitter = emitter
end

local function stopSuction(feel: PileFeel)
	local anchor = feel.anchor
	local emitter = feel.emitter
	if emitter ~= nil then
		emitter.Enabled = false
	end
	if anchor ~= nil then
		task.delay(VacuumConstants.SUCTION_LIFETIME, function()
			anchor:Destroy()
		end)
	end
	feel.anchor = nil
	feel.emitter = nil
	local whine = feel.whine
	if whine ~= nil then
		whine:stop(0.15)
	end
	feel.whine = nil
end

-- Reads the pile's channel attributes and updates its suction and whine.
local function update(feel: PileFeel)
	feel.progress = readNumber(feel.pile, InteractionConstants.CHANNEL_PROGRESS_ATTRIBUTE)
	feel.count = readNumber(feel.pile, InteractionConstants.CHANNEL_COUNT_ATTRIBUTE)
	feel.peak = math.max(feel.peak, feel.progress)
	feel.position = feel.pile.Position
	if feel.count <= 0 then
		stopSuction(feel)
		return
	end
	feel.activeAt = os.clock()
	startSuction(feel)
	if feel.whine == nil and SoundRegistry.has(VacuumAssets.WHINE) then
		feel.whine = play(VacuumAssets.WHINE, { at = feel.pile })
	end
	local whine = feel.whine
	local def = SoundRegistry.get(VacuumAssets.WHINE)
	if whine ~= nil and def ~= nil then
		local pitch, volume = VacuumFeedbackFormulas.whine(feel.progress)
		whine.sound.PlaybackSpeed = pitch
		whine.sound.Volume = def.volume * volume
	end
end

local function pop(position: Vector3)
	counters.pops += 1
	play(VacuumAssets.POP, { at = position })
	local anchor = Instance.new("Attachment")
	anchor.Name = "VacuumSparkle"
	anchor.Parent = Workspace.Terrain
	anchor.WorldPosition = position
	local emitter = Instance.new("ParticleEmitter")
	emitter.Color = ColorSequence.new(VacuumConstants.SPARKLE_COLOR)
	emitter.Size = NumberSequence.new(0.5, 0)
	emitter.Lifetime = NumberRange.new(VacuumConstants.SPARKLE_LIFETIME)
	emitter.Speed = NumberRange.new(VacuumConstants.SPARKLE_SPEED * 0.5, VacuumConstants.SPARKLE_SPEED)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.LightEmission = 1
	emitter.Enabled = false
	emitter.Parent = anchor
	emitter:Emit(VacuumConstants.SPARKLE_COUNT)
	task.delay(VacuumConstants.SPARKLE_LIFETIME + 0.1, function()
		anchor:Destroy()
	end)
end

local function observePile(instance: Instance): (() -> ())?
	if not instance:IsA("BasePart") then
		return nil
	end
	local pile: BasePart = instance
	local feel: PileFeel = {
		pile = pile,
		position = pile.Position,
		progress = 0,
		peak = 0,
		count = 0,
		activeAt = -math.huge,
	}
	active[pile] = feel
	update(feel)
	local onChange = function()
		update(feel)
	end
	local progressChanged =
		pile:GetAttributeChangedSignal(InteractionConstants.CHANNEL_PROGRESS_ATTRIBUTE):Connect(onChange)
	local countChanged = pile:GetAttributeChangedSignal(InteractionConstants.CHANNEL_COUNT_ATTRIBUTE):Connect(onChange)
	return function()
		progressChanged:Disconnect()
		countChanged:Disconnect()
		active[pile] = nil
		local vacuumed = VacuumFeedbackFormulas.cleared(feel.peak, os.clock() - feel.activeAt)
		stopSuction(feel)
		if vacuumed then
			pop(feel.position)
		end
	end
end

-- Points every running suction stream at its vacuumer's hand.
local function aim()
	for _, feel in active do
		local anchor = feel.anchor
		local emitter = feel.emitter
		if anchor ~= nil and emitter ~= nil then
			local target = vacuumerPoint(feel.position)
			if target ~= nil then
				-- Top (+Y) emission, turned to face the hand: lookAt points -Z at it, the X turn brings +Y round.
				anchor.WorldCFrame = CFrame.lookAt(feel.position, target) * CFrame.Angles(-math.pi / 2, 0, 0)
				local distance = (target - feel.position).Magnitude
				emitter.Speed = NumberRange.new(distance / VacuumConstants.SUCTION_LIFETIME)
			end
		end
	end
end

local function myFill(map: PublicPlayerTypes.PublicPlayerMap): number
	local me = map[StateSyncConstants.publicEntryKey(Players.LocalPlayer.UserId)]
	local value = if me ~= nil then me[VacuumConstants.PUBLIC_FIELD] else nil
	return if type(value) == "number" then value else 0
end

local function onPublic(map: PublicPlayerTypes.PublicPlayerMap)
	local fill = myFill(map)
	local before = lastFill
	lastFill = fill
	if before == nil then
		return
	end
	local snapshot = ShiftStore.snapshot()
	local running = snapshot ~= nil and snapshot.phase == "running"
	local cue = VacuumFeedbackFormulas.canisterCue(before, fill, VacuumConstants.CANISTER_CAPACITY, running)
	if cue == "fill" then
		counters.fills += 1
		play("canisterTick")
	elseif cue == "full" then
		counters.fulls += 1
		play("canisterChime")
		local character = Players.LocalPlayer.Character
		local root = if character ~= nil then character:FindFirstChild("HumanoidRootPart") else nil
		if root ~= nil and root:IsA("BasePart") then
			play("dustBagPop", { at = root.Position })
		end
	end
end

local VacuumFeedbackSystem = {}

function VacuumFeedbackSystem.start()
	if #stoppers > 0 then
		return
	end
	table.insert(stoppers, Observers.observeTag(VacuumConstants.PILE_TAG, observePile))
	lastFill = myFill(StateSyncClientStore.publicPlayers())
	table.insert(stoppers, Charm.subscribe(StateSyncClientStore.publicPlayers, onPublic))
	local connection = RunService.RenderStepped:Connect(aim)
	table.insert(stoppers, function()
		connection:Disconnect()
	end)
end

function VacuumFeedbackSystem.stop()
	for _, stop in stoppers do
		stop()
	end
	table.clear(stoppers)
	for _, feel in active do
		stopSuction(feel)
	end
	table.clear(active)
	lastFill = nil
end

function VacuumFeedbackSystem.getState(): { [string]: any }
	local streaming = 0
	for _, feel in active do
		if feel.emitter ~= nil then
			streaming += 1
		end
	end
	return { piles = streaming, counters = table.clone(counters) }
end

return VacuumFeedbackSystem
```

Notes for the implementer: `Observers.observeTag` runs the returned cleanup when the pile leaves the tag, which includes its destruction. If luau-lsp rejects `local pile: BasePart = instance` after the `IsA` guard, bind it inside an `if instance:IsA("BasePart") then ... end` branch instead (no cast). If `RenderStepped:Connect(aim)` complains about the `deltaTime` argument, wrap it: `function(_deltaTime: number) aim() end`.

- [ ] **Step 7: Wire it.** In `src/ReplicatedStorage/Client/Features/Vacuum/VacuumServiceClient.luau`:
  - Require `local VacuumFeedbackSystem = require(ReplicatedStorage.Client.Features.Vacuum.Systems.VacuumFeedbackSystem)` after the `VacuumAimUtils` require.
  - Add `"SoundServiceClient", "StateSyncServiceClient"` to `dependencies`.
  - At the end of `start`: `VacuumFeedbackSystem.start()`. In `stop`, after `self:endVacuum()`: `VacuumFeedbackSystem.stop()`.
  - Header comment: add "VacuumFeedbackSystem plays the suction, whine, pop and canister sounds."

- [ ] **Step 8: Exemptions.** Under `-- Cleanup Crew: Vacuum`, add:

```lua
	["ReplicatedStorage.Shared.Features.Vacuum.Data.VacuumAssets"] = "asset id slots; registers the uploaded sounds at load (no decisions)",
	["ReplicatedStorage.Client.Features.Vacuum.Systems.VacuumFeedbackSystem"] = "particles/Sound/Charm shell (decisions specced in VacuumFeedbackFormulas)",
```

- [ ] **Step 9: Module map, format and gate** (Global Constraints order). Expected: `==> All checks passed.`

- [ ] **Step 10: Controller: Studio TestEZ.** Expected: VacuumFeedbackFormulas passes.

- [ ] **Step 11: Controller: Studio verification** (Play Solo, `RunTests = false`). Inject a temporary client LocalScript:

```lua
local V = require(game.ReplicatedStorage.Client.Features.Vacuum.Systems.VacuumFeedbackSystem)
task.spawn(function()
	while true do
		task.wait(0.5)
		local s = V.getState()
		print("VACFEEL", s.piles, s.counters.pops, s.counters.fills, s.counters.fulls, s.counters.pending)
	end
end)
```
Checklist (screenshots of 1-2):
1. Hold the vacuum on a pile: a stream of beige dust flows from the pile into your right hand (re-aims as you strafe); `piles = 1`; release: the stream stops within ~0.4 s.
2. Vacuum a pile to the end: a bright sparkle burst and `pops` +1 exactly once; the pile shrank as before.
3. Clear three piles: `fills` +2, then `fulls` +1 (the third pops a dust bag at your feet).
4. Vacuum a pile halfway, walk away, then `_G.S:resetShift()` from a server Script (`_G.S` as in Task 1): no sparkle, `pops` unchanged, no `fulls` from the canister reset.
5. Output: no "unknown sound" and no "is not a VacuumAssets sound" warning with every id pending.
6. With a test whine registered (`search_asset` "vacuum cleaner loop", register as `vacuumWhine` with `looped = true` in the LocalScript): the hum rises in pitch as the pile empties and stops on release.

- [ ] **Step 12: Commit**

```bash
git commit -m "feat(vacuum): suction particles, rising whine, pop and sparkle, canister sounds"
python3 scripts/python/module_map.py --check
```

---
### Task 4: The noise ripple ring

**Files:**
- Create: `src/ReplicatedStorage/Client/Features/Noise/Utils/NoiseRippleFormulas.luau` (+ `NoiseRippleFormulas.spec.luau`)
- Modify (full replacement): `src/ReplicatedStorage/Shared/Features/Noise/Data/NoiseConstants.luau`
- Modify (full replacement): `src/ReplicatedStorage/Client/Features/Noise/NoiseServiceClient.luau`

**Interfaces:**
- Consumes: M2's `NoiseEvents.packets.Ripple` (server → all, `{ position: Vector3, radius: number }`, radius already the heard radius: `NoiseRules.heardRadius(radius, hearingScale)`).
- Produces (NoiseRippleFormulas): `type Ring = { outer: number, inner: number, transparency: number }`; `ring(radius: number, alpha: number) -> Ring`; `shown(viewer: Vector3, origin: Vector3, radius: number) -> boolean`.
- Produces (NoiseConstants, replacing M2's placeholder keys): `RIPPLE_NAME`, `RIPPLE_SECONDS = 1.1`, `RIPPLE_COLOR`, `RIPPLE_START_FRACTION = 0.25`, `RIPPLE_WIDTH_FRACTION = 0.12`, `RIPPLE_MIN_WIDTH = 0.5`, `RIPPLE_START_TRANSPARENCY = 0.55`, `RIPPLE_HEIGHT = 0.05`, `RIPPLE_LIFT = 0.06`, `RIPPLE_MAX_DISTANCE = 200`, `FLOOR_PROBE = 12`. (Task 0 Step 2's grep confirmed only NoiseServiceClient reads NoiseConstants; if anything else does, keep the keys it reads.)
- Engine API used: `CylinderHandleAdornment.Radius / InnerRadius / Height / Transparency / Color3 / CFrame / Adornee` (`InnerRadius` makes it a ring). If Studio reports `InnerRadius is not a valid member`, stop and report: the fallback (a ring of thin parts) needs a plan change.

- [ ] **Step 1: Write the failing spec** `src/ReplicatedStorage/Client/Features/Noise/Utils/NoiseRippleFormulas.spec.luau`:

```lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local NoiseRippleFormulas = require(script.Parent.NoiseRippleFormulas)
local NoiseConstants = require(ReplicatedStorage.Shared.Features.Noise.Data.NoiseConstants)

return function()
	describe("ring", function()
		it("starts small, faint and banded", function()
			local ring = NoiseRippleFormulas.ring(40, 0)
			expect(ring.outer).to.be.near(40 * NoiseConstants.RIPPLE_START_FRACTION, 1e-6)
			expect(ring.outer - ring.inner).to.be.near(40 * NoiseConstants.RIPPLE_WIDTH_FRACTION, 1e-6)
			expect(ring.transparency).to.be.near(NoiseConstants.RIPPLE_START_TRANSPARENCY, 1e-6)
		end)

		it("ends exactly at the heard radius, at its thinnest, invisible", function()
			local ring = NoiseRippleFormulas.ring(40, 1)
			expect(ring.outer).to.be.near(40, 1e-6)
			expect(ring.outer - ring.inner).to.be.near(NoiseConstants.RIPPLE_MIN_WIDTH, 1e-6)
			expect(ring.transparency).to.be.near(1, 1e-6)
		end)

		it("spreads fast then slows (eases out)", function()
			local early = NoiseRippleFormulas.ring(40, 0.25).outer - NoiseRippleFormulas.ring(40, 0).outer
			local late = NoiseRippleFormulas.ring(40, 1).outer - NoiseRippleFormulas.ring(40, 0.75).outer
			expect(early > late).to.equal(true)
		end)

		it("never inverts the band on a tiny noise", function()
			local ring = NoiseRippleFormulas.ring(1, 0.5)
			expect(ring.inner >= 0).to.equal(true)
			expect(ring.inner <= ring.outer).to.equal(true)
		end)

		it("clamps alpha and a negative radius", function()
			expect(NoiseRippleFormulas.ring(40, 2).outer).to.be.near(40, 1e-6)
			expect(NoiseRippleFormulas.ring(40, -1).outer).to.be.near(40 * NoiseConstants.RIPPLE_START_FRACTION, 1e-6)
			expect(NoiseRippleFormulas.ring(-5, 0.5).outer).to.equal(0)
		end)
	end)

	describe("shown", function()
		it("draws a ripple whose ring comes within reach of the camera", function()
			local far = NoiseConstants.RIPPLE_MAX_DISTANCE
			expect(NoiseRippleFormulas.shown(Vector3.zero, Vector3.new(far + 30, 0, 0), 40)).to.equal(true)
			expect(NoiseRippleFormulas.shown(Vector3.zero, Vector3.new(far + 50, 0, 0), 40)).to.equal(false)
		end)

		it("never draws a noise with no radius", function()
			expect(NoiseRippleFormulas.shown(Vector3.zero, Vector3.zero, 0)).to.equal(false)
		end)
	end)
end
```

- [ ] **Step 2: Controller: Studio TestEZ.** Expected: the spec errors (module missing; constants missing).

- [ ] **Step 3: Constants.** Replace `src/ReplicatedStorage/Shared/Features/Noise/Data/NoiseConstants.luau` with:

```lua
--!strict
--[=[
	NoiseConstants: the ripple ring's look (Cleanup Crew spec §7: "any noise: faint ripple ring on the floor at the
	radius Harlow hears it"). A thin pale ring that spreads from a quarter of the heard radius out to all of it,
	thinning and fading (NoiseRippleFormulas). The radii themselves live with their sources (VacuumConstants,
	CargoConstants). Static data (spec-exempt).

	@class NoiseConstants
]=]

return table.freeze({
	RIPPLE_NAME = "NoiseRipple",
	-- Seconds from the noise to the ring vanishing at the heard radius.
	RIPPLE_SECONDS = 1.1,
	RIPPLE_COLOR = Color3.fromRGB(205, 225, 255),
	-- The ring starts at this fraction of the heard radius and eases out to all of it.
	RIPPLE_START_FRACTION = 0.25,
	-- Its band starts this fraction of the radius wide and thins to RIPPLE_MIN_WIDTH studs.
	RIPPLE_WIDTH_FRACTION = 0.12,
	RIPPLE_MIN_WIDTH = 0.5,
	-- Faint: it starts this transparent and fades to nothing.
	RIPPLE_START_TRANSPARENCY = 0.55,
	-- The ring's thickness, and how far above the floor it floats (no z-fighting).
	RIPPLE_HEIGHT = 0.05,
	RIPPLE_LIFT = 0.06,
	-- A ripple whose ring never comes within this many studs of the camera is not drawn.
	RIPPLE_MAX_DISTANCE = 200,
	-- How far down the floor is looked for under a noise.
	FLOOR_PROBE = 12,
})
```

- [ ] **Step 4: Formulas** `src/ReplicatedStorage/Client/Features/Noise/Utils/NoiseRippleFormulas.luau`:

```lua
--!strict
--[=[
	NoiseRippleFormulas: the ripple ring over its life (Cleanup Crew spec §7 "faint ripple ring on the floor at the
	radius Harlow hears it"). At `alpha` (0 = the noise, 1 = gone) the ring's outer edge has eased out from
	RIPPLE_START_FRACTION of the heard radius to all of it, its band has thinned from RIPPLE_WIDTH_FRACTION of the
	radius to RIPPLE_MIN_WIDTH, and it has faded from RIPPLE_START_TRANSPARENCY to invisible. A ripple is drawn
	only when its ring can come within RIPPLE_MAX_DISTANCE of the camera. Pure.

	@class NoiseRippleFormulas
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local NoiseConstants = require(ReplicatedStorage.Shared.Features.Noise.Data.NoiseConstants)

export type Ring = {
	outer: number,
	inner: number,
	transparency: number,
}

local NoiseRippleFormulas = {}

function NoiseRippleFormulas.ring(radius: number, alpha: number): Ring
	local t = math.clamp(alpha, 0, 1)
	local size = math.max(radius, 0)
	local eased = 1 - (1 - t) * (1 - t)
	local start = NoiseConstants.RIPPLE_START_FRACTION
	local outer = size * (start + (1 - start) * eased)
	local width = math.max(NoiseConstants.RIPPLE_MIN_WIDTH, size * NoiseConstants.RIPPLE_WIDTH_FRACTION * (1 - t))
	local faint = NoiseConstants.RIPPLE_START_TRANSPARENCY
	return {
		outer = outer,
		inner = math.max(0, outer - width),
		transparency = faint + (1 - faint) * t,
	}
end

function NoiseRippleFormulas.shown(viewer: Vector3, origin: Vector3, radius: number): boolean
	return radius > 0 and (viewer - origin).Magnitude <= NoiseConstants.RIPPLE_MAX_DISTANCE + radius
end

return NoiseRippleFormulas
```

- [ ] **Step 5: Client.** Replace `src/ReplicatedStorage/Client/Features/Noise/NoiseServiceClient.luau` with:

```lua
--!strict
--[=[
	NoiseServiceClient: the ripple ring (Cleanup Crew spec §7: "any noise: faint ripple ring on the floor at the
	radius Harlow hears it"). Each `Ripple` becomes a thin, pale ring lying on the floor under the noise: a
	CylinderHandleAdornment with an inner radius, on an invisible anchor, that spreads out to the heard radius,
	thins and fades (NoiseRippleFormulas), driven every frame until it is gone. Ripples whose ring stays far from
	the camera are not drawn. Client-local instances (never replicated).

	Spec-exempt shell (Instances, raycasts, RunService); the ring's shape over time is the specced
	NoiseRippleFormulas.

	@class NoiseServiceClient
]=]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local NoiseConstants = require(ReplicatedStorage.Shared.Features.Noise.Data.NoiseConstants)
local NoiseEvents = require(ReplicatedStorage.Shared.Features.Noise.Net.NoiseEvents)
local NoiseRippleFormulas = require(ReplicatedStorage.Client.Features.Noise.Utils.NoiseRippleFormulas)

type Ripple = {
	anchor: BasePart,
	ring: CylinderHandleAdornment,
	radius: number,
	started: number,
}

local ripples: { Ripple } = {}
local stoppers: { () -> () } = {}
local counters = { drawn = 0, skipped = 0 }

-- The floor under a noise (characters and non-colliding parts ignored), or the noise itself.
local function floorBelow(position: Vector3): Vector3
	local ignore: { Instance } = {}
	for _, player in Players:GetPlayers() do
		local character = player.Character
		if character ~= nil then
			table.insert(ignore, character)
		end
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = ignore
	params.RespectCanCollide = true
	local hit =
		Workspace:Raycast(position + Vector3.new(0, 1, 0), Vector3.new(0, -NoiseConstants.FLOOR_PROBE, 0), params)
	return if hit ~= nil then hit.Position else position
end

local function shape(ring: CylinderHandleAdornment, radius: number, alpha: number)
	local frame = NoiseRippleFormulas.ring(radius, alpha)
	-- Radius before InnerRadius when growing, so the inner never exceeds the outer for a frame.
	ring.Radius = frame.outer
	ring.InnerRadius = frame.inner
	ring.Transparency = frame.transparency
end

local function draw(position: Vector3, radius: number)
	local camera = Workspace.CurrentCamera
	if camera == nil or not NoiseRippleFormulas.shown(camera.CFrame.Position, position, radius) then
		counters.skipped += 1
		return
	end
	local floor = floorBelow(position)
	local anchor = Instance.new("Part")
	anchor.Name = NoiseConstants.RIPPLE_NAME
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CanTouch = false
	anchor.CastShadow = false
	anchor.Transparency = 1
	anchor.Size = Vector3.new(0.2, 0.2, 0.2)
	anchor.CFrame = CFrame.new(floor + Vector3.new(0, NoiseConstants.RIPPLE_LIFT, 0))
	anchor.Parent = Workspace
	local ring = Instance.new("CylinderHandleAdornment")
	ring.Adornee = anchor
	-- A handle cylinder's axis is its Z: tip it up so the ring lies flat on the floor.
	ring.CFrame = CFrame.Angles(math.rad(90), 0, 0)
	ring.Height = NoiseConstants.RIPPLE_HEIGHT
	ring.Color3 = NoiseConstants.RIPPLE_COLOR
	ring.AlwaysOnTop = false
	shape(ring, radius, 0)
	ring.Parent = anchor
	table.insert(ripples, { anchor = anchor, ring = ring, radius = radius, started = os.clock() })
	counters.drawn += 1
end

local function step()
	local now = os.clock()
	for index = #ripples, 1, -1 do
		local ripple = ripples[index]
		local alpha = (now - ripple.started) / NoiseConstants.RIPPLE_SECONDS
		if alpha >= 1 then
			ripple.anchor:Destroy()
			table.remove(ripples, index)
		else
			shape(ripple.ring, ripple.radius, alpha)
		end
	end
end

export type NoiseServiceClient = {
	dependencies: { string },
	start: (self: NoiseServiceClient) -> (),
	stop: (self: NoiseServiceClient) -> (),
	getState: (self: NoiseServiceClient) -> { [string]: any },
}

local NoiseServiceClient: NoiseServiceClient = {
	dependencies = {},

	start = function(_self)
		table.insert(
			stoppers,
			NoiseEvents.packets.Ripple.listen(function(data)
				draw(data.position, data.radius)
			end)
		)
		local connection = RunService.RenderStepped:Connect(function(_deltaTime: number)
			step()
		end)
		table.insert(stoppers, function()
			connection:Disconnect()
		end)
	end,

	stop = function(_self)
		for _, stop in stoppers do
			stop()
		end
		table.clear(stoppers)
		for _, ripple in ripples do
			ripple.anchor:Destroy()
		end
		table.clear(ripples)
	end,

	getState = function(_self)
		return { live = #ripples, drawn = counters.drawn, skipped = counters.skipped }
	end,
}

return NoiseServiceClient
```

- [ ] **Step 6: Exemption reason.** In `SpecRoots.luau`, change the NoiseServiceClient entry's reason to `"Instance/raycast/RunService shell (the ring's shape is specced in NoiseRippleFormulas)"`.

- [ ] **Step 7: Module map, format and gate** (Global Constraints order). Expected: `==> All checks passed.`

- [ ] **Step 8: Controller: Studio TestEZ.** Expected: NoiseRippleFormulas passes.

- [ ] **Step 9: Controller: Studio verification** (Play Solo, `RunTests = false`; the M2 Task 3 server Script with `_G.N`). Checklist (screenshot 1 and 2):
1. Vacuum a pile: each second a thin pale ring (not a disc) spreads across the floor to about 60 studs across (solo hearing 0.75 × 40 × 2), slowing as it goes and fading out in ~1 s.
2. Drop the water jug: a big ring (~105 studs across at solo hearing); the ring hugs the floor and does not flicker through it.
3. `_G.N:emit(workspace.CleanupCrewOffice:GetPivot().Position + Vector3.new(400, 0, 0), 10, "test")` (far away): no ring, `skipped` +1 (`require(game.ReplicatedStorage.Client.Features.Noise.NoiseServiceClient):getState()` from a client LocalScript).
4. `live` returns to 0 a second after the last noise; no errors in Output.

- [ ] **Step 10: Commit**

```bash
git commit -m "feat(noise): faint ripple ring that spreads to the heard radius"
python3 scripts/python/module_map.py --check
```

---
### Task 5: Cargo feel (banking swoop, cha-ching and floaters; drop, rattle and search sounds; the plant's leaves)

**Files:**
- Create: `src/ReplicatedStorage/Shared/Features/Cargo/Data/CargoAssets.luau`
- Create: `src/ReplicatedStorage/Shared/Features/Cargo/Utils/CargoFeedbackUtils.luau` (+ `CargoFeedbackUtils.spec.luau`)
- Create: `src/ReplicatedStorage/Client/Features/Cargo/Systems/CargoFeedbackSystem.luau`
- Modify: `src/ReplicatedStorage/Shared/Features/Cargo/Data/CargoConstants.luau`
- Modify: `src/ReplicatedStorage/Shared/Features/Cargo/Data/CargoTypes.luau`
- Modify: `src/ReplicatedStorage/Shared/Features/Cargo/Net/CargoEvents.luau`
- Modify: `src/ServerScriptService/Features/Cargo/CargoServiceServer.luau`
- Modify: `src/ServerScriptService/Features/Shift/ShiftServiceServer.luau` (`onBanked`)
- Modify: `src/ReplicatedStorage/Client/Features/Cargo/CargoServiceClient.luau`
- Modify: `src/ServerScriptService/Core/Testing/SpecRoots.luau`

**Interfaces:**
- Consumes: M1/M2 Cargo: `CargoServiceServer`'s locals `noiseMade`, `claims`, `entryOf`, `idOf`, `rootOf`, `onDropped` (fires `noiseMade` with `"drop"` for every impact), `load` (`pcall(handler, player, deposit)` then claim/destroy), the trait system's `"rattle"` and the search's `"search"` noises on `noiseMade`; `CargoTypes.Deposit = { clearance, bonus, items: { { kind, category, value } } }`; M2's Shift `onBanked` (`multiplier = ShiftPhaseRules.salvageMultiplier(state)`, `bonus = math.floor(deposit.bonus * multiplier + 0.5)`, a "Loaded: …" toast); base `SoundServiceServer:playAt(position, id, radius?)` (refuses an unregistered id silently); `CarryConstants.PUBLIC_FIELD = "carrying"`; `CargoConstants.PUBLIC_POCKET_FIELDS`; `CargoRegistry.get(kind)` (`partSize`, `color`, `blocksView`, `splashes`, `fragile`, `size`).
- Produces (CargoTypes): `BankHandler = (player: Player, deposit: Deposit) -> (boolean, number?)` (the second value is the bonus actually credited, after any overtime multiplier; absent = `deposit.bonus`).
- Produces (CargoEvents): `packets.Banked` (server → all) `{ kinds: { string }, from: Vector3, to: Vector3, clearance: number (uint16), bonus: number (uint16) }`.
- Produces (CargoAssets): `PENDING`, `SOUNDS` (`cargoChaChing`, `cargoSwoosh`, `cargoPickup`, `cargoPocket`, `cargoThudLight`, `cargoThudHeavy`, `cargoShatter`, `cargoSplash`, `cargoRattle`, `cargoRummage`).
- Produces (CargoFeedbackUtils): `type Tone = "clearance" | "bonus"`, `type Floater = { text: string, tone: Tone }`; `floaters(clearance: number, bonus: number) -> { Floater }`; `arc(from: Vector3, to: Vector3, alpha: number, height: number) -> Vector3`; `dropSound(def: ItemDef) -> string`; `noiseSound(source: string) -> string?`; `pickedUp(before: string?, after: string?) -> boolean`; `pocketed(before: number, after: number) -> boolean`; `blocksView(kind: string?) -> boolean`.
- Produces (CargoFeedbackSystem, client module-level): `start()`, `stop()`, `getState()`.
- Produces (CargoConstants, new keys): `SOUND_RADIUS = 120`, `SWOOP_SECONDS = 0.55`, `SWOOP_HEIGHT = 6`, `SWOOP_STAGGER = 0.12`, `SWOOP_END_SCALE = 0.35`, `FLOATER_SECONDS = 1.4`, `FLOATER_RISE = 4`, `FLOATER_SPACING = 1.3`, `FLOATER_DISTANCE = 150`, `FLOATER_FONT`, `CLEARANCE_COLOR`, `BONUS_COLOR`, `LEAF_SIZE`, `LEAF_COLORS`, `LEAF_OFFSETS`.

- [ ] **Step 1: Write the failing spec** `src/ReplicatedStorage/Shared/Features/Cargo/Utils/CargoFeedbackUtils.spec.luau`:

```lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CargoFeedbackUtils = require(script.Parent.CargoFeedbackUtils)
local CargoAssets = require(ReplicatedStorage.Shared.Features.Cargo.Data.CargoAssets)
local CargoRegistry = require(ReplicatedStorage.Shared.Features.Cargo.Data.CargoRegistry)

return function()
	describe("floaters", function()
		it("shows clearance as a green +N", function()
			local list = CargoFeedbackUtils.floaters(15, 0)
			expect(#list).to.equal(1)
			expect(list[1].text).to.equal("+15")
			expect(list[1].tone).to.equal("clearance")
		end)

		it("shows clearance first, then the bonus", function()
			local list = CargoFeedbackUtils.floaters(15, 45)
			expect(#list).to.equal(2)
			expect(list[2].text).to.equal("+45")
			expect(list[2].tone).to.equal("bonus")
		end)

		it("omits a zero amount", function()
			local list = CargoFeedbackUtils.floaters(0, 38)
			expect(#list).to.equal(1)
			expect(list[1].tone).to.equal("bonus")
			expect(#CargoFeedbackUtils.floaters(0, 0)).to.equal(0)
		end)

		it("rounds like the review", function()
			expect(CargoFeedbackUtils.floaters(0, 37.5)[1].text).to.equal("+38")
		end)
	end)

	describe("arc", function()
		it("starts at the item and ends in the truck", function()
			local from, to = Vector3.new(0, 0, 0), Vector3.new(10, 0, 0)
			expect((CargoFeedbackUtils.arc(from, to, 0, 6) - from).Magnitude).to.be.near(0, 1e-6)
			expect((CargoFeedbackUtils.arc(from, to, 1, 6) - to).Magnitude).to.be.near(0, 1e-6)
		end)

		it("lifts half the arc height at the middle", function()
			local middle = CargoFeedbackUtils.arc(Vector3.new(0, 0, 0), Vector3.new(10, 0, 0), 0.5, 6)
			expect((middle - Vector3.new(5, 3, 0)).Magnitude).to.be.near(0, 1e-6)
		end)
	end)

	describe("sounds", function()
		it("picks the drop sound by trait, then by weight", function()
			expect(CargoFeedbackUtils.dropSound(CargoRegistry.get("waterJug"))).to.equal("cargoSplash")
			expect(CargoFeedbackUtils.dropSound(CargoRegistry.get("monitor"))).to.equal("cargoShatter")
			expect(CargoFeedbackUtils.dropSound(CargoRegistry.get("printer"))).to.equal("cargoThudHeavy")
			expect(CargoFeedbackUtils.dropSound(CargoRegistry.get("filingCabinet"))).to.equal("cargoThudHeavy")
			expect(CargoFeedbackUtils.dropSound(CargoRegistry.get("rubbishBag"))).to.equal("cargoThudLight")
		end)

		it("gives rattle and search noises their sounds, and nothing else", function()
			expect(CargoFeedbackUtils.noiseSound("rattle")).to.equal("cargoRattle")
			expect(CargoFeedbackUtils.noiseSound("search")).to.equal("cargoRummage")
			expect(CargoFeedbackUtils.noiseSound("drop")).to.equal(nil)
			expect(CargoFeedbackUtils.noiseSound("vacuum")).to.equal(nil)
		end)

		it("only names sounds CargoAssets declares", function()
			for _, kind in CargoRegistry.ids() do
				expect(CargoAssets.SOUNDS[CargoFeedbackUtils.dropSound(CargoRegistry.get(kind))]).to.be.ok()
			end
			expect(CargoAssets.SOUNDS[CargoFeedbackUtils.noiseSound("rattle")]).to.be.ok()
			expect(CargoAssets.SOUNDS[CargoFeedbackUtils.noiseSound("search")]).to.be.ok()
			for _, id in { "cargoChaChing", "cargoSwoosh", "cargoPickup", "cargoPocket" } do
				expect(CargoAssets.SOUNDS[id]).to.be.ok()
			end
		end)
	end)

	describe("hands and pockets", function()
		it("cues a pickup when something new comes into the hands", function()
			expect(CargoFeedbackUtils.pickedUp(nil, "monitor")).to.equal(true)
			expect(CargoFeedbackUtils.pickedUp("plaque", "monitor")).to.equal(true)
			expect(CargoFeedbackUtils.pickedUp("monitor", "monitor")).to.equal(false)
			expect(CargoFeedbackUtils.pickedUp("monitor", nil)).to.equal(false)
		end)

		it("cues a pocket when a pocket fills", function()
			expect(CargoFeedbackUtils.pocketed(0, 1)).to.equal(true)
			expect(CargoFeedbackUtils.pocketed(1, 1)).to.equal(false)
			expect(CargoFeedbackUtils.pocketed(2, 0)).to.equal(false)
		end)

		it("hides the view only behind the office plant", function()
			expect(CargoFeedbackUtils.blocksView("officePlant")).to.equal(true)
			expect(CargoFeedbackUtils.blocksView("monitor")).to.equal(false)
			expect(CargoFeedbackUtils.blocksView(nil)).to.equal(false)
			expect(CargoFeedbackUtils.blocksView("no-such-item")).to.equal(false)
		end)
	end)
end
```

- [ ] **Step 2: Controller: Studio TestEZ.** Expected: the spec errors (modules missing).

- [ ] **Step 3: Assets** `src/ReplicatedStorage/Shared/Features/Cargo/Data/CargoAssets.luau`:

```lua
--!strict
--[=[
	CargoAssets: every asset id the Cargo feature uses (Cleanup Crew spec §7: "Asset id literals live only in each
	feature's Data/<Feature>Assets"). An id is PENDING ("") until the developer uploads the staged file (the M3
	plan's "Asset staging" appendix); a pending sound is never registered, so playing it is silent (the server's
	SoundServiceServer:playAt and every client caller check SoundRegistry.has). Registers the uploaded sounds at
	load on whichever realm requires this first (guarded): the server plays the drop, rattle and search sounds,
	the client the rest.

	Static data + registration (spec-exempt).

	@class CargoAssets
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SoundRegistry = require(ReplicatedStorage.Shared.Features.Sound.Data.SoundRegistry)
local SoundTypes = require(ReplicatedStorage.Shared.Features.Sound.Data.SoundTypes)

local PENDING = ""

local SOUNDS: { [string]: SoundTypes.SoundDef } = {
	-- Banking: the item whooshing into the truck, then a cash-register "cha-ching" at the bed.
	cargoSwoosh = { assetId = PENDING, group = "SFX", volume = 0.6, rollOffMaxDistance = 60 },
	cargoChaChing = { assetId = PENDING, group = "SFX", volume = 0.9, rollOffMaxDistance = 80 },
	-- Your own hands and pockets.
	cargoPickup = { assetId = PENDING, group = "SFX", volume = 0.5 },
	cargoPocket = { assetId = PENDING, group = "UI", volume = 0.6 },
	-- Drops, by trait then weight (CargoFeedbackUtils.dropSound); heard by everyone near.
	cargoThudLight = { assetId = PENDING, group = "SFX", volume = 0.7, pitch = { min = 0.9, max = 1.1 }, rollOffMaxDistance = 70, maxConcurrent = 4 },
	cargoThudHeavy = { assetId = PENDING, group = "SFX", volume = 1, pitch = { min = 0.9, max = 1.05 }, rollOffMaxDistance = 90, maxConcurrent = 3 },
	cargoShatter = { assetId = PENDING, group = "SFX", volume = 0.9, rollOffMaxDistance = 90, maxConcurrent = 3 },
	cargoSplash = { assetId = PENDING, group = "SFX", volume = 1, rollOffMaxDistance = 120, maxConcurrent = 2 },
	-- A rattly item's pulse while carried, and rummaging through a desk or locker.
	cargoRattle = { assetId = PENDING, group = "SFX", volume = 0.5, pitch = { min = 0.9, max = 1.15 }, rollOffMaxDistance = 40, maxConcurrent = 4 },
	cargoRummage = { assetId = PENDING, group = "SFX", volume = 0.6, rollOffMaxDistance = 40, maxConcurrent = 3 },
}

for id, def in SOUNDS do
	if def.assetId ~= PENDING and not SoundRegistry.has(id) then
		SoundRegistry.register(id, def)
	end
end

return table.freeze({
	PENDING = PENDING,
	SOUNDS = table.freeze(SOUNDS),
})
```

(stylua will wrap the long sound lines; that is fine.)

- [ ] **Step 4: Utils** `src/ReplicatedStorage/Shared/Features/Cargo/Utils/CargoFeedbackUtils.luau`:

```lua
--!strict
--[=[
	CargoFeedbackUtils: Cargo's feel decisions (Cleanup Crew spec §7 "Banking: item swoops into the truck,
	cha-ching, '+15' floater"; §4 drops by weight, fragile, the jug's splash, rattly, search, the office plant's
	leaves). The floater lines for a Load (clearance, then the bonus actually credited; zero omitted; rounded
	like the review), the swoop's arc (a quadratic curve lifted `height` at its control point), which sound a drop
	or a noise makes, and the hands/pocket cues read from the public fields. Pure.

	@class CargoFeedbackUtils
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CargoRegistry = require(ReplicatedStorage.Shared.Features.Cargo.Data.CargoRegistry)
local CargoTypes = require(ReplicatedStorage.Shared.Features.Cargo.Data.CargoTypes)

export type Tone = "clearance" | "bonus"

export type Floater = {
	text: string,
	tone: Tone,
}

local function round(value: number): number
	return math.floor(value + 0.5)
end

local CargoFeedbackUtils = {}

function CargoFeedbackUtils.floaters(clearance: number, bonus: number): { Floater }
	local list: { Floater } = {}
	local cleared = round(clearance)
	local earned = round(bonus)
	if cleared > 0 then
		table.insert(list, { text = `+{cleared}`, tone = "clearance" })
	end
	if earned > 0 then
		table.insert(list, { text = `+{earned}`, tone = "bonus" })
	end
	return list
end

function CargoFeedbackUtils.arc(from: Vector3, to: Vector3, alpha: number, height: number): Vector3
	local t = math.clamp(alpha, 0, 1)
	local control = (from + to) / 2 + Vector3.new(0, height, 0)
	local first = from:Lerp(control, t)
	local second = control:Lerp(to, t)
	return first:Lerp(second, t)
end

function CargoFeedbackUtils.dropSound(def: CargoTypes.ItemDef): string
	if def.splashes then
		return "cargoSplash"
	end
	if def.fragile then
		return "cargoShatter"
	end
	if def.size == "heavy" or def.size == "bulky" then
		return "cargoThudHeavy"
	end
	return "cargoThudLight"
end

function CargoFeedbackUtils.noiseSound(source: string): string?
	if source == "rattle" then
		return "cargoRattle"
	end
	if source == "search" then
		return "cargoRummage"
	end
	return nil
end

function CargoFeedbackUtils.pickedUp(before: string?, after: string?): boolean
	return after ~= nil and after ~= before
end

function CargoFeedbackUtils.pocketed(before: number, after: number): boolean
	return after > before
end

function CargoFeedbackUtils.blocksView(kind: string?): boolean
	if kind == nil then
		return false
	end
	local def = CargoRegistry.get(kind)
	return def ~= nil and def.blocksView
end

return CargoFeedbackUtils
```

- [ ] **Step 5: Constants.** In `src/ReplicatedStorage/Shared/Features/Cargo/Data/CargoConstants.luau`:
  - After `local PUBLIC_POCKET_FIELDS ...`, add:

```lua
-- The office plant's leaves in front of the camera while you carry it (spec §4: "leaves partly block your
-- view"): camera-space offsets (x right, y up, -z forward), a few greens, one thin leaf size.
local LEAF_OFFSETS: { CFrame } = {
	CFrame.new(-0.9, -0.55, -1.6) * CFrame.Angles(math.rad(70), 0, math.rad(30)),
	CFrame.new(0.95, -0.6, -1.7) * CFrame.Angles(math.rad(75), 0, math.rad(-35)),
	CFrame.new(-0.55, -0.75, -1.5) * CFrame.Angles(math.rad(60), 0, math.rad(10)),
	CFrame.new(0.5, -0.8, -1.55) * CFrame.Angles(math.rad(65), 0, math.rad(-15)),
	CFrame.new(0.05, -0.7, -1.8) * CFrame.Angles(math.rad(80), 0, 0),
}
local LEAF_COLORS: { Color3 } = {
	Color3.fromRGB(46, 120, 52),
	Color3.fromRGB(62, 145, 66),
	Color3.fromRGB(38, 100, 44),
}
```
  - In the returned table, after `FLOOR_PROBE = 20,`, add:

```lua
	-- Feel (spec §7 "Banking: item swoops into the truck, cha-ching, '+15' floater"). Positional Cargo sounds the
	-- server plays reach this far.
	SOUND_RADIUS = 120,
	-- The swoop: seconds along the arc, its lift, the gap between several items, and how small it ends.
	SWOOP_SECONDS = 0.55,
	SWOOP_HEIGHT = 6,
	SWOOP_STAGGER = 0.12,
	SWOOP_END_SCALE = 0.35,
	-- The "+N" floaters: life, rise, spacing between two, draw distance, look.
	FLOATER_SECONDS = 1.4,
	FLOATER_RISE = 4,
	FLOATER_SPACING = 1.3,
	FLOATER_DISTANCE = 150,
	FLOATER_FONT = Enum.Font.Oswald,
	CLEARANCE_COLOR = Color3.fromRGB(110, 210, 120),
	BONUS_COLOR = Color3.fromRGB(100, 175, 255),
	LEAF_SIZE = Vector3.new(1.4, 0.05, 0.7),
	LEAF_COLORS = table.freeze(LEAF_COLORS),
	LEAF_OFFSETS = table.freeze(LEAF_OFFSETS),
```

- [ ] **Step 6: Types and packet.**
  - In `src/ReplicatedStorage/Shared/Features/Cargo/Data/CargoTypes.luau`, replace the `BankHandler` comment and type with:

```lua
-- The game's banking callback (Shift): adds the deposit and returns true plus the bonus it actually credited
-- (after any overtime multiplier; absent = deposit.bonus), or false to refuse it (no shift running). It must not
-- yield: claim, add and destroy run as one step.
export type BankHandler = (player: Player, deposit: Deposit) -> (boolean, number?)
```
  - In `src/ReplicatedStorage/Shared/Features/Cargo/Net/CargoEvents.luau`, in `packets`, after `Pocket` (and M2's `Swap`), add:

```lua
			-- Server → all: a Load landed (spec §7 "item swoops into the truck, cha-ching, '+15' floater"). The
			-- kinds loaded, where the swoop starts (the hands item, or the player), the bed's top, and the amounts
			-- credited (clearance, then the bonus after any overtime multiplier).
			Banked = ByteNet.definePacket({
				value = ByteNet.struct({
					kinds = ByteNet.array(ByteNet.string),
					from = ByteNet.vec3,
					to = ByteNet.vec3,
					clearance = ByteNet.uint16,
					bonus = ByteNet.uint16,
				}),
				reliabilityType = "reliable",
			}),
```
  and change the header's first line to "CargoEvents: Cargo's ByteNet packets: requests (client → server; the server decides everything) and one announcement (`Banked`, server → all)."

- [ ] **Step 7: Server.** In `src/ServerScriptService/Features/Cargo/CargoServiceServer.luau`:
  1. Requires (beside the other Cargo shared requires, through `CargoShared`): `local CargoAssets = require(CargoShared.Data.CargoAssets)` (requiring it registers the server-side sounds; `soundAt` below also reads it), `local CargoFeedbackUtils = require(CargoShared.Utils.CargoFeedbackUtils)`; and `local SoundRegistry = require(ReplicatedStorage.Shared.Features.Sound.Data.SoundRegistry)`, `local SoundServiceServer = require(ServerScriptService.Features.Sound.SoundServiceServer)`.
  2. After `ignoreList`, add:

```lua
-- A Cargo sound at a spot, for everyone near it; silent while its id is pending (CargoAssets).
local function soundAt(position: Vector3, id: string)
	if CargoAssets.SOUNDS[id] ~= nil and SoundRegistry.has(id) then
		SoundServiceServer:playAt(position, id, CargoConstants.SOUND_RADIUS)
	end
end
```
  3. In `onDropped`, right after `noiseMade:Fire(position, CargoHandlingRules.dropNoise(def), "drop")`, add `soundAt(position, CargoFeedbackUtils.dropSound(def))`.
  4. In `start`, after `local dropped = CarryServiceServer.dropped:Connect(onDropped)`, add:

```lua
		-- Rattles and searches are heard as sounds too (drops play theirs in onDropped, which knows the item).
		local noises = noiseMade:Connect(function(position: Vector3, _radius: number, source: string)
			local id = CargoFeedbackUtils.noiseSound(source)
			if id ~= nil then
				soundAt(position, id)
			end
		end)
```
  and `noises:Disconnect()` in the same stopper function as `dropped:Disconnect()`.
  5. In `load`:
     - after the line that reads the hands entry's `id` (`local id = if item ~= nil then idOf(item) else nil`), add:
```lua
		-- Where the swoop starts: the hands item, or the player (a pockets-only Load).
		local from = if item ~= nil and item:IsA("BasePart") then item.Position else root.Position
```
     - replace `local ok, accepted = pcall(handler, player, deposit)` with `local ok, accepted, credited = pcall(handler, player, deposit)`;
     - immediately before `counters.banked += 1`, add:
```lua
		local kinds: { string } = {}
		for _, deposited in deposit.items do
			table.insert(kinds, deposited.kind)
		end
		CargoEvents.packets.Banked.sendToAll({
			kinds = kinds,
			from = from,
			to = bed.Position + Vector3.new(0, bed.Size.Y / 2, 0),
			clearance = math.clamp(math.floor(deposit.clearance + 0.5), 0, 65535),
			bonus = math.clamp(math.floor((if type(credited) == "number" then credited else deposit.bonus) + 0.5), 0, 65535),
		})
```
  6. Add `"SoundServiceServer"` to `dependencies`.
  7. Header comment: add a bullet `- Feel (M3): every Load is announced (\`Banked\`: the client swoops the items into the truck, cha-chings and floats "+N"); drops, rattles and searches play positional sounds (CargoFeedbackUtils, CargoAssets; silent while pending).`
  8. Check `python3 scripts/python/check_file_length.py` keeps this file ≤ 400 code lines. If it does not, move `soundAt` and the `noiseMade` listener into the existing `CargoTraitSystem` (M2) behind a `sounds: (position: Vector3, id: string) -> ()` dep, and report it.

  If luau-lsp does not narrow `root` to `BasePart` at the `from` line (it is checked by `if root == nil or not CargoBankRules.onBed(...) then return ... end` above), move the `from` line to just after that guard; no cast.

- [ ] **Step 8: Shift returns the credited bonus.** In `src/ServerScriptService/Features/Shift/ShiftServiceServer.luau`, in `onBanked` (M2's version):
  - Signature: `local function onBanked(player: Player, deposit: CargoTypes.Deposit): (boolean, number?)`.
  - `return false` (not running) → `return false, nil`.
  - Delete the two statements that build and send the "Loaded: …" toast (`local overtime = if multiplier > 1 then …` and the `ToastServiceServer:send(player, { text = \`Loaded: …\`, duration = 2 })` call): the floater replaces them.
  - The final `return true` → `return true, bonus`.
  - Comment above it: replace "(claim → add → destroy happens around it)" with "(claim → add → destroy happens around it); returns the bonus credited, which Cargo's Banked floater shows".

- [ ] **Step 9: Client system** `src/ReplicatedStorage/Client/Features/Cargo/Systems/CargoFeedbackSystem.luau`:

```lua
--!strict
--[=[
	CargoFeedbackSystem: how cargo feels on this client (Cleanup Crew spec §7 "Banking: item swoops into the
	truck, cha-ching, '+15' floater, clearance bar fills"; §4 "Office plant: leaves partly block your view").
	- `Banked` (server → all): a ghost of each loaded item swoops on an arc into the truck bed, shrinking and
	  spinning (CargoFeedbackUtils.arc); when the last lands, a cha-ching at the bed and a rising "+N" per amount
	  (clearance green, bonus blue; CargoFeedbackUtils.floaters). The clearance bar is the HUD's.
	- Your public fields: a pickup sound when something new comes into your hands, a pocket sound when a pocket
	  fills, and plant leaves in front of your camera while your hands hold a blocksView item.
	Drop, rattle and search sounds are the server's (CargoServiceServer). Client-local instances; pending sounds
	(CargoAssets) are skipped silently and counted.

	Spec-exempt shell (Instances, tweens, RunService, ByteNet, Charm); the choices and the arc are the specced
	CargoFeedbackUtils.

	@class CargoFeedbackSystem
]=]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local CargoShared = ReplicatedStorage.Shared.Features.Cargo
local Charm = require(ReplicatedStorage.Packages.Charm)
local Logger = require(ReplicatedStorage.Shared.Core.Logger)
local PublicPlayerTypes = require(ReplicatedStorage.Shared.Data.PublicPlayerTypes)
local CargoAssets = require(CargoShared.Data.CargoAssets)
local CargoConstants = require(CargoShared.Data.CargoConstants)
local CargoRegistry = require(CargoShared.Data.CargoRegistry)
local CargoEvents = require(CargoShared.Net.CargoEvents)
local CargoFeedbackUtils = require(CargoShared.Utils.CargoFeedbackUtils)
local CarryConstants = require(ReplicatedStorage.Shared.Features.Carry.Data.CarryConstants)
local SoundRegistry = require(ReplicatedStorage.Shared.Features.Sound.Data.SoundRegistry)
local SoundTypes = require(ReplicatedStorage.Shared.Features.Sound.Data.SoundTypes)
local StateSyncConstants = require(ReplicatedStorage.Shared.Features.StateSync.Data.StateSyncConstants)
local SoundServiceClient = require(ReplicatedStorage.Client.Features.Sound.SoundServiceClient)
local StateSyncClientStore = require(ReplicatedStorage.Client.Features.StateSync.State.StateSyncClientStore)

type Swoop = {
	part: BasePart,
	from: Vector3,
	to: Vector3,
	size: Vector3,
	started: number,
}

local log = Logger.new("CargoFeedbackSystem")

local swoops: { Swoop } = {}
local leaves: { BasePart } = {}
local lastHands: string? = nil
local lastPockets = 0
local counters = { banked = 0, swoops = 0, floaters = 0, pickups = 0, pockets = 0, played = 0, pending = 0 }
local stoppers: { () -> () } = {}

local function play(id: string, options: SoundTypes.PlayOptions?)
	if CargoAssets.SOUNDS[id] == nil then
		log:warn(`"{id}" is not a CargoAssets sound`)
		return
	end
	if not SoundRegistry.has(id) then
		counters.pending += 1
		return
	end
	counters.played += 1
	SoundServiceClient:play(id, options)
end

local function floater(at: Vector3, index: number, item: CargoFeedbackUtils.Floater)
	local anchor = Instance.new("Attachment")
	anchor.Name = "CargoFloater"
	anchor.Parent = Workspace.Terrain
	anchor.WorldPosition = at + Vector3.new(0, 1 + index * CargoConstants.FLOATER_SPACING, 0)
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(140, 48)
	gui.AlwaysOnTop = true
	gui.LightInfluence = 0
	gui.MaxDistance = CargoConstants.FLOATER_DISTANCE
	gui.Adornee = anchor
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = CargoConstants.FLOATER_FONT
	label.TextScaled = true
	label.Text = item.text
	label.TextColor3 = if item.tone == "bonus" then CargoConstants.BONUS_COLOR else CargoConstants.CLEARANCE_COLOR
	label.TextStrokeTransparency = 0.2
	label.Parent = gui
	gui.Parent = anchor
	local info = TweenInfo.new(CargoConstants.FLOATER_SECONDS, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(gui, info, { StudsOffset = Vector3.new(0, CargoConstants.FLOATER_RISE, 0) }):Play()
	local fade = TweenService:Create(label, info, { TextTransparency = 1, TextStrokeTransparency = 1 })
	fade.Completed:Once(function()
		anchor:Destroy()
	end)
	fade:Play()
	counters.floaters += 1
end

local function swoop(kind: string, from: Vector3, to: Vector3)
	local def = CargoRegistry.get(kind)
	if def == nil then
		return
	end
	local part = Instance.new("Part")
	part.Name = "CargoSwoop"
	part.Size = def.partSize
	part.Color = def.color
	part.Material = Enum.Material.SmoothPlastic
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.CFrame = CFrame.new(from)
	part.Parent = Workspace
	table.insert(swoops, { part = part, from = from, to = to, size = def.partSize, started = os.clock() })
	counters.swoops += 1
end

local function onBanked(data: { kinds: { string }, from: Vector3, to: Vector3, clearance: number, bonus: number })
	counters.banked += 1
	play("cargoSwoosh", { at = data.from })
	for index, kind in data.kinds do
		task.delay((index - 1) * CargoConstants.SWOOP_STAGGER, swoop, kind, data.from, data.to)
	end
	local landing = math.max(0, #data.kinds - 1) * CargoConstants.SWOOP_STAGGER + CargoConstants.SWOOP_SECONDS
	task.delay(landing, function()
		play("cargoChaChing", { at = data.to })
		for index, item in CargoFeedbackUtils.floaters(data.clearance, data.bonus) do
			floater(data.to, index - 1, item)
		end
	end)
end

local function showLeaves(on: boolean)
	if not on then
		for _, leaf in leaves do
			leaf:Destroy()
		end
		table.clear(leaves)
		return
	end
	local camera = Workspace.CurrentCamera
	if #leaves > 0 or camera == nil then
		return
	end
	for index = 1, #CargoConstants.LEAF_OFFSETS do
		local leaf = Instance.new("Part")
		leaf.Name = "CargoLeaf"
		leaf.Size = CargoConstants.LEAF_SIZE
		leaf.Color = CargoConstants.LEAF_COLORS[(index - 1) % #CargoConstants.LEAF_COLORS + 1]
		leaf.Material = Enum.Material.SmoothPlastic
		leaf.Anchored = true
		leaf.CanCollide = false
		leaf.CanQuery = false
		leaf.CanTouch = false
		leaf.CastShadow = false
		-- Parts under the camera exist only on this client.
		leaf.Parent = camera
		table.insert(leaves, leaf)
	end
end

local function step()
	local now = os.clock()
	for index = #swoops, 1, -1 do
		local item = swoops[index]
		local alpha = (now - item.started) / CargoConstants.SWOOP_SECONDS
		if alpha >= 1 then
			item.part:Destroy()
			table.remove(swoops, index)
		else
			local scale = 1 + (CargoConstants.SWOOP_END_SCALE - 1) * alpha
			item.part.Size = item.size * scale
			item.part.CFrame = CFrame.new(CargoFeedbackUtils.arc(item.from, item.to, alpha, CargoConstants.SWOOP_HEIGHT))
				* CFrame.Angles(0, alpha * math.pi * 2, 0)
		end
	end
	local camera = Workspace.CurrentCamera
	if camera ~= nil then
		for index, leaf in leaves do
			local sway = CFrame.Angles(0, 0, math.sin(now * 2 + index) * 0.05)
			leaf.CFrame = camera.CFrame * CargoConstants.LEAF_OFFSETS[index] * sway
		end
	end
end

-- The local player's hands kind and pocket count, from the public fields.
local function readMine(map: PublicPlayerTypes.PublicPlayerMap): (string?, number)
	local me = map[StateSyncConstants.publicEntryKey(Players.LocalPlayer.UserId)]
	if me == nil then
		return nil, 0
	end
	local hands = me[CarryConstants.PUBLIC_FIELD]
	local pockets = 0
	for _, field in CargoConstants.PUBLIC_POCKET_FIELDS do
		if me[field] ~= nil then
			pockets += 1
		end
	end
	return if type(hands) == "string" then hands else nil, pockets
end

local function onPublic(map: PublicPlayerTypes.PublicPlayerMap)
	local hands, pockets = readMine(map)
	if CargoFeedbackUtils.pickedUp(lastHands, hands) then
		counters.pickups += 1
		play("cargoPickup")
	end
	if CargoFeedbackUtils.pocketed(lastPockets, pockets) then
		counters.pockets += 1
		play("cargoPocket")
	end
	showLeaves(CargoFeedbackUtils.blocksView(hands))
	lastHands = hands
	lastPockets = pockets
end

local CargoFeedbackSystem = {}

function CargoFeedbackSystem.start()
	if #stoppers > 0 then
		return
	end
	-- The current fields are the baseline: no pickup sound for what you already hold.
	lastHands, lastPockets = readMine(StateSyncClientStore.publicPlayers())
	showLeaves(CargoFeedbackUtils.blocksView(lastHands))
	table.insert(stoppers, Charm.subscribe(StateSyncClientStore.publicPlayers, onPublic))
	table.insert(stoppers, CargoEvents.packets.Banked.listen(onBanked))
	local connection = RunService.RenderStepped:Connect(function(_deltaTime: number)
		step()
	end)
	table.insert(stoppers, function()
		connection:Disconnect()
	end)
end

function CargoFeedbackSystem.stop()
	for _, stop in stoppers do
		stop()
	end
	table.clear(stoppers)
	for _, item in swoops do
		item.part:Destroy()
	end
	table.clear(swoops)
	showLeaves(false)
	lastHands = nil
	lastPockets = 0
end

function CargoFeedbackSystem.getState(): { [string]: any }
	return { swooping = #swoops, leaves = #leaves, counters = table.clone(counters) }
end

return CargoFeedbackSystem
```

If luau-lsp's inferred type of the `Banked` listener's data does not match the annotated `onBanked` parameter, drop the annotation and let ByteNet's type flow in (`CargoEvents.packets.Banked.listen(function(data) onBanked(data.kinds, data.from, data.to, data.clearance, data.bonus) end)` with `onBanked` taking the five values); no cast. If `ByteNet.array` is not exported under that name by the installed ByteNetMax, check `Packages/_Index/elitriare_bytenet-max@0.2.7/bytenet-max/src/init.luau` for the array constructor's name and use it; report it.

- [ ] **Step 10: Wire it.** In `src/ReplicatedStorage/Client/Features/Cargo/CargoServiceClient.luau`:
  - Require `local CargoFeedbackSystem = require(ReplicatedStorage.Client.Features.Cargo.Systems.CargoFeedbackSystem)` after the `CarryServiceClient` require.
  - Add `"SoundServiceClient", "StateSyncServiceClient"` to `dependencies`.
  - At the end of `start`: `CargoFeedbackSystem.start()`. At the start of `stop`: `CargoFeedbackSystem.stop()`.
  - Header comment: add "CargoFeedbackSystem plays the banking swoop and floaters, the pickup and pocket sounds, and the plant's leaves."

- [ ] **Step 11: Exemptions.** Under `-- Cleanup Crew: Cargo`, add:

```lua
	["ReplicatedStorage.Shared.Features.Cargo.Data.CargoAssets"] = "asset id slots; registers the uploaded sounds at load (no decisions)",
	["ReplicatedStorage.Client.Features.Cargo.Systems.CargoFeedbackSystem"] = "Instance/tween/ByteNet/Charm shell (choices and arc specced in CargoFeedbackUtils)",
```

- [ ] **Step 12: Module map, format and gate** (Global Constraints order). Expected: `==> All checks passed.`

- [ ] **Step 13: Controller: Studio TestEZ, then Studio verification** (Play Solo, `RunTests = false`; Task 1's server Script for `_G.S` / `_G.R`). TestEZ: CargoFeedbackUtils passes; ShiftNoticeUtils and Shift specs still pass. Inject a client LocalScript printing `require(game.ReplicatedStorage.Client.Features.Cargo.Systems.CargoFeedbackSystem).getState()` every second. Checklist (screenshot 1 and 4):
1. Load a rubbish bag: a dark box flies from your hands on an arc into the bed, spinning and shrinking; then a green "+10" rises over the bed and fades. No "Loaded: …" toast any more.
2. Pocket a plaque, empty your hands, Load: the plaque's ghost starts at you (pockets-only Load); a blue "+25"; no green "+0".
3. In overtime (`_G.R:addTeam("clearance", 345)`, Load, wait through the break and warning), Load the plaque again: blue "+38".
4. Pick up the office plant: five green leaves sit at the bottom of your view, swaying slightly; drop it (G): they vanish.
5. `pickups` and `pockets` count your pickups and pockets; a drop of the water jug, the monitor and the printer and a desk search play nothing (pending) and print no warning; `getState` of `SoundServiceServer` (F4 → Services) shows no new `refused` from Cargo.
6. With a test `cargoChaChing` registered on the client and `cargoThudHeavy` on the server (inject one line in each injected script, ids from `search_asset` "cash register" / "heavy thud"): Load = cha-ching at the truck; drop the printer = a thud heard from where it fell.

- [ ] **Step 14: Commit**

```bash
git commit -m "feat(cargo): banking swoop, cha-ching and floaters; drop, rattle and search sounds; plant leaves"
python3 scripts/python/module_map.py --check
```

---
### Task 6: Harlow's presence and voice (footsteps, mutter, heartbeat, cues, chase music, gibberish, typewriter bubble)

**Files:**
- Create: `src/ReplicatedStorage/Shared/Features/Occupant/Data/OccupantAssets.luau`
- Create: `src/ReplicatedStorage/Shared/Features/Occupant/Utils/OccupantFeedbackUtils.luau` (+ `OccupantFeedbackUtils.spec.luau`)
- Create: `src/ReplicatedStorage/Client/Features/Occupant/Systems/OccupantPresenceSystem.luau`
- Modify: `src/ReplicatedStorage/Shared/Features/Occupant/Data/OccupantConstants.luau`
- Modify: `src/ServerScriptService/Features/Occupant/OccupantServiceServer.luau` (`show` picks a line variant)
- Modify: `src/ServerScriptService/Features/Occupant/Systems/OccupantRigSystem.luau` (the bubble's paper look)
- Modify: `src/ReplicatedStorage/Client/Features/Occupant/OccupantServiceClient.luau`
- Modify: `src/ServerScriptService/Core/Testing/SpecRoots.luau`

**Interfaces:**
- Consumes (M2): Harlow's model tagged `OccupantConstants.TAG` with `HumanoidRootPart`, `Head`, the `MODE_ATTRIBUTE` ("patrol" | "investigate" | "chase" | "search" | "rest" | "catch") and `TARGET_ATTRIBUTE` (UserId, 0 = nobody) attributes, and the speech BillboardGui `SPEECH_NAME` under the head with one TextLabel whose `Text` the server sets per line (`OccupantRigSystem.say`); cues from the brain: `spotted` on chase, `curious` on investigate, `giveUp` ("*sigh*") on returning to patrol, `resting`, `caught`; `OccupantTellRules.heartbeat(distance, mode, huntingMe) / period(distance) / lineFor(cue)`; `OccupantConstants.LINES`, `HEARTBEAT_RANGE`; the service's `show(current, nextMind, cue)` and `rng`.
- Produces (OccupantAssets): `PENDING`; `export type AnimationSlot = { assetId: string, looped: boolean, priority: Enum.AnimationPriority, interruption: AnimationTypes.InterruptionClass }`; `SOUNDS` (`harlowFootstep`, `harlowMutter`, `harlowHeartbeat`, `harlowCurious`, `harlowSpotted`, `harlowChase`, `harlowSigh`, `harlowGibberish1..4`, `harlowCatchSting`, `harlowPowerDown`, `harlowGrab`); `GIBBERISH: { string }` (the four clip ids in order); `IMAGES = { grin: string }`; `ANIMATIONS: { [string]: AnimationSlot }` (`harlowWalk`, `harlowRun`, `harlowLook`, `harlowGrab`, `harlowThrow`; used by Task 7).
- Produces (OccupantFeedbackUtils): `type PresenceCue = "curious" | "spotted" | "giveUp" | "chaseStart" | "chaseEnd"`; `pickLine(lines: { string }, roll: number, last: string?) -> string?`; `clipFor(line: string, count: number) -> number?`; `voiced(line: string) -> boolean`; `reveal(total: number, elapsed: number, rate: number) -> number`; `cues(beforeMode: string?, afterMode: string?, wasMine: boolean, isMine: boolean) -> { PresenceCue }`; `footstepInterval(speed: number) -> number?`.
- Produces (OccupantConstants, new keys): `LINE_VARIANTS: { [string]: { string } }`, `SPEECH_FONT`, `SPEECH_PAPER`, `SPEECH_INK`, `SPEECH_BORDER`, `TYPE_RATE = 28`, `STRIDE = 4.5`, `STEP_MIN_SPEED = 2`, `STEP_MIN = 0.28`, `STEP_MAX = 0.8`.
- Produces (OccupantPresenceSystem, client module-level): `start()`, `stop()`, `getState()`.

- [ ] **Step 1: Write the failing spec** `src/ReplicatedStorage/Shared/Features/Occupant/Utils/OccupantFeedbackUtils.spec.luau`:

```lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local OccupantFeedbackUtils = require(script.Parent.OccupantFeedbackUtils)
local OccupantConstants = require(ReplicatedStorage.Shared.Features.Occupant.Data.OccupantConstants)

local function has(list, value)
	return table.find(list, value) ~= nil
end

return function()
	describe("pickLine", function()
		local lines = { "Those are COMPANY ASSETS.", "Put that BACK.", "This is THEFT." }

		it("picks by the roll", function()
			expect(OccupantFeedbackUtils.pickLine(lines, 0, nil)).to.equal(lines[1])
			expect(OccupantFeedbackUtils.pickLine(lines, 0.999, nil)).to.equal(lines[3])
		end)

		it("never repeats the last line when there is a choice", function()
			for roll = 0, 0.99, 0.11 do
				expect(OccupantFeedbackUtils.pickLine(lines, roll, "Put that BACK.")).never.to.equal("Put that BACK.")
			end
		end)

		it("repeats a lone line, and has nothing for no lines", function()
			expect(OccupantFeedbackUtils.pickLine({ "You're FIRED!" }, 0.5, "You're FIRED!")).to.equal("You're FIRED!")
			expect(OccupantFeedbackUtils.pickLine({}, 0.5, nil)).to.equal(nil)
		end)

		it("keeps the spec's three lines in his mouth", function()
			expect(has(OccupantConstants.LINE_VARIANTS.spotted, "Those are COMPANY ASSETS.")).to.equal(true)
			expect(has(OccupantConstants.LINE_VARIANTS.curious, "Per my last email…")).to.equal(true)
			expect(has(OccupantConstants.LINE_VARIANTS.caught, "You're FIRED!")).to.equal(true)
		end)
	end)

	describe("clipFor", function()
		it("gives a line the same clip every time, within range", function()
			local first = OccupantFeedbackUtils.clipFor("Per my last email…", 4)
			expect(first >= 1 and first <= 4).to.equal(true)
			expect(OccupantFeedbackUtils.clipFor("Per my last email…", 4)).to.equal(first)
		end)

		it("spreads different lines over the clips", function()
			local seen = {}
			for _, set in OccupantConstants.LINE_VARIANTS do
				for _, line in set do
					seen[OccupantFeedbackUtils.clipFor(line, 4)] = true
				end
			end
			local distinct = 0
			for _ in seen do
				distinct += 1
			end
			expect(distinct >= 2).to.equal(true)
		end)

		it("has no clip when none is uploaded", function()
			expect(OccupantFeedbackUtils.clipFor("You're FIRED!", 0)).to.equal(nil)
		end)
	end)

	describe("voiced", function()
		it("speaks words but not *actions*", function()
			expect(OccupantFeedbackUtils.voiced("You're FIRED!")).to.equal(true)
			expect(OccupantFeedbackUtils.voiced("*sigh*")).to.equal(false)
			expect(OccupantFeedbackUtils.voiced("")).to.equal(false)
		end)
	end)

	describe("reveal", function()
		it("types the line out at the rate, then shows it all", function()
			expect(OccupantFeedbackUtils.reveal(20, 0, 28)).to.equal(0)
			expect(OccupantFeedbackUtils.reveal(20, 0.5, 28)).to.equal(14)
			expect(OccupantFeedbackUtils.reveal(20, 5, 28)).to.equal(20)
			expect(OccupantFeedbackUtils.reveal(20, 1, 0)).to.equal(20)
		end)
	end)

	describe("cues", function()
		it("hums when he starts to investigate", function()
			local list = OccupantFeedbackUtils.cues("patrol", "investigate", false, false)
			expect(#list).to.equal(1)
			expect(list[1]).to.equal("curious")
		end)

		it("stings and starts the chase music when he spots you", function()
			local list = OccupantFeedbackUtils.cues("patrol", "chase", false, true)
			expect(#list).to.equal(2)
			expect(list[1]).to.equal("spotted")
			expect(list[2]).to.equal("chaseStart")
		end)

		it("stings without music when he spots someone else", function()
			local list = OccupantFeedbackUtils.cues("search", "chase", false, false)
			expect(#list).to.equal(1)
			expect(list[1]).to.equal("spotted")
		end)

		it("ends your music when he switches to someone else or loses you", function()
			expect(OccupantFeedbackUtils.cues("chase", "chase", true, false)[1]).to.equal("chaseEnd")
			local lost = OccupantFeedbackUtils.cues("chase", "search", true, false)
			expect(#lost).to.equal(1)
			expect(lost[1]).to.equal("chaseEnd")
		end)

		it("sighs when he gives up, and only then", function()
			expect(OccupantFeedbackUtils.cues("search", "patrol", false, false)[1]).to.equal("giveUp")
			expect(OccupantFeedbackUtils.cues("investigate", "patrol", false, false)[1]).to.equal("giveUp")
			expect(#OccupantFeedbackUtils.cues("rest", "patrol", false, false)).to.equal(0)
			expect(#OccupantFeedbackUtils.cues(nil, "patrol", false, false)).to.equal(0)
		end)
	end)

	describe("footstepInterval", function()
		it("steps faster the faster he walks, within limits", function()
			local patrol = OccupantFeedbackUtils.footstepInterval(10)
			local chase = OccupantFeedbackUtils.footstepInterval(15)
			expect(chase < patrol).to.equal(true)
			expect(patrol).to.be.near(OccupantConstants.STRIDE / 10, 1e-6)
			expect(OccupantFeedbackUtils.footstepInterval(100)).to.equal(OccupantConstants.STEP_MIN)
			expect(OccupantFeedbackUtils.footstepInterval(3)).to.equal(OccupantConstants.STEP_MAX)
		end)

		it("is silent standing still", function()
			expect(OccupantFeedbackUtils.footstepInterval(0)).to.equal(nil)
			expect(OccupantFeedbackUtils.footstepInterval(1)).to.equal(nil)
		end)
	end)
end
```

- [ ] **Step 2: Controller: Studio TestEZ.** Expected: the spec errors (module missing).

- [ ] **Step 3: Constants.** In `src/ReplicatedStorage/Shared/Features/Occupant/Data/OccupantConstants.luau`:
  - After the `LINES` table, add:

```lua
-- His lines per cue (spec §4 "Voice": the speech bubble's line; the spec's three are kept). The server picks one
-- per cue, never the same twice running (OccupantFeedbackUtils.pickLine); LINES stays the fallback.
local LINE_VARIANTS: { [string]: { string } } = {
	spotted = { "Those are COMPANY ASSETS.", "Put that BACK.", "This is THEFT.", "Who authorised this?!" },
	curious = { "Per my last email…", "Who's there? Accounting?", "I heard that.", "Is someone in my office?" },
	caught = { "You're FIRED!" },
	giveUp = { "*sigh*" },
	resting = { "Fifteen minutes. Union rules.", "Don't touch my stapler.", "Coffee. Then performance reviews." },
}
```
  - In the returned table, after `LINES = table.freeze(LINES),`, add:

```lua
	LINE_VARIANTS = table.freeze(LINE_VARIANTS),
	-- His speech bubble as a memo (spec §7 "typewriter type"): paper, ink, a thin border; the client types each
	-- line out at TYPE_RATE characters a second.
	SPEECH_FONT = Enum.Font.SpecialElite,
	SPEECH_PAPER = Color3.fromRGB(248, 243, 226),
	SPEECH_INK = Color3.fromRGB(34, 30, 26),
	SPEECH_BORDER = Color3.fromRGB(70, 60, 46),
	TYPE_RATE = 28,
	-- Footsteps: one per STRIDE studs walked, clamped to STEP_MIN..STEP_MAX seconds; none below STEP_MIN_SPEED.
	STRIDE = 4.5,
	STEP_MIN_SPEED = 2,
	STEP_MIN = 0.28,
	STEP_MAX = 0.8,
```

- [ ] **Step 4: Utils** `src/ReplicatedStorage/Shared/Features/Occupant/Utils/OccupantFeedbackUtils.luau`:

```lua
--!strict
--[=[
	OccupantFeedbackUtils: the decisions behind Mr. Harlow's voice and presence (Cleanup Crew spec §4 "Tells" and
	"Voice"). Which line he says for a cue (never the same twice running), which gibberish clip voices a line
	(a stable hash, so a line always sounds the same), whether a line is spoken at all ("*sigh*" is an action),
	how much of a line the typewriter shows, which sounds his mode changes make for this client (a "hm?" when he
	investigates, a sting when he spots someone, the chase music while he chases you, a sigh when he gives up),
	and how often his footsteps fall. Pure.

	@class OccupantFeedbackUtils
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local OccupantConstants = require(ReplicatedStorage.Shared.Features.Occupant.Data.OccupantConstants)

export type PresenceCue = "curious" | "spotted" | "giveUp" | "chaseStart" | "chaseEnd"

local OccupantFeedbackUtils = {}

--[=[
	A line from `lines` by `roll` (0..1), skipping `last` when there is another; nil for no lines.
]=]
function OccupantFeedbackUtils.pickLine(lines: { string }, roll: number, last: string?): string?
	if #lines == 0 then
		return nil
	end
	local pool: { string } = {}
	for _, line in lines do
		if line ~= last then
			table.insert(pool, line)
		end
	end
	if #pool == 0 then
		pool = lines
	end
	local index = math.clamp(math.floor(math.clamp(roll, 0, 1) * #pool) + 1, 1, #pool)
	return pool[index]
end

--[=[
	Which of `count` gibberish clips voices `line` (1..count, the same every time); nil when count < 1.
]=]
function OccupantFeedbackUtils.clipFor(line: string, count: number): number?
	if count < 1 then
		return nil
	end
	local hash = 0
	for index = 1, #line do
		hash = (hash * 31 + string.byte(line, index)) % 1000003
	end
	return hash % count + 1
end

--[=[
	Whether a line is spoken: words are, an *action* in asterisks is not, nor an empty bubble.
]=]
function OccupantFeedbackUtils.voiced(line: string): boolean
	if line == "" then
		return false
	end
	return not (string.sub(line, 1, 1) == "*" and string.sub(line, -1) == "*")
end

--[=[
	How many of a line's `total` characters the typewriter shows `elapsed` seconds in at `rate` per second.
]=]
function OccupantFeedbackUtils.reveal(total: number, elapsed: number, rate: number): number
	if rate <= 0 then
		return total
	end
	return math.clamp(math.floor(elapsed * rate), 0, total)
end

--[=[
	The sounds one change of his mode makes for this client. `wasMine` / `isMine`: he was / is chasing you.
]=]
function OccupantFeedbackUtils.cues(
	beforeMode: string?,
	afterMode: string?,
	wasMine: boolean,
	isMine: boolean
): { PresenceCue }
	local list: { PresenceCue } = {}
	if afterMode ~= beforeMode then
		if afterMode == "investigate" then
			table.insert(list, "curious")
		elseif afterMode == "chase" then
			table.insert(list, "spotted")
		elseif afterMode == "patrol" and (beforeMode == "search" or beforeMode == "investigate") then
			table.insert(list, "giveUp")
		end
	end
	if isMine and not wasMine then
		table.insert(list, "chaseStart")
	elseif wasMine and not isMine then
		table.insert(list, "chaseEnd")
	end
	return list
end

--[=[
	Seconds between his footsteps at `speed` (studs/s); nil when he is (nearly) standing still.
]=]
function OccupantFeedbackUtils.footstepInterval(speed: number): number?
	if speed < OccupantConstants.STEP_MIN_SPEED then
		return nil
	end
	return math.clamp(OccupantConstants.STRIDE / speed, OccupantConstants.STEP_MIN, OccupantConstants.STEP_MAX)
end

return OccupantFeedbackUtils
```

If luau-lsp widens the string literals inside `table.insert(list, "...")`, use a typed local (`local cue: PresenceCue = "..."`); no cast.

- [ ] **Step 5: Assets** `src/ReplicatedStorage/Shared/Features/Occupant/Data/OccupantAssets.luau`:

```lua
--!strict
--[=[
	OccupantAssets: every asset id Mr. Harlow uses (Cleanup Crew spec §7: "Asset id literals live only in each
	feature's Data/<Feature>Assets"): his sounds, his grin image, and his animation slots ("lurch walk,
	look-around, grab and throw", from Kimodo/MoMask). An id is PENDING ("") until the developer uploads the
	staged file (the M3 plan's "Asset staging" appendix). A pending sound is never registered (silent); a pending
	grin falls back to a grin built from frames (OccupantScareSystem); a pending animation is left out of the
	`occupant` animation domain, so he keeps the base clips (OccupantAnimationUtils). Registers the uploaded sounds
	at load on whichever realm requires this first (guarded).

	Static data + registration (spec-exempt).

	@class OccupantAssets
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AnimationTypes = require(ReplicatedStorage.Shared.Features.Animation.Data.AnimationTypes)
local SoundRegistry = require(ReplicatedStorage.Shared.Features.Sound.Data.SoundRegistry)
local SoundTypes = require(ReplicatedStorage.Shared.Features.Sound.Data.SoundTypes)

export type AnimationSlot = {
	assetId: string,
	looped: boolean,
	priority: Enum.AnimationPriority,
	interruption: AnimationTypes.InterruptionClass,
}

local PENDING = ""

local SOUNDS: { [string]: SoundTypes.SoundDef } = {
	-- His heavy, uneven step (one per stride, positional, through walls).
	harlowFootstep = { assetId = PENDING, group = "SFX", volume = 0.7, pitch = { min = 0.9, max = 1.05 }, rollOffMaxDistance = 70, maxConcurrent = 2 },
	-- Low muttering under his breath (looped on his head).
	harlowMutter = { assetId = PENDING, group = "SFX", volume = 0.35, looped = true, rollOffMaxDistance = 55 },
	-- Your heartbeat while he is near and has not seen you (2D).
	harlowHeartbeat = { assetId = PENDING, group = "SFX", volume = 0.8 },
	-- A suspicious "hm?" when he goes to investigate.
	harlowCurious = { assetId = PENDING, group = "SFX", volume = 0.8, rollOffMaxDistance = 80 },
	-- The "!" sting (2D for the one he spotted, positional for everyone else).
	harlowSpotted = { assetId = PENDING, group = "SFX", volume = 1, rollOffMaxDistance = 90 },
	-- Chase music for the chased player (looped).
	harlowChase = { assetId = PENDING, group = "Music", volume = 0.6, looped = true },
	harlowSigh = { assetId = PENDING, group = "SFX", volume = 0.8, rollOffMaxDistance = 80 },
	-- Pitched, distorted office gibberish (Stable Audio), one clip per line (OccupantFeedbackUtils.clipFor).
	harlowGibberish1 = { assetId = PENDING, group = "SFX", volume = 0.9, pitch = { min = 0.92, max = 1.12 }, rollOffMaxDistance = 90 },
	harlowGibberish2 = { assetId = PENDING, group = "SFX", volume = 0.9, pitch = { min = 0.92, max = 1.12 }, rollOffMaxDistance = 90 },
	harlowGibberish3 = { assetId = PENDING, group = "SFX", volume = 0.9, pitch = { min = 0.92, max = 1.12 }, rollOffMaxDistance = 90 },
	harlowGibberish4 = { assetId = PENDING, group = "SFX", volume = 0.9, pitch = { min = 0.92, max = 1.12 }, rollOffMaxDistance = 90 },
	-- The catch: a distorted sting for the caught player, the lights' power-down and his grab for everyone near.
	harlowCatchSting = { assetId = PENDING, group = "SFX", volume = 1 },
	harlowPowerDown = { assetId = PENDING, group = "SFX", volume = 0.9, rollOffMaxDistance = 90 },
	harlowGrab = { assetId = PENDING, group = "SFX", volume = 0.9, rollOffMaxDistance = 60 },
}

local GIBBERISH: { string } = { "harlowGibberish1", "harlowGibberish2", "harlowGibberish3", "harlowGibberish4" }

-- The stretched grin shown over his face for the catch (Flux; transparent PNG).
local IMAGES: { grin: string } = {
	grin = PENDING,
}

local ANIMATIONS: { [string]: AnimationSlot } = {
	-- Lurch walk (patrol), and a run if one is made (else the base run).
	harlowWalk = { assetId = PENDING, looped = true, priority = Enum.AnimationPriority.Movement, interruption = "ambient" },
	harlowRun = { assetId = PENDING, looped = true, priority = Enum.AnimationPriority.Movement, interruption = "ambient" },
	-- Look-around: his standing clip (investigating, searching, on break, over a catch).
	harlowLook = { assetId = PENDING, looped = true, priority = Enum.AnimationPriority.Idle, interruption = "ambient" },
	-- The catch: grab, then throw.
	harlowGrab = { assetId = PENDING, looped = false, priority = Enum.AnimationPriority.Action, interruption = "protected" },
	harlowThrow = { assetId = PENDING, looped = false, priority = Enum.AnimationPriority.Action, interruption = "protected" },
}

for id, def in SOUNDS do
	if def.assetId ~= PENDING and not SoundRegistry.has(id) then
		SoundRegistry.register(id, def)
	end
end

return table.freeze({
	PENDING = PENDING,
	SOUNDS = table.freeze(SOUNDS),
	GIBBERISH = table.freeze(GIBBERISH),
	IMAGES = table.freeze(IMAGES),
	ANIMATIONS = table.freeze(ANIMATIONS),
})
```

- [ ] **Step 6: Server picks a line variant.** In `src/ServerScriptService/Features/Occupant/OccupantServiceServer.luau`:
  - Require `local OccupantFeedbackUtils = require(OccupantShared.Utils.OccupantFeedbackUtils)` beside the other `OccupantShared` requires.
  - Module state: after `local rng = Random.new()` add `local lastLine: string? = nil`.
  - In `show`, replace

```lua
	local line = OccupantTellRules.lineFor(cue)
	if line ~= nil then
		OccupantRigSystem.say(current, line)
	end
```
  with
```lua
	local variants = if cue ~= nil then OccupantConstants.LINE_VARIANTS[cue] else nil
	local line = if variants ~= nil then OccupantFeedbackUtils.pickLine(variants, rng:NextNumber(), lastLine) else nil
	line = line or OccupantTellRules.lineFor(cue)
	if line ~= nil then
		lastLine = line
		OccupantRigSystem.say(current, line)
	end
```
  - Header comment: the Tells bullet ends "…a speech bubble (OccupantRigSystem, a paper memo; the line varies per cue, OccupantFeedbackUtils.pickLine); the client voices and types it (OccupantPresenceSystem)."

- [ ] **Step 7: The bubble's paper look.** In `src/ServerScriptService/Features/Occupant/Systems/OccupantRigSystem.luau`, in `build`, replace the five speech-styling lines

```lua
	speech.BackgroundTransparency = 0.1
	speech.BackgroundColor3 = Color3.new(1, 1, 1)
	speech.TextColor3 = Color3.fromRGB(20, 20, 24)
	speech.TextStrokeTransparency = 1
	speech.Font = Enum.Font.SourceSansSemibold
```
  with
```lua
	-- A memo, typed (spec §7 "UI as office paperwork … typewriter type"); the client reveals it letter by letter.
	speech.BackgroundTransparency = 0
	speech.BackgroundColor3 = OccupantConstants.SPEECH_PAPER
	speech.TextColor3 = OccupantConstants.SPEECH_INK
	speech.TextStrokeTransparency = 1
	speech.Font = OccupantConstants.SPEECH_FONT
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 6)
	corner.Parent = speech
	local border = Instance.new("UIStroke")
	border.Color = OccupantConstants.SPEECH_BORDER
	border.Thickness = 2
	border.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	border.Parent = speech
	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0, 8)
	padding.PaddingRight = UDim.new(0, 8)
	padding.PaddingTop = UDim.new(0, 4)
	padding.PaddingBottom = UDim.new(0, 4)
	padding.Parent = speech
```
  and in the header comment replace "M3 replaces the cues and bubble with the final face, voice and art." with "The bubble is a typed paper memo (M3); the client voices and types each line (OccupantPresenceSystem)."

- [ ] **Step 8: Presence system** `src/ReplicatedStorage/Client/Features/Occupant/Systems/OccupantPresenceSystem.luau`:

```lua
--!strict
--[=[
	OccupantPresenceSystem: how Mr. Harlow sounds on this client (Cleanup Crew spec §4 "Tells": "heartbeat when he
	is near but hasn't seen you; 3D footsteps and muttering through walls; '!' + sting + chase music when he spots
	you; a sigh when he gives up"; "Voice": "pitched, distorted gibberish plus a speech bubble with the line").
	- His footsteps, paced by his speed (OccupantFeedbackUtils.footstepInterval), and a muttering loop on his head.
	- His mode changes (OccupantFeedbackUtils.cues): a "hm?" when he investigates, the sting when he spots someone
	  (2D when it is you, positional otherwise), the chase music while he chases you, a sigh when he gives up.
	- Your heartbeat, on the beat OccupantTellRules sets (the same rule as M2's red pulse).
	- His voice: each new bubble line types out (MaxVisibleGraphemes, OccupantFeedbackUtils.reveal) and plays one
	  uploaded gibberish clip chosen per line (OccupantFeedbackUtils.clipFor); "*sigh*" is not voiced.
	Reads only replicated state: his tagged model, its mode/target attributes, his speech billboard. Pending sounds
	(OccupantAssets) are skipped silently and counted.

	Spec-exempt shell (Sound, Instances, RunService); the choices are the specced OccupantFeedbackUtils and
	OccupantTellRules.

	@class OccupantPresenceSystem
]=]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local OccupantShared = ReplicatedStorage.Shared.Features.Occupant
local Logger = require(ReplicatedStorage.Shared.Core.Logger)
local OccupantAssets = require(OccupantShared.Data.OccupantAssets)
local OccupantConstants = require(OccupantShared.Data.OccupantConstants)
local OccupantTellRules = require(OccupantShared.Rules.OccupantTellRules)
local OccupantFeedbackUtils = require(OccupantShared.Utils.OccupantFeedbackUtils)
local SoundRegistry = require(ReplicatedStorage.Shared.Features.Sound.Data.SoundRegistry)
local SoundTypes = require(ReplicatedStorage.Shared.Features.Sound.Data.SoundTypes)
local SoundServiceClient = require(ReplicatedStorage.Client.Features.Sound.SoundServiceClient)

type Harlow = {
	model: Model,
	root: BasePart,
	head: BasePart,
	speech: TextLabel?,
}

local log = Logger.new("OccupantPresenceSystem")

local current: Harlow? = nil
local mutter: SoundServiceClient.SoundHandle? = nil
local speechConnection: RBXScriptConnection? = nil
local connection: RBXScriptConnection? = nil
local lastMode: string? = nil
local lastMine = false
local ownsMusic = false
local stepClock = 0
local beatClock = 0
local revealText = ""
local revealStarted = 0
local revealing = false
local counters = { steps = 0, beats = 0, lines = 0, cues = 0, played = 0, pending = 0 }

local function play(id: string, options: SoundTypes.PlayOptions?): SoundServiceClient.SoundHandle?
	if OccupantAssets.SOUNDS[id] == nil then
		log:warn(`"{id}" is not an OccupantAssets sound`)
		return nil
	end
	if not SoundRegistry.has(id) then
		counters.pending += 1
		return nil
	end
	counters.played += 1
	return SoundServiceClient:play(id, options)
end

local function find(): Harlow?
	for _, instance in CollectionService:GetTagged(OccupantConstants.TAG) do
		if instance:IsA("Model") then
			local root = instance:FindFirstChild("HumanoidRootPart")
			local head = instance:FindFirstChild("Head")
			if root ~= nil and root:IsA("BasePart") and head ~= nil and head:IsA("BasePart") then
				local bubble = head:FindFirstChild(OccupantConstants.SPEECH_NAME)
				local label = if bubble ~= nil then bubble:FindFirstChildOfClass("TextLabel") else nil
				return { model = instance, root = root, head = head, speech = label }
			end
		end
	end
	return nil
end

local function setMusic(on: boolean)
	if on and not ownsMusic then
		if SoundRegistry.has("harlowChase") then
			ownsMusic = true
			SoundServiceClient:playMusic("harlowChase")
		else
			counters.pending += 1
		end
	elseif not on and ownsMusic then
		ownsMusic = false
		SoundServiceClient:playMusic(nil)
	end
end

local function onSpeech(label: TextLabel)
	local text = label.Text
	if text == "" then
		revealing = false
		return
	end
	counters.lines += 1
	revealText = text
	revealStarted = os.clock()
	revealing = true
	label.MaxVisibleGraphemes = 0
	local harlow = current
	if harlow == nil or not OccupantFeedbackUtils.voiced(text) then
		return
	end
	local uploaded: { string } = {}
	for _, id in OccupantAssets.GIBBERISH do
		if SoundRegistry.has(id) then
			table.insert(uploaded, id)
		end
	end
	local index = OccupantFeedbackUtils.clipFor(text, #uploaded)
	if index == nil then
		counters.pending += 1
		return
	end
	play(uploaded[index], { at = harlow.head })
end

local function attach(harlow: Harlow)
	current = harlow
	lastMode = nil
	lastMine = false
	stepClock = 0
	mutter = play("harlowMutter", { at = harlow.head })
	local label = harlow.speech
	if label ~= nil then
		speechConnection = label:GetPropertyChangedSignal("Text"):Connect(function()
			onSpeech(label)
		end)
	end
end

local function detach()
	local loop = mutter
	if loop ~= nil then
		loop:stop(0.3)
	end
	mutter = nil
	local listening = speechConnection
	if listening ~= nil then
		listening:Disconnect()
	end
	speechConnection = nil
	current = nil
	revealing = false
	lastMode = nil
	lastMine = false
	setMusic(false)
end

local function onCue(cue: OccupantFeedbackUtils.PresenceCue, harlow: Harlow, mine: boolean)
	counters.cues += 1
	if cue == "curious" then
		play("harlowCurious", { at = harlow.head })
	elseif cue == "spotted" then
		if mine then
			play("harlowSpotted")
		else
			play("harlowSpotted", { at = harlow.head, volumeScale = 0.6 })
		end
	elseif cue == "giveUp" then
		play("harlowSigh", { at = harlow.head })
	elseif cue == "chaseStart" then
		setMusic(true)
	elseif cue == "chaseEnd" then
		setMusic(false)
	end
end

local function stepFootsteps(harlow: Harlow, deltaTime: number)
	local velocity = harlow.root.AssemblyLinearVelocity
	local interval = OccupantFeedbackUtils.footstepInterval(Vector3.new(velocity.X, 0, velocity.Z).Magnitude)
	if interval == nil then
		stepClock = 0
		return
	end
	stepClock += deltaTime
	if stepClock >= interval then
		stepClock = 0
		counters.steps += 1
		play("harlowFootstep", { at = harlow.root })
	end
end

local function stepHeartbeat(harlow: Harlow, mode: string?, mine: boolean, deltaTime: number)
	local character = Players.LocalPlayer.Character
	local root = if character ~= nil then character:FindFirstChild("HumanoidRootPart") else nil
	if root == nil or not root:IsA("BasePart") then
		beatClock = 0
		return
	end
	local distance = (root.Position - harlow.root.Position).Magnitude
	if not OccupantTellRules.heartbeat(distance, mode, mine) then
		beatClock = 0
		return
	end
	beatClock += deltaTime
	if beatClock >= OccupantTellRules.period(distance) then
		beatClock = 0
		counters.beats += 1
		local closeness = 1 - math.clamp(distance / OccupantConstants.HEARTBEAT_RANGE, 0, 1)
		play("harlowHeartbeat", { volumeScale = 0.6 + 0.6 * closeness })
	end
end

local function stepReveal(harlow: Harlow)
	local label = harlow.speech
	if not revealing or label == nil then
		return
	end
	local total = utf8.len(revealText) or #revealText
	local shown = OccupantFeedbackUtils.reveal(total, os.clock() - revealStarted, OccupantConstants.TYPE_RATE)
	if shown >= total then
		label.MaxVisibleGraphemes = -1
		revealing = false
	else
		label.MaxVisibleGraphemes = shown
	end
end

local function step(deltaTime: number)
	local found = current
	if found ~= nil and found.model.Parent == nil then
		detach()
		found = nil
	end
	if found == nil then
		found = find()
		if found == nil then
			return
		end
		attach(found)
	end
	local harlow: Harlow = found
	local modeValue = harlow.model:GetAttribute(OccupantConstants.MODE_ATTRIBUTE)
	local mode = if type(modeValue) == "string" then modeValue else nil
	local mine = mode == "chase"
		and harlow.model:GetAttribute(OccupantConstants.TARGET_ATTRIBUTE) == Players.LocalPlayer.UserId
	for _, cue in OccupantFeedbackUtils.cues(lastMode, mode, lastMine, mine) do
		onCue(cue, harlow, mine)
	end
	lastMode = mode
	lastMine = mine
	stepFootsteps(harlow, deltaTime)
	stepHeartbeat(harlow, mode, mine, deltaTime)
	stepReveal(harlow)
end

local OccupantPresenceSystem = {}

function OccupantPresenceSystem.start()
	if connection ~= nil then
		return
	end
	connection = RunService.Heartbeat:Connect(step)
end

function OccupantPresenceSystem.stop()
	local running = connection
	if running ~= nil then
		running:Disconnect()
		connection = nil
	end
	detach()
end

function OccupantPresenceSystem.getState(): { [string]: any }
	return {
		present = current ~= nil,
		mode = lastMode,
		chasingMe = lastMine,
		music = ownsMusic,
		counters = table.clone(counters),
	}
end

return OccupantPresenceSystem
```

If luau-lsp does not narrow `found` after the reassignments in `step`, restructure with an early-returning helper `local function ensure(): Harlow?` that returns the attached Harlow; no cast.

- [ ] **Step 9: Wire it.** In `src/ReplicatedStorage/Client/Features/Occupant/OccupantServiceClient.luau`:
  - Require `local OccupantPresenceSystem = require(ReplicatedStorage.Client.Features.Occupant.Systems.OccupantPresenceSystem)` after the `OccupantTellSystem` require.
  - Add `"SoundServiceClient"` to `dependencies`.
  - In `start`, after `table.insert(stoppers, OccupantTellSystem.stop)`, add `OccupantPresenceSystem.start()` and `table.insert(stoppers, OccupantPresenceSystem.stop)`.
  - In `getState`, add `presence = OccupantPresenceSystem.getState(),`.
  - Header comment: add "OccupantPresenceSystem plays his footsteps, mutter, cues, chase music, your heartbeat and his voice."

- [ ] **Step 10: Exemptions.** Under `-- Cleanup Crew: Occupant`, add:

```lua
	["ReplicatedStorage.Shared.Features.Occupant.Data.OccupantAssets"] = "asset id slots; registers the uploaded sounds at load (no decisions)",
	["ReplicatedStorage.Client.Features.Occupant.Systems.OccupantPresenceSystem"] = "Sound/Instance/RunService shell (choices specced in OccupantFeedbackUtils, OccupantTellRules)",
```

- [ ] **Step 11: Module map, format and gate** (Global Constraints order). Expected: `==> All checks passed.`

- [ ] **Step 12: Controller: Studio TestEZ.** Expected: OccupantFeedbackUtils passes; M2's Occupant specs still pass.

- [ ] **Step 13: Controller: Studio verification** (Play Solo, `RunTests = false`; the M2 Task 9 server Script for `_G.O`; a client LocalScript printing `require(game.ReplicatedStorage.Client.Features.Occupant.OccupantServiceClient):getState().presence` every second). Checklist (screenshot 1):
1. Get Harlow to speak ("?" on a vacuum noise): his bubble is a cream memo with a dark border in typewriter type, and the line types out over ~1 s instead of appearing at once.
2. Over several investigations the curious line varies ("Per my last email…", "I heard that.", …) and never repeats twice in a row.
3. `steps` climbs while he walks and stops while he stands; `cues` counts "curious", "spotted", "giveUp"; when he chases you `chasingMe = true`; losing him sets it back to false.
4. With every id pending: `played = 0`, `pending` climbs, no "unknown sound" and no "is not an OccupantAssets sound" warning; `music = false` throughout.
5. Register test clips in the LocalScript (from `search_asset`: "footsteps heavy", "heartbeat", "gibberish voice" as `harlowGibberish1`, "horror chase music" as `harlowChase` with `looped = true`): footsteps are heard from his direction through a wall; the heartbeat thumps faster as he nears unseen and stops when he spots you; the chase music starts when he chases you and fades when he gives up; every voiced line plays the gibberish clip; "*sigh*" plays no gibberish.

- [ ] **Step 14: Commit**

```bash
git commit -m "feat(occupant): Harlow's footsteps, mutter, cues, chase music, heartbeat and typed gibberish voice"
python3 scripts/python/module_map.py --check
```

---
### Task 7: The catch scare and Harlow's animation hooks

**Files:**
- Create: `src/ReplicatedStorage/Shared/Features/Occupant/Utils/OccupantAnimationUtils.luau` (+ `OccupantAnimationUtils.spec.luau`)
- Create: `src/ReplicatedStorage/Shared/Features/Animation/Data/AnimationOccupantRegistry.luau` (+ `AnimationOccupantRegistry.spec.luau`)
- Create: `src/ReplicatedStorage/Client/Features/Occupant/Systems/OccupantScareSystem.luau`
- Modify: `src/ReplicatedStorage/Shared/Features/Animation/Data/AnimationRegistry.luau` (one domain row)
- Modify: `src/ReplicatedStorage/Shared/Features/Occupant/Data/OccupantConstants.luau`
- Modify: `src/ServerScriptService/Features/Occupant/OccupantServiceServer.luau` (the kind's poses)
- Modify: `src/ServerScriptService/Features/Occupant/Systems/OccupantCatchSystem.luau` (grab and throw)
- Modify: `src/ReplicatedStorage/Client/Features/Occupant/OccupantServiceClient.luau`
- Modify: `src/ServerScriptService/Core/Testing/SpecRoots.luau`

**Interfaces:**
- Consumes: Task 6's `OccupantAssets.ANIMATIONS / PENDING / IMAGES.grin / AnimationSlot`; `AnimationTypes.AnimationDomain = { [string]: AnimationDef }`, `AnimationDef = { assetId, priority, looped, interruption, ... }`; `AnimationRegistry.get(id)` (composes `DOMAIN_MODULES` at require and asserts each assetId is canonical: pending slots must never reach it); `AnimationServiceServer:playOnRig(model, id, opts?) -> (PlayHandle?, string?)`; base Npc plays `def.animations.idle / walk / run` by speed (NpcBehaviourSystem); M2's `OccupantCatchSystem.begin` (turns him, freezes the player, `CatchCam`, `LightsOut`, says the caught line, then after `SNAP_SECONDS` kills with a launch); M2's client `CatchCam` / `LightsOut` listeners.
- Produces (OccupantAnimationUtils): `domain(slots: { [string]: AnimationSlot }, pending: string) -> AnimationDomain`; `poses(has: (id: string) -> boolean) -> { idle: string, walk: string, run: string }`; `action(id: string, has: (id: string) -> boolean) -> string?`.
- Produces (AnimationOccupantRegistry): the `occupant` domain (uploaded slots only), composed into `AnimationRegistry`.
- Produces (OccupantScareSystem, client module-level): `snap()` (sting + stretched grin over his face for `SNAP_SECONDS`), `lightsOut(position: Vector3)` (power-down + grab sound there), `getState()`.
- Produces (OccupantConstants, new keys): `GRIN_NAME = "OccupantGrin"`, `GRIN_SIZE = 3.2`, `GRIN_STRETCH = 0.92`, `GRIN_TEETH = 7`, `GRIN_WHITE`, `GRIN_INK`.

- [ ] **Step 1: Write the failing specs.**

`src/ReplicatedStorage/Shared/Features/Occupant/Utils/OccupantAnimationUtils.spec.luau`:

```lua
local OccupantAnimationUtils = require(script.Parent.OccupantAnimationUtils)

local function slot(assetId, looped)
	return {
		assetId = assetId,
		looped = looped,
		priority = Enum.AnimationPriority.Movement,
		interruption = "ambient",
	}
end

local function hasOnly(ids)
	return function(id)
		return table.find(ids, id) ~= nil
	end
end

return function()
	describe("domain", function()
		it("keeps uploaded slots, copied as animation entries", function()
			local domain = OccupantAnimationUtils.domain({
				harlowWalk = slot("rbxassetid://1", true),
				harlowLook = slot("", true),
			}, "")
			expect(domain.harlowWalk).to.be.ok()
			expect(domain.harlowWalk.assetId).to.equal("rbxassetid://1")
			expect(domain.harlowWalk.looped).to.equal(true)
			expect(domain.harlowWalk.priority).to.equal(Enum.AnimationPriority.Movement)
			expect(domain.harlowWalk.interruption).to.equal("ambient")
			expect(domain.harlowLook).to.equal(nil)
		end)

		it("is empty while everything is pending", function()
			expect(next(OccupantAnimationUtils.domain({ harlowWalk = slot("", true) }, ""))).to.equal(nil)
		end)
	end)

	describe("poses", function()
		it("falls back to the base locomotion clips while Harlow's are pending", function()
			local poses = OccupantAnimationUtils.poses(hasOnly({ "idle", "walk", "run" }))
			expect(poses.idle).to.equal("idle")
			expect(poses.walk).to.equal("walk")
			expect(poses.run).to.equal("run")
		end)

		it("uses his lurch walk and look-around once uploaded, the base run without his own", function()
			local poses = OccupantAnimationUtils.poses(hasOnly({ "idle", "walk", "run", "harlowWalk", "harlowLook" }))
			expect(poses.walk).to.equal("harlowWalk")
			expect(poses.idle).to.equal("harlowLook")
			expect(poses.run).to.equal("run")
			expect(OccupantAnimationUtils.poses(hasOnly({ "harlowRun" })).run).to.equal("harlowRun")
		end)
	end)

	describe("action", function()
		it("names an uploaded action, nothing otherwise", function()
			expect(OccupantAnimationUtils.action("harlowGrab", hasOnly({ "harlowGrab" }))).to.equal("harlowGrab")
			expect(OccupantAnimationUtils.action("harlowThrow", hasOnly({ "harlowGrab" }))).to.equal(nil)
		end)
	end)
end
```

`src/ReplicatedStorage/Shared/Features/Animation/Data/AnimationOccupantRegistry.spec.luau`:

```lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AnimationOccupantRegistry = require(script.Parent.AnimationOccupantRegistry)
local AnimationRegistry = require(script.Parent.AnimationRegistry)
local AnimationTypes = require(script.Parent.AnimationTypes)
local OccupantAssets = require(ReplicatedStorage.Shared.Features.Occupant.Data.OccupantAssets)

return function()
	it("holds only uploaded slots, with canonical ids", function()
		for id, def in AnimationOccupantRegistry do
			local slot = OccupantAssets.ANIMATIONS[id]
			expect(slot).to.be.ok()
			expect(slot.assetId).never.to.equal(OccupantAssets.PENDING)
			expect(AnimationTypes.isCanonicalAssetId(def.assetId)).to.equal(true)
		end
	end)

	it("leaves every pending slot out of the registry", function()
		for id, slot in OccupantAssets.ANIMATIONS do
			if slot.assetId == OccupantAssets.PENDING then
				expect(AnimationRegistry.get(id)).to.equal(nil)
			end
		end
	end)

	it("is composed as the occupant domain", function()
		expect(AnimationRegistry.domain("occupant")).to.equal(AnimationOccupantRegistry)
	end)
end
```

- [ ] **Step 2: Controller: Studio TestEZ.** Expected: both specs error (modules missing).

- [ ] **Step 3: Utils** `src/ReplicatedStorage/Shared/Features/Occupant/Utils/OccupantAnimationUtils.luau`:

```lua
--!strict
--[=[
	OccupantAnimationUtils: Mr. Harlow's animations (Cleanup Crew spec §7 asset pipeline: "lurch walk, look-around,
	grab and throw"). `domain` turns his uploaded slots into the Animation registry's `occupant` domain, leaving
	pending ones out (the registry asserts canonical ids at require); `poses` names his NPC idle / walk / run clips,
	his own where uploaded and the base locomotion clips otherwise; `action` names a catch clip only when it is
	uploaded. Pure.

	@class OccupantAnimationUtils
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AnimationTypes = require(ReplicatedStorage.Shared.Features.Animation.Data.AnimationTypes)
local OccupantAssets = require(ReplicatedStorage.Shared.Features.Occupant.Data.OccupantAssets)

export type Poses = {
	idle: string,
	walk: string,
	run: string,
}

local OccupantAnimationUtils = {}

function OccupantAnimationUtils.domain(
	slots: { [string]: OccupantAssets.AnimationSlot },
	pending: string
): AnimationTypes.AnimationDomain
	local domain: AnimationTypes.AnimationDomain = {}
	for id, slot in slots do
		if slot.assetId ~= pending then
			local def: AnimationTypes.AnimationDef = {
				assetId = slot.assetId,
				priority = slot.priority,
				looped = slot.looped,
				interruption = slot.interruption,
			}
			domain[id] = table.freeze(def)
		end
	end
	return table.freeze(domain)
end

function OccupantAnimationUtils.poses(has: (id: string) -> boolean): Poses
	return {
		idle = if has("harlowLook") then "harlowLook" else "idle",
		walk = if has("harlowWalk") then "harlowWalk" else "walk",
		run = if has("harlowRun") then "harlowRun" else "run",
	}
end

function OccupantAnimationUtils.action(id: string, has: (id: string) -> boolean): string?
	return if has(id) then id else nil
end

return OccupantAnimationUtils
```

- [ ] **Step 4: The domain** `src/ReplicatedStorage/Shared/Features/Animation/Data/AnimationOccupantRegistry.luau`:

```lua
--!strict
--[=[
	AnimationOccupantRegistry: the `occupant` animation domain (Cleanup Crew's Mr. Harlow), composed by
	AnimationRegistry. Built from OccupantAssets.ANIMATIONS (the one home of his animation ids, spec §7), uploaded
	slots only, so a pending slot never reaches the registry's canonical-id assert and he keeps the base clips.

	@class AnimationOccupantRegistry
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local OccupantAssets = require(ReplicatedStorage.Shared.Features.Occupant.Data.OccupantAssets)
local OccupantAnimationUtils = require(ReplicatedStorage.Shared.Features.Occupant.Utils.OccupantAnimationUtils)

return OccupantAnimationUtils.domain(OccupantAssets.ANIMATIONS, OccupantAssets.PENDING)
```

- [ ] **Step 5: Compose it.** In `src/ReplicatedStorage/Shared/Features/Animation/Data/AnimationRegistry.luau`:
  - After `local AnimationActionRegistry = require(...)`, add `local AnimationOccupantRegistry = require(AnimationShared.Data.AnimationOccupantRegistry)`.
  - In `DOMAIN_MODULES`, after `actions = AnimationActionRegistry,`, add `occupant = AnimationOccupantRegistry,`.

- [ ] **Step 6: Constants.** In `OccupantConstants`'s returned table, after the Task 6 keys, add:

```lua
	-- The catch scare's grin over his face (spec §4 "stretched-grin face"; kid-safe cartoon): its billboard,
	-- size in studs, how wide the mouth stretches, teeth, colours (used while the grin image is pending).
	GRIN_NAME = "OccupantGrin",
	GRIN_SIZE = 3.2,
	GRIN_STRETCH = 0.92,
	GRIN_TEETH = 7,
	GRIN_WHITE = Color3.fromRGB(250, 250, 240),
	GRIN_INK = Color3.fromRGB(15, 10, 10),
```

- [ ] **Step 7: His poses.** In `src/ServerScriptService/Features/Occupant/OccupantServiceServer.luau`:
  - Requires: `local AnimationRegistry = require(ReplicatedStorage.Shared.Features.Animation.Data.AnimationRegistry)` and `local OccupantAnimationUtils = require(OccupantShared.Utils.OccupantAnimationUtils)`.
  - In the `NpcRegistry.register` call, replace `animations = { idle = "idle", walk = "walk", run = "run" },` with:

```lua
		-- His own clips where uploaded (lurch walk, look-around as his standing pose), else the base ones.
		animations = OccupantAnimationUtils.poses(function(id: string): boolean
			return AnimationRegistry.get(id) ~= nil
		end),
```

- [ ] **Step 8: Grab and throw.** In `src/ServerScriptService/Features/Occupant/Systems/OccupantCatchSystem.luau`:
  - Requires: `local AnimationRegistry = require(ReplicatedStorage.Shared.Features.Animation.Data.AnimationRegistry)`, `local OccupantAnimationUtils = require(ReplicatedStorage.Shared.Features.Occupant.Utils.OccupantAnimationUtils)`, `local AnimationServiceServer = require(ServerScriptService.Features.Animation.AnimationServiceServer)`.
  - After the `catching` table, add:

```lua
local function registered(id: string): boolean
	return AnimationRegistry.get(id) ~= nil
end

-- Plays one of his catch clips on the rig, when it is uploaded (nothing while pending).
local function act(rig: OccupantRigSystem.Rig, id: string)
	local clip = OccupantAnimationUtils.action(id, registered)
	if clip ~= nil then
		AnimationServiceServer:playOnRig(rig.model, clip)
	end
end
```
  - In `begin`, right after `OccupantRigSystem.say(rig, OccupantConstants.LINES.caught)`, add `act(rig, "harlowGrab")`.
  - In the delayed step, right before `DeathServiceServer:kill(humanoid, "caught", { launch = velocity })`, add `act(rig, "harlowThrow")`.
  - Header comment: add "He plays his grab clip at the start and his throw clip at the launch when they are uploaded (OccupantAssets)."

- [ ] **Step 9: Scare system** `src/ReplicatedStorage/Client/Features/Occupant/Systems/OccupantScareSystem.luau`:

```lua
--!strict
--[=[
	OccupantScareSystem: the catch scare on this client (Cleanup Crew spec §4 "Catch" step 1: "camera snaps to his
	face ~0.6 s, nearby lights die, distorted sting, stretched-grin face"; kid-safe). `snap` (on CatchCam, which
	only the caught player gets) plays the distorted sting and, for SNAP_SECONDS, puts a grin over his face that
	stretches wide: the uploaded grin image (OccupantAssets.IMAGES.grin) or, while it is pending, a cartoon grin
	built from frames (white eyes, a wide toothy mouth). `lightsOut` (everyone) plays the power-down and his grab
	where it happened. The camera, the red screen and the dark lights are M2's (OccupantServiceClient,
	OccupantTellSystem).

	Spec-exempt shell (Instances, tweens, Sound).

	@class OccupantScareSystem
]=]

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local OccupantShared = ReplicatedStorage.Shared.Features.Occupant
local Logger = require(ReplicatedStorage.Shared.Core.Logger)
local OccupantAssets = require(OccupantShared.Data.OccupantAssets)
local OccupantConstants = require(OccupantShared.Data.OccupantConstants)
local SoundRegistry = require(ReplicatedStorage.Shared.Features.Sound.Data.SoundRegistry)
local SoundTypes = require(ReplicatedStorage.Shared.Features.Sound.Data.SoundTypes)
local SoundServiceClient = require(ReplicatedStorage.Client.Features.Sound.SoundServiceClient)

local log = Logger.new("OccupantScareSystem")

local counters = { scares = 0, grins = 0, lightsOut = 0, played = 0, pending = 0 }

local function play(id: string, options: SoundTypes.PlayOptions?)
	if OccupantAssets.SOUNDS[id] == nil then
		log:warn(`"{id}" is not an OccupantAssets sound`)
		return
	end
	if not SoundRegistry.has(id) then
		counters.pending += 1
		return
	end
	counters.played += 1
	SoundServiceClient:play(id, options)
end

local function headOf(): BasePart?
	for _, instance in CollectionService:GetTagged(OccupantConstants.TAG) do
		local head = instance:FindFirstChild("Head")
		if head ~= nil and head:IsA("BasePart") then
			return head
		end
	end
	return nil
end

local function frame(parent: Instance, size: UDim2, position: UDim2, color: Color3, round: boolean): Frame
	local item = Instance.new("Frame")
	item.AnchorPoint = Vector2.new(0.5, 0.5)
	item.Size = size
	item.Position = position
	item.BackgroundColor3 = color
	item.BorderSizePixel = 0
	if round then
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0.5, 0)
		corner.Parent = item
	end
	item.Parent = parent
	return item
end

-- The frame-built grin (while the image is pending); returns the mouth, which stretches.
local function drawGrin(gui: BillboardGui): Frame
	local white = OccupantConstants.GRIN_WHITE
	local ink = OccupantConstants.GRIN_INK
	for _, x in { 0.32, 0.68 } do
		local eye = frame(gui, UDim2.fromScale(0.2, 0.16), UDim2.fromScale(x, 0.32), white, true)
		frame(eye, UDim2.fromScale(0.35, 0.45), UDim2.fromScale(0.5, 0.55), ink, true)
	end
	local mouth = frame(gui, UDim2.fromScale(0.45, 0.16), UDim2.fromScale(0.5, 0.68), white, true)
	local outline = Instance.new("UIStroke")
	outline.Color = ink
	outline.Thickness = 3
	outline.Parent = mouth
	for index = 1, OccupantConstants.GRIN_TEETH - 1 do
		frame(mouth, UDim2.new(0, 2, 1, 0), UDim2.fromScale(index / OccupantConstants.GRIN_TEETH, 0.5), ink, false)
	end
	return mouth
end

local OccupantScareSystem = {}

--[=[
	The caught player's scare beat: the sting, and the grin over his face for SNAP_SECONDS.
]=]
function OccupantScareSystem.snap()
	counters.scares += 1
	play("harlowCatchSting")
	local head = headOf()
	if head == nil then
		return
	end
	counters.grins += 1
	local gui = Instance.new("BillboardGui")
	gui.Name = OccupantConstants.GRIN_NAME
	gui.Adornee = head
	-- A BillboardGui's scale size is in studs.
	gui.Size = UDim2.fromScale(OccupantConstants.GRIN_SIZE, OccupantConstants.GRIN_SIZE)
	gui.AlwaysOnTop = true
	gui.LightInfluence = 0
	local stretch = TweenInfo.new(OccupantConstants.SNAP_SECONDS, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
	local image = OccupantAssets.IMAGES.grin
	if image ~= OccupantAssets.PENDING then
		local picture = Instance.new("ImageLabel")
		picture.AnchorPoint = Vector2.new(0.5, 0.5)
		picture.Position = UDim2.fromScale(0.5, 0.5)
		picture.Size = UDim2.fromScale(0.7, 0.7)
		picture.BackgroundTransparency = 1
		picture.Image = image
		picture.Parent = gui
		TweenService:Create(picture, stretch, { Size = UDim2.fromScale(1, 0.85) }):Play()
	else
		local mouth = drawGrin(gui)
		TweenService:Create(mouth, stretch, { Size = UDim2.fromScale(OccupantConstants.GRIN_STRETCH, 0.2) }):Play()
	end
	-- Under his head on this client only (a client-made child of a replicated part never replicates).
	gui.Parent = head
	task.delay(OccupantConstants.SNAP_SECONDS, function()
		gui:Destroy()
	end)
end

--[=[
	A catch somewhere: the lights' power-down and his grab, heard from there.
]=]
function OccupantScareSystem.lightsOut(position: Vector3)
	counters.lightsOut += 1
	play("harlowPowerDown", { at = position })
	play("harlowGrab", { at = position })
end

function OccupantScareSystem.getState(): { [string]: any }
	return table.clone(counters)
end

return OccupantScareSystem
```

- [ ] **Step 10: Wire it.** In `src/ReplicatedStorage/Client/Features/Occupant/OccupantServiceClient.luau`:
  - Require `local OccupantScareSystem = require(ReplicatedStorage.Client.Features.Occupant.Systems.OccupantScareSystem)`.
  - In the `CatchCam` listener, after `snap(cframe)`, add `OccupantScareSystem.snap()`.
  - In the `LightsOut` listener, after `OccupantTellSystem.lightsOut(position, os.clock())`, add `OccupantScareSystem.lightsOut(position)`.
  - In `getState`, add `scare = OccupantScareSystem.getState(),`.
  - Header comment: replace "The stretched-grin face and the distorted sting are M3." with "The sting and the stretched grin are OccupantScareSystem's."

- [ ] **Step 11: Exemptions.** Under `-- Cleanup Crew: Occupant`, add:

```lua
	["ReplicatedStorage.Client.Features.Occupant.Systems.OccupantScareSystem"] = "Instance/tween/Sound shell (the scare beat; no decisions)",
```
(OccupantAnimationUtils and AnimationOccupantRegistry have specs.)

- [ ] **Step 12: Module map, format and gate** (Global Constraints order). Expected: `==> All checks passed.`

- [ ] **Step 13: Controller: Studio TestEZ.** Expected: OccupantAnimationUtils and AnimationOccupantRegistry pass; AnimationRegistry's spec still passes (its unknown-domain case uses "combat").

- [ ] **Step 14: Controller: Studio verification** (Play Solo, `RunTests = false`; M2 Task 10's server Script). Checklist (screenshot 1 mid-scare):
1. Get caught: during the 0.6 s camera snap a cartoon grin covers his face (two white eyes, a white toothy mouth stretching wide), then vanishes with the launch. Nothing gory; it reads at phone size (check a 375×812 screenshot via the MCP viewport if available).
2. Harlow still walks, runs and stands with the base clips (all animation slots pending); F4 → Anims on his rig is not available, so watch him: no T-pose, no frozen limbs; Output has no AnimationRegistry assert and no "unknown animation".
3. `require(game.ReplicatedStorage.Client.Features.Occupant.OccupantServiceClient):getState().scare` shows `scares = 1`, `grins = 1`, `lightsOut = 1` after one catch.
4. Optional (only if the developer has uploaded a test clip to their own account): paste its id into `OccupantAssets.ANIMATIONS.harlowWalk`, sync, Play: he walks with it; revert the edit afterwards (uploads are the developer's).

- [ ] **Step 15: Commit**

```bash
git commit -m "feat(occupant): catch sting and stretched grin; Harlow's animation domain with base fallbacks"
python3 scripts/python/module_map.py --check
```

---
### Task 8: The office at night (decor, atmosphere per phase and tier, overtime red, broken fluorescents, hum)

**Files:**
- Create: `src/ReplicatedStorage/Shared/Features/Office/Data/OfficeDecorConstants.luau`
- Create: `src/ServerScriptService/Features/Office/Systems/OfficeDecorSystem.luau`
- Create: `src/ReplicatedStorage/Client/Features/Office/OfficeServiceClient.luau`
- Create: `src/ReplicatedStorage/Client/Features/Office/Data/OfficeAssets.luau`
- Create: `src/ReplicatedStorage/Client/Features/Office/Data/OfficeAtmosphereConstants.luau`
- Create: `src/ReplicatedStorage/Client/Features/Office/Utils/OfficeAtmosphereUtils.luau` (+ `OfficeAtmosphereUtils.spec.luau`)
- Create: `src/ReplicatedStorage/Client/Features/Office/Utils/OfficeLightUtils.luau` (+ `OfficeLightUtils.spec.luau`)
- Create: `src/ReplicatedStorage/Client/Features/Office/Systems/OfficeAtmosphereSystem.luau`
- Modify: `src/ServerScriptService/Features/Office/OfficeServiceServer.luau`
- Modify: `src/ServerScriptService/Core/Testing/SpecRoots.luau`

**Interfaces:**
- Consumes: M1 Office: `OfficeTypes.Layout` (`startRoom`, `doors: { { a, b, x, z, width } }`, `markers`), `OfficeLayoutUtils.room(layout, id) -> Room?`, `doorEdge(room, door) -> Edge?` ("minX" | "maxX" | "minZ" | "maxZ"), `markersOf(layout, "desk") -> { Marker }`, `OfficeConstants.ORIGIN / DESK_SIZE / WALL_HEIGHT`, `OfficeServiceServer.start` (`built = OfficeBuildSystem.build(LAYOUT, OfficeConstants.ORIGIN)`); M2's ceiling lights (Part, Neon, a PointLight child, tag `OccupantConstants.LIGHT_TAG`), whose `Material` and `PointLight.Enabled` M2's OccupantTellSystem owns on the client; `ShiftStore.snapshot` (`phase`, `stage`, `tier`); `VfxAtmosphereRegistry.register / has`, `VfxServiceClient:setAtmosphere(id?, fade?) / requestScreen / releaseScreen`; `SoundServiceClient:setAmbience / play`.
- Produces (OfficeDecorConstants): `type AmbientKind = "phone" | "typing" | "elevator"`; `AMBIENT_TAG = "OfficeAmbient"`, `AMBIENT_KIND_ATTRIBUTE = "AmbientKind"`, `DECOR_FOLDER`, `ELEVATOR_POINT`, `EMITTER_LIFT`, `TYPING_EVERY = 2`, exit-sign, monitor and elevator look.
- Produces (OfficeDecorSystem): `build(layout: OfficeTypes.Layout, origin: CFrame, parent: Instance) -> Folder`.
- Produces (OfficeAtmosphereConstants): `PRESETS: { [string]: VfxTypes.Atmosphere }` (`officeNight`, `officeTier1`, `officeTier2`, `officeBreak`, `officeOvertime`), their names `NIGHT / TIER1 / TIER2 / BREAK / OVERTIME`, `FADE = 3`, `OVERTIME_TINT`, `OVERTIME_SATURATION`, `OVERTIME_LIGHT_COLOR`, `HUM_LAYER = "officeHum"`, `BROKEN_FRACTION = 0.18`, `BROKEN_RADIUS = 80`, `BROKEN_RATE = 6`, `BROKEN_THRESHOLD = -0.3`, `BROKEN_DIM = 0.15`, `BROKEN_TRANSPARENCY = 0.6`, `ATMOSPHERE_INTERVAL = 0.05`; Task 9's ambience keys (`PHONE_MIN / PHONE_MAX / ELEVATOR_MIN / ELEVATOR_MAX / EMPTY_RADIUS / TYPING_STOP_RADIUS / TYPING_QUIET_SECONDS / TYPING_FADE / AMBIENCE_INTERVAL`).
- Produces (OfficeAtmosphereUtils): `preset(snapshot: ShiftSnapshot?) -> string?`; `overtime(snapshot: ShiftSnapshot?) -> boolean`; `hum(snapshot: ShiftSnapshot?) -> boolean`.
- Produces (OfficeLightUtils): `hash(position: Vector3) -> number` (0..1, stable); `broken(position: Vector3, fraction: number) -> boolean`; `nearbyBroken(positions: { Vector3 }, center: Vector3, radius: number, fraction: number) -> { number }`; `glow(now: number, seed: number) -> number` (1 or `BROKEN_DIM`).
- Produces (OfficeAssets): `PENDING`, `SOUNDS` (`officeHum`, `officeLightZap`, `officePhoneRing`, `officeElevatorDing`, `officeTyping`), and their ids as `HUM`, `ZAP`, `PHONE`, `ELEVATOR`, `TYPING`.
- Produces (OfficeServiceClient): the client service; `getState()`. (Task 9 adds the ambience.)
- Produces (OfficeAtmosphereSystem, client module-level): `start()`, `stop()`, `getState()`.

- [ ] **Step 1: Write the failing specs.**

`src/ReplicatedStorage/Client/Features/Office/Utils/OfficeAtmosphereUtils.spec.luau`:

```lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local OfficeAtmosphereUtils = require(script.Parent.OfficeAtmosphereUtils)
local OfficeAtmosphereConstants = require(ReplicatedStorage.Client.Features.Office.Data.OfficeAtmosphereConstants)

local function snapshot(overrides)
	local base = { phase = "running", sub = "normal", stage = "normal", tier = 0, quotaMet = false }
	for key, value in overrides or {} do
		base[key] = value
	end
	return base
end

return function()
	describe("preset", function()
		it("keeps the place's own lighting outside a shift", function()
			expect(OfficeAtmosphereUtils.preset(nil)).to.equal(nil)
			expect(OfficeAtmosphereUtils.preset(snapshot({ phase = "lobby" }))).to.equal(nil)
		end)

		it("is night from the arrival countdown through the results", function()
			expect(OfficeAtmosphereUtils.preset(snapshot({ phase = "starting" }))).to.equal(OfficeAtmosphereConstants.NIGHT)
			expect(OfficeAtmosphereUtils.preset(snapshot())).to.equal(OfficeAtmosphereConstants.NIGHT)
			expect(OfficeAtmosphereUtils.preset(snapshot({ phase = "results", stage = "overtime", tier = 2 }))).to.equal(
				OfficeAtmosphereConstants.NIGHT
			)
		end)

		it("darkens a step per pressure tier", function()
			expect(OfficeAtmosphereUtils.preset(snapshot({ tier = 1 }))).to.equal(OfficeAtmosphereConstants.TIER1)
			expect(OfficeAtmosphereUtils.preset(snapshot({ tier = 2 }))).to.equal(OfficeAtmosphereConstants.TIER2)
			expect(OfficeAtmosphereUtils.preset(snapshot({ stage = "warning", tier = 1 }))).to.equal(OfficeAtmosphereConstants.TIER1)
		end)

		it("lifts a little for Harlow's break", function()
			expect(OfficeAtmosphereUtils.preset(snapshot({ stage = "break", tier = 2 }))).to.equal(OfficeAtmosphereConstants.BREAK)
		end)

		it("picks overtime over the tier", function()
			expect(OfficeAtmosphereUtils.preset(snapshot({ stage = "overtime", tier = 2 }))).to.equal(
				OfficeAtmosphereConstants.OVERTIME
			)
		end)

		it("only names registered presets", function()
			for _, name in {
				OfficeAtmosphereConstants.NIGHT,
				OfficeAtmosphereConstants.TIER1,
				OfficeAtmosphereConstants.TIER2,
				OfficeAtmosphereConstants.BREAK,
				OfficeAtmosphereConstants.OVERTIME,
			} do
				expect(OfficeAtmosphereConstants.PRESETS[name]).to.be.ok()
			end
		end)
	end)

	describe("overtime", function()
		it("turns the lights red only while overtime runs", function()
			expect(OfficeAtmosphereUtils.overtime(snapshot({ stage = "overtime" }))).to.equal(true)
			expect(OfficeAtmosphereUtils.overtime(snapshot({ stage = "warning" }))).to.equal(false)
		end)

		it("drops overtime when the run ends", function()
			expect(OfficeAtmosphereUtils.overtime(snapshot({ phase = "results", stage = "overtime" }))).to.equal(false)
			expect(OfficeAtmosphereUtils.overtime(nil)).to.equal(false)
		end)
	end)

	describe("hum", function()
		it("hums whenever the office is in a shift", function()
			expect(OfficeAtmosphereUtils.hum(snapshot())).to.equal(true)
			expect(OfficeAtmosphereUtils.hum(snapshot({ phase = "results" }))).to.equal(true)
			expect(OfficeAtmosphereUtils.hum(snapshot({ phase = "lobby" }))).to.equal(false)
			expect(OfficeAtmosphereUtils.hum(nil)).to.equal(false)
		end)
	end)
end
```

`src/ReplicatedStorage/Client/Features/Office/Utils/OfficeLightUtils.spec.luau`:

```lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local OfficeLightUtils = require(script.Parent.OfficeLightUtils)
local OfficeAtmosphereConstants = require(ReplicatedStorage.Client.Features.Office.Data.OfficeAtmosphereConstants)

local function grid()
	local positions = {}
	for x = 0, 120, 15 do
		for z = 0, 90, 15 do
			table.insert(positions, Vector3.new(1000 + x, 11.5, z))
		end
	end
	return positions
end

return function()
	describe("hash", function()
		it("is stable per light and within 0..1", function()
			for _, position in grid() do
				local value = OfficeLightUtils.hash(position)
				expect(value >= 0 and value < 1).to.equal(true)
				expect(OfficeLightUtils.hash(position)).to.equal(value)
			end
		end)
	end)

	describe("broken", function()
		it("breaks none at 0 and all at 1", function()
			for _, position in grid() do
				expect(OfficeLightUtils.broken(position, 0)).to.equal(false)
				expect(OfficeLightUtils.broken(position, 1)).to.equal(true)
			end
		end)

		it("breaks some but not most of a real grid at the tuned fraction", function()
			local count, total = 0, 0
			for _, position in grid() do
				total += 1
				if OfficeLightUtils.broken(position, OfficeAtmosphereConstants.BROKEN_FRACTION) then
					count += 1
				end
			end
			expect(count >= 1).to.equal(true)
			expect(count < total / 2).to.equal(true)
		end)
	end)

	describe("nearbyBroken", function()
		it("selects only broken lights within the radius", function()
			local positions = { Vector3.new(0, 0, 0), Vector3.new(10, 0, 0), Vector3.new(500, 0, 0) }
			local all = OfficeLightUtils.nearbyBroken(positions, Vector3.zero, 50, 1)
			expect(#all).to.equal(2)
			expect(all[1]).to.equal(1)
			expect(all[2]).to.equal(2)
			expect(#OfficeLightUtils.nearbyBroken(positions, Vector3.zero, 50, 0)).to.equal(0)
		end)
	end)

	describe("glow", function()
		it("is either full or dimmed, and blinks dim now and then", function()
			local dims, fulls = 0, 0
			for step = 0, 600 do
				local value = OfficeLightUtils.glow(step * 0.05, 3.7)
				if value == 1 then
					fulls += 1
				elseif value == OfficeAtmosphereConstants.BROKEN_DIM then
					dims += 1
				end
			end
			expect(dims + fulls).to.equal(601)
			expect(dims >= 1).to.equal(true)
			expect(fulls > dims).to.equal(true)
		end)
	end)
end
```

- [ ] **Step 2: Controller: Studio TestEZ.** Expected: both specs error (modules missing). If "blinks dim now and then" later finds no dim sample (the noise field happens to stay high on that line), move `BROKEN_THRESHOLD` to `-0.25` and report.

- [ ] **Step 3: Shared decor constants** `src/ReplicatedStorage/Shared/Features/Office/Data/OfficeDecorConstants.luau`:

```lua
--!strict
--[=[
	OfficeDecorConstants: the office at night (Cleanup Crew spec §7 "emergency-exit glow, monitors glowing blue";
	"phones ringing in empty rooms, an elevator dinging on its own, typing that stops when you enter"). The decor's
	look and placement (OfficeDecorSystem builds it on the server) and the ambience emitters' tag and kinds (the
	client's OfficeAmbienceSystem plays from them). Positions are office-local studs (OfficeTypes). Static data
	(spec-exempt).

	@class OfficeDecorConstants
]=]

export type AmbientKind = "phone" | "typing" | "elevator"

return table.freeze({
	DECOR_FOLDER = "NightDecor",
	-- The invisible sound emitters: their tag, and the attribute naming what plays there.
	AMBIENT_TAG = "OfficeAmbient",
	AMBIENT_KIND_ATTRIBUTE = "AmbientKind",
	-- How far above a desk's top a phone or typing emitter sits; every TYPING_EVERY-th desk has a typist.
	EMITTER_LIFT = 0.5,
	TYPING_EVERY = 2,
	-- The elevator in reception (its west wall): the doors' centre, office-local (x, height, z).
	ELEVATOR_POINT = Vector3.new(0.6, 4, 45),
	ELEVATOR_DOOR_SIZE = Vector3.new(0.2, 8, 3),
	ELEVATOR_COLOR = Color3.fromRGB(150, 155, 162),
	ELEVATOR_LAMP_SIZE = Vector3.new(0.2, 0.6, 1.2),
	ELEVATOR_LAMP_COLOR = Color3.fromRGB(255, 176, 60),
	-- Exit signs over the doorways out of the loading bay.
	EXIT_SIGN_SIZE = Vector3.new(3, 1, 0.3),
	EXIT_SIGN_HEIGHT = 9,
	EXIT_COLOR = Color3.fromRGB(60, 235, 120),
	EXIT_LIGHT_RANGE = 12,
	EXIT_LIGHT_BRIGHTNESS = 1.4,
	-- A monitor on each desk: a dark case and a glowing blue screen.
	MONITOR_SIZE = Vector3.new(2, 1.3, 0.25),
	MONITOR_CASE_COLOR = Color3.fromRGB(30, 30, 34),
	MONITOR_COLOR = Color3.fromRGB(80, 140, 255),
	MONITOR_LIGHT_RANGE = 8,
	MONITOR_LIGHT_BRIGHTNESS = 0.9,
})
```

- [ ] **Step 4: Server decor** `src/ServerScriptService/Features/Office/Systems/OfficeDecorSystem.luau`:

```lua
--!strict
--[=[
	OfficeDecorSystem: the office at night (Cleanup Crew spec §7 "dim, buzzing fluorescents (some flickering),
	emergency-exit glow, monitors glowing blue"; ambient dread). Built once, after the graybox, into one folder: a
	glowing green EXIT sign over each doorway out of the loading bay, a monitor glowing blue on every desk, the
	elevator's doors and floor lamp in reception, and the invisible sound emitters the client's ambience plays from
	(tag OfficeAmbient, attribute AmbientKind: a phone on every desk, a typist at every other desk, the elevator).
	Non-colliding, non-queryable, so nothing here blocks a path, a ray or a floor probe. The flickering and the
	sounds are client side.

	Spec-exempt shell (Instances); placement comes from the layout the specced OfficeLayoutRules validated.

	@class OfficeDecorSystem
]=]

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local OfficeServer = ServerScriptService.Features.Office
local OfficeDecorConstants = require(ReplicatedStorage.Shared.Features.Office.Data.OfficeDecorConstants)
local OfficeConstants = require(OfficeServer.Data.OfficeConstants)
local OfficeTypes = require(OfficeServer.Data.OfficeTypes)
local OfficeLayoutUtils = require(OfficeServer.Utils.OfficeLayoutUtils)

local function part(name: string, size: Vector3, cframe: CFrame, color: Color3, parent: Instance): Part
	local created = Instance.new("Part")
	created.Name = name
	created.Size = size
	created.CFrame = cframe
	created.Color = color
	created.Material = Enum.Material.SmoothPlastic
	created.Anchored = true
	created.CanCollide = false
	created.CanQuery = false
	created.CanTouch = false
	created.CastShadow = false
	created.Parent = parent
	return created
end

local function glow(on: BasePart, color: Color3, range: number, brightness: number)
	local point = Instance.new("PointLight")
	point.Color = color
	point.Range = range
	point.Brightness = brightness
	point.Parent = on
end

local function exitSign(at: CFrame, parent: Instance)
	local sign = part("ExitSign", OfficeDecorConstants.EXIT_SIGN_SIZE, at, OfficeDecorConstants.EXIT_COLOR, parent)
	sign.Material = Enum.Material.Neon
	for _, face in { Enum.NormalId.Front, Enum.NormalId.Back } do
		local surface = Instance.new("SurfaceGui")
		surface.Face = face
		surface.LightInfluence = 0
		surface.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		surface.PixelsPerStud = 50
		local label = Instance.new("TextLabel")
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundTransparency = 1
		label.Text = "EXIT"
		label.Font = Enum.Font.Oswald
		label.TextScaled = true
		label.TextColor3 = Color3.new(1, 1, 1)
		label.Parent = surface
		surface.Parent = sign
	end
	glow(sign, OfficeDecorConstants.EXIT_COLOR, OfficeDecorConstants.EXIT_LIGHT_RANGE, OfficeDecorConstants.EXIT_LIGHT_BRIGHTNESS)
end

local function monitor(deskTop: CFrame, parent: Instance)
	local size = OfficeDecorConstants.MONITOR_SIZE
	-- Towards the desk's back edge, facing -Z (where a sitter would be).
	local case = part(
		"Monitor",
		size,
		deskTop * CFrame.new(0, size.Y / 2, 0.6),
		OfficeDecorConstants.MONITOR_CASE_COLOR,
		parent
	)
	local screen = part(
		"Screen",
		Vector3.new(size.X - 0.2, size.Y - 0.2, 0.05),
		case.CFrame * CFrame.new(0, 0, -size.Z / 2 - 0.03),
		OfficeDecorConstants.MONITOR_COLOR,
		parent
	)
	screen.Material = Enum.Material.Neon
	glow(
		screen,
		OfficeDecorConstants.MONITOR_COLOR,
		OfficeDecorConstants.MONITOR_LIGHT_RANGE,
		OfficeDecorConstants.MONITOR_LIGHT_BRIGHTNESS
	)
end

local function emitter(kind: OfficeDecorConstants.AmbientKind, position: Vector3, parent: Instance)
	local spot = part(`Ambient ({kind})`, Vector3.new(1, 1, 1), CFrame.new(position), Color3.new(0, 0, 0), parent)
	spot.Transparency = 1
	spot:SetAttribute(OfficeDecorConstants.AMBIENT_KIND_ATTRIBUTE, kind)
	CollectionService:AddTag(spot, OfficeDecorConstants.AMBIENT_TAG)
end

local function elevator(origin: CFrame, parent: Instance)
	local point = OfficeDecorConstants.ELEVATOR_POINT
	local door = OfficeDecorConstants.ELEVATOR_DOOR_SIZE
	for _, side in { -1, 1 } do
		local panel = part(
			"ElevatorDoor",
			door,
			origin * CFrame.new(point.X, point.Y, point.Z + side * door.Z / 2),
			OfficeDecorConstants.ELEVATOR_COLOR,
			parent
		)
		panel.Material = Enum.Material.Metal
	end
	local lamp = part(
		"ElevatorLamp",
		OfficeDecorConstants.ELEVATOR_LAMP_SIZE,
		origin * CFrame.new(point.X, point.Y + door.Y / 2 + 0.6, point.Z),
		OfficeDecorConstants.ELEVATOR_LAMP_COLOR,
		parent
	)
	lamp.Material = Enum.Material.Neon
	emitter("elevator", (origin * CFrame.new(point.X + 1, point.Y, point.Z)).Position, parent)
end

local OfficeDecorSystem = {}

--[=[
	Builds the night decor for `layout` at `origin` into one folder under `parent`, and returns it.
]=]
function OfficeDecorSystem.build(layout: OfficeTypes.Layout, origin: CFrame, parent: Instance): Folder
	local folder = Instance.new("Folder")
	folder.Name = OfficeDecorConstants.DECOR_FOLDER
	local start = OfficeLayoutUtils.room(layout, layout.startRoom)
	if start ~= nil then
		for _, door in layout.doors do
			if door.a == layout.startRoom or door.b == layout.startRoom then
				local edge = OfficeLayoutUtils.doorEdge(start, door)
				local turn = if edge == "minX" or edge == "maxX" then CFrame.Angles(0, math.rad(90), 0) else CFrame.identity
				exitSign(origin * CFrame.new(door.x, OfficeDecorConstants.EXIT_SIGN_HEIGHT, door.z) * turn, folder)
			end
		end
	end
	local lift = OfficeDecorConstants.EMITTER_LIFT
	for index, desk in OfficeLayoutUtils.markersOf(layout, "desk") do
		local deskTop = origin * CFrame.new(desk.x, OfficeConstants.DESK_SIZE.Y, desk.z)
		monitor(deskTop, folder)
		emitter("phone", (deskTop * CFrame.new(1.5, lift, 0)).Position, folder)
		if index % OfficeDecorConstants.TYPING_EVERY == 1 then
			emitter("typing", (deskTop * CFrame.new(-1, lift, 0)).Position, folder)
		end
	end
	elevator(origin, folder)
	folder.Parent = parent
	return folder
end

return OfficeDecorSystem
```

- [ ] **Step 5: Build it.** In `src/ServerScriptService/Features/Office/OfficeServiceServer.luau`:
  - Require `local OfficeDecorSystem = require(OfficeServer.Systems.OfficeDecorSystem)` after the `OfficeBuildSystem` require.
  - In `start`, replace `built = OfficeBuildSystem.build(LAYOUT, OfficeConstants.ORIGIN)` with:

```lua
		local current = OfficeBuildSystem.build(LAYOUT, OfficeConstants.ORIGIN)
		built = current
		-- The office at night (exit signs, blue monitors, the elevator, ambience emitters), once.
		OfficeDecorSystem.build(LAYOUT, OfficeConstants.ORIGIN, current.model)
```
  - Header comment: after "builds the static graybox once (OfficeBuildSystem)", add ", then its night decor (OfficeDecorSystem)".

- [ ] **Step 6: Client constants** `src/ReplicatedStorage/Client/Features/Office/Data/OfficeAtmosphereConstants.luau`:

```lua
--!strict
--[=[
	OfficeAtmosphereConstants: the office's look and dread on the client (Cleanup Crew spec §7 "The office at
	night: dim, buzzing fluorescents (some flickering) …"; "Overtime: lighting shifts dim red"; ambient dread). The
	atmosphere presets (registered with Vfx at load by OfficeAtmosphereSystem), the overtime tint and light colour,
	the broken fluorescents' share, reach and blink, and the ambience timing. Every number is a tuning hypothesis.
	Static data (spec-exempt).

	@class OfficeAtmosphereConstants
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local VfxTypes = require(ReplicatedStorage.Shared.Features.Vfx.Data.VfxTypes)

local PRESETS: { [string]: VfxTypes.Atmosphere } = {
	officeNight = {
		clockTime = 0,
		brightness = 0.6,
		exposure = -0.2,
		ambient = Color3.fromRGB(40, 44, 58),
		outdoorAmbient = Color3.fromRGB(22, 24, 34),
		fogColor = Color3.fromRGB(10, 12, 18),
		fogStart = 60,
		fogEnd = 260,
	},
	officeTier1 = {
		clockTime = 0,
		brightness = 0.5,
		exposure = -0.3,
		ambient = Color3.fromRGB(34, 36, 50),
		outdoorAmbient = Color3.fromRGB(18, 20, 28),
		fogColor = Color3.fromRGB(8, 9, 14),
		fogStart = 50,
		fogEnd = 220,
	},
	officeTier2 = {
		clockTime = 0,
		brightness = 0.4,
		exposure = -0.4,
		ambient = Color3.fromRGB(28, 28, 42),
		outdoorAmbient = Color3.fromRGB(14, 14, 22),
		fogColor = Color3.fromRGB(6, 6, 10),
		fogStart = 40,
		fogEnd = 180,
	},
	officeBreak = {
		clockTime = 0,
		brightness = 0.65,
		exposure = -0.15,
		ambient = Color3.fromRGB(48, 50, 62),
		outdoorAmbient = Color3.fromRGB(24, 26, 36),
		fogColor = Color3.fromRGB(12, 14, 20),
		fogStart = 70,
		fogEnd = 280,
	},
	officeOvertime = {
		clockTime = 0,
		brightness = 0.35,
		exposure = -0.45,
		ambient = Color3.fromRGB(78, 26, 26),
		outdoorAmbient = Color3.fromRGB(40, 12, 12),
		fogColor = Color3.fromRGB(28, 6, 6),
		fogStart = 35,
		fogEnd = 170,
	},
}

return table.freeze({
	PRESETS = table.freeze(PRESETS),
	NIGHT = "officeNight",
	TIER1 = "officeTier1",
	TIER2 = "officeTier2",
	BREAK = "officeBreak",
	OVERTIME = "officeOvertime",
	-- Seconds to blend between presets.
	FADE = 3,
	-- Overtime: a red, slightly drained screen and red ceiling lights.
	OVERTIME_TINT = Color3.fromRGB(255, 185, 185),
	OVERTIME_SATURATION = -0.2,
	OVERTIME_LIGHT_COLOR = Color3.fromRGB(255, 95, 80),
	-- The fluorescent hum's ambience slot.
	HUM_LAYER = "officeHum",
	-- Broken fluorescents: this share of the lights (stable per light), within this many studs of the camera,
	-- blink to BROKEN_DIM when their noise (at BROKEN_RATE) drops below BROKEN_THRESHOLD.
	BROKEN_FRACTION = 0.18,
	BROKEN_RADIUS = 80,
	BROKEN_RATE = 6,
	BROKEN_THRESHOLD = -0.3,
	BROKEN_DIM = 0.15,
	-- A blinking light's neon fades this far while dim.
	BROKEN_TRANSPARENCY = 0.6,
	ATMOSPHERE_INTERVAL = 0.05,
	-- Ambient dread (OfficeAmbienceSystem): phone and elevator waits, an "empty room" radius, when typing stops and
	-- how long it stays quiet, how often it re-checks.
	PHONE_MIN = 20,
	PHONE_MAX = 50,
	ELEVATOR_MIN = 50,
	ELEVATOR_MAX = 110,
	EMPTY_RADIUS = 28,
	TYPING_STOP_RADIUS = 20,
	TYPING_QUIET_SECONDS = 25,
	TYPING_FADE = 0.2,
	AMBIENCE_INTERVAL = 0.25,
})
```

- [ ] **Step 7: Atmosphere rules** `src/ReplicatedStorage/Client/Features/Office/Utils/OfficeAtmosphereUtils.luau`:

```lua
--!strict
--[=[
	OfficeAtmosphereUtils: which atmosphere the office has (Cleanup Crew spec §7 "The office at night"; "Tier up";
	"Overtime: lighting shifts dim red"). Outside a shift (no snapshot, or the lobby) the place keeps its own
	lighting; from the arrival countdown through the results it is night; while running, each pressure tier darkens
	it a step, Harlow's break lifts it a little and overtime turns it dim red (and the lights red). The fluorescent
	hum plays whenever the office is in a shift. Pure.

	@class OfficeAtmosphereUtils
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ShiftTypes = require(ReplicatedStorage.Shared.Features.Shift.Data.ShiftTypes)
local OfficeAtmosphereConstants = require(ReplicatedStorage.Client.Features.Office.Data.OfficeAtmosphereConstants)

type ShiftSnapshot = ShiftTypes.ShiftSnapshot

local OfficeAtmosphereUtils = {}

function OfficeAtmosphereUtils.preset(snapshot: ShiftSnapshot?): string?
	if snapshot == nil or snapshot.phase == "lobby" then
		return nil
	end
	if snapshot.phase ~= "running" then
		return OfficeAtmosphereConstants.NIGHT
	end
	if snapshot.stage == "overtime" then
		return OfficeAtmosphereConstants.OVERTIME
	end
	if snapshot.stage == "break" then
		return OfficeAtmosphereConstants.BREAK
	end
	if snapshot.tier >= 2 then
		return OfficeAtmosphereConstants.TIER2
	end
	if snapshot.tier >= 1 then
		return OfficeAtmosphereConstants.TIER1
	end
	return OfficeAtmosphereConstants.NIGHT
end

function OfficeAtmosphereUtils.overtime(snapshot: ShiftSnapshot?): boolean
	return snapshot ~= nil and snapshot.phase == "running" and snapshot.stage == "overtime"
end

function OfficeAtmosphereUtils.hum(snapshot: ShiftSnapshot?): boolean
	return snapshot ~= nil and snapshot.phase ~= "lobby"
end

return OfficeAtmosphereUtils
```

- [ ] **Step 8: Light rules** `src/ReplicatedStorage/Client/Features/Office/Utils/OfficeLightUtils.luau`:

```lua
--!strict
--[=[
	OfficeLightUtils: the broken fluorescents (Cleanup Crew spec §7 "dim, buzzing fluorescents (some flickering)").
	A light is broken by a stable hash of where it hangs (lights never move), so every client and every shift
	agrees; only broken lights within a radius of the camera are animated; a broken light is full most of the time
	and blinks dim when its noise dips (a slow, irregular blink, distinct from the fast flicker that means Harlow is
	near). Pure.

	@class OfficeLightUtils
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local OfficeAtmosphereConstants = require(ReplicatedStorage.Client.Features.Office.Data.OfficeAtmosphereConstants)

local OfficeLightUtils = {}

--[=[
	A stable 0..1 value for a light's position.
]=]
function OfficeLightUtils.hash(position: Vector3): number
	local value = math.sin(position.X * 12.9898 + position.Z * 78.233) * 43758.5453
	return value - math.floor(value)
end

function OfficeLightUtils.broken(position: Vector3, fraction: number): boolean
	return OfficeLightUtils.hash(position) < fraction
end

--[=[
	The indices of the broken lights within `radius` of `center`, in order.
]=]
function OfficeLightUtils.nearbyBroken(
	positions: { Vector3 },
	center: Vector3,
	radius: number,
	fraction: number
): { number }
	local list: { number } = {}
	for index, position in positions do
		if (position - center).Magnitude <= radius and OfficeLightUtils.broken(position, fraction) then
			table.insert(list, index)
		end
	end
	return list
end

--[=[
	A broken light's brightness factor at `now`: 1, or BROKEN_DIM while its noise is below BROKEN_THRESHOLD.
]=]
function OfficeLightUtils.glow(now: number, seed: number): number
	local noise = math.noise(now * OfficeAtmosphereConstants.BROKEN_RATE, seed * 7.31)
	if noise < OfficeAtmosphereConstants.BROKEN_THRESHOLD then
		return OfficeAtmosphereConstants.BROKEN_DIM
	end
	return 1
end

return OfficeLightUtils
```

- [ ] **Step 9: Sound slots** `src/ReplicatedStorage/Client/Features/Office/Data/OfficeAssets.luau`:

```lua
--!strict
--[=[
	OfficeAssets: every asset id the Office feature uses (Cleanup Crew spec §7: "Asset id literals live only in each
	feature's Data/<Feature>Assets"): the fluorescent hum, a broken light's zap, and the ambient dread (a phone
	ringing, the elevator's ding, typing). Client-only: nothing on the server plays them. An id is PENDING ("")
	until the developer uploads the staged file (the M3 plan's "Asset staging" appendix); a pending sound is never
	registered, so playing it is silent. Registers the uploaded sounds at load (guarded).

	Static data + registration (spec-exempt).

	@class OfficeAssets
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SoundRegistry = require(ReplicatedStorage.Shared.Features.Sound.Data.SoundRegistry)
local SoundTypes = require(ReplicatedStorage.Shared.Features.Sound.Data.SoundTypes)

local PENDING = ""

local SOUNDS: { [string]: SoundTypes.SoundDef } = {
	-- Buzzing fluorescent tubes under everything (looped ambience).
	officeHum = { assetId = PENDING, group = "Ambient", volume = 0.35, looped = true },
	-- A broken tube's electric zap as it blinks.
	officeLightZap = { assetId = PENDING, group = "SFX", volume = 0.4, rollOffMaxDistance = 30, maxConcurrent = 2 },
	-- An old office phone ringing in an empty room.
	officePhoneRing = { assetId = PENDING, group = "Ambient", volume = 0.7, rollOffMaxDistance = 70, maxConcurrent = 1 },
	-- An elevator's ding, nobody inside.
	officeElevatorDing = { assetId = PENDING, group = "Ambient", volume = 0.7, rollOffMaxDistance = 90, maxConcurrent = 1 },
	-- Someone typing (looped); it stops when you come close.
	officeTyping = { assetId = PENDING, group = "Ambient", volume = 0.5, looped = true, rollOffMaxDistance = 35 },
}

for id, def in SOUNDS do
	if def.assetId ~= PENDING and not SoundRegistry.has(id) then
		SoundRegistry.register(id, def)
	end
end

return table.freeze({
	PENDING = PENDING,
	SOUNDS = table.freeze(SOUNDS),
	HUM = "officeHum",
	ZAP = "officeLightZap",
	PHONE = "officePhoneRing",
	ELEVATOR = "officeElevatorDing",
	TYPING = "officeTyping",
})
```

- [ ] **Step 10: Atmosphere system** `src/ReplicatedStorage/Client/Features/Office/Systems/OfficeAtmosphereSystem.luau`:

```lua
--!strict
--[=[
	OfficeAtmosphereSystem: the office's light and air on this client (Cleanup Crew spec §7 "The office at night:
	dim, buzzing fluorescents (some flickering)"; "Overtime: lighting shifts dim red"). Follows ShiftStore's
	snapshot: blends Lighting to OfficeAtmosphereUtils.preset (night, darker per tier, lighter on Harlow's break,
	dim red in overtime; the place's own lighting outside a shift); in overtime a red screen tint and red ceiling
	lights; the fluorescent hum while the office is in a shift. Every ATMOSPHERE_INTERVAL the broken lights near the
	camera (OfficeLightUtils) blink, with a zap as each dims. It changes only a light's Color, Transparency and
	PointLight Color/Brightness; M2's OccupantTellSystem owns Material and PointLight.Enabled, so the two compose.
	Registers the office presets with Vfx at load. Pending sounds (OfficeAssets) are silent.

	Spec-exempt shell (Lighting via Vfx, Instances, Sound, Charm, RunService); the choices are the specced
	OfficeAtmosphereUtils and OfficeLightUtils.

	@class OfficeAtmosphereSystem
]=]

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local OfficeClient = ReplicatedStorage.Client.Features.Office
local Charm = require(ReplicatedStorage.Packages.Charm)
local OccupantConstants = require(ReplicatedStorage.Shared.Features.Occupant.Data.OccupantConstants)
local ShiftTypes = require(ReplicatedStorage.Shared.Features.Shift.Data.ShiftTypes)
local SoundRegistry = require(ReplicatedStorage.Shared.Features.Sound.Data.SoundRegistry)
local VfxAtmosphereRegistry = require(ReplicatedStorage.Shared.Features.Vfx.Data.VfxAtmosphereRegistry)
local OfficeAssets = require(OfficeClient.Data.OfficeAssets)
local OfficeAtmosphereConstants = require(OfficeClient.Data.OfficeAtmosphereConstants)
local OfficeAtmosphereUtils = require(OfficeClient.Utils.OfficeAtmosphereUtils)
local OfficeLightUtils = require(OfficeClient.Utils.OfficeLightUtils)
local ShiftStore = require(ReplicatedStorage.Client.Features.Shift.State.ShiftStore)
local SoundServiceClient = require(ReplicatedStorage.Client.Features.Sound.SoundServiceClient)
local VfxServiceClient = require(ReplicatedStorage.Client.Features.Vfx.VfxServiceClient)

-- Registered at load: setAtmosphere refuses an unknown preset.
for id, preset in OfficeAtmosphereConstants.PRESETS do
	if not VfxAtmosphereRegistry.has(id) then
		VfxAtmosphereRegistry.register(id, preset)
	end
end

type LightBase = {
	color: Color3,
	brightness: number,
	transparency: number,
}

-- Each light's own look (captured the first time this client touches it), and which are dimmed now.
local bases: { [BasePart]: LightBase } = {}
setmetatable(bases, { __mode = "k" })
local dimmed: { [BasePart]: boolean } = {}
setmetatable(dimmed, { __mode = "k" })

local applied = false
local currentPreset: string? = nil
local overtimeOn = false
local overtimeToken: number? = nil
local humOn = false
local stoppers: { () -> () } = {}
local counters = { presets = 0, zaps = 0, pending = 0 }

local function baseOf(light: BasePart): LightBase
	local existing = bases[light]
	if existing ~= nil then
		return existing
	end
	local point = light:FindFirstChildOfClass("PointLight")
	local created: LightBase = {
		color = light.Color,
		brightness = if point ~= nil then point.Brightness else 0,
		transparency = light.Transparency,
	}
	bases[light] = created
	return created
end

local function lights(): { BasePart }
	local list: { BasePart } = {}
	for _, instance in CollectionService:GetTagged(OccupantConstants.LIGHT_TAG) do
		if instance:IsA("BasePart") then
			table.insert(list, instance)
		end
	end
	return list
end

local function paint(light: BasePart, red: boolean)
	local color = if red then OfficeAtmosphereConstants.OVERTIME_LIGHT_COLOR else baseOf(light).color
	light.Color = color
	local point = light:FindFirstChildOfClass("PointLight")
	if point ~= nil then
		point.Color = color
	end
end

local function setOvertime(on: boolean)
	if on == overtimeOn then
		return
	end
	overtimeOn = on
	for _, light in lights() do
		paint(light, on)
	end
	local token = overtimeToken
	if on and token == nil then
		overtimeToken = VfxServiceClient:requestScreen({
			tint = OfficeAtmosphereConstants.OVERTIME_TINT,
			saturation = OfficeAtmosphereConstants.OVERTIME_SATURATION,
		})
	elseif not on and token ~= nil then
		VfxServiceClient:releaseScreen(token)
		overtimeToken = nil
	end
end

local function setHum(on: boolean)
	if on == humOn then
		return
	end
	humOn = on
	if not on then
		SoundServiceClient:setAmbience(OfficeAtmosphereConstants.HUM_LAYER, nil)
	elseif SoundRegistry.has(OfficeAssets.HUM) then
		SoundServiceClient:setAmbience(OfficeAtmosphereConstants.HUM_LAYER, OfficeAssets.HUM)
	else
		counters.pending += 1
	end
end

local function onSnapshot(snapshot: ShiftTypes.ShiftSnapshot?)
	local preset = OfficeAtmosphereUtils.preset(snapshot)
	if not applied or preset ~= currentPreset then
		applied = true
		currentPreset = preset
		counters.presets += 1
		VfxServiceClient:setAtmosphere(preset, OfficeAtmosphereConstants.FADE)
	end
	setOvertime(OfficeAtmosphereUtils.overtime(snapshot))
	setHum(OfficeAtmosphereUtils.hum(snapshot))
end

local function restore(light: BasePart)
	local base = baseOf(light)
	light.Transparency = base.transparency
	local point = light:FindFirstChildOfClass("PointLight")
	if point ~= nil then
		point.Brightness = base.brightness
	end
end

-- The broken lights near the camera blink; any that left the radius are restored.
local function stepBroken()
	local camera = Workspace.CurrentCamera
	if camera == nil then
		return
	end
	local now = os.clock()
	local list = lights()
	local positions: { Vector3 } = {}
	for index, light in list do
		positions[index] = light.Position
	end
	local near: { [BasePart]: boolean } = {}
	local center = camera.CFrame.Position
	local radius = OfficeAtmosphereConstants.BROKEN_RADIUS
	for _, index in OfficeLightUtils.nearbyBroken(positions, center, radius, OfficeAtmosphereConstants.BROKEN_FRACTION) do
		local light = list[index]
		near[light] = true
		local base = baseOf(light)
		local factor = OfficeLightUtils.glow(now, OfficeLightUtils.hash(light.Position) * 100)
		local dim = factor < 1
		local point = light:FindFirstChildOfClass("PointLight")
		if point ~= nil then
			point.Brightness = base.brightness * factor
		end
		light.Transparency = if dim then OfficeAtmosphereConstants.BROKEN_TRANSPARENCY else base.transparency
		if dim and not dimmed[light] then
			counters.zaps += 1
			if SoundRegistry.has(OfficeAssets.ZAP) then
				SoundServiceClient:play(OfficeAssets.ZAP, { at = light })
			else
				counters.pending += 1
			end
		end
		dimmed[light] = dim
	end
	for light in dimmed do
		if not near[light] then
			restore(light)
			dimmed[light] = nil
		end
	end
end

local OfficeAtmosphereSystem = {}

function OfficeAtmosphereSystem.start()
	if #stoppers > 0 then
		return
	end
	onSnapshot(ShiftStore.snapshot())
	table.insert(stoppers, Charm.subscribe(ShiftStore.snapshot, onSnapshot))
	local elapsed = 0
	local connection = RunService.Heartbeat:Connect(function(deltaTime: number)
		elapsed += deltaTime
		if elapsed >= OfficeAtmosphereConstants.ATMOSPHERE_INTERVAL then
			elapsed = 0
			stepBroken()
		end
	end)
	table.insert(stoppers, function()
		connection:Disconnect()
	end)
end

function OfficeAtmosphereSystem.stop()
	for _, stop in stoppers do
		stop()
	end
	table.clear(stoppers)
	for light in dimmed do
		restore(light)
	end
	table.clear(dimmed)
	setOvertime(false)
	setHum(false)
	VfxServiceClient:setAtmosphere(nil, 0)
	applied = false
	currentPreset = nil
end

function OfficeAtmosphereSystem.getState(): { [string]: any }
	local blinking = 0
	for _, dim in dimmed do
		if dim then
			blinking += 1
		end
	end
	return {
		preset = currentPreset or "place",
		overtime = overtimeOn,
		hum = humOn,
		dimNow = blinking,
		counters = table.clone(counters),
	}
end

return OfficeAtmosphereSystem
```

- [ ] **Step 11: Client service** `src/ReplicatedStorage/Client/Features/Office/OfficeServiceClient.luau`:

```lua
--!strict
--[=[
	OfficeServiceClient: the Harlow & Finch office on this client (Cleanup Crew spec §6.2 "Office: … atmosphere
	presets"; §7 "The office at night"). Starts OfficeAtmosphereSystem (presets per phase and tier, overtime red,
	broken fluorescents, the hum). Everything it does is client-local presentation; the office itself is the
	server's.

	Spec-exempt shell (starts the systems).

	@class OfficeServiceClient
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local OfficeAtmosphereSystem = require(ReplicatedStorage.Client.Features.Office.Systems.OfficeAtmosphereSystem)

export type OfficeServiceClient = {
	dependencies: { string },
	start: (self: OfficeServiceClient) -> (),
	stop: (self: OfficeServiceClient) -> (),
	getState: (self: OfficeServiceClient) -> { [string]: any },
}

local OfficeServiceClient: OfficeServiceClient = {
	dependencies = { "StateSyncServiceClient", "SoundServiceClient", "VfxServiceClient" },

	start = function(_self)
		OfficeAtmosphereSystem.start()
	end,

	stop = function(_self)
		OfficeAtmosphereSystem.stop()
	end,

	getState = function(_self)
		return { atmosphere = OfficeAtmosphereSystem.getState() }
	end,
}

return OfficeServiceClient
```

- [ ] **Step 12: Exemptions.** Under `-- Cleanup Crew: Office`, add:

```lua
	["ReplicatedStorage.Shared.Features.Office.Data.OfficeDecorConstants"] = "static decor look and emitter names (no logic)",
	["ServerScriptService.Features.Office.Systems.OfficeDecorSystem"] = "Instance builder (night decor and ambience emitters from the validated layout)",
	["ReplicatedStorage.Client.Features.Office.OfficeServiceClient"] = "client service shell (starts the atmosphere and ambience systems)",
	["ReplicatedStorage.Client.Features.Office.Data.OfficeAssets"] = "asset id slots; registers the uploaded sounds at load (no decisions)",
	["ReplicatedStorage.Client.Features.Office.Data.OfficeAtmosphereConstants"] = "static presets and timing (no logic)",
	["ReplicatedStorage.Client.Features.Office.Systems.OfficeAtmosphereSystem"] = "Lighting/Instance/Sound/Charm shell (choices specced in OfficeAtmosphereUtils, OfficeLightUtils)",
```

- [ ] **Step 13: Module map, format and gate** (Global Constraints order). Expected: `==> All checks passed.` (The module map gains an Office shared and client realm.)

- [ ] **Step 14: Controller: Studio TestEZ.** Expected: OfficeAtmosphereUtils and OfficeLightUtils pass; OfficeLayoutRules still passes (the decor does not touch the layout).

- [ ] **Step 15: Controller: Studio verification** (Play Solo, `RunTests = false`; Task 1's server Script; a client LocalScript printing `require(game.ReplicatedStorage.Client.Features.Office.OfficeServiceClient):getState().atmosphere` every second). Checklist (screenshots of 1, 2, 4, 5):
1. In the lobby phase (before the countdown) Lighting is the place's own (`preset = place`). From the arrival countdown the office goes dark blue-grey night over ~3 s (`preset = officeNight`).
2. The loading bay's doorways have glowing green EXIT signs (readable both sides); every desk has a monitor with a glowing blue screen; reception's west wall has steel elevator doors under an amber lamp. None of it blocks walking, vacuum aim, item drops or Harlow's paths.
3. At 2:00 / 4:00 the office darkens a step (`officeTier1`, `officeTier2`).
4. Quota met → break: a little lighter (`officeBreak`); overtime: dim red atmosphere, red ceiling lights and a red-tinted screen (`overtime = true`).
5. Walk around: some ceiling lights (about one in six) blink dim irregularly and recover (`dimNow` > 0 at times); Harlow's fast flicker near him still works on top; after a catch the lights-out still darkens them.
6. Results: back to night, lights white, no tint, `overtime = false`. `_G.S:resetShift()` mid-overtime: the same, then night again for the next shift.
7. Output: no "unknown atmosphere", no "unknown sound" warning with every id pending.

- [ ] **Step 16: Commit**

```bash
git commit -m "feat(office): night decor, atmosphere per phase and tier, overtime red, broken fluorescents"
python3 scripts/python/module_map.py --check
```

---
### Task 9: Ambient dread (phones in empty rooms, the elevator, typing that stops)

**Files:**
- Create: `src/ReplicatedStorage/Client/Features/Office/Utils/OfficeAmbienceUtils.luau` (+ `OfficeAmbienceUtils.spec.luau`)
- Create: `src/ReplicatedStorage/Client/Features/Office/Systems/OfficeAmbienceSystem.luau`
- Modify: `src/ReplicatedStorage/Client/Features/Office/OfficeServiceClient.luau`
- Modify: `src/ServerScriptService/Core/Testing/SpecRoots.luau`

**Interfaces:**
- Consumes: Task 8's emitters (parts tagged `OfficeDecorConstants.AMBIENT_TAG` with the string attribute `AMBIENT_KIND_ATTRIBUTE` = "phone" | "typing" | "elevator"); `OfficeAtmosphereConstants.PHONE_MIN / PHONE_MAX / ELEVATOR_MIN / ELEVATOR_MAX / EMPTY_RADIUS / TYPING_STOP_RADIUS / TYPING_QUIET_SECONDS / TYPING_FADE / AMBIENCE_INTERVAL`; `OfficeAssets.PHONE / ELEVATOR / TYPING`; `ShiftStore.snapshot` (phase).
- Produces (OfficeAmbienceUtils): `type Emitter = { kind: string, position: Vector3 }`; `empty(position: Vector3, crew: { Vector3 }, radius: number) -> boolean`; `pick(emitters: { Emitter }, kind: string, crew: { Vector3 }, radius: number, roll: number) -> number?`; `typingStops(distance: number, radius: number) -> boolean`; `delay(roll: number, min: number, max: number) -> number`.
- Produces (OfficeAmbienceSystem, client module-level): `start()`, `stop()`, `getState()`.

- [ ] **Step 1: Write the failing spec** `src/ReplicatedStorage/Client/Features/Office/Utils/OfficeAmbienceUtils.spec.luau`:

```lua
local OfficeAmbienceUtils = require(script.Parent.OfficeAmbienceUtils)

local EMITTERS = {
	{ kind = "phone", position = Vector3.new(0, 0, 0) },
	{ kind = "typing", position = Vector3.new(5, 0, 0) },
	{ kind = "phone", position = Vector3.new(100, 0, 0) },
	{ kind = "elevator", position = Vector3.new(0, 0, 200) },
}

return function()
	describe("empty", function()
		it("is empty when nobody is within the radius", function()
			expect(OfficeAmbienceUtils.empty(Vector3.zero, { Vector3.new(40, 0, 0) }, 28)).to.equal(true)
			expect(OfficeAmbienceUtils.empty(Vector3.zero, { Vector3.new(40, 0, 0), Vector3.new(10, 0, 0) }, 28)).to.equal(false)
			expect(OfficeAmbienceUtils.empty(Vector3.zero, {}, 28)).to.equal(true)
		end)
	end)

	describe("pick", function()
		it("rings a phone only in an empty room", function()
			local crew = { Vector3.new(2, 0, 0) }
			expect(OfficeAmbienceUtils.pick(EMITTERS, "phone", crew, 28, 0)).to.equal(3)
			expect(OfficeAmbienceUtils.pick(EMITTERS, "phone", crew, 28, 0.99)).to.equal(3)
		end)

		it("chooses among the empty ones by the roll", function()
			expect(OfficeAmbienceUtils.pick(EMITTERS, "phone", {}, 28, 0)).to.equal(1)
			expect(OfficeAmbienceUtils.pick(EMITTERS, "phone", {}, 28, 0.99)).to.equal(3)
		end)

		it("rings nothing when every room of that kind has someone in it", function()
			local crew = { Vector3.new(0, 0, 0), Vector3.new(100, 0, 0) }
			expect(OfficeAmbienceUtils.pick(EMITTERS, "phone", crew, 28, 0.5)).to.equal(nil)
			expect(OfficeAmbienceUtils.pick(EMITTERS, "fax", {}, 28, 0.5)).to.equal(nil)
		end)
	end)

	describe("typingStops", function()
		it("stops the typing when you come within the radius", function()
			expect(OfficeAmbienceUtils.typingStops(19, 20)).to.equal(true)
			expect(OfficeAmbienceUtils.typingStops(20, 20)).to.equal(true)
			expect(OfficeAmbienceUtils.typingStops(21, 20)).to.equal(false)
		end)
	end)

	describe("delay", function()
		it("waits between the minimum and the maximum", function()
			expect(OfficeAmbienceUtils.delay(0, 20, 50)).to.equal(20)
			expect(OfficeAmbienceUtils.delay(1, 20, 50)).to.equal(50)
			expect(OfficeAmbienceUtils.delay(0.5, 20, 50)).to.equal(35)
			expect(OfficeAmbienceUtils.delay(7, 20, 50)).to.equal(50)
		end)
	end)
end
```

- [ ] **Step 2: Controller: Studio TestEZ.** Expected: the spec errors (module missing).

- [ ] **Step 3: Utils** `src/ReplicatedStorage/Client/Features/Office/Utils/OfficeAmbienceUtils.luau`:

```lua
--!strict
--[=[
	OfficeAmbienceUtils: the ambient dread's choices (Cleanup Crew spec §7 "phones ringing in empty rooms, an
	elevator dinging on its own, typing that stops when you enter"). A spot is empty when no crew member is within
	the radius; a phone (or the elevator) is picked by roll among the empty spots of its kind; typing stops when
	you come within its radius; the wait before the next one is a roll between a minimum and a maximum. Pure.

	@class OfficeAmbienceUtils
]=]

export type Emitter = {
	kind: string,
	position: Vector3,
}

local OfficeAmbienceUtils = {}

function OfficeAmbienceUtils.empty(position: Vector3, crew: { Vector3 }, radius: number): boolean
	for _, member in crew do
		if (member - position).Magnitude <= radius then
			return false
		end
	end
	return true
end

--[=[
	The index of the emitter of `kind` to play, chosen by `roll` (0..1) among the empty ones; nil when none.
]=]
function OfficeAmbienceUtils.pick(
	emitters: { Emitter },
	kind: string,
	crew: { Vector3 },
	radius: number,
	roll: number
): number?
	local eligible: { number } = {}
	for index, emitter in emitters do
		if emitter.kind == kind and OfficeAmbienceUtils.empty(emitter.position, crew, radius) then
			table.insert(eligible, index)
		end
	end
	if #eligible == 0 then
		return nil
	end
	return eligible[math.clamp(math.floor(math.clamp(roll, 0, 1) * #eligible) + 1, 1, #eligible)]
end

function OfficeAmbienceUtils.typingStops(distance: number, radius: number): boolean
	return distance <= radius
end

function OfficeAmbienceUtils.delay(roll: number, min: number, max: number): number
	return min + (max - min) * math.clamp(roll, 0, 1)
end

return OfficeAmbienceUtils
```

- [ ] **Step 4: System** `src/ReplicatedStorage/Client/Features/Office/Systems/OfficeAmbienceSystem.luau`:

```lua
--!strict
--[=[
	OfficeAmbienceSystem: the ambient dread on this client (Cleanup Crew spec §7 "Ambient dread: phones ringing in
	empty rooms, an elevator dinging on its own, typing that stops when you enter"). While a shift runs, every
	AMBIENCE_INTERVAL: when the phone's wait is up, a phone rings on a desk with nobody near it (OfficeAmbienceUtils
	.pick over the OfficeAmbient emitters); the elevator dings on the same rule on its own wait; each typist types
	(a loop) while nobody is near and stops the moment you come within TYPING_STOP_RADIUS, staying quiet
	TYPING_QUIET_SECONDS. Per client, no packets: each player hears their own office. Pending sounds (OfficeAssets)
	are skipped silently and counted.

	Spec-exempt shell (Sound, Instances, RunService); the choices are the specced OfficeAmbienceUtils.

	@class OfficeAmbienceSystem
]=]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local OfficeClient = ReplicatedStorage.Client.Features.Office
local OfficeDecorConstants = require(ReplicatedStorage.Shared.Features.Office.Data.OfficeDecorConstants)
local SoundRegistry = require(ReplicatedStorage.Shared.Features.Sound.Data.SoundRegistry)
local OfficeAssets = require(OfficeClient.Data.OfficeAssets)
local OfficeAtmosphereConstants = require(OfficeClient.Data.OfficeAtmosphereConstants)
local OfficeAmbienceUtils = require(OfficeClient.Utils.OfficeAmbienceUtils)
local ShiftStore = require(ReplicatedStorage.Client.Features.Shift.State.ShiftStore)
local SoundServiceClient = require(ReplicatedStorage.Client.Features.Sound.SoundServiceClient)

type Typist = {
	handle: SoundServiceClient.SoundHandle?,
	quietUntil: number,
}

local typists: { [BasePart]: Typist } = {}
setmetatable(typists, { __mode = "k" })
local rng = Random.new()
local nextPhone = 0
local nextElevator = 0
local connection: RBXScriptConnection? = nil
local counters = { phones = 0, elevators = 0, typingStarts = 0, typingStops = 0, pending = 0 }

local function play(id: string, at: BasePart): SoundServiceClient.SoundHandle?
	if not SoundRegistry.has(id) then
		counters.pending += 1
		return nil
	end
	return SoundServiceClient:play(id, { at = at })
end

local function emitters(): ({ OfficeAmbienceUtils.Emitter }, { BasePart })
	local list: { OfficeAmbienceUtils.Emitter } = {}
	local parts: { BasePart } = {}
	for _, instance in CollectionService:GetTagged(OfficeDecorConstants.AMBIENT_TAG) do
		local kind = instance:GetAttribute(OfficeDecorConstants.AMBIENT_KIND_ATTRIBUTE)
		if instance:IsA("BasePart") and type(kind) == "string" then
			table.insert(list, { kind = kind, position = instance.Position })
			table.insert(parts, instance)
		end
	end
	return list, parts
end

local function crew(): { Vector3 }
	local positions: { Vector3 } = {}
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local root = if character ~= nil then character:FindFirstChild("HumanoidRootPart") else nil
		if root ~= nil and root:IsA("BasePart") then
			table.insert(positions, root.Position)
		end
	end
	return positions
end

local function silence(typist: Typist)
	local handle = typist.handle
	if handle ~= nil then
		handle:stop(OfficeAtmosphereConstants.TYPING_FADE)
		counters.typingStops += 1
	end
	typist.handle = nil
end

local function silenceAll()
	for _, typist in typists do
		silence(typist)
	end
end

local function schedule(now: number)
	local constants = OfficeAtmosphereConstants
	nextPhone = now + OfficeAmbienceUtils.delay(rng:NextNumber(), constants.PHONE_MIN, constants.PHONE_MAX)
	nextElevator = now + OfficeAmbienceUtils.delay(rng:NextNumber(), constants.ELEVATOR_MIN, constants.ELEVATOR_MAX)
end

local function ring(kind: string, id: string, list: { OfficeAmbienceUtils.Emitter }, parts: { BasePart }, positions: { Vector3 }): boolean
	local index = OfficeAmbienceUtils.pick(list, kind, positions, OfficeAtmosphereConstants.EMPTY_RADIUS, rng:NextNumber())
	if index == nil then
		return false
	end
	play(id, parts[index])
	return true
end

local function stepTypists(list: { OfficeAmbienceUtils.Emitter }, parts: { BasePart }, positions: { Vector3 }, now: number)
	local character = Players.LocalPlayer.Character
	local root = if character ~= nil then character:FindFirstChild("HumanoidRootPart") else nil
	local me = if root ~= nil and root:IsA("BasePart") then root.Position else nil
	for index, emitter in list do
		if emitter.kind == "typing" then
			local part = parts[index]
			local typist = typists[part]
			if typist == nil then
				typist = { handle = nil, quietUntil = 0 }
				typists[part] = typist
			end
			local distance = if me ~= nil then (me - emitter.position).Magnitude else math.huge
			if OfficeAmbienceUtils.typingStops(distance, OfficeAtmosphereConstants.TYPING_STOP_RADIUS) then
				silence(typist)
				typist.quietUntil = now + OfficeAtmosphereConstants.TYPING_QUIET_SECONDS
			elseif
				typist.handle == nil
				and now >= typist.quietUntil
				and OfficeAmbienceUtils.empty(emitter.position, positions, OfficeAtmosphereConstants.EMPTY_RADIUS)
			then
				typist.handle = play(OfficeAssets.TYPING, part)
				if typist.handle ~= nil then
					counters.typingStarts += 1
				else
					-- Pending: do not retry every tick.
					typist.quietUntil = now + OfficeAtmosphereConstants.TYPING_QUIET_SECONDS
				end
			end
		end
	end
end

local function step()
	local now = os.clock()
	local snapshot = ShiftStore.snapshot()
	if snapshot == nil or snapshot.phase ~= "running" then
		silenceAll()
		schedule(now)
		return
	end
	local list, parts = emitters()
	local positions = crew()
	if now >= nextPhone then
		if ring("phone", OfficeAssets.PHONE, list, parts, positions) then
			counters.phones += 1
		end
		nextPhone = now
			+ OfficeAmbienceUtils.delay(rng:NextNumber(), OfficeAtmosphereConstants.PHONE_MIN, OfficeAtmosphereConstants.PHONE_MAX)
	end
	if now >= nextElevator then
		if ring("elevator", OfficeAssets.ELEVATOR, list, parts, positions) then
			counters.elevators += 1
		end
		nextElevator = now
			+ OfficeAmbienceUtils.delay(
				rng:NextNumber(),
				OfficeAtmosphereConstants.ELEVATOR_MIN,
				OfficeAtmosphereConstants.ELEVATOR_MAX
			)
	end
	stepTypists(list, parts, positions, now)
end

local OfficeAmbienceSystem = {}

function OfficeAmbienceSystem.start()
	if connection ~= nil then
		return
	end
	schedule(os.clock())
	local elapsed = 0
	connection = RunService.Heartbeat:Connect(function(deltaTime: number)
		elapsed += deltaTime
		if elapsed >= OfficeAtmosphereConstants.AMBIENCE_INTERVAL then
			elapsed = 0
			step()
		end
	end)
end

function OfficeAmbienceSystem.stop()
	local running = connection
	if running ~= nil then
		running:Disconnect()
		connection = nil
	end
	silenceAll()
	table.clear(typists)
end

function OfficeAmbienceSystem.getState(): { [string]: any }
	local typing = 0
	for _, typist in typists do
		if typist.handle ~= nil then
			typing += 1
		end
	end
	return { typing = typing, counters = table.clone(counters) }
end

return OfficeAmbienceSystem
```

- [ ] **Step 5: Wire it.** In `src/ReplicatedStorage/Client/Features/Office/OfficeServiceClient.luau`:
  - Require `local OfficeAmbienceSystem = require(ReplicatedStorage.Client.Features.Office.Systems.OfficeAmbienceSystem)`.
  - `start`: after `OfficeAtmosphereSystem.start()`, add `OfficeAmbienceSystem.start()`. `stop`: add `OfficeAmbienceSystem.stop()` before `OfficeAtmosphereSystem.stop()`.
  - `getState`: `return { atmosphere = OfficeAtmosphereSystem.getState(), ambience = OfficeAmbienceSystem.getState() }`.
  - Header comment: "… and OfficeAmbienceSystem (phones ringing in empty rooms, the elevator, typing that stops when you come close)."

- [ ] **Step 6: Exemption.** Under `-- Cleanup Crew: Office`, add:

```lua
	["ReplicatedStorage.Client.Features.Office.Systems.OfficeAmbienceSystem"] = "Sound/Instance/RunService shell (choices specced in OfficeAmbienceUtils)",
```

- [ ] **Step 7: Module map, format and gate** (Global Constraints order). Expected: `==> All checks passed.`

- [ ] **Step 8: Controller: Studio TestEZ.** Expected: OfficeAmbienceUtils passes.

- [ ] **Step 9: Controller: Studio verification** (Play Solo, `RunTests = false`; a client LocalScript printing `require(game.ReplicatedStorage.Client.Features.Office.OfficeServiceClient):getState().ambience` every 2 s; to hear it, register three test clips in that LocalScript from `search_asset` "office phone ring", "elevator ding", "keyboard typing loop" as `officePhoneRing`, `officeElevatorDing`, `officeTyping` (`looped = true`)). Checklist:
1. During a shift, within ~50 s a phone rings from a desk in a room you are not in (never the desk beside you); `phones` +1 each ring; the elevator dings in reception within ~2 min when nobody is in reception.
2. Typing is audible from the desks you are away from (`typing` ≥ 1); walk up to a typing desk: within a quarter second the typing stops and stays quiet for ~25 s even after you leave.
3. Results and the lobby: no phones, no typing (`typing = 0`).
4. With the ids pending (remove the test registrations): `pending` counts, nothing plays, no warnings.

- [ ] **Step 10: Commit**

```bash
git commit -m "feat(office): phones ringing in empty rooms, the elevator, typing that stops"
python3 scripts/python/module_map.py --check
```

---

### Task 10: Full-shift feel playtest, docs, PR update

**Files:**
- Modify: `docs/ROADMAP.md` (the "Games on this base" row)
- (Module map: already current from each task.)

**Interfaces:** none new.

- [ ] **Step 1: ROADMAP row.** In `docs/ROADMAP.md`, in the "Games on this base" table, append to the Cleanup Crew row's "Built so far" cell (after the M2 sentence and any M4 sentence, before "Spec: ..."):

```markdown
M3 feel (final UI screens wait for Figma approval): sticky-note and stamp toasts; shift horns, stings, overtime ticking and clock-out countdown (Shift); suction particles, rising whine, pop and sparkle, canister sounds (Vacuum); a faint ripple ring at the heard radius (Noise); banking swoop, cha-ching and "+N" floaters, drop/rattle/search sounds, the plant's leaves (Cargo); Harlow's footsteps, mutter, heartbeat, cues, chase music, typed gibberish voice, catch sting and stretched grin, and an animation domain with base fallbacks (Occupant); night decor, atmosphere per phase and tier, overtime red, broken fluorescents and ambient dread (Office). Every asset id is a pending slot in its feature's `Data/<Feature>Assets` until the developer uploads it.
```

- [ ] **Step 2: Gate**

```bash
python3 scripts/python/module_map.py --check
bash .superpowers/sdd/gate.sh
```
Expected: `==> All checks passed.`

- [ ] **Step 3: Commit**

```bash
git add docs/ROADMAP.md
git commit -m "docs: record Cleanup Crew M3 feel on the roadmap"
python3 scripts/python/module_map.py --check
```

- [ ] **Step 4: Controller: full TestEZ run in Studio** (`RunTests = true`). Expected: every spec passes; `assertAllModulesSpecced` and `assertAllSpecsCovered` pass.

- [ ] **Step 5: Controller: full-shift feel playtest** (Play Solo, `RunTests = false`, no helper scripts first; then once more with the free test clips registered from a client LocalScript and a server Script as in Tasks 2-9). MCP screenshots of each numbered moment; optionally a Qwen3-VL readability pass on them (local; not during a GPU-heavy job). Checklist:
1. **Every id pending:** arrival → night; the whole loop (vacuum, haul, bank, a chase, a catch, tiers, quota, break, overtime, clock out, results, Another shift) plays with all visuals and no sound; client and server Output have no "unknown sound", "unknown atmosphere", "unknown vfx recipe", "is not a …Assets sound", AnimationRegistry assert or error. Harlow animates with base clips.
2. Vacuum: dust streams into your hand, sparkle on clear, ripple rings at the heard radius.
3. Bank: the item swoops into the truck; "+N" floats (green clearance, blue bonus; ×1.5 in overtime); no "Loaded" toast.
4. Harlow: his bubble types out as a memo; footsteps and heartbeat counters run; the catch shows the grin over his face during the snap; lights die around him.
5. Pacing: QUOTA MET stamp + sticky; tier stickies with the office darkening a step; overtime stamp, red lights, red tint; clock-out ticks; results back to night.
6. **Another shift mid-feedback:** start Another shift while overtime is red and a pile is half-vacuumed: no red, no ticking, no leftover dust stream, leaves or grin; no canister chime; night resumes with the next arrival.
7. **With test clips registered:** the horn on quota, the ticking in overtime, the whine rising, the cha-ching, Harlow's footsteps through a wall, the chase music only while he chases you, gibberish on each voiced line, a phone ringing in an empty room, typing that stops as you approach.
8. Phone-size readability: a 375×812 screenshot of a sticky note, a stamp and a floater; text legible.

- [ ] **Step 6: Controller: update PR #3's description (never merge).**

```bash
git push origin game/cleanup-crew
gh pr view 3 --json body -q .body > "<scratchpad>/cc-pr-body.md"
cat >> "<scratchpad>/cc-pr-body.md" <<'EOF'

## M3: Feel (everything except the final UI screens)

Milestone M3 of docs/superpowers/specs/2026-10-10-cleanup-crew-design.md, minus the Figma-gated React screens (plan: overnight-handoff/2026-10-10-m3-cleanup-crew-feel.md).

- Toasts: Cleanup Crew's "sticky" and "stamp" styles (QUOTA MET, OVERTIME stamps; every other notice a sticky note).
- Shift: punch-in, truck horn, tier and overtime stings, an overtime ticking layer, clock-out horn and countdown ticks, camera kicks (ShiftCueUtils, specced; late joiners get no burst).
- Vacuum: suction particles into the hand, a whine rising with progress, pop + sparkle on clear (peak-progress rule), canister tick and chime.
- Noise: a faint ripple ring spreading to the heard radius (NoiseRippleFormulas).
- Cargo: a `Banked` announcement → swoop, cha-ching and "+N" floaters with the credited bonus (BankHandler now returns it); positional drop, rattle and search sounds; the office plant's leaves in front of the camera.
- Occupant: footsteps, mutter, heartbeat, "hm?", "!" sting, chase music (chased player only), sigh, typed memo bubble with varied lines and per-line gibberish; the catch sting and a cartoon stretched grin; an `occupant` animation domain (lurch walk, look-around, grab, throw) used only when uploaded.
- Office: exit signs, blue monitors, elevator doors; atmosphere per phase and tier, dim red overtime, broken fluorescents; phones in empty rooms, the elevator, typing that stops when you come close.
- Every asset id is a pending slot in its feature's Data/<Feature>Assets (silent/fallback until uploaded); staging prompts are in the plan's appendix. Nothing was uploaded.

Open questions: see the M3 plan's list (toast look pending Figma, clock-out countdown and Rehired card gated, lobby lighting, one standing clip, chase music scope, per-client ambience, floater split, broken-light share).

Verified: .superpowers/sdd/gate.sh green; TestEZ green in Studio; Studio checklists in Tasks 1-10 (solo).
EOF
gh pr edit 3 --body-file "<scratchpad>/cc-pr-body.md"
```
Replace `<scratchpad>` with the controller's scratchpad directory. Do not merge.

---

## Asset staging (controller, optional)

Not a code task and not part of any implementer's work. It produces files for the developer to review and upload; **no Roblox uploads here** (uploads are the developer's, through `publishing-roblox-assets`, owner = the personal account), **no paid services, no ElevenLabs, no TTS**. **Never run GPU jobs during a Studio playtest** (stop ComfyUI / MoMask before pressing Play; the Studio verification steps above assume a free GPU).

**Order of preference per sound** (spec §7 asset pipeline: "Creator Store first, else Stable Audio 3"): 1) a free Creator Store sound found with the Studio MCP `search_asset` (search terms below) and checked with `insert_asset` in an empty place; record its id and creator in `assets/sfx/creator-store.md` for the developer (a Creator Store sound needs no upload: the developer pastes its id into the slot after checking its licence); 2) else generate locally with Stable Audio 3 in `F:\AI\ComfyUI_windows_portable` through the `sourcing-roblox-sfx` skill (its QA gates: onset ≤ 20 ms unless noted, no hiss tail, loudness about −16 LUFS for SFX, −20 LUFS for loops and music, loops crossfaded so they do not pulse), exported as `.ogg` 44.1 kHz.

**Staging layout:** `assets/sfx/<feature>/<id>.ogg`, `assets/images/<name>.png`, `assets/anims/<id>.fbx` (+ the retargeted R15 `.rbxm` from the animation skill), each with a one-line `assets/README.md` entry: slot id, file, source (Creator Store id or generated + prompt + seed), length. Commit the staged files on the branch only if the developer wants them versioned (binary size); otherwise keep them local.

**Slot → id mapping:** after upload, the developer pastes `rbxassetid://<n>` into the slot named below (one-line edit in that `Data/<Feature>Assets`), syncs, and replays the matching Task's Studio checklist with no test registrations.

### Sounds

| Slot (module) | Creator Store search terms | Stable Audio 3 prompt (fallback) | Length |
|---|---|---|---|
| `shiftPunchIn` (ShiftAssets) | "punch clock", "time clock stamp" | "single mechanical punch clock card stamp, metallic ka-chunk, dry office room, no music" | 0.6 s |
| `shiftTruckHorn` | "truck horn", "box truck horn" | "single box truck horn blast, medium distance, slight parking garage echo" | 1.2 s |
| `shiftTierSting` | "horror sting low brass", "tension hit" | "short low brass swell with a dull thud, ominous, cartoon horror, kid friendly" | 1.5 s |
| `shiftWarningChime` | "office PA chime", "intercom chime" | "two-tone office intercom chime, slightly detuned, old ceiling speaker" | 1.2 s |
| `shiftOvertimeSting` | "alarm sting", "clock alarm short" | "short old office bell ring into a low synth drone hit, tense, kid-friendly horror" | 2 s |
| `shiftTicking` (loop) | "clock ticking loop" | "steady wall clock ticking loop with a faint low pulse underneath, tense, seamless loop, 100 bpm" | 8 s loop |
| `shiftClockOutHorn` | "truck horn double" | "two short box truck horn honks, beep beep, parking lot" | 1 s |
| `shiftCountdownTick` | "clock tick single" | "single crisp mechanical clock tick, close, dry" | 0.15 s |
| `shiftStickyNote` | "paper rustle", "sticky note" | "quick sticky note peeled and slapped on paper, close, dry" | 0.4 s |
| `shiftStamp` | "rubber stamp" | "heavy rubber stamp thump on paper on a wooden desk, close" | 0.4 s |
| `vacuumWhine` (VacuumAssets, loop) | "vacuum cleaner loop", "shop vac running" | "small wet-dry shop vacuum motor running steady, whiny, seamless loop, no start or stop" | 4 s loop |
| `vacuumPop` | "pop small", "suction pop" | "soft cartoon suction pop as debris goes up a vacuum hose" | 0.3 s |
| `canisterTick` | "plastic click" | "small plastic canister click, satisfying, close" | 0.2 s |
| `canisterChime` | "positive chime small" | "bright short two-note chime, cheerful, like a full meter" | 0.6 s |
| `dustBagPop` | "bag thump", "cartoon pop out" | "stuffed bag popping out of a machine and plopping on carpet, cartoon" | 0.5 s |
| `cargoSwoosh` (CargoAssets) | "whoosh short" | "quick airy whoosh, object flying past, cartoon" | 0.4 s |
| `cargoChaChing` | "cash register", "cha ching" | "old cash register cha-ching with a coin jingle, bright" | 0.9 s |
| `cargoPickup` | "pick up item", "cloth grab" | "quick grab of a box, cardboard rustle, close" | 0.3 s |
| `cargoPocket` | "pocket item", "zip" | "small item slipped into a jacket pocket, short zip" | 0.4 s |
| `cargoThudLight` | "bag drop", "light thud" | "garbage bag dropped on office carpet, soft thud" | 0.4 s |
| `cargoThudHeavy` | "heavy thud", "box drop heavy" | "heavy office printer dropped on a hard floor, deep thud with a rattle" | 0.7 s |
| `cargoShatter` | "glass crack", "plastic crack" | "monitor screen cracking on a hard floor, glass crunch, short" | 0.7 s |
| `cargoSplash` | "water splash", "jug splash" | "big water cooler jug bursting on a hard floor, loud splash and glug" | 1.5 s |
| `cargoRattle` | "bottles rattle" | "glass bottles in a bag rattling briefly, clink clink" | 0.5 s |
| `cargoRummage` | "drawer rummage", "search drawer" | "rummaging through a metal desk drawer, papers and pens, short" | 1 s |
| `harlowFootstep` (OccupantAssets) | "footstep dress shoe hard floor" | "single heavy dress shoe step on an office floor, slightly dragging, close-mic" | 0.4 s |
| `harlowMutter` (loop) | "mumbling loop", "muttering" | "elderly office manager muttering under his breath, unintelligible, grumbly, no words, seamless loop" | 6 s loop |
| `harlowHeartbeat` | "heartbeat single" | "single deep heartbeat thump, lub-dub, close, low end" | 0.6 s |
| `harlowCurious` | "hm question male" | "suspicious short 'hmm?' hum from an old man, pitched down, slightly distorted, no words" | 0.7 s |
| `harlowSpotted` | "horror sting jump", "spotted sting" | "sharp orchestral stab with a distorted squeal, cartoon horror jump, kid-friendly" | 1.2 s |
| `harlowChase` (loop) | "chase music horror comedy" | "frantic comedic horror chase music, pizzicato strings and low brass, 150 bpm, seamless loop" | 16 s loop |
| `harlowSigh` | "sigh male" | "long tired disappointed sigh from an old man, pitched down, slightly distorted" | 1.5 s |
| `harlowGibberish1..4` | "gibberish voice", "babble voice" | "pitched, distorted gibberish speech of an angry old office manager, fast, nonsense syllables, no real words, radio distortion" (four seeds; 1 short, 2 medium, 1 long, 1 rising) | 1-2.5 s |
| `harlowCatchSting` | "jumpscare sting", "distorted scream sting" | "short distorted orchestral hit with a warped laugh, cartoon horror jump scare, kid-friendly, no screaming" | 1 s |
| `harlowPowerDown` | "power down", "lights off" | "fluorescent lights shutting off with an electrical power-down whine" | 1.2 s |
| `harlowGrab` | "grab cloth whoosh" | "quick cloth grab and whoosh, someone grabbed by the collar, cartoon" | 0.5 s |
| `officeHum` (OfficeAssets, loop) | "fluorescent hum loop" | "fluorescent office lights buzzing at night, 60 Hz hum, empty office room tone, seamless loop" | 10 s loop |
| `officeLightZap` | "electric zap small" | "small electrical zap of a failing fluorescent tube" | 0.3 s |
| `officePhoneRing` | "office phone ring" | "old office desk phone ringing twice in an empty room, slight reverb" | 4 s |
| `officeElevatorDing` | "elevator ding" | "single elevator arrival ding, empty building, reverb" | 1.5 s |
| `officeTyping` (loop) | "keyboard typing loop" | "someone typing on an old mechanical keyboard in a quiet office, steady, seamless loop" | 6 s loop |

### Image (Flux 2 Klein / Qwen Image, local)

| Slot | Target | Prompt |
|---|---|---|
| `OccupantAssets.IMAGES.grin` | `assets/images/harlow_grin.png`, 512×512, transparent background, upload as a Decal/Image | "cartoon stretched toothy grin and wide white eyes of a creepy but kid-friendly office manager ghost, flat 2D, thick black outline, white and off-white only, centred, transparent background, no blood, no gore" (negative: "realistic, blood, gore, text, background") |

### Animations (Kimodo / MoMask → R15, via `generating-animations-with-ai`)

Harlow's rig is a tall, thin R15 from a HumanoidDescription (OccupantConstants.BODY: height 1.3, width 0.7, depth 0.65, head 0.9); retarget to standard R15 joint names (check `Workspace.Retargeting` per docs/animation.md if poses look wrong).

| Slot | Prompt | Notes |
|---|---|---|
| `harlowWalk` | "a tall stiff old man walks forward with a slow, uneven lurch, shoulders hunched, arms hanging, slight limp on the right leg" | looped, in place (root motion removed), cycle ~1.1 s at walk speed 10 |
| `harlowRun` (optional) | "a tall stiff old man hurries forward in an awkward stiff-legged fast walk, arms swinging rigidly" | looped, in place; only if it reads; otherwise leave pending (base run) |
| `harlowLook` | "a tall old man stands and slowly looks left and right with suspicion, leaning forward, hands behind his back" | looped, ~4 s, feet planted |
| `harlowGrab` | "a tall man lunges one step forward and grabs with both hands at chest height" | one-shot ~0.6 s (matches SNAP_SECONDS) |
| `harlowThrow` | "a tall man throws something heavy forward and up with both arms, then straightens his tie" | one-shot ~0.8 s |

Finish each to the skill's shippable bar (no foot sliding, readable silhouette at 30 studs), then hand the `.rbxm` to the developer for upload.
