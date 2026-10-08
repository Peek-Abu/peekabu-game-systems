# Testing Guide

This document explains how to write and run tests for the venture framework using TestEZ.

---

## Table of Contents

1. [Setup](#setup)
2. [Running Tests](#running-tests)
3. [Writing Tests](#writing-tests)
4. [Test Organization](#test-organization)
5. [Test-Driven Development](#test-driven-development)
6. [Best Practices](#best-practices)
7. [Troubleshooting](#troubleshooting)

---

## Setup

### 1. Install Dependencies

Run Wally to install TestEZ:

```bash
wally install
```

This will install:
- `TestEZ` - The BDD-style testing framework

### 2. No Additional Setup Required

TestEZ works out of the box for authoring and running specs — no flags or special configuration
needed. (One caveat lives in the typecheck job, not here: `luau-lsp analyze` excludes `*.spec.luau`
because specs use TestEZ globals — `describe`/`it`/`expect` — that would otherwise need a
`testez.d.luau` definitions file. See [ci-cd.md](ci-cd.md).)

---

## Running Tests

### In Roblox Studio

1. Sync your project with Rojo: `rojo serve`
2. Connect to the Rojo server in Studio
3. **Opt in:** select `Workspace`, add a boolean attribute `RunTests`, set it `true`
4. Hit Play — `TestRunner.server.luau` runs the suite on server start
5. Check the Output window for test results

> **Why opt-in (and why not to play in a test session):** several specs exercise `init()`/`stop()`
> on REAL module singletons — e.g. `StateSyncServiceServer.spec` tears down and recreates the
> production charm-sync transport. Running the suite inside a live play session destroys that
> session's runtime state (found 2026-07-17: the auto-running suite permanently severed the live
> client's state sync every session — the client State tab never received a patch). Run tests OR
> play; never expect both from one session. Leave `RunTests` unset for normal play.

### Via Command Line (CI/CD)

CI does **not** use Lemur or `run-in-roblox`. The `test` job in
[.github/workflows/ci-cd.yml](../.github/workflows/ci-cd.yml) runs the suite in a real Roblox
runtime through **Open Cloud Luau Execution**:

1. `rojo build default.project.json --output dist.rbxlx` builds the place (specs and `DevPackages`
   included).
2. `scripts/python/upload_and_run_task.py dist.rbxlx tasks/runTests.luau` uploads the place and runs
   [`tasks/runTests.luau`](../tasks/runTests.luau) against it via the Open Cloud API.
3. `runTests.luau` seeds `ItemContentRegistry.init()`, runs the full TestEZ suite, and **`error()`s if any test
   fails** — which fails the Open Cloud task and therefore the CI job.

This mirrors the local Studio runner ([`TestRunner.server.luau`](../src/ServerScriptService/TestRunner.server.luau)),
which shares the same list of test locations. To reproduce locally without the cloud, run the Studio
runner (see above); the cloud path is only needed to gate merges. See
[ci-cd.md](ci-cd.md) for the required secrets/variables.

---

## Writing Tests

### Test File Naming

Test files must use the `.spec.luau` suffix and be placed alongside the module they test:

```
src/
  ReplicatedStorage/
    Shared/
      Features/
        Currency/
          Utils/
            CurrencyUtils.luau
            CurrencyUtils.spec.luau  ← Test file
```

### Basic Test Structure

TestEZ injects `describe`, `it`, `expect`, and other functions into the test environment automatically.

```lua
--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MyModule = require(script.Parent.MyModule)

return function()
    describe("MyModule", function()
        describe("myFunction", function()
            it("should do something", function()
                local result = MyModule.myFunction(5)
                expect(result).to.equal(10)
            end)
        end)
    end)
end
```

**Important:** Test files must return a function that contains your test suite.

### Common Matchers

TestEZ uses a chainable assertion API:

```lua
-- Equality
expect(value).to.equal(5)                -- Equality check
expect(value).to.be.a("number")          -- Type check

-- Truthiness
expect(value).to.be.ok()                 -- Truthy check (not nil/false)
expect(value).never.to.be.ok()           -- Falsy check

-- Nil checks
expect(value).to.equal(nil)              -- Is nil
expect(value).never.to.equal(nil)        -- Not nil

-- Functions
expect(fn).to.throw()                    -- Function throws error
expect(fn).never.to.throw()              -- Function doesn't throw

-- Negation
expect(value).never.to.equal(5)          -- Use 'never' to negate

-- Custom messages
expect(value).to.equal(5)                -- Automatic error messages
```

**Note:** TestEZ has fewer built-in matchers than Jest, but they cover most use cases.

### Setup and Teardown

TestEZ provides `beforeEach` and `afterEach` hooks (injected automatically):

```lua
return function()
    describe("MyModule", function()
        local testData
        
        beforeEach(function()
            -- Runs before each test in this describe block
            testData = { value = 0 }
        end)
        
        afterEach(function()
            -- Runs after each test in this describe block
            testData = nil
        end)
        
        it("should use fresh testData", function()
            expect(testData.value).to.equal(0)
        end)
        
        it("should have independent state", function()
            testData.value = 10
            expect(testData.value).to.equal(10)
        end)
    end)
end
```

**Note:** TestEZ also provides `beforeAll` and `afterAll` hooks (declared in `testez.yml` so Selene
accepts them). They run once per `describe` block and are this project's standard mechanism for
installing and restoring service mocks — patch dependency methods in `beforeAll`, restore the saved
originals in `afterAll`. See `CurrencyServiceServer.spec.luau` or `StateSyncServiceServer.spec.luau`
for the canonical pattern.

---

## Test Organization

### What to Test

**Priority 1: Pure Functions (Utils)**
- `CurrencyUtils.luau`
- `InventoryUtils.luau`
- Any utility modules with no side effects

**Priority 2: Service Logic**
- Validation functions
- Type synchronization checks
- Business logic that doesn't require external dependencies

**Priority 3: Integration Tests**
- Transaction rollback scenarios
- Multi-service interactions
- Network event flows (with mocks)

### Test Structure

Organize tests using nested `describe` blocks:

```lua
return function()
    describe("CurrencyUtils", function()
        describe("getCurrencyAmount", function()
            it("should return correct amount for valid currency", function()
                -- Test implementation
            end)
            
            it("should return 0 for missing currency", function()
                -- Test implementation
            end)
        end)
        
        describe("hasEnoughCurrency", function()
            it("should return true when player has enough", function()
                -- Test implementation
            end)
        end)
    end)
end
```

---

## Test-Driven Development

**CRITICAL PROJECT STANDARD:** When adding new systems, features, or modules to this codebase, **always start by writing tests first**.

### Development Workflow

Follow this workflow for all new development:

#### 1. **Write Tests First**
Before implementing any new functionality, write tests that describe the intended behavior:

```lua
-- Example: Adding a new CurrencyUtils function
return function()
    describe("CurrencyUtils", function()
        describe("convertCurrency", function()
            it("should convert jaku to tickets at correct rate", function()
                local result = CurrencyUtils.convertCurrency("jaku", "tickets", 100)
                expect(result).to.equal(10) -- 10:1 conversion rate
            end)
            
            it("should throw error for invalid currency types", function()
                expect(function()
                    CurrencyUtils.convertCurrency("invalid", "tickets", 100)
                end).to.throw()
            end)
            
            it("should return 0 for zero amount", function()
                local result = CurrencyUtils.convertCurrency("jaku", "tickets", 0)
                expect(result).to.equal(0)
            end)
        end)
    end)
end
```

#### 2. **Run Tests (They Should Fail)**
Execute the tests to verify they fail as expected. This confirms:
- Tests are correctly written
- The feature doesn't accidentally already exist
- You understand the requirements

```
❌ Expected: 10, Actual: nil (function doesn't exist yet)
```

#### 3. **Implement the Feature**
Write the minimal code needed to make the tests pass:

```lua
function CurrencyUtils.convertCurrency(fromType: string, toType: string, amount: number): number
    assert(CurrencyConstants.isValidCurrencyType(fromType), "Invalid from currency")
    assert(CurrencyConstants.isValidCurrencyType(toType), "Invalid to currency")
    
    if amount == 0 then return 0 end
    
    -- Implementation logic
    return convertedAmount
end
```

#### 4. **Run Tests Again (They Should Pass)**
Verify all tests pass:

```
✅ All tests passed!
Tests: 3 passed, 0 failed, 3 total
```

#### 5. **Refactor If Needed**
With tests in place, safely refactor your code knowing tests will catch regressions.

### Why Test-Driven Development?

**Benefits for this project:**

1. **Design Clarity** - Writing tests first forces you to think about:
   - Function signatures and types
   - Edge cases and error conditions
   - Expected behavior before implementation details

2. **Documentation** - Tests serve as executable documentation showing how to use your code

3. **Confidence** - Change code fearlessly knowing tests will catch breaking changes

4. **Regression Prevention** - Once a bug is fixed, add a test to prevent it from returning

5. **Faster Development** - Catch issues immediately rather than during manual testing

### What to Test First

When adding new systems, prioritize tests in this order:

**Priority 1: Pure Functions**
- Utility functions with no side effects
- Data transformations
- Validation logic
- Calculations

**Priority 2: Business Logic**
- Service methods that can be tested in isolation
- State mutations with predictable outcomes
- Error handling paths

**Priority 3: Integration Points**
- Cross-service interactions (may require mocks)
- Network event flows
- Transaction scenarios

### Example: Adding a New Service

When creating a new service like `ShopService`:

```lua
-- 1. Write tests first (ShopService.spec.luau)
return function()
    describe("ShopService", function()
        describe("purchaseItem", function()
            it("should deduct currency and add item to inventory", function()
                -- Test the intended outcome
            end)
            
            it("should reject purchase if insufficient funds", function()
                -- Test error conditions
            end)
            
            it("should rollback on inventory add failure", function()
                -- Test transaction safety
            end)
        end)
    end)
end

-- 2. Implement the service to make tests pass
-- 3. Refactor with confidence
```

### Test Coverage — what's enforced

There is no line-coverage tool in this project: the suite runs inside a real Roblox runtime via
Open Cloud (see [ci-cd.md](ci-cd.md)), where per-line instrumentation isn't practical. So instead of
tracking an unenforceable *percentage*, the project enforces coverage at the **module** level, and
that rule actually fails the build:

- **Every first-party module must have a `<name>.spec.luau` sibling.** `SpecRoots.assertAllModulesSpecced`
  (run by both test runners before the suite) errors if a module under a scanned root has no spec and
  is not on the explicit `EXEMPT_MODULES` list. A new service or util that ships without a spec fails
  the suite — it can't silently go uncovered.
- **Exemptions are explicit and justified.** A module earns a pass only by an `EXEMPT_MODULES` line
  naming the reason (React UI with no TestEZ renderer, a thin typed wrapper over a vendored library
  with no logic of its own, a Cmdr command *definition* whose `*Server` implementation is specced,
  etc.). Adding a new module forces the choice: write its spec, or record why a unit test would be
  tautological.

Within a module that *has* a spec, still aim to cover the meaningful surface — every Utils/Constants
function and each service's core branches and failure modes (the existing specs test rollback,
rate-limit denial, invalid input, etc., not just happy paths). Complex cross-service flows get
integration coverage as needed. The module-level guard guarantees the *floor*; depth is on you.

### When NOT to Write Tests First

Some scenarios where implementation-first is acceptable:

- **Prototyping** - Exploring ideas or proof-of-concepts
- **UI/Visual work** - Requires manual visual verification
- **One-off scripts** - Temporary or admin-only code
- **Roblox-specific integration** - Requires actual game environment

However, once the prototype is validated, **refactor it with tests** before merging to main.

---

## Testing React UI (the Phase 7 framework)

The UI framework (`Client/UI/`) splits cleanly into two kinds of module, and each is tested — or
not — for a concrete reason:

- **Pure logic → specced normally.** The scene stack, the layer bookkeeping, the world-suppression
  refcount, and every screen's **view-model** (the pure functions that derive displayed values from
  atoms — filtering, sorting, formatting, "what's actionable") are plain Luau with no Instance or
  React contact. They get ordinary `.spec.luau` siblings and are the primary test surface.
- **Presentational components → exempt, verified visually.** Design tokens (`Tokens`), primitives
  (`Button`, `Panel`), and screen components hold no business logic — they map props/state to
  instances. A unit test would only assert "it rendered", which is low-value, and TestEZ has no
  renderer besides a live Studio session. These are listed in `SpecRoots.EXEMPT_MODULES` with a
  reason and verified at the visual checkpoints.

**The rule that keeps the exemption honest:** logic must live in the view-model, not the component.
A component that grows real branching logic is a smell — push that logic into its specced view-model.

### Previewing UI without a Play session (UI Labs stories)

Visual checkpoints do **not** require booting the game. Presentational components are previewed in
Studio's **edit mode** with the [UI Labs](https://ui-labs.luau.page) plugin, which renders any
`*.story.luau` ModuleScript and re-renders as Rojo syncs.

**One-time setup:** install the *UI Labs* plugin from the Creator Store. The companion library is
already a dev-dependency (`pepeeltoro41/ui-labs`, mounted at `ReplicatedStorage.DevPackages.UILabs`).

**Writing one:** a story sits next to its component (`Slot.story.luau` beside `Slot.luau`) and returns
`UILabs.CreateReactStory({ react, reactRoblox, controls }, render)`. Control values arrive as
`props.controls`; `UILabs.Choose({...})` gives a dropdown. Shared sample data lives in
`Client/UI/React/StoryFixtures.luau` so stories stay about layout.

`VentureUI.storybook.luau` declares which folders UI Labs scans (`Primitives` and `Screens`, grouped).
Without a storybook module UI Labs files everything under a catch-all **"Unknown Stories"** node, so
that file is what gives the tree its shape — it only needs editing if a new top-level story location
appears, not per story.

`SpecRoots` skips `*.story` and `*.storybook` modules by name, exactly as it skips `*.spec` ones —
**adding a story never means editing `SpecRoots`**, and a story is not a substitute for a view-model's
spec.

**What a story can't cover:** the scene stack, input capture, HUD suppression, and real synced data.
Those still need a Play pass. Stories cover the visual loop — proportions, regions, colour, states that
are hard to reach in-game (an empty slot, every rarity at once, a zero-item grid).

**On mounted component tests (`ReactRoblox.createRoot` + `act`, or `jsdotlua/react-test-renderer`):**
our suite runs in a real Studio runtime, so mounting a component in a spec is *possible* with no new
dependency. We are **deliberately not building that harness yet** — the current primitives are
logic-free, so a mounted test would assert nothing the visual checkpoint doesn't already cover. The
harness gets built the first time a component has assertable interactive logic that *can't* be
extracted into a pure view-model. Until then, mounting buys complexity without coverage.

---

## Best Practices

### 1. Test One Thing Per Test

❌ **Bad:**
```lua
it("should handle currency operations", function()
    expect(CurrencyUtils.getCurrencyAmount(currency, "jaku")).to.equal(100)
    expect(CurrencyUtils.hasEnoughCurrency(currency, "jaku", 50)).to.equal(true)
    expect(CurrencyUtils.formatCurrency(100)).to.equal("100")
end)
```

✅ **Good:**
```lua
it("should return correct amount for valid currency", function()
    expect(CurrencyUtils.getCurrencyAmount(currency, "jaku")).to.equal(100)
end)

it("should return true when player has enough", function()
    expect(CurrencyUtils.hasEnoughCurrency(currency, "jaku", 50)).to.equal(true)
end)

it("should format amounts without commas for values < 1000", function()
    expect(CurrencyUtils.formatCurrency(100)).to.equal("100")
end)
```

### 2. Use Descriptive Test Names

Test names should clearly describe what is being tested and the expected outcome:

```lua
it("should return 0 for nil currency table", function() ... end)
it("should throw error for non-positive amount", function() ... end)
it("should stack quantities for existing stackable item", function() ... end)
```

### 3. Test Edge Cases

Always test:
- Nil/empty inputs
- Boundary values (0, -1, max values)
- Invalid types
- Error conditions

```lua
describe("hasEnoughCurrency", function()
    it("should return false for nil currency table", function()
        expect(CurrencyUtils.hasEnoughCurrency(nil, "jaku", 10)).to.equal(false)
    end)
    
    it("should throw error for non-positive amount", function()
        expect(function()
            CurrencyUtils.hasEnoughCurrency(currency, "jaku", 0)
        end).to.throw()
    end)
end)
```

### 4. Keep Tests Independent

Each test should be able to run in isolation. Use `beforeEach` to reset state:

```lua
return function()
    describe("InventoryUtils", function()
        local inventory
        
        beforeEach(function()
            inventory = {
                { itemType = "iron-sword", quantity = 5 }
            }
        end)
        
        it("should add item", function()
            InventoryUtils.add(inventory, { itemType = "phoenix-blade", quantity = 1 })
            expect(#inventory).to.equal(2)
        end)
        
        it("should remove item", function()
            InventoryUtils.remove(inventory, { itemType = "iron-sword" })
            expect(#inventory).to.equal(0)
        end)
    end)
end
```

### 5. Test Error Conditions

Verify that functions throw errors when they should:

```lua
it("should throw error for invalid item type", function()
    expect(function()
        InventoryUtils.tryAdd(inventory, { itemType = "invalid-item" })
    end).to.throw()
end)
```

---

## Troubleshooting

### Tests not running

**Check:**
1. Test files have `.spec.luau` suffix
2. Test files return a function containing the test suite
3. TestEZ package is installed via Wally
4. TestRunner script is being executed
5. Rojo is syncing files correctly

### "Module not found" errors

**Solution:** Ensure your test file's require paths match your project structure. Use absolute paths from `ReplicatedStorage`:

```lua
local MyModule = require(ReplicatedStorage.Shared.Features.MyFeature.Utils.MyFeatureUtils)
```

### Tests pass in Studio but fail in CI

**Solution:** Ensure your CI environment has the same Wally packages and Roblox API version as your Studio environment.

### Lint errors for `describe`, `it`, `expect`

**These shouldn't occur.** The TestEZ globals are declared in [`testez.yml`](../testez.yml) and
enabled via `std = "roblox+testez"` in [`selene.toml`](../selene.toml), so Selene accepts them in
spec files. If you see `undefined_variable` for them, your editor's Selene isn't picking up the
repo's `selene.toml` — check your working directory / extension configuration.

---

---

## Creating Tests for New Infrastructure

When you create a new Service or Utility, you **must** create a corresponding test file.

### Step-by-Step Guide

1. **Create the spec file**: If your service is `CurrencyServiceServer.luau`, create `CurrencyServiceServer.spec.luau` in the same directory.
2. **Standard Template**:
```lua
--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MyService = require(script.Parent.MyService)

return function()
    describe("MyService", function()
        it("should be initialized correctly", function()
            -- Tests here
        end)
    end)
end
```
3. **Registering the Test**: TestEZ does **not** scan recursively from `src`. Both runners
   (`src/ServerScriptService/TestRunner.server.luau` and `tasks/runTests.luau`) pass an explicit
   root list, shared via `ServerScriptService/Core/Testing/SpecRoots.luau`:
   `Shared/Core`, `Shared/Data`, `Shared/Features`, `Client`, `ServerScriptService/Commands`,
   `Core`, and `Features`. A spec placed under any of these roots (any depth) is discovered
   automatically. A spec placed **outside** them — e.g. under `Shared/CmdrTypes` —
   would not be, so both runners sweep the DataModel for `*.spec` ModuleScripts and **error on any
   spec outside the roots** rather than silently skipping it. If you legitimately need a new spec
   location, add the root to `SpecRoots.luau` (one edit covers Studio and CI). The runners also call
   `assertAllModulesSpecced`, the inverse guard: it **errors on any first-party module under a root
   that has no `.spec` sibling** and isn't in `SpecRoots.EXEMPT_MODULES` — so a new module can't ship
   untested (see [Test Coverage](#test-coverage--whats-enforced)).

### Testing Lifecycle Methods
Methods are fields on the service table that take `self` explicitly (see
[conventions: Service Module Shape](conventions.md#service-module-shape)), so you can call any of
them in a test by passing the service table itself — lifecycle methods included:

```lua
it("should initialize internal state", function()
    MyService.init(MyService) -- call the field, passing the table as self
    expect(MyService.state).to.be.ok()
end)
```

### Conventions in Tests
- All `.spec.luau` files MUST return a function.
- Prefer mocking `PlayerDataService` or other dependencies if they require DataStore access.
