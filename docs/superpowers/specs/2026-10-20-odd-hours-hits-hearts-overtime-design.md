# Odd Hours: catches as hits, hearts, and overtime loot

Status: approved by the owner in chat (2026-10-20). Branch `game/cleanup-crew`. It builds on `2026-10-20-odd-hours-gloom-lives-design.md`, which is built: 3 lives per player, the third catch knocks you out, and the whole crew out is a missed contract.

## Why

- **Catches 1 and 2:** dying, waiting 8 s and the CCTV screen make an early catch feel like a death. The owner wants players back "pretty quickly". A catch should feel like a hit: thrown, ragdolled for about a second, up again.
- **The lives display:** three red dots don't read as lives. The owner approved toon heart icons.
- **Overtime:** ×1.5 on everything banked in overtime rewards holding loot back and re-walking cleaned rooms. The owner approved ×1.5 on new overtime loot only. Today nothing spawns in overtime, so overtime must bring new loot.

## 1. Catches 1 and 2 are hits, not deaths

When a catch leaves the player at least one life:
- **The grab:** the Manager's grab and the snap stay as today. The root is anchored for `SNAP_SECONDS`, with the catch camera and the lights-out beat.
- **No death:** the player is **not killed**. They are thrown with the same launch as today (`OccupantCatchRules.launch`), ragdolled for about **1 second**, then stand up where they landed.
  - Use a recoverable knockdown, like the cargo slip (`PlatformStand` plus an impulse, then `GettingUp`), not Death's one-way ragdoll.
  - The body never goes through walls or the floor while thrown.
  - Movement, the vacuum and interaction are blocked while down, and restored when up.
- **What's skipped:** no `caughtUntil`, no CatchReport/CCTV panel, no rehire card, no "back in" timer, no 8 s respawn.
- **Life and stats:** they lose one life, and the hearts update. The catch still counts in the roster (`noteCatch`), and the crew toast reads that they were caught, without the "back in" time.
- **Safe window:** the existing 10 s Manager grace after a catch keeps applying, so the player can run.
- **Hiding:** a player who was hidden when caught is evicted as today, then hit.

The third catch is unchanged from the built lives feature: killed (the ragdolled body stays where it fell, with the respawn held), spectating, "OUT FOR THE SHIFT", OUT on the roster, the crack VFX. **Verify in play that the knocked-out body stays where it fell.**

## 2. Hearts replace the dots

- **Icons:** uploaded and owner-approved, owned by Icey Labs group 189923277. The source is Figma "Cleanup Crew — UI (for approval)" › Style › "Lives hearts (for approval)".
  - `heart`: image `rbxassetid://75866312534437` (decal 106230225187259)
  - `heart_gloomed`: image `rbxassetid://85905766239276` (decal 89088085486181)
- **Wiring:** register both in `UIAssets.toonIcons` (`heart`, `heartGloomed`) and in the `ToonIcon` name union.
- **Drawing:** the crew-row lives and the local HUD lives draw `livesMax` hearts. The first `lives` are `heart` and the rest are `heartGloomed`. They replace the circles in `ShiftLivesPips`.
- **Sizes:** 20 px on phone, 28 px on desktop; never smaller than 20 px. The existing layout specs (the name gets at least 60 px, no overlaps) must keep passing at the new sizes.
- **Losing a heart:** the existing loss pop applies to the heart that turns gloomed.

## 3. Overtime brings new loot, and only that pays ×1.5

- **The new batch:** when the stage turns to `"overtime"`, Office spawns a new batch of valuables. That's about half the shift's normal valuable count (`OVERTIME_LOOT_SHARE = 0.5`, rounded, at least 1). The batch uses spots the shift's first roll didn't use and the same spawn rules (`OfficeSpawnRules`) and kinds as normal valuables.
- **Marking:** each overtime item carries an attribute (`OvertimeLoot = true`), set at spawn through `CargoServiceServer:spawnItem` / `CargoSpawnSystem`. It travels into the deposit (`DepositItem.overtime: boolean?`) through `CargoBankRules`.
- **Banking:** pay applies `OVERTIME_SALVAGE_MULTIPLIER` (1.5) only to items with `overtime = true`. Everything else pays ×1, even when banked during overtime.
  - Today's multiplier argument (`ShiftPhaseRules.salvageMultiplier`) is replaced by the per-item flag.
  - The `overtimeSalvage` stat (rank XP, the review cue) counts overtime items banked.
- **Look:** overtime items get a subtle gold shimmer, a light sparkle on the item using existing VFX/Toon sparkle assets, visible to everyone. Nothing on characters.
- **Once only:** one batch per shift. Overtime can only start once, so no repeats.

## Not in scope

- Currencies and pay. That's a separate design, reusing the week-1 currency design.
- Changing the Manager's AI, the grace length, the overtime warning time, or the quota.
- Sounds beyond what the knockdown and the sparkle already use.

## Anti-goals

- A catch with lives left that kills you, shows the CCTV screen, or makes you wait.
- Items that were already in the office paying ×1.5.
- Hearts drawn on the character.
- Calling it done on specs alone. Done is the owner's 2-player play-check, below.

## Left to the builder

- Where the knockdown lives: a small, reusable knockdown in the base Death or Carry feature, or in Occupant. It must follow `docs/project-structure.md`, and be specced where it's pure.
- How the client and the server agree on the knockdown. The server must own the hit; network ownership and replication follow the cargo slip's pattern.
- Where exactly the overtime batch is rolled, as long as Office owns spawning.

## Verification

1. **Specs:**
   - the hit decision: a life left → knockdown; the last life → knock-out;
   - the pay maths per item flag;
   - the overtime batch size and spot choice;
   - the heart view models and layouts.
2. **Controller 2-player check, with screenshots:**
   - catch 1 → thrown, up in about 1 s, one gloomed heart, no CCTV;
   - catch 2 → the same;
   - catch 3 → out, and the body stays where it fell;
   - start overtime → new shimmering items appear; bank one overtime item and one old item, and check the pay difference.
3. **The owner's play-check.**
