# Character systems step 4: concept-quality screens, the Shop, and reveals — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: superpowers:executing-plans. Steps use checkbox (`- [ ]`) syntax.

**Status:** built 2026-10-24, ready for the owner's play-check together with step 3 (report:
`reports/2026-10-24-character-step4.md`). Uploads approved (Let's Go! remade as Pippa's foot); calls 1-5 built with
the defaults below until the owner answers. Deviation: the reveal queue is `CosmeticRevealStore` (Cosmetic client
State), not a UI store.

**Goal:** The step 3 screens look like the round 3 concepts, the Shop sells skins / emotes / idles / sticker packs /
employees for Gleam or Credits in one safe transaction, and every new thing you get plays a reveal.

**Design:** `docs/superpowers/specs/2026-10-24-odd-hours-character-systems-design.md` §6, §7, §9, §10.
Concepts: `characters/ui/character-ui/frames3/{crew,char-skins,char-about,shop,product}.jpg`,
`frames2/pick.jpg`, `frames4/{reveal-hire,reveal-leg,stages}.jpg` (Figma page "Character UI", rounds 3-4).

**Not in this step:** Lockers (odds, pity, keys), Passes, emotes on the wheel / stickers / pings (step 5), colour-style
art, per-rarity sound stings (a sound task), legendary reveal clips with props (needs animation work), Cappy's model.

## Why step 3 looks worse than the concepts (owner question)
Step 3 put the effort into the systems (data, saving, swapping, layouts on two screen sizes) and drew the visuals at a
functional level, and I skipped the skill's last check (built screen next to the concept, redo until it matches).
Nothing later in the old plan fixed that, so Part A below does, before the Shop reuses the same pieces.

## Part A: bring the step 3 screens up to the concepts
Every screen gets a side-by-side check against its concept (same viewport) before it is called done.

**Shared, all full-screen menus (Inventory, pick, Shop, reveals):**
- `ToonBackdrop` (new kit piece): the screen's colour as diagonal stripes (one tile image) + rays behind the hero +
  a vignette, over the **blurred depot** (a camera BlurEffect while a menu scene is open; removed on close).
- **Scale**: type and art sized from the concepts at 1920x1080 (titles ~100 px, names ~70 px, cards fill the screen
  height); no large empty areas.
- **Header**: title plate with its render breaking the edge (Inventory: the locker; Shop: the gift; employee page: the
  employee's head from a static viewport), tabs with small renders, **Credits and Gleam** wallets (Gleam is the
  `premium` balance; step 3 wrongly said it had none).
- **Ribbon flags** with a notched end (one 9-slice image) instead of plain tags.

**Crew tab:** cards like `frames3/crew.jpg`: an art window with rays in the employee's colour on top, a darker footer
with the name, line and ability chip (ability render), a "You!" sticker on the worn one, the selected card lifted with
the lilac glow, a dark silhouette on the "???" card (not just text). The gloss band no longer crosses the art.

**Employee page:** like `frames3/char-skins.jpg`:
- grid cards with an inset rarity stage (stripes for Epic, foil for Legendary, goo for Odd), rarity ribbon, "On" check
  on the worn one, footer band kept (owner decision: where-to-get bands, no icons on the art);
- hero bigger, on a raised platform (lip + shadow, rarity colour);
- detail panel filled: lore in a quote box with the employee's name, Styles as buttons (greyed "Coming soon" until art),
  **Comes with** as small tiles, and the main button (Wear / Wearing / **See in Shop** with the price / Gloom Locker /
  Missed it / Coming later). "See in Shop" opens that item's Shop product page.
- About tab like `frames3/char-about.jpg`.

**Pick:** like `frames2/pick.jpg`: big two-tone title with a sub-plate ("You can switch any time in your Inventory at
the depot"), heads breaking the cards' top, gold stat bars on a purple About card, the ability card with its render
breaking the edge, the round cooldown chip, a two-line name plate under the platform.

## Part B: the Shop
**What the player sees** (`frames3/shop.jpg`, `product.jpg`):
- Opens from a new **SHOP** hub tile and from any "See in Shop" button. Tabs: **Featured · Skins · Gleam** (Lockers and
  Passes come later and are not shown).
- **Featured:** one big banner offer (live 3D hero on its stage, name, what's inside, price button, "Leaves in 2d 14h"
  timer) and **Today's picks**: 6 cards (3D or icon on a stage, name, item line, price, New!/Hot/Last day! ribbon).
  Picks change at the same UTC time on every server; a "New in 6h 12m" chip counts down.
- **Skins tab:** every buyable item, filterable by employee, owned ones stamped **Owned**.
- **Gleam tab:** the 4 Gleam bundles (100 / 275 / 600 / 1,500 for R$49 / 129 / 249 / 549, bonus bursts +10/20/35%),
  bought with Robux through the existing Marketplace receipts (see call 2).
- **Product page:** left panel (rarity + event ribbons, name, "Bundle for Cappy · cosmetic only", lore quote, Styles,
  "what's inside" rows with each item's own price), big price button; right: the item live on its stage. Buying asks
  "Buy PJ Cappy for 1,500 Gleam?" (Yes / No), then plays the reveal.
- Not enough Gleam/Credits: the button says "Need 300 more" and (for Gleam) offers the Gleam tab.

**How it's built:**
- `ShopRegistry`: offers by id: item ids (one item or a bundle), currency (`gleam` | `credits`), price, flags, the
  pool it rotates in (`featured` | `picks` | `always`), optional start/end (UTC) for events. Prices come from the
  catalog by default.
- `ShopRotationUtils.live(now)`: which offers are live (pure, specced): the featured offer and 6 picks chosen by a
  day seed from UTC date, so every server agrees; `always` offers (employees) always listed.
- `ShopServiceServer:buy(userId, offerId)`: checks live + not owned + not in a shift + balance, then ONE PlayerData
  transaction: spend (`MarketplaceServiceServer:premiumOp` for Gleam, `CurrencyServiceServer:currencyOp` for Credits)
  + `CosmeticServiceServer:grantOps` (the item and its bundle). You can never pay without getting it, or get it without
  paying. Rate-limited request; a buy of something you own is refused before any spend.
- Gleam bundles: `MarketplaceServiceServer:onProduct(key, grant)` adds Gleam (existing exactly-once receipts).
- Hiring an employee is a Credits offer; the pick screen's locked employees get "Hire for 2,500" when you have the
  Credits (design §5), else stay preview-only.

## Part C: reveals
`RevealScreen`, one screen scaled by rarity (`frames4/reveal-*.jpg`):
- big two-tone title (YOU'RE HIRED! / RARE! / EPIC! / LEGENDARY! / ODD!), a "New skin for Cappy" ribbon, the item live
  on a platform, name plate with style dots, "You also got" tiles for the bundle, **Wear it!** (equips on the spot, in
  the depot) and **Later**;
- Uncommon: quick card flip; Rare: + rays; Epic: + stripes and sparkles; Legendary: + foil sweep, confetti; Odd: red
  goo burst; hire: the ID card stamped HIRED! with the ability card.
- Triggered by the server after a grant (`CosmeticEvents.Granted` → the client queues reveals, one at a time): Shop
  buys, Gleam is not a reveal (a toast), the first-join pick shows the hire reveal before you start.
- Sounds: the existing UI tiers for now (rarity stings are a separate sound task).

## Uploads needed (one batch, Icey Labs group 189923277, your OK required)
1. Stripe tile (white, tinted per screen), 2. ribbon notch 9-slice, 3. deal burst (the spiky -30%/+20% badge),
4. Shop gift render (header), 5-8. Gleam bundle renders (crystals, bucket, crate, truck), 9. ability renders for the
three abilities (sneaker, magnifier, flower pot), 10. "Owned" stamp. All 256-512 px PNGs made with the icon pipeline
(GPT render → cut-out → ink outline), shown to you on a sheet before upload.

## New modules
| Feature | Realm | Subfolder | Name | Job |
|---|---|---|---|---|
| Shop | shared | Data | ShopRegistry | offers: items, currency, price, flags, pool, dates |
| Shop | shared | Data | ShopTypes | Offer, LiveShop types |
| Shop | shared | Data | ShopConstants | picks per day, rotation hour, Gleam bundle amounts |
| Shop | shared | Utils | ShopRotationUtils | which offers are live at a UTC time (pure) |
| Shop | shared | Rules | ShopRules | can this player buy this offer (owned, live, balance) |
| Shop | shared | Rules | ShopRequestRules | build/parse the buy request |
| Shop | shared | Net | ShopEvents | BuyRequest packet |
| Shop | server | (root) | ShopServiceServer | runs buys in one transaction; Gleam bundle receipts |
| Shop | client | (root) | ShopServiceClient | live offers, requestBuy |
| Cosmetic | shared | Net | CosmeticEvents (+ Granted packet) | server → client "you got these" for reveals |
| UI | client | Screens/Toon | ToonBackdrop, ToonBurst, ToonStamp, ToonPrice (+ stories) | stripes/rays/blur, deal burst, Owned stamp, price with struck old price |
| UI | client | Screens/Shop | ShopScreen, ShopProductPanel, ShopViewModel (+spec), ShopScene (+story) | the Shop |
| UI | client | Screens/Reveal | RevealScreen, RevealViewModel (+spec), RevealScene (+story) | reveals |
| UI | client | State | RevealStore | the queue of reveals waiting to show |

Shop is a new feature (named in the design); no new subfolder kinds, role words or second services.

## Tasks (each: spec → implement → typecheck → commit; screens: side-by-side with the concept)
1. Uploads sheet → your OK → upload batch.
2. Kit: ToonBackdrop (+ blur), notched ToonFlag, ToonBurst, ToonStamp, ToonPrice, wallets in a shared header.
3. Part A: Crew tab, employee page, About, pick, each checked against its concept at desktop and phone size.
4. Shop data: ShopTypes / ShopConstants / ShopRegistry / ShopRotationUtils (+spec: same picks for the same UTC day on
   any server, changes at the rotation hour, event offers only inside their dates, always-offers always there).
5. ShopRules + ShopRequestRules + ShopServiceServer.buy (+spec: Gleam and Credits buys spend and grant together; a
   short balance, an owned item, a dead offer, a shift and a malformed request each change nothing; bundle grants all).
6. Gleam bundles through Marketplace receipts (+spec: one receipt adds Gleam once).
7. ShopServiceClient + ShopViewModel (+spec) + Shop screens + SHOP hub tile + "See in Shop" links.
8. Granted packet + RevealStore + RevealViewModel (+spec: title, effects and buttons per rarity; hire variant; queue
   order) + RevealScreen; pick → hire reveal → start.
9. Studio: suite green; screenshots of every screen beside its concept (desktop + phone); play: buy a skin with Gleam
   (granted with the admin command), see the reveal, Wear it!; hire Prickles with Credits; report for your check.

## Calls for you to check
1. **Gleam bundles need 4 developer products** on the experience (R$49 / 129 / 249 / 549). Create them in the
   Creator Dashboard and send me the ids, or I leave the Gleam tab showing the bundles greyed "Soon" this step.
2. **Struck "was" prices and -30% bursts:** I show them only when an item really sold at the higher price before (a
   sale on a past price), never an invented "was" price. At launch that means no struck prices. OK?
3. The Shop shows **Featured · Skins · Gleam** now; Lockers and Passes tabs appear when those are built.
4. Today's picks change once a day at **00:00 UTC** (8 pm New York in summer, 7 pm in winter). Pick another hour if you like.
5. Buying asks a **Yes/No confirm** for every Gleam or Credits purchase.
6. The 10 uploads above (one approval, after you see the sheet).
