# Crew truck remake: a truck that can grow (design)

Status: **proposal, waiting for the owner's picks** (2026-11-04). Nothing is built, uploaded or committed.
Concepts: `design/production-art/truck-remake/` (`truck_A/B/C.jpg`, `truck_skins.jpg`, `truck_parts.jpg`,
`truck_slot_map.jpg`; the prompts are in `prompts/`).

The owner, 2026-11-04: "I thought we were deciding to remake the trucks?! (so it can have potential upgrades in the
future for internal things, skins, etc!)"

## Was a remake ever decided?

No. Nothing on the launch board's `decisions` or `scope` collections mentions a truck remake. The idea showed up four
times, but nobody ever picked it:

| Where | What it says |
|---|---|
| `design/production-art/truck-b/` (2026-10-12) | A flatbed "truck B" study (teal cab, open bed). Never picked or uploaded. |
| `docs/superpowers/specs/2026-10-22-odd-hours-office-map-design.md` (non-goals) | "The truck redesign. It is being regenerated separately." No follow-up session or doc exists. |
| `characters/launch/crew-hosting/DESIGN.md` batch 6 | Truck skins and accessories (Cosmetic kinds `truck` / `truckPart`, slots roof / front / side). Deferred. It "needs truck skin art (a separate art job)". |
| `docs/superpowers/launch-backlog.md` | "Arrival as an event": the truck drives in. Parked for later updates. |

So this doc is the first real decision point.

## Where the truck lives today

- **It is not Studio art in Workspace.** There is one template, `ReplicatedStorage.Assets.CleanupCrew.Truck`: a Model
  with `RuntimeApproved = true`, 28 MeshParts, model asset 76610482634098 (Icey Labs). It comes from
  `characters/truck/build_truck.py`, a hand-built Blender truck ("design A": Morrow & Morrow teal cab-over, ivory box,
  roll-up back door, ribbed ramp, scanner arch). The MeshParts were coloured in Studio from `Truck.json`.
- **`DepotTruckVisualSystem` (server, Depot) clones it round every truck bed:** the 3 queue trucks in the hub depot
  and the office's yard truck (on the yard pad at `OUTSIDE.TRUCK_CENTRE`). The bed part is the authority (queue pad,
  banking bed, load prompt). Around the bed, the system builds:
  - invisible native **collision**: walls, roof, arch posts, cab, and the ramp wedge;
  - an opaque **camera shell** inside the art's walls;
  - the **time clock**;
  - the **livery**, a SurfaceGui image on BoxShell's left and right faces;
  - the **scanner arch light**.
  All of it is in deck space (`DepotTruckVisualConstants`). Without the template, a graybox of the same layout is used.
- **Ghost / parked:** crew hosting batch 4 tags the art (`DepotConstants.TRUCK_ART_TAG`) and marks the shell cores.
  The client's `DepotTruckGhostSystem` then draws an empty, held bay as a ghost outline, and the full truck appears
  when a host steps in. Batch 6 was to park it in the host's skin.
- **The hub depot bays and the office arrival are place art only around the truck** (the pad, the bay markings). The
  truck itself always comes from the template, so one new template changes every truck in both places.

## The proposal: one modular truck

Keep everything the game relies on and replace only the art. Split the art into named parts so that skins, parts
and interior upgrades are data, not new models.

### 1. Same footprint, same collision (the contract)

The new truck is built to today's deck-space outline (`characters/truck/README.md`):

- The bed (12 x 3 x 16) is the floor.
- The box walls sit outside x = ±6.
- The doorway is 12 wide and about 6.1 tall.
- The ramp runs from z -8 down to the ground at z -12.
- The cab sits inside today's cab collision box.

`DepotTruckVisualConstants.COLLISION` and `SHELL` stay as they are, so queue pads, banking, the load prompt, the
camera and Harlow's pathing don't change. Only the shell cores may need new sizes, if the new walls are thicker. The
three looks below all fit this outline: they differ in panel shape, trim and corners, never in the box's size.

### 2. Paint slots (skins)

Every mesh piece belongs to one paint slot. A skin is a palette (one colour and material per slot) plus optional
box-side art. That mirrors employee skins, which have N colour **styles**.

| Slot | Pieces | Default (look A) |
|---|---|---|
| `cab` | cab body, visor, mirror arms | teal `#1F6E66` |
| `box` | box shell, roof, roll drum housing | cream `#FFF7E8` |
| `band` | the box-side band (its own mesh strip, so a skin can recolour it) | grape `#7B3FF2` |
| `trim` | bumper, fenders, arch frame, corner caps, ramp rails | warm grey |
| `metal` | hubs, handles, horn base | gold `#FFC93A` |
| `fixed` | tyres, glass, lamps, tail lights, scanner light (never skinned) | |

- **How a skin is drawn:** MeshPart `Color` and `Material` per slot, the way today's template is coloured. Patterns
  (pumpkin vines, stars) are box-side art, drawn on the same SurfaceGui faces the livery uses today, so a pattern
  skin is one image, not a new mesh.
- **Upload cost:** a palette-only skin uploads nothing. A pattern skin uploads one image.

### 3. Sockets (accessories)

Attachments on the template, named `Socket_<Slot>`, each in deck space. One `truckPart` fills one socket. A part is
an inert Model (no collision, query or touch) pivoted at its socket.

| Socket | Holds | Examples (`truck_parts.jpg`) |
|---|---|---|
| `Socket_Roof` | the cab roof item | light bar, beacon, rubber duck, hose rack, ghost sign (no face) |
| `Socket_Front` | the bumper item | bull bar (mop head), trumpet horns |
| `Socket_SideL` / `Socket_SideR` | a decal over the band | star flap, sticker decals |
| `Socket_Mirror` | something hanging | fuzzy dice, bunny-ear antenna |
| `horn` (sound, no mesh) | the horn sound when the truck leaves | classic honk, clown horn, duck squeak |

The `horn` slot is a sound only. It plays where the clock-out horn plays today and follows the sound place rule: it is
heard Outside. One part per socket, swappable in the Locker.

### 4. Interior slots (future upgrades)

The box interior **is** the bed: players stand there, bank there and queue there. Interior items must never take
floor space or block anything. The rule: an interior item is inert, hugs a wall within 1.2 studs, and sits between
0.5 and 7.5 studs above the deck. Named attachments:

| Slot | Where | Future items |
|---|---|---|
| `Interior_Ceiling` | the roof's underside | lamp style (warm, disco, lava lamp glow) |
| `Interior_WallL` / `Interior_WallR` | upper half of each side wall | shelves with trophies, posters, a crew photo board |
| `Interior_Bench` | fold-up benches along both walls, seat at 2.2 studs | seats (cosmetic, players can't sit at launch) |
| `Interior_Front` | the front wall beside the time clock | a radio, a fish tank, a plant |

These are slots only at launch. Each future upgrade is one more `truckPart` with its slot set to an interior name.

### 5. The three looks (pick one as the base)

All three keep the cab-over-plus-box shape and today's footprint.

| Look | File | Idea | Notes |
|---|---|---|---|
| **A · Night Shift** (recommended) | `truck_A.jpg` | Today's teal and cream truck, made chunkier and toy-like: grape band with a gold pinstripe, mint roof light bar, gold hubs. | Closest to the art players already know; the skins read cleanly on it (`truck_skins.jpg` is built on A). The box sides are flat, so patterns and decals sit well. |
| **B · Gloom Hauler** | `truck_B.jpg` | All violet, with a round glass goo tank on each side, a vacuum hose on the roof rack, and mint light strips. | The most "this is the cleaning game". But it spends the box side on the tank (there is little room for skins), and it is very dark against the night yard. The hose rack could ship as a roof part on A instead. |
| **C · Toy Box** | `truck_C.jpg` | Pillowy corners, a lilac cab, a coral and sky colour-block box, and a gold beacon. | Cutest. The round cab and the headlight-and-grille front read a little like a face, and it is the furthest from the spooky half of spooky-cartoony. |

- **Skins test (`truck_skins.jpg`):** the same truck as Default, Pumpkin Patch and Starry Night. It shows that a skin
  changes only paint and box art.
- **Parts sheet (`truck_parts.jpg`):** ten example accessories for the sockets.

## How it plugs into Cosmetic and the Locker (later, after picks)

This is crew hosting batch 6, re-scoped to the modular truck. It edits the Cosmetic feature and the `loadout` slice,
so it waits until no other session is writing those files (a skin session has Cosmetic open today).

- **Cosmetic kinds:** `truck` (a skin, with `styles`, account-wide like `vacuum`: one truck per account, not per
  employee) and `truckPart` (with a `slot`: `roof`, `front`, `sideL`, `sideR`, `mirror`, `horn`, `interiorCeiling`,
  ...). `Change` gains `{ kind = "truck", id, style }` and `{ kind = "truckPart", slot, id }` (an id of "" clears
  the slot). The loadout gains `truck`, `truckStyle` and `truckParts`. A migration gives everyone the default truck.
- **Who you see:** in the hub, the truck wears its host's loadout (crew hosting already knows the host). The office
  yard truck should wear the shift host's loadout too. The host would ride in the depart payload; check that the
  payload carries them before relying on it.
- **Locker:** a Trucks page in the one Inventory (the owner's rule: one inventory, not separate tabs per kind). It shows
  the truck turning on a stand, with the socket list beside it. Rarity cards and stripes as for skins.
- **Shop and Lockers:** truck skins and parts join the rotation like vacuums. Prices and rarity come in a separate
  pass, not this doc.

### New modules (placement, per `docs/project-structure.md`)

| Feature | Realm | Subfolder | Name | Job |
|---|---|---|---|---|
| Cosmetic | shared | Data | `CosmeticTruckRegistry` | Truck skins' palettes per style and slot, and each truck part's socket and asset (looked up by id). |
| Depot | server | Utils | `DepotTruckDressUtils` | Pure: from a truck id, style and parts, the plan of colours per paint slot and parts per socket. Specced. |

Changed, not new:
- `DepotTruckVisualSystem` gains `park(bed, dress)`, which applies the plan;
- `DepotTruckVisualConstants` gains the socket and interior attachment names;
- `CosmeticTypes`, `CosmeticRules`, `CosmeticRegistry` and the Loadout types change as listed above.

No new subfolder kind, role word or service.

## Art needed

- **The base truck, hand-built in Blender** (the hard-surface prop kit, `texture-pipeline`: `hardlib.py` +
  `build_set.py`, the same route as `build_truck.py`). It is not an AI mesh: AI meshes are at their worst on
  straight-edged props, and the AI route already failed for character outfits.
  - One mesh per paint slot piece, about 30 MeshParts, under 20k triangles each.
  - Attachments for every socket and interior slot.
  - Colour, normal and roughness baked for `fixed` pieces only. The skinned pieces stay plain material, so `Color`
    can tint them.
- **Launch set (if picked for launch):** the base truck in the default skin, plus a new kid-level livery to replace
  "A clean site is a compliant site". That line is corporate wording.
- **After launch:** 2-3 skins (one is box-side art), the roof and front parts (each a small hand-built prop), and the
  horn sounds (in-house, `game-sound-design`).
- **Uploads:** to Icey Labs (189923277) only, one approval per batch. The old template stays in the place until the new
  one is checked in play, so a rollback is one rename.

## Done means (when built)

- Every truck shows the new art: the 3 hub bays and the yard truck.
- Queue, banking, the load prompt and the camera work exactly as before.
- The ghost bay and the pop-in still work.
- A skin and a part equipped in the Locker show on the host's truck to a second client.
- Checked in real play, both places.

## Owner picks

- 2026-11-04: **look A (Night Shift)** is the base truck.
- 2026-11-04: questions 2-8 take the recommendations as the defaults:
  - B's hose rack and goo tank become truck parts, not a look;
  - a kid-level line replaces "A clean site is a compliant site";
  - sockets: roof, front, two sides, mirror, horn;
  - interior slots on the walls and ceiling only;
  - one truck per account;
  - the crew sees the host's truck in the hub and at the office;
  - **for launch, the new base truck and its default skin only**; skins and parts come after launch (batch 6).

## Build plan

**Launch: the new base truck. No new modules.**

| Step | What | Who |
|---|---|---|
| T1 | **Build the truck in Blender:** `characters/truck/build_truck_v2.py` with the hard-surface kit (`hardlib.py`), to today's deck-space outline. Pieces are split by paint slot. Every socket and interior slot is an empty with its name, written to `Truck_v2.json`. Renders: front 3/4, back 3/4 with the door open, and Pippa on the ramp. | art session (Claude, Blender, headless) |
| T2 | **Owner checks the renders.** Then a new livery image with the kid-level line. | owner, then the art session |
| T3 | **Upload** the FBX and the livery to Icey Labs (189923277), on the owner's OK for the batch. | art session |
| T4 | **Into the places.** Both places: import as `ReplicatedStorage.Assets.CleanupCrew.Truck`, coloured per slot from the JSON, with the attachments added. Rename the old template `Truck_v1` (the rollback: rename it back). | Studio session (Claude via Studio MCP; the coordinator frees Studio). Assets are copied into both places. |
| T5 | **Code.** In `DepotTruckVisualConstants`, resize the `SHELL` cores to the new wall thickness if it changed, and name the socket and interior attachments (unused until batch 6). Check that `DepotTruckGhostSystem` still finds the shell cores and the art tag. Spec first. | code session |
| T6 | **Check in real play.** 3 hub bays: ghost, pop-in, queue, depart. The yard truck: banking, the load prompt, the camera inside the box, the clock. A second client. | Studio session, then the owner |

**After launch: batch 6, skins and parts.** It starts once no other session is writing Cosmetic or the loadout slice.

| Feature | Realm | Subfolder | Name | Job |
|---|---|---|---|---|
| Cosmetic | shared | Data | `CosmeticTruckRegistry` | Truck skins' palettes per style and slot, and each part's socket and asset. |
| Depot | server | Utils | `DepotTruckDressUtils` | Pure: from a truck id, style and parts, the colours per slot and the part per socket. |

Changed:
- `CosmeticTypes` / `CosmeticRules` / `CosmeticRegistry`: the kinds `truck` and `truckPart`, and the `Change` variants;
- the Loadout types and a `PlayerDataMigrationSystem` step (the default truck);
- `DepotTruckVisualSystem.park(bed, dress)`;
- the depart payload carries the host (check it first);
- the UI tree: a Trucks page in the Inventory, placed by the UI tree's rules when that plan is written.

The art (2-3 skins, roof and front parts, the horn sounds) is made by the art and sound sessions.

## Questions for the owner

**Look**
1. Use look **A (Night Shift)** as the new base truck? (No: say B or C.)
2. Ship B's goo tank and hose as truck parts (a roof hose rack, a side tank decal) instead of a whole look?
3. Replace the side writing "A clean site is a compliant site" with a kid-level line (for example "We clean up the
   night!")?

**Layout**

4. Sockets: roof, front, two sides, mirror, plus a horn sound slot. Is that the right set?
5. Interior slots on the walls and ceiling only, with the floor always clear for the crew?

**Rules**

6. One truck per account (like the vacuum), not one per employee?
7. Your crew sees the host's truck: in the hub and at the office?
8. For launch, only the new base truck and its default skin, with skins and parts after launch (batch 6)? (No: skins
   at launch too, which needs the art and the Cosmetic work in the next three weeks.)
