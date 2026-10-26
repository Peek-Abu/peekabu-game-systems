# Odd Hours: Character, Skin & Locker Polish / Art / Implementation Backlog (2026-10-25)

Consolidated roadmap of everything remaining after Character Steps 1–5, Vacuum Cosmetics, Lost & Found Lockers (Stages 1 & 2), and Rank Lanyards v6.

---

## 1. Code-Ready Polish & Systems

### 1.1 Hovered Grid Cards = Live Animated Previews
- **Design reference:** `docs/superpowers/specs/2026-10-24-odd-hours-character-systems-design.md` §7.
- **Current state:** Grid cards in `InventoryCharacterPanel`, `ShopScreen`, and `LockerPanel` render static posed viewports (`EmployeePreviewSystem.static`), while only the central hero viewport uses a live animated `WorldModel`.
- **To build:**
  - Wire hover/selection state on grid cards to claim the second live slot in `EmployeePreviewSystem` (`LIVE_CAP = 2`: 1 hero + 1 hovered card) and play the item's idle/emote loop while hovered.

### 1.2 Shop & Locker Economy Analytics
- **Current state:** `ShopServiceServer` and `LockerServiceServer` log audit lines (`SHOP_BOUGHT`, `LOCKER_OPENED`, `LOCKER_DIRECT_BOUGHT`) and `CurrencyServiceServer` / `MarketplaceServiceServer` fire `changed` / `premiumChanged`, but direct `premiumOp` / `currencyOp` transaction legs inside Shop and Locker purchases should also emit economy sink events (`reason = "shop"` / `"locker"`) so telemetry dashboards track per-offer and per-locker spend.

### 1.3 Admin / Playtest Commands (`LockerGiveKey`, `PolicyRestricted`)
- **To build:**
  - `lockergivekey <player> <gloom|gleam> <amount>` — calls `LockerServiceServer:addKeys(player.UserId, locker, amount)`.
  - `policyrestricted <player> <true|false|clear>` — calls `PolicyServiceServer:setRestricted(player.UserId, flag)` and re-sends `LockerEvents.packets.Status` so restricted direct-purchase UI can be toggled live in Studio.

### 1.4 Shift Place (`Odd Hours: Shift`, `118845637680835`) Sync
- **To do:**
  - Copy `ReplicatedStorage.Assets.CleanupCrew.Characters.Cappy`, `Prickles`, and the v6 `Lanyards` / `BadgesInfo` assets into `Odd Hours: Shift` so all employees, skins, vacuums, emotes, callouts, and v6 rank lanyards work identically inside shifts.

---

## 2. Content & Owner Decisions Needed

### 2.1 Gleam Locker Item Pool
- **Where:** `src/ReplicatedStorage/Shared/Features/Cosmetic/Data/CosmeticRegistry.luau`
- **Current state:** `Gloom Locker` has 6 items (`source = "gloomLocker"`). `Gleam Locker` (`source = "gleamLocker"`) currently has 0 items, so its card shows `"Coming soon"`.
- **Action needed:** Tag existing or new Rare / Epic / Legendary skins, idles, emotes, or vacuums with `source = "gleamLocker"`. `LockerRules` and `LockerViewModel` automatically compute the real scaled odds and pity threshold (`ceil(1.5 / epicPlus)`) as soon as items are in the pool.

### 2.2 Shop Sale Prices, Event Windows & Passes
- **Where:** `ShopRegistry.luau` / `ShopConstants.luau` / `ShopViewModel.luau`
- **Action needed:**
  - Set `was` prices on discounted offers once final pricing is chosen.
  - Set `startsAt` / `endsAt` UTC timestamps on limited/event offers.
  - Define gamepasses in `MarketplaceRegistry` to enable the Shop's **Passes** tab.

---

## 3. Animation & Audio Assets to Wire

### 3.1 Custom Idle & Emote Clips In-Game and in Previews
- **Where:** `AnimationEmoteRegistry` / `AnimationEmployeeRegistry`
- **Current state:** Equipped idles and the 4 emote wheel slots per employee are saved and replicated, and `EmoteServiceServer` validates and plays any emote with a registered clip. Currently emote clips are pending upload, so wheel slots show `"Soon"`.
- **Action needed:**
  - Upload and register animation asset IDs for:
    - Defaults: `Pippa.Wave`, `Cappy.FistBump`, `Prickles.Huff`
    - Legendaries: `Pippa.Bubbles` (with bubble wand prop), `Cappy.CocoaSip` (with mug prop), `Prickles.Lasso`
    - Shared / custom idles: `SleepySway`
  - Wire `EmployeeLocomotionUtils` / `EmployeePreviewSystem` to play the equipped cosmetic idle clip when its asset ID is registered.

### 3.2 Reveal Rarity Audio Stings
- **Where:** `SoundRegistry.luau` / `UISoundSystem.luau` / `RevealScreen.luau`
- **Action needed:** Produce and upload 5 rarity stings (`uncommon`, `rare`, `epic`, `legendary`, `odd`) + `hire` sting and trigger the matching sting when `RevealScreen` mounts.

---

## 4. 3D Character Skins & 2D Sticker Art

### 4.1 Employee Skin Palettes & Fitted Accessories
- **Where:** `EmployeeRegistry.luau` (`skins` table per employee) + `ReplicatedStorage.Assets.CleanupCrew.Accessories`
- **Skins awaiting palette texture IDs / accessory models:**
  - **Pippa:** `BubbleBuddy` (Legendary, 3 styles), `GloomTouched` (Uncommon), `Gloomkeeper` (Epic)
  - **Cappy:** `PJ` (Legendary, 3 styles), `GloomTouched` (Uncommon), `GhostDebunker` (Epic)
  - **Prickles:** `Sheriff` (Legendary, 3 styles), `GloomTouched` (Uncommon), `PotKnight` (Epic)

### 4.2 Sticker Pack PNG Sheets
- **Where:** `UIAssets.luau` / `CalloutConstants.luau`
- **Action needed:** Upload the 512×512 ink-outlined transparent PNGs for `CozyPack`, `BubblePack`, `SheriffPack`, and `GloomPack` and replace the temporary kit-icon stand-ins.
