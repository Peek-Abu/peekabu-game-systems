# Character systems step 3: first-join pick, Inventory (Crew + character page) — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: superpowers:executing-plans. Steps use checkbox (`- [ ]`) syntax.

**Status:** approved by the owner 2026-10-24 (calls 1, 2, 3, 5 yes; call 4 changed: the Styles row shows only for skins that have more than one style). Every screen is data-driven: employees, skins and items come from CosmeticRegistry / EmployeeRegistry / EmployeeProfileRegistry; nothing is per-character in the UI code.

**Goal:** A new player picks their employee on first join; anyone in the depot opens **Inventory** to see the crew,
open an employee's page, look at every skin (owned, buyable, earnable, missed, later) and wear one. What you wear
changes on the spot (step 2's swap). Look and layout follow the round 3/4 Figma concepts, built in the V1 Toon kit.

**Not in this step:** the Shop (buy buttons say "In the Shop soon"), Emotes tab and chat wheel (step 5), reveals (step 4),
colour-style art, Cappy (parked).

## What the player sees

### 1. First-join pick (hub only, once)
- Opens by itself after the load screen when `loadout.picked == false` and the player is in the depot.
- Full screen, tinted in the selected employee's colour (Pippa coral, Cappy mustard, Prickles cactus green),
  diagonal stripes, rays behind the hero.
- Left: one card per employee (head render breaking the card's top). Pippa "Free!"; Prickles (and Cappy when back)
  show their Credits price and padlock C. Selecting a locked one previews it but the button says "Hire in the Shop
  soon" (buying is step 4).
- Middle: the selected employee **live** on a platform (idle loop playing), name plate under.
- Right: About card (bio, 5 stat bars with the GPT stat icons, ability card with its cooldown).
- Bottom right: big mint **Start as Pippa!** → sends the pick; the screen closes when the loadout says picked.
- No close button (you must pick once). Returning players never see it.

### 2. Inventory (replaces the hub's LOCKER button; label becomes INVENTORY)
Top bar like the concepts: Inventory title, tabs **Crew** · **Vacuums** · **Chat wheel** (Chat wheel greyed "Soon"),
Credits + Gleam wallets, close. Vacuums = today's Locker/gear page content, unchanged, moved under this tab.

**Crew tab:** a card per employee, filled with their colour:
- the employee **posed in the skin they currently wear** (static viewport), skin name on a small flag;
- name, kind line, ability chip;
- buttons by state: **Wearing** (greyed) + **Skins** · **Equip** + **Skins** · locked: price + **Look**;
- a "???" card for the next employee (goo drip, "Coming soon").
- No skin counts (owner).

**Character page** (opens from Skins / Look): tabs **Skins · Idles · About** (Emotes added in step 5); back button to Crew.
- Left: grid of cards (2 columns, scrolls), each a static posed viewport on its rarity stage, rarity flag, name, and
  the **source band in the card footer** (gold = Gleam price, night = Gloom Locker, mint = goal, grey = missed it);
  owned cards have no band (the worn one gets a mint "Wearing" band). Locked art is darkened with padlock C.
  Rarity frames: Epic stripes + rim, Legendary foil sweep + gold halo + sparkles, Odd red glow + goo.
- Middle: the selected item **live** (WorldModel, idle loop), platform, rays in the rarity colour.
- Right panel: rarity + New! flags, name, a line under it, the **lore quote**, **Styles** row (shown, disabled with
  "Coming soon" until style art exists), **Comes with** row (bundle items), main button by state: **Wear** /
  **Wearing** / **In the Shop soon** / **Gloom Locker** / **Missed it** / **Coming later**.
- Idles tab: same layout; idles you own can be worn per employee (saved now; the idle animation itself plays once
  idle clips exist, until then it previews the employee's own idle).
- About tab: who they are, 3 personality words, fun fact, ability card, stat bars, "Every employee can finish every
  job, even alone."

Phone (844x390): the same screens in the concept's phone layouts (pick: heads column + hero + compact info; character
page: grid of 4x2 small cards + hero + a compact detail bar).

## How it is built
- **Data (shared):** `EmployeeProfileRegistry` (Employee/Data): per employee the kind line, 3 words, bio, fun fact,
  ability (name, one-liner, cooldown text) and display stats 1–5. Display only: no gameplay reads it until the stat
  and ability systems exist. Kid-reading-level copy from the requirements doc (owner can edit the file).
- **Skins for any player's preview (client):** the skin dressing (palette, faces, accessories) moves from the
  server-only `EmployeeSkinSystem`/`EmployeeGearSystem` to shared `Systems` so the client can dress a preview model the
  same way the server dresses a character (one code path, no drift). Server behaviour unchanged.
- **Previews (client):** `EmployeePreviewSystem` builds a dressed preview model per (employee, skin) from the art in
  ReplicatedStorage and keeps it pooled. Two kinds:
  - **static** (cards): posed once, anchored, no Animator (as CharacterPortrait does: costs about one image);
  - **live** (hero only): in a `WorldModel` with an Animator playing the employee's idle loop.
  At most **2 live previews at once** (pick/page hero + one hovered card); none outside the depot.
- **UI (React, V1 Toon kit):** new Toon pieces `ToonViewport` (frames a preview, rarity stage background), `ToonFlag`
  (notched flag), `ToonSourceBand` (card footer band), `ToonRarityFrame` (tier extras). Screens `CharacterPickScreen`,
  `InventoryScreen` (tabs; Crew panel; character page panel), each with a ViewModel (pure, specced: card states,
  button states, tints, layout) and a UI Labs story. All drawn through `PaperHudFrame` at the game's one UI scale, text
  ≥ 16 px desktop / 12 pt phone, touch targets ≥ 44 px, clear of Roblox's top-left buttons.
- **Actions:** Equip / Wear → `CosmeticServiceClient:requestEquip`; Start → `requestPick`. The screen shows the
  result from the synced loadout (no optimistic change).
- **Hub button:** LOCKER → INVENTORY, opens Inventory on the Crew tab.

## Uploads needed (one batch, Icey Labs group 189923277, your OK required)
- Padlock C icon; the 5 stat icons (sneaker, bolt, arm, nozzle, sock); the deal burst is drawn with frames (no upload).
  6 PNGs, 256 px, from `characters/ui/character-ui/art/`.
- Until approved, cards use a grey placeholder square labelled "icon".

## New modules
| Feature | Realm | Subfolder | Name | Job |
|---|---|---|---|---|
| Employee | shared | Data | EmployeeProfileRegistry | bio, words, ability, display stats per employee |
| Employee | shared | Systems | EmployeeSkinSystem, EmployeeGearSystem (moved from server) | dress a model in a skin |
| Employee | client | Systems | EmployeePreviewSystem | pooled static/live preview models |
| UI | client | Screens/Toon | ToonViewport, ToonFlag, ToonSourceBand, ToonRarityFrame (+stories) | kit pieces |
| UI | client | Screens/Inventory | InventoryScreen, InventoryCrewPanel, InventoryCharacterPanel, InventoryViewModel, InventoryScene (+story, spec) | Inventory |
| UI | client | Screens/Pick | CharacterPickScreen, CharacterPickViewModel, CharacterPickScene (+story, spec) | first-join pick |

## Tasks (each: spec → implement → typecheck → commit)
1. EmployeeProfileRegistry (+spec: every employee has a profile, stats 1–5, copy non-empty).
2. Move skin/gear dressing to shared Systems; server imports updated; suite green.
3. EmployeePreviewSystem (+spec on fake art: dressed clone, static is anchored with no Animator, live has Animator,
   pool reuse, live cap of 2).
4. Toon kit pieces + stories.
5. InventoryViewModel (+spec: card state per item from catalog/ownership/loadout; button state; source band; tint).
6. Inventory screens (Crew, character page Skins/Idles/About), hub button → INVENTORY, Vacuums tab = old gear page.
7. CharacterPickViewModel (+spec) + pick screen + auto-open when not picked.
8. Studio: suite green; screenshots of every screen on desktop and phone sizes; play: pick → Inventory → wear Lavender
   Specs (swap) → back; report with screenshots for your look/layout/rules check.

## Calls for you to check
1. Inventory **replaces** the LOCKER button (Vacuums becomes a tab inside it).
2. First-join pick has **no close button** (Pippa preselected; one tap to start).
3. Locked employees can be previewed in the pick screen but not hired until the Shop exists (step 4).
4. Styles row is visible but disabled ("Coming soon") until style art exists.
5. The 6 icon uploads above (one approval).
