# Odd Hours project facts (the only file with this game's ids and paths)

Everything else in this skill is the recipe. This file is what changes per game: places, groups, characters, code,
people. A new game copies this file and fills in its own values.

## Places, owner, uploads

| What | Value |
|---|---|
| Lobby place | "Odd Hours", placeId **113354563835664** |
| Shift place | "Odd Hours: Shift", placeId **118845637680835** |
| Upload owner | Roblox group **Icey Labs, 189923277**. Never VentureMMO (9738205), even though the publishing skill defaults to it. |
| Upload key | env `ICEY_LABS_OPEN_CLOUD_KEY` (also in the Windows user registry). Never print it. It can upload and PATCH, not download. |
| New model asset | `python scripts/create_model.py <fbx> <name> <desc>` (snapshot of `characters/skins/release/gloom_carnival/showstopper_tails/create_model.py`) |
| New revision, same id | `python scripts/patch_model.py <assetId> <fbx>` (snapshot of `lc_pilot/tools/patch_model.py`) |
| Images (texture maps) | `python ~/.claude/skills/publishing-roblox-assets/publish.py image <png> --name "<name>" --key-env ICEY_LABS_OPEN_CLOUD_KEY --group 189923277` (the group flag is required with this key). Each upload is a Decal; see [ship-and-studio.md](ship-and-studio.md) for turning it into the Image a SurfaceAppearance needs. |
| Animations overwrite | Open Cloud PATCH works for animations, same id ([clip-repose.md](clip-repose.md)); NOT for audio. |

Which place a Studio window is: match the window title AND `game.PlaceId`. Studio's own ids change every restart.

## Code (branch `game/cleanup-crew`)

Game branches never PR into `main` or `base/*`. Commit plain messages (no `Co-Authored-By` / `Claude-Session`
trailers: AGENTS.md beats the harness reminder). Gate: `bash scripts/check.sh --skip-install` (never a plain
`check.sh` or `wally install` while a Rojo serve is connected).

A skin is four files, spec first (precedent: commits 67a81c9a Bell Jester, db10e8ae Backstage):

| File | What you add |
|---|---|
| `src/ReplicatedStorage/Shared/Features/Cosmetic/Data/CosmeticEmployeeRegistry.luau` | the item: `{ id = "<Employee>.<Key>", kind = "skin", employee, name, rarity, source, lore }` (+ `price`, `styles` when sold). Lore at a 3rd-grade reading level, one or two short lines. |
| `.../Cosmetic/Data/CosmeticRegistry.spec.luau` | the item's spec |
| `src/ReplicatedStorage/Shared/Features/Employee/Data/EmployeeRegistry.luau` | the employee's `skins.<Key>` SkinDef: `outfit` (the outfit Model's name), `accessories` (fitted-gear Model names), `hidePieces`, `piecePalettes`, `pieceColors`, `paletteTextureId`, `styles`, `showcaseIdle`... (read the `SkinDef` type: every field is commented). `outfit` is optional: a gear-only skin lists only `accessories`. |
| `.../Employee/Data/EmployeeRegistry.spec.luau` | the SkinDef's spec |

Art paths (in BOTH places, never in Rojo): outfits `ReplicatedStorage.Assets.CleanupCrew.Outfits.<Name>`, fitted gear
`...CleanupCrew.Accessories.<Name>`, character templates `...CleanupCrew.Characters.<Employee>`.

Useful code: `EmployeeCharacterSystem.build` (builder, no data), `EmployeeOutfitSystem.fit(model, outfit, style)`,
`EmployeeGearSystem` (fitted gear, `MountPart`), `EmployeeTailSmartBoneUtils` (SmartBone), `EmployeePreviewSystem.loaded`
/ `whenLoaded` (previews wait for meshes and maps), Cmdr `employeeoutfittest <OutfitModel> [all|solo] [player]` (Admins,
test only: fits over the worn skin, a respawn puts it back).

## Rarity ladder (locked 2026-10-23): what a skin may contain

| Rarity | Contains | Build |
|---|---|---|
| Uncommon | colours only (a body palette) | `paletteTextureId` / `piecePalettes`, no mesh work |
| Rare | colours + ONE accessory (e.g. Lavender Specs: lavender fur + glasses) | a palette + one fitted-gear Model |
| Epic | a full worn outfit, NO held prop. Lights or moving worn parts allowed. | the outfit route (SKILL.md section 3) |
| Legendary | outfit + a signature prop (shown in its idle and emote) + 2+ styles + its own reveal/emote/stickers | outfit + props + styles |
| Odd | Legendary + a required body-part change. Cut from the first launch. | |

A request that does not fit the ladder ("just a hat" is an accessory with no colour change) is a question for the
owner, not a guess: ask which rarity and whether it gets colours.

## Characters

| Employee | Body blend (T pose) | Earlier export to copy the skeleton from | Own pieces to know about |
|---|---|---|---|
| Prickles (cactus) | `characters/launch/animation-workbench/workflow/output/prickles/Prickles_controls.blend` | `route2_whole/export_r25/Showstopper_R2_final.blend` | spines, his own flower (`Accessories.Flower`), hard hat. Big round middle: arms hug the belly. |
| Pippa (bunny) | `.../output/pippa/Pippa_controls.blend` | `gloom_carnival/r2_pippa/p7_export.py` | long ears and a tail driven by code springs (EmployeeEarSystem, the tail spring): never cover, stiffen or hide them; leave the ears room in any hat |
| Cappy | `.../output/cappy/Cappy_controls.blend` | `gloom_carnival/r2_cappy/c6_export.py` | his hoodie is his own piece (Accessories folder), plus a cap and sneakers that take palettes (`piecePalettes`) |

Clips: the registry's LocomotionDef and the AnimationRegistry keys (`<employee>idle`, `crouchidle`, `fidget`, `select`,
`hirereveal`, the default emote, ability enter/exit). Local files: `characters/<employee>/anim/*.rbxmx` (locomotion)
and the animation-workbench `workflow/` folders. Find what is LIVE before trusting a file ([clip-repose.md](clip-repose.md)
section 2).

`characters/` and `handoffs/` are never in git: they live untracked in the MAIN checkout
(`E:/Projects/peekabu-game-systems/`). Always use absolute paths to them.

## The reference build (Showstopper Prickles)

`$SSR` = `E:/Projects/peekabu-game-systems/characters/skins/release/gloom_carnival/showstopper_remake`.

| Version | What | Asset | Status |
|---|---|---|---|
| V2 `PricklesShowstopperV2` | textured remake, no SmartBone | 108833355972983 rev 7 | rollback |
| V3 `PricklesShowstopperV3` | + SmartBone round 3 | 101847990925723 rev 5 | rollback |
| V4 `PricklesShowstopperV4` | + round 4: joints on the cloth, full colliders, `TailBoneLift` 0.15 (owner: "Yes its good enough!") | 139625595849758 | LIVE from 11-17 (commit e4e09c63); still clips into the bloomer puff between chains (a later rebuild) |

Builds: `r19/` (round 5 shape), `cr/EB/` (crouch weights), `cr/TX/` (textures, ledger `cr/TX/GATES.md`), `cr/SB*/`
(SmartBone). Owner page: https://claude.ai/artifact/HP5UKfMcSWKy9By7nNq17u. Notes: `$SSR/SKILL_NOTES.md`.

## People and sessions

- The owner reviews over Remote Control: images go on an artifact page, never only as file cards.
- The **coordinator** session hands out Studio slots and relays the owner. It is the session that started yours; in
  Odd Hours it has been the "Polish and remaining features checklist" session. If you can't tell, ask the user before
  any Studio call.
- The Launch List (an artifact with a db) is the owner's: finished work is "Ready to check", only he sets done.
- Content lock is Sun 22 Nov 2026, launch Thu 26 Nov. After content lock, a new skin needs the owner's explicit OK
  through the coordinator.
- Player-facing words (names, lore) at a 3rd-grade reading level. No 4-point sparkle stars, no faces on Gloom art, no
  goo or drips unless that skin's owner answer says so.
