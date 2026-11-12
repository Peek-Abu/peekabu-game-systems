# Odd Hours depot hub (Night Garage) dressing

- `build_hub.py`: hand-built props on the yard kit (`../yard-dressing/build_yard.py` materials and helpers), Blender 5.1 headless.
  Props: `pumpkin:round|tall|squat`, `leafpile:a|b` (drift, scatter), `tree` (autumn maple), `pendant` (caged garage lamp),
  `wallpack` (wall light). Env `HUB_OUT` = output folder; `TEXPIPE_WORK` as the texture pipeline.
- `to_fbx_hub.py`: `_parts.glb` -> FBX (Glow / Glass / Hazard pieces keep their names).
- `upload_batch.json` / `upload_log.jsonl`: the 2026-11-11 upload (owner OK via the coordinator), 8 meshes + 24 maps,
  Icey Labs (group 189923277) only, every asset checked group-owned and Approved.

Placed in the lobby place (Studio art, `Workspace.DepotHub`): pumpkins and leaves under `Dressing/Autumn`, garage lamps and wall
lights under `Lights` (they carry the old fixtures' lights), the maples and `Yard/YardLife` (yard-kit bushes, grass, cars,
dumpster, barriers, outside wall lights, fireflies) under `Yard`, and `Training/TrainingTruck` (a 0.5-scale clone of
`Assets.CleanupCrew.Truck` with the band livery and TRAINING signs). Placing a loaded mesh: its parts' CFrames are relative to
the authored floor origin, so `cf * (part.CFrame.Rotation + part.CFrame.Position * k)` with `Size * k`.

## Pumpkins v2 (2026-11-11, owner OK)
The vine leaf's veins/stalk (`vleaf_veins`) were never moved with the leaf, so they sat inside the pumpkin, and the leaf
cut into the ribs. `build_hub.py` now moves both and seats them rigidly on the skin (`_drape`). Re-uploaded to Icey Labs
and swapped into the lobby's 14 pumpkins in place (MeshPart:ApplyMesh, scale and CFrame kept; SurfaceAppearance maps):

| Variant | Model | Mesh | Color / Normal / Rough (image ids) |
|---|---|---|---|
| round | 118435555682999 | 77809726577446 | 99998307521436 / 74155896689065 / 131731772303976 |
| tall | 139682393289774 | 132186097936997 | 97822968756899 / 91975468946512 / 122189962640296 |
| pale (squat) | 103333606513045 | 124424530913187 | 109552291066008 / 130340302459288 / 128424890770824 |

## Radio and shift bell v2 (2026-11-11, look sheet only, nothing uploaded)
Office procedure. Texture pass: ambientCG Metal048C (brass) and PaintedMetal012 (chipped paint) through new
`brass` / `paint` style classes (owner OK for the two downloads); wood is the oak scan. Model pass: `build_hub.py`
props `radio` (1.9 x 0.95 x 1.35, oak cabinet, cream front, brass slats over a dark cloth, dial, knobs, handle,
antenna), `bellpost` (teal post, base plate, collar, arm and yoke) and `bell` (brass bell, pivot at its pin, hangs
from the yoke at (0, -0.85, 4.1)); `radio_bell_look.py` renders them. When swapped into the hub: the radio mesh must be
named `RadioBody` (the music notes emit from it) and the bell parts keep `DepotSwing` + the `BellPivot` attachment.
Sheet: notes `hub-r3-radio-bell-v2-look.jpg`.

## Round 5 (2026-11-12, owner notes)
- **Pumpkins without leaves + a separate leaf prop.** `pumpkin:<variant>-bare` builds the pumpkins with no leaf or vine;
  `pumpkinleaf:a|b` is two broad five-lobed pumpkin leaves with pale veins, stalks and a corkscrew tendril, shaped over a
  round pumpkin's shoulder. Its authored pivot is the stem base; Roblox centres the mesh on its bounds, so in Roblox the
  stem sits at (-0.0034, -0.2938, -0.197) (a) / (-0.2333, -0.2941, 0.2258) (b) from the MeshPart's centre, x the leaf's
  scale (scale = the pumpkin's scale x its radius / 1.25: round 1.25, tall 1.0, pale 1.35). Uploaded with the owner's
  pumpkin OK (all 40 ids checked group 189923277) and swapped in: the 14 lobby pumpkins wear the bare meshes
  (ApplyMesh, size and CFrame kept), 7 of them (every other one) wear a leaf cluster in `Dressing/Autumn/PumpkinLeaves`
  (the owner fixes the ones that look off).

| Asset | Model | Mesh | Color / Normal / Rough (images) |
|---|---|---|---|
| pumpkin round bare | 114263424312463 | 98880936845404 | 75532230980509 / 119463233517741 / 71124988591438 |
| pumpkin tall bare | 134081924395063 | 116707374539199 | 88617841673681 / 105881846486619 / 133343324659102 |
| pumpkin pale bare | 93268058464016 | 111538999063491 | 100712249641636 / 78541582672765 / 105831343578270 |
| pumpkin leaves a | 82777977320744 | 135627605351141 | 72535696753865 / 100488666054292 / 112328920216420 |
| pumpkin leaves b | 123622410456209 | 78090684098995 | 127188943897320 / 73103075065016 / 109428284027877 |

- **Snack machine remake (owner OK 11-12, uploaded and swapped in).** `vending` (the hub machine's size: grape steel, mint and
  gold trim, an open window onto four coil shelves, lit buttons, coin slot, card reader, pickup tray, a Gleam sparkle
  header) and `snack:can|bottle|chips|bar`. `r5_look.py` renders them; sheet: notes `hub-r5-vending-pumpkinleaf-look.jpg`.
  In the hub the stocked items are tagged `DepotVendingStock` (the vend motion drops one to the tray).

  Uploaded with the owner's OK (all 41 ids checked group 189923277) and swapped in: `CoffeeCorner/vending` wears the new
  mesh (its authored origin at (-12.5, 1.06, -240.2), turned 180 deg; the old `Glow` part carries the lit button and card
  light), the glass sits in the new window, a soft `InsideLight`, and `vending/Stock` holds 16 snacks (bars, chips,
  bottles, cans from the bottom up) tagged `DepotVendingStock`. The shelves stand back from the glass so a vended snack
  drops down the lane in front of them; `IdleMotions/VendingCans` spans the window from the tray up, facing the glass.

| Asset | Model | Mesh | Color / Normal / Rough (images) |
|---|---|---|---|
| snack machine v2 | 124770794210652 | 87520540525046 (+ Glow 72276313046221) | 73950959597054 / 101997262118335 / 138911549358103 |
| snack can | 80265359587698 | 76826477230720 | 98246391209606 / 97093626673453 / 101999382998920 |
| snack bottle | 74718849864046 | 138701778330518 | 121692672852079 / 92203595821535 / 101705239471195 |
| snack chips | 133010450796957 | 84514870296740 | 76220164300441 / 134696409403450 / 114105196004947 |
| snack bar | 79264925729143 | 115883930717980 | 100262445950274 / 138703037299381 / 98278877383864 |

## Round 6 (2026-11-12, owner notes)
- **Radio notes without the star.** The owner said the 4-point sparkle cell in `radio_notes_flipbook.png` looked
  AI-made; it is a mint eighth note now (notes only). A decal cannot be updated in place over Open Cloud ("Updating
  Decal is not supported yet"), so it is a new upload: decal 79230367007309, image 118582584373486 (both checked
  group 189923277); `DepotAssets.RADIO_NOTES` points at the image.
