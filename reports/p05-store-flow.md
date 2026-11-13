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
`CharacterPickViewModel`, and two kit pieces: `ToonPrice` (old price above on a card, beside it in a button) and
`ToonMenuBar` (optional `width`: the tabs shrink to fit beside the wallets).

Hires cost 5,000 Credits (owner, 11-13). The deals now give the whole Legendary bundle again (the catalog split had
left only the skin), and their "% off" is recomputed: Pick a Legendary -70%, Pick a New Hire -74%. A spec fails the
build if a price change makes those numbers untrue.

## Commits (game/cleanup-crew)

- `7dbb2162`: Gleam top-up, back to the item, Hire tab
- `e9c29401`: partial-bundle price, only new items granted and revealed
- `e74aaa39`: owner prices, sales, daily sale, crossed-out look
- `e8dde5ed`: hires 5,000, deals give the whole bundle, deal % recomputed
- `19b5400e`: spec fixes from the full suite run (a priced fixture kept its own items)
- `f5d42f38`: Shop tabs fit beside the wallets; crossed-out price never clipped

## Studio (Lobby, 11-13)

Full TestEZ suite on the served worktree: 6,619 passed, 8 failed. Five of the failures were mine, fixed in
`19b5400e` but not rerun yet. The other three went to their owners through the coordinator: InventoryViewModel and
LockerServiceServer are catalog's, VacuumMountSystem is the vacuum session's.

Played in the Lobby; balances were set and purchases sent from the server and client, so no real clicks yet. Then I
put the account back to how it was:
- The Hire tab shows Cappy and Prickles at 5,000.
- Top-up: with 4,700 Credits, Prickles' page says "Use 30 Gleam" and asks "You need 300 more Credits. Use 30 Gleam to
  hire Prickles?". Buying took Credits 4,700 → 0 and Gleam 600 → 570, and Prickles was hired.
- Back to the item: the Gleam tab said "Get 630 more Gleam for Bubble Buddy!" with Just right! on 1,500, plus a Back
  button. After +1,500 Gleam arrived, the Shop jumped back to Bubble Buddy with "Buy Bubble Buddy for 1,200 Gleam?"
  up.
- Today's sale: Cocoa Sip 320 and Sheriff Prickles 960, each -20%; the deal banner reads -70%.
- Two problems seen in play are fixed in `f5d42f38` but not seen in Studio yet: the Passes tab ran under the wallet,
  and the crossed-out price was clipped on the bundle's buy button.

## Owner check in play (real clicks)

1. **Hire** tab: Cappy and Prickles at 5,000 Credits; a hired one says OWNED, last.
2. With 4,700 Credits and some Gleam, open Prickles → **Use 30 Gleam** → Yes → hired.
3. With too little Gleam, open a skin → **Need … more** → Gleam tab (line, **Just right!**, Back) → buy a pack →
   back on the skin with "Buy …?" up.
4. Pick Your Employee with Gleam and no Credits: **Hire with 500 Gleam** → tap again → hired.
5. Featured and picks show sale prices (~~1,200~~ 960, -20%) and the page says "Sale ends in …". Bundles show
   ~~2,150~~ 1,500, -30%. Owning one item of a bundle lowers its price.
6. Gleam tab: 100 / 150 / 600 / 1,500 with +15 / +32 / +49%. All six tabs fit on desktop and phone.

## Owner to-do (Creator Dashboard)

- Product 3722076494 (pack 2, R$ 129): name and description must say **150 Gleam**, not 275. The icon has no
  number.
- When the Robux prices go up, send them on: I update ShopConstants / DealConstants and the "% off" spec forces
  the numbers to match.
