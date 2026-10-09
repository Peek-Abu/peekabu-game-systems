# Round / match lifecycle — design

Status: built with this spec. Roadmap item #7 (docs/ROADMAP.md).

## Goal

One owner for "where are we in the match": a lobby, a countdown, the run itself, and a results screen,
plus the state that only lives for one run (who is in it, the team's quota progress, scores, a run bag).
The horror games run nights or missions; the rodeo game runs events. Each configures the same machine
and reacts to its phase changes instead of hand-rolling timers and player lists.

## Decisions

1. **Four phases, one server-owned machine.** `lobby → starting → running → results → lobby`.
   The transitions are a pure module (`RoundPhaseRules`) the service steps a few times a second:
   - lobby → starting when `autoStart` and at least `minPlayers` are present (or when the game calls
     `startCountdown()` — a ship lever, a "ready" pad);
   - starting → lobby if players drop below `minPlayers`; starting → running when the countdown ends;
   - running → results when `duration` runs out (`"timeout"`), when every participant has left
     (`"abandoned"`), when every remaining participant is eliminated (`"wiped"`), or when the game
     calls `endRound(outcome)` (`"quota"`, `"survived"`, any string);
   - results → lobby after `resultsDuration`.
   `startNow()` skips the countdown (admin, tests).
2. **Configured, not subclassed.** `configure({ minPlayers, countdown, duration?, resultsDuration,
   autoStart, lateJoin, eligible? })`. No `duration` = the run lasts until the game ends it. `eligible`
   picks who joins a run (default: everyone present). `autoStart` defaults to **false**, so the base is
   inert until a game opts in: a game that never uses rounds simply stays in the lobby.
3. **Run state is not saved.** `RoundRunTracker` holds the participants and eliminated players, team
   counters (`addTeam("scrap", 40)` — a shared wallet or quota progress), targets (`setTarget("scrap",
   300)`), per-player scores, and run containers. It is reset when the next run starts; nothing touches
   the profile. A game that pays out at the end does it in its `results` handler through the normal
   persistent services (Currency, Inventory), so payouts get the data layer's guarantees.
4. **Run containers reuse the inventory rules.** `RoundContainerUtils` adds stacks with
   `InventoryPlacementUtils` and checks every result with `InventoryContainerRules.checkEntryShapes`
   under a flat capacity, so a run bag holds exactly the same entry shapes (and registered items) as
   the saved inventory. Unique items get run-local uids (`r<round>-<n>`).
5. **Everyone sees the round.** The snapshot (phase, round number, phase end time in server time,
   outcome, participants, eliminated, team counters, targets, scores, containers) is published as the
   `round` entry of a new StateSync **world store** — named entries every client syncs — so it rides the
   charm-sync spine like all other state. Clients count down with `workspace:GetServerTimeNow()`.
6. **Hooks are signals.** `phaseChanged(state)` after every transition, plus `runStarted(participants)` and
   `runEnded(outcome)` for the common cases. Participants who leave mid-run are removed; late joiners
   join only when `lateJoin` is set (otherwise they watch).

Not now: teams inside a run (a game adds a public `team` field), voting, map loading (game code, run from
the `starting` handler), multiple concurrent matches per server.

## New modules

| Feature | Realm | Subfolder | Name | Job (one line) |
|---|---|---|---|---|
| Round | shared | Data | RoundTypes | Types only: Phase, RoundConfig, RoundState, RoundSnapshot |
| Round | shared | Data | RoundConstants | Phase names, default config, outcomes, the world entry name |
| Round | shared | Utils | RoundSnapshotUtils | Decodes the replicated snapshot (an untyped wire value) into a RoundSnapshot |
| Round | server | Rules | RoundPhaseRules | Pure phase machine: tick, startCountdown, startNow, finish |
| Round | server | Utils | RoundContainerUtils | Pure run-container ops over the inventory container rules |
| Round | server | State | RoundRunTracker | The run's participants, counters, targets, scores and containers |
| Round | server | root | RoundServiceServer | Clock, players, hooks, publishing the snapshot |
| Round | client | root | RoundServiceClient | The typed snapshot as a Charm atom, time left |
| StateSync | server | State | StateSyncWorldStore | Named world entries that every client syncs |

Plus admin commands `roundstart` and `roundend <outcome>`.

## API

```lua
RoundService:configure({ autoStart = true, minPlayers = 2, countdown = 10, duration = 6 * 60, resultsDuration = 10 })
RoundService.runStarted:Connect(function(participants) spawnMonsters() end)
RoundService:addTeam("scrap", 45)
RoundService:setTarget("scrap", 300)
if RoundService:teamValue("scrap") >= 300 then RoundService:endRound("quota") end
RoundService:eliminate(player)                 -- dead in a horror game; a full wipe ends the run
RoundService:addToContainer("team", "flare", 2) -- a shared run stash
```
