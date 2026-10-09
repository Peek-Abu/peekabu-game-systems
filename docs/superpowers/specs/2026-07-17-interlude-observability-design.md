# Design — Interlude: Observability, Docs & Data-Layer Polish

**Status:** approved · **Date:** 2026-07-17 · **Phase:** interlude between Phase 3b (equipment,
merged PR #6) and the next full domain phase (3c affix research / Phase 4 Bank). Consolidates every
"before the next phase" item accumulated across Phases 3a–3b.

## Purpose

Four loosely-coupled workstreams, one branch/PR (`feat/interlude-observability`):

- **A. Debugger observability** — fix the client-context staleness bug found during Phase 3b's
  manual testing, audit every service's `getState`, make large tables inspectable.
- **B. Docs restructure** — commit the untracked agent docs, split the doc hierarchy by job.
- **C. Data-layer validator reasons** — the deferred root fix from PR #6's Qodo review:
  `transaction()`/`mutate()` propagate the failing validator's reason to callers.
- **D. Cleanups** — small ledgered leftovers from Phase 3b's reviews.

No profile schema changes. No new slices. No gameplay behavior changes (C changes *reported
reasons*, never accept/reject outcomes).

## A. Debugger observability

### A1 — Client State tab reactivity (bug fix)

**The bug (found 2026-07-17 during Phase 3b Studio testing):** in client context, `StatePanel`
calls `DebuggerState.getClientAtoms()`/`getClientPlayers()` as plain functions during render — they
read `ClientStore.readSlice()` imperatively, so nothing subscribes to the underlying atoms. The
client view only refreshes when something else happens to re-render the panel (context switch, a
server snapshot arriving). Commands visibly change server state while the client tab sits stale.

**Fix:** convert the client snapshot to a `Charm.computed`. Reading each `ClientStore` slice atom
*inside* the computed's getter makes every slice a tracked dependency, so the computed re-evaluates
when any slice changes. `StatePanel` consumes it via `useAtom` exactly like it already consumes
`DebuggerState.serverSnapshot`. The slice list still derives from `SyncState.SLICES`, so new slices
keep appearing for free.

### A2 — `getState` audit (new convention)

**Convention (document at `ServiceController.getState`'s doc comment, the contract's home):**
`getState` shows what the State tab can't — DERIVED or DIAGNOSTIC data. Raw synced-slice mirrors
are banned (the State tab already shows every synced slice). **A service with nothing derived or
diagnostic to show has NO `getState` at all** — the panel renders "(no getState)" cleanly, and an
absent method beats useless/repetitive data. (`getState` is already optional in
`ServiceController`'s service type.)

| Service | Change |
|---|---|
| `StatsServiceClient` | Rewrite: level, xpIntoLevel/xpToNext, unspent pools (main/sub), full derived stats (via the same `getDerived`-equivalent client computation over the synced slices) |
| `EquipmentServiceClient` | NEW: per-slot equipped itemType summary + aggregated stat bonuses (`EquipmentBonuses.aggregate` over the synced slice) |
| `InventoryServiceClient` | Rewrite: entry counts per kind vs `ItemConstants.KIND_CAPS` (the caps meter) — not the raw items list |
| `CurrencyServiceClient` | DELETE `getState` (its content was a raw slice mirror; nothing derived to show) |
| `InventoryServiceServer` | DELETE `getState` (a prose note pointing at PlayerDataService — useless) |
| `StatsServiceServer` | NEW: active character-subscription count (the mirror-subscription diagnostics — how many players currently have live `Charm.subscribe` pairs) |
| `EquipmentServiceServer` | NEW: slot registry summary (each `EquipmentConstants.SLOTS` id + acceptsKind) — boot-time config visibility |

Other services (`PlayerDataServiceServer`, `DebuggerService*`, `StateSyncService*`) keep their
current `getState`s — they already show diagnostics.

### A3 — Expandable table detail view

The State tab's floating detail window renders values through `TableView`, which truncates nested
tables (`...`) past a small size, making any inventory with more than a few items uninspectable.
Replace the detail window's value rendering with a collapsible tree: every table node expandable/
collapsible by click, primitives rendered inline, no depth- or length-based data loss (large tables
are scrollable within the existing resizable detail window). Collapsed-by-default beyond depth 2 to
keep first paint readable. React Debugger components remain in `SpecRoots.EXEMPT_MODULES`
(rendered in-game; TestEZ has no renderer).

### ~~A4 — Cmdr commands~~ — CUT

`stats <player>` is redundant with the fixed debugger (that is the point of A1/A2), and `setlevel`
is not needed (`givexp` suffices). Explicitly out of scope.

## B. Docs restructure

1. **Commit the currently-untracked `CLAUDE.md` and `AGENTS.md`** — they have never entered git.
2. **Split by job:**
   - `CLAUDE.md` — stays a thin pointer (`@AGENTS.md` import), unchanged shape.
   - `AGENTS.md` — slims to what an agent cannot infer from the code: non-negotiable working rules,
     gotchas learned the hard way, commands table, deployment model, refactor decisions, live-game
     inspection rules. Links out to the docs below for everything else.
   - `docs/project-structure.md` — NEW: where things live (`src/` realm layout,
     Services/Modules/State/Commands trees, the `*ServiceServer`/`*ServiceClient` discovery
     convention, spec-sibling rule, the add-a-slice recipe currently living in `SliceManifest`'s
     header — referenced, not duplicated).
   - `docs/tech-stack.md` — NEW: toolchain (rokit/wally/rojo/selene/stylua/luau-lsp + the CI
     pipeline) and each Wally dependency's sanctioned role — promoting the one-line comments
     currently squeezed into `wally.toml` into real prose.
   - `AGENTS.md`'s "Architecture in one screen" section stays (it is the correct 30-second
     orientation) but content moved to the new files is removed from it, not duplicated.
4. **Relocation guardrails (binding on the implementing task, checked by its reviewer):**
   - **Nothing normative leaves `AGENTS.md`** — rules, locked-in decisions, gotchas, and
     constraints stay. Only descriptive reference material (inferable from the code) moves.
   - **Every moved section leaves a one-line pointer behind in `AGENTS.md`** naming the target doc
     and what's in it, and `AGENTS.md` gains a short "Where to look" doc index (architecture.md,
     project-structure.md, tech-stack.md, ROADMAP.md, testing.md) near the top, so relocated
     content is one hop away in every session even though it no longer auto-loads via
     `CLAUDE.md`'s `@AGENTS.md` import.
3. **`ServerStore` header note** — one paragraph sanctioning server-side derivation reads via
   `getterFor` (first done by `StatsServiceServer.getDerived` in Phase 3b, reviewer-recommended to
   document): the mirror is written synchronously after every committed write, so a server-side
   consumer reading its own player's committed state through `getterFor` is a supported pattern,
   not sync-plumbing abuse.

## C. Validator reasons through the data layer

**Decision (human-approved): extend BOTH `transaction()` and `mutate()`.**

- `TransactionResult` gains `rejectionReason: string?` and `rejectedPath: string?`, populated when
  a slice validator rejects an op's result (the reason string validators already return today —
  currently logged and discarded). Business-logic aborts (a mutator returning `false` itself) leave
  both `nil` — the mutator's owner communicates those via its own mechanism, as today.
- `mutate()` gains a second return: `(changed: boolean, reason: string?)` — `reason` non-nil only
  on validator rejection. Additive and backward compatible (existing single-value callers are
  unaffected; Luau tolerates ignoring extra returns).
- **Consumers simplify:** `InventoryServiceServer` (addStackable/removeByUid/
  removeByTypeAndQuantity/addUnique) and `EquipmentServiceServer` (equip/unequip) replace their
  `"mutation rejected (see server logs)"` fallbacks with the propagated validator reason when
  present. The upvalue-reason pattern remains ONLY for business-logic refusals that genuinely
  originate inside a mutator (e.g. "no item with uid"). `unequip`'s Phase-3b kind-cap pre-flight
  stays (a friendly pre-check), with the propagated reason now backing the exceptional paths too.
- **No behavior change to accept/reject outcomes** — only what gets *reported*.

## D. Cleanups

- `GameItems.spec.luau`: unify the boolean-chain assertions (`expect(x and x.kind == "weapon" and
  x.equipSlot).to.equal("weapon")`) to the guarded-`if` idiom the same file already uses for the
  armour case.

## Testing

- **C (spec-first, `PlayerDataServiceServer.spec`):** validator rejection populates
  `rejectionReason` + `rejectedPath` on the transaction result; `mutate()` returns the reason as
  its second value; a business-logic abort leaves both nil. Consumer specs (Inventory/Equipment)
  tighten their reason assertions from the generic string to real validator messages.
- **A1:** a spec proving the client-snapshot computed recomputes when a `ClientStore` slice atom
  changes (seeded-atom style, like existing client specs).
- **A2:** new/rewritten getStates get value assertions in their services' existing specs; deleted
  getStates get their spec cases removed.
- **A3 + end-to-end:** hand-verified in Studio (F4) at the end — the checks that were impossible
  during Phase 3b's testing: client State tab updating live as commands run, level/derived visible
  in the Services tab, a 40-item inventory fully inspectable in the detail view.

## Deliberately NOT in this phase

- Cmdr `stats`/`setlevel` commands (cut — see A4).
- The live-game systems discovery pass (E) — separate read-only workstream, runs whenever the
  Studio reference place is open; produces a doc, not code.
- 3c affix-rolling research; Phase 4 Bank.
- Any profile schema change.
