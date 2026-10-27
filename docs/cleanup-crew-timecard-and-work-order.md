# Cleanup Crew: the weekly Timecard and the daily Work Order

Two retention pieces from the first-launch handoff ("Weekly Timecard (any 5 of 7 days, punched at the hub time
clock) plus a daily Work Order"). This page records the rules both features are built on. Only the pure layer
exists so far; the service, the profile slice, the hub time clock and the HUD come next, and they must not need
to change a rule here.

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

## Not built yet

- The profile slices (the Timecard card, the Work Order day + progress), their validators and the server services
  that punch, count and pay.
- The hub time clock (the punch prompt), the paycheque, and the key/stars grants.
- The HUD: this week's card, today's order and its progress.
- Analytics for punches, filled cards, paycheques and order completions (every launch experiment needs its event).
