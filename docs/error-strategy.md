# Error Strategy

This document defines the error handling conventions for all services in this codebase.

## Core Principle

**Fail fast for developer errors, gracefully handle runtime conditions.**

## Error Handling Rules

| Scenario | Approach | Rationale |
|----------|----------|-----------|
| Invalid argument type | `assert()` | Developer error - fix the bug |
| Invalid argument value | `assert()` | Developer error - fix the bug |
| Profile not loaded | Return `false` / `nil` | Runtime condition - expected |
| Player left during operation | Return `false` / `nil` | Runtime condition - expected |
| External API failure (DataStore, HTTP) | `pcall()` + log + graceful handling | Can't control external systems |
| Invariant violation (should never happen) | `assert()` or `error()` | Indicates a bug - crash loudly |

## Examples

### 1. Input Validation (use `assert`)

```lua
function MyService:doSomething(userId: number, amount: number): boolean
    assert(type(userId) == "number", "userId must be a number")
    assert(type(amount) == "number" and amount > 0, "amount must be a positive number")
    -- ...
end
```

**Why:** If a developer passes the wrong type, the code should crash immediately so they fix it. These errors should never reach production.

### 2. Runtime Conditions (return `false` / `nil`)

```lua
function MyService:doSomething(userId: number): boolean
    local profile = PlayerDataService:getProfile(userId)
    if not profile then
        return false -- Player may have left, profile not loaded yet
    end
    -- ...
end
```

**Why:** Players leaving, profiles not being ready, or data being nil are expected runtime conditions. The caller decides how to handle them.

### 3. External API Calls (use `pcall`)

```lua
local success, result = pcall(function()
    return self.PlayerStore:StartSessionAsync(...)
end)

if not success then
    log:error("Failed to load profile:", result)
    player:Kick("Profile load error - Please rejoin")
    return
end
```

**Why:** External systems (DataStore, HTTP, ProfileStore) can fail for reasons outside our control. Wrap them in `pcall` to handle failures gracefully.

### 4. Invariant Violations (use `assert` or `error`)

```lua
-- This should never happen if code is correct
local entry = self._services[name]
assert(entry, `Service "{name}" is not registered`)
```

**Why:** If an invariant is violated, something is fundamentally wrong. Crash loudly so the bug is found and fixed.

## Return Value Conventions

| Return Type | Meaning |
|-------------|---------|
| `boolean` | `true` = success, `false` = operation failed (expected) |
| `T?` (optional) | `nil` = not found / not available |
| `T, string?` | Value + optional error message for debugging |

## Logging Guidelines

| Log Level | When to Use |
|-----------|-------------|
| `log:debug()` | Successful operations, state changes (verbose) |
| `log:info()` | Important events, milestones |
| `log:warn()` | Recoverable issues, unexpected but handled conditions |
| `log:error()` | Failures that need attention, external API errors |

## Anti-Patterns to Avoid

### ❌ Silent failures
```lua
-- BAD: Silently returns without logging
if not profile then
    return false
end
```

### ✅ Log then return
```lua
-- GOOD: Log the condition, then return
if not profile then
    log:warn("Cannot mutate, profile not loaded for userId:", userId)
    return false
end
```

### ❌ Catching all errors
```lua
-- BAD: Swallows all errors including bugs
local success, err = pcall(function()
    doEverything()
end)
```

### ✅ Targeted pcall
```lua
-- GOOD: Only wrap the external call
local success, result = pcall(function()
    return externalAPI:Call()
end)
-- Let other errors propagate
```
