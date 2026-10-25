# Vacuum skins as cosmetics + the Vacuums tab (2026-10-25)

Owner's answers on Figma round 5 (Character UI page): layout A (a skins screen); the middle preview is YOUR employee
wearing the vacuum; a vacuum is one thing (no mix-and-match parts row; its sounds/visuals are a separate topic);
Standard Issue is the free one; vacuums come from the Gleam Shop, both lockers, events, Credits only in a special
promotion, the same source bands as skins, and can be Featured in the Shop; the old Company Equipment page goes.

## What changes
1. **Catalogue**: `CosmeticTypes.Kind` gains `"vacuum"`. Items `Vacuum.StandardIssue` (default, free) and
   `Vacuum.BrassBellows` (rare, Gleam 600, price not final). The part after the dot is the VacuumSkinRegistry key.
   Only built vacuums are in the catalogue (Board 4's other 9 are concepts: added when their models exist).
2. **Loadout**: `vacuum: string?` (account-wide: one vacuum for the whole crew). Optional, so old saves need no
   migration; `CosmeticRules.vacuumFor` falls back to Standard Issue. Change `{ kind = "vacuum", id }`.
3. **Server**: VacuumSkinRules reads the wearer's loadout (the MVP owner allowlist is removed; the owner grants
   himself `Vacuum.BrassBellows` with `cosmeticgrant`). VacuumServiceServer re-wears the pack on
   `CosmeticServiceServer.changed` when the vacuum differs.
4. **Outfit** (the owner's "shared utility for the current employee"): `CosmeticOutfitRules.current(loadout, owns)`
   = employee, look (skin, style, idle, wheel), vacuum, stickers; `tryOn(outfit, id)` swaps one item in. Rank stays
   on the character (the lanyard), read by the preview from the live character.
5. **Preview**: `EmployeePreviewSystem.outfit(outfit, source, character)` clones your live character when it wears
   the outfit's employee (so rank lanyard, skin and pack come along), else dresses the template; then
   `VacuumPreviewSystem.swap` puts the tried-on vacuum's art on the clone's pack. `VacuumPreviewSystem.alone` is a
   card's art (the skin's Backpack). ToonViewport gains `outfit`, `vacuum` and `turn` (show the back).
6. **UI**: Inventory's Vacuums tab = the skins screen (list left, your employee wearing it in the middle seen from
   the back, info right). Vacuums appear in the Shop (picks/featured), with a product page and a reveal. The
   Company Equipment page (DepotHub "gear") is removed.
7. **Fixes found on the pages**: the Shop product page's two "SHOP" buttons; Cappy's real model replaces the
   placeholder photo (template copied into ReplicatedStorage.Assets.CleanupCrew.Characters.Cappy in the place).

## New modules
| Feature | Realm | Subfolder | Name | Job (one line) |
|---|---|---|---|---|
| Cosmetic | shared | Rules | CosmeticOutfitRules | the current outfit (employee, look, vacuum, stickers) and trying one item on |
| Vacuum | client | Systems | VacuumPreviewSystem | a vacuum skin's art for previews: alone on a card, or swapped onto a cloned character's pack |
