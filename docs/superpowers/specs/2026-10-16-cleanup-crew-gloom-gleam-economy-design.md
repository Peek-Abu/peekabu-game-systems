# Cleanup Crew: the Gloom and Gleam economy

Date: 2026-10-16. Approved by the user: **"Vacuum it = the job. Bank it = the pay."** It replaces the quota and the
pay of [the loot loop](2026-10-15-cleanup-crew-loot-loop-design.md) §3.6, the dust bags of
[the MVP design](2026-10-10-cleanup-crew-design.md) §4 "Vacuum", and the "$" / Recovery pay everywhere players see
money. The cleaning, grime, appraisal and buried-loot rules of the loot loop are unchanged. Every number is a tuning
hypothesis kept in a Data constants module.

## 1. Why

The quota counted everything banked, so the job was hauling: dust only mattered once it was bagged and carried to the
truck, and cleaning a valuable mattered only through its price. The new split gives each action one clear purpose:

- **The job** is removing the anomaly's residue from the building. It counts the moment it happens, wherever you are.
- **The pay** is what you bring back. Walking to the truck is a choice you make for Gleam, never a chore the contract
  forces on you.

## 2. Words

- **Gloom**: the anomaly's residue. It is the dust in the building and the grime on valuables. The contract is
  counted in Gloom.
- **Gleam**: refined Gloom. Morrow & Morrow pays its associates in Gleam. It is the one currency players see, written
  as the word after the number ("45 Gleam"), with no sign and no emoji (`ShiftCurrencyUtils`).
- In code the contract keeps its old names (`quota`, `quotaMet`, Round's `clearance` counter), so the shift machine,
  the analytics and the rank did not have to be renamed. Only what players read changed.

## 3. Rules and numbers

### 3.1 Dust piles

- A cleared pile removes **20 Gloom** (`VacuumConstants.PILE_GLOOM`) toward the contract **the instant it is
  vacuumed** (`ShiftGloomSystem`, from Vacuum's `pileCleared`).
- **No dust bags.** The canister has no capacity and nothing pops out. Nothing needs carrying to count. The
  backpack's canister window is now a **live Gloom gauge**: every crew member's gauge shows the crew's Gloom as a
  share of the contract, its lamp lights once the contract is met, it ticks as the Gloom rises and chimes once when
  the contract is met (`VacuumFeedbackSystem`, `VacuumFeedbackFormulas.gaugeTarget` / `gloomTick`).
- Why a shared gauge and not a per-player one: the contract is the crew's, so the gauge answers the one question a
  player has ("how far are we?"). Per-player effort still shows on the review (piles per player).

### 3.2 Valuables

- Every valuable carries Gloom by size, at full grime (`CargoConstants.GLOOM_BY_SIZE`): **tiny 5, light 8, medium 15,
  heavy 25, bulky 35**, times its starting grime (every valuable spawns fully grimy, so that is all of it).
- Cleaning removes it **live, in step with cleanliness**: each cleaning step reports the Gloom it took off
  (`CargoAppraisalFormulas.gloomRemoved`, through `CargoGrimeSystem`'s `cleaned` and Cargo's `grimeRemoved`). The
  steps are differences of one rounding, so a full cleaning always adds up to exactly the item's Gloom.
- **Banking a valuable adds no Gloom.** A valuable counts toward the contract only for the grime cleaned off it.
- **Grabbed dirty, it never gives the rest.** The first pick-up locks its grime (loot loop §3.2a), and a locked item
  can never be cleaned, so the Gloom left on it is never removed.

### 3.3 Pay (Gleam)

- **1 Gleam per Gloom removed** (`ShiftConstants.GLEAM_PER_GLOOM`), dust and item cleaning alike, paid at clock-out.
  It is never multiplied.
- **Plus banked valuables** at their appraised value, cleanliness-scaled and depth-scaled exactly as before, in Gleam
  (Round's `bonus` counter, `ShiftQuotaFormulas.pay`).
- **Overtime:** valuables ×1.5 (`OVERTIME_SALVAGE_MULTIPLIER`); the Gloom keeps paying the normal rate.
- The Gloom is paid whether or not the contract was met: it is work done. A missed contract still rates NEEDS
  IMPROVEMENT, as before.
- There is still no saved balance. The pay is display-only, like Recovery pay was.

### 3.4 The contract

- **Remove X Gloom.** Clock-out unlocks once it is met, and overtime stays opt-in after it, both as with the quota.
- **By crew size 1 / 2 / 3 / 4: 260 / 280 / 300 / 320 Gloom** (`ShiftConstants.QUOTA_BY_CREW`).
- **Measured** over 30 generated offices (2026-10-16, the same check as the old quota): 16.4 piles on average (14-18)
  and about 107 Gloom of grime (70-170) on 11.6 valuables, so a site holds about **435 Gloom** (350-530). The
  contract asks about **60 / 64 / 69 / 74%** of it. Solo gets the smallest share because one player covers less
  ground; the biggest crew is capped because the site does not grow with the crew.
- **Guarantee** (`OfficeLootUtils.shortfall`, `OfficeSpawnRules.check`): the contract may ask at most **80%**
  (`OfficeConstants.CONTRACT_SHARE_MAX`) of the site's Gloom. A thinner roll gets up to 4 extra plain piles on free
  pile markers (`TOP_UP_MAX`); a plan still short is refused and re-rolled. The old value top-up (extra valuables) is
  gone: the pay is no longer what the contract needs.
- `OfficeSpawnUtils.spec` checks every generated office against the biggest crew's contract, and that the contract
  is 62-78% of the average site.

### 3.5 "A room of dust ≈ one good valuable": not met at 20, needs a decision

Measured: a room that has dust holds **1.25 piles on average** (1 pile in 75% of them, 2 in 25%), so a room of dust is
worth about **25 Gleam**. A good valuable banks about **90-165 Gleam** (median base 120 after depth; tiny ones 40-170).
At 20 Gloom per pile the rule does not hold, by a factor of about 4. Two levers, for the user to choose:

1. **Raise `PILE_GLOOM` to about 75-80.** The rule holds, the site grows to about 1,400 Gloom and the contract table
   scales with it (×3.7), and dust becomes about half of the pay. That softens "bank it = the pay".
2. **Cluster the dust**: fewer dusty rooms with 3-5 piles each (an `OfficeSpawnUtils` change). The rule holds at about
   20-25 per pile and dust stays the smaller part of the pay.

Until then the shipped value is the approved **20**.

## 4. What was removed

- **Dust bags**: the `dustBag` cargo kind (registry and art-kit key), the canister capacity, `dustBagReady`, the bag's
  landing spot, the per-player public `canister` field, `VacuumCanisterUtils` and its spec, and the `dustBagPop`
  sound. The place still holds the dust bag's art template (`ArtKits["client-office-slate"].cargo.dustBag`); nothing
  reads it, and it can be deleted in Studio.
- **Trash spawns**: trash only existed to pad the old quota. Desks and lockers now hold a valuable (still capped at 3)
  or nothing; trash has no weights, so it never spawns. Banking adds no "CLEARED" floater any more.
- **Open question:** the three trash kinds (rubbish bag, recycling box, bottle bag) stay in the catalog, unspawned,
  because the cargo rules' specs use them as fixtures and a throwable distraction could reuse them. Deleting them
  outright touches about 20 spec files.

## 5. UI and copy (paperwork style)

| Where | Now reads |
|---|---|
| HUD contract folder | tab "SITE CONTRACT", "340" over "/ 500 Gloom"; compact "Gloom 340 / 500" |
| HUD fee plate | "EARNED 760 Gleam": the Gloom removed so far plus the valuables banked |
| Hotbar slot 1 (the vacuum) | "340/500", the contract's progress |
| Backpack canister window | the crew's Gloom gauge, lamp lit when met |
| Price tags, hotbar tags, appraisal slips | "120 Gleam", "??? Gleam" until appraised |
| Banking floater | "+120 Gleam" (no CLEARED number: banking removes no Gloom) |
| Milestone stamp | "CONTRACT MET" |
| Depot board | CONTRACT row "Remove 300 Gloom for your crew of 3. Vacuum the dust; clean valuables before you lift them."; PAY row "1 Gleam per Gloom removed, paid at clock-out, plus every valuable you bank at its appraised value (x1.5 in overtime)." |
| Work order sign, arrival card | "REMOVE 300 GLOOM" |
| Truck pad tag | "TRUCK 2 · CREW · 300 GLOOM" |
| Results (review) | "CONTRACT MET / MISSED"; GLOOM REMOVED "340 / 500" with "Dust 260 · Item cleaning 80"; EARNED "760 Gleam" with "Dust 260 · Cleaning 80 · Valuables 420" (the breakdown lines are on desktop; the phone review shows the totals) |
| Depot last-shift card and result board | "Gloom removed" and "Earned" in Gleam, "CONTRACT MET" |
| Field guide | "VACUUM & BANK", "NO DUST BAGS" |
| Rank XP line | "Contract" (was "Quota"); the award is unchanged: it pays for the contract met |

Ranks and owner skins are unaffected.

## 6. Modules

| Feature | Realm | Subfolder | Name | Job |
|---|---|---|---|---|
| Shift | server | Systems | ShiftGloomSystem | Credits each cleared pile's and cleaning step's Gloom to Round's `clearance` (and piles to `dust`) while a shift runs, then re-checks the contract |

Changed: `CargoConstants` (`GLOOM_BY_SIZE`), `CargoAppraisalFormulas` (`gloomLeft`, `gloomRemoved`), `CargoGrimeSystem`
(`cleaned`), `CargoServiceServer` (`grimeRemoved`), `CargoRegistry` (no dust bag, trash unweighted),
`CargoFeedbackUtils` (no CLEARED for banking), `VacuumConstants` (`PILE_GLOOM`), `VacuumServiceServer` (no canister),
`VacuumFeedbackSystem` and `VacuumFeedbackFormulas` (the gauge), `OfficeLootUtils` (`gloomOf`, the Gloom shortfall),
`OfficeSpawnUtils` (desk valuables only, the pile top-up), `OfficeSpawnRules`, `OfficeConstants`,
`ShiftConstants` (contract table, `CURRENCY_NAME` "Gleam", `CONTRACT_UNIT`, `GLEAM_PER_GLOOM`, the `dust` counter),
`ShiftQuotaFormulas` (`pay`, `pileGloom`, `breakdown`), `ShiftBankingSystem` (pay only), `ShiftResultsUtils` and
`ShiftSnapshotUtils` (the results' `dust`), `ShiftCurrencyUtils` (Gleam, `unknown`, `gloom`, `contract`),
`ShiftNoticeUtils` (CONTRACT MET), and the view models listed in §5. Removed: `VacuumCanisterUtils`.
