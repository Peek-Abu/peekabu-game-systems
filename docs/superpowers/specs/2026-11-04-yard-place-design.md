# The yard as its own place (design)

Status: **proposal, waiting for the owner's picks** (2026-11-04). Nothing is built or generated.
Concepts: `design/production-art/yard-dressing/yard_scene.jpg` (the yard dressed, mood only) and `yard_props.jpg`
(the prop list drawn). Builds on `2026-11-04-sound-places.md` (the Building / Outside cut, commit 0d278e4d).

Backlog item: "Make the outside its own place, not a quiet backdrop": its own ambience bed, outdoor footstep surfaces,
more set dressing, and the open question of outdoor creatures.

## Today

- **The yard:** the Shift place's `Workspace.OfficeExterior`, built by
  `design/production-art/map-kits/odd-hours-b1/exterior/BuildExterior.CommandBar.luau`. It has:
  - open asphalt, a 200-stud walk from the truck pad to the dock door (12.5 s);
  - 12 sodium poles and puddle discs;
  - a security booth and barrier, a fence and a pine treeline;
  - blockout cars, a dumpster and crates by the dock;
  - the lobby plaza and the car park to the west.
  Budget used: about 3,350 of 4,500 parts and 63 of 70 lights. The captures (`exterior/captures/t9_*`) show it: wide,
  dark and mostly empty.
  This inventory comes from the builder and the 2026-10-24 captures. Before building, read the live place once
  (Studio, via the coordinator) for anything builders added since.
- **Sound outside:**
  - The office bed (four looped 2D beds, `OfficeAssets.BED`) is hushed outside.
  - Since 0d278e4d, every positional sound plays in its place's group (`SFX/Outside`, `Ambient/Outside`), and only the
    listener's place is heard.
  - 2D sounds are not placed. So the yard has no bed at all, only the truck, the steps and the odd zap.
- **Footsteps:** one sound per character, not per material (the owner's call, round 3). `FootstepConstants` maps
  Asphalt and Pavement to `concrete`, and LeafyGrass, Grass and Ground to nothing, but every set fills only its
  `default` pool. So the yard sounds exactly like the office carpet.
- **Outside is the safe zone** (office map spec non-goals: no outdoor enemies, puzzles or loot; Harlow never paths
  there).

## 1. The yard bed (sound)

Built the `game-sound-design` way: an in-house layered bed (`make_bed.py`), co-prime loop lengths, gated against the
office bed the owner picked (r2 A) and the APM drone benchmarks. The identity line: the yard is the **quiet, slightly
lonely** half of the night. Cozy-spooky, never a slasher's parking lot.

| Layer | What | Job |
|---|---|---|
| A · lamp hum | sodium ballast buzz on B (120 Hz mains = B2, the office's tonic, so walking in and out stays in one key), 3 detuned voices drifting | the tonal floor |
| B · far traffic | a low wash of a road far away, slow swells every 20-40 s, a different timbre at F# | movement, distance |
| C · wind | soft wind through the pines, band-passed, with slow gusts | air |
| D · insects | a cricket bed, sparse, thinning on gusts | night, outdoors |

**Sweeteners** (positional, so they fall into `SFX/Outside` by the place rule; every 6-15 s, never the same variant
twice in a row):
- a soft owl hoot;
- a chain-link fence rattle;
- a can rolling on asphalt;
- a far car passing;
- a moth ticking on a lamp;
- a shopping trolley creak.

None of these is a voice or a bark, and none sparkles.

**Fixed emitters** (3D loops with short roll-off; positional, so they are placed Outside automatically):
- each sodium pole: a quiet buzz near the lamp;
- the vending machine: a hum;
- the booth: a tiny radio playing the hub's lounge record, faint and a little warped ("a record left playing after
  closing", the game's own identity line);
- the `carTicking` anomaly car already ticks.

**Wiring (the one design decision here):** a 2D bed is not placed today, so pin it. `SoundDef` gains an optional
`place: SoundPlace`. A 2D sound with `place = "Outside"` plays in `Ambient/Outside`, and one with `place = "Building"`
plays in `Ambient/Building`. The yard bed's four layers are pinned Outside, and the office bed's four are pinned
Building. The existing place switch then crossfades the two beds at every door (instant behind the teleport fade, 0.3 s
otherwise), with no new timing code. The hub has no boxes, so the hub's record is untouched.

Changes, not new modules:
- `SoundTypes` (`SoundDef.place`);
- `SoundRegistry` (validates it, specced);
- `SoundServiceClient` (puts a pinned 2D sound in that place's group);
- `OfficeAssets` (the yard bed, sweeteners and emitters);
- `OfficeAtmosphereSystem` and `OfficeAmbienceSystem` (start the yard bed with the office one; scatter its sweeteners
  round the listener while Outside).

## 2. Outdoor footsteps (surface layer)

The owner's indoor rule stays: one sound per character. Outside adds a **surface layer** under that sound. It is
shared by every character and plays on the same foot-fall at the same gait scale, so Pippa still sounds like Pippa,
now on gravel.

| Surface | From | Layer |
|---|---|---|
| `asphalt` | Asphalt, Pavement (outside only) | a light grit scuff |
| `grass` | Grass, LeafyGrass, Ground | a soft swish |
| `gravel` | Pebble, or the `FootstepSurface = "gravel"` attribute | a crunch |
| `puddle` | the `FootstepSurface = "puddle"` attribute on the yard's Puddle discs (the builder sets it) | a cartoony "plap" splash, the loudest |

- **Assets:** 6 walk variants per surface. Sprint and crouch reuse them through the gait scales, as the employee sets
  do. In-house, layered (transient + body + a little tail), gated with the named-source gate so you hear the surface,
  then one listening page.
- **Indoors:** carpet, tile, wood and concrete get no layer, so nothing changes inside.
- **Code (later):**
  - `FootstepTypes` gains the four surfaces and a `LayerPools` type;
  - `FootstepAssets` gains `LAYERS`;
  - `FootstepConstants` gains the material map for them;
  - `FootstepEmitterSystem` plays the layer next to the step;
  - `FootstepSurfaceUtils` (specced) decides the surface.
  No new modules.

## 3. Set dressing (the yard and car park)

Mood: `yard_scene.jpg`. The aim is to give the 12.5-second walk things to look at, and to make the yard read as
a real place at night. The walk line, the truck pad, both entrances, the arrival spots and the pathing must stay
clear.

| Area | Props (count) | Notes |
|---|---|---|
| Dock apron | dumpster with lid ajar (1), wheelie bins (3), pallets stacked (2 stacks), plastic crates (4), yellow bollards (2, exist), vending machine (1, a light) | The goo already seeps under the dock door. The machine is the dock's warm landmark. |
| The walk | puddles (exist; + `FootstepSurface`), traffic cones (4), an A-frame barrier (1), a lone shopping trolley (1), moths at 3 poles (particles, no part cost) | Keep the wet-floor anomaly's puddle as it is. |
| Grass verges | strips along the walk with dandelion tufts and 3 crooked bushes | They give the grass footstep layer somewhere to play. |
| Car park (west) | the blockout cars → 5 boxy toy-like cars (one with hazards blinking; the `carTicking` car stays), wheel stops, a painted crossing | Cars are hand-built hard-surface props. |
| Gate | booth upgrade: a lit window, a little desk and the radio emitter; the barrier exists | The booth TV is an anomaly slot: leave its parts named. |
| Plaza | a picnic bench (1) with a plain litter bin (1), planters (2) | The concept drew a smoking bin; it is dropped (not for kids). |

- **Budget:** about 1,100 parts and 7 lights of headroom. The vending machine and the booth window take 2 lights; the
  hazards are Neon blinking, not lights.
- **How props are made:** `texture-pipeline`:
  - hard props hand-built (`hardlib.py`): dumpster, bins, pallets, crates, cones, barrier, trolley, vending machine,
    bench, cars;
  - bushes and grass tufts as TRELLIS + `rebake.py`, or simple stylized primitives;
  - textures through the style filter (calm surfaces, detail in the normal map).
- **Keep clear: the bigger truck.** The owner approved truck size B, "Moving Van", on 2026-11-04. It is not in the
  places yet; see `2026-11-04-truck-size-design.md`. In the office layout space the truck is centred at
  `OUTSIDE.TRUCK_CENTRE` (168, -276), turned yaw pi: the cab faces -Z and the ramp faces +Z, toward the dock.
  - Body: x 158.7 to 177.3 (19 wide), z -296.2 (cab bumper) to -259.8 (ramp foot), top about 14.8 studs up.
  - No props in x 155.7 to 180.3, z -299.2 to -256.8 (the body plus a 3-stud walk margin). Keep the ramp approach
    clear from z -256.8 toward the dock.
  - Keep a 3-stud circle clear round the time clock post, at about (154, -266).
- **Both places:** this is Shift-place art only. The lobby place has no yard.
- **Who builds it:** a Studio art session (or a hired builder, per the team handoff workflow), tag-driven where code
  needs it (puddles' attribute, emitter parts tagged for the bed system).

## 4. Outdoor creatures: gameplay or dressing?

The owner decides. The outside is a safe zone by design: the walk is the breather between the scary inside and the
truck.

- **Dressing only** (recommended): harmless critters that make the yard feel alive and a bit spooky, never a threat.
  For example:
  - a black cat on the dumpster that hops down when you come near;
  - crows on the fence that flap off;
  - a raccoon peeking from a bin;
  - fireflies in the grass verges.
  All are cheap, all are kid-safe, and none is a Gloom creature (Gloom never gets a face).
- **Gameplay:** for example a Gloom blob that steals a carried item on the walk back. This reverses the safe-zone
  decision, adds an outdoor threat to the loaded trip (the tense part already), and needs AI, catch rules and tuning
  three weeks before launch.

## Owner picks

- 2026-11-04: **yes** to the yard bed (1), the footstep surface layer (4), the puddle splash (5), the booth radio
  (6), and creatures as harmless dressing only (7).
- 2026-11-04: **yes** to the set dressing as listed (2, 3): bins and a dumpster by the dock, pallets, cones, a
  trolley, real parked cars, grass strips, a vending machine, moths. The walk and the truck pad stay clear.

## Build plan

**Order:** Y1 and Y2 can run side by side (different files). Y3 comes before Y4, and before Y1's fixed emitters,
which sit on Y3's props.

| Step | What | Who |
|---|---|---|
| Y1a | **The yard bed and sweeteners.** `make_bed.py` stems (lamp hum, far traffic, wind, crickets), the sweetener variants, the fixed loops (lamp buzz, vending hum), and the booth radio (a warped stem of the hub song). Gated, then one listening page. Owner picks. Upload to Icey Labs. | sound session (Claude, local tools) |
| Y1b | **Code, spec first.** `SoundTypes` gains `SoundDef.place`. `SoundRegistry` validates it. `SoundServiceClient` puts a pinned 2D sound in that place's group. `OfficeAssets` gains the yard bed (pinned Outside), the sweeteners, and new `AmbientKind`s (`lampBuzz`, `vendingHum`, `boothRadio`). The office bed is pinned Building. `OfficeAtmosphereSystem` starts both beds in a shift. `OfficeAmbienceSystem` scatters the yard sweeteners round an Outside listener. | code session |
| Y2a | **Footstep layers.** 6 variants each for asphalt, grass, gravel and puddle. Gated with the named-source gate, one listening page, upload. | sound session |
| Y2b | **Code, spec first.** `FootstepTypes` gains the 4 surfaces and `LayerPools`. `FootstepConstants` gains the material map (Grass, LeafyGrass, Ground → grass; Pebble → gravel; Asphalt and Pavement → asphalt only outside, by the `FootstepSurface` attribute or the place). `FootstepSurfaceUtils` decides the surface. `FootstepAssets` gains `LAYERS`. `FootstepEmitterSystem` plays the layer with the step. | code session |
| Y3a | **Props.** Hand-built hard props (`hardlib.py`): dumpster, wheelie bins, pallets, crates, cones, A-frame barrier, trolley, vending machine, picnic bench, plain litter bin, 5 toy-like cars. Bushes and grass tufts. Through the texture style filter. Owner checks the turntables. Upload. | art session (Claude, Blender) |
| Y3b | **Placement.** In the Shift place, in a new top-level `Workspace.YardDressing` folder, so a rebuild of `OfficeExterior` never deletes it. Puddles get `FootstepSurface = "puddle"` (in the builder script too). The vending machine, booth radio and walk poles get invisible `OfficeAmbient` emitters with their `AmbientKind`. Within budget: about 1,100 parts and 7 lights. The walk line, the truck pad, the arrivals and the pathing stay clear. | Studio builder (hired) or a Studio session (Claude via Studio MCP), coordinator first |
| Y4 | **Critters (dressing only).** Moths and fireflies as particles on the poles and verges. A cat on the dumpster, crows on the fence and a raccoon in a bin, each hopping or flying off when a player comes near, on this client only. | art session (models), code session |
| Y5 | **Check in real play.** Walk truck → dock → lobby → truck with a second client: the bed crossfades at each door, the steps change on grass, gravel and puddles, and nothing blocks the walk. | owner |

**New modules (Y4 only):**

| Feature | Realm | Subfolder | Name | Job |
|---|---|---|---|---|
| Office | client | Systems | `OfficeCritterSystem` | Plays the yard critters' idle and flee on this client when a player comes near (tag-driven). |
| Office | client | Data | `OfficeCritterConstants` | The critter tag, the flee distance, and each critter's idle and flee clips. |

Y1 and Y2 change existing modules only. No new subfolder kind, role word or service.

## Questions for the owner

**Look**
1. The yard bed: lamp hum + far traffic + wind + crickets, cozy-spooky (quiet and a bit lonely, not scary)?
2. The set dressing in `yard_scene.jpg` (bins, pallets, cones, trolley, cars, vending machine, grass verges, moths)?
   (No smoking bin.)

**Layout**

3. Dress the dock apron, the walk's edges and the car park, and keep the walk itself and the truck pad clear?

**Rules**

4. Footsteps outside: keep each character's own step and add a shared surface layer (asphalt, grass, gravel,
   puddle) on top?
5. Puddles get the loudest, splashiest step (a cartoony "plap")?
6. A faint radio in the gate booth playing the warped hub song?
7. Outdoor creatures as harmless dressing only (cat, crows, raccoon, fireflies), with the outside staying a safe
   zone? (No: say what kind of gameplay creature you want.)
