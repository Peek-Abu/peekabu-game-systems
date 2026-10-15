# Cleanup Crew: the cleaning-and-loot loop

Date: 2026-10-15. Extends [the MVP design](2026-10-10-cleanup-crew-design.md) §4 "Vacuum" and "Cargo and carrying",
and replaces its trash-only quota. The developer approved the three mechanics (buried loot, grimy valuables and
mystery appraisal) and the rebalance toward fewer, richer items. Every number is a tuning hypothesis kept in a Data
constants module or the cargo registry.

## 1. Why

The playtest verdict was that the shift plays like a walking simulator. About 88% of a shift is spent carrying items
back to the truck. Cleaning felt like a side chore, and the loop never changed: grab whatever is in the nearest room,
walk it back, repeat. The fix is to make **the vacuum the way you find value and raise it**, and to put **fewer, richer
items** on the map, so every find feels like a find and every trip carries more value.

### Departures from the MVP design

| MVP design says | We do now | Why |
|---|---|---|
| The clearance quota counts trash only; salvage is a separate bonus | **The quota counts everything banked** (trash and valuables, at ×1). Valuables still pay Recovery pay | With trash padding gone, valuables are where the value is |
| The floor is padded with trash to 1.5× the quota | **No trash padding.** Trash comes only from dust bags and the odd desk | 10–15 per bag was pure walking filler |
| 6–9 salvage at 20–120, catalog prices | **10–14 valuables a map** (open, buried and in desks), each **rolled in a range**, scaled by depth, with rare jackpots | Fewer trips, each one worth more |
| Variant B hides 35% of hideable salvage under piles | **Every shift buries loot**; the A/B variant no longer changes the roll | Burying is now core, not an experiment |
| 18–24 piles | **14–18 piles**, about a third of them hiding something | Every pile is still worth a look; fewer of them to clear |

## 2. The loop

1. Explore. A pile that **glints** may hide something, and a grimy valuable's tag reads **"$???"**.
2. Vacuum. A pile clears in 2.5 s and pays canister fill, which still makes a dust bag. A buried pile **pops** its item
   out. A grimy item gets cleaner, rises in value and is **appraised** at 65%.
3. Choose. Cleaning takes time and is loud: it draws the Manager. You can clean it now, or grab it dirty for less.
4. Bank it at the truck. An item that was never appraised is appraised there, with the same stamp.

## 3. Rules and numbers

### 3.1 Valuables (`CargoRegistry`)

Each valuable has a value **range** and an optional **jackpot** variant. Its true value (the **base**) is rolled once,
when the shift's plan is made. The roll is `NextInteger(min, max)` × the depth multiplier, then × the jackpot
multiplier if the jackpot roll hits, rounded to a whole number. The roll always draws the jackpot number, so seeds stay
deterministic.

| Kind | Size | Range | Jackpot (chance, ×) | Buriable |
|---|---|---|---|---|
| Office plant | medium | 45–90 | none | yes |
| Employee of the Month plaque | tiny | 50–100 | "Solid brass" (8%, ×2.5) | yes |
| Monitor | medium | 40–120 | "Gold-trim" (10%, ×2.5) | yes |
| Water cooler jug | heavy | 60–110 | none | no |
| Coffee machine | heavy | 120–200 | "Chrome espresso" (8%, ×2) | no |
| Fish tank (greed) | heavy | 200–320 | none | no |
| Golden stapler (greed) | tiny | 180–300 | "24-karat" (15%, ×2) | under a deep pile or in a desk only |
| Filing cabinet on cart (greed) | bulky | 260–420 | none | no |

The old catalog values averaged about 45. The ranges average about 85 before depth, and about 110 after it, so each
valuable is roughly 2.5–3× the old one. The greed target (always one, always deep) is now worth 300–600, about 4×.
Trash keeps its fixed price: the rubbish bag at 10, the bottle bag and recycling box at 15, and the **dust bag at 15**.

**Depth.** A spawn's room depth is its number of doors from the loading bay. Value is ×(1 + 0.15 × (depth − 1)),
clamped to between ×1 and ×1.6. That makes the next room ×1 and the far rooms ×1.45–1.6. Going deep is the gamble:
richer loot, a longer walk, more time near the Manager.

### 3.2 Grime and value (`CargoAppraisalFormulas`)

- Every valuable spawns **fully grimy** (cleanliness 0). Trash is never grimy.
- What it pays: **base × fragile tier × grime factor**. The grime factor is 0.3 + 0.7 × cleanliness, so 30% at full
  grime and 100% when clean. A cracked monitor that is half clean pays base × 0.5 × 0.65.
- **Cleaning** means aiming the vacuum at the item while it sits on the floor or a surface. It is the same hold, the
  same aim (`VacuumTargetRules`), the same suction and whine as a pile. Time to clean fully, for one player, by size:
  tiny 3 s, light 3.5 s, medium 5 s, heavy 7 s, bulky 9 s. Rates add up across players (2 players clean twice as
  fast). Progress is kept when you stop.
- Cleaning is server-authoritative. It runs as an Interaction channel (`grime-<size>`), and the server mirrors the
  channel's progress into the item's `CargoClean` attribute: cleanliness = start + (1 − start) × progress. The start is
  folded in whenever the channel forgets the item. When an item is fully clean it drops its channel kind and stops
  being a vacuum target.
- **Noise:** while anyone is cleaning an item, it pulses the vacuum's noise (radius 40, every second), exactly like a
  pile. The Manager hears it.

### 3.3 Appraisal

- The tag shows **"$???"** until the item is **appraised**. That happens when cleanliness first reaches **65%**, and
  it sticks.
- When it happens: the tag's APPRAISED stamp pops in. A stamp toast goes to every crew member within 30 studs:
  "APPRAISED · Gold-trim monitor $250". There is a sound hook (`cargoAppraise`, pending) and a small paper burst.
- A jackpot item shows its variant name only once it is appraised ("Gold-trim monitor"). Until then it reads like any
  other monitor.
- **Banking an unappraised item** appraises it at the truck. The banker gets the same stamp toast, and the item pays
  its value as it is (its grime factor still applies: banking does not clean it).

### 3.4 Buried loot

- Each pile hides an item with chance **0.35**. That is about 5–6 of 14–18 piles, capped so that at least 2 valuables
  still lie in the open.
- What goes under a pile is a buriable valuable: plaque, monitor or plant, weighted by their floor weights. A golden
  stapler greed target goes in a deep desk or under a deep pile, as before.
- A buried item is invisible, can't be picked up and has no tag until its pile is vacuumed away. Then it is
  **revealed** with a pop: a gold burst, a sound hook (`cargoReveal`, pending), and the item appearing where the pile
  stood.
- **Glint:** a pile that hides something sparkles. A small twinkle plays every 3–5.5 s (randomised per pile), and only
  clients within 20 studs draw it. It is meant to be easy to miss, and plain piles still pay canister fill toward dust
  bags, so it is still worth vacuuming everything.

### 3.5 The map (`OfficeLootUtils`, `OfficeConstants`)

- **14–18 piles**, each with a 35% burial roll.
- Desks and lockers: a 50% chance each holds something (rubbish, bottle bag or plaque by desk weight). A desk
  valuable counts toward the map's valuables. Once **3** desks hold a valuable, the rest hold trash or nothing. A
  generated office has dozens of desks, and uncapped they took about 7 of the 12 valuables (measured), which left
  almost nothing to bury.
- **Valuables:** a budget of 10–14 a map, counting the greed target, desk valuables and buried ones. The rest of the
  budget goes in the open, on floor markers or their furniture surfaces as before.
- **Top-up guarantee:** if the plan's value at average cleanliness (0.5, a grime factor of 0.65), plus its trash, falls
  below quota ÷ 0.75, the roll adds open-floor valuables, up to 4 extra. `OfficeSpawnRules.check` refuses a plan that
  still falls short (the seed is re-rolled, as before). So the quota never needs more than 75% of a map's value at
  average cleanliness.
- **Trash padding is gone.** That keeps the item count down, and trash is too cheap to be worth a trip on its own. The
  canister still makes dust bags (15 each, about 5 a shift), so vacuuming plain piles still pays.

### 3.6 Quota and pay (`ShiftQuotaFormulas`, `ShiftConstants`)

- **Quota by crew size: 770 / 830 / 870 / 900** for 1 / 2 / 3 / 4 players. Measured over 30 generated offices, a
  map is worth about 1,850 fully clean and about 1,280 at average cleanliness (minimum 1,000, before any top-up), so
  the quota needs roughly 60 / 65 / 68 / 70% of it. Solo gets the smallest share, because one carrier makes fewer
  trips. A crew of four is capped near 70%, because the map does not grow with the crew. `ShiftConstants.QUOTA` (830,
  the two-player figure) stays as the quota posted at the depot; the depot board's copy now reads "of site value".
- **Cleared (the quota)** counts every banked item at ×1: trash value plus valuables' current value.
- **Earned (Recovery pay)** counts valuables only, × the salvage multiplier: ×1 normally, **×1.5 in overtime**. Trash
  never pays, as before.
- **Overtime** still needs the quota met and is still opt-in. Only pay is multiplied: the quota is already met by
  then.

## 4. Edge cases

| Case | Rule |
|---|---|
| Carrying a grimy item | It keeps its cleanliness. Nobody can clean it while it is held: `canChannel` refuses a target with `CarriedBy` set, the client never aims at it, and the channel is re-checked every tick. |
| Dropping or throwing it | It lands with its cleanliness and can be cleaned again. A fragile item's crack and its grime multiply. |
| Cleaning while someone holds it | Not allowed (as above). If someone picks up an item mid-clean, the cleaners' channels end on the next tick. Progress is kept. |
| A catch drops it | Same as a drop: forced drops keep the item and its state. Pocketed items scatter with their appraisal (base, cleanliness, appraised, variant) intact. |
| Pocketing a tiny grimy item | Allowed. The pocket entry carries the appraisal. You can't clean in a pocket. Unpocketing or a scatter respawns it as it was. |
| Multiplayer cleaning | Channel rates add up. Everyone on the item at the appraisal moment, plus anyone within 30 studs, gets the stamp. Noise is credited to every cleaner. |
| Vacuuming a pile next to an item | The aim picks the target nearest the wand's floor head, and keeps the current one while it stays in reach. Piles and items share one pick. |
| Overtime ×1.5 | It applies to the valuables' pay, at their current (grime-scaled) value, at the moment they are banked. Cleared counts ×1. |
| Dust-bag canister | Unchanged: 3 piles make a 15 dust bag. Cleaning an item does not fill the canister, because only cleared piles do. |
| Banking an unappraised item | It is appraised at the truck, with the stamp toast to the banker. It pays at its current cleanliness. |
| A buried item and the greed target | The stapler still prefers a deep desk; if none exists it goes under a deep pile. Buried greed glints like any buried pile. |
| Results screen | CLEARED shows every banked value against the quota. EARNED shows Recovery pay (valuables, overtime ×1.5). ASSETS RECOVERED shows valuables banked out of valuables offered, counting open, buried and desk ones. The EXCEEDS rating rule is unchanged (2 of every 3 offered). |
| The HUD's hands line | A held valuable reads "$???". Its real number is on its tag. |

## 5. Presentation

- **Grime look (client, `CargoGrimeVisualSystem`):** a `Highlight` on the item, with a dark brown fill (fill
  transparency 0.35 at full grime, easing to 1 when clean, no outline, occluded depth). Dust motes drift up from it,
  their rate falling from 4/s to 0. The art kit's meshes and SurfaceAppearances are never touched, so any template
  works, and a cleaned item is exactly its authored self.
- **Tag:** the existing paper price tag (string hole, cream paper). The price reads "$???" until the item is
  appraised. Its mark line reads "62% CLEAN" (joined with "FRAGILE" or "CRACKED −50%" where those apply). Once
  appraised, a small red **APPRAISED** rubber stamp sits on the tag. It pops in when the appraisal is fresh
  (`PaperStamp` pop). A tag also mounts while its item is being cleaned, so you can watch the percentage climb.
- **Reveal:** a gold burst where the item appears, plus `cargoReveal`. **Appraisal:** a paper-fleck burst, plus
  `cargoAppraise`.
- The **sounds still to source:** the reveal sting (`cargoReveal`), the appraisal stamp (`cargoAppraise`), and the
  glint twinkle (`cargoGlint`). They are pending slots in `CargoAssets`; a pending slot is silent.

## 6. Modules

| Feature | Realm | Subfolder | Name | Job |
|---|---|---|---|---|
| Cargo | shared | Utils | CargoAppraisalFormulas | The value maths: the range and jackpot roll, the depth multiplier, the grime factor, the appraisal threshold, an item's current value, cleanliness from channel progress |
| Cargo | server | Systems | CargoGrimeSystem | Mirrors grime channel progress into cleanliness, re-prices, appraises (stamp toast and sound), finishes cleaning, appraises at the truck |
| Cargo | client | Systems | CargoGrimeVisualSystem | The darkening highlight and dust motes, fading with `CargoClean` |
| Cargo | client | Systems | CargoLootFeedbackSystem | The glint on buried piles, the reveal pop, the appraisal burst and sounds |
| Cargo | client | Utils | CargoLootFeedbackFormulas | The grime look (fill, motes, draw distance), the glint schedule and range, and stamp freshness |
| Office | server | Utils | OfficeLootUtils | Rolls the map's valuables: the budget, buried piles, open placement, depth-scaled appraisals, the top-up |
| Shift | server | Utils | ShiftQuotaFormulas | The quota for a crew size, and what one deposit adds to cleared and earned |

Changed: `CargoRegistry` (ranges, jackpots, buriable, grimy), `CargoTypes`, `CargoConstants`, `CargoSpawnSystem`
(appraisal attributes, `reprice`), `CargoFeedbackUtils.entryOf`, `CargoBankRules`, the pocket respawns,
`VacuumConstants` (the grime tag, kinds and times) and `VacuumServiceServer` (`canVacuum` for Cargo's grime channels, and
noise for items being cleaned), `VacuumServiceClient` (aims at grimy items), `VacuumFeedbackSystem` (suction on items),
`CargoPocketSystem` (now answers the pocket and swap packets itself, which keeps `CargoServiceServer` under 400 lines), `OfficeSpawnUtils` and `OfficeSpawnRules` (the loot roll, the
value guarantee), `OfficeServiceServer` (appraisals, glint attribute), `ShiftBankingSystem` and `ShiftServiceServer`
(quota by crew, everything counts), the price tag and its view model, and the HUD hands line.
