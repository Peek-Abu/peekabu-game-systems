# Training map polish (owner 11-12)

Studio command-bar scripts that restyle the authored TrainingMap in a place. Run them in Studio Edit in EACH place that
holds the map (the lobby and the Shift place), in this order; each is idempotent. They change looks only: every part
with a TrainingRole, the HideFurniture desks, the doors and the TruckBed keep their tags, roles and collision.

1. `BuildTruckDock.CommandBar.luau` - opens the stop-2 room's right wall onto a loading dock and makes the TruckBed
   full size (16 x 3 x 24); TrainingSiteSystem builds the company truck round a full-size bed at runtime. Grows the bay
   box and the stop-2 zone over the dock.
2. `DressShell.CommandBar.luau` - Office plaster walls with the oak dado rail and skirting, carpet floors (concrete in
   the dock), ceiling tiles under a T-bar grid, troffer housings and lights, door looks and frames, and the Gloom creep
   as round goo blobs (TrainingHallSystem grows them, TrainingCreepRules).
3. `DressProps.CommandBar.luau` - the Office kit's uploaded props (no new uploads) on the furniture colliders (each
   collider unseen, its look an `Art` model under it) and Office dressing round the walls.

Uses the place's OH_Plaster / OH_Carpet / OH_Ceiling / OH_Oak MaterialVariants when it has them (the Shift place),
else Roblox's Plaster / Carpet / Concrete / Wood. The lobby got the four Office variants copied from the Shift place's
MaterialService (read 2026-11-12), image ids colour / normal / rough, StudsPerTile:

| Variant | Base | Colour | Normal | Rough | Studs |
|---|---|---|---|---|---|
| OH_Plaster | Plaster | 112255944983790 | 131482043768970 | 108734579719883 | 10 |
| OH_Oak | Wood | 140176970339235 | 133450618501853 | 98108513656521 | 6 |
| OH_Carpet | Fabric | 122567516631364 | 99767245032269 | 71491637029770 | 8 |
| OH_Ceiling | Concrete | 76019697303102 | 128615599160062 | 82067933016233 | 8 |

Done in the lobby 2026-11-12 (unsaved, the owner saves). The Shift place's map is not restyled yet.
