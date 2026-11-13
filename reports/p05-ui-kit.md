# P0.5 UI kit, clipboard, old Pippa icons (2026-11-13)

Session: p05-ui-kit. Launch List rows `p1-old-pippa-art`, `p1-ui-kit`, `p1-clipboard`.

Review page with picks: https://claude.ai/artifact/Jt3mAQxL3rHkEYkXHrCM31 (db collection `picks`, one doc per card id).

Work files (outside the repo, next to the other sessions' notes):
`C:/Users/Bruk Abu/AppData/Roaming/Claude/side-session-notes/local_563d59fb-00af-49e0-842b-041a39c00a94/p05-ui-kit/`
- `gpt/` prompts, raw sheets, `cut/`, `icons/` (256 px, ink outline, iconize.py), `icons_preview.jpg`
- `clipboard/clipboard.html` (mock-ups) + rendered JPGs
- `current/current_icons.png` (today's repeated icons)

## 1. Old Pippa icons (`p1-old-pippa-art`)
- Where they are: `UIAssets.toonIcons.pippaHappy` (83422913842035) and `UIAssets.toonPhotos.pippaSaluteCut`
  (77407692720114). Every use reads the name, so the swap is two id edits in
  `src/ReplicatedStorage/Client/Features/UI/Data/UIAssets.luau`:
  ChatWheelButtons (Emotes), DepotBoardViewModel (CREW chip), InventoryCrewPanel (hire silhouette),
  InventoryViewModel (Crew tab), ShopViewModel (Skins tab), ShiftReviewPanel (empty award card).
- Status: waiting for a Studio slot to render today's Pippa (Edit mode, temp model, posed wave + salute), then
  cutout.py + iconize.py, then the owner's OK, then upload to Icey Labs.

## 2. Icon / UI kit options (`p1-ui-kit`)
Built as an HTML review page because the Figma Desktop Bridge plugin was not connected (figma-console reports no
file). The same options can be mirrored to a Figma page once the plugin is open.
- New icons (GPT sheets in the owner-approved pipeline, then cutout + iconize ink): shop (stall, bag, register),
  featured (spotlight, ribbon, megaphone), daily (lunchbox, calendar tick, lunch bag), packs/stickers (foil pack,
  sticker sheet, speech sticker), inventory (backpack, gym bag, box), locks by reason (price tag, rank lanyard,
  key ring), Let's Go foot without stars (streaks, dust cloud, hop arcs).
- Sparkle replacement: one picture swaps every star. The stars come from three assets only:
  `UIAssets.toon.sparkle` (ToonSparkle: rewards, reveal/hire, toasts, rarity frames, CTAs),
  `UIAssets.toon.patternSparkle` (every cream panel, `pattern = "sparkle"`, 18 uses) and `VfxAssets.TEXTURES.star`
  (world VFX: Bubble Buddy pop, ability, cargo, vacuum, truck pop, occupant, employee). Options: clean "ting",
  soap bubbles, Gleam chip; pattern: dots, bubble rings, plain.
- Colour: "each screen its own colour" rule (Shop mint, Inventory sky, Clipboard coral, Settings night, Guide gold).
- Repeat audit: `shopGift` is on Shop tab/topper, Featured tab, chat-wheel Stickers, Inventory chat-wheel tab, Locker
  panel, Reveal, product art fallback, Inventory character panel; `gift` on the hub daily gift and the daily sign.
  `lockNight` on Inventory crew/character, Pick, ToonSourceBand; `lock` on the depot board.

## 3. Company clipboard (`p1-clipboard`)
Today: `DepotTimecardPanel.luau` (620x390, Timecard + Today's Job faces). Concepts:
- A: tabs kept; Timecard = 5-punch track with the prizes hung on punch 3 and 5, big PUNCH IN!, paycheck as 4 dots;
  Today's Job = big task words + bar + reward chip + time chip.
- B: both sheets on one coral clipboard, no tabs (phone version too).
- Words cut: week code, UTC, "missed days keep your punches", "filled weeks" lines.

## Waiting on
- Owner picks on the review page (cards 2-5).
- A Studio slot for the Pippa renders.

## Not done
- Nothing built in game yet (all three rows need the owner's yes first). No uploads.
