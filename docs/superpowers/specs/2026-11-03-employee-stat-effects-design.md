# Employee stats that change play: design (2026-11-03)

Status: **plan only, waiting for the owner's yes.** Nothing is built.

Today the five stats (Speed, Stamina, Strength, Suction, Quiet; 1 to 5 bars) are display only:
`EmployeeStatFormulas` has `STEP = 0`, so every effect is 1. This plan turns them on.

Roster (sum 15 each): Pippa 4/4/2/3/2, Cappy 3/2/3/3/4, Prickles 3/3/3/3/3.

Rules this plan keeps (characters/launch/new-employee-requirements.md §C, §G): stats are fixed by design, equal
totals, a narrow range, no stat points, nothing gated by a stat, health parked, lives stay 3, abilities separate.
The biggest one: **solo play is never made worse; every map stays clearable solo with the lowest stats.**

## 1. The big decision: 1 bar plays like today

Today's numbers (walk 16, sprint 23, 6 s stamina, the carry slowdown, 2.5 s piles, noise 40/10) are the ones the
maps and Mr. Harlow were tuned and play-checked against. So:

- **1 bar = exactly today's game.** Each bar above 1 adds a small step. Stats only ever add; nobody is ever
  slower, weaker or louder than the game the owner has already play-checked.
- The solo check then holds by construction: a 1-bar employee plays today's tested solo game.
- Cost: every crew gets a little better than today (the average is 3 bars, so about two steps up). The steps are
  small (table below), and Harlow can be retuned later from playtests, with one hard rule: **any Harlow retune is
  re-checked solo with every stat at 1** (`employeestatset me all 1`).
- The 1-to-5 spread stays inside the ±15%-from-the-middle rule (each stat spans at most +16% from 1 to 5, so
  ±8% round the middle).

Alternative (if the owner says no): keep 3 bars = today, as the seam does now. Then a 1 or 2 is worse than
today, so the steps must be smaller, and Speed/Stamina at 1 have to be re-checked against solo Harlow at the top
tier (chase 20.5), where today's lead is only 2.5 studs a second.

`EmployeeStatFormulas` changes from one `STEP` round `MIDDLE` to a per-stat step from a floor:
`effect = 1 + STEP[stat] x (bars - 1)`, and a missing employee counts as 1 bar (today's game).

## 2. Each stat

Numbers are the start of tuning; the owner's play-check sets the final steps.

### Speed: walk and sprint speed
- **Step:** +1.5% walk and sprint per bar above 1. Crouch (6.5) is unchanged; sneaking is not a race.

| Bars | 1 | 2 | 3 | 4 | 5 |
|---|---|---|---|---|---|
| Walk | 16.0 | 16.24 | 16.48 | 16.72 | 16.96 |
| Sprint | 23.0 | 23.35 | 23.69 | 24.04 | 24.38 |

- **2 vs 4 in play:** over a full sprint, a 4 gets about 4 studs further than a 2. You feel it in a long hall,
  not in a room.
- **Why so small:** an escape is the gap between your sprint and Harlow's chase (20, 21 at the top tier), not
  your speed. +1.5% of speed is +0.35 of a 3 stud/s gap, about +12% lead per bar. A bigger step would double the
  lead at 5.
- **Solo:** 1 bar = sprint 23 vs solo Harlow 19.5 (20.5 at the top tier), as today.
- **Stacks with Let's Go!:** Speed is part of the **plain speed**, not a boost. Commit 1eb6751a keeps
  `WalkSpeed = plain speed x one boost scale`; the stat changes the plain speed, Let's Go!'s 1.25 multiplies on
  top, and the boost rule (one scale, never multiplied) is untouched. Pippa at 4 boosted sprints 30.05; a
  1-Speed teammate she boosts sprints 28.75.
- **Carry:** the carry slowdown multiplies the stat's speed, as it multiplies today's.

### Stamina: how long the sprint lasts and how fast it comes back
- **Step:** +5% bar length and +5% refill speed per bar above 1. Regen delay (0.8 s) and the 30% restart stay.

| Bars | 1 | 2 | 3 | 4 | 5 |
|---|---|---|---|---|---|
| Full sprint | 6.0 s | 6.3 s | 6.6 s | 6.9 s | 7.2 s |
| Empty to full | 3.5 s | 3.33 s | 3.18 s | 3.04 s | 2.92 s |

- **2 vs 4 in play:** Pippa (4) runs 0.6 s longer than Cappy (2): about 14 studs more running, about 2 studs more
  lead on Harlow, and her bar is back about 0.3 s sooner.
- **Solo:** 1 bar = today's 6 s and 3.5 s, the "12-18 studs of lead" the chase kit was tuned for.
- **Abilities:** none touch stamina today. If a later ability refills stamina, it refills the bar to full, whatever
  its length.

### Strength: carried items slow you less
- **Step:** takes 4% of an item's weight off per bar above 1, before Carry's slowdown (5% speed per unit of weight,
  floor 40%). The floor does not move.

| Walk while carrying | 1 | 2 | 3 | 4 | 5 |
|---|---|---|---|---|---|
| Heavy (weight 7) | 10.4 | 10.62 | 10.85 | 11.07 | 11.30 |
| Bulky (weight 10) | 8.0 | 8.32 | 8.64 | 8.96 | 9.28 |

(At Speed 1. Sprint is 23/16 of each.)
- **2 vs 4 in play:** with a heavy item, Cappy/Prickles (3) walk about 2% faster than Pippa (2); a 4 would be about
  4% faster than a 2. Small items (the hotbar) weigh nothing to the walk, so Strength is only felt with big items.
- **Solo:** 1 bar = today's slowdown.
- **Abilities:** none. Throwing is unchanged.

### Suction: the vacuum cleans faster
- **Step:** +4% cleaning speed per bar above 1, for dust piles and for grimy items.

| Bars | 1 | 2 | 3 | 4 | 5 |
|---|---|---|---|---|---|
| One pile | 2.5 s | 2.40 s | 2.31 s | 2.23 s | 2.16 s |
| Heavy grime (7 s) | 7.0 s | 6.73 s | 6.48 s | 6.25 s | 6.03 s |

- **Not wider.** The brief says "fast and wide"; this plan does speed only. Wider reach would change
  `VacuumTargetRules` (the client picks the pile, the server re-checks it), which is a second, riskier change and
  harder to see. Reach could come later.
- **2 vs 4 in play:** about one extra pile in every 13.
- **Today all three are 3**, so Suction makes no difference between today's employees; everyone cleans 8% faster
  than now.
- **Crew:** players on one pile still add up; each one adds at their own speed.
- **Solo:** 1 bar = today.
- **Abilities:** none.

### Quiet: Mr. Harlow hears you from less far
- **Step:** -4% to the radius of **your own** noises per bar above 1: sprinting feet (10) and your vacuum (40),
  before Harlow's hearing scale. Noises that are not "you" (a dropped item, a hide tumble, the truck) are not
  changed.

| Bars | 1 | 2 | 3 | 4 | 5 |
|---|---|---|---|---|---|
| Vacuum | 40 | 38.4 | 36.8 | 35.2 | 33.6 |
| Sprint feet | 10 | 9.6 | 9.2 | 8.8 | 8.4 |

- **2 vs 4 in play:** Cappy (4) vacuuming is heard about 3 studs less far than Pippa (2). The ripple ring on the
  floor (it is drawn at the radius Harlow hears) is visibly smaller.
- **Several vacuums on one pile:** the pile's noise uses the loudest one on it, so a quiet employee cannot hide a
  loud one.
- **Solo:** 1 bar = today.
- **Abilities:** Potted Plant stands still, so it makes no noise anyway; nothing stacks.

## 3. How players can tell

- The stat rows (pick screen, Locker About tab, Shop hire page; `ToonStatRows`) get one short line under each
  name, at kid reading level:
  - Speed: "Run faster." Stamina: "Run longer." Strength: "Carry big stuff faster."
  - Suction: "Clean faster." Quiet: "Mr. Harlow hears you less."
- No numbers or percentages shown. The ripple ring already shows Quiet in play.
- No in-shift HUD change.

## 4. How it is wired (server-authoritative)

- The server knows each character's employee (`EmployeeName` on the character, set by Employee). A new
  `EmployeeStatSystem` writes five attributes on each character (`StatSpeed` … `StatQuiet`, bars 1-5) at every
  dress and swap, from the profile or from an admin override. The server writes them; a client cannot change the
  server's copy.
- Each owner reads the bars from the character and does its own maths through `EmployeeStatFormulas.effect`:
  Sprint (Speed, Stamina), Carry (Strength), Vacuum and Cargo's grime (Suction), Sprint and Vacuum's noise (Quiet).
  No owner depends on the Employee service, so no dependency loop (Employee already depends on Carry, Vacuum and
  Occupant). A character without the attributes plays at 1 bar, today's game.
- Speed: the plain walk is set from the stat at spawn; `SPRINT_SPEED` is scaled by the same effect. Every place that
  reads a base back already divides out the boost scale (1eb6751a), so the stat stays in the base.
- Stamina: `SprintStaminaFormulas.step` takes the effect for drain length and refill time. The client's bar
  (`SprintViewModel`) reads the server's `SprintStamina` attribute, so it needs no change.
- Suction: Interaction's channel today advances by `dt x players / duration`, the same for everyone. It needs an
  optional per-player rate (`rateFor(player)`, default 1). **Interaction is a base feature, so this one change is
  its own `base/*` PR**, then the game branch uses it.

## 5. New modules

| Feature | Realm | Subfolder | Name | Job (one line) |
|---|---|---|---|---|
| Employee | server | Systems | `EmployeeStatSystem` | Writes each character's five stat bars (profile or admin override) at dress and swap |
| Employee | server | State | `EmployeeStatOverrideTracker` | Remembers admin stat overrides per player for testing; cleared when they leave |
| (Commands) | server | `Commands/` | `EmployeeStatSet` + `EmployeeStatSetServer` | Cmdr: set or reset a player's stat bars for testing |

Each gets a `.spec` sibling. No new subfolder kind, role word or second service.

Changed, not new: `EmployeeStatFormulas` (per-stat steps from a floor of 1), `EmployeeConstants` (the attribute
names), `SprintSpeedFormulas`, `SprintStaminaFormulas`, `SprintServiceServer`, `CarryFormulas` /
`CarrySpeedSystem`, `VacuumServiceServer`, `CargoGrimeSystem`, `InteractionChannelTracker` /
`InteractionChannelSystem` (base PR), `ToonStatRows` (the one-line hints), and the existing spec that checks every
effect is 1 (it becomes: 1 bar is exactly 1 for every stat; 5 bars stay inside the band).

## 6. Admin command

`employeestatset <players> <stat|all> <1-5|reset>`, for example:
- `employeestatset me all 1`: the solo floor check.
- `employeestatset me speed 5`, then `... speed 1`: feel the range.
- `employeestatset me all reset`: back to the employee's own bars.

Admin-only through the existing fail-closed allowlist. An override lasts until reset or the player leaves, and
survives a respawn.

## 7. Risks

| Risk | Guard |
|---|---|
| Crews find shifts a little easier (stats only add) | Small steps; retune Harlow from playtests, always re-checking solo at all-1 |
| Differences too small to notice | The owner's play-check with the command at 1 and 5 decides; steps are one table to change |
| Speed splits a crew (a fast teammate runs off) | +6% at most from 1 to 5; Let's Go! still pulls the crew together |
| A stat value leaks into a base, or a boost into the stat | Speed lives only in the plain speed; specs for boost + stat + load together |
| Suction needs a base change | Its own small `base/*` PR first; the rest does not wait on it |
| Attributes missing after a respawn or employee swap | Written at every dress and swap; missing = 1 bar (today), never worse |

## 8. How the owner tests it (2 clients, real play)

1. Solo, top tier: `employeestatset me all 1`. Escape Harlow down a long hall and clear the map. It should feel
   exactly like today.
2. `employeestatset me speed 5` then `1`: run the same hall; the 5 should feel a little quicker, not a jump.
3. Carry a bulky item at Strength 1 and 5.
4. Two clients on one pile, one at Suction 1, one at 5: the pile clears faster than either alone.
5. Vacuum at Quiet 1 and 5: the ripple ring is smaller at 5.
6. Pippa uses Let's Go! next to a 1-Speed teammate: both speed up, nobody shoots off.

## 9. Order of work (after the owner's yes)

1. Interaction per-player channel rate (`base/*` PR).
2. `EmployeeStatFormulas` per-stat steps + `EmployeeStatSystem` + override tracker + the command (specs first).
3. Speed and Stamina in Sprint; then Strength in Carry; then Quiet in Sprint/Vacuum noise; then Suction.
4. The stat-row hints.
5. Owner play-check (section 8). Board status "Ready to check", never Done until the owner says so.
