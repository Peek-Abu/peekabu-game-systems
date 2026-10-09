# SDD Progress — Interlude (Observability, Docs & Data-Layer Polish)

Plan: docs/superpowers/plans/2026-07-17-interlude-observability.md
Branch: feat/interlude-observability (off main). Base: 2df35e8.
Phases 3a (PR #5) and 3b (PR #6) merged; this interlude consolidates their "before next phase" backlog.

Standing decisions:
- Subagents CANNOT run TestEZ. Gate = FULL `bash scripts/check.sh` (with wally install).
- MANDATORY after EVERY commit: `python scripts/python/check_pr_rules.py origin/main` -> zero errors
  (the gate diffs origin/main...HEAD; pre-commit-only runs let banned casts slip once in 3b).
- No new `::` casts without human sign-off. No profile schema changes. No accept/reject behavior
  changes (Task 1 changes REPORTED reasons only).
- getState convention: derived/diagnostic data or NO getState at all (never raw slice mirrors).
- Cmdr stats/setlevel commands are CUT (A4) - do not add them.
- Docs relocation guardrails (Task 6): nothing normative leaves AGENTS.md; only descriptive
  reference moves; every moved section leaves a pointer; "Where to look" index added.
- React Debugger components: spec-EXEMPT (no renderer), but still --!strict, no casts.

## Tasks
- [x] Task 1: complete (commit adb532b, review clean — all 5 correctness questions verified;
  zero behavior change confirmed line-by-line). Minor for final triage: one-line comments at
  CurrencyServiceServer's 3 tail-call mutate sites noting the second return is intentionally
  dropped there (extend Currency to surface reasons in a later pass).
- [x] Task 2: complete (commit f190981, six methods on the fallback chain, review clean; zero findings).
- [x] Task 3: complete (commit adf1f4d, clientAtoms computed + StatePanel useAtom, review clean).
  Two deviations adjudicated sound: userId=0 fallback for nil LocalPlayer (unreachable in prod,
  needed for server-only TestEZ), DebuggerState's spec exemption removed (module gained real logic).
  Minor for final triage: getClientPlayers() has the same latent nil-LocalPlayer read (pre-existing).
- [x] Task 4: complete (commit 6e5c612, 8-file getState audit, review clean; counter proven
  leak-free against Observers source, spec math independently re-derived).
- [x] Task 5: complete (commits e2c313c+a8dd81e, TreeView + fix round, review approved).
  Fix round: unescalated useState cast (root-fixed via typed local; generic-instantiation call
  syntax is NOT valid Luau), nil-slice visibility sentinel, path-stable React keys, updater
  derives from previous. Minors for final triage: sentinel could render theme.MUTED for visual
  distinction; PRE-EXISTING StatePanel:132 hiddenSlices has the same useState cast pattern
  (typed-local fix now proven; follow-up ticket).
- [x] Task 6: complete (commits 742bd4d+11229ff + doc-polish fix, review approved). Key finding
  adjudicated: AGENTS.md contained NO relocatable descriptive content (all normative per guardrail
  #1's ALL-STAYS list) - nothing removed, docs written fresh from code/config, index added. The 3
  reviewer minors (Rokit link, CI-trigger framing, silently-unregisters overstatement) fixed
  inline by controller per reviewer's exact prescriptions.

## Final whole-branch review (opus)
Ready to merge: YES. No Critical/Important. Cross-task integration verified: reason plumbing
airtight end-to-end (all 14 transaction failure paths well-formed), TreeView preserves open state
across live syncs, no new production casts, clean commits. StatePanel:132 cast folded in pre-push
(a3f4e43) per reviewer recommendation. Remaining follow-ups (one bundled ticket suggested):
ServicesPanel reactivity (pull-based vs State tab's push — pre-existing, more visible now),
getClientPlayers nil-guard symmetry, TreeView sentinel theme.MUTED color, CurrencyServiceServer
tail-call drop comments, `local next` shadow nit.

Interlude COMPLETE pending Studio F4 verification + PR. Head: a3f4e43.

## Minor findings (final review triage)
