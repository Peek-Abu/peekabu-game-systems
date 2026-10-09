# Module Layout and Placement — Design

**Issue:** [Peek-Abu/venture-game-systems#37](https://github.com/Peek-Abu/venture-game-systems/issues/37)
**Status:** design agreed in brainstorming (2026-10-05 to 2026-10-07); this written spec awaits review.
**Lands:** on its own branch based on R5's head, merged after R2–R5 (#29, #31, #34, #38).
**Companion page:** [Venture module layout](https://claude.ai/artifact/FQ2QGKY8rVM5xqhXSP8MgJ), the same map with search and filters.

## 1. Why

Each phase has added modules wherever seemed reasonable at the time. The result:

- One module's job is hard to guess from its name (`General`, `Actions`, `SyncState`, `Admin`).
- Related files are split across `Shared/Modules`, `Shared/Events`, `Shared/State`, `Shared/Types`,
  `Modules/Constants` and `Services/<X>Service`, so a feature is never in one place.
- Nothing says where the next module goes, so every plan decides again.

The goal is a layout with **rhyme and reason**: given any module, you can tell its feature, its
realm and its role from its path and name; given a new module, the rules give exactly one place
and one name. The rules live in the docs, AGENTS.md, a skill and automated checks, so every future
phase follows them without anyone remembering to.

**Out of scope:** behaviour changes. The move renames and relocates files and updates the code that
points at them, nothing else. No module is split, merged or rewritten, except the one fold in §6.3
and three extractions the code-line cap forces (§6.3): three files sit at 397 to 400 code lines today,
and the longer names wrap enough lines to push them past 400.

## 2. The layout

### 2.1 Realm roots

Every feature gets one folder per realm it has code in:

| Realm | Root | Who can require it |
|---|---|---|
| shared | `ReplicatedStorage/Shared/Features/<Feature>/` | server and client |
| client | `ReplicatedStorage/Client/Features/<Feature>/` | client only |
| server | `ServerScriptService/Features/<Feature>/` | server only |

A feature with no code in a realm has no folder there (Item is shared only; Slot is server only).

### 2.2 Outside features

Only these live outside a `Features/` root:

| Place | What goes there |
|---|---|
| `ReplicatedStorage/Shared/Core/` | the framework and typed wrappers around libraries: ServiceController, Logger, Guard, SignalTyped |
| `ServerScriptService/Core/` | server framework: ProfileStoreTyped, `Net/RequestHandler`, `Testing/SpecRoots` |
| `ReplicatedStorage/Shared/Data/` | types every feature reads: PlayerDataTypes, PublicPlayerTypes |
| `ReplicatedStorage/Client/UI/` | the React UI tree (layers, components, hooks, scenes); conventions in §4.2 |
| `ServerScriptService/Commands/` | Cmdr commands; naming in §4.3 |
| `ReplicatedStorage/Shared/CmdrTypes/` | Cmdr argument types |
| entry scripts | `ServerHandler.server`, `TestRunner.server`, `ClientHandler.client`, and `RbxCharacterSounds.client` (the engine replaces its own script only when the name matches) |

Core and Data are closed lists. A module joins Core only if it is framework every feature uses, or
a typed wrapper around a library; anything owned by one feature goes in that feature.

### 2.3 Inside a feature

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
   something it doesn't own? → **Systems**
2. Does it remember anything between calls? → **State** (it may change only what it owns, and only
   when called)
3. Otherwise it remembers nothing and changes nothing → **Utils**

### 2.4 Worked example: Bank

```
ReplicatedStorage/Shared/Features/Bank/
  Data/BankConstants
  Net/BankEvents
ReplicatedStorage/Client/Features/Bank/
  BankServiceClient
ServerScriptService/Features/Bank/
  BankServiceServer
  Net/BankReceiver            (was Services/BankService/BankRequests)
```

## 3. Rules

1. **A module belongs to the feature whose job it does,** not the feature it happens to run on.
   (PuppetOutfit dresses puppets for Replication, but dressing is Customization's job, so it is
   `CustomizationOutfitSystem`.)
2. **One service per feature per realm by default.** A second service needs the user's approval and
   its reason recorded in
   `docs/project-structure.md` and in the check's exceptions table (§5.4). Today there are none:
   the only second service, `CustomizationConformanceServiceServer`, folds into
   `CustomizationArtCheckSystem` (§6.3).
3. **A new subfolder kind needs at least three modules that share it, and the user's approval.**
   Both, not either. Two modules that look alike go in the existing subfolder that fits best.
   (This is why there is no `Signals/` or `Hooks/`: of 22 Systems modules, 8 react to events, and
   only BodyObservers is purely an event helper.) An approved kind is added to
   `docs/project-structure.md`, the skill, and the check's allowed list in the same change.
4. **A new role word also needs the user's approval,** for the same reason: the vocabulary only
   stays small if adding to it is a decision, not a side effect.
5. **The top folder is `Features`.** `Systems` is a subfolder name, and `Services` named only one
   kind of module.
6. **Specs stay siblings.** `<Name>.spec.luau` sits next to `<Name>.luau` wherever it lives; the
   spec-sibling rule and `SpecRoots` are unchanged in spirit. A spec that tests no single module (the
   60-player replication load test) lives in its feature's `Testing/` folder with a `Harness` name.
7. **Requires use full addresses; a folder used three or more times gets one variable.** Every
   `require` names its module from the realm root. When a file requires **three or more** modules from
   one feature folder, it names that folder once and requires through it. Fewer than three stay full
   addresses, even when a line wraps: a variable is for real repetition, not for one long line.

   ```lua
   local ReplicationClient = ReplicatedStorage.Client.Features.Replication

   local ReplicationOwnerRigSystem = require(ReplicationClient.Systems.ReplicationOwnerRigSystem)
   local ReplicationPuppetPool = require(ReplicationClient.State.ReplicationPuppetPool)
   local ReplicationUplinkSender = require(ReplicationClient.Net.ReplicationUplinkSender)
   ```

   The variable is `<Feature><Realm>` (`Shared`, `Client`, `Server`): `ReplicationClient`,
   `CustomizationShared`, `BankServer`. The one relative require is a spec requiring its own module
   (`script.Parent.X` from `X.spec`); the UI tree keeps the relative requires inside itself.

## 4. Naming

### 4.1 Feature modules: `<Feature><What><RoleWord>`

Every feature module name starts with its feature and ends with a role word allowed in its
subfolder. `<What>` is optional when the feature has only one module of that role
(`BankEvents`, `TitleRegistry`).

| Folder | Role words | Meaning |
|---|---|---|
| `Data/` | Constants · Registry · Types · Assets | tuning values · a catalog looked up by id · type definitions only · asset id lists |
| `Net/` | Events · Codec · Sender · Receiver | packet definitions · our own byte packing (Replication only) · decides what to send · takes in and checks what arrives |
| `Rules/` | Rules · Check | decides whether something is allowed or valid · checks the place's setup at boot and reports problems |
| `State/` | Store · Tracker · Pool | Charm state others subscribe to · plain bookkeeping nothing subscribes to · spare objects kept for reuse |
| `Utils/` | Utils · Formulas | pure helpers, plans, diffs · game maths |
| `Systems/` | System | runs and changes the game |
| `Testing/` | Harness | test tooling |
| root | ServiceServer · ServiceClient | the feature's service |

**Feature names** (singular, PascalCase): Admin, Animation, Bank, Currency, Customization, Debugger,
Equipment, Inventory, Item (new: the item catalog and affixes, split from Inventory), PlayerData,
Replication (was CharacterReplication), Slot, StateSync, Stat (was Stats), Title (was Titles), UI,
Voice.

**Networking stays on ByteNet.** `Codec` exists only because Replication packs 16-byte records into
`ByteNet.buff` for its high-volume traffic. Other features use ByteNet's typed fields. A new codec is
written only for traffic of that volume; there is no custom networking library.

**Not renamed:** Core modules, Data modules, entry scripts and names the engine fixes.

### 4.2 UI tree

The UI tree keeps its folders. Convention:

- Components are named for what they show (`LogsPanel`, `StatDisplay`).
- Hooks are `use<Thing>` in `Hooks/`; a hook only one screen uses may sit beside that screen.
- View models end in `ViewModel`, scenes are `<Feature>Scene`, stores end in `Store`, constants are
  `UI<Thing>Constants`.

Three files break it today and are renamed:

| Today | New | Why |
|---|---|---|
| `Client/UI/Scenes/UIState` | `Client/UI/Scenes/UIStore` | a Charm store, so it ends in Store |
| `Client/UI/React/Debugger/theme` | `Client/UI/React/Debugger/DebuggerTheme` | the only lowercase module name |
| `Client/UI/React/Hooks/TrailEasing` | `Client/UI/React/Hooks/TrailEasingUtils` | not a hook; hooks start with `use` |

`Client/UI/React/Debugger/useDrag` stays: a hook only the Debugger uses.

### 4.3 Admin commands

Commands stay in `ServerScriptService/Commands/` (Cmdr registers them from one folder) and become
**feature-first**. The name an admin types is the file name in lower case, so the file, the
definition's `Name` field and the typed command always match. No aliases are kept for the old names.

| Command today | New file (plus its `Server` half) | Typed in game |
|---|---|---|
| AddCurrency | **CurrencyAdd** | `currencyadd` |
| SetCurrency | **CurrencySet** | `currencyset` |
| DepositCurrency | **BankDepositCurrency** | `bankdepositcurrency` |
| WithdrawCurrency | **BankWithdrawCurrency** | `bankwithdrawcurrency` |
| DepositItem | **BankDepositItem** | `bankdeposititem` |
| WithdrawItem | **BankWithdrawItem** | `bankwithdrawitem` |
| GiveItem | **InventoryGiveItem** | `inventorygiveitem` |
| RemoveItem | **InventoryRemoveItem** | `inventoryremoveitem` |
| RollPreview | **ItemRollPreview** | `itemrollpreview` |
| EquipItem | **EquipmentEquipItem** | `equipmentequipitem` |
| UnequipItem | **EquipmentUnequipItem** | `equipmentunequipitem` |
| EquipCosmetic | **CustomizationEquipCosmetic** | `customizationequipcosmetic` |
| UnlockCosmetic | **CustomizationUnlockCosmetic** | `customizationunlockcosmetic` |
| SetBodyColor | **CustomizationSetBodyColor** | `customizationsetbodycolor` |
| SetCosmeticColor | **CustomizationSetCosmeticColor** | `customizationsetcosmeticcolor` |
| SetHeadType | **CustomizationSetHeadType** | `customizationsetheadtype` |
| SetSoulColor | **CustomizationSetSoulColor** | `customizationsetsoulcolor` |
| SetSurface | **CustomizationSetSurface** | `customizationsetsurface` |
| CheckArt | **CustomizationCheckArt** | `customizationcheckart` |
| TuneOffset | **CustomizationTuneOffset** | `customizationtuneoffset` |
| GiveXp | **StatGiveXp** | `statgivexp` |
| InvestStat | **StatInvest** | `statinvest` |
| RespecStats | **StatRespec** | `statrespec` |
| SwitchSlot | **SlotSwitch** | `slotswitch` |
| UnlockSlot | **SlotUnlock** | `slotunlock` |
| TitleAward | TitleAward | `titleaward` |
| TitleEquip | TitleEquip | `titleequip` |
| TitleRevoke | TitleRevoke | `titlerevoke` |
| AnimPlay | **AnimationPlay** | `animationplay` |
| AnimStop | **AnimationStop** | `animationstop` |
| AnimStopClass | **AnimationStopClass** | `animationstopclass` |
| AnimTracks | **AnimationTracks** | `animationtracks` |
| AnimReport | **AnimationReport** | `animationreport` |


## 5. Enforcement

Docs alone drift. The rules are carried by four things, each with one job.

### 5.1 `docs/project-structure.md`: the reference

Rewritten to hold: the realm roots and the outside-features list (§2.1–2.2), the seven subfolders and
their questions (§2.3), the three-question test, the rules (§3), the naming vocabulary (§4), a
"where does my new code go?" decision list, and the module map (one line per module, grouped by
feature). It replaces the current "Realm layout" and "Service discovery" sections; the spec-sibling
and add-a-slice sections are kept with their paths updated.

### 5.2 `AGENTS.md`: the non-negotiable rule

One bullet under "Non-negotiable working rules":

> **Module placement.** Every new module's feature, realm, subfolder and name are stated in the plan
> before it is written, and follow `docs/project-structure.md`. Run the `module-placement` skill when
> planning or reviewing. A new subfolder kind, role word or second service needs the user's approval.

The "Architecture in one screen" discovery line and the reference implementation paths are updated.

### 5.3 The `module-placement` skill

A project skill at `.claude/skills/module-placement/SKILL.md`. Used when writing a plan, adding a
module, or reviewing a change. It:

1. walks the decision list (which feature does this job → which realm → which subfolder via the
   three-question test → which role word → the name);
2. requires every plan to carry a **New modules** table (feature, realm, subfolder, name, one-line
   job) before any task that creates a file;
3. lists the approval-gated changes (new subfolder kind, new role word, second service) and says to
   stop and ask rather than decide.

### 5.4 Automated checks in `check_pr_rules.py`

New **whole-tree** invariants, like the asset-id rule: the move makes the tree compliant, so there
is no past to grandfather. For every `.luau` file under `src/` (specs and stories are checked
against the module they sit beside):

| Check | Fails when |
|---|---|
| placement | a file is outside a `Features/<Feature>/` root and outside the §2.2 list |
| depth | a feature file is deeper than `<Feature>/<Subfolder>/<Name>`, or sits in a subfolder not in the allowed list |
| prefix | a feature module's name doesn't start with its feature folder's name |
| role word | a name doesn't end with a role word allowed for its subfolder, or a root file isn't `<Feature>ServiceServer` / `<Feature>ServiceClient` matching its realm |
| one service | a feature folder holds more than one service in a realm and isn't in the exceptions table |
| command names | a `Commands/` definition's `Name` isn't its file name in lower case, or a command file doesn't start with a feature name |
| UI names | a module under `Client/UI/` is neither PascalCase nor a `use<Thing>` hook |

The allowed subfolders, role words and service exceptions are constants at the top of the script,
each with a comment. Changing them is a rule change and needs the user's approval (§3.3–3.4); a
change that edits them only to make a failing file pass is a CI bypass and is rejected.

Existing path-keyed constants in the script move with the code: the asset-id allowed prefixes
become every feature's `Data/` folder (registries, assets and constants), and the UI lifecycle tree
becomes `Client/Features/`.

## 6. The move

### 6.1 What changes

- **Files:** 146 modules are placed; 94 are renamed. Every spec moves and is renamed with its module.
- **Requires:** every `require(...)` path to a moved module is rewritten as a full address, and a
  file that requires three or more modules from one feature folder gets that folder's variable
  (rule 7). In the dry run, 44 files get one.
- **Discovery:** `ServerHandler` walks `ServerScriptService.Features`; `ClientHandler` walks
  `ReplicatedStorage.Client.Features`. The suffix rule (`*ServiceServer` / `*ServiceClient`) and the
  "looks like a service but isn't" warning are kept.
- **Service names:** ServiceController registers by file name, so renamed services
  (`ReplicationServiceServer`, `StatServiceServer`, `TitleServiceServer`, and their clients) change
  their registered names; every `dependencies` list, `getService` call and `Logger.new` name that
  spells an old name is updated.
- **SpecRoots:** `get()` returns the new roots (`Shared.Core`, `Shared.Data`, `Shared.Features`,
  `Client`, `ServerScriptService.Core`, `ServerScriptService.Features`, `ServerScriptService.Commands`),
  and every `EXEMPT_MODULES` key is rewritten to the module's new full name.
- **Commands and UI:** the renames in §4.2–4.3, including each command's `Name` field.
- **Docs:** `project-structure.md` (§5.1), `AGENTS.md` (§5.2), and every path in `architecture.md`,
  `testing.md`, `animation.md`, `conventions.md` and `tech-stack.md`.

### 6.2 How

The map below is the input. A one-off script reads it, `git mv`s each file, and rewrites requires,
SpecRoots keys and service-name references. The move goes one feature per commit, and `check.sh` is
green after every commit, so a bad step is found where it happened. The new checks (§5.4) land
last, once the tree passes them. TestEZ in Studio and a two-player play test prove nothing changed
at runtime.

Because `ReplicatedStorage` keeps `$ignoreUnknownInstances: true`, the first `rojo serve` after the
move is checked by hand for stale `Shared/Modules`, `Shared/Events`, `Shared/State`, `Shared/Types`
or `Client/Services` folders; SpecRoots' orphan-spec check would also fail on any stale spec. The
same folders go on the cutover hand-clean list.

### 6.3 The one fold

`CustomizationConformanceServiceServer` stops being a service: its body becomes
`Customization/Systems/CustomizationArtCheckSystem`, started by `CustomizationServiceServer`. Its
behaviour (boot-time art conformance check, the `customizationcheckart` command's backing) is
unchanged; its spec moves with it.

**Three extractions.** Three files sit at the cap today. The longer names wrap ordinary code lines
as well as requires, so no require style keeps them under 400. In each, a job that rule 1 places
elsewhere moves out. Behaviour is unchanged.

| File | Today | Moved, no extraction | What moves out, and where | After (dry run) |
|---|---|---|---|---|
| `ReplicationServiceClient` | 397 | 401 | Building the cosmetic piece folder, its pool and the outfit system → `CustomizationOutfitSystem.mount(): (State, () -> ())`, which returns the teardown. Customization's job. | 386 |
| `ReplicationServiceServer` | 400 | 408 | `slotEntryOf` / `broadcastSlot`, which decide who receives a slot update → new `Replication/Net/ReplicationSlotSender` (Sender). The packet is passed in, like `ReplicationObserverUtils.sendToObservers`. | 394 |
| `CustomizationServiceServer` | 397 | 398, +2 for the art check | `isUnlocked` / `canEquip`, the ownership gate → new `Customization/Rules/CustomizationEntitlementRules` (server Rules), pure: it takes the entitlements and the scope. The service keeps the scope table and a 3-line `canEquip` that feeds it. | 380 |

Each extraction gets its own checks at the end of the move (plan Task 11).

### 6.4 Sequencing

1. The move runs on `feature/module-layout`, based on R5's head (the furthest branch). It doesn't wait
   for R2–R5 to merge.
2. R2–R5 merge in order (#29 → #31 → #34 → #38). The layout branch then rebases onto main and merges
   last. If a fix lands on R2–R5 first, the branch is rebuilt from the new R5 head by re-running the
   move, not rebased through a tree-wide rename. R6 and R7 start from the layout branch.
3. Until the move lands, new modules on any branch state their feature, realm, subfolder and target
   name in the plan, so they move cleanly.

## 7. Verification

- `check.sh` green after every commit (lint, format, strict typecheck, ruff, file length, PR rules).
- The new checks (§5.4) pass on the moved tree and fail on a planted bad file for each row
  (a red test per check, then removed).
- TestEZ in Studio: the same pass count as before the move, 0 errors.
- A two-player Studio play test: services boot (no discovery warnings), customization, replication,
  voice, chat and the Debugger work; three renamed admin commands run by their new typed names.
- No stale folders after `rojo serve` (§6.2).

## 8. Module map

All 146 modules. **Bold** names are renamed. The folder is relative to the realm's `Features/` root
(§2.1); Core, Data and entry scripts show their full place. Spec files follow their module.

### Admin

| Realm | Folder | New name | Today |
|---|---|---|---|
| shared | `Admin/Rules` | **AdminRules** | `ReplicatedStorage/Shared/Modules/Admin` |
| client | `Admin` | AdminServiceClient | `ReplicatedStorage/Client/Services/AdminService/AdminServiceClient` |
| server | `Admin` | AdminServiceServer | `ServerScriptService/Services/AdminService/AdminServiceServer` |

### Animation

| Realm | Folder | New name | Today |
|---|---|---|---|
| shared | `Animation/Data` | **AnimationActionRegistry** | `ReplicatedStorage/Shared/Modules/Constants/Animations/Actions` |
| shared | `Animation/Data` | **AnimationLocomotionRegistry** | `ReplicatedStorage/Shared/Modules/Constants/Animations/Locomotion` |
| shared | `Animation/Data` | AnimationRegistry | `ReplicatedStorage/Shared/Modules/Constants/Animations/AnimationRegistry` |
| shared | `Animation/Data` | AnimationTypes | `ReplicatedStorage/Shared/Modules/Constants/Animations/AnimationTypes` |
| shared | `Animation/Net` | AnimationEvents | `ReplicatedStorage/Shared/Events/AnimationEvents` |
| shared | `Animation/Systems` | **AnimationPlayerEngineSystem** | `ReplicatedStorage/Shared/Modules/AnimationPlayerRuntime` |
| shared | `Animation/Systems` | **AnimationPlayerSystem** | `ReplicatedStorage/Shared/Modules/AnimationPlayer` |
| client | `Animation` | AnimationServiceClient | `ReplicatedStorage/Client/Services/AnimationService/AnimationServiceClient` |
| client | `Animation/Systems` | **AnimationLocomotionHumanoidSystem** | `ReplicatedStorage/Client/Services/AnimationService/LocomotionBinding` |
| client | `Animation/Systems` | **AnimationLocomotionSystem** | `ReplicatedStorage/Client/Services/AnimationService/LocomotionAnimator` |
| server | `Animation` | AnimationServiceServer | `ServerScriptService/Services/AnimationService/AnimationServiceServer` |
| server | `Animation/Systems` | **AnimationActionGrantSystem** | `ServerScriptService/Services/AnimationService/ActionGrants` |

### Bank

| Realm | Folder | New name | Today |
|---|---|---|---|
| shared | `Bank/Data` | BankConstants | `ReplicatedStorage/Shared/Modules/Constants/BankConstants` |
| shared | `Bank/Net` | BankEvents | `ReplicatedStorage/Shared/Events/BankEvents` |
| client | `Bank` | BankServiceClient | `ReplicatedStorage/Client/Services/BankService/BankServiceClient` |
| server | `Bank` | BankServiceServer | `ServerScriptService/Services/BankService/BankServiceServer` |
| server | `Bank/Net` | **BankReceiver** | `ServerScriptService/Services/BankService/BankRequests` |

### Currency

| Realm | Folder | New name | Today |
|---|---|---|---|
| shared | `Currency/Data` | CurrencyConstants | `ReplicatedStorage/Shared/Modules/Constants/CurrencyConstants` |
| shared | `Currency/Utils` | CurrencyUtils | `ReplicatedStorage/Shared/Modules/Utils/CurrencyUtils` |
| client | `Currency` | CurrencyServiceClient | `ReplicatedStorage/Client/Services/CurrencyService/CurrencyServiceClient` |
| server | `Currency` | CurrencyServiceServer | `ServerScriptService/Services/CurrencyService/CurrencyServiceServer` |

### Customization

| Realm | Folder | New name | Today |
|---|---|---|---|
| shared | `Customization/Data` | **CustomizationCosmeticRegistry** | `ReplicatedStorage/Shared/Modules/Constants/CosmeticRegistry` |
| shared | `Customization/Data` | **CustomizationSoulColorRegistry** | `ReplicatedStorage/Shared/Modules/Constants/SoulColorRegistry` |
| shared | `Customization/Rules` | **CustomizationArtCheck** | `ReplicatedStorage/Shared/Modules/CustomizationConformance` |
| shared | `Customization/Rules` | **CustomizationRegistryCheck** | `ReplicatedStorage/Shared/Modules/Constants/CosmeticChecks` |
| shared | `Customization/Rules` | **CustomizationSliceRules** | `ReplicatedStorage/Shared/Modules/CustomizationValidation` |
| shared | `Customization/Rules` | **CustomizationWearRules** | `ReplicatedStorage/Shared/Modules/CustomizationCompatibility` |
| shared | `Customization/Utils` | **CustomizationPlanUtils** | `ReplicatedStorage/Shared/Modules/CustomizationPlan` |
| client | `Customization` | CustomizationServiceClient | `ReplicatedStorage/Client/Services/CustomizationService/CustomizationServiceClient` |
| client | `Customization/State` | **CustomizationPiecePool** | `ReplicatedStorage/Shared/Modules/PiecePool` |
| client | `Customization/State` | **CustomizationRigOutfitTracker** | `ReplicatedStorage/Shared/Modules/RigOutfit` |
| client | `Customization/Utils` | **CustomizationOutfitDiffUtils** | `ReplicatedStorage/Shared/Modules/OutfitDiff` |
| client | `Customization/Systems` | **CustomizationDressQueueSystem** | `ReplicatedStorage/Shared/Modules/AppearanceQueue` |
| client | `Customization/Systems` | **CustomizationDressSystem** | `ReplicatedStorage/Shared/Modules/CustomizationApplication` |
| client | `Customization/Systems` | **CustomizationOutfitSystem** | `ReplicatedStorage/Client/Modules/PuppetOutfit` |
| client | `Customization/Systems` | **CustomizationRigLookSystem** | `ReplicatedStorage/Shared/Modules/RigLook` |
| client | `Customization/Systems` | **CustomizationTuneOffsetSystem** | `ReplicatedStorage/Client/Modules/TuneOffsetClient` |
| server | `Customization` | CustomizationServiceServer | `ServerScriptService/Services/CustomizationService/CustomizationServiceServer` |
| server | `Customization/Systems` | **CustomizationArtCheckSystem** | `ServerScriptService/Services/CustomizationService/CustomizationConformanceServiceServer` |
| server | `Customization/Systems` | **CustomizationPublishSystem** | `ServerScriptService/Services/CustomizationService/AppearancePublisher` |

### Debugger

| Realm | Folder | New name | Today |
|---|---|---|---|
| shared | `Debugger/Net` | DebuggerEvents | `ReplicatedStorage/Shared/Events/DebuggerEvents` |
| client | `Debugger` | DebuggerServiceClient | `ReplicatedStorage/Client/Services/DebuggerService/DebuggerServiceClient` |
| client | `Debugger/State` | **DebuggerStore** | `ReplicatedStorage/Client/State/DebuggerState` |
| server | `Debugger` | DebuggerServiceServer | `ServerScriptService/Services/DebuggerService/DebuggerServiceServer` |

### Equipment

| Realm | Folder | New name | Today |
|---|---|---|---|
| shared | `Equipment/Data` | EquipmentConstants | `ReplicatedStorage/Shared/Modules/Constants/EquipmentConstants` |
| shared | `Equipment/Net` | EquipmentEvents | `ReplicatedStorage/Shared/Events/EquipmentEvents` |
| shared | `Equipment/Utils` | **EquipmentBonusFormulas** | `ReplicatedStorage/Shared/Modules/Utils/EquipmentBonuses` |
| client | `Equipment` | EquipmentServiceClient | `ReplicatedStorage/Client/Services/EquipmentService/EquipmentServiceClient` |
| server | `Equipment` | EquipmentServiceServer | `ServerScriptService/Services/EquipmentService/EquipmentServiceServer` |

### Inventory

| Realm | Folder | New name | Today |
|---|---|---|---|
| shared | `Inventory/Rules` | **InventoryContainerRules** | `ReplicatedStorage/Shared/Modules/ContainerValidation` |
| shared | `Inventory/Utils` | **InventoryPlacementUtils** | `ReplicatedStorage/Shared/Modules/ContainerPlacement` |
| shared | `Inventory/Utils` | InventoryUtils | `ReplicatedStorage/Shared/Modules/Utils/InventoryUtils` |
| client | `Inventory` | InventoryServiceClient | `ReplicatedStorage/Client/Services/InventoryService/InventoryServiceClient` |
| server | `Inventory` | InventoryServiceServer | `ServerScriptService/Services/InventoryService/InventoryServiceServer` |

### Item

| Realm | Folder | New name | Today |
|---|---|---|---|
| shared | `Item/Data` | **ItemAffixConstants** | `ReplicatedStorage/Shared/Modules/Constants/AffixConstants` |
| shared | `Item/Data` | ItemConstants | `ReplicatedStorage/Shared/Modules/Constants/ItemConstants` |
| shared | `Item/Data` | **ItemContentRegistry** | `ReplicatedStorage/Shared/Modules/GameItems` |
| shared | `Item/Data` | **ItemRegistry** | `ReplicatedStorage/Shared/Modules/ItemDefinitions` |
| shared | `Item/Utils` | **ItemAffixFormulas** | `ReplicatedStorage/Shared/Modules/AffixRoller` |

### PlayerData

| Realm | Folder | New name | Today |
|---|---|---|---|
| server | `PlayerData` | PlayerDataServiceServer | `ServerScriptService/Services/PlayerDataService/PlayerDataServiceServer` |
| server | `PlayerData/Data` | PlayerDataConstants | `ServerScriptService/Modules/Constants/PlayerDataConstants` |
| server | `PlayerData/Utils` | **PlayerDataPathUtils** | `ServerScriptService/Modules/ProfilePath` |
| server | `PlayerData/Systems` | **PlayerDataMigrationSystem** | `ServerScriptService/Modules/PlayerDataMigrations` |
| server | `PlayerData/Systems` | **PlayerDataSliceSystem** | `ServerScriptService/Modules/SliceOwner` |

### Replication

| Realm | Folder | New name | Today |
|---|---|---|---|
| shared | `Replication/Net` | **ReplicationBatchCodec** | `ReplicatedStorage/Shared/Modules/CharacterReplication/CharacterBatchCodec` |
| shared | `Replication/Net` | **ReplicationEvents** | `ReplicatedStorage/Shared/Events/CharacterReplicationEvents` |
| shared | `Replication/Net` | **ReplicationRecordCodec** | `ReplicatedStorage/Shared/Modules/CharacterReplication/CharacterRecordCodec` |
| shared | `Replication/Net` | **ReplicationUplinkCodec** | `ReplicatedStorage/Shared/Modules/CharacterReplication/CharacterUplinkCodec` |
| shared | `Replication/Rules` | **ReplicationFallRules** | `ReplicatedStorage/Shared/Modules/CharacterReplication/FallPlane` |
| shared | `Replication/Rules` | **ReplicationSendRules** | `ReplicatedStorage/Shared/Modules/CharacterReplication/SendPolicy` |
| shared | `Replication/State` | **ReplicationSampleTracker** | `ReplicatedStorage/Shared/Modules/CharacterReplication/CharacterInterpolator` |
| shared | `Replication/Utils` | **ReplicationStateTimingUtils** | `ReplicatedStorage/Shared/Modules/CharacterReplication/BodyStateTiming` |
| shared | `Replication/Systems` | **ReplicationRenderClockSystem** | `ReplicatedStorage/Shared/Modules/CharacterReplication/RenderClock` |
| shared | `Replication/Testing` | **ReplicationDesignHarness** | `ReplicatedStorage/Shared/Modules/CharacterReplication/Harness/HarnessVenture` |
| shared | `Replication/Testing` | **ReplicationLinkHarness** | `ReplicatedStorage/Shared/Modules/CharacterReplication/Harness/HarnessNetwork` |
| shared | `Replication/Testing` | **ReplicationRunHarness** | `ReplicatedStorage/Shared/Modules/CharacterReplication/Harness/HarnessRunner` |
| shared | `Replication/Testing` | **ReplicationTraceHarness** | `ReplicatedStorage/Shared/Modules/CharacterReplication/Harness/HarnessTrace` |
| client | `Replication` | **ReplicationServiceClient** | `ReplicatedStorage/Client/Services/CharacterReplicationService/CharacterReplicationServiceClient` |
| client | `Replication/Net` | **ReplicationUplinkSender** | `ReplicatedStorage/Client/Services/CharacterReplicationService/UplinkSender` |
| client | `Replication/Rules` | **ReplicationAnimationRules** | `ReplicatedStorage/Client/Services/CharacterReplicationService/PuppetLod` |
| client | `Replication/Rules` | **ReplicationViewCheck** | `ReplicatedStorage/Client/Services/CharacterReplicationService/ReplicationTripwire` |
| client | `Replication/State` | **ReplicationActionTracker** | `ReplicatedStorage/Client/Services/CharacterReplicationService/BodyActions` |
| client | `Replication/State` | **ReplicationPuppetPool** | `ReplicatedStorage/Client/Services/CharacterReplicationService/PuppetPool` |
| client | `Replication/State` | **ReplicationRemoteBodyTracker** | `ReplicatedStorage/Client/Services/CharacterReplicationService/RemoteBodies` |
| client | `Replication/State` | **ReplicationRigTracker** | `ReplicatedStorage/Client/Services/CharacterReplicationService/RigRegistry` |
| client | `Replication/Systems` | **ReplicationDiagnosticsSystem** | `ReplicatedStorage/Client/Services/CharacterReplicationService/ReplicationDiagnostics` |
| client | `Replication/Systems` | **ReplicationOwnerRigSystem** | `ReplicatedStorage/Client/Services/CharacterReplicationService/OwnerRig` |
| client | `Replication/Systems` | **ReplicationPuppetLocomotionSystem** | `ReplicatedStorage/Client/Services/CharacterReplicationService/PuppetLocomotion` |
| client | `Replication/Systems` | **ReplicationRigAnimationSystem** | `ReplicatedStorage/Client/Services/CharacterReplicationService/RigAnimation` |
| server | `Replication` | **ReplicationServiceServer** | `ServerScriptService/Services/CharacterReplicationService/CharacterReplicationServiceServer` |
| server | `Replication/Net` | **ReplicationBodyStateSender** | `ServerScriptService/Services/CharacterReplicationService/BodyStateRelay` |
| server | `Replication/Net` | **ReplicationReceiver** | `ServerScriptService/Services/CharacterReplicationService/ReplicationPackets` |
| server | `Replication/Net` | **ReplicationUplinkReceiver** | `ServerScriptService/Services/CharacterReplicationService/UplinkPipeline` |
| server | `Replication/Rules` | **ReplicationRigCheck** | `ServerScriptService/Services/CharacterReplicationService/RigIntegrity` |
| server | `Replication/Rules` | **ReplicationUplinkRules** | `ServerScriptService/Services/CharacterReplicationService/UplinkIngest` |
| server | `Replication/State` | **ReplicationBodyStateTracker** | `ServerScriptService/Services/CharacterReplicationService/BodyStates` |
| server | `Replication/State` | **ReplicationSlotTracker** | `ServerScriptService/Services/CharacterReplicationService/ReplicationSlots` |
| server | `Replication/State` | **ReplicationVisibilityTracker** | `ServerScriptService/Services/CharacterReplicationService/VisibilitySet` |
| server | `Replication/Utils` | **ReplicationObserverUtils** | `ServerScriptService/Services/CharacterReplicationService/ObserverQuery` |
| server | `Replication/Systems` | **ReplicationBodyObserverSystem** | `ServerScriptService/Services/CharacterReplicationService/BodyObservers` |
| server | `Replication/Systems` | **ReplicationDownlinkSystem** | `ServerScriptService/Services/CharacterReplicationService/DownlinkScheduler` |
| server | `Replication/Systems` | **ReplicationFanoutSystem** | `ServerScriptService/Services/CharacterReplicationService/ReplicationFanout` |
| server | `Replication/Systems` | **ReplicationInstanceSystem** | `ServerScriptService/Services/CharacterReplicationService/ReplicationInstances` |
| server | `Replication/Testing` | **ReplicationIntegratedHarness** | `ServerScriptService/Services/CharacterReplicationService/HarnessIntegrated` |

### Slot

| Realm | Folder | New name | Today |
|---|---|---|---|
| server | `Slot` | SlotServiceServer | `ServerScriptService/Services/SlotService/SlotServiceServer` |

### StateSync

| Realm | Folder | New name | Today |
|---|---|---|---|
| shared | `StateSync/Data` | **StateSyncConstants** | `ReplicatedStorage/Shared/State/SyncState` |
| shared | `StateSync/Data` | **StateSyncSliceRegistry** | `ReplicatedStorage/Shared/State/SliceManifest` |
| client | `StateSync` | StateSyncServiceClient | `ReplicatedStorage/Client/Services/StateSyncService/StateSyncServiceClient` |
| client | `StateSync/State` | **StateSyncClientStore** | `ReplicatedStorage/Client/State/ClientStore` |
| server | `StateSync` | StateSyncServiceServer | `ServerScriptService/Services/StateSyncService/StateSyncServiceServer` |
| server | `StateSync/State` | **StateSyncPublicPlayerStore** | `ServerScriptService/State/PublicPlayerState` |
| server | `StateSync/State` | **StateSyncServerStore** | `ServerScriptService/State/ServerStore` |

### Stat

| Realm | Folder | New name | Today |
|---|---|---|---|
| shared | `Stat/Data` | StatConstants | `ReplicatedStorage/Shared/Modules/Constants/StatConstants` |
| shared | `Stat/Utils` | StatFormulas | `ReplicatedStorage/Shared/Modules/Utils/StatFormulas` |
| client | `Stat` | **StatServiceClient** | `ReplicatedStorage/Client/Services/StatsService/StatsServiceClient` |
| server | `Stat` | **StatServiceServer** | `ServerScriptService/Services/StatsService/StatsServiceServer` |

### Title

| Realm | Folder | New name | Today |
|---|---|---|---|
| shared | `Title/Data` | **TitleGeneralRegistry** | `ReplicatedStorage/Shared/Modules/Constants/Titles/General` |
| shared | `Title/Data` | **TitleRegistry** | `ReplicatedStorage/Shared/Modules/Constants/Titles/TitlesRegistry` |
| shared | `Title/Data` | **TitleTypes** | `ReplicatedStorage/Shared/Modules/Constants/Titles/TitlesTypes` |
| shared | `Title/Net` | **TitleEvents** | `ReplicatedStorage/Shared/Events/TitlesEvents` |
| shared | `Title/Rules` | **TitleRequestRules** | `ReplicatedStorage/Shared/Modules/TitlesRequests` |
| shared | `Title/Rules` | **TitleSliceRules** | `ReplicatedStorage/Shared/Modules/TitlesValidation` |
| client | `Title` | **TitleServiceClient** | `ReplicatedStorage/Client/Services/TitlesService/TitlesServiceClient` |
| server | `Title` | **TitleServiceServer** | `ServerScriptService/Services/TitlesService/TitlesServiceServer` |

### UI

| Realm | Folder | New name | Today |
|---|---|---|---|
| client | `UI` | UIServiceClient | `ReplicatedStorage/Client/Services/UIService/UIServiceClient` |
| client | `UI/Data` | UIAssets | `ReplicatedStorage/Shared/Modules/Constants/UIAssets` |

### Voice

| Realm | Folder | New name | Today |
|---|---|---|---|
| client | `Voice` | VoiceServiceClient | `ReplicatedStorage/Client/Services/VoiceService/VoiceServiceClient` |
| client | `Voice/State` | **VoiceWiringTracker** | `ReplicatedStorage/Client/Services/VoiceService/VoiceWiring` |
| server | `Voice` | VoiceServiceServer | `ServerScriptService/Services/VoiceService/VoiceServiceServer` |
| server | `Voice/Rules` | **VoiceSettingsCheck** | `ServerScriptService/Services/VoiceService/VoiceSettings` |

### Core

| Realm | Folder | New name | Today |
|---|---|---|---|
| shared | `ReplicatedStorage/Shared/Core` | Guard | `ReplicatedStorage/Shared/Modules/Guard` |
| shared | `ReplicatedStorage/Shared/Core` | Logger | `ReplicatedStorage/Shared/Modules/Logger` |
| shared | `ReplicatedStorage/Shared/Core` | ServiceController | `ReplicatedStorage/Shared/Modules/ServiceController` |
| shared | `ReplicatedStorage/Shared/Core` | SignalTyped | `ReplicatedStorage/Shared/Modules/SignalTyped` |
| server | `ServerScriptService/Core` | ProfileStoreTyped | `ServerScriptService/Modules/ProfileStoreTyped` |
| server | `ServerScriptService/Core/Net` | RequestHandler | `ServerScriptService/Modules/RequestHandler` |
| server | `ServerScriptService/Core/Testing` | SpecRoots | `ServerScriptService/Modules/SpecRoots` |

### Data

| Realm | Folder | New name | Today |
|---|---|---|---|
| shared | `ReplicatedStorage/Shared/Data` | PlayerDataTypes | `ReplicatedStorage/Shared/Types/PlayerDataTypes` |
| shared | `ReplicatedStorage/Shared/Data` | PublicPlayerTypes | `ReplicatedStorage/Shared/Types/PublicPlayerTypes` |

### Entry scripts

| Realm | Folder | New name | Today |
|---|---|---|---|
| client | `StarterPlayer/StarterPlayerScripts` | ClientHandler.client | `StarterPlayer/StarterPlayerScripts/ClientHandler.client` |
| client | `StarterPlayer/StarterPlayerScripts` | RbxCharacterSounds.client | `StarterPlayer/StarterPlayerScripts/RbxCharacterSounds.client` |
| server | `ServerScriptService` | ServerHandler.server | `ServerScriptService/ServerHandler.server` |
| server | `ServerScriptService` | TestRunner.server | `ServerScriptService/TestRunner.server` |

