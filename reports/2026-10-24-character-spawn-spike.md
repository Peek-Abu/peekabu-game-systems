# Step 0 spike: each player spawns as their own employee (2026-10-24)

Plan: `docs/superpowers/specs/2026-10-24-odd-hours-character-systems-design.md`, section 4.
Where: Studio "Odd Hours: Shift" (placeId 118845637680835), Play with 1 player, injected throwaway server scripts
(nothing in the repo or the place changed). Screenshot: `reports/spawn-spike-prickles.jpg`.

## What was tried
Build the character by hand instead of `LoadCharacterAsync`: clone the employee template
(`ReplicatedStorage.Assets.CleanupCrew.Characters.Prickles`), `EmployeeSpawnSystem.prepare`, scale 1.25,
un-anchor every part, copy `StarterCharacterScripts`, name it after the player, pivot it where the old one stood,
set `player.Character`, parent to Workspace, destroy the old one. Then swap again in place (back to Pippa from
the StarterCharacter template), then kill it.

## Results
| Check | Result |
|---|---|
| Swap time on the server | 8–11 ms |
| `CharacterAdded` fires on a hand-assigned character | yes, every time (3/3) |
| Server dresses it (uniform, lanyard, skin via the existing CharacterAdded hook) | yes (Pippa swap came back dressed) |
| Vacuum backpack fits a new body (Prickles) | yes, `VacuumBackpack` fitted on its own |
| Physics owned by the player (`GetNetworkOwner`) | yes |
| Camera follows the new Humanoid | yes |
| `Animate` runs, idle and walk play | yes (Prickles uses the stock clips: he has no locomotion entry yet) |
| Walks (`MoveTo` 8 studs) | yes, 5.4 studs in 0.8 s |
| HUD portrait follows the new character | yes, the profile card switched to Prickles by itself |
| Ragdoll on death | yes |
| Respawn after death | works, but comes back as the shared StarterCharacter (Pippa): Death's respawn must call the new builder |

## Findings for step 2
1. **Templates are saved anchored** (the art files keep the root anchored so they don't fall in the editor). The
   builder must un-anchor every BasePart, or the employee is frozen and `GetNetworkOwner` throws.
2. **Respawns** go through `DeathServiceServer.loadCharacter` (`LoadCharacterAsync`) today; it must call the
   Employee builder instead (one place), and so must the boot-time respawn in `EmployeeServiceServer.start`.
3. The **vacuum wand** (Tool) is only handed out during a live shift (the engine-spawned Pippa had none here
   either), so the spike could not test equipping it. It follows `player.Character`, so it should work; checked in
   step 2's play-check in a real shift.
4. **Prickles has no registry entry** (locomotion, faces, uniform, backpack fit): he walked with stock clips and no
   uniform. Adding Cappy and Prickles to `EmployeeRegistry` is part of step 2.
5. Not covered (needs a 2-client server, which the Studio MCP cannot start): what a second player sees during a
   swap, voice following the new character, spectate onto a hand-built character. These go into step 2's owner
   play-check with a second client.

## Verdict
The hand-built spawn (plan A) works. No need for the fallback (swapping StarterCharacter per spawn).
