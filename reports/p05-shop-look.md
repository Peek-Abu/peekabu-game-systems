# P0.5 shop look: preview spin and rarity look (2026-11-14)

Launch List rows: `p1-shop-rotate` (built) and `p1-rarity-shop` (concept, waiting on the owner's picks).

## 1. `p1-shop-rotate`: players spin the preview

Commit `a4722b80` on `game/cleanup-crew`.

**What the player can do**
- On a computer, hold either mouse button on the model and drag left or right. Let go mid-drag and it coasts a little, then slows to a stop.
- On a phone, drag with a finger. A flick coasts the same way.
- On a controller, push the right stick left or right to turn it at a steady speed.
- Each new item starts from the front. Changing a colour style keeps the angle you turned to.
- No auto-turn while idle (it was optional, so I left it out). It is easy to add if the owner wants it.

**Where it is on**
- The shop product page's big model (skins, employees, emotes, idles, and the vacuum try-on seen from behind).
- The Inventory character page's big model, which uses the same ToonViewport.
- Small cards, thumbnails and the locker cards do not spin. They are too small to drag, and a drag there would fight scrolling.

**How it works**
- `Toon/ToonViewport` has a new `spin` prop. With it on, the viewport takes the drag (`Active`, so the world camera does not turn under it). It binds the right stick at high priority while it is mounted, and it steps a coast each frame.
- In a ViewportFrame it turns the camera and the light together, which looks the same as turning the model on a turntable: the side facing you stays lit. The camera's grow-to-fit (so a reveal never gets cut off) uses the same angle.
- Emote previews draw on the 3D stage, not in the viewport. There the model and its platform turn round their own upright axis (`EmployeeStageSystem` Stage `turn`).
- The maths lives in the new `Toon/ToonSpinViewModel`, pure and specced: drag to degrees (half a turn per frame width), the coast and its slow-down, the stick dead zone and speed, and keeping the angle within one turn.

**Checks**
- selene, stylua and luau-lsp are clean on every file I touched. Two warnings remain in files I did not touch: `UIPreloadRules` shadowing and `QueueTicketSystem` ForRange.
- The TestEZ spec `ToonSpinViewModel.spec` has not run yet. It needs Studio or Open Cloud.
- **Lobby Play check (2026-11-14, real mouse input through Studio):**
  - A right-drag of 100 px across the 685 px hero turned it 26°, as the maths says. A drag that stopped before letting go did not coast.
  - On the emote stage (Bubble Ride), a left-drag turned Pippa 37° in place, still centred.
  - The light follows the turn.
  - Phone touch and the controller stick are not checked yet; they need the owner's devices.
- **Found, not caused by this work (follow-up):** the shop's vacuum try-on (`turn = 150`) opened facing the front, not the back. The camera ended up on the model's front side, so the cloned character probably keeps the player's own world facing (`EmployeePreviewSystem.outfit`). **Fixed** after the coordinator's go: `EmployeePreviewSystem.outfit` now stands a live clone of your character upright facing -Z (new spec case: a character turned 120° and tilted still previews facing -Z, in place). Not play-checked yet.

**Files I edited** (please keep these in mind for the other shop sessions)
- `src/ReplicatedStorage/Client/UI/React/Screens/Toon/ToonViewport.luau` (spin input and apply)
- `src/ReplicatedStorage/Client/UI/React/Screens/Toon/ToonSpinViewModel.luau` + `.spec.luau` (new)
- `src/ReplicatedStorage/Client/Features/Employee/Systems/EmployeeStageSystem.luau` (Stage `turn`)
- `src/ReplicatedStorage/Client/UI/React/Screens/Shop/ShopProductPanel.luau` (one line: `spin = true` on the hero)
- `src/ReplicatedStorage/Client/UI/React/Screens/Inventory/InventoryCharacterPanel.luau` (one line: `spin = true` on the hero)

## 2. `p1-rarity-shop`: concept round

Review page: https://claude.ai/artifact/HxiuMvSf8ANc6RkSa74Lzf (picks are saved to its db collection `picks`, doc `r1`).

Three options, each shown as a six-tier ladder plus the real shop screen at Legendary and Odd:
- **A, the stage grows.** The platform climbs with the tier (1 to 3 steps), with a light ring for Uncommon and Rare and round show lights for Epic and Legendary. Legendary also gets a warm spotlight. Odd is a cracked red stage with Gloom goo spilling over it and a red underglow. It is 3D in the viewport, so it turns with the spin.
- **B, the backdrop takes the tier.** The screen's gradient and rays strength follow the tier, with the tier name huge and faint behind the model. Odd turns dark red, with goo creeping from the top edge.
- **C, a show frame.** A plaque, then velvet rope posts, then curtains, then a lit arch. Odd has torn curtains and a crooked arch with dead bulbs.

My recommendation: A, plus B's backdrop for Legendary and Odd only.

Questions on the page, split into look / layout / rules:
- Look: which option, and whether Odd gets goo.
- Layout: does the model stay where it is, and is there a tier plaque under the stage?
- Rules: does every Legendary and Odd skin play its own shop idle (made before launch where missing), do Common and Uncommon stay plain, and do tier sounds and effects wait for a later round?

No sparkle, diamond or 4-point-star motifs. Mock-up sources are in this session's scratchpad (`rarity/kit/kit.html`); the Pippa cut-out is from the 2026-11-13 skin-page capture.

**Owner's pick (2026-11-14): B.** "B is solid. Lets implement this and leave this open for p1 / post p0.5". The owner's firm rule from the same day: the item must always be clearly visible, and nothing may cover a skin. So the model stays where and as big as it was, and B's extras sit only around and behind it.

### B built (commit `38c2b071`)
- `Shop/ShopRarityLookViewModel` (new, specced) maps a tier to its look: colours, rays (none on Common and Uncommon, stronger from Rare to Epic to Legendary, plus a second counter-turning layer on Legendary), the tier word, and Odd's goo and red edges.
- `Toon/ToonBackdrop` gets additive props: `counterRays`, `word` (faint display text behind the hero), `edge` (vignette colour, stronger when set) and `goo` (a ToonGoo cap along the top edge). Every other screen passes none of them and looks as before.
- `Shop/ShopScreen` changes only at its backdrop call plus a `HERO_X` constant: an open item's page takes the look, and the lists and tabs keep the coral-to-grape backdrop.
- Lint, format and types are clean.
- **Lobby Play check (2026-11-14):** captured Classic (Cappy), Rare (Brass Bellows), Epic (Bubble Ride on the 3D stage) and Legendary (Bubble Buddy). No Uncommon or Odd item is on sale, so those two were shown by forcing the look on the Bubble Buddy page in that Play only. All draw as designed, the goo is attached along the top edge, and the model is never covered.
- **Fixed after the check** (commit `ccd3cce6`): the default tier's word now says CLASSIC like its flag (it said COMMON), and a tier's backdrop is opaque (the depot showed through the pale colours; the emote stage was already opaque and looked cleaner).
- Captures are on the review page (top section, "B in the game").
- The Launch List row stays open for later polish (sounds, VFX, per-tier poses).
