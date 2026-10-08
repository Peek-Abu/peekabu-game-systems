# Design — Customization 5b: the appearance surface (head type, remaining channels, Soul Color)

**Status:** draft · **Date:** 2026-07-19 · **Phase:** 5b of 3 (follows 5a, PR #10; 5c is the asset
pipeline)

## Purpose

Finish the player-visible customization surface on the mechanism 5a proved. Everything here is
**additive**: extend `Appearance`, add `CosmeticRegistry` rows, extend the validator and plan-builder.
No new architecture — the two-scope slice model, the descriptor-driven channels, the pure-plan /
Instance-shell split, and the `observeCharacter` seam all stay exactly as shipped.

Scope: **head type** (Covered/Uncovered), **hair↔head-type compatibility**, **clothing patterns /
backpacks / shoes**, and **Soul Color**. Explicitly NOT here: the asset reorganization, attachment
offsets, and conformance checker — those restructure how assets are found and mounted, so they are 5c.

## Rig grounding (read-only live inspection, 2026-07-19)

Verified before designing, the same discipline that caught real problems in 5a:

- **Head-type machinery is real and substantial.** `Head` carries `Skin ColorCovered` and
  `Skin ColorUncovered` (two MeshParts toggled against each other), a `FacemaskLower` Model containing
  `Facemask1` + `Color 1`, and `Head.Color 1` — which also hosts the `Hair` Attachment and a
  `Clothing Material` SurfaceAppearance. The old code additionally repositioned the `Head` attachment
  and the eyes between the two modes.
- **⚠ The `Covered` compatibility data DOES NOT EXIST.** Every value is empty: `Hair2`–`Hair8` carry
  `Covered = ""` and `Hair1`/`Hair9`/`Hair10`/`Hair11` carry no value at all; eyebrows and eyelashes
  have none. The partial pattern reads as abandoned authoring. **There is nothing to port** — the
  mechanism is built here, but the DATA is a content decision the developer supplies (Decision 2).
- **⚠ Clothing and shoes are nearly contentless.** Real (non-`None`) options: `PrimaryClothingPattern`
  **1**, `SecondaryClothing` **1**, `Shoes` **1**, backpacks **5** (`Back1`–`Back4`, `Skin2`),
  clothing textures **12**. Backpacks and textures are the only channels with a real menu today
  (Decision 4).
- **The head carries non-cosmetic junk** — 8 `ParticleEmitter`s, an `OxygenUI` BillboardGui,
  `HeadHitbox`, `ClimbPart`. Not this phase's problem; it is precisely what 5c's conformance checker
  is for, and it is noted here so 5b's head-type toggling is written to touch only the parts it owns.

## Decision 1 — `headType` is a per-slot `Appearance` field with an explicit default

```lua
-- Appearance gains:
headType: string,   -- "Covered" | "Uncovered"; validated against the registry's declared set
```

Stored as a validated string rather than a Luau literal union, matching how `ItemDefinition.rarity`
stays `string` and is checked against its constants module — it keeps `PlayerDataTypes` free of a
Constants dependency and lets the set grow without a type change.

**Not optional.** Unlike every other channel (where absent = "none"), a character always has a head,
so the profile skeleton stamps a default (`"Uncovered"`) and the validator requires a registered value.
An absent `headType` would leave the facemask in an undefined state.

## Decision 2 — hair↔head-type compatibility: mechanism here, DATA authored by the developer

`CosmeticRegistry` mount entries gain an optional `headTypes` set:

```lua
{ id = "Hair2", socket = "Hair", headTypes = { Covered = true } },  -- absent = compatible with both
```

Absent means "works with both" — so the default is permissive and only genuinely restricted cosmetics
need a row edit. **The initial values are supplied by the developer, not derived from the art**: the
grounding pass proved the old `Covered` StringValues are empty (see above).

**The content pass is IN SCOPE for 5b** (developer's call), not deferred — otherwise the feature ships
inert. Because the data exists nowhere, it is authored by OBSERVATION, and that needs the head-type
machinery working first. Hence the task order: build the model → build the application → *then* walk
the matrix in Studio (10 hairs × 2 head types, plus eyebrows/eyelashes) equipping each and recording
which clip or break → bake the results into the registry rows. The live `equipcosmetic` /
`setheadtype` commands are what make that walk cheap, which is why they land before the pass.

**This invariant is VALIDATOR-enforceable, unlike 5a's ownership gate.** `cosmetics.hair` and
`headType` live in the SAME `appearance` slice, so `validateAppearance` can see both and reject an
incompatible pair on **any** write path — no service-level policy needed. That is a genuinely stronger
guarantee than the ownership check, which needs two slices and therefore lives in the service.

## Decision 3 — changing head type AUTO-CLEARS an incompatible cosmetic

If the player switches to a head type their current hair does not support, `setHeadType` clears the
offending cosmetic in the SAME mutation rather than refusing the switch.

**Rejected: refuse the head-type change.** The player asked for the head change; refusing because of a
hat they may not even be thinking about reads as broken. Clearing is recoverable (re-pick a hair) and
keeps the slice valid. Because the clear and the head-type write happen in one mutation, the validator
never sees the intermediate incompatible state, so this needs no relaxation of Decision 2's rule.

The service reports which cosmetics it cleared in its `(ok, reason)` string so an admin/UI caller can
surface it rather than silently losing a selection.

## Decision 4 — clothing / backpacks / shoes ship as descriptor rows, content thinness accepted

These reuse the exact `CosmeticSelection` + descriptor mechanism 5a built; they are registry rows plus
application handling, not new architecture:

- **Backpacks** and **clothing textures** have real content (5 and 12) and are worth shipping now.
- **Clothing patterns (1) and shoes (1)** are shipped for completeness but will present a menu of one
  until content is authored. This is a KNOWN, accepted state — flagged here so it reads as a content
  gap rather than a bug when the UI phase renders a one-item picker.

Application differs from accessories: clothing/backpack patterns are `SurfaceAppearance` swaps on
MeshParts and textures are `Texture` id assignments, not attachment mounts. That is new work in the
Instance shell (still spec-exempt), driven by new descriptor kinds so the plan-builder stays pure.

## Decision 5 — Soul Color: one per-character value, roll deferred

```lua
-- Appearance gains:
soulColor: string?,   -- a SoulColorRegistry id; may be multi-hue ("blue-green"); nil = none yet
```

Per the revision recorded in the 5a spec (Decision 4 there): a character has exactly ONE soul color and
a roll REPLACES it, so this is a per-slot value, never an owned collection in `entitlements`.

`SoulColorRegistry` ports the OLD module's pure resolution logic — the dominant `Color3`, the two
`ColorSequence`s, and multi-hue composition by splitting on `-` — because that part is math, not
Instance-mutation, and it is genuinely correct. What it does NOT port is the weighted gacha roll; 5b
ships `setsoulcolor` as an admin command and the reactive mirror so VFX can read the equipped color
later. The roll/spinner stays deferred to an economy phase.

## Validators (extending 5a's, same contract)

`validateAppearance` gains:
1. `headType` is present and is a registered head type.
2. Every mount cosmetic whose registry entry declares `headTypes` is compatible with the current
   `headType` (Decision 2 — the cross-field rule).
3. Clothing/backpack/shoe/texture ids are registered, same treatment as every other channel.
4. `soulColor`, if set, is a registered `SoulColorRegistry` id.

Unchanged: registered-id checks, the `Color` union + per-channel free-RGB policy, dense-array
enforcement (the sparse-array fix from the 5a review), and the entitlements rules.

## Service surface (additions)

```
setHeadType(userId, headType)      -> (boolean, string?)   -- auto-clears incompatible cosmetics (Decision 3)
setClothing(userId, channel, id)   -> (boolean, string?)
setBackpack(userId, channel, id)   -> (boolean, string?)
setShoes(userId, id, colors?)      -> (boolean, string?)
setSoulColor(userId, colorId)      -> (boolean, string?)
```

Each follows 5a's established shape: `Guard` for numeric-shape contracts, registry pre-check for a
friendly message, and the data-layer validator as the real backstop — surfacing `mutate`'s rejection
reason (the fix from the 5a review), never a generic string.

## Testing (spec-first, the cases that matter)

- `headType`: unregistered value rejected; the skeleton default is registered; a raw op cannot store an
  absent/unknown head type.
- **Cross-field compatibility**: equipping a Covered-only hair while Uncovered is rejected BY THE
  VALIDATOR (prove it on a raw `appearanceOp`, not just the service method — that is the whole point of
  it being validator-enforced).
- **Auto-clear**: switching head type with an incompatible hair equipped clears that hair, leaves
  compatible cosmetics untouched, reports what was cleared, and leaves the slice valid.
- Clothing/backpack/shoes: unregistered id rejected; a registered one round-trips.
- Soul Color: unregistered id rejected; multi-hue id resolves to the expected composed sequence and
  dominant color (pure, deterministic — the ported math).
- Plan-builder: head type and the new channels resolve into the plan deterministically, retired ids
  skipped (the tolerance rule).

## Findings carried into 5c (recorded here so they survive the phase)

Three things learned while building 5b that 5c needs, and which exist nowhere else in the repo:

1. **Rig socket DEPTH varies, and it may break the platform mounting API.** Measured against the live
   rig: `Head`, `Helm`, `Mouth`, `Eyebrows` sit on `Head` and `Chest` on `UpperTorso` — all DIRECT part
   children of the character (depth 1). But `Hair` sits on `Head.Color 1` (depth 2) and `Eyes` on
   `Head.Eyes 1.Eye Color` (depth 3). `Humanoid:AddAccessory` matches attachments on direct part
   children, so if that limit is real, hair/eyelashes/every Eyes-socket accessory silently never weld
   while Head/Mouth/Chest ones work.
   **Status: UNPROVEN.** A fix was written and then reverted — the bug we were actually chasing turned
   out to be a missing models folder, and the depth limit was inferred from docs rather than
   demonstrated. 5c should settle it EMPIRICALLY now the art is restored, because the answer decides
   the mounting approach: if the native path handles nested sockets, keep it; if not, choose between
   `RigidConstraint`-based mounting and simply adding sibling attachments to `Head` (an art change that
   makes the native path work with no custom mounting code at all).
2. **Silent asset failure is expensive.** A missing `Customs` folder produced NO error: every command
   reported success, the slice validated, the F4 panel updated, and nothing appeared. It cost a full
   debugging round to find. A conformance checker asserting "every catalog id resolves to art, with a
   Handle and a socket-named Attachment" would have said so on the first boot. This is the concrete
   justification for that 5c task.
3. ~~**Per-cosmetic attachment offsets are a CONFIRMED need.**~~ **MISDIAGNOSED — corrected 2026-07-20.**
   The observation was real (eyebrow and eyelash fit looked wrong, equally in both head modes) but the
   cause was not fit: those cosmetics were rendering with parts MISSING. Roblox welds only an
   Accessory's Handle on mount, and 21 of the 50 catalogued accessories had no joints at all, so their
   loose parts stayed at the source model's coordinates. `Eyebrows4` looked fine only because it is
   Handle-only and had nothing to leave behind.
   Once the art was welded (5c) the fit was correct with no offset at all. 5c still SHIPPED the offset
   mechanism — it is cheap, and the rig redo may well need it — but no cosmetic currently uses one.
   The lesson worth keeping: "it sits slightly wrong" and "it is missing geometry" look identical from
   the outside, and the difference is only visible by inspecting the art.
4. **A retired cosmetic id FREEZES the whole appearance slice.** `validateSelection` rejects any id not
   in the registry, and the per-slice validator runs against the WHOLE resulting appearance on every
   write — so a player holding a since-retired cosmetic cannot change their head type, colours, or
   anything else until that id is cleared. Meanwhile `CustomizationPlan` deliberately SKIPS retired ids
   so the character still renders. The two halves take opposite stances.

   The 5a spec documents that split as intentional ("the resolver keeps rendering what is persisted;
   the validator refuses bad NEW writes"). What it did not anticipate is that whole-slice revalidation
   turns "refuse bad new writes" into "freeze the slice". Latent today — nothing has been retired
   pre-launch — but it is a live-ops trap the moment anything is.

   **5c should align cosmetics with the affix precedent** (PR #8, lenient-on-retired-keys): let
   `validateAppearance` tolerate unregistered COSMETIC ids, since services pre-check on equip and
   clients never write, while `entitlements` stays strict (a retired id there is dead weight, not a
   rendering concern). Deferred from 5b rather than patched late because it revises a 5a decision and
   deserves its own spec entry.
5. **No `CmdrTypes` module carries `--!strict`** — not the four 5b added, and not `currencyType` /
   `itemType` / `statId` from earlier phases. Review flags it every time, correctly: it is a real
   compliance gap. It is deferred here rather than half-fixed because the set should move together, and
   because these modules take a Cmdr-internal untyped `registry` argument, so turning strict on may
   surface type errors worth handling deliberately rather than in the middle of a feature branch.

## Deliberately NOT in 5b

- **Asset reorganization, attachment offsets, live-tuning command, conformance checker** → 5c.
- **The Soul Color gacha roll / spinner UI** → economy phase.
- **Authoring more clothing/shoe options** → content, not code (Decision 4). (Populating `headTypes`
  IS in scope — see Decision 2.)
- **Customization UI** → the later UI-framework phase.
