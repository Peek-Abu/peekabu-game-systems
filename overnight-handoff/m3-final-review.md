# M3 "feel" — final whole-branch review (f65f1e4..15ca529)

Reviewer: senior code review (read-only). Scope: the 13 M3 commits on `game/cleanup-crew`. I read every src/ hunk of
`review-f65f1e4..15ca529.diff` (the 5300-line plan doc only skimmed), plus amendments.md, preflight-scan.md §6-§8,
progress.md and spec §4/§6/§7. I also checked the base APIs the new code calls against their source: SoundRegistry,
SoundServiceClient/Server, ToastRegistry/ToastServiceClient, VfxServiceClient/VfxAtmosphereRegistry, AnimationRegistry,
AnimationServiceServer.playOnRig, NpcBehaviourSystem poses, CarryServiceServer release/dropped, VacuumServiceServer/
VacuumCanisterUtils, OfficeBuildSystem lights and OccupantTellSystem. Code-line counts come from the repo's
`check_file_length.count_code_lines`: CargoServiceServer **400**, OccupantServiceServer 398, ShiftServiceServer 376.

## Strengths

- **The pending-asset pattern holds up when real ids go in.** Every `*Assets` module registers only non-PENDING
  sounds. The SoundRegistry asserts (canonical id, known group, volume 0..10, pitch min<=max, integer maxConcurrent,
  positive rollOff) all pass for every declared def, so pasting a real `rbxassetid://N` cannot trip a boot assert.
  Every player of a sound checks `SoundRegistry.has` first. This includes ToastServiceClient for the toast styles'
  `sound` (checked: `ToastServiceClient.luau:52`), so a pending id never reaches the "unknown sound" warning.
  CargoAssets is required on both realms (server: CargoTraitSystem; client: CargoFeedbackSystem), so server
  `playAt` validation and client playback agree. Animation slots are left out of the `occupant` domain while
  pending, so AnimationRegistry's compose-time asserts (canonical id, interruption class, unique keys, replication
  fields) only ever see uploaded entries. The keys are unique across domains, and `ambient`/`protected` are valid
  classes. The five office presets satisfy every VfxAtmosphereRegistry assert.
- **Lifecycle on reset / Another shift is sound** (checklist item 6 was not run live, so I traced it in code):
  - Overtime red, the tint and the ticking are all functions of the snapshot. `OfficeAtmosphereUtils.overtime` and
    `ShiftCueUtils.ticking` are false outside `running`, so they drop at `results`, which is before the vote can
    even happen.
  - The light base colour is captured before the red paint (the Task 8 fix). Restore therefore returns the built
    colour, and broken-light restore touches only Transparency and Brightness.
  - The countdown is nil outside a running clock-out.
  - Dust streams stop through the Observers cleanup when the reset destroys the piles.
  - Leaves go away because CarryServiceServer's tag cleanup calls `release`, which clears the public field, when a
    carried item is destroyed.
  - The grin self-destroys after SNAP_SECONDS and dies with the head anyway.
  - The chase music and the mutter end in `detach()` when his model leaves.
  - The canister chime cannot fire on the real Another shift / Back to depot path: the Vacuum reset runs during
    `results`, so `running` is false.
- **Light ownership composes.** OccupantTellSystem owns only Material and PointLight.Enabled. OfficeAtmosphereSystem
  owns Color, Transparency and PointLight Color/Brightness. Both screen effects (catch, overtime) go through Vfx
  `requestScreen` tokens, so they stack instead of fighting.
- **Client dependency graph** is acyclic and complete. Office depends on Vfx, so Vfx captures the place's Lighting
  base before the first `setAtmosphere`. Shift depends on Camera (kicks); Vacuum and Cargo depend on Sound and
  StateSync.
- **No double registration.** Toast styles are has-guarded on each realm. Sound ids are disjoint across the five
  Assets modules and nothing else registers sounds. There is one `occupant` domain row.
- **Server authority is intact.** `Banked` is server→all only: there is no server listener, amounts are clamped to
  uint16, and the client nil-guards `CargoRegistry.get(kind)`. Speech text is server-set from constants; the client
  only writes the local `MaxVisibleGraphemes`. No new client→server surface.
- **Good refactors under the caps:**
  - ShiftVoteSystem is a clean seam, and ShiftServiceServer went from 396 to 376.
  - `CargoFeedbackUtils.banked` keeps the 400 cap.
  - BankHandler `(boolean, number?)` is backward compatible (nil means `deposit.bonus`).
- **Specs:** the pure decisions (cues, ring, whine, canister, reveal, clipFor, presets, ambience, arc, floaters) are
  all specced. The B2 tier-note suppression was kept, and the three M2 cases were restyled rather than deleted.

## Issues

### Critical

None.

### Important

None. I specifically looked for, and did not find:
- a leftover red light, ticking layer, dust stream, leaf, grin or canister chime on the real results → vote →
  reset path;
- a boot assert or warning once ids are filled in (Sound, Vfx atmosphere, Animation, Toast);
- a service-start ordering hole;
- an authority hole in Banked or speech.

### Minor

1. **Stale comments left by M3** (cheap; recommended before merge, one doc-only commit).
   - `src/ReplicatedStorage/Client/Features/Occupant/Systems/OccupantTellSystem.luau:11` says "Placeholder for the
     heartbeat sound (M3)". Replace it with "The heartbeat sound is OccupantPresenceSystem's."
   - `src/ReplicatedStorage/Shared/Features/Occupant/Data/OccupantConstants.luau:31` says "Placeholder
     speech-bubble lines … M3 adds the gibberish voice". It should say these are the fallback lines when a cue has
     no LINE_VARIANTS entry (OccupantFeedbackUtils.pickLine).
   - `src/ServerScriptService/Features/Shift/Utils/ShiftResultsUtils.luau:4` says "the joke awards grow in M3", but
     M3 didn't grow them. Reword to "(the joke awards come with the Figma-gated review screen)".
   - `src/ReplicatedStorage/Client/UI/React/Screens/Shift/ShiftMobileButtons.luau:6` says "M3 replaces it". It is
     now "the Figma-gated UI pass replaces it".
2. **`ShiftFeedbackSystem.getState(): { [string]: any }`**
   (`src/ReplicatedStorage/Client/Features/Shift/Systems/ShiftFeedbackSystem.luau:139`). This is the only new `any`
   in M3; the Cargo, Vacuum, Noise, Occupant and Office systems each export a typed state. Fix: export
   `ShiftFeedbackState = { ticking: boolean, counters: { [string]: number } }` and return it. This is about 4 lines,
   and the AGENTS.md no-`any` rule favours it even though the base's own `getState` signatures use `any`.
3. **The Assets registration has-guard hides id collisions.** The pattern is `if def.assetId ~= PENDING and not
   SoundRegistry.has(id)` in `CargoAssets.luau:61`, `OccupantAssets.luau:126`, `ShiftAssets.luau:53`,
   `VacuumAssets.luau:39` and `OfficeAssets.luau:41`.
   - Each module is required once per realm, so the guard never protects against a re-require.
   - Its only effect is that a future duplicate id across two features would silently keep the first def. The
     registry's own contract is to assert loudly on that.
   - Fix (any time): drop `not SoundRegistry.has(id)`, or assert `SoundRegistry.get(id) == def`.
4. **`ensure()` revalidates only the model**
   (`src/ReplicatedStorage/Client/Features/Occupant/Systems/OccupantPresenceSystem.luau:244`). `root`, `head` and
   `speech` are cached at attach. If the place runs StreamingEnabled with a non-atomic model, a re-streamed head is a
   new instance: the mutter, voice and footsteps would then target a dead part and the typewriter would stop. That
   cannot happen with today's small office inside the target radius, but the check is cheap. Also require
   `attached.root.Parent ~= nil and attached.head.Parent ~= nil`.
5. **A retarget gives music but no sting.** `OccupantFeedbackUtils.cues` (`OccupantFeedbackUtils.luau:88-95`) plays
   "spotted" only on a mode change. When he switches his chase from player A to player B, B gets `chaseStart`
   (music) with no "!" sting, while spec §4 pairs "! + sting + chase music". Fix: also emit `spotted` when
   `isMine and not wasMine and beforeMode == "chase"`, with one spec case. This is a design nicety and can wait for
   tuning.
6. **The chase music assumes it owns the global music slot** (`OccupantPresenceSystem.luau:95`). `setMusic(false)`
   calls `playMusic(nil)` whenever `ownsMusic` is set, so any future game music started during a chase would be cut
   when the chase ends. No other caller exists today. Note it, or move the chase music to its own ambience layer
   (`setAmbience("harlowChase", …)`), which mixes instead of replacing.
7. **The PointLight colour is restored from the part's colour** (`OfficeAtmosphereSystem.luau:96-104`). `paint`
   writes `base.color` (the fixture's Color) into `point.Color`. This is correct today only because OfficeBuildSystem
   gives both the same LIGHT_COLOR. Store `pointColor` in LightBase if the two ever diverge.
8. **`harlowGrab` names both a sound and an animation slot** (`OccupantAssets.luau:84` and `:111`). They live in
   different registries, so there is no runtime clash, but the developer pasting ids could easily cross them.
   Consider `harlowGrabSfx` (sound), or a comment on both.
9. **Two inconsistencies in the pending counters (diagnostics only).**
   - `VacuumFeedbackSystem.luau:153` checks `has` before calling `play`, so a pending whine is never counted as
     pending.
   - `OfficeAmbienceSystem.luau:48`'s `play` skips the "declared in OfficeAssets" warning the other systems have.
   - Harmless; align when convenient.
10. **Single-server Studio bleed (already recorded in preflight, accepted).** Depot players get the office's night
    preset, hum, cues and countdown ticks while another crew's shift runs, because ShiftStore is server-global. This
    only affects the placeholder-PlaceId setup; production puts the office in its own place.
11. **Caps (N7).** CargoServiceServer sits at exactly 400 code lines and OccupantServiceServer at 398. None of the
    fixes above touch them, but anything that does (for example guarding `Banked.sendToAll` at
    `CargoServiceServer.luau:429`) needs an extraction first. A natural seam is a `CargoBankSystem` that takes
    `load`'s body.

## Deferred-minor triage (progress.md)

| Task | Deferred minor | Verdict | Why |
|---|---|---|---|
| 1 | "only names styles the game registers" spec checks the table, not ToastRegistry.has | Keep | ShiftNoticeUtils is pure server code; ToastRegistry is filled at service load, and both Shift services register from this exact table. |
| 1 | Sticky bodies not asserted for tier/overtime | Keep | The final spec does assert the tier note text+style and the overtime note style and "×1.5"; that is enough. |
| 2 | `lastSecond` unseeded on start (one extra tick) | Keep | Only a client starting mid-countdown; one extra tick is harmless. |
| 2 | `stop()` leaves in-flight one-shots/counters | Keep | `stop` runs only in test teardown; one-shots end on their own. |
| 2 | Header line wrap | Keep | Cosmetic; stylua is green. |
| 2 | `ShiftFeedbackSystem.getState` returns `{ [string]: any }` | **Fix before merge (trivial)** | The only new `any`; the sibling systems are typed (Minor 2). |
| 3 | `stop()` may pop a mid-vacuum pile at teardown | Keep | Test teardown only. |
| 3 | Stream targets the nearest hand even if not vacuuming | Keep | Cosmetic, and only with two players inside VACUUMER_RANGE of one pile. |
| 3 | False "full" chime on a non-pile canister drop to 0 (N6) | Keep | Cannot happen on the real Another shift / Back to depot path (the reset runs in `results`). Only Studio `resetShift` mid-run can race it. If checklist item 6 is run via `resetShift`, expect it and don't count it as a regression. |
| 3 | Canister sound ids are literals in the system | Keep | They are registry keys, not asset ids (spec §7 is about asset ids). The `play` guard warns on a typo. Optionally add CANISTER_TICK / CANISTER_CHIME / BAG_POP constants to VacuumAssets. |
| 4 | Per-frame ring table alloc | Keep | A handful of live rings at most. |
| 4 | floorBelow lifts the ring onto collidable props | Keep | Visual only, and arguably correct (the ring sits on what is there). |
| 5 | `Banked.sendToAll` unguarded after a credited bank | Keep (M5) | Inputs are clamped and server-built, and a throw cannot double-bank because the claim and destroy already ran. The fix needs an extraction from a 400-line file (Minor 11). |
| 5 | N9 guard has a stop→start gap | Keep | A swoop created after a restart joins the new run's `swoops` and is stepped and cleaned normally. |
| 5 | Leaves stranded if CurrentCamera is replaced | Keep | Nothing in the game replaces the camera (the catch uses a camera mode). |
| 5 | Leaves flash at the origin for one frame | Keep (optional 1-line fix) | One frame, and in Studio the depot is at the origin. Setting `leaf.CFrame` from the camera at creation removes it; do it if touching the file. |
| 6 | Same line twice within SPEECH_SECONDS not re-voiced | Keep | pickLine avoids repeats for every voiced multi-line cue; only "You're FIRED!" on two catches within SPEECH_SECONDS. |
| 6 | `stop()` mid-reveal leaves MaxVisibleGraphemes partial | Keep | Test teardown only; the label is cleared and hidden by the server within SPEECH_SECONDS anyway. |
| 6 | Stale comments (OccupantTellSystem "heartbeat (M3)", OccupantConstants LINES "M3 adds") | **Fix before merge (trivial)** | The branch is final for M3, so these now mislead (Minor 1). |
| 6 | Heartbeat volume up to 0.96 | Keep | Inside 0..10; a tuning value. |
| 7 | Grin delay/tween not tied to `stop()` | Keep | Destroys itself after 0.6 s. |
| 7 | Duplicated sound-guard pattern (Presence/Scare) | Keep | It is actually repeated in 6 systems. A shared `playIfUploaded(assets, id, options, counters)` helper is worth doing in the base when a second game needs it, not now. |
| 7 | `headOf` takes the first tagged rig | Keep | There is one Harlow by design (spec §10). |
| 8 | `bases` strong refs never cleared | Keep | The graybox lights are built once at start and never replaced (OfficeServiceServer builds once; no rebuild path). |
| 8 | Long header line in OfficeServiceServer | Keep (fold into the doc commit if convenient) | Cosmetic. |
| 8 | stepBroken rebuilds the tagged list 20×/s | Keep | A few dozen lights; negligible. |
| 8 | No regression spec for overtime→restore | Keep | The fix is in a spec-exempt shell. The ordering guarantee is documented at the call site (`paint`), and it needs a live overtime check once (item 5 of the Task 10 checklist). |
| 9 | Phone/elevator handles discarded | Keep | One-shots clean themselves up. |
| 9 | Counters count chosen rings, not heard ones | Keep | Diagnostics only. |
| 9 | Typing stops only for the local player | Keep | Matches "per client" (header: "the moment you come within"). |
| 9 | Header wrap | Keep | Cosmetic. |
| 9 | Typists strong refs | Keep | Emitters are built once with the office. |

## Paths not exercised live (reasoned in code)

- **Banking swoop and floaters:**
  - The server builds `Banked` after claim → credit → destroy, from the pre-destroy `from` and the bed's top, with
    `credited` from the handler (nil means the deposit's bonus).
  - The client staggers its ghost parts and early-returns once stopped (N9).
  - The landing plays the cha-ching and spawns BillboardGui floaters that self-destroy on the fade.
  - Correct as written.
- **Vacuum pop.** The canister math goes from capacity−1 straight to 0 (VacuumCanisterUtils.add), which matches
  `canisterCue`'s "full" rule. Interaction clears the progress attribute the same frame it completes the pile, and
  the peak-progress rule handles that. Correct.
- **Catch scare:**
  - Only the caught player gets `CatchCam`, which triggers the sting and the grin.
  - Everyone gets `LightsOut`, which triggers the power-down and the grab.
  - The server's grab/throw clips are skipped while pending.
  - Correct.
- **Overtime red:**
  - Paint, tint and restore are tied to snapshot transitions; the base is captured before the red.
  - A catch's lights-out composes, because OccupantTellSystem toggles Material and Enabled, not Color.
  - Correct.
- **Another shift mid-feedback (item 6).** Correct on the real path (see Strengths). The literal "Another shift
  while overtime is red and a pile is half-vacuumed" can only be staged with Studio's mid-run `resetShift`. On that
  path, expect two cosmetic artefacts:
  - possibly a false canister chime (N6);
  - possibly a pop + sparkle on a pile destroyed within POP_WINDOW of being channelled past 50%.

## Assessment

**With fixes.** No Critical or Important issues. Before merge, make one small commit with no behaviour change:
- the four stale comments (Minor 1);
- the typed `ShiftFeedbackSystem.getState` (Minor 2).

Everything else is fine to keep or to schedule; Minor 4 and Minor 5 are worth folding into M5's pass. When the
developer uploads assets, run checklist item 7 once. Also run item 5 live (overtime → results lights back to
night-white), since the overtime-restore fix has no spec.
