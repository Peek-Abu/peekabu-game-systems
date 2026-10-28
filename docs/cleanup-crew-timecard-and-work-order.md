# Cleanup Crew: the weekly Timecard and the daily Work Order

Two retention pieces from the first-launch handoff ("Weekly Timecard (any 5 of 7 days, punched at the hub time
clock) plus a daily Work Order"). This page records the rules both features are built on. The runtime includes validated account slices, atomic rewards, the hub time clock, calendar and daily-order views.

## The weekly Timecard

`Timecard/Utils/TimecardCalendarFormulas` (`ReplicatedStorage/Shared/Features/`) is the whole calendar, pure and
clockless: every function takes the moment it should answer for, so the server and the specs agree.

- **The week is a UTC week.** It starts Monday 00:00 UTC and ends Sunday 23:59:59 UTC. `weekStart` / `weekKey`
  turn any moment into its week (the key is that Monday's date, "2026-10-26").
- **The days are numbered Monday = 1 … Sunday = 7** (`dayOfWeek`).
- **Five of the seven fill the card.** `complete` is five punches.
- **One punch a day.** Punching a day that is already on the card changes nothing and reports `"already"`.
- **A missed day never clears the card.** Punch Monday and Thursday and the card holds two days, not one.
- **The card rolls over by itself.** `roll` brings a card up to a moment's week: the punches start over, and the
  paycheque run survives only from a completed week into the very next week. Skip a week, or come back two weeks
  later, and the run is back to 0.
- **The punch that fills the card advances the run.** `punch` reports what that punch paid:
  - the **3rd punch** pays a key (a Gloom Locker key),
  - the **5th punch**, the one that fills the card, pays the stars,
  - **every fourth consecutive filled week** pays the paycheque (`paycheck = true` on that punch only).
- Punches pay nothing on the 1st, 2nd, 4th, 6th and 7th days; what the key, the stars and the paycheque are worth
  is a constants decision for the service, not a calendar rule.

The card itself is `{ week, punched, weeks }`: the Monday it covers (a Unix timestamp), the days punched (ascending,
unique) and the consecutive completed weeks so far. The profile slice will hold exactly that shape.

The specs pin real timestamps (Monday 26 Oct 2026, 00:00 UTC and its neighbours) rather than reading a clock, so a
change to the boundary shows up as a failing case, not as a bug found in play.

## The daily Work Order

`WorkOrder/Data/WorkOrderRegistry` is the catalog and the rotation.

- **The catalog is data.** One row per order: `id`, `kind`, `target`, `label`. The kinds are the counters a shift
  already reports (`piles`, `cargo`, `salvage`, `shifts`), so every target is something the server can measure.
- **The catalog is checked at load** (`check`): at least one order, non-empty unique ids and labels, a known kind,
  and a positive whole target.
- **One order per UTC day, the same for every server.** `orderFor(now)` is `dayIndex(now) % #WORK_ORDERS`: the whole
  day gets one order, the next day moves on, and a cycle shows every order once before any repeats. `dayIndex` is
  the UTC day counted from the Unix epoch, which is also the key a stored completion is checked against. The same
  boundary as the Timecard's weeks, so nobody has to reason about two "days".
- `get(id)` is the lookup, nil for an unknown id; `all()` is the catalog as a copy.

## Runtime and rewards

The account-wide slices are `timecard = { week, punched, weeks }` and `workOrder = { day, progress, claimed }`.
Their validators run on every data-layer write. Profiles reconcile new slices from the template; no schema reset is required.
The hub has one COMPANY CLIPBOARD shortcut. Its Timecard and Daily Work Order tabs share a620x390 card using the normal global UI scale. Close/reopen remembers the selected tab for the client session. The physical weekly clock opens Timecard; the daily sheet beside the contract board opens Daily Work Order. Tonight's Job remains the existing Jobs/contract flow. Opening an entrance does not punch or grant rewards.
PUNCH TODAY requests a server punch; reliable feedback reports accepted/refused requests, and replicated state confirms the result.

Tunable MVP reward defaults (implementation defaults, subject to future balance review):

| Trigger | Reward |
|---|---|
| Third weekly punch | 1 actual Gloom Locker key (`account.lockers.keys.gloom`) |
| Fifth weekly punch | 5 Gleam (`account.premium.balance`; the design's stars use the existing premium currency) |
| Fourth consecutive filled week | 500 Credits, alongside that week's fifth-punch Gleam |
| Daily Work Order completion | 100 Credits |

TimecardConstants owns weekly values; WorkOrderRegistry.REWARD_CREDITS owns the daily value. No premium currency is invented.
The weekly punch and all milestone payouts commit in one PlayerData transaction. A refused payout rolls the card back.
Repeated requests cannot pay the same punch again. `setPayout(nil)` restores the default payout; custom payout handlers must return transaction operations.

`WorkOrderServiceServer:record(player, kind, amount)` accepts positive finite whole increments from server gameplay only.
There is no client progress/reward packet. Only today's matching kind counts. Progress caps at the catalog target;
reaching it commits progress, `claimed = true` and the Credits reward atomically. Further increments are ignored.
The first real progress after UTC midnight starts today's order at zero. Load reconciles yesterday's state;
clients also roll the display on the server clock so a midnight wait cannot show yesterday's reward as ready.
ShiftWorkOrderSystem feeds individual real pile clears, banked cargo/overtime salvage, and completed shifts; no client claim authorizes progress.

## Verification

Sibling specs cover UTC week/day boundaries, five-of-seven behavior, skipped weeks, duplicate punches,
actual milestone balances, transaction rollback, daily target cap/once-only payment, unrelated counters and invalid amounts.
TestEZ requires a dedicated Studio test session; gameplay verification uses a fresh normal session afterwards.
Studio mock profiles prove session transactions only. Persistence requires a published authorized profile environment;
API/security settings are not changed for these checks. Parent report records actual runtime evidence and the physical clock integration.

Hub authorization is injected by the game through TimecardServiceServer:setCanPunch(predicate). Nil fails closed; both the hub UI request and physical prompt use the same server punch method. Stopping the service clears the predicate.

The physical WeeklyTimeClock is built beside the contract board (local x = contractBoard.x - 10); DailyWorkOrderSheet sits between them (x - 5.3). Both use the standard distance/aim-validated Interaction prompt. The weekly clock sends the cosmetic clipboard-open event for Timecard; the daily sheet selects Daily Work Order. PUNCH TODAY still uses TimecardServiceServer:punch and the existing native hub authorization. Depot accepts a phase-reader callback from Timecard during init and never requires Timecard or Shift, keeping the dependency graph acyclic.

Daily progress notices appear on first progress, halfway and completion. Rewards commit before notices; completion adds a PAID stamp and100Credit notification.

**Retention moments (client only; the server already decided everything):**
- **Daily greeting.** In the hub, the clipboard opens on the Timecard by itself once a UTC day while today is still free, on the real (synced) card, after the hub has stayed free of other screens (pick, reveal, travel card, scenes) for 1.5 s (`TimecardMomentSystem`, rule in `TimecardMomentUtils.shouldGreet`).
- **Punch stamp.** A punch this client asked for slams an "IN!" stamp on today's tile with a banner of what it paid or how far the next reward is ("DAY 3! +1 GLOOM KEY", "DAY 1! 2 MORE FOR A GLOOM KEY"), with the punch clock, the rubber stamp and, on a reward, the contract-met fanfare (`DepotTimecardStamp`). A card arriving from the first sync never stamps.
- **Today tracker.** Pinned by default (× unpins for the session): in the hub under COMPANY CLIPBOARD (gold with "PUNCH YOUR TIMECARD!" until today is punched; a tap opens the clipboard) and in running shifts for active crew (hidden during clock-out/scares/catches and on phone while crew details are expanded). Once today's order is paid it reads "ALL DONE TODAY!" and counts down to tomorrow's order (`CompanyTrackerViewModel`).

Starting2026-10-28 00:00UTC (day20754), the basic daily catalog uses8piles,4cargo,1shift or12piles. These are tunable first pacing values against roughly19piles/site (ShiftConstants measured data), not a claim that every crew/playstyle completes them in one shift. Overtime salvage is excluded from the required basic pool and remains a possible future optional stretch objective. Historical days retain their frozen catalog/targets so existing progress and claims remain valid; today's order is never reinterpreted during rollout.
