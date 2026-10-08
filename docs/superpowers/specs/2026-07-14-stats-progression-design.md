# Design — Stats & Progression (Refactor Phase 2)

**Status:** approved · **Date:** 2026-07-14 · **Phase:** 2 of the Venture port
**Branch:** `feat/stats`, stacked on `feat/player-data-slots` (Phase 1, PR #1)

## Purpose

Give a character slot a **character**: a level, an XP total, and a build (points invested into stats).
This is the first domain that makes slots mean something — today slots differ only by a Jaku balance.

It is also the prerequisite for two later phases: **equip requirements** (Phase 3's twinking gate is
gated on level) and the **slot-select UI** (a preview needs a level to show).

---

## Governing principle — the old game is evidence, not a source

We read the live game to learn what the game *needs*. We do **not** port its code or its schema. See
`docs/superpowers/specs/2026-07-12-player-data-slots-design.md`. Schema changes are free until launch
(data is wiped, nothing is published): **no migrations are written during the port.**

**Names in this spec are provisional.** Stat ids, pool names, and every constant are expected to
change. The design's job is to make changing them cheap — one config entry, never a schema change.

---

## Evidence from the old game (what we learned, and what we are dropping)

Gathered by reading `PlayerStatManager`, `LevelUp`, `PlayerStatDefinitions`, `StatHandler`, and their
consumers in the live place.

**The decisive finding: the old game had TWO stat systems, mid-migration.** A legacy persisted blob
(deeply nested `Stats` table → `ServerStorage[UserId]` ValueObjects), and a newer, better runtime
engine (`StatHandler`: base values + named modifier sources + a `flat → +% → ×` stack). The old team
was already escaping the legacy blob. **We do not inherit the thing they were running away from.**

Of the old persisted `Stats` table, only a small part was ever a genuine player *choice*:

| Kept (a real progression fact) | Dropped, and why |
|---|---|
| `Level`, `Experience` | `Health/Stamina/Mana/Decay/Rot/Stealth/Walkspeeds` tables — **derived or config**, needlessly baked into the save blob. Recomputed from investments anyway. |
| The point pools | `Strength` (top-level) — **dead**: its load-time write is commented out. It also collided with two other "Strength" concepts. |
| The 8 `Investments` | `Mana` — **abandoned**: one skill reads it, no regen loop, no investment feeds it. |
| | `Decay` (the saved resource) — **never a choice**: no investment feeds it; it was a config constant in every save. The "decay" players experience is the Rot *status effect*, which is combat-phase machinery. If a decay-style resource returns, it will be a **derived** runtime value needing zero persistence. |
| | `Deaths` / `KillTracker` — **telemetry, not stats.** Returns later as its own slice, designed around quest-tracking needs (event counters), which is a different shape from a vanity kill list. |

**Kept because it is distinctive:** the **Rot subsystem** (`rotStrength` → spell-shield power,
`rotEndurance` → rot-bar size, `rotRejuvenation` → spell-shield regen). Three of the eight
investments feed it; it is Venture's signature mitigation mechanic.

**Level-up rewards were stubs** in the old game (empty tables, commented-out `-- ADD WEAPON`). A
level-up granted points and nothing else. We inherit that: points only.

---

## Decision 1 — Store `totalXp`. Derive the level.

The old game stored `Level` **and** `Experience`-within-level, mutating both on level-up with a
recursive carry loop (`exp - level*25`, then recurse). Two fields that can disagree, and the buggiest
path in the system.

**We store lifetime `totalXp` only.** `level = levelOf(totalXp)` is a pure function.

- `addExperience(n)` is `totalXp += n`. **No level-up loop, no carry, no recursion** — that entire
  class of bug becomes unrepresentable.
- Level and XP **cannot** disagree: one source of truth.
- Level-up *detection* (for VFX/sound) is `levelOf(before) ~= levelOf(after)` — an **event**, not state.

## Decision 2 — Store `investments`. Derive the unspent point pools.

The old game already proved this model: it **never stored Skill Points as a counter**, deriving them
as `Level × 2 − unlocked nodes`.

- Points **earned** is a pure function of level: `mainPointsEarned(level)`, `subPointsEarned(level)`.
- Points **spent** is `sum(investments)`.
- **Unspent = earned − spent.** Nothing to store, nothing to desync, **nothing to inflate.**

"Conservation of points" therefore stops being an invariant we *check* and becomes **true by
construction**. There is no counter to corrupt.

## The whole persistent schema

```lua
-- slot-scoped slice: each character has their own build
stats = {
	totalXp = 0,                          -- lifetime XP; level derives from this
	investments = {},                     -- { [statId]: points }, e.g. { health = 3, rotEndurance = 1 }
}
```

**Two fields.** Everything else — level, xp-into-level, xp-to-next, unspent pools, maxHealth, regens,
rot-bar size — is computed by a shared pure module. **Nothing derived is stored, and nothing derived
is replicated**; the client runs the same pure function against the replicated slice.

---

## Decision 3 — A pure derive module, not a modifier engine (yet)

`StatFormulas` (shared realm, pure, no dependencies):

```
levelOf(totalXp) -> number                       -- clamped to MAX_LEVEL
xpForLevel(level) -> number                      -- cumulative XP at which `level` begins
progress(totalXp) -> { level, xpIntoLevel, xpToNext }
pointsEarned(level) -> { main: number, sub: number }
pointsSpent(investments) -> { main: number, sub: number }
pointsUnspent(totalXp, investments) -> { main: number, sub: number }
derive(totalXp, investments) -> DerivedStats     -- maxHealth, maxStamina, healthRegen, ... 
```

`derive` is `base + points × perPoint` per stat, read from the definitions registry.

**We do NOT build the modifier-source engine now** (the `flat → +% → ×` stack with named sources for
equipment/mutations/statuses). Every consumer of it belongs to a system that does not exist yet —
speculative machinery is exactly what YAGNI kills.

**But we shape for it.** When Phase 3 (equipment) lands, `derive` grows a `sources` parameter and
becomes the StatHandler shape. That is an **extension, not a rewrite**, because `derive` is already
the single funnel every consumer reads through.

## Decision 4 — One config registry: `StatDefinitions`

Every stat is one entry. Adding or renaming a stat is a config edit, **never** a schema change —
which is what makes "names are not final" cheap.

```lua
StatDefinitions.DEFINITIONS = {
	health          = { pool = "main", base = 200, perPoint = 5, derives = "maxHealth" },
	stamina         = { pool = "main", base = 100, perPoint = 2, derives = "maxStamina" },
	healthRegen     = { pool = "sub",  base = 1,   perPoint = 1, derives = "healthRegen" },
	staminaRegen    = { pool = "sub",  base = 1,   perPoint = 1, derives = "staminaRegen" },
	rotStrength     = { pool = "sub",  base = 1,   perPoint = 1, derives = "rotStrength" },
	rotEndurance    = { pool = "sub",  base = 1,   perPoint = 1, derives = "rotEndurance" },
	rotRejuvenation = { pool = "sub",  base = 1,   perPoint = 1, derives = "rotRejuvenation" },
	strength        = { pool = "sub",  base = 1,   perPoint = 1, derives = "strength" },
}
```

Values carried from the old game **as provisional starting points**, not as truth.

Tuning constants live beside them, all explicitly provisional:
- `MAX_LEVEL = 30`
- `xpToNext(level) = level * 25` (linear, from the old game)
- Points per level: **1 main, 3 sub**

**Two pools: main and sub.** (Names not final.) Skill points are **not** in this slice at all — the
old game derived them from level, and the skill tree is a later phase. Nothing to store now, and no
dead field in the schema.

---

## Decision 5 — The slice validator (what the data layer enforces)

Registered via `SliceOwner.registerSlot`, so it holds for **any** path into the slice — including a
raw `transaction()` op that never went through a service method.

1. `totalXp` is a number, an integer, `>= 0`, and `<= xpForLevel(MAX_LEVEL)` (the clamp — see below).
2. Every `investments` key is a **registered stat id** (unknown keys rejected — same rule as currency).
3. Every investment value is an integer `>= 0`.
4. **Spent must not exceed earned, per pool.** `pointsSpent(investments).main <= pointsEarned(level).main`,
   and the same for `sub`.

Rule 4 is the one that matters: it makes an over-invested build **unrepresentable in stored data**,
regardless of which code path tried to write it.

## Decision 6 — XP clamps at max level; no overflow banking

`addExperience` clamps `totalXp` at the max-level threshold. XP earned at max level is **discarded**.

Consequence, stated plainly: raising `MAX_LEVEL` later does **not** retro-credit XP earned while
capped. That is the accepted trade (chosen deliberately over banking overflow), and it keeps
`totalXp` bounded.

---

## Service surface — `StatsServiceServer`

Server-authoritative. The client never writes; it reads the replicated slice and runs `StatFormulas`
locally.

```
getStats(userId)            -> StatsSlice?              -- the raw persisted slice
getProgress(userId)         -> { level, xpIntoLevel, xpToNext }?
getDerived(userId)          -> DerivedStats?            -- via StatFormulas.derive
getUnspentPoints(userId)    -> { main, sub }?
addExperience(userId, n)    -> (boolean, leveledUp: boolean)   -- clamped at MAX_LEVEL
invest(userId, statId, n)   -> (boolean, reason: string?)      -- refuses if unspent < n
respec(userId)              -> boolean                          -- investments = {}; refunds ALL points
```

- `invest` validates the stat id and the pool's unspent balance **before** writing; the data-layer
  validator is the backstop, not the primary check.
- **Respec is a full reset** (`investments = {}`). Per-point *uninvest* is deferred to the UI phase —
  the old game had server-side uninvest that its own UI never called.
- `applyToCharacter(player)` sets `Humanoid.MaxHealth` from `derive`, on spawn and after any change.
  **Server-side only** — note the old game let *clients* write `WalkSpeed`, which is a server-authority
  hole we are not reproducing.

**Admin Cmdr commands** (the test surface, as with slots): `givexp`, `invest`, `respec`.

## Replication

`stats` is a **slot-scoped** slice → `SliceManifest` entry → the client atom holds the **active
character's** stats only, per Phase 1a. The client computes level/derived values from it with the
same `StatFormulas` module. **No derived value is ever replicated** — there is nothing to desync.

## Testing

Spec-first, per the repo's TDD gate. The cases that matter:

- `levelOf` / `xpForLevel` are **mutual inverses** at every level boundary; `levelOf` clamps at `MAX_LEVEL`.
- A single `addExperience` that crosses **several** levels at once lands on the right level (the old
  game's recursive carry loop is exactly what this replaces).
- `pointsUnspent` = earned − spent, across levels and investment sets.
- `invest` refuses when the pool is short, and **writes nothing** when it refuses.
- The validator **rejects** an over-invested build, an unknown stat id, a negative investment, and a
  `totalXp` above the cap — each rolled back by the data layer.
- `respec` returns every point (unspent == earned afterwards).
- Slot isolation: investing on slot 1 leaves slot 2's build untouched (the Phase 1 guarantee, re-proved
  for a second domain).

## Deliberately NOT in this phase

- The **modifier-source engine** (equipment/mutation/status layers). Arrives with equipment (Phase 3),
  as an extension to `derive`.
- **Skill points / the skill tree** — a later phase; derived from level, so nothing to store now.
- **XP sources.** `addExperience` is the entry point; what *grants* XP (kills, quests, arena) is wired
  per-domain as those systems port. The old game granted XP only from arena — we are not bound by that.
- **Telemetry** (kills/deaths) — a FUTURE NOTE only, not scheduled work in any current phase. When it
  does happen it will be its own slice, shaped around quest-tracking needs (event counters), not a
  port of the old KillTracker.
- Per-point **uninvest** (UI phase). Full `respec` covers the need today.
- Stamina/rot **runtime resource loops** (drain/regen ticks) — combat-phase machinery. This phase
  produces the *values*; consuming them is a later phase's job.

## Known consequence — retroactive curve changes

Because level is derived from `totalXp`, changing the curve **retroactively re-levels everyone**.

- Pre-launch: free (data is wiped).
- Post-launch, *softening* the curve levels players up — harmless.
- Post-launch, **hardening** it levels players *down*, which can leave a character with more invested
  points than their new level earns — and the validator (rule 4) would then reject their next write.
  If we ever harden the curve post-launch, it must ship with a one-time migration that refunds the
  overage. Bounded and known; noted here so it is not a surprise.
