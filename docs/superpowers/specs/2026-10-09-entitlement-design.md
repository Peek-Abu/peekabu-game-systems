# Entitlements — design

Status: built with this spec. Roadmap item #9 (docs/ROADMAP.md).

## Goal

One account-wide answer to "does this player own this?" — a suit, a pet skin, a night unlock, a VIP
cosmetic — fed by purchases and by gameplay, so no game invents its own ownership table per category.

## Decisions

1. **Ownership is account data**, `entitlements = { owned = { [category] = { [id] = true } } }`, shared by
   every save slot (like titles). Owning is idempotent, so it is safe to share; quantities never live
   here (they belong in Inventory or Currency).
2. **Registered by category and id.** `EntitlementRegistry.register("suit", "hazmat", { name, icon? })`.
   Granting an unregistered id is programmer error (asserts); reading tolerates unknown ids, so retiring
   one never needs a migration. The data-layer validator checks structure only (non-empty ids of at most
   64 characters, `true` values) — the Titles precedent.
3. **Server writes, everyone else reads.** `grant` / `revoke` / `owns` / `ownedIn`, and `grantOp` to put
   a grant into a transaction — a Marketplace product handler returns
   `{ EntitlementService:grantOp(player.UserId, "suit", "hazmat") }`, so the purchase and the unlock are
   one atomic, exactly-once write. `granted(userId, category, id)` fires after a new grant.
4. **Replicated to the owner** (StateSync slice `entitlements`); the client reads `owns` / `ownedIn` for
   shop and wardrobe UI. Other players' cosmetics are what a game publishes to the public slice when one
   is equipped — equipping is game-specific and not here.
5. Pure ownership logic (`owns`, `grant`, `revoke`, `validate`) is shared `EntitlementRules`, used by both
   realms.

## New modules

| Feature | Realm | Subfolder | Name | Job (one line) |
|---|---|---|---|---|
| Entitlement | shared | Data | EntitlementTypes | Types only: EntitlementDef |
| Entitlement | shared | Data | EntitlementRegistry | Categories and ids, validated |
| Entitlement | shared | Rules | EntitlementRules | Pure: owns, grant, revoke, list, the slice validator |
| Entitlement | server | root | EntitlementServiceServer | The account slice: grant / revoke / owns / grantOp |
| Entitlement | client | root | EntitlementServiceClient | Reads the replicated slice |

Plus admin commands `entitlementgrant` and `entitlementrevoke`.
