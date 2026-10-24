# Character systems step 2: each player spawns as their own employee; swap in place (2026-10-24)

Plan: `docs/superpowers/plans/2026-10-24-character-step2-spawn-and-swap.md`.

## What changed
- **Death** (base-shaped, needs its own base PR later): `setCharacterLoader(loader)` (joins and respawns call it instead
  of LoadCharacterAsync) and the `KeepPlace` character attribute (the spawn point leaves such a character where it was
  put). Rule `DeathRespawnRules.keepsPlace`.
- **EmployeeCharacterSystem** (new): prepares each employee's art once (rig attachments, Animator, scale 1.25,
  every part un-anchored, overhead display off, HipHeight fitted when the art says 0), builds a fresh character per
  spawn (name, footstep set, character scripts), assigns it.
- **EmployeeServiceServer**: is Death's loader (waits up to 5 s for the loadout, builds the loadout's employee, falls
  back to Pippa when a place has no art for it); dresses the character in the loadout's skin; on a loadout change in
  the depot rebuilds the character where it stands, marked for the puff. `EmployeeSkinRegistry` (MVP owner list)
  deleted: the owner's look is now the item `Pippa.OwnerSpecial`.
- **Cappy and Prickles** registered: their uploaded idle/walk/run/crouch clips and measured planted speeds, Pippa's
  face map, scale 1.25, `uniform = {}` (no rank lanyard fitted to their bodies yet), Pippa's footsteps
  (`FootstepSet = "pippa"`), Pippa's ID photo as a marked PLACEHOLDER portrait.
- **Goo puff**: `employeeSwapGoo` burst (purple goo ring + gold stars) on every client when a swapped character
  appears.
- Portrait fallback photo now takes a skin key (no per-user owner list).

## Verified (hub window)
- Full suite: **4589 passed, 0 failed**.
- Play, through the admin command handlers:
  - spawned via the builder as Pippa;
  - `employee Cappy` → Cappy appeared exactly where Pippa stood (0 studs), EmployeeSwap set, nothing anchored, hip
    height fitted (0.13), footsteps set to pippa; walks (MoveTo 7.3 studs), his walk clip at the 2.5x cap while
    moving and his idle when still; camera follows; HUD portrait switched to him (`reports/step2-cappy-depot.jpg`);
  - `employee Prickles` → the purple goo puff at his feet (`reports/step2-prickles-goo-puff.jpg`);
  - Pippa + `Pippa.OwnerSpecial` → round glasses on, rank lanyard on, no vest;
  - killed → respawned as Pippa in the owner skin; as Cappy → respawned as Cappy.
- Studio left clean (no injected scripts, RunTests off, lock removed).

## Art-place changes made in Studio (save the hub place to keep them)
- `ReplicatedStorage.Assets.CleanupCrew.Characters.Cappy` added: a copy of `ServerStorage._WorkspaceArchive.Cappy_v6_NewHair`
  (v6 body, your new hair, the old shorts), `EmployeeName = "Cappy"`.
- Cappy's and Prickles' saved HumanoidRootPart un-anchored; Prickles' `EmployeeName` attribute set to "Prickles".
- **The shift place ("Odd Hours: Shift") still needs the Cappy model** (and its Rojo plugin reconnected): until then a
  player who picked Cappy spawns as Pippa in a shift (warned, falls back).

## Update: Cappy parked (owner, 2026-10-24)
Another agent is building a better Cappy, so the temporary Cappy copy was removed from the hub's Assets again (the
archived preview is untouched). His registry entry and clips stay: until his model lands in
`Assets.CleanupCrew.Characters.Cappy`, choosing him falls back to Pippa (warned in the log). The only art-place change
left to save in the hub is Prickles' un-anchored root and his `EmployeeName = "Prickles"`.

## Known / next
- On a swap the camera snaps to the new character's default angle (not where it was looking). Worth smoothing.
- Styles (colour variants) are saved but have no art; skins without art (the Legendaries, Gloom skins) fall back to
  Default when worn.
- Cappy still has the old shorts; the v7 skinned shorts are a later swap.
- Not tested: a second client watching a swap, voice and spectate on a built character, the vacuum wand in a live
  shift (owner play-check with 2 clients).
- Pre-existing checker errors untouched (Office, Anomaly, EmployeeServiceServer's RBXScriptConnection ~= nil lines).
