# SDD ledger — plan: docs/superpowers/plans/2026-10-10-m4-cleanup-crew-depot.md

Spec: cleanup-crew-design.md (M4 row). Branch game/cleanup-crew (M1+M2 complete, Queue + Death root fix merged at 97938d5); plan commit (this). Same PR #3. Plan by an opus planner subagent (pre-authorised, NOT reviewed by the developer). Real PlaceIds stay placeholders (developer creates the shift place); everything plays through the Studio local fallback.

## Pre-flight scan (opus): 21 pair rows, 7 task rows, 34 dependency rows; 7 blocking, 12 non-blocking; scanner built a scratch merge with Queue and measured the corrected plan gate-green; 5 pure specs pass in lune (52/52).
- Ruling: B1-B7 accepted with the scanner's corrected files (incl. RETURN_WAIT_SECONDS 40 → 130 because Queue's real return can take up to 127 s; Studio scripts set a temporary arrival point until Task 5) — cost if wrong: a fix round.
- Ruling: N1-N12 accepted / recorded per the scan.
- Ruling: the plan's 7 open questions taken at the planner's defaults (live depot place also builds the empty office; drive card not on the loading screen; failed return → next shift after the wait; contracts = 3 flavour texts by day, quota 350; result card = world billboard for the returning player; Studio 2-client HUD quirk; 3 trucks, validator accepts 4) — reversible.

## Tasks
- [x] Task 0: complete (controller; greps pass on the merged tree per scan; gate green at 97938d5)
- [x] Task 1: complete (commits 2e9612a..90b2955, review clean; Studio TestEZ 1684/0, +24)
- Task 1: minor (deferred): PlaceId test in the layout spec; "always finds a contract" spec weak; NaN coords unchecked; spawns not checked against boards
- [x] Task 2: complete (commits 90b2955..d5b5a20, review clean; Studio TestEZ 1706/0, +22)
- Task 2: minor (deferred): no worst-case (multibyte, 4 crew + 3 awards) fit spec; encode passes unsanitized numbers (Queue would drop the card); second party mid-leaving keeps the old window (untested)
- Task 3: Studio TestEZ 1706/0. DepotVerify (scanner's corrected script, controller): all 18 PASS — depot built at (-952,6.5,36), 3 truck pads (cap 4 → shift), contract chosen + board, aboard + truck label "1/4 aboard", Depart now → departed + arrived with tonight's contract + 2 travel cards, forged card pins nothing, return moves to depot, real card pinned with the review, survives respawn.
- [x] Task 3: complete (commits d5b5a20..0b10877, review clean)
- Task 3: minor (deferred): contract chosen once at server start (midnight rollover); live arrival card may race the client listener (Task 4 lens); drive card fires on route success, not teleport success (inherent)
- [x] Task 4: complete (commits 0b10877..4844db0, review clean; Studio TestEZ 1712/0, +6). Live (CardDepart, controller): departing from truck 1 → client shows the ARRIVAL card titled "Harlow & Finch Ltd.".
- Task 4: Ruling: the live arrival-card race (card sent before the reserved server's client listens) is deferred to the M4 final fix wave as MUST-FIX before any live two-place test (needs a Depot server ready/re-send — Task 3 modules; make it idempotent) — cost if wrong: players miss the arrival card live.
- Task 5: Studio TestEZ 1712/0. TripVerify (brief Step 7, controller): all 18 PASS, "TripVerify done 1 1" — no shift without a crew; spawn + respawn at the depot; truck 1 → loading bay, crew 1, shift runs with the player as Round participant; crew respawns in the bay; clock out → results → vote depot → back at the depot with the result card pinned, crew 0, no shift restarts, no Round participant; depart again → running → vote another → same crew stays in the office.
- [x] Task 5: complete (commits 4844db0..1bd33f2, review clean (opus); ShiftServiceServer 396, identical to the measured reference)
- Task 5: minor (deferred, triage-worthy for live): a stranded player on a public shift server never leaves if the sweep teleport gives up (retry or kick); failed live return shows Queue's "Try again" then STUCK toast (misleading); stale header line (respawn in the bay); late expected member during leaving gets the STUCK toast
- [x] Task 6: complete (commit 1681d74, docs + docs/cleanup-crew-publish.md walkthrough incl. live-only checks; controller-checked summary)

## Final whole-branch review (opus) — With fixes
Important: (1) live arrival-card race (Ready handshake + held cards); (2) stranded player on a public shift server (kick after the window); (3) walkthrough inaccuracies; (4) ShiftServiceServer 396/400 — plan an extraction as M3's first step. Minor: stale header, non-crew vote acknowledged, joinedLate arrival card, sendHome with nil results, stop cleanup.
Triage: T3 race + T5 stranded promoted to Important (fix); T5 stale header fix; T2 worst-case fit CLOSED; rest accepted/kept.
- Ruling: fix wave = Important 1-3 + Minors 1-3 (stale header, vote guard, joinedLate card) — cost if wrong: none.
- Ruling: Important 4 (ShiftServiceServer extraction, e.g. ShiftVoteSystem) becomes the first task/amendment of M3 — cost if wrong: M3 starts with a small refactor.
- Final fix wave: commit f65f1e4 (card handshake Ready + held cards + joinedLate card; stranded-player kick; walkthrough corrections; header; vote guard); re-review: all addressed. Studio TestEZ 1712/0; live depart → 2 cards sent.
- M4 final: minor (deferred): a Ready packet dropped before the server listens has no fallback (boot ordering makes it unlikely); joinedLate card uses the last arrived crew's contract.
M4 COMPLETE. Head f65f1e4.
