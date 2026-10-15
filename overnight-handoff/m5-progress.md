# SDD ledger — plan: docs/superpowers/plans/2026-10-10-m5-cleanup-crew-analytics.md

Spec: docs/superpowers/specs/2026-10-10-cleanup-crew-design.md (§1, §6.2, §6.6, M5 row). Branch game/cleanup-crew @ 3793d02 (M1-M4 + M3). Same PR #3. Plan by an opus planner subagent (pre-authorised, NOT reviewed by the developer). Gated: phone test, publish, sibling session (developer's).

## Pre-flight scan (opus, on 15ca529): 8 blocking, 10 non-blocking; pass 1: T0 stops + 7/9 code tasks fail the gate; pass 2 all green with Task 6 dropped; lune 115/0. Tables: preflight-scan.md §1-§3.
- Ruling: B1 accepted — corrected Task 0 greps; re-run by the controller at 3793d02 (after M3's fix wave): 40 OK, cycle check empty — cost if wrong: none.
- Ruling: B2 accepted — Task 6 dropped (M3 Task 0.5 already moved the vote); 8 new modules; ShiftServiceServer 376 → 382 — cost if wrong: none.
- Ruling: B3-B6, B8 accepted — annotated locals / precomputed booleans / pcall wrapper (no casts) — cost if wrong: a fix round.
- Ruling: B7 accepted — `scatter` source stamped in CargoPocketSystem.scatter, not intoHands (as written it inverts the validation data) — cost if wrong: wrong source tags in analytics.
- Ruling: N4 — document, not code: a pocket round-trip reads `open`; unpocketing in the bay keeps the attempt open until banked (carrying source needs a CargoServiceServer extraction) — cost if wrong: slightly noisier salvage-source data; reversible.
- Ruling: N5 — document, not code: `caught` drops include any death (reset/fall); disabling reset is a gameplay call for the developer — cost if wrong: caught counts slightly inflated.
- Ruling: N7 — left open for the developer (session id logged, not a custom field), planner default kept — cost if wrong: re-publish with a field change.
- Ruling: N1-N3, N6, N8, N9 accepted; N10 not applied (clarity only, +3 lines) — reversible.
- Ruling: plan open questions taken at the planner's defaults except N7 — reversible.

## Tasks
- [x] Task 0: complete (controller; corrected greps at 3793d02 all OK)
- Task 6: dropped (B2)
- Task 1: complete (commits 60d3b00..c349d75, review clean; lune ShiftAnalyticsUtils 27/0; Studio pending)
- Task 1: minor (deferred): outcomeField can reach 81 chars (2×TOKEN_MAX) vs the engine's 50 cap — real words are short; clamp in Task 7 or pin a spec; record.reason "none" vs field omission
- Task 2: complete (commits c349d75..c51cf64, review clean; lune ShiftPlatformRules 7/0; Studio pending)
- Task 2: minor (deferred): long header line in ShiftServiceClient; reportPlatform delay not cancelled on stop
- Task 3: complete (commits c51cf64..5197a3c, review clean; lune ShiftAnalyticsTracker 8/0; Studio pending)
- Task 3: minor (deferred): limit ≤ 0 unguarded; platforms rely on forget() at PlayerRemoving (Task 7 must call it)
- Task 4: complete (commits 5197a3c..d39f5e1, review clean; lune ShiftSalvageTracker 10/0; Studio pending)
- Task 4: minor (deferred): open() can re-key a player's attempt onto an item id another open attempt already holds (only if a teammate's attempt wasn't closed on drop; plan-mandated); counts kept per shift until clear()
- Task 5: complete (commits d39f5e1..35409ae, review clean; lune ShiftVariantRules 11/0; Studio TestEZ 1865/0 @35409ae incl. the OfficeSpawnUtils A/B fairness case; controller grep: only OfficeSpawnUtils gates gameplay on the variant)
- Task 5: minor (deferred): long header line in OfficeSpawnUtils; ShiftVariantRules header says "B in Studio" while code uses input.fixed
- Task 7: Studio TestEZ 1865/0 @ccfe1a4. Live M5Verify (sink + scripted loop): contract_started alternate first 1 B pc 1 m5-dev studio; platform spoof 9 refused ("unknown platform"), later records still pc; override A → shift 2 A (contract_started override replay + replay_started); cleared → shift 3 B (alternate); AnalyticsService skipped 5 = sink lines 5, A.unknown 0. FAIL: no shift_ended on either clock-out.
- Task 7: Ruling: live finding enters the fix loop as Important — Round's runEnded is a deferred SignalPlus fire and Shift configures resultsDuration = 0, so by the time onRunEnded runs Round has reached lobby and cleared participants → crew() is empty → shift_ended never sent (the reviewer's "participants still present" assumed a synchronous fire) — cost if wrong: one fix round.
- Task 7: fix round 1/5 (1 addressed, 0 open — shift_ended crew now from ShiftTripSystem:crew(); commits ccfe1a4..6129ef7). Live re-check: shift_ended piles_0 clockout quota_missed 0 B/A pc 1 on both clock-outs; skipped 7 = sink 7.
- Task 7: complete (commits 35409ae..6129ef7, review clean (opus) + live fix; ShiftServiceServer 382, ShiftBankingSystem 67, Cargo 400; banking events (cargo_banked/quota_met) not exercised live — need item handling)
- Task 7: minor (deferred): watch header stray " : " and "last running copy" wording; Studio resetShift sends shift_ended cancelled; ShiftAnalyticsSystem.stop() partial reset
- Task 8: complete (commits 6129ef7..2025e3f, review clean (opus); CargoServiceServer 400, VacuumServiceServer 203, CargoPocketSystem 215, watch 208; Studio TestEZ 1865/0 @2025e3f). Live M5Verify (scripted Carry:pickUp / drop / Cargo:load): cargo_picked_up rubbishBag:open before_quota; cargo_dropped … dropped; cargo_banked ×2 before_quota; quota_met 7.9 s; monitor picked up after quota → openAttempts 1 → cargo_banked after_quota + optional_salvage_attempted monitor:open banked 1.4 → openAttempts 0; shift_ended … quota_met 1. 12 records, 0 unknown.
- Task 8: minor (deferred): cargo_dropped "left" never sent (deferred Carry "removed" fires after the Player is unparented; the attempt still closes once as left) — document in the checklist; a non-death respawn closes attempts as left (plan-mandated); Vacuum header line 123 cols + bullet punctuation; `vacuuming` holds destroyed piles until reset/leave
- Task 9: complete (commits 2025e3f..af72ac8, review clean; watch 314 code lines). Live: chase_started printer after_quota 38.2 (once); held after-quota printer closes as optional_salvage_attempted printer:open failed unbanked before shift_ended … quota_met 2; 15 records, 0 unknown. Not reproduced in the scripted window: noise_investigation and a catch (player_caught / failed caught) — left for the developer's playtest.
- Task 9: minor (deferred): shared module-level `harlow` could be reset by an old model's late cleanup (repeat chase_started); pending task.defer not cancelled on stop; held() read one defer late
- Task 10 (docs): implementer DONE (commit ad69d17: docs/cleanup-crew-m5-checklist.md incl. Known limits N4/N5/left/respawn/cancelled/N6 + N7 open question; ROADMAP M5 sentence)
- Task 10 (docs): complete (commits af72ac8..ad69d17, review clean; accuracy checked against the code)
- Task 10: minor (deferred → final fix wave): raw `|` inside table cells breaks the markdown table (2 rows); table omits the `unknown`/`other` fallbacks; cargo_banked quota tag timing unstated

## Final whole-branch review (opus) — With fixes (0 Critical, 1 Important, 8 Minor). Full text: final-review.md
Confirmed: caps (Cargo 400, Shift 382); banking guard can't un-bank; variant chosen before any event; no personal data in fields/logs from new code (except M5 below, base RequestHandler); cleanup on stop/new shift.
- Ruling: fix wave = I1 (pass the leaving Player through to closeAttempts/emit so "left" records can be sent) + M1 (per-model Harlow state) + M3 (listeners run without yielding the caller) + M5 (Platform handler onReject = "count", no UserId log) + M6/M8/T7a doc and comment fixes + M2/M4 documented (checklist / spec comment) + Task 10 doc minors (escaped pipes, unknown/other fallbacks, cargo_banked quota timing) — cost if wrong: none.
- Ruling: M7 (Banked.sendToAll guard, from M3) stays deferred — needs a CargoServiceServer extraction (file at exactly 400), the same one N4 would need; listed for the developer — cost if wrong: a ByteNet fault after a credited bank errors the Load request (nothing un-banked).
- Final fix wave: commit a498a8f (I1 leaving-player records; M1 per-model Harlow state; M3 listeners in task.spawn; M5 onReject count; M2/M4/M6/M8/T7a + checklist table docs); re-review: all addressed, no new breakage. Studio TestEZ 1865/0 @a498a8f. Live regression (sink): full loop incl. a Harlow catch while holding an after-quota printer → optional_salvage_attempted printer:open failed caught, cargo_dropped … caught, player_caught harlow after_quota (each once); shift_ended … quota_met 2; 17 records, 0 unknown.
M5 COMPLETE. Head a498a8f.
