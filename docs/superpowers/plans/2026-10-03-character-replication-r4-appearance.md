# Character Replication R4 — Appearance Implementation Plan

Spec: `docs/superpowers/specs/2026-10-03-character-replication-r4-appearance-design.md`
Branch: `feature/replication-appearance` (from `feature/replication-animation`, tip d14202d)
Models: implementers haiku for single-file/pure modules, sonnet for multi-file integration; reviewers sonnet; final opus. Studio TestEZ + (controller, Studio) measurement steps run by the controller — the developer serves this worktree for those. Implementers typecheck only in a scratch copy (no rojo in the served worktree).

## Global Constraints

- `--!strict`, no `any`, no casts without justification; ≤400 code lines per module; spec-first.
- Server-authoritative: clients never author appearance state; the client only applies the synced one.
- `ReplicatedStorage` keeps `$ignoreUnknownInstances` (art lives there).
- No Rojo/wally/scripts/check.sh in the served worktree — gate in a scratch export (`git archive HEAD | tar -x -C <scratch>`).
- Commits: plain messages, no agent trailers. Merge only after the developer verifies in Studio.

## Review Focus

- Diff purity: `OutfitDiff` has no Instance access and is stable across equal inputs.
- Dressed rule never leaks a half-dressed or bald frame.
- Missing art/socket → skip + record reason + default shown; never float, never silent success.
- Version tag end-to-end: every queued job carries rig owner + version; stale jobs drop.
- Pool affinity actually returns the same rig; cap respected; stale pieces return to the pool, not the void.

## Rulings this plan makes

- Late joiners: FullState covers the norm; puppet wait-with-timeout → default look → swap on dressed.
- Respawn/slot-switch: slice entry unchanged → same diff path against a fresh `RigOutfit`.
- `Appearance` shape on the public slice mirrors `CustomizationPlan`'s input, plus `appearanceVersion`.
- `TuneOffset` re-enables on the owner rig only; puppets never run it.
- Idle puppet cap 8 → 16, tuned against phone probe.

## File Structure

New (Shared unless noted):
- `Shared/Modules/OutfitDiff.luau` + `.spec.luau`
- `Shared/Modules/RigOutfit.luau` + `.spec.luau`
- `Shared/Modules/PiecePool.luau` + `.spec.luau`
- `Shared/Modules/AppearanceQueue.luau` + `.spec.luau`
- `Client/Modules/PuppetOutfit.luau` (client glue: public slice → `RigOutfit` → queue) + spec
- Moved: `ServerScriptService/.../CustomizationApplication.luau` → `Shared/Modules/CustomizationApplication.luau` (slimmed; same role)

Touched:
- `Server/Services/CustomizationService/CustomizationServiceServer.luau` — publish copy+version to `PublicPlayerState`.
- `Shared/State/PublicPlayerState.luau` (+spec) — appearance fields on the slice entry.
- `Shared/Types/PublicPlayerTypes.luau` — drop the stale "title joins R4" comment.
- `Client/Worktrees.../PuppetPool.luau` — owner affinity + cap 16.
- `Client/.../TuneOffset.luau` — un-refuse on owner rig via live `RigidConstraint` attachment edit.
- `Shared/Modules/CustomizationPlan.luau` — consumed, not changed.

## Commands

- Gate (scratch): `bash scripts/check.sh`
- TestEZ: Studio, `RunTests` attribute, Output.
- Studio probe: 59 puppets, PreRender off into the distance, measure dress step ms (mirrors R3 Task 9/10 probe).

## Task 1: Public-slice appearance publishing

Files: `PublicPlayerTypes.luau`, `PublicPlayerState.luau` (+spec), `CustomizationServiceServer.luau` (+spec).
Steps:
1. Add `appearance: Appearance` + `appearanceVersion: number` to the public slice entry type.
2. Server publishes a deep copy + bumped version on: validated appearance writes, slot switch, spawn defaults.
3. Spec: version increments on each change; copy is not the live profile table; defaults on first spawn.
Verify: typecheck + spec green.

## Task 2: `OutfitDiff` (pure)

Files: `OutfitDiff.luau` + spec.
Steps:
1. Input: target from `CustomizationPlan`, worn from `RigOutfit`'s record. Output: list of ops (add/remove/recolour cosmetic, set body colour, set surface, set head-part visibility).
2. Version equal → empty diff (skip everything).
3. Deterministic order; spec covers added/removed/recoloured/no-op/retired-id-skipped (tolerant, matching `CustomizationPlan`).
Verify: specs green; no Instance access.

## Task 3: `RigOutfit` + `PiecePool`

Files: both + specs.
Steps:
1. `RigOutfit`: per rig — worn record, version, one-time parts-by-name index; `reset()` for release.
2. `PiecePool`: spare pieces kept in the world (parented, hidden), capped, keyed by cosmetic id; take-first, clone on miss; `release(piece)` returns to pool.
3. Specs: reset clears worn without destroying; pool cap; same id returns the same piece instance when un-recoloured.
Verify: specs green.

## Task 4: `CustomizationApplication` — move, slim, `RigidConstraint`

Files: move file to Shared; rewrite to consume `OutfitDiff`; +spec.
Steps:
1. Apply diff only; body colours/surfaces via the `RigOutfit` parts index (no `GetDescendants` per entry).
2. Bind: exact attachment-name match, `RigidConstraint`; per-piece result `bound | noArt | noHandle | noSocket | nameMismatch`.
3. Missing art → show default, record reason on the rig, F4 counter.
4. `TuneOffsetServer` un-refuses on the owner rig; live-edits the attachment; puppets excluded.
Verify: typecheck + spec; Studio: tune offset live on owner rig moves the piece.

## Task 5: `AppearanceQueue` + dressed rule

Files: `AppearanceQueue.luau` + spec; client glue.
Steps:
1. Per-frame budget ~2 ms; FIFO per rig; a body is hidden until its outfit completes.
2. Visible-body look change: bind new before releasing old (no bald frame).
3. Spec: budget respected across N jobs; hidden-until-complete; look change never renders an unbound old/new gap.
Verify: specs; Studio: acquire puppet, assert it pops in fully dressed.

## Task 6: PuppetPool owner affinity + cap 16

Files: `PuppetPool.luau` (+spec).
Steps:
1. Label each pooled rig with owner userId + appearance version on dress; lookup prefers that owner on reacquire.
2. Miss → least-recently-used spare, redress from the slice entry.
3. Cap 8 → 16, tuned against the phone probe.
Verify: spec; Studio: two clients, swap ranges, owner gets its own outfit back.

## Task 7: Client wiring + stale-job safety

Files: `PuppetOutfit.luau` (new glue, +spec).
Steps:
1. Owner rig dresses from its own synced appearance entry.
2. Puppets dress from the public slice; job carries owner + version; stale jobs drop.
3. Respawn/slot-switch re-runs the diff against a fresh `RigOutfit` (entry unchanged).
Verify: spec incl. the stale-job race (queue job A, entry updates to B, assert B wins, A never partially dressed).

## Task 8: Docs, probes, checklist

Files: `docs/animation.md`-style update → `docs/character-replication.md` if it exists, else a short R4 section in the master design doc; probe results appended to the master spec's CP4 tables.
Steps:
1. 59-puppet probe on PC and phone: dress-step ms, PreRender-rate check before debugging (laptop awake!).
2. Developer checklist: missing art (Hair1), stale-outfit-on-reuse, TuneOffset live, slot switch, respawn.
Verify: numbers recorded; checklist passed in Studio.

## After R4

R2–R5 merge together once R5 (chat and voice) is verified. `PublicPlayerTypes` comment updated; CP4 customization-half and the cosmetics-mount fix get their real verdict.

## As built (deviations from this plan)

- Slot switch is a NEW look, so the server bumps `appearanceVersion` on it; only a plain respawn keeps the
  entry and version (the "entry unchanged" ruling above holds for respawn only).
- `OutfitDiff` is split into `target(appearance)` and `compute(worn, target)`; the worn record IS the last
  target, so versions live on `RigOutfit` and the queue, not in the diff.
- `RigOutfit` lives as long as its rig (owned by the puppet), never reset: the record must keep describing
  what a pooled rig physically wears, or a reused rig dresses on top of its last owner.
- `RigLook` was split out of `CustomizationApplication` (authored-state restores + art lookup) for the
  400-line limit.
- `tuneoffset` runs as a Cmdr `ClientRun` (`Client/Modules/TuneOffsetClient`); `TuneOffsetServer` is gone —
  there is no server rig to nudge.
