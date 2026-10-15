# SDD ledger — plan: docs/superpowers/plans/2026-10-10-m3-cleanup-crew-feel.md

Spec: docs/superpowers/specs/2026-10-10-cleanup-crew-design.md (§4, §6, §7). Branch game/cleanup-crew @ f65f1e4 (M1+M2+M4). Same PR #3. Plan by an opus planner subagent (pre-authorised, NOT reviewed by the developer). Gated: final UI screens (Figma pending), uploads (all asset slots stay pending, ids only in Data/<Feature>Assets).

## Pre-flight scan (opus, retry after a rate-limit cut): 59 pair rows, 12 task rows, 64 dependency rows; 11 blocking, 10 non-blocking; as written 8/10 code tasks fail the gate; with the fixes every task green, lune 162/0. Table: preflight-scan.md §1-§3.
- Ruling: B1 accepted — new Task 0.5 moves the results vote into ShiftVoteSystem first (ShiftServiceServer 396 → 368), per the M4 final review — cost if wrong: one small refactor commit.
- Ruling: B2 accepted — keep M2's tier-note suppression during break/warning (the plan's replacement would regress M2's final-review fix) — cost if wrong: none (spec silent; M2 behaviour kept).
- Ruling: B3-B11 accepted with the scanner's measured-green corrected files (type fixes, CargoServiceServer cap via CargoFeedbackUtils.banked + sounds in CargoTraitSystem, banking handler is ShiftBankingSystem, anchors, weak-table removal) — cost if wrong: a fix round.
- Ruling: N1-N10 accepted / recorded (N1 repeated lines re-voice; N5 Studio checks queue a crew first; N7 CargoServiceServer ends at exactly 400 — M5 must extract before adding lines) — reversible.
- Ruling: the plan's open questions taken at the planner's defaults (look pending Figma; large clock-out countdown stays in the gated HUD; ambient dread per client) — reversible.

## Tasks
- [x] Task 0: complete (controller; scan ran the greps on f65f1e4; baseline gate green)
- Ruling: the Baseplate Studio ("Place1", 3c129969…) is no longer connected (open: Venture Closed Test, VentureAnimLab ×2, VentureTestingPlace, peekabu-game-systems.rbxl). Per the "Baseplate only" instruction I touch none of them; per-task Studio TestEZ/live checks are queued as "Studio pending" and run in one batch if the Baseplate returns; meanwhile pure specs run in the local lune harness (scratchpad m3lune2) as a stand-in — cost if wrong: runtime-only bugs (instances, replication, sound/VFX wiring) surface later, at the user's playtest.
- [x] Task 0.5: implementer DONE (commit 8107942, gate green, ShiftServiceServer 368). Review pending.
- Task 0.5: complete (commits 7226cc7..8107942, review clean; Studio pending)
- Task 1: complete (commits 8107942..8c2e14c, review clean; lune ShiftNoticeUtils 10/0; ShiftServiceServer 376, OccupantServiceServer 389; Studio pending — check stamp+sticky stacking in the same tick)
- Task 1: minor (deferred): "only names styles the game registers" spec checks the table, not ToastRegistry.has; sticky bodies not asserted for tier/overtime
- Task 2: complete (commits 8c2e14c..2653757, review clean; lune ShiftCueUtils 11/0; Studio pending)
- Task 2: minor (deferred): lastSecond unseeded on start (one extra tick mid-countdown); stop() leaves in-flight one-shots/counters; header line wrap
- Task 3: Ruling: getState returns an exported VacuumFeedbackState instead of the brief's `{ [string]: any }` (implementer deviation, reviewer accepted) — AGENTS.md no-any wins over plan text — cost if wrong: none.
- Task 3: complete (commits 2653757..cbc1a27, review clean; lune VacuumFeedbackFormulas 11/0; Studio pending — N6 chime race, stop-time pop, aim)
- Task 3: minor (deferred): stop() may pop a mid-vacuum pile at teardown; stream targets the nearest hand even if not vacuuming; false "full" chime on a non-pile canister drop to 0 (N6); canister sound ids are literals in the system
- Task 4: complete (commits cbc1a27..50ec53e, review clean; lune NoiseRippleFormulas 7/0; getState typed NoiseClientState (same ruling as Task 3); Studio pending — InnerRadius, flat ring, live→0)
- Task 4: minor (deferred): per-frame ring table alloc; floorBelow lifts ring onto collidable props
- Task 2: minor (deferred): ShiftFeedbackSystem.getState returns { [string]: any } (repo convention allows it; Tasks 3-5 typed theirs — consistency)
- Task 5: complete (commits 50ec53e..2e48071, review clean (opus); lune CargoFeedbackUtils 15/0, CargoHandlingRules 34/0; CargoServiceServer 400, CargoTraitSystem 133, ShiftBankingSystem 63; Studio pending — swoop arc, floaters, leaves)
- Task 5: minor (deferred): Banked.sendToAll unguarded after a credited bank (load would raise; needs extraction — file at 400); N9 guard has a stop→start gap; leaves stranded if CurrentCamera is replaced; leaves flash at origin for one frame
- Task 6: complete (commits 2e48071..efdc7b4, review clean (opus); lune OccupantFeedbackUtils 16/0, OccupantTellRules 24/0; OccupantServiceServer 394; Studio pending — SpecialElite, typewriter reveal, positional sounds)
- Task 6: minor (deferred): same line twice within SPEECH_SECONDS not re-voiced; stop() mid-reveal leaves MaxVisibleGraphemes partial (set -1 on detach); stale comments (OccupantTellSystem header "heartbeat (M3)", OccupantConstants LINES "M3 adds"); heartbeat volume 0.96
- Task 7: complete (commits efdc7b4..e05b6b3, review clean; lune OccupantAnimationUtils 5/0, AnimationOccupantRegistry 3/0, AnimationRegistry 23/0; OccupantServiceServer 398; Studio pending — grin look, headOf client-side)
- Task 7: minor (deferred): grin delay/tween not tied to stop(); duplicated sound-guard pattern (Presence/Scare); headOf takes the first tagged rig
- Studio is back (Place1 eb68b2b0…, PlaceId 0; user connected Rojo). Studio TestEZ @ 1c5e837 (Tasks 0.5-8): 1795 passed / 0 failed (+83).
- Live FeelVerify (controller, solo, @1c5e837): depart → shift running → 3 noises → clock out → results. No errors, no "unknown sound" warnings. Client states: office preset place→officeNight at shift start (Lighting clock 0, brightness 0.6, fogEnd 260), hum on, broken-light zaps; shift toast in PermanentMarker (sticky); noise drawn 3, live→0; Harlow present (patrol) with steps + heartbeat beats; shift cues 3 + countdown ticks 10; all sounds counted pending (silent). Not exercised solo: banking swoop/floaters, vacuum pop, catch scare, overtime red (need item handling / a catch / 4 min).
- Task 8: Ruling: plan-mandated paint() bug (base captured after the red paint → lights stay red after overtime) is fixed, not kept — spec §7 overtime is a phase look, results/next shift are night-white — cost if wrong: none.
- Task 8: fix round 1/5 (1 addressed, 0 open — overtime red captured as light base; commits 1c5e837..60863fe)
- Task 8: complete (commits e05b6b3..60863fe, review clean after round 1; lune OfficeAtmosphereUtils 9/0, OfficeLightUtils 5/0; Studio TestEZ 1795/0 @1c5e837; live: officeNight preset, hum, broken-light zaps)
- Task 8: minor (deferred): `bases` strong refs never cleared (StreamingEnabled/rebuild); long header line in OfficeServiceServer; stepBroken rebuilds tagged list 20×/s; no regression spec for overtime→restore
- Task 9: complete (commits 60863fe..2017662, review clean; lune OfficeAmbienceUtils 6/0; Studio TestEZ 1801/0 @2017662; live FeelVerify rerun: no errors, ambience typing attempts counted pending (4), phones none in ~40 s (20-50 s delay))
- Task 9: minor (deferred): phone/elevator handles discarded (one-shots only); phones/elevators counters count chosen rings not heard; typing stops only for the local player (undocumented); header wrap; typists strong refs
- Task 10 (Steps 1-3): implementer DONE (commit 15ca529, ROADMAP M3 + N10 sentence, gate green)
- Task 10: complete (Steps 1-3: commits 2017662..15ca529, review clean; Steps 4-6 controller after the final review)

## Final whole-branch review (opus) — With fixes (no Critical/Important). Full text: final-review.md
Traced in code: Another shift/reset clears red, tint, ticking, countdown, dust, leaves, grin, music; real ids trip no registry asserts; client dep graph acyclic; no double registration; no authority holes.
Triage: fix before merge = ShiftFeedbackSystem.getState any (Task 2) + 4 stale comments (OccupantTellSystem:11, OccupantConstants:31, ShiftResultsUtils:4, ShiftMobileButtons:6). All other deferred minors kept (reasons in final-review.md); Banked.sendToAll guard → M5 (needs a CargoServiceServer extraction).
- Ruling: fix wave = the any + 4 stale comments only — cost if wrong: none.
- Ruling: Banked.sendToAll guard deferred to M5 with the CargoServiceServer extraction — cost if wrong: a ByteNet fault after a credited bank errors the Load request (nothing un-banked).
- Final fix wave: commit 3793d02 (typed ShiftFeedbackState; 4 stale comments); re-review: all 5 addressed. Studio TestEZ 1801/0 @3793d02.
M3 COMPLETE. Head 3793d02, pushed; PR #3 description updated with the M3 section.
