# P0.5 store flow (2026-11-13)

Rows: `p1-gleam-topup`, `p1-return-after-gleam`, `p1-sell-hires`, `p1-prices`. All built and pushed. None is
"check" until it has been played in Studio.

## What changed

- **Gleam pays the rest** (`ShopTopUpRules`, `ShopServiceServer:payOps`). Short on Credits for a Shop item or a
  hire, the button says **Use 30 Gleam**. The question says "You need 300 more Credits. Use 30 Gleam to hire
  Cappy?". The Credits and Gleam are spent in one save; the Gleam is rounded up and the player keeps what it
  over-covers. Rate: 1 Gleam = 10 Credits. No top-up on the Gloom Locker (owner, 11-13).
  - Starting-employee pick: **Hire with 250 Gleam**, then **Tap again: use 250 Gleam**.
  - The School unlock (p05-places-school) pays through the same `payOps`.
- **Back to the item after buying Gleam** (`ShopStore.returnTo`). The Gleam tab says "Get 300 more Gleam for
  Bubble Buddy!". It marks the smallest pack that covers it **Just right!** and has a Back button. When the Gleam
  arrives, the Shop goes back to the item with its Yes/No up. The Lockers tab returns the same way. What I copied
  from free-to-play shop UX write-ups: a currency upsell right where the player is short, the cost always shown,
  and a safe path back that keeps their place. What I didn't copy: auto-buying without a final yes
  ([PocketGamer](https://www.pocketgamer.biz/5-monetization-missteps-in-midnight-star-ui),
  [SEELE](https://www.seeles.ai/features/create/iap-families-low-friction),
  [Xsolla](https://xsolla.com/blog/getting-players-to-purchase-with-ux-optimization)).
- **Hire tab** (right after Featured): every employee for sale, hired ones last.
- **Prices** (owner said yes to the whole price sheet, 11-13; `ShopPriceRules`):
  - Legendary skin alone: 1,200.
  - Bundles: 30% off their items (1,750 → 1,220).
  - Gleam pack 2: 150. The bonuses are worked out from the numbers: +15 / +32 / +49%.
  - A bundle you own part of costs its share of what's missing, at the bundle's discount, never more than the
    missing items alone. Only new items are granted and revealed.
  - Sales count only with an end time. Daily sale: Featured + the first 2 picks are 20% off until midnight UTC
    (never hires or bundles, never stacked).
  - The old price shows small and crossed out above the new one, with a "-20%" burst and "Sale ends in …".
  - The server prices on its own clock and never charges more than the price the player saw.

Shop UI files touched: `ShopScreen`, `ShopProductPanel`, `ShopViewModel`, `ShopStore`, `CharacterPickScreen`,
`CharacterPickViewModel`, and the kit's `ToonPrice` (its old price now sits above the price).

## Commits (game/cleanup-crew)

- `7dbb2162`: Gleam top-up, back to the item, Hire tab
- `e9c29401`: partial-bundle price, only new items granted and revealed
- `e74aaa39`: owner prices, sales, daily sale, crossed-out look

## Check in play (Lobby)

1. **Hire** tab: Cappy and Prickles priced in Credits; a hired one says OWNED, last.
2. With 2,200 Credits and some Gleam, open Prickles → **Use 30 Gleam** → Yes → hired; Credits 0, Gleam −30.
3. With 0 Gleam, open a skin → **Need … more** → the Gleam tab shows the line and **Just right!** → buy it → back
   on the skin with "Buy …?" up. **Back to …** opens the page with no question.
4. Pick Your Employee with Gleam: **Hire with 250 Gleam** → tap again → hired.
5. Featured and Today's picks: up to 3 single items show ~~1,200~~ 960 with a -20% burst. The product page says
   "Sale ends in …". A bundle card shows ~~1,750~~ 1,220, -30%.
6. Own a bundle's emote, then open the bundle: the price drops, and buying it reveals only the new items.
7. Gleam tab: 100 / 150 / 600 / 1,500 with +15 / +32 / +49%.
8. Phone: six tabs fit, and the old price above the new one doesn't hit the card's name.

## Owner to-do (Creator Dashboard)

- Product 3722076494 (pack 2, R$ 129): name and description must say **150 Gleam**, not 275. The icon has no
  number.

## Open

- Deal cards' "% off" (Pick a Legendary 45%, Pick a New Hire 36%) were worked out against old prices. Whoever owns
  Deals should recompute them.
