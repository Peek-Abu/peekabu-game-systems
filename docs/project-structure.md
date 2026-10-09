# Project Structure

Where things live in `src/`, how modules are named, and the conventions that let files be *found*
automatically: `*ServiceServer`/`*ServiceClient` discovery, the spec-sibling rule, and where a new
profile slice gets wired in. For *how the pieces are wired together at runtime* (boot sequence,
ServiceController, the data layer, the reactive spine), see [architecture.md](architecture.md); for
the style rules a file must follow once it exists, see [conventions.md](conventions.md).

Code is grouped by **feature** (Currency, Inventory, Animation, ...), not by kind. A feature owns one
folder per realm it has code in, and a module's place is decided by the job it does. The rules below
are enforced by `scripts/python/check_pr_rules.py`.

Rojo assembles the DataModel from `src/` per [default.project.json](../default.project.json).
`Workspace`, `Lighting`, and `ServerStorage` are deliberately **not** mounted; see the deployment
model in [AGENTS.md](../AGENTS.md#deployment-model--read-before-touching-ci). Package realms
(Wally-managed, not source you edit) are `Packages/` and `DevPackages/` under `ReplicatedStorage`
and `ServerPackages/` under `ServerScriptService`; see [tech-stack.md](tech-stack.md).

---

## Realm roots

Every feature gets one folder per realm it has code in:

| Realm | Root | Who can require it |
|---|---|---|
| shared | `ReplicatedStorage/Shared/Features/<Feature>/` | server and client |
| client | `ReplicatedStorage/Client/Features/<Feature>/` | client only |
| server | `ServerScriptService/Features/<Feature>/` | server only |

A feature with no code in a realm has no folder there (Item is shared only).

---

## Outside features

Only these live outside a `Features/` root:

| Place | What goes there |
|---|---|
| `ReplicatedStorage/Shared/Core/` | the framework and typed wrappers around libraries: ServiceController, Logger, Guard, SignalTyped |
| `ServerScriptService/Core/` | server framework: ProfileStoreTyped, `Net/RequestHandler`, `Testing/SpecRoots` |
| `ReplicatedStorage/Shared/Data/` | types every feature reads: PlayerDataTypes, PublicPlayerTypes |
| `ReplicatedStorage/Client/UI/` | the React UI tree (layers, components, hooks, scenes); conventions in [Naming](#naming) |
| `ServerScriptService/Commands/` | Cmdr commands; naming in [Naming](#naming) |
| `ReplicatedStorage/Shared/CmdrTypes/` | Cmdr argument types |
| entry scripts | `ServerHandler.server`, `TestRunner.server`, `ClientHandler.client`, and `StarterCharacterScripts/Animate.client` (the engine skips inserting its own Animate script only when the name matches) |

Core and Data are closed lists. A module joins Core only if it is framework every feature uses, or a
typed wrapper around a library; anything owned by one feature goes in that feature.

---

## Inside a feature

The feature's service sits at the feature root. Everything else sits in exactly one of seven
subfolders, one level deep. Each subfolder answers one question:

| Subfolder | Question it answers | Examples |
|---|---|---|
| `Data/` | What exists? | constants, catalogs looked up by id, type definitions, asset id lists |
| `Net/` | How does it travel? | packet definitions, byte codecs, senders, receivers |
| `Rules/` | Is it allowed or valid? | validators, permission rules, boot-time setup checks |
| `State/` | What is true now? | Charm stores, bookkeeping tables, object pools |
| `Utils/` | What is the answer? | pure helpers and game maths |
| `Systems/` | What runs or changes things? | per-frame loops, event handlers, anything that changes what it doesn't own |
| `Testing/` | What helps the tests? | test harnesses (specs stay beside the module they test) |

A subfolder exists only when the feature has a module for it; empty subfolders are not created.

**Telling Utils, State and Systems apart.** Ask in order; the first yes wins:

1. Does it act on its own (runs every frame, or reacts to an event it subscribed to), or change
   something it doesn't own? Then it is **Systems**.
2. Does it remember anything between calls? Then it is **State** (it may change only what it owns,
   and only when called).
3. Otherwise it remembers nothing and changes nothing, so it is **Utils**.

Example, the Inventory feature:

```
ReplicatedStorage/Shared/Features/Inventory/
  Rules/InventoryContainerRules
  Utils/InventoryPlacementUtils
  Utils/InventoryUtils
ReplicatedStorage/Client/Features/Inventory/
  InventoryServiceClient
ServerScriptService/Features/Inventory/
  InventoryServiceServer
```

---

## Rules

1. **A module belongs to the feature whose job it does,** not the feature it happens to run on.
   A system that plays an emote when a pet is petted belongs to Animation if it is animation logic,
   even if only the pet feature calls it.
2. **One service per feature per realm.** A second service needs the developer's approval and its
   reason recorded in this file and in the check's exceptions table. There are none today.
3. **A new subfolder kind needs at least three modules that share it, and the developer's
   approval.** Both, not either. Two modules that look alike go in the existing subfolder that fits
   best. (This is why there is no `Signals/` or `Hooks/`: most Systems modules that react to events
   do more than react.) An approved kind is added to this file, the `module-placement` skill, and the
   check's allowed list in the same change.
4. **A new role word also needs the developer's approval,** for the same reason: the vocabulary only
   stays small if adding to it is a decision, not a side effect.
5. **The top folder is `Features`.** `Systems` is a subfolder name, and `Services` named only one
   kind of module.
6. **Specs stay siblings.** `<Name>.spec.luau` sits next to `<Name>.luau` wherever it lives. A spec
   that tests no single module (an end-to-end load test) lives in its feature's
   `Testing/` folder with a `Harness` name.
7. **Requires use full addresses; a folder used three or more times gets one variable.** Every
   `require` names its module from the realm root. When a file requires **three or more** modules
   from one feature folder, it names that folder once and requires through it. Fewer than three stay
   full addresses, even when a line wraps: a variable is for real repetition, not for one long line.

   ```lua
   local AnimationShared = ReplicatedStorage.Shared.Features.Animation

   local AnimationEvents = require(AnimationShared.Net.AnimationEvents)
   local AnimationRegistry = require(AnimationShared.Data.AnimationRegistry)
   local AnimationTypes = require(AnimationShared.Data.AnimationTypes)
   ```

   The variable is `<Feature><Realm>` (`Shared`, `Client`, `Server`): `AnimationShared`,
   `InventoryShared`, `ItemShared`. The one relative require is a spec requiring its own module
   (`script.Parent.X` from `X.spec`); the UI tree keeps the relative requires inside itself.

---

## Naming

### Feature modules: `<Feature><What><RoleWord>`

Every feature module name starts with its feature and ends with a role word allowed in its
subfolder. `<What>` is optional when the feature has only one module of that role (`AnimationEvents`,
`TitleRegistry`).

| Folder | Role words | Meaning |
|---|---|---|
| `Data/` | Constants · Registry · Types · Assets | tuning values · a catalog looked up by id · type definitions only · asset id lists |
| `Net/` | Events · Codec · Sender · Receiver | packet definitions · our own byte packing (high-volume traffic only) · decides what to send · takes in and checks what arrives |
| `Rules/` | Rules · Check | decides whether something is allowed or valid · checks the place's setup at boot and reports problems |
| `State/` | Store · Tracker · Pool | Charm state others subscribe to · plain bookkeeping nothing subscribes to · spare objects kept for reuse |
| `Utils/` | Utils · Formulas | pure helpers, plans, diffs · game maths |
| `Systems/` | System | runs and changes the game |
| `Testing/` | Harness | test tooling |
| root | ServiceServer · ServiceClient | the feature's service |

**Feature names** (singular, PascalCase): Admin, Analytics, Animation, Badge, Camera, Carry, Currency, DailyReward, Death, Debugger, Entitlement, Input,
Interaction, Inventory, Item (the item catalog), Leaderstat, Loot, Marketplace, Npc, PlayerData, Round, Setting,
Sound, StateSync, Title, UI, Vfx, Voice. A game adds its own (Pet, Shop, ...).

**Networking stays on ByteNet.** Features use ByteNet's typed fields. A `Codec` (our own byte packing
into `ByteNet.buff`) is written only for genuinely high-volume traffic (bit-packed per-frame records);
there is no custom networking library.

**Not renamed:** Core modules, Data modules, entry scripts and names the engine fixes.

### UI tree

The UI tree keeps its own folders. Convention:

- Components are named for what they show (`LogsPanel`, `HudRoot`).
- Hooks are `use<Thing>` in `Hooks/`; a hook only one screen uses may sit beside that screen.
- View models end in `ViewModel`, scenes are `<Feature>Scene`, stores end in `Store`, constants are
  `UI<Thing>Constants`.

### Admin commands

Commands live in `ServerScriptService/Commands/` (Cmdr registers them from one folder) and are
named **feature-first**: `CurrencyAdd`, `InventoryGiveItem`, `TitleAward`. Each has a definition file
and a `Server` half. The name an admin types is the file name in lower case (`currencyadd`), so the
file, the definition's `Name` field and the typed command always match. No alias keeps an old command name; aliases that remain are short forms (for example `anim-report`).

---

## Service discovery

`ServerHandler.server.luau` and `ClientHandler.client.luau` don't have a manual registration list.
`ServerHandler` walks `ServerScriptService.Features` and `ClientHandler` walks
`ReplicatedStorage.Client.Features`. Each `require()`s every `ModuleScript` whose name contains
`Service` and ends in `Server` (server boot) or `Client` (client boot), then calls
`ServiceController:register()` on it. A service is found purely by filename, so **renaming a service
file off that pattern unregisters it** (it will neither init nor start). The boot handlers `warn` on
a near-miss (a name containing `Service` without the realm suffix), but a rename that drops
`Service` entirely is fully silent.

The reference pair to copy when porting a new domain is `CurrencyServiceServer` /
`InventoryServiceServer` (+ their clients); full rationale in
[AGENTS.md: Architecture in one screen](../AGENTS.md#architecture-in-one-screen).

---

## Where does my new code go?

1. **Which feature does this job?** The feature whose job it is, not the one it runs inside. A new
   feature needs a name: singular, PascalCase.
2. **Which realm?** Needed by both server and client: shared. Client only: client. Server only:
   server.
3. **Is it the feature's service?** One per feature per realm, at the feature root:
   `<Feature>ServiceServer` / `<Feature>ServiceClient`. A second one needs the developer's approval.
4. **Otherwise, which subfolder?** Data (what exists), Net (how it travels), Rules (allowed or
   valid?), Testing (test tools). Otherwise ask, in order: acts on its own or changes what it
   doesn't own: Systems; remembers anything: State; otherwise: Utils.
5. **Name it** `<Feature><What><RoleWord>` with a role word its subfolder allows.
6. **Nothing fits?** Stop and ask. A new subfolder kind needs three modules that share it and the
   developer's approval; a new role word needs approval.
7. **Write its spec** beside it, or add it to `SpecRoots.EXEMPT_MODULES` with a reason.
8. Run `python3 scripts/python/module_map.py --write`.

---

## The spec-sibling rule, and where the roots live

Every first-party module needs a `<Name>.spec.luau` sibling in the same folder, or an explicit,
justified exemption. This isn't just a convention — it's enforced at test-run time by
[`SpecRoots.luau`](../src/ServerScriptService/Core/Testing/SpecRoots.luau):

- **`SpecRoots.get()`** returns the fixed list of roots TestEZ scans (both the Studio runner and the
  CI runner pass exactly this list — TestEZ does not scan recursively from `src`):
  `Shared/Core`, `Shared/Data`, `Shared/Features`, `Client`, `ServerScriptService/Commands`,
  `ServerScriptService/Core`, `ServerScriptService/Features`. A spec
  placed outside these roots would silently never run, so a second guard
  (`assertAllSpecsCovered`) sweeps every mounted container and **errors** on any `*.spec` module
  it finds outside them.
- **`SpecRoots.assertAllModulesSpecced`** is the inverse: it **fails the build** if a first-party
  module under a scanned root has no `.spec` sibling and isn't listed (with a reason) in
  `SpecRoots.EXEMPT_MODULES`.

Adding a new spec location = add the root to `SpecRoots.get()` — one edit covers Studio and CI. Full
writing/running guidance is in [testing.md](testing.md).

---

## Adding a profile slice

The recipe for wiring a new replicated profile slice into the reactive spine (currency, inventory,
titles are the existing examples) is **not duplicated here** — it lives, and should be
edited, at exactly one place: the header comment of
[`StateSyncSliceRegistry.luau`](../src/ReplicatedStorage/Shared/Features/StateSync/Data/StateSyncSliceRegistry.luau)
(`ReplicatedStorage/Shared/Features/StateSync/Data/StateSyncSliceRegistry.luau`), which is also the single declaration site the
recipe describes. See also
[conventions.md: Adding a service that owns a profile slice](conventions.md#adding-a-service-that-owns-a-profile-slice)
for the fuller walkthrough (public methods, `Guard` validation, transactions) and
[architecture.md: Reactive state](architecture.md#reactive-state) for how the pieces fit together at
runtime.

---

## Module map

Generated by `scripts/python/module_map.py --write`; `check.sh` and CI fail when it is stale.

<!-- module-map:start -->

### Admin

| Realm | Module |
|---|---|
| shared | `Rules/AdminRules` |
| client | `AdminServiceClient` |
| server | `AdminServiceServer` |

### Analytics

| Realm | Module |
|---|---|
| server | `AnalyticsServiceServer` |
| server | `Rules/AnalyticsRules` |

### Animation

| Realm | Module |
|---|---|
| shared | `Data/AnimationActionRegistry` |
| shared | `Data/AnimationLocomotionRegistry` |
| shared | `Data/AnimationRegistry` |
| shared | `Data/AnimationTypes` |
| shared | `Net/AnimationEvents` |
| shared | `Systems/AnimationPlayerEngineSystem` |
| shared | `Systems/AnimationPlayerSystem` |
| client | `AnimationServiceClient` |
| client | `Systems/AnimationLocomotionHumanoidSystem` |
| client | `Systems/AnimationLocomotionSystem` |
| server | `AnimationServiceServer` |
| server | `State/AnimationGrantTracker` |
| server | `Systems/AnimationActionGrantSystem` |

### Badge

| Realm | Module |
|---|---|
| shared | `Data/BadgeRegistry` |
| server | `BadgeServiceServer` |
| server | `State/BadgeAwardTracker` |

### Camera

| Realm | Module |
|---|---|
| client | `CameraServiceClient` |
| client | `Data/CameraConstants` |
| client | `Data/CameraTypes` |
| client | `State/CameraEffectTracker` |
| client | `State/CameraModeTracker` |
| client | `Utils/CameraMotionFormulas` |

### Carry

| Realm | Module |
|---|---|
| shared | `Data/CarryConstants` |
| shared | `Data/CarryRegistry` |
| shared | `Data/CarryTypes` |
| shared | `Net/CarryEvents` |
| shared | `Utils/CarryFormulas` |
| client | `CarryServiceClient` |
| server | `CarryServiceServer` |
| server | `State/CarryHoldTracker` |

### Currency

| Realm | Module |
|---|---|
| shared | `Data/CurrencyConstants` |
| shared | `Utils/CurrencyUtils` |
| client | `CurrencyServiceClient` |
| server | `CurrencyServiceServer` |

### DailyReward

| Realm | Module |
|---|---|
| shared | `Data/DailyRewardConstants` |
| shared | `Net/DailyRewardEvents` |
| shared | `Rules/DailyRewardRules` |
| client | `DailyRewardServiceClient` |
| server | `DailyRewardServiceServer` |

### Death

| Realm | Module |
|---|---|
| shared | `Data/DeathConstants` |
| shared | `Data/DeathTypes` |
| shared | `Rules/DeathSpectateRules` |
| shared | `Utils/DeathRagdollUtils` |
| client | `DeathServiceClient` |
| server | `DeathServiceServer` |
| server | `State/DeathCreditTracker` |

### Debugger

| Realm | Module |
|---|---|
| shared | `Net/DebuggerEvents` |
| client | `DebuggerServiceClient` |
| client | `State/DebuggerStore` |
| server | `DebuggerServiceServer` |

### Entitlement

| Realm | Module |
|---|---|
| shared | `Data/EntitlementRegistry` |
| shared | `Data/EntitlementTypes` |
| shared | `Rules/EntitlementRules` |
| client | `EntitlementServiceClient` |
| server | `EntitlementServiceServer` |

### Input

| Realm | Module |
|---|---|
| client | `Data/InputActionRegistry` |
| client | `Data/InputConstants` |
| client | `Data/InputTypes` |
| client | `InputServiceClient` |
| client | `Rules/InputBindingRules` |
| client | `State/InputActionTracker` |
| client | `State/InputContextTracker` |
| client | `Systems/InputControlsSystem` |

### Interaction

| Realm | Module |
|---|---|
| shared | `Data/InteractionConstants` |
| shared | `Data/InteractionRegistry` |
| shared | `Data/InteractionTypes` |
| client | `InteractionServiceClient` |
| server | `InteractionServiceServer` |
| server | `Rules/InteractionRules` |
| server | `State/InteractionCooldownTracker` |

### Inventory

| Realm | Module |
|---|---|
| shared | `Rules/InventoryContainerRules` |
| shared | `Utils/InventoryPlacementUtils` |
| shared | `Utils/InventoryUtils` |
| client | `InventoryServiceClient` |
| server | `InventoryServiceServer` |

### Item

| Realm | Module |
|---|---|
| shared | `Data/ItemConstants` |
| shared | `Data/ItemContentRegistry` |
| shared | `Data/ItemRegistry` |

### Leaderstat

| Realm | Module |
|---|---|
| server | `Data/LeaderstatRegistry` |
| server | `LeaderstatServiceServer` |

### Loot

| Realm | Module |
|---|---|
| shared | `Data/LootRegistry` |
| shared | `Data/LootTypes` |
| shared | `Rules/LootRules` |

### Marketplace

| Realm | Module |
|---|---|
| shared | `Data/MarketplaceConstants` |
| shared | `Data/MarketplaceRegistry` |
| shared | `Data/MarketplaceTypes` |
| client | `MarketplaceServiceClient` |
| server | `MarketplaceServiceServer` |
| server | `Rules/MarketplaceReceiptRules` |
| server | `State/MarketplacePassTracker` |
| server | `Systems/MarketplaceReceiptSystem` |

### Npc

| Realm | Module |
|---|---|
| server | `Data/NpcConstants` |
| server | `Data/NpcRegistry` |
| server | `Data/NpcTypes` |
| server | `NpcServiceServer` |
| server | `Rules/NpcBrainRules` |
| server | `Rules/NpcPathRules` |
| server | `Rules/NpcSenseRules` |
| server | `State/NpcRosterTracker` |
| server | `Systems/NpcBehaviourSystem` |
| server | `Systems/NpcMoverSystem` |

### PlayerData

| Realm | Module |
|---|---|
| server | `Data/PlayerDataConstants` |
| server | `PlayerDataServiceServer` |
| server | `Systems/PlayerDataMigrationSystem` |
| server | `Systems/PlayerDataSliceSystem` |
| server | `Utils/PlayerDataPathUtils` |

### Round

| Realm | Module |
|---|---|
| shared | `Data/RoundConstants` |
| shared | `Data/RoundTypes` |
| shared | `Utils/RoundSnapshotUtils` |
| client | `RoundServiceClient` |
| server | `RoundServiceServer` |
| server | `Rules/RoundPhaseRules` |
| server | `State/RoundRunTracker` |
| server | `Utils/RoundContainerUtils` |

### Setting

| Realm | Module |
|---|---|
| shared | `Data/SettingConstants` |
| shared | `Data/SettingRegistry` |
| shared | `Data/SettingTypes` |
| shared | `Net/SettingEvents` |
| shared | `Rules/SettingRules` |
| shared | `Utils/SettingKeybindUtils` |
| client | `SettingServiceClient` |
| server | `SettingServiceServer` |

### Sound

| Realm | Module |
|---|---|
| shared | `Data/SoundConstants` |
| shared | `Data/SoundRegistry` |
| shared | `Data/SoundTypes` |
| shared | `Net/SoundEvents` |
| shared | `Utils/SoundFormulas` |
| client | `SoundServiceClient` |
| client | `State/SoundVoiceTracker` |
| server | `SoundServiceServer` |

### StateSync

| Realm | Module |
|---|---|
| shared | `Data/StateSyncConstants` |
| shared | `Data/StateSyncSliceRegistry` |
| client | `State/StateSyncClientStore` |
| client | `StateSyncServiceClient` |
| server | `State/StateSyncPublicPlayerStore` |
| server | `State/StateSyncServerStore` |
| server | `State/StateSyncWorldStore` |
| server | `StateSyncServiceServer` |

### Title

| Realm | Module |
|---|---|
| shared | `Data/TitleGeneralRegistry` |
| shared | `Data/TitleRegistry` |
| shared | `Data/TitleTypes` |
| shared | `Net/TitleEvents` |
| shared | `Rules/TitleRequestRules` |
| shared | `Rules/TitleSliceRules` |
| client | `TitleServiceClient` |
| server | `TitleServiceServer` |

### UI

| Realm | Module |
|---|---|
| client | `Data/UIAssets` |
| client | `UIServiceClient` |

### Vfx

| Realm | Module |
|---|---|
| shared | `Data/VfxAtmosphereRegistry` |
| shared | `Data/VfxConstants` |
| shared | `Data/VfxRecipeRegistry` |
| shared | `Data/VfxTypes` |
| shared | `Net/VfxEvents` |
| shared | `Utils/VfxFormulas` |
| client | `State/VfxScreenTracker` |
| client | `VfxServiceClient` |
| server | `VfxServiceServer` |

### Voice

| Realm | Module |
|---|---|
| shared | `Data/VoiceConstants` |
| shared | `Data/VoiceTypes` |
| shared | `Rules/VoiceRoutingRules` |
| client | `State/VoiceWiringTracker` |
| client | `VoiceServiceClient` |
| server | `VoiceServiceServer` |

### Core

| Realm | Module |
|---|---|
| shared | `Guard` |
| shared | `Logger` |
| shared | `ServiceController` |
| shared | `SignalTyped` |
| server | `Net/RequestHandler` |
| server | `ProfileStoreTyped` |
| server | `Testing/SpecRoots` |

### Data

| Realm | Module |
|---|---|
| shared | `PlayerDataTypes` |
| shared | `PublicPlayerTypes` |
| shared | `WorldTypes` |

<!-- module-map:end -->
