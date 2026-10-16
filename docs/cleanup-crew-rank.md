# Cleanup Crew: company rank ("Clearance Level")

The MVP's career goal: a company rank earned by working shifts. Cosmetic only, never power: a level changes how a
player is labelled, not what they can do. Rank only goes up (XP is never taken away).

## The ladder (MVP: levels 1-3)

| Level | Rank | XP to reach | Lanyard |
|---|---|---|---|
| 1 | Intern (Unpaid) | 0 | grey |
| 2 | Probationary Associate | 40 | green |
| 3 | Clearance Associate | 120 | blue |

The ladder is data: one row per level in `RankRegistry` (`ReplicatedStorage/Shared/Features/Rank/Data/`). Levels 4
("Senior Clearance Associate", 300) and 5 ("Regional Clearance Lead", 600) are added later as two more rows; nothing
else changes. The registry checks the ladder at load (level n is row n, level 1 needs 0 XP, thresholds strictly rise).
The lanyard colour paints the uniform's lanyard strap and the ID card's band.

## XP per shift

Paid once per player by the server when the shift reaches its review (`RankConstants.XP`):

| Earned for | XP |
|---|---|
| Working the shift (on the crew's review) | +10 |
| The crew met the contract (Gloom removed; was the quota) | +15 |
| Each cargo item you banked yourself | +1 (up to 10) |
| Banking any salvage during overtime | +5 |
| Clocking out uncaught (still with the crew at the end, never caught) | +5 |
| The whole crew clocked out uncaught | +5 each |

A caught player gets neither extraction bonus; the results card types "Incident Report filed" instead. A shift ended by
a reset (`resetShift`) never reaches its review and pays nothing.

## The two reset switches

Both live at the top of `RankConstants` (`ReplicatedStorage/Shared/Features/Rank/Data/RankConstants.luau`) and are
one-line edits:

- **`RANK_SEASON`** (now `"mvp-1"`). Every saved rank carries the season it was earned in. When a player joins with a
  different stored season, their rank resets to level 1 / 0 XP. Bump the string (`"mvp-2"`) to wipe everyone's rank on
  their next join: no DataStore edits, no migration.
- **`RANK_PERSIST`** (now `true`). `true` saves the rank in the player's profile (the account-wide `rank` slice).
  `false` keeps it in server memory for the session only (`RankTracker`): nothing is written to the profile, and every
  join starts at level 1.

Studio Play uses ProfileStore's mock store (`ServerHandler`: `useMock = RunService:IsStudio()`), so ranks never survive
a Studio session in either mode; persistence happens only on published servers.

## How it is wired

- **Slice.** `account.rank = { season, xp, lastAwardedRunId }` (`PlayerDataTypes.Rank`), registered by
  `RankServiceServer` with `RankRules.validate`. Existing profiles need no migration: ProfileStore's `Reconcile`
  backfills `account.rank` from the template default (current season, 0 XP) on their next load.
- **Award.** `RankShiftSystem` follows `ShiftServiceServer.changed`; on a shift's first `results` state it pays every
  member of the shift roster (`ShiftReviewSystem.crew`) through `RankServiceServer:awardShift`. Cargo items and
  overtime salvage are counted into the roster from every accepted Load (`ShiftAnalyticsSystem.loaded`); catches come
  from the roster, the quota from the shift state, and "still with the crew" from `ShiftAnalyticsSystem.crew`.
- **Double-award guard.** Each run id is `<server GUID>:<shift number>`; `RankRules.applyAward` refuses the run the
  rank was last paid for (`lastAwardedRunId`), and the system pays each shift number once.
- **Display.** The server publishes each player's XP (and the XP before their latest award) on their public entry
  (`rankXp`, `rankPrevXp`), so the same path works in both storage modes and for other players. The `rank` slice is
  therefore not in `StateSyncSliceRegistry` (like `receipts`, it stays server-side).
  - Results card (`ShiftReviewPanel`, `RankSlip`): "CLEARANCE LEVEL n · RANK", the XP bar in the lanyard colour,
    "n / next XP", "Next: <rank> (<colour> lanyard) at <XP>", this shift's "+N XP" and breakdown, PROMOTED once a
    level-up lands, and the incident line for a caught player.
  - The lanyard's ID card (`EmployeeGearSystem.badge`, server-painted so everyone sees it): the name, the rank, the
    band and strap in the lanyard colour, and the wearer's skin portrait. There is no overhead badge (it was removed
    after playtest: the card replaces it); the engine's own name label shows over each character.

## Testing hooks

`RankServiceServer:_setSeason(season)` and `:_setPersist(bool)` override the two switches on one server (nil restores
the constants); `:reset(userId)` returns one player to level 1. Specs: `RankRules`, `RankFormulas`, `RankRegistry`,
`RankConstants`, `RankTracker`, `RankShiftSystem`, `RankServiceServer`, `RankViewModel`.
