# M3b (World UI): Cleanup Crew, the Approved In-World Billboards and Travel Cards Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Every world-space sign the developer approved on the Figma "World UI" page (truck pad tags, the contract board, the result board with your review card, cargo price tags, load floaters, Harlow's cue and memo) and the drive / arrival screen cards are drawn with the game's paper kit in React, with a UI Labs story each, and the kit gains a texture layer that turns on when the developer pastes six asset ids.

**Architecture:** The paper kit is React and client-only, and `check_pr_rules` forbids `Client/UI/React` from doing I/O, so the work splits along the existing server/client line. **Server:** each system keeps building its BillboardGui *shell* (size, offset, MaxDistance, AlwaysOnTop, Adornee, LightInfluence 0) but stops writing TextLabels. It publishes the shell's display data as Instance attributes and tags the shell (CollectionService), one tag per kind. Where the client already has the data through state sync (the truck tags' crew and countdown: Queue's `queue` world entry plus Depot's public `truck` field), the shell carries only static keys. **Client:** one Systems module per owning feature (`DepotBillboardSystem`, `CargoBillboardSystem`, `OccupantBillboardSystem`) watches its tags through a shared host (`UIBillboardHost.watch`). It mounts one React root per shell into a child Frame (a React root clears its container), renders a presentational component from `Screens/World/` with props built by pure, specced view models, re-renders in place on change and destroys the root when the shell leaves. That bookkeeping is the specced `UIBillboards` core. A `WorldBillboard` wrapper maps each component's Figma px design size onto its shell with a UIScale: board-sized shells (studs) fit the shell's live AbsoluteSize, screen-sized shells (offset px) scale by the viewport. The review card stays per-player (PlayerGui). The load floaters are already client-side and are restyled in place. Server authority is unchanged: attributes are display data only.

**Tech Stack:** Luau `--!strict`, React-lua (`React.createElement`, bindings, `React.Change`), ReactRoblox `createRoot`, Charm (`subscribe`), CollectionService tags, Instance attributes, ByteNetMax (`struct`), UI Labs (`UILabs.CreateReactStory`), TestEZ (Studio, `RunTests = true`).

**Spec:** Figma file `PYtXsNlpV1MW2nOVx0wXl4`, page "World UI": frame 2a (depot billboards: W1 truck pad tag, W2 contract board, W3+W4 result board), 2b (on-shift billboards: W5 cargo tag, W6 load floaters, W7 Harlow cue, W8 Harlow speech) and 2c (S1 drive and arrival cards). PNG exports: `overnight-handoff/ui-previews/world-ui/2a-depot-billboards.png`, `2b-shift-billboards.png`, `2c-drive-arrival-cards.png`. Approved texture pass on the existing screens: `overnight-handoff/ui-previews/textured/sheet-textured-all.jpg`. The developer's design notes are restated in "Decisions" and in each task. Both folders are local and untracked (`git status`: `?? overnight-handoff/`, `?? assets/`); read them, never commit them. House template and prior decisions: `docs/superpowers/plans/2026-10-11-m3-cleanup-crew-ui.md` (M3 UI, merged; its modules are the real API).

**Branch / PR:** `game/cleanup-crew`, head `e0bd9f2` or later. No base changes. Nothing here touches `base/*` or `main`.

## Global Constraints

- `--!strict` everywhere except `*.spec.luau` (specs are untyped by design); stories follow the existing `--!strict` story files. No `any`, no `::` casts. If one seems needed, stop and report.
- Service shape: lean annotated literal (`export type X = {...}` + `local X: X = {...}`, methods as fields). Systems modules here are plain module tables with `start` / `stop` / `getState` functions (the `CargoFeedbackSystem` / `OccupantPresenceSystem` pattern).
- Every new first-party module has a `<Name>.spec.luau` sibling or an `EXEMPT_MODULES` line with a reason in `src/ServerScriptService/Core/Testing/SpecRoots.luau`. `*.story` need neither. View models and pure cores get real specs. Presentational components, hooks and Instance shells are exempt with a reason that names the specced module holding their decisions (docs/testing.md "Testing React UI"). Logic that branches lives in the view model.
- Feature modules are `<Feature><What><RoleWord>` in an allowed subfolder. UI tree modules are PascalCase (`ViewModel` suffix, `use<Thing>` hooks beside the one screen using them). Requires use full addresses; a feature folder required 3+ times in one file gets a `<Feature><Realm>` variable. The UI tree keeps relative-free full requires like its neighbours.
- ≤ 400 code lines per module (`scripts/python/check_file_length.py`; comments and blanks do not count). Measured at `e0bd9f2`: `CargoServiceServer` **400** and `OccupantServiceServer` **397** are untouched by this plan. `SpecRoots` 349 (+≈22 here), `DepotServiceServer` 265, `CargoFeedbackSystem` 233, `OccupantPresenceSystem` 260, `DepotBuildSystem` 195, `ShiftCardUtils` 208.
- CI rules this plan must keep (`scripts/python/check_pr_rules.py`): a `ScreenGui` only in `UILayerHost`; no `.Enabled =` / `.Visible =` assignment in `Client/UI/` or `Client/Features/UI/` (the server-side `billboard.Enabled =` writes in Cargo / Occupant systems are outside those trees and stay); no `:FireServer` / `:InvokeServer` / `.packets.` in `Client/UI/React`; asset-id literals (`rbxassetid://` + digits) only in a `Data/` module or a spec; no `Name =` React prop.
- **Rojo safety:** the developer may be connected to `rojo serve`. Never run `rokit install`, `wally install`, `install.sh`, `wally-package-types` or `scripts/check.sh`, and never start `rojo serve`. The per-task gate is `PYTHONUTF8=1 bash .superpowers/sdd/gate.sh` (selene, stylua check, luau-lsp, `check_pr_rules`, file length, module map, python tests).
- **Tests run only in Studio, by the controller:** "Controller: Studio TestEZ" = set the Workspace attribute `RunTests = true`, Play, read Output (the suite mutates live singletons, so it is never a play session). Gameplay and visual checks run in a fresh Play with `RunTests = false`. The Studio MCP plugin VM cannot reach live services, so a check that needs them uses a temporary `Script` / `LocalScript` the controller injects and deletes. UI Labs stories are checked in **edit mode** (no Play).
- **Commit order (every task):** `git add src` → `python3 scripts/python/module_map.py --write` → `git add docs/project-structure.md` → `stylua <each new or edited .luau file>` → `git add src` → `PYTHONUTF8=1 bash .superpowers/sdd/gate.sh` → `python3 scripts/python/check_pr_rules.py origin/main` (zero errors) → `git commit -m "<message as given>"` → `python3 scripts/python/module_map.py --check`. Never `stylua src` wholesale. Never `git add assets` or `git add overnight-handoff`.
- **Commits: plain messages, no `Co-Authored-By:` / `Claude-Session:` trailers** (AGENTS.md; `check_pr_rules` rejects them).
- Server-authoritative: the server decides every number a sign shows. Attributes are display data, written only by the server. New client → server traffic: **none**.
- Palette and fonts come only from `UIPaperConstants` (cream `F4ECD6`, manila `E8C98A`, manilaDeep `C9A564`, sticky `FFE45C`, ink `24211C`, stamp `C8202F`, fluorGlow `B8F0C4`, monitor `4C9BFF`, monitorDeep `12305C`, night `0E1116`; Special Elite / Oswald Bold / Roboto Mono / Permanent Marker).
- Textures: six slots, all PENDING (`""`). When a slot is `""` the texture layer is not created (flat colour, today's look). **No upload task.** Uploads to the Icey Labs group need the developer's approval per asset and an API key that does not exist yet (see "Closing note").
- Every shell sets `LightInfluence = 0` and `ZIndexBehavior = Sibling`. Cargo tags keep `MaxDistance = 24` (`CargoConstants.LABEL_DISTANCE`) and stay hidden under piles. Floaters keep their rise and fade. Harlow's memo keeps letter-by-letter typing at `OccupantConstants.TYPE_RATE`.
- **Out of scope, do not build:** EXIT signs, Harlow's grin, the carry panel, mobile buttons, CCTV.

## Review Focus

1. **A cargo item is banked, destroyed or streamed out while its tag is mounted, and its React root leaks** (or errors unmounting into a destroyed container) → the root is destroyed exactly once, the mounted count returns to zero, nothing errors. (Task 3 `UIBillboards` spec "destroys a hidden shell's root and forgets it", "destroys every root on teardown"; Task 3 Step 6 command-bar check that unmounts after the part is destroyed; Task 6 Step 9 live check `CargoBillboardSystem.getState().mounted` returns to 0 after banking.)
2. **Attribute and store updates every 0.25–0.5 s remount the sign instead of re-rendering it** (the stamp re-pops, the memo restarts typing, React churns) → one root per shell for its whole life; a refresh renders into it, and an unchanged truck tag is not rendered at all. (Task 3 `UIBillboards` spec "renders into the same root on every later show, never mounting twice"; Task 4 `DepotWorldViewModel` spec "is the same tag only when every drawn line matches"; Task 8 `useTypedGraphemes` restarts only when the text changes, checked in Task 10 Step 3.)
3. **Long text overflows a fixed sign** ("Employee of the Month plaque", a long client name riding a forged teleport payload, an 80-character Harlow line) → names are cut on a character boundary with "…" at a per-sign limit, and fixed frames shrink text between a floor and the design size. (Task 2 `WorldBillboardViewModel` spec "clip"; Task 6 `CargoWorldViewModel` spec "keeps the longest catalog name whole"; Task 5 `DepotWorldViewModel` spec "cuts a long client name in the band"; Task 9 `DepotCardViewModel` spec "cuts a long client name on both cards"; Task 8 `OccupantWorldViewModel` spec "caps a line at 80 characters".)
4. **A room full of cargo mounts a React tree per item** (60–100 items, most far away or under piles) → only items within 24 studs of the camera mount, with a 28-stud keep radius so a tag at the edge does not flicker, and hidden items never mount. (Task 6 `CargoWorldViewModel` spec "mounts only within 24 studs, keeps until 28, never under a pile".)
5. **Phone vs desktop scale** (a 260 px price tag or a 520 px memo covering a third of an 844×390 phone; board signs unreadable at a distance) → screen-sized signs scale by `min(w/1920, h/1080)` clamped to 0.6..1; board signs fit their stud-sized shell. (Task 2 `WorldBillboardViewModel` spec "screenScale" and "fit"; Task 10 Step 5 phone emulation.)

---

## Decisions (from the developer, the approved frames and the code)

Developer decisions restated (not re-opened): the World UI frames 2a/2b/2c as specified; textures as tiled ImageLabels over flat colour, ids PENDING; shells stay server-built and the React UI is client-only; W4 stays per-player; W6 is restyled in place; shouted lines are "all-caps or end with !", as a pure specced rule.

Decisions taken in this plan (each small and reversible):

- **W1 data comes from state sync, not new attributes.** The truck tag's crew count and countdown are already on the client: Queue's `queue` world entry (`QueueStore.snapshot`: members, endsAt, departing per pad) and Depot's public `truck` field per player. The shell carries only `DepotTruck` and `DepotCapacity` (written once). `DepotWorldViewModel.padFor` finds the pad whose members stand in that truck. The server stops rewriting pad text every 0.5 s; its tick only maintains the public `truck` field, as today.
- **W1 line 3 rule.** A countdown runs as soon as anyone is aboard (Queue), but Figma shows the join line at 2 / 4. So line 3 is the red "Leaving in m:ss" when the truck is full **or** 10 s or less remain (`DepotConstants.TAG_WARN_SECONDS = 10`), "Leaving now" while departing, else "Stand in the bed to join".
- **W3 + W4 composition.** Two billboards at one spot z-fight. The per-player review shell (in your PlayerGui, `ResetOnSpawn = false`, same adornee and size) draws the whole result board plus your card and stickies. On your client the shared board shell draws nothing while you have a card. Without a card you see the shared cork board with its "PERFORMANCE REVIEWS" tab.
- **W4 data:** `ShiftCardUtils.attributes(card)` writes the decoded card under shared keys (`DepotConstants.REVIEW_KEYS`) and replaces `ShiftCardUtils.lines`. The card has no award details and no user ids after the teleport, so stickies read "TITLE" + name, and the crew line lists names as written (no "You").
- **W2:** the E chip and "Read the work order" are always visible (prompt range is not tracked client-side at the depot). The job line is the contract's real `job` (Figma's "4th floor offices · Harlow on site" is sample text). The work-order number is `DepotBoardViewModel.workOrder(id)` (the same number the board scene prints).
- **W5:** salvage prices read "$45"; trash reads "+10" (clearance points, like the "+15 CLEARED" floater). The mark is "FRAGILE" for an undamaged fragile item and "CRACKED −50%" / "−75%" from `CargoConstants.FRAGILE_TIERS` after impacts; otherwise nothing (Figma's "salvage" sub-line is not drawn: the written spec says "else nothing").
- **W6 copy:** "+40 BONUS" exactly as the approved frame 2b, although the M3 UI plan's copy rule says "Finder's fee". It applies to the floater only.
- **Sizes.** Depot signs are stud-sized at Figma's "1 px ≈ 1/40 stud" (`DepotConstants.STUDS_PER_PX`): truck tag 340×310 px (a 60 px wire + the 340×250 tag) = 8.5×7.75 studs; contract board 600×420 = 15×10.5; result board 1140×446 = 28.5×11.15. Harlow's cue stays 2.5×2.5 studs (design 140×140). Cargo tags (260×70), floaters (340×130) and the memo (520×166) stay offset-sized as today, scaled by the viewport (Review Focus 5; floor 0.6).
- **Textures.** `UIAssets.paper` becomes six `{ id, tile }` slots (cream 160, manila 160, manilaDeep 128, sticky 128, cork 192, wood 256×128). The unused `scanlines` slot moves to `UIAssets.cctv`. `UIPaperConstants.COLOR.wood = 4A2E1A` (picked from the 2a PNG frame). The colour → material lookup is by hex, so any `Color3.fromHex` of a palette colour gets its texture.
- **The board scene** (`DepotBoardPanel`) swaps its flat cork Frame for `CorkBoard` (cork texture, 12 px wood edge, children unchanged), matching the approved textured sheet.
- **Where the generic pieces live.** `UIBillboards` (pure core) and `UIBillboardHost` (ReactRoblox/CollectionService shell) live beside `UILayers` / `UILayerHost` in `Client/UI/Layers/`, the folder of root factories. They are generic and could move to base later; that is not done here.
- **S1 cards carry structured data.** `DepotTypes.CardMessage` becomes `{ kind, client, job, note, quota, truck }` (title/body strings removed); the client builds every line (`DepotCardViewModel`). The drive card's truck number is the departing pad's index; the arrival card's comes from the untrusted payload through `DepotContractUtils.truckOf`. The cards scale by the same `screenScale`, centred at 40% height.

## Frame index (what each task matches)

| Frame | Item | Built in |
|---|---|---|
| 2a | W1 truck pad tag | Task 4 |
| 2a | W2 contract board | Task 5 |
| 2a | W3 + W4 result board with your review card | Task 5 |
| 2b | W5 cargo price tag | Task 6 |
| 2b | W6 load floaters | Task 7 |
| 2b | W7 Harlow cue, W8 Harlow memo | Task 8 |
| 2c | S1 drive card, arrival card | Task 9 |
| textured sheet | texture layer on PaperSheet / StickyNote / tags / cork | Tasks 1-2 |

Key measurements (from the PNG exports, px at the design size): truck tag 340×250 manila, hole Ø22 at (170, 26), "TRUCK n" Oswald 64, 4 seats Ø32 gap 14, "n / 4 ABOARD" Oswald 26, line 3 Special Elite 20; contract cork board 600×420 in a 20 px wood frame, work order 310×360 cream at (150, 34) tilt 1.5 with a red band and a pin; result board 1140×420 at y 26 with a manilaDeep tab 380×64 at (380, 0) "PERFORMANCE REVIEWS" Oswald 36, review card 568×330 at (60, 76) tilt −1.5 (ink band), stickies 200 wide at (675, 96) / (900, 110) / (790, 262); price tag 260×70 (body 238 + a 22 px point), name/price Oswald 24, mark Oswald 14 in a 2 px red outline; floater "+15" Oswald 80 fluorGlow with a 4 px night outline + "CLEARED" Oswald 26, bonus stamp 300×96 monitorDeep fill, 5 px monitor ring, Oswald 64, rotated 5°; cue disc Ø120 with a 6 px ring, glyph Oswald 90, "!" tilted −8°; memo 520×140 cream, 30 px red band "MEMO — FROM THE DESK OF H. HARLOW" Oswald 18, line Special Elite 30 (shouted 38, red), tail 24 px at x 90; drive card 520×260 cream tilt 1.5, ink band 46 px, "ON THE ROAD" Oswald 58, "Heading to …" Special Elite 24, 13 dashes 24×6 every 36 px, truck block 30×20 stamp red; arrival folder 640×400 manila with a 220 px "ARRIVAL" tab, client Oswald 56, job Special Elite 26, slip 330×170 cream tilt 1.5 with a red band, "CLEAR n" Oswald 58, sticky 200 wide at (400, 184) tilt −2.

---

## New modules

| Feature | Realm | Subfolder | Name | Job (one line) |
|---|---|---|---|---|
| Depot | client | Systems | DepotBillboardSystem | Draws the truck tags, the contract board and the result board (with your review card) into the depot's billboard shells |
| Cargo | client | Systems | CargoBillboardSystem | Draws a price tag on each cargo item near the camera, from the item's attributes |
| Occupant | client | Systems | OccupantBillboardSystem | Draws Harlow's cue disc and memo into his billboard shells |
| UI tree | client | `Client/UI/Layers/` | UIBillboards | Pure bookkeeping core: one React root per world shell, render in place, destroy on hide |
| UI tree | client | `Client/UI/Layers/` | UIBillboardHost | Instance/ReactRoblox factory for a shell's root, and the CollectionService tag watcher |
| UI tree | client | `Client/UI/React/Screens/Paper/` | PaperTextureViewModel | Paper colour → material → tiled texture layer, or none while PENDING (pure) |
| UI tree | client | `.../Screens/Paper/` | PaperTexture | The tiled texture ImageLabel over a paper's flat colour |
| UI tree | client | `.../Screens/Paper/` | CorkBoard | Cork in a wood frame |
| UI tree | client | `.../Screens/Paper/` | PaperTag | A luggage tag (hole at the top) or a price tag (pointed left end and hole) |
| UI tree | client | `.../Screens/World/` | WorldBillboard | Scales a component's Figma px design onto its shell (fit to studs, or by the screen) |
| UI tree | client | `.../Screens/World/` | WorldBillboardViewModel | Fit, screen scale and text clipping for world signs (pure) |
| UI tree | client | `.../Screens/World/` | DepotWorldViewModel | The truck tag, work order and review card views, and the pad of a truck (pure) |
| UI tree | client | `.../Screens/World/` | DepotTruckTag | W1 |
| UI tree | client | `.../Screens/World/` | DepotWorkOrderBoard | W2 |
| UI tree | client | `.../Screens/World/` | DepotResultBoard | W3 + W4 |
| UI tree | client | `.../Screens/World/` | CargoWorldViewModel | The price tag and floater views, and when a tag is mounted (pure) |
| UI tree | client | `.../Screens/World/` | CargoPriceTag | W5 |
| UI tree | client | `.../Screens/World/` | CargoLoadFloater | W6 |
| UI tree | client | `.../Screens/World/` | OccupantWorldViewModel | The cue and memo views and the shout rule (pure) |
| UI tree | client | `.../Screens/World/` | OccupantCueDisc | W7 |
| UI tree | client | `.../Screens/World/` | OccupantMemo | W8 |
| UI tree | client | `.../Screens/World/` | useTypedGraphemes | Hook: a MaxVisibleGraphemes binding that types a line out |
| UI tree | client | `.../Screens/Depot/` | DepotCardViewModel | The dispatch ticket and the arrival folder lines (pure) |

Stories (no spec, no exemption): `Screens/World/DepotWorld.story`, `Screens/World/CargoWorld.story`, `Screens/World/OccupantWorld.story`; rewritten: `Screens/Depot/DepotCardPanel.story`, `Screens/Paper/PaperKit.story` (extended).

Rewritten in place: `DepotCardPanel` (S1), `DepotCard`. Removed functions: `ShiftCardUtils.lines`, `DepotContractUtils.boardLines`; constants `CargoConstants.FLOATER_FONT / CLEARANCE_COLOR / BONUS_COLOR`, `OccupantConstants.SPEECH_FONT / SPEECH_PAPER / SPEECH_INK / SPEECH_BORDER`, `DepotLayoutConstants.PAD_LABEL_SIZE / PAD_LABEL_OFFSET / BOARD_LABEL_SIZE / BOARD_LABEL_OFFSET / TITLE_LABEL_SIZE / TITLE_LABEL_OFFSET / CARD_LABEL_SIZE / CARD_LABEL_OFFSET / LABEL_BACKGROUND / LABEL_TEXT`.

Extended: `UIAssets`, `UIPaperConstants`, `PaperLabel`, `PaperSheet`, `StickyNote`, `PaperKit.story`, `DepotBoardPanel`, `DepotConstants`, `DepotTypes`, `DepotEvents`, `DepotLayoutConstants`, `DepotContractUtils`, `DepotBuildSystem`, `DepotServiceServer`, `DepotStore`, `DepotServiceClient`, `ShiftCardUtils`, `CargoConstants`, `CargoSpawnSystem`, `CargoFeedbackSystem`, `CargoServiceClient`, `OccupantConstants`, `OccupantRigSystem`, `OccupantPresenceSystem`, `OccupantServiceClient`, `SpecRoots`.

**Layout check (module-placement skill):** the three feature rows use the existing `Systems` kind and the `System` role word. Depot's client realm gains a `Systems/` folder (an existing kind). No feature gains a second service. The UI tree keeps its own folders: `Screens/World` is a new folder beside `Screens/Paper`, `Screens/Depot`, … (no subfolder-kind rule there; `GameUI.storybook` scans everything under `Screens`). `UIBillboards` / `UIBillboardHost` sit in `Client/UI/Layers/` beside `UILayers` / `UILayerHost`. **No new subfolder kind, no new role word, no second service: nothing needs approval.**

---

### Task 0: Preflight

**Files:** none.

- [ ] **Step 1: Confirm the branch and head**

```bash
git branch --show-current
git log --oneline -3
```
Expected: `game/cleanup-crew`; `e0bd9f2 fix(ui): desktop prompt chip is a plain Frame so it never sinks mouse clicks` or a later commit.

- [ ] **Step 2: Confirm every API this plan edits or calls** (each prints at least one line; if one prints nothing, stop and report which):

```bash
grep -n "local function billboard" src/ServerScriptService/Features/Depot/Systems/DepotBuildSystem.luau
grep -n "function DepotBuildSystem.pinCard" src/ServerScriptService/Features/Depot/Systems/DepotBuildSystem.luau
grep -n "local function refreshLabels" src/ServerScriptService/Features/Depot/DepotServiceServer.luau
grep -n "function DepotContractUtils.boardLines" src/ServerScriptService/Features/Depot/Utils/DepotContractUtils.luau
grep -n "function ShiftCardUtils.lines" src/ServerScriptService/Features/Shift/Utils/ShiftCardUtils.luau
grep -n "local function makeLabel" src/ServerScriptService/Features/Cargo/Systems/CargoSpawnSystem.luau
grep -n "local function floater" src/ReplicatedStorage/Client/Features/Cargo/Systems/CargoFeedbackSystem.luau
grep -n "local function tells" src/ServerScriptService/Features/Occupant/Systems/OccupantRigSystem.luau
grep -n "local function stepReveal" src/ReplicatedStorage/Client/Features/Occupant/Systems/OccupantPresenceSystem.luau
grep -n "function OccupantFeedbackUtils.reveal" src/ReplicatedStorage/Shared/Features/Occupant/Utils/OccupantFeedbackUtils.luau
grep -n "function DepotBoardViewModel.workOrder" src/ReplicatedStorage/Client/UI/React/Screens/Depot/DepotBoardViewModel.luau
grep -n "function ShiftHudViewModel.clock" src/ReplicatedStorage/Client/UI/React/Screens/Shift/ShiftHudViewModel.luau
grep -n "function QueueSnapshotUtils.padOf" src/ReplicatedStorage/Shared/Features/Queue/Utils/QueueSnapshotUtils.luau
grep -n "UIAssets.paper" src/ReplicatedStorage/Client/Features/UI/Data/UIAssets.luau
grep -rn "PAD_LABEL\|BOARD_LABEL\|TITLE_LABEL\|CARD_LABEL\|LABEL_BACKGROUND\|LABEL_TEXT" src --include=*.luau
python3 scripts/python/check_file_length.py
```
Expected: every grep prints; the second-to-last prints only `DepotLayoutConstants.luau` and `DepotBuildSystem.luau` lines (if `DepotLayoutRules` reads one of them, stop and report). The length check passes.

- [ ] **Step 3: Confirm nobody else reads what this plan removes** (each prints only the files named in the task that removes it):

```bash
grep -rn "UIAssets.paper\|FLOATER_FONT\|CLEARANCE_COLOR\|BONUS_COLOR\|SPEECH_PAPER\|SPEECH_INK\|SPEECH_BORDER\|SPEECH_FONT\|ShiftCardUtils.lines\|boardLines\|DepotStore.show\|packets.Card" src --include=*.luau
```
Expected: only `UIAssets`, `CargoConstants`, `CargoFeedbackSystem`, `OccupantConstants`, `OccupantRigSystem`, `ShiftCardUtils(.spec)`, `DepotContractUtils(.spec)`, `DepotServiceServer`, `DepotStore(.spec)`, `DepotServiceClient`.

- [ ] **Step 4: Read the spec images** with the Read tool: the three `world-ui/*.png` and `textured/sheet-textured-all.jpg`. If anything in them contradicts "Decisions", stop and report.

---

### Task 1: The texture layer in the paper kit

Six tileable textures exist in `assets/ui/textures/` but are not uploaded. This task adds their slots (PENDING), a specced lookup from a paper colour to its texture, and a `PaperTexture` layer that `PaperSheet` (paper and tab) and `StickyNote` draw over their flat colour. While a slot is `""` nothing is created, so every existing screen looks exactly as today.

**Files:**
- Modify: `src/ReplicatedStorage/Client/Features/UI/Data/UIAssets.luau`
- Modify: `src/ReplicatedStorage/Client/UI/React/Screens/Paper/UIPaperConstants.luau` (`COLOR.wood`)
- Create: `src/ReplicatedStorage/Client/UI/React/Screens/Paper/PaperTextureViewModel.luau`; Test: `.../Paper/PaperTextureViewModel.spec.luau`
- Create: `src/ReplicatedStorage/Client/UI/React/Screens/Paper/PaperTexture.luau`
- Modify: `src/ReplicatedStorage/Client/UI/React/Screens/Paper/PaperSheet.luau`, `.../Paper/StickyNote.luau`
- Modify: `src/ServerScriptService/Core/Testing/SpecRoots.luau`

**Interfaces:**
- Consumes: `UIPaperConstants.COLOR` (`cream`, `manila`, `manilaDeep`, `sticky`, `cork`).
- Produces:
  - `UIAssets.Texture = { id: string, tile: Vector2 }`; `UIAssets.paper: { [string]: Texture }` with keys `cream`, `manila`, `manilaDeep`, `sticky`, `cork`, `wood`; `UIAssets.cctv = { scanlines = "" }`.
  - `UIPaperConstants.COLOR.wood = Color3.fromHex("4A2E1A")`.
  - `PaperTextureViewModel.Material = "cream" | "manila" | "manilaDeep" | "sticky" | "cork" | "wood"`; `Layer = { image: string, tile: Vector2 }`; `materialOf(paper: Color3) -> Material?`; `layer(material: Material?, slots: { [string]: UIAssets.Texture }) -> Layer?`; `forPaper(paper: Color3) -> Layer?`; `validId(id: string) -> boolean`.
  - `PaperTexture(props: { paper: Color3, corner: number?, zIndex: number? })`: an ImageLabel filling its parent, or nothing.

- [ ] **Step 1: Write the failing spec** `PaperTextureViewModel.spec.luau`:

```lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PaperTextureViewModel = require(script.Parent.PaperTextureViewModel)
local UIAssets = require(ReplicatedStorage.Client.Features.UI.Data.UIAssets)
local UIPaperConstants = require(ReplicatedStorage.Client.UI.React.Screens.Paper.UIPaperConstants)

local COLOR = UIPaperConstants.COLOR

local function slots(id)
	return {
		cork = { id = id, tile = Vector2.new(192, 192) },
		wood = { id = id, tile = Vector2.new(256, 128) },
	}
end

return function()
	describe("materialOf", function()
		it("names the material of each paper colour", function()
			expect(PaperTextureViewModel.materialOf(COLOR.cream)).to.equal("cream")
			expect(PaperTextureViewModel.materialOf(COLOR.manila)).to.equal("manila")
			expect(PaperTextureViewModel.materialOf(COLOR.manilaDeep)).to.equal("manilaDeep")
			expect(PaperTextureViewModel.materialOf(COLOR.sticky)).to.equal("sticky")
			expect(PaperTextureViewModel.materialOf(COLOR.cork)).to.equal("cork")
			expect(PaperTextureViewModel.materialOf(COLOR.wood)).to.equal("wood")
		end)

		it("matches a colour built separately from the same hex", function()
			expect(PaperTextureViewModel.materialOf(Color3.fromHex("E8C98A"))).to.equal("manila")
			expect(PaperTextureViewModel.materialOf(Color3.fromHex("f4ecd6"))).to.equal("cream")
		end)

		it("has no material for a colour that is not paper", function()
			expect(PaperTextureViewModel.materialOf(COLOR.office)).to.equal(nil)
			expect(PaperTextureViewModel.materialOf(COLOR.stamp)).to.equal(nil)
			expect(PaperTextureViewModel.materialOf(COLOR.ink)).to.equal(nil)
		end)
	end)

	describe("layer", function()
		it("draws no layer while the slot is PENDING", function()
			expect(PaperTextureViewModel.layer("cork", slots(""))).to.equal(nil)
		end)

		it("tiles an uploaded texture at its file size", function()
			local layer = PaperTextureViewModel.layer("wood", slots("rbxassetid://1"))
			expect(layer.image).to.equal("rbxassetid://1")
			expect(layer.tile).to.equal(Vector2.new(256, 128))
		end)

		it("draws nothing for no material or a missing slot", function()
			expect(PaperTextureViewModel.layer(nil, slots("rbxassetid://1"))).to.equal(nil)
			expect(PaperTextureViewModel.layer("sticky", slots("rbxassetid://1"))).to.equal(nil)
		end)
	end)

	describe("the game's slots", function()
		it("lists the six textures at their file sizes", function()
			local sizes = {
				cream = Vector2.new(160, 160),
				manila = Vector2.new(160, 160),
				manilaDeep = Vector2.new(128, 128),
				sticky = Vector2.new(128, 128),
				cork = Vector2.new(192, 192),
				wood = Vector2.new(256, 128),
			}
			local count = 0
			for material, size in sizes do
				local slot = UIAssets.paper[material]
				expect(slot ~= nil).to.equal(true)
				expect(slot.tile).to.equal(size)
				count += 1
			end
			for _ in UIAssets.paper do
				count -= 1
			end
			expect(count).to.equal(0)
		end)

		it("holds only PENDING or well-formed asset ids", function()
			for _, slot in UIAssets.paper do
				expect(PaperTextureViewModel.validId(slot.id)).to.equal(true)
			end
			expect(PaperTextureViewModel.validId("")).to.equal(true)
			expect(PaperTextureViewModel.validId("rbxassetid://123")).to.equal(true)
			expect(PaperTextureViewModel.validId("123")).to.equal(false)
			expect(PaperTextureViewModel.validId("rbxassetid://abc")).to.equal(false)
			expect(PaperTextureViewModel.validId("rbxassetid://")).to.equal(false)
		end)
	end)
end
```

- [ ] **Step 2: Controller: Studio TestEZ.** Expected: the new cases fail (`PaperTextureViewModel` missing).

- [ ] **Step 3: The slots.** In `UIAssets.luau` replace the `UIAssets.paper = ...` block with:

```lua
-- A tileable texture: its asset id (PENDING "" until the developer uploads it) and its size in px, the TileSize it
-- repeats at. PaperTexture draws nothing while an id is "", so every paper stays a flat colour until then.
export type Texture = { id: string, tile: Vector2 }

-- Cleanup Crew paper textures (M3b world UI; files in assets/ui/textures/). Paste each uploaded id as
-- "rbxassetid://<number>" (PaperTextureViewModel.spec checks the form).
local PAPER: { [string]: Texture } = {
	cream = table.freeze({ id = "", tile = Vector2.new(160, 160) }), -- paper-cream.png
	manila = table.freeze({ id = "", tile = Vector2.new(160, 160) }), -- paper-manila.png
	manilaDeep = table.freeze({ id = "", tile = Vector2.new(128, 128) }), -- paper-manila-deep.png
	sticky = table.freeze({ id = "", tile = Vector2.new(128, 128) }), -- paper-sticky.png
	cork = table.freeze({ id = "", tile = Vector2.new(192, 192) }), -- cork.png
	wood = table.freeze({ id = "", tile = Vector2.new(256, 128) }), -- wood.png
}
UIAssets.paper = table.freeze(PAPER)

-- The CCTV overlay's scanlines (M3 UI). PENDING and not drawn yet.
UIAssets.cctv = table.freeze({
	scanlines = "",
})
```

In `UIPaperConstants.luau`, under `cork`:

```lua
	-- The cork board's wood frame (Figma World UI 2a; picked from the export).
	wood = Color3.fromHex("4A2E1A"),
```

- [ ] **Step 4: `PaperTextureViewModel.luau`**

```lua
--!strict
--[=[
	PaperTextureViewModel: which tiled texture a paper colour gets (M3b world UI, the approved texture pass). A paper's
	colour names its material by hex (cream, manila, manilaDeep, sticky, cork, wood); the material's UIAssets.paper
	slot gives the image and the tile size. A PENDING slot ("") gives no layer, so the paper stays its flat colour. Pure.

	@class PaperTextureViewModel
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local UIAssets = require(ReplicatedStorage.Client.Features.UI.Data.UIAssets)
local UIPaperConstants = require(ReplicatedStorage.Client.UI.React.Screens.Paper.UIPaperConstants)

export type Material = "cream" | "manila" | "manilaDeep" | "sticky" | "cork" | "wood"
export type Layer = { image: string, tile: Vector2 }

local COLOR = UIPaperConstants.COLOR

local function hexOf(color: Color3): string
	return string.lower(color:ToHex())
end

local MATERIAL_BY_HEX: { [string]: Material } = {
	[hexOf(COLOR.cream)] = "cream",
	[hexOf(COLOR.manila)] = "manila",
	[hexOf(COLOR.manilaDeep)] = "manilaDeep",
	[hexOf(COLOR.sticky)] = "sticky",
	[hexOf(COLOR.cork)] = "cork",
	[hexOf(COLOR.wood)] = "wood",
}
table.freeze(MATERIAL_BY_HEX)

local PaperTextureViewModel = {}

function PaperTextureViewModel.materialOf(paper: Color3): Material?
	return MATERIAL_BY_HEX[hexOf(paper)]
end

function PaperTextureViewModel.layer(material: Material?, slots: { [string]: UIAssets.Texture }): Layer?
	-- Tested with `not` (the DepotStore note): comparing an optional singleton union against nil widens it.
	if not material then
		return nil
	end
	local slot = slots[material]
	if slot == nil or slot.id == "" then
		return nil
	end
	return { image = slot.id, tile = slot.tile }
end

-- The layer the game draws for a paper colour (UIAssets.paper).
function PaperTextureViewModel.forPaper(paper: Color3): Layer?
	return PaperTextureViewModel.layer(PaperTextureViewModel.materialOf(paper), UIAssets.paper)
end

-- PENDING ("") or an asset id of the form the developer pastes.
function PaperTextureViewModel.validId(id: string): boolean
	return id == "" or string.match(id, "^rbxassetid://%d+$") ~= nil
end

return PaperTextureViewModel
```

- [ ] **Step 5: `PaperTexture.luau`**

```lua
--!strict
--[=[
	PaperTexture: the tiled texture over a paper's flat colour (an ImageLabel filling its parent, ScaleType Tile at the
	texture's file size), or nothing while its slot is PENDING. Put it first inside the paper frame, under the content.
	Presentational; the choice is PaperTextureViewModel.forPaper.

	@class PaperTexture
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local PaperTextureViewModel = require(ReplicatedStorage.Client.UI.React.Screens.Paper.PaperTextureViewModel)

local e = React.createElement

export type PaperTextureProps = {
	paper: Color3,
	-- The paper's corner radius in px, so the texture keeps its rounded corners (0: square).
	corner: number?,
	zIndex: number?,
}

local function PaperTexture(props: PaperTextureProps): React.ReactNode
	local layer = PaperTextureViewModel.forPaper(props.paper)
	if layer == nil then
		return nil
	end
	local corner = props.corner or 0
	return e("ImageLabel", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Image = layer.image,
		ScaleType = Enum.ScaleType.Tile,
		TileSize = UDim2.fromOffset(layer.tile.X, layer.tile.Y),
		ZIndex = props.zIndex or 1,
	}, {
		corner = if corner > 0 then e("UICorner", { CornerRadius = UDim.new(0, corner) }) else nil,
	})
end

return PaperTexture
```

- [ ] **Step 6: Draw it in the kit.** In `PaperSheet.luau` require `PaperTexture` and:
  - in `paperChildren` add `texture = e(PaperTexture, { paper = paper, corner = 4, zIndex = 1 }),` (content, band and torn edge are already ZIndex 3);
  - in `tabOf`, add to the tab Frame's children `texture = e(PaperTexture, { paper = COLOR.manilaDeep, corner = 4, zIndex = 1 }),` and give its label `zIndex = 2`;
  - update the header: "Every visual is a plain Frame (no images...)" → "Every visual is a plain Frame plus, once uploaded, the paper's tiled texture (PaperTexture; flat colour while PENDING)".

  In `StickyNote.luau` require `PaperTexture` and add to the `note` Frame's children `texture = e(PaperTexture, { paper = COLOR.sticky, zIndex = 1 }),` (body is ZIndex 2, tape 3).

- [ ] **Step 7: `SpecRoots`.** Under "-- Cleanup Crew: the paper UI kit (M3 UI)":

```lua
	["ReplicatedStorage.Client.UI.React.Screens.Paper.PaperTexture"] = "presentational React component (the texture choice is specced in PaperTextureViewModel)",
```

- [ ] **Step 8: Controller: Studio TestEZ.** Expected: every `PaperTextureViewModel` case passes; `assertAllModulesSpecced` passes.

- [ ] **Step 9: Visual checkpoint (controller, edit mode, UI Labs):** open `Game UI → Screens → Paper → PaperKit`, `Shift → ShiftHudPanel` and `Depot → DepotBoardPanel`. They must look exactly as before (all slots PENDING). Then, in Studio's command bar, temporarily check the layer path with a known public texture: `local V = require(game.ReplicatedStorage.Client.UI.React.Screens.Paper.PaperTextureViewModel) print(V.layer("cork", { cork = { id = "rbxasset://textures/ui/GuiImagePlaceholder.png", tile = Vector2.new(192, 192) } }).image)` prints the path. Do not edit `UIAssets` for this.

- [ ] **Step 10: Gate and commit**

```bash
git add src
python3 scripts/python/module_map.py --write
git add docs/project-structure.md
stylua src/ReplicatedStorage/Client/Features/UI/Data/UIAssets.luau src/ReplicatedStorage/Client/UI/React/Screens/Paper/UIPaperConstants.luau src/ReplicatedStorage/Client/UI/React/Screens/Paper/PaperTextureViewModel.luau src/ReplicatedStorage/Client/UI/React/Screens/Paper/PaperTextureViewModel.spec.luau src/ReplicatedStorage/Client/UI/React/Screens/Paper/PaperTexture.luau src/ReplicatedStorage/Client/UI/React/Screens/Paper/PaperSheet.luau src/ReplicatedStorage/Client/UI/React/Screens/Paper/StickyNote.luau src/ServerScriptService/Core/Testing/SpecRoots.luau
git add src
PYTHONUTF8=1 bash .superpowers/sdd/gate.sh
python3 scripts/python/check_pr_rules.py origin/main
git commit -m "feat(ui): paper texture layer with pending texture slots"
python3 scripts/python/module_map.py --check
```

---

### Task 2: World kit pieces: cork board, tags, the billboard wrapper

Shared pieces every world sign uses: `CorkBoard` and `PaperTag` (both textured), a `scaled` option on `PaperLabel` (shrink long text into a fixed frame), and `WorldBillboard`, which maps a component's Figma px design onto its shell. Its maths is the specced `WorldBillboardViewModel`. The board scene switches to `CorkBoard`.

**Files:**
- Create: `src/ReplicatedStorage/Client/UI/React/Screens/World/WorldBillboardViewModel.luau`; Test: `.../World/WorldBillboardViewModel.spec.luau`
- Create: `src/ReplicatedStorage/Client/UI/React/Screens/World/WorldBillboard.luau`
- Create: `src/ReplicatedStorage/Client/UI/React/Screens/Paper/CorkBoard.luau`, `.../Paper/PaperTag.luau`
- Modify: `src/ReplicatedStorage/Client/UI/React/Screens/Paper/PaperLabel.luau` (`scaled`, `minSize`)
- Modify: `src/ReplicatedStorage/Client/UI/React/Screens/Depot/DepotBoardPanel.luau` (the board Frame → `CorkBoard`)
- Modify: `src/ReplicatedStorage/Client/UI/React/Screens/Paper/PaperKit.story.luau`
- Modify: `src/ServerScriptService/Core/Testing/SpecRoots.luau`

**Interfaces:**
- Consumes: `PaperTexture` (Task 1), `usePaperViewport() -> Vector2`.
- Produces:
  - `WorldBillboardViewModel.REFERENCE = Vector2.new(1920, 1080)`, `MIN_SCREEN_SCALE = 0.6`; `fit(absolute: Vector2, design: Vector2) -> number`; `screenScale(viewport: Vector2) -> number`; `clip(text: string, max: number) -> string`.
  - `WorldBillboard.Sizing = "studs" | "pixels"`; `WorldBillboard(props: { design: Vector2, sizing: Sizing, children: { [string]: React.ReactNode }? })`.
  - `CorkBoard(props: { size: UDim2, position: UDim2?, anchor: Vector2?, frame: number?, layoutOrder: number?, children: { [string]: React.ReactNode }? })`: children fill the whole board (wood included).
  - `PaperTag(props: { size: Vector2, paper: Color3, hole: "top" | "left", children: { [string]: React.ReactNode }? })`: children fill the tag's body.
  - `PaperLabelProps` gains `scaled: boolean?` (TextScaled between `minSize` and `size`) and `minSize: number?` (default `floor(size × 0.6)`).

- [ ] **Step 1: Write the failing spec** `WorldBillboardViewModel.spec.luau`:

```lua
local WorldBillboardViewModel = require(script.Parent.WorldBillboardViewModel)

local function near(a, b)
	return math.abs(a - b) < 1e-6
end

return function()
	describe("fit", function()
		it("scales the design to the shell's drawn size, by the tighter side", function()
			expect(WorldBillboardViewModel.fit(Vector2.new(170, 155), Vector2.new(340, 310))).to.equal(0.5)
			expect(near(WorldBillboardViewModel.fit(Vector2.new(680, 300), Vector2.new(340, 310)), 300 / 310)).to.equal(true)
		end)

		it("draws nothing for a shell with no size yet, and 1 for an empty design", function()
			expect(WorldBillboardViewModel.fit(Vector2.zero, Vector2.new(340, 310))).to.equal(0)
			expect(WorldBillboardViewModel.fit(Vector2.new(100, 100), Vector2.zero)).to.equal(1)
		end)
	end)

	describe("screenScale", function()
		it("is 1 on the 1920x1080 reference and never grows past it", function()
			expect(WorldBillboardViewModel.screenScale(Vector2.new(1920, 1080))).to.equal(1)
			expect(WorldBillboardViewModel.screenScale(Vector2.new(3840, 2160))).to.equal(1)
		end)

		it("shrinks with the smaller screen side", function()
			expect(near(WorldBillboardViewModel.screenScale(Vector2.new(1280, 720)), 2 / 3)).to.equal(true)
			expect(near(WorldBillboardViewModel.screenScale(Vector2.new(1366, 768)), 768 / 1080)).to.equal(true)
		end)

		it("keeps a phone's signs readable at 0.6", function()
			expect(WorldBillboardViewModel.screenScale(Vector2.new(844, 390))).to.equal(0.6)
			expect(WorldBillboardViewModel.screenScale(Vector2.new(0, 0))).to.equal(0.6)
		end)
	end)

	describe("clip", function()
		it("keeps text that fits", function()
			expect(WorldBillboardViewModel.clip("Employee of the Month plaque", 32)).to.equal("Employee of the Month plaque")
			expect(WorldBillboardViewModel.clip("", 4)).to.equal("")
		end)

		it("cuts longer text to the limit, ending in an ellipsis", function()
			local cut = WorldBillboardViewModel.clip(string.rep("a", 40), 32)
			expect(cut).to.equal(string.rep("a", 31) .. "…")
			expect(utf8.len(cut)).to.equal(32)
		end)

		it("cuts on a character boundary", function()
			expect(WorldBillboardViewModel.clip("Café Ünïcode", 5)).to.equal("Café…")
		end)

		it("reads broken UTF-8 as a question mark", function()
			expect(WorldBillboardViewModel.clip("\255\254", 10)).to.equal("?")
		end)
	end)
end
```

- [ ] **Step 2: Controller: Studio TestEZ.** Expected: the new cases fail (module missing).

- [ ] **Step 3: `WorldBillboardViewModel.luau`**

```lua
--!strict
--[=[
	WorldBillboardViewModel: the maths every world sign shares (M3b world UI). `fit` is the UIScale that maps a
	component's Figma px design onto a stud-sized shell's drawn size (it changes with distance); `screenScale` is the
	UIScale of a px-sized shell, by the screen against the 1920x1080 reference, never above 1 and never below 0.6 so a
	phone's signs stay readable; `clip` cuts text to a character limit with an ellipsis. Pure.

	@class WorldBillboardViewModel
]=]

local WorldBillboardViewModel = {}

WorldBillboardViewModel.REFERENCE = Vector2.new(1920, 1080)
WorldBillboardViewModel.MIN_SCREEN_SCALE = 0.6

function WorldBillboardViewModel.fit(absolute: Vector2, design: Vector2): number
	if design.X <= 0 or design.Y <= 0 then
		return 1
	end
	return math.max(0, math.min(absolute.X / design.X, absolute.Y / design.Y))
end

function WorldBillboardViewModel.screenScale(viewport: Vector2): number
	local reference = WorldBillboardViewModel.REFERENCE
	local ratio = math.min(viewport.X / reference.X, viewport.Y / reference.Y)
	return math.clamp(ratio, WorldBillboardViewModel.MIN_SCREEN_SCALE, 1)
end

-- At most `max` characters; a longer text keeps `max - 1` and ends in "…". Invalid UTF-8 reads "?".
function WorldBillboardViewModel.clip(text: string, max: number): string
	local length = utf8.len(text)
	if length == nil then
		return "?"
	end
	if length <= max then
		return text
	end
	local stop = utf8.offset(text, max)
	if stop == nil then
		return text
	end
	return string.sub(text, 1, stop - 1) .. "…"
end

return WorldBillboardViewModel
```

- [ ] **Step 4: `WorldBillboard.luau`** (presentational). Contract:
  - Renders a full-size transparent Frame filling the shell's root Frame, containing one child Frame `design` sized `UDim2.fromOffset(design.X, design.Y)`, anchored (0.5, 0.5) at (0.5, 0.5), with a `UIScale`, holding `props.children`.
  - `sizing = "studs"`: the outer Frame tracks its own `AbsoluteSize` with `React.Change.AbsoluteSize` into a binding; `UIScale.Scale = binding:map(function(size) return WorldBillboardViewModel.fit(size, design) end)` (no re-render per frame).
  - `sizing = "pixels"`: `UIScale.Scale = WorldBillboardViewModel.screenScale(usePaperViewport())`, and the shell is expected to be offset-sized at the design size (the scale shrinks it; it never grows past 1).
  - Header doc names both modes and points at the specced `WorldBillboardViewModel`.

- [ ] **Step 5: `CorkBoard.luau` and `PaperTag.luau`** (presentational).
  - `CorkBoard`: a Frame of `props.size` filled `COLOR.wood` with `PaperTexture { paper = COLOR.wood }`, a 4 px corner; inside it, inset by `props.frame or 20` px on every side, a Frame filled `COLOR.cork` with `PaperTexture { paper = COLOR.cork }` and a dark inner edge (a `UIStroke` 3 px `COLOR.night` at transparency 0.5, `ApplyStrokeMode = Border`). `children` are placed in a transparent Frame covering the whole board (ZIndex 3) so callers position cards over wood and cork alike.
  - `PaperTag`: `hole = "top"` (luggage tag): a Frame of `props.size` in `props.paper` with `PaperTexture`, 10 px corners, a drop shadow Frame (`COLOR.night`, transparency 0.5, offset (4, 6)), and a 22 px circular hole (`COLOR.office` fill, 3 px `COLOR.manilaDeep` ring) centred at x = width/2, y = 26. `hole = "left"` (price tag): body Frame of width `size.X - 22` at x 22 plus a 45°-rotated square of side `size.Y / √2` in the paper colour centred at (22, size.Y/2) forming the point, and an 12 px hole (`COLOR.office`) at (16, size.Y/2 − 6). Children fill the body (ZIndex 3).

- [ ] **Step 6: `PaperLabel`.** Add props `scaled: boolean?` and `minSize: number?`. When `scaled == true`: set `TextScaled = true` and add a `UITextSizeConstraint { MaxTextSize = size, MinTextSize = minSize or math.floor(size * 0.6) }` child; otherwise behaviour is unchanged. Update its header doc.

- [ ] **Step 7: `DepotBoardPanel`.** Replace the flat cork Frame (fill `UIPaperConstants.COLOR.cork`) with `e(CorkBoard, { size = <the same size>, position = <same>, anchor = <same>, frame = 12, children = <the same children> })`. Nothing else in the scene changes.

- [ ] **Step 8: `PaperKit.story`.** Add a row "World kit": a `CorkBoard` 600×420 with a pinned `PaperSheet`, a `PaperTag` with `hole = "top"` (340×250, manila) and one with `hole = "left"` (260×70, cream), and six swatches labelled by material showing "flat (PENDING)" or "textured" per `PaperTextureViewModel.forPaper`.

- [ ] **Step 9: `SpecRoots`.**

```lua
	["ReplicatedStorage.Client.UI.React.Screens.World.WorldBillboard"] = "presentational React wrapper (fit and screen scale specced in WorldBillboardViewModel)",
	["ReplicatedStorage.Client.UI.React.Screens.Paper.CorkBoard"] = "presentational React component (story in PaperKit.story; texture choice specced in PaperTextureViewModel)",
	["ReplicatedStorage.Client.UI.React.Screens.Paper.PaperTag"] = "presentational React component (story in PaperKit.story; texture choice specced in PaperTextureViewModel)",
```

- [ ] **Step 10: Controller: Studio TestEZ**, then UI Labs: `PaperKit` world-kit row matches the 2a/2b shapes; `DepotBoardPanel` shows the wood edge around the cork and is otherwise unchanged.

- [ ] **Step 11: Gate and commit**

```bash
git add src
python3 scripts/python/module_map.py --write
git add docs/project-structure.md
stylua src/ReplicatedStorage/Client/UI/React/Screens/World src/ReplicatedStorage/Client/UI/React/Screens/Paper/CorkBoard.luau src/ReplicatedStorage/Client/UI/React/Screens/Paper/PaperTag.luau src/ReplicatedStorage/Client/UI/React/Screens/Paper/PaperLabel.luau src/ReplicatedStorage/Client/UI/React/Screens/Paper/PaperKit.story.luau src/ReplicatedStorage/Client/UI/React/Screens/Depot/DepotBoardPanel.luau src/ServerScriptService/Core/Testing/SpecRoots.luau
git add src
PYTHONUTF8=1 bash .superpowers/sdd/gate.sh
python3 scripts/python/check_pr_rules.py origin/main
git commit -m "feat(ui): cork board, paper tags and the world billboard wrapper"
python3 scripts/python/module_map.py --check
```

---

### Task 3: Billboard roots: `UIBillboards` and `UIBillboardHost`

The world signs need one React root per BillboardGui shell for the shell's whole life: a refresh renders into the root it has, a shell that leaves (banked, destroyed, streamed out, untagged) loses its root exactly once. The bookkeeping is a pure core with an injected factory (the `UILayers` / `UILayerHost` split), so it is specced without a renderer. The host shell makes the real root (a child Frame `WorldRoot`, because a React root clears its container) and watches a CollectionService tag. `ReactRobloxRoot:unmount` is synchronous (it wraps `flushSync`), so unmounting inside `Destroying` runs while the shell's children can still be removed.

**Files:**
- Create: `src/ReplicatedStorage/Client/UI/Layers/UIBillboards.luau`; Test: `src/ReplicatedStorage/Client/UI/Layers/UIBillboards.spec.luau`
- Create: `src/ReplicatedStorage/Client/UI/Layers/UIBillboardHost.luau`
- Modify: `src/ServerScriptService/Core/Testing/SpecRoots.luau`

**Interfaces:**
- Consumes: `ReactRoblox.createRoot(container: Instance)` → `root:render(element)`, `root:unmount()` (synchronous); `CollectionService:GetTagged`, `:GetInstanceAddedSignal`, `:GetInstanceRemovedSignal`; `Instance.Destroying`, `Instance.AncestryChanged`, `Instance.AttributeChanged`.
- Produces:
  - `UIBillboards.BillboardHandle = { render: (element: React.ReactNode) -> (), unmount: () -> (), destroy: () -> () }`
  - `UIBillboards.BillboardFactory = (shell: BillboardGui) -> BillboardHandle`
  - `UIBillboards.UIBillboardsCore = { show: (shell: BillboardGui, element: React.ReactNode) -> (), hide: (shell: BillboardGui) -> (), teardown: () -> (), count: () -> number }`
  - `UIBillboards.new(factory: BillboardFactory) -> UIBillboardsCore`
  - `UIBillboardHost.factory: BillboardFactory` (child Frame `WorldRoot` filling the shell + a ReactRoblox root in it)
  - `UIBillboardHost.WatchOptions = { tag: string, roots: UIBillboards.UIBillboardsCore, refresh: (shell: BillboardGui) -> (), removed: ((shell: BillboardGui) -> ())? }`; `UIBillboardHost.watch(options: WatchOptions) -> () -> ()` (the stop function)

- [ ] **Step 1: Write the failing spec** `UIBillboards.spec.luau`:

```lua
--[=[
	Unit tests for the UIBillboards core: one React root per world shell, rendered in place, destroyed once on hide.
	The factory is a spy, so no renderer or Instance tree is needed; UIBillboardHost is the exempt real factory.
]=]

local UIBillboards = require(script.Parent.UIBillboards)

local function shellNamed(name)
	local shell = Instance.new("BillboardGui")
	shell.Name = name
	return shell
end

-- A spy factory: records every root made and every render / unmount / destroy, in order.
local function spyFactory()
	local record = { made = {}, events = {} }
	local factory = function(shell)
		local name = shell.Name
		table.insert(record.made, name)
		return {
			render = function(element)
				table.insert(record.events, `render:{name}:{tostring(element)}`)
			end,
			unmount = function()
				table.insert(record.events, `unmount:{name}`)
			end,
			destroy = function()
				table.insert(record.events, `destroy:{name}`)
			end,
		}
	end
	return factory, record
end

return function()
	describe("show", function()
		it("makes no root until a shell is shown", function()
			local factory, record = spyFactory()
			local roots = UIBillboards.new(factory)
			expect(#record.made).to.equal(0)
			expect(roots.count()).to.equal(0)
		end)

		it("makes a root on the first show and renders into it", function()
			local factory, record = spyFactory()
			local roots = UIBillboards.new(factory)
			roots.show(shellNamed("A"), "one")
			expect(#record.made).to.equal(1)
			expect(record.events[1]).to.equal("render:A:one")
			expect(roots.count()).to.equal(1)
		end)

		it("renders into the same root on every later show, never mounting twice", function()
			local factory, record = spyFactory()
			local roots = UIBillboards.new(factory)
			local shell = shellNamed("A")
			roots.show(shell, "one")
			roots.show(shell, "two")
			roots.show(shell, "three")
			expect(#record.made).to.equal(1)
			expect(record.events[2]).to.equal("render:A:two")
			expect(record.events[3]).to.equal("render:A:three")
			expect(roots.count()).to.equal(1)
		end)

		it("keeps one root per shell", function()
			local factory, record = spyFactory()
			local roots = UIBillboards.new(factory)
			roots.show(shellNamed("A"), "a")
			roots.show(shellNamed("B"), "b")
			expect(#record.made).to.equal(2)
			expect(roots.count()).to.equal(2)
		end)
	end)

	describe("hide", function()
		it("destroys a hidden shell's root and forgets it", function()
			local factory, record = spyFactory()
			local roots = UIBillboards.new(factory)
			local shell = shellNamed("A")
			roots.show(shell, "one")
			roots.hide(shell)
			expect(record.events[2]).to.equal("unmount:A")
			expect(record.events[3]).to.equal("destroy:A")
			expect(roots.count()).to.equal(0)
			-- Shown again later, it gets a fresh root.
			roots.show(shell, "two")
			expect(#record.made).to.equal(2)
		end)

		it("ignores a shell it never showed", function()
			local factory, record = spyFactory()
			local roots = UIBillboards.new(factory)
			roots.hide(shellNamed("A"))
			expect(#record.events).to.equal(0)
		end)

		it("destroys a root exactly once, even when hide runs again while it unmounts", function()
			local record = { destroyed = 0 }
			local roots
			local shell = shellNamed("A")
			roots = UIBillboards.new(function(_shell)
				return {
					render = function() end,
					-- The unmount re-enters hide, the way a Destroying handler can.
					unmount = function()
						roots.hide(shell)
					end,
					destroy = function()
						record.destroyed += 1
					end,
				}
			end)
			roots.show(shell, "one")
			roots.hide(shell)
			roots.hide(shell)
			expect(record.destroyed).to.equal(1)
			expect(roots.count()).to.equal(0)
		end)
	end)

	describe("teardown", function()
		it("destroys every root on teardown, in the order they were made", function()
			local factory, record = spyFactory()
			local roots = UIBillboards.new(factory)
			roots.show(shellNamed("A"), "a")
			roots.show(shellNamed("B"), "b")
			roots.teardown()
			expect(record.events[3]).to.equal("unmount:A")
			expect(record.events[4]).to.equal("destroy:A")
			expect(record.events[5]).to.equal("unmount:B")
			expect(record.events[6]).to.equal("destroy:B")
			expect(roots.count()).to.equal(0)
		end)

		it("is safe to call twice", function()
			local factory, record = spyFactory()
			local roots = UIBillboards.new(factory)
			roots.show(shellNamed("A"), "a")
			roots.teardown()
			roots.teardown()
			expect(#record.events).to.equal(3)
		end)
	end)
end
```

- [ ] **Step 2: Controller: Studio TestEZ.** Expected: the new cases fail (`UIBillboards` missing).

- [ ] **Step 3: `UIBillboards.luau`**

```lua
--!strict
--[=[
	UIBillboards: the pure bookkeeping core for world-sign roots (M3b world UI), the UILayers pattern for BillboardGui
	shells. One React root per shell for the shell's whole life: the first `show` makes it through the injected factory,
	every later `show` renders into the same root (a refresh never remounts, so a stamp does not re-pop and a memo does
	not restart typing), `hide` destroys it and forgets the shell, `teardown` destroys every root. The real
	Instance/ReactRoblox factory is UIBillboardHost.factory; the specs pass a spy.

	A hide forgets the shell BEFORE it unmounts, so a hide that re-enters while the root unmounts (a Destroying handler)
	is a no-op and the root is destroyed exactly once.

	@class UIBillboards
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)

--[=[
	One shell's live root, as the factory makes it. `render` draws into it; `unmount` tears the React tree down;
	`destroy` removes the root's container and MUST follow `unmount`.
]=]
export type BillboardHandle = {
	render: (element: React.ReactNode) -> (),
	unmount: () -> (),
	destroy: () -> (),
}

export type BillboardFactory = (shell: BillboardGui) -> BillboardHandle

export type UIBillboardsCore = {
	show: (shell: BillboardGui, element: React.ReactNode) -> (),
	hide: (shell: BillboardGui) -> (),
	teardown: () -> (),
	count: () -> number,
}

local UIBillboards = {}

function UIBillboards.new(factory: BillboardFactory): UIBillboardsCore
	local handles: { [BillboardGui]: BillboardHandle } = {}
	-- Creation order, so teardown is deterministic.
	local order: { BillboardGui } = {}

	local function show(shell: BillboardGui, element: React.ReactNode)
		local handle = handles[shell]
		if handle == nil then
			handle = factory(shell)
			handles[shell] = handle
			table.insert(order, shell)
		end
		handle.render(element)
	end

	local function hide(shell: BillboardGui)
		local handle = handles[shell]
		if handle == nil then
			return
		end
		-- Forgotten first: a hide that re-enters during the unmount finds nothing.
		handles[shell] = nil
		local index = table.find(order, shell)
		if index ~= nil then
			table.remove(order, index)
		end
		handle.unmount()
		handle.destroy()
	end

	local function teardown()
		local shells = table.clone(order)
		for _, shell in shells do
			hide(shell)
		end
	end

	local function count(): number
		return #order
	end

	return {
		show = show,
		hide = hide,
		teardown = teardown,
		count = count,
	}
end

return UIBillboards
```

- [ ] **Step 4: `UIBillboardHost.luau`**

```lua
--!strict
--[=[
	UIBillboardHost: the real Instance/ReactRoblox side of the world signs (M3b world UI), behind the specced UIBillboards
	core (the UILayerHost pattern).

	- `factory(shell)`: a child Frame "WorldRoot" filling the shell and a ReactRoblox root in it. A React root clears its
	  container, so it never mounts into the server-built shell itself. `unmount` is synchronous (ReactRobloxRoot wraps it
	  in flushSync); `destroy` removes the Frame.
	- `watch(options)`: every BillboardGui carrying `tag` (already tagged, or tagged later) gets `refresh(shell)` once and
	  again on each attribute change; the caller decides what to show (`roots.show`). A shell that leaves (untagged,
	  removed from the DataModel, streamed out, or destroyed, directly or with its part) is dropped once:
	  its connections are cut, `roots.hide(shell)` runs and then `removed(shell)`. `Destroying` fires before the
	  instance is destroyed, while its children can still be unmounted. Returns the stop function, which drops every
	  watched shell.

	Spec-exempt shell (ReactRoblox, CollectionService, Instance events); the root bookkeeping is the specced UIBillboards.

	@class UIBillboardHost
]=]

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local ReactRoblox = require(ReplicatedStorage.Packages.ReactRoblox)
local UIBillboards = require(ReplicatedStorage.Client.UI.Layers.UIBillboards)

export type WatchOptions = {
	tag: string,
	roots: UIBillboards.UIBillboardsCore,
	-- Draws (or re-draws) one shell: when it is first seen and whenever one of its attributes changes.
	refresh: (shell: BillboardGui) -> (),
	-- After a shell left and its root was hidden.
	removed: ((shell: BillboardGui) -> ())?,
}

local ROOT_NAME = "WorldRoot"

local UIBillboardHost = {}

function UIBillboardHost.factory(shell: BillboardGui): UIBillboards.BillboardHandle
	local container = Instance.new("Frame")
	container.Name = ROOT_NAME
	container.Size = UDim2.fromScale(1, 1)
	container.BackgroundTransparency = 1
	container.BorderSizePixel = 0
	container.Parent = shell
	local root = ReactRoblox.createRoot(container)
	return {
		render = function(element: React.ReactNode)
			root:render(element)
		end,
		unmount = function()
			root:unmount()
		end,
		destroy = function()
			container:Destroy()
		end,
	}
end

function UIBillboardHost.watch(options: WatchOptions): () -> ()
	local watched: { [BillboardGui]: { RBXScriptConnection } } = {}

	local function drop(shell: BillboardGui)
		local connections = watched[shell]
		if connections == nil then
			return
		end
		watched[shell] = nil
		for _, connection in connections do
			connection:Disconnect()
		end
		options.roots.hide(shell)
		local removed = options.removed
		if removed ~= nil then
			removed(shell)
		end
	end

	local function add(instance: Instance)
		if not instance:IsA("BillboardGui") then
			return
		end
		local shell: BillboardGui = instance
		if watched[shell] ~= nil then
			return
		end
		watched[shell] = {
			shell.AttributeChanged:Connect(function(_attribute: string)
				options.refresh(shell)
			end),
			shell.Destroying:Connect(function()
				drop(shell)
			end),
			shell.AncestryChanged:Connect(function()
				if not shell:IsDescendantOf(game) then
					drop(shell)
				end
			end),
		}
		options.refresh(shell)
	end

	local added = CollectionService:GetInstanceAddedSignal(options.tag):Connect(add)
	local removedSignal = CollectionService:GetInstanceRemovedSignal(options.tag):Connect(function(instance: Instance)
		if instance:IsA("BillboardGui") then
			drop(instance)
		end
	end)
	for _, instance in CollectionService:GetTagged(options.tag) do
		add(instance)
	end

	return function()
		added:Disconnect()
		removedSignal:Disconnect()
		local shells: { BillboardGui } = {}
		for shell in watched do
			table.insert(shells, shell)
		end
		for _, shell in shells do
			drop(shell)
		end
	end
end

return UIBillboardHost
```

- [ ] **Step 5: `SpecRoots`.** Next to the existing `UILayerHost` line:

```lua
	["ReplicatedStorage.Client.UI.Layers.UIBillboardHost"] = "Instance/ReactRoblox/CollectionService factory shell (the root bookkeeping UIBillboards core is specced)",
```

- [ ] **Step 6: Controller: Studio TestEZ**, then the unmount check. Expected TestEZ: every `UIBillboards` case passes; `assertAllModulesSpecced` passes.

  Unmount check (Review Focus 1), in a fresh Play (`RunTests = false`): the controller injects this temporary `LocalScript` into `StarterPlayer.StarterPlayerScripts` before Play, reads Output, then deletes it (never committed):

```lua
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local React = require(ReplicatedStorage.Packages.React)
local UIBillboards = require(ReplicatedStorage.Client.UI.Layers.UIBillboards)
local UIBillboardHost = require(ReplicatedStorage.Client.UI.Layers.UIBillboardHost)

task.wait(5)
local roots = UIBillboards.new(UIBillboardHost.factory)
local stop = UIBillboardHost.watch({
	tag = "UIBillboardProbe",
	roots = roots,
	refresh = function(shell)
		roots.show(shell, React.createElement("TextLabel", { Size = UDim2.fromScale(1, 1), Text = "probe" }))
	end,
})
local function probe(label, remove)
	local camera = Workspace.CurrentCamera
	local part = Instance.new("Part")
	part.Anchored = true
	part.Position = camera.CFrame.Position + camera.CFrame.LookVector * 10
	part.Parent = Workspace
	local shell = Instance.new("BillboardGui")
	shell.Size = UDim2.fromOffset(200, 60)
	shell.Parent = part
	CollectionService:AddTag(shell, "UIBillboardProbe")
	task.wait(0.5)
	print(label, "mounted", roots.count())
	remove(part)
	task.wait(0.5)
	print(label, "after", roots.count())
end
probe("destroy", function(part)
	part:Destroy()
end)
probe("unparent", function(part)
	part.Parent = nil
end)
stop()
print("probe done")
```

  Expected Output: `destroy mounted 1`, `destroy after 0`, `unparent mounted 1`, `unparent after 0`, `probe done`, and no error or warning from React / ReactRoblox (in particular no "The Parent property of … is locked"). **If anything errors, stop and report the exact Output; do not wrap `unmount` in a `pcall`.** (The server-destroyed path, a banked cargo item, is checked live in Task 6 Step 9.)

- [ ] **Step 7: Gate and commit**

```bash
git add src
python3 scripts/python/module_map.py --write
git add docs/project-structure.md
stylua src/ReplicatedStorage/Client/UI/Layers/UIBillboards.luau src/ReplicatedStorage/Client/UI/Layers/UIBillboards.spec.luau src/ReplicatedStorage/Client/UI/Layers/UIBillboardHost.luau src/ServerScriptService/Core/Testing/SpecRoots.luau
git add src
PYTHONUTF8=1 bash .superpowers/sdd/gate.sh
python3 scripts/python/check_pr_rules.py origin/main
git commit -m "feat(ui): one React root per world billboard shell"
python3 scripts/python/module_map.py --check
```

---

### Task 4: W1 truck pad tags

The server builds an empty, tagged shell over each truck bed (its truck number and seats written once) and stops rewriting pad text every 0.5 s; its tick only keeps each player's public `truck` field, as today. The client finds the truck's crew through Queue's state-synced snapshot and those public fields, builds the tag (`DepotWorldViewModel.truckTag`) every 0.25 s and renders it only when a drawn line changed.

**Files:**
- Modify: `src/ReplicatedStorage/Shared/Features/Depot/Data/DepotConstants.luau`
- Modify: `src/ServerScriptService/Features/Depot/Data/DepotLayoutConstants.luau` (`PAD_LABEL_SIZE` / `PAD_LABEL_OFFSET` → `PAD_TAG_OFFSET`, `LABEL_INTERVAL` → `TRUCK_INTERVAL`)
- Modify: `src/ServerScriptService/Features/Depot/Systems/DepotBuildSystem.luau` (truck tag shells; `BuiltTruck.label` removed)
- Modify: `src/ServerScriptService/Features/Depot/DepotServiceServer.luau` (`refreshLabels` → `refreshTrucks`, `padText` removed)
- Create: `src/ReplicatedStorage/Client/UI/React/Screens/World/DepotWorldViewModel.luau`; Test: `.../World/DepotWorldViewModel.spec.luau`
- Create: `src/ReplicatedStorage/Client/UI/React/Screens/World/DepotTruckTag.luau`
- Create: `src/ReplicatedStorage/Client/Features/Depot/Systems/DepotBillboardSystem.luau`
- Modify: `src/ReplicatedStorage/Client/Features/Depot/DepotServiceClient.luau`
- Create: `src/ReplicatedStorage/Client/UI/React/Screens/World/DepotWorld.story.luau`
- Modify: `src/ServerScriptService/Core/Testing/SpecRoots.luau`

**Interfaces:**
- Consumes: `UIBillboards.new`, `UIBillboardHost.factory`, `UIBillboardHost.watch` (Task 3); `WorldBillboard` (`design`, `sizing = "studs"`), `PaperTag` (`hole = "top"`), `PaperLabel` (`scaled`) (Task 2); `QueueStore.snapshot(): QueueTypes.QueueSnapshot?`; `StateSyncClientStore.publicPlayers(): PublicPlayerTypes.PublicPlayerMap`; `StateSyncConstants.publicEntryKey(userId): string`; `DepotConstants.PUBLIC_TRUCK`; `ShiftHudViewModel.clock(seconds): string`; `QueueServiceServer:padOf(player): BasePart?`.
- Produces:
  - `DepotConstants.STUDS_PER_PX = 1 / 40`; `DepotConstants.BILLBOARD_PX = { truck = Vector2.new(340, 310), contract = Vector2.new(600, 420), result = Vector2.new(1140, 446) }`; `DepotConstants.BILLBOARD_TAGS = { truck = "DepotTruckTag", contract = "DepotContractBoard", result = "DepotResultBoard", review = "DepotReviewCard" }`; `DepotConstants.TRUCK_ATTRIBUTE = "DepotTruck"`, `CAPACITY_ATTRIBUTE = "DepotCapacity"`, `TAG_WARN_SECONDS = 10`.
  - `DepotLayoutConstants.PAD_TAG_OFFSET = Vector3.new(0, 8, 0)`, `TRUCK_INTERVAL = 0.5`.
  - `DepotBuildSystem.BuiltTruck = { id: string, index: number, capacity: number, pad: BasePart }`.
  - `DepotWorldViewModel.TruckTagView = { title: string, seats: { boolean }, count: string, line: string, warn: boolean }`; `truckTag(truck: number, capacity: number, pad: QueueTypes.PadSnapshot?, now: number) -> TruckTagView`; `padFor(snapshot: QueueTypes.QueueSnapshot?, truck: number, players: PublicPlayerTypes.PublicPlayerMap) -> QueueTypes.PadSnapshot?`; `sameTag(a: TruckTagView?, b: TruckTagView?) -> boolean`.
  - `DepotTruckTag(props: { view: DepotWorldViewModel.TruckTagView })`, drawn at 340×310.
  - `DepotBillboardSystem.start()`, `.stop()`, `.getState() -> { mounted: number, trucks: number, reviews: number }` (`reviews` is 0 until Task 5).

- [ ] **Step 1: Write the failing spec** `DepotWorldViewModel.spec.luau`:

```lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DepotWorldViewModel = require(script.Parent.DepotWorldViewModel)
local DepotConstants = require(ReplicatedStorage.Shared.Features.Depot.Data.DepotConstants)

local NOW = 1000

-- A queue pad snapshot: `left` seconds on its countdown (nil: no countdown), optionally departing.
local function pad(members, left, departing)
	return {
		members = members,
		capacity = 4,
		destination = "shift",
		endsAt = if left ~= nil then NOW + left else nil,
		departing = departing == true,
	}
end

-- The public player map, from userId -> truck number.
local function players(trucks)
	local map = {}
	for userId, truck in trucks do
		map[tostring(userId)] = { [DepotConstants.PUBLIC_TRUCK] = truck }
	end
	return map
end

return function()
	describe("truckTag", function()
		it("shows an empty truck with open seats and how to join", function()
			local tag = DepotWorldViewModel.truckTag(1, 4, nil, NOW)
			expect(tag.title).to.equal("TRUCK 1")
			expect(#tag.seats).to.equal(4)
			for _, filled in tag.seats do
				expect(filled).to.equal(false)
			end
			expect(tag.count).to.equal("0 / 4 ABOARD")
			expect(tag.line).to.equal("Stand in the bed to join")
			expect(tag.warn).to.equal(false)
		end)

		it("fills a seat per player aboard and keeps the join line while time is left", function()
			local tag = DepotWorldViewModel.truckTag(2, 4, pad({ 11, 12 }, 15), NOW)
			expect(tag.seats[1]).to.equal(true)
			expect(tag.seats[2]).to.equal(true)
			expect(tag.seats[3]).to.equal(false)
			expect(tag.seats[4]).to.equal(false)
			expect(tag.count).to.equal("2 / 4 ABOARD")
			expect(tag.line).to.equal("Stand in the bed to join")
			expect(tag.warn).to.equal(false)
		end)

		it("counts down in red when the truck is full", function()
			local tag = DepotWorldViewModel.truckTag(3, 4, pad({ 1, 2, 3, 4 }, 8), NOW)
			expect(tag.count).to.equal("4 / 4 ABOARD")
			expect(tag.line).to.equal("Leaving in 0:08")
			expect(tag.warn).to.equal(true)
		end)

		it("counts down in red once TAG_WARN_SECONDS or fewer remain", function()
			local warn = DepotConstants.TAG_WARN_SECONDS
			local at = DepotWorldViewModel.truckTag(1, 4, pad({ 1 }, warn), NOW)
			expect(at.line).to.equal(`Leaving in 0:{string.format("%02d", warn)}`)
			expect(at.warn).to.equal(true)
			local before = DepotWorldViewModel.truckTag(1, 4, pad({ 1 }, warn + 0.5), NOW)
			expect(before.line).to.equal("Stand in the bed to join")
			expect(before.warn).to.equal(false)
		end)

		it("says the truck is leaving while it departs", function()
			local tag = DepotWorldViewModel.truckTag(2, 4, pad({ 1, 2 }, nil, true), NOW)
			expect(tag.line).to.equal("Leaving now")
			expect(tag.warn).to.equal(true)
		end)

		it("never counts below 0:00", function()
			local tag = DepotWorldViewModel.truckTag(2, 4, pad({ 1, 2, 3, 4 }, -3), NOW)
			expect(tag.line).to.equal("Leaving in 0:00")
		end)
	end)

	describe("padFor", function()
		it("finds the pad whose crew stand in the truck", function()
			local snapshot = { pads = { a = pad({ 11 }, 10), b = pad({ 21, 22 }, 12) } }
			local found = DepotWorldViewModel.padFor(snapshot, 2, players({ [11] = 1, [21] = 2, [22] = 2 }))
			expect(found).to.equal(snapshot.pads.b)
		end)

		it("finds nothing for an empty truck, no snapshot, or crew without a truck field", function()
			local snapshot = { pads = { a = pad({ 11 }, 10) } }
			expect(DepotWorldViewModel.padFor(snapshot, 3, players({ [11] = 1 }))).to.equal(nil)
			expect(DepotWorldViewModel.padFor(nil, 1, players({ [11] = 1 }))).to.equal(nil)
			expect(DepotWorldViewModel.padFor(snapshot, 1, {})).to.equal(nil)
		end)
	end)

	describe("sameTag", function()
		it("is the same tag only when every drawn line matches", function()
			local a = DepotWorldViewModel.truckTag(2, 4, pad({ 1, 2 }, 9), NOW)
			expect(DepotWorldViewModel.sameTag(a, DepotWorldViewModel.truckTag(2, 4, pad({ 1, 2 }, 9), NOW))).to.equal(true)
			-- 0.2 s later the clock still reads 0:09: nothing to re-render.
			expect(DepotWorldViewModel.sameTag(a, DepotWorldViewModel.truckTag(2, 4, pad({ 1, 2 }, 9), NOW + 0.2))).to.equal(
				true
			)
			expect(DepotWorldViewModel.sameTag(a, DepotWorldViewModel.truckTag(2, 4, pad({ 1, 2 }, 8), NOW))).to.equal(false)
			expect(DepotWorldViewModel.sameTag(a, DepotWorldViewModel.truckTag(2, 4, pad({ 1, 2, 3 }, 9), NOW))).to.equal(
				false
			)
			expect(DepotWorldViewModel.sameTag(a, DepotWorldViewModel.truckTag(1, 4, pad({ 1, 2 }, 9), NOW))).to.equal(false)
			expect(DepotWorldViewModel.sameTag(nil, a)).to.equal(false)
			expect(DepotWorldViewModel.sameTag(a, nil)).to.equal(false)
			expect(DepotWorldViewModel.sameTag(nil, nil)).to.equal(true)
		end)
	end)
end
```

- [ ] **Step 2: Controller: Studio TestEZ.** Expected: the new cases fail (`DepotWorldViewModel` missing).

- [ ] **Step 3: Constants.** In `DepotConstants.luau`, inside the returned table after `RETURN_TEXT`:

```lua
	-- M3b world UI. The depot's signs are drawn at Figma's "1 px ≈ 1/40 stud": a shell's size in studs is its design
	-- size in px times STUDS_PER_PX. BILLBOARD_PX is each sign's design size (the truck tag includes its 60 px wire).
	STUDS_PER_PX = 1 / 40,
	BILLBOARD_PX = table.freeze({
		truck = Vector2.new(340, 310),
		contract = Vector2.new(600, 420),
		result = Vector2.new(1140, 446),
	}),
	-- The tags the client finds each kind of depot shell by (DepotBillboardSystem); `review` is your own card's shell.
	BILLBOARD_TAGS = table.freeze({
		truck = "DepotTruckTag",
		contract = "DepotContractBoard",
		result = "DepotResultBoard",
		review = "DepotReviewCard",
	}),
	-- A truck tag shell's truck number and seats, written once by the server.
	TRUCK_ATTRIBUTE = "DepotTruck",
	CAPACITY_ATTRIBUTE = "DepotCapacity",
	-- A truck tag's line 3 turns red ("Leaving in 0:08") when the truck is full or this many seconds or fewer remain.
	TAG_WARN_SECONDS = 10,
```

  In `DepotLayoutConstants.luau` replace

```lua
	-- How often the pad labels recount who is aboard (seconds).
	LABEL_INTERVAL = 0.5,
	-- Billboard sizes are in studs (BillboardGui scale); offsets from the part's centre.
	PAD_LABEL_SIZE = Vector2.new(8, 3),
	PAD_LABEL_OFFSET = Vector3.new(0, 7, 0),
```

  with

```lua
	-- How often each player's public `truck` field is checked against the bed they stand in (seconds).
	TRUCK_INTERVAL = 0.5,
	-- World sign shells are sized from their design (DepotConstants.BILLBOARD_PX); offsets from the part's centre.
	PAD_TAG_OFFSET = Vector3.new(0, 8, 0),
```

- [ ] **Step 4: `DepotWorldViewModel.luau`**

```lua
--!strict
--[=[
	DepotWorldViewModel: what the depot's world signs say (Figma World UI 2a). The truck pad tag (W1): "TRUCK n", a seat
	per place (filled = aboard), "n / 4 ABOARD" and line 3: the red "Leaving in m:ss" when the truck is full or
	DepotConstants.TAG_WARN_SECONDS or fewer remain, "Leaving now" while it departs, else how to join. `padFor` finds the
	Queue pad whose crew stand in a truck (by their public `truck` field); `sameTag` says whether two tags draw the same,
	so an unchanged tag is not re-rendered. Pure.

	@class DepotWorldViewModel
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PublicPlayerTypes = require(ReplicatedStorage.Shared.Data.PublicPlayerTypes)
local DepotConstants = require(ReplicatedStorage.Shared.Features.Depot.Data.DepotConstants)
local QueueTypes = require(ReplicatedStorage.Shared.Features.Queue.Data.QueueTypes)
local StateSyncConstants = require(ReplicatedStorage.Shared.Features.StateSync.Data.StateSyncConstants)
local ShiftHudViewModel = require(ReplicatedStorage.Client.UI.React.Screens.Shift.ShiftHudViewModel)

export type TruckTagView = {
	title: string,
	seats: { boolean },
	count: string,
	line: string,
	warn: boolean,
}

local JOIN_LINE = "Stand in the bed to join"
local LEAVING_NOW = "Leaving now"

local DepotWorldViewModel = {}

function DepotWorldViewModel.truckTag(
	truck: number,
	capacity: number,
	pad: QueueTypes.PadSnapshot?,
	now: number
): TruckTagView
	local aboard = if pad ~= nil then #pad.members else 0
	local seats: { boolean } = {}
	for seat = 1, capacity do
		table.insert(seats, seat <= aboard)
	end
	local endsAt = if pad ~= nil then pad.endsAt else nil
	local line = JOIN_LINE
	local warn = false
	if pad ~= nil and pad.departing then
		line = LEAVING_NOW
		warn = true
	elseif endsAt ~= nil then
		local left = endsAt - now
		if aboard >= capacity or left <= DepotConstants.TAG_WARN_SECONDS then
			line = `Leaving in {ShiftHudViewModel.clock(left)}`
			warn = true
		end
	end
	return {
		title = `TRUCK {truck}`,
		seats = seats,
		count = `{aboard} / {capacity} ABOARD`,
		line = line,
		warn = warn,
	}
end

-- The Queue pad of `truck`: the first pad with a member whose public `truck` field names it; nil when nobody is aboard.
function DepotWorldViewModel.padFor(
	snapshot: QueueTypes.QueueSnapshot?,
	truck: number,
	players: PublicPlayerTypes.PublicPlayerMap
): QueueTypes.PadSnapshot?
	if snapshot == nil then
		return nil
	end
	for _, pad in snapshot.pads do
		for _, userId in pad.members do
			local entry = players[StateSyncConstants.publicEntryKey(userId)]
			if entry ~= nil and entry[DepotConstants.PUBLIC_TRUCK] == truck then
				return pad
			end
		end
	end
	return nil
end

function DepotWorldViewModel.sameTag(a: TruckTagView?, b: TruckTagView?): boolean
	if a == nil or b == nil then
		return a == nil and b == nil
	end
	if a.title ~= b.title or a.count ~= b.count or a.line ~= b.line or a.warn ~= b.warn or #a.seats ~= #b.seats then
		return false
	end
	for index, filled in a.seats do
		if b.seats[index] ~= filled then
			return false
		end
	end
	return true
end

return DepotWorldViewModel
```

- [ ] **Step 5: `DepotTruckTag.luau`**

```lua
--!strict
--[=[
	DepotTruckTag: the truck pad tag (Figma World UI 2a, W1) at its 340x310 design size: a 60 px wire down to a 340x250
	manila luggage tag (PaperTag, hole at the top), "TRUCK n" (Oswald 64), a punched seat per place (Ø32, 14 apart;
	filled = aboard), "n / 4 ABOARD" (Oswald 26) and line 3 (Special Elite 20, stamp red when `warn`). Presentational;
	the words and the warn rule are DepotWorldViewModel.truckTag.

	@class DepotTruckTag
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local PaperLabel = require(ReplicatedStorage.Client.UI.React.Screens.Paper.PaperLabel)
local PaperTag = require(ReplicatedStorage.Client.UI.React.Screens.Paper.PaperTag)
local UIPaperConstants = require(ReplicatedStorage.Client.UI.React.Screens.Paper.UIPaperConstants)
local DepotWorldViewModel = require(ReplicatedStorage.Client.UI.React.Screens.World.DepotWorldViewModel)

local e = React.createElement

export type DepotTruckTagProps = {
	view: DepotWorldViewModel.TruckTagView,
}

local COLOR = UIPaperConstants.COLOR
local WIRE = 60
local TAG = Vector2.new(340, 250)
local SEAT = 32
local SEAT_GAP = 14

-- One centred line on the tag body, shrunk into its frame when long.
local function line(text: string, role: PaperLabel.Role, size: number, color: Color3, y: number, height: number): React.ReactNode
	return e(PaperLabel, {
		text = text,
		role = role,
		size = size,
		color = color,
		align = "center",
		position = UDim2.fromOffset(16, y),
		frame = UDim2.new(1, -32, 0, height),
		autoSize = false,
		wrapped = false,
		scaled = true,
	})
end

local function seatsOf(seats: { boolean }): React.ReactNode
	local children: { [string]: React.ReactNode } = {
		layout = e("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			Padding = UDim.new(0, SEAT_GAP),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	}
	for index, filled in seats do
		children[`seat{index}`] = e("Frame", {
			LayoutOrder = index,
			Size = UDim2.fromOffset(SEAT, SEAT),
			BackgroundColor3 = COLOR.ink,
			BackgroundTransparency = if filled then 0 else 1,
			BorderSizePixel = 0,
		}, {
			corner = e("UICorner", { CornerRadius = UDim.new(0.5, 0) }),
			ring = e("UIStroke", {
				Color = COLOR.ink,
				Thickness = 3,
				ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			}),
		})
	end
	return e("Frame", {
		Position = UDim2.fromOffset(0, 132),
		Size = UDim2.new(1, 0, 0, SEAT),
		BackgroundTransparency = 1,
	}, children)
end

local function DepotTruckTag(props: DepotTruckTagProps): React.ReactNode
	local view = props.view
	local body: { [string]: React.ReactNode } = {
		title = line(view.title, "heading", 64, COLOR.ink, 48, 76),
		seats = seatsOf(view.seats),
		count = line(view.count, "heading", 26, COLOR.ink, 176, 32),
		line = line(view.line, "body", 20, if view.warn then COLOR.stamp else COLOR.ink, 210, 28),
	}
	return e("Frame", {
		Size = UDim2.fromOffset(TAG.X, WIRE + TAG.Y),
		BackgroundTransparency = 1,
	}, {
		wire = e("Frame", {
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.fromScale(0.5, 0),
			Size = UDim2.fromOffset(3, WIRE),
			BackgroundColor3 = COLOR.slotEmpty,
			BorderSizePixel = 0,
		}),
		tag = e("Frame", {
			Position = UDim2.fromOffset(0, WIRE),
			Size = UDim2.fromOffset(TAG.X, TAG.Y),
			BackgroundTransparency = 1,
		}, {
			paper = e(PaperTag, { size = TAG, paper = COLOR.manila, hole = "top" }, body),
		}),
	})
end

return DepotTruckTag
```

- [ ] **Step 6: The server shells.** In `DepotBuildSystem.luau`:
  - `BuiltTruck` loses `label: TextLabel`.
  - Add, after `folder`:

```lua
-- An empty world-sign shell over `adornee` (M3b world UI), sized in studs from its Figma design (`design` px times
-- DepotConstants.STUDS_PER_PX). The client draws into it (DepotBillboardSystem). The caller writes its attributes, then
-- tags and parents it. Returned unparented.
local function shell(name: string, adornee: BasePart, design: Vector2, offset: Vector3): BillboardGui
	local gui = Instance.new("BillboardGui")
	gui.Name = name
	gui.Adornee = adornee
	local studs = design * DepotConstants.STUDS_PER_PX
	gui.Size = UDim2.fromScale(studs.X, studs.Y)
	gui.StudsOffset = offset
	gui.MaxDistance = DepotLayoutConstants.LABEL_MAX_DISTANCE
	gui.LightInfluence = 0
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	return gui
end
```

  - In `build`, replace the truck's `local gui, label = billboard("PadLabel", …)` block and its `table.insert` with:

```lua
		local tag = shell("PadTag", pad, DepotConstants.BILLBOARD_PX.truck, DepotLayoutConstants.PAD_TAG_OFFSET)
		tag:SetAttribute(DepotConstants.TRUCK_ATTRIBUTE, index)
		tag:SetAttribute(DepotConstants.CAPACITY_ATTRIBUTE, truck.capacity)
		CollectionService:AddTag(tag, DepotConstants.BILLBOARD_TAGS.truck)
		tag.Parent = truckFolder
		table.insert(trucks, { id = truck.id, index = index, capacity = truck.capacity, pad = pad })
```

  - Header: "…a cab behind it and a label above it;" → "…a cab behind it and an empty truck tag shell above it (tagged, its truck number and seats as attributes; the client draws it);".

  In `DepotServiceServer.luau`:
  - Delete `padText`. Replace `refreshLabels` with:

```lua
-- Keeps each player's public `truck` field on the truck bed they stand in (Queue's membership); written on change.
-- The truck tags themselves are drawn by the client from Queue's state sync and these fields (DepotBillboardSystem).
local function refreshTrucks()
	if built == nil then
		return
	end
	for _, player in Players:GetPlayers() do
		local pad = QueueServiceServer:padOf(player)
		local index = if pad ~= nil then truckIndexOf(pad) else nil
		if index ~= truckOf[player.UserId] then
			if index ~= nil then
				truckOf[player.UserId] = index
				StateSyncPublicPlayerStore.set(player.UserId, { [DepotConstants.PUBLIC_TRUCK] = index })
			else
				truckOf[player.UserId] = nil
				StateSyncPublicPlayerStore.clearField(player.UserId, DepotConstants.PUBLIC_TRUCK)
			end
		end
	end
end
```

  - In `start`: `refreshLabels()` → `refreshTrucks()` (both calls), `DepotLayoutConstants.LABEL_INTERVAL` → `DepotLayoutConstants.TRUCK_INTERVAL`.
  - Header: "…the result board, and a label over each truck counting who is aboard (QueueServiceServer:padOf; Queue's own HUD widget shows the countdown to those aboard)." → "…the result board, and a tag shell over each truck that every client draws from Queue's state sync and the public `truck` field this service keeps (DepotBillboardSystem)."

- [ ] **Step 7: `DepotBillboardSystem.luau`**

```lua
--!strict
--[=[
	DepotBillboardSystem: draws the depot's world signs on this client (Figma World UI 2a). The server builds each sign
	as an empty tagged shell (DepotBuildSystem); this watches the tags (UIBillboardHost.watch) and keeps one React root
	per shell (UIBillboards). Truck tags (W1): the crew and the countdown come from Queue's state-synced snapshot and each
	player's public `truck` field; every TICK_SECONDS each tag is rebuilt (DepotWorldViewModel.truckTag) and rendered
	only when a drawn line changed (`sameTag`), so the countdown re-renders once a second and nothing remounts.

	Spec-exempt shell (CollectionService, RunService, React roots); the decisions are the specced DepotWorldViewModel and
	the UIBillboards core.

	@class DepotBillboardSystem
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local React = require(ReplicatedStorage.Packages.React)
local DepotConstants = require(ReplicatedStorage.Shared.Features.Depot.Data.DepotConstants)
local QueueStore = require(ReplicatedStorage.Client.Features.Queue.State.QueueStore)
local StateSyncClientStore = require(ReplicatedStorage.Client.Features.StateSync.State.StateSyncClientStore)
local UIBillboardHost = require(ReplicatedStorage.Client.UI.Layers.UIBillboardHost)
local UIBillboards = require(ReplicatedStorage.Client.UI.Layers.UIBillboards)
local DepotTruckTag = require(ReplicatedStorage.Client.UI.React.Screens.World.DepotTruckTag)
local DepotWorldViewModel = require(ReplicatedStorage.Client.UI.React.Screens.World.DepotWorldViewModel)
local WorldBillboard = require(ReplicatedStorage.Client.UI.React.Screens.World.WorldBillboard)

export type DepotBillboardState = {
	mounted: number,
	trucks: number,
	reviews: number,
}

local e = React.createElement

local TAGS = DepotConstants.BILLBOARD_TAGS
local PX = DepotConstants.BILLBOARD_PX
local TICK_SECONDS = 0.25

local roots = UIBillboards.new(UIBillboardHost.factory)
local trucks: { [BillboardGui]: true } = {}
-- The tag each truck shell last rendered, so an unchanged tag is skipped.
local drawn: { [BillboardGui]: DepotWorldViewModel.TruckTagView } = {}
local stoppers: { () -> () } = {}

local function sign(design: Vector2, child: React.ReactNode): React.ReactNode
	return e(WorldBillboard, { design = design, sizing = "studs" }, { sign = child })
end

local function drawTruck(shell: BillboardGui)
	local truck = shell:GetAttribute(DepotConstants.TRUCK_ATTRIBUTE)
	local capacity = shell:GetAttribute(DepotConstants.CAPACITY_ATTRIBUTE)
	if type(truck) ~= "number" or type(capacity) ~= "number" then
		return
	end
	local pad = DepotWorldViewModel.padFor(QueueStore.snapshot(), truck, StateSyncClientStore.publicPlayers())
	local view = DepotWorldViewModel.truckTag(truck, capacity, pad, Workspace:GetServerTimeNow())
	if DepotWorldViewModel.sameTag(drawn[shell], view) then
		return
	end
	drawn[shell] = view
	roots.show(shell, sign(PX.truck, e(DepotTruckTag, { view = view })))
end

local function count(set: { [BillboardGui]: true }): number
	local total = 0
	for _ in set do
		total += 1
	end
	return total
end

local function watch(
	tag: string,
	refresh: (shell: BillboardGui) -> (),
	removed: ((shell: BillboardGui) -> ())?
)
	table.insert(
		stoppers,
		UIBillboardHost.watch({ tag = tag, roots = roots, refresh = refresh, removed = removed })
	)
end

local DepotBillboardSystem = {}

function DepotBillboardSystem.start()
	if #stoppers > 0 then
		return
	end
	watch(TAGS.truck, function(shell)
		trucks[shell] = true
		-- An attribute change redraws even an unchanged tag.
		drawn[shell] = nil
		drawTruck(shell)
	end, function(shell)
		trucks[shell] = nil
		drawn[shell] = nil
	end)
	local elapsed = 0
	local ticking = RunService.Heartbeat:Connect(function(deltaTime: number)
		elapsed += deltaTime
		if elapsed < TICK_SECONDS then
			return
		end
		elapsed = 0
		for shell in trucks do
			drawTruck(shell)
		end
	end)
	table.insert(stoppers, function()
		ticking:Disconnect()
	end)
end

function DepotBillboardSystem.stop()
	for _, stop in stoppers do
		stop()
	end
	table.clear(stoppers)
	roots.teardown()
	table.clear(trucks)
	table.clear(drawn)
end

function DepotBillboardSystem.getState(): DepotBillboardState
	return { mounted = roots.count(), trucks = count(trucks), reviews = 0 }
end

return DepotBillboardSystem
```

  In `DepotServiceClient.luau`: require `ReplicatedStorage.Client.Features.Depot.Systems.DepotBillboardSystem`; dependencies become `{ "QueueServiceClient", "StateSyncServiceClient" }`; at the end of `start` add `DepotBillboardSystem.start()`; at the top of `stop` add `DepotBillboardSystem.stop()`; `getState` returns `{ card = …, signs = DepotBillboardSystem.getState().mounted }`. Header: "…the boards and truck labels are world billboards the server builds." → "…the depot's world signs (truck tags, the boards) are drawn by DepotBillboardSystem into the shells the server builds."

- [ ] **Step 8: `DepotWorld.story.luau`**

```lua
--!strict
--[=[
	DepotWorld.story: the depot's world signs (Figma World UI 2a) at their design size over the dark depot, in Studio's
	edit mode (UI Labs). Each sign is drawn through WorldBillboard in a frame of its design size times `Scale` (a sign
	seen from further away). Truck 1 is empty, truck 2 has `Aboard` crew and `SecondsLeft` on its clock (or `Departing`),
	truck 3 is full with 8 s left.

	@class DepotWorld.story
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local ReactRoblox = require(ReplicatedStorage.Packages.ReactRoblox)
local UILabs = require(ReplicatedStorage.DevPackages.UILabs)
local DepotConstants = require(ReplicatedStorage.Shared.Features.Depot.Data.DepotConstants)
local QueueTypes = require(ReplicatedStorage.Shared.Features.Queue.Data.QueueTypes)
local UIPaperConstants = require(ReplicatedStorage.Client.UI.React.Screens.Paper.UIPaperConstants)
local DepotTruckTag = require(ReplicatedStorage.Client.UI.React.Screens.World.DepotTruckTag)
local DepotWorldViewModel = require(ReplicatedStorage.Client.UI.React.Screens.World.DepotWorldViewModel)
local WorldBillboard = require(ReplicatedStorage.Client.UI.React.Screens.World.WorldBillboard)

local e = React.createElement

local NOW = 1000
local PX = DepotConstants.BILLBOARD_PX

-- A sign through the real wrapper, in a frame of its design size times `scale` (fit = scale).
local function sign(order: number, design: Vector2, scale: number, child: React.ReactNode): React.ReactNode
	return e("Frame", {
		LayoutOrder = order,
		Size = UDim2.fromOffset(design.X * scale, design.Y * scale),
		BackgroundTransparency = 1,
	}, {
		billboard = e(WorldBillboard, { design = design, sizing = "studs" }, { sign = child }),
	})
end

local function row(order: number, children: { [string]: React.ReactNode }): React.ReactNode
	local content: { [string]: React.ReactNode } = {
		layout = e("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			VerticalAlignment = Enum.VerticalAlignment.Top,
			Padding = UDim.new(0, 40),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	}
	for key, node in children do
		content[key] = node
	end
	return e("Frame", {
		LayoutOrder = order,
		Size = UDim2.fromOffset(0, 0),
		AutomaticSize = Enum.AutomaticSize.XY,
		BackgroundTransparency = 1,
	}, content)
end

local function truckSign(order: number, truck: number, pad: QueueTypes.PadSnapshot?, scale: number): React.ReactNode
	local view = DepotWorldViewModel.truckTag(truck, 4, pad, NOW)
	return sign(order, PX.truck, scale, e(DepotTruckTag, { view = view }))
end

return UILabs.CreateReactStory({
	react = React,
	reactRoblox = ReactRoblox,
	controls = {
		Aboard = 2,
		SecondsLeft = 12,
		Departing = false,
		Scale = 1,
	},
}, function(props)
	local aboard: number = math.clamp(math.floor(props.controls.Aboard), 0, 4)
	local secondsLeft: number = props.controls.SecondsLeft
	local departing: boolean = props.controls.Departing
	local scale: number = math.max(props.controls.Scale, 0.1)
	local members: { number } = {}
	for userId = 1, aboard do
		table.insert(members, userId)
	end
	local second: QueueTypes.PadSnapshot? = if aboard > 0
		then {
			members = members,
			capacity = 4,
			destination = DepotConstants.ROLE_SHIFT,
			endsAt = if departing then nil else NOW + secondsLeft,
			departing = departing,
		}
		else nil
	local full: QueueTypes.PadSnapshot = {
		members = { 1, 2, 3, 4 },
		capacity = 4,
		destination = DepotConstants.ROLE_SHIFT,
		endsAt = NOW + 8,
		departing = false,
	}
	return e("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = UIPaperConstants.COLOR.night,
		BorderSizePixel = 0,
	}, {
		padding = e("UIPadding", {
			PaddingLeft = UDim.new(0, 60),
			PaddingTop = UDim.new(0, 60),
		}),
		layout = e("UIListLayout", {
			FillDirection = Enum.FillDirection.Vertical,
			Padding = UDim.new(0, 60),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
		trucks = row(1, {
			truck1 = truckSign(1, 1, nil, scale),
			truck2 = truckSign(2, 2, second, scale),
			truck3 = truckSign(3, 3, full, scale),
		}),
	})
end)
```

- [ ] **Step 9: `SpecRoots`.** Under "-- Cleanup Crew: Depot":

```lua
	["ReplicatedStorage.Client.Features.Depot.Systems.DepotBillboardSystem"] = "CollectionService/RunService/React-root shell (signs specced in DepotWorldViewModel; roots in UIBillboards)",
	["ReplicatedStorage.Client.UI.React.Screens.World.DepotTruckTag"] = "presentational React component (tag specced in DepotWorldViewModel; story in DepotWorld.story)",
```

- [ ] **Step 10: Controller: Studio TestEZ**, then the visual and live checks. Expected TestEZ: every `DepotWorldViewModel` case passes; `assertAllModulesSpecced` passes.
  - UI Labs (edit mode), `Game UI → Screens → World → DepotWorld`: the three tags beside frame 2a's W1 (same wire, hole, seat circles, line positions; truck 3 line red). `Aboard` 0–4 fills seats; `SecondsLeft` 10 turns line 3 red, 11 does not; `Departing` reads "Leaving now"; `Scale` 0.4 shrinks the whole tag evenly.
  - Fresh Play (`RunTests = false`), solo, at the depot: three manila tags over the beds, no TextLabel text anywhere over the trucks. Step into truck 2's bed: its tag goes to "1 / 4 ABOARD" within 0.5 s, line 3 counts down and turns red at 0:10; "Leaving now" at departure. In the client command bar: `print(require(game.ReplicatedStorage.Client.Features.Depot.Systems.DepotBillboardSystem).getState().mounted)` prints `3` (one root per truck, never more while the countdown runs). No Output errors.

- [ ] **Step 11: Gate and commit**

```bash
git add src
python3 scripts/python/module_map.py --write
git add docs/project-structure.md
stylua src/ReplicatedStorage/Shared/Features/Depot/Data/DepotConstants.luau src/ServerScriptService/Features/Depot/Data/DepotLayoutConstants.luau src/ServerScriptService/Features/Depot/Systems/DepotBuildSystem.luau src/ServerScriptService/Features/Depot/DepotServiceServer.luau src/ReplicatedStorage/Client/UI/React/Screens/World/DepotWorldViewModel.luau src/ReplicatedStorage/Client/UI/React/Screens/World/DepotWorldViewModel.spec.luau src/ReplicatedStorage/Client/UI/React/Screens/World/DepotTruckTag.luau src/ReplicatedStorage/Client/UI/React/Screens/World/DepotWorld.story.luau src/ReplicatedStorage/Client/Features/Depot/Systems/DepotBillboardSystem.luau src/ReplicatedStorage/Client/Features/Depot/DepotServiceClient.luau src/ServerScriptService/Core/Testing/SpecRoots.luau
git add src
PYTHONUTF8=1 bash .superpowers/sdd/gate.sh
python3 scripts/python/check_pr_rules.py origin/main
git commit -m "feat(depot): truck pad tags drawn with the paper kit"
python3 scripts/python/module_map.py --check
```

---

### Task 5: W2 contract board and W3+W4 result board

The two boards become empty tagged shells: the contract board carries tonight's contract as attributes (`DepotContractUtils.boardAttributes`), the shared result board carries nothing, and a returning player's review shell (in their PlayerGui, same adornee and size) carries the decoded card (`ShiftCardUtils.attributes`, replacing `ShiftCardUtils.lines`). On the client the review shell draws the whole result board with the card pinned on it and the award stickies; while that client has a review shell, the shared board's shell draws nothing (one sign per spot, no z-fighting). The old text billboards, `DepotContractUtils.boardLines` and the label constants go.

**Files:**
- Modify: `src/ReplicatedStorage/Shared/Features/Depot/Data/DepotConstants.luau` (`CONTRACT_KEYS`, `REVIEW_KEYS`)
- Modify: `src/ServerScriptService/Features/Depot/Utils/DepotContractUtils.luau` (`boardAttributes`; `boardLines` removed); Test: `.../Utils/DepotContractUtils.spec.luau`
- Modify: `src/ServerScriptService/Features/Shift/Utils/ShiftCardUtils.luau` (`attributes`; `lines`, `OUTCOME_TEXT` and the `ShiftConstants` require removed); Test: `.../Utils/ShiftCardUtils.spec.luau`
- Modify: `src/ServerScriptService/Features/Depot/Data/DepotLayoutConstants.luau` (label constants removed; `CONTRACT_OFFSET`, `RESULT_OFFSET`)
- Modify: `src/ServerScriptService/Features/Depot/Systems/DepotBuildSystem.luau` (`billboard` removed; board shells; `pinCard` takes attributes)
- Modify: `src/ServerScriptService/Features/Depot/DepotServiceServer.luau`
- Modify: `src/ReplicatedStorage/Client/UI/React/Screens/World/DepotWorldViewModel.luau` (`workOrder`, `review`); Test: `.../World/DepotWorldViewModel.spec.luau`
- Create: `src/ReplicatedStorage/Client/UI/React/Screens/World/DepotWorkOrderBoard.luau`, `.../World/DepotResultBoard.luau`
- Modify: `src/ReplicatedStorage/Client/Features/Depot/Systems/DepotBillboardSystem.luau`
- Modify: `src/ReplicatedStorage/Client/UI/React/Screens/World/DepotWorld.story.luau`
- Modify: `src/ServerScriptService/Core/Testing/SpecRoots.luau`

**Interfaces:**
- Consumes: `CorkBoard`, `PaperTexture` (Tasks 1–2); `PaperSheet` (`band`, `bandColor`, `fastener = "pin"`, `tilt`, `padding`), `PaperStamp`, `StickyNote` (`tape`), `KeyChip`, `PaperLabel`; `DepotBoardViewModel.workOrder(id): string` ("#0471"); `WorldBillboardViewModel.clip(text, max)`; `ShiftConstants.QUOTA`, `SHIFT_SECONDS`, `RATING_TEXT`, `REVIEW_QUOTES`; `DepotConstants.BOARD_COPY.title`, `RESULT_BOARD_TITLE`; `ShiftCardUtils.ResultCard`; Task 4's `shell` helper in `DepotBuildSystem` and `DepotBillboardSystem`'s `roots` / `watch` / `sign`.
- Produces:
  - `DepotConstants.CONTRACT_KEYS = { id = "ContractId", client = "ContractClient", job = "ContractJob" }`.
  - `DepotConstants.REVIEW_KEYS = { client = "ReviewClient", cleared = "ReviewCleared", quota = "ReviewQuota", bonus = "ReviewBonus", catches = "ReviewCatches", salvage = "ReviewSalvage", offered = "ReviewOffered", met = "ReviewMet", rating = "ReviewRating", truck = "ReviewTruck", crew = "ReviewCrew", awardTitle = "ReviewAwardTitle", awardName = "ReviewAwardName" }` (`crew`, `awardTitle`, `awardName` are prefixes: `ReviewCrew1`, `ReviewAwardTitle2`, …).
  - `DepotContractUtils.boardAttributes(contract: Contract) -> { [string]: string }`.
  - `ShiftCardUtils.attributes(card: ResultCard) -> { [string]: string | number | boolean }`.
  - `DepotLayoutConstants.CONTRACT_OFFSET = Vector3.new(0, 2, 0)`, `RESULT_OFFSET = Vector3.new(0, 2.5, 0)`.
  - `DepotBuildSystem.build(layout: DepotTypes.Layout, origin: CFrame, contractAttributes: { [string]: string }): Built`; `DepotBuildSystem.pinCard(player: Player, board: BasePart, attributes: { [string]: string | number | boolean }): boolean`.
  - `DepotWorldViewModel.WORK_CLIENT_MAX = 24`, `BAND_CLIENT_MAX = 22`, `STICKY_MAX = 24`, `MAX_CREW = 4`, `MAX_AWARDS = 3`; `WorkOrderView = { number, kicker, client, job, clear, before, key, action: string }`; `ReviewRow = { label: string, value: string }`; `StickyView = { title: string, name: string }`; `ReviewView = { band: string, rows: { ReviewRow }, headline: string, met: boolean, rating: string, crew: string, quote: string, stickies: { StickyView } }`; `workOrder(attributes: { [string]: unknown }) -> WorkOrderView?`; `review(attributes: { [string]: unknown }) -> ReviewView?`.
  - `DepotWorkOrderBoard(props: { view: DepotWorldViewModel.WorkOrderView })` at 600×420; `DepotResultBoard(props: { title: string, review: DepotWorldViewModel.ReviewView? })` at 1140×446.

- [ ] **Step 1: Write the failing specs.**

  `DepotWorldViewModel.spec.luau`: add requires at the top

```lua
local DepotBoardViewModel = require(ReplicatedStorage.Client.UI.React.Screens.Depot.DepotBoardViewModel)
local ShiftConstants = require(ReplicatedStorage.Shared.Features.Shift.Data.ShiftConstants)
local ShiftHudViewModel = require(ReplicatedStorage.Client.UI.React.Screens.Shift.ShiftHudViewModel)
```

  and these blocks inside the returned function:

```lua
	describe("workOrder", function()
		local keys = DepotConstants.CONTRACT_KEYS

		local function board(client)
			return {
				[keys.id] = "harlow-finch-1",
				[keys.client] = client or "Harlow & Finch Ltd.",
				[keys.job] = "Clear the office before the sale.",
			}
		end

		it("reads tonight's contract off the board's attributes", function()
			local view = DepotWorldViewModel.workOrder(board())
			expect(view.number).to.equal(`WORK ORDER {DepotBoardViewModel.workOrder("harlow-finch-1")}`)
			expect(view.kicker).to.equal("TONIGHT'S JOB")
			expect(view.client).to.equal("Harlow & Finch Ltd.")
			expect(view.job).to.equal("Clear the office before the sale.")
			expect(view.clear).to.equal(`CLEAR {ShiftConstants.QUOTA}`)
			expect(view.before).to.equal(`of trash before {ShiftHudViewModel.clock(ShiftConstants.SHIFT_SECONDS)}`)
			expect(view.key).to.equal("E")
			expect(view.action).to.equal("Read the work order")
		end)

		it("cuts a long client name", function()
			local view = DepotWorldViewModel.workOrder(board(string.rep("Pemberton ", 6)))
			expect(utf8.len(view.client)).to.equal(DepotWorldViewModel.WORK_CLIENT_MAX)
			expect(string.sub(view.client, -3)).to.equal("…")
		end)

		it("draws nothing for a board without its contract", function()
			expect(DepotWorldViewModel.workOrder({})).to.equal(nil)
			local bad = board()
			bad[keys.client] = 5
			expect(DepotWorldViewModel.workOrder(bad)).to.equal(nil)
		end)
	end)

	describe("review", function()
		local keys = DepotConstants.REVIEW_KEYS
		local quotes = ShiftConstants.REVIEW_QUOTES

		local function card()
			return {
				[keys.client] = "Pemberton Dental",
				[keys.cleared] = 362,
				[keys.quota] = 350,
				[keys.bonus] = 215,
				[keys.catches] = 3,
				[keys.salvage] = 5,
				[keys.offered] = 9,
				[keys.met] = true,
				[keys.rating] = "exceeds",
				[keys.truck] = 2,
				[`{keys.crew}1`] = "Sam",
				[`{keys.crew}2`] = "Alex",
				[`{keys.crew}3`] = "Jo",
				[`{keys.awardTitle}1`] = "EMPLOYEE OF THE NIGHT",
				[`{keys.awardName}1`] = "Sam",
				[`{keys.awardTitle}2`] = "BUTTERFINGERS",
				[`{keys.awardName}2`] = "Jo",
			}
		end

		it("lays the card out like the review", function()
			local view = DepotWorldViewModel.review(card())
			expect(view.band).to.equal("SHIFT REVIEW · PEMBERTON DENTAL")
			expect(view.rows[1].label).to.equal("CLEARED")
			expect(view.rows[1].value).to.equal("362 / 350")
			expect(view.rows[2].label).to.equal("FINDER'S FEE")
			expect(view.rows[2].value).to.equal("+215")
			expect(view.rows[3].label).to.equal("TIMES CAUGHT")
			expect(view.rows[3].value).to.equal("3")
			expect(view.rows[4].label).to.equal("SALVAGE")
			expect(view.rows[4].value).to.equal("5 of 9")
			expect(view.headline).to.equal("QUOTA MET")
			expect(view.met).to.equal(true)
			expect(view.rating).to.equal("EXCEEDS EXPECTATIONS")
			expect(view.crew).to.equal("Crew: Sam · Alex · Jo")
			expect(view.quote).to.equal(`{quotes.met.line} {quotes.met.by}`)
			expect(#view.stickies).to.equal(2)
			expect(view.stickies[1].title).to.equal("EMPLOYEE OF THE NIGHT")
			expect(view.stickies[1].name).to.equal("Sam")
			expect(view.stickies[2].title).to.equal("BUTTERFINGERS")
			expect(view.stickies[2].name).to.equal("Jo")
		end)

		it("stamps a missed quota and never rates it above NEEDS IMPROVEMENT", function()
			local missed = card()
			missed[keys.met] = false
			local view = DepotWorldViewModel.review(missed)
			expect(view.headline).to.equal("QUOTA MISSED")
			expect(view.met).to.equal(false)
			expect(view.rating).to.equal("NEEDS IMPROVEMENT")
			expect(view.quote).to.equal(`{quotes.missed.line} {quotes.missed.by}`)
		end)

		it("reads an unknown rating as NEEDS IMPROVEMENT", function()
			local odd = card()
			odd[keys.rating] = "legendary"
			expect(DepotWorldViewModel.review(odd).rating).to.equal("NEEDS IMPROVEMENT")
		end)

		it("cuts a long client name in the band", function()
			local long = card()
			long[keys.client] = string.rep("Pemberton ", 6)
			local view = DepotWorldViewModel.review(long)
			local clipped = string.sub(view.band, #"SHIFT REVIEW · " + 1)
			expect(utf8.len(clipped)).to.equal(DepotWorldViewModel.BAND_CLIENT_MAX)
			expect(string.sub(clipped, -3)).to.equal("…")
		end)

		it("lists at most four crew and three awards, stopping at the first gap", function()
			local many = card()
			many[`{keys.crew}4`] = "Kim"
			many[`{keys.crew}5`] = "Extra"
			many[`{keys.awardTitle}3`] = "QUIETEST FEET"
			many[`{keys.awardName}3`] = "Alex"
			many[`{keys.awardTitle}4`] = "LOUDEST VACUUM"
			many[`{keys.awardName}4`] = "Kim"
			local view = DepotWorldViewModel.review(many)
			expect(view.crew).to.equal("Crew: Sam · Alex · Jo · Kim")
			expect(#view.stickies).to.equal(3)
			local gap = card()
			gap[`{keys.crew}2`] = nil
			expect(DepotWorldViewModel.review(gap).crew).to.equal("Crew: Sam")
		end)

		it("draws no card from attributes that are not a card", function()
			expect(DepotWorldViewModel.review({})).to.equal(nil)
			local bad = card()
			bad[keys.met] = "yes"
			expect(DepotWorldViewModel.review(bad)).to.equal(nil)
			local noCount = card()
			noCount[keys.cleared] = "lots"
			expect(DepotWorldViewModel.review(noCount)).to.equal(nil)
		end)
	end)
```

  `ShiftCardUtils.spec.luau`: add `local ReplicatedStorage = game:GetService("ReplicatedStorage")` and `local DepotConstants = require(ReplicatedStorage.Shared.Features.Depot.Data.DepotConstants)` at the top; replace the whole `describe("lines", …)` block with

```lua
	describe("attributes", function()
		local keys = DepotConstants.REVIEW_KEYS

		it("writes the card under the board's keys", function()
			local attributes = ShiftCardUtils.attributes(ShiftCardUtils.decode(payload()))
			expect(attributes[keys.client]).to.equal("Harlow & Finch Ltd.")
			expect(attributes[keys.cleared]).to.equal(380)
			expect(attributes[keys.quota]).to.equal(350)
			expect(attributes[keys.bonus]).to.equal(95)
			expect(attributes[keys.catches]).to.equal(1)
			expect(attributes[keys.salvage]).to.equal(3)
			expect(attributes[keys.offered]).to.equal(9)
			expect(attributes[keys.met]).to.equal(true)
			expect(attributes[keys.rating]).to.equal("satisfactory")
			expect(attributes[keys.truck]).to.equal(0)
		end)

		it("numbers the crew lines and the awards", function()
			local attributes = ShiftCardUtils.attributes(ShiftCardUtils.decode(payload()))
			expect(attributes[`{keys.crew}1`]).to.equal("Crew1")
			expect(attributes[`{keys.crew}2`]).to.equal("Crew2")
			expect(attributes[`{keys.crew}3`]).to.equal(nil)
			expect(attributes[`{keys.awardTitle}1`]).to.equal("Top Hauler")
			expect(attributes[`{keys.awardName}2`]).to.equal("Crew2")
			expect(attributes[`{keys.awardTitle}3`]).to.equal(nil)
		end)

		it("writes the truck when it is known", function()
			local card = ShiftCardUtils.decode(
				wire(ShiftCardUtils.encode(review(2), { client = INFO.client, shift = INFO.shift, truck = 3 }))
			)
			expect(ShiftCardUtils.attributes(card)[keys.truck]).to.equal(3)
		end)

		it("keeps only values an attribute can hold", function()
			for _, value in ShiftCardUtils.attributes(ShiftCardUtils.decode(payload())) do
				local kind = type(value)
				expect(kind == "string" or kind == "number" or kind == "boolean").to.equal(true)
			end
		end)
	end)
```

  and, in `describe("M3 UI fields", …)`, replace the case "shows salvage as N of M and the rating" with

```lua
		it("hands the board the salvage found, the salvage offered and the rating", function()
			local fixture = review(2)
			fixture.salvage = 2
			fixture.offered = 9
			local keys = DepotConstants.REVIEW_KEYS
			local attributes = ShiftCardUtils.attributes(ShiftCardUtils.decode(ShiftCardUtils.encode(fixture, INFO)))
			expect(attributes[keys.salvage]).to.equal(2)
			expect(attributes[keys.offered]).to.equal(9)
			expect(type(attributes[keys.rating])).to.equal("string")
		end)
```

  `DepotContractUtils.spec.luau`: replace the case "keeps the in-world board to a sign" with

```lua
		it("puts tonight's contract on the board's attributes", function()
			local keys = DepotConstants.CONTRACT_KEYS
			local attributes = DepotContractUtils.boardAttributes(CONTRACTS[2])
			expect(attributes[keys.id]).to.equal("b")
			expect(attributes[keys.client]).to.equal("Beta Ltd.")
			expect(attributes[keys.job]).to.equal("Clear more.")
		end)
```

- [ ] **Step 2: Controller: Studio TestEZ.** Expected: the new cases fail (`workOrder`, `review`, `attributes`, `boardAttributes` missing).

- [ ] **Step 3: Constants.** In `DepotConstants.luau`, after `TAG_WARN_SECONDS`:

```lua
	-- The contract board shell's attributes (DepotContractUtils.boardAttributes → DepotWorldViewModel.workOrder).
	CONTRACT_KEYS = table.freeze({
		id = "ContractId",
		client = "ContractClient",
		job = "ContractJob",
	}),
	-- Your review card shell's attributes (ShiftCardUtils.attributes → DepotWorldViewModel.review). `crew`,
	-- `awardTitle` and `awardName` are prefixes: crew line i is "ReviewCrew<i>", award i "ReviewAwardTitle<i>" and
	-- "ReviewAwardName<i>".
	REVIEW_KEYS = table.freeze({
		client = "ReviewClient",
		cleared = "ReviewCleared",
		quota = "ReviewQuota",
		bonus = "ReviewBonus",
		catches = "ReviewCatches",
		salvage = "ReviewSalvage",
		offered = "ReviewOffered",
		met = "ReviewMet",
		rating = "ReviewRating",
		truck = "ReviewTruck",
		crew = "ReviewCrew",
		awardTitle = "ReviewAwardTitle",
		awardName = "ReviewAwardName",
	}),
```

  In `DepotLayoutConstants.luau` delete `BOARD_LABEL_SIZE`, `BOARD_LABEL_OFFSET`, `TITLE_LABEL_SIZE`, `TITLE_LABEL_OFFSET`, `CARD_LABEL_SIZE`, `CARD_LABEL_OFFSET`, `LABEL_BACKGROUND`, `LABEL_TEXT`, and after `PAD_TAG_OFFSET` add:

```lua
	CONTRACT_OFFSET = Vector3.new(0, 2, 0),
	RESULT_OFFSET = Vector3.new(0, 2.5, 0),
```

- [ ] **Step 4: The server words.** In `DepotContractUtils.luau` require `ReplicatedStorage.Shared.Features.Depot.Data.DepotConstants`, delete `boardLines` and its comment, and add:

```lua
-- The contract board's shell attributes (M3b world UI): the client draws the work order from them.
function DepotContractUtils.boardAttributes(contract: Contract): { [string]: string }
	local keys = DepotConstants.CONTRACT_KEYS
	return {
		[keys.id] = contract.id,
		[keys.client] = contract.client,
		[keys.job] = contract.job,
	}
end
```

  Header: "…the rest build the contract board's lines and the drive and arrival cards." → "…the rest build the contract board's attributes and the drive and arrival cards."

  In `ShiftCardUtils.luau`: delete `OUTCOME_TEXT`, `ShiftCardUtils.lines` and the now unused `ShiftConstants` require; header "…`lines` is what the depot's board shows." → "…`attributes` is what the depot's result board draws (DepotConstants.REVIEW_KEYS)."; add:

```lua
--[=[
	The card as your review card's shell attributes (DepotConstants.REVIEW_KEYS; the client draws it,
	DepotWorldViewModel.review): the numbers, met, the rating word, the truck (0 = unknown), crew names and awards
	numbered from 1. Every value is a string, a number or a boolean, as an attribute must be.
]=]
function ShiftCardUtils.attributes(card: ResultCard): { [string]: string | number | boolean }
	local keys = DepotConstants.REVIEW_KEYS
	local attributes: { [string]: string | number | boolean } = {
		[keys.client] = card.client,
		[keys.cleared] = card.cleared,
		[keys.quota] = card.quota,
		[keys.bonus] = card.bonus,
		[keys.catches] = card.catches,
		[keys.salvage] = card.salvage,
		[keys.offered] = card.offered,
		[keys.met] = card.quotaMet,
		[keys.rating] = card.rating,
		[keys.truck] = card.truck or 0,
	}
	for index, line in card.crew do
		attributes[`{keys.crew}{index}`] = line.name
	end
	for index, award in card.awards do
		attributes[`{keys.awardTitle}{index}`] = award.title
		attributes[`{keys.awardName}{index}`] = award.name
	end
	return attributes
end
```

- [ ] **Step 5: The board shells.** In `DepotBuildSystem.luau`:
  - Delete the `billboard` helper.
  - `build`'s third parameter becomes `contractAttributes: { [string]: string }`. Replace the `contractGui` block with

```lua
	local contractSign =
		shell("ContractSign", contractBoard, DepotConstants.BILLBOARD_PX.contract, DepotLayoutConstants.CONTRACT_OFFSET)
	for key, value in contractAttributes do
		contractSign:SetAttribute(key, value)
	end
	CollectionService:AddTag(contractSign, DepotConstants.BILLBOARD_TAGS.contract)
	contractSign.Parent = boards
```

    and the `titleGui` block with

```lua
	local resultSign =
		shell("ResultSign", resultBoard, DepotConstants.BILLBOARD_PX.result, DepotLayoutConstants.RESULT_OFFSET)
	CollectionService:AddTag(resultSign, DepotConstants.BILLBOARD_TAGS.result)
	resultSign.Parent = boards
```

  - `pinCard` becomes

```lua
--[=[
	Pins `attributes` (ShiftCardUtils.attributes) on the result board for `player` only: a review shell in their
	PlayerGui (replacing their last card, kept across respawns) at the board's spot and size, which their client draws as
	the whole board with the card on it (DepotBillboardSystem). Yields up to PLAYER_GUI_WAIT seconds for the PlayerGui;
	false when it never appears or the player left.
]=]
function DepotBuildSystem.pinCard(
	player: Player,
	board: BasePart,
	attributes: { [string]: string | number | boolean }
): boolean
	local found = player:WaitForChild("PlayerGui", DepotLayoutConstants.PLAYER_GUI_WAIT)
	if found == nil or not found:IsA("PlayerGui") or player.Parent == nil then
		return false
	end
	local old = found:FindFirstChild(DepotLayoutConstants.CARD_NAME)
	if old ~= nil then
		old:Destroy()
	end
	local card =
		shell(DepotLayoutConstants.CARD_NAME, board, DepotConstants.BILLBOARD_PX.result, DepotLayoutConstants.RESULT_OFFSET)
	for key, value in attributes do
		card:SetAttribute(key, value)
	end
	CollectionService:AddTag(card, DepotConstants.BILLBOARD_TAGS.review)
	card.ResetOnSpawn = false
	card.Parent = found
	return true
end
```

  - Header: "…the contract board with tonight's contract; the result board, where `pinCard` hangs a returning player's card that only they see (a BillboardGui in their PlayerGui, kept across respawns). Plain placeholder look on purpose: the final boards and labels wait for the developer's Figma approval (spec §7)." → "…the contract board's sign shell with tonight's contract as attributes; the result board's sign shell, and `pinCard`, which hangs a returning player's review shell that only they see (in their PlayerGui, kept across respawns). Every sign is an empty tagged BillboardGui the client draws (Figma World UI 2a, DepotBillboardSystem)."

  In `DepotServiceServer.luau`: `DepotBuildSystem.build(LAYOUT, DepotLayoutConstants.ORIGIN, DepotContractUtils.boardAttributes(contract))`; in `pinResultCard` `local lines = ShiftCardUtils.lines(card)` → `local attributes = ShiftCardUtils.attributes(card)` and `pinCard(player, current.resultBoard, attributes)`.

- [ ] **Step 6: `DepotWorldViewModel` additions.** Requires:

```lua
local ShiftConstants = require(ReplicatedStorage.Shared.Features.Shift.Data.ShiftConstants)
local DepotBoardViewModel = require(ReplicatedStorage.Client.UI.React.Screens.Depot.DepotBoardViewModel)
local WorldBillboardViewModel = require(ReplicatedStorage.Client.UI.React.Screens.World.WorldBillboardViewModel)
```

  Types and functions (header gains: "The contract board (W2): the work order from the board's attributes. Your review card (W4): the card from its attributes, with the award stickies; nil for anything that is not a card."):

```lua
export type WorkOrderView = {
	number: string,
	kicker: string,
	client: string,
	job: string,
	clear: string,
	before: string,
	key: string,
	action: string,
}

export type ReviewRow = { label: string, value: string }
export type StickyView = { title: string, name: string }

export type ReviewView = {
	band: string,
	rows: { ReviewRow },
	headline: string,
	met: boolean,
	rating: string,
	crew: string,
	quote: string,
	stickies: { StickyView },
}

-- Character limits: the work order's client line, the review band's client, a sticky's line.
DepotWorldViewModel.WORK_CLIENT_MAX = 24
DepotWorldViewModel.BAND_CLIENT_MAX = 22
DepotWorldViewModel.STICKY_MAX = 24
-- The most crew lines and award stickies a card shows (ShiftCardUtils keeps the same caps).
DepotWorldViewModel.MAX_CREW = 4
DepotWorldViewModel.MAX_AWARDS = 3

-- A whole, non-negative number read off an attribute; nil for anything else.
local function count(value: unknown): number?
	if type(value) ~= "number" or value ~= value then
		return nil
	end
	return math.max(0, math.floor(value))
end

function DepotWorldViewModel.workOrder(attributes: { [string]: unknown }): WorkOrderView?
	local keys = DepotConstants.CONTRACT_KEYS
	local id = attributes[keys.id]
	local client = attributes[keys.client]
	local job = attributes[keys.job]
	if type(id) ~= "string" or type(client) ~= "string" or type(job) ~= "string" then
		return nil
	end
	return {
		number = `WORK ORDER {DepotBoardViewModel.workOrder(id)}`,
		kicker = DepotConstants.BOARD_COPY.title,
		client = WorldBillboardViewModel.clip(client, DepotWorldViewModel.WORK_CLIENT_MAX),
		job = job,
		clear = `CLEAR {ShiftConstants.QUOTA}`,
		before = `of trash before {ShiftHudViewModel.clock(ShiftConstants.SHIFT_SECONDS)}`,
		key = "E",
		action = "Read the work order",
	}
end

function DepotWorldViewModel.review(attributes: { [string]: unknown }): ReviewView?
	local keys = DepotConstants.REVIEW_KEYS
	local client = attributes[keys.client]
	local met = attributes[keys.met]
	local rating = attributes[keys.rating]
	local cleared = count(attributes[keys.cleared])
	local quota = count(attributes[keys.quota])
	local bonus = count(attributes[keys.bonus])
	local catches = count(attributes[keys.catches])
	local salvage = count(attributes[keys.salvage])
	local offered = count(attributes[keys.offered])
	if
		type(client) ~= "string"
		or type(met) ~= "boolean"
		or type(rating) ~= "string"
		or cleared == nil
		or quota == nil
		or bonus == nil
		or catches == nil
		or salvage == nil
		or offered == nil
	then
		return nil
	end
	local names: { string } = {}
	for index = 1, DepotWorldViewModel.MAX_CREW do
		local name = attributes[`{keys.crew}{index}`]
		if type(name) ~= "string" then
			break
		end
		table.insert(names, name)
	end
	local stickies: { StickyView } = {}
	for index = 1, DepotWorldViewModel.MAX_AWARDS do
		local title = attributes[`{keys.awardTitle}{index}`]
		local name = attributes[`{keys.awardName}{index}`]
		if type(title) ~= "string" or type(name) ~= "string" then
			break
		end
		table.insert(stickies, {
			title = WorldBillboardViewModel.clip(title, DepotWorldViewModel.STICKY_MAX),
			name = WorldBillboardViewModel.clip(name, DepotWorldViewModel.STICKY_MAX),
		})
	end
	local text = ShiftConstants.RATING_TEXT
	-- A missed quota never rates above NEEDS IMPROVEMENT (the review's rule); an unknown word reads as it too.
	local stamp = if met then text[rating] or text.needsImprovement else text.needsImprovement
	local quote = if met then ShiftConstants.REVIEW_QUOTES.met else ShiftConstants.REVIEW_QUOTES.missed
	local band = string.upper(WorldBillboardViewModel.clip(client, DepotWorldViewModel.BAND_CLIENT_MAX))
	return {
		band = `SHIFT REVIEW · {band}`,
		rows = {
			{ label = "CLEARED", value = `{cleared} / {quota}` },
			{ label = "FINDER'S FEE", value = `+{bonus}` },
			{ label = "TIMES CAUGHT", value = tostring(catches) },
			{ label = "SALVAGE", value = `{salvage} of {offered}` },
		},
		headline = if met then "QUOTA MET" else "QUOTA MISSED",
		met = met,
		rating = stamp,
		crew = if #names > 0 then `Crew: {table.concat(names, " · ")}` else "",
		quote = `{quote.line} {quote.by}`,
		stickies = stickies,
	}
end
```

  (`string.upper` touches ASCII letters only, so the "…" bytes stay intact.)

- [ ] **Step 7: `DepotWorkOrderBoard.luau`**

```lua
--!strict
--[=[
	DepotWorkOrderBoard: the contract board (Figma World UI 2a, W2) at its 600x420 design size: a cork board in a 20 px
	wood frame (CorkBoard) with tonight's work order pinned on it, a 310x360 cream sheet at (150, 34) tilted 1.5° under
	a red "WORK ORDER #0471" band: TONIGHT'S JOB, the client, the job line, a rule, the red CLEAR n, its deadline, and
	the E key chip with "Read the work order" (always shown: prompt range is not tracked at the depot). Presentational;
	the words are DepotWorldViewModel.workOrder.

	@class DepotWorkOrderBoard
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local CorkBoard = require(ReplicatedStorage.Client.UI.React.Screens.Paper.CorkBoard)
local KeyChip = require(ReplicatedStorage.Client.UI.React.Screens.Paper.KeyChip)
local PaperLabel = require(ReplicatedStorage.Client.UI.React.Screens.Paper.PaperLabel)
local PaperSheet = require(ReplicatedStorage.Client.UI.React.Screens.Paper.PaperSheet)
local UIPaperConstants = require(ReplicatedStorage.Client.UI.React.Screens.Paper.UIPaperConstants)
local DepotWorldViewModel = require(ReplicatedStorage.Client.UI.React.Screens.World.DepotWorldViewModel)

local e = React.createElement

export type DepotWorkOrderBoardProps = {
	view: DepotWorldViewModel.WorkOrderView,
}

local COLOR = UIPaperConstants.COLOR

local function label(
	text: string,
	role: PaperLabel.Role,
	size: number,
	color: Color3,
	y: number,
	height: number,
	scaled: boolean?
): React.ReactNode
	return e(PaperLabel, {
		text = text,
		role = role,
		size = size,
		color = color,
		position = UDim2.fromOffset(0, y),
		frame = UDim2.new(1, 0, 0, height),
		autoSize = false,
		scaled = scaled,
	})
end

local function DepotWorkOrderBoard(props: DepotWorkOrderBoardProps): React.ReactNode
	local view = props.view
	local sheet: { [string]: React.ReactNode } = {
		kicker = label(view.kicker, "body", 16, COLOR.ink, 0, 22),
		client = label(view.client, "heading", 40, COLOR.ink, 22, 50, true),
		job = label(view.job, "body", 18, COLOR.ink, 74, 46),
		rule = e("Frame", {
			Position = UDim2.fromOffset(0, 124),
			Size = UDim2.new(1, 0, 0, 2),
			BackgroundColor3 = COLOR.manilaDeep,
			BorderSizePixel = 0,
		}),
		clear = label(view.clear, "heading", 40, COLOR.stamp, 134, 46, true),
		before = label(view.before, "body", 18, COLOR.ink, 180, 24),
		prompt = e("Frame", {
			Position = UDim2.fromOffset(0, 228),
			Size = UDim2.fromOffset(0, 34),
			AutomaticSize = Enum.AutomaticSize.X,
			BackgroundTransparency = 1,
		}, {
			layout = e("UIListLayout", {
				FillDirection = Enum.FillDirection.Horizontal,
				VerticalAlignment = Enum.VerticalAlignment.Center,
				Padding = UDim.new(0, 12),
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),
			chip = e(KeyChip, { label = view.key, size = 24, layoutOrder = 1 }),
			action = e(PaperLabel, {
				text = view.action,
				role = "body",
				size = 20,
				color = COLOR.ink,
				fit = true,
				layoutOrder = 2,
			}),
		}),
	}
	return e(CorkBoard, { size = UDim2.fromOffset(600, 420), frame = 20 }, {
		order = e(PaperSheet, {
			position = UDim2.fromOffset(150, 34),
			size = UDim2.fromOffset(310, 360),
			paper = COLOR.cream,
			tilt = 1.5,
			band = view.number,
			fastener = "pin",
			padding = 18,
		}, sheet),
	})
end

return DepotWorkOrderBoard
```

- [ ] **Step 8: `DepotResultBoard.luau`**

```lua
--!strict
--[=[
	DepotResultBoard: the result board (Figma World UI 2a, W3 + W4) at its 1140x446 design size: a cork board
	(1140x420 at y 26, 20 px wood frame) under a 380x64 manilaDeep folder tab at (380, 0) with the title (Oswald 36).
	With `review` (your card, W4): the review card pinned at (60, 76), 568x330 cream, tilted -1.5° under an ink band,
	with the four rows, the QUOTA MET / MISSED stamp and the rating stamp, the crew line and Harlow's quote; and one
	sticky per award ("TITLE" over the name) at (675, 96), (900, 110) and (790, 262). Without it: the bare board.
	Presentational; the words are DepotWorldViewModel.review.

	@class DepotResultBoard
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local CorkBoard = require(ReplicatedStorage.Client.UI.React.Screens.Paper.CorkBoard)
local PaperLabel = require(ReplicatedStorage.Client.UI.React.Screens.Paper.PaperLabel)
local PaperSheet = require(ReplicatedStorage.Client.UI.React.Screens.Paper.PaperSheet)
local PaperStamp = require(ReplicatedStorage.Client.UI.React.Screens.Paper.PaperStamp)
local PaperTexture = require(ReplicatedStorage.Client.UI.React.Screens.Paper.PaperTexture)
local StickyNote = require(ReplicatedStorage.Client.UI.React.Screens.Paper.StickyNote)
local UIPaperConstants = require(ReplicatedStorage.Client.UI.React.Screens.Paper.UIPaperConstants)
local DepotWorldViewModel = require(ReplicatedStorage.Client.UI.React.Screens.World.DepotWorldViewModel)

local e = React.createElement

export type DepotResultBoardProps = {
	title: string,
	review: DepotWorldViewModel.ReviewView?,
}

local COLOR = UIPaperConstants.COLOR
local STICKY_AT: { Vector2 } = { Vector2.new(675, 96), Vector2.new(900, 110), Vector2.new(790, 262) }
local STICKY_TILT: { number } = { -2, 3, -1 }
local ROW_HEIGHT = 42

local function reviewCard(review: DepotWorldViewModel.ReviewView): React.ReactNode
	local content: { [string]: React.ReactNode } = {}
	for index, row in review.rows do
		local y = (index - 1) * ROW_HEIGHT
		content[`label{index}`] = e(PaperLabel, {
			text = row.label,
			role = "medium",
			size = 20,
			color = COLOR.ink,
			position = UDim2.fromOffset(0, y + 8),
			frame = UDim2.fromOffset(180, 30),
			autoSize = false,
			wrapped = false,
		})
		content[`value{index}`] = e(PaperLabel, {
			text = row.value,
			role = "number",
			size = 30,
			color = COLOR.ink,
			position = UDim2.fromOffset(180, y),
			frame = UDim2.fromOffset(130, 40),
			autoSize = false,
			wrapped = false,
			scaled = true,
		})
		content[`rule{index}`] = e("Frame", {
			Position = UDim2.fromOffset(0, y + ROW_HEIGHT - 2),
			Size = UDim2.fromOffset(310, 1),
			BackgroundColor3 = COLOR.manilaDeep,
			BorderSizePixel = 0,
		})
	end
	content.headline = e(PaperStamp, {
		text = review.headline,
		size = 44,
		tilt = 4,
		anchor = Vector2.new(0.5, 0.5),
		position = UDim2.fromOffset(420, 58),
	})
	content.rating = e(PaperStamp, {
		text = review.rating,
		size = 20,
		tilt = 2,
		anchor = Vector2.new(0.5, 0.5),
		position = UDim2.fromOffset(420, 140),
	})
	content.crew = e(PaperLabel, {
		text = review.crew,
		role = "body",
		size = 18,
		color = COLOR.ink,
		position = UDim2.fromOffset(0, 186),
		frame = UDim2.new(1, 0, 0, 24),
		autoSize = false,
		wrapped = false,
		scaled = true,
	})
	content.quote = e(PaperLabel, {
		text = review.quote,
		role = "body",
		size = 16,
		color = COLOR.ink,
		position = UDim2.fromOffset(0, 220),
		frame = UDim2.new(1, 0, 0, 44),
		autoSize = false,
	})
	return e(PaperSheet, {
		position = UDim2.fromOffset(60, 76),
		size = UDim2.fromOffset(568, 330),
		paper = COLOR.cream,
		tilt = -1.5,
		band = review.band,
		bandColor = COLOR.ink,
		fastener = "pin",
		padding = 20,
	}, content)
end

local function DepotResultBoard(props: DepotResultBoardProps): React.ReactNode
	local children: { [string]: React.ReactNode } = {
		board = e(CorkBoard, { size = UDim2.fromOffset(1140, 420), position = UDim2.fromOffset(0, 26), frame = 20 }),
		tab = e("Frame", {
			Position = UDim2.fromOffset(380, 0),
			Size = UDim2.fromOffset(380, 64),
			BackgroundColor3 = COLOR.manilaDeep,
			BorderSizePixel = 0,
			ZIndex = 5,
		}, {
			corner = e("UICorner", { CornerRadius = UDim.new(0, 6) }),
			texture = e(PaperTexture, { paper = COLOR.manilaDeep, corner = 6, zIndex = 1 }),
			label = e(PaperLabel, {
				text = props.title,
				role = "heading",
				size = 36,
				color = COLOR.ink,
				align = "center",
				frame = UDim2.fromScale(1, 1),
				autoSize = false,
				wrapped = false,
				zIndex = 2,
			}),
		}),
	}
	local review = props.review
	if review ~= nil then
		children.card = e("Frame", {
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			ZIndex = 3,
		}, { sheet = reviewCard(review) })
		for index, sticky in review.stickies do
			local at = STICKY_AT[index]
			if at ~= nil then
				children[`sticky{index}`] = e("Frame", {
					Position = UDim2.fromOffset(at.X, at.Y),
					Size = UDim2.fromOffset(200, 0),
					AutomaticSize = Enum.AutomaticSize.Y,
					BackgroundTransparency = 1,
					ZIndex = 4,
				}, {
					note = e(StickyNote, {
						text = `{sticky.title}\n\n{sticky.name}`,
						width = 200,
						size = 18,
						tilt = STICKY_TILT[index],
						tape = Vector2.new(80, 20),
					}),
				})
			end
		end
	end
	return e("Frame", {
		Size = UDim2.fromOffset(1140, 446),
		BackgroundTransparency = 1,
	}, children)
end

return DepotResultBoard
```

- [ ] **Step 9: `DepotBillboardSystem` draws the boards.** Require `DepotWorkOrderBoard` and `DepotResultBoard` (`ReplicatedStorage.Client.UI.React.Screens.World.…`). Add state and draw functions after `drawTruck`:

```lua
local results: { [BillboardGui]: true } = {}
local reviews: { [BillboardGui]: true } = {}

-- Your review shell (PlayerGui, the same spot and size) draws the whole result board with your card on it; while you
-- have one, the shared board's shell draws nothing, so two signs never z-fight. Without one: the bare board.
local function drawResults()
	local mine = next(reviews) ~= nil
	for shell in results do
		if mine then
			roots.hide(shell)
		else
			roots.show(shell, sign(PX.result, e(DepotResultBoard, { title = DepotConstants.RESULT_BOARD_TITLE })))
		end
	end
end

local function drawReview(shell: BillboardGui)
	local review = DepotWorldViewModel.review(shell:GetAttributes())
	roots.show(
		shell,
		sign(PX.result, e(DepotResultBoard, { title = DepotConstants.RESULT_BOARD_TITLE, review = review }))
	)
end

local function drawContract(shell: BillboardGui)
	local view = DepotWorldViewModel.workOrder(shell:GetAttributes())
	roots.show(shell, if view ~= nil then sign(PX.contract, e(DepotWorkOrderBoard, { view = view })) else nil)
end
```

  In `start`, after the truck `watch`:

```lua
	watch(TAGS.contract, drawContract)
	watch(TAGS.result, function(shell)
		results[shell] = true
		drawResults()
	end, function(shell)
		results[shell] = nil
	end)
	watch(TAGS.review, function(shell)
		reviews[shell] = true
		drawReview(shell)
		drawResults()
	end, function(shell)
		reviews[shell] = nil
		drawResults()
	end)
```

  In `stop` add `table.clear(results)` and `table.clear(reviews)`; `getState` returns `reviews = count(reviews)`. Header gains: "The contract board (W2) and the result board (W3) draw from their shells' attributes; your review card's shell (W4, in your PlayerGui) draws the whole result board with your card and award stickies, and while it exists the shared board draws nothing."

- [ ] **Step 10: `DepotWorld.story`.** Require `DepotWorkOrderBoard`, `DepotResultBoard` and `ShiftConstants`; add controls `Review = true`, `QuotaMet = true`, `LongClient = false`; header gains "the contract board and the result board with (`Review`) or without your card; `QuotaMet` stamps it, `LongClient` tries a 60-character client". Build the attribute maps the server would write and add a second row after `trucks`:

```lua
	local contract = DepotConstants.CONTRACTS[1]
	local client = if props.controls.LongClient then string.rep("Pemberton ", 6) else "Pemberton Dental"
	local contractKeys = DepotConstants.CONTRACT_KEYS
	local workOrder = DepotWorldViewModel.workOrder({
		[contractKeys.id] = contract.id,
		[contractKeys.client] = client,
		[contractKeys.job] = contract.job,
	})
	local keys = DepotConstants.REVIEW_KEYS
	local met: boolean = props.controls.QuotaMet
	local review = if props.controls.Review
		then DepotWorldViewModel.review({
			[keys.client] = client,
			[keys.cleared] = if met then 362 else 214,
			[keys.quota] = ShiftConstants.QUOTA,
			[keys.bonus] = 215,
			[keys.catches] = 3,
			[keys.salvage] = 5,
			[keys.offered] = 9,
			[keys.met] = met,
			[keys.rating] = "exceeds",
			[keys.truck] = 2,
			[`{keys.crew}1`] = "Sam",
			[`{keys.crew}2`] = "Alex",
			[`{keys.crew}3`] = "Jo",
			[`{keys.awardTitle}1`] = "EMPLOYEE OF THE NIGHT",
			[`{keys.awardName}1`] = "Sam",
			[`{keys.awardTitle}2`] = "BUTTERFINGERS",
			[`{keys.awardName}2`] = "Jo",
		})
		else nil
	local boards: { [string]: React.ReactNode } = {
		result = sign(
			1,
			PX.result,
			scale,
			e(DepotResultBoard, { title = DepotConstants.RESULT_BOARD_TITLE, review = review })
		),
	}
	if workOrder ~= nil then
		boards.contract = sign(2, PX.contract, scale, e(DepotWorkOrderBoard, { view = workOrder }))
	end
```

  and `boards = row(2, boards),` in the returned children.

- [ ] **Step 11: `SpecRoots`.** Under "-- Cleanup Crew: Depot":

```lua
	["ReplicatedStorage.Client.UI.React.Screens.World.DepotWorkOrderBoard"] = "presentational React component (work order specced in DepotWorldViewModel; story in DepotWorld.story)",
	["ReplicatedStorage.Client.UI.React.Screens.World.DepotResultBoard"] = "presentational React component (review card specced in DepotWorldViewModel; story in DepotWorld.story)",
```

- [ ] **Step 12: Controller: Studio TestEZ**, then the visual and live checks. Expected TestEZ: the new `DepotWorldViewModel`, `ShiftCardUtils` and `DepotContractUtils` cases pass, and nothing else regresses; `assertAllModulesSpecced` passes.
  - UI Labs, `World → DepotWorld`: the contract board and the result board beside frame 2a (W2: sheet tilt, red band, pin, E chip; W3+W4: tab over the frame edge, card tilt, stamps clear of the rows, three sticky spots). `Review` off shows the bare board with its tab; `QuotaMet` off stamps QUOTA MISSED / NEEDS IMPROVEMENT; `LongClient` cuts the band and the work order's client with "…" inside their frames.
  - Fresh Play, solo: the contract board shows tonight's real client and job, "CLEAR 350 / of trash before 7:00"; its prompt still opens the board scene. Then play a shift and choose Back to depot: on return the result board shows your card and stickies, with no flicker between two boards (walk around it: one sign only). Client command bar: `print(require(game.ReplicatedStorage.Client.Features.Depot.Systems.DepotBillboardSystem).getState().reviews)` prints `1`; `mounted` is 5 (three trucks, the contract board and your review; the shared result board's root is hidden, and before the return it was the fifth). Respawn (reset character): the card stays. No Output errors.

- [ ] **Step 13: Gate and commit**

```bash
git add src
python3 scripts/python/module_map.py --write
git add docs/project-structure.md
stylua src/ReplicatedStorage/Shared/Features/Depot/Data/DepotConstants.luau src/ServerScriptService/Features/Depot/Utils/DepotContractUtils.luau src/ServerScriptService/Features/Depot/Utils/DepotContractUtils.spec.luau src/ServerScriptService/Features/Shift/Utils/ShiftCardUtils.luau src/ServerScriptService/Features/Shift/Utils/ShiftCardUtils.spec.luau src/ServerScriptService/Features/Depot/Data/DepotLayoutConstants.luau src/ServerScriptService/Features/Depot/Systems/DepotBuildSystem.luau src/ServerScriptService/Features/Depot/DepotServiceServer.luau src/ReplicatedStorage/Client/UI/React/Screens/World/DepotWorldViewModel.luau src/ReplicatedStorage/Client/UI/React/Screens/World/DepotWorldViewModel.spec.luau src/ReplicatedStorage/Client/UI/React/Screens/World/DepotWorkOrderBoard.luau src/ReplicatedStorage/Client/UI/React/Screens/World/DepotResultBoard.luau src/ReplicatedStorage/Client/UI/React/Screens/World/DepotWorld.story.luau src/ReplicatedStorage/Client/Features/Depot/Systems/DepotBillboardSystem.luau src/ServerScriptService/Core/Testing/SpecRoots.luau
git add src
PYTHONUTF8=1 bash .superpowers/sdd/gate.sh
python3 scripts/python/check_pr_rules.py origin/main
git commit -m "feat(depot): contract board and result board drawn with the paper kit"
python3 scripts/python/module_map.py --check
```

---

### Task 6: W5 cargo price tags

Each cargo item's white floating text becomes a small cream price tag. The server keeps the shell it already builds (offset-sized, `MaxDistance` 24, off while the item is hidden under a pile) but writes the item's display data as attributes and tags it instead of adding a TextLabel; `setValue` and `reveal` update those attributes. The client mounts a tag only for items near the camera (mount within 24 studs, keep until 28, never while hidden), so a room of 60–100 items holds a handful of React roots.

**Files:**
- Modify: `src/ReplicatedStorage/Shared/Features/Cargo/Data/CargoConstants.luau` (`LABEL_TAG`, `LABEL_KEYS`, `LABEL_PX`, `LABEL_KEEP_DISTANCE`, `LABEL_CHECK`)
- Modify: `src/ServerScriptService/Features/Cargo/Systems/CargoSpawnSystem.luau` (`makeLabel` → `makeTag`; `labelText`, `labelOf` → `tagOf`)
- Create: `src/ReplicatedStorage/Client/UI/React/Screens/World/CargoWorldViewModel.luau`; Test: `.../World/CargoWorldViewModel.spec.luau`
- Create: `src/ReplicatedStorage/Client/UI/React/Screens/World/CargoPriceTag.luau`
- Create: `src/ReplicatedStorage/Client/Features/Cargo/Systems/CargoBillboardSystem.luau`
- Modify: `src/ReplicatedStorage/Client/Features/Cargo/CargoServiceClient.luau`
- Create: `src/ReplicatedStorage/Client/UI/React/Screens/World/CargoWorld.story.luau`
- Modify: `src/ServerScriptService/Core/Testing/SpecRoots.luau`

`CargoServiceServer` (400 lines) is not touched: it keeps calling `spawner:setValue(object, value)` after writing `CargoImpacts`, and `setValue` copies both onto the tag.

**Interfaces:**
- Consumes: `UIBillboards`, `UIBillboardHost` (Task 3); `WorldBillboard` (`sizing = "pixels"`), `PaperTag` (`hole = "left"`), `PaperLabel` (`scaled`, `minSize`), `WorldBillboardViewModel.clip` (Task 2); `CargoRegistry.get(kind): ItemDef?`, `CargoRegistry.ids(): { string }`; `CargoConstants.FRAGILE_TIERS`, `LABEL_DISTANCE` (24), `LABEL_NAME`, `VALUE_ATTRIBUTE`, `IMPACTS_ATTRIBUTE`, `HIDDEN_ATTRIBUTE`.
- Produces:
  - `CargoConstants.LABEL_TAG = "CargoPriceTag"`; `LABEL_KEYS = { name = "CargoTagName", category = "CargoTagCategory", value = "CargoTagValue", fragile = "CargoTagFragile", impacts = "CargoTagImpacts", hidden = "CargoTagHidden" }`; `LABEL_PX = Vector2.new(260, 70)`; `LABEL_KEEP_DISTANCE = 28`; `LABEL_CHECK = 0.2`.
  - `CargoWorldViewModel.NAME_MAX = 28`; `PriceTagView = { name: string, price: string, cracked: boolean, mark: string? }`; `priceTag(attributes: { [string]: unknown }) -> PriceTagView?`; `mounted(distance: number, mountedNow: boolean, hidden: boolean) -> boolean`.
  - `CargoPriceTag(props: { view: CargoWorldViewModel.PriceTagView })` at 260×70.
  - `CargoBillboardSystem.start()`, `.stop()`, `.getState() -> { shells: number, mounted: number, counters: { [string]: number } }`.

- [ ] **Step 1: Write the failing spec** `CargoWorldViewModel.spec.luau`:

```lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CargoWorldViewModel = require(script.Parent.CargoWorldViewModel)
local CargoConstants = require(ReplicatedStorage.Shared.Features.Cargo.Data.CargoConstants)
local CargoRegistry = require(ReplicatedStorage.Shared.Features.Cargo.Data.CargoRegistry)

local KEYS = CargoConstants.LABEL_KEYS

-- The attributes the server writes on an item's tag shell.
local function tag(name, category, value, fragile, impacts)
	return {
		[KEYS.name] = name,
		[KEYS.category] = category,
		[KEYS.value] = value,
		[KEYS.fragile] = fragile == true,
		[KEYS.impacts] = impacts or 0,
		[KEYS.hidden] = false,
	}
end

return function()
	describe("priceTag", function()
		it("prices salvage in dollars", function()
			local view = CargoWorldViewModel.priceTag(tag("Printer", "salvage", 40))
			expect(view.name).to.equal("Printer")
			expect(view.price).to.equal("$40")
			expect(view.cracked).to.equal(false)
			expect(view.mark).to.equal(nil)
		end)

		it("shows trash as the clearance it adds", function()
			expect(CargoWorldViewModel.priceTag(tag("Rubbish bag", "trash", 10)).price).to.equal("+10")
		end)

		it("marks an undamaged fragile item FRAGILE", function()
			local view = CargoWorldViewModel.priceTag(tag("Monitor", "salvage", 30, true, 0))
			expect(view.mark).to.equal("FRAGILE")
			expect(view.cracked).to.equal(false)
		end)

		it("marks a cracked item by the value it lost, from the fragile tiers", function()
			local tiers = CargoConstants.FRAGILE_TIERS
			local once = CargoWorldViewModel.priceTag(tag("Fish tank", "salvage", 35, true, 1))
			expect(once.mark).to.equal(`CRACKED −{math.floor((1 - tiers[2]) * 100 + 0.5)}%`)
			expect(once.mark).to.equal("CRACKED −50%")
			expect(once.cracked).to.equal(true)
			expect(once.price).to.equal("$35")
			local twice = CargoWorldViewModel.priceTag(tag("Fish tank", "salvage", 18, true, 2))
			expect(twice.mark).to.equal("CRACKED −75%")
			local many = CargoWorldViewModel.priceTag(tag("Fish tank", "salvage", 18, true, 9))
			expect(many.mark).to.equal("CRACKED −75%")
		end)

		it("puts no mark on a sturdy item, whatever its impacts", function()
			local view = CargoWorldViewModel.priceTag(tag("Printer", "salvage", 40, false, 3))
			expect(view.mark).to.equal(nil)
			expect(view.cracked).to.equal(false)
		end)

		it("rounds a value to a whole price", function()
			expect(CargoWorldViewModel.priceTag(tag("Monitor", "salvage", 14.6)).price).to.equal("$15")
		end)

		it("keeps the longest catalog name whole", function()
			for _, id in CargoRegistry.ids() do
				local def = CargoRegistry.get(id)
				expect(CargoWorldViewModel.priceTag(tag(def.name, def.category, def.value)).name).to.equal(def.name)
			end
			local long = CargoWorldViewModel.priceTag(tag(string.rep("x", 40), "salvage", 1)).name
			expect(utf8.len(long)).to.equal(CargoWorldViewModel.NAME_MAX)
		end)

		it("draws no tag without a name and a value", function()
			expect(CargoWorldViewModel.priceTag({})).to.equal(nil)
			expect(CargoWorldViewModel.priceTag(tag(nil, "trash", 10))).to.equal(nil)
			expect(CargoWorldViewModel.priceTag(tag("Rubbish bag", "trash", "ten"))).to.equal(nil)
		end)
	end)

	describe("mounted", function()
		it("mounts only within 24 studs, keeps until 28, never under a pile", function()
			expect(CargoConstants.LABEL_DISTANCE).to.equal(24)
			expect(CargoConstants.LABEL_KEEP_DISTANCE).to.equal(28)
			expect(CargoWorldViewModel.mounted(24, false, false)).to.equal(true)
			expect(CargoWorldViewModel.mounted(24.5, false, false)).to.equal(false)
			expect(CargoWorldViewModel.mounted(27, true, false)).to.equal(true)
			expect(CargoWorldViewModel.mounted(28, true, false)).to.equal(true)
			expect(CargoWorldViewModel.mounted(28.5, true, false)).to.equal(false)
			expect(CargoWorldViewModel.mounted(0, false, true)).to.equal(false)
			expect(CargoWorldViewModel.mounted(0, true, true)).to.equal(false)
		end)
	end)
end
```

- [ ] **Step 2: Controller: Studio TestEZ.** Expected: the new cases fail (`CargoWorldViewModel` missing).

- [ ] **Step 3: Constants.** In `CargoConstants.luau`, replace

```lua
	-- Graybox item labels are seen within this many studs.
	LABEL_DISTANCE = 24,
```

  with

```lua
	-- An item's price tag (M3b world UI, W5): its shell's tag and attributes (the client draws it,
	-- CargoBillboardSystem), its design size in px, and when it is drawn: seen within LABEL_DISTANCE studs (the
	-- shell's MaxDistance), mounted on a client within LABEL_DISTANCE of the camera and kept until LABEL_KEEP_DISTANCE
	-- (no flicker at the edge), checked every LABEL_CHECK seconds.
	LABEL_TAG = "CargoPriceTag",
	LABEL_KEYS = table.freeze({
		name = "CargoTagName",
		category = "CargoTagCategory",
		value = "CargoTagValue",
		fragile = "CargoTagFragile",
		impacts = "CargoTagImpacts",
		hidden = "CargoTagHidden",
	}),
	LABEL_PX = Vector2.new(260, 70),
	LABEL_DISTANCE = 24,
	LABEL_KEEP_DISTANCE = 28,
	LABEL_CHECK = 0.2,
```

- [ ] **Step 4: The server shell.** In `CargoSpawnSystem.luau`, replace `labelText`, `labelOf` and `makeLabel` with:

```lua
local function tagOf(item: Instance): BillboardGui?
	local shell = item:FindFirstChild(CargoConstants.LABEL_NAME)
	if shell == nil or not shell:IsA("BillboardGui") then
		return nil
	end
	return shell
end

-- The item's price tag shell (W5): empty and offset-sized at the tag's design size, the item's display data as
-- attributes (CargoConstants.LABEL_KEYS), tagged LABEL_TAG last; CargoBillboardSystem draws it on clients near it. Off
-- while the item is hidden under a pile.
local function makeTag(part: BasePart, def: CargoTypes.ItemDef, value: number, hidden: boolean)
	local keys = CargoConstants.LABEL_KEYS
	local shell = Instance.new("BillboardGui")
	shell.Name = CargoConstants.LABEL_NAME
	shell.Size = UDim2.fromOffset(CargoConstants.LABEL_PX.X, CargoConstants.LABEL_PX.Y)
	shell.StudsOffset = Vector3.new(0, part.Size.Y / 2 + 1.5, 0)
	shell.MaxDistance = CargoConstants.LABEL_DISTANCE
	shell.LightInfluence = 0
	shell.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	shell.Enabled = not hidden
	shell:SetAttribute(keys.name, def.name)
	shell:SetAttribute(keys.category, def.category)
	shell:SetAttribute(keys.value, value)
	shell:SetAttribute(keys.fragile, def.fragile)
	shell:SetAttribute(keys.impacts, 0)
	shell:SetAttribute(keys.hidden, hidden)
	CollectionService:AddTag(shell, CargoConstants.LABEL_TAG)
	shell.Parent = part
end
```

  - In `spawn`: `makeLabel(part, labelText(kind, value), not hidden)` → `makeTag(part, def, value, hidden)`.
  - In `reveal`, replace the `labelOf` block with

```lua
		local shell = tagOf(item)
		if shell ~= nil then
			shell.Enabled = true
			shell:SetAttribute(CargoConstants.LABEL_KEYS.hidden, false)
		end
```

  - `setValue` becomes

```lua
		--[=[
			Sets an item's value (a fragile item dropped a tier) and copies it, with the item's impacts, onto its tag.
		]=]
		setValue = function(_self, item, value)
			item:SetAttribute(CargoConstants.VALUE_ATTRIBUTE, value)
			local shell = tagOf(item)
			if shell ~= nil then
				local impacts = item:GetAttribute(CargoConstants.IMPACTS_ATTRIBUTE)
				shell:SetAttribute(CargoConstants.LABEL_KEYS.value, value)
				shell:SetAttribute(CargoConstants.LABEL_KEYS.impacts, if type(impacts) == "number" then impacts else 0)
			end
		end,
```

  - Header: "…and a name-and-value label…" → "…and an empty price tag shell (its display data as attributes, tagged CargoPriceTag; the client draws it)…".

- [ ] **Step 5: `CargoWorldViewModel.luau`**

```lua
--!strict
--[=[
	CargoWorldViewModel: what a cargo item's price tag says and when it is drawn (Figma World UI 2b, W5). The tag reads
	the item's shell attributes (CargoConstants.LABEL_KEYS): the name (cut at NAME_MAX, the longest catalog name, so
	every real name stays whole), the price ("$45" for salvage, "+10" clearance for trash) and the mark: "FRAGILE" for an
	undamaged fragile item, "CRACKED −50%" / "CRACKED −75%" from CargoConstants.FRAGILE_TIERS once it took impacts
	(the price turns red), else none. `mounted`: a tag mounts within LABEL_DISTANCE of the camera and stays until
	LABEL_KEEP_DISTANCE, and never while the item is hidden under a pile. Pure.

	@class CargoWorldViewModel
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CargoConstants = require(ReplicatedStorage.Shared.Features.Cargo.Data.CargoConstants)
local WorldBillboardViewModel = require(ReplicatedStorage.Client.UI.React.Screens.World.WorldBillboardViewModel)

export type PriceTagView = {
	name: string,
	price: string,
	-- A fragile item that took impacts: the price is drawn in stamp red.
	cracked: boolean,
	mark: string?,
}

local CargoWorldViewModel = {}

-- utf8.len("Employee of the Month plaque"), the longest catalog name.
CargoWorldViewModel.NAME_MAX = 28

local function markOf(fragile: boolean, impacts: number): string?
	if not fragile then
		return nil
	end
	if impacts == 0 then
		return "FRAGILE"
	end
	local tiers = CargoConstants.FRAGILE_TIERS
	local fraction = tiers[math.clamp(impacts + 1, 1, #tiers)]
	return `CRACKED −{math.floor((1 - fraction) * 100 + 0.5)}%`
end

function CargoWorldViewModel.priceTag(attributes: { [string]: unknown }): PriceTagView?
	local keys = CargoConstants.LABEL_KEYS
	local name = attributes[keys.name]
	local value = attributes[keys.value]
	if type(name) ~= "string" or type(value) ~= "number" or value ~= value then
		return nil
	end
	local fragile = attributes[keys.fragile] == true
	local rawImpacts = attributes[keys.impacts]
	local impacts = if type(rawImpacts) == "number" then math.max(0, math.floor(rawImpacts)) else 0
	local whole = math.max(0, math.floor(value + 0.5))
	return {
		name = WorldBillboardViewModel.clip(name, CargoWorldViewModel.NAME_MAX),
		price = if attributes[keys.category] == "salvage" then `${whole}` else `+{whole}`,
		cracked = fragile and impacts > 0,
		mark = markOf(fragile, impacts),
	}
end

function CargoWorldViewModel.mounted(distance: number, mountedNow: boolean, hidden: boolean): boolean
	if hidden then
		return false
	end
	if mountedNow then
		return distance <= CargoConstants.LABEL_KEEP_DISTANCE
	end
	return distance <= CargoConstants.LABEL_DISTANCE
end

return CargoWorldViewModel
```

- [ ] **Step 6: `CargoPriceTag.luau`**

```lua
--!strict
--[=[
	CargoPriceTag: a cargo item's price tag (Figma World UI 2b, W5) at its 260x70 design size: a cream price tag with a
	pointed left end and a string hole (PaperTag), the name (Oswald 24, shrinking to 12 for the plaque) and the price
	(Oswald 24, stamp red once cracked) on top, and the mark (Oswald 14 in a 2 px stamp-red outline) under the name.
	Presentational; the words are CargoWorldViewModel.priceTag.

	@class CargoPriceTag
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local PaperLabel = require(ReplicatedStorage.Client.UI.React.Screens.Paper.PaperLabel)
local PaperTag = require(ReplicatedStorage.Client.UI.React.Screens.Paper.PaperTag)
local UIPaperConstants = require(ReplicatedStorage.Client.UI.React.Screens.Paper.UIPaperConstants)
local CargoWorldViewModel = require(ReplicatedStorage.Client.UI.React.Screens.World.CargoWorldViewModel)

local e = React.createElement

export type CargoPriceTagProps = {
	view: CargoWorldViewModel.PriceTagView,
}

local COLOR = UIPaperConstants.COLOR
local SIZE = Vector2.new(260, 70)

local function CargoPriceTag(props: CargoPriceTagProps): React.ReactNode
	local view = props.view
	local body: { [string]: React.ReactNode } = {
		name = e(PaperLabel, {
			text = view.name,
			role = "heading",
			size = 24,
			minSize = 12,
			scaled = true,
			color = COLOR.ink,
			position = UDim2.fromOffset(12, 6),
			frame = UDim2.fromOffset(150, 30),
			autoSize = false,
		}),
		price = e(PaperLabel, {
			text = view.price,
			role = "number",
			size = 24,
			scaled = true,
			color = if view.cracked then COLOR.stamp else COLOR.ink,
			align = "right",
			position = UDim2.new(1, -72, 0, 6),
			frame = UDim2.fromOffset(60, 30),
			autoSize = false,
			wrapped = false,
		}),
	}
	local mark = view.mark
	if mark ~= nil then
		body.mark = e("Frame", {
			Position = UDim2.fromOffset(12, 40),
			Size = UDim2.fromOffset(0, 0),
			AutomaticSize = Enum.AutomaticSize.XY,
			BackgroundTransparency = 1,
		}, {
			outline = e("UIStroke", {
				Color = COLOR.stamp,
				Thickness = 2,
				ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			}),
			padding = e("UIPadding", {
				PaddingLeft = UDim.new(0, 6),
				PaddingRight = UDim.new(0, 6),
				PaddingTop = UDim.new(0, 1),
				PaddingBottom = UDim.new(0, 1),
			}),
			label = e(PaperLabel, { text = mark, role = "heading", size = 14, color = COLOR.stamp, fit = true }),
		})
	end
	return e(PaperTag, { size = SIZE, paper = COLOR.cream, hole = "left" }, body)
end

return CargoPriceTag
```

- [ ] **Step 7: `CargoBillboardSystem.luau`**

```lua
--!strict
--[=[
	CargoBillboardSystem: draws cargo price tags on this client (Figma World UI 2b, W5). It watches the items' tag
	shells (UIBillboardHost.watch, tag CargoConstants.LABEL_TAG) and every LABEL_CHECK seconds mounts a tag for each
	item near the camera and unmounts the rest (CargoWorldViewModel.mounted: within 24 studs, kept until 28, never while
	hidden under a pile), so only a handful of React roots live at once. A mounted tag re-renders in place when the
	server changes its attributes (a fragile item cracked); a banked, destroyed or streamed-out item loses its root once.

	Spec-exempt shell (CollectionService, Camera, RunService, React roots); the decisions are the specced
	CargoWorldViewModel and the UIBillboards core.

	@class CargoBillboardSystem
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local React = require(ReplicatedStorage.Packages.React)
local CargoConstants = require(ReplicatedStorage.Shared.Features.Cargo.Data.CargoConstants)
local UIBillboardHost = require(ReplicatedStorage.Client.UI.Layers.UIBillboardHost)
local UIBillboards = require(ReplicatedStorage.Client.UI.Layers.UIBillboards)
local CargoPriceTag = require(ReplicatedStorage.Client.UI.React.Screens.World.CargoPriceTag)
local CargoWorldViewModel = require(ReplicatedStorage.Client.UI.React.Screens.World.CargoWorldViewModel)
local WorldBillboard = require(ReplicatedStorage.Client.UI.React.Screens.World.WorldBillboard)

export type CargoBillboardState = {
	shells: number,
	mounted: number,
	counters: { [string]: number },
}

local e = React.createElement

local roots = UIBillboards.new(UIBillboardHost.factory)
local shells: { [BillboardGui]: true } = {}
local mounted: { [BillboardGui]: true } = {}
local counters = { mounts = 0, unmounts = 0 }
local stoppers: { () -> () } = {}

local function draw(shell: BillboardGui)
	local view = CargoWorldViewModel.priceTag(shell:GetAttributes())
	roots.show(
		shell,
		if view ~= nil
			then e(WorldBillboard, { design = CargoConstants.LABEL_PX, sizing = "pixels" }, {
				tag = e(CargoPriceTag, { view = view }),
			})
			else nil
	)
end

local function distanceTo(shell: BillboardGui, from: Vector3): number
	local part = shell.Parent
	if part == nil or not part:IsA("BasePart") then
		return math.huge
	end
	return (part.Position - from).Magnitude
end

local function step()
	local camera = Workspace.CurrentCamera
	if camera == nil then
		return
	end
	local from = camera.CFrame.Position
	for shell in shells do
		local now = mounted[shell] == true
		local hidden = shell:GetAttribute(CargoConstants.LABEL_KEYS.hidden) == true
		local want = CargoWorldViewModel.mounted(distanceTo(shell, from), now, hidden)
		if want and not now then
			mounted[shell] = true
			counters.mounts += 1
			draw(shell)
		elseif now and not want then
			mounted[shell] = nil
			counters.unmounts += 1
			roots.hide(shell)
		end
	end
end

local CargoBillboardSystem = {}

function CargoBillboardSystem.start()
	if #stoppers > 0 then
		return
	end
	table.insert(
		stoppers,
		UIBillboardHost.watch({
			tag = CargoConstants.LABEL_TAG,
			roots = roots,
			refresh = function(shell)
				shells[shell] = true
				-- A mounted tag re-renders in place; an unmounted one waits for the next check.
				if mounted[shell] then
					draw(shell)
				end
			end,
			removed = function(shell)
				shells[shell] = nil
				mounted[shell] = nil
			end,
		})
	)
	local elapsed = 0
	local ticking = RunService.Heartbeat:Connect(function(deltaTime: number)
		elapsed += deltaTime
		if elapsed >= CargoConstants.LABEL_CHECK then
			elapsed = 0
			step()
		end
	end)
	table.insert(stoppers, function()
		ticking:Disconnect()
	end)
end

function CargoBillboardSystem.stop()
	for _, stop in stoppers do
		stop()
	end
	table.clear(stoppers)
	roots.teardown()
	table.clear(shells)
	table.clear(mounted)
end

function CargoBillboardSystem.getState(): CargoBillboardState
	local total = 0
	for _ in shells do
		total += 1
	end
	return { shells = total, mounted = roots.count(), counters = table.clone(counters) }
end

return CargoBillboardSystem
```

  In `CargoServiceClient.luau`: require `ReplicatedStorage.Client.Features.Cargo.Systems.CargoBillboardSystem`; in `start` after `CargoFeedbackSystem.start()` add `CargoBillboardSystem.start()`; at the top of `stop` add `CargoBillboardSystem.stop()`. Header: "CargoFeedbackSystem plays the banking swoop and floaters, …" gains "; CargoBillboardSystem draws the price tags near the camera."

- [ ] **Step 8: `CargoWorld.story.luau`**

```lua
--!strict
--[=[
	CargoWorld.story: the on-shift cargo signs (Figma World UI 2b) over the dark office, in Studio's edit mode (UI
	Labs). Price tags for a salvage item, a trash item, the longest catalog name and the fish tank after `Impacts` drops
	(0 FRAGILE, 1 CRACKED −50%, 2+ CRACKED −75%). Drawn through WorldBillboard as on a pixel-sized shell, so the
	scale follows this viewport (min(w/1920, h/1080), 0.6 to 1).

	@class CargoWorld.story
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local ReactRoblox = require(ReplicatedStorage.Packages.ReactRoblox)
local UILabs = require(ReplicatedStorage.DevPackages.UILabs)
local CargoConstants = require(ReplicatedStorage.Shared.Features.Cargo.Data.CargoConstants)
local CargoRegistry = require(ReplicatedStorage.Shared.Features.Cargo.Data.CargoRegistry)
local UIPaperConstants = require(ReplicatedStorage.Client.UI.React.Screens.Paper.UIPaperConstants)
local CargoPriceTag = require(ReplicatedStorage.Client.UI.React.Screens.World.CargoPriceTag)
local CargoWorldViewModel = require(ReplicatedStorage.Client.UI.React.Screens.World.CargoWorldViewModel)
local WorldBillboard = require(ReplicatedStorage.Client.UI.React.Screens.World.WorldBillboard)

local e = React.createElement

local KEYS = CargoConstants.LABEL_KEYS

-- A price tag for catalog item `kind` with `impacts` drops, as its shell would draw it.
local function priceTag(order: number, kind: string, impacts: number): React.ReactNode
	local def = CargoRegistry.get(kind)
	if def == nil then
		return nil
	end
	local view = CargoWorldViewModel.priceTag({
		[KEYS.name] = def.name,
		[KEYS.category] = def.category,
		[KEYS.value] = def.value,
		[KEYS.fragile] = def.fragile,
		[KEYS.impacts] = impacts,
		[KEYS.hidden] = false,
	})
	if view == nil then
		return nil
	end
	local size = CargoConstants.LABEL_PX
	return e("Frame", {
		LayoutOrder = order,
		Size = UDim2.fromOffset(size.X, size.Y),
		BackgroundTransparency = 1,
	}, {
		billboard = e(WorldBillboard, { design = size, sizing = "pixels" }, {
			tag = e(CargoPriceTag, { view = view }),
		}),
	})
end

local function row(order: number, children: { [string]: React.ReactNode }): React.ReactNode
	local content: { [string]: React.ReactNode } = {
		layout = e("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			Padding = UDim.new(0, 40),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	}
	for key, node in children do
		content[key] = node
	end
	return e("Frame", {
		LayoutOrder = order,
		Size = UDim2.fromOffset(0, 0),
		AutomaticSize = Enum.AutomaticSize.XY,
		BackgroundTransparency = 1,
	}, content)
end

return UILabs.CreateReactStory({
	react = React,
	reactRoblox = ReactRoblox,
	controls = {
		Impacts = 1,
	},
}, function(props)
	local impacts: number = math.max(0, math.floor(props.controls.Impacts))
	return e("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = UIPaperConstants.COLOR.office,
		BorderSizePixel = 0,
	}, {
		padding = e("UIPadding", {
			PaddingLeft = UDim.new(0, 60),
			PaddingTop = UDim.new(0, 60),
		}),
		layout = e("UIListLayout", {
			FillDirection = Enum.FillDirection.Vertical,
			Padding = UDim.new(0, 60),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
		tags = row(1, {
			printer = priceTag(1, "printer", 0),
			bag = priceTag(2, "rubbishBag", 0),
			plaque = priceTag(3, "plaque", 0),
			monitor = priceTag(4, "monitor", 0),
			fishTank = priceTag(5, "fishTank", impacts),
		}),
	})
end)
```

- [ ] **Step 9: `SpecRoots`.** Under "-- Cleanup Crew: Cargo":

```lua
	["ReplicatedStorage.Client.Features.Cargo.Systems.CargoBillboardSystem"] = "CollectionService/Camera/RunService/React-root shell (tag and mount rule specced in CargoWorldViewModel; roots in UIBillboards)",
	["ReplicatedStorage.Client.UI.React.Screens.World.CargoPriceTag"] = "presentational React component (tag specced in CargoWorldViewModel; story in CargoWorld.story)",
```

- [ ] **Step 10: Controller: Studio TestEZ**, then the visual and live checks. Expected TestEZ: every `CargoWorldViewModel` case passes; `assertAllModulesSpecced` passes.
  - UI Labs, `World → CargoWorld`: the tags beside frame 2b's W5 (point and hole on the left, name/price on top, red outlined mark; the plaque's name shrinks but stays whole inside the tag); `Impacts` 0/1/2 → FRAGILE / CRACKED −50% / CRACKED −75% with a red price.
  - Fresh Play, solo shift: tags appear only on items within ~24 studs and vanish past 28; nothing shows over a pile until it is vacuumed away; drop the monitor once: its tag reads CRACKED −50% with a red price, without flicker. In the client command bar, standing in a busy room: `print(require(game.ReplicatedStorage.Client.Features.Cargo.Systems.CargoBillboardSystem).getState().mounted)` is far below `.shells`. Review Focus 1: stand in the loading bay with no other cargo within 28 studs, bank everything you carry (hands and pockets): `mounted` reads `0` right after, and Output shows no error (in particular no "Parent property … is locked"). If it errors, stop and report.

- [ ] **Step 11: Gate and commit**

```bash
git add src
python3 scripts/python/module_map.py --write
git add docs/project-structure.md
stylua src/ReplicatedStorage/Shared/Features/Cargo/Data/CargoConstants.luau src/ServerScriptService/Features/Cargo/Systems/CargoSpawnSystem.luau src/ReplicatedStorage/Client/UI/React/Screens/World/CargoWorldViewModel.luau src/ReplicatedStorage/Client/UI/React/Screens/World/CargoWorldViewModel.spec.luau src/ReplicatedStorage/Client/UI/React/Screens/World/CargoPriceTag.luau src/ReplicatedStorage/Client/UI/React/Screens/World/CargoWorld.story.luau src/ReplicatedStorage/Client/Features/Cargo/Systems/CargoBillboardSystem.luau src/ReplicatedStorage/Client/Features/Cargo/CargoServiceClient.luau src/ServerScriptService/Core/Testing/SpecRoots.luau
git add src
PYTHONUTF8=1 bash .superpowers/sdd/gate.sh
python3 scripts/python/check_pr_rules.py origin/main
git commit -m "feat(cargo): paper price tags on cargo near the camera"
python3 scripts/python/module_map.py --check
```

---

### Task 7: W6 load floaters

The "+N" floaters stay client-side in `CargoFeedbackSystem` with their rise and fade, but each one is now drawn with the kit through a React root in its BillboardGui: clearance as a big glow-green "+15" with a 4 px night outline and "CLEARED" under it, the bonus as a tilted blue stamp "+40 BONUS". The fade is a binding the existing tween drives (a NumberValue tweened 0 → 1), so the React tree is never touched by the tween and never re-renders while it fades. The three floater look constants go.

**Files:**
- Modify: `src/ReplicatedStorage/Shared/Features/Cargo/Data/CargoConstants.luau` (`FLOATER_FONT`, `CLEARANCE_COLOR`, `BONUS_COLOR` removed; `FLOATER_PX` added)
- Modify: `src/ReplicatedStorage/Client/UI/React/Screens/World/CargoWorldViewModel.luau` (`floater`); Test: `.../World/CargoWorldViewModel.spec.luau`
- Create: `src/ReplicatedStorage/Client/UI/React/Screens/World/CargoLoadFloater.luau`
- Modify: `src/ReplicatedStorage/Client/Features/Cargo/Systems/CargoFeedbackSystem.luau` (`floater` restyled; `release`; floaters cleaned on stop)
- Modify: `src/ReplicatedStorage/Client/UI/React/Screens/World/CargoWorld.story.luau`
- Modify: `src/ServerScriptService/Core/Testing/SpecRoots.luau`

**Interfaces:**
- Consumes: `CargoFeedbackUtils.Floater = { text: string, tone: "clearance" | "bonus" }` and `CargoFeedbackUtils.floaters(clearance, bonus)`; `UIBillboardHost.factory`, `UIBillboards.BillboardHandle` (Task 3); `WorldBillboard` (`sizing = "pixels"`); `React.createBinding<T>(initial: T) -> (React.Binding<T>, (T) -> ())`; `UIPaperConstants.COLOR.fluorGlow / night / monitor / monitorDeep`, `FONT.number / heading`.
- Produces:
  - `CargoConstants.FLOATER_PX = Vector2.new(340, 130)`.
  - `CargoWorldViewModel.FloaterView = { bonus: boolean, text: string, caption: string? }`; `floater(item: CargoFeedbackUtils.Floater) -> FloaterView`.
  - `CargoLoadFloater(props: { view: CargoWorldViewModel.FloaterView, fade: React.Binding<number> })` at 340×130.

- [ ] **Step 1: Write the failing spec.** In `CargoWorldViewModel.spec.luau` add:

```lua
	describe("floater", function()
		it("pops clearance as the number over CLEARED", function()
			local view = CargoWorldViewModel.floater({ text = "+15", tone = "clearance" })
			expect(view.bonus).to.equal(false)
			expect(view.text).to.equal("+15")
			expect(view.caption).to.equal("CLEARED")
		end)

		it("stamps the finder's fee as a BONUS with no caption", function()
			local view = CargoWorldViewModel.floater({ text = "+40", tone = "bonus" })
			expect(view.bonus).to.equal(true)
			expect(view.text).to.equal("+40 BONUS")
			expect(view.caption).to.equal(nil)
		end)
	end)
```

- [ ] **Step 2: Controller: Studio TestEZ.** Expected: the two new cases fail (`floater` missing).

- [ ] **Step 3: `CargoWorldViewModel.floater`.** Require `ReplicatedStorage.Shared.Features.Cargo.Utils.CargoFeedbackUtils`; header gains "The load floaters (W6): clearance pops as the number over CLEARED, the finder's fee as a \"+40 BONUS\" stamp (the approved frame's copy)."; add:

```lua
export type FloaterView = {
	-- The finder's fee: drawn as the blue stamp.
	bonus: boolean,
	text: string,
	caption: string?,
}

function CargoWorldViewModel.floater(item: CargoFeedbackUtils.Floater): FloaterView
	if item.tone == "bonus" then
		return { bonus = true, text = `{item.text} BONUS`, caption = nil }
	end
	return { bonus = false, text = item.text, caption = "CLEARED" }
end
```

- [ ] **Step 4: `CargoLoadFloater.luau`**

```lua
--!strict
--[=[
	CargoLoadFloater: a load floater (Figma World UI 2b, W6) at its 340x130 design size. Clearance: "+15" in Oswald 80
	fluorGlow with a 4 px night outline over "CLEARED" (Oswald 26). Bonus: a 300x96 monitorDeep stamp with a 5 px
	monitor ring, "+40 BONUS" in Oswald 64 monitor blue, turned 5°. `fade` (0 → 1) is every part's transparency, driven
	by CargoFeedbackSystem's tween, so fading never re-renders. Presentational; the words are CargoWorldViewModel.floater.

	@class CargoLoadFloater
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local UIPaperConstants = require(ReplicatedStorage.Client.UI.React.Screens.Paper.UIPaperConstants)
local CargoWorldViewModel = require(ReplicatedStorage.Client.UI.React.Screens.World.CargoWorldViewModel)

local e = React.createElement

export type CargoLoadFloaterProps = {
	view: CargoWorldViewModel.FloaterView,
	fade: React.Binding<number>,
}

local COLOR = UIPaperConstants.COLOR
local FONT = UIPaperConstants.FONT

-- Oswald text in fluorGlow with a night outline (the stroke follows the glyphs: Contextual).
local function outlined(
	text: string,
	size: number,
	outline: number,
	y: number,
	height: number,
	fade: React.Binding<number>
): React.ReactNode
	return e("TextLabel", {
		Position = UDim2.fromOffset(0, y),
		Size = UDim2.new(1, 0, 0, height),
		BackgroundTransparency = 1,
		FontFace = FONT.number,
		TextSize = size,
		TextColor3 = COLOR.fluorGlow,
		TextTransparency = fade,
		TextXAlignment = Enum.TextXAlignment.Center,
		RichText = false,
		Text = text,
	}, {
		outline = e("UIStroke", {
			Color = COLOR.night,
			Thickness = outline,
			Transparency = fade,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual,
		}),
	})
end

local function CargoLoadFloater(props: CargoLoadFloaterProps): React.ReactNode
	local view = props.view
	local fade = props.fade
	if view.bonus then
		return e("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(300, 96),
			Rotation = 5,
			BackgroundColor3 = COLOR.monitorDeep,
			BackgroundTransparency = fade,
			BorderSizePixel = 0,
		}, {
			corner = e("UICorner", { CornerRadius = UDim.new(0, 6) }),
			ring = e("UIStroke", {
				Color = COLOR.monitor,
				Thickness = 5,
				Transparency = fade,
				ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			}),
			label = e("TextLabel", {
				Size = UDim2.fromScale(1, 1),
				BackgroundTransparency = 1,
				FontFace = FONT.heading,
				TextScaled = true,
				TextColor3 = COLOR.monitor,
				TextTransparency = fade,
				RichText = false,
				Text = view.text,
			}, {
				limit = e("UITextSizeConstraint", { MaxTextSize = 64, MinTextSize = 32 }),
				padding = e("UIPadding", {
					PaddingLeft = UDim.new(0, 14),
					PaddingRight = UDim.new(0, 14),
				}),
			}),
		})
	end
	local children: { [string]: React.ReactNode } = {
		amount = outlined(view.text, 80, 4, 0, 92, fade),
	}
	local caption = view.caption
	if caption ~= nil then
		children.caption = outlined(caption, 26, 2, 92, 34, fade)
	end
	return e("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
	}, children)
end

return CargoLoadFloater
```

- [ ] **Step 5: `CargoFeedbackSystem` draws them.** Requires: `React` (`ReplicatedStorage.Packages.React`), `UIBillboardHost`, `UIBillboards` (`ReplicatedStorage.Client.UI.Layers.…`), `CargoLoadFloater`, `CargoWorldViewModel`, `WorldBillboard` (`ReplicatedStorage.Client.UI.React.Screens.World.…`). Add after `type Swoop`:

```lua
-- A floater on screen: its anchor (which holds the BillboardGui and the fade value) and its React root.
type Floating = {
	anchor: Attachment,
	root: UIBillboards.BillboardHandle,
}
```

  and the state `local floating: { Floating } = {}` beside `swoops`. Replace `floater` with:

```lua
-- Unmounts a floater's root, then destroys its anchor (and with it the BillboardGui). Once per floater.
local function release(entry: Floating)
	local index = table.find(floating, entry)
	if index == nil then
		return
	end
	table.remove(floating, index)
	entry.root.unmount()
	entry.root.destroy()
	entry.anchor:Destroy()
end

local function floater(at: Vector3, index: number, item: CargoFeedbackUtils.Floater)
	local anchor = Instance.new("Attachment")
	anchor.Name = "CargoFloater"
	anchor.Parent = Workspace.Terrain
	anchor.WorldPosition = at + Vector3.new(0, 1 + index * CargoConstants.FLOATER_SPACING, 0)
	local size = CargoConstants.FLOATER_PX
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(size.X, size.Y)
	gui.AlwaysOnTop = true
	gui.LightInfluence = 0
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.MaxDistance = CargoConstants.FLOATER_DISTANCE
	gui.Adornee = anchor
	gui.Parent = anchor
	local fade, setFade = React.createBinding(0)
	local entry: Floating = { anchor = anchor, root = UIBillboardHost.factory(gui) }
	table.insert(floating, entry)
	entry.root.render(e(WorldBillboard, { design = size, sizing = "pixels" }, {
		floater = e(CargoLoadFloater, { view = CargoWorldViewModel.floater(item), fade = fade }),
	}))
	local info = TweenInfo.new(CargoConstants.FLOATER_SECONDS, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(gui, info, { StudsOffset = Vector3.new(0, CargoConstants.FLOATER_RISE, 0) }):Play()
	-- The fade tweens a value that drives the floater's transparency binding; the React tree itself is never tweened.
	local alpha = Instance.new("NumberValue")
	alpha.Parent = anchor
	alpha.Changed:Connect(function(value: number)
		setFade(value)
	end)
	local fadeOut = TweenService:Create(alpha, info, { Value = 1 })
	fadeOut.Completed:Once(function()
		release(entry)
	end)
	fadeOut:Play()
	counters.floaters += 1
end
```

  (`local e = React.createElement` goes under the requires. The `Changed` connection dies with `alpha` when the anchor is destroyed.)

  In `stop`, after the swoops are cleared:

```lua
	while #floating > 0 do
		release(floating[1])
	end
```

  `getState` adds `floating = #floating` (and `CargoFeedbackState` gains `floating: number`). Header: "a rising \"+N\" per amount (clearance green, bonus blue; CargoFeedbackUtils.floaters)" → "a rising, fading load floater per amount, drawn with the paper kit (CargoLoadFloater: \"+15 CLEARED\", the \"+40 BONUS\" stamp; CargoWorldViewModel.floater)".

  In `CargoConstants.luau` replace

```lua
	-- The "+N" floaters: life, rise, spacing between two, draw distance, look.
```

  with

```lua
	-- The load floaters: life, rise, spacing between two, draw distance, design size in px (CargoLoadFloater).
```

  delete `FLOATER_FONT`, `CLEARANCE_COLOR`, `BONUS_COLOR`, and after `FLOATER_DISTANCE` add `FLOATER_PX = Vector2.new(340, 130),`.

- [ ] **Step 6: `CargoWorld.story`.** Require `CargoLoadFloater`; the story hands each floater a fixed binding (`React.createBinding`), so no hook is needed. Add a control `Fade = 0` and a second row; header gains "and the two load floaters (`Fade` 0..1 previews the fade)":

```lua
local function floaterSign(order: number, text: string, tone: "clearance" | "bonus", fade: number): React.ReactNode
	local size = CargoConstants.FLOATER_PX
	local binding = React.createBinding(fade)
	return e("Frame", {
		LayoutOrder = order,
		Size = UDim2.fromOffset(size.X, size.Y),
		BackgroundTransparency = 1,
	}, {
		billboard = e(WorldBillboard, { design = size, sizing = "pixels" }, {
			floater = e(CargoLoadFloater, {
				view = CargoWorldViewModel.floater({ text = text, tone = tone }),
				fade = binding,
			}),
		}),
	})
end
```

  and in the returned children:

```lua
		floaters = row(2, {
			clearance = floaterSign(1, "+15", "clearance", math.clamp(props.controls.Fade, 0, 1)),
			bonus = floaterSign(2, "+40", "bonus", math.clamp(props.controls.Fade, 0, 1)),
		}),
```

- [ ] **Step 7: `SpecRoots`.** Under "-- Cleanup Crew: Cargo":

```lua
	["ReplicatedStorage.Client.UI.React.Screens.World.CargoLoadFloater"] = "presentational React component (floater specced in CargoWorldViewModel; story in CargoWorld.story)",
```

  and update the `CargoFeedbackSystem` line's reason to "Instance/tween/ByteNet/Charm/React-root shell (choices and arc specced in CargoFeedbackUtils; floater words in CargoWorldViewModel)".

- [ ] **Step 8: Controller: Studio TestEZ**, then the visual and live checks. Expected TestEZ: the `floater` cases pass; nothing else regresses.
  - UI Labs, `World → CargoWorld`: the two floaters beside frame 2b's W6 (outline weight, CLEARED spacing, stamp tilt and ring); `Fade` 0.5 fades every part evenly, 1 hides them.
  - Fresh Play, solo shift: load a rubbish bag: "+10 / CLEARED" rises and fades over 1.4 s; load salvage: "+N BONUS" stamp rises above it. Load several items at once: floaters stack 1.3 studs apart as before. In the client command bar, 2 s after a load: `print(require(game.ReplicatedStorage.Client.Features.Cargo.Systems.CargoFeedbackSystem).getState().floating)` prints `0` and `Workspace.Terrain` holds no `CargoFloater`. No Output errors.

- [ ] **Step 9: Gate and commit**

```bash
git add src
python3 scripts/python/module_map.py --write
git add docs/project-structure.md
stylua src/ReplicatedStorage/Shared/Features/Cargo/Data/CargoConstants.luau src/ReplicatedStorage/Client/UI/React/Screens/World/CargoWorldViewModel.luau src/ReplicatedStorage/Client/UI/React/Screens/World/CargoWorldViewModel.spec.luau src/ReplicatedStorage/Client/UI/React/Screens/World/CargoLoadFloater.luau src/ReplicatedStorage/Client/UI/React/Screens/World/CargoWorld.story.luau src/ReplicatedStorage/Client/Features/Cargo/Systems/CargoFeedbackSystem.luau src/ServerScriptService/Core/Testing/SpecRoots.luau
git add src
PYTHONUTF8=1 bash .superpowers/sdd/gate.sh
python3 scripts/python/check_pr_rules.py origin/main
git commit -m "feat(cargo): load floaters restyled with the paper kit"
python3 scripts/python/module_map.py --check
```

---

### Task 8: W7 cue and W8 memo

Harlow's "?" / "!" and his speech bubble become two empty tagged shells on his head; the server writes only the `OccupantCue` and `OccupantLine` attributes (`say` sets the line, then clears it after `SPEECH_SECONDS`, as it cleared the text before). The client draws a sticky-yellow "?" disc or a tilted red "!" stamp disc (W7) and a typed memo with a red letterhead and a tail (W8); a shouted line (it ends with "!", or it has 3+ letters and none lowercase) goes red and bigger. The typing moves into the memo (`useTypedGraphemes`, the same `OccupantFeedbackUtils.reveal` at `TYPE_RATE`), and `OccupantPresenceSystem` keeps only the gibberish voice, now triggered by the line attribute. `OccupantServiceServer` (397 lines) is not touched: it keeps calling `OccupantRigSystem.setCue` / `say`.

**Files:**
- Modify: `src/ReplicatedStorage/Shared/Features/Occupant/Data/OccupantConstants.luau`
- Modify: `src/ServerScriptService/Features/Occupant/Systems/OccupantRigSystem.luau`
- Create: `src/ReplicatedStorage/Client/UI/React/Screens/World/OccupantWorldViewModel.luau`; Test: `.../World/OccupantWorldViewModel.spec.luau`
- Create: `src/ReplicatedStorage/Client/UI/React/Screens/World/useTypedGraphemes.luau`
- Create: `src/ReplicatedStorage/Client/UI/React/Screens/World/OccupantCueDisc.luau`, `.../World/OccupantMemo.luau`
- Create: `src/ReplicatedStorage/Client/Features/Occupant/Systems/OccupantBillboardSystem.luau`
- Modify: `src/ReplicatedStorage/Client/Features/Occupant/Systems/OccupantPresenceSystem.luau`
- Modify: `src/ReplicatedStorage/Client/Features/Occupant/OccupantServiceClient.luau`
- Create: `src/ReplicatedStorage/Client/UI/React/Screens/World/OccupantWorld.story.luau`
- Modify: `src/ServerScriptService/Core/Testing/SpecRoots.luau`

**Interfaces:**
- Consumes: `UIBillboards`, `UIBillboardHost` (Task 3); `WorldBillboard` (`studs` for the cue, `pixels` for the memo), `PaperTexture`, `WorldBillboardViewModel.clip` (Tasks 1–2); `PaperLabel`; `UIPaperConstants.inkColor(ink: Ink): Color3`, `UIPaperConstants.Ink`; `OccupantFeedbackUtils.reveal(total, elapsed, rate): number`, `.voiced(line): boolean`, `.clipFor(line, count): number?`; `OccupantConstants.TYPE_RATE` (28), `SPEECH_SECONDS`, `CUE_NAME`, `SPEECH_NAME`; `OccupantServiceServer`'s existing calls `OccupantRigSystem.setCue(rig, OccupantTellRules.cueFor(mode))` ("?" / "!" / "") and `OccupantRigSystem.say(rig, line)`.
- Produces:
  - `OccupantConstants.CUE_TAG = "OccupantCueBillboard"`, `SPEECH_TAG = "OccupantSpeechBillboard"`, `CUE_ATTRIBUTE = "OccupantCue"`, `LINE_ATTRIBUTE = "OccupantLine"`, `CUE_STUDS = 2.5`, `CUE_PX = Vector2.new(140, 140)`, `MEMO_PX = Vector2.new(520, 166)`; `SPEECH_FONT`, `SPEECH_PAPER`, `SPEECH_INK`, `SPEECH_BORDER` removed.
  - `OccupantRigSystem.Rig = { model: Model, humanoid: Humanoid, root: BasePart, head: BasePart, cue: BillboardGui, speech: BillboardGui }` (`bubble` removed; `cue` / `speech` are now the shells).
  - `OccupantWorldViewModel.LINE_MAX = 80`, `MIN_SHOUT_LETTERS = 3`, `MEMO_BAND = "MEMO — FROM THE DESK OF H. HARLOW"`; `CueView = { glyph: string, fill: Color3, ring: Color3, ink: Color3, tilt: number }`; `MemoView = { band: string, text: string, shouted: boolean, size: number, ink: UIPaperConstants.Ink }`; `shouted(line: string) -> boolean`; `memo(line: unknown) -> MemoView?`; `cue(text: unknown) -> CueView?`.
  - `useTypedGraphemes(text: string, rate: number) -> React.Binding<number>` (a `MaxVisibleGraphemes` value: 0.. while typing, -1 once the line is out; restarts only when `text` or `rate` changes).
  - `OccupantCueDisc(props: { view: CueView })` at 140×140; `OccupantMemo(props: { view: MemoView })` at 520×166.
  - `OccupantBillboardSystem.start()`, `.stop()`, `.getState() -> { mounted: number }`.

- [ ] **Step 1: Write the failing spec** `OccupantWorldViewModel.spec.luau`:

```lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local OccupantWorldViewModel = require(script.Parent.OccupantWorldViewModel)
local UIPaperConstants = require(ReplicatedStorage.Client.UI.React.Screens.Paper.UIPaperConstants)

local COLOR = UIPaperConstants.COLOR

return function()
	describe("shouted", function()
		it("shouts a line that ends with !", function()
			expect(OccupantWorldViewModel.shouted("You're FIRED!")).to.equal(true)
			expect(OccupantWorldViewModel.shouted("Who authorised this?!")).to.equal(true)
			expect(OccupantWorldViewModel.shouted("  stop!  ")).to.equal(true)
		end)

		it("shouts a line in capitals with at least three letters", function()
			expect(OccupantWorldViewModel.shouted("COMPANY ASSETS.")).to.equal(true)
			expect(OccupantWorldViewModel.shouted("NOPE.")).to.equal(true)
			expect(OccupantWorldViewModel.shouted("*SIGH*")).to.equal(true)
		end)

		it("speaks a line with any lowercase letter, or too few letters", function()
			expect(OccupantWorldViewModel.shouted("Those are COMPANY ASSETS.")).to.equal(false)
			expect(OccupantWorldViewModel.shouted("Per my last email…")).to.equal(false)
			expect(OccupantWorldViewModel.shouted("*sigh*")).to.equal(false)
			expect(OccupantWorldViewModel.shouted("OK")).to.equal(false)
			expect(OccupantWorldViewModel.shouted("...")).to.equal(false)
			expect(OccupantWorldViewModel.shouted("")).to.equal(false)
		end)
	end)

	describe("memo", function()
		it("types a spoken line in ink at the body size", function()
			local view = OccupantWorldViewModel.memo("Those are COMPANY ASSETS.")
			expect(view.band).to.equal("MEMO — FROM THE DESK OF H. HARLOW")
			expect(view.text).to.equal("Those are COMPANY ASSETS.")
			expect(view.shouted).to.equal(false)
			expect(view.size).to.equal(30)
			expect(view.ink).to.equal("ink")
		end)

		it("makes a shouted line red and bigger", function()
			local view = OccupantWorldViewModel.memo("You're FIRED!")
			expect(view.shouted).to.equal(true)
			expect(view.size).to.equal(38)
			expect(view.ink).to.equal("danger")
		end)

		it("caps a line at 80 characters", function()
			local view = OccupantWorldViewModel.memo(string.rep("a", 200))
			expect(utf8.len(view.text)).to.equal(OccupantWorldViewModel.LINE_MAX)
			expect(OccupantWorldViewModel.LINE_MAX).to.equal(80)
			expect(string.sub(view.text, -3)).to.equal("…")
		end)

		it("draws no memo for an empty line or a value that is not text", function()
			expect(OccupantWorldViewModel.memo("")).to.equal(nil)
			expect(OccupantWorldViewModel.memo(nil)).to.equal(nil)
			expect(OccupantWorldViewModel.memo(5)).to.equal(nil)
			expect(OccupantWorldViewModel.memo(true)).to.equal(nil)
		end)
	end)

	describe("cue", function()
		it("draws ? as a sticky disc with a black ring, upright", function()
			local view = OccupantWorldViewModel.cue("?")
			expect(view.glyph).to.equal("?")
			expect(view.fill).to.equal(COLOR.sticky)
			expect(view.ring).to.equal(COLOR.night)
			expect(view.ink).to.equal(COLOR.night)
			expect(view.tilt).to.equal(0)
		end)

		it("draws ! as a red stamp disc with a cream ring, tilted", function()
			local view = OccupantWorldViewModel.cue("!")
			expect(view.glyph).to.equal("!")
			expect(view.fill).to.equal(COLOR.stamp)
			expect(view.ring).to.equal(COLOR.cream)
			expect(view.ink).to.equal(COLOR.cream)
			expect(view.tilt).to.equal(-8)
		end)

		it("draws nothing for no cue or anything else", function()
			expect(OccupantWorldViewModel.cue("")).to.equal(nil)
			expect(OccupantWorldViewModel.cue(nil)).to.equal(nil)
			expect(OccupantWorldViewModel.cue("?!")).to.equal(nil)
			expect(OccupantWorldViewModel.cue(1)).to.equal(nil)
		end)
	end)
end
```

- [ ] **Step 2: Controller: Studio TestEZ.** Expected: the new cases fail (`OccupantWorldViewModel` missing).

- [ ] **Step 3: Constants.** In `OccupantConstants.luau`, replace

```lua
	-- His billboards (placeholders).
	CUE_NAME = "OccupantCue",
	SPEECH_NAME = "OccupantSpeech",
```

  with

```lua
	-- His two billboard shells on his head (M3b world UI): empty, tagged, drawn by the client (OccupantBillboardSystem);
	-- the server writes only their attributes ("?" / "!" / "" and the line, "" when none). The cue shell is CUE_STUDS
	-- square (design CUE_PX); the memo shell is MEMO_PX px (the 520x140 memo, its 24 px tail and a margin).
	CUE_NAME = "OccupantCue",
	SPEECH_NAME = "OccupantSpeech",
	CUE_TAG = "OccupantCueBillboard",
	SPEECH_TAG = "OccupantSpeechBillboard",
	CUE_ATTRIBUTE = "OccupantCue",
	LINE_ATTRIBUTE = "OccupantLine",
	CUE_STUDS = 2.5,
	CUE_PX = Vector2.new(140, 140),
	MEMO_PX = Vector2.new(520, 166),
```

  and replace

```lua
	-- His speech bubble as a memo (spec §7 "typewriter type"): paper, ink, a thin border; the client types each
	-- line out at TYPE_RATE characters a second.
	SPEECH_FONT = Enum.Font.SpecialElite,
	SPEECH_PAPER = Color3.fromRGB(248, 243, 226),
	SPEECH_INK = Color3.fromRGB(34, 30, 26),
	SPEECH_BORDER = Color3.fromRGB(70, 60, 46),
	TYPE_RATE = 28,
```

  with

```lua
	-- His memo types each line out at TYPE_RATE characters a second (spec §7 "typewriter type"; useTypedGraphemes).
	TYPE_RATE = 28,
```

- [ ] **Step 4: The server shells.** In `OccupantRigSystem.luau`:
  - `Rig` becomes `{ model: Model, humanoid: Humanoid, root: BasePart, head: BasePart, cue: BillboardGui, speech: BillboardGui }`.
  - Delete `CUE_COLOR`, `SPOTTED_COLOR` and `billboard`; replace `tells` with:

```lua
-- An empty shell over his head for the client to draw into (OccupantBillboardSystem): its attribute starts "", then
-- the tag, then the parent.
local function shell(name: string, size: UDim2, offset: Vector3, tag: string, attribute: string, head: BasePart): BillboardGui
	local gui = Instance.new("BillboardGui")
	gui.Name = name
	gui.Size = size
	gui.StudsOffset = offset
	gui.AlwaysOnTop = true
	gui.MaxDistance = 90
	gui.LightInfluence = 0
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui:SetAttribute(attribute, "")
	CollectionService:AddTag(gui, tag)
	gui.Parent = head
	return gui
end

-- His cue disc and memo shells on his head.
local function tells(head: BasePart): (BillboardGui, BillboardGui)
	local studs = OccupantConstants.CUE_STUDS
	local memo = OccupantConstants.MEMO_PX
	local cue = shell(
		OccupantConstants.CUE_NAME,
		UDim2.fromScale(studs, studs),
		Vector3.new(0, 2.5, 0),
		OccupantConstants.CUE_TAG,
		OccupantConstants.CUE_ATTRIBUTE,
		head
	)
	local speech = shell(
		OccupantConstants.SPEECH_NAME,
		UDim2.fromOffset(memo.X, memo.Y),
		Vector3.new(0, 4.5, 0),
		OccupantConstants.SPEECH_TAG,
		OccupantConstants.LINE_ATTRIBUTE,
		head
	)
	return cue, speech
end
```

  - In `build`: `local cue, speech, bubble = tells(head)` → `local cue, speech = tells(head)`, and the returned rig drops `bubble`.
  - `setCue` and `say` become:

```lua
--[=[
	The cue over his head ("?", "!" or ""), as the cue shell's attribute; the client draws the disc.
]=]
function OccupantRigSystem.setCue(rig: Rig, text: string)
	rig.cue:SetAttribute(OccupantConstants.CUE_ATTRIBUTE, text)
end

--[=[
	Puts a line on his memo for SPEECH_SECONDS (a newer line replaces it), as the speech shell's attribute; the client
	types and voices it.
]=]
function OccupantRigSystem.say(rig: Rig, line: string)
	local token = (speechTokens[rig.model] or 0) + 1
	speechTokens[rig.model] = token
	rig.speech:SetAttribute(OccupantConstants.LINE_ATTRIBUTE, line)
	task.delay(OccupantConstants.SPEECH_SECONDS, function()
		if speechTokens[rig.model] == token and rig.speech.Parent ~= nil then
			-- Cleared so the next identical line changes the attribute and the client types and voices it again.
			rig.speech:SetAttribute(OccupantConstants.LINE_ATTRIBUTE, "")
		end
	end)
end
```

  - Header: "…adds a cue billboard (\"?\" / \"!\") and a plain speech bubble over his head, … The bubble is a typed paper memo (M3); the client voices and types each line (OccupantPresenceSystem)." → "…adds two empty tagged shells over his head (his cue and his memo; the server writes only their attributes, the client draws them: OccupantBillboardSystem, and voices each line: OccupantPresenceSystem)…".

- [ ] **Step 5: `OccupantWorldViewModel.luau`**

```lua
--!strict
--[=[
	OccupantWorldViewModel: what Mr. Harlow's world signs show (Figma World UI 2b). The cue (W7): "?" (curious) is a
	sticky-yellow disc with a black ring, "!" (spotted) a red stamp disc with a cream ring and glyph, tilted -8°; any
	other value draws nothing. The memo (W8): the red letterhead, the line cut at LINE_MAX characters, and the shout rule:
	a line that ends with "!" or has MIN_SHOUT_LETTERS+ ASCII letters and none lowercase is shouted, drawn red at 38
	instead of ink at 30. An empty line, or a value that is not text, draws no memo. Pure.

	@class OccupantWorldViewModel
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local UIPaperConstants = require(ReplicatedStorage.Client.UI.React.Screens.Paper.UIPaperConstants)
local WorldBillboardViewModel = require(ReplicatedStorage.Client.UI.React.Screens.World.WorldBillboardViewModel)

export type CueView = {
	glyph: string,
	fill: Color3,
	ring: Color3,
	ink: Color3,
	tilt: number,
}

export type MemoView = {
	band: string,
	text: string,
	shouted: boolean,
	size: number,
	ink: UIPaperConstants.Ink,
}

local COLOR = UIPaperConstants.COLOR

local OccupantWorldViewModel = {}

OccupantWorldViewModel.LINE_MAX = 80
OccupantWorldViewModel.MIN_SHOUT_LETTERS = 3
OccupantWorldViewModel.MEMO_BAND = "MEMO — FROM THE DESK OF H. HARLOW"

function OccupantWorldViewModel.shouted(line: string): boolean
	local trimmed = string.match(line, "^%s*(.-)%s*$") or ""
	if string.sub(trimmed, -1) == "!" then
		return true
	end
	local _, letters = string.gsub(trimmed, "[A-Za-z]", "")
	return letters >= OccupantWorldViewModel.MIN_SHOUT_LETTERS and string.find(trimmed, "[a-z]") == nil
end

function OccupantWorldViewModel.memo(line: unknown): MemoView?
	if type(line) ~= "string" or line == "" then
		return nil
	end
	local loud = OccupantWorldViewModel.shouted(line)
	return {
		band = OccupantWorldViewModel.MEMO_BAND,
		text = WorldBillboardViewModel.clip(line, OccupantWorldViewModel.LINE_MAX),
		shouted = loud,
		size = if loud then 38 else 30,
		ink = if loud then "danger" else "ink",
	}
end

function OccupantWorldViewModel.cue(text: unknown): CueView?
	if text == "?" then
		return { glyph = "?", fill = COLOR.sticky, ring = COLOR.night, ink = COLOR.night, tilt = 0 }
	elseif text == "!" then
		return { glyph = "!", fill = COLOR.stamp, ring = COLOR.cream, ink = COLOR.cream, tilt = -8 }
	end
	return nil
end

return OccupantWorldViewModel
```

- [ ] **Step 6: The components.**

  `useTypedGraphemes.luau`:

```lua
--!strict
--[=[
	useTypedGraphemes: a MaxVisibleGraphemes binding that types `text` out at `rate` characters a second, from when the
	text appears (OccupantFeedbackUtils.reveal), and reads -1 once the whole line is out. It restarts only when `text`
	or `rate` changes, so a re-render with the same line never retypes it. Writes the binding only, on RenderStepped.
	React hook (exempt: needs a renderer and RunService); the reveal maths is the specced OccupantFeedbackUtils.reveal.

	@class useTypedGraphemes
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local React = require(ReplicatedStorage.Packages.React)
local OccupantFeedbackUtils = require(ReplicatedStorage.Shared.Features.Occupant.Utils.OccupantFeedbackUtils)

local function useTypedGraphemes(text: string, rate: number): React.Binding<number>
	local shown, setShown = React.useBinding(0)
	React.useEffect(function(): () -> ()
		local total = utf8.len(text) or #text
		local started = os.clock()
		setShown(0)
		local connection: RBXScriptConnection? = nil
		connection = RunService.RenderStepped:Connect(function(_deltaTime: number)
			local count = OccupantFeedbackUtils.reveal(total, os.clock() - started, rate)
			if count >= total then
				setShown(-1)
				if connection ~= nil then
					connection:Disconnect()
				end
			else
				setShown(count)
			end
		end)
		return function()
			if connection ~= nil then
				connection:Disconnect()
			end
		end
	end, { text, rate })
	return shown
end

return useTypedGraphemes
```

  (If luau-lsp rejects the mixed dependency list, stop and report; never cast it.)

  `OccupantCueDisc.luau`:

```lua
--!strict
--[=[
	OccupantCueDisc: Harlow's cue (Figma World UI 2b, W7) at its 140x140 design size: a Ø120 disc with a 6 px ring and
	the glyph in Oswald 90, turned by the view's tilt, over a soft night shadow. Presentational; the colours and tilt are
	OccupantWorldViewModel.cue.

	@class OccupantCueDisc
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local PaperLabel = require(ReplicatedStorage.Client.UI.React.Screens.Paper.PaperLabel)
local UIPaperConstants = require(ReplicatedStorage.Client.UI.React.Screens.Paper.UIPaperConstants)
local OccupantWorldViewModel = require(ReplicatedStorage.Client.UI.React.Screens.World.OccupantWorldViewModel)

local e = React.createElement

export type OccupantCueDiscProps = {
	view: OccupantWorldViewModel.CueView,
}

local DISC = 120

local function OccupantCueDisc(props: OccupantCueDiscProps): React.ReactNode
	local view = props.view
	return e("Frame", {
		Size = UDim2.fromOffset(140, 140),
		BackgroundTransparency = 1,
	}, {
		shadow = e("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0.5, 0, 0.5, 5),
			Size = UDim2.fromOffset(DISC + 12, DISC + 12),
			BackgroundColor3 = UIPaperConstants.COLOR.night,
			BackgroundTransparency = 0.5,
			BorderSizePixel = 0,
			ZIndex = 1,
		}, { corner = e("UICorner", { CornerRadius = UDim.new(0.5, 0) }) }),
		disc = e("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(DISC, DISC),
			Rotation = view.tilt,
			BackgroundColor3 = view.fill,
			BorderSizePixel = 0,
			ZIndex = 2,
		}, {
			corner = e("UICorner", { CornerRadius = UDim.new(0.5, 0) }),
			ring = e("UIStroke", {
				Color = view.ring,
				Thickness = 6,
				ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			}),
			glyph = e(PaperLabel, {
				text = view.glyph,
				role = "heading",
				size = 90,
				color = view.ink,
				align = "center",
				frame = UDim2.fromScale(1, 1),
				autoSize = false,
				wrapped = false,
			}),
		}),
	})
end

return OccupantCueDisc
```

  `OccupantMemo.luau`:

```lua
--!strict
--[=[
	OccupantMemo: Harlow's speech (Figma World UI 2b, W8) at its 520x166 design size: a 520x140 cream memo (textured once
	uploaded) under a 30 px stamp-red letterhead "MEMO — FROM THE DESK OF H. HARLOW" (Oswald 18, cream), the line in
	Special Elite (30 ink, or 38 red when shouted, shrinking to fit two lines), typed out letter by letter
	(useTypedGraphemes at OccupantConstants.TYPE_RATE), and a 24 px tail at x 90 pointing down at his head.
	Presentational; the words and the shout are OccupantWorldViewModel.memo.

	@class OccupantMemo
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local OccupantConstants = require(ReplicatedStorage.Shared.Features.Occupant.Data.OccupantConstants)
local PaperLabel = require(ReplicatedStorage.Client.UI.React.Screens.Paper.PaperLabel)
local PaperTexture = require(ReplicatedStorage.Client.UI.React.Screens.Paper.PaperTexture)
local UIPaperConstants = require(ReplicatedStorage.Client.UI.React.Screens.Paper.UIPaperConstants)
local OccupantWorldViewModel = require(ReplicatedStorage.Client.UI.React.Screens.World.OccupantWorldViewModel)
local useTypedGraphemes = require(ReplicatedStorage.Client.UI.React.Screens.World.useTypedGraphemes)

local e = React.createElement

export type OccupantMemoProps = {
	view: OccupantWorldViewModel.MemoView,
}

local COLOR = UIPaperConstants.COLOR
local PAPER = Vector2.new(520, 140)
local BAND = 30
local TAIL = 24
local TAIL_X = 90

local function OccupantMemo(props: OccupantMemoProps): React.ReactNode
	local view = props.view
	local shown = useTypedGraphemes(view.text, OccupantConstants.TYPE_RATE)
	return e("Frame", {
		Size = UDim2.fromOffset(PAPER.X, OccupantConstants.MEMO_PX.Y),
		BackgroundTransparency = 1,
	}, {
		shadow = e("Frame", {
			Position = UDim2.fromOffset(4, 6),
			Size = UDim2.fromOffset(PAPER.X, PAPER.Y),
			BackgroundColor3 = COLOR.night,
			BackgroundTransparency = 0.5,
			BorderSizePixel = 0,
			ZIndex = 0,
		}),
		-- A cream square turned 45° under the paper's bottom edge: its lower half is the tail.
		tail = e("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromOffset(TAIL_X, PAPER.Y),
			Size = UDim2.fromOffset(TAIL, TAIL),
			Rotation = 45,
			BackgroundColor3 = COLOR.cream,
			BorderSizePixel = 0,
			ZIndex = 1,
		}),
		paper = e("Frame", {
			Size = UDim2.fromOffset(PAPER.X, PAPER.Y),
			BackgroundColor3 = COLOR.cream,
			BorderSizePixel = 0,
			ZIndex = 2,
		}, {
			texture = e(PaperTexture, { paper = COLOR.cream, zIndex = 1 }),
			band = e("Frame", {
				Size = UDim2.new(1, 0, 0, BAND),
				BackgroundColor3 = COLOR.stamp,
				BorderSizePixel = 0,
				ZIndex = 2,
			}, {
				label = e(PaperLabel, {
					text = view.band,
					role = "heading",
					size = 18,
					color = COLOR.cream,
					position = UDim2.fromOffset(14, 0),
					frame = UDim2.new(1, -28, 1, 0),
					autoSize = false,
					wrapped = false,
				}),
			}),
			line = e("TextLabel", {
				Position = UDim2.fromOffset(18, BAND + 10),
				Size = UDim2.new(1, -36, 0, PAPER.Y - BAND - 18),
				BackgroundTransparency = 1,
				FontFace = UIPaperConstants.FONT.body,
				TextScaled = true,
				TextWrapped = true,
				TextColor3 = UIPaperConstants.inkColor(view.ink),
				TextXAlignment = Enum.TextXAlignment.Left,
				TextYAlignment = Enum.TextYAlignment.Top,
				RichText = false,
				Text = view.text,
				MaxVisibleGraphemes = shown,
				ZIndex = 2,
			}, {
				limit = e("UITextSizeConstraint", { MaxTextSize = view.size, MinTextSize = 18 }),
			}),
		}),
	})
end

return OccupantMemo
```

- [ ] **Step 7: `OccupantBillboardSystem.luau`**

```lua
--!strict
--[=[
	OccupantBillboardSystem: draws Mr. Harlow's cue disc (W7) and memo (W8) on this client (Figma World UI 2b) into the
	two shells on his head (tags OccupantConstants.CUE_TAG / SPEECH_TAG), one React root each for the shell's life
	(UIBillboards). An attribute change re-renders in place: a new line keeps the memo mounted and retypes it, a cleared
	line or cue draws nothing until the next one. His voice is OccupantPresenceSystem's.

	Spec-exempt shell (CollectionService, React roots); the decisions are the specced OccupantWorldViewModel and the
	UIBillboards core.

	@class OccupantBillboardSystem
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local OccupantConstants = require(ReplicatedStorage.Shared.Features.Occupant.Data.OccupantConstants)
local UIBillboardHost = require(ReplicatedStorage.Client.UI.Layers.UIBillboardHost)
local UIBillboards = require(ReplicatedStorage.Client.UI.Layers.UIBillboards)
local OccupantCueDisc = require(ReplicatedStorage.Client.UI.React.Screens.World.OccupantCueDisc)
local OccupantMemo = require(ReplicatedStorage.Client.UI.React.Screens.World.OccupantMemo)
local OccupantWorldViewModel = require(ReplicatedStorage.Client.UI.React.Screens.World.OccupantWorldViewModel)
local WorldBillboard = require(ReplicatedStorage.Client.UI.React.Screens.World.WorldBillboard)

export type OccupantBillboardState = {
	mounted: number,
}

local e = React.createElement

local roots = UIBillboards.new(UIBillboardHost.factory)
local stoppers: { () -> () } = {}

local function drawCue(shell: BillboardGui)
	local view = OccupantWorldViewModel.cue(shell:GetAttribute(OccupantConstants.CUE_ATTRIBUTE))
	roots.show(
		shell,
		if view ~= nil
			then e(WorldBillboard, { design = OccupantConstants.CUE_PX, sizing = "studs" }, {
				cue = e(OccupantCueDisc, { view = view }),
			})
			else nil
	)
end

local function drawMemo(shell: BillboardGui)
	local view = OccupantWorldViewModel.memo(shell:GetAttribute(OccupantConstants.LINE_ATTRIBUTE))
	roots.show(
		shell,
		if view ~= nil
			then e(WorldBillboard, { design = OccupantConstants.MEMO_PX, sizing = "pixels" }, {
				memo = e(OccupantMemo, { view = view }),
			})
			else nil
	)
end

local OccupantBillboardSystem = {}

function OccupantBillboardSystem.start()
	if #stoppers > 0 then
		return
	end
	table.insert(stoppers, UIBillboardHost.watch({ tag = OccupantConstants.CUE_TAG, roots = roots, refresh = drawCue }))
	table.insert(
		stoppers,
		UIBillboardHost.watch({ tag = OccupantConstants.SPEECH_TAG, roots = roots, refresh = drawMemo })
	)
end

function OccupantBillboardSystem.stop()
	for _, stop in stoppers do
		stop()
	end
	table.clear(stoppers)
	roots.teardown()
end

function OccupantBillboardSystem.getState(): OccupantBillboardState
	return { mounted = roots.count() }
end

return OccupantBillboardSystem
```

- [ ] **Step 8: `OccupantPresenceSystem` voices from the attribute.**
  - `Harlow.speech: TextLabel?` → `speech: BillboardGui?` (the memo shell).
  - Delete the state `revealText`, `revealStarted`, `revealing`, and the function `stepReveal`; in `step` delete the `stepReveal(harlow)` call; in `detach` delete `revealing = false`.
  - In `find`, replace the two `bubble` / `label` lines and the return with:

```lua
				local shell = head:FindFirstChild(OccupantConstants.SPEECH_NAME)
				local speech = if shell ~= nil and shell:IsA("BillboardGui") then shell else nil
				return { model = instance, root = root, head = head, speech = speech }
```

  - `onSpeech` becomes:

```lua
-- A new line on his memo shell: counted and, when it is words, voiced with one gibberish clip. The memo types itself
-- out (OccupantMemo); a cleared line ("") does nothing.
local function onSpeech(shell: BillboardGui)
	local value = shell:GetAttribute(OccupantConstants.LINE_ATTRIBUTE)
	local text = if type(value) == "string" then value else ""
	if text == "" then
		return
	end
	counters.lines += 1
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
```

  - In `attach`, the speech hook becomes:

```lua
	local shell = harlow.speech
	if shell ~= nil then
		speechConnection = shell:GetAttributeChangedSignal(OccupantConstants.LINE_ATTRIBUTE):Connect(function()
			onSpeech(shell)
		end)
	end
```

  - Header: "- His voice: each new bubble line types out (MaxVisibleGraphemes, OccupantFeedbackUtils.reveal) and plays one uploaded gibberish clip chosen per line (OccupantFeedbackUtils.clipFor); \"*sigh*\" is not voiced." → "- His voice: each new line on his memo shell (OccupantConstants.LINE_ATTRIBUTE) plays one uploaded gibberish clip chosen per line (OccupantFeedbackUtils.clipFor); \"*sigh*\" is not voiced. The memo itself, typed out, is OccupantBillboardSystem's." and "…his speech billboard." → "…his memo shell's line attribute."

  In `OccupantServiceClient.luau`: require `ReplicatedStorage.Client.Features.Occupant.Systems.OccupantBillboardSystem`; in `start` after the presence lines add

```lua
		OccupantBillboardSystem.start()
		table.insert(stoppers, OccupantBillboardSystem.stop)
```

  `getState` adds `billboards = OccupantBillboardSystem.getState()`; header gains "OccupantBillboardSystem draws his cue disc and typed memo."

- [ ] **Step 9: `OccupantWorld.story.luau`**

```lua
--!strict
--[=[
	OccupantWorld.story: Mr. Harlow's world signs (Figma World UI 2b, W7 and W8) over the dark office, in Studio's edit
	mode (UI Labs): both cue discs at their design size, and the memo with `Line` typed out (shouted when it ends with
	"!" or is in capitals). Change `Line`, or flip `Retype`, to type it again.

	@class OccupantWorld.story
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local ReactRoblox = require(ReplicatedStorage.Packages.ReactRoblox)
local UILabs = require(ReplicatedStorage.DevPackages.UILabs)
local OccupantConstants = require(ReplicatedStorage.Shared.Features.Occupant.Data.OccupantConstants)
local UIPaperConstants = require(ReplicatedStorage.Client.UI.React.Screens.Paper.UIPaperConstants)
local OccupantCueDisc = require(ReplicatedStorage.Client.UI.React.Screens.World.OccupantCueDisc)
local OccupantMemo = require(ReplicatedStorage.Client.UI.React.Screens.World.OccupantMemo)
local OccupantWorldViewModel = require(ReplicatedStorage.Client.UI.React.Screens.World.OccupantWorldViewModel)
local WorldBillboard = require(ReplicatedStorage.Client.UI.React.Screens.World.WorldBillboard)

local e = React.createElement

local function cue(order: number, glyph: string): React.ReactNode
	local view = OccupantWorldViewModel.cue(glyph)
	if view == nil then
		return nil
	end
	local size = OccupantConstants.CUE_PX
	return e("Frame", {
		LayoutOrder = order,
		Size = UDim2.fromOffset(size.X, size.Y),
		BackgroundTransparency = 1,
	}, {
		billboard = e(WorldBillboard, { design = size, sizing = "studs" }, { cue = e(OccupantCueDisc, { view = view }) }),
	})
end

return UILabs.CreateReactStory({
	react = React,
	reactRoblox = ReactRoblox,
	controls = {
		Line = "Those are COMPANY ASSETS.",
		Retype = false,
	},
}, function(props)
	local line: string = props.controls.Line
	local memo = OccupantWorldViewModel.memo(line)
	local size = OccupantConstants.MEMO_PX
	local memoChildren: { [string]: React.ReactNode } = {}
	if memo ~= nil then
		-- Keyed by Retype, so flipping it remounts the memo and types the same line again.
		memoChildren[if props.controls.Retype then "memoA" else "memoB"] = e(
			WorldBillboard,
			{ design = size, sizing = "pixels" },
			{ memo = e(OccupantMemo, { view = memo }) }
		)
	end
	return e("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = UIPaperConstants.COLOR.office,
		BorderSizePixel = 0,
	}, {
		padding = e("UIPadding", {
			PaddingLeft = UDim.new(0, 60),
			PaddingTop = UDim.new(0, 60),
		}),
		layout = e("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			VerticalAlignment = Enum.VerticalAlignment.Top,
			Padding = UDim.new(0, 60),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
		curious = cue(1, "?"),
		spotted = cue(2, "!"),
		memo = e("Frame", {
			LayoutOrder = 3,
			Size = UDim2.fromOffset(size.X, size.Y),
			BackgroundTransparency = 1,
		}, memoChildren),
	})
end)
```

- [ ] **Step 10: `SpecRoots`.** Under "-- Cleanup Crew: Occupant":

```lua
	["ReplicatedStorage.Client.Features.Occupant.Systems.OccupantBillboardSystem"] = "CollectionService/React-root shell (cue and memo specced in OccupantWorldViewModel; roots in UIBillboards)",
	["ReplicatedStorage.Client.UI.React.Screens.World.OccupantCueDisc"] = "presentational React component (cue specced in OccupantWorldViewModel; story in OccupantWorld.story)",
	["ReplicatedStorage.Client.UI.React.Screens.World.OccupantMemo"] = "presentational React component (memo and shout specced in OccupantWorldViewModel; story in OccupantWorld.story)",
	["ReplicatedStorage.Client.UI.React.Screens.World.useTypedGraphemes"] = "React hook over RenderStepped (the reveal maths is the specced OccupantFeedbackUtils.reveal)",
```

  Update the `OccupantRigSystem` reason to "Instance builder (HumanoidDescription rig, billboard shells and their attributes)" and the `OccupantPresenceSystem` reason to "Sound/Instance/RunService shell (choices specced in OccupantFeedbackUtils, OccupantTellRules; the memo is OccupantWorldViewModel's)".

- [ ] **Step 11: Controller: Studio TestEZ**, then the visual and live checks. Expected TestEZ: every `OccupantWorldViewModel` case passes; `OccupantFeedbackUtils` and the rest unchanged; `assertAllModulesSpecced` passes.
  - UI Labs, `World → OccupantWorld`: both discs beside frame 2b's W7 (yellow ? upright, red ! tilted with a cream ring); the memo beside W8 (red letterhead, tail at x 90, the line typing out at ~28 characters a second). Set `Line` to "You're FIRED!": red and bigger. An 80+ character line ends in "…" inside the paper. Flip `Retype`: the line types again; editing any other control does not.
  - Fresh Play, solo shift: walk into Harlow's sight: the red "!" disc over his head and a memo typing his line; leave his sight until he investigates: the yellow "?"; get caught: "You're FIRED!" in red. While a line types, the memo does not restart when his cue changes. The gibberish voice still plays once per line (when the clips are uploaded; else `presence.counters.pending` rises). Client command bar: `print(require(game.ReplicatedStorage.Client.Features.Occupant.Systems.OccupantBillboardSystem).getState().mounted)` prints `2` while he exists. No Output errors.

- [ ] **Step 12: Gate and commit**

```bash
git add src
python3 scripts/python/module_map.py --write
git add docs/project-structure.md
stylua src/ReplicatedStorage/Shared/Features/Occupant/Data/OccupantConstants.luau src/ServerScriptService/Features/Occupant/Systems/OccupantRigSystem.luau src/ReplicatedStorage/Client/UI/React/Screens/World/OccupantWorldViewModel.luau src/ReplicatedStorage/Client/UI/React/Screens/World/OccupantWorldViewModel.spec.luau src/ReplicatedStorage/Client/UI/React/Screens/World/useTypedGraphemes.luau src/ReplicatedStorage/Client/UI/React/Screens/World/OccupantCueDisc.luau src/ReplicatedStorage/Client/UI/React/Screens/World/OccupantMemo.luau src/ReplicatedStorage/Client/UI/React/Screens/World/OccupantWorld.story.luau src/ReplicatedStorage/Client/Features/Occupant/Systems/OccupantBillboardSystem.luau src/ReplicatedStorage/Client/Features/Occupant/Systems/OccupantPresenceSystem.luau src/ReplicatedStorage/Client/Features/Occupant/OccupantServiceClient.luau src/ServerScriptService/Core/Testing/SpecRoots.luau
git add src
PYTHONUTF8=1 bash .superpowers/sdd/gate.sh
python3 scripts/python/check_pr_rules.py origin/main
git commit -m "feat(occupant): Harlow's cue disc and typed memo drawn with the paper kit"
python3 scripts/python/module_map.py --check
```

---

### Task 9: S1 drive and arrival cards

The travel cards carry structured data instead of a title and body: the server sends the contract's client, job and note, the quota and the truck number; the client writes every line (`DepotCardViewModel`). The drive card is a cream dispatch ticket with an ink letterhead ("TRUCK n" in glow green) and a red truck block sliding along 13 dashes over the card's seconds; the arrival card is a manila job folder with an "ARRIVAL" tab, the client as headline, the job line, a cream clearance-contract slip and the contract's note on a sticky. Both are centred at 40% height and scaled by the screen (`WorldBillboardViewModel.screenScale`). The drive card's truck is the departing pad's number; the arrival card's comes from the untrusted payload through `DepotContractUtils.truckOf`.

**Files:**
- Modify: `src/ReplicatedStorage/Shared/Features/Depot/Data/DepotTypes.luau` (`CardMessage`, `ShownCard`)
- Modify: `src/ReplicatedStorage/Shared/Features/Depot/Net/DepotEvents.luau` (`Card` struct)
- Modify: `src/ServerScriptService/Features/Depot/Utils/DepotContractUtils.luau` (`driveCard`, `arrivalCard`); Test: `.../Utils/DepotContractUtils.spec.luau`
- Modify: `src/ServerScriptService/Features/Depot/DepotServiceServer.luau`
- Modify: `src/ReplicatedStorage/Client/Features/Depot/State/DepotStore.luau` (`show(message, now)`); Test: `.../State/DepotStore.spec.luau`
- Modify: `src/ReplicatedStorage/Client/Features/Depot/DepotServiceClient.luau`
- Create: `src/ReplicatedStorage/Client/UI/React/Screens/Depot/DepotCardViewModel.luau`; Test: `.../Depot/DepotCardViewModel.spec.luau`
- Modify (rewrite): `src/ReplicatedStorage/Client/UI/React/Screens/Depot/DepotCardPanel.luau`, `.../Depot/DepotCard.luau`, `.../Depot/DepotCardPanel.story.luau`
- Modify: `src/ServerScriptService/Core/Testing/SpecRoots.luau`

**Interfaces:**
- Consumes: `QueueServiceServer.departing: Signal<BasePart, { Player }>`, `.arrived: Signal<{ Player }, QueuePayload>`, `.joinedLate: Signal<Player>`; `truckIndexOf(pad): number?` (DepotServiceServer local); `DepotContractUtils.truckOf(value: unknown, max: number): number?`; `DepotConstants.MAX_TRUCKS`, `DRIVE_CARD_SECONDS`, `ARRIVAL_CARD_SECONDS`; `ShiftConstants.QUOTA`, `SHIFT_SECONDS`; `ShiftHudViewModel.clock`; `WorldBillboardViewModel.clip`, `.screenScale` (Task 2); `usePaperViewport`, `usePaperMotion(seconds): React.Binding<number>`; `PaperSheet` (`tab`, `tabWidth`, `tabTextSize`, `band`), `StickyNote`, `PaperLabel`, `PaperTexture`.
- Produces:
  - `DepotTypes.CardMessage = { kind: string, client: string, job: string, note: string, quota: number, truck: number }` (truck 0 = unknown; quota 0 on the drive card); `DepotTypes.ShownCard = { kind: CardKind, client: string, job: string, note: string, quota: number, truck: number, expiresAt: number }`.
  - `DepotEvents.packets.Card` value: `ByteNet.struct({ kind = string, client = string, job = string, note = string, quota = uint16, truck = uint8 })`.
  - `DepotContractUtils.driveCard(contract: Contract, truck: number?) -> CardMessage`; `arrivalCard(contract: Contract, quota: number, truck: number?) -> CardMessage`.
  - `DepotStore.show(message: DepotTypes.CardMessage, now: number) -> boolean`.
  - `DepotCardViewModel.CLIENT_MAX = 30`; `DriveView = { band: string, truck: string?, title: string, heading: string, seconds: number }`; `ArrivalView = { tab: string, client: string, job: string, slip: string, clear: string, before: string, note: string }`; `drive(card: DepotTypes.ShownCard) -> DriveView`; `arrival(card: DepotTypes.ShownCard) -> ArrivalView`.
  - `DepotCardPanel(props: { drive: DriveView?, arrival: ArrivalView?, scale: number })`.

- [ ] **Step 1: Write the failing specs.**

  `DepotCardViewModel.spec.luau`:

```lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DepotCardViewModel = require(script.Parent.DepotCardViewModel)
local DepotConstants = require(ReplicatedStorage.Shared.Features.Depot.Data.DepotConstants)
local ShiftConstants = require(ReplicatedStorage.Shared.Features.Shift.Data.ShiftConstants)
local ShiftHudViewModel = require(ReplicatedStorage.Client.UI.React.Screens.Shift.ShiftHudViewModel)

local function card(kind, client, truck)
	return {
		kind = kind,
		client = client or "Pemberton Dental",
		job = "4th floor offices. Harlow is in tonight.",
		note = "Watch the fish tank. Fragile!",
		quota = 350,
		truck = truck or 0,
		expiresAt = 10,
	}
end

return function()
	describe("drive", function()
		it("writes the dispatch ticket", function()
			local view = DepotCardViewModel.drive(card("drive", nil, 2))
			expect(view.band).to.equal("HARLOW & FINCH — DISPATCH")
			expect(view.truck).to.equal("TRUCK 2")
			expect(view.title).to.equal("ON THE ROAD")
			expect(view.heading).to.equal("Heading to Pemberton Dental")
			expect(view.seconds).to.equal(DepotConstants.DRIVE_CARD_SECONDS)
		end)

		it("leaves the truck off when it is unknown", function()
			expect(DepotCardViewModel.drive(card("drive", nil, 0)).truck).to.equal(nil)
		end)
	end)

	describe("arrival", function()
		it("writes the job folder", function()
			local view = DepotCardViewModel.arrival(card("arrival"))
			expect(view.tab).to.equal("ARRIVAL")
			expect(view.client).to.equal("Pemberton Dental")
			expect(view.job).to.equal("4th floor offices. Harlow is in tonight.")
			expect(view.slip).to.equal("CLEARANCE CONTRACT")
			expect(view.clear).to.equal("CLEAR 350")
			expect(view.before).to.equal(`of trash before {ShiftHudViewModel.clock(ShiftConstants.SHIFT_SECONDS)}`)
			expect(view.note).to.equal("Watch the fish tank. Fragile!")
		end)
	end)

	it("cuts a long client name on both cards", function()
		local long = string.rep("Pemberton ", 6)
		local drive = DepotCardViewModel.drive(card("drive", long, 1))
		local arrival = DepotCardViewModel.arrival(card("arrival", long, 1))
		expect(utf8.len(arrival.client)).to.equal(DepotCardViewModel.CLIENT_MAX)
		expect(string.sub(arrival.client, -3)).to.equal("…")
		expect(drive.heading).to.equal(`Heading to {arrival.client}`)
	end)
end
```

  `DepotStore.spec.luau`, rewritten for the structured card (same cases):

```lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DepotStore = require(script.Parent.DepotStore)
local DepotConstants = require(ReplicatedStorage.Shared.Features.Depot.Data.DepotConstants)

local DRIVE = DepotConstants.DRIVE_CARD_SECONDS
local ARRIVAL = DepotConstants.ARRIVAL_CARD_SECONDS

local function message(kind, client)
	return {
		kind = kind,
		client = client or "Harlow & Finch Ltd.",
		job = "Clear it.",
		note = "Quiet.",
		quota = if kind == "arrival" then 350 else 0,
		truck = 2,
	}
end

return function()
	afterEach(function()
		DepotStore.clear()
	end)

	it("shows a card for its kind's time, with every field the server sent", function()
		expect(DepotStore.show(message("drive"), 10)).to.equal(true)
		local card = DepotStore.card()
		expect(card.kind).to.equal("drive")
		expect(card.client).to.equal("Harlow & Finch Ltd.")
		expect(card.job).to.equal("Clear it.")
		expect(card.note).to.equal("Quiet.")
		expect(card.quota).to.equal(0)
		expect(card.truck).to.equal(2)
		expect(card.expiresAt).to.equal(10 + DRIVE)
	end)

	it("ignores an unknown kind", function()
		expect(DepotStore.show(message("party"), 0)).to.equal(false)
		expect(DepotStore.card()).to.equal(nil)
	end)

	it("keeps the card until its time is up, then clears it", function()
		DepotStore.show(message("arrival"), 10)
		DepotStore.expire(10 + ARRIVAL - 0.1)
		expect(DepotStore.card() ~= nil).to.equal(true)
		DepotStore.expire(10 + ARRIVAL)
		expect(DepotStore.card()).to.equal(nil)
	end)

	it("queues a card that arrives while another shows, then shows it in full", function()
		DepotStore.show(message("drive"), 10)
		DepotStore.show(message("arrival"), 11)
		expect(DepotStore.card().kind).to.equal("drive")
		DepotStore.expire(10 + DRIVE)
		local card = DepotStore.card()
		expect(card.kind).to.equal("arrival")
		expect(card.quota).to.equal(350)
		expect(card.expiresAt).to.equal(10 + DRIVE + ARRIVAL)
	end)

	it("drops the oldest queued card past the limit", function()
		DepotStore.show(message("drive", "first"), 0)
		for index = 1, DepotConstants.MAX_QUEUED_CARDS + 1 do
			DepotStore.show(message("arrival", tostring(index)), 1)
		end
		DepotStore.expire(DRIVE)
		expect(DepotStore.card().client).to.equal("2")
	end)

	it("replaces a card whose time has passed without waiting", function()
		DepotStore.show(message("drive", "old"), 0)
		DepotStore.show(message("arrival", "new"), DRIVE + 1)
		expect(DepotStore.card().client).to.equal("new")
	end)
```

  followed by the unchanged `describe("board and last shift", …)` block and the closing `end`.

  `DepotContractUtils.spec.luau`: replace the cases "builds the drive card" and "builds the arrival card" with

```lua
		it("builds the drive card with the departing truck", function()
			local card = DepotContractUtils.driveCard(CONTRACTS[1], 3)
			expect(card.kind).to.equal("drive")
			expect(card.client).to.equal("Alpha Ltd.")
			expect(card.job).to.equal("Clear it.")
			expect(card.note).to.equal("Quiet.")
			expect(card.quota).to.equal(0)
			expect(card.truck).to.equal(3)
			expect(DepotContractUtils.driveCard(CONTRACTS[1]).truck).to.equal(0)
		end)

		it("builds the arrival card with the quota and the truck", function()
			local card = DepotContractUtils.arrivalCard(CONTRACTS[3], 350, 2)
			expect(card.kind).to.equal("arrival")
			expect(card.client).to.equal("Gamma Ltd.")
			expect(card.job).to.equal("Clear all.")
			expect(card.note).to.equal("Odd.")
			expect(card.quota).to.equal(350)
			expect(card.truck).to.equal(2)
			expect(DepotContractUtils.arrivalCard(CONTRACTS[3], 350).truck).to.equal(0)
		end)
```

- [ ] **Step 2: Controller: Studio TestEZ.** Expected: the new and rewritten cases fail (`DepotCardViewModel` missing; the store and the cards still use title/body).

- [ ] **Step 3: The wire.** In `DepotTypes.luau` replace `CardMessage` and `ShownCard` with:

```lua
-- A travel card on the wire (DepotEvents.Card): the contract's words, the quota (0 on the drive card) and the truck
-- (0 = unknown). `kind` is checked on the client (DepotStore.show); the client writes every line (DepotCardViewModel).
export type CardMessage = {
	kind: string,
	client: string,
	job: string,
	note: string,
	quota: number,
	truck: number,
}

-- The card on screen; `expiresAt` is os.clock() on the client.
export type ShownCard = {
	kind: CardKind,
	client: string,
	job: string,
	note: string,
	quota: number,
	truck: number,
	expiresAt: number,
}
```

  In `DepotEvents.luau` the `Card` packet's value becomes

```lua
				value = ByteNet.struct({
					kind = ByteNet.string,
					client = ByteNet.string,
					job = ByteNet.string,
					note = ByteNet.string,
					-- ShiftConstants.QUOTA (350) and a layout truck (1..DepotConstants.MAX_TRUCKS, 0 = unknown).
					quota = ByteNet.uint16,
					truck = ByteNet.uint8,
				}),
```

  and its header line "Card (server → client), a travel card (…)" gains "with the contract's words, the quota and the truck number".

- [ ] **Step 4: The server cards.** In `DepotContractUtils.luau` replace `driveCard` and `arrivalCard` with:

```lua
-- The drive card: tonight's contract and the truck that left (nil: unknown, sent as 0).
function DepotContractUtils.driveCard(contract: Contract, truck: number?): DepotTypes.CardMessage
	return {
		kind = "drive",
		client = contract.client,
		job = contract.job,
		note = contract.note,
		quota = 0,
		truck = truck or 0,
	}
end

-- The arrival card: the crew's contract, the quota to clear and the truck they rode (nil: unknown, sent as 0).
function DepotContractUtils.arrivalCard(contract: Contract, quota: number, truck: number?): DepotTypes.CardMessage
	return {
		kind = "arrival",
		client = contract.client,
		job = contract.job,
		note = contract.note,
		quota = quota,
		truck = truck or 0,
	}
end
```

  In `DepotServiceServer.luau`:
  - Beside `crewContract` add `local crewTruck: number? = nil` with the comment "-- The truck that crew rode (from the untrusted payload; nil when unknown)."
  - `departing:Connect(function(_pad, party)` → `departing:Connect(function(pad, party)` sending `DepotContractUtils.driveCard(contract, truckIndexOf(pad))`.
  - In `arrived`, after `crewContract = …`: `crewTruck = DepotContractUtils.truckOf(payload.truck, DepotConstants.MAX_TRUCKS)`, and both `arrivalCard(crewContract, ShiftConstants.QUOTA)` calls (arrived and late) gain `, crewTruck`.
  - Header: "…An arriving party (and a member who joins late), wherever it lands, gets the arrival card for its contract (resolved from the untrusted payload)." gains ", with the truck it rode (DepotContractUtils.truckOf); the drive card names the departing truck".

- [ ] **Step 5: The client store.** In `DepotStore.luau`: `Pending` becomes `{ kind: DepotTypes.CardKind, client: string, job: string, note: string, quota: number, truck: number }`; `present` builds the shown card from it:

```lua
local function present(entry: Pending, now: number)
	card({
		kind = entry.kind,
		client = entry.client,
		job = entry.job,
		note = entry.note,
		quota = entry.quota,
		truck = entry.truck,
		expiresAt = now + secondsFor(entry.kind),
	})
end
```

  and `show` becomes:

```lua
-- Shows (or queues) a card from the server. False, and nothing shown, for an unknown kind.
function DepotStore.show(message: DepotTypes.CardMessage, now: number): boolean
	-- Annotated and tested with `not` (the RoundSnapshotUtils note): comparing an optional singleton union
	-- against nil widens it back to string.
	local parsed: DepotTypes.CardKind? = kindOf(message.kind)
	if not parsed then
		return false
	end
	local entry: Pending = {
		kind = parsed,
		client = message.client,
		job = message.job,
		note = message.note,
		quota = message.quota,
		truck = message.truck,
	}
	local current = card()
	if current == nil or now >= current.expiresAt then
		present(entry, now)
		return true
	end
	if #pending >= DepotConstants.MAX_QUEUED_CARDS then
		table.remove(pending, 1)
	end
	table.insert(pending, entry)
	return true
end
```

  In `DepotServiceClient.luau`: `DepotStore.show(data.kind, data.title, data.body, os.clock())` → `DepotStore.show(data, os.clock())`.

- [ ] **Step 6: `DepotCardViewModel.luau`**

```lua
--!strict
--[=[
	DepotCardViewModel: the travel cards' lines (Figma World UI 2c, S1). The drive card is a dispatch ticket: the
	"HARLOW & FINCH — DISPATCH" letterhead, "TRUCK n" (none when unknown), ON THE ROAD and where the truck is heading,
	shown for DepotConstants.DRIVE_CARD_SECONDS (the truck crosses the road in that time). The arrival card is the job
	folder: the ARRIVAL tab, the client as headline, the job line, the clearance-contract slip ("CLEAR 350 / of trash
	before 7:00") and the contract's note. A client name is cut at CLIENT_MAX on both (it rides the teleport). Pure.

	@class DepotCardViewModel
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DepotConstants = require(ReplicatedStorage.Shared.Features.Depot.Data.DepotConstants)
local DepotTypes = require(ReplicatedStorage.Shared.Features.Depot.Data.DepotTypes)
local ShiftConstants = require(ReplicatedStorage.Shared.Features.Shift.Data.ShiftConstants)
local ShiftHudViewModel = require(ReplicatedStorage.Client.UI.React.Screens.Shift.ShiftHudViewModel)
local WorldBillboardViewModel = require(ReplicatedStorage.Client.UI.React.Screens.World.WorldBillboardViewModel)

export type DriveView = {
	band: string,
	truck: string?,
	title: string,
	heading: string,
	-- How long the card shows: the truck block crosses the road in this time.
	seconds: number,
}

export type ArrivalView = {
	tab: string,
	client: string,
	job: string,
	slip: string,
	clear: string,
	before: string,
	note: string,
}

local DepotCardViewModel = {}

DepotCardViewModel.CLIENT_MAX = 30

function DepotCardViewModel.drive(card: DepotTypes.ShownCard): DriveView
	return {
		band = "HARLOW & FINCH — DISPATCH",
		truck = if card.truck > 0 then `TRUCK {card.truck}` else nil,
		title = "ON THE ROAD",
		heading = `Heading to {WorldBillboardViewModel.clip(card.client, DepotCardViewModel.CLIENT_MAX)}`,
		seconds = DepotConstants.DRIVE_CARD_SECONDS,
	}
end

function DepotCardViewModel.arrival(card: DepotTypes.ShownCard): ArrivalView
	return {
		tab = "ARRIVAL",
		client = WorldBillboardViewModel.clip(card.client, DepotCardViewModel.CLIENT_MAX),
		job = card.job,
		slip = "CLEARANCE CONTRACT",
		clear = `CLEAR {card.quota}`,
		before = `of trash before {ShiftHudViewModel.clock(ShiftConstants.SHIFT_SECONDS)}`,
		note = card.note,
	}
end

return DepotCardViewModel
```

- [ ] **Step 7: `DepotCardPanel.luau`** (rewrite)

```lua
--!strict
--[=[
	DepotCardPanel: the travel cards (Figma World UI 2c, S1), centred at 40% of the screen height and scaled by `scale`
	(WorldBillboardViewModel.screenScale). Drive: a 520x260 cream dispatch ticket tilted 1.5° with a 46 px ink
	letterhead ("TRUCK n" in glow green on the right), ON THE ROAD (Oswald 58), "Heading to …" (Special Elite 24) and a
	road of 13 dashes (24x6, every 36 px) that a 30x20 stamp-red truck block crosses over the card's seconds. Arrival: a
	640x400 manila folder with a 220 px ARRIVAL tab, the client (Oswald 56), the job line (Special Elite 26), a 330x170
	cream CLEARANCE CONTRACT slip tilted 1.5° (CLEAR n in Oswald 58, its deadline) and the note on a sticky tilted -2°.
	Presentational; the lines are DepotCardViewModel. Remount it per card (DepotCard keys it) so the truck starts again.

	@class DepotCardPanel
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local DepotCardViewModel = require(ReplicatedStorage.Client.UI.React.Screens.Depot.DepotCardViewModel)
local PaperLabel = require(ReplicatedStorage.Client.UI.React.Screens.Paper.PaperLabel)
local PaperSheet = require(ReplicatedStorage.Client.UI.React.Screens.Paper.PaperSheet)
local PaperTexture = require(ReplicatedStorage.Client.UI.React.Screens.Paper.PaperTexture)
local StickyNote = require(ReplicatedStorage.Client.UI.React.Screens.Paper.StickyNote)
local UIPaperConstants = require(ReplicatedStorage.Client.UI.React.Screens.Paper.UIPaperConstants)
local usePaperMotion = require(ReplicatedStorage.Client.UI.React.Screens.Paper.usePaperMotion)

local e = React.createElement

export type DepotCardPanelProps = {
	drive: DepotCardViewModel.DriveView?,
	arrival: DepotCardViewModel.ArrivalView?,
	-- WorldBillboardViewModel.screenScale of this screen.
	scale: number,
}

local COLOR = UIPaperConstants.COLOR
local DRIVE = Vector2.new(520, 260)
local ARRIVAL = Vector2.new(640, 400)
local BAND = 46
local DASHES = 13
local DASH = Vector2.new(24, 6)
local DASH_STEP = 36
local ROAD = Vector2.new(24, 206)
local TRUCK = Vector2.new(30, 20)

local function label(
	text: string,
	role: PaperLabel.Role,
	size: number,
	color: Color3,
	position: UDim2,
	frame: UDim2,
	scaled: boolean?
): React.ReactNode
	return e(PaperLabel, {
		text = text,
		role = role,
		size = size,
		color = color,
		position = position,
		frame = frame,
		autoSize = false,
		wrapped = scaled ~= true,
		scaled = scaled,
	})
end

-- The dashed road and the truck crossing it once over `seconds`, from mount.
local function Road(props: { seconds: number }): React.ReactNode
	local alpha = usePaperMotion(props.seconds)
	local children: { [string]: React.ReactNode } = {
		truck = e("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = alpha:map(function(value: number): UDim2
				return UDim2.fromOffset(DASH.X / 2 + value * (DASHES - 1) * DASH_STEP, DASH.Y / 2)
			end),
			Size = UDim2.fromOffset(TRUCK.X, TRUCK.Y),
			BackgroundColor3 = COLOR.stamp,
			BorderSizePixel = 0,
			ZIndex = 4,
		}, { corner = e("UICorner", { CornerRadius = UDim.new(0, 4) }) }),
	}
	for index = 1, DASHES do
		children[`dash{index}`] = e("Frame", {
			Position = UDim2.fromOffset((index - 1) * DASH_STEP, 0),
			Size = UDim2.fromOffset(DASH.X, DASH.Y),
			BackgroundColor3 = COLOR.manilaDeep,
			BorderSizePixel = 0,
			ZIndex = 3,
		}, { corner = e("UICorner", { CornerRadius = UDim.new(0.5, 0) }) })
	end
	return e("Frame", {
		Position = UDim2.fromOffset(ROAD.X, ROAD.Y),
		Size = UDim2.fromOffset((DASHES - 1) * DASH_STEP + DASH.X, DASH.Y),
		BackgroundTransparency = 1,
		ZIndex = 3,
	}, children)
end

local function driveCard(view: DepotCardViewModel.DriveView): React.ReactNode
	local truck = view.truck
	return e("Frame", {
		Size = UDim2.fromOffset(DRIVE.X, DRIVE.Y),
		Rotation = 1.5,
		BackgroundTransparency = 1,
	}, {
		shadow = e("Frame", {
			Position = UDim2.fromOffset(4, 6),
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = COLOR.night,
			BackgroundTransparency = 0.5,
			BorderSizePixel = 0,
			ZIndex = 0,
		}, { corner = e("UICorner", { CornerRadius = UDim.new(0, 4) }) }),
		paper = e("Frame", {
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = COLOR.cream,
			BorderSizePixel = 0,
			ZIndex = 1,
		}, {
			corner = e("UICorner", { CornerRadius = UDim.new(0, 4) }),
			texture = e(PaperTexture, { paper = COLOR.cream, corner = 4, zIndex = 1 }),
			band = e("Frame", {
				Size = UDim2.new(1, 0, 0, BAND),
				BackgroundColor3 = COLOR.ink,
				BorderSizePixel = 0,
				ZIndex = 2,
			}, {
				label = label(
					view.band,
					"heading",
					22,
					COLOR.cream,
					UDim2.fromOffset(20, 0),
					UDim2.new(1, -170, 1, 0),
					true
				),
				truck = if truck ~= nil
					then e(PaperLabel, {
						text = truck,
						role = "heading",
						size = 22,
						color = COLOR.fluorGlow,
						align = "right",
						position = UDim2.new(1, -140, 0, 0),
						frame = UDim2.fromOffset(120, BAND),
						autoSize = false,
						wrapped = false,
					})
					else nil,
			}),
			title = label(view.title, "heading", 58, COLOR.ink, UDim2.fromOffset(24, 62), UDim2.new(1, -48, 0, 72), true),
			heading = label(
				view.heading,
				"body",
				24,
				COLOR.ink,
				UDim2.fromOffset(24, 138),
				UDim2.new(1, -48, 0, 34),
				true
			),
			road = e(Road, { seconds = view.seconds }),
		}),
	})
end

local function arrivalCard(view: DepotCardViewModel.ArrivalView): React.ReactNode
	local slip: { [string]: React.ReactNode } = {
		clear = label(view.clear, "heading", 58, COLOR.ink, UDim2.fromOffset(0, 0), UDim2.new(1, 0, 0, 66), true),
		before = label(view.before, "body", 20, COLOR.ink, UDim2.fromOffset(0, 70), UDim2.new(1, 0, 0, 28)),
	}
	local folder: { [string]: React.ReactNode } = {
		client = label(view.client, "heading", 56, COLOR.ink, UDim2.fromOffset(30, 22), UDim2.fromOffset(580, 70), true),
		job = label(view.job, "body", 26, COLOR.ink, UDim2.fromOffset(30, 96), UDim2.fromOffset(580, 66)),
		slip = e(PaperSheet, {
			position = UDim2.fromOffset(24, 170),
			size = UDim2.fromOffset(330, 170),
			paper = COLOR.cream,
			tilt = 1.5,
			band = view.slip,
			padding = 16,
		}, slip),
		sticky = e(StickyNote, {
			text = view.note,
			width = 200,
			size = 20,
			tilt = -2,
			position = UDim2.fromOffset(400, 184),
		}),
	}
	return e(PaperSheet, {
		size = UDim2.fromOffset(ARRIVAL.X, ARRIVAL.Y),
		paper = COLOR.manila,
		tab = view.tab,
		tabWidth = 220,
		tabTextSize = 26,
		padding = 0,
	}, folder)
end

local function DepotCardPanel(props: DepotCardPanelProps): React.ReactNode
	local arrival = props.arrival
	local drive = props.drive
	local size = if arrival ~= nil then ARRIVAL else DRIVE
	local card: React.ReactNode = nil
	if arrival ~= nil then
		card = arrivalCard(arrival)
	elseif drive ~= nil then
		card = driveCard(drive)
	end
	return e("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.4),
		Size = UDim2.fromOffset(size.X, size.Y),
		BackgroundTransparency = 1,
	}, {
		scale = e("UIScale", { Scale = props.scale }),
		card = card,
	})
end

return DepotCardPanel
```

- [ ] **Step 8: `DepotCard.luau`** (rewrite)

```lua
--!strict
--[=[
	DepotCard: the travel-card HUD widget (registered by DepotServiceClient). While DepotStore holds a card it draws
	DepotCardPanel with the card's lines (DepotCardViewModel) at the screen's scale (WorldBillboardViewModel.screenScale),
	keyed by the card's expiry so every card mounts fresh (the drive card's truck starts at the left again).
	DepotServiceClient moves the store on as cards expire.

	@class DepotCard
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local ReactCharm = require(ReplicatedStorage.Packages.ReactCharm)
local DepotStore = require(ReplicatedStorage.Client.Features.Depot.State.DepotStore)
local DepotCardPanel = require(ReplicatedStorage.Client.UI.React.Screens.Depot.DepotCardPanel)
local DepotCardViewModel = require(ReplicatedStorage.Client.UI.React.Screens.Depot.DepotCardViewModel)
local usePaperViewport = require(ReplicatedStorage.Client.UI.React.Screens.Paper.usePaperViewport)
local WorldBillboardViewModel = require(ReplicatedStorage.Client.UI.React.Screens.World.WorldBillboardViewModel)

local function DepotCard(): React.ReactNode
	local card = ReactCharm.useAtom(DepotStore.card)
	local viewport = usePaperViewport()
	if card == nil then
		return nil
	end
	local props: DepotCardPanel.DepotCardPanelProps = {
		drive = if card.kind == "drive" then DepotCardViewModel.drive(card) else nil,
		arrival = if card.kind == "arrival" then DepotCardViewModel.arrival(card) else nil,
		scale = WorldBillboardViewModel.screenScale(viewport),
	}
	return React.createElement(React.Fragment, nil, {
		[`card{card.expiresAt}`] = React.createElement(DepotCardPanel, props),
	})
end

return DepotCard
```

- [ ] **Step 9: `DepotCardPanel.story.luau`** (rewrite)

```lua
--!strict
--[=[
	DepotCardPanel.story: the travel cards (Figma World UI 2c, S1) over the dark depot, in Studio's edit mode (UI Labs),
	in a fixed screen-sized frame: `Arrival` switches from the dispatch ticket to the job folder, `Truck` sets the
	truck number (0 hides it), `LongClient` tries a 60-character client and `Phone` draws them at the 844x390 phone's
	scale (0.6). Toggle `Replay` to run the drive card's truck across the road again.

	@class DepotCardPanel.story
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local ReactRoblox = require(ReplicatedStorage.Packages.ReactRoblox)
local UILabs = require(ReplicatedStorage.DevPackages.UILabs)
local DepotConstants = require(ReplicatedStorage.Shared.Features.Depot.Data.DepotConstants)
local DepotTypes = require(ReplicatedStorage.Shared.Features.Depot.Data.DepotTypes)
local ShiftConstants = require(ReplicatedStorage.Shared.Features.Shift.Data.ShiftConstants)
local DepotCardPanel = require(ReplicatedStorage.Client.UI.React.Screens.Depot.DepotCardPanel)
local DepotCardViewModel = require(ReplicatedStorage.Client.UI.React.Screens.Depot.DepotCardViewModel)
local UIPaperConstants = require(ReplicatedStorage.Client.UI.React.Screens.Paper.UIPaperConstants)
local WorldBillboardViewModel = require(ReplicatedStorage.Client.UI.React.Screens.World.WorldBillboardViewModel)

local e = React.createElement

local PHONE = Vector2.new(844, 390)
local DESKTOP = Vector2.new(1920, 1080)

return UILabs.CreateReactStory({
	react = React,
	reactRoblox = ReactRoblox,
	controls = {
		Arrival = false,
		Truck = 2,
		LongClient = false,
		Phone = false,
		Replay = false,
	},
}, function(props)
	local contract = DepotConstants.CONTRACTS[1]
	local card: DepotTypes.ShownCard = {
		kind = "drive",
		client = if props.controls.LongClient then string.rep("Pemberton ", 6) else contract.client,
		job = contract.job,
		note = contract.note,
		quota = ShiftConstants.QUOTA,
		truck = math.max(0, math.floor(props.controls.Truck)),
		expiresAt = 0,
	}
	local arrival: boolean = props.controls.Arrival
	if arrival then
		card.kind = "arrival"
	end
	local screen = if props.controls.Phone then PHONE else DESKTOP
	local panelProps: DepotCardPanel.DepotCardPanelProps = {
		drive = if arrival then nil else DepotCardViewModel.drive(card),
		arrival = if arrival then DepotCardViewModel.arrival(card) else nil,
		scale = WorldBillboardViewModel.screenScale(screen),
	}
	return e("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = UIPaperConstants.COLOR.night,
		BorderSizePixel = 0,
	}, {
		screen = e("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(screen.X, screen.Y),
			BackgroundColor3 = UIPaperConstants.COLOR.office,
			BorderSizePixel = 0,
			ClipsDescendants = true,
		}, {
			-- Keyed by Replay, so flipping it remounts the card and its truck starts again.
			[if props.controls.Replay then "cardA" else "cardB"] = e(DepotCardPanel, panelProps),
		}),
	})
end)
```

- [ ] **Step 10: `SpecRoots`.** Update the two existing Depot lines:

```lua
	["ReplicatedStorage.Client.UI.React.Screens.Depot.DepotCardPanel"] = "presentational React component (card lines specced in DepotCardViewModel; story in DepotCardPanel.story)",
	["ReplicatedStorage.Client.UI.React.Screens.Depot.DepotCard"] = "React HUD widget wiring DepotStore to DepotCardPanel (lines specced in DepotCardViewModel, scale in WorldBillboardViewModel)",
```

- [ ] **Step 11: Controller: Studio TestEZ**, then the visual and live checks. Expected TestEZ: `DepotCardViewModel`, the rewritten `DepotStore` and the `DepotContractUtils` card cases pass; `assertAllModulesSpecced` passes.
  - UI Labs, `Depot → DepotCardPanel`: the dispatch ticket and the job folder beside frame 2c (letterhead, TRUCK 2 in green, the truck block crossing the 13 dashes in 3 s; tab, slip tilt, sticky); `Truck` 0 hides the truck label; `LongClient` cuts the client with "…" on both; `Phone` draws both at 0.6 and they stay on the 844x390 frame.
  - Fresh Play, solo: board truck 2 and depart: the dispatch ticket says TRUCK 2 and "Heading to Harlow & Finch Ltd.", its truck crosses the road; then the arrival folder with CLEAR 350 and tonight's note. No Output errors.

- [ ] **Step 12: Gate and commit**

```bash
git add src
python3 scripts/python/module_map.py --write
git add docs/project-structure.md
stylua src/ReplicatedStorage/Shared/Features/Depot/Data/DepotTypes.luau src/ReplicatedStorage/Shared/Features/Depot/Net/DepotEvents.luau src/ServerScriptService/Features/Depot/Utils/DepotContractUtils.luau src/ServerScriptService/Features/Depot/Utils/DepotContractUtils.spec.luau src/ServerScriptService/Features/Depot/DepotServiceServer.luau src/ReplicatedStorage/Client/Features/Depot/State/DepotStore.luau src/ReplicatedStorage/Client/Features/Depot/State/DepotStore.spec.luau src/ReplicatedStorage/Client/Features/Depot/DepotServiceClient.luau src/ReplicatedStorage/Client/UI/React/Screens/Depot/DepotCardViewModel.luau src/ReplicatedStorage/Client/UI/React/Screens/Depot/DepotCardViewModel.spec.luau src/ReplicatedStorage/Client/UI/React/Screens/Depot/DepotCardPanel.luau src/ReplicatedStorage/Client/UI/React/Screens/Depot/DepotCard.luau src/ReplicatedStorage/Client/UI/React/Screens/Depot/DepotCardPanel.story.luau src/ServerScriptService/Core/Testing/SpecRoots.luau
git add src
PYTHONUTF8=1 bash .superpowers/sdd/gate.sh
python3 scripts/python/check_pr_rules.py origin/main
git commit -m "feat(depot): dispatch ticket and arrival folder travel cards"
python3 scripts/python/module_map.py --check
```

---

### Task 10: Verification and docs

**Files:**
- Modify: `docs/ROADMAP.md` (the Cleanup Crew row)

- [ ] **Step 1: Full Studio TestEZ** (controller, `RunTests = true`): every spec passes; `assertAllModulesSpecced` and `assertAllSpecsCovered` pass. Then confirm nothing reads what this plan removed (each prints nothing):

```bash
grep -rn "FLOATER_FONT\|CLEARANCE_COLOR\|BONUS_COLOR\|SPEECH_PAPER\|SPEECH_INK\|SPEECH_BORDER\|SPEECH_FONT\|ShiftCardUtils.lines\|boardLines\|PAD_LABEL\|BOARD_LABEL\|TITLE_LABEL\|CARD_LABEL\|LABEL_BACKGROUND\|LABEL_TEXT\|LABEL_INTERVAL" src --include=*.luau
grep -rn "\.title\b\|\.body\b" src/ReplicatedStorage/Client/UI/React/Screens/Depot/DepotCard.luau src/ReplicatedStorage/Client/Features/Depot
python3 scripts/python/check_file_length.py
```

  Expected: the two greps print nothing; the length check passes with `CargoServiceServer` still 400 and `OccupantServiceServer` still 397 (untouched).

- [ ] **Step 2: Story pass** (edit mode, UI Labs). Open every new or changed story and screenshot each beside its PNG export, logging every difference in the PR description as "layout bug (fixed)" or "intended":
  - `Paper → PaperKit` (world-kit row) ↔ `2a`/`2b` tag shapes;
  - `World → DepotWorld` (Aboard 0/2/4, SecondsLeft 12/10, Departing; Review on/off, QuotaMet on/off, LongClient) ↔ `2a-depot-billboards.png`;
  - `World → CargoWorld` (Impacts 0/1/2; Fade 0/0.5) ↔ `2b-shift-billboards.png` W5/W6;
  - `World → OccupantWorld` (Line spoken / shouted / 80+ characters; Retype) ↔ `2b-shift-billboards.png` W7/W8;
  - `Depot → DepotCardPanel` (Arrival off/on, Truck 0/2, LongClient, Phone) ↔ `2c-drive-arrival-cards.png`;
  - `Depot → DepotBoardPanel` (the board scene's cork now in its wood frame) ↔ `overnight-handoff/ui-previews/textured/sheet-textured-all.jpg`.

  Intended differences to log, not fix: flat colours where the PNGs show textures (all six slots PENDING); the work order's job line is the contract's real job (Figma: "4th floor offices · Harlow on site"); the review card's crew line lists names as written with no "You", and the stickies show "TITLE" over a name with no detail line (the card carries neither after the teleport); a cracked price shows the item's current value; "+40 BONUS" keeps the approved floater copy.

- [ ] **Step 3: Solo live run** (`RunTests = false`, desktop, 1920×1080 window), checking each item and screenshotting the marked ones:
  - [ ] Truck tags: three manila tags, seats fill as you step in and out within 0.5 s, line 3 turns red at 0:10 and on a full truck, "Leaving now" at departure (screenshot).
  - [ ] Contract board: cork in a wood frame, tonight's client and job, CLEAR 350 / before 7:00, the E chip; its prompt still opens the board scene.
  - [ ] Dispatch ticket with TRUCK n and the truck crossing the road; then the arrival folder (screenshot both).
  - [ ] Cargo tags only on items near you (none across the room, none over piles until vacuumed); the monitor dropped once reads CRACKED −50% in red (screenshot).
  - [ ] Load floaters: "+N / CLEARED" and the "+N BONUS" stamp rise and fade; none left in `Workspace.Terrain` after 2 s.
  - [ ] Harlow: "?" disc when he investigates, red "!" disc when he spots you, the memo typing his line, "You're FIRED!" red and bigger on a catch; a line does not restart typing when his cue changes (screenshot the memo).
  - [ ] Back to depot: the result board shows your card and stickies, one sign only (walk around it: no flicker or z-fighting); reset your character: the card stays (screenshot).
  - [ ] Output: no errors or warnings from React, ReactRoblox or the new systems for the whole run.
  - [ ] Client command bar at the depot and on shift: `DepotBillboardSystem.getState()` (`mounted` 5, `trucks` 3, `reviews` 0 then 1), `CargoBillboardSystem.getState()` (`mounted` well under `shells`; 0 in an empty loading bay after banking), `OccupantBillboardSystem.getState().mounted` (2 while he exists), `CargoFeedbackSystem.getState().floating` (0 at rest).

- [ ] **Step 4: Two-player local server** (Studio → Test → Clients and Servers, 2 players): both see the same truck tag counts and countdown; player A boards truck 1, B boards truck 2: each tag counts its own crew. After a shift, A returns to the depot and B does not (or returns later): A sees their card on the result board, B sees the bare PERFORMANCE REVIEWS board at the same spot, and neither sees the other's card. Both see Harlow's cue and memo and the same cargo tags near them.

- [ ] **Step 5: Phone emulation** (Studio device emulator, a landscape phone of the 844×390 class): price tags, floaters and the memo are drawn at 0.6 (screen-sized signs never smaller); the memo covers well under a third of the screen; the dispatch ticket and the arrival folder fit the screen at 0.6; the depot's board signs stay readable from the spawn points (they are stud-sized, fit to the shell). No text is clipped mid-glyph.

- [ ] **Step 6: Docs.** `docs/ROADMAP.md`, the Cleanup Crew row: insert, just before the row's closing " Spec: `docs/superpowers/specs/2026-10-10-cleanup-crew-design.md`. |":

  " M3b world UI: the approved in-world signs and travel cards in React with the paper kit, each with a UI Labs story: the server builds empty tagged BillboardGui shells and publishes their data as attributes, and the client keeps one React root per shell (`UIBillboards` / `UIBillboardHost` in `Client/UI/Layers`) — manila truck pad tags fed by Queue's state sync (seats, countdown, red when leaving), the cork contract board with the pinned work order, the result board with your own review card and award stickies (per player, no z-fighting), cream price tags on cargo near the camera (FRAGILE / CRACKED), restyled load floaters, Harlow's cue discs and typed memo with shouted lines, and the dispatch ticket and arrival folder cards. The paper kit gained a tiled texture layer whose six slots stay PENDING until the textures are uploaded."

- [ ] **Step 7: Gate and commit**

```bash
python3 scripts/python/module_map.py --check
PYTHONUTF8=1 bash .superpowers/sdd/gate.sh
python3 scripts/python/check_pr_rules.py origin/main
git add docs/ROADMAP.md
git commit -m "docs: record Cleanup Crew world UI on the roadmap"
```

---

## Closing note: texture ids (no upload in this plan)

The texture layer ships with every slot PENDING (`""`), so every screen and sign looks exactly as today until the developer pastes real ids. Nothing in this plan uploads: the textures belong under the Icey Labs group, each upload needs the developer's approval per asset, and the Open Cloud API key for that group does not exist yet. Never run the publish skill for these (it defaults to another group), and never `git add assets`.

The six files, all in the untracked `assets/ui/textures/`, and the slot each id goes into (`UIAssets.paper.<slot>.id` in `src/ReplicatedStorage/Client/Features/UI/Data/UIAssets.luau`, a `Data/` module, so the asset-id rule allows the literal):

| File | Size (px) | Slot | `tile` |
|---|---|---|---|
| `paper-cream.png` | 160×160 | `cream` | `Vector2.new(160, 160)` |
| `paper-manila.png` | 160×160 | `manila` | `Vector2.new(160, 160)` |
| `paper-manila-deep.png` | 128×128 | `manilaDeep` | `Vector2.new(128, 128)` |
| `paper-sticky.png` | 128×128 | `sticky` | `Vector2.new(128, 128)` |
| `cork.png` | 192×192 | `cork` | `Vector2.new(192, 192)` |
| `wood.png` | 256×128 | `wood` | `Vector2.new(256, 128)` |

Each id is pasted as `"rbxassetid://<number>"` (for example `cream = table.freeze({ id = "rbxassetid://1234567890", tile = Vector2.new(160, 160) })`). `PaperTextureViewModel.spec` ("holds only PENDING or well-formed asset ids") fails any other form. After pasting: Studio TestEZ, then the Task 10 Step 2 story pass against `sheet-textured-all.jpg`, and commit as `feat(ui): paper textures uploaded`.

---

## Self-review (planner)

- **Spec coverage.** Every item of frames 2a/2b/2c has a task and a story: W1 → Task 4 (`DepotTruckTag`, `DepotWorld.story`); W2, W3+W4 → Task 5 (`DepotWorkOrderBoard`, `DepotResultBoard`, the per-player review shell); W5 → Task 6 (`CargoPriceTag`, `CargoWorld.story`); W6 → Task 7 (`CargoLoadFloater`, restyled in place); W7, W8 → Task 8 (`OccupantCueDisc`, `OccupantMemo`, `OccupantWorld.story`); S1 → Task 9 (`DepotCardPanel` rewrite, its story); the texture pass → Tasks 1–2. The developer's decisions hold: shells stay server-built and the React UI is client-only (attributes are display data, no new client → server traffic); W4 stays per-player; W6 is restyled in place; the shout rule is the pure specced `OccupantWorldViewModel.shouted`; textures stay PENDING with no upload task. Out of scope items (EXIT signs, the grin, the carry panel, mobile buttons, CCTV) are untouched.
- **Placeholders.** Pure modules (`UIBillboards`, `DepotWorldViewModel`, `CargoWorldViewModel`, `OccupantWorldViewModel`, `DepotCardViewModel`) carry full spec and implementation code; so do every component, system and story in Tasks 3–9. Server edits are given as exact replacements with their anchors. No "TBD"; the only conditional branches are explicit stops (Task 3 Step 6 if an unmount errors; Task 8 if luau-lsp rejects the hook's dependency list).
- **Type consistency.** `UIBillboards.UIBillboardsCore` / `BillboardHandle` (Task 3) are what `UIBillboardHost.watch` and the three systems use, and what `CargoFeedbackSystem`'s floaters hold. `DepotWorldViewModel.TruckTagView` is built by `truckTag`, compared by `sameTag`, cached by `DepotBillboardSystem` and drawn by `DepotTruckTag`. Attribute names live once: `DepotConstants.TRUCK_ATTRIBUTE / CAPACITY_ATTRIBUTE / CONTRACT_KEYS / REVIEW_KEYS`, `CargoConstants.LABEL_KEYS`, `OccupantConstants.CUE_ATTRIBUTE / LINE_ATTRIBUTE`, written only by their server modules and read only by their view models (and `OccupantPresenceSystem` for the voice). `DepotTypes.CardMessage` is the `Card` packet struct, `DepotContractUtils`'s result, `DepotStore.show`'s input; `DepotTypes.ShownCard` is `DepotStore.card`'s value and `DepotCardViewModel`'s input. `OccupantRigSystem.Rig` keeps `model`, `humanoid`, `root`, `head`, the only fields `OccupantServiceServer` and `OccupantCatchSystem` read.
- **Line caps.** `CargoServiceServer` (400) and `OccupantServiceServer` (397) are not edited. `DepotServiceServer` 265 → ~258 (T4: `padText` and the label loop out) → ~262 (T9); `DepotBuildSystem` 195 → ~200 (T4) → ~190 (T5, `billboard` out); `CargoFeedbackSystem` 233 → ~255 (T7); `OccupantPresenceSystem` 260 → ~240 (T8); `ShiftCardUtils` 208 → ~205 (T5); `SpecRoots` 349 → ~370; every new module is under 230. Each task's gate runs `check_file_length`.
- **CI rules.** No `.Enabled =` / `.Visible =` in `Client/UI` or `Client/Features/UI` (the only `Enabled` writes are server-side in `CargoSpawnSystem`); no packets in `Client/UI/React`; no `Name` React prop (the only `.Name` writes are on Instances in `UIBillboardHost` and the server shells); no ScreenGui outside `UILayerHost`; no asset-id literal outside `UIAssets` and specs; no casts.
- **Review Focus.** Line 1 → Task 3 `UIBillboards` "destroys a hidden shell's root and forgets it", "destroys a root exactly once…", "destroys every root on teardown", Task 3 Step 6 probe, Task 6 Step 10 banking check. Line 2 → Task 3 "renders into the same root on every later show, never mounting twice", Task 4 `sameTag` "is the same tag only when every drawn line matches", Task 8 `useTypedGraphemes` (restarts on `text` only), Task 10 Step 3. Line 3 → Task 2 `clip`, Task 6 "keeps the longest catalog name whole", Task 5 "cuts a long client name in the band", Task 9 "cuts a long client name on both cards", Task 8 "caps a line at 80 characters". Line 4 → Task 6 "mounts only within 24 studs, keeps until 28, never under a pile". Line 5 → Task 2 `screenScale` / `fit`, Task 10 Step 5.
- **Worth the developer's eye.** The truck tag reads the crew through the public `truck` field, which the server refreshes every 0.5 s, so a seat can fill up to half a second after Queue's own pad card. The review card shows no award details and no "You" (the teleport payload carries neither). `UIBillboardHost.watch` relies on `Destroying` firing before a part's descendants are locked; Task 3 Step 6 and Task 6 Step 10 prove it in Studio, and the plan stops rather than adding a `pcall` if it does not hold.
