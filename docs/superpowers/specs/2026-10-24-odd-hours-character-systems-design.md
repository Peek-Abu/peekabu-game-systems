# Odd Hours: character systems (pick, spawn, Inventory, skins, Shop, reveals)

Status: **approved by the owner 2026-10-24** (with the changes below). Build starts with step 0.
Concepts: Figma "Cleanup Crew — UI (for approval)" → page "Character UI" (rounds 1–4). Sources:
`characters/ui/character-ui/` (`char3.html`, `char4.html`). Requirements: `characters/launch/new-employee-requirements.md`.

## Why

Today every player in a server spawns as the same Pippa (one shared `StarterCharacter`), skins are a hard-coded
owner list (`EmployeeSkinRegistry`, MVP only), and there is no way to own, pick, wear or buy anything. Before a second
employee (Cappy, Prickles) is playable, the game needs: saved ownership, each player spawning as their own pick,
an Inventory to change it, a Shop to buy it, and reveals when you get something.

## Decisions already made (owner)

- First join shows a pick screen; only Pippa is free, the others cost Credits (price may change).
- Changing employee or skin in the depot swaps you **in place with a goo puff**, no respawn trip.
- Your look **locks when the truck leaves**; Inventory is greyed out during a shift.
- The wardrobe is **Inventory** (tabs Crew, Vacuums, Chat wheel). The key boxes stay **Gloom Locker / Gleam Locker**.
- Crew → a **Character page** per employee (Skins, Emotes, Idles, About). Every skin, emote and idle has a short lore line.
- A not-owned item has one button that opens its **Shop product page**.
- **Skins, emotes and other "worn" shop items are shown in ViewportFrames with live models**, never flat images, so
  they can pose and animate. Cards show the item **posed with its props**; hover/select plays the animation.
- Rarity ladder, tier bundles, release skins: as in the requirements doc. Odd is red; Odd skins are after launch.
- Stickers are expressives on the chat wheel, next to free pings.

## Goals / non-goals / anti-goals

Goals: each player plays as their own employee + skin + idle in the hub and in shifts; owning, equipping and buying
are server-authoritative and saved; the UI matches the approved concepts closely in look, not pixel for pixel.

Non-goals (this build): Odd skins, mastery tracks, trading (never), gifting, a battle pass, vacuum skins rework,
voice barks.

Anti-goals: anything that changes stats through a cosmetic; a pick or swap that can be done mid-shift; client-written
ownership; pay-to-win; UI that costs frame rate in a shift (no live viewports during a shift).

## How it works

### 1. One catalog: `CosmeticRegistry`
Every ownable thing is one entry, looked up by id: `kind` (employee, skin, style, emote, idle, stickerPack, sticker),
`rarity`, `employee` (nil = works on everyone), `source` (default, credits, gleam, gloomLocker, gleamLocker, goal,
event, later), `price`, `lore` (one line, kid reading level), `bundle` (ids it includes), and the asset ids it needs.
`EmployeeRegistry` keeps the rig facts (template, scale, faces, locomotion, uniform) and points at catalog ids; skins
move into the catalog. `EmployeeSkinRegistry` (the MVP owner list) is deleted; the owner's skin becomes a granted item.

### 2. Saved data: one account slice `cosmetics`

> **As built in step 1 (2026-10-24), changes from the sketch below:** ownership is the existing account slice
> `entitlements` (each CosmeticRegistry item registered under its kind; Marketplace purchases already grant through
> `EntitlementServiceServer:grantOp`, so paying and unlocking stay one write), so there is no `owned` map. The new
> account slice is named `loadout` (current, picked, looks with per-employee idle and emote wheel, stickers, seen).
> Free defaults are never stored. No migration: existing players see the first-join pick once (Pippa preselected).
> Plan: `docs/superpowers/plans/2026-10-24-character-step1-cosmetic-data.md`.
```
owned   = { [itemId] = true }                 -- everything you own (employees, skins, emotes, ...)
current = "Pippa"                             -- employee you play as
looks   = { Pippa = { skin = "Default", style = 1, idle = "PippaClassic", wheel = { "Wave", nil, nil, nil } }, ... }  -- per employee, incl. the 4 emote slots
stickers= { "CozyCocoa", nil, nil, nil }       -- 4 sticker slots on the chat wheel
seen    = { [itemId] = true }                 -- for the New! flag
picked  = false                               -- has done the first-join pick
```
Account-wide (not slot), so the hub and shift places read the same thing. The slice validator rejects anything
not in `owned`, an employee you don't own, an emote on the wheel you don't own, and unknown ids (old saves keep
working: unknown ids are dropped, missing looks fall back to defaults). Migration: existing players get
`owned = { Pippa, Pippa/Default, + defaults }`, `picked = true` (they already played), and the owner keeps OwnerSpecial.

### 3. Server API (`CosmeticServiceServer`)
`equip(player, change)` (employee, skin, style, idle, wheel slot, sticker slot), `pick(player, employee)` (first join),
`grant(player, ids, source)` (shop, lockers, goals; idempotent per receipt), `buy(player, offerId)` (spends Gleam or
Credits in one PlayerData transaction with the grant, so you can never pay and not get it). Every call is checked on
the server: owned, allowed, **not during a shift** (shift place: always refused), rate-limited. Net: ByteNet
request/response packets. State for the UI rides the charm-sync spine (your own `cosmetics` mirror; other players'
current employee/skin as public fields for crew lists and portraits).

### 4. Each player spawns as their own employee (needs a spike first)
The shared `StarterCharacter` cannot serve different employees. Plan: `CharacterAutoLoads` is already off (Death owns
respawns), so Employee builds the character itself: clone the employee's prepared template, apply skin + style +
idle + uniform, copy `StarterCharacterScripts`, set `player.Character`, place it at the spawn point. Death's respawn
calls this instead of `LoadCharacterAsync`. **Spike first (half a day):** prove a manually assigned character keeps
everything that works today (Animate, carry IK, tools/vacuum, ragdoll, spectate, camera, voice, Hide, proximity
prompts, network ownership) on a 2-client test server. If the spike fails, fallback B: keep `LoadCharacterAsync` and
swap `StarterPlayer.StarterCharacter` per spawn under a server lock (simpler, slower, more fragile); I'd come back to you
before using it.

**Swap in place:** equip in the depot → server builds the new character at your current position/facing, plays the
goo puff (Vfx) and the selection reaction, (swaps only happen in the depot, outside a shift, so there is nothing carried to keep).
**Shift place:** spawns you from `current` + `looks` at load; Inventory there is read-only.

### 5. First-join pick
Shown once (`picked = false`) after the load screen in the hub: Pippa free, others with their Credits price (buying
one here is allowed if you have the Credits). Pick → hire reveal → spawn. Returning players skip it.

### 6. Inventory UI (React, hub only)
Screens as in the concepts: Crew roster → Character page (Skins / Emotes / Idles / About) → buttons by state
(Wear, Wearing, See in Shop, Gloom Locker, Missed it, Coming later). Where to get an item is a coloured band in the card's footer (gold = Gleam, night = Gloom Locker, mint = earn, grey = missed), never an icon on the art. Locked items use padlock C (the night lock) for now; the owner wants a better "not owned yet" look later. Built from the Toon kit plus the new **Shop kit**
pieces (deal burst, notched flag, Owned stamp, struck price, timer chip, rarity frames, viewport stages by item type).
Phone layouts at 844×390. Locked during a shift (greyed, "Back at the depot").

### 7. Viewports: how skins, emotes and idles are shown
- **Hero preview** (character page middle, product page, reveal): `ViewportFrame` + `WorldModel` + the real character
  model with an `Animator`, playing its idle / emote / reveal clip on the client. Lit to the rarity, camera framed by
  a shared helper (the portrait code already does framing and posing).
- **Cards in grids**: `ViewportFrame` with a **static posed** copy (the card's own pose + props, posed once like
  `CharacterPortrait` does today, so it costs about one image). **Hover or select** swaps that one card to a live
  WorldModel and plays its loop.
- **Budget**: at most 2 live animated viewports at once (hero + hovered card); everything else static; no viewports
  at all during a shift. Models are pooled and rebuilt only when the item changes.
- **Stages per item type** (the background behind the model): skin on rarity rays, emote in a spotlight burst, idle in
  a cozy diorama, stickers on paper. Round 4 concepts show more options for you to pick from.
- Not viewports: Gleam bundles, lockers and other plain objects use rendered PNG icons (same pipeline as the stat icons).

### 8. Stickers and pings
- **Sticker art**: PNG images (512×512, transparent, ink outline, uploaded as decals to Icey Labs after your OK).
  Made like the icons (GPT render → cut-out → outline), one sheet per pack so a pack matches.
- **Animated?** Yes, by motion, not by frames: each sticker pops in over your head (scale bounce, wobble, then fade,
  ~2.5 s) in a BillboardGui, and shows in the crew list. Legendary packs may get a 4–6 frame flipbook later (one sprite
  sheet per sticker) if you want more.
- Stickers make no sound (safe while hiding). **Pings** are free, the same for everyone, make a small sound only your
  crew hears, and mark a spot in the world (Gloom here, Loot here, Manager!, Help me!, To the truck, Okay!).
- Both on one **chat wheel** (hold T on PC; a button on phones). Pings and the wheel are their own build step (Phase 4).

### 9. Shop
Data-driven offers (a `ShopRegistry` of offers: item ids, price, currency, discount, start/end time, flags such as
New!/Hot/Last day!), rotated by UTC time so every server shows the same shop. Featured banner, Today's picks, Lockers,
Gleam bundles (Robux developer products through the existing Marketplace receipts), product page with "what's
inside" and per-item prices. Buying runs `CosmeticServiceServer:buy` (one transaction). Lockers (odds, pity) are a
later step, not this build.

### 10. Reveals
One reveal screen, scaled by rarity: Uncommon is a quick card flip; Rare adds rays; Epic adds stripes, sparkles and a
louder sting; Legendary gets its own reveal clip with the prop, a foil sweep and confetti; employee hires play the hire
reveal clip. Shown after a pick, a purchase, a locker opening or a goal. "Wear it!" equips on the spot (in the depot).
Sounds per rarity from the sound plan.

## Build order (each step ends in an owner play-check)

| Step | What | You check |
|---|---|---|
| 0 | Spike: manual character assignment on a 2-client server | a short report + video: everything still works |
| 1 | Catalog + `cosmetics` slice + server API + migration (no UI; admin commands to grant/equip) | grant/equip in Studio, rejoin keeps it |
| 2 | Per-player spawn + swap in place + shift lock; add Cappy (v6/v7) and Prickles to the registry | 2 players, different employees, swap with goo puff, shift place spawns your look |
| 3 | First-join pick + Inventory Crew + Character page (Skins/Idles/About), viewports | the screens in play, PC + phone |
| 4 | Shop (offers, product page, buy with Gleam/Credits) + reveals | buy a skin, see the reveal, wear it |
| 5 | Emotes (wheel, playback) + stickers + pings (chat wheel) | use them in a shift with a 2nd client |

Uploads (character models, sticker decals, icons, animations) are batched and each batch waits for your OK; owner =
Icey Labs group.

## New modules (placement, per docs/project-structure.md)

| Feature | Realm | Subfolder | Name | Job |
|---|---|---|---|---|
| Cosmetic (new) | shared | Data | CosmeticRegistry | the catalog of every ownable item |
| Cosmetic | shared | Data | CosmeticTypes | item, loadout and offer types |
| Cosmetic | shared | Rules | CosmeticRules | may this player own/equip/buy this now |
| Cosmetic | shared | Net | CosmeticNet | equip / pick / buy packets |
| Cosmetic | server | (root) | CosmeticServiceServer | owns the `cosmetics` slice, equip, pick, grant, buy |
| Cosmetic | client | (root) | CosmeticServiceClient | requests + the local mirror |
| Employee | server | Systems | EmployeeCharacterSystem | builds and assigns a player's character (replaces the shared StarterCharacter path) |
| Employee | server | Systems | EmployeeSwapSystem | swap in place + goo puff |
| Employee | client | Systems | EmployeePreviewSystem | live/static preview models for viewports (pooled) |
| Shop (new) | shared | Data | ShopRegistry | offers, prices, discounts, times |
| Shop | shared | Utils | ShopRotationUtils | which offers are live at a UTC time |
| Shop | server | (root) | ShopServiceServer | serves the live shop, runs buys through Cosmetic |
| Shop | client | (root) | ShopServiceClient | live offers for the UI |
| UI | client | Screens/Inventory | InventoryScreen, InventoryCrewPanel, InventoryCharacterPanel (+ ViewModels, stories) | Inventory screens |
| UI | client | Screens/Shop | ShopScreen, ShopProductPanel (+ ViewModels, stories) | Shop screens |
| UI | client | Screens/Reveal | RevealScreen (+ ViewModel) | pick / hire / purchase reveals |
| UI | client | Screens/Toon | ToonBurst, ToonFlag, ToonStamp, ToonPrice, ToonViewport (+ stories) | the Shop kit pieces |

Two new features (Cosmetic, Shop) and no new subfolder kinds or role words. Pings/stickers (step 5) get their own
rows when that step is planned.

## Left to the builder
Exact pixel layout (match the concepts' look and hierarchy, not their coordinates), animation timings, lighting of
viewports, ids and names of catalog entries, and how the offers rotate inside a day.

## Calls I made (check these)
1. Two new features, **Cosmetic** (ownership + loadout) and **Shop** (offers + buying), instead of growing Employee.
2. Idles are per employee in `looks` (owner: yes).
3. The emote wheel is per employee too (owner); the 4 sticker slots stay account-wide (my call).
4. Grid cards are static posed viewports; only the hero and the hovered card animate (performance on phones).
5. Plain objects (Gleam, lockers, sticker packs) use PNG icons, not viewports.
