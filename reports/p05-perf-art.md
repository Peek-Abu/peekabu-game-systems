# P0.5 performance and art (2026-11-13)

Session: p05-perf-art. Branch: `game/cleanup-crew`. Captures: the shared notes folder, `p05-perf-art/`.

## 1. Cappy's pack lean (`p1-cappy-pack-lean`): fixed, waiting on a play-check

Commit `e4a61342`: `VacuumConstants.MOUNT.maxTilt` 25 -> 12 degrees.

The pack's plate leans with the slope of the back under it (fitted through the mount rays). Cappy's hoodie hood bulges
out behind his shoulders, so his "back" read as a 23 degree slope and the pack lay along it.

Measured in the Shift place (Edit), every employee x every skin, with today's place art. Each cell shows the plate's
lean and the largest gap between the plate and the back at that cap:

| Employee / skin | cap 25 (before) | cap 12 (now) | cap 0 (upright) |
|---|---|---|---|
| Cappy / Default, PJ, GloomTouched | 23.4 deg, 0.10 | 12.0 deg, 0.14 | 0, 0.23 |
| Cappy / Backstage | 21.7 deg, 0.11 | 12.0 deg, 0.14 | 0, 0.22 |
| Pippa / Default, OwnerSpecial, GloomTouched | -4.7 deg, 0.03 | same | 0, 0.07 |
| Pippa / Bubble Buddy | 11.1 deg, 0.08 | same | 0, 0.15 |
| Pippa / Bell Jester | -1.6 deg, 0.36 | same | 0, 0.36 |
| Prickles / Default, GloomTouched, Showstopper | -4.5 to -4.7 deg, 0.04 | same | 0, 0.06 |
| Prickles / Sheriff | -12.6 deg, 0.16 | -12.0 deg, 0.16 | 0, 0.19 |

- 12 changes only Cappy (Sheriff moves 0.6 degrees). No per-character number; the rule is the same for everyone.
- Cappy now stands nearly upright with the pack's top resting on the hood. His lower back shows a 0.14 stud gap, hidden
  behind the straps from most angles. Captures: `cappy-pack-tilt25-before.jpg`, `cappy-pack-tilt12-after.jpg`.
- Separate, not changed: Bell Jester Pippa shows a 0.36 stud gap at every cap. Something on her back (likely the collar
  or bells) sits further out than the rest of the back under the pad, so the plate stands off to clear it. Worth a look
  in play.
- Not yet checked on a real character in play: Shift's Rojo was not connected, so the comparison was re-seated by
  hand in a Play copy.

## 2. First employee swap freeze (`p1-first-swap`): fixed and checked in a real Lobby Play

Commit `3af5823d`: in the hub (`DepotConstants.HUB_PLACE_ID`), each player's first character is rebuilt once in place
`EmployeeConstants.WARM_SWAP_DELAY` (0.5 s) after it spawns: the same employee, with no goo puff, while the welcome
card still covers the screen. Debugger: `EmployeeServiceServer.getState().warmSwaps`.

Measured in the Lobby (Studio Play, client frame times from RenderStepped; swaps scripted on the server through
`EmployeeCharacterSystem.build` / `assign`, the same calls a depot swap makes):

| | Worst frame, first swap | Worst frame, later swaps |
|---|---|---|
| Before (no pre-swap) | **594 ms**, on the frame just before the client's CharacterAdded | 67-97 ms |
| With the hidden pre-swap 1 s after spawn | the pre-swap itself: 549 ms, behind the welcome card | 4 real swaps in a row: none over 100 ms |

- The freeze is a one-time cost per client session, not per employee: Prickles, never worn before, swapped in 67 ms
  after Cappy took the 594 ms. The server's `assign` takes 5-7 ms; the stall is engine work on the client's first
  character replacement (P0's profiles showed our Lua is not it).
- The Shift place showed no freeze at all (71-100 ms on every swap). Its place code was older (Rojo not connected), and
  swaps can't happen there anyway (Cosmetic is locked outside the lobby phase), so the warm swap is hub-only.
- Checked with the shipped code (Lobby, Rojo synced, fresh Play): `warmSwaps = 1` (it ran during the welcome card),
  then the first real swap Pippa -> Cappy peaked at **125 ms**, Prickles 167 ms, Pippa 172 ms. Frames were a little
  heavier in that run than earlier (other sessions were using the machine), but the 0.6 s freeze is gone.
- Risk to watch: a client whose welcome card lifts in under ~1 s (everything cached) could see the rebuild. It is the
  same employee in the same spot, so at most a one-frame flicker.

## 3. More performance (`p1-perf-more`)

### Memory leaks: none found

| Test (Studio runs server and client in one process, so both report the same memory tags) | Result |
|---|---|
| Shift: 20 character swaps (Cappy, Prickles, Pippa cycling) | Instance count flat (16,316 -> 16,225). PhysicsParts rose 43.6 -> 58.5 MB during the swaps and was back to 43.6 MB after 40 s idle; Instances memory back to 159.2 MB. Animation +2.6 MB stays (clips cached once). |
| Lobby: Inventory and Shop opened and closed 10 times each | Instance count identical before/after (12,413). ViewportFrames 6 -> 9 (Inventory) / 12 (Shop) -> back to 6; Models 35 -> 50 / 65 -> back to 35. Memory +114 MB right after; after 45 s idle +42 MB total, +0.9 MB Instances, Lua heap below baseline. |

- At idle in the Lobby the only animated viewport is the character-pick hero, which is on screen. The hub profile
  portrait is hidden but static (no WorldModel), so it costs nothing.
- Code review of every ViewportFrame/WorldModel owner (ToonViewport, EmployeePreviewSystem, EmployeeStageSystem,
  CharacterPortrait, EmployeePortraitSystem, the lanyard info card, ShiftHotbar, EmoteLassoSystem): every model,
  camera, WorldModel and connection is destroyed on close. Smaller items found, not fixed (no measured cost yet):
  - EmployeePreviewSystem loads a new AnimationTrack per idle/reaction call without destroying the old one (grows with
    clicks while a hero is open, freed when it closes);
  - its static preview cache (64 looks) is wiped whole at the cap, and the rank in its key leaves old-rank copies until
    then;
  - EmoteLassoSystem does a couple of lookups per tracked character every frame even when nobody is lassoing.

### Hitches when equipping or buying

- Equip = the swap above (fixed). Later swaps cost 60-100 ms worst frame.
- Opening the Inventory raises the median frame 17.4 -> 20 ms; the Shop 17.4 -> 22-24 ms (worst 69 ms on open), from
  its animated heroes and 12 viewports. Fine on desktop; worth profiling on a phone.
- Commit `fd40d32c`: the lanyard no longer throws away a strap build in flight (it yields on CreateMeshPartAsync) when
  any player's public data changes to the same rank. Every buy or equip changes public data, so around a swap the strap
  could be built two or three times. Not measured in play: EditableMesh is off for this experience in Studio ("EditableMesh
  is not accessible"), so the strap isn't built there at all.
- A skin purchase itself was not simulated: a test grant writes the owner's real Studio save.

### Heavy models (triangle counts from EditableMesh face counts in the Lobby, 409 unique meshes)

| What | Triangles |
|---|---|
| Cappy (body + hair, hoodie, shorts, cap...) | 138,760 (32 meshes) |
| Prickles | 125,604 |
| Manager (NPC) | 102,682 |
| Pippa | 83,200 |
| Skin outfits on top | Sheriff 71,120 · Showstopper 43,118 · Bubble Buddy 35,969 · Bell Jester 30,032 · PJ 28,797 · Backstage 21,216 |
| Lobby Workspace total | 1,126,562 (356 MeshParts) |
| of which DepotHub | 765,069 (Dressing 313,852 · Yard 243,067 · Spots 81,659 · Lights 72,072) |
| of which LockerStage_Ref | 221,960 |
| Truck template | 34,307 |

- Largest single meshes: the heads (Cappy 19,536 · Prickles 19,936 · Pippa 17,632, all near Roblox's 20k cap), the
  FacePlates (10,112 each), Cappy's skinned shorts 14,740 and hair 14,000, the Sheriff legs 20,000, the vending machine
  15,780, the leaf piles 13,752 x 8, the bookshelf 13,032 x 6.
- A crew of 6 is ~0.5-0.8M triangles of characters before the map. Every hub prop uses RenderFidelity Automatic
  (engine LOD at distance); characters in viewports render at full detail.
- **Not decimated here.** The tool exists (`characters/kit/optimize_mesh.py`): halving Pippa v12 moved surfaces by at
  most 0.003 studs, and her head and FacePlate by at most 0.0005, with the face and palette UVs kept. But its quality
  gates (`employees_build/gates/6_decimate.md`, OM1-OM5) were never finished, and shipping it means new mesh uploads
  (owner OK, Icey Labs), new mesh ids in both places, and a re-check of every fitted skin outfit. Proposed as its own
  task.
- `LockerStage_Ref` (222k): a Workspace copy of the locker cutscene stage. The client destroys it on the first locker
  opening when `ReplicatedStorage.Assets.CleanupCrew.LockerStage` exists, so if both are in the place the Workspace
  copy is dead weight until then. Check in Studio before removing (place art: the owner's call).

### Decimation proposal (owner's yes/no)

| Candidate | Today | Proposed | Look risk |
|---|---|---|---|
| Employee heads (Pippa, Cappy, Prickles) | 17.6k-19.9k each | about half, with `optimize_mesh.py` (max surface error 0.005 studs) | low: the October test moved Pippa's head by 0.0005 studs at most |
| FacePlates | 10.1k each | about 5k | low: face UVs re-sampled, error 0.0004 |
| Cappy's hair and skinned shorts | 14.0k, 14.7k | about half | medium: skinned mesh, re-check how it bends |
| Skin outfits (Sheriff 71k, Showstopper 43k, ...) | 21k-71k each | later, after the bodies | medium-high: fitted to the body, each needs a play re-check |
| `LockerStage_Ref` in the Lobby | 222k | remove from Workspace if `Assets.CleanupCrew.LockerStage` exists | none in play (the client already destroys it on first use); place art, owner's call |
| Hub props (leaf piles 13.8k x 8, bookshelf 13k x 6, vending 15.8k) | 765k in the hub | leave | engine LOD already thins them at distance |

- **D1.** Decimate the three employees' bodies (heads, FacePlates, then hair/shorts), shown to you side by side
  before any upload? (yes / no)
- **D2.** Remove `LockerStage_Ref` from the Lobby's Workspace if the ReplicatedStorage copy is there? (yes / no)

Owner, 2026-11-13: "yes to both d1 and d2 if locker stage is truly not needed!"

D2 done in the Lobby (Edit, one undo step; the owner saves the place). Proof it was unused:
- In code it is only `LockerCutsceneSystem`'s fallback when `Assets.CleanupCrew.LockerStage` is missing. That template
  is in the place, the same model (7 children, 298 parts), and the cutscene destroyed the Workspace copy on first use
  anyway.
- Nothing in the place points at it (no ObjectValue, joint or constraint).
- With it deleted, the Locker cutscene started in a Lobby Play, built its stage from the template (438 parts), moved
  the camera, and cleaned up on stop.
- The Lobby drops 222k triangles once saved.

The work is a separate task (proposed: "Cut character triangles with optimize_mesh"): finish the tool's OM1-OM5
gates on the shipped builds, render the comparison, and upload to Icey Labs only after your yes.

### D1: lighter characters, built (waiting on the owner's look check before any upload)

Run with `characters/kit/optimize_mesh.py` (ratio 0.5, max error 0.005 studs) on the shipped builds, matched to the
Lobby's meshes by per-part triangle counts: Pippa `pippa/v13`, Prickles `prickles/v4`, Cappy `cappy/v6` (head and
FacePlate; his hair, hoodie and shorts in the game are later uploads, not done yet). Outputs:
`F:/Dev/temp/claude/texwork/decimate/<name>/` (FBX, blend, rig JSON, `optimize_report.json`).

| Employee | Parts halved | Triangles | Largest surface error |
|---|---|---|---|
| Pippa | Head, FacePlate, UpperTorso, both feet, both ears | 83,200 -> 58,816 | 0.0006 studs |
| Prickles | Head, FacePlate, UpperTorso, both feet | 125,604 -> 100,688 | 0.0014 studs |
| Cappy | Head, FacePlate | 138,760 -> 123,936 | 0.0005 studs |

- Look check: EEVEE renders of the original and the lighter build from the same cameras (front, 3/4, head close-up),
  with every image pointed at the exact file the original uses. Mean pixel difference 0.01-0.19 / 255 on every view.
  The worst 16-px block is 2-9 / 255 for Prickles and Cappy, and 28 / 255 on Pippa's head close-up (an eye highlight
  edge; it looks identical). Sheets are on the review page.
- A first Pippa comparison showed grey patches on the head. Those came from the renderer relinking a face image from
  the wrong version folder, not from the mesh; with the exact files the builds match.
- Tool note: `optimize_mesh.py` refused Prickles' head because its own triangulation check (1e-5 studs) caught 3.5e-5
  studs of float noise. I ran a scratch copy with that check at 1e-4; the shared tool is unchanged. Worth raising
  that limit in the tool.
- Next, on the owner's yes: upload the new parts to Icey Labs, swap the MeshIds in `Assets.CleanupCrew.Characters`
  in both places, and play-check every skin's outfit and accessories on the lighter bodies.

### D1 round 2 (owner: not OK yet; waiting on the level pick, nothing uploaded)

Owner: the renders showed Cappy's earbuds without their Studio fix, and "I was fully expecting the decimation to bring
it down to like 10k tris". Answers:
- Source of truth checked against the live models, read-only, in both places. Every part to decimate (heads, face
  plates, torsos, feet, ears, hands of Pippa, Prickles and Cappy) has the same triangle count and size live as in the
  source build (`pippa/v13`, `prickles/v4`, `cappy/v6`), so the geometry is the game's. Cappy's earbuds are the same
  mesh live and in the source. The owner's fix is their placement and texture (welded to the Head, TextureID
  132723230315784), which a Head/FacePlate mesh swap never touches; the first renders just used the build file's old
  placement. The only source mismatch is Cappy's hair (live 14,000 vs v6 13,948), not in the decimation set.
- Lobby vs Shift: all 17 shared Characters/Outfits/Accessories models are identical, part by part (mesh ids, sizes,
  offsets, colours, textures and maps, attachments, joints, cages). The Lobby has no Bramble (Shift only).
- Pippa at 39,909 / 19,948 / 9,969 (from 83,200), same cameras plus close-ups (review page):
  - 40k: no visible change anywhere.
  - 20k: small steps on the hand's outline up close.
  - 10k: fine at play distance and the face is untouched. Up close the hands look lumpy, the head's outline is
    slightly angular, and the white inside the ears is jagged. Largest surface error 0.019 studs.
- What doesn't break: shading (custom normals copied from the original), the face decal UVs, deformation (Pippa's limbs
  are rigid R15 pieces; no skinning to break), and the clothing cages (separate meshes, left untouched).
- 10k needs no retopo or bake for these round shapes. A per-part budget (more on hands and ears, less on the torso
  and the back of the head) would make 10k cleaner: about 1-2 h per character plus checks. One skin (Bubble Buddy)
  gets a play test on the chosen level before any swap.

### D1 shipped: the 10k level in both places (the owner to save both)

Owner pick: "Honestly the 10k one looks good!" The page showed plain 10k at that level; I built the uneven per-part
budget I had recommended. It has the same count and is visibly smoother on the hands and head outline (Pippa's final
sheet shows plain and uneven side by side).

| Employee | Before | After | Budget (triangles per part) |
|---|---|---|---|
| Pippa | 83,200 | 9,899 | head 2,300, face plate 1,200, ears and hands 650, feet 450, upper torso 1,000, lower torso 300, limbs 200 |
| Prickles | 125,604 | 10,198 | head 2,300, face plate 1,200, flower 550, hard hat 500, hands 450, feet 400, torso 750/400, limbs 300-400 |
| Cappy | 138,760 | 52,791 | head 2,300, face plate 1,200, cap 900, hoodie 1,100 / sleeves 800 and 1,600, sneakers 600, hidden body 150-200 |

- Cappy's hair (owner-edited), earbuds (owner fix), skinned shorts, socks and waist piece are untouched: about 38k on
  their own. Cutting them is a separate job, and only if the owner wants it.
- Uploaded to Icey Labs, owner verified: 8 models (`reports/p05-decimation-assets.json`).
- Swapped into both places' templates with `design/production-art/character-decimation/decimate_swap.luau`: 61 parts
  each; old ids in `PreDecimateMeshId`.
- **Incident, fixed:** `MeshPart:ApplyMesh` resets `TextureID`. It cleared the palette texture on 58 of the 61 parts,
  first in the Lobby, then in Shift. The Lobby play-check missed it because skins set their palettes at spawn. The
  Shift before/after diff caught it. Fixed in both places: the mesh-blind fingerprint now equals the pre-swap one
  (Pippa 52eb3556, Cappy 04d171ff, Prickles a4a2abeb), so only the meshes changed. The committed script now carries
  `TextureID` over and undoes itself unless that fingerprint is unchanged.
- Play-check (Lobby, all 13 employee x skin looks as stand-ins): frozen mid walk, crouch walk and emote, every outfit
  and accessory fits, nothing pokes through or detaches, and the inventory cards draw the lighter models. Hide: Pippa
  and Prickles entered a real training-map desk (server: hidden), but your own character is invisible while hiding
  (LocalTransparencyModifier 1). Seeing it needs a second client: worth one look in the owner's play-check. Every part
  keeps its original size (about 0.01 studs), so furniture fit is unchanged. Captures: notes `d1-10k-lobby-check-*.jpg`.

### D1 follow-up: the carry test and Pippa's upper torso (both places; owner to save both)

- The suite at 5e84b7b1 had 1 failure: AnimationCarryHarness `Pippa keyring (hand): plan right: palm 0.125 from the
  handle`. The live idle and walk poses were fine, and the StockR15 plan passed.
- Cause, found by putting Pippa's pre-swap meshes back in Play only:
  - all parts back: passes;
  - the hand only, or the arms too: still fails;
  - the UpperTorso only: passes (the lower torso or the head only: still fails).

  So the planner's one-hand keyring hold depends on Pippa's UpperTorso mesh: her chest with the bell and bow tie, cut
  from 13,824 to 1,000 triangles. The hand, attachments and part sizes were unchanged.
- Fix (art, not the tolerance):
  - Pippa's UpperTorso rebuilt at 2,000 triangles (largest error 0.005 studs), uploaded as 88534524319865; all 34
    carry holds pass.
  - A 3,000 version (116222203120920, unused) failed the coffee mug instead, so the planner sits close to its limits
    for Pippa.
  - Pippa is now 10,899 triangles.
- Applied in both places (TextureID carried over, PreDecimateMeshId still the original). The mesh-blind fingerprint
  is unchanged and equal to pre-swap in both: Pippa 52eb3556, Cappy 04d171ff, Prickles a4a2abeb.
- Full TestEZ suite, Shift, with the fix: **6,663 passed, 0 failed.**
- `decimate_swap.luau` now loads the 2,000 torso for Pippa (a later asset overrides an earlier one by part name).

## 4. Truck redo (`p1-truck-lore`): v4 is in both places (owner to save both), ready for the owner's play-check

Shipped (2026-11-13). Owner: T1 "fine", T2 pass, plus one fix: "move wheels to side for back wheels? The top of
wheel / guard is clipping into truck!!"
- Fix: the rear tyres now stand beside the box (inner face 0.02 off the wall, tyres 1.4 wide); the guards are flares on
  the wall; the bottom rail stops in front of them. The truck is 20.4 studs wide. The hub bays are 28 apart (Lobby
  x 20 / -8 / -36; the Shift test depot the same), so 7.6 studs stay between trucks. `681292cd`: `TRUCK_WIDTH` 20.5,
  `HALF_WIDTH` 10.25, the graybox's rear tyres beside the box. No bay was moved.
- Uploaded to Icey Labs (owner verified on economy.roblox.com): model 94655249327854; images (decal -> image) old sign
  74575119736869 -> 122225529513930, paint color 135127847966340 -> 138264076346730, normal 129129956082610 ->
  108711044187760, rough 89452180093827 -> 91431433008800 (`design/production-art/truck-lore/assets_v4.json`).
- Template `ReplicatedStorage.Assets.CleanupCrew.Truck` in both places: 39 MeshParts at their deck-space centres,
  `PaintSlot`, anchored and inert, Box fidelity, CabWindows Glass 0.25. The 22 paint-slot pieces carry a
  SurfaceAppearance (the paint set; its `Color` is the slot colour), and there are 9 attachments.
  `RuntimeApproved`, `SourceAsset`. Rollback: delete `Truck`, rename `Truck_v3` back.
- Code `299a572e`: no `TruckLuton` camera wall (no Luton), no side line, `LORE_SIGN` (a SurfaceGui on the art's
  BoxShell Right face). Specs updated first.
- Checked in play, Shift and Lobby with the code synced: every truck (3 hub bays + the office) builds the
  approved-mesh art from 94655249327854 with the sign; no `TruckLuton`; no layout errors. In-Roblox captures in the
  notes folder (`truck-v4-in-roblox-shift-2026-11-13.jpg`, next to v3).
- For later truck skins (crew hosting batch 6): recolour a slot through the SurfaceAppearance's `Color`, not the
  MeshPart's (a SurfaceAppearance ignores the part colour).

Earlier step (look A built, waiting on the owner's look check):

Owner, 2026-11-13: "yes build look A and take Morrow and Morrow off the truck! Sure to Q5! I think maybe keep off Q6".

- Built (`42066a98`): `design/production-art/truck-lore/build_truck_v4.py`, a copy of v3's builder reshaped to look A.
  - Bubble cab: a rounded side profile with a fat bevel, a split windscreen, big round headlights in cream bezels, a
    bar grille and a fat bumper bar.
  - Mint beacon on the cab roof (it carries `Socket_Roof`). The Luton is gone.
  - Loaf box: a thick roof cap rounded over the long and end edges, flush with the walls.
  - A wavy grape swoosh (`BoxBand`, no line on it), five glowing portholes per side, chunkier fenders.
  - Same bed, walls, ramp, arch and interior; 44,084 triangles in 39 pieces. `Truck_v4.json` beside the builder.
- Texture pass: a new `vehicle_paint` class in the texture-pipeline's `style.json` (backup `style.json.bak-2026-11-13`).
  It produces `truck_paint_color/normal/rough`: a near-white satin with a fine orange-peel bump from the PaintedPlaster017
  scan, lum_std 0.012 (PASS). Every piece has box-projected UVs at 4 studs per tile, so a slot's colour is a
  SurfaceAppearance tint and skins still need no upload.
- Lore find: `make_lore_sign.py` draws `lore_sign.png`, the old "MORROW & MORROW / CLEARANCE" lettering and an "M&M"
  seal ring, faint brown-grey under cream roller strokes. It goes on `BoxShell`'s Right face, low near the back, at the
  JSON's `loreSign` rectangle. It reads as a patchy panel from the yard and as the name up close.
- Q4: the shipped truck already had no Morrow & Morrow (the v3 livery line was the only text, and the time clock has
  none), so nothing to remove.
- Next, after T1 = yes:
  - upload to Icey Labs: the FBX, the three paint maps and the sign image;
  - code (`DepotTruckVisualConstants` / `DepotTruckVisualSystem`): drop the `TruckLuton` camera wall and the livery
    line, and add the sign. Held until the art swaps, since the v3 art still has the Luton;
  - Studio: swap `Assets.CleanupCrew.Truck` in both places (SurfaceAppearance per piece, colour from the slot).

Earlier step (concepts):

- Three looks, all at today's footprint (16 x 24 bed, 10 high, open back and ramp), no company name on any:
  A Night Bakery Van, B Gleam Machine, C Hand-Me-Down Hauler (with a faint painted-over sign as a lore spot).
  Review page: https://claude.ai/artifact/AkKKXjosViijRC93UtnG8h. Sources: `design/production-art/truck-lore/`.
- Yes/no questions on the board row: Q1-Q3 build A / B / C; Q4 take Morrow & Morrow off the truck and its time clock;
  Q5 hide a painted-over M&M sign as a lore find; Q6 keep "WE CLEAN UP THE NIGHT!".
- The v3 livery already has no Morrow & Morrow; the name is still in the time clock's build notes, the depot board's
  subtitle ("Morrow & Morrow Clearance · tonight's contracts") and `DepotTruckVisualSystem`'s doc comment.
- Build after the yes: hand-built in Blender with the Office split modelling/texturing passes (`texture-pipeline`),
  same collision contract as `DepotTruckVisualConstants`, upload to Icey Labs after the owner's OK, in both places.

## Studio housekeeping

- No place saved or published. Temp instances (`__p05*`) removed in both places; Plays stopped; RunTests left as found
  (false on Shift, unset on the Lobby).
- Studio's master volume was set to 0 for the Plays and left there.
- Neither place had Rojo connected during this session (Shift showed the connect prompt; the Lobby lacked 3af5823d
  after the served worktree pulled it).
- Gate: selene's shadowing warning in `UIPreloadRules.luau:161`, which stopped `scripts/check.sh`, is fixed in
  `c9658522`. Many files are still over the 400-line limit (on the "split the long files" row; EmployeeServiceServer
  is now 419).
