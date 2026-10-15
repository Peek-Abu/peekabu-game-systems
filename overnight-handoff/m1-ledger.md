# SDD ledger — plan: docs/superpowers/plans/2026-10-10-m1-cleanup-crew-graybox.md

Spec: docs/superpowers/specs/2026-10-10-cleanup-crew-design.md (M1 row). Branch game/cleanup-crew from base/game-hooks 8b0b399; plan commit e989187.
Plan written by an opus planner subagent overnight (pre-authorised, NOT reviewed by the developer). Studio = Place1 studio_id 3c129969-53e0-4d0f-824e-f2d59506a523 (never VentureTestingPlace).
Shared rules: .superpowers/sdd/common-rules.md (gate.sh, no Studio for implementers, module-map order, stylua, no trailers). Amendments: amendments.md (binding per task).
Studio method: inject temporary server Script / client LocalScript (plugin VM can't reach live services); RunTests=false for gameplay.

## Pre-flight scan
Done by an opus subagent (scan delegated to keep the controller's context for coordination); table in preflight-scan.md: 69 task-pair rows, 13 per-task rows, 37 base-API rows, 12 defect rows, 6 spec rows. 9 blocking, 15 non-blocking.
- Ruling: pre-flight scan delegated to a subagent; controller adjudicated every finding — cost if wrong: a conflict the scanner missed surfaces in task review instead.
- Ruling: B1-B9 accepted exactly as the scan prescribes (branch exists; module-map after git add; stylua own files; six typed-local fixes for luau-lsp) — scanner verified them on a scratch copy (0 type errors) — cost if wrong: a fix round.
- Ruling: N1-N4 accepted (checklist expectations, header wording, a no-op spec override) — cost: none.
- Ruling: N5 accepted — one `OfficeSpawnRules.pileTrash` helper instead of two copies of the dust-bag formula — cost if wrong: trivial.
- Ruling: N6 accepted — build results before endRound on clock-out so Round's next tick can't zero the counters first — cost if wrong: none.
- Ruling: N12 accepted — client aim hysteresis (one AIM_INTERVAL) to keep start/stop flapping under the 20/5 s rate limit — cost if wrong: a 0.1-0.25 s late stop.
- Ruling: N13 accepted — CanQuery=false on piles and hidden items so dropped items don't land on them — cost if wrong: an aim util that raycasts piles would break (implementer told to check).
- Ruling: N9 swap/unpocket (spec §6.3) deferred to the M2 plan — M1 row doesn't name it and CargoServiceServer is near the cap — cost if wrong: pockets only empty by Load/death/leave in the M1 build.
- Ruling: N10 → M4, N11 → M3, N14 no change, N8 exemption stays — per scan.
- Ruling: the plan's 7 open questions are taken at the planner's defaults (game-side touch buttons; Cargo client sends Carry packets for mobile drop/throw; Shift holds results itself with Round resultsDuration 0; NO_SPRINT data only; pocket key Q / D-pad up; lowest-fill channeler's canister credited on a shared pile; Back to depot before M4 → toast + another shift) — all reversible game-side choices — cost if wrong: small rework each.

## Tasks
- [x] Task 0: complete (branch exists at plan commit; baseline gate run by controller below)
- [x] Task 1: complete (commits e989187..2f1538b, review clean; Studio TestEZ 1342/0, +24)
- Task 1: Ruling: fragile/spill "impact" includes forced/death/removed drops (reviewer minor, plan-mandated) — items scattered by a catch or death hit the floor; the spec's "per drop or throw" read as any fall — cost if wrong: narrow CargoHandlingRules.isImpact + one spec line.
- Task 1: minor (deferred): WEIGHT/DROP_NOISE/NO_SPRINT keyed by string not Size — add a spec that every size has entries
- Task 1: minor (deferred): valueAfter with a fractional impact count would index nil (theoretical)
- Task 1: minor (deferred → Task 8 review lens): CargoBankRules.deposit trusts entry.value (cap at def.value or build entries from server attributes)
- [x] Task 2: complete (commits 2f1538b..774a5eb, review clean; Studio TestEZ 1352/0, +10)
- Task 2: minor (deferred): canister tie-break spec only covers lower id arriving later; add() at/over capacity unspecced
- [x] Task 3: complete (commits 774a5eb..bc95d68, review clean; Studio TestEZ 1372/0, +20; reviewer hand-traced the authored layout through the validator)
- Task 3: minor (deferred): validator doesn't check door adjacency beyond edge points, marker kinds, markers inside the truck footprint, door overlaps; checkCapacity ignores item-marker coverage; LAYOUT shallow-frozen
- Task 3 → Task 9 carry: wallSegments is per room (shared walls emitted twice — builder must de-dup or accept coincident parts); truck CAB_SIZE 12×8×6 "behind" the bed (bed minZ 4) would poke through the bay wall at z=0 — builder must place the cab inside the bay.
- [x] Task 4: complete (commits bc95d68..453fb65, review clean; Studio TestEZ 1388/0, +16 incl. 50-seed guarantees both variants)
- Task 4: minor (deferred): check() doesn't confirm the greed marker is actually placed / kind suits marker; determinism spec omits searchables/greed.marker/trashValue; freePile relies on index-parallel piles/pileMarkers (comment)
- Task 4 → Task 9 carry: roll is single-pass; OfficeServiceServer must handle `check` failing (re-roll with a new seed, bounded, then log + proceed).
- [x] Task 5: complete (commits 453fb65..55eb5fe, review clean; Studio TestEZ 1413/0, +25)
- Task 5: minor (deferred): tally double-counts duplicate present ids (caller passes unique); spec gaps (results→running follow, another-majority, timedOut tie, markQuota outside running) — plan-mandated
- Task 5 → Task 10 carry: tick returns endShift every step while running/clockout until Round leaves running — call endRound once (guard), ignore repeats; follow(running) from results starts a shift (Another-shift path) — intended.
- [x] Task 6: complete (commits 55eb5fe..e1ae153, review clean; Studio TestEZ 1423/0, +10)
- Task 6: minor (deferred): decode accepts NaN/negative numbers and dictionary-shaped crew/awards (server is the only publisher); decode malformed-branch spec gaps; CrewLine has no userId (can't highlight "my row") — M3 UI consideration
- [x] Task 7: complete (commits e1ae153..cc66328, review clean; Studio TestEZ 1423/0). Live (injected probes, real VacuumServiceClient:beginVacuum/endVacuum): pile1 cleared 2.52 s after hold; pile2 held 1 s → progress 0.40 kept through release (count cleared) → finished 1.55 s after resume; canister 1→2→0 with BAG popped ~2.5 studs ahead at floor; NOISE pulses 1 s apart only while vacuuming; carrying → no progress on pile4; V:reset → canister 0; no errors.
- Task 7: minor (deferred, triage-worthy for mobile tapping): client `while holding` loop can duplicate on release+re-press within 0.1 s (generation counter fix)
- Task 7: minor (deferred): late joiners have no `canister` public field until first change (HUD must treat nil as 0 — Task 11 lens)
- Task 7: minor (deferred): module state (fills/counters, client lastTarget/missed) not reset in stop()
- Task 7 → Task 9 carry: VacuumServiceServer:reset clears canisters only — Office reset must destroy the shift's pile container.
- [x] Task 8: complete (commits cc66328..6a6e97b, review clean (opus); Studio TestEZ 1432/0, +9). Live (server probe): labels "Name (value)" for all kinds; cabinet WalkSpeed 8, rubbish bag 14.8; pocket plaque+stapler → pocket1/pocket2, ws back to 16; monitor "too big for pockets"; drop noise 24, Monitor (30)→(15)→(8); recycling box spilled into 1 pile (noise 14); load beside bed refused "stand in the truck bed to load"; load on bed → BANK 10 105 3, pockets cleared; double Load → `true nil false nothing to load`, one BANK; death with 2 pockets + held monitor → all three items on the floor 3.6-5.5 studs from the body, public fields nil; search → +1 item, noise 12, desk disabled, second search "already searched"; reset → stocked 0; no errors.
- Task 8: Ruling: pockets-only Load (empty hands) stays allowed (reviewer minor, plan-mandated) — pockets are server state and the step is atomic; making players pick something up to bank pockets is friction — cost if wrong: one guard in CargoBankRules.deposit (+ spec) to require hands.
- Task 8: minor (deferred, triage-worthy for Review Focus #2): scatter takes pockets then returns early if HumanoidRootPart is gone (fallen-parts destroy) → pocket items lost mid-shift; fallback to last root position / container pivot
- Task 8: minor (deferred → M2 Noise lens): throw noise/fragile/spill evaluated at release point (deferred listener reads Position a frame after launch), not landing
- Task 8: minor (deferred): banking handler error silently becomes a toast (no warn)
- Task 9: Studio TestEZ 1432/0. Live: office at pivot (1065,5.5,45); 7 doors, 0 blocked (box query at each door centre); seed 1 plan 20 piles / 44 items / trash 530 / greed filingCabinet @ archive.item.2 (deep); re-roll seed 1 → identical placement; variant A hidden 0; variant B hidden by seed 1..12 = 0,2,3,0,0,1,2,1,1,1,1,1; holding item + O:reset → container nil, item gone, ws 16. Expected warn: TimeClock has no kind until Task 10.
- Task 9: review Needs fixes — mergedWalls unspecced geometry in exempt shell; reset leaves Cargo container pointing at destroyed folder.
- Task 9: minor (deferred → Task 10 lens): beginShift/reset don't reset Cargo/Vacuum (caller's job); after 5 failed re-rolls the plan is placed with only a warning; silent markerById nil skips; long header comment lines
- Task 9: fix round 1/5 (2 addressed, 0 open — mergedWallSegments moved to OfficeLayoutUtils + spec (18 pieces / 692 studs); reset clears Cargo container; commits 8145542..027c688). Studio TestEZ 1438/0 (+6).
- [x] Task 9: complete (commits 6a6e97b..027c688, review clean after round 1). Visual: screenshot shows 7 walled rooms with door gaps, truck bed + cab in the bay, items/piles spread.
- Task 9: minor (deferred): OfficeBuildSystem header still names wallSegments (stale)
- [x] Task 10: complete (commits 027c688..d40f419, review clean (opus); Studio TestEZ 1438/0). Live (server probe, toasts hooked): spawn in bay (1028,3,10), quota 350, endsAt ≈ +420; Load trash → toast "+10 clearance", cleared 10; pockets-only Load → bonus 25; addTeam 340 + Load → quotaMet, ONE "QUOTA MET" toast to all (second Load none); clockOut true then false, sub clockout, 10 s → results outcome clockout, cleared 370, crew1 "Ice", Round back in lobby; vote another → starting → shift 2 with a fresh roll; mid-run reset holding monitor + pocketed plaque → shift 6, carried nil, ws 16, pockets nil, canister 0, hasResults false, resetPending false; death → respawn (1028,3,10); duration 20 → results outcome timeout 20 s after start; 30 s vote timeout → next shift. Not live-checked: `piles` score from vacuuming (needs client; Task 12 full loop).
- Task 10: minor (deferred, triage-worthy): resetPending can go stale if resetShift is called twice before the deferred phaseChanged — set false in finishReset
- Task 10: minor (deferred, triage-worthy): a player leaving during results doesn't re-check the vote (waits for the 30 s timeout)
- Task 10: minor (deferred): onBanked doesn't check endingRun (Load between results build and phase change)
- Task 10: minor (deferred): stop() leaves Cargo bank/onInteract handlers registered (no-restart base pattern)
- Task 11: Studio TestEZ 1447/0 (+9). Live (screenshots): HUD top-left "Shift 1 | 6:37", Clearance 0/350, Bonus, Canister 0/3, Hands/Pockets; clock out → red "CLOCKING OUT 0:09" + toast; results panel "Shift 1 performance review" (outcome, totals, crew line, "Deciding in 0:25", two vote buttons); client vote via ShiftStore.myVote → starting → running shift 2.
- Task 11: review Needs fixes — touch Vacuum hold survives button unmount at clock-out.
- Task 11: Ruling: Task 7's deferred minor (vacuum client loop duplicates on fast re-press) folded into this fix round — same "vacuum stays on" area, generation counter — cost if wrong: none (small, reviewed).
- Task 11: minor (deferred): TouchEnabled read at render (hybrid laptops get buttons); snapshot computed atom re-decodes on any world change; useServerClock lazy initializer
- Task 11: fix round 1/5 (3 addressed, 0 open — unmount/phase-exit endVacuum, generation counter, 2 spec cases; commits 72fad41..b7c96a6). Controller verified endVacuum idempotent (base stopChannel early-returns when nothing held) and no require cycle. Studio TestEZ 1449/0 (+2).
- [x] Task 11: complete (commits d40f419..b7c96a6, review clean after round 1)
- Task 11: minor (deferred): ShiftServiceClient.stop() doesn't endVacuum
- [x] Task 12: Steps 1-4 complete (commit e9b0832, docs only, 10 insertions; controller checked). Step 5: TestEZ 1449/0 at b7c96a6 (docs-only since). Step 6 (2-client playtest) NOT runnable via MCP (solo Play only) → developer's morning item; replaced by a solo full-loop run: client vacuumed 3 real office piles (3.2/3.2/2.6 s incl. aim latency) → dust bag spawned → server banked it (+15 clearance) → clock out → results outcome clockout, cleared 15, piles 3, crew1 banked 15 / piles 3, 2 awards. Step 7 after the final review.
- Task 12: Ruling: the 2-client checklist (shared pile half time, leave-with-cargo scatter, late join, depot vote toast) is deferred to the developer — MCP can't start multi-client tests and the handoff forbids touching other Studio windows; the logic is covered by specs + solo checks — cost if wrong: a multi-client bug found in the morning.
