# Character systems step 4: concept-quality screens, the Shop, reveals (2026-10-24)

Plan: `docs/superpowers/plans/2026-10-24-character-step4-shop-reveals.md`. Status: **ready to check** together with
step 3 (not done until you play-check it).

## Part A: the step 3 screens now match the concepts
Checked side by side with `characters/ui/character-ui/frames3/*.jpg` and `frames2/pick.jpg`.
- **Every menu** sits on a new backdrop (diagonal stripes, rays behind the character, edge shading, the depot blurred
  behind) under one shared top bar: a title plate with its render breaking the edge, tabs with renders, Credits AND
  Gleam wallets (Gleam is your real balance; I was wrong in step 3 that it had none), close.
- **Ribbons** with a notched end everywhere (rarity, skin name, New!, On, You!, Soon).
- **Crew cards**: bright art window with rays, darker card body, skin name ribbon, "You!" on the one you play, the
  ability chip with its new render, the hire price as a gold Credits button, the dark silhouette on "???".
- **Employee page**: the employee's head on the name plate and the tabs in the top bar (as in the concept); rarity
  cards with inset stages; a raised platform; the detail panel with the lore quote box, Styles buttons (greyed until
  style art), Comes-with tiles and **See in Shop 1,500** (opens that item's Shop page).
- **About** and **pick** follow their concepts (gold stat bars, ability card with its render, the big gold title).
- Phone sizes trimmed so nothing overlaps (smaller detail panel, no line under the name on phone cards).

## Part B: the Shop
- **SHOP** tile in the hub (under the gift). Tabs **Featured · Skins · Gleam**.
- **Featured**: the day's banner (a Legendary skin, live, its price, "Changes in 23h 57m") and **Today's picks**
  (6 items), the same on every server, changing at 00:00 UTC; Gleam bundles along the bottom (desktop).
- **Skins**: everything for sale, filter by employee, owned items stamped OWNED.
- **Gleam**: the 4 bundles (100 / 275 / 600 / 1,500 with +10/20/35% bursts), greyed "Soon" until their Robux products
  exist.
- **Product page**: ribbons, the name, "Bundle for Pippa · cosmetic only", the lore, Styles, what's inside with each
  extra's own price ("alone 400"), the big price button; "Need 300 more" when short (leads to the Gleam tab).
- **Buying**: Yes/No question first, then one save that spends the Gleam/Credits AND gives the item with its bundle,
  never one without the other. Refused when owned, short, or in a shift.
- **Pick screen**: a locked employee shows **Hire for 2,500** when you have the Credits.

## Part C: reveals
- After any purchase, grant or the first-join pick the server tells your client and the reveal opens by itself
  (queued one at a time; one earned in a shift waits for the depot).
- Louder up the ladder: NICE! / RARE! (rays) / EPIC! (stripes, sparkles) / LEGENDARY! (confetti); the title pops in.
- "You also got" tiles for bundles; **Wear it!** / Later, or Nice! for things you don't wear.
- **YOU'RE HIRED!**: the Morrow & Morrow ID card stamped HIRED!, the ability card, Start! (after the pick) or Equip!
  (after buying an employee).

## Verified (hub window)
- Full suite: **4675 passed, 0 failed** (16 new specs: Shop offers, rotation, buy rules, request shape, the Shop
  server's one-save purchase, the reveal queue, the Shop/Reveal/Inventory view models), plus a final run after the
  last fixes (see below).
- Play, through the real request paths (sent from a test script; no clicks):
  - first join: the pick → **the hire reveal opened by itself** (`step4-reveal-hire.jpg`);
  - +2,000 Gleam → Shop front (`step4-shop-featured.jpg`) → Bubble Buddy's page (`step4-shop-product.jpg`) → buy →
    **the LEGENDARY reveal opened by itself** (`step4-reveal-legendary.jpg`) → Wear it!: Gleam 2,000 → 500, Pippa
    wears Bubble Buddy, the Bubbles emote and Bubble Pack owned.
- Screenshots in `reports/step4-*.jpg` (desktop and phone): crew, Pippa skins, About, pick, Shop Featured / Skins /
  Gleam / product, reveals (legendary, hire from pick, Prickles hire from the Shop).

## Not checked yet / known gaps
- **Real clicks** (cards, tabs, the Yes/No, Wear it!) and **a second player** were not exercised: please play-check.
- Phone captures were taken at phone size inside the desktop window, not on a device.
- **Cappy** shows Pippa's placeholder photo everywhere (Shop banner, cards) until his model is back; skins without
  art (Bubble Buddy, PJ Cappy, Sheriff, Gloom-Touched...) show the default look; styles have no art yet.
- **Gleam bundles** need their 4 developer products (call 1 below); until then they say Soon.
- Gleam spent in the Shop is not reported to the economy analytics yet (the purchase writes the balance inside the
  one save, which skips the analytics event): a small follow-up.
- Reveal: no per-rarity sound stings yet (UI sounds only), no Legendary reveal animation clip, confetti does not fall.
- The reveal queue lives with the Cosmetic client (`CosmeticRevealStore`) instead of a UI store as the plan said
  (cosmetics own grants).

## Calls still open (from the plan; I went with these defaults)
1. Gleam bundles: create 4 developer products (R$49 / 129 / 249 / 549) and send me the ids, or keep them "Soon".
2. No crossed-out "was" prices unless a real sale happened.
3. Shop tabs Featured · Skins · Gleam (Lockers and Passes later).
4. Today's picks change at 00:00 UTC.
5. Every purchase asks Yes / No first.
