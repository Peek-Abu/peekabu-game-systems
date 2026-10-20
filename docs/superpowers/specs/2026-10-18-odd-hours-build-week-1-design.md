# Odd Hours — build week 1 design

Date: 2026-10-18. Branch `game/cleanup-crew` (worktree `.claude/worktrees/mvp-demo-pack-052599`).
Source of truth for decisions: the Launch Board (https://claude.ai/artifact/HAihFJ69ELqoZ8zF3uBgxa) and the
handoff `docs/superpowers/handoffs/2026-10-18-first-launch-build-week-1.md`. This doc only adds what those
leave open. Lines marked **(my call)** are the designer's defaults, not owner decisions; the owner can change them.

## Intent

Odd Hours goes public on or before Thanksgiving (26 Nov 2026) for a broad 16+ audience first. Week 1 lays the
foundation everything else ships into: two places, the polished first employee, the new catch, real saved
money, and the analytics the 12 launch experiments need. Plus the polish the owner saw in family tests.

**Goals:** each of the six parts below works end-to-end in Studio (solo and 2-player Local Server), with specs
green (last count 3828), and goes to "review" on the board.
**Non-goals this week:** Orientation/Probation, School site, employees 2–5, shop and Lockers, effect
cosmetics, Timecard/Work Order (week 2). VFX *polish* (a later dedicated phase; see below).
**Anti-goals:** anything that makes the catch feel toothless (Manager no longer feared); any client-written
authoritative state; anything that lets Rojo touch artist content; a coat whose state players have to guess.

## Order (owner-confirmed 2026-10-18)

1. Hub place + one Shift place
2. Pippa polish
3. Gloom coat catch (with lives hooks)
4. Currencies + data migration
5. Analytics events
6. Polish: hiding, crouching, voice, small leftovers
7. Office map rework (added by the owner 2026-10-18; research starts now, the build follows the place split)

Parts 3–5 don't depend on part 1 landing first in code (they work in the single place too), so they can be
built in parallel as long as no two builders touch the same files.

## Owner answers already given (2026-10-18)

- Rehire card portrait → **round frame** (head and shoulders in a circle).
- Results "Times caught" → rename **"Crew caught"**.
- Caught players stay excluded from clock-out +5 XP ("Incident Report filed" instead).
- **"Whole crew out +5" is paid only on a real clock-out.** Today `RankFormulas.factsFor` (`everyone`,
  `Shared/Features/Rank/Utils/RankFormulas.luau:92-99`) pays it on a timer end too — fix it.

---

## 1. Hub place + one Shift place

**What exists:** the split is already in the code. Queue has roles `depot` (hub) and `shift`
(`DepotConstants.PLACE_IDS`, both `0`, `DepotConstants.luau:46-51`), reserved-server teleports with retries,
arrival/late-joiner/stranger handling, `returnParty` for the trip home, and local mode in Studio (moves
players to the role's arrival point instead of teleporting). Runbook: `docs/cleanup-crew-publish.md`.

**What's left:**
- **The Shift place holds the hand-built Office** (part 7). Until it exists, the code-built blockout keeps
  working; part 7 switches the Office to read tagged gameplay points. Live teleport testing happens on the
  published places.
- **Place ids.** The owner creates the Shift place in Studio and publishes it; ids go into
  `DepotConstants.PLACE_IDS`. The existing place 113354563835664 becomes the **hub** (owner decision 2026-10-18).
  The Shift place is published from the same code (code-only Rojo project), with its own map content
  (the office build) owned in that place.
- **Per-place services.** Every `*ServiceServer` registers in every place today. Hub-only and shift-only
  services must stay inert in the other place. Split:
  - both: PlayerData, Currency, Inventory, Rank, Title, Entitlement, Marketplace, Badge, DailyReward, Setting,
    StateSync, Toast, Admin, Debugger, Analytics, Leaderstat, Animation, Sound, Vfx, Voice, Camera, Sprint,
    Crouch, Death, Employee, Interaction, Queue.
  - hub only: Depot.
  - shift only: Shift (+ Trip, Transit, Vote, ClockOut…), Round, Office, Occupant/Npc, Cargo, Noise, Hide,
    Carry/Loot, Vacuum's tool and piles (the backpack look stays in both).
  - Mechanism **(my call)**: gate inside each service's `start` with `QueueServiceServer:runsRole(role)` (which
    is true for every role in local mode, so Studio still runs everything in one place). No ServiceController
    change in base.
- **Office builds unconditionally** (`OfficeServiceServer.luau:212-221`) — gate it to the shift role.
- **Couplings:** Shift requires Depot (`ShiftServiceServer.luau:398-410`) and the trip system requires Depot and
  Office. Shared pieces (`DepotContractUtils`, `CONTRACTS`, `ShiftQuotaFormulas`, `ShiftCardUtils`) are pure and may stay
  shared. Calls into Depot from Shift must be safe when Depot is inert in the Shift place.
- **Done when:** in Studio (local mode) the full loop still works in one place; with real ids, a published test
  sends a party hub → reserved Shift server → back to hub, the result card shows in the hub, and a stranger
  who joins a Shift server directly is sent to the hub.
- Owner action: create + publish the Shift place; tell us its id. Live teleport testing needs both published.

## 2. Pippa polish

Use the toon character pipeline (memory `toon-character-pipeline.md`) and the Employee Kit in
`characters/kit`. **Reference:** the approved sheet `characters/pippa/ref/pippa-sheet.webp` (main checkout; also `face_happy.png`, `hands_feet.png`); latest build v10 with `v10/compare.png`. Visible gaps: head-heavy, short chunky limbs vs the sheet's slimmer body, longer legs, rounder cheek tufts, bigger mitten hands/feet, longer ears with a softer flop. Goal: Pippa reads like her reference (face,
proportions, ears, palette, uniform) from the hub and on the shift, before new employees reuse her rig and face kit.
Done when the owner approves side-by-side renders against the reference, then in-game.

## 3. Gloom coat catch

Replaces today's catch → death → 8 s spectate → "Rehired" respawn for every catch.

### The rules (board decisions)

- Each grab puts one **Gloom coat layer** on the player. **Layers are lives**: base max **3**.
- A teammate **vacuums a layer off** (hold, base ~2 s; experiment `exp-clean` 1.5 s vs 3 s) — this is also the revive.
- The catch that brings you to max layers ("the last layer"): you are **out** — back to the truck, auto-rehire
  after a countdown (base 5 s; experiment `exp-rehire` 5 s vs 10 s). Rehire clears your coat **(my call)**.
- **Solo:** the last layer rehires you **instantly** at the truck and cuts the shift clock by a growing
  amount (each solo knock-out costs more than the last) **(my call: 15 s, +15 s each time — tunable)**.
- **Solo (my call):** "solo" means only one crew member is still connected when the knock-out happens (a 2-player
  crew that drops to 1 plays solo from then on). A time cut or penalty that takes the clock to 0 ends the shift
  as a normal timeout.
- **Whole crew out at once** (every crew member is in the knock-out countdown): everyone is rehired together
  and the shift clock takes a time penalty **(my call: 30 s — tunable)**.
- Kids-simple: no carrying bodies.

### Down, revive, get up (owner decisions 2026-10-18)

- **Every grab puts you down.** The grab and scare stay as today (freeze, camera on his face, lights out). Then
  he throws you: you ragdoll and lie **down in the goo** with one more layer on. Down is not death: no spectate,
  you can't move or act, and you see your layers and a get-up timer. You drop your hands item and pockets as
  today. He gives you the usual grace (~10 s).
- **A teammate revives you** by vacuuming you (hold, `cleanSeconds`). **The revive takes that layer off**,
  so a good crew restores lives. A teammate can also vacuum a layer off someone who is up.
- **No rescue:** after `downSeconds` (base **12 s**, tunable **(my call)**) you get up on your own — **the
  layer stays**. Solo players never get stuck.
- **The grab that fills your last layer** (layers = maxLayers): you're **out**. "You're FIRED!", launch,
  the CCTV spectate as today, but the wait is the rehire countdown and you come back at the truck with a
  clean coat.
- **"Caught" for XP and results (my call, follows from the above):** being knocked **out** is what counts as
  caught — that's what excludes you from the +5 clock-out XP and the crew's "Whole crew out". A grab that was
  revived doesn't. Results show **"Crew caught"** = knock-outs, plus a "Layers cleaned" line.
- Whole crew down or out at the same time: if nobody is left up to revive, the down players still get up on
  their own timer; the crew-wipe penalty applies only when everyone is **out** at once.

### Obvious to players (owner requirement)

A player must always know how many layers they and each teammate have:
- **On the character:** visible goo layers on the body, one stage per layer (heavier each time), seen by
  everyone. Built in the current style; polish waits for the VFX phase.
- **At the catch:** the catch overlay shows the layer landing ("Layer 2 of 3"); on the last layer it says
  you're headed back to the truck with the countdown (the existing CCTV card, retitled).
- **Crew screen:** the crew roster (`ShiftCrewViewModel` / compact HUD) shows each player's layers as a pip
  row (empty → goo-filled) next to their name. Knocked-out players show "OUT · back 0:05". A teammate with
  layers shows a hint that you can clean them.
- **On a teammate:** the vacuum prompt appears on a coated teammate in range, with the hold progress.

### Hooks: everything about the coat is modifiable (owner requirement)

Not hard-coded constants. These values are computed per player per moment:
`maxLayers`, `cleanSeconds` (revive / clean hold), `downSeconds` (get up on your own), `rehireSeconds`,
`soloTimeCut`, and the crew-wipe `crewPenalty`.

- Each is **base value + registered modifiers**. Other systems register a modifier and get back a remover
  (the pattern of `CameraServiceClient:addModifier`, `Client/Features/Camera/CameraServiceClient.luau:286`).
- A modifier is scoped (whole server, or one player) and is either an add or a multiply; the combine is
  pure, specced logic: adds first, then multiplies, then clamped (maxLayers 1–6, times ≥ 0) **(my call)**.
- Expected sources: the **experiment variant** (`exp-clean`, `exp-rehire`) from day one; then an
  **employee perk** (e.g. "+1 layer"), a boost/pass, a site/difficulty, an event. Employees have no perk data
  yet; week 1 adds only the hook and one test perk in specs — real perks come with employees 2–5.
- The resolved `maxLayers` is what the UI shows, so a "+1 layer" employee visibly has 4 pips.

### Shape

- The coat is shift-only, server-authoritative state (not saved): layers per player, knocked-out deadline.
  Public per-player fields ride the existing StateSync public player store (like today's `caughtUntil`), so
  every client sees each player's `layers`, `maxLayers` and `outUntil`.
- Cleaning a teammate is a new Interaction **channel kind** on the coated player's root part (as
  `CargoGrimeSystem` does for grime), picked up by the vacuum's target selection. Several cleaners stack rate,
  progress kept on release (engine default). You can't clean yourself, can't clean while hiding or carrying
  **(my call)**.
- Down is a non-lethal ragdoll held by the server (not Death). Death is used only for the knock-out; respawn
  policy goes manual so the countdown controls the rehire.
- Voice: today "the living never hear the dead". A down (not out) player stays living, so nothing changes.
- Shift results: count knock-outs ("Crew caught"), layers taken and layers cleaned per player.

**Done when:** solo and 2-player Studio runs show the full ladder (1st grab → down with 1 pip → teammate
revives → up with 0 pips; grab with no rescue → up after the timer, pip stays; last layer → out → countdown →
back at the truck with 0 pips; solo → instant rehire with the clock cut; both
players out → both rehired with the penalty), a spec'd "+1 layer" modifier makes a fourth pip appear, and
the two experiment variants change the clean and rehire times.

## 4. Currencies + data migration

**Pay (owner decision 2026-10-18):** every crew member still in the shift at the end gets the **full** pay
(contract fee + commission on recovered valuables, overtime included), knocked-out players too; players who
left mid-shift get nothing; paid on any ending, timeout included. Saved Gloom = the shift's Gloom scrapings,
same full-crew rule.


**Today:** the only saved currency is the placeholder `coins` (start 100, slot-scoped slice "currency").
Shift pay is **display only** (no balance ever saved). A premium account slice `premium {balance}` already
exists in Marketplace with its validator, but nothing uses it.

**Target (board):**
- **Gloom** — earned only, never sold, from filter scrapings: a little per pile cleared. Buys Gloom Locker keys
  (week 2).
- **Credits** — pay: contract fee + commission per recovered valuable, more for overtime. Buys employees and
  sites.
- **Gleam** — premium, bought with Robux; **is the existing `premium` account slice**, renamed in the
  player-facing text to Gleam **(my call)**. Products/packs come with the shop (week 2); week 1 is the balance.
- Currency definitions: Gloom and Credits replace `coins` in `CurrencyConstants`, validated by the existing
  currency validator.
- The shift's display-only "Gleam" pay becomes real **Credits** paid at shift end, and Gloom scrapings are
  saved, both in one transaction through `PlayerDataService` (server only). The HUD and results say Credits.
- **Migration v2 → v3** in `PlayerDataMigrationSystem`: remove `coins` from saved profiles and start Gloom and
  Credits at 0 **(my call: no carry-over — coins were a placeholder and pay was never saved)**.
- Amounts per pile/valuable/overtime: keep today's formulas as the starting numbers, retuned later.

**Done when:** a finished shift saves Credits and Gloom (visible after rejoin), a v2 profile loads as v3
with `coins` gone, and the spec for `CURRENT_VERSION` reads 3.

## 5. Analytics events

**Today:** `AnalyticsServiceServer` wraps Roblox AnalyticsService (custom, economy, funnel, progression), but
only `custom` is used: 13 shift events from `ShiftAnalyticsWatchSystem`. Field 1 packs
`variant|platform|party|build`. One variant per shift from `ShiftVariantRules`.

**Add:**
- **Experiment assignment** for all launch experiments on the board: each player gets a stable variant per
  experiment (from their userId), readable by any system (the coat uses `exp-clean` and `exp-rehire`).
  Experiments whose feature doesn't exist yet are assigned now, so the first session is already tagged.
- **Funnel** (Roblox funnel events) for the first-time path: joined hub → boarded a truck → shift started →
  first cleanup → first pickup → first bank → quota met → clocked out → results viewed → replay/back to hub.
- **Economy** events for Gloom, Credits and Gleam sources and sinks.
- **Catch/coat** events: layer added, layer cleaned (by whom), knocked out, rehired, crew wiped.
- Every event carries: variant(s), platform, party size, new vs returning, build (competitor handoff §16).
  Roblox allows only 3 custom fields per event, so **(my call)**: each player's full assignment is logged once
  per session as its own event (joinable by session id), and an event carries only the experiment(s) that
  affect it. "New vs returning" uses a saved first-seen timestamp added in the v3 migration.
- **Unit of an experiment (my call):** mechanics a crew shares (`exp-clean`, `exp-rehire`)
  are assigned **per crew** — from the shift's crew id, the same for everyone in it, which replaces
  `ShiftVariantRules`' single per-shift variant. Personal ones (friend-skip, starter pack, timecard, employee 2 timing,
  unlock pace, price ladder) are **per player** from userId. The coat's experiment modifier is therefore
  server-scoped for the shift.
- **Done when:** a Studio run logs the full funnel and coat events at debug with the right context fields.

## 6. Polish

- **Hiding looks bad to others:** clipping and wrong poses from the outside (local view is fine). Inspect
  `HidePoseSystem` (client, blends a tucked pose on every client) and the server anchor/slide into the spot
  from a second client's view; fix per spot type.
- **Owner clarification:** the "crouching looks bad" issue is the hiding one: a player hiding **under** furniture
  clips through it for other viewers. Fix it **generically for every character** (fit the tuck to the spot's
  free space and the character's proportions), never with per-character hide animations.
- **Crouch speed:** owner picked `CROUCH_SPEED = 6.5` with a faster crouch-walk cadence (feet plant). Known: feet slide slightly at 9 st/s
  (`CrouchConstants.CROUCH_SPEED`) — match the walk clip's speed or the speed to the clip.
- **Voice doesn't work.** Config is `VoiceChatService { EnableDefaultVoice = false, UseAudioApi = Enabled }`
  plus `VoiceServiceServer` wiring. Voice is 13+ and ID-verified only; check the setup and the place's voice
  settings. Pings come first (week 2+), so this is a check-and-fix, not a feature.
- **Small:** round-frame rehire portrait (`CatchRehiredPanel.luau:250-262`); "Crew caught" label
  (`ShiftReviewViewModel.luau:291`); hide prompt picks the table behind a cabinet (prefer the nearest spot the
  player faces); "Whole crew out" gated to clock-out.

## 7. Office map rework

Board: the Office is **rebuilt with real hallways, hand-built in Studio**, and code finds gameplay points by
**tags/attributes** (hide spots, Gloom piles, valuables, patrol points, the time clock, the truck dock), so
builders never need code. Today it is a code-generated blockout that looks low-quality next to the
characters and UI, with no hallways.

**Owner decision (2026-10-18): Claude builds it, research first.**
1. **Research:** study large games known for beautiful or scary map design (layout, sightlines, landmarks,
   readability, set dressing, asset quality, **lighting**), on Roblox and off. Output a written reference with
   concrete, checkable rules (`research_notes/` + a reference doc in the repo).
2. **Tag contract + builder guide:** every gameplay point the code needs, as tags/attributes, documented for
   non-coders. The Office service reads them instead of generating the layout; the generator stays only as a
   fallback until the hand-built map passes.
3. **Build:** the Office layout with real hallways in the Shift place (Studio MCP), assets in the toon style
   (Blender MCP, local/free generation; ForgeGUI props only if the owner generates them), lighting per the
   reference. Gameplay first: the Manager's patrol, hiding, sightlines, the truck dock and loading bay must
   play at least as well as today.
4. **Polish loops** with owner review (look, layout and rules approved separately), then a map
   design / building / modeling **skill**, like the UI and VFX phases.

Figma may be used for layout plans and mood boards. **Done this week when:** the research reference and tag
contract are written, and a first playable hallway Office runs a full shift off tags (look polish continues
into later weeks).

## VFX in week 1

Functional and in the current style (goo layers, clean-off puff, knock-out). Real polish is a later VFX
phase run like the UI phase (study games → teach Roblox VFX styling → loop → make a skill). Log polish needs
for that phase instead of polishing now.

## Constraints (from AGENTS.md and the owner's standing rules)

`--!strict`, no `any`/casts; spec-first (every new module has a `.spec` or an exemption with a reason);
module placement per `docs/project-structure.md` and the `module-placement` skill, stated in the plan;
server-authoritative; plain commit messages without trailers; game branch never merges into base (base fixes
go in `base/*` PRs off `origin/main`); Studio only in the "Odd Hours" window; playtest lock; no computer-use;
no installs/builds while the owner is connected; assets to group 189923277 only; UI per `game-ui-design`,
sound per `game-sound-design`. Board items move todo → doing → review; never Done.

## Left to the builder

Module names and placement (in the plan), exact UI layout of pips within the existing crew roster style,
goo look within the current VFX style, tuning numbers marked tunable, and how the knock-down ragdoll is made
without killing (base Death/ragdoll pieces vs a local ragdoll), as long as it doesn't touch base.
