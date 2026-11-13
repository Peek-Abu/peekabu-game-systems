# P0.5: catalog split (Launch List row `p1-skins-bundles`)

Session p05-catalog, 2026-11-13. Status: **built, specs written, NOT yet run in Studio or real play** (needs a Studio slot).

## What the owner approved (rules sheet, 2026-11-13)
Sheet: side-session notes `p05-catalog-rules-sheet-2026-11-14.md`.
- Q1 yes: a skin grants only itself. Promotion prefers the bundle; a skin with no bundle is still promoted.
- Q5, Q6 yes: buying a bundle grants all of it; owning a bundle = owning all its items (nothing saved for the bundle).
- Q7 yes, price drops for owned items, never "discount off the full price of the other item": **store-flow owns the math**.
- Q8 yes: 3 Legendary bundles (skin + emote + sticker pack). Q9 yes: `bundlegrant`.
- Q10 yes: Gloom-Touched collection; plus the 3 Legendary sets as collections (coordinator suggestion, **pending owner OK**, easy to drop).
- Q11, Q12 yes: no Vacuums tab; vacuum skins are a row on each employee's Skins tab; still in the Shop.
- **On hold:** Q2–Q4 (idles as items), Q14 "Idle" word, Q15 migration. Q13 tag look: mock page for the owner.

## What changed (commit 93ce1505)
- `CosmeticTypes`: `Item.bundle` removed; new `Bundle` (`id, name, rarity, items, currency, price, lore`) and `Collection` (`id, name, items`).
- New `Shared/Features/Cosmetic/Data/CosmeticBundleRegistry` (+spec): `Bundle.BubbleBuddy`, `Bundle.PJCappy`, `Bundle.SheriffPrickles`, 1,500 Gleam each (what the skin cost before the split). `get / has / all / containing(itemId)`. Load-time asserts: real items, no stickers, no free defaults, no clash with item ids.
- New `Shared/Features/Cosmetic/Data/CosmeticCollectionRegistry` (+spec): `Collection.GloomTouched` and the 3 Legendary sets. Data only, not shown anywhere.
- `CosmeticServiceServer`: `grant` / `grantOps` = the one item. New `grantBundle(userId, bundleId)`: the missing items in one transaction, announces every item (one reveal).
- New Cmdr `bundlegrant <player> <Bundle.Id>` (`Commands/CosmeticBundleGrant` + Server + spec). `cosmeticgrant` now gives one item.
- `ShopRegistry`: one offer per bundle (`id = Bundle.*`, `items = bundle.items`), pool `featured`. A Legendary skin with a bundle moves to Today's picks; a bundle-less Legendary and the vacuum skins stay featured. `ShopServiceServer` needed no change: it already grants every `offer.items` entry and announces them.
- `ShopViewModel`: a bundle card shows the bundle's name and rarity, line "Bundle · Pippa"; its page lists every item, with "alone N" prices after the first. A skin's page now shows only the skin.
- `RevealViewModel`: "also got" = the other ids in the same grant (a bundle buy shows them; a skin alone shows none).
- Inventory: "Comes with" is now "In a bundle with" (the item's bundle mates). The Vacuums tab is gone. Each employee's Skins tab has a second row, "Vacuum skins: one for the whole crew". Picking a vacuum skin turns the hero round to show the pack (as the old tab did). `InventoryViewModel.sections` builds the rows.
- Comments only: `DealServiceServer`, `LockerServiceServer`.

## No save migration needed for this part
Saves already list every owned item one by one: buying a Legendary skin also saved its emote and pack. So nobody loses anything. The only migration on the table is the idle one (Q15), and it waits for the idle decision.

## Shop / inventory files edited (for the other sessions)
- `ShopRegistry.luau` + spec, `ShopViewModel.luau` + spec, `ShopServiceServer.spec.luau` (two buy tests).
- `InventoryViewModel.luau` + spec, `InventoryCharacterPanel.luau`, `InventoryScreen.luau`.
- `RevealViewModel.luau` + spec.
store-flow's unpushed commit d7392e4d also edits `ShopViewModel` and `ShopServiceServer.spec`. Whoever pushes second rebases. My ShopViewModel edits are inside `card` and `product`, plus two local helpers after `main`.

## For store-flow (prices)
Read `CosmeticBundleRegistry.get(offer.id)` for a bundle, and each item's regular price from `CosmeticRegistry.get(id).price`. Its currency is the item's `source`. `ShopRules.owned(offer, owns)` is true only when every item is owned. A buy of a part-owned bundle grants only the missing items: the grant is idempotent.
Price note for the owner: the bundle costs 1,500, and the skin alone still costs 1,500 too. The skin-alone price is store-flow's call.

## Gates
- `stylua --check` clean. `luau-lsp analyze` has no errors in `src`.
- `check_pr_rules`: passed (its 10 warnings are in files I didn't touch).
- `selene` exits 1 on a warning that was already there, in `UIPreloadRules.luau`, which I didn't touch.
- The file-length step fails on files over the limit before this change (Office, Shift, Employee, ...). My edited Inventory and Shop files are in its list too.
- TestEZ: **not run** (Studio only). Needs a Studio slot: `RunTests = true` in the Lobby place.

## Not done / next
- Real-play check: buy a bundle and a skin alone (2nd client not needed); `bundlegrant`; the Inventory Skins tab with its vacuum row (desktop + phone).
- Type tags (Q13): mock at https://claude.ai/artifact/5uXBTmGBGRefE1ZPJSs9KV. Build after the owner picks A/B.
- Idles as items (Q2–Q4, Q15): on hold. The split leaves room for it: a Legendary idle becomes an `idle` item and joins its bundle's `items`. `EmployeeSkinRules.idleOf` would read the look's idle instead of the skin's showcase idle. The migration grants the idle to skin owners.

## Update: idles are items, type tags dropped (commit 5eec1d8a)
The owner said yes to Q2–Q4, Q14 and Q15 (following the recommendation). Type tags: a firm **no**. Nothing may
cover a card's picture, and none was ever built. Item types are told apart by the Shop/Inventory tabs and rows they
sit in, and by the item's name line.
- New Epic idle items, 400 Gleam each: `Pippa.BubbleBuddyIdle`, `Cappy.PJIdle`, `Prickles.SheriffIdle`. Each one is the
  4th item of its Legendary bundle and collection. Bundles are now 1,500, which is 30% off 2,150, following store-flow's
  rule. The skin alone stays 1,200.
- The free idle (`<Employee>.Classic`) is renamed **"Skin's Own"**. It plays whatever the worn skin does, which is the
  same as before, so nobody's look changes.
- Fit ("lock that pair"): `Item.fits` lists the skins an idle needs. Sheriff Idle fits every Prickles skin, because
  the hose coil is an emote prop template.
- Bubble Buddy Idle fits only Bubble Buddy: the duck ring is worn by her outfit.
- PJ Idle fits only PJ: the pillow is assumed to be in the PJ outfit only. **To verify in Studio**: check
  `ReplicatedStorage.Assets.CleanupCrew.EmoteProps` for a `Pillow` or `DuckRing` template. If one is there, drop that
  idle's `fits` line.
- A locked pair shows "Bubble Buddy only" on the card and "Wear Bubble Buddy first" on the button. Changing to a skin
  the idle doesn't fit plays that skin's own idle. The saved pick comes back with the right skin.
- How the idle plays:
  - `EmployeeRegistry` `idles` maps an idle item to the Legendary skin whose showcase idle and fidget it borrows.
  - `EmployeeSkinRules.idleOf` / `fidgetOf` take the idle key. The server writes `EmployeeIdle` on the character with
    no rebuild, and `Animate.client` rebinds when it changes.
  - `EmployeePreviewSystem` and `ToonViewport` (new `idle` prop) play it in previews. The Inventory hero plays the
    worn idle, or the picked one on the Idles tab.
- Migration v4→v5 (`PlayerDataMigrationSystem`): each owner of a Legendary skin is given its idle. The look is left
  alone.
- Not run yet: TestEZ and a play check (wear the Sheriff Idle on Classic Prickles, then a locked pair, then a migrated
  save).
