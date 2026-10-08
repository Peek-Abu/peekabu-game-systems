# Slot Epoch Hardening + Jaku Rename (Phase 1c) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** (1) Close the "op minted, then held across a yield" hole so a slot switch can never silently reroute a transaction onto an abandoned character. (2) Replace the base's placeholder currencies (`gold` / `gems`) with Venture's real one: **`jaku`**.

**Architecture:** `slotState` gains an `epoch` that `switchSlot` increments. A slot-scoped `op` records the epoch it was minted under; `transaction()` **rejects** any op whose epoch no longer matches. A stale op fails LOUDLY instead of committing to the character the player just left.

**Tech Stack:** Roblox / strict Luau (`--!strict`), ProfileStore, Charm + charm-sync, Cmdr, TestEZ.

Design: `docs/superpowers/specs/2026-07-12-player-data-slots-design.md`
Builds on Phase 1a (slot data layer) and 1b (SlotService) — both on this branch, PR #1.

## Global Constraints

- **`--!strict` everywhere. No `any`, no casts.** A `::` cast needs genuine justification and sign-off. If one seems forced, STOP and escalate.
- **Spec-first TDD.** Write the spec before the implementation. `SpecRoots.assertAllModulesSpecced` fails the build if a first-party module has no `.spec` sibling.
- **Commits: plain messages only.** No `Co-Authored-By:` / `Claude-Session:` trailers.
- **No headless test runner.** Gate = FULL `bash scripts/check.sh` (WITH its wally install step — `wally-package-types` is NOT idempotent; `--skip-install` on stale link files gives spurious `'REQUIRED_MODULE' is not a function call` errors that are not real). TestEZ runs on Open Cloud in CI **only on a PR into main or a push to main** — a feature-branch push SKIPS it. Baseline: **512 tests passing**.
- **No migrations.** Data is wiped pre-launch; change the shape and wipe.
- An expected, accepted warning exists: `DeprecatedApi` on `Player:LoadCharacter`. Not a defect.

## Background — the bug being closed (understand it before touching anything)

`SliceOwner`'s `op()` builds `{ userId, path, mutator }` for `transaction()` to execute LATER. For a slot-scoped slice the path is **baked at mint time**: `slots.1.currency`.

That is safe only if you mint and commit immediately. It breaks when something **yields in between** — which is exactly what a trade does (mint both sides' ops → await confirmation → commit):

1. Op minted while the player is on slot 1 → path `slots.1.currency`.
2. Yield.
3. Player switches to slot 2.
4. `transaction()` commits to `slots.1.currency` — **the character they just left**.
5. `mutate`/`transaction`'s mirror gate only replicates writes to the ACTIVE slot, so **the client never sees it**.

Silent, wrong-character economy writes: the worst failure class in this codebase.

**Unreachable today** (both halves must be true, and both are): nothing in production mints an op (`transaction()` has zero production callers), and players cannot switch slots (admin Cmdr command only). This task closes it BEFORE either half ships.

**`isInTransaction` does NOT close this** — the lock is taken *inside* `transaction()`, while `op()` mints *outside* any lock, so the flag reads false during the dangerous window. Keep that check (it fails fast), but it is not the fix.

**Why REJECT and not REDIRECT.** Two tempting alternatives are both wrong:
- *Re-resolve the slot at execute time* → the trade applies to slot 2, which is **also** the wrong character (it was negotiated as slot 1), and it destroys the ability to address a specific slot deliberately — which is the whole point of the single-key design (atomic cross-slot item moves).
- *Forbid switching while ops are outstanding* → an epoch with more bookkeeping.

**A trade interrupted by a character switch must be CANCELLED, not rerouted.** The epoch gives exactly that.

---

## File Structure

| File | Responsibility |
|---|---|
| `src/ReplicatedStorage/Shared/Types/PlayerDataTypes.luau` | `SlotState` gains `epoch: number`. `Currency` keys become Jaku's. |
| `src/ServerScriptService/Modules/Constants/PlayerDataConstants.luau` | Template `slotState = { active = 1, epoch = 1 }`; its root validator covers `epoch`. |
| `src/ServerScriptService/Services/PlayerDataService/PlayerDataServiceServer.luau` | `TransactionOperation` gains an optional `epoch`; `transaction()` rejects a stale op. Add `getSlotEpoch`. |
| `src/ServerScriptService/Modules/SliceOwner.luau` | `registerSlot`'s `op` stamps the current epoch. `registerAccount`'s does NOT (account data is slot-independent). |
| `src/ServerScriptService/Services/SlotService/SlotServiceServer.luau` | `switchSlot` increments `epoch` in the same mutate that sets `active`. |
| `src/ReplicatedStorage/Shared/Modules/Constants/CurrencyConstants.luau` | `gold` / `gems` → `jaku`. |
| `src/ServerScriptService/Services/CurrencyService/CurrencyServiceServer.luau` | The slice default becomes `{ jaku = 100 }`. |

---

### Task 1: `slotState.epoch` — the field and its invariant

**Files:**
- Modify: `src/ReplicatedStorage/Shared/Types/PlayerDataTypes.luau` (`SlotState`)
- Modify: `src/ServerScriptService/Modules/Constants/PlayerDataConstants.luau` (template + the `slotState` root validator)
- Modify: `src/ServerScriptService/Services/SlotService/SlotServiceServer.luau` (`switchSlot` increments it)
- Test: `PlayerDataServiceServer.spec.luau`, `SlotServiceServer.spec.luau`, `PlayerDataConstants.spec.luau`

**Interfaces:**
- Produces: `SlotState = { active: number, epoch: number }`. Template default `{ active = 1, epoch = 1 }`.
- `switchSlot` increments `epoch` **in the same `mutate("slotState", ...)`** that sets `active` — one atomic write, so the two can never disagree.

The `slotState` root validator (registered via `registerRootPath`, added in Phase 1b) must now also enforce: `epoch` is a **number**, an **integer**, and `>= 1`. Keep the existing `active` checks (number, integer, `1..MAX_SLOTS`).

**Epoch is monotonic and never resets.** It is a generation counter, not a slot index — do not tie it to the slot number.

- [ ] **Step 1: Write the failing specs**

In `PlayerDataConstants.spec.luau`:

```lua
it("seeds slotState with epoch 1", function()
	expect(PlayerDataConstants.PROFILE_TEMPLATE.slotState.epoch).to.equal(1)
end)
```

In `PlayerDataServiceServer.spec.luau` (the `slotState` describe added in Phase 1b):

```lua
it("rejects a non-integer epoch", function()
	local ok = PlayerDataService:mutate(USER_ID, "slotState", function(slotState)
		slotState.epoch = 2.5
		return true
	end)
	expect(ok).to.equal(false)
end)

it("rejects an epoch below 1", function()
	local ok = PlayerDataService:mutate(USER_ID, "slotState", function(slotState)
		slotState.epoch = 0
		return true
	end)
	expect(ok).to.equal(false)
end)
```

In `SlotServiceServer.spec.luau`:

```lua
it("increments the epoch on a successful switch", function()
	SlotService:unlockSlot(USER_ID, 2)
	local before = SlotService:getSlotEpoch(USER_ID)

	SlotService:switchSlot(fakePlayer(USER_ID), 2)

	expect(SlotService:getSlotEpoch(USER_ID)).to.equal(before + 1)
end)

it("does NOT increment the epoch on a refused switch", function()
	local before = SlotService:getSlotEpoch(USER_ID)
	SlotService:switchSlot(fakePlayer(USER_ID), 3) -- locked slot
	expect(SlotService:getSlotEpoch(USER_ID)).to.equal(before)
end)
```

(Expose `getSlotEpoch` on `SlotService` as a thin passthrough to `PlayerDataService:getSlotEpoch`, mirroring how `getActiveSlot` is already exposed.)

- [ ] **Step 2: Run the gate; confirm it fails**

Run: `bash scripts/check.sh`
Expected: FAIL — `epoch` is not a field of `SlotState`.

- [ ] **Step 3: Implement**

`PlayerDataTypes.SlotState` gains `epoch: number`, with a doc comment stating what it is FOR (it invalidates transaction ops minted against a slot the player has since left — see Task 2). The template seeds `epoch = 1`. The `slotState` root validator gains the epoch checks. `switchSlot`'s mutate becomes:

```lua
		local switched = PlayerDataService:mutate(userId, "slotState", function(slotState)
			slotState.active = slotIndex
			-- Bump the generation in the SAME write that moves the slot: any transaction op minted
			-- against the old character is now stale and will be rejected by transaction(). One atomic
			-- mutate, so `active` and `epoch` can never disagree.
			slotState.epoch += 1
			return true
		end)
```

Add `PlayerDataService:getSlotEpoch(userId) -> number?` next to `getActiveSlot` (same shape), and `SlotService:getSlotEpoch` as a passthrough.

- [ ] **Step 4: Run the gate; confirm it passes**

Run: `bash scripts/check.sh` → must be fully green.

- [ ] **Step 5: Commit**

```bash
git add src/
git commit -m "feat(slots): add a monotonic slotState.epoch, bumped on every switch"
```

---

### Task 2: `transaction()` rejects a stale op

**This is the actual fix.** Task 1 only added the counter.

**Files:**
- Modify: `src/ServerScriptService/Services/PlayerDataService/PlayerDataServiceServer.luau` (`TransactionOperation` type + `transaction`'s validation phase)
- Modify: `src/ServerScriptService/Modules/SliceOwner.luau` (`registerSlot`'s `op` stamps the epoch)
- Test: `PlayerDataServiceServer.spec.luau`, `SliceOwner.spec.luau`

**Interfaces:**
- `TransactionOperation` gains an OPTIONAL `epoch: number?`.
- `SliceOwner.registerSlot(...).op(userId, fn)` stamps the CURRENT epoch onto the op it mints.
- `SliceOwner.registerAccount(...).op(userId, fn)` does **NOT** stamp one — account data is slot-independent, so a switch cannot invalidate it. An op with `epoch == nil` is never epoch-checked.
- `transaction(ops)` **rejects the WHOLE transaction** if any op carries an `epoch` that does not match the profile's current `slotState.epoch`.

**WHERE the check goes matters.** It must run in `transaction`'s **side-effect-free validation phase (Phase 1)** — the same place op shapes are validated — BEFORE any lock is taken and before any mutator runs. A stale op must abort the transaction without touching a single profile.

**Reject the WHOLE transaction, not just the stale op.** A trade is atomic by definition; committing the half whose epoch still matches would be worse than committing nothing.

- [ ] **Step 1: Write the failing spec**

In `PlayerDataServiceServer.spec.luau`:

```lua
describe("stale op rejection (slot epoch)", function()
	it("commits an op minted under the CURRENT epoch", function()
		local op = CurrencyService:currencyOp(USER_ID, function(currency)
			currency.jaku += 10
			return true
		end)
		local committed = PlayerDataService:transaction({ op })
		expect(committed).to.equal(true)
	end)

	it("REJECTS an op minted before a slot switch, and writes NOTHING", function()
		local goldBefore = activeSlotOf(PlayerDataService:getProfile(USER_ID)).currency.jaku

		-- Mint against slot 1 (the trade begins)...
		local op = CurrencyService:currencyOp(USER_ID, function(currency)
			currency.jaku += 1000
			return true
		end)

		-- ...the player switches character mid-trade (this is the yield window)...
		PlayerDataService:mutate(USER_ID, "slotState", function(slotState)
			slotState.active = 2
			slotState.epoch += 1
			return true
		end)

		-- ...and the trade tries to commit. It must be REFUSED, not rerouted.
		local committed = PlayerDataService:transaction({ op })

		expect(committed).to.equal(false)
		-- The abandoned character (slot 1) must be untouched — that is the whole point.
		expect(PlayerDataService:getProfile(USER_ID).slots[1].currency.jaku).to.equal(goldBefore)
		-- And the new character must not have received it either.
		expect(PlayerDataService:getProfile(USER_ID).slots[2].currency.jaku).to.never.equal(goldBefore + 1000)
	end)

	it("rejects the WHOLE transaction when one op is stale", function()
		local freshOp = CurrencyService:currencyOp(USER_ID, function(currency)
			currency.jaku += 5
			return true
		end)
		local staleOp = CurrencyService:currencyOp(USER_ID, function(currency)
			currency.jaku += 5
			return true
		end)
		staleOp.epoch = 999 -- simulate an op minted under a long-gone epoch

		local committed = PlayerDataService:transaction({ freshOp, staleOp })
		expect(committed).to.equal(false)
	end)

	it("does NOT epoch-check an ACCOUNT op (a switch cannot invalidate account data)", function()
		local op = SlotService:unlockedSlotsOp(USER_ID, function(unlocked)
			table.insert(unlocked, 2)
			return true
		end)
		expect(op.epoch).to.never.be.ok()

		PlayerDataService:mutate(USER_ID, "slotState", function(slotState)
			slotState.active = 2
			slotState.epoch += 1
			return true
		end)

		-- Minted before the switch, but account-scoped, so it still commits.
		expect(PlayerDataService:transaction({ op })).to.equal(true)
	end)
end)
```

(If `SlotService` does not already expose an `unlockedSlotsOp`, add it — `SliceOwner`'s accessor already provides `op`; surface it the way `CurrencyService` surfaces `currencyOp`.)

In `SliceOwner.spec.luau`:

```lua
it("stamps the current epoch onto a slot-scoped op", function()
	local op = goldSlice.op(USER_ID, function()
		return true
	end)
	expect(op.epoch).to.equal(PlayerDataService:getSlotEpoch(USER_ID))
end)

it("does not stamp an epoch onto an account op", function()
	local op = accountSlice.op(USER_ID, function()
		return true
	end)
	expect(op.epoch).to.never.be.ok()
end)
```

- [ ] **Step 2: Run the gate; confirm it fails**

Run: `bash scripts/check.sh`
Expected: FAIL — `epoch` is not a field of `TransactionOperation`.

- [ ] **Step 3: Implement**

`TransactionOperation` gains `epoch: number?`, documented as: *the slot generation this op was minted under; `transaction()` refuses the op if the player has since switched character. `nil` for account-scoped and raw ops, which no switch can invalidate.*

In `SliceOwner.registerSlot`'s `op`, stamp it:

```lua
		op = function(userId, fn)
			Guard.userId(userId)
			local path = pathFor(userId)
			assert(path, `SliceOwner.op: no profile loaded for userId {userId}`)
			-- Stamp the slot generation this op is being minted under. If the player switches character
			-- before transaction() runs (a trade awaiting confirmation is exactly this window), the
			-- epoch will no longer match and transaction() REJECTS the op — rather than silently
			-- committing to the character they just left, where the mirror gate would also hide it from
			-- the client. See PlayerDataService.transaction's epoch check.
			return { userId = userId, path = path, mutator = fn, epoch = PlayerDataService:getSlotEpoch(userId) }
		end,
```

In `transaction`'s **Phase 1** (the side-effect-free op-shape validation, before any lock), add the epoch check — refusing the whole transaction, logging the stale op, and returning the standard failure result. Do NOT take a lock, run a mutator, or mirror anything first.

`registerAccount`'s `op` is unchanged (no epoch).

- [ ] **Step 4: Run the gate; confirm it passes**

Run: `bash scripts/check.sh` → fully green.

Then confirm by hand-trace, and state it in the report: a stale op aborts BEFORE any lock is taken and BEFORE any mutator runs, so no profile is touched and no atom is mirrored.

- [ ] **Step 5: Commit**

```bash
git add src/
git commit -m "fix(data): reject transaction ops minted against a slot the player has left"
```

---

### Task 3: `gold` / `gems` → `jaku`

The base shipped placeholder currencies. Venture has exactly one soft currency: **`jaku`** (its gold equivalent).

**Files:**
- Modify: `src/ReplicatedStorage/Shared/Modules/Constants/CurrencyConstants.luau`
- Modify: `src/ServerScriptService/Services/CurrencyService/CurrencyServiceServer.luau` (the slice default)
- Modify: every spec/fixture and Cmdr type that names `gold` or `gems` — **grep for both**.

**Interfaces:**
- `CurrencyType` becomes the single-member set `"jaku"`.
- The currency slice default becomes `{ jaku = 100 }`.

**A premium (Robux) currency is coming later, and it must NOT join this slice.** `currency` is **slot-scoped** — each character has their own balance. A Robux-bought currency is an *entitlement*: it belongs to the ACCOUNT and is shared across all three characters (see the account/slot boundary in the design spec). It will land as its own **account slice** via `SliceOwner.registerAccount`. Adding it needs no migration — ProfileStore's `Reconcile()` backfills new template fields onto existing profiles. **Leave a comment in `CurrencyConstants` saying this**, so nobody later "helpfully" adds `premium` next to `jaku` and quietly makes it per-character.

- [ ] **Step 1: Find every reference**

```bash
grep -rn "gold\|gems" src/ --include=*.luau
```

Update EVERY hit. Expect: `CurrencyConstants`, `CurrencyServiceServer` (default), the Cmdr `currencyType` arg type, and fixtures/assertions across many specs. A missed spec fixture typechecks fine and fails at runtime — this branch has been bitten by that class of bug three times now, so grep, don't guess.

- [ ] **Step 2: Write the failing spec change**

Update `CurrencyServiceServer.spec.luau` (and the shared fixtures) to use `jaku` and the new default of 100. Do NOT weaken or delete any assertion — this is a rename, so every test should survive with its meaning intact. If a test only made sense because there were TWO currencies, say so in the report rather than quietly deleting it.

- [ ] **Step 3: Run the gate; confirm it fails, then implement**

`CurrencyConstants`: `CurrencyType = "jaku"`, `MAX_CURRENCY` unchanged, `isValidCurrencyType` unchanged in shape.
`CurrencyServiceServer`: the `SliceOwner.registerSlot` default becomes `{ jaku = 100 }`.

- [ ] **Step 4: Run the gate; confirm it passes**

Run: `bash scripts/check.sh` → fully green.
Then: `grep -rn "gold\|gems" src/ --include=*.luau` must return NOTHING. Paste the result in the report.

- [ ] **Step 5: Commit**

```bash
git add src/
git commit -m "feat(currency): replace placeholder gold/gems with Venture's jaku"
```

---

## Done when

- `bash scripts/check.sh` clean (the `LoadCharacter` DeprecatedApi warning is expected and accepted).
- The full TestEZ suite passes **on the PR** (a feature-branch push skips the test job by design). Baseline before this plan: **512 passing**.
- `grep -rn "gold\|gems" src/ --include=*.luau` returns nothing.
- An op minted before a slot switch is **rejected**, the abandoned character is **untouched**, and the new character does **not** receive the write either.
- No `::` casts added.
