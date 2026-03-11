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

> Rare exception: a file may use `--!nocheck` only when it requires a module that is created at
> **runtime** and so cannot be resolved statically (e.g. `AdminServiceClient` requires Cmdr's
> runtime-replicated `CmdrClient`). Keep all real logic out of such files. This is a deliberate,
> commented escape hatch — not a default.

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
assert(CurrencyUtils.isValidCurrencyType(currencyType), `invalid currency type: "{currencyType}"`)
assert(ItemDefinitions[itemType], `unknown item type: "{itemType}"`)
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
    assert(CurrencyUtils.isValidCurrencyType(currencyType), `invalid currency type: "{currencyType}"`)

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

### Decision Table

| Scenario | Approach | Rationale |
|----------|----------|-----------|
| Invalid argument type | `assert()` | Developer error - fix the bug |
| Invalid argument value | `assert()` | Developer error - fix the bug |
| Profile not loaded | Return `false` / `nil` | Runtime condition - expected |
| Player left during operation | Return `false` / `nil` | Runtime condition - expected |
| External API failure (DataStore, HTTP) | `pcall()` + log + handle | Can't control external systems |
| Invariant violation | `assert()` or `error()` | Indicates a bug - crash loudly |

### When to Use `pcall`

| Situation | Use pcall? | Why |
|-----------|------------|-----|
| DataStore/ProfileStore calls | ✅ Yes | Network can fail, rate limits |
| HTTP requests | ✅ Yes | External services can timeout |
| Service init/start | ✅ Yes | One bad service shouldn't crash all |
| Parsing JSON/user input | ✅ Yes | Malformed data shouldn't crash |
| User-provided callbacks | ✅ Yes | You don't control their code |
| Internal function calls | ❌ No | Bugs should surface immediately |
| Simple math/table operations | ❌ No | These shouldn't fail |
| Assertions | ❌ No | These are intentional crashes |

### pcall Pattern

```lua
local success, result = pcall(function()
    return somethingThatMightFail()
end)

if not success then
    log:error("Operation failed:", result)
    return nil -- or handle gracefully
end

-- result is the return value when success is true
```

### Runtime Conditions (Don't Assert)

```lua
-- WRONG: Asserting on runtime condition
assert(profile, "Profile not loaded")

-- RIGHT: Return gracefully
local profile = PlayerDataService:getProfile(userId)
if not profile then
    log:warn("Cannot mutate, profile not loaded for userId:", userId)
    return false
end
```

### Anti-Patterns

❌ **Silent failures:**
```lua
if not profile then
    return false  -- No logging!
end
```

✅ **Log then return:**
```lua
if not profile then
    log:warn("Cannot mutate, profile not loaded for userId:", userId)
    return false
end
```

❌ **Catching all errors:**
```lua
local success, err = pcall(function()
    doEverything()  -- Swallows bugs!
end)
```

✅ **Targeted pcall:**
```lua
local success, result = pcall(function()
    return externalAPI:Call()  -- Only wrap the risky call
end)
```

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

### Examples

```lua
log:debug("Profile loaded for userId:", userId)
log:info("Service initialized")
log:warn("Cannot mutate, profile not loaded for userId:", userId)
log:error("Failed to load profile:", errorMessage)
```

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
function CurrencyUtils.formatCurrency(amount: number, currencyType: string?): string
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
| Events | `*Events.luau` | `InventoryEvents.luau` |
| Signals | `*Signals.luau` | `InventorySignals.luau` |
| Utils | `*Utils.luau` | `InventoryUtils.luau` |
| Constants | `*Constants.luau` | `CurrencyConstants.luau` |
| Types | `*Types.luau` | `PlayerDataTypes.luau` |

### Variables

| Type | Convention | Example |
|------|------------|---------|
| Local variables | camelCase | `playerProfile` |
| Constants | SCREAMING_SNAKE_CASE | `PROFILE_TEMPLATE` |
| Types | PascalCase | `PlayerProfile` |
| Private fields/methods | `_` prefix | `self._services`, `_mutateCurrency` |

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

- Indexing a typed struct by a dynamic string key: `(profile.Data :: any)[path]`.
- Narrowing a value off the network (ByteNet) to its real union: `data.currencyType :: CurrencyType`.
- Asserting the type of a dynamically-required module: `require(ServerService) :: ServiceController.ServiceModule`.

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
4. **Register in ServerHandler**: Add it (or let the auto-discovery loop find it) in `src/ServerScriptService/ServerHandler.server.luau` so it is loaded.
5. **Create Tests**: Immediately create a `[Name]ServiceServer.spec.luau` alongside it.

---

## Mutating Player Data

All persistent player state (currency, inventory, and any future slice) lives in a single
ProfileStore profile owned by `PlayerDataServiceServer`. Access is **layered** — always use the
layer that matches who you are.

### The three layers

| Layer | API | Who calls it |
|-------|-----|--------------|
| **Public domain methods** — `CurrencyService:addCurrency`, `InventoryService:addItem`, … | validate input, enforce caps, **broadcast the change to the client** | **any service** that wants to change that data |
| **Private slice accessor** — `_mutateCurrency`, `_mutateInventory` | fills in the profile path; types the mutator argument | only the owning service, internally |
| **Primitive** — `PlayerDataService:mutate` / `:transaction` | raw profile write — no validation, cap, or broadcast | a slice owner's accessor (`mutate`), or cross-slice features (`transaction`) |

**Rule:** to change another service's data, call its **public method**. Never call
`PlayerDataService:mutate(userId, "currency", …)` or the private `_mutateCurrency` from outside
the owning service — both skip the cap **and** the client broadcast, so the client desyncs. The
`_` prefix means "internal," not "a shortcut."

### Adding a service that owns a profile slice

A service "owns a slice" when it registers a root key on the profile. Follow this pattern (see
`CurrencyServiceServer` / `InventoryServiceServer` for complete examples):

1. **Register the path + defaults** at module load:
   ```lua
   PlayerDataConstants.registerProfilePath("quests", { active = {}, completed = {} })
   ```
2. **Add one private, typed accessor** — the only place the path string is written. Declare it in
   the interface, then write it as a field (no inline annotations):
   ```lua
   -- interface:  _mutateQuests: (self: QuestServiceServer, userId: number, fn: (quests: PlayerDataTypes.Quests) -> boolean?) -> boolean,
   _mutateQuests = function(_self, userId, fn)
       return PlayerDataService:mutate(userId, "quests", fn)
   end,
   ```
3. **Expose public methods** that mutate via the accessor and then **broadcast** the change to the
   owning client so the UI stays in sync. Other services call these — never the accessor.
4. **Extend `PlayerProfile`** in `PlayerDataTypes.luau` with the new field, and write the spec.

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

⚠️ **Two things `transaction` does NOT do — you must handle them at the call site:**

1. **It does not broadcast.** After a successful transaction, resync every affected client
   (`PlayerDataService:broadcastProfile(userId)` per affected user). **Known gap:** a full-profile
   rebroadcast currently fires only `PlayerDataServiceClient.ProfileLoaded`, *not* the per-domain UI
   signals (`CurrencySignals` / `InventorySignals`) — no domain client service listens to
   `ProfileLoaded` yet. So until that wiring exists, the UI may not refresh after a transaction.
   Build this together with your first transaction feature, not speculatively.
2. **It does not type the path.** Op `path` is a raw string (the encapsulation only covers
   single-slice `mutate`). When transactions get real callers, extend the pattern with per-domain
   op-builders so the path is written once and the mutator is typed:
   ```lua
   -- Optional helper on the owning service (interface entry +):
   currencyOp = function(_self, userId, fn)
       return { userId = userId, path = "currency", mutator = fn }
   end,
   ```

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
