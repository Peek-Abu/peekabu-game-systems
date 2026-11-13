# P0.5 store flow (2026-11-13)

Rows: `p1-gleam-topup`, `p1-return-after-gleam`, `p1-sell-hires` (built, "check"), `p1-prices` (sheet out for yes/no).

## What changed

- **Gleam pays the rest** (`ShopTopUpRules`, `ShopServiceServer`). Short on Credits for a Shop item or a hire, the
  button says **Use 30 Gleam**. The question says "You need 300 more Credits. Use 30 Gleam to hire Cappy?". The
  server takes the Credits you have plus the Gleam for the rest in ONE save, rounding the Gleam up. You keep what
  the rounding over-covers. The buy request carries the most Gleam the player said yes to. If the rest now costs
  more, the buy is refused ("The Gleam price changed"). `ShopServiceServer:payOps` gives any other Credits purchase
  (e.g. School unlock) the same payment.
  - Starting-employee pick: **Hire with 250 Gleam**, then **Tap again: use 250 Gleam**.
  - Rate: **10 Credits per Gleam** (one constant, `ShopConstants.TOP_UP`), owner-approved 11-13.
    No top-up on the Gloom Locker (owner, 11-13).
- **Back to the item after buying Gleam** (`ShopStore.returnTo`, `ShopViewModel.returnTo / bestBundle`). Short
  on Gleam → the Gleam tab says "Get 300 more Gleam for Bubble Buddy!", marks the smallest pack that covers it
  **Just right!**, and has a **Back to Bubble Buddy** button. As soon as the bought Gleam arrives, the Shop goes
  back to the item with its Yes/No question already up. The Lockers tab returns the same way. What I copied from
  free-to-play shop UX write-ups: a contextual currency upsell when the player is short, the cost always shown
  (never a buy button turned into a currency sale), and a safe path back to the item that keeps the player's place.
  What I didn't copy: auto-buying without a final yes, and hiding the price
  ([PocketGamer: Midnight Star missteps](https://www.pocketgamer.biz/5-monetization-missteps-in-midnight-star-ui),
  [SEELE: low-friction IAP](https://www.seeles.ai/features/create/iap-families-low-friction),
  [Xsolla: purchase UX](https://xsolla.com/blog/getting-players-to-purchase-with-ux-optimization)).
- **Hire tab** (right after Featured): every employee for sale, hired ones last. Their card opens the existing hire
  page (stats, ability).

Shop UI files touched: `ShopScreen`, `ShopProductPanel`, `ShopViewModel`, `ShopStore`, `CharacterPickScreen`,
`CharacterPickViewModel`.

## Commits

- `f6520a0b` feat(shop): Gleam top-up, back to the item after a Gleam buy, Hire tab

## Check in play (Lobby)

1. Shop → **Hire** tab: Cappy and Prickles show, priced in Credits; a hired one says OWNED, last.
2. With 2,200 Credits and some Gleam: open Prickles → button **Use 30 Gleam** → Yes → hired; Credits 0, Gleam −30.
3. With 0 Gleam: open Bubble Buddy → **Need … more** → Gleam tab shows "Get … more Gleam for Bubble Buddy!" and a
   **Just right!** pack → buy it → the Shop jumps back to Bubble Buddy with "Buy … ?" up.
4. Same, but press **Back to Bubble Buddy** instead: the page opens, no question.
5. Fresh account at Pick Your Employee with Gleam: **Hire with 250 Gleam** → tap again → hired.
6. Phone layout: six tabs fit the menu bar.

## Open questions (owner, through the coordinator)

- Price sheet (`p05-store-price-sheet-2026-11-14.md` in the shared notes): yes/no answers needed before `p1-prices` is
  wired. The bundle partial-ownership rule gets 2 worked examples for the owner before it ships.
