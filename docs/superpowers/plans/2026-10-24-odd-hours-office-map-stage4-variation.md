# Odd Hours office map, stage 4: per-run variation and exterior anomalies, implementation plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** No two runs of the same room look identical. Each run picks different props, desk clutter, light moods,
broken tubes, open doors and stains, and 1-2 odd things happen around the building. Searching a desk opens that desk's
own drawers instead of swapping the model.

**Architecture:**
- **One pure rules module** derives every per-run choice from the shift's seed with a stable hash, so the server and
  every client agree without extra networking.
- **The server builds the interior choices:** props, clutter, light moods, door states and stains.
- **Exterior anomalies:** the server picks the run's anomalies and publishes them as one attribute on the office model.
  A client system applies them to tagged slots in the place-owned exterior set: visuals and sounds only, no gameplay.
- **The desk:** it gets a hand-built art model with separate drawer pieces, tagged `SearchComponent`, which the
  existing searched-dressing system already animates.

**Tech Stack:** Roblox Luau (`--!strict`), TestEZ specs (Studio Play with `RunTests`), Studio MCP for art and
verification, Blender MCP for the desk, `publish.py` for owner-approved uploads.

**Spec:** `docs/superpowers/specs/2026-10-22-odd-hours-office-map-design.md`, goals 4, 7 and 11, plus these
2026-10-23 owner notes:
- **Searched desk:** searching a desk must not swap it for a different asset (play-check G14, deferred to this stage).
- **The outside's slots:** the exterior is `Workspace.OfficeExterior`, wrapped around the office (stage 3, offset 0);
  the builder is `design/production-art/map-kits/odd-hours-b1/exterior/BuildExterior.CommandBar.luau`.
- **Deferred to the polish phase:** sound groups and the underground test (`docs/superpowers/launch-backlog.md`).
- **Not in this stage:** the spec's "glass lift that moves on its own" (no glass lift exists yet) and the rare set
  piece. Both go to the backlog.

## Global Constraints

- `--!strict` everywhere. No `any`, no casts. Spec-first TDD: every new module gets a `.spec.luau` sibling, written
  first.
- Module placement per `docs/project-structure.md`, as in the New modules table below. Run
  `python3 scripts/python/module_map.py --write` after `git add` of a new module.
- **Commits:**
  - plain messages with no trailers;
  - stage files by name;
  - never stage the foreign `src/ServerScriptService/Core/Testing/SpecRoots.luau` hunk or `GATES.md`;
  - don't push.
- No wally / rokit / `rojo build` / `scripts/check.sh`. No git checkout/reset/stash.
- **Specs run only in Studio Play** (Workspace attribute `RunTests = true`); clear it afterwards. Use only the Shift
  Studio window (`197d004d-31af-4c67-abfe-2cc4a86884ee`), and follow the playtest lock protocol
  (`docs/superpowers/studio-playtest-shift.lock`).
- **Art and uploads:**
  - Art lives in the place, never in Rojo.
  - Uploads go only via `publish.py … --key-env ICEY_LABS_OPEN_CLOUD_KEY --group 189923277`, never group 9738205,
    and **only after the owner's OK for that batch.** The controller asks; a task never uploads on its own.
- **Style:** simple shapes with drawn detail. No faces on Gloom art or on the silhouette (a featureless shape). Windows
  never show an outside view, and the exterior never shows the interior.
- **Gameplay stays untouched by variation:**
  - hide spots ≥ 8 (desks and closets are never removed);
  - traversal with all doors closed passes;
  - every pile, item, desk and locker marker keeps working;
  - decorative pieces are `CanCollide=false`, `CanQuery=false`, `CanTouch=false` unless the plan says otherwise.
- **The authored boot layout (no seed) behaves exactly as today:** a nil seed means "everything on, no anomalies".

## Review Focus

1. **Every player sees the same run.** The server and each client must make the same choices for the same seed:
   broken tubes, anomaly picks and the welcome-screen word. Choices come only from `OfficeVariationRules` with the
   seed. → Task 1 spec "same seed and key give the same value on every call; different seeds differ"; Task 7 reads
   the server's published picks rather than rolling its own.
2. **Decoration mistaken for gameplay.**
   - A stain or paper clutter must never sit on a marker the spawn plan used, and never carry a prompt or collide.
   - Removing a prop must never remove a desk, closet, locker, shelf proxy or any hide or loot marker.
   - → Task 2 spec on kept kinds; Task 4 spec "dressing uses only free pile markers; every piece is non-queryable".
3. **Doors that start open break nothing.** Harlow's door beat, the closed-door traversal harness and players closing
   them all still work. → Task 4 spec plus Task 10 probe (traversal with `closeAll` still 0 failures; an open door
   closes on interact).
4. **A rebuild between shifts leaves no stale variation.** A new seed gives new choices. Anomaly visuals from the last
   run are undone: the screen text, the TV, the doors, the silhouette, the banner and the sign. → Task 7 spec on
   `apply`/`reset`; Task 10 probe across two shifts.
5. **The searched desk keeps its art.** After a search the same desk model stays, its drawers are open, and the hide
   space under it is unchanged (`HUG_FREE_MIN`). → Task 9 spec and probe.

## New modules

| Feature | Realm | Subfolder | Name | Job (one line) |
|---|---|---|---|---|
| Office | server | Rules | `OfficeVariationRules` | Every per-run choice (props, clutter, light moods, open doors, stains, anomalies), from the shift seed. |
| Office | server | Systems | `OfficeDressingSystem` | Builds the run's decorative stains and paper clutter on free pile markers. |
| Office | shared | Data | `OfficeAnomalyConstants` | Anomaly ids, odds, slot tag/attribute names and the welcome-screen word list (server picks, client applies). |
| Office | client | Systems | `OfficeAnomalySystem` | Applies the run's exterior anomalies to the tagged slots in `OfficeExterior` and resets them. |
| Office | client | Utils | `OfficeAnomalyUtils` | Pure timing and look tests for the anomalies (silhouette seen-then-gone, door cycle, screen word). |

| Office | shared | Utils | `OfficeSeedUtils` | The stable per-run hash `hash01(seed, key)` that server and clients share. |

`OfficeVariationRules` is server-side; the client derives its own seed-based looks (broken tubes, the welcome-screen
line) from `OfficeSeedUtils.hash01` with `Workspace.CleanupCrewOffice`'s `LayoutSeed`, so both sides agree.

---

### Task 1: The variation rules (pure)

**Files:** Create `src/ServerScriptService/Features/Office/Rules/OfficeVariationRules.luau` (+spec),
`src/ReplicatedStorage/Shared/Features/Office/Data/OfficeAnomalyConstants.luau` (+spec if not spec-exempt data), and
the shared hash per the note above.

**Interfaces (produces):**
- `hash01(seed: number, key: string): number` in [0, 1); stable across server and client (no `Random`, no
  `tostring` of floats).
- `OfficeVariationRules.keepProp(seed: number?, markerId: string, art: string): boolean`
  - true when `seed == nil`;
  - otherwise `hash01(seed, "prop:" .. markerId) < (PROP_CHANCE[art] or 1)`.
- `OfficeVariationRules.deskClutter(seed: number?, deskId: string): { string }`
  - the kept items, from `DESK_CLUTTER_CHANCE` (mug 0.7, stationeryCup 0.6, folder 0.5, paperTray 0.5,
    paperStack 0.5, bookStack 0.4);
  - folder and paperStack never both;
  - seed nil keeps today's parity rule.
- `OfficeVariationRules.lightMood(seed: number?, roomId: string, roomType: RoomType?): "normal" | "dim" | "dark"`
  - `normal` for nil seed, halls, storage, server and reception;
  - otherwise weights normal 0.6, dim 0.3, dark 0.1.
- `OfficeVariationRules.doorStartsOpen(seed: number?, doorId: string): boolean`: probability `DOOR_OPEN_CHANCE` 0.3,
  false for nil seed.
- `OfficeVariationRules.dressing(seed: number?, freeMarkerIds: { string }): { [string]: "stain" | "paper" }`: each
  free marker gets a stain with probability 0.2 or paper with probability 0.2, else nothing; empty for nil seed.
- `OfficeVariationRules.anomalies(seed: number?): { AnomalyId }`
  - 1 anomaly with probability 0.65, else 2;
  - drawn without repeats from `OfficeAnomalyConstants.IDS`;
  - empty for nil seed.
- `OfficeAnomalyConstants`:
  - `IDS = { "silhouette", "autoDoors", "carTicking", "welcomeScreen", "boothTv", "wetFloor", "banner" }`;
  - `SLOT_TAG = "OfficeAnomalySlot"` and `SLOT_ATTRIBUTE = "AnomalyId"`;
  - `PUBLISHED_ATTRIBUTE = "OfficeAnomalies"` (a comma-joined id list on the office model);
  - `WELCOME_TEXT = "WE VALUE YOUR TIME"`;
  - `WRONG_WORDS = { "WE VALUE YOUR SLEEP", "WE VALUE YOUR SILENCE", "WE HEAR YOUR TIME", "WE VALUE OUR TIME", "WE VALUE YOUR TEETH" }`,
    picked by `hash01(seed, "welcome")`.
- `PROP_CHANCE` (in `OfficeConstants`, by art key; anything absent is 1):

  | Art key | Chance |
  |---|---|
  | deskPlant | 0.6 |
  | planter | 0.75 |
  | rug | 0.7 |
  | artFrame | 0.8 |
  | copier | 0.85 |
  | sofa | 0.85 |
  | vending | 0.8 |
  | waterCooler | 0.8 |
  | clock | 0.7 |
  | corkboard | 0.8 |
  | floorLamp | 0.75 |

  Never listed, so always 1: `column`, `windowBay`, `partition`, `receptionGlow`, `serverRack`, and every gameplay
  kind.

- [ ] **Step 1: Specs.**
  - **Determinism:** the same `(seed, key)` gives the same `hash01` on repeated calls, and in [0, 1); 1,000 keys spread
    with mean 0.5 ± 0.05.
  - **nil seed:** every rule returns its today/neutral value.
  - **Desk clutter:** never contains both folder and paperStack.
  - **Light mood:** halls, storage, server and reception are always `normal`.
  - **Anomalies:** over seeds 1-2,000, the 1/2 split is within ±5% of 0.65/0.35, no repeats, and every id appears.
  - **Welcome word:** always in `WRONG_WORDS`.
- [ ] **Step 2:** Run in Studio Play. Expected: the new specs FAIL.
- [ ] **Step 3:** Implement.
- [ ] **Step 4:** Run in Studio Play. Expected: all pass. Clear `RunTests`.
- [ ] **Step 5: Commit.** `Office variation: per-run choices from the shift seed`

### Task 2: Props and desk clutter vary per run

**Files:** Modify `Systems/OfficeDecorSystem.luau` (prop loop ~565, `dressDesk` ~295-327, `build` signature ~412),
`OfficeServiceServer.luau` (the `Decor.build` calls ~217, ~325), `Data/OfficeConstants.luau` (`PROP_CHANCE`,
`DESK_CLUTTER_CHANCE`), plus specs.

- `OfficeDecorSystem.build(layout, origin, parent, visuals?, seed: number?)`.
  - A `prop` marker is built only if `keepProp(seed, marker.id, marker.art)`.
  - `dressDesk` places `deskClutter(seed, desk.id)`.
  - The rebuild passes the shift seed; boot passes nil.
- Kit markers, ids and `OfficeKitRegistry` specs are unchanged. Filtering happens at decor time, so ids stay stable.

- [ ] **Step 1: Specs** (`OfficeDecorSystem.spec`):
  - seed nil builds exactly today's props, and the "complete eight-prop kit" still holds;
  - with a seed, built prop count ≤ markers, and two different seeds give different prop sets for a kit with ≥ 6
    optional props;
  - no desk, closet, locker, shelf or board proxy is ever removed;
  - a desk's clutter equals `deskClutter(seed, id)`.
- [ ] **Steps 2-5:** RED, implement, GREEN (full suite), commit. `Office decor: props and desk clutter vary per run`

### Task 3: Light moods and broken tubes vary per run

**Files:** Modify `Utils/OfficeLightingUtils.luau` (`roomLights` ~106-148), `Systems/OfficeShellVisualSystem.luau` (pass
the seed through), the client `Utils/OfficeLightUtils.luau` (`hash`) and `Systems/OfficeAtmosphereSystem.luau`
(`stepBroken` ~250-305), plus specs.

- **`roomLights(layout, …, seed: number?)`.** The mood comes from `lightMood(seed, room.id, room.roomType)`:
  - `normal` keeps today's pattern, `(i + 2j) % 3 ~= 1`, about 2/3 lit;
  - `dim` lights only `(i + 2j) % 3 == 0`, about 1/3;
  - `dark` lights no panels, and its fills' brightness is × 0.5.
  - Halls and `allLit` rooms are unchanged.
- **Client broken tubes:** a tube is broken when `hash01(seed, "tube:" .. <tube position key>) < BROKEN_FRACTION`.
  - The seed comes from `Workspace.CleanupCrewOffice:GetAttribute("LayoutSeed")`; when it is nil, today's position
    hash applies.
  - The position key must be stable: rounded layout-space x/z of the tube.

- [ ] **Step 1: Specs.**
  - seed nil reproduces today's lit set exactly (`OfficeLightingUtils.spec:60` still passes);
  - a `dark` room has 0 lit panels and half-brightness fills;
  - a `dim` room lights about 1/3;
  - client: the broken set differs between two seeds, and is equal for the same seed.
- [ ] **Steps 2-5:** RED, implement, GREEN, commit. `Office lights: room moods and broken tubes vary per run`

### Task 4: Doors that start open, and stains and paper clutter

**Files:** Create `Systems/OfficeDressingSystem.luau` (+spec). Modify `Systems/OfficeDoorSystem.luau` (an
`openAtStart(ids)` on the `DoorSet`, or a build option) and `OfficeServiceServer.luau` (after the spawn plan, about the
`lastPlan = plan` line: one call each, since it is over the line cap).

- **Doors:** after build, every `solid`/`glass` interior door with `doorStartsOpen(seed, door.id)` opens instantly,
  without the 0.3 s swing and without a sound. Facades and exits never.
- **`OfficeDressingSystem.build(layout, plan, seed, origin, parent): Folder?`**
  - The free pile markers are the layout's `pile` markers minus `plan.piles`' markers.
  - `dressing(seed, free)` decides: a `stain` is 1-3 flat dry Gloom blobs (reuse `OfficeOozeSystem`'s blob helper and
    palette, darker and dried: 60% opacity, `CastShadow=false`); `paper` is 2-4 scattered sheets (flat white
    0.05-thick parts, slight random yaw).
  - All `CanCollide/CanQuery/CanTouch=false`.
  - Built into the office model, so a rebuild removes it.

- [ ] **Step 1: Specs.**
  - With a fixed seed, the opened door ids equal `doorStartsOpen`;
  - facades and exits never open;
  - dressing never uses a `plan.piles` or `plan.items` marker;
  - every dressing part is non-collide/query/touch;
  - seed nil builds nothing and opens nothing.
- [ ] **Step 2:** RED.
- [ ] **Step 3:** Implement.
- [ ] **Step 4:** GREEN, then the traversal harness (seeds 1-20, `closeAll` first, as today): 0 failures.
- [ ] **Step 5: Commit.** `Office: some doors start open; stains and paper on free spots`

### Task 5: The server picks the run's anomalies

**Files:** Modify `OfficeServiceServer.luau` (where `LayoutSeed` is set, ~214), plus a spec on the pick through
`OfficeVariationRules`.

- **Publishing:** after a rebuild, `current.model:SetAttribute(OfficeAnomalyConstants.PUBLISHED_ATTRIBUTE,
  table.concat(anomalies(seed), ","))`. The boot layout sets nothing.
- **Debug:** `OfficeServiceServer:anomalies(): { AnomalyId }`, and a Cmdr admin command `anomaly <id|none>` that
  overrides the attribute for testing, following the existing fail-closed admin allowlist pattern.
- [ ] **Steps 1-5:** spec (the attribute equals `anomalies(seed)` for a built seed; boot has no attribute), RED,
  implement, GREEN, commit. `Office: each run publishes its exterior anomalies`

### Task 6: Anomaly slots in the exterior set (Studio art)

**Files:** Modify `design/production-art/map-kits/odd-hours-b1/exterior/BuildExterior.CommandBar.luau` + README.

Every slot is tagged `OfficeAnomalySlot`, with attribute `AnomalyId` set to the slot's id. Each is built in its
**default (no anomaly) state**:

| Slot | Default state |
|---|---|
| `silhouette` | One flat, featureless dark figure cut-out (simple parts, about 2 × 6 studs), invisible (`Transparency 1`), placed just behind the glass of one `WinLit` tower window that faces the yard. |
| `autoDoors` | The two `LobbyDoorLeaf`s, tagged as-is (they slide ±2.2 studs along the rotunda's tangent). |
| `carTicking` | An invisible emitter part at the yard car (909, 35 world). |
| `welcomeScreen` | `Lobby.WelcomeScreen` with a SurfaceGui text label, empty by default. |
| `boothTv` | `Fence.BoothTV` (dark). |
| `wetFloor` | A yellow A-frame "WET FLOOR" sign (simple parts plus SurfaceGui text, no upload), `Transparency 1`, standing in a yard puddle near the walk to the dock. |
| `banner` | A motivational banner on the podium front, right way up: "TOGETHER WE THRIVE", simple parts plus SurfaceGui. |

Keep ≤ 4,500 parts and ≤ 70 lights, and keep the keep-out check.

- [ ] **Step 1:** Rebuild in Edit (one undo step).
- [ ] **Step 2: Probe.** It must print `slots=7` (one per id) plus the parts and lights counts, and `keepoutHits=0`.
- [ ] **Step 3: Commit** the builder and README. `Office exterior: anomaly slots`

### Task 7: The client applies the anomalies

**Files:** Create the client `Systems/OfficeAnomalySystem.luau` and `Utils/OfficeAnomalyUtils.luau` (+spec). Wire them
into the client Office service start/stop, like `OfficeAtmosphereSystem`.

- **Reading:** the system reads `PUBLISHED_ATTRIBUTE` on `Workspace.CleanupCrewOffice` (and its changes) and finds
  slots with `CollectionService:GetTagged(SLOT_TAG)` (streamed-in and -out safe).
- It `apply(id)`s each listed id and `reset`s every slot not listed, restoring the default state.
- **Behaviour per id:**

  | Id | What happens |
  |---|---|
  | `silhouette` | Visible. Once it has been in view (on screen, ≤ 400 studs, not occluded by a raycast) for 0.5 s, it hides the next time it is off screen, and stays hidden for this player for the run. |
  | `autoDoors` | While a player is within 60 studs, the leaves slide open 2.2 studs over 0.6 s, hold 2 s, and close, every 20-40 s (hash-timed per cycle). |
  | `carTicking` | A slow engine-cooling tick loop at the emitter (`rollOffMaxDistance` 40), plus the car's tail lights dim-on. |
  | `welcomeScreen` | Shows `WELCOME_TEXT`, and every 6 s shows the run's wrong line for 1.2 s. |
  | `boothTv` | The screen glows cold blue (Neon) with a flickering SurfaceLight (brightness 0.6-1.2, about 8 Hz noise), plus a faint static loop (`rollOffMaxDistance` 25). |
  | `wetFloor` | The sign becomes visible. |
  | `banner` | The banner turns 180° about its forward axis. |

- **Sounds:** register in `OfficeAssets` as `carTick`, `tvStatic` and `autoDoor`, with **empty assetIds** (pending and
  silent) until Task 8.
- **Pure parts in `OfficeAnomalyUtils`:** the silhouette state machine
  `(state, onScreen, visibleFor, now) -> state`, the door cycle timing, and the welcome text at time t.

- [ ] **Step 1: Specs** (`OfficeAnomalyUtils.spec`):
  - silhouette: hidden → visible → seen after 0.5 s in view → gone once off screen, and never back;
  - door cycle: open/hold/close phases at the right times;
  - welcome text: shows the wrong line in the 1.2 s window of each 6 s cycle;
  - `apply`/`reset` restore every slot's default (Review Focus 4, through a stub slot set).
- [ ] **Steps 2-5:** RED, implement, GREEN, commit. `Office anomalies: the client plays the run's odd things`

### Task 8: The anomaly sounds (sourcing; upload needs the owner's OK)

- Use the `game-sound-design` then the `sourcing-roblox-sfx` skills. Produce 3 cues in Odd Hours' sound identity:
  - `carTick`: an engine-cooling tick loop;
  - `tvStatic`: a quiet static hum loop;
  - `autoDoor`: a soft sliding-door whoosh with a chime.

  Check them against the skills' QA gates.
- **Stop:** the controller presents the 3 files to the owner for an upload OK. Only after it, upload via `publish.py`
  (Icey Labs) and fill the asset ids in `OfficeAssets`.
- **Commit:** `Office anomalies: sounds`

### Task 9: A desk whose drawers open (art; upload needs the owner's OK)

- **Contract:** read `Systems/OfficeSearchedDressingSystem.luau` (`buildTemplate` ~37 and the search path ~250-310).
  Art pieces carrying the attribute `SearchComponent = "drawer"` (or `"door"`) are animated in place; without them the
  native fallback desk replaces the art. That fallback is the swap the owner saw.
- **Build the desk** in Blender, hand-built per the `texture-pipeline` skill's hard-surface kit:
  - the same look and size as `c_desk_nodivider` (8.8 × 4.95 × 4.6, NegativeZ front, KIT_MAP row 23);
  - a top, legs and modesty panel as one mesh, plus 2-3 drawer meshes as separate meshes (each with colour, normal and
    roughness maps);
  - the knee-hole keeps `HUG_FREE_MIN` (3.6 W × 4.2 H × 4.3 D) free;
  - no divider.
- **Stop:** the controller presents renders to the owner for an upload OK. Only after it, upload (Icey Labs) and
  assemble the kit's `desk` template in `ArtKits["odd-hours-b1"]` with each drawer part tagged
  `SearchComponent = "drawer"`. Update `AssembleKit.CommandBar.luau` and `KIT_MAP.md`.
- **Spec and probe** (Review Focus 5): after a search in Studio, the desk's art model is the same instance, its drawer
  parts have moved out, no fallback model exists, and the hide-space measurement still passes.
- **Commit:** `Office desk: drawers that open in place`

### Task 10: Studio verification

**Files:** Create `reports/office-stage4-variation.md`; modify `HANDOFF-office-map-2026-10-23.md`.

**Probes** (lock protocol; real solo shifts):
- **V1:** suite all pass; traversal seeds 1-20: 0 failures; hide spots ≥ 8 on seeds 1-50.
- **V2:** two shifts with different seeds: list the prop, clutter, light-mood, open-door and stain differences in one
  room type.
- **V3:** the broken-tube set is the same on two clients for one seed (or on the server's hash and the client's).
- **V4:** each of the 7 anomalies forced via the admin command:
  - each behaves as specified;
  - after the next shift every slot is back to default;
  - captures of each in `design/production-art/map-kits/odd-hours-b1/exterior/captures/s4_*.jpg`.
- **V5:** an open door closes on interact, and Harlow passes open and closed doors.
- **V6:** the desk search keeps the art, with drawers out (only if Task 9 landed).

**Then:**
- [ ] **Commit.** `Office stage 4: variation and anomalies verified in Studio`
- [ ] **Owner play-check.** Done only after the owner passes it.
