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
- Rendered 2026-11-13 in the Shift place (Edit only, coordinator's slot): a temp clone of
  `Assets.CleanupCrew.Characters.Pippa` (ModelVersion v13, Happy face, lanyard via
  `EmployeeLanyardSystem.attachPreview`), posed by Motor6D C0 (wave; salute at the brow side), temp lights and day
  Lighting, then the temp folder deleted and Lighting restored exactly. Not saved.
- Files: `p05-ui-kit/pippa/raw|cut|out` (`out/ic_pippa_happy.png` 256 px ink/white rim, `out/cut_pippa_salute.png`
  600 px ink/cream rim) and `pippa_old_vs_new.jpg`. The salute capture was small (444 px tall), so the 600 px cut is a
  little soft; recapture closer if the owner wants it sharper.
- Status: card 1 of the review page asks yes/no; on yes, upload both to Icey Labs and swap the two ids.

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
- The owner's yes on the Pippa renders (card 1).

## Not done
- Nothing built in game yet (all three rows need the owner's yes first). No uploads.

## Owner picks, round 1 (read 2026-11-13 from the review page db `picks`)
- Yes: featured A (spotlight), daily B (calendar tick), stickers = sticker sheet (packs B, "less gloss?"), inventory A
  (backpack, "less gloss / AI look"), locker uses the locker icon, shine = soap bubbles, pattern = bubble rings, colour
  per screen, clipboard layout A, clipboard words cut.
- No / redo: shop (all "AI-like"; bag B could work with its strap fixed), locks rule (Gloom lock and the others look
  glossy/AI; only the price tag is decent), Let's Go ("give me more, less AI, not soap-looking"), Pippa renders (hands
  clip into the head; asks about the lavender Pippa). Clipboard look: "I'd have to see it".
- Note on the "white borders" the owner saw on the locks: the PNGs are transparent; the white is the lilac rim light,
  and the review page also previews each icon on a cream plate.

## Built (470f20f9)
- Soap bubbles replace the 4-point star in every reward/earned VFX burst: `VfxAssets.TEXTURES.bubble` (the Bubble
  Ride bubble, already Icey Labs) in Ability, Cargo, truck pop, Emote, Employee, Occupant and Vacuum bursts. `star`
  stays only for Cappy's Spot It locator (a marker, not a reward).
- Light panels: `ToonSurface` pattern `rings` (the bubble tile tinted violet) replaces `sparkle`; the sparkle tile
  is dropped from `UIAssets.toon`.
- Colour per screen: Shop menu bar mint, Inventory sky, Guide header gold, Settings night (`DepotHubViewModel.pageHue`,
  `ToonPanel` header `hue`). The clipboard board is coral.
- Gloom Locker source band shows the locker render instead of the Gloom lock.
- Company Clipboard rebuilt (`DepotTimecardPanel` + new specced `DepotClipboardViewModel`): coral board, steel clip,
  TIMECARD (sky) / TODAY'S JOB (mint) tabs, punch track with the key and Gleam hung on punches 3 and 5, PUNCH IN!,
  paycheck dots; today's job in big words with bar, +100 chip, "NEW JOB IN 5H 12M", SHOW IN SHIFTS. The stamp lands on
  the punch slot.
- Uploaded to Icey Labs (Decals, Approved, Creator = group 189923277): featured spotlight 86065362565121, daily
  calendar 123972910876460, soap bubbles 111550379423940. Their Image ids need a Studio Edit InsertService call before
  they can be wired (featured tab, daily gift/sign, UI ToonSparkle image).

## Round 2 on the review page
Matte, hand-painted icons (no plastic gloss) for: style (matte spotlight/calendar), backpack, sticker sheet, shop,
price tag, Let's Go; plus "which Pippa: coral / lavender / both".

## Round 2 (glossy family chosen, softer shine)
- Built e606be97: Shop = toy shop stall (Shop bar, hub SHOP tile, depot SHOP topper); sticker packs, stickers, the chat
  wheel's Stickers button and the Inventory chat-wheel tab = sticker sheet (also the callout fallback). `shopGift` and
  `gift` are gone from `UIAssets.toonIcons`. Icey Labs decals 106048651825814 / 104162197575790.
- Built 7915b4a5: Featured spotlight, daily calendar, soap-bubble "earned it" mark.
- Fixed 5cf36245: the spotlight and calendar were re-cut (v2 images); the owner's "weird white / black outline" was the
  floor shadow GPT sheets keep, outlined by iconize. `deshadow.py` (now also in the game-ui-design skill scripts, with
  a note in icons-and-photos.md) removes it before the outline.
- Round 3 on the review page: backpack with fewer colours, Let's Go with simpler fur, the price tag with the edge fixed.
- Still open: which Pippa (coral / lavender / both) and the Pippa re-render (needs Studio); the in-game capture of the
  clipboard and colours (waiting for "Lobby go").

## Round 3 + Pippa (ed7a56b6)
- Picks: backpack A (blue, coral pocket), Let's Go A (simpler fur, motion lines), gold price tag (C).
- Inventory icon = backpack (hub INVENTORY tile, Inventory bar). Price tag marks what you can buy: unhired crew cards,
  the pick screen's locked employees (hireable there), and item cards whose band is a Credits/Gleam price
  (`InventoryViewModel.lockIcon`, specced); everything else keeps the Gloom lock. Let's Go icon replaced.
- Pippa re-rendered in Shift Edit from the v13 model, coral (Default) and lavender (Owner Special skin applied with
  `EmployeeSkinSystem.apply`, glasses included), lanyard via `EmployeeLanyardSystem.attachPreview`. Poses chosen by a
  grid search that rejects any pose where `GetPartsInPart` finds a hand or forearm in the head, face plate or ears;
  the award card became a cheer (a salute with her short arms always overlaps her head from the front). Captured on a
  flat green backdrop and keyed with `p05-ui-kit/pippa/chroma.py` (the generic cutout dropped the lavender body).
- Colour per icon (owner: "both, depends on the icon"): coral on chat-wheel Emotes, CREW chip, Crew tab, hire
  silhouette, award card; lavender on the Shop Skins tab (`pippaSkins`); the welcome/loading card already shows the
  live lavender model. Listed on the review page with a veto button each.
- Uploads (Icey Labs, Approved, Image ids verified group 189923277): backpack 81160659671419, Let's Go 124538881139374,
  price tag 140520500336666, Pippa wave coral 126227546924097, wave lavender 97692146860492, cheer coral
  89228375154099. The old `pippaSaluteCut` is replaced by `pippaCheerCut`.

## In-game check (Lobby Play, 2026-11-13)
- Method: a temp LocalScript (`p05-ui-kit/p05-capture-mount.luau`, injected under PlayerScripts) mounted the real
  screens in preview mode (no save, no player data written), using `ReactRoblox.createLegacyRoot` (a `createRoot`
  remount after a script teardown never rendered) and the game's own `PaperHudFrame` scale. Audio muted, temp script
  and gui deleted, Play stopped, no P05 attributes left, RunTests false.
- Seen working: pick screen (price tags, Let's Go), hub (backpack INVENTORY, calendar gift, stall SHOP), Shop (mint,
  spotlight Featured, lavender Skins tab, sticker sheet on packs), Inventory (sky, coral Crew tab, sticker Chat Wheel
  tab, price tags on unhired crew), Guide (gold), Settings (night), clipboard desktop + phone.
- Fixed after the check (3791a4e4): TODAY'S JOB tab, "1 GLOOM KEY", "NEW JOB IN 5H 12M" were cut off; PAID stamp moved.
- Captures: `p05-ui-kit/play/*.jpg` and the review page's top section. Launch List rows set to "decide" with
  "Ready to check" (not done).
- Not checked in real play with a real profile: the clipboard opened from the hub button (needs a trained profile),
  the reward bubbles in a live shift, the award card cheer on a real Shift Review.
