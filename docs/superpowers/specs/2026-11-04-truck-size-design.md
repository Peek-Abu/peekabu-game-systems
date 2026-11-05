# Crew truck: a bigger box (size proposal)

Status: **proposal, waiting for the owner's pick** (2026-11-04). Nothing is built, uploaded or changed in the places.

The owner, 2026-11-04: "can we make truck a bit bigger naturally?? I want the inside to be like lethal company size -
maybe bigger!"

Renders (in the main checkout, not committed), in `characters/truck/v2/size/`:

- `size_options_sheet.jpg`: today, A and B. Each has a back view, a view inside from the door, and the front.
- `size_tops_same_scale.jpg`: top-down views at the same scale, roof off.
- `size_floor_plan.png`: the three floors overlaid, with six crew footprints and the three ceiling heights.
- `size_<now|A|B>_<back|front|inside|top>.png`: the full-size renders.

Built by `characters/truck/render_size_options.py` from the approved v2 truck. Pippa, Cappy and Prickles stand inside
at game scale (1.25).

## 1. Today's inside, measured

| | Studs | In crew heights (about 5.5) |
|---|---|---|
| Floor width (lining to lining) | 11.9 | 2.2 |
| Floor length (door to front wall) | 15.9 | 2.9 |
| Ceiling (deck to lining) | 6.9 | 1.26 |
| Doorway | 12 wide, 6.1 tall under the roll drum | |
| Ramp | 7 wide, 4 long, 3 high (37°) | |

The crew at game scale (Blender, bounding boxes × 1.25):

| Employee | Height (studs) |
|---|---|
| Cappy | 4.7 |
| Prickles | 5.6 |
| Pippa | 6.7, with her ears |

**The tightest dimension is the height, not the floor.** Pippa's ears come within 0.2 studs of the ceiling, and she
doesn't fit through the doorway (6.1) without her ears clipping. Four crew fit on today's floor, but only in a tight
2 x 2 grid with no room to walk round or drop loot.

## 2. What "Lethal Company size" means here (assumptions)

I can't measure Lethal Company's ship, so I'm using a rough recollection, not a measured number: the inside is about 4
crew lengths long and 2.5 across, with a ceiling about 1.5 crew heights. The owner's test is: 4-6 crew can stand, walk
round each other and drop loot, about 2-3 crew lengths across. With a crew height of 5.5 studs:

| | Across | Long | Ceiling | Floor area |
|---|---|---|---|---|
| Today | 2.2 | 2.9 | 1.26 | 192 sq studs |
| Target (assumed) | ~2.5 | ~4 | ~1.5 | |

## 3. Two options (natural shapes, not a uniform scale-up)

Both keep the deck at 3 studs, so the ramp keeps its slope. The walls, roof and frame keep their thickness. The wheels
stay the same size. The cab grows a little.

| | **A · Big Box** | **B · Moving Van** (recommended) |
|---|---|---|
| Inside floor | 14 x 20 (**1.46x**) | 16 x 24 (**2.0x**) |
| Ceiling | 9 (Pippa's ears clear it by 2.3) | 10 (they clear it by 3.3) |
| In crew heights | 2.5 across x 3.6 long, ceiling 1.6 | 2.9 across x 4.4 long, ceiling 1.8 |
| Doorway | 14 wide, ~8.2 tall | 16 wide, ~9.2 tall |
| Shape | A longer, taller box truck; cab x1.1 | A moving van: tandem rear wheels, and the box runs on over the cab roof (a "Luton") with the mint light bar on its nose; cab x1.2 |
| Outside (ramp foot to bumper) | 31.5 long, 16.5 wide, ~13.8 tall | 36.2 long, 18.5 wide, ~14.8 tall |
| Today, for scale | 26.9 long, 14.8 wide, 11.7 tall | |
| Lethal Company test | About the assumed ship size | Bigger. Six crew stand in 2 rows of 3 with a loot pile up front (see the floor plan) |

**Recommendation: B.** It is what the owner asked for ("maybe bigger"). It solves the height problem with room to
spare, and the Luton and tandem wheels read as a real moving van, not a stretched toy. The extra wall and ceiling
space suits the interior upgrades that come later.

## 4. What a bigger truck touches

Nearly everything reads the truck's size from two constants: `BED_SIZE` (in `DepotTruckVisualConstants` and
`DepotLayoutConstants`) and the deck-space extents. So most of the work is changing data. Nothing needs a new module.

| Area | Today | A | B | Change needed |
|---|---|---|---|---|
| **Invisible collision and the camera walls** (`COLLISION`, `SHELL`, `GRAYBOX`) | Hand-placed, in deck space | Fits | Fits | Re-derive every entry from the new box, as v2 did. The specs (bed footprint kept clear inside the box, cores hidden in the art) re-check it. The ramp wedge widens to match the wider ramp. |
| **Hub bays** (3 bays 28 apart; floor 96 x 72) | 14.8 wide, front at z 62.9 | Gap between trucks 11.4. Cab front 65.5 (limit 69) | Gap 9.5. Cab front 68.2 (limit 69, tight) | `TRUCK_WIDTH` 15 → 17 / 19. `CAB_SIZE.Z` 7 → 8 / 9. `BAY_HALF_WIDTH` 9 → 9.5 / 10.5. For B: deepen the depot floor 72 → 78 and move the spawn row from z 26 to 22, so the bay's front markings stay clear of the spawns. `PAD_TAG_OFFSET` 14.5 → 16.5 / 17.5, so the bay sign clears the taller roof. Walls (22) are fine. |
| **The yard truck pad and the walk to the dock** | Pad at (168, -276), turned toward the dock | Fits: 30+ studs spare behind the cab | Fits: 25 studs behind the cab | Nothing in code. The walk to the dock gets ~4 studs shorter. The yard dressing (yard plan Y3b) must keep the new, bigger pad clear, so tell that session the footprint. The time clock beside the truck (14 studs out) still clears B by 4.7. |
| **The office loading bay** (authored layout: bay 44 x 42) | Cab inset 17 | Cab pokes through the wall | Same | `TRUCK_CAB_INSET` 17 → 20 / 22. `BAY_DEPTH` 42 → 46 / 50. Side inset 12 is fine. |
| **The office arrival spots (6)** | ±2.75 across, rows at z -4 / 0 / 4 | Fit | Fit | Spread them to use the room: ±3.5 / ±4, rows at ±5 / ±6. |
| **Banking and the load prompt** | Both read the bed part's size | Automatic | Automatic | `CargoConstants.BED_HEIGHT` 8 → 11, so a player who jumps under the higher ceiling still counts as aboard. `LOAD_DISTANCE` 16 → 18 / 20, so the prompt feels the same from the ramp foot. `LOAD_REACH` stays. |
| **The camera inside the box** | The ceiling at 6.9 squeezes the camera | Better | Best | The shell cores are re-derived, as above. More height means the camera pops in less. |
| **Ghost bays and the pop-in** | Found by tag and the shell attribute | Fine | Fine | Nothing. The dust puff ring is sized for wheels, so check it looks right round 6 wheels in the play check. |
| **Interior upgrade slots** (walls and ceiling) | 3 attachments | More wall | Most wall; B's Luton adds a loft for a future slot | Move the attachments with the walls. The time clock and the overtime sheet move with the front wall (`CLOCK_MOUNT`, `PAPERWORK`). |
| **Harlow's safe zone** | `truckBox` = the bed's footprint and `TOP` | Automatic | Automatic | Nothing, once `TOP` is updated. |
| **Part and light budget** | 37 MeshParts and ~29k tris per truck; 2 lights per truck | Same count | Same count, plus ~6 tandem pieces | Fine at 4 trucks per place. The box lamp's `LAMP_RANGE` 10 → 13 / 15, or a second lamp (+1 light per truck). The scanner glow's range 14 → 16. |
| **Livery** | The band image is 15.8 x 1.8 studs | Stretched 1.25x | Stretched 1.5x | A new band image at the new length, with the same line ("WE CLEAN UP THE NIGHT!"): one upload. |

## 5. If picked: build plan

1. **Art:** `build_truck_v2.py` takes the bed width, length and ceiling as parameters; cab scale, tandem and Luton
   are switches. Rebuild, re-render, owner OK.
2. **Upload:** the model and the new band image to Icey Labs, on the owner's OK. The old v2 stays as the rollback.
3. **Code, specs first:** the constants in the table above, in `DepotTruckVisualConstants`, `DepotLayoutConstants`,
   `OfficeConstants` and `CargoConstants`. No new modules.
4. **Studio:** both places. The new template becomes `Truck`; today's v2 becomes `Truck_v2` (and `Truck_v1` stays).
5. **Real-play check, 2 clients:** hub bays (ghost, pop-in, queue, depart), the yard truck (ramp, banking, load prompt,
   the camera inside, clock and sheet), and 6 crew aboard.

## Questions for the owner

**Look**
1. B (Moving Van: tandem wheels, box over the cab) as the new truck? (No: say A.)

**Layout**

2. Deepen the hub depot by 6 studs and move the spawn row back, so B fits its bays with room to walk?
3. Spread the 6 arrival spots out over the bigger floor?

**Rules**

4. Keep the deck at 3 studs (same ramp, same walk-up feel)?
