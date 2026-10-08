# Design — Customization (Refactor Phase 5)

**Status:** draft · **Date:** 2026-07-18 · **Phase:** 5 of the Venture port (follows Phase 4 Bank;
the roadmap's "Customization" gameplay-domain row)

## Purpose

Give each character a look the player controls: attachment cosmetics (hair, eyebrows, eyelashes,
accessories), body/dye coloring, clothing/backpack/shoe styling, a Covered/Uncovered head type, and a
Soul Color. Persist what a player has **unlocked** (account-wide entitlements) separately from what each
character has **equipped** (per-slot appearance), and apply the equipped appearance to the spawned
character on the existing `Observers.observeCharacter` seam — the same seam `StatsServiceServer` already
uses to push derived state onto the `Humanoid`.

## Governing principle — evidence, not source (reaffirmed)

Per [[old-code-is-evidence-not-source]]: the live inspection pass (read-only, `VentureTestingPlace`,
2026-07-18) is authoritative on the FEATURE surface and never on the SHAPE.

- The old `RequireableCustomization.LoadCustomization` is a **636-line untyped imperative blob** that
  reads a flat `{ [string]: any }` table and mutates the character by hardcoded name-paths
  (`char.UpperTorso.Backpack["Rope Color"]`, `head["Skin ColorCovered"]`). It is the archetype this
  refactor exists to replace — we take its *channel list* as evidence and throw the shape away.
- Colors were stored as raw `{r, g, b}` arrays **with an inconsistent scale** (0–255 for
  `Color3.fromRGB` in some call sites, 0–1 for `Color3.new` in others). That inconsistency is a bug we
  fix at design time (Decision 7), not a convention to preserve.
- Persistence went through a `PlayerStatManager` BindableFunction (`Invoke(player,"GetData"/"SetData",
  {dataKey="Customization"})`); the whole "state via bindable RPC into a DataStore2 blob" path is
  replaced by a validated ProfileStore slice, exactly as every prior phase did.

Confirmed live facts the design leans on:
- Active `StarterCharacter` is a **custom R15 mesh rig, artist-owned in the place** (body-scope B — the
  developer's explicit call). It carries the customization contract as named internal structure:
  dye part-groups (`Color 1`, `Color 2`, `Skin ColorCovered/Uncovered`, `Belt Color`, `Rope Color`,
  `Eyes 1/Eye Color`, `Backpack Color 1/2`), attachment sockets (`Head.Helm`, `Head.Eyebrows`,
  `Head.Mouth`, `UpperTorso.Chest`, `*.Pauldrons`, `*.Greaves`), and a Covered/Uncovered facemask
  mechanic baked into the mesh.
- `ReplicatedStorage.Customs` is the cosmetic catalog (30 entries): `Hair` (11), `Eyebrows` (4),
  `Eyelashes` (3), `Dyes` (6 Textures), `Shoes`, `PrimaryClothingPattern`/`SecondaryClothing`,
  `Primary/SecondaryBackpack`(+pattern), `TexturesFolder` (12 named clothing textures), a `Folder` of
  19 misc accessories, and a `Locked` folder (WizardHat, WoodMask, MagicGoggles, Tabard as BoolValues)
  — the concrete evidence that **most cosmetics are free and only a gated subset needs unlock tracking.**
- Soul Color (`SoulColor`, 294 ln) is a **gacha roll economy**, not a picker: weighted rarities, colors
  combine into multi-color souls (`"blue-green"`), each mapping to a `ColorSequence` + dominant `Color3`
  for VFX tinting.

## Decision 1 — Two slices: per-slot `appearance` + account-scoped `entitlements`

Customization is the first domain to own **two** slices at once, one per scope:

- **`appearance` — per-slot** (`SliceOwner.registerSlot`). Each character slot has its own equipped
  look; switching slots shows a different character. This is the developer's firm call ("per-slot
  equipped appearance for sure").
- **`entitlements` — account-scoped** (`SliceOwner.registerAccount`). What the account has *unlocked*
  is earned once and available to every slot. Developer's guidance: "most cosmetics are account-wide,
  but some may become character-slot-wide later — cross that bridge later, as long as it's extensible."

**Extensibility requirement (Decision 1a):** the entitlement model must not hardcode "all unlocks are
account-wide." It is keyed **by category**, and each category carries a **scope policy** (`account` |
`slot`) resolved through one function. Every category is `account` today; flipping one to `slot` later
means adding a per-slot entitlement store and changing that category's policy — no reshape of callers,
no schema migration of the categories that stay account-wide. The `appearance` validator consults the
policy to decide *which* entitlement store to check an equip against (Decision 11), so the check site is
already scope-agnostic.

## Decision 2 — A typed `Appearance` record replaces the untyped blob

Every channel the old blob smuggled through `{ [string]: any }` becomes a named, typed, validated
field. Grouped so the record reads as structure, not a bag of keys:

```lua
-- CustomizationTypes.luau (new)
-- A color channel is EITHER a reference to an unlockable dye OR a free RGB triple (Decision 7, hybrid).
-- Whether free RGB is allowed is per-channel policy (Decision 10); the validator enforces it.
export type Color =
    { source: "dye", id: string }                        -- dye id in CosmeticRegistry (lockable → entitlement-gated)
  | { source: "rgb", r: number, g: number, b: number }   -- 0–255 integers, one convention

export type AccessorySlot = { id: string, colors: { Color } }   -- id indexes CosmeticRegistry; colors length per-accessory

export type Appearance = {
  -- attachment cosmetics
  hair:      { id: string?, color: Color? },
  eyebrows:  { id: string?, color: Color? },
  eyelashes: { id: string?, color: Color? },
  accessories: { AccessorySlot },              -- up to ACCESSORY_SLOTS entries (old game: 3)

  -- body / dye colors
  body: {
    color1: Color?, color2: Color?, skin: Color?,
    rope: Color?, belt: Color?, eye: Color?, wrap: Color?,
  },

  -- head identity
  headType: "Covered" | "Uncovered",

  -- clothing / backpack / shoes (heaviest, rig-coupled — see sub-phase 5b)
  clothing: { color1Pattern: string?, color2Pattern: string?, color1Texture: string?, color2Texture: string? },
  backpack: { pattern1: string?, pattern2: string?, texture1: string?, texture2: string?, color1: Color?, color2: Color? },
  shoes:    { id: string?, color1: Color?, color2: Color? },

  -- soul color (Decision 6) — the equipped selection, a registry color id (may be multi: "blue-green")
  soulColor: string?,
}
```

Every `id`/`pattern`/`texture`/`soulColor` string references a registry entry (Decision 3); `nil`
means "none/default." No field is `any`. The validator (Decision 11) rejects any unregistered id and any
out-of-range color, so no write path can persist a malformed appearance.

## Decision 3 — Three data-only registries (the `ItemDefinitions` pattern)

Mirroring how Items already work (`ItemDefinitions`/`GameItems` registry modules), customization gets
data-only registries — the single source of truth for "what exists," decoupled from both the artist
rig and the persisted slice:

1. **`CosmeticRegistry`** — the catalog. Per category (`hair`, `eyebrows`, `eyelashes`, `accessory`,
   `shoes`, `clothingPattern`, `clothingTexture`, `backpackPattern`, `backpackTexture`, **`dye`**), the
   set of valid ids and, per id, whether it is **lockable** (default: free). The `Customs.Locked` folder
   seeds the initial lockable accessory set (WizardHat, WoodMask, MagicGoggles, Tabard); the `dye`
   category is the unlockable color palette (Decision 7). Also declares per-accessory metadata the
   validator needs (how many color channels an accessory takes), and the **channel descriptor table**
   (Decision 10) — the data rows the validator and plan-builder iterate instead of per-channel code.
2. **`RigContract`** — the **thin rig registry**: the code-side mirror of the naming convention the
   artist rig must follow, so application locates customization targets by a documented contract instead
   of 600 lines of literal paths. It declares the dye part-group names (`Color 1`, `Color 2`,
   `Skin Color*`, `Belt Color`, `Rope Color`, `Eye Color`, backpack color parts), the head-type
   covered/uncovered part sets, and the attachment socket names. Application **scans the spawned
   character for conventionally-named parts** (as the old code already did) rather than hardcoding a
   part tree — so an artist re-mesh that keeps the naming convention needs no code change. `RigContract`
   is where that convention is written down and asserted. **Implementation note (grounded 2026-07-18):**
   the binding is small enough that it rides on the `CosmeticRegistry` channel descriptor rows (Decision
   10) — dye channel → exact part-name to scan, accessory category → attachment socket — so 5a needs no
   separate `RigContract` module. A dedicated rig-structural module arrives only if 5b's head-type
   part-sets outgrow a descriptor row. Coloring is uniform per channel, so there is **no exclusion rule**:
   head/facemask parts that share a channel name are correctly colored the same; only their visibility
   (head type, 5b) is special.
3. **`SoulColorRegistry`** — per soul color id: dominant `Color3` + the two `ColorSequence`s for VFX
   tinting, plus rarity metadata (kept for the deferred roll). Multi-color ids (`"blue-green"`) resolve
   by splitting on `-` and composing a sequence, exactly as the old `getColorSequence` did — that pure
   logic ports cleanly (it's math, not Instance-mutation).

## Decision 4 — Entitlements: an owned-set for lockables, free items implicitly available

```lua
-- CustomizationTypes.luau
export type Entitlements = {
  cosmetics: { [string]: { [string]: true } },  -- category -> set of owned lockable ids (dyes live here too, category "dye")
}
```

An id that is **not** flagged lockable in `CosmeticRegistry` is always available — it is never written
into `entitlements`, keeping the slice small (only earned/gated things are stored). An id that **is**
lockable must appear in the owning store before `appearance` may equip it. Lockable **dyes** are gated
the same way — a `Color` with `source = "dye"` must reference an owned (or free) dye id (Decision 7).

**Soul color is deliberately NOT an entitlement** (revised 2026-07-18, developer's call). A character has
exactly ONE soul color — itself possibly multi-hued (`"blue-green"`) — and rolling REPLACES it. That is a
per-character VALUE, not an owned collection, so it lives on the per-slot `Appearance` (Decision 6) and
never in `Entitlements`. Modeling it as a set would have communicated "collection" while behaving as
"single". A "keep every soul you've rolled" collection is added only if a gamepass ever needs one —
schema changes are free pre-launch, so nothing is lost by waiting.

## Decision 5 — Application on the `observeCharacter` seam; testable core vs. Instance-mutation shell

`CustomizationServiceServer:start()` uses `Observers.observeCharacter` (the proven seam) to apply the
active slot's `appearance` whenever a character spawns, and re-applies on any `appearance` mirror change
(same subscription pattern `StatsServiceServer` uses for stats/equipment). Re-application on
`SlotService` slot-switch respawn is automatic — the fresh character triggers `observeCharacter`.

The redesigned application logic splits so the messy part is small and isolated:
- **Pure/testable core** — resolving an `Appearance` + the registries into a **plan**: the list of
  accessories to mount (id → clone source), the dye part-groups → color assignments, the head-type part
  toggles, the clothing/backpack/shoe operations. No Instance access; unit-testable against fixtures.
- **Instance-mutation shell** — walks the spawned character applying the plan (clone accessory, weld via
  `AccessoryUtilities`, set part colors, swap `SurfaceAppearance`, toggle transparency for head type).
  This needs a real rig, cannot be TestEZ-unit-driven, and goes in `SpecRoots.EXEMPT_MODULES` with that
  reason (the same honesty the codebase already applies to boot/seal-only code).

## Decision 6 — Soul Color: store + equip now, roll deferred

This phase builds the character's **single soul color** (`appearance.soulColor`, per-slot — see
Decision 4's revision; a roll REPLACES it) + the reactive mirror so any consumer (VFX, later) can read the equipped
color's dominant/sequence via `SoulColorRegistry`. Acquisition this phase is an **admin grant command**
(`grantsoulcolor <target> <colorId>`), mirroring how affix `rollpreview` deferred the real economy. The
**weighted gacha roll** (Common/Uncommon/Rare/Double, multi-color combining, the spinner UI) is
explicitly out of scope — it is lootbox/economy territory for a later phase. The pure roll math in the
old `SoulColor` module is preserved as reference for that phase, not ported here.

Soul Color lives **inside the Customization domain** (developer's call), not as a separate service — it
is one more channel on `Appearance` + one more store on `Entitlements`.

## Decision 7 — Hybrid color model: unlockable dye palette + free RGB, per-channel policy

Chosen (developer's call, informed by genre research — see the research appendix). A color channel is a
**tagged union** (Decision 2's `Color`):

- **`{ source = "dye", id }`** — references an entry in `CosmeticRegistry`'s `dye` category, an
  **account-wide unlockable color palette** collected like any other cosmetic (the GW2 dye model — the
  closest precedent to our exact system). Lockable dyes are entitlement-gated; free dyes always
  available. This is the default for most channels: curated, on-theme, monetizable.
- **`{ source = "rgb", r, g, b }`** — a free 0–255 integer triple, allowed only on channels whose
  descriptor opts into free RGB (Decision 10's per-channel `allowFreeRgb`).

The validator enforces both the `[0,255]` range on RGB and the per-channel free-RGB permission, and
resolves a `dye` id to a concrete color at application time. This kills the old 0–255/0–1 scale
ambiguity and folds dyes into the entitlements model instead of a separate mechanism. (ProfileStore
can't hold a `Color3`, so a plain typed table is required regardless.)

## Decision 8 — Appearance is PUBLIC state: the character is the visibility channel, not charm-sync

Unlike every prior slice (inventory/currency/bank are **private** — only the owner's client needs
them), appearance must be visible to **every** player. The research is explicit that the mechanism is
Roblox's native instance replication, not our reactive spine:

- **The character model is the source of truth for what OTHERS see.** The server applies the appearance
  onto the spawned character (clone/weld accessories, set part colors, toggle head-type parts) via the
  Instance-mutation shell (Decision 5); Roblox replicates those instances to all clients automatically.
  No appearance data is sent to other clients through charm-sync.
- **The `appearance` slice on charm-sync is the source of truth for what the OWNER edits/reads** (their
  own customization UI). It is not the visibility mechanism.

They stay consistent because the server applies the slice onto the character on the `observeCharacter`
seam (Decision 5). **Config requirement:** set `StarterPlayer.LoadCharacterAppearance = false` (via the
project's `StarterPlayer` properties) so Roblox does not stamp the player's own Roblox avatar over the
custom rig — with a custom `StarterCharacter`, `LoadCharacterAppearance = true` would fight our rig.

## Decision 9 — Share the pure plan-builder to `ReplicatedStorage`; appearance writes are coarse commits

Decision 5's **pure plan-builder** (resolve `Appearance` + registries → application plan) lives in
`ReplicatedStorage.Shared` so **both** realms call it: the server to drive the Instance-mutation shell,
and the client customization UI (a later phase) to render a **live local preview** as the player edits —
no server round-trip per tweak.

This sets the **coarse-commit contract**: the customization UI edits a *local draft* and writes the
`appearance` slice only on an explicit **commit** ("Apply"), never per-keystroke. That is why a full
server-side reapply on any `appearance` change is acceptable here — appearance reapplication is
expensive (destroy/re-clone/re-weld/recolor), and it must never run per slider-drag. Per-channel
application is a permitted optimization for cheap single-channel setters (e.g. `setSoulColor`), but the
correctness baseline is full-reapply-on-commit. The UI phase must honor the coarse-commit contract.

## Decision 10 — Descriptor-driven channels (data rows, not per-channel code)

To serve the stated reality that customization *will* gain and lose channels over time, the validator
and plan-builder iterate a **channel descriptor table** in `CosmeticRegistry` rather than hand-coding
each channel:

```lua
-- dye/color channels: { key = "belt", rigPartGroup = "Belt Color", allowFreeRgb = false }
-- accessory-like channels: { key = "hair", category = "hair", socket = <attachment>, colorChannels = 1 }
```

Adding a new dye slot or accessory-like cosmetic becomes a **descriptor-row edit** (plus a registry
entry), not new validator/plan-builder/service code. Only genuinely novel mechanics — the Covered/
Uncovered head-type toggle is the one in scope — need bespoke handling outside the descriptor loop, and
those are explicitly the exception, not the rule.

## Decision 11 — Validators (data layer; hold for ANY write path)

- **`validateAppearance(appearance)`** — every non-nil `id`/`pattern`/`texture` is registered in
  `CosmeticRegistry`; every `Color` is well-formed per its tagged union (a `dye` id is registered; an
  `rgb` triple is in `[0,255]` **and** its channel descriptor sets `allowFreeRgb` — Decision 10);
  `headType` is one of the two literals; accessory list length `<= ACCESSORY_SLOTS` and each accessory's
  `colors` length matches its registry metadata; `soulColor`, if set, is a valid `SoulColorRegistry` id.
  **Does not** check ownership — a validator runs on raw slice data and can't see the account scope;
  ownership is enforced at the equip *method* (below), the same split Inventory uses (shape in the
  validator, policy in the service method).
- **`validateEntitlements(entitlements)`** — every stored id is registered and (for cosmetics) actually
  lockable; no free id is redundantly stored.
- **Equip-time ownership gate** — `CustomizationServiceServer`'s equip methods check the category's
  scope policy (Decision 1a) → the right entitlement store → refuse with a specific reason if a lockable
  id isn't owned. This is the one check that needs both slices, so it lives in the service, not the
  per-slice validator.

## Service surface — `CustomizationServiceServer` (new)

```
getAppearance(userId)                       -> Appearance?          -- active slot
getEntitlements(userId)                     -> Entitlements?
equip(userId, channel, selection)           -> (boolean, string?)   -- one typed setter per channel group
setBodyColor(userId, part, color)           -> (boolean, string?)
setHeadType(userId, headType)               -> (boolean, string?)
unlockCosmetic(userId, category, id)        -> (boolean, string?)   -- writes entitlements (account scope today)
grantSoulColor(userId, colorId)             -> (boolean, string?)
setSoulColor(userId, colorId)               -> (boolean, string?)   -- ownership-gated
appearanceOp(userId, fn)                    -> TransactionOperation
```

Exact setter decomposition is a plan-time detail; the shape mirrors Inventory/Equipment (typed methods,
`Guard.userId`, no-profile bail, specific `(ok, reason)` strings, a public `*Op` wrapper).

**Registration:** `appearanceSlice = SliceOwner.registerSlot("appearance", DEFAULT_APPEARANCE, reader,
validateAppearance)` and `entitlementsSlice = SliceOwner.registerAccount("entitlements",
DEFAULT_ENTITLEMENTS, reader, validateEntitlements)`. `dependencies = { "PlayerDataServiceServer" }`.
`PlayerDataConstants.emptySlots()` gains an `appearance = DEFAULT_APPEARANCE` placeholder and the
account template gains `entitlements = DEFAULT_ENTITLEMENTS` (skeleton declares, registration owns — the
seal-time `assertAllSlicesOwned()` pattern from 3b).

## Client facade + reactive state

`CustomizationServiceClient` — thin read facade over `ClientStore.appearance` / `ClientStore.entitlements`
(same shape as `InventoryServiceClient`). Both slices join `SliceManifest.DEFINITIONS` + `ClientStore`
atoms so UI (a later phase) reads them reactively. No client writes (server-authoritative).

## Sub-phase sequencing (keep each PR tight — mirrors 3a/3b/3c)

The full surface is too large for one PR under the 400-line file gate. Proposed split:

- **5a — Foundation + attachment cosmetics + body color.** Two-slice model, three registries (seeded),
  `Appearance`/`Entitlements` types, validators, `CustomizationServiceServer` with the
  `observeCharacter` application seam, and the channels that share the attachment/dye mechanism: hair,
  eyebrows, eyelashes, accessories (with unlock gating), body/dye colors. Client facade + Cmdr equip/
  unlock commands. **This is the vertical slice that proves the architecture end-to-end.**
- **5b — Clothing, backpacks, shoes, head type.** The heavier, most rig-coupled channels
  (`SurfaceAppearance` clothing/backpack patterns + textures, shoe models, Covered/Uncovered facemask
  toggling). Extends `Appearance` + the application plan; no new architecture.
- **5c — Soul Color (store + equip).** `SoulColorRegistry`, the per-slot `appearance.soulColor`
  (a single value a roll replaces), reactive mirror for VFX consumption, `setsoulcolor` admin
  commands. Roll stays deferred.

Each sub-phase is spec-first TDD, its own PR, merge-commit onto `main`.

## Testing (spec-first, the cases that matter)

- Registries: unknown id rejected; lockable-flag lookups; `SoulColorRegistry` multi-color sequence
  composition (pure, deterministic).
- `validateAppearance`: unregistered id, out-of-range color, bad `headType`, over-length accessory list,
  wrong accessory color-channel count, unregistered `soulColor` — each rejected.
- `validateEntitlements`: storing a non-lockable id rejected; unregistered id rejected.
- Equip ownership gate: equipping a lockable cosmetic not owned → refused with a specific reason;
  equipping a free cosmetic → allowed; after `unlockCosmetic`, equip allowed.
- Scope-policy extensibility: the ownership check routes through the category policy — a test flips one
  category's policy to `slot` and asserts the check consults a per-slot store (guards the extensibility
  requirement without building the per-slot store for real).
- Application plan (pure core): an `Appearance` + registries resolve to the expected accessory-mount /
  dye / head-toggle plan; the Instance-mutation shell is exempted (needs a real rig).
- Slot isolation: two slots carry independent `appearance`; `entitlements` is shared (unlock on the
  account shows through both slots).
- Soul Color: `grantSoulColor` adds to the owned set; `setSoulColor` refused when not owned, allowed
  after grant; equipped id resolves to the right dominant color via the registry.

## Deliberately NOT in this phase

- **The Soul Color roll / gacha economy / spinner UI** (Decision 6) — store + equip + admin grant only.
- **HuntingKnife skin** — it's a tool/weapon skin, not body cosmetics; belongs with professions/combat.
- **`AllBlack` special mode** — an event/toggle effect, not a persisted customization channel.
- **Per-slot entitlements** — the model is *extensible* to them (Decision 1a) but every category is
  account-scoped today; no per-slot entitlement store is built until a category actually needs it.
- **Customization UI** — the React customization menu is a later UI-framework phase; this phase ships
  the data layer + admin commands to drive it, exactly as Inventory/Equipment/Bank did.
- **VFX consumption of Soul Color** — this phase exposes the equipped color reactively; typed-ByteNet
  VFX tinting that reads it is the VFX presentation phase.
- **The artist rig model itself** — art, owned in the Studio place (body-scope B). This phase owns only
  the code-side `RigContract` naming convention it binds to.

## Research appendix — genre/platform precedent (2026-07-18)

External research done to pressure-test the decisions rather than trust the old game's shape. Findings:

- **Two-scope model is the modern standard, not a guess.** Account-wide appearance *collection* +
  per-character/outfit *equipped* state is what WoW's Wardrobe, GW2's Wardrobe, and ESO all converged
  on. ESO is a near-exact match: outfit motifs (unlocks) are account-wide while outfit slots (equipped)
  are per-character — validating Decision 1.
- **Manual attachment-welding over `HumanoidDescription:ApplyDescription` is correct for a custom mesh
  rig.** Roblox's docs state `ApplyDescription` assumes it is the *only* thing changing appearance and
  targets standard avatars/catalog assets; for a custom rig whose meshes can't change you must handle
  accessories manually. Our rig is exactly that — validating Decision 5's mechanism and motivating
  Decision 8's `LoadCharacterAppearance = false`.
- **Appearance visibility rides native instance replication, not the reactive spine** — the basis for
  Decision 8 (public vs. private state), which the original draft left implicit.
- **GW2's account-wide unlockable dye collection** is the precedent for the hybrid dye model (Decision
  7): dyes as a collected palette applied to channels, with free RGB where a channel opts in.

Sources: [WoW Appearances/Wardrobe](https://wowpedia.fandom.com/wiki/Appearances) ·
[ESO account-wide outfit motifs vs per-character slots](https://forums.elderscrollsonline.com/en/discussion/402449/is-the-outfit-system-unlocked-motifs-account-wide) ·
[Roblox `HumanoidDescription` docs](https://create.roblox.com/docs/reference/engine/classes/HumanoidDescription) ·
[Applying HumanoidDescriptions to custom rigs (devforum)](https://devforum.roblox.com/t/applying-humanoid-descriptions-to-custom-rigs/2608537) ·
[Roblox server authority model](https://create.roblox.com/docs/projects/server-authority) ·
[MMO cosmetic system comparison](https://mmosworld.com/top-5-best-mmorpg-cosmetic-systems/)
```
