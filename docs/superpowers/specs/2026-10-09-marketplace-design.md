# Marketplace — design

Status: built with this spec. Roadmap item #8 (docs/ROADMAP.md).

## Goal

Robux purchases that can never be lost or granted twice, gamepasses checked once and cached, and a
premium currency that survives across saves — with no game pasting a product id into gameplay code.

## Decisions

1. **Products and passes are registered by a game key.** `MarketplaceRegistry.registerProduct("coins-small",
   { productId })` and `registerPass("vip", { passId })` (validated: positive integer ids, no duplicate
   key or id). Code says `promptProduct("coins-small")`, never `1234567`.
2. **Exactly-once grants.** The service owns `MarketplaceService.ProcessReceipt`. A game registers what a
   product grants as transaction operations: `onProduct("coins-small", function(player, receipt)
   return { CurrencyService:currencyOp(player.UserId, ...) } end)`. For each receipt
   (`MarketplaceReceiptSystem`):
   - unknown product, buyer not on this server, or profile not loaded → `NotProcessedYet` (Roblox retries
     later; nothing is ever dropped);
   - the purchase id is recorded in the account's bounded receipt history (the last 100 ids, the
     ProfileStore recommendation) **in the same transaction** as the grant's operations, saved with
     `persist = true`. Only a confirmed durable save returns `PurchaseGranted`;
   - an id already in the history is not granted again — the history alone is re-saved, and the receipt
     is acknowledged once that save is confirmed;
   - concurrent callbacks for one purchase id are serialized (the second waits for a retry).
   ProfileStore's session lock means a profile is loaded on one server at a time, so the history is
   authoritative across servers. `productGranted(player, key)` fires after a grant for non-data effects
   (a sound, a VFX burst).
3. **Gamepass ownership is cached per player**: checked with `UserOwnsGamePassAsync` when they join
   (failures retry a few times, then count as not owned until the next purchase or rejoin), updated by
   `PromptGamePassPurchaseFinished`. `ownsPass(player, "vip")` reads the cache; `onPass("vip", fn)` runs
   when a player is found to own it (on join or on purchase). Ownership is published as the public field
   `pass:<key> = true`, so every client can show a VIP badge and the owner's client can unlock UI.
4. **Premium currency is an ACCOUNT slice** (`premium = { balance }`), shared by every save slot,
   replicated to its owner, validated by the data layer (a whole number from 0 to `MAX_PREMIUM`).
   `addPremium` / `spendPremium` / `premiumOp` (for a transaction that spends premium and grants an item
   atomically). The receipt history is a second account slice (`receipts`) that is never replicated.
5. **The client only prompts.** `MarketplaceServiceClient:promptProduct(key)` / `promptPass(key)`,
   `ownsPass(key)` (from the public field) and the premium atom. It never grants anything.

Not now: subscriptions, a shop catalogue UI (game-specific), price lookup caching (`GetProductInfo` is a
one-line call a game makes for its own shop).

## New modules

| Feature | Realm | Subfolder | Name | Job (one line) |
|---|---|---|---|---|
| Marketplace | shared | Data | MarketplaceTypes | Types only: ProductDef, PassDef, Receipt |
| Marketplace | shared | Data | MarketplaceConstants | Receipt history size, premium cap, pass field prefix, retries |
| Marketplace | shared | Data | MarketplaceRegistry | Products and passes by game key, validated |
| Marketplace | server | Rules | MarketplaceReceiptRules | Pure: the bounded receipt history; premium and history validators |
| Marketplace | server | Systems | MarketplaceReceiptSystem | The exactly-once receipt decision over injected dependencies |
| Marketplace | server | State | MarketplacePassTracker | Gamepass ownership per player |
| Marketplace | server | root | MarketplaceServiceServer | ProcessReceipt, passes, premium |
| Marketplace | client | root | MarketplaceServiceClient | Prompts, owned passes, the premium balance |

Plus the admin command `premiumadd <player> <amount>`.

## API

```lua
MarketplaceRegistry.registerProduct("gems-100", { productId = 1234567 })
MarketplaceService:onProduct("gems-100", function(player)
	return { MarketplaceService:premiumOp(player.UserId, function(p) p.balance += 100 return true end) }
end)
MarketplaceRegistry.registerPass("vip", { passId = 7654321 })
MarketplaceService:onPass("vip", function(player) grantVipPerks(player) end)

-- spend premium and grant an item in one atomic write
PlayerDataService:transaction({
	MarketplaceService:premiumOp(userId, function(p) if p.balance < 50 then return false end p.balance -= 50 return true end),
	InventoryService:inventoryOp(userId, function(inv) ... end),
})
```
