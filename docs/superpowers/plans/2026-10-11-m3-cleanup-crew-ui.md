# M3 (UI): Cleanup Crew, the Approved Paperwork Screens Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Every screen the developer approved in Figma ("Cleanup Crew — UI (for approval)", file `PYtXsNlpV1MW2nOVx0wXl4`, page "Screens") is built in React on the "Corporate After Hours" paperwork style, each with a UI Labs story, fed by server-authoritative data that exists for it: the Shift HUD (desktop and phone), paper toasts and rubber stamps, the depot contract board, the truck queue pad, the catch (scare beat, CCTV spectating, Rehired card) and the performance review (quota met and missed, rating, joke awards, crew vote).

**Architecture:** Two halves, data first. **(A) Data:** the screens show facts the game does not publish yet, so Tasks 1-5 add them on the server, each specced and each leaving the placeholder UI working: review stats per crew member (drops, noise made, times Harlow went to investigate their noise, the most valuable drop), the rating tier, the four joke awards and "salvage found N of M" (Shift); who made each noise (Noise, Vacuum, Cargo); per-player public status fields (in the truck bed, vacuuming, room, rooms from the truck: Shift polls Office, Cargo and Vacuum); the truck number riding the depart payload and a client copy of the last shift (Depot); the caught deadline, a private incident report and a rehire notice (Occupant). **(B) UI:** a game paper kit in the UI tree (`Client/UI/React/Screens/Paper/`: palette and fonts in `UIPaperConstants`, `PaperSheet`, `PaperStamp`, `StickyNote`, `KeyChip`, `PaperButton`, `PaperLabel`, a phone/desktop layout hook), then each screen as a pure, specced **view model** + presentational components + a story, exactly the split `docs/testing.md` asks for. HUD widgets register in `HudRegistry`; the depot board and the performance review are **scenes** (`SceneRegistry`, Panel layer: they free the mouse and hide the HUD; Escape closes them through the base's existing stack). Components never send packets: they call the client services' existing methods (the `ShiftMobileButtons` precedent) or write a client store.

**Tech Stack:** Luau `--!strict`, React-lua (`React.createElement`), ReactCharm `useAtom`, Charm atoms, ByteNetMax (`struct`, `array`, `optional`), the base UI framework (UILayers, SceneRegistry/SceneStack/SceneHost, HudRegistry/HudRoot), UI Labs (`UILabs.CreateReactStory`), TestEZ (Studio, `RunTests = true`), the engine's `ProximityPrompt` Custom style (`ProximityPromptService.PromptShown` / `PromptHidden`, `ProximityPrompt:InputHoldBegin()` / `InputHoldEnd()`).

**Spec:** `docs/superpowers/specs/2026-10-10-cleanup-crew-design.md` §6.2 (UI screens live in the UI tree, registered as HUD widgets and scenes), §6.3 (per-player public fields incl. `caught`), §7 ("Only approved screens are built in React, each with a UI Labs story"). Approved state: `overnight-handoff/m3-figma-summary.md` (the "Update", "Review changes applied", "Game-rule decisions", rating tiers, restyle and crew-roster notes) and the developer's decisions restated in "Decisions" below. Builds on M1-M5 (head `a498a8f`); their modules are the real API.

**Figma was read live for this plan** (figma-console Desktop Bridge, read-only: screenshots and text/size dumps of every frame listed in "Frame index"). Every copy line and size quoted below comes from those dumps.

**Branch / PR:** `game/cleanup-crew`, after M5. No merge (the developer merges). Base changes are confined to Task 6 and need approval first (see "Approval needed").

## Global Constraints

- `--!strict` everywhere except `*.spec.luau` and `*.story.luau` (stories follow the existing `--!strict` story files). No `any`, no `::` casts (none are planned; if one seems needed, stop and report).
- Service shape: lean annotated literal (`export type X = {...}` + `local X: X = {...}`, methods as fields, callers use colon syntax).
- Every new first-party module has a `<Name>.spec.luau` sibling or an `EXEMPT_MODULES` line with a reason in `src/ServerScriptService/Core/Testing/SpecRoots.luau`. `*.story` / `*.storybook` need neither. **View models and pure utils get real specs; presentational components and hooks are exempt** (docs/testing.md "Testing React UI"). Logic that branches lives in the view model, never in the component.
- Module names `<Feature><What><RoleWord>` in an allowed subfolder; UI tree modules PascalCase (`ViewModel` suffix for view models, `use<Thing>` hooks, `<Feature>Scene` scene modules, `UI<Thing>Constants` constants). Requires use full addresses; a feature folder required 3+ times in one file gets a `<Feature><Realm>` variable.
- ≤ 400 code lines per module (`scripts/python/check_file_length.py`; comments and blanks do not count). **Three services sit at the cap:** `CargoServiceServer` 400, `OccupantServiceServer` 398, `ShiftServiceServer` 382 (measured at `a498a8f`). Every edit to them in this plan is line-neutral or pays for itself (each task states its count); new logic goes into new Systems/Utils modules.
- CI rules this plan must keep (`scripts/python/check_pr_rules.py`): a `ScreenGui` only in `UILayerHost`; no `.Visible =` / `.Enabled =` assignments in `Client/UI` (components return `nil` or set props, they never toggle instances); no `:FireServer` / `:InvokeServer` / `.packets.` in `Client/UI/React`; asset id literals only in a `Data/` module or a spec. No `Name =` prop except on a layer root (selene's `roblox_incorrect_roact_usage`).
- **Rojo safety:** the developer may be connected to `rojo serve`. Never run `rokit install`, `wally install`, `install.sh`, `wally-package-types` or `scripts/check.sh`, never start `rojo serve`. The per-task gate is `bash .superpowers/sdd/gate.sh` (selene, stylua check, luau-lsp, `check_pr_rules`, file length, module map, python tests).
- **Tests run only in Studio, by the controller:** "Controller: Studio TestEZ" = set the Workspace attribute `RunTests = true`, Play, read Output (the suite mutates live singletons, so it is never a play session). Gameplay and visual checks run in a fresh Play with `RunTests = false`; the Studio MCP plugin VM cannot reach live services, so a check that needs them uses a temporary server `Script` / client `LocalScript` the controller injects and deletes. UI Labs stories are checked in **edit mode** (no Play).
- **Commit order (every task):** `git add src` → `python3 scripts/python/module_map.py --write` → `git add docs/project-structure.md` → `stylua <each new or edited .luau file>` → `git add src` → `bash .superpowers/sdd/gate.sh` → `python3 scripts/python/check_pr_rules.py origin/main` (zero errors) → `git commit -m "<message as given>"` → `python3 scripts/python/module_map.py --check`. Never `stylua src` wholesale.
- **Commits: plain messages, no `Co-Authored-By:` / `Claude-Session:` trailers** (AGENTS.md; `check_pr_rules` rejects them).
- Server-authoritative: the server decides every number the screens show. New client → server traffic: **none** (the board opens through an Interaction prompt the server already validates; votes, Depart now, pocket/drop/throw/vacuum use existing requests).
- Copy: "**Finder's fee**" everywhere (Figma), never "Bonus". Asset slots for paper textures and Harlow's face stay `""` (PENDING) in `Client/Features/UI/Data/UIAssets`; every component draws flat colours when a slot is empty.
- **Deferred, do not build** (developer, 2026-10-11): darker in-shift paper, green/neutral success stamps, a separate threat-toast style, cutting the PRESSURE meter, contextual canister/pockets/hints, a first-time depot variant, stamp timing changes, an icon set.

## Review Focus

1. **The rating stamp claims more than the crew earned** (quota missed but EXCEEDS; a crew that found no salvage reads EXCEEDS; a spoofed result card's rating) → missed is always NEEDS IMPROVEMENT, nothing offered is SATISFACTORY, the card's rating is re-derived from its own numbers. (Task 1 `ShiftResultsUtils` spec "never rates a missed quota above NEEDS IMPROVEMENT", "reads SATISFACTORY when no salvage was offered"; Task 1 `ShiftCardUtils` spec "re-derives the rating instead of trusting the card".)
2. **A joke award goes to the wrong person or to nobody-who-did-it** (an award for zero drops; two players with the same display name and "you" shown on both) → awards need a score above zero (quietest/loudest excepted by rule), ties go to crew order, "you" is matched by userId only. (Task 1 `ShiftResultsUtils` spec "gives no BUTTERFINGERS when nobody dropped anything"; Task 15 `ShiftReviewViewModel` spec "calls an award yours by userId, not by name".)
3. **A noise is pinned on someone who was not making it** (a vacuum pulse credited to a player who stopped vacuuming, or to everyone near the pile) → only players whose channel ticked on that pile within the window are makers. (Task 2 `VacuumChannelTracker` spec "names only the players still channeling that pile"; Task 2 `ShiftAnalyticsUtils` spec "returns the makers of the noise he most likely heard".)
4. **Untrusted teleport data reaching the screens** (a payload `truck` of 9, 2.5, "2" or NaN; a result card with a made-up rating) → truck must be a whole number 1..`DepotConstants.MAX_TRUCKS`, else nil; the rating is recomputed. (Task 4 `DepotContractUtils` spec "accepts only a whole truck number on the layout"; Task 1 `ShiftCardUtils` spec.)
5. **The roster or the CCTV lies about a teammate** (a caught player shown "carrying", a negative "back in", "NOT ABOARD" outside the clock-out) → caught beats every other status, countdowns clamp at 0:00, aboard/not-aboard shows only during the clock-out countdown. (Task 9 `ShiftCrewViewModel` spec "puts CAUGHT above every other status", "clamps the back-in countdown at 0:00", "shows aboard / NOT ABOARD only while clocking out"; Task 14 `CatchViewModel` spec "counts down to the respawn and never below 0:00".)

---

## Decisions (from the developer, the approved frames and the code)

Developer decisions (2026-10-11, not re-opened): vote = majority, auto-pick when the timer runs out (`ShiftConstants.VOTE_SECONDS = 30` stays), a tie → Another shift, the player's own vote is marked; spectating while caught = a CCTV overlay with an incident-report slip; rating = 3 tiers (missed → NEEDS IMPROVEMENT, met → SATISFACTORY, met + the salvage threshold → EXCEEDS EXPECTATIONS), the results headline stamp is QUOTA MET / QUOTA MISSED and the rating is the smaller second stamp; the joke awards EMPLOYEE OF THE NIGHT, MOST REHIRED, BUTTERFINGERS, QUIETEST FEET (5c shows LOUDEST VACUUM in the fourth slot); the quota-met and caught toast copy; the clock-out countdown is a stapled torn slip under the punch clock; the crew roster card; the depot pinboard; phone buttons arc around the big VACUUM↔LOAD button with ≥ 16 px gaps; no HUD and no text during the 0.6 s scare, "You're FIRED!" on the throw.

Decisions taken in this plan (each is small and reversible; the questions they raise are in "Open questions"):

- **Spectate keys stay ← / → (and D-pad).** Figma drew Q / E, but Q is Pocket (`CargoConstants.POCKET_ACTION`). The CCTV key chips read the live bindings of `DeathConstants.SPECTATE_PREV` / `SPECTATE_NEXT` (← / → today), so a rebind moves the chips too.
- **The game kit does not re-dial the base `Tokens`.** `Tokens` is read by base primitives (`Button`, `Panel`), the base `QueuePadPanel` and `ToastStack`; the paper look needs more roles than its structure has (manila, punch cream, ink, sticky, stamp red, fluorescent, monitor blue, four fonts). The kit's own `UIPaperConstants` holds the Style-page palette; base `Tokens` stays neutral. (Open question 4.)
- **Phone vs desktop** is `ShiftPlatformRules.detect` (already specced, M5) on the live viewport: `"phone"` → the 844×390 layouts, anything else → the 1920×1080 layouts, at 1:1 offsets anchored to the screen edges (no `UIScale`: scaling down would break the ≥ 20 px desktop / ≥ 14 px phone text minimums).
- **Interaction prompt: custom, without a base change.** A game client system sets `Style = Custom` on the Interaction prompts (a client-side property write, local to that client) and draws the paper "[E] LOAD monitor onto the truck" chip from `ProximityPromptService.PromptShown` / `PromptHidden`; touch and the phone LOAD button press it with `ProximityPrompt:InputHoldBegin()` / `InputHoldEnd()`. Task 11 Step 1 verifies those engine APIs against the reference first; **if any of them does not behave as documented, the task keeps the engine's default prompt and the phone LOAD button stays hidden** (the tap-the-prompt path still works) and reports why.
- **Results and the depot board are scenes; the HUD, toasts, CCTV and Rehired card are HUD widgets.** A HUD widget hides itself by returning `nil` from its own state (the existing `ShiftHud` pattern), so the HUD can go dark during the scare and while caught without a scene (a scene would let Escape pop the CCTV). Escape closing the review is accepted: a manila "PERFORMANCE REVIEW" tab HUD widget reopens it while the vote runs.
- **The paper toast stack replaces the base `ToastStack` through a base seam** (`ToastServiceClient:setDefaultWidget(false)`, Task 6, approval needed), mirroring `QueueServiceClient:setDefaultWidget`. Stamps (`ShiftConstants.TOAST_STAMP`) draw centre-screen and big; stickies stack top-right, max 3, newest on top, ±2° tilt, slide in from the right.
- **Carry panel value = the catalog value** (`CargoRegistry` `value`): a damaged fragile item's reduced value is not public. Figma shows the catalog figure ("+30").
- **CCTV camera number = the room's index in the office layout** ("CAM 04"), the room name is the authored one (`OfficeLayoutConstants`: "Archive", "Server room", ...; Figma's "Copy Room" was sample text), and "2 rooms from the truck" is `OfficeLayoutUtils.depths` from the loading bay.
- **The timestamp is a fictional night clock:** `THU 03:00:00` + time into the shift (`ShiftConstants.NIGHT_CLOCK_START = 3 * 3600`, `NIGHT_DAY = "THU"`).
- **BUTTERFINGERS counts drops by hand plus throws of fragile items** (a throw is a tool, a broken monitor is butter fingers); drops made by a catch (`"death"`) or by pocketing/banking (`"forced"`) never count. The detail names the most valuable item dropped ("dropped the fish tank").
- **QUIETEST FEET vs LOUDEST VACUUM:** the fourth award is LOUDEST VACUUM ("woke him 4 times") when someone's noise sent Harlow to investigate at least `ShiftConstants.LOUDEST_MIN_WOKE = 3` times, otherwise QUIETEST FEET (fewest investigations, then fewest noises; "never heard once" at zero). (Open question 2.)
- **"Woke him"** = Harlow switches to investigate and the noise he most likely heard (M5's `ShiftAnalyticsUtils.heardSource` inference, now returning the noise record) had makers: each maker gets one.
- **Rating threshold as a ratio of integers:** `RATING_EXCEEDS_LOADED = 2`, `RATING_EXCEEDS_OF = 3` (salvage loaded × 3 ≥ salvage offered × 2), so there is no float edge. (Open question 1: the annotation's own sample contradicts it.)
- **"Salvage found 6 of 9"** = salvage items loaded by the crew of the salvage the shift's roll offered (open floor, hidden, desks/lockers: `OfficeSpawnUtils.salvageCount`).
- **Quota-met note copy keeps the approved template but tells the truth about the time:** "Quota met! Clock out at the truck any time, or stay: salvage ×1.5 in 1:00." The approved frame says "in 0:30", but ×1.5 starts after the 30 s break **and** the 30 s warning (`BREAK_SECONDS + WARNING_SECONDS`). (Open question 3.)
- **Depot board opens from a prompt** ("Read · Work order") on the contract board; the in-world billboard shrinks to a sign ("TONIGHT'S JOB" + the client). (Open question 5.)
- **Truck numbers:** the depot's depart payload carries the truck's layout index (untrusted on arrival: `DepotContractUtils.truckOf`); the shift publishes it in its snapshot (CREW ROSTER · TRUCK 2, the review's "Crew of Truck 2", the clock-out slip), and the depot publishes a public `truck` field while a player stands in a bed (the queue pad's "TRUCK 2 — HARLOW & FINCH JOB"). Without a truck number the titles drop the "· TRUCK n" part.
- **CLOCKED OUT stamp** (1f states sheet only) is not placed: no approved frame shows where it plays. (Open question 6.)
- **Overhead name tags on the truck bed** (3a) are the engine's default character names; nothing is built for them.

## Frame index (what each task matches)

| Frame | Node | Built in |
|---|---|---|
| 1a Shift HUD desktop | 6:2 | Tasks 9, 11 |
| 1b quota met | 6:67 | Tasks 8, 9 |
| 1c overtime + clock-out | 6:136 | Tasks 9 |
| 1d phone (in truck bed, holding) | 9:61 | Task 10 |
| 1e phone (overtime + clock-out) | 9:116 | Task 10 |
| 1f toasts & stamps | 9:172 | Task 8 |
| 2a / 2b depot contract board | 31:458 / 31:516 | Task 12 |
| 3a / 3b queue pad | 22:183 / 22:217 | Task 13 |
| 4a scare beat | 22:241 | Task 14 |
| 4b / 4d CCTV spectating | 22:249 / 22:285 | Task 14 |
| 4c / 4e Rehired card | 22:263 / 22:299 | Task 14 |
| 5a / 5c / 5b review (met / missed / phone) | 31:557 / 31:611 / 31:665 | Task 15 |
| rating tiers note | 35:1096 | Task 1 |
| crew roster cards | 35:1100, 35:1119, 35:1137, 35:1160, 35:1165 | Task 9, 10 |
| Style guide / Components | 4:2 / 5:2 | Task 7 |

Key measurements from the dumps (desktop 1920×1080, phone 844×390): clearance folder at (60, 68), tab "CLEARANCE CONTRACT" Oswald Bold 20, value 44, "/ 350 cleared" Special Elite 22; fee plate at y ≈ 245, "+140" Oswald Bold 32; crew roster card 350×156 at (60, 330), title 20, names 22, status 20, marker X 22; time card 360×132 top-centre (band 26 px Stamp Red, time Roboto Mono Bold 58, labels 20, 5 punch holes 10×16, 3 tier pips 26×12); clock-out slip under the time card at ≈ (710, 255), "0:07" Roboto Mono 52; toasts 340×112 top-right at (1520, 80), Permanent Marker 24, tape 110×26; carry panel bottom-left (48, 830) ≈ 640×200 with hands 28/24/20, pocket slots 76×76, canister 3 bars; key hints bottom-centre y = 1030, 20 px at 80% opacity; stamp 437×133, 7 px Stamp Red border, Oswald Bold 72 (centre stamp 120 at 1b), −3° tilt; mobile buttons large 104 (VACUUM/LOAD 20 px), small 72 (15 px), 3 px Fluorescent stroke; phone LOAD centre ≈ (660, 320), DROP (512, 282), THROW (555, 194), POCKET (651, 173) (top-left corners of the 72 px circles); review paper 1600×900 with a manila tab; depot pinboard 1580×900 cork (#5C3D22-ish brown) with the work order (manila), last-shift card (Punch Cream, red band), dispatch slip (pinned, green marker underline), night-guard sticky, CLOSE [Esc] (secondary button).

---

## New modules

| Feature | Realm | Subfolder | Name | Job (one line) |
|---|---|---|---|---|
| Shift | server | Systems | ShiftReviewSystem | Records each crew member's review stats (piles, drops, noise, times heard) from the features' signals |
| Shift | server | Systems | ShiftCrewStatusSystem | Publishes each crew member's truck-bed, vacuuming and room fields four times a second |
| Shift | server | Utils | ShiftCrewStatusUtils | One crew member's status fields and what changed since the last publish (pure) |
| Vacuum | server | State | VacuumChannelTracker | Who is vacuuming which pile right now, from the channel's per-tick asks |
| Occupant | client | State | OccupantCatchStore | The local player's catch as the UI sees it: the scare beat, the incident report, the rehire notice |
| Shift | client | State | ShiftPromptStore | The interaction prompt on screen (action, object, key, hold) for the paper chip and the phone LOAD button |
| Shift | client | Systems | ShiftPromptSystem | Switches the Interaction prompts to Custom style, tracks the shown one and presses it for touch |
| UI tree | client | `Client/UI/React/Screens/Paper/` | UIPaperConstants | The Style page: palette, font faces, text sizes, safe areas, motion timings |
| UI tree | client | `.../Screens/Paper/` | PaperLabel | Text in one of the five type roles (body, heading, number, timer, marker) |
| UI tree | client | `.../Screens/Paper/` | PaperSheet | A paper card: fill, edge, optional tab/band, fastener (clip, pin, tape, staple), torn edge, tilt |
| UI tree | client | `.../Screens/Paper/` | PaperStamp | The rubber stamp (red border, Oswald, tilt, pop-in) |
| UI tree | client | `.../Screens/Paper/` | StickyNote | The taped sticky note (marker text, tilt) |
| UI tree | client | `.../Screens/Paper/` | KeyChip | A key cap with its label ("E", "←", "LMB") |
| UI tree | client | `.../Screens/Paper/` | PaperButton | Primary / Secondary / Danger / Go buttons from the Components frame |
| UI tree | client | `.../Screens/Paper/` | usePaperLayout | Hook: "phone" or "desktop" from the live viewport and input devices |
| UI tree | client | `.../Screens/Paper/` | usePaperMotion | Hook: a pop-in / slide-in binding that runs once on mount |
| UI tree | client | `.../Screens/Paper/` | PaperToastViewModel | Which toasts are stamps and which are stickies, the order, tilt and limits (pure) |
| UI tree | client | `.../Screens/Paper/` | PaperToastStack | HUD widget: stamps centre, stickies top-right |
| UI tree | client | `.../Screens/Shift/` | ShiftCrewViewModel | The crew roster: each member's status line, ink, tick or strike, and the phone's two-line form (pure) |
| UI tree | client | `.../Screens/Shift/` | ShiftTimeCard | The punch clock: stage label, time, OUT, punch holes, pressure pips, SALVAGE ×1.5 |
| UI tree | client | `.../Screens/Shift/` | ShiftClearancePanel | Clearance folder with the bar and MET, and the finder's fee plate |
| UI tree | client | `.../Screens/Shift/` | ShiftCrewRoster | The clipped crew roster card (desktop) and the two-line strip (phone) |
| UI tree | client | `.../Screens/Shift/` | ShiftCarryPanel | Hands, pockets and canister |
| UI tree | client | `.../Screens/Shift/` | ShiftClockOutSlip | The stapled torn CLOCK-OUT SLIP |
| UI tree | client | `.../Screens/Shift/` | ShiftKeyHints | The desktop key-hint row |
| UI tree | client | `.../Screens/Shift/` | ShiftPromptChip | HUD widget: the paper interaction prompt |
| UI tree | client | `.../Screens/Shift/` | ShiftReviewViewModel | The performance review's stamps, rows, awards and vote (pure) |
| UI tree | client | `.../Screens/Shift/` | ShiftReviewScreen | The review scene's screen: reads the stores, draws ShiftReviewPanel |
| UI tree | client | `.../Screens/Shift/` | ShiftReviewPanel | The review on paper, desktop and phone |
| UI tree | client | `.../Screens/Shift/` | ShiftReviewTab | HUD widget: the manila tab that reopens a closed review while the vote runs |
| UI tree | client | `.../Screens/Shift/` | ShiftScene | Registers the performance review scene |
| UI tree | client | `.../Screens/Depot/` | DepotBoardViewModel | The work order rows, the last-shift card and the dispatch slip (pure) |
| UI tree | client | `.../Screens/Depot/` | DepotBoardScreen | The board scene's screen: reads DepotStore |
| UI tree | client | `.../Screens/Depot/` | DepotBoardPanel | The pinboard, desktop and phone |
| UI tree | client | `.../Screens/Depot/` | DepotScene | Registers the contract board scene |
| UI tree | client | `.../Screens/Depot/` | DepotPadViewModel | The queue pad card: title, crew slots, countdown (pure) |
| UI tree | client | `.../Screens/Depot/` | DepotPad | HUD widget: reads QueueStore and the public truck field |
| UI tree | client | `.../Screens/Depot/` | DepotPadPanel | The queue pad card, desktop and phone |
| UI tree | client | `.../Screens/Catch/` | CatchViewModel | The CCTV overlay and the Rehired card's lines (pure) |
| UI tree | client | `.../Screens/Catch/` | CatchOverlay | HUD widget: the CCTV overlay while caught |
| UI tree | client | `.../Screens/Catch/` | CatchCctvPanel | The CCTV feed frame, desktop and phone |
| UI tree | client | `.../Screens/Catch/` | CatchRehiredCard | HUD widget: the HR "Notice of Re-employment" |
| UI tree | client | `.../Screens/Catch/` | CatchRehiredPanel | The Rehired card on paper, desktop and phone |
| UI tree | client | `.../Screens/Catch/` | useSpectateTarget | Hook: the userId Death is spectating, polled (Death's getter is not reactive) |

Stories (no spec, no exemption): `Screens/Paper/PaperKit.story`, `Screens/Paper/PaperToastStack.story`, `Screens/Shift/ShiftHudPanel.story` (rewritten), `Screens/Shift/ShiftReviewPanel.story`, `Screens/Depot/DepotBoardPanel.story`, `Screens/Depot/DepotPadPanel.story`, `Screens/Catch/CatchCctvPanel.story`, `Screens/Catch/CatchRehiredPanel.story`; one fixtures module `Screens/Shift/ShiftStoryFixtures` (shared sample snapshots for the Shift stories; exempt: "story fixtures (static sample data)").

Rewritten in place: `ShiftHudViewModel` (+ spec), `ShiftHud`, `ShiftHudPanel` (+ story), `ShiftMobileButtons`. Deleted (Task 15): `ShiftResults`, `ShiftResultsPanel`, `ShiftResultsPanel.story` and `ShiftHudViewModel.results`.

Extended (existing modules, new functions or fields; specs extended; `DepotConstants` also gains `BOARD_SCENE`): `ShiftTypes`, `ShiftConstants`, `ShiftRosterTracker`, `ShiftResultsUtils`, `ShiftSnapshotUtils`, `ShiftCardUtils`, `ShiftNoticeUtils`, `ShiftAnalyticsUtils`, `ShiftAnalyticsWatchSystem`, `ShiftTripSystem`, `ShiftServiceServer`, `ShiftServiceClient`, `ShiftStore` (unchanged API), `OfficeLayoutUtils`, `OfficeSpawnUtils`, `OfficeServiceServer`, `NoiseTypes`, `NoiseServiceServer`, `VacuumConstants`, `VacuumServiceServer`, `CargoServiceServer` (line-neutral), `CargoTraitSystem`, `OccupantConstants`, `OccupantEvents`, `OccupantFeedbackUtils`, `OccupantCatchSystem`, `OccupantServiceServer` (net −2 lines), `OccupantServiceClient`, `DepotConstants`, `DepotTypes`, `DepotEvents`, `DepotContractUtils`, `DepotBuildSystem`, `DepotServiceServer`, `DepotStore`, `DepotServiceClient`, `UIAssets`, `SpecRoots`.

**Layout check (module-placement skill):** every feature row uses an existing subfolder kind and role word; Vacuum's server realm gains a `State/` folder and Occupant's client realm a `State/` folder (existing kinds); Shift gains no second service. The UI tree keeps its own folders: `Screens/Paper` and `Screens/Catch` are new folders beside the existing `Screens/Depot`, `Screens/Hud`, `Screens/Shift` (the UI tree has no subfolder-kind rule; `GameUI.storybook` already scans everything under `Screens`). **No new subfolder kind, no new role word, no second service.**

## Approval needed

Nothing in the layout needs approval (see the layout check above). **Two base changes do** (base code must stay generic, and AGENTS.md says the base holds only what several games need); both are in Task 6, which must not start until the developer says yes to each:

- **B1. `DeathServiceClient:cycleSpectate(direction: number)`** (base Death, client). The phone CCTV frame (4d) has ‹ / › buttons; spectate cycling today is reachable only through the keyboard/gamepad Input actions, so a touch player cannot switch teammates at all. Generic: every game that spectates on phone needs it (Night Watch). 6 lines, no behaviour change for existing callers. **If declined:** the phone CCTV draws no ‹ / › buttons (the camera still auto-picks a teammate; Task 14 reads the decline flag noted in the task).
- **B2. `ToastServiceClient:setDefaultWidget(enabled: boolean)`** + `ToastStore.widgetEnabled` (base Toast, client), the exact mirror of `QueueServiceClient:setDefaultWidget`. The paper toasts (tape, tilt, slide-in, centre stamps) cannot be drawn by the base `ToastStack` (one rounded label per toast). Generic: each game approves its own toast look. **If declined:** Task 8 registers `PaperToastStack` under the key `"toasts"` at `ShiftServiceClient` load time, before `ToastServiceClient:init` runs (its `if not HudRegistry.has("toasts")` guard then skips the base widget). That works today but leans on a guard written for double-registration, not as a seam, so it is the fallback only.

**Answered 2026-10-11: B1 and B2 are both approved, built on their own `base/ui-seams` branch** (PR into `base/queue`, then merged into the game branch; see Task 6). Game branches never merge into `main` or `base/*`.

## Open questions for the developer

**Answered 2026-10-11: take every default below.** For Q1, the Figma sample was corrected to "5 of 9 → SATISFACTORY", so the share rule stands: loaded ≥ ⅔ of offered → EXCEEDS.

1. **EXCEEDS EXPECTATIONS threshold.** The note (35:1096) says "quota met + at least 2 of 3 salvage loaded" and shows "5a = SATISFACTORY (6 of 9 salvage)". 6 of 9 *is* 2 of 3, so the sample and the rule disagree. The plan reads the rule as a share (loaded ≥ ⅔ of offered → EXCEEDS, so 6 of 9 would be EXCEEDS) and keeps the two numbers in `ShiftConstants.RATING_EXCEEDS_LOADED / _OF`. If you meant "strictly more than ⅔", or "2 of the 3 greed targets", it is one constant or one line in `ShiftResultsUtils.rating`.
2. **Fourth award.** LOUDEST VACUUM when someone woke Harlow ≥ 3 times, else QUIETEST FEET (both drawn in Figma, 5c vs 5a; the rule choosing between them is this plan's). Ties in every award go to crew order (most banked, then name).
3. **Quota-met note time.** Approved text says "salvage ×1.5 in 0:30"; the real wait is break 30 s + warning 30 s = 1:00, so the plan prints "in 1:00" (computed). Alternatively shorten the break or warning, or drop the time from the note.
4. **Base `Tokens` re-dial vs a game kit.** The plan leaves base `Tokens` neutral and adds `UIPaperConstants` in the game's UI tree. Re-dialling `Tokens` too would only recolour the base primitives (`Button`, `Panel`), which no Cleanup Crew screen uses after this milestone.
5. **Depot board opening:** a "Read · Work order" prompt on the board (built). Walking up to the board could open it instead (a proximity trigger), but a scene that frees the mouse should not open by itself while a player walks past.
6. **CLOCKED OUT stamp** (1f) has no approved place. Options: on the clock-out countdown's end before the review, or never.
7. **Base changes B1 and B2** (Approval needed above).
8. **"Crew of Truck 2 · Harlow & Finch Ltd. · 4th floor offices"**: the site line ("4th floor offices") is a constant (`DepotConstants.SITE`); every contract is the same office today.
9. **Harlow's face (4a) and paper textures** stay PENDING (`UIAssets.paper.*`, `OccupantAssets` grin): flat colours until the art pass. Nothing in this plan generates or uploads art.

---
### Task 0: Preflight

**Files:** none.

- [ ] **Step 1: Confirm the branch and head**

```bash
git branch --show-current
git log --oneline -3
```
Expected: `game/cleanup-crew`; `a498a8f fix(shift): final M5 review fixes ...` or a later commit. If M5 is missing, stop and report.

- [ ] **Step 2: Confirm every API this plan edits or calls** (each command prints at least one line; if one prints nothing, stop and report which):

```bash
grep -n "function ShiftResultsUtils.build" src/ServerScriptService/Features/Shift/Utils/ShiftResultsUtils.luau
grep -n "record = function" src/ServerScriptService/Features/Shift/State/ShiftRosterTracker.luau
grep -n "function ShiftSnapshotUtils.build" src/ReplicatedStorage/Shared/Features/Shift/Utils/ShiftSnapshotUtils.luau
grep -n "function ShiftCardUtils.decode" src/ServerScriptService/Features/Shift/Utils/ShiftCardUtils.luau
grep -n "function ShiftAnalyticsUtils.heardSource" src/ServerScriptService/Features/Shift/Utils/ShiftAnalyticsUtils.luau
grep -n "local piles = VacuumServiceServer.pileCleared" src/ServerScriptService/Features/Shift/ShiftServiceServer.luau
grep -n "vacuuming\[player.UserId\] = target" src/ServerScriptService/Features/Vacuum/VacuumServiceServer.luau
grep -n "noiseMade:Fire" src/ServerScriptService/Features/Cargo/CargoServiceServer.luau src/ServerScriptService/Features/Cargo/Systems/CargoTraitSystem.luau src/ServerScriptService/Features/Vacuum/VacuumServiceServer.luau
grep -n "function OfficeLayoutUtils.depths" src/ServerScriptService/Features/Office/Utils/OfficeLayoutUtils.luau
grep -n "bed: BasePart" src/ServerScriptService/Features/Office/Systems/OfficeBuildSystem.luau
grep -n "OccupantRigSystem.say(rig, OccupantConstants.LINES.caught)" src/ServerScriptService/Features/Occupant/Systems/OccupantCatchSystem.luau
grep -n "REHIRED_TEXT" src/ServerScriptService/Features/Occupant/OccupantServiceServer.luau
grep -n "setDepartData(function" src/ServerScriptService/Features/Depot/DepotServiceServer.luau
grep -n "setDefaultWidget" src/ReplicatedStorage/Client/Features/Queue/QueueServiceClient.luau
grep -n "spectating = function" src/ReplicatedStorage/Client/Features/Death/DeathServiceClient.luau
grep -n "HudRegistry.register(\"toasts\"" src/ReplicatedStorage/Client/Features/Toast/ToastServiceClient.luau
python3 scripts/python/check_file_length.py
```
Expected: every grep prints a line and the length check passes. Note the code-line counts the plan assumes: `ShiftServiceServer` 382, `OccupantServiceServer` 398, `CargoServiceServer` 400 (comments and blanks excluded); each task states what it adds or removes there.

- [ ] **Step 3: Confirm Figma is the approved state.** Read `overnight-handoff/m3-figma-summary.md` "Update", "Review changes applied", "Earlier design questions" and "Game-rule decisions". If anything there contradicts "Decisions" in this plan, stop and report it.

- [ ] **Step 4: Ask the controller for the B1 / B2 answers** (see "Approval needed") and record them in the task log; Tasks 6, 8 and 14 branch on them.

---

### Task 1: Review data: rating, joke-award stats, salvage offered (server, pure)

The review needs per-player drops, noise and "woke him" counts, the most valuable drop, a rating and "salvage found N of M". This task adds the data shapes, the pure rules and the snapshot/card plumbing; Task 2 feeds the new counters from live signals (until then they read 0 and the awards degrade gracefully: QUIETEST FEET to the first crew member, no BUTTERFINGERS). The placeholder results panel keeps working (it reads `title` and `name`, both kept).

**Files:**
- Modify: `src/ReplicatedStorage/Shared/Features/Shift/Data/ShiftTypes.luau`
- Modify: `src/ReplicatedStorage/Shared/Features/Shift/Data/ShiftConstants.luau`
- Modify: `src/ServerScriptService/Features/Shift/State/ShiftRosterTracker.luau`; Test: `src/ServerScriptService/Features/Shift/State/ShiftRosterTracker.spec.luau`
- Modify: `src/ServerScriptService/Features/Shift/Utils/ShiftResultsUtils.luau`; Test: `src/ServerScriptService/Features/Shift/Utils/ShiftResultsUtils.spec.luau` (rewritten)
- Modify: `src/ReplicatedStorage/Shared/Features/Shift/Utils/ShiftSnapshotUtils.luau`; Test: `src/ReplicatedStorage/Shared/Features/Shift/Utils/ShiftSnapshotUtils.spec.luau`
- Modify: `src/ServerScriptService/Features/Shift/Utils/ShiftCardUtils.luau`; Test: `src/ServerScriptService/Features/Shift/Utils/ShiftCardUtils.spec.luau`
- Modify: `src/ServerScriptService/Features/Office/Utils/OfficeSpawnUtils.luau`; Test: `src/ServerScriptService/Features/Office/Utils/OfficeSpawnUtils.spec.luau`
- Modify: `src/ServerScriptService/Features/Shift/ShiftServiceServer.luau` (+5 code lines: 382 → 387)

**Interfaces:**
- Consumes: `CargoRegistry.get(kind) -> ItemDef?` (`id`, `name`, `category`); `OfficeTypes.SpawnPlan` (`items[].kind`, `piles[].hides`, `searchables[].kind`).
- Produces:
  - `ShiftTypes.Rating = "needsImprovement" | "satisfactory" | "exceeds"`.
  - `ShiftTypes.CrewStats` gains `drops: number?, noise: number?, woke: number?, dropKind: string?, dropValue: number?`.
  - `ShiftTypes.CrewLine = { userId: number, name: string, banked: number, piles: number, salvage: number, caught: number }`.
  - `ShiftTypes.Award = { title: string, name: string, userId: number, detail: string }`.
  - `ShiftTypes.ShiftResults` gains `offered: number, rating: Rating`.
  - `ShiftTypes.ShiftSnapshot` gains `crew: { number }` (crew userIds, sorted) and `truck: number?` (filled in Task 4).
  - `ShiftRosterTracker.Delta` gains `noise: number?, woke: number?`; new method `noteDrop(self, userId: number, name: string, kind: string, value: number)`.
  - `ShiftResultsUtils.rating(quotaMet: boolean, salvage: number, offered: number) -> Rating`; `ShiftResultsUtils.times(count: number) -> string`; `ShiftResultsUtils.awards(crew: { CrewStats }, lookup: (kind: string) -> CargoTypes.ItemDef?) -> { Award }`; `ResultsInput` gains `offered: number, lookup: (kind: string) -> CargoTypes.ItemDef?`.
  - `ShiftSnapshotUtils.build(state, cleared, bonus, votesAnother, votesDepot, results, crew: { number }?, truck: number?)`.
  - `ShiftCardUtils.ResultCard` gains `offered: number, rating: Rating` (the rating is always re-derived on decode, never read from the payload).
  - `OfficeSpawnUtils.salvageCount(plan: OfficeTypes.SpawnPlan) -> number`.
  - `ShiftConstants`: `RATING_EXCEEDS_LOADED = 2`, `RATING_EXCEEDS_OF = 3`, `RATING_TEXT`, `AWARD_TITLES`, `LOUDEST_MIN_WOKE = 3`.

- [ ] **Step 1: Types and constants.** In `ShiftTypes.luau` replace `CrewStats`, `CrewLine`, `Award` and extend `ShiftResults` / `ShiftSnapshot`:

```lua
-- The performance review's overall stamp (Figma 35:1096): quota missed, met, or met with the salvage threshold.
export type Rating = "needsImprovement" | "satisfactory" | "exceeds"

-- One crew member's run, as the results builder reads it.
export type CrewStats = {
	userId: number,
	name: string,
	banked: number,
	piles: number,
	salvage: number,
	-- Times Mr. Harlow caught them (M2); absent reads 0.
	caught: number?,
	-- M3 UI (the joke awards): drops by hand (and throws of fragile items), noises made, times Harlow went to
	-- investigate a noise they made, and the most valuable item they dropped (its kind and value then). Absent reads 0.
	drops: number?,
	noise: number?,
	woke: number?,
	dropKind: string?,
	dropValue: number?,
}

export type CrewLine = {
	userId: number,
	name: string,
	banked: number,
	piles: number,
	salvage: number,
	caught: number,
}

-- A joke award: its title (upper case, as stamped), who won it and the one-line reason ("hauled 140").
export type Award = {
	title: string,
	name: string,
	userId: number,
	detail: string,
}
```

In `ShiftResults` add after `catches: number,`:

```lua
	-- Salvage the shift's roll offered (open floor, under piles, in desks); `salvage` of `offered` were loaded.
	offered: number,
	rating: Rating,
```

In `ShiftSnapshot` add after `results: ShiftResults?,`:

```lua
	-- The crew's userIds (sorted), for the HUD's crew roster; empty in the lobby.
	crew: { number },
	-- The truck the crew came in (the depot's layout index), when the depart payload carried a valid one.
	truck: number?,
```

In `ShiftConstants.luau` add before `return table.freeze({`:

```lua
-- The review's rating stamp text (Figma 5a/5c) per ShiftTypes.Rating.
local RATING_TEXT: { [string]: string } = {
	needsImprovement = "NEEDS IMPROVEMENT",
	satisfactory = "SATISFACTORY",
	exceeds = "EXCEEDS EXPECTATIONS",
}

-- The joke awards' titles (Figma 5a/5c sticky notes).
local AWARD_TITLES = {
	employee = "EMPLOYEE OF THE NIGHT",
	rehired = "MOST REHIRED",
	butterfingers = "BUTTERFINGERS",
	quietest = "QUIETEST FEET",
	loudest = "LOUDEST VACUUM",
}
```

and inside the frozen table, after `STAMP_SECONDS = 3,`:

```lua
	-- The review's rating (Figma 35:1096): quota met and at least LOADED of every OF salvage offered was loaded ->
	-- EXCEEDS EXPECTATIONS. A proposal (open question 1); integers so the comparison has no float edge.
	RATING_EXCEEDS_LOADED = 2,
	RATING_EXCEEDS_OF = 3,
	RATING_TEXT = table.freeze(RATING_TEXT),
	AWARD_TITLES = table.freeze(AWARD_TITLES),
	-- The fourth award is LOUDEST VACUUM when someone's noise sent Harlow to investigate this many times, else QUIETEST FEET.
	LOUDEST_MIN_WOKE = 3,
```

- [ ] **Step 2: Write the failing specs.** Append to `ShiftRosterTracker.spec.luau` (inside its `return function()`):

```lua
	describe("review stats", function()
		it("counts noises made and times Harlow came to look", function()
			local roster = ShiftRosterTracker.new()
			roster:record(1, "Ava", { noise = 1 })
			roster:record(1, "Ava", { noise = 1, woke = 1 })
			local entry = roster:list()[1]
			expect(entry.noise).to.equal(2)
			expect(entry.woke).to.equal(1)
		end)

		it("counts drops and keeps the most valuable one", function()
			local roster = ShiftRosterTracker.new()
			roster:noteDrop(1, "Ava", "monitor", 30)
			roster:noteDrop(1, "Ava", "fishTank", 70)
			roster:noteDrop(1, "Ava", "rubbishBag", 10)
			local entry = roster:list()[1]
			expect(entry.drops).to.equal(3)
			expect(entry.dropKind).to.equal("fishTank")
			expect(entry.dropValue).to.equal(70)
		end)

		it("keeps the first of two drops worth the same", function()
			local roster = ShiftRosterTracker.new()
			roster:noteDrop(1, "Ava", "monitor", 30)
			roster:noteDrop(1, "Ava", "waterJug", 30)
			expect(roster:list()[1].dropKind).to.equal("monitor")
		end)

		it("starts a new member at zero for every stat", function()
			local roster = ShiftRosterTracker.new()
			roster:record(2, "Ben", {})
			local entry = roster:list()[1]
			expect(entry.drops).to.equal(0)
			expect(entry.noise).to.equal(0)
			expect(entry.woke).to.equal(0)
			expect(entry.dropKind).to.equal(nil)
		end)
	end)
```

Replace `ShiftResultsUtils.spec.luau` entirely:

```lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ShiftResultsUtils = require(script.Parent.ShiftResultsUtils)
local CargoRegistry = require(ReplicatedStorage.Shared.Features.Cargo.Data.CargoRegistry)

local function input(crew, extra)
	local value = {
		outcome = "clockout",
		quota = 350,
		cleared = 380,
		bonus = 95,
		quotaMet = true,
		crew = crew,
		offered = 9,
		lookup = CargoRegistry.get,
	}
	for key, item in extra or {} do
		value[key] = item
	end
	return value
end

local function member(userId, name, stats)
	local value = { userId = userId, name = name, banked = 0, piles = 0, salvage = 0 }
	for key, item in stats or {} do
		value[key] = item
	end
	return value
end

local CREW = {
	member(1, "Ava", { banked = 120, piles = 3, salvage = 1, caught = 2, noise = 5, woke = 1 }),
	member(2, "Ben", { banked = 200, piles = 6, drops = 2, dropKind = "fishTank", dropValue = 70, noise = 9 }),
	member(3, "Cat", { noise = 0, woke = 0 }),
}

local function awardOf(results, title)
	for _, award in results.awards do
		if award.title == title then
			return award
		end
	end
	return nil
end

return function()
	describe("totals and crew", function()
		it("copies the shift's totals and sums the crew's", function()
			local results = ShiftResultsUtils.build(input(CREW))
			expect(results.outcome).to.equal("clockout")
			expect(results.cleared).to.equal(380)
			expect(results.bonus).to.equal(95)
			expect(results.piles).to.equal(9)
			expect(results.salvage).to.equal(1)
			expect(results.catches).to.equal(2)
			expect(results.offered).to.equal(9)
		end)

		it("lists the crew by amount banked, with userIds and catches", function()
			local results = ShiftResultsUtils.build(input(CREW))
			expect(results.crew[1].name).to.equal("Ben")
			expect(results.crew[1].userId).to.equal(2)
			expect(results.crew[1].caught).to.equal(0)
			expect(results.crew[2].caught).to.equal(2)
		end)

		it("builds a bare review for when the real one cannot be built", function()
			local results = ShiftResultsUtils.bare("clockout", 350, true)
			expect(results.cleared).to.equal(0)
			expect(results.offered).to.equal(0)
			expect(results.rating).to.equal("satisfactory")
			expect(#results.awards).to.equal(0)
		end)
	end)

	describe("rating", function()
		it("never rates a missed quota above NEEDS IMPROVEMENT", function()
			expect(ShiftResultsUtils.rating(false, 9, 9)).to.equal("needsImprovement")
			expect(ShiftResultsUtils.rating(false, 0, 0)).to.equal("needsImprovement")
		end)

		it("reads SATISFACTORY when no salvage was offered", function()
			expect(ShiftResultsUtils.rating(true, 0, 0)).to.equal("satisfactory")
		end)

		it("reads EXCEEDS at two of every three salvage loaded", function()
			expect(ShiftResultsUtils.rating(true, 6, 9)).to.equal("exceeds")
			expect(ShiftResultsUtils.rating(true, 2, 3)).to.equal("exceeds")
		end)

		it("reads SATISFACTORY just under the threshold", function()
			expect(ShiftResultsUtils.rating(true, 5, 9)).to.equal("satisfactory")
			expect(ShiftResultsUtils.rating(true, 1, 3)).to.equal("satisfactory")
		end)

		it("puts the rating on the review", function()
			expect(ShiftResultsUtils.build(input(CREW)).rating).to.equal("satisfactory")
			expect(ShiftResultsUtils.build(input(CREW, { quotaMet = false })).rating).to.equal("needsImprovement")
		end)
	end)

	describe("joke awards", function()
		it("makes the top hauler EMPLOYEE OF THE NIGHT", function()
			local award = awardOf(ShiftResultsUtils.build(input(CREW)), "EMPLOYEE OF THE NIGHT")
			expect(award.name).to.equal("Ben")
			expect(award.userId).to.equal(2)
			expect(award.detail).to.equal("hauled 200")
		end)

		it("gives MOST REHIRED to the most caught, in words", function()
			local award = awardOf(ShiftResultsUtils.build(input(CREW)), "MOST REHIRED")
			expect(award.name).to.equal("Ava")
			expect(award.detail).to.equal("caught twice")
			expect(ShiftResultsUtils.times(1)).to.equal("once")
			expect(ShiftResultsUtils.times(3)).to.equal("3 times")
		end)

		it("names the most valuable drop on BUTTERFINGERS", function()
			local award = awardOf(ShiftResultsUtils.build(input(CREW)), "BUTTERFINGERS")
			expect(award.name).to.equal("Ben")
			expect(award.detail).to.equal("dropped the fish tank")
		end)

		it("gives no BUTTERFINGERS when nobody dropped anything", function()
			local crew = { member(1, "Ava", { banked = 10 }) }
			expect(awardOf(ShiftResultsUtils.build(input(crew)), "BUTTERFINGERS")).to.equal(nil)
		end)

		it("gives QUIETEST FEET to the fewest times heard, then the fewest noises", function()
			local award = awardOf(ShiftResultsUtils.build(input(CREW)), "QUIETEST FEET")
			expect(award.name).to.equal("Cat")
			expect(award.detail).to.equal("never heard once")
		end)

		it("swaps in LOUDEST VACUUM when someone woke him three times", function()
			local crew = { member(1, "Ava", { woke = 4 }), member(2, "Ben", { woke = 0 }) }
			local results = ShiftResultsUtils.build(input(crew))
			expect(awardOf(results, "QUIETEST FEET")).to.equal(nil)
			local award = awardOf(results, "LOUDEST VACUUM")
			expect(award.name).to.equal("Ava")
			expect(award.detail).to.equal("woke him 4 times")
		end)

		it("hands a tie to crew order (more banked, then name)", function()
			local crew = { member(1, "Zed", { banked = 50, caught = 1 }), member(2, "Amy", { banked = 50, caught = 1 }) }
			local results = ShiftResultsUtils.build(input(crew))
			expect(awardOf(results, "EMPLOYEE OF THE NIGHT").name).to.equal("Amy")
			expect(awardOf(results, "MOST REHIRED").name).to.equal("Amy")
		end)

		it("gives no award for a stat nobody scored", function()
			local results = ShiftResultsUtils.build(input({ member(1, "Ava", {}) }))
			expect(awardOf(results, "EMPLOYEE OF THE NIGHT")).to.equal(nil)
			expect(awardOf(results, "MOST REHIRED")).to.equal(nil)
			expect(#results.awards).to.equal(1) -- QUIETEST FEET only
		end)
	end)
end
```

Append to `ShiftSnapshotUtils.spec.luau` (inside `return function()`; `state` and `RESULTS` are the file's existing fixtures):

```lua
	describe("M3 UI fields", function()
		local FULL = {
			outcome = "clockout",
			quota = 350,
			cleared = 380,
			bonus = 95,
			salvage = 6,
			piles = 12,
			catches = 3,
			quotaMet = true,
			offered = 9,
			rating = "exceeds",
			crew = { { userId = 7, name = "Ava", banked = 200, piles = 6, salvage = 2, caught = 1 } },
			awards = { { title = "MOST REHIRED", name = "Ava", userId = 7, detail = "caught once" } },
		}

		it("carries the crew, the truck, the rating and the award details through build and decode", function()
			local snapshot = ShiftSnapshotUtils.build(state({ phase = "results" }), 380, 95, 1, 0, FULL, { 7, 9 }, 2)
			local decoded = ShiftSnapshotUtils.decode(snapshot)
			expect(decoded.truck).to.equal(2)
			expect(#decoded.crew).to.equal(2)
			expect(decoded.results.offered).to.equal(9)
			expect(decoded.results.rating).to.equal("exceeds")
			expect(decoded.results.crew[1].userId).to.equal(7)
			expect(decoded.results.crew[1].caught).to.equal(1)
			expect(decoded.results.awards[1].userId).to.equal(7)
			expect(decoded.results.awards[1].detail).to.equal("caught once")
		end)

		it("reads absent M3 fields as empty, zero or derived", function()
			local decoded = ShiftSnapshotUtils.decode(ShiftSnapshotUtils.build(state(), 0, 0, 0, 0, nil))
			expect(#decoded.crew).to.equal(0)
			expect(decoded.truck).to.equal(nil)
			local old = ShiftSnapshotUtils.decode(ShiftSnapshotUtils.build(state({ phase = "results" }), 0, 0, 0, 0, RESULTS))
			expect(old.results.offered).to.equal(0)
			expect(old.results.rating).to.equal("satisfactory")
			expect(old.results.crew[1].userId).to.equal(0)
			expect(old.results.awards[1].detail).to.equal("")
		end)

		it("rejects an unknown rating, a crew list that is not numbers and a text truck", function()
			local bad = table.clone(FULL)
			bad.rating = "superb"
			local results = ShiftSnapshotUtils.build(state({ phase = "results" }), 0, 0, 0, 0, bad)
			expect(ShiftSnapshotUtils.decode(results)).to.equal(nil)
			local snapshot = ShiftSnapshotUtils.build(state(), 0, 0, 0, 0, nil)
			snapshot.crew = { "Ava" }
			expect(ShiftSnapshotUtils.decode(snapshot)).to.equal(nil)
			snapshot.crew = {}
			snapshot.truck = "2"
			expect(ShiftSnapshotUtils.decode(snapshot)).to.equal(nil)
		end)
	end)
```

Append to `ShiftCardUtils.spec.luau` (inside `return function()`; the file's fixtures are `review(crewSize)` and `INFO`):

```lua
	describe("M3 UI fields", function()
		it("carries the salvage offered and derives the rating", function()
			local fixture = review(2)
			fixture.salvage = 6
			fixture.offered = 9
			fixture.quotaMet = true
			local card = ShiftCardUtils.decode(ShiftCardUtils.encode(fixture, INFO))
			expect(card.offered).to.equal(9)
			expect(card.rating).to.equal("exceeds")
		end)

		it("re-derives the rating instead of trusting the card", function()
			local payload = ShiftCardUtils.encode(review(2), INFO)
			payload.met = false
			payload.rating = "exceeds"
			expect(ShiftCardUtils.decode(payload).rating).to.equal("needsImprovement")
		end)

		it("reads an absent salvage-offered as 0 and rejects a wrong type", function()
			local payload = ShiftCardUtils.encode(review(2), INFO)
			payload.offered = nil
			expect(ShiftCardUtils.decode(payload).offered).to.equal(0)
			payload.offered = "nine"
			expect(ShiftCardUtils.decode(payload)).to.equal(nil)
		end)

		it("shows salvage as N of M and the rating", function()
			local fixture = review(2)
			review.salvage = 2
			review.offered = 9
			local text = table.concat(ShiftCardUtils.lines(ShiftCardUtils.decode(ShiftCardUtils.encode(review, INFO))), "\n")
			expect(string.find(text, "Salvage 2 of 9", 1, true) ~= nil).to.equal(true)
			expect(string.find(text, "Rating: ", 1, true) ~= nil).to.equal(true)
		end)
	end)
```

(Add `offered = 9` to the table `review(crewSize)` builds: the review type now requires it.)

Append to `OfficeSpawnUtils.spec.luau` (inside `return function()`):

```lua
	describe("salvageCount", function()
		it("counts salvage on the floor, under piles and in desks, and nothing else", function()
			local plan = {
				items = { { marker = "a", kind = "monitor" }, { marker = "b", kind = "rubbishBag" } },
				piles = { { marker = "c", kind = "paper", hides = "plaque" }, { marker = "d", kind = "paper" } },
				searchables = { { marker = "e", kind = "goldenStapler" }, { marker = "f" } },
				trashValue = 0,
			}
			expect(OfficeSpawnUtils.salvageCount(plan)).to.equal(3)
		end)
	end)
```

(Check the ids `rubbishBag`, `plaque`, `goldenStapler`, `monitor` with `grep -n "define(" src/ReplicatedStorage/Shared/Features/Cargo/Data/CargoRegistry.luau`, and the pile kind word with `grep -n "kind" src/ReplicatedStorage/Shared/Features/Vacuum/Data/VacuumConstants.luau`; use the real ids.)

- [ ] **Step 3: Controller: Studio TestEZ.** Expected: the new cases fail (missing functions and fields); every other case passes.

- [ ] **Step 4: Implement `ShiftRosterTracker`.** Replace `Delta`, add `noteDrop` to the type, and build entries through one helper:

```lua
export type Delta = {
	banked: number?,
	piles: number?,
	salvage: number?,
	caught: number?,
	noise: number?,
	woke: number?,
}
```

```lua
	-- One drop by hand (or a fragile throw); keeps the most valuable item dropped (the first on a tie).
	noteDrop: (self: ShiftRosterTracker, userId: number, name: string, kind: string, value: number) -> (),
```

```lua
	local function entryFor(userId: number, name: string): ShiftTypes.CrewStats
		local entry = roster[userId]
		if entry == nil then
			entry = { userId = userId, name = name, banked = 0, piles = 0, salvage = 0, caught = 0, drops = 0, noise = 0, woke = 0 }
			roster[userId] = entry
		end
		return entry
	end

	local tracker: ShiftRosterTracker = {
		record = function(_self, userId, name, delta)
			local entry = entryFor(userId, name)
			entry.banked += delta.banked or 0
			entry.piles += delta.piles or 0
			entry.salvage += delta.salvage or 0
			entry.caught = (entry.caught or 0) + (delta.caught or 0)
			entry.noise = (entry.noise or 0) + (delta.noise or 0)
			entry.woke = (entry.woke or 0) + (delta.woke or 0)
		end,

		noteDrop = function(_self, userId, name, kind, value)
			local entry = entryFor(userId, name)
			entry.drops = (entry.drops or 0) + 1
			if entry.dropKind == nil or value > (entry.dropValue or 0) then
				entry.dropKind = kind
				entry.dropValue = value
			end
		end,
```

(`list` and `clear` unchanged.)

- [ ] **Step 5: Implement `ShiftResultsUtils`.** Update the header (the awards are now Figma's four joke awards plus the rating; ties go to crew order), and replace everything below the requires:

```lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CargoTypes = require(ReplicatedStorage.Shared.Features.Cargo.Data.CargoTypes)
local ShiftConstants = require(ReplicatedStorage.Shared.Features.Shift.Data.ShiftConstants)
local ShiftTypes = require(ReplicatedStorage.Shared.Features.Shift.Data.ShiftTypes)

type CrewStats = ShiftTypes.CrewStats
type Lookup = (kind: string) -> CargoTypes.ItemDef?

export type ResultsInput = {
	outcome: string,
	quota: number,
	cleared: number,
	bonus: number,
	quotaMet: boolean,
	crew: { CrewStats },
	-- Salvage the shift's roll offered (OfficeSpawnUtils.salvageCount).
	offered: number,
	-- The cargo catalog (CargoRegistry.get), for item names in award details.
	lookup: Lookup,
}

local ShiftResultsUtils = {}

-- "once", "twice", "3 times".
function ShiftResultsUtils.times(count: number): string
	if count == 1 then
		return "once"
	elseif count == 2 then
		return "twice"
	end
	return `{count} times`
end

--[=[
	The overall stamp: a missed quota is NEEDS IMPROVEMENT whatever else happened; a met quota is SATISFACTORY, or
	EXCEEDS EXPECTATIONS when at least RATING_EXCEEDS_LOADED of every RATING_EXCEEDS_OF salvage offered was loaded.
	Nothing offered never exceeds.
]=]
function ShiftResultsUtils.rating(quotaMet: boolean, salvage: number, offered: number): ShiftTypes.Rating
	if not quotaMet then
		return "needsImprovement"
	end
	local loaded, of = ShiftConstants.RATING_EXCEEDS_LOADED, ShiftConstants.RATING_EXCEEDS_OF
	if offered > 0 and salvage * of >= offered * loaded then
		return "exceeds"
	end
	return "satisfactory"
end

-- Whoever leads `score` with more than zero (the first in crew order on a tie), and their score.
local function leader(crew: { CrewStats }, score: (member: CrewStats) -> number): (CrewStats?, number)
	local best: CrewStats? = nil
	local bestScore = 0
	for _, member in crew do
		local value = score(member)
		if value > bestScore then
			best = member
			bestScore = value
		end
	end
	return best, bestScore
end

-- Fewest times heard, then fewest noises (the first in crew order on a tie); nil for an empty crew.
local function quietest(crew: { CrewStats }): CrewStats?
	local best: CrewStats? = nil
	for _, member in crew do
		local current = best
		if current == nil then
			best = member
		else
			local woke, bestWoke = member.woke or 0, current.woke or 0
			if woke < bestWoke or (woke == bestWoke and (member.noise or 0) < (current.noise or 0)) then
				best = member
			end
		end
	end
	return best
end

--[=[
	The four joke awards (Figma 5a/5c), from a crew already in crew order: EMPLOYEE OF THE NIGHT (most banked),
	MOST REHIRED (most caught), BUTTERFINGERS (most drops; names the most valuable), and LOUDEST VACUUM when someone
	woke Harlow LOUDEST_MIN_WOKE times, else QUIETEST FEET. A stat nobody scored gives no award.
]=]
function ShiftResultsUtils.awards(crew: { CrewStats }, lookup: Lookup): { ShiftTypes.Award }
	local titles = ShiftConstants.AWARD_TITLES
	local awards: { ShiftTypes.Award } = {}
	local function add(title: string, member: CrewStats, detail: string)
		table.insert(awards, { title = title, name = member.name, userId = member.userId, detail = detail })
	end
	local hauler, hauled = leader(crew, function(member)
		return member.banked
	end)
	if hauler ~= nil then
		add(titles.employee, hauler, `hauled {hauled}`)
	end
	local rehired, caught = leader(crew, function(member)
		return member.caught or 0
	end)
	if rehired ~= nil then
		add(titles.rehired, rehired, `caught {ShiftResultsUtils.times(caught)}`)
	end
	local fumbler, drops = leader(crew, function(member)
		return member.drops or 0
	end)
	if fumbler ~= nil then
		local kind = fumbler.dropKind
		local def = if kind ~= nil then lookup(kind) else nil
		local detail = if def ~= nil
			then `dropped the {string.lower(def.name)}`
			else `dropped things {ShiftResultsUtils.times(drops)}`
		add(titles.butterfingers, fumbler, detail)
	end
	local loudest, woke = leader(crew, function(member)
		return member.woke or 0
	end)
	if loudest ~= nil and woke >= ShiftConstants.LOUDEST_MIN_WOKE then
		add(titles.loudest, loudest, `woke him {ShiftResultsUtils.times(woke)}`)
	else
		local quiet = quietest(crew)
		if quiet ~= nil then
			local heard = quiet.woke or 0
			add(titles.quietest, quiet, if heard == 0 then "never heard once" else `heard {ShiftResultsUtils.times(heard)}`)
		end
	end
	return awards
end

-- An empty review: what the shift falls back to when building the real one throws.
function ShiftResultsUtils.bare(outcome: string, quota: number, quotaMet: boolean): ShiftTypes.ShiftResults
	return {
		outcome = outcome,
		quota = quota,
		cleared = 0,
		bonus = 0,
		salvage = 0,
		piles = 0,
		catches = 0,
		offered = 0,
		rating = ShiftResultsUtils.rating(quotaMet, 0, 0),
		quotaMet = quotaMet,
		crew = {},
		awards = {},
	}
end

function ShiftResultsUtils.build(input: ResultsInput): ShiftTypes.ShiftResults
	local crew = table.clone(input.crew)
	table.sort(crew, function(a, b)
		if a.banked ~= b.banked then
			return a.banked > b.banked
		end
		return a.name < b.name
	end)
	local lines: { ShiftTypes.CrewLine } = {}
	local salvage, piles, catches = 0, 0, 0
	for _, member in crew do
		table.insert(lines, {
			userId = member.userId,
			name = member.name,
			banked = member.banked,
			piles = member.piles,
			salvage = member.salvage,
			caught = member.caught or 0,
		})
		salvage += member.salvage
		piles += member.piles
		catches += member.caught or 0
	end
	return {
		outcome = input.outcome,
		quota = input.quota,
		cleared = input.cleared,
		bonus = input.bonus,
		salvage = salvage,
		piles = piles,
		catches = catches,
		offered = input.offered,
		rating = ShiftResultsUtils.rating(input.quotaMet, salvage, input.offered),
		quotaMet = input.quotaMet,
		crew = lines,
		awards = ShiftResultsUtils.awards(crew, input.lookup),
	}
end

return ShiftResultsUtils
```

- [ ] **Step 6: Implement `OfficeSpawnUtils.salvageCount`** (the module already requires `CargoRegistry`):

```lua
--[=[
	How many salvage items a plan offers: on the open floor, hidden under piles and in desks or lockers (the review's
	"salvage found N of M").
]=]
function OfficeSpawnUtils.salvageCount(plan: OfficeTypes.SpawnPlan): number
	local count = 0
	local function add(kind: string?)
		local def = if kind ~= nil then CargoRegistry.get(kind) else nil
		if def ~= nil and def.category == "salvage" then
			count += 1
		end
	end
	for _, item in plan.items do
		add(item.kind)
	end
	for _, pile in plan.piles do
		add(pile.hides)
	end
	for _, search in plan.searchables do
		add(search.kind)
	end
	return count
end
```

If `plan.greed` can name an item that is not also in `items` / `piles` / `searchables`, `grep -n "greed" src/ServerScriptService/Features/Office/Utils/OfficeSpawnUtils.luau` tells; the greed target is placed through one of those lists, so it is counted once.

- [ ] **Step 7: Implement `ShiftSnapshotUtils`.** Add the two decoders:

```lua
local function ratingOf(value: WorldValue?, quotaMet: boolean): ShiftTypes.Rating?
	if value == nil then
		-- A review from before M3 UI: derive what it can (no salvage share known).
		return if quotaMet then "satisfactory" else "needsImprovement"
	elseif value == "needsImprovement" then
		return "needsImprovement"
	elseif value == "satisfactory" then
		return "satisfactory"
	elseif value == "exceeds" then
		return "exceeds"
	end
	return nil
end

-- A list of userIds: absent reads empty; anything but numbers is malformed.
local function idsOf(value: WorldValue?): { number }?
	local result: { number } = {}
	if value == nil then
		return result
	end
	if type(value) ~= "table" then
		return nil
	end
	for _, item in value do
		if type(item) ~= "number" then
			return nil
		end
		table.insert(result, item)
	end
	return result
end
```

In `crewOf`, before its `table.insert` (absent userId / caught read 0):

```lua
		local userId, userOk = countOf(item.userId)
		local caught, caughtOk = countOf(item.caught)
		if not userOk or not caughtOk then
			return nil
		end
		table.insert(
			result,
			{ userId = userId, name = name, banked = banked, piles = piles, salvage = salvage, caught = caught }
		)
```

In `awardsOf` (absent userId → 0, absent detail → ""):

```lua
		local userId, userOk = countOf(item.userId)
		local detail = item.detail
		if not userOk or (detail ~= nil and type(detail) ~= "string") then
			return nil
		end
		table.insert(result, {
			title = title,
			name = name,
			userId = userId,
			detail = if type(detail) == "string" then detail else "",
		})
```

In `resultsOf`, after the `catchesOk` check:

```lua
	local offered, offeredOk = countOf(value.offered)
	local rating: ShiftTypes.Rating? = ratingOf(value.rating, quotaMet)
	if not offeredOk or not rating then
		return nil, false
	end
```

and add `offered = offered,` and `rating = rating,` to its returned table. `build` gains two trailing parameters `crew: { number }?, truck: number?` and sets `crew = if crew ~= nil then table.clone(crew) else {},` and `truck = truck,`. In `decode`, before building `snapshot`:

```lua
	local crew = idsOf(value.crew)
	local truck, truckOk = optionalNumber(value.truck)
	if crew == nil or not truckOk then
		return nil
	end
```

and add `crew = crew,` and `truck = truck,` to `snapshot`. Update the header's field list.

- [ ] **Step 8: Implement `ShiftCardUtils`.** Add `offered: number, rating: ShiftTypes.Rating,` to `ResultCard`; require `ShiftConstants` (`ReplicatedStorage.Shared.Features.Shift.Data.ShiftConstants`) and `ShiftResultsUtils` (`ServerScriptService.Features.Shift.Utils.ShiftResultsUtils`, with `local ServerScriptService = game:GetService("ServerScriptService")`). `encode` adds `offered = results.offered,` (28 keys of Queue's 32: update the header's key list). In `decode`, after `local awardCount = count(payload.awards)`:

```lua
	-- Absent on a card written before M3 UI.
	local offered = if payload.offered == nil then 0 else count(payload.offered)
```

add `or offered == nil` to the big rejection `if`, and return `offered = offered,` and `rating = ShiftResultsUtils.rating(met, salvage, offered),` (a payload's own `rating` key, if any, is never read). In `lines`, replace the salvage line and add the rating line:

```lua
		`Salvage {card.salvage} of {card.offered} | Piles {card.piles} | Caught {card.catches}`,
		`Rating: {ShiftConstants.RATING_TEXT[card.rating] or card.rating}`,
```

- [ ] **Step 9: Wire `ShiftServiceServer`** (+5 code lines, 382 → 387). After `local ShiftConstants = require(ShiftShared.Data.ShiftConstants)` add `local CargoRegistry = require(ReplicatedStorage.Shared.Features.Cargo.Data.CargoRegistry)`; after `local OfficeServiceServer = require(...)` add `local OfficeSpawnUtils = require(ServerScriptService.Features.Office.Utils.OfficeSpawnUtils)`. After `local results: ShiftTypes.ShiftResults? = nil`:

```lua
-- Salvage this run's roll offered (the review's "salvage found N of M").
local offered = 0
```

In `beginRun`, after the `local plan = OfficeServiceServer:beginShift({...})` statement: `offered = OfficeSpawnUtils.salvageCount(plan)`. In `buildResults`, add `offered = offered,` and `lookup = CargoRegistry.get,` to the `ShiftResultsUtils.build({...})` table. In `publish`, pass the crew as the seventh argument: `ShiftSnapshotUtils.build(state, cleared, bonus, another, depot, review, trip:crewIds())`.

- [ ] **Step 10: Controller: Studio TestEZ.** Expected: every `ShiftRosterTracker`, `ShiftResultsUtils`, `ShiftSnapshotUtils`, `ShiftCardUtils` and `OfficeSpawnUtils` case passes, and the existing `ShiftHudViewModel` results cases still pass (they read `title` / `name`).

- [ ] **Step 11: Play check (controller, `RunTests = false`):** a solo shift, bank something, clock out. The placeholder review lists "EMPLOYEE OF THE NIGHT: <you>" and "QUIETEST FEET: <you>"; no server errors.

- [ ] **Step 12: Gate and commit**

```bash
git add src
python3 scripts/python/module_map.py --write
git add docs/project-structure.md
stylua src/ReplicatedStorage/Shared/Features/Shift/Data/ShiftTypes.luau src/ReplicatedStorage/Shared/Features/Shift/Data/ShiftConstants.luau src/ServerScriptService/Features/Shift/State/ShiftRosterTracker.luau src/ServerScriptService/Features/Shift/State/ShiftRosterTracker.spec.luau src/ServerScriptService/Features/Shift/Utils/ShiftResultsUtils.luau src/ServerScriptService/Features/Shift/Utils/ShiftResultsUtils.spec.luau src/ReplicatedStorage/Shared/Features/Shift/Utils/ShiftSnapshotUtils.luau src/ReplicatedStorage/Shared/Features/Shift/Utils/ShiftSnapshotUtils.spec.luau src/ServerScriptService/Features/Shift/Utils/ShiftCardUtils.luau src/ServerScriptService/Features/Shift/Utils/ShiftCardUtils.spec.luau src/ServerScriptService/Features/Office/Utils/OfficeSpawnUtils.luau src/ServerScriptService/Features/Office/Utils/OfficeSpawnUtils.spec.luau src/ServerScriptService/Features/Shift/ShiftServiceServer.luau
git add src
bash .superpowers/sdd/gate.sh
python3 scripts/python/check_pr_rules.py origin/main
git commit -m "feat(shift): review rating, joke-award stats and salvage offered"
python3 scripts/python/module_map.py --check
```

---

### Task 2: Who made each noise, and the review's live counters

Noise events gain their makers; Vacuum learns who is vacuuming which pile right now; a new Shift system feeds the roster's drops, noise and "woke him" counters and takes over the piles counter from the service (which pays for the lines).

**Files:**
- Create: `src/ServerScriptService/Features/Vacuum/State/VacuumChannelTracker.luau`; Test: `src/ServerScriptService/Features/Vacuum/State/VacuumChannelTracker.spec.luau`
- Create: `src/ServerScriptService/Features/Shift/Systems/ShiftReviewSystem.luau` (spec-exempt shell)
- Modify: `src/ReplicatedStorage/Shared/Features/Noise/Data/NoiseTypes.luau`, `src/ServerScriptService/Features/Noise/NoiseServiceServer.luau`
- Modify: `src/ReplicatedStorage/Shared/Features/Vacuum/Data/VacuumConstants.luau`, `src/ServerScriptService/Features/Vacuum/VacuumServiceServer.luau`
- Modify: `src/ServerScriptService/Features/Cargo/CargoServiceServer.luau` (line-neutral: 400 → 400), `src/ServerScriptService/Features/Cargo/Systems/CargoTraitSystem.luau`
- Modify: `src/ServerScriptService/Features/Shift/Utils/ShiftAnalyticsUtils.luau`; Test: `src/ServerScriptService/Features/Shift/Utils/ShiftAnalyticsUtils.spec.luau`
- Modify: `src/ServerScriptService/Features/Shift/State/ShiftAnalyticsTracker.luau` (only if `noteNoise` copies fields one by one)
- Modify: `src/ServerScriptService/Features/Shift/Systems/ShiftAnalyticsWatchSystem.luau`
- Modify: `src/ServerScriptService/Features/Shift/ShiftServiceServer.luau` (about −7 code lines: 387 → ~380)
- Modify: `src/ServerScriptService/Core/Testing/SpecRoots.luau`

**Interfaces:**
- Consumes: `ShiftRosterTracker:record / noteDrop` (Task 1); `CarryServiceServer.dropped: Signal<Player, Instance, CarryTypes.DropReason>` (`"drop" | "throw" | "forced" | "death" | "removed" | "destroyed"`); `NoiseServiceServer.made`; `VacuumServiceServer.pileCleared`.
- Produces:
  - `NoiseTypes.NoiseEvent` gains `makers: { number }` (userIds; empty when nobody is known).
  - `NoiseServiceServer:emit(position: Vector3, radius: number, source: string, makers: { number }?)`.
  - `VacuumServiceServer.noiseMade` and `CargoServiceServer.noiseMade`: `SignalTyped.Signal<Vector3, number, string, { number }>`; `VacuumServiceServer:isVacuuming(player: Player) -> boolean`.
  - `VacuumChannelTracker.new(window: number)` with `note(self, userId: number, pile: Instance, now: number) -> boolean` (true when this is a new pile for them: a start), `makersOn(self, pile: Instance, now: number) -> { number }` (sorted), `isActive(self, userId: number, now: number) -> boolean`, `forget(self, userId: number)`, `clear(self)`.
  - `ShiftAnalyticsUtils.Noise` gains `makers: { number }`; `ShiftAnalyticsUtils.heardNoise(noises, listener, scale, now) -> Noise?` (`heardSource` keeps its signature).
  - `ShiftAnalyticsWatchSystem.investigated: SignalTyped.Signal<{ number }>` (the makers of the noise Harlow went to investigate).
  - `ShiftReviewSystem.start(roster: ShiftRosterTracker.ShiftRosterTracker, running: () -> boolean) -> () -> ()`.
  - `VacuumConstants.MAKER_WINDOW = 0.5`.

- [ ] **Step 1: Write the failing specs.** `src/ServerScriptService/Features/Vacuum/State/VacuumChannelTracker.spec.luau`:

```lua
local VacuumChannelTracker = require(script.Parent.VacuumChannelTracker)

return function()
	local pileA, pileB
	beforeEach(function()
		pileA = Instance.new("Part")
		pileB = Instance.new("Part")
	end)
	afterEach(function()
		pileA:Destroy()
		pileB:Destroy()
	end)

	it("reports a start only for a new pile", function()
		local tracker = VacuumChannelTracker.new(0.5)
		expect(tracker:note(1, pileA, 10)).to.equal(true)
		expect(tracker:note(1, pileA, 10.1)).to.equal(false)
		expect(tracker:note(1, pileB, 10.2)).to.equal(true)
	end)

	it("keeps the same pile a non-start after a release and re-press", function()
		local tracker = VacuumChannelTracker.new(0.5)
		tracker:note(1, pileA, 10)
		expect(tracker:note(1, pileA, 20)).to.equal(false)
	end)

	it("names only the players still channeling that pile", function()
		local tracker = VacuumChannelTracker.new(0.5)
		tracker:note(1, pileA, 10)
		tracker:note(2, pileA, 10.3)
		tracker:note(3, pileB, 10.3)
		local makers = tracker:makersOn(pileA, 10.4)
		expect(#makers).to.equal(2)
		expect(makers[1]).to.equal(1)
		expect(makers[2]).to.equal(2)
		-- Player 1 stopped asking (released the button) more than a window ago.
		expect(#tracker:makersOn(pileA, 10.6)).to.equal(1)
	end)

	it("says whether a player is vacuuming right now", function()
		local tracker = VacuumChannelTracker.new(0.5)
		tracker:note(1, pileA, 10)
		expect(tracker:isActive(1, 10.4)).to.equal(true)
		expect(tracker:isActive(1, 10.6)).to.equal(false)
		expect(tracker:isActive(2, 10)).to.equal(false)
	end)

	it("forgets a leaver and clears everyone", function()
		local tracker = VacuumChannelTracker.new(0.5)
		tracker:note(1, pileA, 10)
		tracker:note(2, pileA, 10)
		tracker:forget(1)
		expect(#tracker:makersOn(pileA, 10)).to.equal(1)
		tracker:clear()
		expect(#tracker:makersOn(pileA, 10)).to.equal(0)
		expect(tracker:note(2, pileA, 11)).to.equal(true)
	end)
end
```

Append to `ShiftAnalyticsUtils.spec.luau` (inside `return function()`):

```lua
	describe("heardNoise", function()
		local function noise(source, x, radius, at, makers)
			return { source = source, position = Vector3.new(x, 0, 0), radius = radius, at = at, makers = makers or {} }
		end

		it("returns the makers of the noise he most likely heard", function()
			local noises = { noise("drop", 0, 40, 9, { 2 }), noise("vacuum", 5, 40, 9.5, { 1, 3 }) }
			local heard = ShiftAnalyticsUtils.heardNoise(noises, Vector3.new(10, 0, 0), 1, 10)
			expect(heard.source).to.equal("vacuum")
			expect(#heard.makers).to.equal(2)
		end)

		it("skips a noise that could not reach him, and returns nil when none did", function()
			local noises = { noise("drop", 0, 40, 9, { 2 }), noise("vacuum", 200, 40, 9.5, { 1 }) }
			expect(ShiftAnalyticsUtils.heardNoise(noises, Vector3.new(10, 0, 0), 1, 10).source).to.equal("drop")
			expect(ShiftAnalyticsUtils.heardNoise({}, Vector3.zero, 1, 10)).to.equal(nil)
		end)

		it("keeps heardSource answering with the source word", function()
			local noises = { noise("search", 0, 40, 9, { 4 }) }
			expect(ShiftAnalyticsUtils.heardSource(noises, Vector3.new(1, 0, 0), 1, 10)).to.equal("search")
			expect(ShiftAnalyticsUtils.heardSource({}, Vector3.zero, 1, 10)).to.equal("unknown")
		end)
	end)
```

(The existing `heardSource` cases build noises without `makers`; add `makers = {}` to their fixtures so they match the widened type.)

- [ ] **Step 2: Controller: Studio TestEZ.** Expected: the new cases fail (module missing, `heardNoise` nil).

- [ ] **Step 3: Implement `VacuumChannelTracker`:**

```lua
--!strict
--[=[
	VacuumChannelTracker: who is vacuuming which pile right now (Cleanup Crew M3 UI: the crew roster's "vacuuming" and
	the makers of each vacuum noise pulse, for the review's QUIETEST FEET / LOUDEST VACUUM). The Interaction channel asks
	Vacuum's `canChannel` at the start and every tick while a player holds the button; each allowed ask is `note`d. A
	player counts as vacuuming their last pile until `window` seconds pass with no ask (released, or the channel ended).
	`note` reports a start when the pile differs from their last one, exactly like the map it replaces. Plain
	bookkeeping (pure: it never touches the Instances it keys by).

	@class VacuumChannelTracker
]=]

export type VacuumChannelTracker = {
	note: (self: VacuumChannelTracker, userId: number, pile: Instance, now: number) -> boolean,
	makersOn: (self: VacuumChannelTracker, pile: Instance, now: number) -> { number },
	isActive: (self: VacuumChannelTracker, userId: number, now: number) -> boolean,
	forget: (self: VacuumChannelTracker, userId: number) -> (),
	clear: (self: VacuumChannelTracker) -> (),
}

type Channel = { pile: Instance, at: number }

local VacuumChannelTracker = {}

function VacuumChannelTracker.new(window: number): VacuumChannelTracker
	local channels: { [number]: Channel } = {}

	local tracker: VacuumChannelTracker = {
		note = function(_self, userId, pile, now)
			local current = channels[userId]
			local started = current == nil or current.pile ~= pile
			channels[userId] = { pile = pile, at = now }
			return started
		end,

		makersOn = function(_self, pile, now)
			local makers: { number } = {}
			for userId, channel in channels do
				if channel.pile == pile and now - channel.at <= window then
					table.insert(makers, userId)
				end
			end
			table.sort(makers)
			return makers
		end,

		isActive = function(_self, userId, now)
			local channel = channels[userId]
			return channel ~= nil and now - channel.at <= window
		end,

		forget = function(_self, userId)
			channels[userId] = nil
		end,

		clear = function(_self)
			table.clear(channels)
		end,
	}
	return tracker
end

return VacuumChannelTracker
```

- [ ] **Step 4: Wire Vacuum.** `VacuumConstants`: add `-- Seconds a vacuuming player stays counted after their channel's last tick (the channel asks every 0.1 s). MAKER_WINDOW = 0.5,`. `VacuumServiceServer`:
  - require `VacuumChannelTracker` from `ServerScriptService.Features.Vacuum.State.VacuumChannelTracker`; replace the `vacuuming` map declaration with `local channels = VacuumChannelTracker.new(VacuumConstants.MAKER_WINDOW)`;
  - `noiseMade` is `SignalTyped.Signal<Vector3, number, string, { number }>` (declaration and type field);
  - `pulse()` fires `noiseMade:Fire(pile.Position, VacuumConstants.NOISE_RADIUS, "vacuum", channels:makersOn(pile, os.clock()))`;
  - in `canChannel` replace the `vacuuming[...]` block:

```lua
				-- Asked at the start and every tick: the first allowed ask on a new pile is a start (never yields).
				if channels:note(player.UserId, target, os.clock()) and target:IsA("BasePart") then
					vacuumStarted:Fire(player, target)
				end
```

  - `PlayerRemoving` calls `channels:forget(player.UserId)`; wherever `vacuuming` was cleared (`reset`), `channels:clear()`;
  - new method (type field `isVacuuming: (self: VacuumServiceServer, player: Player) -> boolean,`):

```lua
	--[=[
		Whether `player` is vacuuming a pile right now (their channel asked within MAKER_WINDOW).
	]=]
	isVacuuming = function(_self, player)
		return channels:isActive(player.UserId, os.clock())
	end,
```

  `grep -n "vacuuming\[" src/ServerScriptService/Features/Vacuum/VacuumServiceServer.luau` must print nothing afterwards.

- [ ] **Step 5: Makers through Noise and Cargo.**
  - `NoiseTypes.NoiseEvent` gains `-- Who made it (userIds): the vacuumers on the pile, the dropper, the carrier, the searcher; empty when unknown.` `makers: { number },`.
  - `NoiseServiceServer`: `emit: (self: NoiseServiceServer, position: Vector3, radius: number, source: string, makers: { number }?) -> ()`; the event is `{ position = position, radius = radius, source = source, makers = makers or {} }`; both relays take and pass a fourth parameter `makers: { number }`.
  - `CargoServiceServer` (line-neutral): both `Signal<Vector3, number, string>` mentions become `Signal<Vector3, number, string, { number }>`; in `onDropped` rename `_player` to `player` and fire `noiseMade:Fire(position, CargoHandlingRules.dropNoise(def), "drop", { player.UserId })`; the search fire (around line 445) passes the searching player's id the same way (read the enclosing function's parameter name first). `python3 scripts/python/check_file_length.py` must still pass with Cargo at 400.
  - `CargoTraitSystem`: `deps.noiseMade`'s type gains `{ number }`; the rattle becomes `deps.noiseMade:Fire(root.Position, CargoConstants.RATTLE_NOISE, "rattle", { player.UserId })`; its own `noises` listener keeps its three parameters.
  - `grep -rn "noiseMade:Fire\|:emit(" src/ServerScriptService` lists every other site: give each the makers it knows, or `{}`.

- [ ] **Step 6: `heardNoise` and the investigated signal.** `ShiftAnalyticsUtils`: add `makers: { number },` to `Noise`; replace `heardSource` with:

```lua
--[=[
	The noise Harlow most likely heard: the newest one within NOISE_MEMORY whose heard radius reached him; nil if none.
]=]
function ShiftAnalyticsUtils.heardNoise(noises: { Noise }, listener: Vector3, scale: number, now: number): Noise?
	for index = #noises, 1, -1 do
		local noise = noises[index]
		local recent = now - noise.at <= ShiftAnalyticsConstants.NOISE_MEMORY
		if recent and (listener - noise.position).Magnitude <= noise.radius * scale then
			return noise
		end
	end
	return nil
end

function ShiftAnalyticsUtils.heardSource(noises: { Noise }, listener: Vector3, scale: number, now: number): string
	local noise = ShiftAnalyticsUtils.heardNoise(noises, listener, scale, now)
	return if noise ~= nil then noise.source else "unknown"
end
```

`ShiftAnalyticsWatchSystem`: `onNoise` stores `makers = table.clone(event.makers),` (and `ShiftAnalyticsTracker.noteNoise` keeps it if it copies fields); near the top `local investigated: SignalTyped.Signal<{ number }> = SignalTyped.new()`; right after `local ShiftAnalyticsWatchSystem = {}`: `ShiftAnalyticsWatchSystem.investigated = investigated`; `readHarlow`'s `noise_investigation` branch computes the noise once:

```lua
		local noise = ShiftAnalyticsUtils.heardNoise(ShiftAnalyticsSystem.tracker:noises(), position, scale, os.clock())
		ShiftAnalyticsSystem.emit("noise_investigation", "crew", {
			target = if noise ~= nil then noise.source else "unknown",
			outcome = ShiftAnalyticsSystem.quotaTag(),
			value = ShiftAnalyticsSystem.elapsed(),
		})
		if noise ~= nil and #noise.makers > 0 then
			investigated:Fire(table.clone(noise.makers))
		end
		return now
```

Update the header: "`investigated` tells the review who woke him (ShiftReviewSystem)".

- [ ] **Step 7: `ShiftReviewSystem`:**

```lua
--!strict
--[=[
	ShiftReviewSystem: keeps each crew member's review stats while a shift runs (Cleanup Crew M3 UI: the performance
	review's joke awards). It listens to the features that own the facts and writes the roster (ShiftRosterTracker):
	- Vacuum `pileCleared`: a pile for everyone on it, and Round's per-player `piles` score (moved from
	  ShiftServiceServer);
	- Carry `dropped`: a drop by hand, or a throw of a fragile item (a break), with the item's kind and value then.
	  Catch drops ("death"), pocketing and banking ("forced") and resets never count;
	- Noise `made`: one noise for each maker;
	- ShiftAnalyticsWatchSystem `investigated`: Harlow went to investigate a noise; each of its makers woke him once.

	Spec-exempt shell (signals, Players); the counting is the specced ShiftRosterTracker, the awards the specced
	ShiftResultsUtils.

	@class ShiftReviewSystem
]=]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local CargoConstants = require(ReplicatedStorage.Shared.Features.Cargo.Data.CargoConstants)
local CargoRegistry = require(ReplicatedStorage.Shared.Features.Cargo.Data.CargoRegistry)
local CarryConstants = require(ReplicatedStorage.Shared.Features.Carry.Data.CarryConstants)
local CarryTypes = require(ReplicatedStorage.Shared.Features.Carry.Data.CarryTypes)
local NoiseTypes = require(ReplicatedStorage.Shared.Features.Noise.Data.NoiseTypes)
local ShiftConstants = require(ReplicatedStorage.Shared.Features.Shift.Data.ShiftConstants)
local CarryServiceServer = require(ServerScriptService.Features.Carry.CarryServiceServer)
local NoiseServiceServer = require(ServerScriptService.Features.Noise.NoiseServiceServer)
local RoundServiceServer = require(ServerScriptService.Features.Round.RoundServiceServer)
local VacuumServiceServer = require(ServerScriptService.Features.Vacuum.VacuumServiceServer)
local ShiftRosterTracker = require(ServerScriptService.Features.Shift.State.ShiftRosterTracker)
local ShiftAnalyticsWatchSystem = require(ServerScriptService.Features.Shift.Systems.ShiftAnalyticsWatchSystem)

local function nameOf(userId: number): string?
	local player = Players:GetPlayerByUserId(userId)
	return if player ~= nil then player.DisplayName else nil
end

local ShiftReviewSystem = {}

function ShiftReviewSystem.start(roster: ShiftRosterTracker.ShiftRosterTracker, running: () -> boolean): () -> ()
	local function each(makers: { number }, delta: ShiftRosterTracker.Delta)
		if not running() then
			return
		end
		for _, userId in makers do
			local name = nameOf(userId)
			if name ~= nil then
				roster:record(userId, name, delta)
			end
		end
	end

	local piles = VacuumServiceServer.pileCleared:Connect(function(_pile: BasePart, players: { Player })
		if not running() then
			return
		end
		for _, player in players do
			if player.Parent ~= nil then
				RoundServiceServer:addScore(player, ShiftConstants.SCORE_PILES, 1)
				roster:record(player.UserId, player.DisplayName, { piles = 1 })
			end
		end
	end)

	local drops = CarryServiceServer.dropped:Connect(
		function(player: Player, object: Instance, reason: CarryTypes.DropReason)
			local kind = object:GetAttribute(CarryConstants.KIND_ATTRIBUTE)
			local def = if type(kind) == "string" then CargoRegistry.get(kind) else nil
			if not running() or def == nil or player.Parent == nil then
				return
			end
			if reason == "drop" or (reason == "throw" and def.fragile) then
				local value = object:GetAttribute(CargoConstants.VALUE_ATTRIBUTE)
				roster:noteDrop(player.UserId, player.DisplayName, def.id, if type(value) == "number" then value else def.value)
			end
		end
	)

	local noises = NoiseServiceServer.made:Connect(function(event: NoiseTypes.NoiseEvent)
		each(event.makers, { noise = 1 })
	end)

	local woke = ShiftAnalyticsWatchSystem.investigated:Connect(function(makers: { number })
		each(makers, { woke = 1 })
	end)

	return function()
		piles:Disconnect()
		drops:Disconnect()
		noises:Disconnect()
		woke:Disconnect()
	end
end

return ShiftReviewSystem
```

Carry's `dropped` is delivered deferred (SignalPlus): by then a fragile item's `CargoValue` attribute may already be the damaged value. That is fine: BUTTERFINGERS ranks by the value when it hit the floor.

- [ ] **Step 8: Hand the piles counter over in `ShiftServiceServer`.** Delete the `local piles = VacuumServiceServer.pileCleared:Connect(...)` block and its `piles:Disconnect()` line; add the require after `ShiftAnalyticsWatchSystem`'s: `local ShiftReviewSystem = require(ShiftServer.Systems.ShiftReviewSystem)`; add near `now()`:

```lua
local function isRunning(): boolean
	return state.phase == "running"
end
```

and after `table.insert(stoppers, ShiftAnalyticsWatchSystem.start(changed, trip))`: `table.insert(stoppers, ShiftReviewSystem.start(roster, isRunning))`. Update the header ("ShiftReviewSystem counts piles, drops, noise and times heard for the review"). Run the file-length check: Shift ≈ 380.

- [ ] **Step 9: `SpecRoots`** (in the `-- Cleanup Crew: Shift` block):

```lua
	["ServerScriptService.Features.Shift.Systems.ShiftReviewSystem"] = "signal subscription shell (counting specced in ShiftRosterTracker, awards in ShiftResultsUtils)",
```

- [ ] **Step 10: Controller: Studio TestEZ.** Expected: `VacuumChannelTracker`, `ShiftAnalyticsUtils` and every earlier spec pass; `assertAllModulesSpecced` passes.

- [ ] **Step 11: Play check (controller, `RunTests = false`):** a solo shift: vacuum a pile (it clears, a dust bag pops: M1 behaviour), drop a monitor by hand, let Harlow come to a noise, clock out. The placeholder review shows BUTTERFINGERS "dropped the monitor" and either QUIETEST FEET "heard once" or LOUDEST VACUUM; Harlow still investigates vacuum noise (M2 unchanged); no server errors.

- [ ] **Step 12: Gate and commit**

```bash
git add src
python3 scripts/python/module_map.py --write
git add docs/project-structure.md
stylua src/ServerScriptService/Features/Vacuum/State/VacuumChannelTracker.luau src/ServerScriptService/Features/Vacuum/State/VacuumChannelTracker.spec.luau src/ServerScriptService/Features/Vacuum/VacuumServiceServer.luau src/ReplicatedStorage/Shared/Features/Vacuum/Data/VacuumConstants.luau src/ReplicatedStorage/Shared/Features/Noise/Data/NoiseTypes.luau src/ServerScriptService/Features/Noise/NoiseServiceServer.luau src/ServerScriptService/Features/Cargo/CargoServiceServer.luau src/ServerScriptService/Features/Cargo/Systems/CargoTraitSystem.luau src/ServerScriptService/Features/Shift/Utils/ShiftAnalyticsUtils.luau src/ServerScriptService/Features/Shift/Utils/ShiftAnalyticsUtils.spec.luau src/ServerScriptService/Features/Shift/Systems/ShiftAnalyticsWatchSystem.luau src/ServerScriptService/Features/Shift/Systems/ShiftReviewSystem.luau src/ServerScriptService/Features/Shift/ShiftServiceServer.luau src/ServerScriptService/Core/Testing/SpecRoots.luau
git add src
bash .superpowers/sdd/gate.sh
python3 scripts/python/check_pr_rules.py origin/main
git commit -m "feat(shift): noise makers and live review counters"
python3 scripts/python/module_map.py --check
```

---

### Task 3: Crew status fields (truck bed, vacuuming, room)

The crew roster needs each teammate's "in the truck bed", "vacuuming" and room; the CCTV needs the watched teammate's room, camera number and distance from the truck. A Shift system polls the crew four times a second and publishes only what changed, as public player fields (spec §6.3's per-player public fields).

**Files:**
- Create: `src/ServerScriptService/Features/Shift/Utils/ShiftCrewStatusUtils.luau`; Test: `src/ServerScriptService/Features/Shift/Utils/ShiftCrewStatusUtils.spec.luau`
- Create: `src/ServerScriptService/Features/Shift/Systems/ShiftCrewStatusSystem.luau` (spec-exempt shell)
- Modify: `src/ServerScriptService/Features/Office/Utils/OfficeLayoutUtils.luau`; Test: `src/ServerScriptService/Features/Office/Utils/OfficeLayoutUtils.spec.luau`
- Modify: `src/ServerScriptService/Features/Office/OfficeServiceServer.luau`
- Modify: `src/ReplicatedStorage/Shared/Features/Shift/Data/ShiftConstants.luau`
- Modify: `src/ServerScriptService/Features/Shift/ShiftServiceServer.luau` (+2 code lines)
- Modify: `src/ServerScriptService/Core/Testing/SpecRoots.luau`

**Interfaces:**
- Consumes: `CargoBankRules.onBed(localPoint: Vector3, bedSize: Vector3) -> boolean`; `VacuumServiceServer:isVacuuming(player)` (Task 2); `OfficeLayoutUtils.depths(layout) -> { [string]: number }`; `StateSyncPublicPlayerStore.set(userId, update)` / `.clearField(userId, field)`; `ShiftTripSystem:crew() -> { Player }`.
- Produces:
  - `OfficeLayoutUtils.roomAt(layout: Layout, x: number, z: number) -> (Room?, number?)` (the room and its 1-based index in `layout.rooms`).
  - `OfficeServiceServer:whereIs(position: Vector3) -> (string?, number?, number?)` (room name, rooms from the loading bay, camera number = room index); `OfficeServiceServer:truckBed() -> BasePart?`.
  - `ShiftCrewStatusUtils.Status = { inTruck: boolean, vacuuming: boolean, room: string?, roomDepth: number?, cam: number? }`; `ShiftCrewStatusUtils.fields(status: Status) -> PublicPlayer`; `ShiftCrewStatusUtils.changes(before: Status?, after: Status?) -> { set: PublicPlayer, clear: { string } }`.
  - `ShiftCrewStatusSystem.start(trip: ShiftTripSystem.ShiftTripSystem, running: () -> boolean) -> () -> ()`.
  - Public fields (names in `ShiftConstants`): `PUBLIC_IN_TRUCK = "inTruck"` (true or absent), `PUBLIC_VACUUMING = "vacuuming"` (true or absent), `PUBLIC_ROOM = "room"` (room name), `PUBLIC_ROOM_DEPTH = "roomDepth"` (number), `PUBLIC_CAM = "cam"` (number); `CREW_STATUS_INTERVAL = 0.25`.

- [ ] **Step 1: Write the failing specs.** `ShiftCrewStatusUtils.spec.luau`:

```lua
local ShiftCrewStatusUtils = require(script.Parent.ShiftCrewStatusUtils)

local function status(extra)
	local value = { inTruck = false, vacuuming = false, room = "Archive", roomDepth = 2, cam = 7 }
	for key, item in extra or {} do
		value[key] = item
	end
	return value
end

local function count(map)
	local n = 0
	for _ in map do
		n += 1
	end
	return n
end

return function()
	it("publishes only true flags and the room", function()
		local fields = ShiftCrewStatusUtils.fields(status())
		expect(fields.inTruck).to.equal(nil)
		expect(fields.vacuuming).to.equal(nil)
		expect(fields.room).to.equal("Archive")
		expect(fields.roomDepth).to.equal(2)
		expect(fields.cam).to.equal(7)
	end)

	it("sets everything on the first publish", function()
		local change = ShiftCrewStatusUtils.changes(nil, status({ vacuuming = true }))
		expect(change.set.vacuuming).to.equal(true)
		expect(change.set.room).to.equal("Archive")
		expect(#change.clear).to.equal(0)
	end)

	it("sends nothing when nothing changed", function()
		local change = ShiftCrewStatusUtils.changes(status(), status())
		expect(count(change.set)).to.equal(0)
		expect(#change.clear).to.equal(0)
	end)

	it("clears a flag that went false and sets only what moved", function()
		local change = ShiftCrewStatusUtils.changes(status({ vacuuming = true }), status({ inTruck = true }))
		expect(change.set.inTruck).to.equal(true)
		expect(change.set.room).to.equal(nil)
		expect(change.clear[1]).to.equal("vacuuming")
	end)

	it("clears the room when the player is outside every room", function()
		local change = ShiftCrewStatusUtils.changes(status(), status({ room = nil, roomDepth = nil, cam = nil }))
		table.sort(change.clear)
		expect(#change.clear).to.equal(3)
		expect(change.clear[1]).to.equal("cam")
	end)

	it("clears every field once the status is gone (dead, shift over)", function()
		local change = ShiftCrewStatusUtils.changes(status({ inTruck = true }), nil)
		expect(count(change.set)).to.equal(0)
		expect(#change.clear).to.equal(4)
	end)
end
```

Append to `OfficeLayoutUtils.spec.luau` (inside `return function()`; the file already requires `OfficeLayoutConstants`, else add `local LAYOUT = require(game:GetService("ServerScriptService").Features.Office.Data.OfficeLayoutConstants).LAYOUT`):

```lua
	describe("roomAt", function()
		it("finds the room a point stands in, with its camera number", function()
			local room, index = OfficeLayoutUtils.roomAt(LAYOUT, 10, 10)
			expect(room.id).to.equal("bay")
			expect(index).to.equal(1)
			local archive, archiveIndex = OfficeLayoutUtils.roomAt(LAYOUT, 120, 20)
			expect(archive.name).to.equal("Archive")
			expect(archiveIndex).to.equal(7)
		end)

		it("returns nothing outside every room", function()
			local room, index = OfficeLayoutUtils.roomAt(LAYOUT, -50, -50)
			expect(room).to.equal(nil)
			expect(index).to.equal(nil)
		end)

		it("gives a shared wall to the first room listed", function()
			local room = OfficeLayoutUtils.roomAt(LAYOUT, 40, 10)
			expect(room.id).to.equal("bay")
		end)
	end)
```

(The coordinates come from `OfficeLayoutConstants`' rooms: bay 0..40 × 0..30, archive 100..130 × 0..40, seventh in the list. If the layout's rooms changed, read them and adjust the three points.)

- [ ] **Step 2: Controller: Studio TestEZ.** Expected: the new cases fail.

- [ ] **Step 3: Implement.** `OfficeLayoutUtils.roomAt`:

```lua
--[=[
	The room a floor point (office-local studs) stands in, and its 1-based index in `layout.rooms` (the CCTV's camera
	number); a point on a shared wall belongs to the first room listed. Nothing outside every room.
]=]
function OfficeLayoutUtils.roomAt(layout: Layout, x: number, z: number): (Room?, number?)
	for index, room in layout.rooms do
		if x >= room.minX and x <= room.maxX and z >= room.minZ and z <= room.maxZ then
			return room, index
		end
	end
	return nil, nil
end
```

`ShiftCrewStatusUtils.luau`:

```lua
--!strict
--[=[
	ShiftCrewStatusUtils: one crew member's public status fields (Cleanup Crew M3 UI: the crew roster and the CCTV): in
	the truck bed, vacuuming, and the room they stand in (name, rooms from the loading bay, camera number). Flags are
	published only while true (absent = false) so the public map stays small; `changes` says what to set and what to
	clear since the last publish, so the system sends nothing when nothing moved. Pure.

	@class ShiftCrewStatusUtils
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PublicPlayerTypes = require(ReplicatedStorage.Shared.Data.PublicPlayerTypes)
local ShiftConstants = require(ReplicatedStorage.Shared.Features.Shift.Data.ShiftConstants)

type PublicPlayer = PublicPlayerTypes.PublicPlayer

export type Status = {
	inTruck: boolean,
	vacuuming: boolean,
	room: string?,
	roomDepth: number?,
	cam: number?,
}

export type Change = {
	set: PublicPlayer,
	clear: { string },
}

local ShiftCrewStatusUtils = {}

function ShiftCrewStatusUtils.fields(status: Status): PublicPlayer
	local fields: PublicPlayer = {}
	if status.inTruck then
		fields[ShiftConstants.PUBLIC_IN_TRUCK] = true
	end
	if status.vacuuming then
		fields[ShiftConstants.PUBLIC_VACUUMING] = true
	end
	local room, depth, cam = status.room, status.roomDepth, status.cam
	if room ~= nil then
		fields[ShiftConstants.PUBLIC_ROOM] = room
	end
	if depth ~= nil then
		fields[ShiftConstants.PUBLIC_ROOM_DEPTH] = depth
	end
	if cam ~= nil then
		fields[ShiftConstants.PUBLIC_CAM] = cam
	end
	return fields
end

function ShiftCrewStatusUtils.changes(before: Status?, after: Status?): Change
	local old: PublicPlayer = if before ~= nil then ShiftCrewStatusUtils.fields(before) else {}
	local new: PublicPlayer = if after ~= nil then ShiftCrewStatusUtils.fields(after) else {}
	local set: PublicPlayer = {}
	local clear: { string } = {}
	for field, value in new do
		if old[field] ~= value then
			set[field] = value
		end
	end
	for field in old do
		if new[field] == nil then
			table.insert(clear, field)
		end
	end
	return { set = set, clear = clear }
end

return ShiftCrewStatusUtils
```

`ShiftConstants` (inside the frozen table):

```lua
	-- Crew status public fields (M3 UI: the crew roster and the CCTV), published by ShiftCrewStatusSystem every
	-- CREW_STATUS_INTERVAL seconds while a shift runs. Flags are present only while true.
	PUBLIC_IN_TRUCK = "inTruck",
	PUBLIC_VACUUMING = "vacuuming",
	PUBLIC_ROOM = "room",
	PUBLIC_ROOM_DEPTH = "roomDepth",
	PUBLIC_CAM = "cam",
	CREW_STATUS_INTERVAL = 0.25,
```

`OfficeServiceServer`: compute `local depths = OfficeLayoutUtils.depths(LAYOUT)` once at load (beside `LAYOUT`), add to the type

```lua
	whereIs: (self: OfficeServiceServer, position: Vector3) -> (string?, number?, number?),
	truckBed: (self: OfficeServiceServer) -> BasePart?,
```

and the methods:

```lua
	--[=[
		The room a world position stands in: its name, how many rooms from the loading bay, and its camera number (its
		index in the layout). Nothing outside the office.
	]=]
	whereIs = function(_self, position)
		local localPoint = OfficeConstants.ORIGIN:PointToObjectSpace(position)
		local room, index = OfficeLayoutUtils.roomAt(LAYOUT, localPoint.X, localPoint.Z)
		if room == nil then
			return nil, nil, nil
		end
		return room.name, depths[room.id], index
	end,

	--[=[
		The truck bed in the loading bay (Cargo's Load zone), once the office is built.
	]=]
	truckBed = function(_self)
		local current = built
		return if current ~= nil then current.bed else nil
	end,
```

(Confirm `OfficeConstants.ORIGIN` is the CFrame the office is built at: `grep -n "ORIGIN" src/ServerScriptService/Features/Office/Data/OfficeConstants.luau`; if the build uses another origin, use that.)

`ShiftCrewStatusSystem.luau`:

```lua
--!strict
--[=[
	ShiftCrewStatusSystem: publishes each crew member's status four times a second while a shift runs (Cleanup Crew
	M3 UI: the crew roster's "in the truck bed" / "vacuuming", the CCTV's room, camera and rooms-from-the-truck). Reads
	Office (room, truck bed), Cargo's bed rule and Vacuum; writes public player fields through
	StateSyncPublicPlayerStore, only what changed (ShiftCrewStatusUtils). A dead player, a player who left the crew,
	and everyone once the shift stops running get their fields cleared.

	Spec-exempt shell (RunService, characters, the public store); the decisions are the specced ShiftCrewStatusUtils,
	OfficeLayoutUtils.roomAt and CargoBankRules.onBed.

	@class ShiftCrewStatusSystem
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")

local CargoBankRules = require(ReplicatedStorage.Shared.Features.Cargo.Rules.CargoBankRules)
local ShiftConstants = require(ReplicatedStorage.Shared.Features.Shift.Data.ShiftConstants)
local OfficeServiceServer = require(ServerScriptService.Features.Office.OfficeServiceServer)
local VacuumServiceServer = require(ServerScriptService.Features.Vacuum.VacuumServiceServer)
local StateSyncPublicPlayerStore = require(ServerScriptService.Features.StateSync.State.StateSyncPublicPlayerStore)
local ShiftCrewStatusUtils = require(ServerScriptService.Features.Shift.Utils.ShiftCrewStatusUtils)
local ShiftTripSystem = require(ServerScriptService.Features.Shift.Systems.ShiftTripSystem)

type Status = ShiftCrewStatusUtils.Status

local function statusOf(player: Player): Status?
	local character = player.Character
	local humanoid = if character ~= nil then character:FindFirstChildOfClass("Humanoid") else nil
	local root = if character ~= nil then character:FindFirstChild("HumanoidRootPart") else nil
	if humanoid == nil or humanoid.Health <= 0 or root == nil or not root:IsA("BasePart") then
		return nil
	end
	local bed = OfficeServiceServer:truckBed()
	local room, depth, cam = OfficeServiceServer:whereIs(root.Position)
	return {
		inTruck = bed ~= nil and CargoBankRules.onBed(bed.CFrame:PointToObjectSpace(root.Position), bed.Size),
		vacuuming = VacuumServiceServer:isVacuuming(player),
		room = room,
		roomDepth = depth,
		cam = cam,
	}
end

local ShiftCrewStatusSystem = {}

function ShiftCrewStatusSystem.start(trip: ShiftTripSystem.ShiftTripSystem, running: () -> boolean): () -> ()
	local last: { [number]: Status } = {}

	local function apply(userId: number, status: Status?)
		local change = ShiftCrewStatusUtils.changes(last[userId], status)
		if next(change.set) ~= nil then
			StateSyncPublicPlayerStore.set(userId, change.set)
		end
		for _, field in change.clear do
			StateSyncPublicPlayerStore.clearField(userId, field)
		end
		last[userId] = status
	end

	local function step()
		local seen: { [number]: boolean } = {}
		if running() then
			for _, player in trip:crew() do
				seen[player.UserId] = true
				apply(player.UserId, statusOf(player))
			end
		end
		for userId in last do
			if not seen[userId] then
				apply(userId, nil)
			end
		end
	end

	local elapsed = 0
	local ticking = RunService.Heartbeat:Connect(function(deltaTime: number)
		elapsed += deltaTime
		if elapsed >= ShiftConstants.CREW_STATUS_INTERVAL then
			elapsed = 0
			step()
		end
	end)
	return function()
		ticking:Disconnect()
		for userId in last do
			apply(userId, nil)
		end
	end
end

return ShiftCrewStatusSystem
```

(`apply(userId, nil)` sets `last[userId] = nil` while iterating `last` in `step`: assigning nil to an existing key during `for ... in` is allowed in Luau. A player who left: `StateSyncPublicPlayerStore` already removed their entry; `clearField` on a missing entry must be a no-op: check `StateSyncPublicPlayerStore.clearField` and guard with `StateSyncPublicPlayerStore.get(userId) ~= nil` if it is not.)

`ShiftServiceServer` (+2): require `local ShiftCrewStatusSystem = require(ShiftServer.Systems.ShiftCrewStatusSystem)` and after the `ShiftReviewSystem` line: `table.insert(stoppers, ShiftCrewStatusSystem.start(trip, isRunning))`.

`SpecRoots` (Shift block):

```lua
	["ServerScriptService.Features.Shift.Systems.ShiftCrewStatusSystem"] = "RunService/character/public-store shell (fields and diffs specced in ShiftCrewStatusUtils, rooms in OfficeLayoutUtils)",
```

- [ ] **Step 4: Controller: Studio TestEZ.** Expected: `ShiftCrewStatusUtils` and `OfficeLayoutUtils` cases pass.

- [ ] **Step 5: Play check (controller, `RunTests = false`):** in a shift, open F4 → State → StateSync public players: your entry gains `room = "Loading bay"`, `roomDepth = 0`, `cam = 1`; stepping into the truck bed adds `inTruck = true`; holding the vacuum on a pile adds `vacuuming = true` and releasing removes it within ~0.5 s; walking into the archive shows `roomDepth = 2`. After the shift ends the fields are gone.

- [ ] **Step 6: Gate and commit**

```bash
git add src
python3 scripts/python/module_map.py --write
git add docs/project-structure.md
stylua src/ServerScriptService/Features/Shift/Utils/ShiftCrewStatusUtils.luau src/ServerScriptService/Features/Shift/Utils/ShiftCrewStatusUtils.spec.luau src/ServerScriptService/Features/Shift/Systems/ShiftCrewStatusSystem.luau src/ServerScriptService/Features/Office/Utils/OfficeLayoutUtils.luau src/ServerScriptService/Features/Office/Utils/OfficeLayoutUtils.spec.luau src/ServerScriptService/Features/Office/OfficeServiceServer.luau src/ReplicatedStorage/Shared/Features/Shift/Data/ShiftConstants.luau src/ServerScriptService/Features/Shift/ShiftServiceServer.luau src/ServerScriptService/Core/Testing/SpecRoots.luau
git add src
bash .superpowers/sdd/gate.sh
python3 scripts/python/check_pr_rules.py origin/main
git commit -m "feat(shift): publish crew status fields for the roster and CCTV"
python3 scripts/python/module_map.py --check
```

---

### Task 4: Depot data: truck numbers, the board prompt, the last shift on the client

**Files:**
- Modify: `src/ReplicatedStorage/Shared/Features/Depot/Data/DepotConstants.luau`, `src/ReplicatedStorage/Shared/Features/Depot/Data/DepotTypes.luau`, `src/ReplicatedStorage/Shared/Features/Depot/Net/DepotEvents.luau`
- Modify: `src/ServerScriptService/Features/Depot/Utils/DepotContractUtils.luau`; Test: `src/ServerScriptService/Features/Depot/Utils/DepotContractUtils.spec.luau`
- Modify: `src/ServerScriptService/Features/Shift/Utils/ShiftCardUtils.luau`; Test: `src/ServerScriptService/Features/Shift/Utils/ShiftCardUtils.spec.luau`
- Modify: `src/ServerScriptService/Features/Depot/Systems/DepotBuildSystem.luau`, `src/ServerScriptService/Features/Depot/DepotServiceServer.luau`
- Modify: `src/ServerScriptService/Features/Shift/Systems/ShiftTripSystem.luau`, `src/ServerScriptService/Features/Shift/ShiftServiceServer.luau` (+0: the `publish` call gains an argument)
- Modify: `src/ReplicatedStorage/Client/Features/Depot/State/DepotStore.luau`; Test: `src/ReplicatedStorage/Client/Features/Depot/State/DepotStore.spec.luau`
- Modify: `src/ReplicatedStorage/Client/Features/Depot/DepotServiceClient.luau`

**Interfaces:**
- Consumes: `QueueServiceServer:setDepartData((pad: BasePart, party: { Player }) -> QueuePayload)`, `QueueServiceServer:padOf(player) -> BasePart?`, `QueueServiceServer.returned`, `InteractionRegistry.register(kind, { actionText, objectText })`, `InteractionServiceServer:onInteract(kind, handler)`, `ShiftCardUtils.ResultCard` (Task 1).
- Produces:
  - `DepotConstants`: `MAX_TRUCKS = 4`, `PUBLIC_TRUCK = "truck"`, `BOARD_KIND = "depot-board"`, `SITE = "4th floor offices"`, `JOB_TITLE = "HARLOW & FINCH JOB"`, `BOARD_COPY` (Task 12 reads it).
  - `DepotTypes.LastShift = { cleared: number, quota: number, bonus: number, catches: number, salvage: number, offered: number, quotaMet: boolean, rating: string, truck: number }` (`truck` 0 = unknown).
  - `DepotEvents.packets.Board` (server → client, `ByteNet.string`: tonight's contract id) and `DepotEvents.packets.LastShift` (server → client, the `LastShift` struct).
  - `DepotContractUtils.truckOf(value: unknown, max: number) -> number?`; `DepotContractUtils.boardLines(contract) -> { string }` (now the in-world sign only).
  - `ShiftCardUtils.CardInfo` gains `truck: number?`; `ResultCard` gains `truck: number?`; `ShiftCardUtils.summary(card: ResultCard) -> DepotTypes.LastShift`.
  - `ShiftTripSystem:truck() -> number?`; the shift snapshot's `truck`.
  - `DepotStore.board: Atom<string?>` (contract id of the open board), `DepotStore.lastShift: Atom<DepotTypes.LastShift?>`, `DepotStore.openBoard(id: string) -> string` (the resolved id), `DepotStore.setLastShift(value: DepotTypes.LastShift)`.
  - `DepotBuildSystem.Built` gains `contractBoard: BasePart` (tagged `Interactable`, kind `BOARD_KIND`).

- [ ] **Step 1: Write the failing specs.** Append to `DepotContractUtils.spec.luau`:

```lua
	describe("truckOf", function()
		it("accepts only a whole truck number on the layout", function()
			expect(DepotContractUtils.truckOf(2, 4)).to.equal(2)
			expect(DepotContractUtils.truckOf(4, 4)).to.equal(4)
			expect(DepotContractUtils.truckOf(9, 4)).to.equal(nil)
			expect(DepotContractUtils.truckOf(0, 4)).to.equal(nil)
			expect(DepotContractUtils.truckOf(2.5, 4)).to.equal(nil)
			expect(DepotContractUtils.truckOf("2", 4)).to.equal(nil)
			expect(DepotContractUtils.truckOf(0 / 0, 4)).to.equal(nil)
			expect(DepotContractUtils.truckOf(nil, 4)).to.equal(nil)
		end)
	end)

	it("keeps the in-world board to a sign", function()
		local lines = DepotContractUtils.boardLines(CONTRACTS[2])
		expect(lines[1]).to.equal("TONIGHT'S JOB")
		expect(lines[2]).to.equal(CONTRACTS[2].client)
		expect(#lines).to.equal(3)
	end)
```

(`CONTRACTS` is the spec file's fixture list; replace the old `boardLines(CONTRACTS[2], 350)` case, whose expectations no longer hold.)

Append to `ShiftCardUtils.spec.luau`:

```lua
	describe("truck and summary", function()
		it("carries a valid truck and drops a bad one", function()
			local info = { client = INFO.client, shift = INFO.shift, truck = 2 }
			expect(ShiftCardUtils.decode(ShiftCardUtils.encode(review(2), info)).truck).to.equal(2)
			local payload = ShiftCardUtils.encode(review(2), info)
			payload.truck = 99
			expect(ShiftCardUtils.decode(payload).truck).to.equal(nil)
			payload.truck = nil
			expect(ShiftCardUtils.decode(payload).truck).to.equal(nil)
		end)

		it("summarises the card for the depot board", function()
			local fixture = review(2)
			fixture.offered = 9
			local card = ShiftCardUtils.decode(ShiftCardUtils.encode(fixture, { client = "H&F", shift = 1, truck = 3 }))
			local summary = ShiftCardUtils.summary(card)
			expect(summary.cleared).to.equal(card.cleared)
			expect(summary.offered).to.equal(9)
			expect(summary.rating).to.equal(card.rating)
			expect(summary.truck).to.equal(3)
		end)

		it("writes truck 0 for an unknown truck", function()
			local card = ShiftCardUtils.decode(ShiftCardUtils.encode(review(2), INFO))
			expect(ShiftCardUtils.summary(card).truck).to.equal(0)
		end)
	end)
```

Append to `DepotStore.spec.luau`:

```lua
	describe("board and last shift", function()
		afterEach(function()
			DepotStore.clear()
		end)

		it("opens the board on a known contract and falls back to the first for an unknown one", function()
			local id = DepotConstants.CONTRACTS[2].id
			expect(DepotStore.openBoard(id)).to.equal(id)
			expect(DepotStore.board()).to.equal(id)
			expect(DepotStore.openBoard("nope")).to.equal(DepotConstants.CONTRACTS[1].id)
		end)

		it("keeps the last shift until cleared", function()
			local last = { cleared = 362, quota = 350, bonus = 215, catches = 2, salvage = 6, offered = 9, quotaMet = true, rating = "exceeds", truck = 2 }
			DepotStore.setLastShift(last)
			expect(DepotStore.lastShift().cleared).to.equal(362)
			DepotStore.clear()
			expect(DepotStore.lastShift()).to.equal(nil)
			expect(DepotStore.board()).to.equal(nil)
		end)
	end)
```

(The spec already requires `DepotConstants`.)

- [ ] **Step 2: Controller: Studio TestEZ.** Expected: the new cases fail.

- [ ] **Step 3: Implement the pure parts.** `DepotConstants` (inside the frozen table):

```lua
	-- M3 UI. The most trucks a depot layout has (the truck number riding the teleport is checked against it).
	MAX_TRUCKS = 4,
	-- Public player field: the truck whose bed a player stands in (the queue pad card's "TRUCK 2").
	PUBLIC_TRUCK = "truck",
	-- The contract board's Interaction kind (its prompt opens the board scene).
	BOARD_KIND = "depot-board",
	-- Every contract is the same office (open question 8).
	SITE = "4th floor offices",
	JOB_TITLE = "HARLOW & FINCH JOB",
	BOARD_COPY = BOARD_COPY,
```

with, above the table:

```lua
-- The contract board's work order (Figma 2a/2b). Quota and shift lines are filled from ShiftConstants by
-- DepotBoardViewModel; NOTES is the contract's own note.
local BOARD_COPY = table.freeze({
	title = "TONIGHT'S JOB",
	quota = "clearance (rubbish bags, dust bags, recycling)",
	quotaPhone = "clearance",
	shift = "on the clock. Clock out at the truck any time.",
	shiftPhone = "clock out at the truck",
	fee = "Salvage you load is auctioned. The crew keeps the fee.",
	feePhone = "Salvage → finder's fee",
	crew = "1–4 per truck.",
	hazard = "Occupant on site. Hears vacuums and dropped items. Empty hands run faster.",
	hazardPhone = "Occupant hears vacuums and drops",
	sticky = "Lights on the 4th floor again?? — night guard",
	approved = "APPROVED",
	dispatchLabel = "DISPATCH · HOW TO START",
	dispatchTitle = "JOIN A SHIFT",
	dispatchSteps = "1.  Walk into a truck bed outside.\n2.  Anyone aboard presses DEPART NOW.",
	dispatchPhone = "Walk into a truck bed outside.",
	close = "CLOSE  [Esc]",
})
```

`DepotTypes`:

```lua
-- The returning player's last shift on the client (DepotEvents.LastShift; the board's "YOUR LAST SHIFT" card).
-- `rating` is a ShiftTypes.Rating word; `truck` 0 = unknown.
export type LastShift = {
	cleared: number,
	quota: number,
	bonus: number,
	catches: number,
	salvage: number,
	offered: number,
	quotaMet: boolean,
	rating: string,
	truck: number,
}
```

`DepotEvents` (inside `packets`):

```lua
			-- To one player: open the contract board on this contract id (the board's prompt was used).
			Board = ByteNet.definePacket({
				value = ByteNet.string,
				reliabilityType = "reliable",
			}),
			-- To a returning player: their last shift, for the board's card (held until Ready, like Card).
			LastShift = ByteNet.definePacket({
				value = ByteNet.struct({
					cleared = ByteNet.uint32,
					quota = ByteNet.uint32,
					bonus = ByteNet.uint32,
					catches = ByteNet.uint16,
					salvage = ByteNet.uint16,
					offered = ByteNet.uint16,
					quotaMet = ByteNet.bool,
					rating = ByteNet.string,
					truck = ByteNet.uint8,
				}),
				reliabilityType = "reliable",
			}),
```

(ByteNetMax 0.2.7 exports `uint8`, `uint16`, `uint32`, `float32`, `float64`, `bool`, `string`, `array`, `struct`, `optional`.)

`DepotContractUtils`:

```lua
--[=[
	A truck number that rode a teleport (untrusted): a whole number 1..max, else nil.
]=]
function DepotContractUtils.truckOf(value: unknown, max: number): number?
	if type(value) ~= "number" or value ~= value or value % 1 ~= 0 then
		return nil
	end
	if value < 1 or value > max then
		return nil
	end
	return value
end

-- The in-world contract board is a sign now; the work order itself is the board scene (M3 UI).
function DepotContractUtils.boardLines(contract: Contract): { string }
	return { "TONIGHT'S JOB", contract.client, "[Read the work order]" }
end
```

(`boardLines` loses its `quota` parameter: update its one caller in `DepotServiceServer`.)

`ShiftCardUtils`: `CardInfo` and `ResultCard` gain `truck: number?`; `encode` writes `payload.truck = info.truck` when not nil (29 keys at most); `decode` reads `truck = DepotContractUtils.truckOf(payload.truck, DepotConstants.MAX_TRUCKS),` (a bad truck reads nil, it never rejects the card); add

```lua
--[=[
	The card as the depot board shows it (DepotEvents.LastShift): the numbers, the rating word, the truck (0 = unknown).
]=]
function ShiftCardUtils.summary(card: ResultCard): DepotTypes.LastShift
	return {
		cleared = card.cleared,
		quota = card.quota,
		bonus = card.bonus,
		catches = card.catches,
		salvage = card.salvage,
		offered = card.offered,
		quotaMet = card.quotaMet,
		rating = card.rating,
		truck = card.truck or 0,
	}
end
```

(require `DepotConstants`, `DepotTypes` from `ReplicatedStorage.Shared.Features.Depot.Data` and `DepotContractUtils` from `ServerScriptService.Features.Depot.Utils`; check `DepotContractUtils` does not require `ShiftCardUtils`, so there is no cycle.)

`DepotStore`:

```lua
local initialBoard: string? = nil
local board = Charm.atom(initialBoard)
local initialLast: DepotTypes.LastShift? = nil
local lastShift = Charm.atom(initialLast)
```

(add both to the `DepotStore` table) and:

```lua
-- Opens the board on a contract id from the server; an unknown id reads as the first contract. Returns the id shown.
function DepotStore.openBoard(id: string): string
	local shown = DepotConstants.CONTRACTS[1].id
	for _, contract in DepotConstants.CONTRACTS do
		if contract.id == id then
			shown = id
		end
	end
	board(shown)
	return shown
end

function DepotStore.setLastShift(value: DepotTypes.LastShift)
	lastShift(table.clone(value))
end
```

and `clear` also sets `board(nil)` and `lastShift(nil)`.

- [ ] **Step 4: Controller: Studio TestEZ.** Expected: the new and old `DepotContractUtils`, `ShiftCardUtils`, `DepotStore` cases pass.

- [ ] **Step 5: Wire the server.**
  - `DepotBuildSystem`: `Built` gains `contractBoard: BasePart`; after creating `contractBoard`:

```lua
	-- The board's prompt opens the work order (M3 UI): attributes first, then the tag (Interaction reads them on tag).
	contractBoard:SetAttribute(InteractionConstants.KIND_ATTRIBUTE, DepotConstants.BOARD_KIND)
	CollectionService:AddTag(contractBoard, InteractionConstants.TAG)
```

  (require `InteractionConstants` from `ReplicatedStorage.Shared.Features.Interaction.Data.InteractionConstants`), and return `contractBoard = contractBoard`. Its `build` signature keeps `boardLines`.
  - `DepotServiceServer`: at load, beside the place-role registration:

```lua
-- The contract board's prompt (M3 UI): registered at load, before the board is built and tagged.
if not InteractionRegistry.has(DepotConstants.BOARD_KIND) then
	InteractionRegistry.register(DepotConstants.BOARD_KIND, { actionText = "Read", objectText = "Work order" })
end
```

  dependencies gain `"InteractionServiceServer"` and `"StateSyncServiceServer"`; in `start`:

```lua
		QueueServiceServer:setDepartData(function(pad, _party)
			return { contract = contract.id, truck = truckIndexOf(pad) }
		end)
		InteractionServiceServer:onInteract(DepotConstants.BOARD_KIND, function(player, _target)
			DepotEvents.packets.Board.sendTo(contract.id, player)
		end)
```

  with a module-level helper

```lua
-- The truck number (layout order) of a pad, or nil before the garage is built.
local function truckIndexOf(pad: BasePart): number?
	local current = built
	if current == nil then
		return nil
	end
	for _, truck in current.trucks do
		if truck.pad == pad then
			return truck.index
		end
	end
	return nil
end
```

  (a `nil` truck leaves the key out of the payload). `refreshLabels` also publishes the public `truck` field: keep `local truckOf: { [number]: number } = {}` at module level and, inside the player loop,

```lua
		local index = if pad ~= nil then truckIndexOf(pad) else nil
		if index ~= truckOf[player.UserId] then
			truckOf[player.UserId] = index
			if index ~= nil then
				StateSyncPublicPlayerStore.set(player.UserId, { [DepotConstants.PUBLIC_TRUCK] = index })
			else
				StateSyncPublicPlayerStore.clearField(player.UserId, DepotConstants.PUBLIC_TRUCK)
			end
		end
```

  (forget the player in the existing `PlayerRemoving` handler: `truckOf[player.UserId] = nil`). In `pinResultCard`, after decoding the card, send the summary through the same ready/held path as cards: add `local heldLast: { [Player]: DepotTypes.LastShift } = {}`, and a `sendLast(player, summary)` that sends now when `ready[player]`, else stores it in `heldLast`; `onReady` also flushes `heldLast[player]`; `PlayerRemoving` and `stop` clear it. Call `sendLast(player, ShiftCardUtils.summary(card))` before the billboard pin (the billboard stays as it is). Update the header: board prompt, LastShift, public truck field.
  - `ShiftTripSystem`: keep `local truck: number? = nil`; in the `arrived` handler, after the contract line: `truck = DepotContractUtils.truckOf(payload.truck, DepotConstants.MAX_TRUCKS)`; add `truck: (self: ShiftTripSystem) -> number?,` to the type and `truck = function(_self) return truck end,`; `sendHome`'s encode passes `{ client = contract.client, shift = shift, truck = truck }`. Clear `truck = nil` where the crew is cleared.
  - `ShiftServiceServer` `publish`: `ShiftSnapshotUtils.build(state, cleared, bonus, another, depot, review, trip:crewIds(), trip:truck())`.

- [ ] **Step 6: Wire the client (data only; the board scene lands in Task 12).** `DepotServiceClient.start` adds:

```lua
		table.insert(
			stoppers,
			DepotEvents.packets.Board.listen(function(id: string)
				DepotStore.openBoard(id)
			end)
		)
		table.insert(
			stoppers,
			DepotEvents.packets.LastShift.listen(function(data: DepotTypes.LastShift)
				DepotStore.setLastShift(data)
			end)
		)
```

(the `listen` return is the disconnect function, as with `Card`; if `Card.listen`'s return is used differently in this file, follow it.)

- [ ] **Step 7: Play check (controller, `RunTests = false`, Studio local roles):** in the depot, the contract board shows a prompt "Read · Work order"; pressing it sets F4 → DepotServiceClient state / `DepotStore.board()` (via a temporary LocalScript printing it) to tonight's id. Stand in truck 2's bed: your public entry gains `truck = 2`. Depart, play, clock out, vote Back to depot: the shift snapshot showed `truck = 2`; back at the depot `DepotStore.lastShift()` holds the shift's numbers and the billboard card still pins.

- [ ] **Step 8: Gate and commit**

```bash
git add src
python3 scripts/python/module_map.py --write
git add docs/project-structure.md
stylua src/ReplicatedStorage/Shared/Features/Depot/Data/DepotConstants.luau src/ReplicatedStorage/Shared/Features/Depot/Data/DepotTypes.luau src/ReplicatedStorage/Shared/Features/Depot/Net/DepotEvents.luau src/ServerScriptService/Features/Depot/Utils/DepotContractUtils.luau src/ServerScriptService/Features/Depot/Utils/DepotContractUtils.spec.luau src/ServerScriptService/Features/Shift/Utils/ShiftCardUtils.luau src/ServerScriptService/Features/Shift/Utils/ShiftCardUtils.spec.luau src/ServerScriptService/Features/Depot/Systems/DepotBuildSystem.luau src/ServerScriptService/Features/Depot/DepotServiceServer.luau src/ServerScriptService/Features/Shift/Systems/ShiftTripSystem.luau src/ServerScriptService/Features/Shift/ShiftServiceServer.luau src/ReplicatedStorage/Client/Features/Depot/State/DepotStore.luau src/ReplicatedStorage/Client/Features/Depot/State/DepotStore.spec.luau src/ReplicatedStorage/Client/Features/Depot/DepotServiceClient.luau
git add src
bash .superpowers/sdd/gate.sh
python3 scripts/python/check_pr_rules.py origin/main
git commit -m "feat(depot): truck numbers, board prompt and the last shift on the client"
python3 scripts/python/module_map.py --check
```

---

### Task 5: Catch data and the approved server copy

The caught player needs a deadline everyone can see ("CAUGHT · back 0:06"), a private incident report (cause, clock, room, what dropped) and a rehire notice; "You're FIRED!" moves to the throw; the toasts use the approved copy.

**Files:**
- Modify: `src/ReplicatedStorage/Shared/Features/Occupant/Data/OccupantConstants.luau`, `src/ReplicatedStorage/Shared/Features/Occupant/Data/OccupantTypes.luau`, `src/ReplicatedStorage/Shared/Features/Occupant/Net/OccupantEvents.luau`
- Modify: `src/ReplicatedStorage/Shared/Features/Occupant/Utils/OccupantFeedbackUtils.luau`; Test: `src/ReplicatedStorage/Shared/Features/Occupant/Utils/OccupantFeedbackUtils.spec.luau`
- Modify: `src/ServerScriptService/Features/Occupant/Systems/OccupantCatchSystem.luau`
- Modify: `src/ServerScriptService/Features/Occupant/OccupantServiceServer.luau` (net −3 code lines: 398 → 395)
- Create: `src/ReplicatedStorage/Client/Features/Occupant/State/OccupantCatchStore.luau`; Test: `src/ReplicatedStorage/Client/Features/Occupant/State/OccupantCatchStore.spec.luau`
- Modify: `src/ReplicatedStorage/Client/Features/Occupant/OccupantServiceClient.luau`
- Modify: `src/ServerScriptService/Features/Shift/Utils/ShiftNoticeUtils.luau`; Test: `src/ServerScriptService/Features/Shift/Utils/ShiftNoticeUtils.spec.luau`
- Modify: `src/ServerScriptService/Features/Shift/ShiftServiceServer.luau` (+0: the clock-out toast text)

**Interfaces:**
- Consumes: `OfficeServiceServer:whereIs` (Task 3); `CarryServiceServer:getCarried(player) -> Instance?` (kind in `CarryConstants.KIND_ATTRIBUTE`); `CargoServiceServer:pocketsOf(player) -> { CargoEntry }` (`kind`); `ShiftServiceServer:getShift().endsAt`; `StateSyncPublicPlayerStore`.
- Produces:
  - `OccupantConstants`: `PUBLIC_CAUGHT_UNTIL = "caughtUntil"` (server time the caught player is back), `REHIRED_LEAD = 1.5`, `REHIRED_HOLD = 3`, `CATCH_ROOM_FALLBACK = "the office"`.
  - `OccupantTypes.CatchReport = { room: string, clock: number, backAt: number, dropped: { string } }` (`clock`: seconds left on the shift clock at the catch; `dropped`: item names).
  - `OccupantEvents.packets.CatchReport` (server → the caught player) and `OccupantEvents.packets.Rehired` (server → the respawned player, `ByteNet.bool`).
  - `OccupantFeedbackUtils.droppedNames(hands: string?, pockets: { string }, lookup: (kind: string) -> CargoTypes.ItemDef?) -> { string }`; `OccupantFeedbackUtils.caughtText(name: string, seconds: number) -> string`.
  - `OccupantCatchSystem.rehired(player: Player)` (clears the public deadline, sends `Rehired`).
  - `OccupantCatchStore`: atoms `scaring: boolean`, `report: CatchReport?`, `rehiredAt: number?` (os.clock); functions `snap()`, `endSnap()`, `setReport(report: CatchReport)`, `rehired(now: number)`, `clear()`.
  - `ShiftNoticeUtils` quota-met note: `Quota met! Clock out at the truck any time, or stay: salvage ×1.5 in 1:00.`

- [ ] **Step 1: Write the failing specs.** Append to `OccupantFeedbackUtils.spec.luau`:

```lua
	describe("catch copy", function()
		local CargoRegistry = require(game:GetService("ReplicatedStorage").Shared.Features.Cargo.Data.CargoRegistry)

		it("lists the hands item, then the pockets, by name", function()
			local names = OccupantFeedbackUtils.droppedNames("monitor", { "plaque" }, CargoRegistry.get)
			expect(#names).to.equal(2)
			expect(names[1]).to.equal("Monitor")
			expect(names[2]).to.equal("Employee of the Month plaque")
		end)

		it("skips empty hands and unknown kinds", function()
			local names = OccupantFeedbackUtils.droppedNames(nil, { "nope", "goldenStapler" }, CargoRegistry.get)
			expect(#names).to.equal(1)
			expect(names[1]).to.equal("Golden stapler")
		end)

		it("writes the caught toast with the respawn time", function()
			expect(OccupantFeedbackUtils.caughtText("Alex", 8)).to.equal("Alex was caught! Back in 0:08.")
			expect(OccupantFeedbackUtils.caughtText("Alex", 61)).to.equal("Alex was caught! Back in 1:01.")
		end)
	end)
```

`src/ReplicatedStorage/Client/Features/Occupant/State/OccupantCatchStore.spec.luau`:

```lua
local OccupantCatchStore = require(script.Parent.OccupantCatchStore)

local REPORT = { room = "Archive", clock = 222, backAt = 1008, dropped = { "Monitor" } }

return function()
	afterEach(function()
		OccupantCatchStore.clear()
	end)

	it("holds the scare beat between snap and endSnap", function()
		expect(OccupantCatchStore.scaring()).to.equal(false)
		OccupantCatchStore.snap()
		expect(OccupantCatchStore.scaring()).to.equal(true)
		OccupantCatchStore.endSnap()
		expect(OccupantCatchStore.scaring()).to.equal(false)
	end)

	it("keeps the report and forgets an older rehire notice", function()
		OccupantCatchStore.rehired(5)
		OccupantCatchStore.setReport(REPORT)
		expect(OccupantCatchStore.report().room).to.equal("Archive")
		expect(OccupantCatchStore.rehiredAt()).to.equal(nil)
	end)

	it("keeps the report through the rehire (the card lists what dropped)", function()
		OccupantCatchStore.setReport(REPORT)
		OccupantCatchStore.rehired(12)
		expect(OccupantCatchStore.rehiredAt()).to.equal(12)
		expect(OccupantCatchStore.report().dropped[1]).to.equal("Monitor")
	end)

	it("copies the report it is given", function()
		local report = table.clone(REPORT)
		OccupantCatchStore.setReport(report)
		report.room = "changed"
		expect(OccupantCatchStore.report().room).to.equal("Archive")
	end)

	it("clears everything", function()
		OccupantCatchStore.snap()
		OccupantCatchStore.setReport(REPORT)
		OccupantCatchStore.rehired(1)
		OccupantCatchStore.clear()
		expect(OccupantCatchStore.scaring()).to.equal(false)
		expect(OccupantCatchStore.report()).to.equal(nil)
		expect(OccupantCatchStore.rehiredAt()).to.equal(nil)
	end)
end
```

In `ShiftNoticeUtils.spec.luau` change the quota-met note expectation (line ~36):

```lua
		expect(list[2].text).to.equal("Quota met! Clock out at the truck any time, or stay: salvage ×1.5 in 1:00.")
```

- [ ] **Step 2: Controller: Studio TestEZ.** Expected: the new cases fail.

- [ ] **Step 3: Implement the shared parts.** `OccupantConstants` (frozen table):

```lua
	-- M3 UI. Public field: the server time a caught player is back on the clock (the roster's "CAUGHT · back 0:06");
	-- cleared on the respawn.
	PUBLIC_CAUGHT_UNTIL = "caughtUntil",
	-- The Rehired card shows from REHIRED_LEAD seconds before the respawn until REHIRED_HOLD seconds after it.
	REHIRED_LEAD = 1.5,
	REHIRED_HOLD = 3,
	-- The incident report's room when the catch happened outside every room.
	CATCH_ROOM_FALLBACK = "the office",
```

`OccupantTypes`:

```lua
-- What the caught player is told (OccupantEvents.CatchReport, M3 UI incident report): the room, the shift clock's
-- seconds left at the catch, the server time they are back, and the names of the items they dropped.
export type CatchReport = {
	room: string,
	clock: number,
	backAt: number,
	dropped: { string },
}
```

`OccupantEvents` (inside `packets`):

```lua
			-- To the caught player, at the throw: their incident report.
			CatchReport = ByteNet.definePacket({
				value = ByteNet.struct({
					room = ByteNet.string,
					clock = ByteNet.float32,
					backAt = ByteNet.float64,
					dropped = ByteNet.array(ByteNet.string),
				}),
				reliabilityType = "reliable",
			}),
			-- To a caught player whose new character spawned: back on the clock (the Rehired card).
			Rehired = ByteNet.definePacket({
				value = ByteNet.bool,
				reliabilityType = "reliable",
			}),
```

`OccupantFeedbackUtils` (require `CargoTypes` from `ReplicatedStorage.Shared.Features.Cargo.Data.CargoTypes`):

```lua
--[=[
	The names of what a caught player dropped: the hands item, then the pockets; empty hands and unknown kinds skipped.
]=]
function OccupantFeedbackUtils.droppedNames(
	hands: string?,
	pockets: { string },
	lookup: (kind: string) -> CargoTypes.ItemDef?
): { string }
	local names: { string } = {}
	local function add(kind: string?)
		local def = if kind ~= nil then lookup(kind) else nil
		if def ~= nil then
			table.insert(names, def.name)
		end
	end
	add(hands)
	for _, kind in pockets do
		add(kind)
	end
	return names
end

-- The crew's toast when someone is caught (Figma 1f): "Alex was caught! Back in 0:08."
function OccupantFeedbackUtils.caughtText(name: string, seconds: number): string
	local whole = math.max(0, math.ceil(seconds))
	return `{name} was caught! Back in {string.format("%d:%02d", whole // 60, whole % 60)}.`
end
```

`OccupantCatchStore.luau`:

```lua
--!strict
--[=[
	OccupantCatchStore: the local player's catch as the UI sees it (Cleanup Crew M3 UI): `scaring` while the 0.6 s scare
	beat runs (the HUD goes dark), the incident report the server sent at the throw (the CCTV's slip, the Rehired card's
	"Dropped: ..."), and when the rehire notice arrived (os.clock). Written only by OccupantServiceClient from the
	server's packets; nothing here is sent back.

	@class OccupantCatchStore
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Charm = require(ReplicatedStorage.Packages.Charm)
local OccupantTypes = require(ReplicatedStorage.Shared.Features.Occupant.Data.OccupantTypes)

local scaring = Charm.atom(false)
local initialReport: OccupantTypes.CatchReport? = nil
local report = Charm.atom(initialReport)
local initialRehired: number? = nil
local rehiredAt = Charm.atom(initialRehired)

local OccupantCatchStore = {
	scaring = scaring,
	report = report,
	rehiredAt = rehiredAt,
}

function OccupantCatchStore.snap()
	scaring(true)
end

function OccupantCatchStore.endSnap()
	scaring(false)
end

-- A new catch: its report replaces the last one, and the last rehire notice is forgotten.
function OccupantCatchStore.setReport(value: OccupantTypes.CatchReport)
	report({ room = value.room, clock = value.clock, backAt = value.backAt, dropped = table.clone(value.dropped) })
	rehiredAt(nil)
end

function OccupantCatchStore.rehired(now: number)
	rehiredAt(now)
end

function OccupantCatchStore.clear()
	scaring(false)
	report(nil)
	rehiredAt(nil)
end

return OccupantCatchStore
```

`ShiftNoticeUtils`: the quota-met note becomes

```lua
		table.insert(
			list,
			note(
				`Quota met! Clock out at the truck any time, or stay: salvage ×{multiplier} in {clock(ShiftConstants.BREAK_SECONDS + ShiftConstants.WARNING_SECONDS)}.`
			)
		)
```

(Open question 3 explains why "1:00", not Figma's "0:30".)

- [ ] **Step 4: Implement the server.** `OccupantCatchSystem` (add requires: `Workspace`, `CargoRegistry`, `CarryConstants`, `OccupantFeedbackUtils`, `OccupantTypes`, and `CargoServiceServer`, `CarryServiceServer`, `OfficeServiceServer`, `ShiftServiceServer`, `StateSyncPublicPlayerStore` from `ServerScriptService.Features...`):
  - delete `OccupantRigSystem.say(rig, OccupantConstants.LINES.caught)` from `begin` (Figma 4a: no text during the scare);
  - in the delayed step, between the `if not hooks.stillOn() ... return end` guard and `local velocity = ...`, capture the report **before** the kill (the kill drops the hands and scatters the pockets):

```lua
		local report = reportFor(player, root.Position)
```

  and after `DeathServiceServer:kill(victim, "caught", { launch = velocity })`:

```lua
		-- Figma 4a: the line comes with the throw, not the scare.
		OccupantRigSystem.say(rig, OccupantConstants.LINES.caught)
		StateSyncPublicPlayerStore.set(userId, { [OccupantConstants.PUBLIC_CAUGHT_UNTIL] = report.backAt })
		OccupantEvents.packets.CatchReport.sendTo(report, player)
```

  with the module-level helper

```lua
-- The caught player's incident report, read before the kill drops what they carry.
local function reportFor(player: Player, position: Vector3): OccupantTypes.CatchReport
	local carried = CarryServiceServer:getCarried(player)
	local hands = if carried ~= nil then carried:GetAttribute(CarryConstants.KIND_ATTRIBUTE) else nil
	local pockets: { string } = {}
	for _, entry in CargoServiceServer:pocketsOf(player) do
		table.insert(pockets, entry.kind)
	end
	local room = OfficeServiceServer:whereIs(position)
	local endsAt = ShiftServiceServer:getShift().endsAt
	local now = Workspace:GetServerTimeNow()
	return {
		room = room or OccupantConstants.CATCH_ROOM_FALLBACK,
		clock = if endsAt ~= nil then math.max(0, endsAt - now) else 0,
		backAt = now + OccupantConstants.SPECTATE_SECONDS,
		dropped = OccupantFeedbackUtils.droppedNames(
			if type(hands) == "string" then hands else nil,
			pockets,
			CargoRegistry.get
		),
	}
end
```

  and the new public function

```lua
--[=[
	A caught player's new character spawned: clears their public deadline and tells them they are back (the Rehired card).
]=]
function OccupantCatchSystem.rehired(player: Player)
	StateSyncPublicPlayerStore.clearField(player.UserId, OccupantConstants.PUBLIC_CAUGHT_UNTIL)
	OccupantEvents.packets.Rehired.sendTo(true, player)
end
```

  Update the header (report, deadline, rehire, the line at the throw). Before writing, check `ShiftServiceServer` does not require anything from Occupant (`grep -n "Occupant" src/ServerScriptService/Features/Shift/ShiftServiceServer.luau`: expect nothing) and that `OccupantCatchSystem` is not required by Office/Cargo/Carry (no cycle).
  - `OccupantServiceServer` (net −3): in the `observeCharacter` callback replace the four-line `ToastServiceServer:send(player, { text = OccupantConstants.REHIRED_TEXT, ... })` call with `OccupantCatchSystem.rehired(player)`; in `catchHooks.onCaught` replace the toast text with `text = OccupantFeedbackUtils.caughtText(player.DisplayName, OccupantConstants.SPECTATE_SECONDS),` (same line count). Run the file-length check: ≤ 398.
  - `ShiftServiceServer.clockOut`: the toast text becomes `` text = `{who} is clocking out!`, `` (Figma 1c/1f; the countdown itself is the clock-out slip now).

- [ ] **Step 5: Implement the client.** `OccupantServiceClient.start`: in the `CatchCam` listener add `OccupantCatchStore.snap()` and schedule `task.delay(OccupantConstants.SNAP_SECONDS, OccupantCatchStore.endSnap)`; add listeners:

```lua
		table.insert(
			stoppers,
			OccupantEvents.packets.CatchReport.listen(function(data: OccupantTypes.CatchReport)
				OccupantCatchStore.setReport(data)
			end)
		)
		table.insert(
			stoppers,
			OccupantEvents.packets.Rehired.listen(function(_back: boolean)
				OccupantCatchStore.rehired(os.clock())
			end)
		)
```

and `OccupantCatchStore.clear()` in `stop`. Require `OccupantCatchStore` and `OccupantTypes`.

- [ ] **Step 6: Controller: Studio TestEZ.** Expected: `OccupantFeedbackUtils`, `OccupantCatchStore`, `ShiftNoticeUtils` and every earlier spec pass.

- [ ] **Step 7: Play check (controller, `RunTests = false`):** get caught holding the monitor with the plaque pocketed. The scare shows no speech bubble; "You're FIRED!" appears on Harlow as you are thrown; the crew toast reads "<you> was caught! Back in 0:08."; F4 public players shows `caughtUntil` while you spectate and drops it when you respawn; the old "Rehired." sticky no longer appears (the Rehired card arrives in Task 14). A temporary LocalScript printing `OccupantCatchStore.report()` shows the room you were caught in, the clock and `{ "Monitor", "Employee of the Month plaque" }`. Meeting the quota shows the new note text.

- [ ] **Step 8: Gate and commit**

```bash
git add src
python3 scripts/python/module_map.py --write
git add docs/project-structure.md
stylua src/ReplicatedStorage/Shared/Features/Occupant/Data/OccupantConstants.luau src/ReplicatedStorage/Shared/Features/Occupant/Data/OccupantTypes.luau src/ReplicatedStorage/Shared/Features/Occupant/Net/OccupantEvents.luau src/ReplicatedStorage/Shared/Features/Occupant/Utils/OccupantFeedbackUtils.luau src/ReplicatedStorage/Shared/Features/Occupant/Utils/OccupantFeedbackUtils.spec.luau src/ServerScriptService/Features/Occupant/Systems/OccupantCatchSystem.luau src/ServerScriptService/Features/Occupant/OccupantServiceServer.luau src/ReplicatedStorage/Client/Features/Occupant/State/OccupantCatchStore.luau src/ReplicatedStorage/Client/Features/Occupant/State/OccupantCatchStore.spec.luau src/ReplicatedStorage/Client/Features/Occupant/OccupantServiceClient.luau src/ServerScriptService/Features/Shift/Utils/ShiftNoticeUtils.luau src/ServerScriptService/Features/Shift/Utils/ShiftNoticeUtils.spec.luau src/ServerScriptService/Features/Shift/ShiftServiceServer.luau
git add src
bash .superpowers/sdd/gate.sh
python3 scripts/python/check_pr_rules.py origin/main
git commit -m "feat(occupant): caught deadline, incident report, rehire notice and approved catch copy"
python3 scripts/python/module_map.py --check
```

---

### Task 6: Base seams (APPROVAL-GATED: B1 and B2)

**Approved by the developer (2026-10-11): B1 and B2, on a base branch.** Game branches never merge into `main` or a `base/*` branch, so base code is never written on `game/cleanup-crew`:

1. In a separate worktree, create `base/ui-seams` from `base/queue` (the top of the base stack: Death spectate and Toast come from `base/game-hooks`, which `base/queue` stacks on). Example: `git worktree add .claude/worktrees/ui-seams -b base/ui-seams base/queue`.
2. Do Steps 1-5 below in that worktree. The gate and `check_pr_rules` run there against `origin/main`.
3. Push `base/ui-seams` and open a PR into `base/queue` (stacked, so it reaches `main` after #2 and #4). Plain title and body; it is generic base work.
4. Back in the game worktree, `git merge base/ui-seams` into `game/cleanup-crew` (a merge commit, never a squash), so Tasks 10, 14 and 8 can use the seams.

The controller does steps 1, 3 and 4 (branches, push, PR); the implementer does Steps 1-5 inside the `base/ui-seams` worktree.

**Files:**
- B1 Modify: `src/ReplicatedStorage/Client/Features/Death/DeathServiceClient.luau`
- B2 Modify: `src/ReplicatedStorage/Client/Features/Toast/State/ToastStore.luau`; Test: `src/ReplicatedStorage/Client/Features/Toast/State/ToastStore.spec.luau`
- B2 Modify: `src/ReplicatedStorage/Client/Features/Toast/ToastServiceClient.luau`, `src/ReplicatedStorage/Client/UI/React/Screens/Hud/ToastStack.luau`

**Interfaces:**
- Produces (B1): `DeathServiceClient:cycleSpectate(direction: number)` (`1` next, `-1` previous; a no-op unless the local player is dead and spectating is enabled).
- Produces (B2): `ToastStore.widgetEnabled: Atom<boolean>` (default `true`); `ToastServiceClient:setDefaultWidget(enabled: boolean)`; `ToastStack` renders nothing while it is false.

- [ ] **Step 1 (B1): Add `cycleSpectate`.** Type field `cycleSpectate: (self: DeathServiceClient, direction: number) -> (),` and:

```lua
	--[=[
		Cycles the spectated player: 1 next, -1 previous. The touch twin of the spectate Input actions (a phone has no
		key to press); does nothing unless the local player is dead.
	]=]
	cycleSpectate = function(_self, direction)
		refresh(if direction < 0 then -1 else 1)
	end,
```

Update the header ("`spectateNext` / `spectatePrev` or `cycleSpectate` cycle"). `DeathServiceClient` is spec-exempt (its stepping is the specced `DeathSpectateRules`), so no spec changes.

- [ ] **Step 2 (B1): Gate and commit**

```bash
stylua src/ReplicatedStorage/Client/Features/Death/DeathServiceClient.luau
git add src
bash .superpowers/sdd/gate.sh
python3 scripts/python/check_pr_rules.py origin/main
git commit -m "feat(death): cycle spectating from touch controls"
```

- [ ] **Step 3 (B2): Failing spec.** Append to `ToastStore.spec.luau`:

```lua
	describe("widgetEnabled", function()
		it("shows the base widget until a game turns it off", function()
			expect(ToastStore.widgetEnabled()).to.equal(true)
			ToastStore.widgetEnabled(false)
			expect(ToastStore.widgetEnabled()).to.equal(false)
			ToastStore.widgetEnabled(true)
		end)
	end)
```

Controller: Studio TestEZ: fails (`widgetEnabled` nil).

- [ ] **Step 4 (B2): Implement.** `ToastStore`: `local widgetEnabled = Charm.atom(true)` added to the `ToastStore` table, header: "`widgetEnabled` lets a game hide the base ToastStack and draw its own (the QueueStore precedent)". `ToastServiceClient`: type field `setDefaultWidget: (self: ToastServiceClient, enabled: boolean) -> (),` and

```lua
	--[=[
		Shows or hides the base toast stack (a game with its own approved toast look turns it off and reads ToastStore).
	]=]
	setDefaultWidget = function(_self, enabled)
		ToastStore.widgetEnabled(enabled)
	end,
```

`ToastStack`: read `local enabled = ReactCharm.useAtom(ToastStore.widgetEnabled)` before the loop and `if not enabled then return nil end` (hooks first, then the early return).

- [ ] **Step 5 (B2): Controller: Studio TestEZ** (`ToastStore` passes) **and gate/commit**

```bash
stylua src/ReplicatedStorage/Client/Features/Toast/State/ToastStore.luau src/ReplicatedStorage/Client/Features/Toast/State/ToastStore.spec.luau src/ReplicatedStorage/Client/Features/Toast/ToastServiceClient.luau src/ReplicatedStorage/Client/UI/React/Screens/Hud/ToastStack.luau
git add src
bash .superpowers/sdd/gate.sh
python3 scripts/python/check_pr_rules.py origin/main
git commit -m "feat(toast): let a game replace the default toast widget"
```

---

### Task 7: The paper kit (game UI kit in the UI tree)

Every later screen is built from these pieces, so they come with one story that shows them all for the visual checkpoint against the Style page (4:2) and the Components frame (5:2). Nothing is mounted in-game yet.

**Files (all under `src/ReplicatedStorage/Client/UI/React/Screens/Paper/`):**
- Create: `UIPaperConstants.luau`, `PaperLabel.luau`, `PaperSheet.luau`, `PaperStamp.luau`, `StickyNote.luau`, `KeyChip.luau`, `PaperButton.luau`, `usePaperLayout.luau`, `usePaperMotion.luau`, `PaperKit.story.luau`
- Modify: `src/ReplicatedStorage/Client/Features/UI/Data/UIAssets.luau` (pending paper slots)
- Modify: `src/ServerScriptService/Core/Testing/SpecRoots.luau`

**Interfaces:**
- Consumes: `ShiftPlatformRules.detect(input) -> Platform` (shared, specced in M5); `UIAssets`.
- Produces:
  - `UIPaperConstants`: `export type Layout = "desktop" | "phone"`; `export type Ink = "ok" | "busy" | "danger" | "muted" | "ink"`; `COLOR` (the 14 Style colours + the three paper inks), `FONT` (`body`, `heading`, `medium`, `number`, `timer`, `marker` as `Font` faces), `TEXT` (sizes per layout), `SAFE` (per layout: `left`, `right`, `top`, `bottom`, `topBar`), `MOTION` (`popSeconds`, `popFrom`, `slideSeconds`, `slideFrom`), `inkColor(ink: Ink) -> Color3`.
  - `PaperLabel(props: { text: string, role: "body" | "heading" | "medium" | "number" | "timer" | "marker", size: number, color: Color3?, align: ("left" | "center" | "right")?, frame: UDim2?, position: UDim2?, anchor: Vector2?, transparency: number?, wrapped: boolean?, autoSize: boolean?, strike: boolean?, layoutOrder: number?, zIndex: number? })`.
  - `PaperSheet(props: { size: UDim2, position: UDim2?, anchor: Vector2?, paper: Color3?, tilt: number?, fastener: ("clip" | "pin" | "tape" | "staple")?, torn: boolean?, band: string?, bandColor: Color3?, tab: string?, shadow: boolean?, padding: number?, layoutOrder: number?, children: { [string]: React.ReactNode }? })`.
  - `PaperStamp(props: { text: string, size: number, color: Color3?, tilt: number?, pop: boolean?, position: UDim2?, anchor: Vector2?, layoutOrder: number? })`.
  - `StickyNote(props: { text: string, width: number, size: number, tilt: number?, slide: boolean?, position: UDim2?, anchor: Vector2?, layoutOrder: number? })`.
  - `KeyChip(props: { key: string, size: number, layoutOrder: number? })`.
  - `PaperButton(props: { text: string, variant: "primary" | "secondary" | "danger" | "go", onActivated: () -> (), size: UDim2, textSize: number, onPaper: boolean?, mark: string?, disabled: boolean?, position: UDim2?, anchor: Vector2?, layoutOrder: number? })`.
  - `usePaperLayout() -> UIPaperConstants.Layout`; `usePaperMotion(seconds: number) -> React.Binding<number>` (0 → 1 once, from mount).
  - `UIAssets.paper = { manila = "", cream = "", cork = "", scanlines = "" }` (PENDING).

- [ ] **Step 1: `UIPaperConstants.luau`** (static data; values are the Style page's):

```lua
--!strict
--[=[
	UIPaperConstants: Cleanup Crew's "Corporate After Hours" paperwork look (Figma "Style" page 4:2 and "Components"
	5:2, approved 2026-10-11): the 14-colour palette plus the three paper inks, the four fonts as Font faces, text
	sizes per layout (desktop >= 20 px for anything read in play, phone >= 14 px), the phone safe area and the motion
	timings. The game's UI kit reads only this; the base Tokens stay neutral (plan "Decisions").

	@class UIPaperConstants
]=]

export type Layout = "desktop" | "phone"
export type Ink = "ok" | "busy" | "danger" | "muted" | "ink"

local COLOR = table.freeze({
	night = Color3.fromHex("0E1116"),
	office = Color3.fromHex("1A1F26"),
	manila = Color3.fromHex("E8C98A"),
	manilaDeep = Color3.fromHex("C9A564"),
	cream = Color3.fromHex("F4ECD6"), -- Punch Cream
	ink = Color3.fromHex("24211C"),
	sticky = Color3.fromHex("FFE45C"),
	stamp = Color3.fromHex("C8202F"),
	fluorescent = Color3.fromHex("E6F5E8"),
	fluorGlow = Color3.fromHex("B8F0C4"),
	exitRed = Color3.fromHex("FF4A3D"),
	exitGreen = Color3.fromHex("2FD27A"),
	monitor = Color3.fromHex("4C9BFF"),
	monitorDeep = Color3.fromHex("12305C"),
	-- Ink on paper.
	inkBlue = Color3.fromHex("1F4E9A"),
	inkGreen = Color3.fromHex("1E7A46"),
	inkRed = Color3.fromHex("C8202F"),
	-- Not on the Style page: the depot pinboard's cork and the empty pocket label (Components 5:2).
	cork = Color3.fromHex("6B4A2B"),
	slotEmpty = Color3.fromHex("8A8F98"),
})

local function face(font: Enum.Font, weight: Enum.FontWeight): Font
	return Font.new(Font.fromEnum(font).Family, weight)
end

local FONT = table.freeze({
	-- Special Elite: typewriter body copy.
	body = face(Enum.Font.SpecialElite, Enum.FontWeight.Regular),
	-- Oswald: numbers, headings, buttons, stamps.
	heading = face(Enum.Font.Oswald, Enum.FontWeight.Bold),
	medium = face(Enum.Font.Oswald, Enum.FontWeight.Medium),
	number = face(Enum.Font.Oswald, Enum.FontWeight.Bold),
	-- Roboto Mono: timers only (digits do not jitter).
	timer = face(Enum.Font.RobotoMono, Enum.FontWeight.Bold),
	-- Permanent Marker: sticky notes and marker marks only.
	marker = face(Enum.Font.PermanentMarker, Enum.FontWeight.Regular),
})

-- Text sizes in px, by role and layout (Figma dumps).
local TEXT = table.freeze({
	desktop = table.freeze({ hint = 20, label = 20, body = 22, value = 32, big = 44, timer = 58, sticky = 24, stamp = 72, bigStamp = 120 }),
	phone = table.freeze({ hint = 14, label = 14, body = 15, value = 18, big = 24, timer = 32, sticky = 16, stamp = 22, bigStamp = 40 }),
})

-- Safe areas (Components 5:2 rules): the Roblox top bar (~58 px, GuiService.TopbarInset), the phone notch margins,
-- the thumbstick zone (bottom-left 40%) and the Jump button (bottom-right).
local SAFE = table.freeze({
	desktop = table.freeze({ left = 60, right = 60, top = 68, bottom = 40, topBar = 58 }),
	phone = table.freeze({ left = 48, right = 48, top = 12, bottom = 20, topBar = 58 }),
})

local MOTION = table.freeze({
	-- A stamp drops from 140% with a thunk (1f), a sticky slides in from the right edge.
	popSeconds = 0.18,
	popFrom = 1.4,
	slideSeconds = 0.25,
	slideFrom = 380,
	-- Desktop key hints sit at 80% opacity (1a).
	hintTransparency = 0.2,
})

local UIPaperConstants = {
	COLOR = COLOR,
	FONT = FONT,
	TEXT = TEXT,
	SAFE = SAFE,
	MOTION = MOTION,
	-- Every tilt the kit uses, in degrees.
	STAMP_TILT = -3,
	STICKY_TILT = 2,
	-- Touch targets (Components 5:2): small >= 48 (72 drawn), large 104.
	BUTTON_SMALL = 72,
	BUTTON_LARGE = 104,
}

function UIPaperConstants.inkColor(ink: Ink): Color3
	if ink == "ok" then
		return COLOR.inkGreen
	elseif ink == "busy" then
		return COLOR.inkBlue
	elseif ink == "danger" then
		return COLOR.inkRed
	elseif ink == "muted" then
		return COLOR.slotEmpty
	end
	return COLOR.ink
end

return table.freeze(UIPaperConstants)
```

Check in Studio's command bar before going on (edit mode): `print(Font.fromEnum(Enum.Font.SpecialElite).Family, Font.fromEnum(Enum.Font.Oswald).Family)` prints two `rbxasset://fonts/families/...json` paths. If a weight does not exist in a family, the engine falls back to the nearest; the story makes that visible.

- [ ] **Step 2: The pieces.** Each is presentational (no branching beyond prop defaults). Sketches with the load-bearing parts:

`PaperLabel.luau`:

```lua
--!strict
--[=[
	PaperLabel: text in one of the kit's type roles (UIPaperConstants.FONT). Presentational.

	@class PaperLabel
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local UIPaperConstants = require(ReplicatedStorage.Client.UI.React.Screens.Paper.UIPaperConstants)

local e = React.createElement

export type Role = "body" | "heading" | "medium" | "number" | "timer" | "marker"

export type PaperLabelProps = {
	text: string,
	role: Role,
	size: number,
	color: Color3?,
	align: ("left" | "center" | "right")?,
	frame: UDim2?,
	position: UDim2?,
	anchor: Vector2?,
	transparency: number?,
	wrapped: boolean?,
	autoSize: boolean?,
	strike: boolean?,
	layoutOrder: number?,
	zIndex: number?,
}

local ALIGN = {
	left = Enum.TextXAlignment.Left,
	center = Enum.TextXAlignment.Center,
	right = Enum.TextXAlignment.Right,
}

local function PaperLabel(props: PaperLabelProps): React.ReactNode
	local text = if props.strike then `<s>{props.text}</s>` else props.text
	return e("TextLabel", {
		LayoutOrder = props.layoutOrder,
		ZIndex = props.zIndex,
		AnchorPoint = props.anchor,
		Position = props.position,
		Size = props.frame or UDim2.fromScale(1, 0),
		AutomaticSize = if props.autoSize == false then Enum.AutomaticSize.None else Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		FontFace = UIPaperConstants.FONT[props.role],
		TextSize = props.size,
		TextColor3 = props.color or UIPaperConstants.COLOR.ink,
		TextTransparency = props.transparency or 0,
		TextXAlignment = ALIGN[props.align or "left"],
		TextWrapped = props.wrapped ~= false,
		RichText = props.strike == true,
		Text = text,
	})
end

return PaperLabel
```

(`strike` uses RichText `<s>`; escape `<`, `>` and `&` in names first if `strike` is set: the roster passes player display names, so `PaperLabel` escapes `text` with `string.gsub(text, "[<>&]", { ["<"] = "&lt;", [">"] = "&gt;", ["&"] = "&amp;" })` before wrapping.)

`PaperSheet.luau` (the load-bearing parts; every visual is a plain Frame, no images):

```lua
local function fastenerOf(kind: string?): React.ReactNode
	local color = UIPaperConstants.COLOR
	if kind == "clip" then
		-- A binder clip: a dark plate over the top edge with a lighter lip.
		return e("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0),
			Size = UDim2.fromOffset(64, 16),
			BackgroundColor3 = Color3.fromHex("3A3F47"),
			BorderSizePixel = 0,
			ZIndex = 5,
		}, {
			corner = e("UICorner", { CornerRadius = UDim.new(0, 3) }),
			lip = e("Frame", {
				Position = UDim2.fromOffset(6, 3),
				Size = UDim2.new(1, -12, 0, 4),
				BackgroundColor3 = Color3.fromHex("6B717C"),
				BorderSizePixel = 0,
			}),
		})
	elseif kind == "pin" then
		return e("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0.5, 0, 0, 6),
			Size = UDim2.fromOffset(16, 16),
			BackgroundColor3 = color.stamp,
			BorderSizePixel = 0,
			ZIndex = 5,
		}, {
			corner = e("UICorner", { CornerRadius = UDim.new(0.5, 0) }),
			shine = e("Frame", {
				Position = UDim2.fromOffset(4, 3),
				Size = UDim2.fromOffset(5, 5),
				BackgroundColor3 = color.cream,
				BorderSizePixel = 0,
			}, { corner = e("UICorner", { CornerRadius = UDim.new(0.5, 0) }) }),
		})
	elseif kind == "tape" then
		return e("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0),
			Size = UDim2.fromOffset(110, 26),
			Rotation = -2,
			BackgroundColor3 = color.cream,
			BackgroundTransparency = 0.35,
			BorderSizePixel = 0,
			ZIndex = 5,
		})
	elseif kind == "staple" then
		return e("Frame", {
			Position = UDim2.fromOffset(14, 8),
			Size = UDim2.fromOffset(26, 3),
			Rotation = -8,
			BackgroundColor3 = Color3.fromHex("9AA0A8"),
			BorderSizePixel = 0,
			ZIndex = 5,
		})
	end
	return nil
end

-- A torn bottom edge: paper-coloured squares turned 45° along the bottom, so the edge zigzags.
local function tornEdge(paper: Color3): React.ReactNode
	local teeth: { [string]: React.ReactNode } = {
		layout = e("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			Padding = UDim.new(0, 2),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	}
	for index = 1, 48 do
		teeth[`t{index}`] = e("Frame", {
			LayoutOrder = index,
			Size = UDim2.fromOffset(10, 10),
			Rotation = 45,
			BackgroundColor3 = paper,
			BorderSizePixel = 0,
		})
	end
	return e("Frame", {
		Position = UDim2.new(0, 0, 1, -5),
		Size = UDim2.new(1, 0, 0, 10),
		BackgroundTransparency = 1,
		ClipsDescendants = true,
	}, teeth)
end
```

The sheet itself: an outer transparent `Frame` (the given size/position/anchor, `Rotation = tilt or 0`) holding, in order, the drop shadow (`Frame` offset (4, 6), `COLOR.night`, transparency 0.5) when `shadow ~= false`; an optional manila `tab` (`Frame` 251×46 `COLOR.manilaDeep` above the top-left, Oswald Bold label 20 ink); the paper `Frame` (`BackgroundColor3 = props.paper or COLOR.manila`, `UICorner` 4, `UIStroke` 1 px `COLOR.ink` at 0.8 transparency); an optional `band` (26 px `bandColor or COLOR.stamp` strip at the top with an Oswald Bold label in `COLOR.cream`, size 20 desktop); a content `Frame` inset by `padding or 20` (and by the band height) holding `props.children`; `tornEdge(paper)` when `torn`; `fastenerOf(fastener)`. The children impose their own layout, like the base `Panel`.

`PaperStamp.luau`: a `Frame` sized by `AutomaticSize = XY`, `Rotation = tilt or UIPaperConstants.STAMP_TILT`, `UIStroke` (`Color = color or COLOR.stamp`, `Thickness = math.max(3, math.floor(props.size / 10))`, `ApplyStrokeMode = Border`), `UICorner` 10, `UIPadding` `size / 4` horizontally and `size / 8` vertically, a `PaperLabel` role `heading` in the stamp colour; when `pop`, a `UIScale` whose `Scale` is the `usePaperMotion(MOTION.popSeconds)` binding mapped `alpha → popFrom + (1 - popFrom) * alpha`.

`StickyNote.luau`: a `Frame` `width` × auto height, `COLOR.sticky`, `Rotation = tilt or 0`, `UIPadding` 24 / 18, a centred tape `Frame` 110×26 (`COLOR.cream`, 0.35 transparency, anchored at the top centre so a resized note keeps it centred: the Figma CENTER constraint), the text as `PaperLabel` role `marker`, size `props.size`, colour `COLOR.ink`; when `slide`, the outer `Position` is offset by `slideFrom * (1 - alpha)` px to the right from `usePaperMotion(MOTION.slideSeconds)`.

`KeyChip.luau`: a `Frame` with `AutomaticSize = X`, height `size + 10`, min width `size + 10` (`UISizeConstraint`), `COLOR.cream`, `UICorner` 4, `UIStroke` 1 px ink at 0.6, a centred `PaperLabel` role `heading`, ink, size `size`.

`PaperButton.luau`: a `TextButton` (`AutoButtonColor = false`, `Text = ""`) with a centred `PaperLabel` role `heading`; fills: `primary` → `COLOR.manila` + ink text; `secondary` → transparent + 3 px stroke (`onPaper` → ink stroke and ink text, else `COLOR.cream`); `danger` → `COLOR.stamp` + cream text; `go` → `COLOR.exitGreen` + `COLOR.night` text; `disabled` → `BackgroundTransparency = 0.5`, text transparency 0.5, activation swallowed; `UICorner` 6; an optional `mark` string drawn to the right of the button in Oswald Medium (the review's "✓ your vote").

- [ ] **Step 3: The hooks.** `usePaperLayout.luau`:

```lua
--!strict
--[=[
	usePaperLayout: "phone" or "desktop" for the current device, from M5's specced ShiftPlatformRules.detect on the live
	viewport and input devices; re-renders when the viewport changes size. React hook (exempt: needs a renderer).

	@class usePaperLayout
]=]

local GuiService = game:GetService("GuiService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local React = require(ReplicatedStorage.Packages.React)
local ShiftPlatformRules = require(ReplicatedStorage.Shared.Features.Shift.Rules.ShiftPlatformRules)
local UIPaperConstants = require(ReplicatedStorage.Client.UI.React.Screens.Paper.UIPaperConstants)

local function read(): UIPaperConstants.Layout
	local camera = Workspace.CurrentCamera
	local viewport = if camera ~= nil then camera.ViewportSize else Vector2.new(1920, 1080)
	local platform = ShiftPlatformRules.detect({
		touch = UserInputService.TouchEnabled,
		keyboard = UserInputService.KeyboardEnabled,
		gamepad = UserInputService.GamepadEnabled,
		tenFoot = GuiService:IsTenFootInterface(),
		shortSide = math.min(viewport.X, viewport.Y),
	})
	return if platform == "phone" then "phone" else "desktop"
end

local function usePaperLayout(): UIPaperConstants.Layout
	local layout, setLayout = React.useState(read)
	React.useEffect(function(): () -> ()
		local camera = Workspace.CurrentCamera
		if camera == nil then
			return function() end
		end
		local connection = camera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
			setLayout(read())
		end)
		return function()
			connection:Disconnect()
		end
	end, {})
	return layout
end

return usePaperLayout
```

`usePaperMotion.luau`: `React.useBinding(0)`; a `useEffect` with `{}` deps that connects `RunService.RenderStepped`, advances `elapsed / seconds` clamped to 1, sets the binding, and disconnects at 1 or on unmount; returns the binding.

- [ ] **Step 4: Pending art slots.** In `UIAssets.luau`:

```lua
-- Cleanup Crew paper textures (M3 UI). PENDING: empty until the art pass uploads them; every paper component draws
-- flat colours while a slot is "".
UIAssets.paper = table.freeze({
	manila = "",
	cream = "",
	cork = "",
	scanlines = "",
})
```

- [ ] **Step 5: `PaperKit.story.luau`** (UI Labs, edit mode): one `Frame` (`COLOR.office` background) showing, in a grid: a manila `PaperSheet` with a tab and a clip; a cream sheet with a red band, a pin and a torn edge; `PaperStamp` "QUOTA MET" at 72 and 40 with `pop` on a control toggle; `StickyNote` "You hear Harlow pacing faster…" at 340/24 and 250/16; `KeyChip`s "E", "LMB", "←"; the four `PaperButton` variants (and secondary `onPaper`); a `PaperLabel` per role; controls `Pop = false`, `Tilt = 2`. Return `UILabs.CreateReactStory({ react = React, reactRoblox = ReactRoblox, controls = {...} }, function(props) ... end)` as in `Primitives/Button.story.luau`.

- [ ] **Step 6: `SpecRoots`.** After the existing UI lines, a new block:

```lua
	-- Cleanup Crew: the paper UI kit (M3 UI)
	["ReplicatedStorage.Client.UI.React.Screens.Paper.UIPaperConstants"] = "static palette, fonts and sizes (no logic)",
	["ReplicatedStorage.Client.UI.React.Screens.Paper.PaperLabel"] = "presentational React component (story in PaperKit.story)",
	["ReplicatedStorage.Client.UI.React.Screens.Paper.PaperSheet"] = "presentational React component (story in PaperKit.story)",
	["ReplicatedStorage.Client.UI.React.Screens.Paper.PaperStamp"] = "presentational React component (story in PaperKit.story)",
	["ReplicatedStorage.Client.UI.React.Screens.Paper.StickyNote"] = "presentational React component (story in PaperKit.story)",
	["ReplicatedStorage.Client.UI.React.Screens.Paper.KeyChip"] = "presentational React component (story in PaperKit.story)",
	["ReplicatedStorage.Client.UI.React.Screens.Paper.PaperButton"] = "presentational React component (story in PaperKit.story)",
	["ReplicatedStorage.Client.UI.React.Screens.Paper.usePaperLayout"] = "React hook over the viewport (the decision is the specced ShiftPlatformRules.detect)",
	["ReplicatedStorage.Client.UI.React.Screens.Paper.usePaperMotion"] = "React hook — RenderStepped easing over a binding (no logic)",
```

- [ ] **Step 7: Visual checkpoint (controller, edit mode, UI Labs):** open `Game UI → Screens → Paper → PaperKit`. Compare with Figma Style 4:2 and Components 5:2 side by side: colours, fonts (Special Elite / Oswald / Roboto Mono / Permanent Marker render, not a fallback face), stamp border and tilt, sticky tape centred, buttons. Screenshot it into the task log. No Play needed.

- [ ] **Step 8: Gate and commit**

```bash
git add src
python3 scripts/python/module_map.py --write
git add docs/project-structure.md
stylua src/ReplicatedStorage/Client/UI/React/Screens/Paper src/ReplicatedStorage/Client/Features/UI/Data/UIAssets.luau src/ServerScriptService/Core/Testing/SpecRoots.luau
git add src
bash .superpowers/sdd/gate.sh
python3 scripts/python/check_pr_rules.py origin/main
git commit -m "feat(ui): Cleanup Crew paper UI kit"
python3 scripts/python/module_map.py --check
```

---

### Task 8: Paper toasts and rubber stamps

Toasts become taped sticky notes top-right (phone: 250 px), and stamp-style toasts (QUOTA MET, OVERTIME) thunk in big at the centre. The HUD's toasts also go dark during the scare beat.

**Files:**
- Create: `src/ReplicatedStorage/Client/UI/React/Screens/Paper/PaperToastViewModel.luau`; Test: `.../Paper/PaperToastViewModel.spec.luau`
- Create: `src/ReplicatedStorage/Client/UI/React/Screens/Paper/PaperToastStack.luau`, `.../Paper/PaperToastStack.story.luau`
- Modify: `src/ReplicatedStorage/Client/Features/Shift/ShiftServiceClient.luau`
- Modify: `src/ServerScriptService/Core/Testing/SpecRoots.luau`

**Interfaces:**
- Consumes: `ToastStore.toasts: Atom<{ ToastTypes.Toast }>`; `ShiftConstants.TOAST_STAMP`; `OccupantCatchStore.scaring` (Task 5); `ToastServiceClient:setDefaultWidget` (Task 6 B2) or the fallback.
- Produces: `PaperToastViewModel.layout(toasts: { ToastTypes.Toast }, maxNotes: number) -> ToastView` with `ToastView = { stamp: NoteView?, notes: { NoteView } }`, `NoteView = { id: number, text: string, tilt: number }`; `PaperToastViewModel.MAX_NOTES = 3`; the `PaperToastStack` HUD widget (key `"paperToasts"`, order 1000).

- [ ] **Step 1: Failing spec** `PaperToastViewModel.spec.luau`:

```lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PaperToastViewModel = require(script.Parent.PaperToastViewModel)
local ShiftConstants = require(ReplicatedStorage.Shared.Features.Shift.Data.ShiftConstants)

local function toast(id, style, text)
	return { id = id, text = text or `toast {id}`, style = style or ShiftConstants.TOAST_STICKY, expiresAt = 100 }
end

return function()
	it("splits stamps from notes", function()
		local view = PaperToastViewModel.layout({ toast(1), toast(2, ShiftConstants.TOAST_STAMP, "QUOTA MET"), toast(3, "info") }, 3)
		expect(view.stamp.text).to.equal("QUOTA MET")
		expect(#view.notes).to.equal(2)
	end)

	it("puts the newest note first and keeps at most the limit", function()
		local view = PaperToastViewModel.layout({ toast(1), toast(2), toast(3), toast(4) }, 3)
		expect(#view.notes).to.equal(3)
		expect(view.notes[1].id).to.equal(4)
		expect(view.notes[3].id).to.equal(2)
	end)

	it("shows only the newest stamp", function()
		local view = PaperToastViewModel.layout({ toast(1, ShiftConstants.TOAST_STAMP, "OVERTIME"), toast(2, ShiftConstants.TOAST_STAMP, "QUOTA MET") }, 3)
		expect(view.stamp.text).to.equal("QUOTA MET")
	end)

	it("tilts notes alternately by id, so a note keeps its tilt as others come and go", function()
		local view = PaperToastViewModel.layout({ toast(7), toast(8) }, 3)
		expect(view.notes[1].tilt).to.equal(-view.notes[2].tilt)
		expect(PaperToastViewModel.layout({ toast(8) }, 3).notes[1].tilt).to.equal(view.notes[1].tilt)
	end)

	it("is empty for no toasts", function()
		local view = PaperToastViewModel.layout({}, 3)
		expect(view.stamp).to.equal(nil)
		expect(#view.notes).to.equal(0)
	end)
end
```

Controller: Studio TestEZ: fails.

- [ ] **Step 2: Implement** `PaperToastViewModel.luau`:

```lua
--!strict
--[=[
	PaperToastViewModel: how the toasts on screen are drawn on paper (Figma 1f): stamp-style toasts (QUOTA MET,
	OVERTIME) are one big centre stamp, the newest only; everything else is a taped sticky note, newest on top, at
	most MAX_NOTES, each tilted ±STICKY_TILT by its id so it keeps its tilt while others come and go. Pure.

	@class PaperToastViewModel
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ShiftConstants = require(ReplicatedStorage.Shared.Features.Shift.Data.ShiftConstants)
local ToastTypes = require(ReplicatedStorage.Shared.Features.Toast.Data.ToastTypes)
local UIPaperConstants = require(ReplicatedStorage.Client.UI.React.Screens.Paper.UIPaperConstants)

export type NoteView = {
	id: number,
	text: string,
	tilt: number,
}

export type ToastView = {
	stamp: NoteView?,
	notes: { NoteView },
}

local PaperToastViewModel = {
	MAX_NOTES = 3,
}

function PaperToastViewModel.layout(toasts: { ToastTypes.Toast }, maxNotes: number): ToastView
	local stamp: NoteView? = nil
	local notes: { NoteView } = {}
	for index = #toasts, 1, -1 do
		local toast = toasts[index]
		local tilt = if toast.id % 2 == 0 then UIPaperConstants.STICKY_TILT else -UIPaperConstants.STICKY_TILT
		if toast.style == ShiftConstants.TOAST_STAMP then
			if stamp == nil then
				stamp = { id = toast.id, text = toast.text, tilt = UIPaperConstants.STAMP_TILT }
			end
		elseif #notes < maxNotes then
			table.insert(notes, { id = toast.id, text = toast.text, tilt = tilt })
		end
	end
	return { stamp = stamp, notes = notes }
end

return PaperToastViewModel
```

(ToastStore keeps toasts oldest first: `ToastQueueUtils.push` appends and drops from the front.)

- [ ] **Step 3: `PaperToastStack.luau`** (HUD widget):

```lua
local function PaperToastStack(): React.ReactNode
	local toasts = ReactCharm.useAtom(ToastStore.toasts)
	local scaring = ReactCharm.useAtom(OccupantCatchStore.scaring)
	local layout = usePaperLayout()
	if scaring then
		return nil -- Figma 4a: no HUD and no text during the scare beat
	end
	local view = PaperToastViewModel.layout(toasts, PaperToastViewModel.MAX_NOTES)
	local text = UIPaperConstants.TEXT[layout]
	local phone = layout == "phone"
	local notes: { [string]: React.ReactNode } = {
		list = e("UIListLayout", {
			FillDirection = Enum.FillDirection.Vertical,
			HorizontalAlignment = Enum.HorizontalAlignment.Right,
			Padding = UDim.new(0, if phone then 8 else 16),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	}
	for order, note in view.notes do
		notes[`note{note.id}`] = e(StickyNote, {
			text = note.text,
			width = if phone then 250 else 340,
			size = text.sticky,
			tilt = note.tilt,
			slide = true,
			layoutOrder = order,
		})
	end
	local children: { [string]: React.ReactNode } = {
		notes = e("Frame", {
			-- Desktop: top-right under the top bar (1a/1b at x 1520, y 80). Phone: centre-top (1d at x 304, y 86).
			AnchorPoint = if phone then Vector2.new(0.5, 0) else Vector2.new(1, 0),
			Position = if phone then UDim2.new(0.5, 0, 0, 86) else UDim2.new(1, -60, 0, 80),
			Size = UDim2.fromOffset(if phone then 250 else 340, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
		}, notes),
	}
	local stamp = view.stamp
	if stamp ~= nil then
		-- Keyed by the toast id, so a new stamp remounts and pops again.
		children[`stamp{stamp.id}`] = e(PaperStamp, {
			text = stamp.text,
			size = text.bigStamp,
			tilt = stamp.tilt,
			pop = true,
			anchor = Vector2.new(0.5, 0.5),
			position = UDim2.fromScale(0.5, 0.38),
		})
	end
	return e("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1 }, children)
end
```

**Module shape:** the file holds two functions: `Layer(props: { view: PaperToastViewModel.ToastView, layout: UIPaperConstants.Layout })` (everything above from `local text = ...` down, presentational) and `Widget()` (reads `ToastStore.toasts`, `OccupantCatchStore.scaring` and `usePaperLayout()`, returns `nil` while scaring, else `e(Layer, { view = PaperToastViewModel.layout(toasts, PaperToastViewModel.MAX_NOTES), layout = layout })`), and returns `{ Widget = Widget, Layer = Layer }`. `HudRegistry` gets `PaperToastStack.Widget`; `PaperToastStack.story.luau` renders `PaperToastStack.Layer` from a control-built toast list (controls `Notes = 3`, `Stamp = true`, `Phone = false`) so the story never touches the stores.

- [ ] **Step 4: Register it and retire the base toasts.** In `ShiftServiceClient`:
  - **B2 approved:** in `init`, `ToastServiceClient:setDefaultWidget(false)` (add `"ToastServiceClient"` to `dependencies`) and

```lua
		if not HudRegistry.has("paperToasts") then
			HudRegistry.register("paperToasts", PaperToastStack.Widget, 1000)
		end
```

  - **B2 declined (fallback):** at module load, beside the toast-style registration loop:

```lua
-- The approved paper toasts replace the base stack: registered under the base's own key at load, before
-- ToastServiceClient's init (its `HudRegistry.has("toasts")` guard then skips the base widget). Open question 7.
if not HudRegistry.has("toasts") then
	HudRegistry.register("toasts", PaperToastStack.Widget, 1000)
end
```

  Update the header.

- [ ] **Step 5: `SpecRoots`** (Paper block):

```lua
	["ReplicatedStorage.Client.UI.React.Screens.Paper.PaperToastStack"] = "React HUD widget (layout specced in PaperToastViewModel; story in PaperToastStack.story)",
```

- [ ] **Step 6: Controller: Studio TestEZ** (`PaperToastViewModel` passes) **and visual checks:** UI Labs `PaperToastStack` story against Figma 1f (desktop 340 px stickies, phone 250 px, stamp 120/40 px). Then Play (`RunTests = false`): the shift-start sticky slides in top-right; meeting the quota thunks "QUOTA MET" at the centre and the quota-met sticky appears; getting caught: during the 0.6 s scare no toast is visible. The base rounded toasts never appear. Screenshot 1b's moment.

- [ ] **Step 7: Gate and commit**

```bash
git add src
python3 scripts/python/module_map.py --write
git add docs/project-structure.md
stylua src/ReplicatedStorage/Client/UI/React/Screens/Paper src/ReplicatedStorage/Client/Features/Shift/ShiftServiceClient.luau src/ServerScriptService/Core/Testing/SpecRoots.luau
git add src
bash .superpowers/sdd/gate.sh
python3 scripts/python/check_pr_rules.py origin/main
git commit -m "feat(ui): paper sticky-note toasts and rubber stamps"
python3 scripts/python/module_map.py --check
```

---

### Task 9: The Shift HUD, desktop (1a, 1b, 1c)

The placeholder text panel becomes the approved desktop HUD: clearance folder and finder's fee plate, the punch-clock time card (with OVERTIME and the SALVAGE ×1.5 stamp), the clipped crew roster, the carry panel and the stapled clock-out slip. The view model now returns raw, display-ready fields per piece; a second view model builds the roster. The HUD goes dark during the scare beat and while the local player is caught.

**Files:**
- Modify: `src/ReplicatedStorage/Client/UI/React/Screens/Shift/ShiftHudViewModel.luau`; Test: `.../Shift/ShiftHudViewModel.spec.luau` (the `hud` and `pacing line` blocks rewritten; `clock` and `results` blocks kept)
- Create: `src/ReplicatedStorage/Client/UI/React/Screens/Shift/ShiftCrewViewModel.luau`; Test: `.../Shift/ShiftCrewViewModel.spec.luau`
- Create: `.../Shift/ShiftTimeCard.luau`, `.../Shift/ShiftClearancePanel.luau`, `.../Shift/ShiftCrewRoster.luau`, `.../Shift/ShiftCarryPanel.luau`, `.../Shift/ShiftClockOutSlip.luau`, `.../Shift/ShiftStoryFixtures.luau`
- Modify: `.../Shift/ShiftHudPanel.luau` (rewritten), `.../Shift/ShiftHudPanel.story.luau` (rewritten), `.../Shift/ShiftHud.luau`
- Modify: `src/ServerScriptService/Core/Testing/SpecRoots.luau`

**Interfaces:**
- Consumes: `ShiftStore.snapshot` (`crew`, `truck`, `stage`, `tier`, `sub`, `clockOutAt`, ...); `StateSyncClientStore.publicPlayers` (`carrying`, `pocket1`, `pocket2`, `canister`, `dead`, `caughtUntil`, `inTruck`, `vacuuming`, `room`); `OccupantCatchStore.scaring`; `CargoRegistry.get`; the paper kit (Task 7).
- Produces:
  - `ShiftHudViewModel.HudView = { clockLabel: string, time: string, outText: string, overtime: boolean, punched: number, pressure: number, cleared: string, quotaText: string, clearedShort: string, fill: number, quotaMet: boolean, fee: string, feeBoost: string?, hands: HandsView?, pockets: { PocketView }, canister: number, canisterMax: number, clockOut: string?, truck: number? }`; `HandsView = { name: string, value: string, traits: string, short: string }`; `PocketView = { name: string, empty: boolean }`; `ShiftHudViewModel.hud(snapshot: ShiftSnapshot?, me: PublicPlayer?, now: number, hidden: boolean) -> HudView?`; `ShiftHudViewModel.PUNCH_HOLES = 5`, `PRESSURE_PIPS = 3`.
  - `ShiftCrewViewModel.Tone = "ok" | "busy" | "danger" | "muted"`; `MemberView = { userId: number, name: string, status: string, short: string, tone: Tone, struck: boolean }`; `RosterView = { title: string, members: { MemberView }, compact: { string } }`; `ShiftCrewViewModel.roster(crew: { number }, players: PublicPlayerMap, names: { [number]: string }, truck: number?, clockingOut: boolean, now: number) -> RosterView?`.
  - Components: `ShiftTimeCard({ view: HudView, layout: Layout })`, `ShiftClearancePanel({ view, layout })`, `ShiftCrewRoster({ roster: RosterView, layout })`, `ShiftCarryPanel({ view, layout })`, `ShiftClockOutSlip({ left: string, truck: number?, layout })`, `ShiftHudPanel({ view: HudView, roster: RosterView?, layout: Layout })`.

- [ ] **Step 1: Failing specs.** Replace the `describe("hud", ...)` and `describe("pacing line", ...)` blocks of `ShiftHudViewModel.spec.luau` with:

```lua
	describe("hud", function()
		it("shows nothing outside a running shift, or while hidden", function()
			expect(ShiftHudViewModel.hud(nil, nil, 0, false)).to.equal(nil)
			expect(ShiftHudViewModel.hud(snapshot({ phase = "results" }), nil, 0, false)).to.equal(nil)
			expect(ShiftHudViewModel.hud(snapshot(), nil, 0, true)).to.equal(nil)
		end)

		it("fills the clearance folder and the fee plate", function()
			local view = ShiftHudViewModel.hud(snapshot(), nil, 580, false)
			expect(view.cleared).to.equal("120")
			expect(view.quotaText).to.equal("/ 350 cleared")
			expect(view.clearedShort).to.equal("120 / 350")
			expect(math.abs(view.fill - 120 / 350) < 1e-6).to.equal(true)
			expect(view.fee).to.equal("+40")
			expect(view.feeBoost).to.equal(nil)
		end)

		it("caps the clearance bar at full", function()
			local view = ShiftHudViewModel.hud(snapshot({ cleared = 400, quotaMet = true }), nil, 0, false)
			expect(view.fill).to.equal(1)
			expect(view.quotaMet).to.equal(true)
		end)

		it("punches the time card as the shift goes and lights a pip per tier", function()
			-- endsAt 1000: at now 580 there are 420 s left (nothing punched); at 832, 168 s left (3 of 5 punched).
			expect(ShiftHudViewModel.hud(snapshot(), nil, 580, false).punched).to.equal(0)
			expect(ShiftHudViewModel.hud(snapshot(), nil, 832, false).punched).to.equal(3)
			expect(ShiftHudViewModel.hud(snapshot({ tier = 0 }), nil, 600, false).pressure).to.equal(1)
			expect(ShiftHudViewModel.hud(snapshot({ tier = 2 }), nil, 600, false).pressure).to.equal(3)
		end)

		it("reads the time, OUT and the stage label", function()
			local view = ShiftHudViewModel.hud(snapshot(), nil, 748, false)
			expect(view.time).to.equal("4:12")
			expect(view.outText).to.equal("OUT 7:00")
			expect(view.clockLabel).to.equal("SHIFT")
			expect(view.overtime).to.equal(false)
		end)

		it("labels the break, the warning and overtime", function()
			expect(ShiftHudViewModel.hud(snapshot({ stage = "break", stageEndsAt = 124 }), nil, 100, false).clockLabel)
				.to.equal("HARLOW ON BREAK 0:24")
			expect(ShiftHudViewModel.hud(snapshot({ stage = "warning", stageEndsAt = 112 }), nil, 100, false).clockLabel)
				.to.equal("OVERTIME IN 0:12")
			local overtime = ShiftHudViewModel.hud(snapshot({ stage = "overtime" }), nil, 100, false)
			expect(overtime.clockLabel).to.equal("OVERTIME")
			expect(overtime.overtime).to.equal(true)
			expect(overtime.feeBoost).to.equal("×1.5 now")
		end)

		it("describes the hands item with its value and traits", function()
			local view = ShiftHudViewModel.hud(snapshot(), { carrying = "monitor" }, 0, false)
			expect(view.hands.name).to.equal("Monitor")
			expect(view.hands.value).to.equal("+30")
			expect(view.hands.traits).to.equal("medium · FRAGILE")
			expect(view.hands.short).to.equal("+30 fragile")
		end)

		it("shows empty hands, empty pockets and an absent canister", function()
			local view = ShiftHudViewModel.hud(snapshot(), nil, 0, false)
			expect(view.hands).to.equal(nil)
			expect(view.pockets[1].empty).to.equal(true)
			expect(view.pockets[1].name).to.equal("empty")
			expect(view.canister).to.equal(0)
			expect(view.canisterMax).to.equal(3)
		end)

		it("names a pocketed item", function()
			local view = ShiftHudViewModel.hud(snapshot(), { pocket2 = "plaque" }, 0, false)
			expect(view.pockets[2].name).to.equal("Employee of the Month plaque")
			expect(view.pockets[2].empty).to.equal(false)
		end)

		it("counts the clock-out down and carries the truck", function()
			local view =
				ShiftHudViewModel.hud(snapshot({ sub = "clockout", clockOutAt = 107, truck = 2 }), nil, 100, false)
			expect(view.clockOut).to.equal("0:07")
			expect(view.truck).to.equal(2)
		end)
	end)
```

(The file's `snapshot()` fixture gains `stage = "normal", tier = 0, crew = {}` defaults.)

`ShiftCrewViewModel.spec.luau`:

```lua
local ShiftCrewViewModel = require(script.Parent.ShiftCrewViewModel)

local NAMES = { [1] = "Sam", [2] = "Alex", [3] = "Jo" }

local function players(map)
	local result = {}
	for userId, entry in map do
		result[tostring(userId)] = entry
	end
	return result
end

local function statusOf(view, userId)
	for _, member in view.members do
		if member.userId == userId then
			return member
		end
	end
	return nil
end

return function()
	it("shows nothing for an empty crew", function()
		expect(ShiftCrewViewModel.roster({}, {}, NAMES, nil, false, 0)).to.equal(nil)
	end)

	it("titles the card with the truck when known", function()
		expect(ShiftCrewViewModel.roster({ 1 }, players({}), NAMES, 2, false, 0).title).to.equal("CREW ROSTER · TRUCK 2")
		expect(ShiftCrewViewModel.roster({ 1 }, players({}), NAMES, nil, false, 0).title).to.equal("CREW ROSTER")
	end)

	it("reads carrying, vacuuming, at the truck and the room in that order", function()
		local view = ShiftCrewViewModel.roster({ 1, 2, 3 }, players({
			[1] = { carrying = "printer", vacuuming = true },
			[2] = { vacuuming = true, inTruck = true },
			[3] = { inTruck = true, room = "Loading bay" },
		}), NAMES, 2, false, 0)
		expect(statusOf(view, 1).status).to.equal("carrying Printer")
		expect(statusOf(view, 1).tone).to.equal("busy")
		expect(statusOf(view, 2).status).to.equal("vacuuming")
		expect(statusOf(view, 2).tone).to.equal("ok")
		expect(statusOf(view, 3).status).to.equal("at the truck")
	end)

	it("puts CAUGHT above every other status", function()
		local view = ShiftCrewViewModel.roster({ 2 }, players({
			[2] = { caughtUntil = 106, carrying = "printer", dead = true },
		}), NAMES, nil, false, 100)
		local alex = statusOf(view, 2)
		expect(alex.status).to.equal("CAUGHT · back 0:06")
		expect(alex.tone).to.equal("danger")
		expect(alex.struck).to.equal(true)
	end)

	it("clamps the back-in countdown at 0:00", function()
		local view = ShiftCrewViewModel.roster({ 2 }, players({ [2] = { caughtUntil = 90, dead = true } }), NAMES, nil, false, 100)
		expect(statusOf(view, 2).status).to.equal("CAUGHT · back 0:00")
	end)

	it("shows aboard / NOT ABOARD only while clocking out", function()
		local crew = players({ [1] = { inTruck = true, carrying = "printer" }, [3] = { vacuuming = true } })
		local out = ShiftCrewViewModel.roster({ 1, 3 }, crew, NAMES, 2, true, 0)
		expect(statusOf(out, 1).status).to.equal("in the truck bed")
		expect(statusOf(out, 3).status).to.equal("NOT ABOARD")
		expect(statusOf(out, 3).struck).to.equal(true)
		local normal = ShiftCrewViewModel.roster({ 1, 3 }, crew, NAMES, 2, false, 0)
		expect(statusOf(normal, 1).status).to.equal("carrying Printer")
		expect(statusOf(normal, 3).status).to.equal("vacuuming")
	end)

	it("falls back to the room, then to on shift", function()
		local view = ShiftCrewViewModel.roster({ 1, 2 }, players({ [1] = { room = "Archive" } }), NAMES, nil, false, 0)
		expect(statusOf(view, 1).status).to.equal("Archive")
		expect(statusOf(view, 1).tone).to.equal("muted")
		expect(statusOf(view, 2).status).to.equal("on shift")
	end)

	it("writes the phone's two lines, trouble on the second", function()
		local view = ShiftCrewViewModel.roster({ 1, 2, 3 }, players({
			[1] = { carrying = "printer" },
			[2] = { caughtUntil = 106, dead = true },
			[3] = { vacuuming = true },
		}), NAMES, nil, false, 100)
		expect(view.compact[1]).to.equal("Sam: carrying · Jo: vacuuming")
		expect(view.compact[2]).to.equal("Alex: CAUGHT · back 0:06")
	end)

	it("groups names that share a status on the phone", function()
		local view = ShiftCrewViewModel.roster({ 1, 2, 3 }, players({
			[1] = { inTruck = true },
			[2] = { inTruck = true },
		}), NAMES, nil, true, 0)
		expect(view.compact[1]).to.equal("Sam, Alex: in the truck bed")
		expect(view.compact[2]).to.equal("Jo: NOT ABOARD")
	end)

	it("names an unknown player Crew", function()
		local view = ShiftCrewViewModel.roster({ 9 }, players({}), NAMES, nil, false, 0)
		expect(view.members[1].name).to.equal("Crew")
	end)
end
```

Controller: Studio TestEZ: the new cases fail.

- [ ] **Step 2: Implement `ShiftHudViewModel.hud`.** Replace `HudView` and `hud` (keep `clock`, `ResultsView`, `results`, `OUTCOME_TEXT`, `nameOf`); update the header (the final HUD; `results` goes in Task 15):

```lua
export type HandsView = {
	name: string,
	value: string,
	traits: string,
	short: string,
}

export type PocketView = {
	name: string,
	empty: boolean,
}

export type HudView = {
	-- The time card.
	clockLabel: string,
	time: string,
	outText: string,
	overtime: boolean,
	punched: number,
	pressure: number,
	-- The clearance folder and the finder's fee plate.
	cleared: string,
	quotaText: string,
	clearedShort: string,
	fill: number,
	quotaMet: boolean,
	fee: string,
	feeBoost: string?,
	-- The carry panel.
	hands: HandsView?,
	pockets: { PocketView },
	canister: number,
	canisterMax: number,
	-- The clock-out slip's countdown, while one runs.
	clockOut: string?,
	truck: number?,
}

ShiftHudViewModel.PUNCH_HOLES = 5
ShiftHudViewModel.PRESSURE_PIPS = 3

local function traitsOf(def: CargoTypes.ItemDef): string
	local parts: { string } = { def.size }
	if def.fragile then
		table.insert(parts, "FRAGILE")
	end
	if def.rattly then
		table.insert(parts, "RATTLY")
	end
	return table.concat(parts, " · ")
end

local function handsOf(kind: PublicPlayerTypes.PublicValue?): HandsView?
	if type(kind) ~= "string" then
		return nil
	end
	local def = CargoRegistry.get(kind)
	if def == nil then
		return { name = kind, value = "", traits = "", short = "" }
	end
	return {
		name = def.name,
		value = `+{def.value}`,
		traits = traitsOf(def),
		short = `+{def.value}{if def.fragile then " fragile" else ""}`,
	}
end

local function stageLabel(snapshot: ShiftSnapshot, now: number): string
	local stageEndsAt = snapshot.stageEndsAt
	local left = if stageEndsAt ~= nil then stageEndsAt - now else 0
	if snapshot.stage == "break" then
		return `HARLOW ON BREAK {ShiftHudViewModel.clock(left)}`
	elseif snapshot.stage == "warning" then
		return `OVERTIME IN {ShiftHudViewModel.clock(left)}`
	elseif snapshot.stage == "overtime" then
		return "OVERTIME"
	end
	return "SHIFT"
end

--[=[
	The HUD's pieces while a shift runs; nil otherwise, and nil while `hidden` (the scare beat, or the local player is
	caught: the CCTV takes the screen). `me` is the local player's public entry.
]=]
function ShiftHudViewModel.hud(
	snapshot: ShiftSnapshot?,
	me: PublicPlayerTypes.PublicPlayer?,
	now: number,
	hidden: boolean
): HudView?
	if hidden or snapshot == nil or snapshot.phase ~= "running" then
		return nil
	end
	local entry: PublicPlayerTypes.PublicPlayer = me or {}
	local endsAt = snapshot.endsAt
	local left = if endsAt ~= nil then endsAt - now else 0
	local total = ShiftConstants.SHIFT_SECONDS
	local elapsed = math.clamp(total - left, 0, total)
	local pockets: { PocketView } = {}
	for _, field in CargoConstants.PUBLIC_POCKET_FIELDS do
		local kind = entry[field]
		local def = if type(kind) == "string" then CargoRegistry.get(kind) else nil
		table.insert(pockets, {
			name = if def ~= nil then def.name elseif type(kind) == "string" then kind else "empty",
			empty = type(kind) ~= "string",
		})
	end
	local fill = entry[VacuumConstants.PUBLIC_FIELD]
	local clockOutAt = snapshot.clockOutAt
	local overtime = snapshot.stage == "overtime"
	return {
		clockLabel = stageLabel(snapshot, now),
		time = ShiftHudViewModel.clock(left),
		outText = `OUT {ShiftHudViewModel.clock(total)}`,
		overtime = overtime,
		punched = math.clamp(math.floor(elapsed / total * ShiftHudViewModel.PUNCH_HOLES), 0, ShiftHudViewModel.PUNCH_HOLES),
		pressure = math.clamp(snapshot.tier + 1, 1, ShiftHudViewModel.PRESSURE_PIPS),
		cleared = tostring(snapshot.cleared),
		quotaText = `/ {snapshot.quota} cleared`,
		clearedShort = `{snapshot.cleared} / {snapshot.quota}`,
		fill = if snapshot.quota > 0 then math.clamp(snapshot.cleared / snapshot.quota, 0, 1) else 1,
		quotaMet = snapshot.quotaMet,
		fee = `+{snapshot.bonus}`,
		feeBoost = if overtime then `×{ShiftConstants.OVERTIME_SALVAGE_MULTIPLIER} now` else nil,
		hands = handsOf(entry[CarryConstants.PUBLIC_FIELD]),
		pockets = pockets,
		canister = if type(fill) == "number" then fill else 0,
		canisterMax = VacuumConstants.CANISTER_CAPACITY,
		clockOut = if snapshot.sub == "clockout" and clockOutAt ~= nil
			then ShiftHudViewModel.clock(clockOutAt - now)
			else nil,
		truck = snapshot.truck,
	}
end
```

(require `CargoTypes` from `ReplicatedStorage.Shared.Features.Cargo.Data.CargoTypes`.)

- [ ] **Step 3: Implement `ShiftCrewViewModel`:**

```lua
--!strict
--[=[
	ShiftCrewViewModel: the crew roster card (Figma 35:1100-35:1165, 1a-1e): each crew member's status line, the ink it
	is written in, whether their name is struck through (caught, or not aboard while clocking out), and the phone's
	two-line form (everyone fine on line one, trouble on line two, names sharing a status grouped). Status priority:
	caught > (while clocking out) in the truck bed / NOT ABOARD > carrying > vacuuming > at the truck > room > on shift.
	Pure.

	@class ShiftCrewViewModel
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PublicPlayerTypes = require(ReplicatedStorage.Shared.Data.PublicPlayerTypes)
local CargoRegistry = require(ReplicatedStorage.Shared.Features.Cargo.Data.CargoRegistry)
local CarryConstants = require(ReplicatedStorage.Shared.Features.Carry.Data.CarryConstants)
local DeathConstants = require(ReplicatedStorage.Shared.Features.Death.Data.DeathConstants)
local OccupantConstants = require(ReplicatedStorage.Shared.Features.Occupant.Data.OccupantConstants)
local ShiftConstants = require(ReplicatedStorage.Shared.Features.Shift.Data.ShiftConstants)
local StateSyncConstants = require(ReplicatedStorage.Shared.Features.StateSync.Data.StateSyncConstants)
local ShiftHudViewModel = require(ReplicatedStorage.Client.UI.React.Screens.Shift.ShiftHudViewModel)

export type Tone = "ok" | "busy" | "danger" | "muted"

export type MemberView = {
	userId: number,
	name: string,
	status: string,
	short: string,
	tone: Tone,
	struck: boolean,
}

export type RosterView = {
	title: string,
	members: { MemberView },
	compact: { string },
}

local ShiftCrewViewModel = {}

local function member(userId: number, name: string, status: string, short: string, tone: Tone, struck: boolean): MemberView
	return { userId = userId, name = name, status = status, short = short, tone = tone, struck = struck }
end

local function statusOf(
	userId: number,
	name: string,
	entry: PublicPlayerTypes.PublicPlayer,
	clockingOut: boolean,
	now: number
): MemberView
	local caughtUntil = entry[OccupantConstants.PUBLIC_CAUGHT_UNTIL]
	if type(caughtUntil) == "number" then
		local text = `CAUGHT · back {ShiftHudViewModel.clock(caughtUntil - now)}`
		return member(userId, name, text, text, "danger", true)
	end
	if entry[DeathConstants.PUBLIC_FIELD] == true then
		return member(userId, name, "CAUGHT", "CAUGHT", "danger", true)
	end
	local inTruck = entry[ShiftConstants.PUBLIC_IN_TRUCK] == true
	if clockingOut then
		if inTruck then
			return member(userId, name, "in the truck bed", "in the truck bed", "ok", false)
		end
		return member(userId, name, "NOT ABOARD", "NOT ABOARD", "danger", true)
	end
	local carrying = entry[CarryConstants.PUBLIC_FIELD]
	if type(carrying) == "string" then
		local def = CargoRegistry.get(carrying)
		return member(userId, name, `carrying {if def ~= nil then def.name else carrying}`, "carrying", "busy", false)
	end
	if entry[ShiftConstants.PUBLIC_VACUUMING] == true then
		return member(userId, name, "vacuuming", "vacuuming", "ok", false)
	end
	if inTruck then
		return member(userId, name, "at the truck", "at the truck", "ok", false)
	end
	local room = entry[ShiftConstants.PUBLIC_ROOM]
	if type(room) == "string" then
		return member(userId, name, room, room, "muted", false)
	end
	return member(userId, name, "on shift", "on shift", "muted", false)
end

-- "Sam, Alex: in the truck bed · Jo: vacuuming": names that share a short status, grouped, in roster order.
local function line(members: { MemberView }): string?
	local order: { string } = {}
	local names: { [string]: { string } } = {}
	for _, item in members do
		local group = names[item.short]
		if group == nil then
			group = {}
			names[item.short] = group
			table.insert(order, item.short)
		end
		table.insert(group, item.name)
	end
	if #order == 0 then
		return nil
	end
	local parts: { string } = {}
	for _, short in order do
		table.insert(parts, `{table.concat(names[short], ", ")}: {short}`)
	end
	return table.concat(parts, " · ")
end

function ShiftCrewViewModel.roster(
	crew: { number },
	players: PublicPlayerTypes.PublicPlayerMap,
	names: { [number]: string },
	truck: number?,
	clockingOut: boolean,
	now: number
): RosterView?
	if #crew == 0 then
		return nil
	end
	local members: { MemberView } = {}
	local fine: { MemberView } = {}
	local trouble: { MemberView } = {}
	for _, userId in crew do
		local entry = players[StateSyncConstants.publicEntryKey(userId)] or {}
		local view = statusOf(userId, names[userId] or "Crew", entry, clockingOut, now)
		table.insert(members, view)
		table.insert(if view.tone == "danger" then trouble else fine, view)
	end
	local compact: { string } = {}
	local first, second = line(fine), line(trouble)
	if first ~= nil then
		table.insert(compact, first)
	end
	if second ~= nil then
		table.insert(compact, second)
	end
	return {
		title = if truck ~= nil then `CREW ROSTER · TRUCK {truck}` else "CREW ROSTER",
		members = members,
		compact = compact,
	}
end

return ShiftCrewViewModel
```

(`StateSyncConstants.publicEntryKey(userId)` is the string key the spec's `players()` helper mimics with `tostring`; if `publicEntryKey` is not plain `tostring`, change the helper to call it.)

- [ ] **Step 4: Controller: Studio TestEZ.** Expected: the new `hud` and `ShiftCrewViewModel` cases pass (the old `ShiftHudPanel` no longer type-checks against the new `HudView`: Step 5 replaces it before the gate).

- [ ] **Step 5: The components.** All take `layout` and draw both variants only where Task 10 needs it (this task: desktop; the phone branch is a `nil` placeholder until Task 10). Positions are Figma 1a's, from the screen's top-left, below the top bar.

`ShiftTimeCard.luau` (360×132, top-centre at y 10):

```lua
local function ShiftTimeCard(props: ShiftTimeCardProps): React.ReactNode
	local view = props.view
	local color = UIPaperConstants.COLOR
	local holes: { [string]: React.ReactNode } = {}
	for index = 1, ShiftHudViewModel.PUNCH_HOLES do
		-- A punched hole is a dark slot; an unpunched one is a faint outline (shift progress, 1/5 each).
		holes[`hole{index}`] = e("Frame", {
			Position = UDim2.fromOffset(14, 34 + (index - 1) * 19),
			Size = UDim2.fromOffset(10, 16),
			BackgroundColor3 = color.ink,
			BackgroundTransparency = if index <= view.punched then 0 else 0.8,
			BorderSizePixel = 0,
		}, { corner = e("UICorner", { CornerRadius = UDim.new(0, 3) }) })
	end
	local pips: { [string]: React.ReactNode } = {}
	for index = 1, ShiftHudViewModel.PRESSURE_PIPS do
		pips[`pip{index}`] = e("Frame", {
			Position = UDim2.fromOffset(236 + (index - 1) * 32, 100),
			Size = UDim2.fromOffset(26, 12),
			BackgroundColor3 = color.stamp,
			BackgroundTransparency = if index <= view.pressure then 0 else 0.75,
			BorderSizePixel = 0,
		})
	end
	return e(PaperSheet, {
		anchor = Vector2.new(0.5, 0),
		position = UDim2.new(0.5, 0, 0, 10),
		size = UDim2.fromOffset(360, 132),
		paper = color.cream,
		band = "HARLOW & FINCH — TIME CARD",
		padding = 0,
		children = {
			holes = e("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1 }, holes),
			label = e(PaperLabel, { text = view.clockLabel, role = "body", size = 20, position = UDim2.fromOffset(40, 30), frame = UDim2.fromOffset(190, 0) }),
			time = e(PaperLabel, { text = view.time, role = "timer", size = 58, position = UDim2.fromOffset(40, 46), frame = UDim2.fromOffset(190, 0), color = if view.overtime then color.stamp else color.ink }),
			out = e(PaperLabel, { text = view.outText, role = "body", size = 20, position = UDim2.fromOffset(236, 30), frame = UDim2.fromOffset(110, 0) }),
			pressure = e(PaperLabel, { text = "PRESSURE", role = "body", size = 20, position = UDim2.fromOffset(236, 66), frame = UDim2.fromOffset(110, 0) }),
			pips = e("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1 }, pips),
		},
	})
end
```

plus, when `view.overtime`, a sibling `PaperStamp` "SALVAGE ×1.5" (size 30, tilt −3) anchored under the card at `UDim2.new(0.5, 0, 0, 156)` (1c: 875, 178). The component returns a transparent full-screen `Frame` holding the card and the optional stamp.

`ShiftClearancePanel.luau`: a manila `PaperSheet` with `tab = "CLEARANCE CONTRACT"` at (60, 72) 400×128: `PaperLabel` number 44 `view.cleared`, body 22 `view.quotaText`, an Oswald Bold 22 "MET" in `COLOR.inkGreen` at the right when `view.quotaMet`, and a bar: a 12 px ink-at-0.85 track with a `COLOR.exitGreen` fill `UDim2.fromScale(view.fill, 1)` (1c's green bar). Below it (60, 245) the fee plate: a `COLOR.monitorDeep` 400×56 strip (no paper: Figma's dark plate = a live number) with "FINDER'S FEE" (body 20, `COLOR.monitor`) and `view.fee` (number 32, `COLOR.cream`) and, when present, `view.feeBoost` (number 32, `COLOR.fluorGlow`) right-aligned.

`ShiftCrewRoster.luau` (desktop): a cream `PaperSheet` 350 × (46 + 36 per member) at (60, 330), `fastener = "clip"`, title `roster.title` (heading 20); per member a row: a 16 px tick box (ink stroke; a ✔-free tick drawn as two thin rotated ink Frames when `not struck`), the name (`PaperLabel` heading 22, `strike = member.struck`), the status (`PaperLabel` body 20, `color = UIPaperConstants.inkColor(tone)`), and for a struck member a marker "X" (`PaperLabel` marker 22, `COLOR.inkRed`) over the box. Rows are 36 px apart (Figma 35:1100: 50, 86, 122).

`ShiftCarryPanel.luau` (desktop, bottom-left at (48, 830), 640×200, `COLOR.night` at 0.15 transparency with a 1 px `COLOR.fluorescent` stroke at 0.7: Figma's dark tray for live state): HANDS block (title Oswald Bold 20; a 76×76 dashed-outline art slot; the item name Oswald Bold 28, the value 24 in `COLOR.monitor`, the traits body 20 in `COLOR.exitRed` when FRAGILE is in them else `COLOR.fluorescent`; "—" when hands are empty), POCKETS block (two 76×76 slots, Oswald Medium 20 names, the empty one dashed and `COLOR.slotEmpty`; a body-20 "Q pocket" caption built from the pocket binding in Task 11, plain "Q pocket" here), CANISTER block (three 26×60 bars filled `COLOR.fluorGlow` up to `view.canister`, "2 / 3" Oswald Bold 26, "full = dust bag" body 20).

`ShiftClockOutSlip.luau`: a cream `PaperSheet` 500×120, `fastener = "staple"`, `torn = true`, `tilt = -1`, red `band` `if truck then "CLOCK-OUT SLIP — TRUCK {truck}" else "CLOCK-OUT SLIP"`, "LEAVING IN" body 20, the countdown `PaperLabel` timer 52 in `COLOR.stamp`, and "Get in the truck bed.\nUnbanked cargo stays." body 20 to the right. Desktop position: top-centre under the time card, `AnchorPoint (0.5, 0)`, `Position = UDim2.new(0.5, 0, 0, 250)` (1c: 726, 263).

`ShiftHudPanel.luau` (rewritten): `props = { view: HudView, roster: RosterView?, layout: Layout }`; desktop returns a transparent full-screen `Frame` with `ShiftClearancePanel`, the roster when present, `ShiftTimeCard`, `ShiftCarryPanel`, and `ShiftClockOutSlip` when `view.clockOut ~= nil`; phone returns `nil` until Task 10.

`ShiftHud.luau` (the widget, rewired):

```lua
local function ShiftHud(): React.ReactNode
	local snapshot = useAtom(ShiftStore.snapshot)
	local publicPlayers = useAtom(StateSyncClientStore.publicPlayers)
	local scaring = useAtom(OccupantCatchStore.scaring)
	local layout = usePaperLayout()
	local now = useServerClock()
	local player = Players.LocalPlayer
	local me = if player ~= nil then publicPlayers[StateSyncConstants.publicEntryKey(player.UserId)] else nil
	local dead = me ~= nil and me[DeathConstants.PUBLIC_FIELD] == true
	local view = ShiftHudViewModel.hud(snapshot, me, now, scaring or dead)
	if view == nil or snapshot == nil then
		return nil
	end
	local names: { [number]: string } = {}
	for _, userId in snapshot.crew do
		local member = Players:GetPlayerByUserId(userId)
		if member ~= nil then
			names[userId] = member.DisplayName
		end
	end
	local roster = ShiftCrewViewModel.roster(snapshot.crew, publicPlayers, names, snapshot.truck, snapshot.sub == "clockout", now)
	return e(ShiftHudPanel, { view = view, roster = roster, layout = layout })
end
```

`ShiftStoryFixtures.luau` (static sample data for the Shift stories, no logic): `snapshot(extra)` (a running shift like the spec fixture, `crew = { 1, 2, 3 }`, `truck = 2`), `players` (Sam carrying a printer, Alex caught with `caughtUntil` 6 s ahead and `dead`, Jo vacuuming), `names = { [1] = "Sam", [2] = "Alex", [3] = "Jo" }`, `me = { canister = 2, carrying = "monitor", pocket1 = "plaque" }`.

`ShiftHudPanel.story.luau` (rewritten): controls `Variant = UILabs.Choose({ "1a normal", "1b quota met", "1c overtime + clock-out" })`, `Phone = false`, `SecondsLeft = 252`; builds the snapshot from the fixtures per variant (1b: `cleared = 362, quotaMet = true`; 1c: `stage = "overtime", sub = "clockout", clockOutAt = 7`), runs `ShiftHudViewModel.hud(..., 0, false)` and `ShiftCrewViewModel.roster(...)` (1c with `clockingOut = true`), and renders `ShiftHudPanel` over an `COLOR.office` background at 1920×1080.

- [ ] **Step 6: `SpecRoots`.** Replace the two existing `ShiftHudPanel` / `ShiftHud` lines' reasons and add:

```lua
	["ReplicatedStorage.Client.UI.React.Screens.Shift.ShiftHudPanel"] = "React UI component (layout only; story in ShiftHudPanel.story; values specced in ShiftHudViewModel)",
	["ReplicatedStorage.Client.UI.React.Screens.Shift.ShiftHud"] = "React HUD widget wiring stores to ShiftHudPanel (view models specced)",
	["ReplicatedStorage.Client.UI.React.Screens.Shift.ShiftTimeCard"] = "presentational React component (story in ShiftHudPanel.story)",
	["ReplicatedStorage.Client.UI.React.Screens.Shift.ShiftClearancePanel"] = "presentational React component (story in ShiftHudPanel.story)",
	["ReplicatedStorage.Client.UI.React.Screens.Shift.ShiftCrewRoster"] = "presentational React component (roster specced in ShiftCrewViewModel; story in ShiftHudPanel.story)",
	["ReplicatedStorage.Client.UI.React.Screens.Shift.ShiftCarryPanel"] = "presentational React component (story in ShiftHudPanel.story)",
	["ReplicatedStorage.Client.UI.React.Screens.Shift.ShiftClockOutSlip"] = "presentational React component (story in ShiftHudPanel.story)",
	["ReplicatedStorage.Client.UI.React.Screens.Shift.ShiftStoryFixtures"] = "story fixtures (static sample data)",
```

- [ ] **Step 7: Visual checkpoint (controller).** UI Labs, edit mode: `ShiftHudPanel` story, each variant beside Figma 1a / 1b / 1c (6:2, 6:67, 6:136): positions, sizes, inks, the struck roster name with its marker X, the stapled torn slip, the SALVAGE ×1.5 stamp in overtime. Then Play (`RunTests = false`): the HUD shows during a shift and updates (bank → clearance bar; pick up → carry panel; vacuum → roster "vacuuming" for yourself), and disappears during the 0.6 s scare and while spectating. Screenshot each against its frame id.

- [ ] **Step 8: Gate and commit**

```bash
git add src
python3 scripts/python/module_map.py --write
git add docs/project-structure.md
stylua src/ReplicatedStorage/Client/UI/React/Screens/Shift src/ServerScriptService/Core/Testing/SpecRoots.luau
git add src
bash .superpowers/sdd/gate.sh
python3 scripts/python/check_pr_rules.py origin/main
git commit -m "feat(ui): approved desktop Shift HUD"
python3 scripts/python/module_map.py --check
```

---

### Task 10: The Shift HUD on phone (1d, 1e) and the arc of action buttons

**Files:**
- Modify: `src/ReplicatedStorage/Client/UI/React/Screens/Shift/ShiftHudViewModel.luau`; Test: `.../Shift/ShiftHudViewModel.spec.luau`
- Modify: `.../Shift/ShiftHudPanel.luau`, `.../Shift/ShiftTimeCard.luau`, `.../Shift/ShiftClearancePanel.luau`, `.../Shift/ShiftCrewRoster.luau`, `.../Shift/ShiftCarryPanel.luau`, `.../Shift/ShiftClockOutSlip.luau` (phone branches)
- Modify: `.../Shift/ShiftMobileButtons.luau` (rewritten), `.../Shift/ShiftHudPanel.story.luau` (the `Phone` control now renders 844×390)

**Interfaces:**
- Consumes: `CargoServiceClient:pocket() / drop() / throw()`, `VacuumServiceClient:beginVacuum() / endVacuum()` (unchanged); Task 9's views.
- Produces: `ShiftHudViewModel.ButtonsView = { primary: "VACUUM" | "LOAD", primaryReady: boolean, drop: boolean, throw: boolean, pocket: boolean, pocketReady: boolean }`; `ShiftHudViewModel.buttons(me: PublicPlayer?, loadReady: boolean) -> ButtonsView`.

- [ ] **Step 1: Failing spec** (append to `ShiftHudViewModel.spec.luau`):

```lua
	describe("phone buttons", function()
		it("offers VACUUM with empty hands, and nothing to drop or throw", function()
			local view = ShiftHudViewModel.buttons(nil, false)
			expect(view.primary).to.equal("VACUUM")
			expect(view.primaryReady).to.equal(false)
			expect(view.drop).to.equal(false)
			expect(view.throw).to.equal(false)
		end)

		it("switches to LOAD while holding something, lit only at the truck", function()
			expect(ShiftHudViewModel.buttons({ carrying = "monitor" }, false).primary).to.equal("LOAD")
			expect(ShiftHudViewModel.buttons({ carrying = "monitor" }, false).primaryReady).to.equal(false)
			expect(ShiftHudViewModel.buttons({ carrying = "monitor" }, true).primaryReady).to.equal(true)
		end)

		it("allows a throw only for a throwable item", function()
			expect(ShiftHudViewModel.buttons({ carrying = "rubbishBag" }, false).throw).to.equal(true)
			expect(ShiftHudViewModel.buttons({ carrying = "printer" }, false).throw).to.equal(false)
		end)

		it("lights POCKET for a tiny item and a free pocket", function()
			local tiny = ShiftHudViewModel.buttons({ carrying = "plaque" }, false)
			expect(tiny.pocket).to.equal(true)
			expect(tiny.pocketReady).to.equal(true)
			local full = ShiftHudViewModel.buttons({ carrying = "plaque", pocket1 = "plaque", pocket2 = "goldenStapler" }, false)
			expect(full.pocketReady).to.equal(false)
		end)

		it("keeps POCKET usable to take something out with empty hands", function()
			local view = ShiftHudViewModel.buttons({ pocket1 = "plaque" }, false)
			expect(view.pocket).to.equal(true)
			expect(view.pocketReady).to.equal(false)
		end)
	end)
```

(`throwable` per item: check `grep -n "throwable = true" src/ReplicatedStorage/Shared/Features/Cargo/Data/CargoRegistry.luau` and pick one throwable and one not.)

- [ ] **Step 2: Implement `buttons`:**

```lua
export type ButtonsView = {
	primary: "VACUUM" | "LOAD",
	primaryReady: boolean,
	drop: boolean,
	throw: boolean,
	pocket: boolean,
	pocketReady: boolean,
}

--[=[
	The phone's action buttons (Figma 1d/1e): one big button that is VACUUM with empty hands and LOAD while holding
	something (lit green when the truck's Load prompt is up, `loadReady`); DROP / THROW only with something in hand
	(THROW only for a throwable item); POCKET usable with a tiny item or something pocketed, lit when a tiny item can
	go in a free pocket.
]=]
function ShiftHudViewModel.buttons(me: PublicPlayerTypes.PublicPlayer?, loadReady: boolean): ButtonsView
	local entry: PublicPlayerTypes.PublicPlayer = me or {}
	local kind = entry[CarryConstants.PUBLIC_FIELD]
	local def = if type(kind) == "string" then CargoRegistry.get(kind) else nil
	local holding = type(kind) == "string"
	local filled, free = 0, 0
	for _, field in CargoConstants.PUBLIC_POCKET_FIELDS do
		if type(entry[field]) == "string" then
			filled += 1
		else
			free += 1
		end
	end
	local tiny = def ~= nil and def.size == "tiny"
	local primary: "VACUUM" | "LOAD" = if holding then "LOAD" else "VACUUM"
	return {
		primary = primary,
		primaryReady = holding and loadReady,
		drop = holding,
		throw = def ~= nil and def.throwable,
		pocket = tiny or filled > 0,
		pocketReady = tiny and free > 0,
	}
end
```

Controller: Studio TestEZ: the new cases pass.

- [ ] **Step 3: Phone layouts** (Figma 1d/1e, 844×390; safe area 48 L/R, 12 top, 20 bottom; nothing in the thumbstick zone, the bottom-left 40%; nothing on the Jump button):
  - `ShiftTimeCard` phone: 210×58 at top-centre y 8, red left edge 8 px instead of the band, time timer 32, `outText` Oswald 14 at the right, the three pips 16×8 under it; no punch holes (Figma drops them).
  - `ShiftClearancePanel` phone: manila 236×56 at (48, 64): "CLEARANCE" heading 14, `clearedShort` number 18 right-aligned, bar 10 px; fee plate 236×34 at (48, 128): "FINDER'S FEE" body 14, `fee` + `feeBoost` number 18.
  - `ShiftCrewRoster` phone: a cream strip 232 wide at (48, 172), clip on top, the `compact` lines Oswald Medium 15, line 2 in `COLOR.inkRed`.
  - `ShiftCarryPanel` phone: top-right at (572, 66) 224×92 (the thumbstick owns the bottom-left): HANDS 14 / name 18 / `short` 14 (red when fragile), two 52×52 pocket slots (15), "CAN" + three 12 px squares + "2/3" 14.
  - `ShiftClockOutSlip` phone: 200×72 at top-centre y 66 (1e: 290, 64): "CLOCK-OUT SLIP" heading 12 on the band, the countdown timer 30, "Get in the truck!" body 14; staple and torn edge as desktop.
  - The key hints and the prompt chip are desktop-only (Task 11); phone uses the engine prompt's tap or the LOAD button.

- [ ] **Step 4: `ShiftMobileButtons.luau` (rewritten).** Shown only on touch devices while a shift runs and the HUD is not hidden; reads `ShiftStore.snapshot`, the local public entry, `OccupantCatchStore.scaring`, and (Task 11) the prompt store; `buttons(me, false)` for now. The arc (Figma 1d, top-left corners in the 844×390 frame, converted to offsets from the bottom-right so they track the Jump button on any phone):

```lua
-- Figma 1d: LOAD/VACUUM 104 px at (608, 268); DROP (512, 282), THROW (555, 194), POCKET (651, 173), 72 px each;
-- >= 16 px between circles, all clear of the Jump button (bottom-right). Offsets from the bottom-right corner.
local ARC = {
	primary = UDim2.new(1, -236, 1, -122),
	drop = UDim2.new(1, -332, 1, -108),
	throw = UDim2.new(1, -289, 1, -196),
	pocket = UDim2.new(1, -193, 1, -217),
}
```

Each button is a round `TextButton` (`UICorner` 0.5 scale, `UIStroke` 3 px `COLOR.fluorescent`), `COLOR.night` fill, label Oswald Bold (20 large / 15 small) in `COLOR.fluorescent`; a "ready" button (LOAD at the truck, POCKET with a tiny item) fills `COLOR.exitGreen` with `COLOR.night` text; an unavailable one (DROP/THROW with empty hands) draws at 0.5 transparency and ignores input. The big button keeps M1's hold semantics for VACUUM (`InputBegan` → `VacuumServiceClient:beginVacuum()`, `InputEnded` / `MouseLeave` → `endVacuum()`, and the unmount cleanup); as LOAD it is drawn but inert until Task 11 wires it. DROP / THROW / POCKET call `CargoServiceClient:drop() / throw() / pocket()` on `Activated`.

- [ ] **Step 5: Visual checkpoint (controller).** UI Labs `ShiftHudPanel` with `Phone = true` against Figma 1d (9:61) and 1e (9:116). In Studio, Play with the device emulator on a landscape phone (e.g. iPhone 14, 844×390): the arc sits around the Jump button with clear gaps, nothing sits in the bottom-left 40%, every label ≥ 14 px; hold VACUUM on a pile; pick up a plaque: POCKET lights green; pick up a monitor: the big button reads LOAD (inert until Task 11).

- [ ] **Step 6: Gate and commit**

```bash
git add src
python3 scripts/python/module_map.py --write
git add docs/project-structure.md
stylua src/ReplicatedStorage/Client/UI/React/Screens/Shift
git add src
bash .superpowers/sdd/gate.sh
python3 scripts/python/check_pr_rules.py origin/main
git commit -m "feat(ui): phone Shift HUD and action-button arc"
python3 scripts/python/module_map.py --check
```

---

### Task 11: The paper interaction prompt, the phone LOAD button and the key hints

**Files:**
- Create: `src/ReplicatedStorage/Client/Features/Shift/State/ShiftPromptStore.luau`; Test: `.../Shift/State/ShiftPromptStore.spec.luau`
- Create: `src/ReplicatedStorage/Client/Features/Shift/Systems/ShiftPromptSystem.luau` (spec-exempt shell)
- Create: `src/ReplicatedStorage/Client/UI/React/Screens/Shift/ShiftPromptChip.luau`, `.../Shift/ShiftKeyHints.luau`
- Modify: `.../Shift/ShiftHudViewModel.luau`; Test: `.../Shift/ShiftHudViewModel.spec.luau`
- Modify: `.../Shift/ShiftHudPanel.luau` (key hints row), `.../Shift/ShiftHud.luau` (hint bindings), `.../Shift/ShiftMobileButtons.luau` (LOAD wired), `.../Shift/ShiftCarryPanel.luau` (the pocket caption reads the binding)
- Modify: `src/ReplicatedStorage/Client/Features/Shift/ShiftServiceClient.luau`
- Modify: `src/ServerScriptService/Core/Testing/SpecRoots.luau`

**Interfaces:**
- Consumes: the engine's `ProximityPrompt.Style`, `ProximityPromptService.PromptShown(prompt, inputType)` / `PromptHidden(prompt)` / `PromptButtonHoldBegan(prompt, player)` / `PromptButtonHoldEnded(prompt, player)`, `ProximityPrompt:InputHoldBegin()` / `InputHoldEnd()`; `InteractionConstants.TAG`, `PROMPT_NAME`, `KIND_ATTRIBUTE`; `InputServiceClient:bindingsFor(actionId) -> Bindings?`; `CargoConstants.LOAD_KIND`, `POCKET_ACTION`; `VacuumConstants.ACTION`.
- Produces:
  - `ShiftPromptStore.PromptView = { id: number, action: string, object: string, key: string, hold: number, kind: string?, holdStartedAt: number? }`; atom `ShiftPromptStore.shown: Atom<PromptView?>`; `show(view: PromptView)`, `hide(id: number)` (only if `id` is the one shown), `holdBegan(id: number, now: number)`, `holdEnded(id: number)`, `clear()`.
  - `ShiftPromptSystem.start() -> () -> ()`, `ShiftPromptSystem.press(down: boolean)`.
  - `ShiftServiceClient:pressPrompt(down: boolean)`.
  - `ShiftHudViewModel.PromptChipView = { key: string, text: string, fill: number? }`; `ShiftHudViewModel.prompt(view: PromptView?, carrying: PublicValue?, now: number) -> PromptChipView?`; `ShiftHudViewModel.HintView = { prefix: string?, key: string, label: string }`; `ShiftHudViewModel.keyName(input: Enum.KeyCode | Enum.UserInputType) -> string`; `ShiftHudViewModel.keyHints(bindings: { [string]: { Enum.KeyCode | Enum.UserInputType }? }) -> { HintView }`.

- [ ] **Step 1: Verify the engine APIs before building on them.** Read the reference pages for `ProximityPrompt` (`Style`, `InputHoldBegin`, `InputHoldEnd`, `HoldDuration`) and `ProximityPromptService` (`PromptShown`, `PromptHidden`, `PromptButtonHoldBegan`, `PromptButtonHoldEnded`) at create.roblox.com/docs/reference/engine/classes/. Confirm: (1) `Style = Custom` hides the default UI but keeps the keyboard/gamepad key working; (2) the Shown/Hidden events fire for Custom prompts on the client; (3) `InputHoldBegin` / `InputHoldEnd` are callable from a LocalScript and trigger the prompt (respecting `HoldDuration`). Then in Studio Play, from the command bar on the client, set one Interaction prompt's `Style` to `Custom` and call `InputHoldBegin()` / `InputHoldEnd()` on it: the server's interaction runs (e.g. Load banks the carried item). **If any of the three does not hold, stop this task's prompt half**: keep the engine's default prompts, skip Steps 2-4's prompt parts and the LOAD wiring, build only the key hints, and record why in the task log and the PR.

- [ ] **Step 2: Failing specs.** `ShiftPromptStore.spec.luau`:

```lua
local ShiftPromptStore = require(script.Parent.ShiftPromptStore)

local function view(id, kind)
	return { id = id, action = "Load", object = "Truck", key = "E", hold = 0, kind = kind }
end

return function()
	afterEach(function()
		ShiftPromptStore.clear()
	end)

	it("shows the latest prompt", function()
		ShiftPromptStore.show(view(1, "cargo-load"))
		ShiftPromptStore.show(view(2, "shift-clockout"))
		expect(ShiftPromptStore.shown().id).to.equal(2)
	end)

	it("hides only the prompt that is shown", function()
		ShiftPromptStore.show(view(2))
		ShiftPromptStore.hide(1)
		expect(ShiftPromptStore.shown().id).to.equal(2)
		ShiftPromptStore.hide(2)
		expect(ShiftPromptStore.shown()).to.equal(nil)
	end)

	it("records when a hold began and forgets it when it ends", function()
		ShiftPromptStore.show(view(3))
		ShiftPromptStore.holdBegan(3, 10)
		expect(ShiftPromptStore.shown().holdStartedAt).to.equal(10)
		ShiftPromptStore.holdEnded(3)
		expect(ShiftPromptStore.shown().holdStartedAt).to.equal(nil)
	end)

	it("ignores a hold on a prompt that is not shown", function()
		ShiftPromptStore.show(view(3))
		ShiftPromptStore.holdBegan(4, 10)
		expect(ShiftPromptStore.shown().holdStartedAt).to.equal(nil)
	end)
end
```

Append to `ShiftHudViewModel.spec.luau`:

```lua
	describe("prompt chip", function()
		local function prompt(extra)
			local value = { id = 1, action = "Load", object = "Truck", key = "E", hold = 0, kind = "cargo-load" }
			for key, item in extra or {} do
				value[key] = item
			end
			return value
		end

		it("says what a Load does with the item in hand", function()
			local chip = ShiftHudViewModel.prompt(prompt(), "monitor", 0)
			expect(chip.key).to.equal("E")
			expect(chip.text).to.equal("LOAD monitor onto the truck")
		end)

		it("falls back to the prompt's own words", function()
			local chip = ShiftHudViewModel.prompt(prompt({ kind = "shift-clockout", action = "Clock out", object = "Time clock" }), nil, 0)
			expect(chip.text).to.equal("CLOCK OUT time clock")
		end)

		it("fills a hold prompt while it is held", function()
			local chip = ShiftHudViewModel.prompt(prompt({ kind = "cargo-search", action = "Search", object = "Desk", hold = 2, holdStartedAt = 10 }), nil, 11)
			expect(chip.fill).to.equal(0.5)
			expect(ShiftHudViewModel.prompt(prompt({ hold = 2 }), nil, 11).fill).to.equal(0)
			expect(ShiftHudViewModel.prompt(prompt(), nil, 11).fill).to.equal(nil)
		end)

		it("shows nothing without a prompt", function()
			expect(ShiftHudViewModel.prompt(nil, "monitor", 0)).to.equal(nil)
		end)
	end)

	describe("key hints", function()
		it("names keys and mouse buttons the way the HUD prints them", function()
			expect(ShiftHudViewModel.keyName(Enum.KeyCode.G)).to.equal("G")
			expect(ShiftHudViewModel.keyName(Enum.UserInputType.MouseButton1)).to.equal("LMB")
			expect(ShiftHudViewModel.keyName(Enum.KeyCode.Left)).to.equal("←")
		end)

		it("lists the five actions in Figma's order with each first keyboard binding", function()
			local hints = ShiftHudViewModel.keyHints({
				vacuum = { Enum.UserInputType.MouseButton1 },
				drop = { Enum.KeyCode.G },
				throw = { Enum.KeyCode.F },
				pocket = { Enum.KeyCode.Q },
				interact = { Enum.KeyCode.E },
			})
			expect(#hints).to.equal(5)
			expect(hints[1].prefix).to.equal("Hold")
			expect(hints[1].key).to.equal("LMB")
			expect(hints[1].label).to.equal("vacuum")
			expect(hints[5].key).to.equal("E")
			expect(hints[5].label).to.equal("load / search")
		end)

		it("skips an action with no binding", function()
			expect(#ShiftHudViewModel.keyHints({ drop = { Enum.KeyCode.G } })).to.equal(1)
		end)
	end)
```

(`"cargo-search"` stands for any hold prompt; the real search kind does not matter to the rule.)

Controller: Studio TestEZ: the new cases fail.

- [ ] **Step 3: Implement the store, the view-model parts and the system.** `ShiftPromptStore.luau`:

```lua
--!strict
--[=[
	ShiftPromptStore: the interaction prompt on screen, as the paper prompt chip and the phone LOAD button see it (Cleanup
	Crew M3 UI). ShiftPromptSystem writes it from the engine's prompt events; `hide` and the hold calls act only on the
	prompt that is shown, so an old prompt's late Hidden event cannot hide a newer one. Client-only UI state.

	@class ShiftPromptStore
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Charm = require(ReplicatedStorage.Packages.Charm)

export type PromptView = {
	id: number,
	action: string,
	object: string,
	key: string,
	hold: number,
	kind: string?,
	holdStartedAt: number?,
}

local initial: PromptView? = nil
local shown = Charm.atom(initial)

local ShiftPromptStore = {
	shown = shown,
}

function ShiftPromptStore.show(view: PromptView)
	shown(table.clone(view))
end

function ShiftPromptStore.hide(id: number)
	local current = shown()
	if current ~= nil and current.id == id then
		shown(nil)
	end
end

function ShiftPromptStore.holdBegan(id: number, now: number)
	local current = shown()
	if current ~= nil and current.id == id then
		local nextView = table.clone(current)
		nextView.holdStartedAt = now
		shown(nextView)
	end
end

function ShiftPromptStore.holdEnded(id: number)
	local current = shown()
	if current ~= nil and current.id == id then
		local nextView = table.clone(current)
		nextView.holdStartedAt = nil
		shown(nextView)
	end
end

function ShiftPromptStore.clear()
	shown(nil)
end

return ShiftPromptStore
```

`ShiftHudViewModel` additions (require `ShiftPromptStore` for its type, `CargoConstants.LOAD_KIND`, `VacuumConstants.ACTION`, `CargoConstants.POCKET_ACTION`):

```lua
export type PromptChipView = {
	key: string,
	text: string,
	-- 0-1 while a hold prompt is held; 0 for a hold prompt not yet held; nil for a press prompt.
	fill: number?,
}

--[=[
	The paper prompt chip (Figma 1a: "[E] LOAD monitor onto the truck"): a Load names the item in hand; anything else
	is the prompt's action in capitals and its object in lower case.
]=]
function ShiftHudViewModel.prompt(
	view: ShiftPromptStore.PromptView?,
	carrying: PublicPlayerTypes.PublicValue?,
	now: number
): PromptChipView?
	if view == nil then
		return nil
	end
	local text = `{string.upper(view.action)} {string.lower(view.object)}`
	if view.kind == CargoConstants.LOAD_KIND and type(carrying) == "string" then
		local def = CargoRegistry.get(carrying)
		text = `LOAD {string.lower(if def ~= nil then def.name else carrying)} onto the truck`
	end
	local fill: number? = nil
	if view.hold > 0 then
		local started = view.holdStartedAt
		fill = if started ~= nil then math.clamp((now - started) / view.hold, 0, 1) else 0
	end
	return { key = view.key, text = text, fill = fill }
end

export type HintView = {
	prefix: string?,
	key: string,
	label: string,
}

local KEY_GLYPHS: { [string]: string } = {
	MouseButton1 = "LMB",
	MouseButton2 = "RMB",
	Left = "←",
	Right = "→",
	LeftShift = "Shift",
}

function ShiftHudViewModel.keyName(input: Enum.KeyCode | Enum.UserInputType): string
	return KEY_GLYPHS[input.Name] or input.Name
end

-- Figma 1a's hint row, in order: the action id, how to say it, and whether it is held.
local HINTS: { { action: string, label: string, hold: boolean } } = {
	{ action = VacuumConstants.ACTION, label = "vacuum", hold = true },
	{ action = "drop", label = "drop", hold = false },
	{ action = "throw", label = "throw", hold = false },
	{ action = CargoConstants.POCKET_ACTION, label = "pocket", hold = false },
	{ action = "interact", label = "load / search", hold = false },
}

function ShiftHudViewModel.keyHints(bindings: { [string]: { Enum.KeyCode | Enum.UserInputType }? }): { HintView }
	local hints: { HintView } = {}
	for _, hint in HINTS do
		local list = bindings[hint.action]
		local first = if list ~= nil then list[1] else nil
		if first ~= nil then
			table.insert(hints, { prefix = if hint.hold then "Hold" else nil, key = ShiftHudViewModel.keyName(first), label = hint.label })
		end
	end
	return hints
end
```

(The real action ids: `grep -n "register(\"" src/ReplicatedStorage/Client/Features/Carry/CarryServiceClient.luau` gives `drop` / `throw`; `interact` is a base default in `InputConstants`; confirm and use the real ids.)

`ShiftPromptSystem.luau`:

```lua
--!strict
--[=[
	ShiftPromptSystem: draws the Interaction prompts on paper (Cleanup Crew M3 UI, Figma 1a). Every Interaction prompt
	(InteractionConstants.TAG / PROMPT_NAME) is switched to the Custom style on this client (a local property write: the
	engine stops drawing its own card, the key still works); the engine's Shown / Hidden / hold events keep
	ShiftPromptStore current; `press` holds or releases the shown prompt for touch (the chip and the phone LOAD button).
	The server still validates every trigger (InteractionServiceServer).

	Spec-exempt shell (ProximityPromptService, Instances); the chip's words are the specced ShiftHudViewModel.prompt and
	the bookkeeping the specced ShiftPromptStore.

	@class ShiftPromptSystem
]=]

local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Observers = require(ReplicatedStorage.Packages.Observers)
local InteractionConstants = require(ReplicatedStorage.Shared.Features.Interaction.Data.InteractionConstants)
local ShiftPromptStore = require(ReplicatedStorage.Client.Features.Shift.State.ShiftPromptStore)
local ShiftHudViewModel = require(ReplicatedStorage.Client.UI.React.Screens.Shift.ShiftHudViewModel)

local ids: { [ProximityPrompt]: number } = {}
local nextId = 0
local current: ProximityPrompt? = nil

local function idOf(prompt: ProximityPrompt): number
	local id = ids[prompt]
	if id == nil then
		nextId += 1
		id = nextId
		ids[prompt] = id
	end
	return id
end

-- The Interaction kind of the object a prompt belongs to (the tagged ancestor's attribute).
local function kindOf(prompt: ProximityPrompt): string?
	local node: Instance? = prompt.Parent
	while node ~= nil do
		local kind = node:GetAttribute(InteractionConstants.KIND_ATTRIBUTE)
		if type(kind) == "string" then
			return kind
		end
		node = node.Parent
	end
	return nil
end

local function isOurs(prompt: ProximityPrompt): boolean
	return prompt.Name == InteractionConstants.PROMPT_NAME
end

local ShiftPromptSystem = {}

function ShiftPromptSystem.start(): () -> ()
	local connections: { RBXScriptConnection } = {}
	local stopObserver = Observers.observeTag(InteractionConstants.TAG, function(target: Instance)
		local alive = true
		task.spawn(function()
			-- The server parents the prompt under the object's root part; it may replicate a moment later.
			local deadline = os.clock() + 10
			while alive and os.clock() < deadline do
				local prompt = target:FindFirstChild(InteractionConstants.PROMPT_NAME, true)
				if prompt ~= nil and prompt:IsA("ProximityPrompt") then
					prompt.Style = Enum.ProximityPromptStyle.Custom
					return
				end
				task.wait(0.25)
			end
		end)
		return function()
			alive = false
		end
	end)
	table.insert(connections, ProximityPromptService.PromptShown:Connect(function(prompt: ProximityPrompt)
		if not isOurs(prompt) then
			return
		end
		current = prompt
		ShiftPromptStore.show({
			id = idOf(prompt),
			action = prompt.ActionText,
			object = prompt.ObjectText,
			key = ShiftHudViewModel.keyName(prompt.KeyboardKeyCode),
			hold = prompt.HoldDuration,
			kind = kindOf(prompt),
		})
	end))
	table.insert(connections, ProximityPromptService.PromptHidden:Connect(function(prompt: ProximityPrompt)
		if current == prompt then
			current = nil
		end
		ShiftPromptStore.hide(idOf(prompt))
	end))
	table.insert(connections, ProximityPromptService.PromptButtonHoldBegan:Connect(function(prompt: ProximityPrompt, player: Player)
		if player == Players.LocalPlayer then
			ShiftPromptStore.holdBegan(idOf(prompt), os.clock())
		end
	end))
	table.insert(connections, ProximityPromptService.PromptButtonHoldEnded:Connect(function(prompt: ProximityPrompt, player: Player)
		if player == Players.LocalPlayer then
			ShiftPromptStore.holdEnded(idOf(prompt))
		end
	end))
	return function()
		stopObserver()
		for _, connection in connections do
			connection:Disconnect()
		end
		current = nil
		table.clear(ids)
		ShiftPromptStore.clear()
	end
end

--[=[
	Holds (`down`) or releases the shown prompt: the touch path for the chip and the phone LOAD button.
]=]
function ShiftPromptSystem.press(down: boolean)
	local prompt = current
	if prompt == nil or prompt.Parent == nil then
		return
	end
	if down then
		prompt:InputHoldBegin()
	else
		prompt:InputHoldEnd()
	end
end

return ShiftPromptSystem
```

(`ids` keys prompts strongly: they are cleared on stop, and prompts are few and rebuilt only per shift; if Office rebuilds interactables every shift, make the table weak-keyed with `setmetatable(ids, { __mode = "k" })` as `DeathServiceServer` does for humanoids. Also check that `InteractionServiceClient` already waits for the prompt the same way; the two observers are independent and both are harmless.)

`ShiftServiceClient`: in `start`, `table.insert(unsubscribers, ShiftPromptSystem.start())`; the type gains `pressPrompt: (self: ShiftServiceClient, down: boolean) -> (),` and `pressPrompt = function(_self, down) ShiftPromptSystem.press(down) end,`.

- [ ] **Step 4: The components.** `ShiftPromptChip.luau` (HUD widget, desktop and phone): reads `ShiftPromptStore.shown`, the local public entry's `carrying`, `OccupantCatchStore.scaring` and the local `dead` flag (returns `nil` when hidden), `useServerClock(0.05)` only while a hold is running (else 0.25) for the fill, and `ShiftHudViewModel.prompt(...)`. It draws a cream slip (`PaperSheet`, `fastener = "tape"`, tilt −1) at `UDim2.new(0.5, 0, 0.6, 0)` (1a: 757, 654) with a `KeyChip` (24) and the text (body 22); a hold prompt gets an `COLOR.inkGreen` strip filling under the text by `fill`. The whole chip is a `TextButton` (`Text = ""`): `InputBegan` touch/mouse → `ShiftServiceClient:pressPrompt(true)`, `InputEnded` / `MouseLeave` → `pressPrompt(false)` (the touch path; the keyboard key goes to the engine directly). Phone: the chip is 280 wide at `UDim2.new(0.5, 0, 0, 236)`, text 15, KeyChip hidden (`key` drawn only when `layout == "desktop"`).

`ShiftKeyHints.luau`: a horizontal `UIListLayout` row centred at y 1030 (desktop only; `nil` on phone or without a keyboard), each hint `[prefix] KeyChip(20) label` in body 20, `COLOR.fluorescent` at `MOTION.hintTransparency`, 32 px between hints.

`ShiftHud`: build `bindings` once per render from `InputServiceClient:bindingsFor(id)` (`keyboard` list) for the five action ids, pass `hints = ShiftHudViewModel.keyHints(bindings)` to `ShiftHudPanel` (new optional prop `hints: { HintView }?`), which draws `ShiftKeyHints` on desktop. `ShiftCarryPanel`'s caption becomes `"{pocket key} pocket"` from the hints (prop `pocketKey: string?`, default "Q").

`ShiftMobileButtons`: read `ShiftPromptStore.shown`; `loadReady = shown ~= nil and shown.kind == CargoConstants.LOAD_KIND`; as LOAD the big button calls `ShiftServiceClient:pressPrompt(true)` on `InputBegan` and `pressPrompt(false)` on `InputEnded` / `MouseLeave` (it stays inert, drawn at 0.5, when not `primaryReady`).

Register the chip in `ShiftServiceClient.init`: `HudRegistry.register("shiftPrompt", ShiftPromptChip, ShiftConstants.HUD_ORDER + 3)`.

- [ ] **Step 5: `SpecRoots`:**

```lua
	["ReplicatedStorage.Client.Features.Shift.Systems.ShiftPromptSystem"] = "ProximityPromptService/Instance shell (the chip's words are specced in ShiftHudViewModel.prompt, the bookkeeping in ShiftPromptStore)",
	["ReplicatedStorage.Client.UI.React.Screens.Shift.ShiftPromptChip"] = "React HUD widget (words specced in ShiftHudViewModel.prompt)",
	["ReplicatedStorage.Client.UI.React.Screens.Shift.ShiftKeyHints"] = "presentational React component (hints specced in ShiftHudViewModel.keyHints)",
```

- [ ] **Step 6: Controller: Studio TestEZ** (`ShiftPromptStore`, `ShiftHudViewModel` pass) **and Play check:** the engine's grey prompt card never appears; walking to the truck with a monitor shows "[E] LOAD monitor onto the truck" on a taped slip; E banks it (server-validated, Cargo's swoop + "+30" floater); the time clock shows "[E] CLOCK OUT time clock"; a desk search fills its strip while held. Phone emulator: tapping the chip loads; the big button reads LOAD and turns green at the truck, tapping it loads. Desktop bottom row reads "Hold LMB vacuum   G drop   F throw   Q pocket   E load / search" at 80% opacity. Screenshot vs 1a and 1d.

- [ ] **Step 7: Gate and commit**

```bash
git add src
python3 scripts/python/module_map.py --write
git add docs/project-structure.md
stylua src/ReplicatedStorage/Client/Features/Shift src/ReplicatedStorage/Client/UI/React/Screens/Shift src/ServerScriptService/Core/Testing/SpecRoots.luau
git add src
bash .superpowers/sdd/gate.sh
python3 scripts/python/check_pr_rules.py origin/main
git commit -m "feat(ui): paper interaction prompt, phone LOAD and key hints"
python3 scripts/python/module_map.py --check
```

---

### Task 12: The depot contract board scene (2a, 2b)

**Files:**
- Create (under `src/ReplicatedStorage/Client/UI/React/Screens/Depot/`): `DepotBoardViewModel.luau` + `DepotBoardViewModel.spec.luau`, `DepotBoardScreen.luau`, `DepotBoardPanel.luau`, `DepotBoardPanel.story.luau`, `DepotScene.luau`
- Modify: `src/ReplicatedStorage/Client/Features/Depot/DepotServiceClient.luau`, `src/ReplicatedStorage/Shared/Features/Depot/Data/DepotConstants.luau` (`BOARD_SCENE`)
- Modify: `src/ServerScriptService/Core/Testing/SpecRoots.luau`

**Interfaces:**
- Consumes: `DepotStore.board`, `DepotStore.lastShift` (Task 4); `DepotConstants.CONTRACTS`, `BOARD_COPY`, `SITE`; `ShiftConstants.QUOTA`, `SHIFT_SECONDS`, `RATING_TEXT`; `SceneRegistry.register`, `SceneStack.push / remove`; the paper kit.
- Produces:
  - `DepotBoardViewModel.RowView = { label: string, text: string, hazard: boolean }`; `LastView = { title: string, rows: { { label: string, value: string } }, stamp: string, met: boolean, lines: { string } }`; `BoardView = { title: string, workOrder: string, headline: string, subline: string, rows: { RowView }, sticky: string, approved: string, last: LastView?, dispatchLabel: string, dispatchTitle: string, dispatchSteps: string, close: string }`; `DepotBoardViewModel.workOrder(id: string) -> string`; `DepotBoardViewModel.board(id: string?, last: DepotTypes.LastShift?, phone: boolean) -> BoardView`.
  - `DepotConstants.BOARD_SCENE = "depot.Board"`: the scene `DepotScene` registers (Panel layer, `suppress = { mouse = true }`, `hud = "hidden"`). The name lives in `DepotConstants` so the screen (which closes it) and the scene module (which registers the screen) do not require each other.

- [ ] **Step 1: Failing spec** `DepotBoardViewModel.spec.luau`:

```lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DepotBoardViewModel = require(script.Parent.DepotBoardViewModel)
local DepotConstants = require(ReplicatedStorage.Shared.Features.Depot.Data.DepotConstants)

local LAST = { cleared = 362, quota = 350, bonus = 215, catches = 2, salvage = 6, offered = 9, quotaMet = true, rating = "satisfactory", truck = 2 }

local function rowOf(view, label)
	for _, row in view.rows do
		if row.label == label then
			return row
		end
	end
	return nil
end

return function()
	it("numbers the work order the same way every time", function()
		expect(DepotBoardViewModel.workOrder("harlow-finch-1")).to.equal("#2802")
		expect(DepotBoardViewModel.workOrder("harlow-finch-2")).to.equal("#2803")
	end)

	it("heads the work order with the client and the site", function()
		local contract = DepotConstants.CONTRACTS[1]
		local view = DepotBoardViewModel.board(contract.id, nil, false)
		expect(view.title).to.equal("TONIGHT'S JOB")
		expect(view.workOrder).to.equal("WORK ORDER #2802")
		expect(view.headline).to.equal(`{string.upper(contract.client)} — 4TH FLOOR OFFICES`)
		expect(view.subline).to.equal(contract.job)
	end)

	it("lists the desktop rows with the hazard marked and the contract's note", function()
		local contract = DepotConstants.CONTRACTS[2]
		local view = DepotBoardViewModel.board(contract.id, nil, false)
		expect(#view.rows).to.equal(6)
		expect(rowOf(view, "QUOTA").text).to.equal("350 clearance (rubbish bags, dust bags, recycling)")
		expect(rowOf(view, "SHIFT").text).to.equal("7:00 on the clock. Clock out at the truck any time.")
		expect(rowOf(view, "HAZARD").hazard).to.equal(true)
		expect(rowOf(view, "QUOTA").hazard).to.equal(false)
		expect(rowOf(view, "NOTES").text).to.equal(contract.note)
	end)

	it("keeps the phone to four short rows", function()
		local view = DepotBoardViewModel.board(nil, nil, true)
		expect(#view.rows).to.equal(4)
		expect(rowOf(view, "QUOTA").text).to.equal("350 clearance")
		expect(rowOf(view, "FEE").text).to.equal("Salvage → finder's fee")
	end)

	it("reads the first contract when none is open", function()
		expect(DepotBoardViewModel.board(nil, nil, false).subline).to.equal(DepotConstants.CONTRACTS[1].job)
	end)

	it("shows no last-shift card for a player who has not played", function()
		expect(DepotBoardViewModel.board(nil, nil, false).last).to.equal(nil)
	end)

	it("fills the last-shift card", function()
		local last = DepotBoardViewModel.board(nil, LAST, false).last
		expect(last.title).to.equal("YOUR LAST SHIFT — TRUCK 2")
		expect(last.rows[1].value).to.equal("362 / 350")
		expect(last.rows[2].value).to.equal("+215")
		expect(last.rows[3].value).to.equal("2")
		expect(last.rows[4].value).to.equal("6 of 9")
		expect(last.stamp).to.equal("QUOTA MET")
	end)

	it("drops the truck from the title when unknown and stamps a missed quota", function()
		local missed = table.clone(LAST)
		missed.truck = 0
		missed.quotaMet = false
		local last = DepotBoardViewModel.board(nil, missed, false).last
		expect(last.title).to.equal("YOUR LAST SHIFT")
		expect(last.stamp).to.equal("QUOTA MISSED")
		expect(last.met).to.equal(false)
	end)

	it("writes the phone's two last-shift lines", function()
		local last = DepotBoardViewModel.board(nil, LAST, true).last
		expect(last.title).to.equal("LAST SHIFT")
		expect(last.lines[1]).to.equal("Cleared 362/350  ·  Fee +215")
		expect(last.lines[2]).to.equal("Rehired 2  ·  Salvage 6 of 9")
	end)
end
```

Controller: Studio TestEZ: fails.

- [ ] **Step 2: Implement `DepotBoardViewModel`:**

```lua
--!strict
--[=[
	DepotBoardViewModel: the depot's contract board (Figma 2a/2b): tonight's work order (numbered from the contract id,
	the same everywhere), its rows (desktop six, phone four; the HAZARD row marked), the night guard's sticky, the
	returning player's last-shift card and the dispatch slip. Pure.

	@class DepotBoardViewModel
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DepotConstants = require(ReplicatedStorage.Shared.Features.Depot.Data.DepotConstants)
local DepotTypes = require(ReplicatedStorage.Shared.Features.Depot.Data.DepotTypes)
local ShiftConstants = require(ReplicatedStorage.Shared.Features.Shift.Data.ShiftConstants)
local ShiftHudViewModel = require(ReplicatedStorage.Client.UI.React.Screens.Shift.ShiftHudViewModel)

export type RowView = { label: string, text: string, hazard: boolean }

export type LastView = {
	title: string,
	rows: { { label: string, value: string } },
	stamp: string,
	met: boolean,
	lines: { string },
}

export type BoardView = {
	title: string,
	workOrder: string,
	headline: string,
	subline: string,
	rows: { RowView },
	sticky: string,
	approved: string,
	last: LastView?,
	dispatchLabel: string,
	dispatchTitle: string,
	dispatchSteps: string,
	close: string,
}

local DepotBoardViewModel = {}

-- "#2802": four digits from the contract id (a stable string hash), so every depot prints the same number.
function DepotBoardViewModel.workOrder(id: string): string
	local hash = 0
	for index = 1, #id do
		hash = (hash * 31 + string.byte(id, index)) % 10000
	end
	return string.format("#%04d", hash)
end

local function contractOf(id: string?): DepotTypes.Contract
	for _, contract in DepotConstants.CONTRACTS do
		if contract.id == id then
			return contract
		end
	end
	return DepotConstants.CONTRACTS[1]
end

local function lastOf(last: DepotTypes.LastShift, phone: boolean): LastView
	local stamp = if last.quotaMet then "QUOTA MET" else "QUOTA MISSED"
	local title = if phone
		then "LAST SHIFT"
		elseif last.truck > 0 then `YOUR LAST SHIFT — TRUCK {last.truck}`
		else "YOUR LAST SHIFT"
	return {
		title = title,
		rows = {
			{ label = "Cleared", value = `{last.cleared} / {last.quota}` },
			{ label = "Finder's fee", value = `+{last.bonus}` },
			{ label = "Times rehired", value = tostring(last.catches) },
			{ label = "Salvage found", value = `{last.salvage} of {last.offered}` },
		},
		stamp = stamp,
		met = last.quotaMet,
		lines = {
			`Cleared {last.cleared}/{last.quota}  ·  Fee +{last.bonus}`,
			`Rehired {last.catches}  ·  Salvage {last.salvage} of {last.offered}`,
		},
	}
end

function DepotBoardViewModel.board(id: string?, last: DepotTypes.LastShift?, phone: boolean): BoardView
	local contract = contractOf(id)
	local copy = DepotConstants.BOARD_COPY
	local quota = ShiftConstants.QUOTA
	local shift = ShiftHudViewModel.clock(ShiftConstants.SHIFT_SECONDS)
	local rows: { RowView }
	if phone then
		rows = {
			{ label = "QUOTA", text = `{quota} {copy.quotaPhone}`, hazard = false },
			{ label = "SHIFT", text = `{shift} · {copy.shiftPhone}`, hazard = false },
			{ label = "FEE", text = copy.feePhone, hazard = false },
			{ label = "HAZARD", text = copy.hazardPhone, hazard = true },
		}
	else
		rows = {
			{ label = "QUOTA", text = `{quota} {copy.quota}`, hazard = false },
			{ label = "SHIFT", text = `{shift} {copy.shift}`, hazard = false },
			{ label = "FINDER'S FEE", text = copy.fee, hazard = false },
			{ label = "CREW", text = copy.crew, hazard = false },
			{ label = "HAZARD", text = copy.hazard, hazard = true },
			{ label = "NOTES", text = contract.note, hazard = false },
		}
	end
	local number = DepotBoardViewModel.workOrder(contract.id)
	return {
		title = copy.title,
		workOrder = if phone
			then `WORK ORDER {number} · {string.upper(contract.client)}`
			else `WORK ORDER {number}`,
		headline = `{string.upper(contract.client)} — {string.upper(DepotConstants.SITE)}`,
		subline = contract.job,
		rows = rows,
		sticky = copy.sticky,
		approved = copy.approved,
		last = if last ~= nil then lastOf(last, phone) else nil,
		dispatchLabel = if phone then "DISPATCH" else copy.dispatchLabel,
		dispatchTitle = copy.dispatchTitle,
		dispatchSteps = if phone then copy.dispatchPhone else copy.dispatchSteps,
		close = if phone then "CLOSE" else copy.close,
	}
end

return DepotBoardViewModel
```

- [ ] **Step 3: Panel, screen, scene.** `DepotBoardPanel.luau` (`props = { view: BoardView, layout: Layout, onClose: () -> () }`), desktop (2a, 1920×1080): a `COLOR.night` full-screen backdrop at 0.35 transparency; the cork board `Frame` 1580×900 centred (`COLOR.cork`, 8 px `COLOR.ink` border, `UICorner` 4) with "TONIGHT'S JOB" heading 30 cream top-left; the work order: a manila `PaperSheet` 880×740 at (190, 170) on the board with `tab = view.workOrder`, the headline (heading 34), the subline (body 22), then a `UIListLayout` of rows: each row a 1 px `COLOR.manilaDeep` top rule, the label (heading 22, 200 px column; `COLOR.inkRed` when `hazard`), the text (body 24, wrapped), the HAZARD row on a `COLOR.stamp` at 0.85 wash; the `PaperStamp` `view.approved` (44, tilt −6) at the sheet's bottom-right; a `StickyNote` `view.sticky` (300 wide, 24, tilt −3) overlapping the sheet's bottom-left. Right column: when `view.last` is present, a cream `PaperSheet` 540×400 at (1150, 200) `fastener = "clip"`, red `band = last.title`, four label/value rows (body 24 / number 32), and a `PaperStamp` `last.stamp` (30, stamp red for met and missed alike, as Figma draws it; green success stamps are deferred) at its bottom-right; below it the dispatch slip: a cream `PaperSheet` 520×200 `fastener = "pin"` with `dispatchLabel` (body 20), `dispatchTitle` (heading 52) underlined by a 6 px `COLOR.exitGreen` marker stroke (a `Frame` under the text, tilt −1), and `dispatchSteps` (body 22); a `PaperButton` secondary (cream) `view.close` 220×64 at the board's bottom-right calling `onClose`. Phone (2b, 844×390): the board fills the safe area; the work order sheet 460 wide on the left with the four rows (labels 15, text 16), the last-shift card (right top, `lines` in Oswald 17) and the dispatch slip (right middle), CLOSE (`PaperButton` secondary 150×48) bottom-right above the Jump button.

`DepotBoardScreen.luau` (the scene's screen): reads `DepotStore.board`, `DepotStore.lastShift`, `usePaperLayout()`; renders `DepotBoardPanel` with `DepotBoardViewModel.board(board, lastShift, layout == "phone")` and `onClose = function() SceneStack.remove(DepotConstants.BOARD_SCENE) end`.

`DepotScene.luau` (add `BOARD_SCENE = "depot.Board",` to `DepotConstants` first):

```lua
--!strict
--[=[
	DepotScene: registers the depot's contract board scene (Cleanup Crew M3 UI, Figma 2a/2b): the board on the Panel
	layer, the mouse freed, the HUD hidden. DepotServiceClient pushes it when the board's prompt is used; CLOSE and
	Escape take it off the stack. Declarative (registers at require).

	@class DepotScene
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DepotConstants = require(ReplicatedStorage.Shared.Features.Depot.Data.DepotConstants)
local SceneRegistry = require(ReplicatedStorage.Client.UI.Scenes.SceneRegistry)
local DepotBoardScreen = require(ReplicatedStorage.Client.UI.React.Screens.Depot.DepotBoardScreen)

if not SceneRegistry.has(DepotConstants.BOARD_SCENE) then
	SceneRegistry.register({
		name = DepotConstants.BOARD_SCENE,
		screens = { { layer = "Panel", key = "board", component = DepotBoardScreen } },
		suppress = { mouse = true },
		hud = "hidden",
	})
end

return {}
```

`DepotServiceClient`: require `DepotScene` (registration at load) and `SceneStack`; the `Board` listener becomes `DepotStore.openBoard(id)` then `SceneStack.push(DepotConstants.BOARD_SCENE)`.

`DepotBoardPanel.story.luau`: controls `Phone = false`, `LastShift = true`, `QuotaMet = true`; renders the panel from `DepotBoardViewModel.board(DepotConstants.CONTRACTS[1].id, last-or-nil, phone)` with a no-op `onClose`.

- [ ] **Step 4: `SpecRoots`** (Depot block):

```lua
	["ReplicatedStorage.Client.UI.React.Screens.Depot.DepotBoardPanel"] = "presentational React component (board specced in DepotBoardViewModel; story in DepotBoardPanel.story)",
	["ReplicatedStorage.Client.UI.React.Screens.Depot.DepotBoardScreen"] = "React scene screen wiring DepotStore to DepotBoardPanel (no logic)",
	["ReplicatedStorage.Client.UI.React.Screens.Depot.DepotScene"] = "scene registration (declarative, no logic)",
```

- [ ] **Step 5: Controller: Studio TestEZ and checks.** `DepotBoardViewModel` passes. UI Labs `DepotBoardPanel` (desktop and phone) beside Figma 2a (31:458) / 2b (31:516). Play: at the board press E on "[E] READ work order": the board opens, the mouse is free, the HUD (queue pad card, toasts) hides; CLOSE and Escape both close it. After a Back-to-depot return, the board shows "YOUR LAST SHIFT — TRUCK n" with the shift's numbers. Phone emulator: the 2b layout, CLOSE reachable, nothing under the Jump button.

- [ ] **Step 6: Gate and commit**

```bash
git add src
python3 scripts/python/module_map.py --write
git add docs/project-structure.md
stylua src/ReplicatedStorage/Client/UI/React/Screens/Depot src/ReplicatedStorage/Client/Features/Depot/DepotServiceClient.luau src/ReplicatedStorage/Shared/Features/Depot/Data/DepotConstants.luau src/ServerScriptService/Core/Testing/SpecRoots.luau
git add src
bash .superpowers/sdd/gate.sh
python3 scripts/python/check_pr_rules.py origin/main
git commit -m "feat(ui): depot contract board scene"
python3 scripts/python/module_map.py --check
```

---

### Task 13: The truck queue pad card (3a, 3b)

**Files:**
- Create (under `src/ReplicatedStorage/Client/UI/React/Screens/Depot/`): `DepotPadViewModel.luau` + `DepotPadViewModel.spec.luau`, `DepotPad.luau`, `DepotPadPanel.luau`, `DepotPadPanel.story.luau`
- Modify: `src/ReplicatedStorage/Client/Features/Depot/DepotServiceClient.luau`
- Modify: `src/ServerScriptService/Core/Testing/SpecRoots.luau`

**Interfaces:**
- Consumes: `QueueStore.snapshot`, `QueueSnapshotUtils.padOf(snapshot, userId) -> (string?, PadSnapshot?)` (`members: { number }`, `capacity`, `endsAt?`, `departing`); the public `truck` field (Task 4); `QueueServiceClient:setDefaultWidget(false)`, `QueueServiceClient:departNow()`.
- Produces: `DepotPadViewModel.SlotView = { name: string, open: boolean, you: boolean }`; `PadView = { title: string, count: string, slots: { SlotView }, names: string, departsIn: string?, departing: boolean, hint: string }`; `DepotPadViewModel.pad(pad: QueueTypes.PadSnapshot?, myId: number, names: { [number]: string }, truck: number?, now: number, phone: boolean) -> PadView?`.

- [ ] **Step 1: Failing spec** `DepotPadViewModel.spec.luau`:

```lua
local DepotPadViewModel = require(script.Parent.DepotPadViewModel)

local NAMES = { [1] = "Sam", [2] = "Alex", [3] = "Me" }

local function pad(extra)
	local value = { members = { 1, 2, 3 }, capacity = 4, destination = "shift", endsAt = 111, departing = false }
	for key, item in extra or {} do
		value[key] = item
	end
	return value
end

return function()
	it("shows nothing when not aboard", function()
		expect(DepotPadViewModel.pad(nil, 3, NAMES, 2, 100, false)).to.equal(nil)
		expect(DepotPadViewModel.pad(pad({ members = { 1 } }), 3, NAMES, 2, 100, false)).to.equal(nil)
	end)

	it("titles the card with the truck and the job", function()
		expect(DepotPadViewModel.pad(pad(), 3, NAMES, 2, 100, false).title).to.equal("TRUCK 2 — HARLOW & FINCH JOB")
		expect(DepotPadViewModel.pad(pad(), 3, NAMES, nil, 100, false).title).to.equal("HARLOW & FINCH JOB")
		expect(DepotPadViewModel.pad(pad(), 3, NAMES, 2, 100, true).title).to.equal("TRUCK 2 · CREW")
	end)

	it("counts the crew and fills open slots up to capacity, you marked", function()
		local view = DepotPadViewModel.pad(pad(), 3, NAMES, 2, 100, false)
		expect(view.count).to.equal("3 / 4")
		expect(#view.slots).to.equal(4)
		expect(view.slots[3].name).to.equal("you")
		expect(view.slots[3].you).to.equal(true)
		expect(view.slots[4].open).to.equal(true)
		expect(view.slots[4].name).to.equal("open")
	end)

	it("lists names for the phone", function()
		expect(DepotPadViewModel.pad(pad(), 3, NAMES, 2, 100, true).names).to.equal("Sam · Alex · you")
	end)

	it("counts down to departure, never below 0:00", function()
		expect(DepotPadViewModel.pad(pad(), 3, NAMES, 2, 100, false).departsIn).to.equal("0:11")
		expect(DepotPadViewModel.pad(pad({ endsAt = 90 }), 3, NAMES, 2, 100, false).departsIn).to.equal("0:00")
	end)

	it("drops the countdown while departing", function()
		local view = DepotPadViewModel.pad(pad({ endsAt = nil, departing = true }), 3, NAMES, 2, 100, false)
		expect(view.departing).to.equal(true)
		expect(view.departsIn).to.equal(nil)
	end)

	it("writes the leave hint per layout", function()
		expect(DepotPadViewModel.pad(pad(), 3, NAMES, 2, 100, false).hint)
			.to.equal("Step off the bed to leave · timer resets when someone joins")
		expect(DepotPadViewModel.pad(pad(), 3, NAMES, 2, 100, true).hint).to.equal("Step off the truck bed to leave")
	end)
end
```

Controller: Studio TestEZ: fails.

- [ ] **Step 2: Implement `DepotPadViewModel`:**

```lua
--!strict
--[=[
	DepotPadViewModel: the truck's queue card for a player standing in its bed (Figma 3a/3b): the truck and the job,
	"3 / 4" aboard, a slot per seat (you marked, empty seats "open"), the departure countdown, and how to leave. Pure.

	@class DepotPadViewModel
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DepotConstants = require(ReplicatedStorage.Shared.Features.Depot.Data.DepotConstants)
local QueueTypes = require(ReplicatedStorage.Shared.Features.Queue.Data.QueueTypes)
local ShiftHudViewModel = require(ReplicatedStorage.Client.UI.React.Screens.Shift.ShiftHudViewModel)

export type SlotView = { name: string, open: boolean, you: boolean }

export type PadView = {
	title: string,
	count: string,
	slots: { SlotView },
	names: string,
	departsIn: string?,
	departing: boolean,
	hint: string,
}

local DepotPadViewModel = {}

function DepotPadViewModel.pad(
	pad: QueueTypes.PadSnapshot?,
	myId: number,
	names: { [number]: string },
	truck: number?,
	now: number,
	phone: boolean
): PadView?
	if pad == nil or table.find(pad.members, myId) == nil then
		return nil
	end
	local slots: { SlotView } = {}
	local listed: { string } = {}
	for _, userId in pad.members do
		local name = if userId == myId then "you" else names[userId] or "Crew"
		table.insert(slots, { name = name, open = false, you = userId == myId })
		table.insert(listed, name)
	end
	for _ = #pad.members + 1, pad.capacity do
		table.insert(slots, { name = "open", open = true, you = false })
	end
	local endsAt = pad.endsAt
	local title: string
	if phone then
		title = if truck ~= nil then `TRUCK {truck} · CREW` else "CREW"
	else
		title = if truck ~= nil then `TRUCK {truck} — {DepotConstants.JOB_TITLE}` else DepotConstants.JOB_TITLE
	end
	return {
		title = title,
		count = `{#pad.members} / {pad.capacity}`,
		slots = slots,
		names = table.concat(listed, " · "),
		departsIn = if not pad.departing and endsAt ~= nil then ShiftHudViewModel.clock(endsAt - now) else nil,
		departing = pad.departing,
		hint = if phone
			then "Step off the truck bed to leave"
			else "Step off the bed to leave · timer resets when someone joins",
	}
end

return DepotPadViewModel
```

- [ ] **Step 3: Components.** `DepotPadPanel.luau` (`props = { view: PadView, layout: Layout, onDepart: () -> () }`): desktop (3a): a cream `PaperSheet` 760×256 bottom-centre at y 776 with a red `band = view.title`; "CREW" body 20, `view.count` number 64; four 80×80 slot cards (`COLOR.office` filled with the name in body 16 cream; an open seat dashed outline, `COLOR.slotEmpty` "open"; yours with the name in `COLOR.sticky`); "DEPARTS IN" body 20 and `view.departsIn` timer 56 at the right (when departing: the `PaperStamp` "LEAVING" 30 instead); a `PaperButton` go "DEPART NOW" 226×76 (disabled while `departing`) and the hint body 20. Phone (3b): a cream strip across the top safe area (234..844-48, y 12): "TRUCK 2 · CREW" 15, count 40, names 14, "DEPARTS IN" 15 + timer 36 at the right; DEPART NOW `PaperButton` go 240×56 at (540, 300) above the Jump button with the hint 14 above it.

`DepotPad.luau` (HUD widget):

```lua
export type DepotPadProps = {
	onDepart: () -> (),
}

local function DepotPad(props: DepotPadProps): React.ReactNode
	local snapshot = ReactCharm.useAtom(QueueStore.snapshot)
	local publicPlayers = ReactCharm.useAtom(StateSyncClientStore.publicPlayers)
	local layout = usePaperLayout()
	local now = useServerClock(0.2)
	local player = Players.LocalPlayer
	local _, pad = QueueSnapshotUtils.padOf(snapshot, player.UserId)
	if pad == nil then
		return nil
	end
	local names: { [number]: string } = {}
	for _, userId in pad.members do
		local member = Players:GetPlayerByUserId(userId)
		if member ~= nil then
			names[userId] = member.DisplayName
		end
	end
	local me = publicPlayers[StateSyncConstants.publicEntryKey(player.UserId)]
	local truck = if me ~= nil then me[DepotConstants.PUBLIC_TRUCK] else nil
	local view = DepotPadViewModel.pad(pad, player.UserId, names, if type(truck) == "number" then truck else nil, now, layout == "phone")
	if view == nil then
		return nil
	end
	return React.createElement(DepotPadPanel, { view = view, layout = layout, onDepart = props.onDepart })
end
```

`DepotServiceClient.init` (add `"QueueServiceClient"` to `dependencies`):

```lua
		QueueServiceClient:setDefaultWidget(false)
		if not HudRegistry.has("depotPad") then
			HudRegistry.register("depotPad", function()
				return React.createElement(DepotPad, {
					onDepart = function()
						QueueServiceClient:departNow()
					end,
				})
			end, DepotConstants.HUD_ORDER - 1)
		end
```

(`QueueServiceClient`'s own registration of its widget stays; `setDefaultWidget(false)` makes it render nothing, exactly as its header intends.)

`DepotPadPanel.story.luau`: controls `Aboard = 3`, `SecondsLeft = 11`, `Departing = false`, `Phone = false`.

- [ ] **Step 4: `SpecRoots`** (Depot block):

```lua
	["ReplicatedStorage.Client.UI.React.Screens.Depot.DepotPad"] = "React HUD widget wiring QueueStore to DepotPadPanel (card specced in DepotPadViewModel)",
	["ReplicatedStorage.Client.UI.React.Screens.Depot.DepotPadPanel"] = "presentational React component (story in DepotPadPanel.story)",
```

- [ ] **Step 5: Controller: Studio TestEZ and checks.** `DepotPadViewModel` passes; UI Labs `DepotPadPanel` beside 3a (22:183) / 3b (22:217). Play: stand in truck 2's bed: the card reads "TRUCK 2 — HARLOW & FINCH JOB", "1 / 4", your slot, the countdown; DEPART NOW departs; stepping off removes the card; the base placeholder pad panel never shows.

- [ ] **Step 6: Gate and commit**

```bash
git add src
python3 scripts/python/module_map.py --write
git add docs/project-structure.md
stylua src/ReplicatedStorage/Client/UI/React/Screens/Depot src/ReplicatedStorage/Client/Features/Depot/DepotServiceClient.luau src/ServerScriptService/Core/Testing/SpecRoots.luau
git add src
bash .superpowers/sdd/gate.sh
python3 scripts/python/check_pr_rules.py origin/main
git commit -m "feat(ui): truck queue pad card"
python3 scripts/python/module_map.py --check
```

---

### Task 14: The catch: scare beat, CCTV spectating, the Rehired card (4a-4e)

The scare beat already hides the HUD and the toasts (Tasks 8, 9, 11). This task adds the CCTV overlay while caught and the HR Rehired card around the respawn.

**Files:**
- Create (under `src/ReplicatedStorage/Client/UI/React/Screens/Catch/`): `CatchViewModel.luau` + `CatchViewModel.spec.luau`, `CatchOverlay.luau`, `CatchCctvPanel.luau`, `CatchCctvPanel.story.luau`, `CatchRehiredCard.luau`, `CatchRehiredPanel.luau`, `CatchRehiredPanel.story.luau`, `useSpectateTarget.luau`
- Modify: `src/ReplicatedStorage/Shared/Features/Shift/Data/ShiftConstants.luau` (night clock)
- Modify: `src/ReplicatedStorage/Client/Features/Occupant/OccupantServiceClient.luau` (registers the two widgets)
- Modify: `src/ServerScriptService/Core/Testing/SpecRoots.luau`

**Interfaces:**
- Consumes: `OccupantCatchStore.report / rehiredAt` (Task 5); the public `dead`, `caughtUntil`, `carrying`, `room`, `roomDepth`, `cam` fields; `DeathServiceClient:spectating() -> number?`; `DeathServiceClient:cycleSpectate(direction)` (B1, if approved); `InputServiceClient:bindingsFor(DeathConstants.SPECTATE_PREV / SPECTATE_NEXT)`; `ShiftHudViewModel.clock / keyName`.
- Produces:
  - `ShiftConstants.NIGHT_CLOCK_START = 3 * 3600`, `ShiftConstants.NIGHT_DAY = "THU"`.
  - `CatchViewModel.CctvInput = { snapshot: ShiftSnapshot?, me: PublicPlayer?, report: CatchReport?, targetName: string?, target: PublicPlayer?, now: number, prevKey: string, nextKey: string, phone: boolean }`; `CctvView = { rec: string, watching: string, details: string, stamp: string, back: string, incidentTitle: string, incident: { string }, prevKey: string, nextKey: string }`; `CatchViewModel.cctv(input: CctvInput) -> CctvView?`; `CatchViewModel.roomPhrase(room: string) -> string`; `CatchViewModel.nightClock(elapsed: number) -> string`.
  - `CatchViewModel.RehiredInput = { report: CatchReport?, me: PublicPlayer?, name: string, rehiredAt: number?, nowServer: number, nowClock: number, phone: boolean }`; `RehiredView = { header: string, notice: string, title: string, rows: { string }, stamp: string, footer: string }`; `CatchViewModel.rehired(input: RehiredInput) -> RehiredView?`.
  - `useSpectateTarget() -> number?` (polled every 0.2 s).

- [ ] **Step 1: Failing spec** `CatchViewModel.spec.luau`:

```lua
local CatchViewModel = require(script.Parent.CatchViewModel)

local REPORT = { room = "Archive", clock = 222, backAt = 108, dropped = { "Monitor", "Employee of the Month plaque" } }

local function snapshot(extra)
	local value = { phase = "running", sub = "normal", stage = "normal", tier = 0, shift = 1, endsAt = 352, quota = 350, cleared = 0, bonus = 0, quotaMet = false, variant = "B", votesAnother = 0, votesDepot = 0, crew = {} }
	for key, item in extra or {} do
		value[key] = item
	end
	return value
end

local function input(extra)
	local value = {
		snapshot = snapshot(),
		me = { dead = true, caughtUntil = 106 },
		report = REPORT,
		targetName = "Sam",
		target = { carrying = "printer", room = "Server room", roomDepth = 2, cam = 6 },
		now = 100,
		prevKey = "←",
		nextKey = "→",
		phone = false,
	}
	for key, item in extra or {} do
		value[key] = item
	end
	return value
end

return function()
	describe("cctv", function()
		it("shows only while the local player is down in a running shift", function()
			expect(CatchViewModel.cctv(input({ me = { caughtUntil = 106 } }))).to.equal(nil)
			expect(CatchViewModel.cctv(input({ snapshot = snapshot({ phase = "results" }) }))).to.equal(nil)
			expect(CatchViewModel.cctv(input()) ~= nil).to.equal(true)
		end)

		it("labels the camera, the room and who is watched", function()
			local view = CatchViewModel.cctv(input())
			expect(view.rec).to.equal("REC   CAM 06 · SERVER ROOM")
			expect(view.watching).to.equal("WATCHING  SAM")
			expect(view.details).to.equal("carrying: Printer · 2 rooms from the truck")
		end)

		it("says one room, and the loading bay, in words", function()
			local near = CatchViewModel.cctv(input({ target = { roomDepth = 1, room = "Reception", cam = 2 } }))
			expect(near.details).to.equal("hands empty · 1 room from the truck")
			local bay = CatchViewModel.cctv(input({ target = { roomDepth = 0, room = "Loading bay", cam = 1 } }))
			expect(bay.details).to.equal("hands empty · at the truck")
		end)

		it("reads NO SIGNAL with nobody to watch", function()
			local value = input()
			value.targetName = nil
			value.target = nil
			local view = CatchViewModel.cctv(value)
			expect(view.watching).to.equal("NO SIGNAL")
			expect(view.rec).to.equal("REC   CAM -- · NO SIGNAL")
		end)

		it("counts down to the respawn and never below 0:00", function()
			expect(CatchViewModel.cctv(input()).back).to.equal("BACK ON THE CLOCK IN 0:06")
			expect(CatchViewModel.cctv(input({ now = 120 })).back).to.equal("BACK ON THE CLOCK IN 0:00")
		end)

		it("stamps a night clock from the time into the shift", function()
			-- endsAt 352, now 100: 252 s left of 420, so 168 s in: 03:02:48.
			expect(CatchViewModel.cctv(input()).stamp).to.equal("THU 03:02:48")
			expect(CatchViewModel.nightClock(3600)).to.equal("04:00:00")
		end)

		it("writes the incident report with the clock and the room", function()
			local view = CatchViewModel.cctv(input())
			expect(view.incidentTitle).to.equal("INCIDENT REPORT · YOU")
			expect(view.incident[1]).to.equal("Caught by Mr. Harlow at 3:42.")
			expect(view.incident[2]).to.equal("Your cargo dropped in the archive.")
		end)

		it("says nothing dropped for empty hands, and keeps the phone short", function()
			local empty = table.clone(REPORT)
			empty.dropped = {}
			expect(CatchViewModel.cctv(input({ report = empty })).incident[2]).to.equal("You were carrying nothing.")
			local phone = CatchViewModel.cctv(input({ phone = true }))
			expect(phone.incidentTitle).to.equal("INCIDENT REPORT")
			expect(phone.incident[1]).to.equal("Caught by Mr. Harlow.")
			expect(phone.details).to.equal("carrying: Printer")
		end)

		it("phrases a possessive room without 'the'", function()
			expect(CatchViewModel.roomPhrase("Mr. Harlow's office")).to.equal("Mr. Harlow's office")
			expect(CatchViewModel.roomPhrase("Break room")).to.equal("the break room")
		end)
	end)

	describe("rehired", function()
		local function rehiredInput(extra)
			local value = { report = REPORT, me = { dead = true, caughtUntil = 106 }, name = "Ava", rehiredAt = nil, nowServer = 105, nowClock = 50, phone = false }
			for key, item in extra or {} do
				value[key] = item
			end
			return value
		end

		it("shows from just before the respawn until a few seconds after it", function()
			expect(CatchViewModel.rehired(rehiredInput({ nowServer = 100 }))).to.equal(nil)
			expect(CatchViewModel.rehired(rehiredInput()) ~= nil).to.equal(true)
			local after = rehiredInput({ me = {}, rehiredAt = 49 })
			expect(CatchViewModel.rehired(after) ~= nil).to.equal(true)
			after.nowClock = 53
			expect(CatchViewModel.rehired(after)).to.equal(nil)
		end)

		it("needs a report", function()
			local value = rehiredInput()
			value.report = nil
			expect(CatchViewModel.rehired(value)).to.equal(nil)
		end)

		it("fills the HR notice", function()
			local view = CatchViewModel.rehired(rehiredInput())
			expect(view.title).to.equal("Rehired.")
			expect(view.rows[1]).to.equal("Name: Ava")
			expect(view.rows[2]).to.equal("Employment ended: 3:42 (caught by Mr. Harlow)")
			expect(view.rows[3]).to.equal("Re-hired: 3:34, no questions asked")
			expect(view.rows[4]).to.equal("Dropped: Monitor, Employee of the Month plaque. Go back for them!")
			expect(view.stamp).to.equal("REHIRED")
			expect(view.footer).to.equal("Respawning at the loading bay…")
		end)

		it("says nothing was dropped", function()
			local empty = table.clone(REPORT)
			empty.dropped = {}
			expect(CatchViewModel.rehired(rehiredInput({ report = empty })).rows[4]).to.equal("Dropped: nothing.")
		end)
	end)
end
```

(Re-hired = the shift clock at the respawn = `report.clock - SPECTATE_SECONDS` = 222 − 8 = 214 s = "3:34".) Controller: Studio TestEZ: fails.

- [ ] **Step 2: Implement `CatchViewModel`.** `ShiftConstants` gains (frozen table) `-- The CCTV's fictional night clock (Figma 4b "THU 03:44:12"): 03:00:00 at the shift's start. NIGHT_CLOCK_START = 3 * 3600, NIGHT_DAY = "THU",`.

```lua
--!strict
--[=[
	CatchViewModel: the catch's screens (Figma 4b/4d CCTV, 4c/4e Rehired card). `cctv`: while the local player is down
	in a running shift, the feed of the teammate Death is spectating (camera number, room, what they carry, rooms from
	the truck), a fictional night clock, the respawn countdown and the incident report. `rehired`: the HR notice from
	REHIRED_LEAD seconds before the respawn until REHIRED_HOLD seconds after it. Pure.

	@class CatchViewModel
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PublicPlayerTypes = require(ReplicatedStorage.Shared.Data.PublicPlayerTypes)
local CargoRegistry = require(ReplicatedStorage.Shared.Features.Cargo.Data.CargoRegistry)
local CarryConstants = require(ReplicatedStorage.Shared.Features.Carry.Data.CarryConstants)
local DeathConstants = require(ReplicatedStorage.Shared.Features.Death.Data.DeathConstants)
local OccupantConstants = require(ReplicatedStorage.Shared.Features.Occupant.Data.OccupantConstants)
local OccupantTypes = require(ReplicatedStorage.Shared.Features.Occupant.Data.OccupantTypes)
local ShiftConstants = require(ReplicatedStorage.Shared.Features.Shift.Data.ShiftConstants)
local ShiftTypes = require(ReplicatedStorage.Shared.Features.Shift.Data.ShiftTypes)
local ShiftHudViewModel = require(ReplicatedStorage.Client.UI.React.Screens.Shift.ShiftHudViewModel)

type PublicPlayer = PublicPlayerTypes.PublicPlayer

export type CctvInput = {
	snapshot: ShiftTypes.ShiftSnapshot?,
	me: PublicPlayer?,
	report: OccupantTypes.CatchReport?,
	targetName: string?,
	target: PublicPlayer?,
	now: number,
	prevKey: string,
	nextKey: string,
	phone: boolean,
}

export type CctvView = {
	rec: string,
	watching: string,
	details: string,
	stamp: string,
	back: string,
	incidentTitle: string,
	incident: { string },
	prevKey: string,
	nextKey: string,
}

export type RehiredInput = {
	report: OccupantTypes.CatchReport?,
	me: PublicPlayer?,
	name: string,
	rehiredAt: number?,
	nowServer: number,
	nowClock: number,
	phone: boolean,
}

export type RehiredView = {
	header: string,
	notice: string,
	title: string,
	rows: { string },
	stamp: string,
	footer: string,
}

local CatchViewModel = {}

-- "the archive", but "Mr. Harlow's office" (a possessive name takes no article).
function CatchViewModel.roomPhrase(room: string): string
	if string.find(room, "'s ", 1, true) ~= nil then
		return room
	end
	return `the {string.lower(room)}`
end

-- "03:02:48": NIGHT_CLOCK_START plus `elapsed` seconds, on a 24-hour clock.
function CatchViewModel.nightClock(elapsed: number): string
	local total = (ShiftConstants.NIGHT_CLOCK_START + math.max(0, math.floor(elapsed))) % 86400
	return string.format("%02d:%02d:%02d", total // 3600, (total // 60) % 60, total % 60)
end

local function depthText(depth: PublicPlayerTypes.PublicValue?): string?
	if type(depth) ~= "number" then
		return nil
	elseif depth <= 0 then
		return "at the truck"
	elseif depth == 1 then
		return "1 room from the truck"
	end
	return `{depth} rooms from the truck`
end

function CatchViewModel.cctv(input: CctvInput): CctvView?
	local snapshot = input.snapshot
	local me = input.me
	if snapshot == nil or snapshot.phase ~= "running" or me == nil or me[DeathConstants.PUBLIC_FIELD] ~= true then
		return nil
	end
	local target, name = input.target, input.targetName
	local rec, watching, details = "REC   CAM -- · NO SIGNAL", "NO SIGNAL", "Nobody to watch."
	if target ~= nil and name ~= nil then
		local cam, room = target[ShiftConstants.PUBLIC_CAM], target[ShiftConstants.PUBLIC_ROOM]
		rec = `REC   CAM {if type(cam) == "number" then string.format("%02d", cam) else "--"} · {if type(room) == "string" then string.upper(room) else "UNKNOWN"}`
		watching = `WATCHING  {string.upper(name)}`
		local kind = target[CarryConstants.PUBLIC_FIELD]
		local def = if type(kind) == "string" then CargoRegistry.get(kind) else nil
		local carried = if def ~= nil then `carrying: {def.name}` else "hands empty"
		local depth = depthText(target[ShiftConstants.PUBLIC_ROOM_DEPTH])
		details = if input.phone or depth == nil then carried else `{carried} · {depth}`
	end
	local endsAt = snapshot.endsAt
	local elapsed = ShiftConstants.SHIFT_SECONDS - (if endsAt ~= nil then endsAt - input.now else 0)
	local report = input.report
	local caughtUntil = me[OccupantConstants.PUBLIC_CAUGHT_UNTIL]
	local backAt = if type(caughtUntil) == "number" then caughtUntil elseif report ~= nil then report.backAt else input.now
	local incident: { string } = {}
	if report ~= nil then
		local lost = #report.dropped > 0
		if input.phone then
			table.insert(incident, "Caught by Mr. Harlow.")
			table.insert(incident, if lost then `Cargo dropped in {CatchViewModel.roomPhrase(report.room)}.` else "Nothing dropped.")
		else
			table.insert(incident, `Caught by Mr. Harlow at {ShiftHudViewModel.clock(report.clock)}.`)
			table.insert(
				incident,
				if lost then `Your cargo dropped in {CatchViewModel.roomPhrase(report.room)}.` else "You were carrying nothing."
			)
		end
	end
	return {
		rec = rec,
		watching = watching,
		details = details,
		stamp = `{ShiftConstants.NIGHT_DAY} {CatchViewModel.nightClock(elapsed)}`,
		back = `BACK ON THE CLOCK IN {ShiftHudViewModel.clock(backAt - input.now)}`,
		incidentTitle = if input.phone then "INCIDENT REPORT" else "INCIDENT REPORT · YOU",
		incident = incident,
		prevKey = input.prevKey,
		nextKey = input.nextKey,
	}
end

function CatchViewModel.rehired(input: RehiredInput): RehiredView?
	local report = input.report
	if report == nil then
		return nil
	end
	local me = input.me or {}
	local caughtUntil = me[OccupantConstants.PUBLIC_CAUGHT_UNTIL]
	local rehiredAt = input.rehiredAt
	local before = type(caughtUntil) == "number" and caughtUntil - input.nowServer <= OccupantConstants.REHIRED_LEAD
	local after = rehiredAt ~= nil and input.nowClock - rehiredAt <= OccupantConstants.REHIRED_HOLD
	if not before and not after then
		return nil
	end
	local ended = ShiftHudViewModel.clock(report.clock)
	local back = ShiftHudViewModel.clock(report.clock - OccupantConstants.SPECTATE_SECONDS)
	local dropped = if #report.dropped > 0
		then `Dropped: {table.concat(report.dropped, ", ")}. Go back for them!`
		else "Dropped: nothing."
	local rows: { string } = if input.phone
		then { `Caught at {ended} by Mr. Harlow`, dropped }
		else {
			`Name: {input.name}`,
			`Employment ended: {ended} (caught by Mr. Harlow)`,
			`Re-hired: {back}, no questions asked`,
			dropped,
		}
	return {
		header = "HARLOW & FINCH — HUMAN RESOURCES",
		notice = "NOTICE OF RE-EMPLOYMENT",
		title = OccupantConstants.REHIRED_TEXT,
		rows = rows,
		stamp = "REHIRED",
		footer = "Respawning at the loading bay…",
	}
end

return CatchViewModel
```

- [ ] **Step 3: Components.** `useSpectateTarget.luau`: a `useState` + `useEffect` loop (the `QueuePadStatus` pattern) that reads `DeathServiceClient:spectating()` every 0.2 s and sets state only when it changed; returns `number?`.

`CatchCctvPanel.luau` (`props = { view: CctvView, layout: Layout, onPrev: (() -> ())?, onNext: (() -> ())? }`), desktop (4b): a full-screen `Frame` — scanlines as a tiled `ImageLabel` from `UIAssets.paper.scanlines` when that slot is set, else a `COLOR.night` wash at 0.88 transparency (flat fallback); four corner brackets (each two 3 px `COLOR.fluorescent` frames, 60 px arms, 60 px in from the edges); a 14 px red REC dot + `view.rec` (timer 24, `COLOR.fluorescent`) at (96, 104); `view.watching` (heading 48) at (96, 140); `view.details` (body 22) at (96, 206); `view.stamp` (timer 24) right-aligned at y 104; `view.back` (timer 28) centred at y 930; below it the key chips: `KeyChip(view.prevKey)` "previous" and `KeyChip(view.nextKey)` "next teammate" (body 22); the incident report: a cream `PaperSheet` 440×120 at (1408, 863) with a red band `view.incidentTitle` (20), tilt −2, the lines (body 20). Phone (4d): REC/stamp 14 at (78, 70) / right, watching 26, details 14, back 16 at the bottom centre, the incident slip 260 wide top-right (540, 96) with 12/14 text, and — only when `onPrev` / `onNext` are given (B1 approved) — two 48×48 round ‹ / › `TextButton`s at the vertical centre (78, 214) and (754, 214).

`CatchOverlay.luau` (HUD widget):

```lua
local function CatchOverlay(): React.ReactNode
	local snapshot = useAtom(ShiftStore.snapshot)
	local publicPlayers = useAtom(StateSyncClientStore.publicPlayers)
	local report = useAtom(OccupantCatchStore.report)
	local layout = usePaperLayout()
	local now = useServerClock()
	local targetId = useSpectateTarget()
	local player = Players.LocalPlayer
	local me = publicPlayers[StateSyncConstants.publicEntryKey(player.UserId)]
	local target = if targetId ~= nil then publicPlayers[StateSyncConstants.publicEntryKey(targetId)] else nil
	local targetPlayer = if targetId ~= nil then Players:GetPlayerByUserId(targetId) else nil
	local view = CatchViewModel.cctv({
		snapshot = snapshot,
		me = me,
		report = report,
		targetName = if targetPlayer ~= nil then targetPlayer.DisplayName else nil,
		target = target,
		now = now,
		prevKey = keyFor(DeathConstants.SPECTATE_PREV, "←"),
		nextKey = keyFor(DeathConstants.SPECTATE_NEXT, "→"),
		phone = layout == "phone",
	})
	if view == nil then
		return nil
	end
	return e(CatchCctvPanel, {
		view = view,
		layout = layout,
		-- B1 (DeathServiceClient:cycleSpectate) approved: phone arrows. Declined: pass nil for both.
		onPrev = function()
			DeathServiceClient:cycleSpectate(-1)
		end,
		onNext = function()
			DeathServiceClient:cycleSpectate(1)
		end,
	})
end
```

with `keyFor(action, fallback)` reading `InputServiceClient:bindingsFor(action)`'s first keyboard binding through `ShiftHudViewModel.keyName` (fallback when none).

`CatchRehiredPanel.luau` (`props = { view: RehiredView, layout: Layout }`): desktop (4c): a `COLOR.night` full-screen wash at 0.2; a cream `PaperSheet` 700×600 centred, `fastener = "clip"`; `header` heading 22 with a 2 px ink rule, `notice` body 22, `title` body (Special Elite) 104, the rows body 22 at 44 px spacing, a `PaperStamp` `stamp` 60 (tilt −8) at the sheet's right, `footer` body 20 at the bottom. Phone (4e): the sheet 420×330 centred, sizes 14/15/56/30/14. `CatchRehiredCard.luau` (HUD widget): reads `OccupantCatchStore.report`, `OccupantCatchStore.rehiredAt`, the local public entry, `usePaperLayout()`, `useServerClock()` and a local `os.clock()` sampled each render; `CatchViewModel.rehired({...})`; nil → nothing.

Register both in `OccupantServiceClient` (new `init`, typed in the service's export type):

```lua
	init = function(_self)
		if not HudRegistry.has("catchOverlay") then
			HudRegistry.register("catchOverlay", CatchOverlay, ShiftConstants.HUD_ORDER + 5)
		end
		if not HudRegistry.has("catchRehired") then
			HudRegistry.register("catchRehired", CatchRehiredCard, ShiftConstants.HUD_ORDER + 6)
		end
	end,
```

Stories: `CatchCctvPanel.story.luau` (controls `Phone`, `Target = UILabs.Choose({ "Sam carrying", "no signal" })`, `Dropped = true`) and `CatchRehiredPanel.story.luau` (controls `Phone`, `Dropped`), both built from `CatchViewModel` with fixture inputs. Harlow's face for 4a is the existing billboard grin (`OccupantScareSystem`); its art slot stays PENDING in `OccupantAssets`: nothing to build in React for 4a beyond the hidden HUD.

- [ ] **Step 4: `SpecRoots`** (a new `-- Cleanup Crew: catch screens (M3 UI)` block):

```lua
	["ReplicatedStorage.Client.UI.React.Screens.Catch.CatchOverlay"] = "React HUD widget (CCTV lines specced in CatchViewModel)",
	["ReplicatedStorage.Client.UI.React.Screens.Catch.CatchCctvPanel"] = "presentational React component (story in CatchCctvPanel.story)",
	["ReplicatedStorage.Client.UI.React.Screens.Catch.CatchRehiredCard"] = "React HUD widget (notice specced in CatchViewModel)",
	["ReplicatedStorage.Client.UI.React.Screens.Catch.CatchRehiredPanel"] = "presentational React component (story in CatchRehiredPanel.story)",
	["ReplicatedStorage.Client.UI.React.Screens.Catch.useSpectateTarget"] = "React hook polling DeathServiceClient:spectating() (no logic)",
```

- [ ] **Step 5: Controller: Studio TestEZ and checks.** `CatchViewModel` passes. UI Labs stories beside 4b (22:249), 4d (22:285), 4c (22:263), 4e (22:299). Play solo (`RunTests = false`): get caught: 0.6 s of only Harlow's face (no HUD, no text, no toasts), "You're FIRED!" with the throw, then the CCTV overlay ("NO SIGNAL" solo: nobody to watch) with the incident report naming your room and cargo, "BACK ON THE CLOCK IN" counting down; at ≤ 1.5 s the Rehired card appears and stays ~3 s after you respawn in the loading bay; then the HUD is back. 3-client local server (Studio → Test → Clients and Servers, 3 players): the caught player watches a teammate ("WATCHING <NAME>", their carry, room and camera); ← / → switch; the others' roster shows "CAUGHT · back 0:0n" struck through with the marker X. Phone emulator (B1 approved): ‹ / › switch teammates.

- [ ] **Step 6: Gate and commit**

```bash
git add src
python3 scripts/python/module_map.py --write
git add docs/project-structure.md
stylua src/ReplicatedStorage/Client/UI/React/Screens/Catch src/ReplicatedStorage/Client/Features/Occupant/OccupantServiceClient.luau src/ReplicatedStorage/Shared/Features/Shift/Data/ShiftConstants.luau src/ServerScriptService/Core/Testing/SpecRoots.luau
git add src
bash .superpowers/sdd/gate.sh
python3 scripts/python/check_pr_rules.py origin/main
git commit -m "feat(ui): CCTV spectating and the Rehired card"
python3 scripts/python/module_map.py --check
```

---

### Task 15: The performance review scene (5a, 5b, 5c)

**Files:**
- Create (under `src/ReplicatedStorage/Client/UI/React/Screens/Shift/`): `ShiftReviewViewModel.luau` + `ShiftReviewViewModel.spec.luau`, `ShiftReviewScreen.luau`, `ShiftReviewPanel.luau`, `ShiftReviewPanel.story.luau`, `ShiftReviewTab.luau`, `ShiftScene.luau`
- Delete: `.../Shift/ShiftResults.luau`, `.../Shift/ShiftResultsPanel.luau`, `.../Shift/ShiftResultsPanel.story.luau`
- Modify: `.../Shift/ShiftHudViewModel.luau` + spec (remove `results`, `ResultsView`, `OUTCOME_TEXT` and the `results` spec block)
- Modify: `src/ReplicatedStorage/Shared/Features/Shift/Data/ShiftConstants.luau` (review quotes, scene name)
- Modify: `src/ReplicatedStorage/Client/Features/Shift/ShiftServiceClient.luau`
- Modify: `src/ServerScriptService/Core/Testing/SpecRoots.luau`

**Interfaces:**
- Consumes: `ShiftStore.snapshot` (`results` with `rating`, `offered`, awards with `userId` / `detail`; `votesAnother`, `votesDepot`, `voteEndsAt`, `crew`, `truck`), `ShiftStore.myVote`; `ShiftConstants.RATING_TEXT`; `DepotConstants.CONTRACTS[1].client`, `SITE`; `SceneRegistry`, `SceneStack`, `UIStore.sceneStack`.
- Produces:
  - `ShiftConstants.REVIEW_QUOTES = { met = { line, by }, missed = { line, by } }`, `ShiftConstants.REVIEW_SCENE = "shift.Review"`.
  - `ShiftReviewViewModel.RowView = { label: string, value: string }`; `AwardView = { title: string, line: string }`; `VoteView = { label: string, count: number, total: number, mine: boolean, text: string }`; `ReviewView = { tab: string, subtitle: string, headline: string, met: boolean, rows: { RowView }, ratingLabel: string, rating: string, quote: string, quoteBy: string, awards: { AwardView }, moreAwards: string?, voteTitle: string, another: VoteView, depot: VoteView, footer: string }`; `ShiftReviewViewModel.review(snapshot: ShiftSnapshot?, myVote: string?, myUserId: number, now: number, phone: boolean) -> ReviewView?`.
  - The `shift.Review` scene (Panel layer, `suppress = { mouse = true }`, `hud = "hidden"`), pushed when results begin and removed when they end; `ShiftReviewTab` HUD widget.

- [ ] **Step 1: Failing spec** `ShiftReviewViewModel.spec.luau`:

```lua
local ShiftReviewViewModel = require(script.Parent.ShiftReviewViewModel)

local function review(extra)
	local value = {
		outcome = "clockout", quota = 350, cleared = 362, bonus = 215, salvage = 6, piles = 12, catches = 3,
		offered = 9, rating = "satisfactory", quotaMet = true,
		crew = {},
		awards = {
			{ title = "EMPLOYEE OF THE NIGHT", name = "Sam", userId = 1, detail = "hauled 140" },
			{ title = "MOST REHIRED", name = "Alex", userId = 2, detail = "caught twice" },
			{ title = "BUTTERFINGERS", name = "Jo", userId = 3, detail = "dropped the fish tank" },
			{ title = "QUIETEST FEET", name = "Me", userId = 4, detail = "never heard once" },
		},
	}
	for key, item in extra or {} do
		value[key] = item
	end
	return value
end

local function snapshot(extra, results)
	local value = {
		phase = "results", sub = "normal", stage = "normal", tier = 0, shift = 1, quota = 350, cleared = 362, bonus = 215,
		quotaMet = true, variant = "B", votesAnother = 2, votesDepot = 1, voteEndsAt = 120, crew = { 1, 2, 3 }, truck = 2,
		results = results or review(),
	}
	for key, item in extra or {} do
		value[key] = item
	end
	return value
end

return function()
	it("shows nothing outside results or without a review", function()
		expect(ShiftReviewViewModel.review(snapshot({ phase = "running" }), nil, 4, 100, false)).to.equal(nil)
		local bare = snapshot()
		bare.results = nil
		expect(ShiftReviewViewModel.review(bare, nil, 4, 100, false)).to.equal(nil)
	end)

	it("stamps QUOTA MET and lists the four rows", function()
		local view = ShiftReviewViewModel.review(snapshot(), nil, 4, 100, false)
		expect(view.headline).to.equal("QUOTA MET")
		expect(view.met).to.equal(true)
		expect(view.subtitle).to.equal("Crew of Truck 2 · Harlow & Finch Ltd. · 4th floor offices")
		expect(view.rows[1].label).to.equal("CLEARED")
		expect(view.rows[1].value).to.equal("362 / 350")
		expect(view.rows[2].value).to.equal("+215")
		expect(view.rows[3].value).to.equal("3")
		expect(view.rows[4].value).to.equal("6 of 9")
		expect(view.rating).to.equal("SATISFACTORY")
		expect(view.quote).to.equal("\"Those were COMPANY ASSETS.\"")
	end)

	it("stamps QUOTA MISSED with the banked fee and HR's line", function()
		local view = ShiftReviewViewModel.review(snapshot({}, review({ quotaMet = false, rating = "needsImprovement" })), nil, 4, 100, false)
		expect(view.headline).to.equal("QUOTA MISSED")
		expect(view.rows[2].label).to.equal("FINDER'S FEE (banked)")
		expect(view.rating).to.equal("NEEDS IMPROVEMENT")
		expect(view.quoteBy).to.equal("— Harlow & Finch, Human Resources")
	end)

	it("calls an award yours by userId, not by name", function()
		local results = review()
		results.awards[1].name = "Me" -- a teammate with your display name
		local view = ShiftReviewViewModel.review(snapshot({}, results), nil, 4, 100, false)
		expect(view.awards[1].line).to.equal("Me — hauled 140")
		expect(view.awards[4].line).to.equal("you — never heard once")
	end)

	it("counts the votes against the crew and marks yours", function()
		local view = ShiftReviewViewModel.review(snapshot(), "another", 4, 100, false)
		expect(view.another.count).to.equal(2)
		expect(view.another.total).to.equal(3)
		expect(view.another.mine).to.equal(true)
		expect(view.depot.mine).to.equal(false)
		expect(view.footer).to.equal("Majority decides · auto-picks in 0:20 · a tie means Another shift")
	end)

	it("writes the phone's vote lines and folds the extra awards", function()
		local view = ShiftReviewViewModel.review(snapshot(), "another", 4, 100, true)
		expect(view.another.text).to.equal("ANOTHER SHIFT  2/3 ✓")
		expect(view.depot.text).to.equal("BACK TO DEPOT  1/3")
		expect(#view.awards).to.equal(2)
		expect(view.moreAwards).to.equal("+2 MORE AWARDS ›")
		expect(view.tab).to.equal("PERFORMANCE REVIEW")
	end)

	it("never counts the vote timer below 0:00 and drops the truck when unknown", function()
		local value = snapshot({ voteEndsAt = 90 })
		value.truck = nil -- (a nil in the extras table would be skipped by the loop)
		local view = ShiftReviewViewModel.review(value, nil, 4, 100, false)
		expect(view.footer).to.equal("Majority decides · auto-picks in 0:00 · a tie means Another shift")
		expect(view.subtitle).to.equal("Crew · Harlow & Finch Ltd. · 4th floor offices")
	end)
end
```

Controller: Studio TestEZ: fails.

- [ ] **Step 2: Implement.** `ShiftConstants` (above the table, then frozen in):

```lua
-- The review's closing line (Figma 5a met / 5c missed).
local REVIEW_QUOTES = {
	met = { line = "\"Those were COMPANY ASSETS.\"", by = "— H. Harlow, Manager" },
	missed = { line = "\"We will discuss this on Monday.\"", by = "— Harlow & Finch, Human Resources" },
}
```

and `REVIEW_QUOTES = table.freeze(REVIEW_QUOTES), REVIEW_SCENE = "shift.Review",` in the table.

`ShiftReviewViewModel.luau`:

```lua
--!strict
--[=[
	ShiftReviewViewModel: the performance review (Figma 5a met, 5c missed, 5b phone): the QUOTA MET / MISSED headline
	stamp, the four rows, the rating stamp and Harlow's (or HR's) closing line, the joke awards ("you" by userId), and
	the crew vote (counts against the crew, your vote marked, the auto-pick countdown). Pure.

	@class ShiftReviewViewModel
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DepotConstants = require(ReplicatedStorage.Shared.Features.Depot.Data.DepotConstants)
local ShiftConstants = require(ReplicatedStorage.Shared.Features.Shift.Data.ShiftConstants)
local ShiftTypes = require(ReplicatedStorage.Shared.Features.Shift.Data.ShiftTypes)
local ShiftHudViewModel = require(ReplicatedStorage.Client.UI.React.Screens.Shift.ShiftHudViewModel)

export type RowView = { label: string, value: string }
export type AwardView = { title: string, line: string }
export type VoteView = { label: string, count: number, total: number, mine: boolean, text: string }

export type ReviewView = {
	tab: string,
	subtitle: string,
	headline: string,
	met: boolean,
	rows: { RowView },
	ratingLabel: string,
	rating: string,
	quote: string,
	quoteBy: string,
	awards: { AwardView },
	moreAwards: string?,
	voteTitle: string,
	another: VoteView,
	depot: VoteView,
	footer: string,
}

local PHONE_AWARDS = 2

local ShiftReviewViewModel = {}

local function vote(label: string, count: number, total: number, mine: boolean): VoteView
	return { label = label, count = count, total = total, mine = mine, text = `{label}  {count}/{total}{if mine then " ✓" else ""}` }
end

function ShiftReviewViewModel.review(
	snapshot: ShiftTypes.ShiftSnapshot?,
	myVote: string?,
	myUserId: number,
	now: number,
	phone: boolean
): ReviewView?
	if snapshot == nil or snapshot.phase ~= "results" then
		return nil
	end
	local results = snapshot.results
	if results == nil then
		return nil
	end
	local met = results.quotaMet
	local quote = if met then ShiftConstants.REVIEW_QUOTES.met else ShiftConstants.REVIEW_QUOTES.missed
	local truck = snapshot.truck
	local client = DepotConstants.CONTRACTS[1].client
	local awards: { AwardView } = {}
	for index, award in results.awards do
		local name = if myUserId ~= 0 and award.userId == myUserId then "you" else award.name
		if not phone then
			table.insert(awards, { title = award.title, line = `{name} — {award.detail}` })
		elseif index <= PHONE_AWARDS then
			table.insert(awards, { title = award.title, line = name })
		end
	end
	local extra = #results.awards - PHONE_AWARDS
	local total = math.max(#snapshot.crew, snapshot.votesAnother + snapshot.votesDepot, 1)
	local voteEndsAt = snapshot.voteEndsAt
	local left = ShiftHudViewModel.clock(if voteEndsAt ~= nil then voteEndsAt - now else 0)
	return {
		tab = if phone then "PERFORMANCE REVIEW" else "PERFORMANCE REVIEW — NIGHT SHIFT",
		subtitle = `{if truck ~= nil then `Crew of Truck {truck}` else "Crew"} · {client} · {DepotConstants.SITE}`,
		headline = if met then "QUOTA MET" else "QUOTA MISSED",
		met = met,
		rows = {
			{ label = "CLEARED", value = `{results.cleared} / {results.quota}` },
			{ label = if met then "FINDER'S FEE" else "FINDER'S FEE (banked)", value = `+{results.bonus}` },
			{ label = "TIMES CAUGHT", value = tostring(results.catches) },
			{ label = "SALVAGE FOUND", value = `{results.salvage} of {results.offered}` },
		},
		ratingLabel = if phone then "Rating:" else "Overall rating:",
		rating = ShiftConstants.RATING_TEXT[results.rating] or results.rating,
		quote = quote.line,
		quoteBy = quote.by,
		awards = awards,
		moreAwards = if phone and extra > 0 then `+{extra} MORE AWARDS ›` else nil,
		voteTitle = if phone then "WHAT NEXT?" else "WHAT NEXT? (crew vote)",
		another = vote("ANOTHER SHIFT", snapshot.votesAnother, total, myVote == "another"),
		depot = vote("BACK TO DEPOT", snapshot.votesDepot, total, myVote == "depot"),
		footer = if phone
			then `✓ = your vote · auto-picks in {left}\nA tie means Another shift`
			else `Majority decides · auto-picks in {left} · a tie means Another shift`,
	}
end

return ShiftReviewViewModel
```

(The subtitle uses a nested interpolated string; if StyLua or luau-lsp rejects nesting, compute `local crewText = if truck ~= nil then `Crew of Truck {truck}` else "Crew"` first.)

- [ ] **Step 3: Panel, screen, tab, scene, wiring.** `ShiftReviewPanel.luau` (`props = { view: ReviewView, layout: Layout, onVote: (choice: ShiftTypes.Vote) -> () }`), desktop (5a/5c): a `COLOR.night` wash at 0.25; a manila `PaperSheet` 1600×900 centred with `tab = view.tab`; left column (x 128): `view.subtitle` (body 22), the headline `PaperStamp` (64, tilt −3, stamp red), the four rows (label heading 24 / value number 52, 84 px apart with manila-deep rules), "Overall rating:" (body 24) + a `PaperStamp` `view.rating` (30), the quote (body 22) and `quoteBy`; a 1 px ink rule at x 800; right column (x 928): "AWARDS" heading 26 and a 2×2 grid of `StickyNote`s (340 wide, 24, tilts ±2) with `"{title}\n{line}"`; "WHAT NEXT? (crew vote)" heading 26; `PaperButton` go `view.another.label` 286×76 and `PaperButton` secondary `onPaper` `view.depot.label` 286×76, each followed by its dots (`total` 16 px circles, `count` filled ink) and "✓ your vote" (Oswald Medium 22) when `mine`; the footer (body 20). Phone (5b): the sheet fills the safe area; left: the headline stamp 22, the four rows in two columns (label 14 / value 24), two award stickies (16) and the `moreAwards` button (Oswald 15; local `React.useState` toggles showing the rest: UI-only state); right: "WHAT NEXT?" 16, two vote `PaperButton`s 280×64 with `view.another.text` / `view.depot.text` (20), the footer 14, "Rating:" + the rating stamp 16. Buttons call `props.onVote("another")` / `props.onVote("depot")`.

`ShiftReviewScreen.luau`: reads `ShiftStore.snapshot`, `ShiftStore.myVote`, `usePaperLayout()`, `useServerClock()`; `ShiftReviewViewModel.review(snapshot, myVote, Players.LocalPlayer.UserId, now, layout == "phone")`; nil → nothing; else `ShiftReviewPanel` with `onVote = function(choice) ShiftStore.myVote(choice) end` (ShiftServiceClient already sends it).

`ShiftScene.luau`: registers `ShiftConstants.REVIEW_SCENE` (`screens = { { layer = "Panel", key = "review", component = ShiftReviewScreen } }`, `suppress = { mouse = true }`, `hud = "hidden"`), the `DepotScene` shape.

`ShiftReviewTab.luau` (HUD widget): reads `ShiftStore.snapshot` and `UIStore.sceneStack`; while `phase == "results"` and the review scene is not on the stack (Escape closed it), a manila tab `PaperButton` primary "PERFORMANCE REVIEW · OPEN" (bottom-centre, 360×64 desktop / 260×48 phone) that calls `SceneStack.push(ShiftConstants.REVIEW_SCENE)`.

`ShiftServiceClient`: require `ShiftScene` (registration at load), `SceneStack`, `ShiftReviewTab`; in `init` replace the `shiftResults` registration with `HudRegistry.register("shiftReviewTab", ShiftReviewTab, ShiftConstants.HUD_ORDER + 1)`; in the snapshot subscription, after computing `inResults`:

```lua
				if inResults and not reviewing then
					SceneStack.push(ShiftConstants.REVIEW_SCENE)
				elseif not inResults and reviewing then
					SceneStack.remove(ShiftConstants.REVIEW_SCENE)
				end
				reviewing = inResults
```

(`local reviewing = false` at module level; `stop` removes the scene and resets it.) Remove `ShiftResults` and its require.

Delete `ShiftResults.luau`, `ShiftResultsPanel.luau`, `ShiftResultsPanel.story.luau`; remove `ShiftHudViewModel.results`, `ResultsView`, `OUTCOME_TEXT` and the spec's `describe("results", ...)`; `grep -rn "ShiftResults\b\|ShiftResultsPanel\|ShiftHudViewModel.results" src` prints nothing afterwards.

`ShiftReviewPanel.story.luau`: controls `Variant = UILabs.Choose({ "5a met", "5c missed" })`, `Phone = false`, `MyVote = UILabs.Choose({ "another", "depot", "none" })`, built from `ShiftStoryFixtures` plus a results fixture.

- [ ] **Step 4: `SpecRoots`.** Remove the `ShiftResultsPanel` and `ShiftResults` lines; add (Shift block):

```lua
	["ReplicatedStorage.Client.UI.React.Screens.Shift.ShiftReviewPanel"] = "presentational React component (review specced in ShiftReviewViewModel; story in ShiftReviewPanel.story)",
	["ReplicatedStorage.Client.UI.React.Screens.Shift.ShiftReviewScreen"] = "React scene screen wiring ShiftStore to ShiftReviewPanel (no logic)",
	["ReplicatedStorage.Client.UI.React.Screens.Shift.ShiftReviewTab"] = "React HUD widget reopening the review scene (no logic)",
	["ReplicatedStorage.Client.UI.React.Screens.Shift.ShiftScene"] = "scene registration (declarative, no logic)",
```

- [ ] **Step 5: Controller: Studio TestEZ and checks.** `ShiftReviewViewModel` passes (and `ShiftHudViewModel` without its old results block). UI Labs `ShiftReviewPanel` beside 5a (31:557), 5c (31:611), 5b (31:665). Play solo: clock out → the review opens as a scene (mouse free, HUD hidden), QUOTA MET or MISSED, the rows, the rating stamp, your awards read "you — …"; vote Another shift → "✓ your vote" and the dots; Escape closes it and the manila tab reopens it; the timer auto-picks; the next shift starts and the scene closes by itself. 3-client local server: three votes, the counts, a 1-1 tie with one abstaining resolves to Another shift. Phone emulator: 5b layout, "+2 MORE AWARDS ›" expands, buttons ≥ 48 px.

- [ ] **Step 6: Gate and commit**

```bash
git add -A src
python3 scripts/python/module_map.py --write
git add docs/project-structure.md
stylua src/ReplicatedStorage/Client/UI/React/Screens/Shift src/ReplicatedStorage/Client/Features/Shift/ShiftServiceClient.luau src/ReplicatedStorage/Shared/Features/Shift/Data/ShiftConstants.luau src/ServerScriptService/Core/Testing/SpecRoots.luau
git add -A src
bash .superpowers/sdd/gate.sh
python3 scripts/python/check_pr_rules.py origin/main
git commit -m "feat(ui): performance review scene with rating, joke awards and crew vote"
python3 scripts/python/module_map.py --check
```

---

### Task 16: Live verification against Figma, and the docs

**Files:**
- Modify: `docs/ROADMAP.md` (the Cleanup Crew row)
- Modify: `docs/superpowers/specs/2026-10-10-cleanup-crew-design.md` §6.3 (the public fields as built)

- [ ] **Step 1: Full Studio TestEZ** (controller, `RunTests = true`): every spec passes; `assertAllModulesSpecced` and `assertAllSpecsCovered` pass.

- [ ] **Step 2: Story pass** (edit mode, UI Labs): open every story under `Game UI → Screens` (Paper/PaperKit, Paper/PaperToastStack, Shift/ShiftHudPanel ×3 variants × desktop/phone, Shift/ShiftReviewPanel ×2 × desktop/phone, Depot/DepotBoardPanel ×2, Depot/DepotPadPanel ×2, Catch/CatchCctvPanel ×2, Catch/CatchRehiredPanel ×2). Screenshot each beside its Figma frame (figma-console `figma_take_screenshot` with the node ids in "Frame index", read-only) and log the differences. Fix any that are layout bugs; list any intended difference (copy computed from live data, the "1:00", flat colours for pending art) in the log.

- [ ] **Step 3: Solo playtest** (`RunTests = false`, desktop, 1920×1080 window), checking each item and screenshotting the marked ones: depot board opens from its prompt, last-shift card after a return (2a); truck pad card, Depart now (3a); arrival card; HUD normal (1a); the paper prompt and key hints; quota met: stamp + sticky (1b); break label, overtime: OVERTIME, red time, SALVAGE ×1.5, "×1.5 now" (1c); clock out: the slip, "<you> is clocking out!", roster aboard / NOT ABOARD (1c); caught: scare beat with nothing on screen (4a), the throw line, CCTV "NO SIGNAL", incident report, Rehired card (4c); review met and missed (5a/5c); vote, Escape + tab; Another shift resets everything (no stale scene, no stale prompt chip, no stale public fields in F4).

- [ ] **Step 4: Three-player local server** (Studio → Test → Clients and Servers, 3 players): all three in one truck (TRUCK n on every card); one is caught: the other two see "Alex was caught! Back in 0:08." and the struck roster line; the caught one spectates a teammate ("WATCHING", their carry and room, CAM nn, rooms from the truck), switches with ← / →; awards spread across players with "you" only on your own; the vote counts 3.

- [ ] **Step 5: Phone emulation** (Studio device emulator, a landscape phone 844×390 class): 1d / 1e HUD, the button arc around Jump with nothing in the bottom-left 40%, LOAD at the truck, POCKET lit for the plaque, the 2b board, 3b pad, 4d CCTV (‹ / › if B1), 4e Rehired, 5b review; every text ≥ 14 px and every button ≥ 48 px (check sizes in the Explorer).

- [ ] **Step 6: Docs.** `docs/ROADMAP.md`, the Cleanup Crew row: replace "M3 feel (final UI screens wait for Figma approval)" with "M3 feel" and append: "M3 UI: the Figma-approved paperwork screens in React, each with a UI Labs story: a game paper kit (`Screens/Paper`), sticky-note toasts and rubber stamps, the Shift HUD (clearance folder, finder's fee, punch-clock time card, crew roster, carry panel, clock-out slip, paper interaction prompt, key hints; phone layout with the action-button arc), the depot contract board scene and truck pad card, the catch (no-HUD scare beat, CCTV spectating with an incident report, the Rehired card) and the performance review scene (rating tiers, four joke awards, crew vote). New data behind them: review stats per crew member, noise makers, crew status public fields, truck numbers, the caught deadline and incident report." Spec §6.3: list the per-player public fields as built (`inTruck`, `vacuuming`, `room`, `roomDepth`, `cam`, `caughtUntil`, depot `truck`) in place of "caught".

- [ ] **Step 7: Gate and commit**

```bash
python3 scripts/python/module_map.py --check
bash .superpowers/sdd/gate.sh
python3 scripts/python/check_pr_rules.py origin/main
git add docs/ROADMAP.md docs/superpowers/specs/2026-10-10-cleanup-crew-design.md
git commit -m "docs: record Cleanup Crew M3 UI on the roadmap"
```

---

## Self-review (planner)

- **Spec coverage.** §7 "only approved screens are built in React, each with a UI Labs story": every frame in "Frame index" has a task and a story (1a-1f → Tasks 8-11; 2a/2b → 12; 3a/3b → 13; 4a-4e → 14; 5a-5c → 15); the rating note (35:1096) → Task 1; the crew roster cards → Tasks 9/10. §6.2 "UI screens live in the UI tree, registered as HUD widgets and scenes": HUD widgets (Shift HUD, prompt chip, paper toasts, pad card, CCTV, Rehired card, review tab) and scenes (depot board, review). §6.3 "per-player public fields (pockets, canister fill, caught)": `caughtUntil` plus the status fields (Tasks 3, 5). The developer's decisions: vote rule unchanged (server code untouched, own vote marked: Task 15); CCTV with incident report (Task 14); 3 rating tiers (Task 1); joke awards incl. LOUDEST VACUUM (Tasks 1-2); approved copy (Task 5, with the 1:00 note); clock-out slip (Task 9); roster card (Task 9); pinboard (Task 12); arc ≥ 16 px (Task 10); no text during the scare, line on the throw (Tasks 5, 8, 9); spectate keys ← / → (Task 14). Deferred items are not built (Global Constraints).
- **Placeholders.** Pure modules carry full spec and implementation code. Components carry the load-bearing code (widgets, the kit's fasteners and torn edge, the time card, the toast stack, the overlay wiring) and exact sizes/positions/fonts from the Figma dumps for the rest; no "TBD". The two genuinely conditional parts are explicit branches with their fallbacks: B1/B2 (Task 6 and its readers) and the Custom-prompt verification (Task 11 Step 1).
- **Type consistency.** `ShiftTypes.Rating/Award/CrewLine/ShiftSnapshot.crew/truck` (Task 1) are what `ShiftSnapshotUtils.decode`, `ShiftCardUtils`, `ShiftReviewViewModel`, `ShiftCrewViewModel` read; `NoiseTypes.NoiseEvent.makers` (Task 2) is what `ShiftReviewSystem` and `ShiftAnalyticsUtils.Noise.makers` use; public field names live once (`ShiftConstants.PUBLIC_*`, `OccupantConstants.PUBLIC_CAUGHT_UNTIL`, `DepotConstants.PUBLIC_TRUCK`) and are read by name in every view model; `OccupantTypes.CatchReport` is the packet struct, the store's type and `CatchViewModel`'s input; `DepotTypes.LastShift` is the packet struct, `ShiftCardUtils.summary`'s result, `DepotStore.lastShift` and `DepotBoardViewModel`'s input; `ShiftPromptStore.PromptView` feeds `ShiftHudViewModel.prompt`. `ShiftHudViewModel.hud` gains a fourth parameter `hidden` and every caller (ShiftHud, the story) passes it.
- **Line caps.** Shift 382 → 387 (T1) → ~380 (T2) → ~382 (T3) → same (T4, T5); Cargo 400 → 400 (T2); Occupant 398 → 395 (T5). Each task runs `check_file_length` through the gate.
- **Review Focus.** Line 1 → Task 1 `ShiftResultsUtils` / `ShiftCardUtils` cases; line 2 → Task 1 awards cases and Task 15 "calls an award yours by userId"; line 3 → Task 2 `VacuumChannelTracker` and `heardNoise` cases; line 4 → Task 4 `truckOf` and Task 1 card case; line 5 → Task 9 `ShiftCrewViewModel` cases and Task 14 `CatchViewModel` "never counts below 0:00".
- **Surprises worth the developer's eye** (also in Open questions): the rating note's own sample contradicts its rule; the approved quota-met toast says "0:30" where the real wait is 1:00; the base Toast has no way for a game to replace its widget, and touch spectating has no API (B1/B2); `CargoServiceServer` is exactly at the 400-line cap.
