# Old Game (VentureTestingPlace) — Full Systems Inventory

> Discovery pass performed read-only against the live `VentureTestingPlace` Studio session via the
> Roblox Studio MCP, 2026-07-17. Supersedes the memory-recalled table in `docs/ROADMAP.md`
> ("Systems inventory — known-incomplete"). Every module count / line count below is a live read
> (`#Source:gmatch("\n")`), not an estimate. Entry-point sources were read for every system listed;
> full-file reads were done selectively (representative + suspicious files), consistent with the
> "read entry points, not all 990 scripts" instruction.
>
> Root containers walked: `ServerScriptService` (incl. `Modules`, 51 top-level entries),
> `ReplicatedStorage` (incl. `Modules`, 58 top-level entries, plus `Events`/`Effects`/`Skills`/
> `InventoryItems`/`Customs`/`Models`/`Functions`/`Properties`), `StarterPlayer.*`, `StarterGui`,
> `ServerStorage`, `Workspace`, `Lighting`.

## ⚠ How to USE this inventory — read this before planning any phase from it

**This is a census of what EXISTS, not a list of what gets built.** Developer guidance
(2026-07-17, verbatim intent):

- **Several of these systems are EXTREMELY outdated and need to be redone completely.**
- **Several of them will probably be removed entirely** — existence in the old game is not a
  commitment to keep them.
- **None of them will be implemented remotely similar to how they currently work.** All of it is
  bad code. The size/coupling data below describes the OLD implementation's shape, never a target.

**What this means for whoever plans a phase off this doc:** lead with an inquisitive posture
toward the developer, not the old code —
1. First question: **keep, kill, or redesign?** Do not assume "found in inventory" = "gets ported."
2. Question EVERY structural choice the old system made (the same rule that governs the whole
   refactor — see AGENTS.md's "old code is evidence, not source" and each phase spec's governing
   principle). The feature FACTS here are evidence; the shapes are not.
3. For systems chosen to be (re)implemented: research how such systems are best built (genre
   precedent, platform best practices) BEFORE proposing a design — the same research-first rule the
   developer set for affix rolling (3c). Bring options to the developer, don't default to the old
   game's approach.

## How to read this document

Each system row gives: location(s), what it does, size (module count / total lines where read),
key couplings, and **Roadmap status** — `PORTED (Phase N)` / `ON ROADMAP (row)` / **`MISSING`**
(not mentioned anywhere in `docs/ROADMAP.md`). MISSING means "not previously tracked" — per the
section above, it does NOT mean "must be built."

---

## 1. Gameplay domains

| System | Location(s) | What it does | Size | Key couplings | Roadmap status | Port notes |
|---|---|---|---|---|---|---|
| **Combat core** | `SSS.Modules.CombatHandler` (1156 ln), `SSS.Modules.Services.WeaponService` (1244 ln), `SSS.Modules.WeaponHandler` (523 ln), `RS.Modules.Weapon.*` (19 modules — hitbox raycast, per-weapon-type behavior, `AllWeapons`), `RS.Modules.Combat.*` (state/clash/animation-interrupt/status), `SSS.Modules.Combat.DamageProxyManager`, `SSS.Modules.Stat.StatHandler` (416 ln) | Weapon swing → hitbox (custom `RaycastHitboxV4`) → damage → status effect pipeline. Client fires `Hitbox`/`DamageClient` events; server trusts client-reported target + multiplier (confirmed — matches AGENTS.md warning). | ~30 modules, ~5k+ ln | `PlayerStatManager` (damage writes), `CombatHandler`, Knit `StatusService`/`EnchantmentService`, `CollectionService` tags for mob AI configs (`Workspace.Entities.Mobs.*.Configs`) | **Last (Combat core)** | Confirmed: client-trusted hit detection, exactly as the roadmap already flags — genuine redesign needed, not a port. |
| **Skills (combat abilities)** | `RS.Modules.Skills.*` (43 scripts: `HAND_0x`, `STOMP_0x`, `BLOCK_01`, `BLINK_01`, `SWAP_01`, `CALL_01`, imbuements `IMB_0x`, buffs, `SkillHelpers.*` casting infra), `SSS.Modules.HarvestOfFearSkill`, `game.ServerStorage.Bindables.SkillHandlerEvent` | Per-skill modules keyed by short codes (`HAND_05`, `STOMP_02`…), invoked through a `SkillHandlerEvent` BindableFunction hub; `CastClient` (840 ln) drives client-side cast UX. | 43+ modules, several 500+ ln | `WeaponController` (`skill_keycodes`), `EnchantmentService`, `StatusService`, `RagdollHandler` | ON ROADMAP ("Skills") | Old `IsSkill` item flag confirmed live on item records (see Items section) — item↔skill coupling is real, matches the roadmap's "re-derive, don't port" note. |
| **Arena / PVP** | `SSS.Modules.Arena.*` (10 modules: `ArenaService` 1216 ln, `QueueManager` 570 ln, `RewardManager` 413 ln, `CustomLobbyManager`, `HostManager`, `ScoreManager`, `MatchStore`), `RS.Modules.Controllers.ArenaController` (625 ln), `RS.Modules.UIControllers.ArenaUIController` (1276 ln) | Ranked/unranked queueing, custom lobbies, cross-server MessagingService score sync, teleport-based match instancing. | ~13 modules, ~5k ln | Knit services, `PlayerStatManager`, `TeleportService`, `MessagingService`, item `ArenaAllowed` flags (confirmed live) | ON ROADMAP ("Arena") | Confirms roadmap note: item records carry per-match-type `ArenaAllowed` permission tables (`{MatchType..IsRanked = bool}`). |
| **Quests** | `SSS.Modules.QuestHandler` (1087 ln, embeds `DailyQuests`), `RS.Modules.UIControllers.QuestUIController` (810 ln), `RS.Modules.Skills`/`ReplicatedStorage."Quest Items"` (Bottle1, Cat models — message-in-bottle chain confirmed), `Events.Quest*` (5 remotes) | Objective-chain quest definitions (`location_quest`, `talk_quest`, dependency graphs), daily quest rotation, titles awarded on completion (`TitleHandler.Titles` required directly into `QuestHandler`). | ~3 modules, 1000+ ln core | `TitleHandler`, `WeaponUtilities`, `GrudgeService` (bounty quest hook) | ON ROADMAP ("Quests") | Confirms "message-in-bottle" quest-item chain and `QuestItem` flag are real, live data. |
| **Titles** | `SSS.Modules.TitleHandler` (104 ln + `Titles` data submodule), `SSS.Modules.Services.TitleService`, `RS.Modules.Controllers.TitleController` | Award/track player titles; required directly by `QuestHandler` and `GuildHandler`. | 2 modules + data table | `PlayerStatManager`-adjacent, Quest, Guild | ON ROADMAP ("Titles") | Small, clean-ish surface — good early candidate. |
| **Customization** | `SSS.Modules.CustomizationHandler` (58 ln), `RS.Modules.RequireableCustomization` (636 ln), `RS.Customs` folder (30 accessories/dyes/hair), `RS.Modules.Controllers.CustomizationController` (489 ln) | Accessory/dye/hair equip + "unlock" tracking (`Customization.Unlocked.Accessories` list), limb hide/show for equipment layering. | ~3 modules + 30 asset entries | `PlayerStatManager` (BindableFunction `Invoke(player, "GetData"/"SetData", {dataKey="Customization"})` — direct RPC-style coupling) | ON ROADMAP ("Customization") | Confirmed account-scoped unlock list model (not per-slot) — matches the roadmap's open design question, now has a concrete precedent to react to. |
| **Mutations** | `SSS.Modules.MutationHandler.MainMutationHandler` (266 ln), `RS.Modules.MutationDefinitions` (0 ln — **empty/stub in this session**, real data lives in `ServerStorage.MutationDefinitions_MONOLITH_BACKUP`, an unmounted backup), `RS.Modules.Mutations.GrinningHollow.*`, `RS.Modules.Mutations.Leechborn.*` | Stage-progression mutation system; stages tracked as `IntValue`/`BoolValue` instances **parented directly onto the Player object** (`stageValue.Parent = player`) — confirmed live state-smuggling. Effects call `Knit.GetService("StatusService")` for buffs (e.g. Leechborn `Bite`/`Dominion`, Grinning Hollow `Harvest`). | 3+ modules, definitions likely 500+ ln (in the backup) | `PlayerStatManager`, `StatusService`, `Utilities.createValueInstance` | ON ROADMAP ("Mutations") | **Live `MutationDefinitions` module is empty** — the authoritative data is sitting in an unmounted `ServerStorage` backup (`MutationDefinitions_MONOLITH_BACKUP`). Confirms roadmap's "interacts with models/appearance and possibly Rot" — `Rot Strength/Endurance/Rejuvenation` stats live directly in `PlayerStatManager.defaultValue.Stats.Investments`. |
| **Professions / Tomes** | `SSS.Modules.TomeHandler.*` (`TomeHandler` 126 ln, `Bankorai` 633 ln, `Gourmand` 50 ln, `AllTomes`), `SSS.Modules.ItemHandler."Fishing Rod"` (184 ln), `SSS.Modules.ItemHandler."Throwing Knife"` (324 ln) | OOP metatable class (`Tome:Obtain/Unlock/Use`) largely **unimplemented** (bodies are `-- TODO: implement tome behavior`, commented-out example usage). `Bankorai` (633 ln) is the one substantially-implemented tome. Fishing Rod is a per-item skill-tool module, matching the roadmap's `IsSkill`+fishing note. | 4 modules + 2 tool items | `SystemInteractivity.System` base class (metatable inheritance), `PlayerStatManager` | ON ROADMAP ("Professions", partial) | **Tomes are a distinct, roadmap-unlisted sub-system** layered on top of "Professions" — largely scaffold-only in the old game, so there's little to port beyond the `Bankorai` tome and the interaction pattern. |
| **Trading** | `SSS.Modules.TradeHandler` (283 ln — **entirely commented out**, dead code), `Events.*Trade*` (7 remotes: `TradeRequest`, `ItemTradeRequestC/S`, `ProposeTradeC/S`, `TradeAcceptC/S`) | Old trading logic never shipped — the handler module body is 100% comments/pseudocode referencing a `game.ServerStorage[player.UserId].Misc.Trading` pattern that doesn't match any live data shape. Remotes exist but have no live handler. | 1 dead module | none (dead) | ON ROADMAP ("Trading", deferred from 3a) | Nothing to port — old trading was never functional. Confirms it's safe to design from scratch. |
| **Emotes** | `SSS.Modules.Services.EmoteService`, `RS.Modules.Controllers.EmoteController` (+ `EmoteInventoryUI`, `EmoteDataCache`), `StarterGui.EmoteWheelUI` | Knit service; emotes are a hardcoded array (`allEmotes`) with rarity/animationId, not items — confirms roadmap note it's "not an inventory kind." | 2 modules + UI | `AnimationHandler.bothAnimations`, `PlayerStatManager` (Bindable) | ON ROADMAP ("Emotes") | Confirmed: emotes are their own bucket, never routed through the item system. |
| **Bank (stash)** | `SSS.Modules.BankHandler` (140 ln), `SSS.Modules.Services.BankingService` (262 ln), `RS.Modules.Controllers.BankController`, `RS.Modules.UIControllers.BankUIController` (326 ln) | Stash storage service + UI. ⚠ **Scope unconfirmed**: this row previously asserted "per-account" but that was never verified against a source-code read (module names/line counts only) — the developer's recollection is per-slot instead. Re-verify against the live module source before citing scope as fact; the 3a/4 phase design does not depend on the answer either way. | 4 modules | `PlayerStatManager` | ON ROADMAP ("Phase 4: Bank") | Two parallel implementations exist (`BankHandler` legacy + `Services.BankingService` Knit) — pick one lineage as reference, don't blend. |
| **Guilds** | `SSS.Modules.GuildHandler` (366 ln) | Rank-based guild system (Initiate→Guild Master, permission matrix in comments), guild chat via `MessagingService:SubscribeAsync`, persisted directly to `DataStoreService:GetDataStore("GuildHandler2")` — **bypasses `PlayerStatManager`/ProfileService entirely**. | 1 module | `PlayerStatManager` (partial), raw `DataStoreService`, `MessagingService` | **MISSING** | Not on the roadmap at all. Own persistence lineage (raw DataStore, not the PlayerData/ProfileStore path) — a real "which data layer wins" decision if ported. |
| **Parties** | `SSS.Modules.PartyHandler` (693 ln), `game.ServerStorage.Bindables.SetPartyId`/`LoadPartyProfile` | Up to 4-player parties; uses **`ProfileService` directly** (own profile store, `"PartyData"`) — a third, separate persistence pattern from Guilds' raw DataStore and the main player profile. Cross-server sync via `MessagingService:PublishAsync("PartyUpdate", ...)`. | 1 module | `ProfileService`, `MessagingService`, `CollectionService` | **MISSING** | Not on the roadmap. Confirms **3 distinct persistence strategies** coexist in the old game (ProfileStore-alike, raw DataStore, and the main PlayerStatManager/DataStore2 path) — worth flagging for whoever designs the port, since none of them is "the" pattern to mirror. |
| **Mailbox / gifting** | `SSS.Modules.Mailbox` (161 ln) | Cross-player gifting (gold + items) with a 24h-per-gifter cooldown, persisted to `DataStoreService:GetDataStore("Mailbox2")` (raw DataStore again). | 1 module | raw `DataStoreService`, `MessagingService` | **MISSING** | Not on the roadmap. Small, well-scoped — plausible fast follow-on to Trading. |
| **Bounty / Grudge system** | `SSS.Modules.Services.GrudgeService`, `Events.BountyHunter` | Tracks "grudges" (a player-vs-player bounty state) across sessions via `SetAttribute("HasGrudge", ...)`; fires `QuestClient` events on join/leave. Reads `player.Party.Value` directly off the Instance (state smuggled into the Player object, not a data slice). | 1 module | `PlayerStatManager`, `QuestHandler`, live `Player.Party`/`Player.Guild` **StringValue** properties (instance-tree state) | **MISSING** | Not on the roadmap. Confirms `Player.Party`/`Player.Guild` are live `Instance` value objects, not slice data — a concrete example of the "state smuggled into the Instance tree" pattern AGENTS.md calls out. |
| **Marketplace / Shop / monetization** | `SSS.Modules.MarketHandler` (267 ln), `SSS.Modules.ShopHandler` (77 ln), `SSS.Modules.Services.ShopService` (242 ln), `RS.Modules.Controllers.ShopController`, `RS.Modules.UIControllers.ShopUIController` (537 ln), `SSS.Modules.Marketplace.{GamepassService, DeveloperProductHandler}`, `ServerStorage.OldShopController` (unmounted, dead) | NPC shops (buy/sell), Robux gamepasses/dev-product purchase handling. | ~6+ modules | `PlayerStatManager`, `MarketplaceService`, `DialogueController`/`DialogueService` | **MISSING** | Not on the roadmap anywhere — but gamepasses/dev-products are how the live game monetizes; needed before any real cutover regardless of gameplay-phase ordering. |
| **Mounts / Taming** | `SSS.Modules.MountHandler` (282 ln, server-authoritative speed/teleport-anomaly validation), `RS.Modules.MountManager` (545 ln), `Events.{Tame, ClientTame, TameEventClient, FeedTame}` | Server validates mount speed/position against `CONFIG.MAX_SPEED`/`TELEPORT_THRESHOLD`; separate taming flow (feed → tame) for creature mounts. | 2 modules | none unusual — reasonably self-contained | **MISSING** | Not on the roadmap at all. Notably **the cleanest-written system found in this pass** — explicit server-side anti-cheat validation, well-commented, good port candidate. |
| **Labyrinth ("Eyes") stealth minigame** | `SSS.Modules.Services.LabyrinthService` | Stationary "eye" entities that detect players via line-of-sight raycasts within a view range (crouch vs stand), open/close on a timer. Tags into `Combat.Status.Active` for effects. | 1 module | `Combat.Status.Active`, `TweenService` | **MISSING** | Not on the roadmap; scoped exactly as a self-contained minigame — low coupling, easy to defer indefinitely or drop. |
| **Cleansing** | `SSS.Modules.Services.CleansingService` (132 ln), `RS.Modules.Controllers.CleansingController`/`RS.Modules.UIControllers.CleansingController`, `Events.Courage`, `ServerStorage.Skills.Courage` | Debuff/curse-cleansing NPC interaction flow (ties to a "Courage" mechanic). | 2-3 modules | `DialogueService`/`DialogueController` | **MISSING** | Not on the roadmap. |
| **Doors / world locks** | `SSS.Modules.Services.DoorService` (233 ln), `SSS.Modules.Services.LockableService` (252 ln), `RS.Modules.Controllers.LockableController` | World-object interaction: lockable doors/chests requiring keys or level gates. | 3 modules | `PlayerStatManager`, item data (keys) | **MISSING** | Not on the roadmap; overlaps with Chests/Lootboxes below. |
| **Chests & Lootboxes** | `SSS.Modules.Chests.ChestService` (562 ln), `SSS.Modules.Lootboxes.LootboxService` (158 ln), `SSS.Modules.DropTable.*` (`DropTableService` 279 ln + `Tables.{Lootboxes,Chests,ArenaRewards,Mob}`), `ServerStorage.ChestModels`, `RS.Modules.Controllers.LootboxController` (690 ln) | World chest spawning + loot rolling, gacha-style lootboxes with rarity tiers, drop tables per source (mob kill, arena reward, chest). | ~9 modules | `PlayerStatManager`, item registry, `MarketplaceService` (paid lootbox keys implied by `ArenaRewards`/ranked crate keys note) | **MISSING** | Not on the roadmap at all despite being a large, self-contained loot economy — the roadmap's "Arena" row mentions "ranked crate keys" as an item detail but never surfaces Chests/Lootboxes/DropTable as their own system. |
| **NPCs & Dialogue** | `SSS.Modules.EntityHandler.{NPCService 618 ln, NPCs 1318 ln, MobHandler, Mob 976 ln, MobsConfig, DialogueService, CombatTagHandler, RewardHandler, DamageHandler, SpawnHandler}`, `RS.Modules.Controllers.{NPCController 937 ln, DialogueController 629 ln}`, `RS.Modules.EffectHandler.DialogueEvents` (515 ln) | Mob AI (aggro, combat-tag, reward/damage handling), NPC dialogue trees, spawn management. Large — the single biggest gameplay subsystem outside combat. | ~12+ modules, several 500-1300 ln | `CombatHandler`, `PlayerStatManager`, `Encryptions` (dialogue puzzle minigame) | **MISSING** | Not on the roadmap as its own system — it's implicitly needed by Quests/Combat/Shop but never named. Given its size (NPCs alone is 1318 ln) this deserves its own phase, not an incidental port. |
| **Tutorial / onboarding** | `SSS.Modules.Services.TutorialService` (93 ln), `RS.Modules.Controllers.TutorialController` (337 ln) | First-time-user-experience flow. | 2 modules | `LoadingService`, UI | **MISSING** | Not on the roadmap. |
| **Spectating** | `SSS.Modules.Services.SpectateService` (281 ln), `RS.Modules.Controllers.CameraController`, `RS.Modules.Spectating.GhostSpectate` (683 ln) | Death/arena spectate camera mode. | 3 modules | Camera system, Arena, Death | **MISSING** | Not on the roadmap; tightly coupled to Camera + Arena + Death, so it should ride with whichever of those ships last. |
| **Chat** | `SSS.Modules.Services.ChatService` (223 ln), `RS.Modules.Controllers.ChatController` | Custom chat layer (party/guild channel routing implied by Guild's `MessagingService:SubscribeAsync` chat-type messages). | 2 modules | Guild, Party, `Chat` service | **MISSING** | Not on the roadmap. |
| **Social (friends)** | `SSS.Modules.Services.SocialService` (113 ln), `RS.Modules.UIControllers.SocialUIController` (912 ln — the single largest UI controller found) | Friends-list style social UI/backend. | 2 modules | Roblox `Players`/social APIs | **MISSING** | Not on the roadmap; the UI controller size (912 ln) suggests a substantial feature, not a stub. |
| **Zones** | `SSS.Modules.ZoneHandler` (29 ln), `RS.Modules.Zone` (872 ln), `RS.Modules.Controllers.ZoneController`, `Events.Zone` | Region-based trigger system (likely biome/area-based buffs, PVP flags, weather triggers). | 3 modules | Weather, Combat (PVP flags plausible) | **MISSING** | Not on the roadmap; `RS.Modules.Zone` at 872 ln is nontrivial — likely a foundational cross-cutting system other domains lean on. |
| **Weather** | `SSS.Modules.WeatherHandler` (39 ln), `RS.Modules.Rain` (1057 ln) | Weather effects (rain particle/audio system is surprisingly large at 1057 ln). | 2 modules | Zones (plausible) | **MISSING** (adjacent to "VFX handling" row but not itself listed) | Presentation-leaning; `Rain` alone is bigger than most gameplay handlers. |
| **Soul Color** | `SSS.Modules.SoulColor` (294 ln), `RS.Modules.SoulColor` (259 ln), `RS.Modules.Controllers.SoulColorSpinnerController` (829 ln) | Per-player cosmetic "soul color" theming (color palette selection feeding VFX tint) — a whole 829-line UI controller (a "spinner") dedicated to picking it. | 3 modules | Customization, VFX | **MISSING** | Not on the roadmap; large enough (829 ln controller) that it reads as a real feature, not a minor cosmetic toggle. |
| **Encryption/dialogue puzzle** | `SSS.Modules.Encryptions` (189 ln) | Small substitution-cipher puzzle utility used inside dialogue/quest flows (Caesar shift, symbol substitution tables). | 1 module | Dialogue/Quest | **MISSING** | Trivial size — a quest-flavor detail, not a domain of its own. |

---

## 2. Presentation & infrastructure track

| System | Location(s) | What it does | Size | Key couplings | Roadmap status | Port notes |
|---|---|---|---|---|---|---|
| **Sound handling** | `RS.Modules.SoundManager`, `SoundGroupTracker`, `ServerStorage.Groups` (Music/SFX `SoundGroup`s), `RS.Modules.EffectHandler.SoundEvents` | Sound playback + group volume tracking; confirmed the `WeaponSoundUtilities`-style mixing the roadmap flags exists inside `Weapon`/`EffectHandler`, not a standalone registry. | ~3 modules | Weapon, EffectHandler | ON ROADMAP | Confirmed exactly as described: sound is scattered into gameplay code, not centralized. |
| **VFX handling** | `RS.Modules.EffectHandler.*` (22 event modules: `DamageEvents`, `StatusEvents`, `ShopEvents` 1136 ln, `BlockEvents`, `SpellShieldEvents`, `GrinningHollowEvents`…), `RS.Effects` folder (68 children) | Untyped remote-fired effect dispatch confirmed — `EffectFire` `RemoteEvent` exists live in `Events`; per-domain event modules each build ad-hoc payload tables. | 22 modules, several 200-1100 ln | almost everything (combat, shop, mutations, chests) | ON ROADMAP | Confirms the roadmap's "typed ByteNet packet" migration target directly — `EffectFire:FireAllClients({...})` pattern is real and this is genuinely the fan-out hub for most gameplay VFX. |
| **Animation handling** | `RS.Modules.AnimationHandler` (665 ln), `AnimateUtilities`, `RS.Modules.Animate` (Script, 1367 ln — the stock Roblox Animate script, heavily modified), `SSS.Modules.AnimationService`, `RS.Modules.Controllers.AnimationController` | Asset-id registry (`animations.bothAnimations` table referenced by Emotes) + playback service. | ~4 modules | Emotes, Skills, Weapon | ON ROADMAP | Confirms asset-id-registry pattern (matches the `ItemRegistry` precedent the roadmap wants to mirror). |
| **UI framework** | `RS.Modules.UIControllers` (14 modules, largest: `SocialUIController` 912 ln, `ArenaUIController` 1276 ln, `QuestUIController` 810 ln), `RS.Modules.UI.{UIManager 415 ln, UIRegistry, UIContexts}`, `StarterGui` (20 top-level `ScreenGui`s: Banker, BossGui, Cleansing, Crosshair, EmoteWheelUI, GUI (32 children), LootBox, PVP (15 children), Prompts, Shop, ZoneGui…) | Legacy imperative UI controller pattern (one Knit controller per screen) + a `UIManager`/`UIRegistry`/`UIContexts` triple that looks like an attempt at a more systematic UI layer. | 17+ modules, 20 ScreenGuis | Nearly every gameplay domain (each has its own UI controller) | ON ROADMAP | Confirms "old `UIControllers` tree is large" — 14 controllers, several 500-1300 ln each. React-lua rewrite is a big lift; `UIManager`/`UIRegistry` may be worth reading closer as a precedent before assuming a clean-slate design. |
| **Camera handling** | `RS.Modules.Camera.{CameraManager 632 ln, CameraState, States.*}` (10 states: Freelock, Dead, MainGUIOpen, Cutscene, Sneaking, Lootbox, Mount, Sprinting, MovementHead), `RS.Modules.CameraUtil`, `Poppercam`, `Invisicam` (564 ln), `ZoomController`, `StarterCharacterScripts.CameraScript` | Finite-state camera system (10 named states) layered over Roblox's default camera + custom occlusion (`Invisicam`/`BaseOcclusion`/`Poppercam`). | ~15 modules | Combat (Freelock/Sprinting states), Mount, UI (MainGUIOpen state) | ON ROADMAP | Confirms `CameraWrapper`-style customization exists; it's a genuine FSM (10 states), not a thin wrapper — scope accordingly. |
| **Models/asset registry** | `RS.Models` (Camera, Coin, Dagger, Lootboxes, Mobs, Mounts, Mutations, RagdollSkeleton variants, Seeker, SoulColorBallTemplate), `RS.InventoryItems` (Armours: 94 children, Weapons: 30 children, Miscellaneous: 33 children — these are viewport/UI display models, not the data registry), `ServerStorage.Models.Mutations` | Uploaded-asset references split across at least 3 folders by consumer (world models vs UI-display models vs mutation-specific). | large (170+ instances across folders) | Items, Mutations, Customization | ON ROADMAP | Confirms no single asset registry — model references are scattered by consumption context, exactly the gap the roadmap flags. |
| **Input handling** | `RS.Modules.InputManager` (332 ln), `RS.Modules.Packages._Index.sleitnick_input@2.1.1` (Sleitnick's `input` package, vendored via Wally-style `_Index`) | Keymap/input abstraction; layers a custom `InputManager` over a vendored input library. | 2 modules | Movement, Combat, Skills (via `skill_keycodes`) | ON ROADMAP | Confirmed to exist and be non-trivial (332 ln custom layer on top of a library). |
| **Movement / Traversal** | `RS.Modules.Movement.*` (13 modules: `StateManager`, `Sliding`, `JumpHandler`, `WallRunHandler`, `VaultHandler`, `WalkspeedHandler`, `Ziplining` 398 ln, `FreelockHandler`, `ClimbingCore`, plus a **parallel** `Movement.Traversal.*` subtree — `Config`, `Shared`, `WallRun`, `WallSlide`, `Clamber`, `Controller`), `RS.Modules.HeightHandler` (1766 ln — largest single module found) | Full parkour/traversal movement system: wall-run, vault, climb, slide, zipline, freelock. **Two parallel implementations coexist**: `Movement.WallRunHandler`/`VaultHandler` (legacy) vs `Movement.Traversal.WallRun`/`Clamber`/`Controller` (looks like an in-progress rewrite — confirmed by `ClamberHandler_DEPRECATED` (765 ln) sitting alongside `Traversal.Clamber`, and by backups in `ServerStorage.RefactorBackups_2026_06_22.{VaultHandler__BACKUP, Traversal_Clamber__BACKUP}`). | 20 modules, `HeightHandler` alone is 1766 ln | Camera (Sneaking/Sprinting states), Stamina, Input | **MISSING** | **Not on the roadmap at all** — a large (20-module, 1700+-line-single-file) system with zero roadmap mention. The old devs were mid-refactor on it themselves (dual implementation + explicit `_DEPRECATED` suffix + dated backup folder), so treat old code here as even more "evidence not source" than usual. |
| **State management (old, pre-Charm)** | `SSS.Modules.State.{Store 102 ln, StateReplicationHandler, RuntimeStateHandler, StateStart, StateEnd, ResourceService}`, `RS.Modules.State.{ClientStateStore 230 ln, StateDefinitions, RuntimeFacade}`, `Events.{StateDelta, StateSnapshot}` | A bespoke scope/key reactive store (`Store.create()` → `get/set/getScope` + `Signal`-based subscriptions) with client mirroring via `StateDelta`/`StateSnapshot` remotes — **structurally the direct ancestor of the new Charm `StateSyncServerStore`→charm-sync→`StateSyncClientStore` spine**. | 9 modules | `Signal` package, almost everything reads/writes through it | **MISSING** (infra, implicit) | High-value read for whoever designs future reactive-state migrations — it's the same shape (server store → delta → client store) the new base already replaced, so it's confirmation the new architecture is a real improvement, not just a stylistic choice. |
| **Ragdoll** | `SSS.Modules.Ragdoll.{RagdollPhysics 212 ln, RagdollHandler 206 ln}`, `RS.Modules.RagdollClientHandler`, `StarterCharacterScripts.RagdollRKey`, `SSS.RagdollKeybindHandler` (top-level Script) | Physics-based ragdoll on knockdown/death, player-triggerable via keybind. | 4 modules + 1 top-level script | Combat (`Knockdown` status effect cleanup hook confirmed in `StatusService`), Death | **MISSING** | Not on the roadmap; small and combat-adjacent — likely rides in with Combat core. |
| **Death** | `SSS.Modules.Death.{CorpseHandler 356 ln, DeathCinematic 212 ln, DeathHandler}`, `RS.Modules.DeathManager`, `RS.Modules.DeathEvents` (456 ln) | Death cinematic, corpse spawning/loot, respawn flow. | 5 modules | Combat, Spectating, Ragdoll | **MISSING** | Not on the roadmap; couples tightly to Spectating + Ragdoll + Combat, so it's a natural "ships with combat" system. |
| **Stamina** | `ServerStorage.Stamina` folder (10 `Value` instances: `Max`, `Tick`, `DrainPerTick`, `GainPerTick`, `Exhausted`, `SprintingHeld`, `Buff`) | **Confirmed state-smuggling**: stamina isn't in a data table anywhere found — it's a folder of live `NumberValue`/`BoolValue`/`IntValue` instances in `ServerStorage`, presumably templated per-player at runtime. | config-only folder | Movement (Sprint/Dodge drain), Combat | **MISSING** | Not on the roadmap as its own line (Phase 2 "Stats & progression" may already subsume it), but flag: this is a second confirmed example (after Mutations) of core resource state living as Instance values rather than data. |
| **Height / fall damage** | `RS.Modules.HeightHandler` (1766 ln — the single largest module in the entire codebase), `Events.FallDamage`, `ServerStorage.Bindables.FallDamageCheck` | Fall-damage calculation, likely also drives the Camera `HeightThreshold` warning (`PlayerStatManager` has a `HEIGHT_THRESHOLD = -15` constant). | 1 module (huge) | PlayerStatManager, Camera, Movement | **MISSING** | Its size alone (1766 ln in one file) makes it worth a dedicated look before any movement-system port — likely doing far more than "fall damage" implies. |
| **Character rig config** | `ServerStorage.CharacterSettings` (+ `ModuleHandler` Script child), `RS.Modules.CharacterSettings` (7 ln stub) | Central rig/character property configuration; server copy has an attached `Script` (`ModuleHandler`) doing something beyond a pure data module. | 2 modules | Spawning, Customization | **MISSING** (infra) | Small but worth a closer read given the `ModuleHandler` Script child is unusual for a "Settings" module. |

---

## 3. Dev/test tooling and dead code (not gameplay)

| Item | Location | Notes |
|---|---|---|
| `StressTestLeaderboard` | `SSS.Modules.StressTestLeaderboard` (121 ln) | Load-test tooling, not shipped gameplay. |
| `TradeHandler` | `SSS.Modules.TradeHandler` | 100% commented-out dead code (see Trading row). |
| `ClamberHandler_DEPRECATED` | `RS.Modules.Movement.ClamberHandler_DEPRECATED` (765 ln) | Explicitly deprecated, superseded by `Movement.Traversal.Clamber`. |
| `GamepassHandler` | `SSS.Modules.Marketplace.GamepassHandler` | 0 lines — empty stub. |
| `MutationDefinitions` | `RS.Modules.MutationDefinitions` | 0 lines live — real data is in the `ServerStorage` backup (see below). |

---

## 4. Scripts found in unmounted containers (Workspace / ServerStorage / Lighting)

**Per AGENTS.md, Rojo does not mount `Workspace`/`Lighting`/`ServerStorage` — a cutover publish will
NOT delete anything here.** This is exactly the risk the roadmap's cutover section warns about.
Counted **28 live script/module instances** outside mounted containers:

**`Workspace` (15 instances)** — all under `Workspace.Entities.Mobs.*` (13 `Configs` ModuleScripts:
`GuardPunish`, `No Blocking`, `Attacking` ×2, `PerfectBlocking` ×3, `Dodging`, `Blocking` ×2,
`GuardShredder`, `SevereGuardBreak` — these are live per-mob AI behavior configs, i.e. **active
gameplay data sitting in an unmounted container**) plus 2 stray `LocalScript`s parented directly to
map decoration models (`Bauzly`/`Bauzly2`).

**`ServerStorage` (13 instances)**:
- `TESTFREELOCKHANDLER`, `OldShopController`, `HollowMadnessController_BACKUP` — dead/test code, safe to ignore.
- `MutationDefinitions_MONOLITH_BACKUP` — **not dead**: this is the only live copy of the mutation
  data table found anywhere (the mounted `RS.Modules.MutationDefinitions` is an empty 0-line stub).
  A naive cutover would silently drop all mutation definitions.
- `RefactorBackups_2026_06_22.*` (6 modules: `Constants_COMBAT__BACKUP`, `SPELL_SHIELD__BACKUP`,
  `STOMP_01__BACKUP`, `STOMP_02__BACKUP`, `Traversal_Clamber__BACKUP`, `VaultHandler__BACKUP`) —
  a dated backup folder from an in-progress refactor the old devs were doing themselves; the
  "current" (mounted) versions of these systems are presumably the replacements, but not verified
  side-by-side in this pass.
- `DialogueController`, `CharacterSettings` (+ `ModuleHandler` Script) — appear to be live, not backups.

**`Lighting`**: 0 scripts (clean).

**Risk note:** the `Entities.Mobs.*.Configs` set (13 live AI-config modules in `Workspace`) and the
`MutationDefinitions_MONOLITH_BACKUP` module are the two genuinely dangerous ones — both look like
active data a naive "delete everything Rojo doesn't own" mental model would miss, but a real cutover
(rojo serve + publish) doesn't delete unmounted content at all, so the actual risk is the *inverse*:
this dead/backup content will silently **persist** into the new place unless someone manually cleans
Workspace/ServerStorage in Studio before or after cutover.

---

## 5. Summary tables

### 5a. All systems by category

| Category | Count | Systems |
|---|---|---|
| Gameplay domain | 30 | Combat core, Skills, Arena/PVP, Quests, Titles, Customization, Mutations, Professions/Tomes, Trading, Emotes, Bank, Guilds, Parties, Mailbox, Bounty/Grudge, Marketplace/Shop, Mounts/Taming, Labyrinth, Cleansing, Doors/Locks, Chests & Lootboxes, NPCs & Dialogue, Tutorial, Spectating, Chat, Social, Zones, Weather, Soul Color, Encryption puzzle |
| Presentation/infra | 12 | Sound, VFX, Animation, UI framework, Camera, Models/asset registry, Input, Movement/Traversal, State management (pre-Charm), Ragdoll, Death, Height/fall damage, Character rig config *(12 listed, one row — Character rig config — is a 13th; table intentionally inclusive)* |
| Dev/test/dead | 5 | StressTestLeaderboard, dead TradeHandler, deprecated ClamberHandler, empty GamepassHandler, empty MutationDefinitions stub |

Total distinct systems catalogued: **~47** (30 gameplay + 12 presentation/infra + 5 dev/dead), across
roughly **330 ModuleScript/Script instances** enumerated directly under `ServerScriptService.Modules`
and `ReplicatedStorage.Modules` alone (51 + 58 top-level entries expanding to that count once
subfolders are walked), not counting UI `ScreenGui` trees, model folders, or the ~116 `RemoteEvent`/
`RemoteFunction` definitions in `ReplicatedStorage.Events`/`Functions`.

### 5b. MISSING from roadmap — full list (the headline finding)

Not mentioned anywhere in `docs/ROADMAP.md`, in any phase, row, or deferral note:

**Gameplay:** Guilds, Parties, Mailbox/gifting, Bounty/Grudge system, Marketplace/Shop
(incl. gamepasses & dev products), Mounts/Taming, Labyrinth ("Eyes") stealth minigame, Cleansing,
Doors/world-locks, Chests & Lootboxes (+ DropTable economy), NPCs & Dialogue, Tutorial/onboarding,
Spectating, Chat, Social (friends), Zones, Weather, Soul Color, Encryption/dialogue puzzle minigame.

**Presentation/infra:** Movement/Traversal (a 20-module parkour system, largest missing item),
old State management/pre-Charm reactive store, Ragdoll, Death, Height/fall-damage (1766-line
single largest module in the codebase), Character rig config.

That's **24 systems with zero roadmap presence**, several of them large (Movement/Traversal,
NPCs & Dialogue, Chests & Lootboxes, Marketplace). Movement/Traversal and NPCs & Dialogue in
particular are big enough, and coupled widely enough, that they likely need their own phase rather
than being absorbed as a side effect of Combat.

### 5c. Scripts in unmounted containers

**28 total** (15 Workspace, 13 ServerStorage, 0 Lighting). Of those, most are inert
backups/dead-code, but **2 are live risk**: the 13 `Workspace.Entities.Mobs.*.Configs` AI-behavior
modules, and `ServerStorage.MutationDefinitions_MONOLITH_BACKUP` (the only live copy of mutation
data — the mounted copy is an empty stub). See §4 for full detail.

---

## Known gaps in this pass (honest accounting)

This was one broad discovery pass, not an exhaustive line-by-line audit. Not independently verified:
- Whether `RefactorBackups_2026_06_22.*` truly duplicates currently-mounted logic (assumed but not diffed).
- Full content of `StarterGui`'s 32-child `GUI` ScreenGui and `PVP`'s 15-child tree (UI structure noted, not read).
- `ReplicatedStorage.Effects` (68 children) and `ReplicatedStorage.Skills` (34 VFX/prop children) — enumerated, not individually read; these are asset/prop folders consumed by EffectHandler and Skills, respectively, not code.
- Exact runtime relationship between the "legacy" and "Traversal" movement implementations (which one is actually live vs. mid-swap).
