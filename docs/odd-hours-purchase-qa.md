# Odd Hours: purchase QA and "I paid and got nothing" (draft, 2026-11-06)

Every Robux purchase in the game, how to test each one end to end in the **published** game (Studio cannot buy),
and what to do when a player says they paid and got nothing. The owner runs the test purchases with a test account;
agents never buy, refund or grant on their own. Launch List row: st-purchase-qa. Runbook: [odd-hours-launch-runbook.md](odd-hours-launch-runbook.md).

## What can be bought with Robux

Two kinds only. Everything else (skins, emotes, vacuums, sticker packs, Locker keys) is bought with Gleam or Credits
inside the game, so it never touches Robux directly.

| Item | Kind | Id (code) | What the player gets | Where it is granted |
|---|---|---|---|---|
| 100 Gleam (R$ 49) | developer product | 3722076056 (`ShopConstants.PRODUCT_IDS.gleam100`) | +100 Gleam | Marketplace receipt → premium slice |
| 275 Gleam (R$ 129) | developer product | 3722076494 (`gleam275`) | +275 Gleam (+10 % bonus shown) | same |
| 600 Gleam (R$ 249) | developer product | 3722076599 (`gleam600`) | +600 Gleam (+20 %) | same |
| 1,500 Gleam (R$ 549) | developer product | 3722076697 (`gleam1500`) | +1,500 Gleam (+35 %) | same |
| Big Crew | game pass | 2058797732 (`HostConstants.PASS_ID`) | the host's truck holds 6 | Roblox owns it; checked on join and on purchase |

Prices live on the Creator Dashboard and in `ShopConstants.BUNDLES`; change both together.

## How a receipt is handled (why "paid and got nothing" should be rare)

`MarketplaceServiceServer` owns `ProcessReceipt`. A receipt is acknowledged (`PurchaseGranted`) **only after** the
Gleam and the purchase id are saved together in one transaction. Anything else (the buyer left, the profile is not
loaded, the save did not confirm) answers `NotProcessedYet`, and Roblox asks again, including the next time the
player joins any server. The same purchase id is never granted twice (it is checked against the account's receipt
history). So a short delay is normal; a missing grant usually means the player has not rejoined yet.

## Test, per product (published game, test account)

For each Gleam bundle:
- [ ] Open the Shop → GLEAM tab, buy the bundle, confirm in Roblox's window.
- [ ] The Gleam number goes up by exactly the amount, within a few seconds.
- [ ] Leave and rejoin: the new total is still there (saved).
- [ ] Buy the same bundle again: it adds again (developer products can be bought many times).
- [ ] Server log (F9 → Server): one receipt line, no "retry" lines.

Big Crew pass:
- [ ] Shop → PASSES, buy Big Crew.
- [ ] Without rejoining, step on a truck as the first player: its tag shows 6 seats.
- [ ] Rejoin: still 6 seats; the Passes card shows Owned.

Spending Gleam (no Robux, but money-like):
- [ ] Buy one Gleam item in the Shop (e.g. Brass Bellows, 600): Gleam goes down by its price, the item is owned, and
      it survives a rejoin.
- [ ] Open the Gleam Locker once.
- [ ] Try to buy with too little Gleam: refused, no Gleam taken.

The receipt failure path (do once):
- [ ] Buy a bundle and leave the game straight away, before the Gleam shows. Rejoin: the Gleam arrives (Roblox
      retried the receipt).

## "I paid and got nothing": what to do

1. Ask for the player's username, the item, and roughly when.
2. Ask them to rejoin once and wait a minute: an un-acknowledged receipt is retried on join and grants then.
3. Check the sale exists: Creator Dashboard → the experience → Monetization → Developer Products (or Passes) →
   Sales, around that time.
4. Still missing after a rejoin:
   - **Gleam bundle:** as an admin in a live server with the player present, run
     `marketplacepremiumadd <player> <amount>` (alias `premiumadd`). Note it in a sheet (who, what, when, why), so it
     is never granted twice.
   - **Big Crew pass:** pass ownership comes from Roblox, not our saves. If the Sales page shows the purchase, ask
     them to rejoin; if it still fails, report it to Roblox support (we cannot grant a game pass by hand).
5. If several players report the same thing in a short time, it is a bug, not one player: check the Error Report and
   the server logs for receipt "retry" lines, and hold off on ads until it is fixed.

## Still to do

- Run the checklist on the published places (needs the owner and a test account with Robux).
- Decide who answers player reports at launch (the group wall? Discord? a form?) and add it here.
