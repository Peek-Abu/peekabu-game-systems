# Venture Refactor — Roadmap

> Living document. Update the status column as phases land; add rows as systems are discovered.
> Each phase follows the same cycle: design spec (`docs/superpowers/specs/`) → implementation plan
> (`docs/superpowers/plans/`) → subagent-driven implementation → per-task + whole-branch review → PR.

## Governing principles

- **Vertical slices.** Each phase delivers ONE domain end-to-end: profile slice + validator +
  service (server/client) + charm-sync + specs (+ UI where it's the point). Never "all slices
  first, then all services."
- **Old code is evidence, not source.** The live game (`VentureTestingPlace`, read-only) tells us
  *what* a system needs to do; every schema and structural choice is re-derived from first
  principles at port time. This is emphatically not a straight refactor.
- **Schema changes are free until launch.** Data is wiped at cutover; no migrations are written
  pre-launch. Be aggressive about fixing old mistakes.
- **Foundation and leaves first, combat core LAST.** Combat is the hub with 10+ dependencies and
  needs a genuine server-authoritative hit-detection redesign, not a port.

## Phases

### Completed

| Phase | Scope | Landed |
|---|---|---|
| 0 | Repo/toolchain/CI/deploy model (code-only Rojo, validation-only CI, manual Studio deploy) | pre-PR |
| 1 | Slot foundation — account/slots profile shape, slot-aware PlayerDataSliceSystem, slot switch, epoch hardening, jaku currency | PR #1 |
| 2 | Stats & progression — `{ totalXp, investments }`, derived level/pools, Humanoid application | PR #2 |
| — | Infra: CI gates (casts/trailers/file-length/project-rules), Qodo config, data-layer boundary hardening | PRs #3–4 |
| 3a | Items & inventory — tagged item definitions, `{ items }` slice, atomic account-scoped uid minting, per-kind caps | PR #5 |
| 3b | Equipment & gear stats — extensible slot registry, atomic equip/swap/unequip (container-owns-item), fixed `statBonuses` into `StatFormulas.derive`, mirror-subscription stat reapplication, seal-time slice-ownership assert | PR #6 |
| Docs interlude | Committed the agent docs + restructured the doc hierarchy; debugger observability + data-layer polish | PR #7 |
| 3c | Affix rolling — two-tier model (Tier 2 pool affixes BUILT, the `Equipment.Boosts` successor; Tier 1 base-stat variance RESERVED for combat); absolute storage; flat rarity-independent single-affix drop (Terraria-style); lenient-on-retired-keys validator | PR #8 |
| 4 | Bank (per-slot stash) — a second slot-scoped container holding items AND currency; atomic deposit/withdraw ↔ inventory/currency (the equip/unequip 2-op pattern); extracted shared `InventoryContainerRules`/`InventoryPlacementUtils` from Inventory (parameterized cap policy); whole-holding item transfers; flat total-entry cap | PR #9 |
| 4-UI | Bank SCREEN — the client half of Phase 4, which shipped the whole server-authoritative bank and left it reachable only by admin commands. Packets + listeners + client verbs, the two-container screen, and the currency strip. Design: [`docs/superpowers/specs/2026-08-06-bank-ui-design.md`](superpowers/specs/2026-08-06-bank-ui-design.md). Built on Phase 7's framework, so it lands with it | with PR for 7 |
| 5a | Customization foundation — the two-scope slice model (per-slot `appearance` + account-wide `entitlements`, extensible per-category scope policy); map-keyed `Appearance` replacing the old untyped blob; `CustomizationCosmeticRegistry` (catalog + channel descriptors carrying the rig binding); pure validation + plan-builder / spec-exempt Instance shell split; `observeCharacter` application seam; hair/eyebrows/eyelashes, 3 accessory slots, body-color channels; client facade + admin commands | PR #10 |
| 5b | Customization surface — head type (Covered/Uncovered) with rig-part visibility; hair↔head-type compatibility enforced CROSS-FIELD by the data-layer validator (stronger than a service gate) with auto-substitution so bald is never a resting state; clothing/backpack surface channels (`SurfaceAppearance` patterns + `Texture` ids, per-channel art folders); Soul Color as a single per-slot value; client facade + registry-derived Cmdr enums. Four review passes fixed 10 bugs, all in the Instance-application layer or the command boundary | PR #11 |
| 5c | Customization asset pipeline, mounting & fit — owned mount (name-based socket lookup at any depth + `RigidConstraint`, replacing `Humanoid:AddAccessory`, rig-redo-proof); purpose-grouped asset folders with explicit non-recursive lookup; boot-time art conformance checker that REPORTS rather than asserts; shoes as a plain multi-socket mount; per-cosmetic offsets + live-tuning command; retired-cosmetic validator leniency; `--!strict` across the `CmdrTypes` | PR #12 |
| 6 | Animation system — a NEW system, not a port (census: 81 scripts loading animations, 445 `Animation` instances as tree data, 6+ id sources, two diverged `Animate` forks). Typed per-domain registry with a composed index and a **CI gate banning animation ids outside it**; `AnimationPlayerSystem` owning all track lifecycle (load-once cache, handles, owned cleanup); **own `AnimationLocomotionSystem` replacing the forked Roblox `Animate` outright**, with a pose API left as the seam for the Movement phase; interruption class declared per entry; network-owner playback split with a typed ByteNet packet for server-initiated requests; spawn-time locomotion load, lazy everything else, dead ids reported not fatal. ⚠ `Workspace.Retargeting` must stay `Disabled` — now owned by `default.project.json`; check it FIRST if poses ever look wrong | PR #13 |

### In flight

| Phase | Scope | Status |
|---|---|---|
| 7 | UI framework — a NEW system (census: 21 top-level `ScreenGui`s, 14 imperative Knit controllers, a 2,574-descendant `GUI` mega-container holding 30 nested `ScreenGui`s, and a half-adopted `UIManager`/`UIRegistry`/`UIContexts` layer that 0/14 UI controllers register with while 18 non-UI modules drive it). React-lua replaces the hand-rolled reconciler outright; one React root per typed **layer** (the `ResetOnSpawn` direct-child-of-PlayerGui constraint made structural); visibility **derived** from Charm atoms, never commanded; a **scene stack** subsuming the four hardcoded `ExclusiveSets` and giving Escape a generic pop; the world-suppression contract as one **refcounted declarative record** with registration seams for the unbuilt Input and Camera systems; pure view-model + dumb component split so the spec-exemption list stops growing per file; CI gates on the three worst anti-patterns. Proving set is deliberately two-class: Inventory (panel) + Vitals (HUD). **Extended in flight to a THIRD screen, the Bank**, because it is the case the framework was designed around and the only one that exercises it: `SceneRegistry` names two co-visible container panels as the reason scenes exist, and `ItemGrid` was written container-agnostic against a bank that did not exist yet. Both claims held — the shared surface became `ContainerPanel`, rendered once by the inventory and twice by the bank — and the second container immediately found a real bug the first never could (a stackable's display key is its itemType, so the same item in two containers collided) | Built; in review |

### Systems inventory — ✅ discovery pass DONE (2026-07-17)

**The authoritative inventory is [`docs/old-game-systems-inventory.md`](old-game-systems-inventory.md)**
— a full read-only walk of `VentureTestingPlace` (~47 systems found; live module/line counts,
couplings, and port notes per system). The tables below are the roadmap-level summary; the
inventory doc is the detail. The discovery pass found **24 systems that previous versions of this
roadmap (reconstructed from memory) did not mention at all.**

**Gameplay domains (each its own spec→plan→implement cycle; order TBD):**

| Domain | Notes |
|---|---|
| Customization | Character appearance; account-scoped entitlements vs per-slot state to be decided at design time |
| Skills | 43 per-skill modules keyed by short codes, BindableFunction hub; `IsSkill` item flags confirmed live — re-derive, don't port |
| Quests | Old quest items (`QuestItem` flags, message-in-bottle chains) confirmed in item data |
| Titles | Pure display-metadata registry (`Shared/Features/Title/Data/`, composed like Animations); account-wide `titles.earned` + slot-scoped `equippedTitle` slices with data-layer validators (lenient-on-retired, hard-on-malformed); `TitleServiceServer` award/revoke/equip (revoke clears equipped atomically across both slices); ByteNet equip request + client read facade; Cmdr `titleaward`/`titlerevoke`/`titleequip` behind the allowlist. Deliberately NOT: display integration (waits on UI framework #14), award automation, rarity tiers | Implemented through plan Tasks 1–10 (2026-08-25); awaiting Studio verification, then PR |
| Arena | ~13 modules incl. cross-server MessagingService score sync; item `ArenaAllowed` permission tables confirmed live |
| Professions | Fishing rod exists in old item data (`IsSkill`, fishing) |
| Mutations | ⚠ the only LIVE copy of mutation definitions is `ServerStorage.MutationDefinitions_MONOLITH_BACKUP` — the mounted copy is an empty stub (see cutover risks) |
| Emotes | Old game had an `Emotes` inventory bucket — will NOT be an inventory kind here; own domain |
| Trading | Deferred from 3a; inherits the stable-uid contract |
| Hotbar / consumable quickslot | Deferred from 3b; container-owning domain — needs combat's "use" verb |
| **Guilds** (was missing) | Discovered 2026-07-17 |
| **Parties** (was missing) | Discovered 2026-07-17 |
| **Mailbox / gifting** (was missing) | Discovered 2026-07-17 |
| **Bounty / Grudge** (was missing) | Discovered 2026-07-17 |
| **Marketplace / Shop** (was missing) | Gamepasses + dev products — MONETIZATION; cutover keeps the products, this system must exist at launch |
| **Mounts / Taming** (was missing) | Discovered 2026-07-17 |
| **Labyrinth ("Eyes") stealth minigame** (was missing) | Discovered 2026-07-17 |
| **Cleansing** (was missing) | Discovered 2026-07-17 |
| **Doors / world-locks** (was missing) | Discovered 2026-07-17 |
| **Chests & Lootboxes + DropTable economy** (was missing) | Discovered 2026-07-17 |
| **NPCs & Dialogue** (was missing) | Discovered 2026-07-17 |
| **Tutorial / onboarding** (was missing) | Discovered 2026-07-17 |
| **Spectating** (was missing) | Discovered 2026-07-17 |
| **Chat** (was missing) | Discovered 2026-07-17 |
| **Social / friends** (was missing) | Discovered 2026-07-17 |
| **Zones** (was missing) | Discovered 2026-07-17 |
| **Weather** (was missing) | Discovered 2026-07-17 |
| **Soul Color** (was missing) | Discovered 2026-07-17 |
| **Encryption / dialogue puzzle minigame** (was missing) | Discovered 2026-07-17 |

**Presentation & infrastructure track (cross-cutting; most must exist BEFORE combat, since combat
consumes all of them):**

| System | Notes |
|---|---|
| Sound handling | Old game mixes per-weapon sound utilities (`WeaponSoundUtilities`) into gameplay code — extract a proper service/registry |
| VFX handling | Old game ships untyped `EffectFire:FireAllClients({...})` arrays — replace with typed ByteNet packets (the recorded migration #3) |
| Animation handling | Asset-id registry + playback service |
| UI framework / refactor | React-lua provisioned (Debugger overlay is the reference); old `UIControllers` tree is large |
| Camera handling | Old game has camera systems (`CameraWrapper` under PlayerModule customizations) |
| Models/asset registry | Registry-module pattern (like `ItemRegistry`) for equipment models, customization parts, mutation visuals, skill VFX |
| Input handling | Old `InputManager`/keymaps tree |
| **Character replication** | Custom replication with client-only bodies, decided by a spike (`docs/superpowers/specs/2026-09-22-character-replication-design.md`, Verdict 2026-09-30). Phases R1–R7: R1 core library (codec, interpolator, render clock, send policy, harness as acceptance spec) — plan `docs/superpowers/plans/2026-09-30-character-replication-r1-core-library.md`; R2 bodies on screen (client-only bodies, uplink through RequestHandler, encode-once fan-out, pooled puppets, public slice, lifecycle rewires) — plan `docs/superpowers/plans/2026-10-01-character-replication-r2-bodies-on-screen.md`, stacked with R3–R5 (merged together once R5 is verified); results are compared with the saved scorecard; R3 animation and actions (puppet locomotion from the movement records, server-granted actions as timed body state with replay on enter, layered grants, puppet animation LOD, the long-fall pose fix) — plan `docs/superpowers/plans/2026-10-02-character-replication-r3-animation.md`; R4 appearance; R5 chat and voice; R6 player collision (capsule blockers welded into puppets, solid within 20 studs, slide-off; the size table is the anti-cheat contract) — spec `docs/superpowers/specs/2026-10-08-character-replication-r6-collision-design.md`, plan `docs/superpowers/plans/2026-10-08-character-replication-r6-collision.md`; R7 lag compensation (with the combat core). Anti-cheat is its own phase consuming this system's hooks, and must land before cutover. Movement / Traversal builds on R2; Ragdoll (its own system) uses the record's ragdoll variant. |
| **Movement / Traversal** (was missing) | 20-module parkour system — the largest missing item; own phase |
| **Ragdoll** (was missing) | Discovered 2026-07-17 |
| **Death handling** (was missing) | Discovered 2026-07-17 |
| **Height / fall damage** (was missing) | Single largest module found (1,766 lines) — decompose, don't port |
| **Character rig config** (was missing) | Discovered 2026-07-17 |

### Cutover risks found by the discovery pass

**Added 2026-07-20:** `ReplicatedStorage` now sets `$ignoreUnknownInstances` (it must, or `rojo serve`
deletes the customization art under `Assets/` — the silent failure that cost a debugging round in 5b),
so a cutover publish will **no longer prune the old game's `ReplicatedStorage` folders** either
(`Effects`, `Events`, `Modules`, `UI`, `Skills`, `InventoryItems`, …). Those join the manual-cleanup
list below. `ServerScriptService` is unaffected and still prunes.

28 scripts live in unmounted containers (15 `Workspace`, 13 `ServerStorage`) that a cutover publish
will NOT delete. Most are dead backups, but two are LIVE gameplay data:
- `Workspace.Entities.Mobs.*.Configs` — 13 live mob-AI config modules.
- `ServerStorage.MutationDefinitions_MONOLITH_BACKUP` — the ONLY live copy of mutation data.
Both must be ported (or consciously relocated) before cutover, and the dead backups cleaned
manually — see the inventory doc's unmounted-containers table.

### Last

| Phase | Scope |
|---|---|
| Combat core | The hub: weapons/damage/status effects/blocking/enchantment effects, server-authoritative hit detection (a redesign, not a port — old code trusts the client with target + multiplier). Consumes: equipment, stats, sound, VFX, animation, hotbar |
| Cutover | `rojo serve` into the live art-bearing place + Publish from Studio. Deletes old Knit scripts in mounted containers (intended), preserves art in unmounted ones. Old data wiped (ProfileStore keys differ — old data simply never read). Watch for old logic hiding in unmounted containers |

## Standing deferrals attached to future phases

- Weapon subtypes / dual-wield / two-handed slot assignment → with combat (the slot split is
  meaningless without subtype rules).
- Transmog / enchantments / set bonuses → post-equipment; note the old `chambered` 4-piece set
  (`Set = "chambered"`) as the set-bonus reference case.
- Item leveling / evolutionary weapons → named future extension (optional `level: number?` on the
  relevant kinds when designed).
- Provenance display ("crafted by X") → explicit field stamped at mint, never parsed from uid.
