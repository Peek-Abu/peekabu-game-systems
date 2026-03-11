# Coding Conventions

This document defines all coding standards, patterns, and style choices for this codebase. Follow these conventions for consistency across all services.

---

## Table of Contents

1. [Service Module Shape](#service-module-shape)
2. [Strict Mode](#strict-mode)
3. [Docstrings](#docstrings)
4. [Assertions](#assertions)
5. [Error Handling](#error-handling)
6. [Logging](#logging)
7. [Return Value Conventions](#return-value-conventions)
8. [Naming Conventions](#naming-conventions)
9. [File Structure](#file-structure)
10. [Type Annotations](#type-annotations)
11. [Creating New Systems](#creating-new-systems)
12. [Mutating Player Data](#mutating-player-data)
13. [Adding Admin Commands (Cmdr)](#adding-admin-commands-cmdr)

---

## Service Module Shape

Every service module follows **one** shape — the "lean annotated literal" — so it type-checks
end to end under `--!strict` with **zero casts** and types declared in **exactly one place**.

### The three rules

**1. Declare an explicit interface.** `export type MyService = { ... }` lists every field and
method. This is the single source of truth for the module's types.

> Do **not** use `type MyService = typeof(MyService)`. `typeof` re-derives the type from the
> implementation and **widens** method params at generic boundaries (e.g. a `CurrencyType`
> literal union passed into a ByteNet `string` field becomes `string`). The module's exported
> type then disagrees with its own definition (`Expected MyService to be exactly MyService`)
> and **every `require()` consumer fails**. A hand-written interface never widens.

**2. Build the module as one annotated table literal.** `local MyService: MyService = { ... }`.
Annotating the literal makes Luau push each signature from the interface **down into** the
matching method body — so **method bodies carry no inline type annotations**. `self` and every
parameter are typed from the interface. Types live in one place.

**3. Methods are fields.** `methodName = function(self, arg) ... end`. There is no dot-vs-colon
split in the *definition* — lifecycle methods (`init`/`start`/`stop`) and runtime methods are all
just fields. (You still **call** runtime methods with colon: `MyService:doThing()`.)

### `self` vs `_self`

- Use `self` when the body reads or writes the service table (`self.Store = ...`, `self:other()`).
- Use `_self` when the body never touches the service table (silences the **unused self** lint).

### Example

```lua
export type MyService = {
    dependencies: { string },
    init: (self: MyService) -> (),
    doThing: (self: MyService, userId: number) -> boolean,
    getState: (self: MyService) -> { [string]: any },
}

local MyService: MyService = {
    dependencies = { "OtherService" },

    init = function(self) -- no inline types — they come from the interface above
        -- setup
    end,

    doThing = function(self, userId)
        assert(type(userId) == "number", `userId must be a number, got {type(userId)}`)
        return true
    end,

    getState = function(_self)
        return {}
    end,
}

return MyService
```

### Two gotchas

**Don't reference the module by name inside the literal.** While the literal is being
constructed, the `local MyService` is not bound yet. A method that needs a module-level field
must use `self.field`, **not** `MyService.field` (the latter errors *"Unknown global
'MyService'"*). Declare such fields in the interface and initialize them in the literal.

**Don't use colon method *statements* (`function MyService:method()`).** Those do not receive
their param types from the annotated literal, so params re-widen and you'd need both per-method
annotations *and* a `{} :: MyService` seed cast — the worst of all worlds. The annotated literal
with field methods needs neither.

---

## Strict Mode

All files must use strict mode:

```lua
--!strict
```

This enables Luau's type checker for compile-time safety, and the `luau-lsp analyze` step in CI
is a **blocking merge gate** (see `docs/ci-cd.md`) — a type error fails the pipeline.

> Rare exception: a file may skip `--!strict` (via `--!nocheck` or `--!nonstrict`) only at a
> **dynamic Cmdr boundary** that cannot be resolved statically — a module created at runtime
> (e.g. `AdminServiceClient` requires Cmdr's runtime-replicated `CmdrClient`) or a Cmdr type
> definition receiving Cmdr's untyped `registry` (the `Shared/CmdrTypes` modules). Keep all real
> logic out of such files. This is a deliberate, commented escape hatch — not a default.

---

## Docstrings

Use Moonwave-compatible docstrings (`--[=[ ]=]`) for all public methods. The docstring sits
directly above the method **field** in the literal. Because method bodies carry no inline type
annotations, the docstring's `@param`/`@return` lines are the prose description of the types
that live in the interface.

```lua
--[=[
    Brief description of what the method does.
    Additional context if needed.

    @param paramName Type -- Description of parameter
    @param optionalParam Type? -- Optional parameter (note the ?)
    @return ReturnType -- Description of return value
]=]
methodName = function(self, paramName, optionalParam)
    -- ...
end,
```

### Examples

**Simple method:**
```lua
--[=[
    Gets the inventory for a specified user.
    @param userId number -- The user ID to get inventory for
    @return {PlayerDataTypes.InventoryItem} -- Array of inventory items
]=]
getInventory = function(_self, userId)
    -- ...
end,
```

**Method with optional params:**
```lua
--[=[
    Checks if a player has a specific item in their inventory.
    @param userId number -- The user ID to check
    @param targetItem PlayerDataTypes.InventoryItem -- The item to check for
    @param amount number? -- Optional amount required (defaults to 1)
    @return boolean -- True if the player has the item (and quantity)
]=]
hasItem = function(self, userId, targetItem, amount)
    -- ...
end,
```

**Lifecycle method:**
```lua
--[=[
    Initializes the service and sets up event connections.
    @param self MyService -- The service instance
    @param config Config -- Configuration options
]=]
init = function(self, config)
    -- ...
end,
```

The matching interface entries declare the types once:

```lua
export type MyService = {
    getInventory: (self: MyService, userId: number) -> { PlayerDataTypes.InventoryItem },
    hasItem: (self: MyService, userId: number, targetItem: PlayerDataTypes.InventoryItem, amount: number?) -> boolean,
    init: (self: MyService, config: Config) -> (),
}
```

---

## Assertions

### Core Principle

**Use assertions for developer errors. Use return values for runtime conditions.**

### Standard Format

All assertions use **string interpolation** with the actual value included:

```lua
assert(condition, `message describing expected, got {actualValue}`)
```

### Assertion Patterns by Type

#### Type Checks
```lua
assert(type(userId) == "number", `userId must be a number, got {type(userId)}`)
assert(type(item) == "table", `item must be a table, got {type(item)}`)
assert(type(mutator) == "function", `mutator must be a function, got {type(mutator)}`)
assert(type(path) == "string", `path must be a string, got {type(path)}`)
```

#### Value Checks
```lua
assert(amount > 0, `amount must be positive, got {amount}`)
assert(amount >= 0, `amount must be non-negative, got {amount}`)
assert(#items > 0, `items cannot be empty, got {#items} items`)
```

#### Combined Type + Value Checks
```lua
assert(type(amount) == "number" and amount > 0, `amount must be a positive number, got {type(amount)}: {amount}`)
assert(type(amount) == "number" and amount >= 0, `amount must be a non-negative number, got {type(amount)}: {amount}`)
```

#### Enum/Union Checks
```lua
assert(
    action == "add" or action == "remove" or action == "update",
    `action must be "add", "remove", or "update", got "{action}"`
)
```

#### Validation Function Checks
```lua
assert(CurrencyConstants.isValidCurrencyType(currencyType), `invalid currency type: "{currencyType}"`)
assert(ItemDefinitions.isValidItemType(itemType), `unknown item type: "{itemType}"`)
```

#### Required Field Checks
```lua
assert(item.itemType, `item must have an itemType field`)
assert(config.storeName, `config must have a storeName field`)
```

#### Instance Checks
```lua
assert(typeof(player) == "Instance" and player:IsA("Player"), `expected Player instance, got {typeof(player)}`)
```

### Assertion Order

Place assertions at the **top of the method**, before any logic:

```lua
doSomething = function(self, userId, currencyType, amount)
    -- 1. Type assertions (in parameter order)
    assert(type(userId) == "number", `userId must be a number, got {type(userId)}`)
    assert(type(currencyType) == "string", `currencyType must be a string, got {type(currencyType)}`)
    assert(type(amount) == "number" and amount > 0, `amount must be a positive number, got {type(amount)}: {amount}`)

    -- 2. Validation assertions (in parameter order)
    assert(CurrencyConstants.isValidCurrencyType(currencyType), `invalid currency type: "{currencyType}"`)

    -- 3. Method logic starts here
    local profile = PlayerDataService:getProfile(userId)
    -- ...
end,
```

### Parameter Validation Order

1. **Type assertions** - Validate parameter types in declaration order
2. **Value assertions** - Validate parameter values/constraints in declaration order
3. **Cross-parameter assertions** - Validate relationships between parameters
4. **Runtime checks** - Check runtime conditions (return false/nil, don't assert)

---

## Error Handling

### Core Principle

**Fail fast for developer errors, gracefully handle runtime conditions.**

The full decision table (assert vs. return vs. pcall), worked examples, and anti-patterns are
maintained in **[error-strategy.md](error-strategy.md)**; targeted pcall usage (what to wrap,
what not to, and the standard pattern) is in **[pcall-guide.md](pcall-guide.md)**. Those two
docs are the single source of truth — this section deliberately doesn't restate their tables,
so they can't drift out of sync.

In one line: `assert()` on developer errors (bad argument types/values, violated invariants),
return `false`/`nil` on expected runtime conditions (profile not loaded, player left), and
reserve `pcall()` for external systems you don't control (DataStore, HTTP, user callbacks).

---

## Logging

### Logger Usage

Every service should create a logger instance:

```lua
local Logger = require(ReplicatedStorage.Shared.Modules.Logger)
local log = Logger.new("MyServiceName")
```

### Log Levels

| Level | Method | When to Use |
|-------|--------|-------------|
| DEBUG | `log:debug()` | Successful operations, state changes (verbose) |
| INFO | `log:info()` | Important events, milestones |
| WARN | `log:warn()` | Recoverable issues, unexpected but handled conditions |
| ERROR | `log:error()` | Failures that need attention, external API errors |
| AUDIT | `log:audit()` | Economy-critical mutations — `mutate()` / `transaction()` commits, admin command runs. The permanent trail; also printed to the console (see Output sinks) |

### Examples

```lua
log:debug("Profile loaded for userId:", userId)
log:info("Service initialized")
log:warn("Cannot mutate, profile not loaded for userId:", userId)
log:error("Failed to load profile:", errorMessage)
log:audit(`userId={userId}`, "MUTATE_SUCCESS", `path={path}`)
```

### Output sinks

Every emitted line is recorded into an in-memory ring buffer (`Logger.getHistory()` / `Logger.subscribe()`),
which is what the in-game **Service & State Debugger** (F4) log panel reads. **WARN and ERROR** also
`warn` to the Roblox console, and **AUDIT** also `print`s — an audit trail that lived only in the
in-memory ring would evaporate on shutdown and never reach live-server output. `DEBUG`/`INFO` are
menu-only, so the console stays quiet while CI, live-server output, and the Studio console still
surface failures and the economy trail. The buffer is also the seam for future remote telemetry
(subscribe and forward `AUDIT` off-platform).

---

## Return Value Conventions

| Return Type | Meaning | When to Use |
|-------------|---------|-------------|
| `boolean` | `true` = success, `false` = expected failure | Mutations, operations that can fail |
| `T?` | Value or `nil` if not found | Getters, lookups |
| `T` | Always returns value | Pure functions, guaranteed results |

### Examples

These signatures live in the service interface (the single place types are declared):

```lua
-- Boolean return: operation that can fail
addCurrency: (self: CurrencyServiceServer, userId: number, currencyType: CurrencyConstants.CurrencyType, amount: number) -> boolean,

-- Optional return: lookup that might not find anything
getProfile: (self: PlayerDataServiceServer, userId: number) -> PlayerDataTypes.PlayerProfile?,
```

Pure helper functions (not service methods) still use a plain function with annotations:

```lua
-- Guaranteed return: pure function in a *Utils module
function CurrencyUtils.formatCurrency(amount: number, currencyType: CurrencyConstants.CurrencyType?): string
```

---

## Naming Conventions

### Services

| Location | Suffix | Example |
|----------|--------|---------|
| Server | `ServiceServer` | `InventoryServiceServer` |
| Client | `ServiceClient` | `InventoryServiceClient` |

### Files

| Type | Pattern | Example |
|------|---------|---------|
| Server service | `*ServiceServer.luau` | `InventoryServiceServer.luau` |
| Client service | `*ServiceClient.luau` | `InventoryServiceClient.luau` |
| Events (discrete ByteNet) | `*Events.luau` | see [Networking](architecture.md#networking) |
| Reactive state | `*Store.luau` / `SyncState.luau` | `ClientStore.luau`, `SyncState.luau` |
| Utils | `*Utils.luau` | `InventoryUtils.luau` |
| Constants | `*Constants.luau` | `CurrencyConstants.luau` |
| Types | `*Types.luau` | `PlayerDataTypes.luau` |

### Variables

| Type | Convention | Example |
|------|------------|---------|
| Local variables | camelCase | `playerProfile` |
| Constants | SCREAMING_SNAKE_CASE | `PROFILE_TEMPLATE` |
| Types | PascalCase | `PlayerProfile` |
| Private fields/methods | `_` prefix | `self._services`, `_cleanupPlayer` |

---

## File Structure

### Service File Template

```lua
--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

-- Package imports
local Janitor = require(ReplicatedStorage.Packages.Janitor)
local Logger = require(ReplicatedStorage.Shared.Modules.Logger)

-- Local imports
local SomeEvents = require(...)
local SomeTypes = require(...)

local log = Logger.new("MyServiceServer")

-- Module-level state (not part of the service table) lives here, above the interface.
local janitor = Janitor.new()

--[=[
    Public interface — the single place this service's types are declared.
]=]
export type MyServiceServer = {
    dependencies: { string },

    init: (self: MyServiceServer) -> (),
    start: (self: MyServiceServer) -> (),
    stop: (self: MyServiceServer) -> (),
    doSomething: (self: MyServiceServer, userId: number) -> boolean,
    getState: (self: MyServiceServer) -> { [string]: any },
}

local MyServiceServer: MyServiceServer = {
    dependencies = { "OtherService" },

    --[=[
        Initializes the service.
        @param self MyServiceServer -- The service instance
    ]=]
    init = function(_self)
        -- Setup code
    end,

    --[=[
        Starts the service after all dependencies are initialized.
        @param self MyServiceServer -- The service instance
    ]=]
    start = function(_self)
        -- Start code (if needed)
    end,

    --[=[
        Cleans up the service.
        @param self MyServiceServer -- The service instance
    ]=]
    stop = function(_self)
        janitor:Cleanup()
        log:debug("Service stopped")
    end,

    --[=[
        Public method example.
        @param userId number -- The user ID
        @return boolean -- Success status
    ]=]
    doSomething = function(_self, userId)
        assert(type(userId) == "number", `userId must be a number, got {type(userId)}`)
        -- Implementation
        return true
    end,

    --[=[
        Returns the current state for debugging.
        @return { [string]: any } -- Service state
    ]=]
    getState = function(_self)
        return {}
    end,
}

return MyServiceServer
```

---

## Type Annotations

### Always Annotate

- The service **interface** (`export type MyService = { ... }`) — declares every method and field.
- The module literal (`local MyService: MyService = { ... }`) — drives inference into the bodies.
- Module-level variables that hold state (`local playerProfiles: { [number]: Profile } = {}`).
- Pure functions in `*Utils` modules — parameters and return types.

You do **not** annotate service-method parameters or return types inline — the annotated literal
infers them from the interface. Don't repeat them.

### Service Type Pattern

```lua
-- Interface ABOVE the table — the single source of truth.
export type MyServiceServer = {
    dependencies: { string },
    doSomething: (self: MyServiceServer, userId: number) -> boolean,
}

-- Annotated literal builds the module; no `typeof`, no `:: ` cast.
local MyServiceServer: MyServiceServer = {
    dependencies = { "OtherService" },
    doSomething = function(_self, userId)
        return true
    end,
}

return MyServiceServer
```

> Generic methods are declared generically in the interface and still need no body
> annotation: `mutate: <T>(self: MyServiceServer, path: ProfilePath, mutator: (data: T) -> boolean?) -> boolean,`
> with `mutate = function(_self, path, mutator) ... end`.

### Casts

Casts (`::`) are avoided. The lean pattern needs none. The only casts in the codebase are at
genuine **dynamic boundaries** — narrowing a value whose type the checker cannot know
statically — and each is commented:

- Bridging an untyped package to its typed wrapper: `(Signal() :: any) :: Signal<T...>` in
  `SignalTyped`, `(ProfileStoreRaw :: any) :: Module` in `ProfileStoreTyped`.
- Asserting the type of a dynamically-required module in the boot loaders:
  `require(ServerService) :: ServiceController.ServiceModule` (`ServerHandler` / `ClientHandler`).
- Narrowing an `Instance` from the tree to its concrete class: `:: RemoteEvent` in
  `StateSyncServiceClient`.

(Registries that must hold heterogeneous entries — the per-slice atoms in `ServerStore`, the
`ProfilePath` string registry — are *typed* with an erased value type at the declaration rather
than cast; see [limitations #3](limitations.md#3-profilepath-registry-vs-compile-time-paths). Each
*consumer* still uses the narrow slice type.)

Never use `:: any` to silence a checker complaint about your own code. New casts need a
genuine justification.

### Shared Types

Define shared types in `ReplicatedStorage/Shared/Types/`:

```lua
-- PlayerDataTypes.luau
export type InventoryItem = {
    itemType: string,
    quantity: number?,
    instanceId: string?,
}

export type PlayerProfile = {
    currency: Currency,
    inventory: { InventoryItem },
}
```

---

## Creating New Systems

When creating a new system/service infrastructure, follow these steps:

1. **Create the Script**: Place it in `src/ServerScriptService/Services/[Name]/[Name]ServiceServer.luau` (or `src/ReplicatedStorage/Client/Services/` for client).
2. **Declare the interface + build the literal**: Follow the [Service Module Shape](#service-module-shape) — `export type` interface, then `local X: X = { ... }` with methods as fields.
3. **Define Dependencies**: List other services it requires in the `dependencies` field.
4. **Registration is automatic**: the boot loader (`src/ServerScriptService/ServerHandler.server.luau` / `ClientHandler`) auto-discovers any module matching the `*ServiceServer` / `*ServiceClient` naming convention — there is no manual registration site.
5. **Create Tests**: Immediately create a `[Name]ServiceServer.spec.luau` alongside it.

---

## Mutating Player Data

All persistent player state (currency, inventory, and any future slice) lives in a single
ProfileStore profile owned by `PlayerDataServiceServer`. Access is **layered** — always use the
layer that matches who you are.

### The three layers

| Layer | API | Who calls it |
|-------|-----|--------------|
| **Public domain methods** — `CurrencyService:addCurrency`, `InventoryService:addItem`, … | validate input, enforce caps | **any service** that wants to change that data |
| **Slice accessor** — `currencySlice.get` / `.mutate`, from `SliceOwner.register` | owns the path string; types `get`'s return and the mutator argument to the slice type | only the owning service, internally |
| **Primitive** — `PlayerDataService:mutate` / `:transaction` | raw profile write; mirrors the slice into `ServerStore` so charm-sync replicates it | `SliceOwner` (behind `.mutate`), or cross-slice features (`transaction`) |

**Rule:** to change another service's data, call its **public method**. Never call
`PlayerDataService:mutate(userId, "currency", …)` or another service's `SliceOwner` accessor from
outside the owning service — you'd skip that service's validation and caps. (Replication still
happens — `mutate` always mirrors into the reactive store — but the write would be unvalidated.)

### Adding a service that owns a profile slice

A service "owns a slice" when it registers a root key on the profile. Follow this pattern (see
`CurrencyServiceServer` / `InventoryServiceServer` for complete examples):

1. **Register the slice** at module load with `SliceOwner.register` — one call that registers the
   path + defaults AND returns typed `get`/`mutate` for it. The slice's value type is inferred from
   the `read` closure (a typed field access), so no path string is repeated and no casts are needed:
   ```lua
   local questSlice = SliceOwner.register("quests", { active = {}, completed = {} }, function(profile)
       return profile.quests
   end)
   -- questSlice.get(userId)     -> Quests?        (nil if the profile isn't loaded)
   -- questSlice.mutate(userId, function(quests) ... return true end)  -- `quests` is typed Quests
   ```
2. **Expose public methods** that read via `questSlice.get` and write via `questSlice.mutate`.
   Validate arguments with `Guard` (`Guard.userId`, `Guard.positiveAmount`, …) plus any
   domain-specific checks; keep the domain logic (caps, stacking, …) in these methods. Replication
   is automatic — `mutate` mirrors the slice into `ServerStore`, and charm-sync ships it to the
   owning client. Other services call these public methods — never `questSlice` directly.
3. **Extend `PlayerProfile`** in `PlayerDataTypes.luau` with the new field, and write the spec.
4. **If the slice replicates to the client**, wire it into the reactive spine: add one entry to
   `SliceManifest` (`Shared/State/SliceManifest.luau` — name + profile reader), and declare its
   atom + registry line in `ClientStore`. `SyncState.SLICES` and the `ServerStore` registry derive
   from the manifest automatically, and `ClientStore` is validated against it at require time, so a
   missed atom fails at boot. The StateSync services need no change. See
   [architecture: Reactive state](architecture.md#reactive-state).

### Transactions (cross-slice / cross-player atomicity)

Single-slice writes go through the public domain methods above. Use `PlayerDataService:transaction`
**only** when several mutations must succeed or fail **together** — e.g. a shop purchase (spend
currency **and** grant an item) or a trade between two players. `addCurrency`/`addItem` are each
individually atomic, but two in sequence are not: if the second fails, the first already committed.

```lua
local ok = PlayerDataService:transaction({
    { userId = uid, path = "currency",  mutator = function(c) c.gold -= cost; return c.gold >= 0 end },
    { userId = uid, path = "inventory", mutator = function(inv) table.insert(inv, item); return true end },
})
```

**Replication is handled.** On commit, `transaction` mirrors only the slice(s) each op's `path`
actually changed into `ServerStore` (not every affected profile in full), so the reactive UI updates
uniformly — the same per-slice `sync` a single mutation uses. (This is why the old "resync/rebroadcast
after a transaction" gap no longer exists.)

**Mutators are pure slice edits.** A mutator (whether passed to `mutate` or a transaction op) must be
synchronous — a yield is detected and rejected — and must not call `mutate()`/`transaction()` itself,
on **any** profile: a nested write commits outside the outer call's rollback snapshots, so it would
survive a later rollback and break all-or-nothing. Every nested data-layer call from inside a mutator
is refused at runtime. Need to touch several profiles or slices? Make each one a sibling op of the
same transaction.

⚠️ **One thing `transaction` does NOT do — you must handle it at the call site:**

**It does not type the path.** Op `path` is a raw string (the encapsulation only covers single-slice
`mutate`). To avoid restating it, each slice-owning service exposes a typed op-builder so the path is
written once and the mutator argument is typed — use these instead of raw op tables. `CurrencyService`
has `currencyOp` and `InventoryService` has `inventoryOp` (both built on `SliceOwner`'s `op`), already
used to compose transactions:
```lua
-- CurrencyServiceServer.luau — the path string appears only here:
currencyOp = function(_self, userId, mutator)
    return currencySlice.op(userId, mutator) -- { userId, path = "currency", mutator }, mutator typed to Currency
end,
```

---

## Reading State on the Client (the two-door rule)

Replicated player state lives in the `ClientStore` atoms, populated by charm-sync. There are exactly
**two sanctioned ways to read it, and which one you use depends on who you are** — not on preference.

| You are… | Read via | Why |
|----------|----------|-----|
| **Reactive UI** (a React component that should re-render on change) | the atom directly — `useAtom(ClientStore.currency)` | `useAtom` subscribes to the atom *reference*; a point-in-time snapshot can't drive re-renders |
| **Imperative code** (game logic, input handlers, anything that just needs the value *now*) | the client service getter — `CurrencyServiceClient:getCurrency()` | a Charm-agnostic, stable seam; callers never learn *how* the value is stored |

**Rule: imperative code does not `require(ClientStore)`.** Only the reactive UI layer and the client
services import it. Everything else goes through a `*ServiceClient` getter. This is why the thin
read-facades (`getCurrency`, `getInventory`) exist even though they look like pass-throughs — they
are the imperative read door, not redundant wrappers:

- **Encapsulation.** Imperative callers depend on the service API, not the storage mechanism. If
  client state ever moves off Charm atoms, only the service changes — not every call site.
- **A home for domain logic.** Anything beyond a raw snapshot (validation, formatting, "do I have
  enough?", item lookups) belongs on the service — see `getCurrencyAmount` / `hasCurrency` /
  `formatCurrency`. The snapshot getter is the shared internal accessor those build on.
- **Testable.** Specs can stub a service getter without standing up ClientStore + charm-sync.

**The client service never writes.** The server is authoritative; state arrives only as charm-sync
patches. Client services are read + domain-logic facades, never setters. See
[architecture: Reactive state](architecture.md#reactive-state).

---

## Adding Admin Commands (Cmdr)

We use **Cmdr** for all administrative operations. Admin commands should never mutate state directly; they should call methods on the relevant service.

### 1. Structure
- **Definitions**: `src/ServerScriptService/Commands/[CommandName].luau`
- **Server Implementations**: `src/ServerScriptService/Commands/[CommandName]Server.luau`

### 2. Implementation Pattern
Admin commands must wrap their logic in `AdminServiceServer` (or directly call the target service if authorized). Always ensure admin actions are logged.

```lua
-- Example Definition
return {
    Name = "GiveGold",
    Aliases = {"addgold"},
    Description = "Gives gold to a player.",
    Group = "Admins",
    Args = {
        {
            Type = "player",
            Name = "target",
            Description = "The player to give gold to",
        },
        {
            Type = "number",
            Name = "amount",
            Description = "Amount of gold to give",
        }
    }
}
```
