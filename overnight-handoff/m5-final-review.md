# M5 final whole-branch review: Cleanup Crew analytics + A/B variant switch

Range: `3793d02..ad69d17` (11 commits, branch `game/cleanup-crew`, HEAD `ad69d17`). Reviewer: read-only, final
whole-branch pass. Evidence from the controller is taken as given: the gate was green at every commit, Studio TestEZ
passed 1865/0, and the live sink runs are listed in the brief. I re-measured the line caps with
`scripts/python/check_file_length.py`'s own counter.

## Strengths

- **One door for analytics.** Every event goes through `ShiftAnalyticsSystem.emit`, which checks the name against the
  13 spec §6.6 events and passes every string through `ShiftAnalyticsUtils.token`: only vocabulary words or `:`-joined
  pairs get through, and anything else becomes `other`. No new log line or field carries a name, UserId or chat
  (grep of the diff: UserId appears only as a map key or lookup, never in a string). The base `AnalyticsRules.customFields`
  also truncates each field to 50 characters, which settles the Task 1 81-character worry.
- **No feature carries analytics code.** The watch only subscribes to signals the features already had. The one
  feature edit is Vacuum's `vacuumStarted` (+17 code lines in a 203-line file). Cargo got one existing line edited
  (`source = "desk"`), so `CargoServiceServer` is still at exactly **400**. `ShiftServiceServer` is at **382**,
  `OccupantServiceServer` at 398 (untouched), the watch at 314 and `ShiftAnalyticsSystem` at 238. All are within the
  cap and match the ledger.
- **The Task 7 deferred bug is fixed at its root.** The crew now comes from `ShiftTripSystem:crew()`, not from Round's
  participants, which Round has cleared by the time its deferred `runEnded` runs. The fix is documented in three places
  (system header, watch header, checklist).
- **The banking guard is correct.** The analytics call sits in its own `guarded` step, *after* the counters moved and
  *before* `afterBank`. A throw in analytics cannot un-bank a deposit and cannot skip the quota stamp or publish
  (`ShiftBankingSystem.luau:85-91`). The call is synchronous, so `quotaTag()` reads the state before this Load, which is
  what was intended.
- **Every attempt closes exactly once in the tracker.** Every close goes through `take()`, which removes the attempt
  (`ShiftSalvageTracker.luau:60-66`). Bank (synchronous) and drop/throw/death/removed (deferred) race safely: whichever
  runs first removes the attempt, and the other finds nothing. Pocket/bank resets (`forced`/`destroyed`) are not
  closes. Leave, catch and run end close everything left by player or in full.
- **The variant is server-only and recorded correctly.** `pickVariant` runs synchronously in `onRoundPhase` before
  `setState`, so every deferred event of the run (contract_started onward) reads the right `variant`. Only
  `OfficeSpawnUtils` gates on it. The hide roll is now drawn in both arms, and the spec pins this over 30 seeds
  (same salvage multiset, same pile count, same greed kind).
- **Platform input is server-authoritative.** It goes through `RequestHandler.wrap` with a rate limit and a parse
  that accepts only 1..4, and the first valid report wins. A spoof was refused live.
- **The docs are honest about known limits.** The checklist documents N4, N5, the `left` gap, respawn, Studio reset,
  N6, and the open question N7, with a clear method for the §1 question.

## Issues

### Critical

None.

### Important

**I1. A leaving player's `optional_salvage_attempted … failed:left` may never be sent, but the checklist says it is.
Not verified live.**
- **Where:** `ShiftAnalyticsSystem.luau:285-288`, `:205`, `:129`; `docs/cleanup-crew-m5-checklist.md:59-61`.
- **The problem:** the close path for a leaver needs two things at handler time: `closeAttempts` needs
  `Players:GetPlayerByUserId(attempt.userId)` to return the player (`:205`), and `emit` needs `scope.Parent ~= nil`
  (`:129`).
  - Task 8 already observed that the deferred Carry `removed` record has no recipient because the player is gone.
  - The `PlayerRemoving` connection is an engine signal. If the place runs `Workspace.SignalBehavior = Deferred` (the
    current default), its handler may also run after the Player is unparented. I have not verified this either way.
  - If it does, the tracker still closes the attempt exactly once, but nothing is emitted. Checklist lines 60-61 would
    then be false ("The attempt still closes, once, as `left` (`optional_salvage_attempted`)").
  - This is the same class of hazard as the Task 7 bug, on a path nobody exercised.
- **Fix (either one is enough before trusting leave numbers):**
  - (a) Verify it in a two-client Studio local server: pick up salvage after the quota and leave with one client.
    Record the result in the ledger.
  - (b) Harden the code: in the `PlayerRemoving` handler, pass the `player` argument straight through, for example
    `closeAttempts(attempts, player)`, so the handler uses that Player instead of `GetPlayerByUserId`. Then add a
    leaving-allowed path in `emit` for this one caller, or call `send` directly. If live testing then shows the engine
    rejects events for a removed Player, reword the checklist line to say leave closes are not reported.

### Minor

**M1. The shared module-level `harlow` can be reset by an old model's late cleanup.**
- **Where:** `ShiftAnalyticsWatchSystem.luau:60`, `:293`, `:314`.
- **Why it matters:** if a new Harlow is tagged before the old one's Observers cleanup runs, the old cleanup sets
  `harlow = nil`. The next read while he is chasing compares against nil, which can produce a repeat `chase_started`.
  This is the Task 9 deferred minor.
- **Fix:** make the last-seen state local to each `watchHarlow` closure (`local last: Harlow? = nil`) and pass it into
  `readHarlow`. That drops the global and the reset in stop(). About 3 lines.

**M2. The re-key in `ShiftSalvageTracker.open` merges two different items of the same kind.**
- **Where:** `ShiftSalvageTracker.luau:74-77`.
- **Why it matters:** a player pockets salvage K (attempt open on item 10), then picks up a second K in the office.
  The attempt is re-keyed to item 11 and the open count stays at 1. Dropping item 11 then closes the attempt as
  `failed:dropped`, while item 10 is still pocketed, and banking item 10 later closes nothing. The result is a slight
  undercount and a wrong outcome, and only when one player holds two salvage of the same kind.
- **Fix:** document it next to N4 in the checklist (cheapest). The real fix (carrying the source and id through the
  pockets) needs the CargoServiceServer extraction already deferred under N4.

**M3. A yielding `listen` callback would yield inside Cargo's "claim → add → destroy in one synchronous step".**
- **Where:** `ShiftAnalyticsSystem.luau:107-114`, reached from `ShiftBankingSystem.luau:86-88` and
  `CargoServiceServer.load`.
- **Why it matters:** `pcall`/`xpcall` allow yields in Luau. A sink that waits would hold the Load open between the
  handler and `pocketSystem:take`, which breaks the spec §6.4 rule that two Loads can't double-count. Only the Studio
  test sink listens today.
- **Fix:** run listeners with `task.spawn(listener, record)` (errors surface on their own thread), or state in the
  `listen` doc comment "must not yield".

**M4. Same-seed fairness only holds while item markers last.**
- **Where:** `OfficeSpawnUtils.luau:187-189` (and the trash loop at `:201-203`).
- **Why it matters:** in A every salvage needs an item marker. If the pool runs out, the salvage loop `break`s, while
  B would have hidden the same item under a pile and carried on. B can then roll more salvage (and A less trash).
  The 30-seed spec passes on the current layout, so this is latent.
- **Fix:** add one assertion to the A/B spec case that the trash multiset matches too, or a comment that the guarantee
  assumes enough item markers. A guard is optional.

**M5. An invalid platform packet logs the sender's UserId.**
- **Where:** `ShiftAnalyticsSystem.luau:254-269`; `RequestHandler.luau:205-207`; checklist line 19.
- **Why it matters:** with the default `onReject = "warn"`, RequestHandler logs
  `Validation failed: ShiftPlatform userId: <id>`. That contradicts the checklist's "no … UserIds … in any … log
  line", and it lets an exploiter spam the server log.
- **Fix:** add `onReject = "count"` to the wrap (one line). The drops are still counted for the Debugger.

**M6. After a Studio mid-run reset, `shift_ended` reads the lobby copy, so its reason is always `quota_missed`.**
- **Where:** `ShiftAnalyticsWatchSystem.luau:137-138`; the watch header `:9-13`.
- **Why it matters:** `resetShift` → `finishReset` → `setState(toLobby)` (which sets `quotaMet = false`) all runs
  before the deferred `runEnded` is handled. The reason reads `quota_missed` even when the quota was met. This is
  Studio-only. The header's "the quota comes from the last running copy" is inaccurate: it is the last `changed` copy
  (results on a normal end, lobby on a reset). There is also a stray " : " on line 10.
- **Fix:** reword the header, and add "reason always `quota_missed`" to checklist line 63. No code change needed.

**M7. Carry-over from M3, still open: `CargoEvents.packets.Banked.sendToAll(...)` is unguarded.**
- **Where:** `CargoServiceServer.luau:429`.
- **Why it matters:** if it throws after the deposit is banked and destroyed, `load` errors out and
  `counters.banked` is skipped. The deposit is never un-banked, so the impact is cosmetic or diagnostic. M5 could not
  fix it: Cargo is at exactly 400 and a guard needs lines, so the extraction is still owed.
- **Fix:** after M5, extract Load's post-accept follow-up (take, forceDrop/destroy, Banked send, counter) into a Cargo
  system and wrap the send in a guard. The same extraction unblocks N4.

**M8. Small doc and comment nits.**
- The checklist (line 59) says `cargo_dropped … left` is "effectively never sent". It *is* sent on a non-death
  respawn (line 62), so qualify it as "for a leaving player".
- `ShiftVariantRules.luau:8`: "B in Studio" would read better as "the fixed variant (B) in Studio".

## Deferred-minor triage

| # | Deferred minor (ledger) | Verdict | Why |
|---|---|---|---|
| T1a | `outcomeField` can reach 81 chars vs the engine's 50 | Keep | The base `AnalyticsRules.customFields` truncates to 50. The real worst case is ~22 chars ("abandoned:quota_missed"). |
| T1b | `record.reason` "none" vs field omission | Keep | Deliberate: the log and ring always have a reason column, and the engine field 3 adds `:reason` only on failure. |
| T2a | Long header line in ShiftServiceClient | Keep | Comment only. The gate is green. |
| T2b | `reportPlatform` delay not cancelled on stop | Keep | Client-side. A late send after stop is harmless (rate-limited, first report wins). |
| T3a | Tracker `limit ≤ 0` unguarded | Keep | Both limits are positive constants (300, 16). |
| T3b | Platforms rely on `forget()` at PlayerRemoving | Resolved | Task 7 calls `tracker:forget` in the PlayerRemoving handler (`ShiftAnalyticsSystem.luau:287`). |
| T4a | `open()` can re-key onto an item id another open attempt holds | Keep | Practically unreachable: every hand-leaving reason except pocketing closes by id, and ids are monotonic. The related same-kind merge is M2 (document it). |
| T4b | Counts kept per shift until `clear()` | Keep | `beginShift` calls `salvage:clear()` on each run start. |
| T5a | Long header line in OfficeSpawnUtils | Keep | Comment only. |
| T5b | ShiftVariantRules header "B in Studio" vs `input.fixed` | Keep (optional reword, M8) | Behaviour matches: fixed = B. |
| T7a | Watch header stray " : " and "last running copy" wording | Fix (doc-only, M6) | The wording is wrong in the reset case. A two-line comment fix. |
| T7b | Studio `resetShift` sends `shift_ended cancelled` | Keep (documented) | Studio-only and in the checklist. Add the `quota_missed` note (M6). |
| T7c | `ShiftAnalyticsSystem.stop()` partial reset | Keep | Services are not restarted in play. Listeners, ring and variant surviving a stop doesn't matter in a test session. |
| T8a | `cargo_dropped left` never sent for leavers | Keep (documented), but see I1 | The same mechanism may also drop `optional_salvage_attempted left`. Verify or harden (I1). |
| T8b | A non-death respawn closes attempts as `left` | Keep | Plan-mandated and documented. |
| T8c | Vacuum header 123 cols, bullet punctuation | Keep | Comment only. |
| T8d | `vacuuming` holds destroyed piles until reset/leave | Keep | Bounded by players, cleared on `reset()` each shift. Negligible. |
| T9a | Shared `harlow` reset by an old model's late cleanup (repeat chase_started) | Fix (M1) | A 3-line closure-local fix. It removes a duplicate-event source in an event the sibling-session story reads. |
| T9b | Pending `task.defer` not cancelled on stop | Keep | After stop, `running()` is false (`shiftState` nil), so a late read emits nothing. |
| T9c | `held()` read one defer late | Keep | One frame. Harmless for "what were they holding when the chase began". |

None of the deferred minors blocks the merge. T7a and T9a are cheap and worth folding into a fix wave with I1.

## Cross-task checks (summary)

- **Deferred-signal hazards.** Every watch input is a SignalPlus `task.defer` fire, and none of the handlers depends
  on Round state that cleanup clears, except the Task 7 case, which is fixed.
  - Handlers that need the object read attributes, which survive `Destroy`.
  - Handlers that need the phase read the last `changed` copy.
  - The deferred reads that remain are I1 (leave), M6 (Studio reset) and the stale `quotaTag` for a second Load in
    the same frame as the quota-meeting Load (negligible).
- **Exactly-once.** Holds in the tracker on every path: bank, drop, throw, catch (died or death-drop, whichever comes
  first), pocket/unpocket (re-key or stale id, closed by kind on bank), leave, and run end via `resolveAll`. The one
  open question is whether the leave event is emitted (I1).
- **Personal data.** No names, ids or chat in fields or in the new log lines. The one exception is the base
  RequestHandler's warn on an invalid platform packet (M5).
- **Variant.** Fair per seed (except M4's marker exhaustion). It is recorded on every event, and
  contract_started's target says how it was chosen. The override applies from the next run only.
- **Cleanup on stop and between shifts.** The watch's stopper disconnects all 9 subscriptions and the Observers tag,
  then stops ShiftAnalyticsSystem. Each run start calls `beginShift`, which clears the per-shift tracker and the
  attempts.
- **Caps.** Cargo 400 / Shift 382 / Occupant 398, as ruled.
- **M3 deferral.** The `Banked.sendToAll` guard is still open (M7).

## Assessment

**With fixes.** No Critical issues. Fold one small wave in before the PR merge:
- I1: verify the leave path live, or pass the leaving Player through and fix the checklist line.
- Optionally M1 (Harlow state local to each model), M5 (`onReject = "count"`) and the M6/M8 doc lines. Each is a
  few lines with no cap impact.

If the developer accepts I1 as a documented, unverified limit (one checklist line: "leave closes may not be reported"),
the branch is ready to merge as is.
