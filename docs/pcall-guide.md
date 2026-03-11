# When to Use `pcall` in Luau

## Quick Reference

| Situation | Use pcall? | Why |
|-----------|------------|-----|
| **DataStore/ProfileStore calls** | ✅ Yes | Network can fail, rate limits, etc. |
| **HTTP requests** | ✅ Yes | External services can timeout/fail |
| **Service init/start** | ✅ Yes | One bad service shouldn't crash all |
| **Parsing JSON/user input** | ✅ Yes | Malformed data shouldn't crash |
| **Calling user-provided callbacks** | ✅ Yes | You don't control their code |
| **Internal function calls** | ❌ No | Bugs should surface immediately |
| **Simple math/table operations** | ❌ No | These shouldn't fail |
| **Assertions** | ❌ No | These are intentional crashes |

---

## Basic Pattern

```lua
local success, result = pcall(function()
    return somethingThatMightFail()
end)

if not success then
    warn("Failed:", result) -- result is the error message when success is false
    return
end

-- result is now the return value when success is true
print("Got:", result)
```

---

## Common Examples

### DataStore / ProfileStore
```lua
local success, profile = pcall(function()
    return ProfileStore:StartSessionAsync(key, options)
end)

if not success then
    warn("Profile load failed:", profile)
    player:Kick("Data error - Please rejoin")
    return
end
```

### HTTP Requests
```lua
local success, response = pcall(function()
    return HttpService:GetAsync(url)
end)

if not success then
    warn("HTTP request failed:", response)
    return nil
end
```

### JSON Parsing
```lua
local success, data = pcall(function()
    return HttpService:JSONDecode(jsonString)
end)

if not success then
    warn("Invalid JSON:", data)
    return nil
end
```

### Service Initialization
```lua
local success, err = pcall(function()
    service:init(config)
end)

if not success then
    warn("Service init failed:", err)
    return false
end
```

---

## When NOT to Use `pcall`

### Don't wrap internal logic
```lua
-- BAD: Hides bugs
local success, result = pcall(function()
    return calculateDamage(player, weapon)
end)

-- GOOD: Let it crash so you notice the bug
local result = calculateDamage(player, weapon)
```

### Don't wrap assertions
```lua
-- BAD: Defeats the purpose of assertions
pcall(function()
    assert(player, "Player required")
end)

-- GOOD: Let assertions crash
assert(player, "Player required")
```

---

## Tips

1. **Log errors** - Always `warn()` when pcall fails so you can debug
2. **Handle gracefully** - Return early, use fallback values, or retry
3. **Don't overuse** - Only wrap things that can legitimately fail externally
4. **Keep pcall scope small** - Wrap only the risky operation, not huge blocks
