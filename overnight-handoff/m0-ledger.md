# SDD ledger — plan: docs/superpowers/plans/2026-10-10-m0-base-game-hooks.md

Spec: docs/superpowers/specs/2026-10-10-cleanup-crew-design.md (§6.1). Branch base/game-hooks, start 265d42e (main a04cc46 + spec + plan).
Overnight run per HANDOFF.md; developer asleep. Studio = "Place1" studio_id 3c129969-53e0-4d0f-824e-f2d59506a523 (NEVER df15ee21… VentureTestingPlace).

## Standing decisions
- Implementer gate: `bash .superpowers/sdd/gate.sh` (see Rulings 1-2). Controller runs Studio TestEZ + the plan's Studio checklists after each task's review; failures feed the fix loop.
- Baseline (untouched base): gate.sh green; Studio TestEZ 1287 passed / 0 failed.

## Rulings
- Ruling: implementers gate with `.superpowers/sdd/gate.sh` = scripts/check.sh minus `wally install` AND minus `wally-package-types` — `check.sh --skip-install` cannot pass after install.sh: wally-package-types is not idempotent and fails on the already-typed links before any check runs; wally install is forbidden while Studio is on rojo serve — if wrong: CI's fresh install could surface a type error local analysis missed (unlikely; same typed links).
- Ruling: ruff is advisory locally — local ruff 0.16.5 vs CI-pinned 0.15.21 reports 34 pre-existing findings on untouched main; this plan touches no Python — if wrong: none for M0 (no .py changes); CI gates ruff anyway.
- Ruling: plan's API names stand where they differ from spec §6.1 wording (Death `setSpawnPoint(resolver)` + `kill(..., {launch})` vs spec `configure({spawnAt})` + `{impulse}`; Carry reasons `"removed"`/`"destroyed"` vs spec `"leave"`; Interaction ChannelDef in the registry + `channel(kind, handler)` vs spec's single `channel(kind, {rate,...})`) — same capabilities, plan was written against the real code by the spec's author — if wrong: renames in M0 before merge, cheap.
- Ruling: Task 6 Step 5 (merge) is NOT done — developer's explicit instruction "never merge" — cost: none.
- Ruling: Task 6 Step 2 full `check.sh` replaced by gate.sh — wally install would rewrite Packages under a live rojo serve with no human to reconnect the plugin; CI runs the full gate on push — if wrong: a CI-only failure to fix in the morning.
- Ruling: commits carry no Co-Authored-By/Claude-Session trailers — AGENTS.md rule outranks the harness attribution reminder — cost: none.
- Ruling: Studio guard is `assert(game.PlaceId == 0, "WRONG STUDIO")` (+ every call targets studio_id 3c129969) — handoff's `game.Name == "Place1"` is false here (Name = "peekabu-game-systems"); VentureTestingPlace has PlaceId 117773061427551 so the guard still separates them — cost if wrong: none observed.
- Ruling: Tasks 2 and 3 batched into one implementer dispatch (two commits, one review) — both small, complete-code, disjoint files — if wrong: a slightly larger review unit.

## Pre-flight scan
| Rows | Produces / consumes | Finding |
|---|---|---|
| T4 × T5 | both append EXEMPT_MODULES in SpecRoots.luau and regenerate docs/project-structure.md module map | additive, sequential; no conflict |
| T5 × existing Sound | ToastServiceClient depends on SoundServiceClient:play, SoundRegistry.has | both exist (verified) |
| T4 × existing InteractionRules | channel system calls InteractionRules.check{hasCharacter,distance,maxDistance,tolerance,enabled,cooldownRemaining}; constants DEFAULT_MAX_DISTANCE, DISTANCE_TOLERANCE, ENABLED_ATTRIBUTE | all exist (verified); `enabled` field must be checked by implementer |
| T4 × RequestHandler | RequestHandler.wrap{name,rateLimitKey,rateLimit,handler} | wrap exists; implementer confirms config field names |
| T5 × Tokens/HudRegistry/UILabs | Tokens.space.xxl/sm/md/lg, textSize.xl, radius.md, stroke.thick, color.background; HudRegistry.has/register(key,comp,order); DevPackages mounted | exist (verified xxl, register, has, DevPackages); implementer confirms the rest |
| T1 self | spec `def()` helper exists; behaviour-system names list/target/threat/findCandidate/attack/decide match Step 7 | consistent; registry spec uses an `ensure` helper — plan allows plain register with unique kinds |
| T2 self | kill callers keep working (optional param) | consistent |
| T3 self | forceDrop callers only in CarryServiceServer (Died + cleanup) | consistent with Step 3d |
| T4 self | tracker tests vs code: 0.2 / 0.6 / 0.4 / complete-once math re-derived | consistent |
| T5 self | ToastRules/QueueUtils/Store tests vs code (140 clamp, 1–15 clamp, expire at 103 keeps 104) | consistent |
| T6 self | Step 5 merge + Step 2 full check | ruled above |

## Tasks
- [x] Task 0: complete (toolchain by previous session; baseline gate green via gate.sh; Studio TestEZ 1287/0)
- [x] Task 1: complete (commits 265d42e..9cd506a, review clean; Studio TestEZ 1294/0, +7). Implementer deviation accepted: setBrain uses an if/else assignment (strict typing), no cast.
- Task 1: minor (deferred): brain-error pcall path lives in spec-exempt NpcBehaviourSystem — untested by spec (controller to verify in Studio)
- Task 1: minor (deferred): pathCosts table stored by reference (shallow freeze) — clone+freeze in NpcRegistry.register
- Task 1: minor (deferred): NpcBrainRules.tuned does not validate tuning values (negative speeds, sightAngle range)
- Task 1: minor (deferred, plan-mandated): NpcRegistry spec registers "spec-costs" without `ensure` (fails only on same-session rerun; each Play is a fresh DataModel)
- Task 1: minor (deferred): unknown intent kind from a game brain silently does nothing that tick (no log)
- Task 1 Studio verification (controller): brain erroring every other think → `[NpcBehaviourSystem] brain ... errored` once per think, NPC kept thinking; goTo{run=true} walked to x≈39 at runSpeed 16; setTuning{runSpeed=22} → WalkSpeed 22; setTuning(non-npc) → false. Review Focus #3 VERIFIED.
- Studio method note: MCP execute_luau runs in the plugin VM with its OWN require cache — it cannot reach live services. Verify by injecting a temporary server Script (Source set via MCP) that prints a marker, then read LogService:GetLogHistory(). Services only boot when Workspace.RunTests is false/nil.
- Tasks 2+3 Studio verification (controller, injected probe): Carry signals drop/throw/forced/destroyed/death each fire exactly once, walk speed restored after destroy; kill{launch=(0,60,-80)} → body velocity (0,-20,-80) and +8 studs up 0.4 s later; auto respawn at (0,12,60) under resolver (0,20,60); erroring resolver → `spawn resolver failed` warning + engine spawn; non-CFrame resolver → engine spawn but NO warning (confirms review finding).
- Tasks 2+3: Ruling: the reviewer's plan-mandated Important (non-CFrame resolver return not warned) is fixed despite the plan's code — plan Review Focus #4 requires the warning; nil stays the silent "leave alone" result — cost if wrong: one extra log line.
- Tasks 2+3: minor (deferred, plan-mandated): "destroyed" drop path doesn't increment counters.dropped
- Tasks 2+3: minor (deferred): if SignalTyped:Fire runs listeners unprotected, a throwing `dropped` listener could abort cleanup after the state change (unchecked)
- Tasks 2+3: minor (deferred): CarryServiceServer.luau ~407 raw lines; next addition may breach the 400 code-line cap
- Tasks 2+3: fix round 1/5 (1 addressed, 0 open — non-CFrame resolver warns; commits dbb363d..92b7ff5); controller re-ran gate.sh at 92b7ff5: green incl. typecheck.
- [x] Task 2: complete (commits 9cd506a..92b7ff5 incl. fix, review clean after round 1)
- [x] Task 3: complete (commit dbb363d, review clean)
- [x] Task 4: complete (commits 92b7ff5..4e2806a, review clean; Studio TestEZ 1303/0, +9). Deviation accepted: `local target: Instance?` annotations (strict), no casts. module map unchanged (map lists features, gate's --check passes).
- Task 4 Studio verification (controller; server probe + client LocalScript injected via Client datamodel): solo DONE in ~2.9 s (duration 3); stop at 0.34 → progress held over idle → restart completes ~2 s later; walk 30 studs away → ChannelCount cleared, progress kept (0.29); die mid-channel → count cleared, progress kept, no error. Two-client same-tick completion NOT run live (MCP play is solo) — covered by tracker spec "completes once for everyone on it"; developer may run Test→2 clients.
- Task 4: minor (deferred, plan-mandated): targetById/idOf never release completed/abandoned targets (strong ref in targetById defeats weak idOf)
- Task 4: minor (deferred): game `canChannel` runs unprotected in step — a throwing callback aborts the whole step and `elapsed` keeps growing  [triage: likely fix before merge]
- Task 4: minor (deferred): client channelTarget stays cached after the server ends a channel; startChannel on the same target without stopChannel is dropped
- Task 4: minor (deferred): a target dropped as invalid in step (reset + continue) is not re-published, attributes can go stale
- Task 5: Studio TestEZ 1317/0 (+14), assertAllModulesSpecced green. Live: 6 sends + blank + long → blank refused with `toast refused: empty` warning, max 4 visible, each expired on its duration, long text cut to 140, unknown style rendered as info, duration 999 → 15 s.
- Task 5: review Needs fixes — module map stale (module_map.py reads git ls-files; pre-commit gate passes, committed tree fails). Shared rule added to common.md.
- Task 5: Ruling: fix the plan-mandated byte-cut (string.sub 140 bytes) to a UTF-8 character cut — spec/review focus say "140 chars" and a mid-codepoint cut shows garbage — cost if wrong: none.
- Task 5: minor (deferred, plan-mandated): NaN duration passes math.clamp unchecked (server-only callers)
- Task 5: minor (deferred, plan-mandated): non-string request.text from an untyped caller errors in string.match instead of returning false
- Task 5: fix round 1/5 (2 addressed, 0 open — module map Toast section; UTF-8 char cut + spec; commits 92139e3..e41acb1). Studio TestEZ 1318/0.
- [x] Task 5: complete (commits 4e2806a..e41acb1, review clean after round 1)
- [x] Task 6: Step 1 complete (commit 395ad14, docs only; 25 insertions, no line-ending churn — controller inspected).
- Task 6: Ruling: no separate task review for the docs-only commit; it is in the final whole-branch review's scope — cost if wrong: a doc wording issue caught at final review instead.

## Final whole-branch review (opus) — With fixes
Critical: canChannel unprotected → runaway step. Important: forgotten target dead forever (idOf), client held-channel stuck, pathCosts NoPath straight-line fallback. Minor: brain attack unranged, yielding callbacks, completed targets leak.
Deferred-minor triage: T4-a/b/c/d FIX BEFORE MERGE (bundled into the fix wave); T2/3 "throwing dropped listener" CLOSED (SignalPlus Fire uses task.defer); all others KEEP DEFERRED.
- Ruling: held-channel fix = client throttled re-send every 0.5 s (CHANNEL_RESEND_INTERVAL) + clear on CharacterAdded, not a server→client ChannelEnded packet — also covers rate-limit drops; server start is idempotent — cost if wrong: ~2 extra packets/s per holding player.
- Ruling: pathCosts NoPath → NPC stops (only for kinds with pathCosts); others keep the straight-line fallback — makes "math.huge = never enter" true for Harlow's safe zone — cost if wrong: an NPC with costs can stand still when its goal is unreachable.
- Ruling: game-brain `attack` beyond attackRange becomes a chase — same contract as the default brain — cost if wrong: a game wanting ranged attacks must use its own handler.
- Ruling: CI green on the pushed branch is a merge precondition (reviewer) — recorded for the developer in the PR body.
- Final fix wave: commit 8b0b399 (6 items); scoped re-review: all addressed, no new breakage. Studio TestEZ 1318/0. Live: throwing canChannel → errors logged, bad target never completes, next pile completes in a normal 3.0 s; server resetChannel on a held pile → count cleared, client resend resumes within 0.7 s, completes 3 s after reset.
- Final-review out-of-scope note for M1: a still-held channel restarts on a completed target within 0.5 s — Vacuum's onComplete must destroy/disable the pile (or gate repeats).
M0 COMPLETE. Head 8b0b399.
