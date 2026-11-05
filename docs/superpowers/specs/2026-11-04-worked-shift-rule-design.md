# Worked-shift rule: closing the clock-out XP exploit (design, 2026-11-04)

Backlog: `docs/superpowers/launch-backlog.md`, "Clock out at once still pays XP".

## The bug

`RankFormulas.factsFor` sets `worked = true` for anyone on the shift's roster. The roster lists everyone on the crew
at the end, even with nothing done. So a solo player who punches the time clock as soon as the shift starts ends the
run at once (ShiftClockOutRules: everyone still in punched = the truck leaves now) and is paid:

| Line | XP |
|---|---|
| Shift | 10 |
| Clocked out | 5 |
| Whole crew out | 5 |
| **Total** (x2 with a friend) | **20** (40) |

The "Another shift" vote and the 5 s arrival loop that back to a new shift in well under a minute. An honest solo
shift is about 45 XP for about 9.5 minutes. Farming pays 4 to 8 times faster.

## Every quick-leave path, and what rides the same "worked" fact

| Path or reward | Pays for an empty shift today? | Why |
|---|---|---|
| **Instant clock-out** (solo, or every crew member punches) | **Yes**: 20 XP | `worked = true`, and the outcome is a clock-out |
| **Half the crew punches** (the 30 s truck countdown) | **Yes**: same | Same path, 30 s later |
| **Leaving the server** | No | The leaver stays on the roster, but the rank award needs a loaded profile, badges need a `Player`, and work orders and pay read only the crew still present |
| **Results vote "Another shift"** | Not a payout of its own | It only speeds up the loop above |
| **Rank XP** (`RankShiftSystem`) | **Yes** | `factsFor` |
| **Clocked In badge** (`BadgeMilestoneSystem`) | **Yes** (once per account) | `BadgeMilestoneRules.shiftKeys(facts.worked)` |
| **Work orders "Work 1 shift" / "Work 2 shifts"** (`ShiftWorkOrderSystem`) | **Yes** | Records `shifts` +1 for everyone present at the results |
| **Referral Gleam** (`SocialServiceServer.payReferrals`) | **Yes** (once per invited player, 5 per inviter) | Pays everyone on the roster at the first results |
| **Credits / saved Gloom** (`ShiftPaySystem`) | **No** (about 0) | Pay is the Gloom the crew cleared plus banked valuables. An empty shift clears nothing |
| **Daily reward and streak** | Not linked | Claimed in the depot, never from a shift |
| **Weekly timecard** | Not linked | Punched in the depot, never from a shift |

## Proposed rule

A crew member **worked** the shift when both of these hold:

1. **They did something.** They cleared at least 1 Gloom pile, or banked at least 1 cargo item.
2. **The shift ran long enough, or the contract was made.** The shift ran at least **3 minutes**
   (`MIN_WORKED_SECONDS = 180`, about a third of the 8.5-minute shift), **or** the crew met the quota.

A shift that is not worked pays **no rank XP lines at all**. That includes Shift, Clocked out and Whole crew out,
because those already sit under `worked` in `RankFormulas.award`. The same fact gates:

- the **Clocked In** badge (it already reads `facts.worked`);
- the **"Work N shifts"** work-order progress (this is new: the system will ask the same rule);
- the **referral Gleam** (this is new: it pays at the first *worked* shift, not at the first results screen).

**Credits stay as they are.** They are already earned by cleaning, so an empty shift pays about 0. A crew member who
stood still while the others cleaned still gets the team's pay. That is the co-op design, and out of scope here.

### Why these numbers

- **Fair for solo players.** One pile is the smallest real action in the game. A solo player who cleans for 3
  minutes and then clocks out still gets Shift 10 + Clocked out 5 + Whole crew out 5, plus any cargo. A crew that
  makes the contract early (even before 3 minutes) is always paid.
- **Farming is no longer worth it.** The fastest farm is now: clear one pile, wait out 3 minutes, then clock out.
  That is about 20 XP for 3.7 minutes, or about 5.4 XP a minute. An honest solo shift pays about 4.7 XP a minute,
  and a crew shift with cargo pays more. Farming now pays about the same as playing, and it means playing anyway.
- **Considered and dropped:**
  - Time only, with no action. An idle player could still farm. They would just wait.
  - Action only, with no time. One pile, then clocking out at once, still farms about 20 XP a minute.
  - 2 minutes instead of 3. About 7 XP a minute: still better than honest play. Easy to change, since it is one
    constant.

### How time is measured (server-authoritative)

The shift's state already holds `startedAt` while running. The results state will carry `ranFor`, the seconds from
the start to the end of the run. `ShiftPhaseRules.follow` sets it when Round reaches results. Every reader uses that
one number: the rank award, badges, work orders, referrals, and the results card's XP line on the client. Clients
never send it.

A late joiner (a queued crew member who loaded after the start) is measured from the shift's start, not their own
arrival. They still have to clear a pile or bank an item. They are an expected member of a reserved server, so this
is not a way to farm.

## What changes in code (for the build step after the OK)

- `ShiftTypes.ShiftState.ranFor: number?`, set in `ShiftPhaseRules.follow` on running → results.
- `RankTypes.CrewEntry` gains `piles` (and reads `banked`). `RankFormulas.entriesOf` and both roster readers fill
  them.
- `RankFormulas.worked(entry, quotaMet, ranFor)`: the rule above, pure. `factsFor` takes `ranFor` and sets
  `worked` from it.
- `RankConstants.MIN_WORKED_SECONDS = 180`.
- `ShiftWorkOrderSystem` records `shifts` only for crew members who worked. `SocialServiceServer.payReferrals` is
  handed only the crew who worked.
- The results card (`RankViewModel`) reads `ranFor` from the shift state, so it shows "+0 XP" for an empty shift
  and matches the server.
- Specs first: `RankFormulas.spec` (each branch of the rule, plus the instant clock-out case), `ShiftPhaseRules.spec`
  (`ranFor`), `RankShiftSystem.spec`, `ShiftWorkOrderSystem.spec`, and `BadgeMilestoneRules.spec` if anything
  changes there.

## Decision needed from the owner

1. The rule: **at least 1 pile or 1 banked item, AND (at least 3 minutes OR the contract was made).** Yes or no?
2. The time: **3 minutes**? (2 minutes is the fallback. It is easier on short shifts but still farmable.)
3. Gate the **"Work N shifts" work orders** and the **referral Gleam** with the same rule? Yes or no?
