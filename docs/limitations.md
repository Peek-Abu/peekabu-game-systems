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

**Mitigation:** `CurrencyServiceServer.init()` calls `CurrencyConstants.validateCurrencyTypes()`
on startup and errors loudly if the definitions drift. Because Luau types are erased at runtime,
the union can't be enumerated directly — `CURRENCY_TYPE_MEMBERS` in `CurrencyConstants.luau` is
its enumerable runtime mirror, and the three declarations cover every drift direction: a key added
to `CURRENCIES` but not the union (or a mirror entry removed from the union) is a compile error,
and a union member with no `CURRENCIES` entry — or a mirror that fell behind — errors at boot.

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
**Status:** ✅ Resolved — no longer applies.

`PlayerDataTypes.luau` used to also export `CurrencyStruct`/`InventoryItemStruct` ByteNet wire
structs, coupling the pure type definitions to a specific serializer. Those structs backed the
per-domain delta packets (`CurrencyUpdate`, `InventoryDelta`, …) from the old dual-transport
design; once currency/inventory replication moved onto the charm-sync reactive spine (see
[architecture: Reactive state](architecture.md#reactive-state)), the structs had no remaining
caller and were dead code. They've been removed — `PlayerDataTypes.luau` is now types-only (every
export is `export type`; the module returns `{}` at runtime), with no ByteNet dependency at all.

ByteNet itself remains a project dependency and **the default channel for any discrete,
fixed-schema event that is not queryable state** — inbound action requests, one-off signals, RPCs
(see [architecture: Networking](architecture.md#networking) for the state-vs-event rule). The live
consumers today are the debugger's packets (`SetSubscription`, `Snapshot`, `ClearServerLogs` in
`DebuggerEvents.luau`); reactive player state flows through the charm-sync spine instead —
including that spine's own `CharmSyncReady` ping, which rides the state transport's RemoteEvent
rather than ByteNet by design.

---

## Scalability Limitations

### 3. `ProfilePath`: Registry vs. Compile-Time Paths
**Status:** ✅ Registry pattern adopted.

`ProfilePath` is no longer a hand-maintained union. Each domain service registers its own root
key at load time via `PlayerDataConstants.registerProfilePath(path, defaultData)`, which also
assembles the profile template dynamically:

```lua
-- PlayerDataConstants.luau — each domain service registers its root key at load time.
-- (Services no longer call this directly: SliceOwner.register wraps it and is the only
-- call site per service — see the mitigation below.)
PlayerDataConstants.registerProfilePath(path, defaultData)

-- PlayerDataTypes.luau
export type ProfilePath = string  -- no longer enumerated at compile time
```

This removes the per-field manual sync and lets each service own its slice of the profile — at
the cost of compile-time checking on path strings. A typo such as `mutate(userId, "iventory", ...)`
type-checks fine but fails at runtime: `mutate()` logs a warning and returns `false` when the
path isn't present. `registerProfilePath` also asserts against duplicate registration.

**Mitigation — encapsulate the path in a typed accessor.** `ProfilePath` stays `string` (keeping
the open, decentralized registry), but a service that owns a slice should never expose the raw path
to callers. `SliceOwner.register` writes the path string exactly once and hands back a typed
`get`/`mutate` pair, so add/remove/set never restate it and the mutator payload is typed without a
per-call annotation:

```lua
-- CurrencyServiceServer.luau — the ONLY place "currency" appears as a path string
local currencySlice = SliceOwner.register("currency", { gold = 100, gems = 10 }, function(profile)
    return profile.currency
end)

-- add/remove/set then call: currencySlice.mutate(userId, function(currency) ... end)
-- InventoryServiceServer registers "inventory" the same way.
```

This shrinks the typo surface to a single line per service and types the mutator argument, without
re-centralizing the schema. A future toolchain with `keyof` could go further and type the path
itself as `keyof<PlayerProfile>`, making `mutate(uid, "iventory", ...)` a compile error — but
`keyof` isn't recognized by the current `luau-lsp` (see [#1](#1-manual-type-synchronization-required)),
so the accessor pattern is the portable choice today.

---

### 4. Network Batching — handled by the reactive layer
**Status:** ✅ addressed by the reactive spine.

Replicated player state no longer sends a packet per mutation. Writes mirror into `ServerStore`
atoms, and charm-sync coalesces changes and flushes at most once per `Heartbeat`
(`config.interval`, default `0` = per frame), so a burst of same-frame writes to one player collapses
to a single delta. See [architecture: Reactive state](architecture.md#reactive-state).

**Remaining:** discrete *non-state* events sent directly over ByteNet still fire per call — debounce
those at the call site if a system emits them at high frequency.
---

### 5. ProfileStore Locking Nuances
ProfileStore provides **per-profile session locking** — only one server can hold a profile at a time. This prevents duping and corruption for individual player data.

**What IS Supported (same server):**
- Multi-profile transactions (e.g., trades between two players on the same server)
- Atomic rollback via an in-memory per-path snapshot if a transaction fails
- Auto-save detection and abort to prevent partial state persistence

**What is NOT Supported:**
- **Cross-server atomicity:** Two players on different servers cannot trade atomically
- **Shared non-player data:** Guild banks, global auctions, etc. have no built-in locking
- **Cross-profile atomic locking:** No way to lock multiple profiles simultaneously across servers

**Current Implementation:**
The `transaction()` method handles same-server multi-profile operations safely:
1. Validates every op (profile loaded, path exists, well-formed mutator) side-effect-free, then
   locks each affected profile and takes an in-memory deep-copy snapshot of every touched path as
   the rollback anchor — no forced pre-save (mutators cannot yield, so nothing can interleave)
2. Detects auto-save mid-transaction and restores pre-transaction state
3. Rolls back all profiles on any failure; durable persistence is opt-in via `{ persist = true }`

Single-path `mutate()` follows the same model at smaller scale: the slice is snapshotted before
the mutator runs, and a yield, error, or `false` return rolls the slice back — a rejected
mutation can never leave a partial write for the next auto-save to persist.

**Durability caveat for `{ persist = true }`:** the in-memory commit is atomic, but the persist
phase saves each affected profile *independently* (ProfileStore offers no cross-profile durable
commit). ProfileStore's `Save()` is fire-and-forget — it only *dispatches* the write — so the
persist phase confirms durability by waiting (bounded) for each profile's `OnAfterSave`, which
fires only once the underlying `UpdateAsync` actually lands. In a two-player trade, one side's
save can be confirmed while the other's throws or is never confirmed within the timeout across
all retries; `TransactionResult.failedUserIds` flags the non-durable side, but the already-saved
side cannot be un-saved. If the server then crashes before the failed side's next auto-save, the
trade is durably asymmetric. Treat a non-empty `failedUserIds` as "reconcile on next join" —
persist gives per-profile durability confirmation, not cross-profile durable atomicity. (One
narrow race remains: an auto-save already in flight across the commit can fire `OnAfterSave`
having captured pre-commit data, confirming slightly early — the commit is still in memory and
the next auto-save persists it, so the flag can be early but never durably wrong.)

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

### 8. No `BaseService` Abstraction — ✅ mostly resolved

The **meaningful** duplication was the slice-owner scaffolding: every data service hand-rolled the
same `registerProfilePath` + typed `getX` + one-line `_mutateX` wrapper, plus the same
`assert(type(userId) == "number", …)` / positive-amount guards at every method. That's now
extracted:

- **`SliceOwner.register(slice, default, read, validate?)`** (`ServerScriptService/Modules/SliceOwner.luau`)
  returns typed `get`/`mutate`/`op` for a profile slice in one call — generic over the slice type (inferred
  from `read`), so it stays cast-free; the optional `validate` closure registers the slice's data-layer
  invariant (see [#13](#13-slice-invariants-enforced-at-the-data-layer)). See the recipe in
  [conventions: Adding a service that owns a profile slice](conventions.md#adding-a-service-that-owns-a-profile-slice).
- **`Guard`** (`ReplicatedStorage/Shared/Modules/Guard.luau`) centralises the repeated runtime
  argument validators (`userId`, `positiveAmount`, `nonNegativeAmount`).

`CurrencyServiceServer` and `InventoryServiceServer` now contain only their real domain logic (caps,
stacking, batching) on top of these. What's left is the thin, genuinely-per-service shell (the
`export type` interface + `init`/`getState`), which is intentionally NOT abstracted: a metatable
`BaseService` class would fight the lean annotated-literal pattern and reintroduce the `self`-typing
casts that pattern eliminates. A codegen **template/snippet** for the shell remains a possible
convenience, but there is no longer a boilerplate-duplication problem to solve.

---

### 9. Limited Client-Side Schema Validation
Replicated state arrives over charm-sync and is applied into `ClientStore` atoms. The client trusts
server data (correct for a server-authoritative model). `StateSyncServiceClient` guards that the
inbound payload is a table before handing it to charm-sync, but does not deep-validate slice shapes:

```lua
remote.OnClientEvent:Connect(function(payloads)
    if type(payloads) ~= "table" then
        log:warn("Ignoring non-table charm-sync payload:", typeof(payloads))
        return
    end
    client.patch(payloads) -- slice values applied without deep validation
end)
```

**Impact:** A malformed payload (from a bug, not an exploit) could write unexpected values into the
reactive atoms.

**Future Consideration:** Add optional per-slice schema validation in development mode.

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

Critical mutations are logged at the audit level: `mutate()` writes `MUTATE_SUCCESS` and a
committed `transaction()` writes `TRANSACTION_COMMIT` per affected user. Audit lines are recorded
in the in-memory ring buffer (the debug overlay's log panel) **and** printed to the Roblox
console, so they reach live-server output/log analytics rather than evaporating with the ring on
shutdown. This provides a baseline for tracking economy changes, though there is no dedicated
audit database.

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

### 13. Slice Invariants Enforced at the Data Layer
**Current Status:** ✅ Implemented via per-slice validators.

Domain caps (currency `MAX_CURRENCY` / non-negative, inventory `MAX_INVENTORY_SIZE`) used to live only
in the owning service's methods (`CurrencyService:addCurrency`, …). A raw
`PlayerDataService:transaction()` op built with `currencyOp`/`inventoryOp` — whose mutator is arbitrary
server code — could therefore bypass them and write an out-of-range value (e.g. a trade pushing gold
past the cap or negative).

Slices now register an optional **invariant validator** alongside their path. `SliceOwner.register`
takes a `validate` closure typed to the slice value; it is stored via
`PlayerDataConstants.registerProfilePath` and run by **both** `mutate()` and `transaction()` after each
mutator, inside the no-yield locked region. A violation rolls the write back exactly like a `false`
return — so the cap holds no matter which path built the write:

```lua
-- CurrencyServiceServer.luau — the invariant, enforced by the data layer for every write path.
local currencySlice = SliceOwner.register("currency", { gold = 100, gems = 10 }, function(profile)
    return profile.currency
end, function(currency) -- validate: registered key, number, >= 0, <= MAX_CURRENCY per key
    for key, value in currency do
        if not CurrencyConstants.isValidCurrencyType(key) then
            return false, `currency key "{key}" is not a registered currency`
        end
        if type(value) ~= "number" or value < 0 or value > CurrencyConstants.MAX_CURRENCY then
            return false, `currency "{key}" out of range`
        end
    end
    return true
end)
```

**Scope:** validators are opt-in per slice and enforce only what that slice registers (currency:
registered keys + numeric range; inventory: size cap + per-item shape, registered itemType, positive
quantity today). They run for buggy server code as well as raw ops — they are a correctness net,
not an authorization boundary (the client already cannot reach these paths). A validator must be pure
and synchronous, like a mutator.

---

## Summary Table

| Limitation | Severity | Workaround Available |
|------------|----------|---------------------|
| Manual type sync (`CurrencyType`) | Low | Runtime validation on boot (`validateCurrencyTypes`) |
| ByteNet coupling | — | ✅ Resolved (dead structs removed; `PlayerDataTypes` is types-only) |
| `ProfilePath` compile-time safety | Low | Registry adopted (runtime-checked) |
| Network batching | — | ✅ Handled by charm-sync (Heartbeat-coalesced) |
| ProfileStore locking (cross-server) | High | Same-server transactions only; see §5 and §12 |
| Schema versioning | Low | Implemented (`PlayerDataMigrations`) |
| No offline retry | Low | Queue pattern |
| No BaseService | ✅ Resolved | Guard + SliceOwner extract the scaffolding; shell intentionally left |
| No client validation | Low | Dev-mode validation |
| No inventory slots | Low | Add slot field |
| Audit trail persistence | Low | Console + ring buffer today; no dedicated database |
| No multi-server txn | High | MessagingService + locks, or memory store |
| Cap bypass via raw txn ops | ✅ Resolved | Per-slice validators enforced by `mutate()`/`transaction()` (see §13) |
