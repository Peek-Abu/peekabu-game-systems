# Character systems step 2: each player spawns as their own employee; swap in place — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: superpowers:executing-plans. Steps use checkbox (`- [ ]`) syntax.

**Goal:** Every player spawns (join, respawn) as the employee and skin their `loadout` names; changing either in the depot swaps the character where it stands with a goo puff; Cappy and Prickles are playable with their own locomotion.

**Architecture:** Employee builds characters itself (step 0 spike: manual `player.Character` assignment works) through one loader that Death calls for joins and respawns. Death gets two small, generic hooks (base-shaped; they need their own base PR later): `setCharacterLoader` and a keep-place character attribute. Employee listens to `CosmeticServiceServer.changed` to swap. The puff is a client burst.

**Spec:** `docs/superpowers/specs/2026-10-24-odd-hours-character-systems-design.md` §4; spike `reports/2026-10-24-character-spawn-spike.md`; step 1 `reports/2026-10-24-character-step1.md`.

## Global Constraints
- `--!strict`, no `any`/casts beyond existing boundary patterns; spec first; stage files by name (never the foreign SpecRoots / Office hunks); plain commit messages.
- Studio: hub window under `studio-playtest.lock`; RunTests cleared after.
- Art-place edits (template models) are made in Studio Edit mode and only persist when the owner saves; listed in the report.

## Review Focus
1. Profile not loaded at join → spawn waits up to 5 s for the loadout, then spawns the default (Pippa); never errors.
2. A loadout naming an employee whose template is missing in this place → falls back to Pippa (warned), never a nil character.
3. Swap requested while dead / knocked down / no character → no swap now; the next spawn uses the new look.
4. Template saved anchored or with HipHeight 0 → the built character moves and stands on the floor (spec: build un-anchors and fits hip height).
5. Respawn after death keeps the chosen employee (not the StarterCharacter Pippa).

## Decisions
- Skin keys: an EmployeeRegistry skin key is the CosmeticRegistry id after the dot (`Pippa.OwnerSpecial` → `OwnerSpecial`); a skin with no art yet falls back to Default (EmployeeSkinRules.select already does). Styles are saved but have no art yet (ignored when dressing).
- `EmployeeSkinRegistry` (MVP owner list) is deleted; the owner gets `Pippa.OwnerSpecial` with `cosmeticgrant me Pippa.OwnerSpecial` + `cosmeticequip me skin Pippa.OwnerSpecial`.
- Cappy/Prickles: scale 1.25 (as Pippa), the same face map, `uniform = {}` (no rank lanyard fitted to their bodies yet), no backpack fit (fitted from the torso), `portrait` = Pippa's placeholder until theirs are rendered and uploaded, `footstepSet = "pippa"` until they have their own sounds.
- Locomotion (uploaded, Icey Labs): Cappy idle 124155807682224, walk 105426576584816 (1.06 st/s), run 87388143018692 (2.06), crouch idle 78456687803253, crouch walk 140157048070101 (1.32). Prickles idle 108680458550464, walk 137832099996706 (1.03), run 82235036410910 (1.93), crouch idle 126115556970677, crouch walk 112633928289035 (1.34). Rates as Pippa's.
- Cappy template: built in each place by `characters/employees_build/cappy_v6_preview.luau` (the new hair), moved to `ReplicatedStorage.Assets.CleanupCrew.Characters.Cappy`. (The v7 skinned shorts are a later swap.)

## New / changed modules
| Feature | Realm | Subfolder | Name | Job |
|---|---|---|---|---|
| Death | shared | Rules | DeathRespawnRules (+`keepsPlace`) | a character marked to keep its place skips the spawn point |
| Death | server | root | DeathServiceServer (+`setCharacterLoader`) | joins/respawns call the loader when set |
| Employee | shared | Data | EmployeeRegistry (+Cappy, Prickles, `footstepSet`) | rig facts |
| Employee | shared | Utils | EmployeeRigUtils (+`hipHeight`) | hip height from the rig's geometry |
| Employee | server | Systems | EmployeeCharacterSystem (new) | prepared template cache, build, assign |
| Employee | server | root | EmployeeServiceServer | loader, dress from the loadout, swap on `changed` |
| Employee | client | Data | EmployeeVfxConstants (new) | the swap goo-puff burst |
| Employee | client | Systems | EmployeeSwapVfxSystem (new) | plays the puff on swapped characters |
| Animation | shared | Data | AnimationEmployeeRegistry (+10 clips) | Cappy/Prickles locomotion |
| Employee | shared | Data | EmployeeSkinRegistry | **deleted** |

### Task 1: Death hooks — spec `DeathRespawnRules.keepsPlace(true)=true`, (nil/"x")=false; implement; `setCharacterLoader(loader?)` in Death (loadCharacter → `task.spawn(loader, player)` when set); placement skipped when keepsPlace(attribute `DeathConstants.KEEP_PLACE_ATTRIBUTE = "KeepPlace"`). Commit.
### Task 2: Registry + clips — specs: Cappy and Prickles registered with all four faces, locomotion keys present in AnimationRegistry, `footstepSet` nil or a FootstepAssets set name (shared spec checks string); implement. Commit.
### Task 3: EmployeeCharacterSystem — spec on fake templates: `prepared(def, source)` returns a scaled, un-anchored, prepared copy cached per employee (same instance on the second call); `build(def, source, scripts)` returns a fresh clone with NAME_ATTRIBUTE = def.name, FootstepSet when set, every BasePart un-anchored, HipHeight fitted when the template's is 0, overhead display off, the scripts' children copied; nil when the template is missing. `EmployeeRigUtils.hipHeight(rootBottomY, lowestY)` spec. `assign(player, model, at: CFrame?, keepPlace)` (exempt shell). Commit.
### Task 4: EmployeeServiceServer — loader (wait ≤5 s for the loadout; employee from `CosmeticServiceServer:currentEmployee`, falls back to Pippa if not built), dress from `lookOf` (delete EmployeeSkinRegistry + spec), swap on `changed` (only when the worn employee/skin differs, character alive and not down; keep place; `EmployeeSwap` attribute), boot respawn through the loader. Commit.
### Task 5: Swap puff (client) — EmployeeVfxConstants preset `employeeSwapGoo` (grape puff ring + gleam stars) + spec mirroring OccupantVfxConstants.spec; EmployeeSwapVfxSystem plays it at the feet of a new character carrying `EmployeeSwap`. Commit.
### Task 6: Studio — build Cappy template in the hub, un-anchor Prickles' saved root; full suite (expect 0 failures); Play: commands switch Pippa → Cappy (puff, walks with his clips, footsteps), → Prickles, skin OwnerSpecial; die → respawn as chosen. Report + owner play-check list (2 clients, shift place after Rojo reconnect + Cappy template there).
