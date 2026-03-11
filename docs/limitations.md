# Limitations & Future Considerations

This document outlines known limitations of the current architecture and considerations for future development.

---

## Type System Limitations

### 1. Manual Type Synchronization Required
**Affected:** `CurrencyType`, `ProfilePath`

Luau doesn't support `keyof` or deriving union types from table keys. These types must be manually kept in sync:

```lua
-- CurrencyConstants.luau
local CURRENCIES = {
    gold = { ... },
    gems = { ... },
}
export type CurrencyType = "gold" | "gems"  -- Must match CURRENCIES keys manually

-- PlayerDataTypes.luau
export type ProfilePath = "currency" | "inventory"  -- Must match PlayerProfile keys manually
```

**Why This Exists:** Intentional trade-off for intellisense/autocomplete support. No good alternative exists in Luau that preserves type inference.

**Mitigation Strategies:**
1. Add runtime validation at startup to catch mismatches
2. Add comments near both locations referencing each other
3. Consider code generation for larger projects

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

### 3. `ProfilePath` Union Growth
As profile fields grow, the union becomes unwieldy:

```lua
-- Current:
export type ProfilePath = "currency" | "inventory"

-- Future:
export type ProfilePath = "currency" | "inventory" | "quests" | "achievements" 
    | "settings" | "stats" | "friends" | "guild" | ...
```

**Mitigation:** Consider a registry pattern where services register their paths at init time, with runtime validation instead of compile-time types.

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

### 6. No Schema Versioning
`ProfileStore:Reconcile()` handles missing fields but not schema migrations.

**Not Supported:**
- Renaming fields (`gold` → `coins`)
- Changing field types (`quantity: number` → `quantity: { min, max }`)
- Removing deprecated fields

**Future Consideration:** Add schema version to profile template:
```lua
PROFILE_TEMPLATE = {
    _schemaVersion = 1,
    currency = { ... },
    inventory = { ... },
}
```

Then handle migrations in `onPlayerAdded`:
```lua
if profile.Data._schemaVersion < CURRENT_VERSION then
    migrateProfile(profile.Data)
end
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
local MyService = {}
MyService.dependencies = { ... }

function MyService.init(self, ...) end
function MyService:getState() return {} end

type MyService = typeof(MyService)
return MyService :: MyService
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
| Manual type sync | Low | Runtime validation |
| ByteNet coupling | Low | Separate type files |
| ProfilePath growth | Medium | Registry pattern |
| No network batching | Medium | Debounce manually |
| Single-player focus | High | Requires new services |
| No schema versioning | Medium | Add version field |
| No offline retry | Low | Queue pattern |
| No BaseService | Low | Template/snippet |
| No client validation | Low | Dev-mode validation |
| No inventory slots | Low | Add slot field |
| No multi-server txn | High | MessagingService + locks, or memory store |
```
