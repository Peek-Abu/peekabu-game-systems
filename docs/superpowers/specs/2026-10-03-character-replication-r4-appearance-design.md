# Character replication R4 — appearance

Status: DRAFT for developer review. Written 2026-10-03. Builds on
`docs/superpowers/specs/2026-09-22-character-replication-design.md` (CP1–CP3) and
`2026-10-02-character-replication-r3-animation-design.md` (R3). R4 branch to be cut from
`feature/replication-animation`.

Scope: **appearance only.** The equipped title and nameplates are NOT in R4, even though
`PublicPlayerTypes` says "appearance and the equipped title join in R4" — update that comment.
Distance/appearance tiers are deferred until cosmetics with motion or cloth physics arrive, and
will be designed together with them (decision 2).

## Settled decisions

1. The equipped title and nameplates are out of R4.
2. Distance and appearance tiers are deferred; the `AppearanceQueue` budget (~2 ms/frame) is
   designed to compose with a future per-distance tier so tier-2 does not retrofit it.
3. Keep the shared puppet pool (`PuppetPool`); add **owner affinity** — a pooled puppet keeps its
   outfit, labelled with owner userId + appearance version. A returning player gets that rig back
   with nothing to redo; otherwise take the least-recently-used spare and redress. Idle cap raised
   from 8 to ~16 (tune on phone). Measurements: rig clone 19–46 ms, destroy hitchy (24 at once
   froze ~1 s) — pooling is the win.
4. Bind with `RigidConstraint` from the piece Handle's socket attachment to the rig socket, with an
   exact attachment-name check. Measured equal-cost to `Weld` (0.16 vs 0.19 ms/piece) but only
   `RigidConstraint` follows live attachment edits, which `TuneOffset` requires.
5. Appearance rides the **charm-sync public slice** (`PublicPlayerState`, per-viewer filtered) with
   an `appearanceVersion`. The older spec row "appearance on the slot table" is superseded.
6. Combination: a pure diff-based apply with pieces that never leave the world (the pool stays
   parented, hidden).

## Section 1 — architecture (approved)

- **Server:** `CustomizationServiceServer` keeps its validated writes. On every active-appearance
  change (edit, slot switch, defaults filled on spawn) it publishes a **copy** plus a version to the
  player's public-slice entry. The profile is never mutated. Health fields stay; `appearance` and
  `appearanceVersion` are added.
- **Shared, pure and unit-tested:** `CustomizationPlan` (exists) builds the target look. New
  `OutfitDiff` compares target against worn and emits only changes: cosmetics added, removed or
  recoloured; body colours; surfaces; head parts.
- **Client:**
  - `CustomizationApplication` moves from `ServerScriptService/Services/CustomizationService/` to
    Shared, slimmed down. It executes a diff and binds with `RigidConstraint`. It reports each
    piece's result: bound, no art, no handle, no socket, or name mismatch.
  - New `RigOutfit`: per rig, what it wears and its version, plus a one-time index of parts by name.
  - New `PiecePool`: spare cosmetic pieces kept **in the world**, hidden and capped, keyed by
    cosmetic id. Take first, clone only on a miss.
  - New `AppearanceQueue`: per-frame budget (~2 ms). A body is hidden until dressed.
  - Owner rig dresses from the player's own synced appearance; puppets dress from the public slice.
  - `TuneOffset` works again by editing the attachment live on the owner rig. It currently refuses
    with an "until R4" message; its spec asserts that.
- **Not in R4:** tiers, physics cosmetics, titles, nameplates.

## Section 2 — diff application rules (approved)

- Cosmetic slots keyed by category or accessory index, identified by id, colours and offset. Same
  id with new colours: recolour in place. New id: return the old pieces to the piece pool and take
  or clone the new ones.
- Body colours go through the part index. Surfaces handle pattern and texture per channel, keeping
  "restore the rig's authored surface".
- Head parts are a visibility map. An unchanged version skips everything.
- **Dressed rule:** a puppet just acquired or reassigned stays parked until its outfit completes,
  then appears. A look change on a visible body applies in place; the old piece stays until the new
  one is bound, so no bald frame.
- **Missing art or socket:** skip that piece, record why on the rig, and show the default in its
  place, never a floating piece. Per-reason F4 counters replace today's debug-level log (which
  `LogLevel = Warning` hid). Boot conformance still names the art fault.
- **Ownership safety:** each queued job carries the rig owner and version; stale jobs are dropped.

## Section 3 — server and wire (approved)

- Public-slice shape: the full appearance table plus an `appearanceVersion`; charm-sync already
  sends deltas, so shape stays full-table.
- Publishing hooks in at slice mutate, slot switch, and spawn defaults.
- Late joiners: FullState delivers the entry on connect, so the norm is no wait at all. Owner rig
  always dresses locally from its own entry. Remote puppets: hide until dressed, with a timeout
  that falls back to the default look, swap when the real entry dresses them. Version tag makes the
  swap deterministic.
- Respawn and slot switch: respawn reuses the same slice entry (no version change), only the rig is
  new — same diff path re-runs against a fresh `RigOutfit`. Owner dresses locally, puppets from the
  public slice.
- Bandwidth: appearance changes are rare; a byte-counted diff protocol is not needed.

## Section 4 — testing (approved)

- Pure specs for `OutfitDiff` (added/removed/recoloured/no-op) and for pool affinity (returning
  player gets their rig, LRU on miss, cap).
- Studio checks assert each piece **sits on its socket**: Handle attachment to rig socket distance
  < 0.01 studs, never just "apply() returned" (CP4 false-pass lesson).
- Two-client checklist: stale-outfit-on-reuse, missing-art check (`Hair1` has no Handle — must
  skip-and-record, not float), live `TuneOffset` on the owner rig.
- Stale-job race check: queue an outfit, change appearance again before it runs, assert the rig
  ends on the second version and the first never partially dressed.
- One 59-puppet cost probe on PC, then phone, before the R2–R5 merge window.

## Problems in the current code (fixed in R4)

`CustomizationApplication.luau` (607 lines, spec-exempt, server-side today):
- `apply()` clears and re-clones every cosmetic on every change.
- Body colours and surfaces each run a full `character:GetDescendants()` pass per entry (~10+
  passes per apply).
- Its doc comment still claims the engine binds accessories. It doesn't on the client (measured,
  hair fell off).
- `apply()` returns "applied" even when every mount was skipped; the log is debug-level and hidden.

## Measurements (from the R4 spike session)

| Measurement | Result |
|---|---|
| Rig clone | 19–46 ms |
| Dress 6 real pieces fresh | 8.7 ms median, 17 ms p90 |
| Move 6 mounted pieces rig→rig | 0.21 ms |
| Undress 6 pieces | 4.3 ms |
| Body colour: 10 full-rig scans (today) | 2.1 ms; index once 0.17 ms |
| Bind+parent per piece: RigidConstraint | 0.16 ms; live attachment edit moves it |
| Bind+parent per piece: Weld | 0.19 ms; live attachment edit does NOT move it |
| Destroy one rig | 11.6 ms; 24 at once froze ~1 s |
| Memory per parked rig | ~0.46 MB |

## Open items carried from R3 (not R4 scope)

- Restart `rojo serve` on the R3 worktree and re-run TestEZ + the developer checklist before any
  R2–R5 merge.
- Issue #32: R2 follow-ups (`StatsServiceServer` stop(), guard RequestHandler's custom clock).
- First ability system needs owner-side prediction; Death/Ragdoll phases must call
  `AnimationServiceServer:stopAll(player)`; the landing bounce is rig/physics, not replication.
