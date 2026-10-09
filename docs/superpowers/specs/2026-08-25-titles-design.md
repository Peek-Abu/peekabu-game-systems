# Design — Titles (Phase 8)

**Status:** v1 DRAFT 2026-08-25 · **Date:** 2026-08-25 · **Phase:** first of the post-UI-framework
parallel track (branch `feat/titles`). Merge-order note: this branch carries its spec only until
implementation starts; it is deliberately independent of the Sound/VFX branches and touches none
of the same trees.

## Purpose

A titles system that answers, for every current and future consumer (Quests, Guilds, achievements,
admin grants):

1. **Where do title definitions live?** One pure-data registry — display metadata only, never
   persisted, so reshaping definitions is always migration-free.
2. **How does a player earn / lose a title?** Through one server-owned service API that future
   systems call — no other writer.
3. **What can a player wear?** Any *earned* title, selected by the player, enforced where the data
   layer enforces everything else.

The old game (`TitleHandler`, 104 ln + a data submodule) contributes almost nothing structural:
bare string ids awarded directly by `QuestHandler` and read by `GuildHandler`. There was no equip
concept found and no display integration beyond that. We keep the *facts* (titles exist, quests and
guilds consume them) and re-derive the shape.

## Decision 1 — definitions are pure display metadata

`Shared/Modules/Constants/Titles/` — a `TitlesRegistry.luau` index over per-consumer data modules
(mirroring `Animations/`: domain files composed into one typed, frozen lookup), seeded with a
`General.luau`. Entry shape:

```luau
export type TitleDef = {
	id: string,
	displayName: string,
	color: Color3,
}
```

- **Nothing else.** Rarity tiers, gradients, effects — all deferred. Because the profile stores
  only ids, adding fields later is a registry edit, never a migration.
- Cmdr enums derive from the registry (the 5b cosmetics precedent).
- **Rejected — rarity now:** zero consumers today; YAGNI. The shape admits it for free later.
- **Rejected — storing displayName/color in the profile:** freezes display decisions into saves;
  the old game's sin of data-as-content.

## Decision 2 — split scopes: earned is account-wide, equipped is per-slot

Exactly the 5a customization two-scope model:

- **Account-scoped `titles` slice**: `{ earned: { [id]: true } }` — earning a title is about the
  player, once.
- **Slot-scoped `equippedTitle` slice**: `{ equipped: string? }` — different characters wear
  different titles.

Both registered via `SliceOwner.register` with per-slice validators (data-layer enforced, holding
for any write path).

**Validation rules (slice validators enforce per-slice structure; cross-slice membership is enforced as service policy):**

| Rule | Behavior |
|---|---|
| `earned` ids must be strings | hard fail on non-string keys/values |
| unknown id in `earned` | **lenient pass** — the 5c retired-cosmetic rule; a removed title must never freeze a save |
| `equipped` present but not in `earned` | **not a validator rule** — a per-slice validator only ever sees its own slice's value, so cross-slice membership can't be checked from inside either one. Enforced as SERVICE POLICY instead: `equip` refuses unearned ids before writing, and `revoke` atomically clears `equipped` in the same transaction that removes the earn. |

Note the asymmetry: unknown-in-earned is tolerated (retirement), but *equipping* an unearned title
is structurally impossible on every sanctioned path — enforced by policy at the write boundary
rather than by the validators. That guarantee covers the write that mints `equipped`, not every
slot's contents forever after: `revoke` clears `equipped` only on the character the player is
CURRENTLY on, in the same transaction that removes the earn (its baked-path `op` addresses one
concrete slot — see Decision 3). A title revoked while the player is on a different character
therefore leaves that other slot's `equipped` pointing at an id the account no longer earns — inert
history, tolerated by the validators exactly like a retired id, and sitting there until something
(a future equip on that slot, or a consumer resolving it against `earned`) overwrites or accounts
for it. So the precise claim is: no sanctioned path can ever WRITE an unearned id into `equipped`; a
previously-earned id can persist there after the earn is gone, on a non-active slot only. See the
KNOWN LIMITATION under Non-goals for what this means for the display/UI phase.

## Decision 3 — one service surface, server-authoritative

`Services/TitlesService/TitlesServiceServer.luau` (+ `.spec`), lean annotated literal per house
style, mirroring `CurrencyServiceServer` structure:

- `award(userId, titleId)` — idempotent; validates the id exists in the registry (awards of dead
  ids are programmer error, unlike validation which must tolerate history)
- `revoke(userId, titleId)` — removes from `earned`; atomically clears `equipped` if it pointed at
  the revoked id (single transaction across both slices)
- `equip(userId, titleId)` — validated against `earned`
- All writes via `mutate()`; charm mirror atoms updated by the standard write path

Client side: `TitlesServiceClient.luau` facade + one typed ByteNet request in
`Shared/Events/TitlesEvents.luau` for `equip` (discrete event, not queryable state — state rides
charm-sync).

## Decision 4 — admin surface now, consumers later

Cmdr commands `TitleAward` / `TitleRevoke` / `TitleEquip` behind the existing fail-closed allowlist
— this is the only V1 consumer, and it makes every service path testable in Studio before Quests
or Guilds arrive.

## Non-goals (this phase)

- **No display integration** — no chat prefix, no name tag, no UI. Display waits for the UI
  framework (#14) to land and becomes a thin React consumer of the charm atoms.
  - **KNOWN LIMITATION for that phase:** `equipped` on a NON-active slot can hold a revoked id (see
    Decision 2's asymmetry note) — revoke only clears the character the player is on at the time.
    A display consumer that reads `equipped` directly for a slot the player isn't currently playing
    (e.g. a character-select screen, an offline roster view) must either resolve the worn id against
    the account's `earned` set before rendering it (treat `equipped` not in `earned` as "nothing
    worn"), or this residue must be cleared before that consumer ships. Reading the ACTIVE slot's
    `equipped` needs no such guard — revoke already keeps that one honest.
- **No award automation** — quest completion / guild rank hooks arrive with those systems; they
  call `award()`, nothing more.
- **No rarity/tier system** (see Decision 1).

## Testing

Spec-first throughout: registry purity/frozenness + enum derivation, slice validators (including
the lenient-vs-hard asymmetry table above), service ops incl. revoke-clears-equipped atomicity,
ByteNet request boundary validation.
