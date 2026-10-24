# Character systems step 1: cosmetic catalog, loadout save, server rules (2026-10-24)

Plan: `docs/superpowers/plans/2026-10-24-character-step1-cosmetic-data.md`. Design (approved, updated with the
as-built note): `docs/superpowers/specs/2026-10-24-odd-hours-character-systems-design.md`.

## What exists now
- **Cosmetic feature** (shared Data/Rules/Net, server service, client facade):
  - `CosmeticRegistry`: Pippa (free), Cappy and Prickles (2,500 Credits each, placeholder); each employee's free
    Classic skin, idle and default emote; the release Legendaries (Bubble Buddy, PJ Cappy, Sheriff Prickles; 3 styles,
    bundles of prop emote + sticker pack, plus Sleepy Sway with PJ Cappy); the Gloom-Touched and Gloom Epic skins;
    the owner's Lavender Specs as a gift; Sleepy Sway; three sticker packs of three stickers. Lore lines are drafts.
  - Ownership = the existing `entitlements` slice (each item registered under its kind). Free defaults are never
    stored. A sticker is owned through its pack.
  - New account slice `loadout`: current employee, first-join `picked`, per-employee look (skin + style, idle, 4-slot
    emote wheel), 4 sticker slots, `seen`. Validated by structure only; anything retired or no longer owned falls
    back to that employee's default when read.
  - `CosmeticServiceServer`: `equip`, `pick` (once), `grant` (item + bundle, one transaction), `grantOps` (for a
    Shop purchase's transaction), `lookOf`, `currentEmployee`, `owns`, `isLocked` (Shift phase is not "lobby"),
    `changed` signal (deferred, SignalPlus), rate-limited `EquipRequest` / `PickRequest` packets.
  - Admin commands: `cosmeticgrant <player> <id>`, `cosmeticequip <player> <kind> <id> [number] [employee]`.
- **Vest removed** from Pippa's uniform; the rank lanyard stays (commit f3f533ac).

## Verified
- Full TestEZ suite in the hub window (RunTests): **4576 passed, 0 failed** (first run had 3 failures, all in the new
  specs: the `changed` signal is deferred, and stickers have no price of their own; both fixed in 2ba86430).
- Play (services up) through the command handlers on icemonkey1: unlocked Cappy and PJ Cappy (a second PJ grant
  said "already owned"), switched to Cappy, wore PJ Cappy style 2, put Cocoa Sip in wheel slot 2; refused Sheriff
  Prickles ("not owned") and Pippa's idle on Cappy ("wrong employee"). The client's synced loadout matched:
  current Cappy, PJ Cappy style 2, wheel Fist Bump | Cocoa Sip, owns Cappy and the Cozy Pack stickers.
- Studio left clean: no injected scripts, RunTests off, test attributes cleared, hub lock removed.

## Not done / next (step 2)
- Nothing visible changes in play yet: the character still spawns from the shared StarterCharacter. Step 2 builds
  each player's character from `currentEmployee` + `lookOf` (spike findings: un-anchor, respawn through the
  builder), swaps in place with a goo puff on `changed`, adds Cappy and Prickles to EmployeeRegistry (their uploaded
  locomotion clips; footsteps routed to Pippa's set via the `FootstepSet` attribute until they have their own) and
  replaces `EmployeeSkinRegistry` (the owner skin becomes `Pippa.OwnerSpecial`, granted with `cosmeticgrant`).
- Pre-existing type errors seen while checking (not from this work): `OfficeLayoutUtils` (Vector3 vs nil),
  `OfficeOozeSystem` (union call), `AnomalyServer` (string vs anomaly id union).
- The Rojo plugin in the "Odd Hours: Shift" window is not syncing (it holds the branch from before today).
