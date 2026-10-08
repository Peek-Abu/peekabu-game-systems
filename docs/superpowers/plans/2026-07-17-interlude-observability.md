# Interlude: Observability, Docs & Data-Layer Polish — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix the debugger's client-context staleness, audit every service's `getState` to a new derived-or-nothing convention, make large tables inspectable, propagate validator rejection reasons through `transaction()`/`mutate()`, and restructure the agent docs — the consolidated "before the next phase" backlog from Phases 3a–3b.

**Architecture:** No profile schema changes, no new slices, no gameplay behavior changes. The data-layer change (Task 1) alters only what gets *reported* on rejection, never accept/reject outcomes. Debugger changes ride the existing Charm reactivity (a `computed` snapshot) and React component tree.

**Tech Stack:** Roblox / strict Luau (`--!strict`), Charm + ReactCharm, React-lua, ProfileStore, TestEZ.

Spec: `docs/superpowers/specs/2026-07-17-interlude-observability-design.md`
Branch: create `feat/interlude-observability` off `main` (tip ≥ `6d89fbf`).

## Global Constraints

- **`--!strict` everywhere. No `any`, no new `::` casts** without escalation for human sign-off (React Debugger components are `--!strict` too but sit in `EXEMPT_MODULES` for specs, not for casts).
- **Spec-first TDD** for everything with logic; React Debugger UI components are spec-exempt (no renderer in TestEZ) per the existing `SpecRoots.EXEMPT_MODULES` precedent.
- **Plain commit messages. NO `Co-Authored-By:` / `Claude-Session:` trailers.**
- **Gate:** FULL `bash scripts/check.sh` (WITH `wally install` — `wally-package-types` is not idempotent). **MANDATORY after EVERY commit: `python scripts/python/check_pr_rules.py origin/main` must report zero errors** — the gate diffs `origin/main...HEAD` and cannot see uncommitted work; a pre-commit-only run let banned casts slip through once in Phase 3b. There is no headless TestEZ runner (Studio/Open Cloud only).
- **No profile schema changes. No behavior changes to accept/reject outcomes** — Task 1 changes reported reasons only.
- **Docs relocation guardrails (Task 6, binding):** nothing normative (rules, locked-in decisions, gotchas, constraints) leaves `AGENTS.md`; only descriptive reference moves; every moved section leaves a one-line pointer; `AGENTS.md` gains a "Where to look" doc index near the top.

---

## File Structure

| File | Responsibility |
|---|---|
| `src/ServerScriptService/Services/PlayerDataService/PlayerDataServiceServer.luau` | Task 1: `TransactionResult.rejectionReason/rejectedPath`; `mutate()` second return |
| `src/ServerScriptService/Modules/SliceOwner.luau` | Task 1: `SliceAccessor.mutate` type gains the second return (body already forwards) |
| `src/ServerScriptService/Services/InventoryService/InventoryServiceServer.luau` | Task 2: consume propagated reasons (4 methods) |
| `src/ServerScriptService/Services/EquipmentService/EquipmentServiceServer.luau` | Task 2: consume propagated reasons (equip/unequip); Task 4: NEW `getState` |
| `src/ReplicatedStorage/Client/State/DebuggerState.luau` | Task 3: client snapshot becomes `Charm.computed` |
| `src/ReplicatedStorage/Client/UI/React/Debugger/StatePanel.luau` | Task 3: `useAtom` the computed; Task 5: detail window uses TreeView |
| `src/ReplicatedStorage/Client/UI/React/Debugger/TreeView.luau` | Task 5: NEW collapsible tree component |
| `src/ReplicatedStorage/Shared/Modules/ServiceController.luau` | Task 4: getState convention documented at the `getState` field's doc comment |
| `src/ReplicatedStorage/Client/Services/*/{Stats,Equipment,Inventory,Currency}ServiceClient.luau` | Task 4: getState rewrites/additions/deletions |
| `src/ServerScriptService/Services/StatsService/StatsServiceServer.luau` | Task 4: NEW `getState` (subscription count) |
| `src/ServerScriptService/Modules/SpecRoots.luau` | Task 5: `TreeView` exemption entry |
| `AGENTS.md`, `CLAUDE.md`, `docs/project-structure.md`, `docs/tech-stack.md`, `src/ServerScriptService/State/ServerStore.luau` | Task 6: docs restructure + header note |
| `src/ReplicatedStorage/Shared/Modules/GameItems.spec.luau` | Task 6: assertion idiom cleanup |

---

### Task 1: Validator reasons through the data layer

**Files:**
- Modify: `src/ServerScriptService/Services/PlayerDataService/PlayerDataServiceServer.luau` (+ spec)
- Modify: `src/ServerScriptService/Modules/SliceOwner.luau` (type only)

**Interfaces (produces — later tasks and services rely on these exact shapes):**

```lua
export type TransactionResult = {
	committed: boolean,
	persisted: boolean,
	failedUserIds: { number },
	rejectionReason: string?,   -- NEW: the validator's reason, when a slice validator rejected an op
	rejectedPath: string?,      -- NEW: the concrete path whose validator rejected
}
-- mutate: (self, userId, path, fn) -> (boolean, string?)   -- reason non-nil ONLY on validator rejection
-- SliceOwner.SliceAccessor.mutate: (userId, fn) -> (boolean, string?)
```

Verified current state (read before editing): `TransactionResult` is declared at `PlayerDataServiceServer.luau:210-214`. `mutate()`'s validator rejection is the `return false` at ~line 800 (inside the `if validator then ... if not valid` block at lines 787-801). `transaction()`'s `failResult()` helper is at ~line 894, and its validator-rejection site is at ~lines 1128-1135 (`rollbackAll(...)` + `return false, failResult()`). Line numbers may have drifted a few lines — match on the quoted code, not the numbers.

- [ ] **Step 1: Failing specs.** Add to `PlayerDataServiceServer.spec.luau` (find the existing validator-rejection describe blocks — e.g. the currency-cap and inventory rollback tests — and mirror their seeding style):

```lua
it("mutate() returns the validator's reason as a second value on invariant rejection", function()
	seed(1, 100)
	local changed, reason = PlayerData:mutate(1, CURRENCY_PATH, function(currency)
		currency.jaku = -50 -- validator rejects negative
		return true
	end)
	expect(changed).to.equal(false)
	expect(type(reason)).to.equal("string")
	expect(reason:find("jaku", 1, true) ~= nil or reason:find("negative", 1, true) ~= nil).to.equal(true)
end)

it("mutate() returns nil reason when the mutator itself aborts (business-logic false)", function()
	seed(1, 100)
	local changed, reason = PlayerData:mutate(1, CURRENCY_PATH, function()
		return false
	end)
	expect(changed).to.equal(false)
	expect(reason).to.equal(nil)
end)

it("transaction() populates rejectionReason and rejectedPath on validator rejection", function()
	seed(1, 100)
	local ok, result = PlayerData:transaction({
		{ userId = 1, path = CURRENCY_PATH, mutator = function(currency)
			currency.jaku = -50
			return true
		end },
	})
	expect(ok).to.equal(false)
	expect(type(result.rejectionReason)).to.equal("string")
	expect(result.rejectedPath).to.equal(CURRENCY_PATH)
end)

it("transaction() leaves rejectionReason nil on a business-logic abort", function()
	seed(1, 100)
	local ok, result = PlayerData:transaction({
		{ userId = 1, path = CURRENCY_PATH, mutator = function()
			return false
		end },
	})
	expect(ok).to.equal(false)
	expect(result.rejectionReason).to.equal(nil)
	expect(result.rejectedPath).to.equal(nil)
end)
```

(Adapt `CURRENCY_PATH`/`seed`/the negative-jaku trigger to the file's actual existing fixtures and the real currency validator's rules — read the neighboring tests first; the exact rejection trigger there is authoritative, not this sketch. Every OTHER pre-existing `mutate` call site in the spec keeps working unchanged: the second return is additive.)

- [ ] **Step 2: Run to confirm expected RED** (typecheck-only gate limitation applies — reason through it if not mechanically observable; document which).

- [ ] **Step 3: Implement.**

`TransactionResult` (lines 210-214): add the two optional fields with a doc-comment line each, per the interface block above.

`mutate()` validator rejection (the block at ~787-801): change `return false` to `return false, reason` (the `reason` local already exists from `local valid, reason = validator(container[key])`). Every other `return false` in `mutate()` and both `return true` sites stay bare (Luau treats a missing second return as nil — the declared return type becomes `(boolean, string?)` in the `PlayerDataServiceServer` type export at ~line 222's `mutate` entry).

`transaction()`: extend `failResult` to accept the optional reason/path:

```lua
local function failResult(rejectionReason: string?, rejectedPath: string?): TransactionResult
	return {
		committed = false,
		persisted = false,
		failedUserIds = {},
		rejectionReason = rejectionReason,
		rejectedPath = rejectedPath,
	}
end
```

All existing `failResult()` calls stay argument-less EXCEPT the validator-rejection site (~1128-1135), which becomes:

```lua
local validator = PlayerDataConstants.getValidator(op.path)
if validator then
	local valid, reason = validator(container[key])
	if not valid then
		rollbackAll(`slice invariant violated at op {i} (path {op.path}): {reason or "invalid"}`)
		clearTransactionFlags()
		return false, failResult(reason or "invalid", op.path)
	end
end
```

`SliceOwner.luau`: update `SliceAccessor`'s `mutate` type to `(userId: number, fn: (value: T) -> boolean?) -> (boolean, string?)` and its doc line. The body (`return PlayerDataService:mutate(userId, path, fn)`) already forwards multiple returns — no body change.

- [ ] **Step 4: Full gate + MANDATORY post-commit pr-rules check.**
- [ ] **Step 5: Commit** — `feat(data-layer): propagate validator rejection reasons through mutate and transaction`

---

### Task 2: Inventory + Equipment consume the propagated reasons

**Files:**
- Modify: `src/ServerScriptService/Services/InventoryService/InventoryServiceServer.luau` (+ spec)
- Modify: `src/ServerScriptService/Services/EquipmentService/EquipmentServiceServer.luau` (+ spec)

**Interfaces:** Consumes Task 1's exact shapes. Produces no new public surface — only better reason strings.

**The pattern, per method:**

*mutate-based methods* (`addStackable`, `removeByUid`, `removeByTypeAndQuantity` in InventoryServiceServer; `unequip`'s equipment-clear step is transaction-based, see below): capture the second return and fold it into the existing fallback chain — business-logic upvalue reason first (it's more specific), then the validator reason, then the generic string:

```lua
local ok, validatorReason = inventorySlice.mutate(userId, function(inventory)
	-- (existing mutator body unchanged)
end)
if not ok and reason == nil then
	reason = validatorReason or "mutation rejected (see server logs)"
end
```

*transaction-based methods* (`addUnique` in InventoryServiceServer; `equip` and `unequip` in EquipmentServiceServer): capture the result and use its `rejectionReason`:

```lua
local ok, result = PlayerDataService:transaction({ ... })
if not ok and reason == nil then
	reason = result.rejectionReason or "mutation rejected (see server logs)"
end
```

(Each of these methods currently reads only `local ok = PlayerDataService:transaction(...)` with a comment explaining the second return carries no reason — update those comments; they are now stale by design. `unequip`'s Phase-3b kind-cap PRE-FLIGHT stays exactly as is — it is the friendly-specific path; the propagated reason backs the exceptional paths.)

- [ ] **Step 1: Failing spec updates.** In `InventoryServiceServer.spec.luau` and `EquipmentServiceServer.spec.luau`, find every assertion expecting the LITERAL string `"mutation rejected (see server logs)"` on a path where a VALIDATOR (not business logic) rejects — e.g. Equipment's atomicity test (duplicate-uid corruption caught by `validateEquipment`). Tighten those to assert the actual validator message content (e.g. `reason:find("duplicate uid", 1, true)`). Leave business-logic reason assertions untouched. List every assertion you changed in your report.
- [ ] **Step 2: RED (or reasoned equivalent).**
- [ ] **Step 3: Implement per the pattern above** — methods: `addStackable`, `removeByUid`, `removeByTypeAndQuantity`, `addUnique` (Inventory); `equip`, `unequip` (Equipment).
- [ ] **Step 4: Full gate + post-commit pr-rules.**
- [ ] **Step 5: Commit** — `feat(items): surface data-layer validator reasons from inventory and equipment ops`

---

### Task 3: Client State tab reactivity

**Files:**
- Modify: `src/ReplicatedStorage/Client/State/DebuggerState.luau` (+ spec)
- Modify: `src/ReplicatedStorage/Client/UI/React/Debugger/StatePanel.luau` (no spec — exempt React)

**Interfaces (produces):**

```lua
DebuggerState.clientAtoms: () -> { AtomSnapshot }  -- a Charm.computed; reading it inside effects/useAtom subscribes
-- DebuggerState.getClientAtoms is DELETED (StatePanel is its only caller — verify with grep before deleting)
```

**Verified current state:** `DebuggerState.getClientAtoms()` (DebuggerState.luau:111-123) loops `SyncState.SLICES` calling `ClientStore.readSlice(slice)` — a plain read, no subscription. `StatePanel.luau:155-157` calls it (and `getClientPlayers()`) directly in render.

- [ ] **Step 1: Failing spec.** In `DebuggerState.spec.luau` (check it exists; if DebuggerState is spec-exempt, check `SpecRoots.EXEMPT_MODULES` — if exempt, note it and write the spec anyway as a new covered module OR keep exemption and test via ClientStore.spec conventions; read the current state first and follow the file's established status):

```lua
it("clientAtoms recomputes when a ClientStore slice changes", function()
	local before = DebuggerState.clientAtoms()
	ClientStore.currency({ jaku = 42 })
	local after = DebuggerState.clientAtoms()
	expect(after ~= before).to.equal(true) -- computed produced a fresh snapshot table
	local found = false
	for _, atom in after do
		if atom.slice == "currency" then
			found = atom.value ~= nil and atom.value.jaku == 42
		end
	end
	expect(found).to.equal(true)
end)
```

- [ ] **Step 2: Implement.**

```lua
--[=[
	The local player's ClientStore slices as AtomSnapshots — a Charm.computed, NOT a plain function:
	reading each slice atom inside the getter makes every synced slice a tracked dependency, so any
	consumer subscribed via useAtom re-renders the moment charm-sync patches a slice. (The old
	getClientAtoms() read the atoms imperatively during render, so the client State tab only
	refreshed when something ELSE re-rendered the panel — the staleness bug found in Phase 3b's
	manual testing.)
]=]
DebuggerState.clientAtoms = Charm.computed(function()
	local userId = Players.LocalPlayer.UserId
	local result: { AtomSnapshot } = {}
	for _, slice in SyncState.SLICES do
		table.insert(result, {
			slice = slice,
			userId = userId,
			value = ClientStore.readSlice(slice),
		})
	end
	return result
end)
```

(`ClientStore.readSlice` calls `atom()`, which registers the dependency inside a computed's getter — same mechanism `StatsServiceServer.start()`'s selectors already rely on. Add `local Charm = require(ReplicatedStorage.Packages.Charm)` to DebuggerState's requires if absent.)

`StatePanel.luau`: replace the `DebuggerState.getClientAtoms()` call with `useAtom(DebuggerState.clientAtoms)` — hooks must be unconditional, so hoist it next to the existing `useAtom(DebuggerState.serverSnapshot)` at the top and select client-vs-server AFTER:

```lua
local clientAtoms = useAtom(DebuggerState.clientAtoms)
-- ... in the existing context branch:
	atoms = clientAtoms
```

`getClientPlayers()` (a static single-entry list) may stay a plain function — it never changes.

Delete `getClientAtoms` after grep-confirming StatePanel was its only caller.

- [ ] **Step 3: Full gate + post-commit pr-rules.**
- [ ] **Step 4: Commit** — `fix(debugger): client State tab subscribes to slice atoms instead of reading them imperatively`

---

### Task 4: `getState` audit

**Files:**
- Modify: `src/ReplicatedStorage/Shared/Modules/ServiceController.luau` (doc comment only, at the `getState` field, ~line 111)
- Modify: `src/ReplicatedStorage/Client/Services/StatsService/StatsServiceClient.luau` (+ spec)
- Modify: `src/ReplicatedStorage/Client/Services/EquipmentService/EquipmentServiceClient.luau` (+ spec)
- Modify: `src/ReplicatedStorage/Client/Services/InventoryService/InventoryServiceClient.luau` (+ spec)
- Modify: `src/ReplicatedStorage/Client/Services/CurrencyService/CurrencyServiceClient.luau` (+ spec — DELETE getState + its spec cases)
- Modify: `src/ServerScriptService/Services/InventoryService/InventoryServiceServer.luau` (+ spec — DELETE getState + its spec cases)
- Modify: `src/ServerScriptService/Services/StatsService/StatsServiceServer.luau` (+ spec — NEW getState)
- Modify: `src/ServerScriptService/Services/EquipmentService/EquipmentServiceServer.luau` (+ spec — NEW getState)

**The convention (write it at ServiceController's `getState` doc comment — the contract's home):**
> getState shows what the State tab can't: DERIVED or DIAGNOSTIC data. Never mirror a raw synced
> slice (the State tab already renders every synced slice). A service with nothing derived or
> diagnostic to show should have NO getState — "(no getState)" beats useless data.

**Per-service content:**

```lua
-- StatsServiceClient.getState (rewrite):
{
	level = progress.level, xpIntoLevel = progress.xpIntoLevel, xpToNext = progress.xpToNext,
	unspentMain = unspent.main, unspentSub = unspent.sub,
	derived = StatFormulas.derive(stats.investments, { EquipmentBonuses.aggregate(ClientStore.equipment()) }),
}
-- (all nil-guarded: return { synced = false } when the stats slice hasn't synced yet)

-- EquipmentServiceClient.getState (NEW):
{
	equipped = <map: slotId -> entry.itemType for each occupied slot>,
	aggregatedBonuses = EquipmentBonuses.aggregate(ClientStore.equipment()),
}

-- InventoryServiceClient.getState (rewrite; drop itemCount/items):
{
	entriesPerKind = <map: kind -> `{InventoryUtils.countEntriesOfKind(inv, kind)}/{ItemConstants.KIND_CAPS[kind]}` for each ItemConstants.KINDS entry>,
}

-- CurrencyServiceClient: DELETE getState (raw slice mirror; nothing derived). Remove from its
-- export type too, and delete its spec cases.

-- InventoryServiceServer: DELETE getState (a prose note). Remove from export type; delete spec cases if any.

-- StatsServiceServer.getState (NEW): { activeSubscriptions = <count> }
--   Implementation: a module-local `local activeSubscriptions = 0` incremented at the top of the
--   observeCharacter callback in start() and decremented inside the returned cleanup — measuring
--   live Charm.subscribe pairs, the mirror-subscription diagnostic.

-- EquipmentServiceServer.getState (NEW): { slots = <map: slotId -> acceptsKind from EquipmentConstants.SLOTS> }
```

- [ ] **Step 1: Failing specs first** for the three rewrites/two additions (value assertions: seed the client atoms — the established seeded-atom pattern — and assert `getState().level == 8`-style real values; for StatsServiceServer's counter, assert 0 before any character exists in the spec env). Delete the spec cases of the two deleted getStates in the same change.
- [ ] **Step 2: RED.**
- [ ] **Step 3: Implement all eight files** per the content table + the ServiceController doc-comment convention.
- [ ] **Step 4: Full gate + post-commit pr-rules.**
- [ ] **Step 5: Commit** — `feat(debugger): getState audit — derived/diagnostic data or no getState at all`

---

### Task 5: Expandable TreeView for the State detail window

**Files:**
- Create: `src/ReplicatedStorage/Client/UI/React/Debugger/TreeView.luau` (NO spec — React, exempt)
- Modify: `src/ReplicatedStorage/Client/UI/React/Debugger/StatePanel.luau` (detail window only)
- Modify: `src/ServerScriptService/Modules/SpecRoots.luau` (one `EXEMPT_MODULES` entry: `"React UI component (rendered in-game)"`)

**Verified current state:** the detail window renders through `TableView`, whose `renderValue` (TableView.luau:41-62) expands tables exactly ONE level and pushes anything deeper through `theme.serialize` (JSON-encode + truncate) — the `...` problem.

**TreeView contract:**

```lua
export type Props = {
	value: any,          -- the root table to render
	layoutOrder: number?,
}
-- Renders a collapsible tree: each table node is a clickable row (▸/▾ + key + summary) toggling
-- its children; primitives render inline as `key = value` via theme.serialize (untruncated);
-- default-collapsed below depth 2; per-node open state in a single React.useState map keyed by
-- node path (e.g. "items.3.uid"); sorted keys (numeric first) for stable display; indentation via
-- padding per depth. No depth or length limits — the window already scrolls and resizes.
```

`StatePanel`'s detail window swaps its `TableView` usage for `TreeView` for the slice value; `TableView` itself is untouched (the Services tab still uses it for shallow getState rows, which the Task 4 audit keeps shallow by design).

- [ ] **Step 1: Implement TreeView** (mirror the existing Debugger components' house style — `theme.luau` constants, `e = React.createElement`, doc comments).
- [ ] **Step 2: Wire into StatePanel's detail window; add the SpecRoots exemption.**
- [ ] **Step 3: Full gate + post-commit pr-rules** (gate-only verification here; hand-verified in Studio at phase end per the spec).
- [ ] **Step 4: Commit** — `feat(debugger): expandable tree view for State detail (no more truncated tables)`

---

### Task 6: Docs restructure + cleanups

**Files:**
- Commit (currently untracked): `AGENTS.md`, `CLAUDE.md`
- Create: `docs/project-structure.md`, `docs/tech-stack.md`
- Modify: `AGENTS.md` (slim per guardrails), `src/ServerScriptService/State/ServerStore.luau` (header note), `src/ReplicatedStorage/Shared/Modules/GameItems.spec.luau` (idiom)

**Binding guardrails (from the spec — the reviewer checks the diff against these):**
1. Nothing normative leaves `AGENTS.md`: the non-negotiable rules, commands table, gotchas, deployment model, refactor decisions, live-game inspection rules, and "Architecture in one screen" ALL STAY.
2. Only descriptive reference moves: the file-layout/where-things-live details → `docs/project-structure.md`; toolchain + per-dependency roles (promote `wally.toml`'s inline comments to prose) → `docs/tech-stack.md`.
3. Every moved section leaves a one-line pointer in `AGENTS.md`; add a "Where to look" index near the top listing `docs/architecture.md`, `docs/project-structure.md`, `docs/tech-stack.md`, `docs/ROADMAP.md`, `docs/testing.md` with a half-line description each.

**Steps:**
- [ ] **Step 1: FIRST commit the untracked files as-is** (their content predates this task): `git add AGENTS.md CLAUDE.md && git commit -m "docs: commit agent guidance files (previously untracked)"` — so the restructure is a reviewable diff against a committed baseline, not a file birth.
- [ ] **Step 2: Write `docs/project-structure.md`:** `src/` realm layout (ReplicatedStorage Shared/Client trees, ServerScriptService Services/Modules/State/Commands trees, StarterPlayerScripts), the `*ServiceServer`/`*ServiceClient` filename-discovery convention, spec-sibling rule + `SpecRoots` roots list, and the add-a-slice recipe as a REFERENCE to `SliceManifest.luau`'s header (link, don't duplicate).
- [ ] **Step 3: Write `docs/tech-stack.md`:** rokit toolchain (rojo/wally/selene/stylua/luau-lsp + versions from `rokit.toml`), the CI pipeline stages, and one subsection per Wally dependency (from `wally.toml` — Charm, CharmSync, ByteNetMax, Cmdr, ProfileStore, React/ReactRoblox/ReactCharm, Observers, Janitor, Signal, sift, Promise, TestEZ) with its sanctioned role.
- [ ] **Step 4: Slim `AGENTS.md`** per the guardrails; add the "Where to look" index; `CLAUDE.md` unchanged (`@AGENTS.md`).
- [ ] **Step 5: `ServerStore.luau` header:** add one paragraph after the existing atom-mirroring explanation: server-side consumers MAY read a player's committed state through `getterFor` for derivation (first sanctioned use: `StatsServiceServer.getDerived`, Phase 3b) — the mirror is written synchronously after every committed write, so for the ACTIVE slot it is never stale relative to a completed mutation; it is NOT a substitute for `SliceOwner.get` when pre-commit/live-profile reads are needed inside mutators.
- [ ] **Step 6: `GameItems.spec.luau` idiom:** rewrite the two weapon assertions from the `expect(x and x.kind == "weapon" and x.equipSlot).to.equal("weapon")` chain to the guarded-`if` shape the armour test in the same file already uses (`if rustedSaw and rustedSaw.kind == "weapon" then expect(rustedSaw.equipSlot).to.equal("weapon") end` preceded by `expect(rustedSaw).to.be.ok()` etc. — read the armour test and copy its exact shape).
- [ ] **Step 7: Full gate + post-commit pr-rules.**
- [ ] **Step 8: Commit** — `docs: restructure agent docs (project-structure, tech-stack) and cleanups` (Step 1's commit is separate and comes first).

---

## Done when

- FULL `bash scripts/check.sh` green; `check_pr_rules.py origin/main` zero errors post-final-commit.
- TestEZ green on the PR (Open Cloud).
- No new `::` casts (none of these tasks should need one — escalate if one seems forced).
- In Studio (the checks Phase 3b's testing couldn't do): client State tab updates live as Cmdr commands run; Services tab shows level/derived/unspent (client Stats), equipped summary + bonuses (client Equipment), caps meter (client Inventory), subscription count (server Stats); a 40-item inventory is fully inspectable in the expandable detail view; `CurrencyServiceClient` and `InventoryServiceServer` show "(no getState)".
- A validator rejection reaching a Cmdr command surfaces the validator's actual message, not "see server logs".
- `AGENTS.md` diff shows only descriptive content moved out, pointers present, all rules/decisions intact.

## Deliberately NOT in this phase (from the spec)

Cmdr `stats`/`setlevel` commands (cut); the live-game discovery pass (running in parallel, separate doc); 3c affix research; Phase 4 Bank; any profile schema change.
