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

- A cleared pile removes **50 Gloom** (`VacuumConstants.PILE_GLOOM`; 20 until the follow-up of §3.5, 40 until §3.6) toward the
  contract **the instant it is vacuumed** (`ShiftGloomSystem`, from Vacuum's `pileCleared`).
- **The dust is clustered** (§3.5): **4-6 dirty rooms** (`OfficeConstants.DIRTY_ROOMS`), each with **3-5 piles**
  (`PILES_PER_ROOM`), with a clean room between any two of them where the layout allows (no two dirty rooms share a
  doorway or a corridor; `OfficeSpawnUtils` step 1, `pileOrder`). Every other room is clean. Each generated room
  offers up to 5 pile markers (`PILE_SPOTS`): its two rear corners, then the free floor nearest a wall, placed after
  all the furniture so they never displace it (`OfficeLayoutRoomUtils`).
- **No dust bags.** The canister has no capacity and nothing pops out. Nothing needs carrying to count. The
  backpack's canister window is now a **live Gloom gauge**: every crew member's gauge shows the crew's Gloom as a
  share of the contract, its lamp lights once the contract is met, it ticks as the Gloom rises and chimes once when
  the contract is met (`VacuumFeedbackSystem`, `VacuumFeedbackFormulas.gaugeTarget` / `gloomTick`).
- Why a shared gauge and not a per-player one: the contract is the crew's, so the gauge answers the one question a
  player has ("how far are we?"). Per-player effort still shows on the review (piles per player).

### 3.2 Valuables

- Every valuable carries Gloom by size, at full grime (`CargoConstants.GLOOM_BY_SIZE`): **tiny 5, light 8, medium 15,
  heavy 25, bulky 35**, times its starting grime (every valuable spawns fully grimy, so that is all of it).
- **The bottle bag is a valuable again** (one of the three old trash kinds): light (8 Gloom, pocketable like the tiny
  ones, so it goes in a hotbar item slot), rattly, base 45-85 Gleam before depth with a rare "Vintage glass" jackpot
  (x2, 10%), open-floor weight 2 (about 1 in 15 open-floor rolls), never in a desk drawer and never under a pile. It
  is cleaned, appraised and banked like every other valuable (`CargoRegistry`).
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
- **By crew size 1 / 2 / 3 / 4: 640 / 690 / 740 / 790 Gloom** (`ShiftConstants.QUOTA_BY_CREW`; 530 / 560 / 610 /
  650 at 40 per pile, 260 / 280 / 300 / 320 at 20 per pile and spread dust).
- **Measured** over 60 generated offices (2026-10-17, clustered dust at 50 per pile): 19.3 piles on average in 4.9
  dirty rooms (4-6; 3, 4 and 5 piles about equally often), about 965 Gloom of dust and 107 of grime on 12.4
  valuables, so a site holds about **1070 Gloom** (730-1495). The contract asks about **60 / 64 / 69 / 74%** of it,
  the same shares as at 40 per pile, so a shift is as hard as before.
  Solo gets the smallest share because one player covers less ground; the biggest crew is capped because the site
  does not grow with the crew.
- **Guarantee** (`OfficeLootUtils.shortfall`, `OfficeSpawnRules.check`): the contract may ask at most **80%**
  (`OfficeConstants.CONTRACT_SHARE_MAX`) of the site's Gloom. A thinner roll gets up to **6** extra plain piles
  (`TOP_UP_MAX`, was 4: the thinnest clustered roll, 4 rooms of 3 piles, needs about 6 for the biggest crew), on the
  dirty rooms' spare pile markers first, then a clean room's, so the extra dust stays clustered; a plan still short is
  refused and re-rolled. Measured (2026-10-17, 50 per pile): 0 of 60 generated offices refused, 0.83 extra piles a
  site on average, the biggest crew's contract never above 80% of a topped-up site (at most 79.8%). The old value top-up (extra valuables) is gone: the pay is no
  longer what the contract needs.
- `OfficeSpawnUtils.spec` checks every generated office against the biggest crew's contract, that the contract
  is 62-78% of the average site, and that dust is 46-56% of a typical shift's pay (§3.6).

### 3.5 "A room of dust ≈ one good valuable": both levers, approved 2026-10-16

At 20 per pile with the dust spread thin (1.25 piles to a dusty room) a room of dust was worth about 25 Gleam against
90-165 for a good valuable. The user approved R-2's pick: **cluster the dust into fewer, properly dirty rooms (3-5
piles) and raise a pile to about 40.**

Measured after the change (60 generated offices): a dirty room holds **3.9 piles, about 155 Gloom (120-200)**, and a
valuable's plain base averages **142 Gleam** after depth, so a dirty room is worth about one good valuable. Dust is
about **88% of the site's Gloom**. Its share of the pay: about **43% of a typical shift's** (most of the dust vacuumed,
two thirds of the valuables banked at average cleanliness), **29%** of a perfect one (everything vacuumed, cleaned
and banked). If the user wants dust nearer half of a perfect shift, the next levers are more dirty rooms
(`DIRTY_ROOMS` 5-7) or about 50 a pile.

### 3.6 Dust toward half the pay: 50 a pile, approved 2026-10-17

The user approved raising dust's share of the pay toward half, on one condition: **valuables keep their values**.
Only dust is worth more, and the contract scales with it so a shift stays as hard.

- **The lever: the pile value, 40 → 50** (`VacuumConstants.PILE_GLOOM`). It reaches about half on its own, and it
  leaves the map alone (the same 4-6 dirty rooms of 3-5 piles), where 5-7 dirty rooms would have changed how a site
  plays (more rooms to cross, fewer clean ones between them).
- **The typical shift** (the model behind §3.5's 43%, now written down and specced): 80% of the dust vacuumed, two
  thirds of the valuables cleaned to `LOOT_AVERAGE_CLEAN` (0.5, value ×0.65) and banked, their grime cleaned that far.
  Measured over 60 generated offices (2026-10-17):

  | | 40 a pile | 50 a pile |
  |---|---|---|
  | Dust's share of a typical shift's pay | 43.6% | **49.1%** |
  | Dust's share of a perfect shift's pay | 29.2% | 34.0% |
  | A typical shift's pay (Gleam) | ~1,417 (dust 618) | **~1,571 (dust 772)** |
  | A site's Gloom | ~880 (610-1215) | ~1070 (730-1495) |
  | A dirty room | ~155 Gloom | ~198 (150-250) |
  | A valuable's plain base, after depth | 142.3 Gleam | **142.3 Gleam (unchanged)** |
  | Contract, crew 1-4 | 530 / 560 / 610 / 650 | **640 / 690 / 740 / 790** |
  | Contract's share of a site | 60 / 64 / 69 / 74% | 60 / 64 / 69 / 74% |

- **Valuables are untouched:** no change to `CargoRegistry`, `CargoConstants` or the appraisal and depth formulas. A
  valuable's grime Gloom (tiny 5 … bulky 35) and its banked value are what they were, so the extra pay is all dust.
- A dirty room is now worth a good valuable or a little more (about 200 Gloom against about 142 Gleam).

## 4. What was removed

- **Dust bags**: the `dustBag` cargo kind (registry and art-kit key), the canister capacity, `dustBagReady`, the bag's
  landing spot, the per-player public `canister` field, `VacuumCanisterUtils` and its spec, and the `dustBagPop`
  sound. The place still holds the dust bag's art template (`ArtKits["client-office-slate"].cargo.dustBag`); nothing
  reads it, and it can be deleted in Studio.
- **Trash spawns**: trash only existed to pad the old quota. Desks and lockers now hold a valuable (still capped at 3)
  or nothing; trash has no weights, so it never spawns. Banking adds no "CLEARED" floater any more.
- **Answered 2026-10-16:** the bottle bag came back as a valuable (§3.2). The rubbish bag and the recycling box stay
  hidden in the catalog, unspawned: the cargo rules' specs use them as fixtures and a throwable distraction could
  reuse them.

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

Follow-up (2026-10-17, §3.6): `VacuumConstants.PILE_GLOOM` 50; `ShiftConstants.QUOTA_BY_CREW` 640-790 (`QUOTA` 690);
the `OfficeSpawnUtils.spec` dust-share check.

Follow-up (2026-10-16, §3.5): `VacuumConstants.PILE_GLOOM` 40; `OfficeConstants` (`DIRTY_ROOMS`, `PILES_PER_ROOM`,
`PILE_SPOTS`, `PILE_SPOT_STEP`, `TOP_UP_MAX` 6); `OfficeTypes.RollOptions` (`dirtyRooms`, `pilesPerRoom` replace
`piles`); `OfficeLayoutRoomUtils` (the extra pile spots); `OfficeSpawnUtils` (`pileOrder`: dirty rooms, clustered
top-up); `OfficeLayoutRules.checkCapacity` (enough rooms with a dirty room's pile markers); `OfficeLayoutConstants`
(one more pile marker in the authored break room and manager's office); `ShiftConstants.QUOTA_BY_CREW`;
`CargoRegistry` (the bottle bag a valuable).

Changed: `CargoConstants` (`GLOOM_BY_SIZE`), `CargoAppraisalFormulas` (`gloomLeft`, `gloomRemoved`), `CargoGrimeSystem`
(`cleaned`), `CargoServiceServer` (`grimeRemoved`), `CargoRegistry` (no dust bag, trash unweighted),
`CargoFeedbackUtils` (no CLEARED for banking), `VacuumConstants` (`PILE_GLOOM`), `VacuumServiceServer` (no canister),
`VacuumFeedbackSystem` and `VacuumFeedbackFormulas` (the gauge), `OfficeLootUtils` (`gloomOf`, the Gloom shortfall),
`OfficeSpawnUtils` (desk valuables only, the pile top-up), `OfficeSpawnRules`, `OfficeConstants`,
`ShiftConstants` (contract table, `CURRENCY_NAME` "Gleam", `CONTRACT_UNIT`, `GLEAM_PER_GLOOM`, the `dust` counter),
`ShiftQuotaFormulas` (`pay`, `pileGloom`, `breakdown`), `ShiftBankingSystem` (pay only), `ShiftResultsUtils` and
`ShiftSnapshotUtils` (the results' `dust`), `ShiftCurrencyUtils` (Gleam, `unknown`, `gloom`, `contract`),
`ShiftNoticeUtils` (CONTRACT MET), and the view models listed in §5. Removed: `VacuumCanisterUtils`.
