# Limitations & Future Considerations

This document outlines known limitations of the current architecture and considerations for future development.

---

## Type System Limitations

### 1. Manual Type Synchronization Required
**Affected:** `CurrencyType`

Luau doesn't support `keyof` or deriving union types from table keys, so the `CurrencyType`
union must be kept in sync with the `CURRENCIES` table by hand:

```lua
-- CurrencyConstants.luau
local CURRENCIES = {
    gold = { ... },
    gems = { ... },
}
export type CurrencyType = "gold" | "gems"  -- Must match CURRENCIES keys manually
```

**Why This Exists:** Intentional trade-off for intellisense/autocomplete support. No good
alternative exists in Luau that preserves type inference for the union.

**Mitigation:** `CurrencyServiceServer.init()` validates the union against `CURRENCIES` on
startup and errors loudly if they drift, so a mismatch fails fast on boot rather than silently.

**Future:** Luau's `keyof` type operator (`export type CurrencyType = keyof<typeof(CURRENCIES)>`)
would remove this sync entirely — adding a key to `CURRENCIES` would update the type automatically.
Not adopted yet: the project's `JohnnyMorganz.luau-lsp` currently reports `keyof` as an undefined
type (Selene/CI parse it fine, but the editor analyzer doesn't resolve it). Revisit once the
toolchain recognizes the operator; the boot-time validation above is the interim guard.

> **Note:** `ProfilePath` used to be a manually-synced union too, but it has since moved to a
> runtime registry (see [#3](#3-profilepath-registry-vs-compile-time-paths)). It is now typed as
> `string` and is no longer compile-time checked.

---

### 2. ByteNet Struct Coupling
**Affected:** `PlayerDataTypes.luau`

Type definitions are coupled to ByteNet serialization:

```lua
return {
    InventoryItemStruct = {
        itemType = ByteNet.string,
        quantity = ByteNet.optional(ByteNet.uint32),
        ...
    },
}
```

**Impact:** Switching networking libraries requires modifying type files.

**Future Consideration:** Separate pure types from serialization definitions.

---

## Scalability Limitations

### 3. `ProfilePath`: Registry vs. Compile-Time Paths
**Status:** ✅ Registry pattern adopted.

`ProfilePath` is no longer a hand-maintained union. Each domain service registers its own root
key at load time via `PlayerDataConstants.registerProfilePath(path, defaultData)`, which also
assembles the profile template dynamically:

```lua
-- In CurrencyServiceServer.luau
PlayerDataConstants.registerProfilePath("currency", { gold = 100, gems = 10 })

-- In InventoryServiceServer.luau
PlayerDataConstants.registerProfilePath("inventory", {})

-- PlayerDataTypes.luau
export type ProfilePath = string  -- no longer enumerated at compile time
```

This removes the per-field manual sync and lets each service own its slice of the profile — at
the cost of compile-time checking on path strings. A typo such as `mutate(userId, "iventory", ...)`
type-checks fine but fails at runtime: `mutate()` logs a warning and returns `false` when the
path isn't present. `registerProfilePath` also asserts against duplicate registration.

**Mitigation — encapsulate the path in a typed accessor.** `ProfilePath` stays `string` (keeping
the open, decentralized registry), but a service that owns a slice should never expose the raw
path to callers. Each owning service wraps `mutate()` in one private, typed accessor, so the path
string is written exactly once and the mutator payload is typed without a per-call annotation:

```lua
-- CurrencyServiceServer.luau — the ONLY place "currency" appears as a path string
function CurrencyServiceServer:_mutateCurrency(
    userId: number,
    fn: (currency: PlayerDataTypes.Currency) -> boolean?
): boolean
    return PlayerDataService:mutate(userId, "currency", fn)
end

-- add/remove/set then call: self:_mutateCurrency(userId, function(currency) ... end)
-- InventoryServiceServer has the equivalent :_mutateInventory.
```

This shrinks the typo surface to a single line per service and types the mutator argument, without
re-centralizing the schema. A future toolchain with `keyof` could go further and type the path
itself as `keyof<PlayerProfile>`, making `mutate(uid, "iventory", ...)` a compile error — but
`keyof` isn't recognized by the current `luau-lsp` (see [#1](#1-manual-type-synchronization-required)),
so the accessor pattern is the portable choice today.

---

### 4. No Network Batching
Each mutation broadcasts immediately to the client:

```lua
self:broadcastCurrencyUpdate(userId, currencyType, newAmount, amount)
```

**Impact:** High-frequency updates (combat damage, rapid item pickups) could flood the network.

**Future Consideration:** Add a `broadcastBatch()` mechanism or debounce pattern:
```lua
-- Potential API:
PlayerDataService:queueBroadcast(userId, "currency", data)
PlayerDataService:flushBroadcasts(userId) -- Called at end of frame
```
---

### 5. ProfileStore Locking Nuances
ProfileStore provides **per-profile session locking** — only one server can hold a profile at a time. This prevents duping and corruption for individual player data.

**What IS Supported (same server):**
- Multi-profile transactions (e.g., trades between two players on the same server)
- Atomic rollback via `LastSavedData` if transaction fails
- Auto-save detection and abort to prevent partial state persistence

**What is NOT Supported:**
- **Cross-server atomicity:** Two players on different servers cannot trade atomically
- **Shared non-player data:** Guild banks, global auctions, etc. have no built-in locking
- **Cross-profile atomic locking:** No way to lock multiple profiles simultaneously across servers

**Current Implementation:**
The `transaction()` method handles same-server multi-profile operations safely:
1. Force saves all profiles to establish `LastSavedData` rollback point
2. Detects auto-save mid-transaction and restores pre-transaction state
3. Rolls back all profiles on any failure

**Future Consideration (cross-server):**
- Distributed locking via `MemoryStoreService`
- Two-phase commit pattern
- ProfileStore's `GlobalUpdates` for cross-server messaging
- Escrow/saga patterns for eventual consistency

---

## Data Persistence Limitations

### 6. Schema Versioning
**Current Status:** ✅ Implemented via `PlayerDataMigrations`.

`ProfileStore:Reconcile()` backfills missing template fields, but it cannot rename a field,
change a field's type, or remove a deprecated one. Those changes are handled by ordered,
versioned migrations.

**How it works:**
- Every profile carries a `_schemaVersion`. The profile template stamps new profiles with the
  current version (`PlayerDataConstants.PROFILE_TEMPLATE`); profiles saved before versioning
  existed have no field and are treated as the v1 baseline.
- `MIGRATIONS[v]` upgrades a profile from version `v` to `v + 1`, so
  `CURRENT_VERSION = 1 + #MIGRATIONS`.
- `onPlayerAdded` reads the stored version *before* `Reconcile()` (so the backfill doesn't mask
  an old profile), then calls `PlayerDataMigrations.apply(profile.Data, storedVersion)`.
- Migrations run against a deep copy; if one errors, the live profile is left untouched and the
  player is kicked rather than persisting a half-migrated profile.

**Adding a migration** (see `src/ServerScriptService/Modules/PlayerDataMigrations.luau`):
```lua
-- 1. Append to MIGRATIONS (index = the version it upgrades FROM):
[1] = function(data) -- v1 -> v2: rename currency.gold to currency.coins
    data.currency.coins = data.currency.gold
    data.currency.gold = nil
end,
-- 2. Update the template / registerProfilePath defaults so NEW profiles match the new shape.
-- 3. Add a case to PlayerDataMigrations.spec.luau.
```

---

### 7. No Offline/Retry Logic
If network events fail to send (player disconnecting mid-operation), there's no retry mechanism.

**Impact:** For critical operations, data could be saved server-side but client never receives confirmation.

**Future Consideration:** Implement a reliable message queue for critical updates.

---

---

### 8. No `BaseService` Abstraction
Each service repeats the same boilerplate:

```lua
export type MyService = {
    dependencies: { string },
    init: (self: MyService, ...any) -> (),
    getState: (self: MyService) -> { [string]: any },
}

local MyService: MyService = {
    dependencies = { ... },
    init = function(self, ...) end,
    getState = function(_self) return {} end,
}

return MyService
```

**Future Consideration:** Create a service template or factory:
```lua
local MyService = ServiceFactory.create({
    name = "MyService",
    dependencies = { "OtherService" },
})
```

---

### 9. No Client-Side Schema Validation
Client services trust server data completely (correct for server-authoritative model), but there's no validation:

```lua
CurrencyEvents.packets.CurrencyUpdate.listen(function(data)
    -- data is trusted without validation
    currency[data.currencyType] = data.newAmount
end)
```

**Impact:** Malformed packets (from bugs, not exploits) could crash the client.

**Future Consideration:** Add optional schema validation in development mode.

---

---

### 10. No Inventory Slot System
Current inventory is a flat array. Many games need:
- Slot-based inventory (equipment slots, hotbar)
- Inventory tabs/categories
- Weight/capacity limits

**Future Consideration:** Add an optional `slot: number?` field to `InventoryItem`:
```lua
export type InventoryItem = {
    itemType: string,
    quantity: number?,
    instanceId: string?,
    slot: number?, -- Optional: for slot-based inventories
}
```

---

---

### 11. Audit Trail Implementation
**Current Status:** ✅ Implemented via `Logger:audit`.

Critical mutations (transactions, currency changes) are now logged using the audit level. This provides a baseline for tracking economy changes, though it currently persists only to the standard output/logs rather than a dedicated database.

**Future Consideration:** Connect a persistent logging service (e.g. via HTTP) to a dedicated audit database.

---

### 12. No Multi-Server Transaction Support
Current transaction system is single-server only. For cross-server features:
- Trading between players on different servers
- Guild banks
- Global auctions

**Requires:**
- Distributed locking via MessagingService
  MemoryStoreService
- Two-phase commit pattern
- ProfileStore's `GlobalUpdates` feature or use other features of ProfileStore

---

## Summary Table

| Limitation | Severity | Workaround Available |
|------------|----------|---------------------|
| Manual type sync (`CurrencyType`) | Low | Runtime validation on boot |
| ByteNet coupling | Low | Separate type files |
| `ProfilePath` compile-time safety | Low | Registry adopted (runtime-checked) |
| No network batching | Medium | Debounce manually |
| Single-player focus | High | Requires new services |
| Schema versioning | Low | Implemented (`PlayerDataMigrations`) |
| No offline retry | Low | Queue pattern |
| No BaseService | Low | Template/snippet |
| No client validation | Low | Dev-mode validation |
| No inventory slots | Low | Add slot field |
| No multi-server txn | High | MessagingService + locks, or memory store |
```
