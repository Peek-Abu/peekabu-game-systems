# Coding Conventions

This document defines all coding standards, patterns, and style choices for this codebase. Follow these conventions for consistency across all services.

---

## Table of Contents

1. [Method Syntax (`.` vs `:`)](#method-syntax--vs-)
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
12. [Adding Admin Commands (Cmdr)](#adding-admin-commands-cmdr)

---

## Method Syntax (`.` vs `:`)

### Lifecycle Methods → Dot Syntax

Lifecycle methods are called **by the framework** (ServiceController), not by user code. Use dot syntax with explicit `self`:

```lua
function MyService.init(self: MyService, config: Config)
    -- Called by ServiceController:initService()
end

function MyService.start(self: MyService)
    -- Called by ServiceController:startService()
end

function MyService.stop(self: MyService)
    -- Called by ServiceController:stopService()
end
```

**Why:** Visually distinguishes "framework-managed" from "user-called" methods. Engineers and AI can identify method ownership at a glance.

**`self` vs `_self`**:
- Use `self` when the method body uses the service table (e.g., `self.Store = ...`).
- Use `_self` when the method capture is required by the dot syntax signature but remains unused. This silences the **Unused local self** (Roblox LSP) warnings.

### Runtime Methods → Colon Syntax

Runtime methods are called **by other code** (services, scripts, UI). Use colon syntax:

```lua
function MyService:doSomething(userId: number): boolean
    -- Called by other services or scripts
end

function MyService:getState(): { [string]: any }
    -- Called for debugging
end
```

### Quick Reference

| Method Type | Syntax | Example |
|-------------|--------|---------|
| `init` | `.` | `function MyService.init(self)` or `(_self)` |
| `start` | `.` | `function MyService.start(self)` or `(_self)` |
| `stop` | `.` | `function MyService.stop(self)` or `(_self)` |
| All other methods | `:` | `function MyService:doThing()` |

---

## Strict Mode

All files must use strict mode:

```lua
--!strict
```

This enables Luau's type checker for compile-time safety.

---

## Docstrings

Use Moonwave-compatible docstrings (`--[=[ ]=]`) for all public methods:

```lua
--[=[
    Brief description of what the method does.
    Additional context if needed.
    
    @param paramName Type -- Description of parameter
    @param optionalParam Type? -- Optional parameter (note the ?)
    @return ReturnType -- Description of return value
]=]
function MyService:methodName(paramName: Type, optionalParam: Type?): ReturnType
```

### Examples

**Simple method:**
```lua
--[=[
    Gets the inventory for a specified user.
    @param userId number -- The user ID to get inventory for
    @return {PlayerDataTypes.InventoryItem} -- Array of inventory items
]=]
function InventoryServiceServer:getInventory(userId: number): { PlayerDataTypes.InventoryItem }
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
function InventoryServiceServer:hasItem(
    userId: number,
    targetItem: PlayerDataTypes.InventoryItem,
    amount: number?
): boolean
```

**Lifecycle method:**
```lua
--[=[
    Initializes the service and sets up event connections.
    @param self MyService -- The service instance
    @param config Config -- Configuration options
]=]
function MyService.init(self: MyService, config: Config)
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
function MyService:doSomething(userId: number, currencyType: string, amount: number): boolean
    -- 1. Type assertions (in parameter order)
    assert(type(userId) == "number", `userId must be a number, got {type(userId)}`)
    assert(type(currencyType) == "string", `currencyType must be a string, got {type(currencyType)}`)
    assert(type(amount) == "number" and amount > 0, `amount must be a positive number, got {type(amount)}: {amount}`)
    
    -- 2. Validation assertions (in parameter order)
    assert(CurrencyUtils.isValidCurrencyType(currencyType), `invalid currency type: "{currencyType}"`)
    
    -- 3. Method logic starts here
    local profile = PlayerDataService:getProfile(userId)
    -- ...
end
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

```lua
-- Boolean return: operation that can fail
function CurrencyService:addCurrency(userId: number, currencyType: string, amount: number): boolean

-- Optional return: lookup that might not find anything
function PlayerDataService:getProfile(userId: number): PlayerDataTypes.PlayerProfile?

-- Guaranteed return: pure function
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
| Private fields | `_` prefix | `self._services` |

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

local MyServiceServer = {}
MyServiceServer.dependencies = { "OtherService" } :: { string }

local janitor = Janitor.new()

--[=[
    Initializes the service.
    @param self MyServiceServer -- The service instance
]=]
function MyServiceServer.init(_self: MyServiceServer)
    -- Setup code
end

--[=[
    Starts the service after all dependencies are initialized.
    @param self MyServiceServer -- The service instance
]=]
function MyServiceServer.start(_self: MyServiceServer)
    -- Start code (if needed)
end

--[=[
    Cleans up the service.
    @param self MyServiceServer -- The service instance
]=]
function MyServiceServer.stop(_self: MyServiceServer)
    janitor:Cleanup()
    log:debug("Service stopped")
end

--[=[
    Public method example.
    @param userId number -- The user ID
    @return boolean -- Success status
]=]
function MyServiceServer:doSomething(userId: number): boolean
    assert(type(userId) == "number", `userId must be a number, got {type(userId)}`)
    -- Implementation
    return true
end

--[=[
    Returns the current state for debugging.
    @return { [string]: any } -- Service state
]=]
function MyServiceServer:getState(): { [string]: any }
    return {}
end

type MyServiceServer = typeof(MyServiceServer)
return MyServiceServer :: MyServiceServer
```

---

## Type Annotations

### Always Annotate

- Function parameters
- Function return types
- Module-level variables that hold state

### Type Export Pattern

```lua
-- At bottom of module
type MyServiceServer = typeof(MyServiceServer)
return MyServiceServer :: MyServiceServer
```

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

## Complete Method Template

```lua
--[=[
    Brief description of the method.
    @param userId number -- The user ID
    @param amount number -- The amount (must be positive)
    @return boolean -- True if successful, false otherwise
]=]
function MyService:doSomething(userId: number, amount: number): boolean
    -- Type assertions
    assert(type(userId) == "number", `userId must be a number, got {type(userId)}`)
    assert(type(amount) == "number" and amount > 0, `amount must be a positive number, got {type(amount)}: {amount}`)
    
    -- Runtime checks
    local profile = PlayerDataService:getProfile(userId)
    if not profile then
        log:warn("Cannot proceed, profile not loaded for userId:", userId)
        return false
    end
    
    -- Method logic
    -- ...
    
    return true
end
```
---

## Creating New Systems

When creating a new system/service infrastructure, follow these steps:

1. **Create the Script**: Place it in `src/ServerScriptService/Services/[Name]/[Name]ServiceServer.luau` (or `src/ReplicatedStorage/Client/Services/` for client).
2. **Define Dependencies**: List other services it requires in `.dependencies`.
3. **Implement Lifecycle**: Use dot syntax for `init`, `start`, and `stop`.
4. **Register in ServerHandler**: Add it to `src/ServerScriptService/ServerHandler.server.luau` for it to be loaded.
5. **Create Tests**: Immediately create a `[Name]ServiceServer.spec.luau` alongside it.

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
