# Design — Affix Rolling (Refactor Phase 3c)

**Status:** draft (pending approval) · **Date:** 2026-07-17 · **Phase:** 3c of the Venture port
(Phase 3 = Inventory + Equipment, decomposed: 3a items/inventory → 3b equipment/stats → **3c affix
rolling** → later transmog/set-bonuses/bank/trading). **Merges before Phase 4 (Bank).**

## Purpose

Gives unique gear (weapon/armour) **per-instance rolled modifiers**, so two copies of the same item
definition are not identical. This finally populates and reads the `UniqueEntry.affixes` field
(reserved, still unread, since Phase 3a), and folds rolled bonuses into the player's derived stats
alongside the definition's fixed `statBonuses` — through the *same* `StatFormulas.derive` `sources`
path 3b already built, with no new stat machinery.

The research pass established that "item variance" here is **two distinct tiers**, and that the
**storage** and the **roll model** are each their own decision. 3c's shape, confirmed with the
developer:

- **Value storage: the absolute rolled value** (genre-standard — PoE/D4). Values are frozen per
  instance; rebalancing a range is handled by a future reroll layer, not by re-deriving on read.
- **Roll model: probabilistic drop, at most ONE affix per item for now** (a FLAT, rarity-independent
  *chance* to get the item's single affix — Terraria-style), expandable to multiple affixes later with
  no schema change.
- **Tier 2 (pool affixes) BUILT; Tier 1 (guaranteed base-stat variance) RESERVED**, activated with
  combat.

## The two-tier item-modifier model (verified genre precedent)

The old game has TWO overlapping rolled-modifier mechanisms that were never unified; they map cleanly
onto a distinction *every* major ARPG makes. Verified against Diablo 2, Path of Exile, Diablo 4:

| Tier | Old-game name | Genre name | Guaranteed? | Rolls from | Renames item? |
|---|---|---|---|---|---|
| **1 — base-stat variance** | per-def `Stats` `{min,max}` (DmgBuff/DefBuff) | **implicit** (PoE) / base defense-or-damage roll (D2) | ✅ every item, one roll | the item's **own declared** core stat | ❌ |
| **2 — pool affixes** | `Boosts` | **explicit affix** / prefix-suffix | ❌ conditional (chance gated by rarity) | a **shared weighted pool** | ✅ ("Titan's…") |

- **Diablo 2** — armour base defense is a *range rolled per drop*, gated by quality tier (Tier 1);
  magic/rare items add *prefix/suffix affixes from weighted pools* (Tier 2). ([base defense](https://us.forums.blizzard.com/en/d2r/t/how-does-base-defense-work-on-armor/20142))
- **Path of Exile** — names it: **implicit** (intrinsic to base, guaranteed, value in a range) vs
  **explicit** affixes (currency-rolled prefixes/suffixes, capped by rarity, tiered). ([modifiers](https://pathofexile.fandom.com/wiki/Modifiers))
- **Diablo 4** — affix **count scales with rarity** (magic 1–2, rare ~3–5, legendary 4 + aspect). ([rarity](https://www.pcgamesn.com/diablo-4/rarity-levels))

Both tiers are real and Venture needs both: Tier 1 is the *floor* of variance (every drop is a
slightly-unique copy), Tier 2 is the *chase* (rare, named, build-defining).

## Scope split — build Tier 2 now, reserve Tier 1 for combat (confirmed)

**Tier 1's entire content is combat stats** — weapon damage, armour defense — and **neither exists in
`StatConstants` yet** (combat is the last phase). Tier 1 has nothing to roll until combat; Tier 2 can
at least roll `strength`/`staminaRegen` now. So Tier 2 is **built**, Tier 1 is **reserved** (fields +
model + aggregation path added; roller inert until combat adds its stat ids). Exactly how `affixes`
itself was reserved in 3a and built here.

## Governing principle #1 — Tier 2 affixes ARE the old "Boosts" system (verified in the live game)

The old `Boosts` pool (`ReplicatedStorage.Modules.Equipment.Boosts`):
```lua
Weapon = { ["Warrior's"] = { stat="Strength", min=5, max=10, chance=2, displayName="Titan's" }, ... }
Armour = { ["Warded"]    = { stat="Defense",  min=5, max=10, chance=2 }, ... }
```
A **named, weighted pool** (`chance` = drop probability), each entry a **stat + min/max roll**, that
**renames the item** ("Titan's Lightbane" via `ProcessBoostName`). Textbook Tier-2 explicit affixes.
**3c is the modernized successor** to this module, keyed to `StatConstants`. There is no separate
"boosts" and "affixes" — the word is *affix*, and it is what the old game called a boost. The old
`chance` field IS the probabilistic drop the roll model below ships (not a deferred refinement).

## Governing principle #2 — the old `Stats` table ALSO smuggled named combat effects; NOT affixes

`Doombringer = 1`, `["Blood Thirsty"] = 1`, `["Rot Symbiosis"] = 1` — `= 1` markers naming bespoke
**combat behaviours** (procs/on-hit effects), the same as `Enchantments = {{Name="Igniting",
chance=20}}`. **Not affixes of either tier** (an affix rolls a *number onto a stat*; a unique effect
grants a *named power*). They belong with the combat core's effect system, **out of 3c**, never
smuggled into a numeric field as `SomeEffectName = 1`.

## Decision 1 — Value storage: the absolute rolled value (genre-standard)

**Store the concrete rolled number on the instance** — e.g. `affixes = { warriors = 7 }` means "+7
strength". This follows the genre: PoE/D4 store **absolute** values; when balance shifts, existing
items keep their old values ("legacy items"), and a currency (Divine Orb) re-rolls them into the
current range on demand. ([Divine Orb](https://pathofexile.fandom.com/wiki/Divine_Orb))

*(A normalized "store roll-quality `q∈[0,1)`, derive value on read" scheme was considered — it would
make rebalancing auto-update every item with no migration — but rejected: every shipping ARPG stores
absolute, players expect their item's number to be stable and not silently shift on a balance patch,
and aggregate stays a pure sum. The rebalance-migration cost is handled the genre way: see below.)*

**Rebalancing existing items** (post-launch, when a range is retuned): absolute values go "stale". Two
sanctioned answers, neither requiring a schema change: (a) **pre-launch it is a non-issue** — data is
wiped at launch and schema changes are free until then; (b) **post-launch**, either a one-shot
`PlayerDataMigrations` pass re-rolls affected entries, or the deferred **reroll currency** (see "NOT in
this phase") lets players opt in — the PoE model. The validator therefore does **not** range-check a
stored value (a legacy value outside the current range is legitimate persisted data, not corruption —
see Decision 8).

## Decision 2 — Roll model: FLAT rarity-independent drop chance, at most ONE affix per item (for now)

Confirmed: **an item has a single affix slot, filled probabilistically at a FLAT chance that does NOT
depend on rarity** (the developer: *"you can only have 1 affix per weapon/armour"* and *"boosts should
be the same % on all rarities"*). Expanding to multiple affixes later is a config + roller change, **no
schema change** (the field stays a map, currently 0 or 1 entries).

**Why flat, not rarity-scaled (verified against Terraria — the developer's reference).** In Terraria,
**item rarity does not affect modifier chance**: on reforge every eligible modifier has an equal shot
regardless of rarity, and a modifier can even *raise* an item's rarity — so the modifier drives
rarity, not the reverse. ([Terraria Modifiers](https://terraria.wiki.gg/wiki/Modifiers)) Rarity there
is a value/colour tier, not a gate. Applied here: higher-rarity gear already carries better base stats
and `statBonuses`, so *also* scaling affix chance by rarity would double-dip the power gap. A flat
chance makes affixes an **independent "did you get lucky" axis** — any item, common included, has the
same shot. Simpler, and it decouples the two systems cleanly. (The ARPG rarity-scaled model is a valid
*different* goal — rarity as a power amplifier with a bigger chase — but not the one chosen here; a
per-rarity table can be reintroduced later with no schema change if the design shifts.)

The "double roll" ships fully for the single-affix case: **(1)** a flat chance roll — do you get an
affix at all — then **(2)** which affix (uniform now, weighted later) + its value. The *deferred*
refinements are **spawn weighting** (making #2 non-uniform, the old `chance`→`weight`) and **multiple
affixes** (count > 1).

## Decision 3 — `AffixConstants`: the ONE declaration site (Tier 2 pool + drop chance per rarity)

New constants module, mirroring `ItemConstants`/`EquipmentConstants`/`StatConstants` (one declaration
site, provisional numbers, retuning is an edit here — never a schema change). Successor to
`Equipment.Boosts`:

```lua
-- AffixConstants.luau (new)
export type AffixDef = {
    stat: string,        -- a StatConstants.STAT_IDS entry (asserted at module load)
    min: number,         -- inclusive integer floor of the rolled value
    max: number,         -- inclusive integer ceiling of the rolled value
    displayName: string, -- the prefix shown on the item ("Titan's")
    weight: number?,     -- reserved; the old `chance` for weighted PICK. Ignored now (uniform). Additive later.
}

-- Named affixes eligible PER ITEM KIND, keyed by a stable affixId. Weapons roll from `weapon`, armour
-- from `armour`; pools do not bleed. Every `.stat` MUST be a real stat id. Every kind with a nonzero
-- drop chance MUST have a non-empty pool (asserted at load — else a "hit" has nothing to pick).
local POOLS: { [string]: { [string]: AffixDef } } = {
    weapon = {
        warriors = { stat = "strength",     min = 1, max = 3, displayName = "Titan's" },
        vigorous = { stat = "staminaRegen", min = 1, max = 2, displayName = "Vigorous" },
    },
    armour = {
        warded   = { stat = "rotEndurance",    min = 1, max = 2, displayName = "Warded" },
        mending  = { stat = "healthRegen",     min = 1, max = 2, displayName = "Mending" },
        renewing = { stat = "rotRejuvenation", min = 1, max = 2, displayName = "Renewing" },
    },
    -- consumable / misc: no pool → never rolled (they are stacks, never UniqueEntry; see Decision 7)
}

-- FLAT chance that a weapon/armour rolls its single affix — rarity-INDEPENDENT (Decision 2). Any item,
-- common included, has the same shot. Provisional; tune freely. A per-rarity table can replace this
-- later with no schema change if the design shifts back to rarity-scaled.
local AFFIX_CHANCE = 0.30
```

**Keyed by affixId, not stat id:** storing the affix's *identity* keeps the name renderable and lets
two affixes target one stat without colliding. `.stat` is still a validated `StatConstants` id, so
principle #1's "no free-form stat strings" holds. **Per-kind** because weapons roll offensive/utility,
armour rolls defensive/sustain, and pools must not bleed.

## Decision 4 — Tier 1 reservation: `statRanges` on definitions, `statRolls` on entries (inert until combat)

Reserve Tier 1's schema now (roller deferred to combat), storing the **absolute** rolled value,
consistent with Tier 2:

```lua
-- PlayerDataTypes.luau
-- WeaponDefinition / ArmourDefinition gain (config DRIVING the guaranteed base-stat roll):
statRanges: { [string]: { min: number, max: number } }?,  -- reserved; each key a StatConstants id.
                                                          -- No current item declares one (combat stats absent).

-- UniqueEntry gains (the per-instance ROLLED VALUE of the above):
statRolls: { [string]: number }?,  -- reserved; absolute value per stat. Unwritten until combat.
```

Combat *activates* Tier 1 by a code-light recipe (no schema churn): (1) add damage/defense stat ids to
`StatConstants`; (2) declare `statRanges` on definitions; (3) roll the value at mint into `statRolls`;
(4) `EquipmentBonuses.aggregate` already folds `statRolls` (Decision 6), so nothing there changes. In
3c, no item declares `statRanges`, nothing writes `statRolls`, it stays nil everywhere.

## Decision 5 — Roll Tier 2 at mint, server-authoritative, stored immutable

Rolled **once, at mint**, server-side, persisted — never re-rolled (no crafting layer this phase),
never client-supplied. Pure function for deterministic testing:

```lua
-- AffixRoller.luau (new, pure) — ItemDefinitions + AffixConstants + StatConstants only, no services.
-- `random` injected so specs pass a seeded Random; production passes Random.new(). Returns nil when
-- no affix drops, so the stored shape stays `affixes: {...}?` with nil = "no affix".
function AffixRoller.roll(itemType: string, random: Random): { [string]: number }?
```

Algorithm:
1. Resolve the definition; if its `kind` has no `POOLS` entry, return `nil`.
2. **Drop roll:** if `random:NextNumber() >= AFFIX_CHANCE` (flat, rarity-independent), return `nil`.
3. **Pick:** choose ONE affixId uniformly from the kind's pool (weighted later via `weight`).
4. **Value:** `value = random:NextInteger(affixDef.min, affixDef.max)` (uniform inclusive integer).
5. Return `{ [affixId] = value }` (a single-entry map).

**Wiring into the mint path:** `InventoryServiceServer.addUnique` mints `count` copies in a loop; it
calls `AffixRoller.roll(itemType, random)` **once per copy** (so copies differ — never share a roll),
storing each result as that entry's `affixes`, **inside** the same `inventorySlice.op` that inserts the
entry. Affixes commit atomically with the item — never detached; a rejected mint (kind-cap breach)
rolls them back too. No new transaction shape. (Combat's Tier-1 `statRolls` is written in this same op,
one more field per entry.) A single module-level `Random.new()` reused across the loop is fine and
preferred (one RNG stream, distinct draws per copy).

## Decision 6 — Consumption: `EquipmentBonuses.aggregate` folds all layers (absolute sums)

The one consumer change. Today `aggregate` sums each equipped entry's definition `statBonuses`. 3c adds
the affix fold (map affixId → stat, add the stored value) and pre-wires the `statRolls` fold (harmless
while nil, so combat need not touch this module):

```lua
-- inside the per-entry loop, after summing definition.statBonuses:
if entry.statRolls then                        -- Tier 1; nil on every entry until combat writes it
    for statId, value in entry.statRolls do
        bonuses[statId] = (bonuses[statId] or 0) + value
    end
end
if entry.affixes then                          -- Tier 2; built this phase
    for affixId, value in entry.affixes do
        local affixDef = AffixConstants.get(affixId)   -- affixId -> { stat, ... }; nil if retired
        if affixDef then
            bonuses[affixDef.stat] = (bonuses[affixDef.stat] or 0) + value
        end
    end
end
```

Both layers contribute only through `aggregate`, which runs only over `equipment.slots`, so **a
modifier counts only while equipped** — like `statBonuses`. Nothing else in the derive path changes. A
**retired** affix (removed from the pool post-launch) resolves to `nil` here and is silently skipped
(Decision 8) — the item stays valid, the affix simply contributes nothing, matching PoE's
disable-don't-delete. `EquipmentBonuses` gains one leaf require (`AffixConstants`) — no service dep.

## Decision 7 — Only `UniqueEntry` gets modifiers; stacks never do

A `StackEntry` is fungible with no `uid`/identity — nowhere to hang a per-instance roll, and rolling
would make stacking incoherent. Consumable/misc are stacks; weapon/armour are uniques. `POOLS`/
`statRanges` only concern weapon/armour; both `affixes` and `statRolls` live on `UniqueEntry` alone.

## Decision 8 — Modifier validation: tolerate retired keys, guard shape not balance

Because both modifier fields ride on `UniqueEntry` (in both the `inventory` and `equipment` slices),
the per-slice validators enforce well-formedness for **any** path into either slice. **This corrects a
bug in the first draft** (which *rejected* entries with unregistered affixIds — that would make every
item carrying an affix un-saveable the moment the affix is retired from the pool, failing the whole
profile write). The validator is **lenient on keys, strict on type**, matching aggregate's leniency and
PoE's disable-don't-delete:

- **Tolerated (NOT rejected):** an affixId not in the pool, or a `statRolls` stat id not in the
  registry. Config-drift, not corruption — the entry saves; the modifier contributes nothing (aggregate
  skips it). This is what keeps retiring an affix post-launch safe.
- **Rejected (real corruption):** a value that is not a number (or not a finite integer).
- **NOT checked:** whether the value sits within the affix's *current* `min..max`. With absolute
  storage a legacy value outside a retuned range is legitimate ("legacy item"), so the validator guards
  *shape/type* (invariant), never *balance* (which drifts).

## Decision 9 — Item display name is a client concern, computed deterministically, not stored

The old game prepends the affix `displayName` ("Titan's Lightbane"). 3c keeps this but computes it
**client-side at render time** from the entry's affixes + `AffixConstants` — not stored, not
authoritative (the entry stores only `{ affixId: value }`; the name is derived like every derived value
here). With at most one affix the prefix is unambiguous; the helper still sorts affixIds
deterministically (by a declared order, not map-iteration order, which Lua does not guarantee) so it
stays stable when multiple affixes land later:

```lua
AffixConstants.displayPrefix(affixes: { [string]: number }?): string?  -- nil when no affix
```

## Service surface

No new service. 3c is additive:

- `InventoryServiceServer.addUnique` — one `AffixRoller.roll` per minted copy (Decision 5).
- `EquipmentBonuses.aggregate` — folds affixes (+ pre-wired statRolls) (Decision 6).
- `AffixRoller` (new, pure) + `AffixConstants` (new, config, in Shared so both realms read) — leaf modules.
- `PlayerDataTypes` — reserved `statRanges` (defs) + `statRolls` (entry) fields (Decision 4).
- Client read: rolled modifiers ride the `inventory`/`equipment` mirrors already; no new packet. Thin
  `getAffixes(entry)` / `displayName(entry)` client helpers may be added for UI.

## Cmdr

- `giveitem` — unchanged signature; unique grants come pre-rolled (roll is in `addUnique`).
- New admin debug command `rollpreview <itemType> [n]` (admin group, fail-closed): rolls N samples and
  prints them (drop hit/miss, affix name, rolled value), so a designer can eyeball a chance/pool/range
  change without minting. Read-only.

## Testing (spec-first, the cases that matter)

- **`AffixConstants` load-time asserts:** every `POOLS[kind][affixId].stat` is a real stat id; every
  kind pool is non-empty; `AFFIX_CHANCE` is a probability in `[0,1]`; every affix `min <= max`.
  (Negative: synthetic violations throw.)
- **`AffixRoller.roll` (seeded `Random`):** drop rate matches `AFFIX_CHANCE` and is **flat across
  rarity** (a common and a legendary hit at the same rate); on a hit, exactly one affixId, from the
  item's kind pool, with value in `[min,max]`; a kind with no pool → nil; two minted copies of one
  itemType get independent rolls.
- **Mint atomicity:** a mint the kind-cap validator rejects rolls back the affixes too (entry never
  lands, `nextUid` never advances — extends the existing addUnique atomicity spec).
- **`EquipmentBonuses.aggregate`:** `statBonuses` only (unchanged 3b behaviour passes); affix only; both
  together (sum); an entry whose affixId is **retired** (not in the pool) contributes nothing and does
  NOT error; unequipped affixed entry contributes nothing; **statRolls fold**: a hand-built entry with
  `statRolls` sums (proves the reserved Tier-1 path before combat).
- **Slice validators:** an entry with a **retired** affixId still **passes** (leniency); a non-number
  value is **rejected**; a legacy value outside the current range **passes** (balance is not policed);
  both `inventory` and `equipment` validators agree.
- **`AffixConstants.displayPrefix`:** nil affixes → nil; one affix → its displayName; deterministic when
  multiple (declared order, not map order).
- **End-to-end:** equip an affixed weapon → `getDerived` reflects baseline + fixed `statBonuses` + the
  rolled affix value; unequip → gone.

## Deliberately NOT in this phase

- **Tier 1 base-stat roller** — schema reserved (Decision 4), roller/content activated with combat. The
  `statRolls` aggregation path IS built and tested against hand-built entries, so activation is content
  + a mint-time roll, not a schema or aggregate change.
- **Multiple affixes per item** — one slot now (Decision 2); expanding to count-per-rarity is a config +
  roller change, no schema change (the field is already a map).
- **Spawn weighting** — uniform pick now; the `weight` field (old `chance`) is reserved, additive later
  (biases *which* affix, distinct from the drop chance that ships now).
- **Named unique-effect abilities** (`Doombringer = 1` / `Enchantments`) — combat behaviours, deferred
  to the combat core (principle #2). Not smuggled into a numeric field.
- **Temporary / consumable boosts** (timed XP/stat potions, gamepass multipliers, if any) — a time-boxed
  buff, not a rolled item modifier; its own domain if/when needed.
- **Mutual-exclusion groups** — a `group` field per affix, addable later (PoE mod-group refinement).
- **Value tiers gated by item level** — single flat range per affix for now.
- **Currency/material reroll & crafting** — the endgame layer (PoE fossils/divines, D4 tempering +
  masterworking) and the sanctioned answer to "rebalancing existing absolute values" (Decision 1). Out
  this phase; affixes are roll-once-at-mint. A future service acts on the existing `affixes` field.
- **Rich weapon combat affixes** (damage/crit/rot-defense) — blocked on combat stat ids; then a `POOLS`
  edit.
- **Rebalancing/populating existing item definitions** — 3c ships the mechanism + pool *config*; tuning
  each item's affix content is content work riding on top, not a correctness prerequisite.
```
