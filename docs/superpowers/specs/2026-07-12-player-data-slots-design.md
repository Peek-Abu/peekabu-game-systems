# Design — Player Data: Character Slots (Refactor Phase 1)

**Status:** proposed · **Date:** 2026-07-12 · **Phase:** 1 of the Venture port

## Purpose

Establish the profile shape and data-layer machinery for **character slots** on the game-systems
base, and prove it by moving the base's existing `currency` slice from account-level to slot-scoped.

Slots gate everything else: every persistent domain we port (stats, inventory, equipment, hotbar,
skills, quests…) must know whether it is slot-scoped or account-wide. Until that is settled, no
domain can be ported. This spec covers **Phase 1 only**.

---

## Governing principle — the old game is evidence, not a source

We read the live game to learn **what the game needs** ("there are 3 character slots", "there is a
currency called Jaku", "arena has ranked modes"). We do **not** port its code or its schema. Every
service is designed from scratch on the base's patterns (ServiceController + SliceOwner + Charm +
ByteNet).

Even the *facts* are provisional — much of the old schema predates the team's game-design
experience, and names/fields are expected to change. Surface them as questions; don't assume them.

**Schema changes are free until launch.** Data is being wiped, nothing is published, and no live
profiles exist. We write **no migrations** during the port; we change the shape and wipe.
`PlayerDataMigrations` stays holstered for post-launch evolution only. This freedom means we should
be *aggressive* about fixing old schema mistakes rather than preserving them. Example of what we are
deliberately NOT inheriting: the old `Stats.Health = {HealthRegen, Tick, Buff, Health}` mixes
persistent investment with derived runtime values — derived values do not belong in a datastore.

---

## Background: the constraints that decide the architecture

Verified against Roblox docs, the ProfileStore source, and this repo's code.

1. **`UpdateAsync` is atomic for exactly one key.** Roblox has never offered multi-key transactions.
   Therefore: **any item movement that crosses a key boundary is a hand-built distributed
   transaction; any movement inside one key is free and dupe-proof.**
2. **Size is not the binding constraint.** 4 MB/key ≈ 10k–40k items depending on serialization
   verbosity. Three slots in one key is not tight for Venture. (The per-key *write throughput* of
   4 MB/min bites before the size cap does, and only for very fat profiles.)
3. **ProfileStore session locks are per key**, and contested/crashed handoffs are slow:
   `SESSION_STEAL = 40s`, `ASSUME_DEAD = 630s`. A slot switch that changes keys can therefore block
   for a *long* time. `Steal = true` is a documented duplication footgun.
4. **This repo's data layer is root-key-addressed.** `profile.Data[path]` is indexed directly in
   `mutate`, transaction rollback, validator lookup, and the `ServerStore` mirror
   (`ServerStore.sync(path, userId, profile.Data)`). Nested paths are **not** supported today.
   Making the data layer slot-aware is exactly the Phase 1 job.

**Industry precedent** (WoW Warbands, D3/D4 shared stash, PoE league stashes, Destiny vault): every
multi-character game isolates characters and provides **exactly one sanctioned channel** for moving
things between them — and that channel is always a *place* (bank/vault/stash), never direct
character-to-character transfer, because a place is a single object you can lock and make
transactional. The D3/D4 trade dupe (trade, force-close, log back in holding the item) is
structurally identical to a crash during a slot switch — except that in a slot switch, **the
disconnect is a button in our own UI**.

---

## Decision 1 — One profile key, slots nested inside it

```
Profile "Player_<userId>"   (single ProfileStore key, single session lock)
  _schemaVersion
  slotState : { active : number }
  account : { ... account-wide slices ... }
  slots   : { [1] = { ...slot slices... }, [2] = {...}, [3] = {...} }
```

**Rationale — the payoff is not convenience, it is that cross-slot duplication becomes structurally
impossible rather than merely unlikely.** Moving an item between a slot and shared storage is an
in-memory table move committed by one `UpdateAsync`. And a **slot switch costs zero DataStore calls
and has no crash window**: flip `slotState.active`, re-mirror the atoms, respawn.

`slotState` is a **table**, not a bare `activeSlot : number`: `mutate` hands a mutator the *value* at
a path and expects in-place mutation, so a scalar path is read-only through the data layer and a bare
number could never be switched. Wrapping it keeps the atomicity core's contract unchanged. Being a
bare ROOT key (core profile state, not a domain slice), it is registered — with its range validator —
by the core skeleton via `PlayerDataConstants.registerRootPath`, not by `SlotService`.

Rejected alternatives:

- **Per-slot keys** (`Char_<uid>_<n>`) — buys 4 MB *per slot* and an easier path to many/seasonal
  characters, but costs: two live session locks, a slot switch that can block 40s (contested) or
  630s (after a crash), a mandatory escrow protocol with idempotent transfer UUIDs, and a
  stranded-item recovery sweep. That is a great deal of machinery to buy headroom we do not need.
- **Per-slot keys with account data copied into each** — anti-pattern. N copies of entitlements with
  no source of truth; `MessageAsync` is at-least-once, so reconciliation dupes currency.

**Escape hatch (a design constraint, not a feature):** each slot's data MUST be a **self-contained
subtree with no back-references into other slots**. If a slot ever genuinely approaches ~1 MB, it can
then be lifted out to its own key without reshaping domain code.

**MAX_SLOTS = 3** (matching today's live game). `unlockedSlots` is account-level.

---

## Decision 2 — The account / slot boundary

The rule, derived from the precedent above:

> **Account-level** = *entitlements and collections* — "you own this". Idempotent (owning a mount
> twice = owning it once), therefore safe to share.
> **Slot-level** = *anything that defines a character* — what that character earned, is, or looks
> like. Quantities and item instances are NOT idempotent and must live under exactly one owner.

A second rule that resolves the hard cases:

> **A title (or any claim) must live at the same level as the thing it asserts.**
> Arena rank is slot-scoped ⇒ an arena title MUST be slot-scoped, or it asserts a rank the character
> does not have.

| Account-wide | Per-slot |
|---|---|
| Unlocked cosmetics / accessories / hairs (entitlements) | **Applied appearance** (customization choices — characters must look different) |
| Entitlement titles (purchased, event, beta) | **Earned titles** (arena, profession, milestones) + equipped title |
| Premium / Robux entitlements, game passes | Currency (Jaku — arena currencies re-derived later) |
| Settings (SFX, music, camera shake, PG) | Stats, level, XP, investments |
| `slotState.active`, `unlockedSlots` | Equipment, inventory, hotbar, skills |
| *(later)* Shared Stash | Quests, NPC data, arena rank, professions, crossroads, **soul colour** |

**Note the split seams.** Customization is two things: *unlocked* (account) vs *applied* (slot). The
old schema nests `["Unlocked"]` inside `Customization`; we cut that seam. Titles likewise split into
an account collection and a slot collection.

**Data placed at the character level is a one-way door.** Promoting it to account-wide later is a
full migration (WoW spent ~20 years hauling achievements and mounts up to account level); demoting is
impossible. **When genuinely unsure, default to account-wide** and gate it per-character in the UI.

---

## Decision 3 — Two banks, and the order they ship in

- **"Bank" — per-slot** (ships first; the one players use constantly). Lives *inside* the slot's own
  subtree. **Accepts currency and items.** It is architecturally free: there is no cross-slot
  movement, so no boundary, no escrow, no dupe surface.
- **"Shared Stash" — account-wide** (later). The single sanctioned channel between slots.
  **Items only — no currency.** Deliberately small (few tabs/slots).

Building the slot bank first delivers the needed feature while deferring **100% of the
distributed-transaction risk**, and the Shared Stash is then purely additive — a new account-level
slice, no migration, no reshaping.

**Why the Shared Stash must not move currency:** an account-wide stash that accepts currency makes
currency account-wide with extra steps — slot 1 deposits, slot 2 withdraws, and per-slot currency is
a fiction. WoW made exactly this call: even with Warbands, currency was deliberately not pooled.
Until the Shared Stash exists, no cross-slot channel exists at all, so per-slot currency is honest by
construction.

**Twinking is a design problem, not a data problem.** Once the Shared Stash lets a fresh slot receive
endgame gear, do **not** fix it with transfer bans. Let the item move; gate its *use* with **equip
requirements** (level/stat minimums). That preserves the fresh-start feel, and it is a tuning knob
rather than a schema we would have to migrate. Equip requirements land in Phase 3.

**Slot deletion is a data-loss surface** (this is Destiny's Postmaster mistake — per-character
overflow that silently eats items when a character is deleted). Deleting a slot must require a
confirmation that *names what is being destroyed*, and players must be able to move keepsakes out
first. No silent deletion.

---

## Decision 4 — Making the data layer slot-aware

The base addresses slices by a **single root key**. Slots require the layer to address
`slots.<n>.<slice>`. Two ways:

**(A) Slice-major — store a per-slot map inside each slice value** (`profile.Data.currency = {[1]=…,
[2]=…}`). Requires no PlayerDataService changes. **Rejected:** `ServerStore.sync` mirrors the *whole
slice value*, so the client would receive **all three characters' inventories**, and the profile
shape stops being human-legible ("what is in slot 2?" fans across every slice). It also weakens the
self-contained-subtree escape hatch.

**(B) Slot-major with path resolution — CHOSEN.** `profile.Data.slots[n].<slice>`. Teach the data
layer that a `path` may be a *path*, not a bare key, via one small internal resolver:

```
resolve(profileData, path) -> (container, key)
```

used by `_getSliceShell`, `mutate`, `transaction` (including rollback), validator lookup, and the
mirror. Contained, and specced first.

**API.** `SliceOwner` gains two registrars; the returned `SliceAccessor<T>` shape is unchanged, so
**domain services stay ignorant of slots** and keep reading/writing a plain `T`:

- `SliceOwner.registerAccount(slice, default, read, validate?)` → path `account.<slice>`
- `SliceOwner.registerSlot(slice, default, read, validate?)` → resolves to
  `slots.<slotState.active>.<slice>` **at call time**, so `get(userId)` / `mutate(userId, fn)` always
  address the player's active character.
  - plus an explicit `getForSlot(userId, slotIndex)` for the slot-select UI and admin tooling.

Consequences to handle explicitly:

- **Template stamping.** `registerSlot` must stamp its default into **every** slot (1..MAX_SLOTS) of
  `PROFILE_TEMPLATE`, deep-copied per slot.
- **Validator lookup must normalise the slot index**: `slots.2.currency` → `slots.*.currency`.
  Otherwise a slice's invariant silently applies to slot 1 only — precisely the class of bug the
  data-layer validator exists to prevent.
- **The mirror must normalise too, and project only the active slot.** `slots.2.currency` mirrors
  into the client atom `currency`. The client never receives inactive slots' data.
- **Slot switch must re-mirror every slot-scoped slice** (that *is* the switch).
- Atomicity is unchanged throughout: it is all still one profile, one key, one `UpdateAsync`.

---

## Slot switch — the flow

Server-authoritative; the client may only *request*.

1. **Validate** (Guard): slot index in range, slot unlocked, not mid-combat / mid-trade / in
   instanced content. Reject otherwise.
2. Despawn the character.
3. `mutate` the `slotState` root key (`slotState.active = n`).
4. Re-mirror every slot-scoped slice into `ServerStore` for the new slot.
5. Respawn.

No DataStore call. No lock. **No crash window** — if the server dies mid-switch, the player wakes up
in whichever slot the last save recorded, and no state is duplicated or lost, because every slot and
the bank were always in the same atomic value.

---

## Scope of Phase 1

**In:** profile shape (`slotState` / `account` / `slots`); `MAX_SLOTS`, `unlockedSlots`; path
resolution in PlayerDataService; `SliceOwner.registerAccount` / `registerSlot`; validator + mirror
normalisation; slot-switch flow (service + ByteNet packet); slot-select UI; **migrating the existing
`currency` slice to slot-scoped** as the proof.

Currency is the proof case on purpose: it already has a reference implementation and full specs, so
it exercises the new machinery with a small blast radius and tells us immediately if the slot-aware
API is wrong.

**Out (later phases, each its own spec → plan → implement cycle):** stats/progression (2),
inventory + equipment + equip requirements (3), per-slot Bank (4), customization/skills/quests/
titles/arena/professions (5+), Shared Stash, and the combat core **last** (it needs a genuine
server-authoritative hit-detection redesign, not a port).

**Slot creation/deletion UX** beyond the confirmation rule is out of scope here.

---

## Testing

Spec-first (`<Name>.spec.luau` before implementation), per the repo's TDD gate. Cases that matter:

- Path resolution: root, `account.x`, `slots.<n>.x`; missing/malformed path.
- `registerSlot` stamps defaults into all `MAX_SLOTS` slots, deep-copied (no shared-table aliasing).
- Validator normalisation: an invariant registered once is enforced on **every** slot, and a
  `transaction()` op that violates it rolls back.
- Mirror: writing slot 2's currency while slot 2 is active updates the client atom; **inactive
  slots' data never reaches the client**.
- Slot switch: atoms re-mirror; a rejected switch (locked/out-of-range slot) mutates nothing.
- Atomicity: a transaction spanning an account slice and a slot slice commits or rolls back as one.

## Decision 5 — Slot previews are fetched on demand, never persisted

Decision 4 projects **only the active slot** into the client's atoms — that is what keeps inactive
characters' inventories off the wire. So the slot-select screen, which must show slots you are *not*
playing, cannot read them reactively. It fetches them instead:

**Client opens slot select → ByteNet request → server reads `getForSlot(userId, n)` per slot,
projects only the preview fields (name, level, appearance, equipped title, playtime) → returns.**
The server stays the single source of truth, nothing derived is persisted, and inactive slots' full
data never leaves the server — we ship ~5 fields per slot, not an inventory. Point-in-time on open is
sufficient: one session lock means nothing else is mutating slot 2 while you look at it.

If previews end up needed in several places, the client may cache the response in a **client-only**
`ClientStore` atom (refreshed on open, invalidated on slot switch) so any UI can read it reactively.
That is a cache, not state.

**Rejected: a persisted `slotPreviews` account slice.** It is derived data, duplicated — every write
touching a name/level/appearance would have to update it or it drifts, giving "what level is slot 2?"
two sources of truth that can disagree.

**Customization is not a preview problem.** The customization world edits the **active** character
only, and the active slot is already fully mirrored and reactive — it comes for free. Preview
machinery is needed *only* on the slot-select screen.

## Resolved

- **Arena currencies (`RankedToken` / `UnrankedToken`) are dropped from Phase 1.** The arena economy
  is re-derived in its own phase.
- **`Jaku` is confirmed** — it is Venture's gold-equivalent currency, and the name stays.
  NOTE: the base ships placeholder currencies `gold` / `gems` (from the game-systems base, not from
  Venture). Renaming `gold` → `Jaku`, and deciding whether a `gems`-equivalent premium currency
  exists at all, belongs to the **currency-domain phase**, where that schema is re-derived — not a
  drive-by rename here. Slot-scoping the currency slice (Phase 1a) is independent of what the
  currencies are called.
- **`SoulColor` is slot-scoped** — it is character identity.
- **Slot previews:** on-demand fetch, per Decision 5.

## Open questions (deferred, not blocking)

- Is the customization world a separate Roblox place (teleport) or a zone in the same place? It does
  **not** affect the data architecture (same profile key; the session follows the player) — it only
  affects where that UI lives and whether a slot switch implies a teleport. Settle in Phase 5.
