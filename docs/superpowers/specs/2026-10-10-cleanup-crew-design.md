# Cleanup Crew: MVP design

Date: 2026-10-10. Source briefs: `MVP_Demo_Pack/cleanup_crew_01_design.md`, `_02_implementation.md`,
`_03_validation.md` (kept outside the repo). This spec records where we deliberately differ from them.

## 1. Goal and success

A published, playable demo of Cleanup Crew that the developer tests with two siblings (3 players) to
answer one question: **is it fun?** The brief's validation question rides along: *do players voluntarily
go back for optional salvage after the quota, and does cleaning improve that decision?*

Success for this spec: the full loop (depot → queue → shift → results → back or another shift) runs
in a published experience with 1–4 players, on PC and phone, with no developer intervention.

**Polish level: "polished feel on graybox."** Level geometry is code-built blockout. Everything the
player *feels* is finished: VFX, SFX, prompts, progress, threat cues, the catch scare, results.
Dressed art is a later decision, taken only if the demo earns it.

### Deliberate departures from the briefs

| Brief says | We do | Why |
|---|---|---|
| Value quota | **Clearance quota counts trash only**; salvage is a separate bonus | Makes cleaning the core job (developer request); sharpens the "go back for salvage" question |
| One office, fixed items | Authored geometry, **randomised spawns** (piles, items, desk contents, occupant start) with guarantees | Replay value; the brief's "no procedural geometry" still holds |
| 3 pile visuals, printer, cabinet | 3 pile visuals, **12 cargo items with handling traits** | Variety the developer asked for, each item changes how you carry |
| Caught: drop cargo, respawn | Caught: **scare + ragdoll launch + spectate + respawn** | Tension and light horror (kid-safe, no gore) |
| One server session | **Depot lobby place + reserved shift servers** with queue pads | Roblox servers are public; parties must queue together |

Kept from the briefs: one occupant only, no persistent progression, no paid anything, no hidden
success RNG, no complex physics carrying, no two-player carrying.

## 2. Fiction

Harlow & Finch went bust overnight. The bank hired **your liquidation crew to clear the building**
before the sale. Every bag of trash and every full dust canister counts toward the **clearance
contract**. Salvage you load onto the truck is auctioned and the crew earns a **finder's fee**: the
optional greed. **Mr. Harlow**, the last manager, never left. Nobody told him the company is gone; he
still works late, still does performance reviews, and treats you as intruders stealing COMPANY
ASSETS. Tone: horror-comedy, kid-safe.

The depot contract board and a one-card arrival screen carry this; no tutorial narration.

## 3. Player flow

1. **Depot (lobby place, public servers).** Company garage with 3–4 trucks. Each truck is a **queue
   pad holding 1–4 players**. Standing in the truck bed joins that party; leaving leaves it. With ≥1
   player a ~15 s countdown runs (reset on join); anyone aboard can press **Depart now**. The contract
   board shows tonight's job; a returning player sees their last shift's result card.
2. **Teleport** the party to a fresh **reserved shift server** (drive card on the loading screen).
3. **Shift server waits** up to ~20 s for the expected party, then starts with whoever arrived.
   Arrival card, then the loading bay.
4. **Shift (~7 min).** Vacuum piles → canister fills → pop dust bags → haul trash and salvage to the
   truck → **Load**. Harlow patrols; pressure tiers step up at 2:00 and 4:00.
5. **Quota met.** Stamp + horn → Harlow walks to the break room for ~30 s (regroup and bank) →
   "**Overtime in 0:30, salvage ×1.5**" warning → overtime at the top tier until the timer ends.
6. **Clock out** at the truck any time: anyone presses it, a 10 s countdown is announced to all;
   unbanked cargo is lost from this run only. Timer expiry also ends the shift with what is banked.
7. **Results:** Harlow's "performance review" (cleared, bonus, catches, salvage found, joke awards).
   Party vote: **Another shift** (reset in the same server) or **Back to depot** (teleport).

## 4. Mechanics (all numbers are tuning hypotheses, kept in Data constants)

### Vacuum
- Aim at a pile within ~8 studs and **hold** Use (mobile: hold the Vacuum button). Clears in ~2.5 s.
  The pile shrinks visibly; release cancels but **progress is kept**. Two vacuums on one pile add up.
- Can't vacuum while your hands hold an item.
- Each cleared pile adds 1 to your **canister** (capacity 3). Full → a **dust bag** (trash, 15) pops
  out at your feet and the canister empties.
- **Noise:** a pulse every 1 s while vacuuming, radius ~40 studs.
- Pile visuals: paper heap, debris and dust, cable tangle.
- **Variant switch** (A/B from the validation plan, rewards unchanged): **B (default)** some salvage
  spawns hidden under piles; **A** all salvage spawns exposed.

### Cargo and carrying
- **Hands:** one item of any kind. **Pockets:** 2 slots, tiny items only, shown on the HUD.
- Drop (G), throw (F, throwable items only), pocket (tiny items).
- **Dropping makes noise** scaled by weight. Dropping is the escape tool: empty-handed you outrun Harlow.

| Item | Kind | Value | Traits |
|---|---|---|---|
| Rubbish bag | trash | 10 | light, throwable |
| Dust bag (from canister) | trash | 15 | light, throwable |
| Recycling box | trash | 15 | light; **spills into a pile when dropped** |
| Bottle bag | trash | 15 | light, **rattly** |
| Office plant | salvage | 20 | medium; **leaves partly block your view** |
| Employee of the Month plaque | salvage | 25 | tiny |
| Monitor | salvage | 30 | medium, **fragile** |
| Water cooler jug | salvage | 30 | heavy; dropped = **very loud splash + slippery puddle** |
| Printer | salvage | 40 | heavy |
| Coffee machine | salvage | 50 | heavy, rattly |
| Fish tank | salvage | 70 | heavy, fragile, rattly |
| Golden stapler | salvage | 80 | tiny, hidden, rare |
| Filing cabinet on cart | salvage | 120 | **bulky** (pushed, ~half speed, no sprint) |

Traits: *weight* slows (heaviest stop sprint); *fragile* loses one value tier per drop or throw;
*rattly* emits a small noise pulse every ~2 s while carried; *bulky* is a heavy carried object held
far in front with decorative wheels, not networked physics; *hidden* spawns under a pile or in a
searchable desk/locker.

- **Search** desks and lockers: short hold, small noise, may yield a small or tiny item. Contents are
  rolled at shift start, not at search time.
- **Banking:** stand in the truck bed, **Load** your hands item (pockets unload with it). Trash adds to
  clearance, salvage adds to bonus (×1.5 during overtime). Banked is safe forever.
- **Quota** ~350 clearance. Spawn guarantees: total trash value ≥ 1.5× quota (counting canister
  output from the piles spawned), and at least one greed target (fish tank, cabinet or golden
  stapler), placed deep.

### Mr. Harlow (the occupant)
- States: **patrol** (authored route, random start and order) → **investigate** (walk to the last
  heard noise, look around ~4 s) → **chase** (sight ~60 studs, 100° cone, line of sight) → **search**
  (last-seen point, ~6 s) → patrol.
- Speeds: patrol 10, chase 15. Players walk 16; any carried item pushes you under 15.
- **Catch** at ~4 studs:
  1. camera snaps to his face ~0.6 s, nearby lights die, distorted sting, stretched-grin face;
  2. he throws you: **ragdoll launch** (base Death ragdoll + impulse); hands and pockets scatter
     where you land;
  3. you **spectate teammates** ~8 s;
  4. "Rehired." card, respawn at the loading bay.
- **Grace:** after a catch he ignores that player ~10 s and walks away. **The loading bay is a safe
  zone** he never paths into or chases into.
- **Tells:** lights within ~20 studs of him flicker; heartbeat when he is near but hasn't seen you;
  3D footsteps and muttering through walls; **"?"** over his head investigating; **"!"** + sting +
  chase music when he spots you; a sigh when he gives up.
- **Voice:** pitched, distorted gibberish (Stable Audio) plus a speech bubble with the line
  ("Those are COMPANY ASSETS.", "Per my last email…", "You're FIRED!"). No TTS.

### Pacing (one constants module)
- Shift 7:00. Pressure tiers at 2:00 and 4:00: hearing radius ×1.2 and patrol speed +1 per tier,
  announced by a flicker and a sticky note ("You hear Harlow pacing faster…").
- Party size: solo gets hearing ×0.75 and chase speed −1.
- Quota met → break 30 s → overtime warning 30 s → overtime at the top tier.
- No threat budget, no extra entities. Add only if the simple knobs fail to pace well.

## 5. Places and roles

One codebase, synced to two places in one experience (both owned by the developer's personal
account): **depot** and **shift**. A place-role table maps PlaceId → role. **In Studio** (unknown
PlaceId) both roles run in one server and the teleport becomes a local move, so the whole loop plays
through `rojo serve`. Depot geometry and office geometry are built at different world positions.

The developer creates the shift place in the experience before milestone M4; the role table's
PlaceIds are filled in then.

## 6. Architecture

### 6.1 Base changes (`base/game-hooks` → main, merged first)

Each is generic and needed by at least two of the three games (ROADMAP's rule).

| Base feature | Change | Also used by |
|---|---|---|
| **Npc** | Per-kind pluggable brain: `NpcServiceServer:setBrain(kind, fn)`, `fn(def, context, npc) -> Intent?` (nil = default brain). New intent `{ kind: "goTo", position, run: boolean }`. Per-NPC tuning overrides `setTuning(npc, {walkSpeed?, runSpeed?, sightRange?, sightAngle?})`. Optional `pathCosts` on the def, passed to PathfindingService so a game can mark zones NPCs avoid. | Wild Migration herds (goTo along authored waypoints, custom flee) |
| **Death** | Respawn at a chosen point: `configure({ spawnAt = (player) -> CFrame? })`, applied on CharacterAdded. Ragdoll with an initial impulse: `kill(humanoid, cause, { impulse: Vector3? })`. | Night Watch (thief returns to entry) |
| **Carry** | Signals `pickedUp(player, object)` and `dropped(player, object, reason)` with reason `"drop" \| "throw" \| "forced" \| "death" \| "leave"`. | Night Watch (relic), Wild Migration |
| **Interaction** | **Channels:** continuous hold with server-side progress. Server `channel(kind, {rate, maxDistance, canStart?, onComplete})`; client sends start/stop; server re-checks distance and state every tick and cancels on failure; progress replicates on the target (attribute). Several players may channel one target and rates add. | Night Watch (repair fault), Wild Migration (lasso hold) |
| **Toast** (new) | Server `ToastServiceServer:send(target: Player \| "all", {text, style, duration?})`; client HUD widget stacks toasts. Styles are data; Cleanup Crew registers "sticky note" and "stamp". | all three |
| **Queue** (new) | Queue pads (tag `QueuePad`, attributes capacity, countdown, destination role), party tracking, Depart-now, reserved-server teleport with retries (3, backoff) and fall-back to the pad, arrival handling (expected party + timeout), return trip, and the **place-role table** with the Studio local fallback. Signal `arrived(party, data)` fires the same way live and in Studio. | Night Watch (private 1v1) |

### 6.2 Game features (`game/cleanup-crew`, stacked on the base branch)

| Feature | Job |
|---|---|
| **Office** | Builds the office from authored room data; spawn markers; rolls and places piles, items, desk contents and Harlow's start each shift; atmosphere presets; tears the shift's instances down on reset |
| **Depot** | Builds the garage, places truck queue pads, the contract board, the returning player's result card |
| **Shift** | Configures Round; quota, pressure tiers, break and overtime, clock out, results payload, Another-shift vote, A/B variant, analytics events |
| **Vacuum** | Piles, the vacuum channel, canister, dust bag output, vacuum feedback |
| **Cargo** | Item catalog and traits, hands and pockets, fragile and spill rules, search, banking at the truck |
| **Noise** | Noise events from any source, who hears them, the client ripple ring |
| **Occupant** | Harlow: NPC kind and brain, investigate/chase/search, grace and safe zone, catch sequence, tells, voice bubbles, party-size tuning |

UI screens live in the UI tree (`Client/UI/React/Screens/…`), registered as HUD widgets and scenes:
Shift HUD (punch clock, clearance bar, bonus, canister, hands and pockets, mobile buttons), catch
overlay, results scene, depot pad and contract board, arrival and drive cards.

### 6.3 Data flow

- **State in charm-sync:** `shift` world entry (phase, `endsAt`, quota, cleared, bonus, tier,
  overtime and clock-out deadlines, variant); per-player public fields (pockets, canister fill,
  caught). Carry already publishes the hands item.
- **Events in ByteNet:** client→server vacuum start/stop (via Interaction channels), pocket, swap;
  server→client announcements (Toast), bank popup, catch sequence, Harlow cues. Inbound requests go
  through `RequestHandler.wrap`.
- **Interactions:** Load, Search, Clock out, vote buttons on the results scene.

### 6.4 Authority and integrity

- Vacuum progress accumulates on the server; the client only animates it.
- Banking: the item must be in your hands and you in the truck zone; claim → add value → destroy in
  one step, so two simultaneous Loads can't double-count.
- Catches are decided on the server tick; drops happen on the server.
- Teleport data carries only non-security info (expected user ids, contract id). The reserved
  server's private access code is what keeps strangers out.
- The client-reported platform (for analytics) is accepted only from a fixed enum.

### 6.5 Lifecycle, failure and reset

Round phases: lobby = waiting for party, starting = arrival card, running = shift (sub-states:
normal, break, overtime warning, overtime, clock-out countdown), results.

- **Player leaves mid-shift:** hands and pockets drop, channels release. Last player out → the server
  closes.
- **Stranger joins** (join-friend): during waiting they become crew if there's room, otherwise they
  are teleported to a depot server.
- **Teleport fails:** 3 retries with backoff, then the party is back on its pad with a toast.
- **Reset:** everything a shift spawns lives in one per-shift container plus one cleanup object;
  reset destroys both and clears timers, claims, channels and UI. Used by Another shift and by
  Studio test runs.
- **Persistence:** none (session-local). The depot result card comes through the return teleport.

### 6.6 Analytics

Through `AnalyticsServiceServer:custom`. Events (from the brief): `contract_started`,
`first_cleanup_started`, `pile_cleared`, `cargo_picked_up`, `cargo_dropped`, `cargo_banked`,
`noise_investigation`, `chase_started`, `player_caught`, `quota_met`, `optional_salvage_attempted`,
`shift_ended`, `replay_started`. Fields: session (server JobId), build version, variant, platform,
party size, target/object, outcome, failure reason. No personal data, no chat.

## 7. Feedback and presentation

**Identity: "corporate after hours."** UI as office paperwork: manila folders, punch cards,
sticky-note toasts, rubber-stamp announcements, typewriter type. The office at night: dim,
buzzing fluorescents (some flickering), emergency-exit glow, monitors glowing blue. Ambient dread:
phones ringing in empty rooms, an elevator dinging on its own, typing that stops when you enter.

| Moment | Feedback |
|---|---|
| Vacuuming | suction particles into the nozzle, pile shrinks, rising whine, pop + sparkle, canister fills |
| Canister full | chime, dust bag pops out |
| Any noise | faint ripple ring on the floor at the radius Harlow hears it |
| Banking | item swoops into the truck, cha-ching, "+15" floater, clearance bar fills |
| Quota met | "QUOTA MET" stamp, truck horn |
| Tier up | lights flicker, sticky note |
| Overtime | lighting shifts dim red, ticking music layer |
| Clock out | horn honks, large countdown |
| Caught | §4 catch sequence |

Harlow's body: a tall, too-thin suited R15 rig built from a HumanoidDescription in code, so no
place art is needed.

### Asset pipeline (free and local only, uploads owned by the personal account)

| Need | Tool |
|---|---|
| SFX, music, Harlow's gibberish | Creator Store first, else **Stable Audio 3** (local ComfyUI), via the `sourcing-roblox-sfx` skill |
| UI art, icons, signage | **Flux 2 Klein / Qwen Image** (local) |
| Harlow's lurch walk, look-around, grab and throw | **Kimodo / MoMask** text-to-motion → R15, via `generating-animations-with-ai` |
| Readability checks | **Qwen3-VL** on screenshots |
| Uploads | `publishing-roblox-assets`, owner = personal account |
| Later art pass only | TRELLIS 2 / Pixal3D image-to-3D |

Asset id literals live only in each feature's `Data/<Feature>Assets`.

### UI approval

1. A reference board from Game UI Database and Interface In Game (browsed in the built-in browser),
   pinned in Figma.
2. Figma mockups of each screen (HUD, contract board, queue pad, catch overlay, performance review)
   with the generated art. **The developer approves in Figma.**
3. Only approved screens are built in React, each with a UI Labs story for side-by-side checking.

## 8. Testing and verification

- **Spec-first.** Pure rules get specs before code: vacuum progress and stacking; canister and dust
  bag; hands and pocket limits; fragile tiers and spill; bank claim (no double count); shift phase
  transitions (quota → break → warning → overtime, clock out, timer); pressure tiers and party-size
  scaling; Harlow's brain decisions incl. grace and safe zone; noise radius per action; spawn roll
  guarantees; office layout validation (rooms connected, markers inside rooms); queue pad and party
  rules; place-role resolution.
- Instance-heavy systems get harness specs where practical, otherwise `EXEMPT_MODULES` entries with
  reasons, as the base does.
- **Gate per commit:** `bash scripts/check.sh` green. **While the developer is connected to
  `rojo serve`, use `--skip-install`** (a full run's `wally install` disrupts the live sync); run the
  full gate when they are not connected, and say so first.
- **Playtests:** build + serve; the developer connects; check through Studio output, screenshots and
  Qwen3-VL readability passes; Studio local server with 3 clients before publishing.

## 9. Milestones

| # | Branch | Playable result |
|---|---|---|
| M0 | `base/game-hooks` → main | The six base changes in §6.1, each specced; PR + merge |
| M1 | `game/cleanup-crew` | Studio graybox loop: office, random spawns, vacuum + canister, hands + pockets, banking, quota, clock out, plain results. No Harlow |
| M2 | same | Harlow: patrol, noise, investigate, chase, catch (scare, ragdoll, spectate, rehire), tiers, quota → break → overtime |
| M3 | same | Feel: reference board → Figma → **approval** → UI built; SFX, music, gibberish; Flux art; atmosphere; Kimodo animations |
| M4 | same | Depot + queues + reserved servers + return; developer creates the shift place; publish walkthrough |
| M5 | same | Phone pass on a real device, analytics, A/B switch, publish, **sibling session** |

## 10. Out of scope

Other entities or a threat budget; lights-out or breaker mechanics; persistent progression,
currencies, shops, cosmetics; procedural geometry; two-player carrying or networked cart physics;
TTS voices or any paid service; ranked or public matchmaking beyond queue pads; console support.

## 11. Open items for the plan (not design questions)

- Exact module names and placements: the implementation plan carries the **New modules** table
  (`module-placement` skill). Proposed feature names: Office, Depot, Shift, Vacuum, Cargo, Noise,
  Occupant (game); Toast, Queue (base). Each new feature name is a decision the plan states.
- Shift place PlaceId for the role table (M4, from the developer).
