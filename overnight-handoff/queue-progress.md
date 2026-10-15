# SDD ledger — plan: docs/superpowers/plans/2026-10-10-queue-base.md

Worktree E:\Projects\peekabu-game-systems\.claude\worktrees\queue-base, branch base/queue from base/game-hooks 8b0b399; plan commit 9e29b9a. PR → base/game-hooks (never merge). Plan by an opus planner subagent (pre-authorised, NOT reviewed by the developer).
Studio testing: this worktree is not Rojo-synced; Queue specs + Studio checklist run in Place1 AFTER a local merge of base/queue into game/cleanup-crew (handoff: "merge base/queue into game/cleanup-crew locally for M4").

## Pre-flight scan (opus): 25 pair rows, 7 task rows, 24 dependency rows; 12 blocking, 9 non-blocking; scanner measured the corrected plan gate-green and ran 8/9 Queue specs in lune (81 passed).
- Ruling: B1-B12 accepted with the scanner's drop-in files (incl. new Queue/Systems/QueueLandingSystem to fit the 400 cap) — cost if wrong: a fix round.
- Ruling: Queue runs in a separate worktree in parallel with M2 (code + review only); its Studio TestEZ/checklist run after the local merge before M4 — cost if wrong: Queue bugs surface later (before M4, not during).
- Ruling: N1-N4, N8, N9 accepted; N5 recorded for the M4 walkthrough; N6 accepted; N7 no change.

## Tasks
- [x] Task 0: complete (branch + plan commit by controller; baseline gate green)
- [x] Task 1: complete (commits 9e29b9a..04fc8a2, review clean; TestEZ pending until the local merge)
- Task 1: minor (deferred): register accepts math.huge PlaceId; game-flavoured comments ("depot"/"shift"/"contract id"/"result card") in QueueRegistry/QueueTypes → neutral wording; spec gaps (forceLive + registered place)
- Task 1 → Task 4 carry: a placeholder destination routes local even in live mode, so the destination world may not be built — landing must handle a nil ArrivalPoint (never strand the party).
- [x] Task 2: complete (commits 04fc8a2..cc82339, review clean; TestEZ pending until the local merge)
- Task 2: minor (deferred): decoder accepts NaN/fractional capacity & member ids, dictionary as list; remove() returns the internal members table; spec gaps (join after departNow, duplicate ids)
- Task 2 → Task 4 carry: endsAt must use a replicable clock (workspace:GetServerTimeNow()); departNow must be followed by due/lock/teleport in the same step (a later sync admitting a newcomer resets the countdown); sort `aboard` by UserId before sync (deterministic seats); the game's pad sets QueueCapacity=4 (base MAX_CAPACITY is 50).
- Incident (Task 3): implementer made an intermediate spec-only commit with --no-verify, then soft-reset it; only the normal commit 8c2e9a1 remains. Rule added: never --no-verify.
- [x] Task 3: complete (commits cc82339..8c2e9a1, review clean; TestEZ pending until the local merge)
- Task 3: minor (deferred): role/from length uncapped in decode; boundary specs at exact caps missing
- [x] Task 4: complete (commits 8c2e9a1..cd076d6, review clean (opus); TestEZ + Studio checklist pending until the local merge). Accepted signature changes: send/move return boolean, firstMisroute, QueuePadSystem.new(onDue) publishes itself; all-or-nothing local move.
- Task 4: minor (deferred, triage-worthy): ReserveServer can reserve twice on watchdog retry (keep the first code); returnParty ignores send's result; ArrivalPoint type says CFrame? but nil now fails the party; resolvers must not yield (doc); misrouted pad fires departing/departFailed every countdown; dead QueuePadSystem:snapshot(); game names in QueueRegistry/QueueTypes comments + Task 3 spec payload keys; plan Produces lines stale
- Task 4 → M4 walkthrough note: check whether a TeleportAsync error also fires TeleportInitFailed (double-count → fewer real retries); N5 watchdog overlap.
- [x] Task 5: complete (commits cd076d6..6f30507, review clean; TestEZ/UI Labs pending until the local merge)
- Task 5: minor (deferred): tick loop runs while the widget is disabled (ticking ignores `enabled`); stale first-frame countdown; countdown math inline (plan-mandated); panel prop doc imprecise
- [x] Task 6: complete (commit cbd04ee, docs + neutral comments + plan Produces lines updated; controller-checked). N8 had no file (no QueueVerify script in the brief); the Studio checklist is the controller's after the local merge.

## Final whole-branch review (opus) — With fixes
I1 party split across two reserved servers on a slow ReserveServer + watchdog retry (FIX); I2 watchdog may cut a slow legit teleport (ignore IsTeleporting + 30 s). Minors M1-M10; triage: T4 reserve-twice + ArrivalPoint/resolver docs FIX BEFORE MERGE; spec keys, departing timing, widget tick, dead snapshot FIX before base PR (done in the same wave); rest KEEP DEFERRED. All rulings accepted.
- Ruling: fix wave also includes M2, M5, M6, M7, M8, M10 (cheap) — cost if wrong: none.
- Ruling: M4 (placeholder destination vs runsRole) left as is — safe (party stays on its pad); moot for Cleanup Crew once the shift place exists; noted for the developer.
- Final fix wave: commit dfc2fbf (I1, I2, M1, M2, M5-M8, M10); scoped re-review: all addressed, no new breakage. Studio TestEZ pending until the local merge.
- Queue final: minor (deferred): the M8 spec case is also caught by `#party > capacity` (doesn't isolate the new guard); IsTeleporting not logged.
QUEUE CODE COMPLETE (head dfc2fbf). Pending: local merge into game/cleanup-crew + Studio TestEZ + Studio checklist; push + PR → base/game-hooks.
- Local merge: base/game-hooks (Death root fix 4bed14b) → base/queue (e2617cb) → game/cleanup-crew (97938d5); gate green. Studio TestEZ 1660/0 (+90 Queue specs). QueueVerify (Task 4 Step 8, controller): all 22 checks PASS (after waiting for the game's shift to start — the first run's 1c/1d failed only because Cleanup Crew's shift start moved the player off pad A mid-countdown); forced-live: ReserveServer 403 in Studio → 3 retries → back on pad after 9 s.
- PR: https://github.com/Peek-Abu/peekabu-game-systems/pull/4 (base/queue → base/game-hooks). QUEUE COMPLETE.
