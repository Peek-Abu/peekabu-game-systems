# Odd Hours: Gloom lives (3 catches and you're out)

Status: design, waiting for owner approval. Branch `game/cleanup-crew`.

## Why

Getting caught in the MVP costs little: you ragdoll, come back at the truck after a short timer, and keep cleaning. The owner wants getting caught to be scary and to matter. Build week 1 tried a "Gloom coat" where layers could be vacuumed off and players revived. It was rolled back, and the owner rejected that design as too complex. This replaces it with a simple rule.

## What the owner decided

- **Lives:** every employee starts each shift with **3 lives**. Lives are **per player**.
- **Catches 1 and 2:** each costs one life. Otherwise they play exactly like the MVP catch does today, which the owner confirmed plays well: ragdoll, "CAUGHT · back" timer, back in.
- **Catch 3:** **that player is out for the rest of the shift.** The rest of the crew keeps going.
- **While out:** a knocked-out player **spectates their teammates**.
- **Pay:** they **keep their pay**. In the MVP, pay is shared by the crew from team totals, so they simply stay in the review and payout like everyone else.
- **Everyone out:** if every crew member is out (a solo player's third catch included), **the shift ends at once as a missed contract.**
- **No revives:** no vacuuming lives back, no revives, no reapplied lives (owner: "too complex, I don't like it").
- **UI only:** lives show in the UI and **never on the character**.
- **Perks:** an employee or item may change the starting lives later, for example "+1 life". That needs a hook seam now, but no perk content.

## How it fits the MVP

The relevant facts from the code, as of 2026-10-20:

**Catch:**
- Harlow's catch is `OccupantCatchSystem.attempt` → `begin` (`src/ServerScriptService/Features/Occupant/Systems/OccupantCatchSystem.luau`).
- `begin` ends in `DeathServiceServer:kill(victim, "caught", …)`, which is a real death with the Death feature's auto-respawn after 5 s. It also sets the public player field `caughtUntil`.
- `hooks.onCaught` → `OccupantCatchSystem.caught` → `ShiftServiceServer:noteCatch` records `caught` in the shift roster.

**Round:**
- Round already has an unused elimination path: `RoundServiceServer:eliminate(player)`.
- When no participant is left alive, the run ends with the outcome `"wiped"` (`RoundPhaseRules`, `RoundConstants`).
- Shift builds its results from the Round outcome, and a run that didn't meet quota reads "CONTRACT MISSED".

**Spectating:** `DeathServiceClient` spectates living players while the local player is dead (`DeathSpectateRules.candidates`, with cycling). The CCTV catch panel (`CatchViewModel`, `CatchCctvPanel`) shows while dead with a `caughtUntil` time.

**UI and state:**
- Per-player public state goes through `StateSyncPublicPlayerStore` (`caughtUntil`, `dead`, `inTruck` …).
- The crew roster rows are `ShiftCrewViewModel.MemberView` / `ShiftCrewList`.

## Decisions

### 1. Lives are server state with a modifier hook

- **The count:** each player's lives for this shift live on the server in Shift, keyed by UserId, and are set when the shift starts.
- **Starting lives:** `ShiftConstants.STARTING_LIVES = 3`, passed through a registered modifier hook. With no modifiers registered, it returns 3.
- **Clamp:** the result is clamped to at least 1.
- **Publishing:** remaining lives are published as a public player field (`lives`) so every client can show them.
- **Joining late:** a player who joins mid-shift gets full lives.
- **No carry-over:** lives don't persist between shifts and are not saved data.

### 2. A catch costs a life; the last one knocks you out

**Every catch (in the existing `onCaught` path):** subtract one life and publish it.
- If lives are still above 0, nothing else changes: the MVP flow runs (respawn after 5 s, `caughtUntil`, the rehire card).

**At 0 lives, the player is knocked out:**
- they stay dead, with no respawn, until the shift ends;
- the Round eliminates them (`RoundServiceServer:eliminate`);
- `caughtUntil` is cleared and a `knockedOut` public field is set, so the UI shows "out for the shift" instead of a "back in" timer;
- a toast tells the crew: "<name> is out for the shift".

**Knocked-out players:**
- can't be caught again;
- don't count as "still in" for clock-out, as the MVP's dead players already don't;
- return with the crew when the shift ends. Their character comes back at the normal end-of-shift flow.

### 3. Everyone out → missed contract

When the last non-eliminated participant is knocked out, Round's existing `"wiped"` outcome ends the run, and Shift shows the review as a missed contract.

- **The review must treat `"wiped"` like a missed contract:** title "CONTRACT MISSED", the missed-quota rating, and no "extracted" award (`RankFormulas` already requires clock-out for it).
- **A wipe is always a missed contract (owner's call), even when the quota was met before it, in overtime.** Nobody made it out. Shift's results, the review title, the rating and the awards all treat the `"wiped"` outcome as missed, overriding `quotaMet`. Pay maths is unchanged: the MVP pays the team from totals either way.
- **Clocked-out players (Claude's call):** a player who clocked out before the others were knocked out is not eliminated, so Round never reaches `alive == 0`. Knocked-out players count as "out" for clock-out (as dead players already do). Once nobody is still on shift, the shift ends by the normal clock-out rules, with the outcome from the quota as today. It must never hang until the timer runs out; a spec pins that.

### 4. Spectating

Knocked-out players use the existing Death spectate: they follow living teammates and can cycle between them. The CCTV catch panel switches its "BACK ON THE CLOCK IN" line to an "OUT FOR THE SHIFT" state while `knockedOut` is set.

### 5. What players see (UI only)

- **Lives row:** each crew roster row (`ShiftCrewList`) shows the member's remaining lives as 3 small pips, filled or empty. A knocked-out member's row reads "OUT".
- **Local HUD:** the local player sees their own pips, placed by the existing HUD layout rules so they never overlap the Gloom meter, the crew list or the clock-out board (phone included).
- **Losing a life:** when a catch costs a life, the pips update with a short emphasis so the loss is obvious.
- **On the character:** nothing.

### 6. Results

The review keeps today's catch counting (`catches`, the "Most rehired" award). The crew line also records who was knocked out, and the review shows it in the existing crew/results UI without new screens.

## Not in scope (non-goals)

- Revives, vacuuming lives back, the goo coat, or anything on the character.
- Perk content: only the modifier seam.
- Analytics events (a later batch).
- Changes to Harlow's catching, the catch cinematic, the respawn timer for catches 1 and 2, or pay maths.

## Anti-goals

- Lives shown on the character.
- Any way to get a life back during a shift.
- A knocked-out player respawning, cleaning or being caught again.
- A crew that is all out but the shift keeps running.
- Calling it done on specs alone. Done is the owner's 2-player check, below.

## Claude's calls from the builder check (to check while reading)

- **Refills:** lives refill to the starting count at the start of every shift, including "another shift". They do not refill in overtime, which is the same shift. Round's eliminated set already clears on a new run.
- **No respawn:** Death's respawn mode is global today (`CharacterAutoLoads`). A small, generic addition to Death is acceptable: a per-player "hold respawn" that Shift sets for a knocked-out player and clears at shift end. That is a base-shaped change made on the game branch.
- **The third catch:** the life check runs before the catch publishes `caughtUntil`, so the last catch never flashes a "back in" timer.
- **End of shift:** knocked-out players get their character back with the crew in the normal end-of-shift flow. If that flow doesn't already load a dead player's character, the builder adds it.

## Left to the builder

- Where exactly the lives map and modifier registry live inside Shift; it must follow `docs/project-structure.md` (a tracker in State, rules in Rules).
- How Death is told not to respawn a knocked-out player, through its existing respawn modes or a hold.
- Pip art and placement within the existing Toon UI kit and phone-fit rules.

## Verification

1. **Specs:**
   - the lives rules: start, catch, knock-out, the clamp, a late joiner;
   - the modifier hook;
   - the wipe → missed-contract path;
   - the roster and HUD view models: pips and the OUT state.
2. **The owner's 2-player check** (Local Server, 2 players):
   - get one player caught twice and check that the pips drop each time and they come back;
   - on the third catch, check that they stay out, spectate the other player and see "OUT FOR THE SHIFT";
   - then get the second player caught three times and check that the shift ends as a missed contract.

   For a quicker run, a temporary starting-lives value of 1 through the modifier hook is fine.
