--!strict
--[=[
	SpecRoots: the single source of truth for where TestEZ specs live.

	TestEZ does NOT scan recursively from src — both runners (TestRunner.server.luau in Studio,
	tasks/runTests.luau in CI) pass exactly this root list. A spec created outside these roots
	would silently never run, so `assertAllSpecsCovered` sweeps the containers Rojo builds into
	and errors on any `*.spec` ModuleScript that is not under a listed root.

	Adding a new spec location = add the root here; both runners and the guard pick it up.

	Runtime note: this module ships in the production place (it is not spec code), but nothing
	requires it outside the two test entry points, so it never executes in production.

	@class SpecRoots
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local StarterPlayer = game:GetService("StarterPlayer")

local SpecRoots = {}

--[=[
	The roots TestEZ scans: Core, Data and Features in each realm, the client tree (features and UI),
	and the Cmdr commands.
	@return { Instance }
]=]
function SpecRoots.get(): { Instance }
	return {
		ReplicatedStorage.Shared.Core,
		ReplicatedStorage.Shared.Data,
		ReplicatedStorage.Shared.Features,
		ReplicatedStorage.Client,
		ServerScriptService.Commands,
		ServerScriptService.Core,
		ServerScriptService.Features,
	}
end

--[=[
	Errors if any FIRST-PARTY `*.spec` ModuleScript in the built place sits outside the scanned
	roots. Swept containers: everything default.project.json maps source into. Two kinds of
	non-first-party trees are excluded:
	- Vendored Wally package trees (Packages/ServerPackages/DevPackages) — several dependencies
	  ship their own `.spec` files (e.g. evaera_promise, jsdotlua_promise) which are not this
	  project's tests and are intentionally never run.
	- `StarterPlayer.StarterPlayerScripts.PlayerModule` — Roblox's own default camera/control
	  scripts, which the engine auto-provisions at runtime independent of what's actually in the
	  uploaded place file (this repo's `src/StarterPlayer/StarterPlayerScripts` never contains a
	  PlayerModule; confirmed by `rojo build` producing no such instance from source alone, yet a
	  live Luau execution task still saw one — Roblox re-inserts it whenever it's absent). Its
	  nested `CommonUtils` folder happens to contain modules ending in `.spec` (e.g. CameraWrapper,
	  ConnectionUtil) that are not TestEZ specs at all, just Roblox's own naming.
	- `ReplicatedStorage.Modules` — legacy code in an existing place this base is synced into.
	  `ReplicatedStorage` is mounted with `$ignoreUnknownInstances`, deliberately, so that Rojo cannot
	  delete the artist-owned `Assets` folder (see the deployment model in AGENTS.md). The same flag
	  means every legacy folder in an art-bearing place also survives a sync — including vendored
	  libraries (an old Knit `Packages/_Index` tree, for one) that ship `.spec` modules which are not
	  this project's tests. Nothing here is built from `src/`.
	@param roots { Instance } -- The roots about to be passed to TestBootstrap:run
]=]
function SpecRoots.assertAllSpecsCovered(roots: { Instance })
	local containers: { Instance } = { ReplicatedStorage, ServerScriptService, StarterPlayer }

	-- Non-first-party trees to skip. Wally mounts Packages/DevPackages under ReplicatedStorage and
	-- ServerPackages under ServerScriptService (see default.project.json); PlayerModule is Roblox's
	-- own runtime-provisioned default under StarterPlayerScripts, not ours or Wally's.
	local excludedFolders: { Instance } = {}
	for _, name in { "Packages", "ServerPackages", "DevPackages" } do
		local folder = ReplicatedStorage:FindFirstChild(name) or ServerScriptService:FindFirstChild(name)
		if folder then
			table.insert(excludedFolders, folder)
		end
	end
	local playerModule = StarterPlayer.StarterPlayerScripts:FindFirstChild("PlayerModule")
	if playerModule then
		table.insert(excludedFolders, playerModule)
	end
	-- An existing game's legacy tree, present in a place synced over an older game and absent from a
	-- clean build. Matched by NAME rather than by content: `src/ReplicatedStorage` has no `Modules`
	-- child (this project's shared code lives under `Shared`), so nothing first-party can land here.
	local legacyModules = ReplicatedStorage:FindFirstChild("Modules")
	if legacyModules then
		table.insert(excludedFolders, legacyModules)
	end

	local orphans: { string } = {}

	for _, container in containers do
		for _, descendant in container:GetDescendants() do
			if not (descendant:IsA("ModuleScript") and descendant.Name:match("%.spec$")) then
				continue
			end
			local excluded = false
			for _, folder in excludedFolders do
				if descendant:IsDescendantOf(folder) then
					excluded = true
					break
				end
			end
			if excluded then
				continue
			end
			local covered = false
			for _, root in roots do
				if descendant == root or descendant:IsDescendantOf(root) then
					covered = true
					break
				end
			end
			if not covered then
				table.insert(orphans, descendant:GetFullName())
			end
		end
	end

	if #orphans > 0 then
		error(
			`{#orphans} spec(s) exist outside the scanned test roots and would NEVER run: `
				.. table.concat(orphans, ", ")
				.. ". Move them under a root or add the location to SpecRoots.get()."
		)
	end
end

--[=[
	First-party modules that intentionally have NO `.spec` sibling, keyed by full DataModel name with
	the reason as the value (for self-documentation). This is the escape hatch for
	`assertAllModulesSpecced`: a module belongs here only when a unit test would be tautological or
	genuinely can't run under TestEZ. Everything else must have a spec — that's what makes the TDD
	rule enforceable instead of aspirational. Adding a NEW module forces a choice: write its spec, or
	add a line here justifying why not.
]=]
local EXEMPT_MODULES: { [string]: string } = {
	["ReplicatedStorage.Shared.Data.PlayerDataTypes"] = "type definitions only (no runtime logic)",
	["ReplicatedStorage.Shared.Data.PublicPlayerTypes"] = "type definitions only (no runtime logic)",
	["ReplicatedStorage.Shared.Data.WorldTypes"] = "type definitions only (no runtime logic)",
	["ReplicatedStorage.Client.Features.Input.Data.InputTypes"] = "type definitions only (no runtime logic)",
	["ReplicatedStorage.Client.Features.Camera.Data.CameraTypes"] = "type definitions only (no runtime logic)",
	["ReplicatedStorage.Client.Features.Camera.Data.CameraConstants"] = "static tuning values (no logic)",
	["ReplicatedStorage.Shared.Features.Sound.Data.SoundTypes"] = "type definitions only (no runtime logic)",
	["ReplicatedStorage.Shared.Features.Sound.Data.SoundConstants"] = "static tuning values (no logic)",
	["ReplicatedStorage.Shared.Features.Sound.Net.SoundEvents"] = "ByteNet packet definitions (no logic)",
	["ReplicatedStorage.Shared.Features.Vfx.Data.VfxTypes"] = "type definitions only (no runtime logic)",
	["ReplicatedStorage.Shared.Features.Vfx.Data.VfxConstants"] = "static tuning values (no logic)",
	["ReplicatedStorage.Shared.Features.Vfx.Net.VfxEvents"] = "ByteNet packet definitions (no logic)",
	["ReplicatedStorage.Shared.Features.Interaction.Data.InteractionTypes"] = "type definitions only (no runtime logic)",
	["ReplicatedStorage.Shared.Features.Interaction.Data.InteractionConstants"] = "static names and tuning (no logic)",
	["ReplicatedStorage.Shared.Features.Carry.Data.CarryTypes"] = "type definitions only (no runtime logic)",
	["ReplicatedStorage.Shared.Features.Carry.Data.CarryConstants"] = "static names and tuning (no logic)",
	["ReplicatedStorage.Shared.Features.Carry.Net.CarryEvents"] = "ByteNet packet definitions (no logic)",
	["ReplicatedStorage.Shared.Features.Round.Data.RoundTypes"] = "type definitions only (no runtime logic)",
	["ReplicatedStorage.Shared.Features.Round.Data.RoundConstants"] = "static names and defaults (no logic)",
	["ReplicatedStorage.Shared.Features.Marketplace.Data.MarketplaceTypes"] = "type definitions only (no runtime logic)",
	["ReplicatedStorage.Shared.Features.Marketplace.Data.MarketplaceConstants"] = "static limits and names (no logic)",
	["ReplicatedStorage.Shared.Features.Entitlement.Data.EntitlementTypes"] = "type definitions only (no runtime logic)",
	["ReplicatedStorage.Shared.Features.Setting.Data.SettingTypes"] = "type definitions only (no runtime logic)",
	["ReplicatedStorage.Shared.Features.Setting.Data.SettingConstants"] = "static definitions and limits (no logic)",
	["ReplicatedStorage.Shared.Features.Setting.Net.SettingEvents"] = "ByteNet packet definitions (no logic)",
	["ReplicatedStorage.Shared.Features.Death.Data.DeathTypes"] = "type definitions only (no runtime logic)",
	["ReplicatedStorage.Shared.Features.Death.Data.DeathConstants"] = "static names, defaults and joint limits (no logic)",
	["ServerScriptService.Features.Npc.Data.NpcTypes"] = "type definitions only (no runtime logic)",
	["ServerScriptService.Features.Npc.Data.NpcConstants"] = "static names and tuning (no logic)",
	["ReplicatedStorage.Shared.Features.Voice.Data.VoiceTypes"] = "type definitions only (no runtime logic)",
	["ReplicatedStorage.Shared.Features.Voice.Data.VoiceConstants"] = "static names and tuning (no logic)",
	["ReplicatedStorage.Shared.Features.DailyReward.Data.DailyRewardConstants"] = "static tuning (no logic)",
	["ReplicatedStorage.Shared.Features.DailyReward.Net.DailyRewardEvents"] = "ByteNet packet definitions (no logic)",
	["ReplicatedStorage.Shared.Features.Loot.Data.LootTypes"] = "type definitions only (no runtime logic)",
	["ReplicatedStorage.Shared.Features.Title.Net.TitleEvents"] = "ByteNet packet definitions (no logic)",
	["ReplicatedStorage.Shared.Features.Debugger.Net.DebuggerEvents"] = "ByteNet packet definitions (no logic)",
	["ReplicatedStorage.Shared.Features.Animation.Net.AnimationEvents"] = "ByteNet packet definitions (no logic)",
	-- React UI components — rendered and exercised in-game via the F4 overlay; TestEZ has no
	-- renderer, so a unit test would assert nothing meaningful.
	["ReplicatedStorage.Client.UI.React.Debugger.DebuggerOverlay"] = "React UI component (rendered in-game)",
	["ReplicatedStorage.Client.UI.React.Debugger.LogsPanel"] = "React UI component (rendered in-game)",
	["ReplicatedStorage.Client.UI.React.Debugger.ServicesPanel"] = "React UI component (rendered in-game)",
	["ReplicatedStorage.Client.UI.React.Debugger.StatePanel"] = "React UI component (rendered in-game)",
	["ReplicatedStorage.Client.UI.React.Debugger.TableView"] = "React UI component (rendered in-game)",
	["ReplicatedStorage.Client.UI.React.Debugger.TreeView"] = "React UI component (rendered in-game)",
	["ReplicatedStorage.Client.UI.React.Debugger.AnimationsPanel"] = "React UI component (rendered in-game)",
	["ReplicatedStorage.Client.UI.React.Debugger.UIPanel"] = "React UI component (rendered in-game)",
	["ReplicatedStorage.Client.UI.Scenes.UIDebugScenes"] = "debug harness scene registrations (declarative, no logic)",
	["ReplicatedStorage.Client.UI.React.Debugger.DebuggerTheme"] = "static style tokens (no logic)",
	["ReplicatedStorage.Client.UI.React.Debugger.useDrag"] = "React hook (needs a renderer + pointer input)",
	-- Design system: static tokens + presentational primitives. No logic to assert (screen LOGIC
	-- lives in specced view-models, not in these); verified visually. See docs/testing.md.
	["ReplicatedStorage.Client.UI.React.Tokens"] = "static design tokens (no logic)",
	["ReplicatedStorage.Client.UI.React.Primitives.Button"] = "presentational React primitive (no logic)",
	["ReplicatedStorage.Client.UI.React.Primitives.Panel"] = "presentational React primitive (no logic)",
	["ReplicatedStorage.Client.UI.React.Primitives.ClippedBar"] = "presentational React primitive — the clip-technique sprite bar (no logic)",
	["ReplicatedStorage.Client.UI.React.Primitives.FadeGroup"] = "presentational React primitive — CanvasGroup fade; its easing step TrailEasingUtils is specced",
	["ReplicatedStorage.Client.UI.React.Hooks.useProgressTween"] = "React/TweenService binding shell; normalization and interruption policy covered by ProgressTweenUtils.spec",
	["ReplicatedStorage.Client.UI.React.Hooks.useEasedTrail"] = "React hook — Heartbeat easing over bindings; its pure step TrailEasingUtils is specced",
	["ReplicatedStorage.Client.UI.React.SceneHost"] = "React layer view — renders the stack's screens (selection specced in SceneStack.screensFor)",
	["ReplicatedStorage.Client.UI.React.Debugger.DebugPanelScreen"] = "throwaway harness screen proving the SceneHost render path (no logic)",
	["ReplicatedStorage.Client.UI.React.Screens.Hud.HudRoot"] = "React composition root — composes the HUD widgets + hide gate (no logic)",
	["ReplicatedStorage.Client.Features.UI.Data.UIAssets"] = "static image-asset registry (no logic)",

	-- Client services: thin, network/Cmdr-bound shells whose behavior only manifests against a live
	-- server; integration-tested in-game rather than unit-tested.
	["ReplicatedStorage.Client.Features.Admin.AdminServiceClient"] = "Cmdr-bound client shell (--!nocheck)",
	["ReplicatedStorage.Client.Features.Animation.AnimationServiceClient"] = "network-bound client shell",
	["ReplicatedStorage.Client.Features.Debugger.DebuggerServiceClient"] = "network-bound client shell",
	["ReplicatedStorage.Client.Features.StateSync.StateSyncServiceClient"] = "network-bound client shell",
	["ReplicatedStorage.Client.Features.Input.InputServiceClient"] = "UserInputService/UISuppression shell (rules and trackers are specced)",
	["ReplicatedStorage.Client.Features.Input.Systems.InputControlsSystem"] = "runtime PlayerModule controls toggle (--!nocheck)",
	["ReplicatedStorage.Client.Features.Camera.CameraServiceClient"] = "Camera/RunService shell (maths and stacks are specced)",
	["ReplicatedStorage.Client.Features.Sound.SoundServiceClient"] = "Sound/TweenService/ByteNet shell (registry, formulas and voices are specced)",
	["ServerScriptService.Features.Sound.SoundServiceServer"] = "Players/ByteNet shell (listener selection is specced in SoundFormulas)",
	["ReplicatedStorage.Client.Features.Vfx.VfxServiceClient"] = "Instance/Lighting/RunService shell (formulas, registries and tracker are specced)",
	["ServerScriptService.Features.Vfx.VfxServiceServer"] = "Players/ByteNet shell (listener selection is specced in SoundFormulas)",
	["ServerScriptService.Features.Interaction.InteractionServiceServer"] = "CollectionService/ProximityPrompt shell (InteractionRules and the cooldown tracker are specced)",
	["ReplicatedStorage.Shared.Features.Interaction.Net.InteractionEvents"] = "ByteNet packet definitions (no logic)",
	["ServerScriptService.Features.Interaction.Systems.InteractionChannelSystem"] = "Players/Instance/attribute shell (InteractionChannelTracker and InteractionRules are specced)",
	["ReplicatedStorage.Client.Features.Interaction.InteractionServiceClient"] = "prompt re-keying shell (copies Input bindings onto prompts)",
	["ReplicatedStorage.Shared.Features.Toast.Data.ToastTypes"] = "type definitions only (no runtime logic)",
	["ReplicatedStorage.Shared.Features.Toast.Data.ToastConstants"] = "static defaults and limits (no logic)",
	["ReplicatedStorage.Shared.Features.Toast.Net.ToastEvents"] = "ByteNet packet definitions (no logic)",
	["ServerScriptService.Features.Toast.ToastServiceServer"] = "ByteNet shell (ToastRules is specced)",
	["ReplicatedStorage.Client.Features.Toast.ToastServiceClient"] = "ByteNet/RunService/Sound shell (ToastStore and ToastQueueUtils are specced)",
	["ReplicatedStorage.Client.UI.React.Screens.Hud.ToastStack"] = "React UI component (rendered in-game; story in ToastStack.story)",
	["ReplicatedStorage.Shared.Features.Queue.Data.QueueTypes"] = "type definitions only (no runtime logic)",
	["ReplicatedStorage.Shared.Features.Queue.Data.QueueConstants"] = "static names, defaults and limits (no logic)",
	["ReplicatedStorage.Shared.Features.Queue.Net.QueueEvents"] = "ByteNet packet definitions (no logic)",
	["ServerScriptService.Features.Queue.Systems.QueuePadSystem"] = "CollectionService/character shell (QueuePadRules and QueuePadTracker are specced)",
	["ServerScriptService.Features.Queue.Systems.QueueTeleportSystem"] = "TeleportService shell; teleports cannot run in Studio (QueueDepartureTracker and QueueTeleportRules are specced)",
	["ServerScriptService.Features.Queue.Systems.QueueArrivalSystem"] = "Players/join-data shell; join data exists only after a live teleport (QueueArrivalTracker is specced)",
	["ServerScriptService.Features.Queue.Systems.QueueLandingSystem"] = "character/Players/phase shell (QueueTeleportRules decodes the ticket)",
	["ServerScriptService.Features.Queue.QueueServiceServer"] = "TeleportService/Players/HttpService/signal shell (rules and trackers are specced)",
	["ReplicatedStorage.Client.Features.Queue.QueueServiceClient"] = "ByteNet/HUD registration shell (QueueStore and QueueSnapshotUtils are specced)",
	["ReplicatedStorage.Client.UI.React.Screens.Hud.QueuePadStatus"] = "React UI component (rendered in-game; its panel has a story)",
	["ReplicatedStorage.Client.UI.React.Screens.Hud.QueuePadPanel"] = "React UI component (presentational; story in QueuePadPanel.story)",
	["ServerScriptService.Features.Carry.CarryServiceServer"] = "Instance/physics/ByteNet shell (registry, formulas and hold tracker are specced)",
	["ReplicatedStorage.Client.Features.Carry.CarryServiceClient"] = "Input/ByteNet shell (the server decides)",
	["ServerScriptService.Features.Round.RoundServiceServer"] = "Players/RunService/signal shell (phase rules, run tracker and container utils are specced)",
	["ReplicatedStorage.Client.Features.Round.RoundServiceClient"] = "Charm read facade (decoding is specced in RoundSnapshotUtils)",
	["ReplicatedStorage.Client.Features.Entitlement.EntitlementServiceClient"] = "read facade over the replicated slice (EntitlementRules is specced)",
	["ReplicatedStorage.Client.Features.Setting.SettingServiceClient"] = "Charm/timer/ByteNet shell applying settings to Sound, Camera and Input (rules, registry and keybind utils are specced)",
	["ServerScriptService.Features.Death.DeathServiceServer"] = "Humanoid/joint/Players shell (credit tracker, ragdoll limits and spectate rules are specced)",
	["ReplicatedStorage.Client.Features.Death.DeathServiceClient"] = "Camera/Input/Charm spectate shell (DeathSpectateRules is specced)",
	["ServerScriptService.Features.Npc.NpcServiceServer"] = "Instance/physics/raycast shell (registry, sense, brain, path rules and roster are specced)",
	["ServerScriptService.Features.Npc.Systems.NpcBehaviourSystem"] = "Players/raycast/Humanoid shell (every decision is a specced rule module)",
	["ServerScriptService.Features.Npc.Systems.NpcMoverSystem"] = "PathfindingService/Humanoid shell (repath decisions are specced in NpcPathRules)",
	["ServerScriptService.Features.Voice.VoiceServiceServer"] = "Players/audio Instance shell (routing is specced in VoiceRoutingRules)",
	["ReplicatedStorage.Client.Features.Voice.VoiceServiceClient"] = "audio Instance shell (VoiceRoutingRules and VoiceWiringTracker are specced)",
	["ServerScriptService.Features.Leaderstat.LeaderstatServiceServer"] = "Instance/Players shell (the column catalogue is specced)",
	["ServerScriptService.Features.Badge.BadgeServiceServer"] = "BadgeService shell (BadgeAwardTracker and BadgeRegistry are specced)",
	["ServerScriptService.Features.Analytics.AnalyticsServiceServer"] = "AnalyticsService shell (AnalyticsRules is specced)",
	["ReplicatedStorage.Client.Features.DailyReward.DailyRewardServiceClient"] = "read facade and request sender (DailyRewardRules is specced)",
	["ReplicatedStorage.Client.Features.Marketplace.MarketplaceServiceClient"] = "MarketplaceService prompt shell (the server grants; the registry is specced)",

	-- The Instance-touching half of animation playback: every verb needs a live Animator and real
	-- animation assets, which TestEZ cannot fixture. The cache, bookkeeping, and stop-class rules
	-- all live in the pure core and are fully specced in AnimationPlayerSystem.spec.
	["ReplicatedStorage.Shared.Features.Animation.Systems.AnimationPlayerEngineSystem"] = "Animator-touching shell (core is specced)",

	-- The Instance/ReactRoblox factory behind UILayers: news the ScreenGui root (direct PlayerGui
	-- child, ResetOnSpawn=false) and the React root. Needs a live PlayerGui + renderer; the WHEN-to-
	-- create/tear-down bookkeeping is the pure UILayers core, fully specced in UILayers.spec.
	["ReplicatedStorage.Client.UI.Layers.UILayerHost"] = "Instance/ReactRoblox factory shell (UILayers core is specced)",
	["ReplicatedStorage.Client.UI.Layers.UIBillboardHost"] = "Instance/ReactRoblox/CollectionService factory shell (the root bookkeeping UIBillboards core is specced)",
	["ReplicatedStorage.Client.UI.Layers.UIRoot"] = "trivial shared-singleton wiring (UILayers core is specced)",
	["ReplicatedStorage.Client.UI.Suppression.UISuppression"] = "world-suppression handler shell — the mouse handler touches UserInputService (UIWorldSuppression core is specced)",
	["ReplicatedStorage.Client.Features.UI.UIServiceClient"] = "UI lifecycle shell — stack subscription, the Escape shim, and HUD mounting (the logic it drives is specced)",

	-- Native-character animation shells: the Humanoid-event adapter and the per-character entry script
	-- that binds it. Their logic is the specced AnimationLocomotionSystem core.
	["ReplicatedStorage.Client.Features.Animation.Systems.AnimationLocomotionHumanoidSystem"] = "Humanoid-event adapter (core is specced in AnimationLocomotionSystem.spec)",

	-- Thin typed wrappers over vendored libraries — they add types, not behavior; the one `any` cast
	-- each isolates is the whole point, and there is nothing of ours to assert.
	["ReplicatedStorage.Shared.Core.SignalTyped"] = "typed wrapper over SignalPlus (no logic)",
	["ServerScriptService.Core.ProfileStoreTyped"] = "typed wrapper over ProfileStore (no logic)",

	-- Cmdr command DEFINITIONS (declarative arg schemas). Their `*Server` implementations carry the
	-- logic and ARE specced (AddCurrencyServer.spec, etc.).
	["ServerScriptService.Commands.CurrencyAdd"] = "Cmdr command definition (server impl is specced)",
	["ServerScriptService.Commands.AnimationPlay"] = "Cmdr command definition (server impl is specced)",
	["ServerScriptService.Commands.AnimationStop"] = "Cmdr command definition (server impl is specced)",
	["ServerScriptService.Commands.AnimationStopClass"] = "Cmdr command definition (server impl is specced)",
	["ServerScriptService.Commands.AnimationTracks"] = "Cmdr command definition (server impl is specced)",
	["ServerScriptService.Commands.AnimationReport"] = "Cmdr command definition (server impl is specced)",
	["ServerScriptService.Commands.InventoryGiveItem"] = "Cmdr command definition (server impl is specced)",
	["ServerScriptService.Commands.InventoryRemoveItem"] = "Cmdr command definition (server impl is specced)",
	["ServerScriptService.Commands.CurrencySet"] = "Cmdr command definition (server impl is specced)",
	["ServerScriptService.Commands.TitleAward"] = "Cmdr command definition (server impl is specced)",
	["ServerScriptService.Commands.TitleRevoke"] = "Cmdr command definition (server impl is specced)",
	["ServerScriptService.Commands.TitleEquip"] = "Cmdr command definition (server impl is specced)",
	["ServerScriptService.Commands.RoundStart"] = "Cmdr command definition (server impl is specced)",
	["ServerScriptService.Commands.RoundEnd"] = "Cmdr command definition (server impl is specced)",
	["ServerScriptService.Commands.MarketplacePremiumAdd"] = "Cmdr command definition (server impl is specced)",
	["ServerScriptService.Commands.EntitlementGrant"] = "Cmdr command definition (server impl is specced)",
	["ServerScriptService.Commands.EntitlementRevoke"] = "Cmdr command definition (server impl is specced)",
	["ServerScriptService.Commands.NpcSpawn"] = "Cmdr command definition (server impl is specced)",
	["ServerScriptService.Commands.NpcClear"] = "Cmdr command definition (server impl is specced)",
	["ServerScriptService.Commands.DailyRewardReset"] = "Cmdr command definition (server impl is specced)",

	-- Cleanup Crew: Cargo
	["ReplicatedStorage.Shared.Features.Art.Data.ArtTypes"] = "type-only kit/family contracts; behavior covered by ArtKitRegistry, ArtKitRules and ArtVisualSystem specs",
	["ReplicatedStorage.Shared.Features.Cargo.Data.CargoTypes"] = "type definitions only (no runtime logic)",
	["ReplicatedStorage.Shared.Features.Cargo.Data.CargoConstants"] = "static tuning and names (no logic)",
	["ReplicatedStorage.Shared.Features.Cargo.Net.CargoEvents"] = "ByteNet packet definitions (no logic)",
	["ServerScriptService.Features.Cargo.Systems.CargoScatterSystem"] = "Players/Heartbeat/Instance shell (the entries are the specced CargoInventoryTracker's; placement is CarryPlacementSystem's)",
	["ServerScriptService.Features.Cargo.Systems.CargoInventorySystem"] = "Carry/Vacuum/Instance/public-state/ByteNet/Heartbeat shell (pick-up, slot choice, lock and load decisions are specced in CargoInventoryRules, the slots in CargoInventoryTracker)",
	["ServerScriptService.Features.Cargo.Systems.CargoTraitSystem"] = "Players/Carry/Instance/Sound shell (rattle, puddle and sound decisions are specced in CargoHandlingRules and CargoFeedbackUtils)",
	["ReplicatedStorage.Client.Features.Cargo.Systems.CargoSlipSystem"] = "Humanoid/physics shell (the slip decision CargoHandlingRules.slips is specced)",
	["ServerScriptService.Features.Cargo.CargoServiceServer"] = "Instance/Players/ByteNet/signal shell (handling, inventory and bank rules, claim and inventory trackers are specced)",
	["ReplicatedStorage.Client.Features.Cargo.CargoServiceClient"] = "Input/ContextActionService/StarterGui/Camera/ByteNet shell (slot stepping specced in CargoInventoryRules.step; the server decides)",
	["ReplicatedStorage.Shared.Features.Cargo.Data.CargoAssets"] = "asset id slots; registers the uploaded sounds at load (no decisions)",
	["ReplicatedStorage.Client.Features.Cargo.Systems.CargoBillboardSystem"] = "CollectionService/Camera/RunService/React-root shell (tag and mount rule specced in CargoWorldViewModel; roots in UIBillboards)",
	["ReplicatedStorage.Client.UI.React.Screens.World.CargoLoadFloater"] = "presentational React component (floater specced in CargoWorldViewModel; story in CargoWorld.story)",
	["ReplicatedStorage.Client.UI.React.Screens.World.CargoPriceTag"] = "presentational React component (tag specced in CargoWorldViewModel; story in CargoWorld.story)",
	["ReplicatedStorage.Client.Features.Cargo.Systems.CargoFeedbackSystem"] = "Instance/tween/ByteNet/Charm/React-root shell (choices and arc specced in CargoFeedbackUtils; floater words in CargoWorldViewModel)",
	["ReplicatedStorage.Client.Features.Cargo.Systems.CargoGrimeVisualSystem"] = "Highlight/particle/RunService shell (grime look and draw distance specced in CargoLootFeedbackFormulas)",
	["ReplicatedStorage.Client.Features.Cargo.Systems.CargoLootFeedbackSystem"] = "particles/Sound/RunService shell (glint schedule, glint range and stamp freshness specced in CargoLootFeedbackFormulas)",

	-- Cleanup Crew: Vacuum
	["ReplicatedStorage.Shared.Features.Vacuum.Data.VacuumConstants"] = "static tuning and names (no logic)",
	["ReplicatedStorage.Shared.Features.Vacuum.Data.VacuumAssets"] = "asset id slots; registers the uploaded sounds at load (no decisions)",
	["ReplicatedStorage.Client.Features.Vacuum.Systems.VacuumFeedbackSystem"] = "particles/Sound/Charm shell (decisions specced in VacuumFeedbackFormulas)",
	["ServerScriptService.Features.Vacuum.VacuumServiceServer"] = "Instance/Players/RunService/signal shell (VacuumCanisterUtils is specced)",
	["ReplicatedStorage.Client.Features.Vacuum.VacuumServiceClient"] = "Input shell (VacuumTargetRules is specced; the server decides)",

	-- Cleanup Crew: Noise
	["ReplicatedStorage.Shared.Features.Noise.Data.NoiseTypes"] = "type definitions only (no runtime logic)",
	["ReplicatedStorage.Shared.Features.Noise.Data.NoiseConstants"] = "static ripple look (no logic)",
	["ReplicatedStorage.Shared.Features.Noise.Net.NoiseEvents"] = "ByteNet packet definitions (no logic)",
	["ServerScriptService.Features.Noise.NoiseServiceServer"] = "signal/ByteNet relay shell (the hearing rule NoiseRules is specced)",
	["ReplicatedStorage.Client.Features.Noise.NoiseServiceClient"] = "Instance/raycast/RunService shell (the ring's shape is specced in NoiseRippleFormulas)",

	-- Cleanup Crew: Office
	["ServerScriptService.Features.Office.Data.OfficeTypes"] = "type definitions only (no runtime logic)",
	["ServerScriptService.Features.Office.Data.OfficeConstants"] = "static placement, sizes and roll knobs (no logic)",
	["ServerScriptService.Features.Office.Data.OfficeLayoutConstants"] = "authored layout data; validated by OfficeLayoutRules.spec",
	["ServerScriptService.Features.Office.Systems.OfficeBuildSystem"] = "Instance builder (the layout is validated by the specced OfficeLayoutRules)",
	["ServerScriptService.Features.Office.OfficeServiceServer"] = "Instance/signal shell (layout rules, spawn roll and spawn rules are specced)",
	["ReplicatedStorage.Shared.Features.Office.Data.OfficeDecorConstants"] = "static decor look and emitter names (no logic)",
	["ReplicatedStorage.Client.Features.Office.OfficeServiceClient"] = "client service shell (starts the atmosphere and ambience systems)",
	["ReplicatedStorage.Client.Features.Office.Data.OfficeAssets"] = "asset id slots; registers the uploaded sounds at load (no decisions)",
	["ReplicatedStorage.Client.Features.Office.Data.OfficeAtmosphereConstants"] = "static presets and timing (no logic)",
	["ReplicatedStorage.Client.Features.Office.Systems.OfficeAtmosphereSystem"] = "Lighting/Instance/Sound/Charm shell (choices specced in OfficeAtmosphereUtils, OfficeLightUtils)",
	["ReplicatedStorage.Client.Features.Office.Systems.OfficeAmbienceSystem"] = "Sound/Instance/RunService shell (choices specced in OfficeAmbienceUtils)",

	-- Cleanup Crew: Occupant
	["ReplicatedStorage.Shared.Features.Occupant.Data.OccupantAssets"] = "asset id slots; registers the uploaded sounds at load (no decisions)",
	["ReplicatedStorage.Client.Features.Occupant.Systems.OccupantPresenceSystem"] = "Sound/Instance/RunService shell (choices specced in OccupantFeedbackUtils, OccupantTellRules; the memo is OccupantWorldViewModel's)",
	["ReplicatedStorage.Client.Features.Occupant.Systems.OccupantBillboardSystem"] = "CollectionService/React-root shell (cue and memo specced in OccupantWorldViewModel; roots in UIBillboards)",
	["ReplicatedStorage.Client.UI.React.Screens.World.OccupantCueDisc"] = "presentational React component (cue specced in OccupantWorldViewModel; story in OccupantWorld.story)",
	["ReplicatedStorage.Client.UI.React.Screens.World.OccupantMemo"] = "presentational React component (memo and shout specced in OccupantWorldViewModel; story in OccupantWorld.story)",
	["ReplicatedStorage.Client.UI.React.Screens.World.useTypedGraphemes"] = "React hook over RenderStepped (the reveal maths is the specced OccupantFeedbackUtils.reveal)",
	["ReplicatedStorage.Shared.Features.Occupant.Data.OccupantConstants"] = "static tuning, names and placeholder lines (no logic)",
	["ReplicatedStorage.Shared.Features.Occupant.Data.OccupantTypes"] = "type definitions only (no runtime logic)",
	["ReplicatedStorage.Shared.Features.Occupant.Net.OccupantEvents"] = "ByteNet packet definitions (no logic)",
	["ServerScriptService.Features.Occupant.Systems.OccupantRigSystem"] = "Instance builder (HumanoidDescription rig, billboard shells and their attributes)",
	["ServerScriptService.Features.Occupant.OccupantServiceServer"] = "NPC/raycast/signal shell (brain, tuning and tell decisions are specced in OccupantBrainRules, OccupantCatchRules, OccupantTuningFormulas, OccupantTellRules)",
	["ServerScriptService.Features.Occupant.Systems.OccupantCatchSystem"] = "Instance/ByteNet/Death shell (catch decisions and the launch are specced in OccupantCatchRules)",
	["ReplicatedStorage.Client.Features.Occupant.OccupantServiceClient"] = "Camera/Vfx/ByteNet shell (tell decisions are specced in OccupantTellRules)",
	["ReplicatedStorage.Client.Features.Occupant.Systems.OccupantScareSystem"] = "Instance/tween/Sound shell (the scare beat; no decisions)",
	["ReplicatedStorage.Client.Features.Occupant.Systems.OccupantGestureSystem"] = "Motor6D/RunService shell (poses and easing specced in OccupantGestureFormulas)",
	["ReplicatedStorage.Client.Features.Occupant.Systems.OccupantWarningSystem"] = "Sound/Instance/RunService shell (stages and typing specced in OccupantTellRules; the subtitle in OccupantPaStore)",
	["ReplicatedStorage.Client.UI.React.Screens.World.OccupantPaSubtitle"] = "presentational React component (the strip specced in OccupantPaViewModel)",
	["ServerScriptService.Features.Occupant.Systems.OccupantEffectSystem"] = "Players/ByteNet/Hide shell (which effects a think makes is specced in OccupantBrainRules and its rules)",
	["ServerScriptService.Features.Occupant.Systems.OccupantSeatSystem"] = "Instance/tween/clip shell (when to sit, stand, plant or let go is specced in OccupantBrainRules and OccupantMindUtils)",

	-- Cleanup Crew: Hide (hiding spots)
	["ReplicatedStorage.Shared.Features.Hide.Data.HideConstants"] = "static tuning and names (no logic)",
	["ReplicatedStorage.Shared.Features.Hide.Data.HideTypes"] = "type definitions only (no runtime logic)",
	["ReplicatedStorage.Shared.Features.Hide.Net.HideEvents"] = "ByteNet packet definitions (no logic)",
	["ServerScriptService.Features.Hide.Systems.HideSpotSystem"] = "CollectionService/ProximityPrompt builder (spot frames specced in HideSpotUtils)",
	["ServerScriptService.Features.Hide.HideServiceServer"] = "Instance/Players/ByteNet/signal shell (entry, camping and frames specced in HideRules, HideSpotUtils, HideOccupancyTracker)",
	["ReplicatedStorage.Client.Features.Hide.HideServiceClient"] = "ProximityPrompt/Camera/PlayerModule/ByteNet shell (words specced in HideViewModel, state in HideStore)",
	["ReplicatedStorage.Client.UI.React.Screens.Hide.HideChip"] = "presentational React component (words specced in HideViewModel)",
	["ReplicatedStorage.Client.UI.React.Screens.Hide.HidePeekOverlay"] = "presentational React component (overlay choice specced in HideViewModel)",
	-- Cleanup Crew: Sprint
	["ReplicatedStorage.Shared.Features.Sprint.Data.SprintConstants"] = "static tuning and names (no logic)",
	["ReplicatedStorage.Shared.Features.Sprint.Net.SprintEvents"] = "ByteNet packet definitions (no logic)",
	["ServerScriptService.Features.Sprint.SprintServiceServer"] = "Humanoid/Players/ByteNet/RunService shell (decisions specced in SprintRules and SprintStaminaFormulas)",
	["ReplicatedStorage.Client.Features.Sprint.SprintServiceClient"] = "Input/ByteNet/attribute shell (the server decides; the bar is specced in SprintViewModel)",
	["ReplicatedStorage.Client.UI.React.Screens.Sprint.SprintStaminaSlip"] = "presentational React component (bar specced in SprintViewModel)",
	["ReplicatedStorage.Client.Features.Hide.Systems.HidePoseSystem"] = "Players/Motor6D/RunService shell (the pose and its easing are specced in HidePoseFormulas)",
	-- Cleanup Crew: Shift
	["ReplicatedStorage.Shared.Features.Shift.Data.ShiftTypes"] = "type definitions only (no runtime logic)",
	["ReplicatedStorage.Shared.Features.Shift.Data.ShiftConstants"] = "static pacing and names (no logic)",
	["ReplicatedStorage.Shared.Features.Shift.Net.ShiftEvents"] = "ByteNet packet definitions (no logic)",
	["ServerScriptService.Features.Shift.Systems.ShiftCrewStatusSystem"] = "RunService/character/public-store shell (fields and diffs specced in ShiftCrewStatusUtils, rooms in OfficeLayoutUtils)",
	["ServerScriptService.Features.Shift.Systems.ShiftReviewSystem"] = "signal subscription shell (counting specced in ShiftRosterTracker, awards in ShiftResultsUtils)",
	["ServerScriptService.Features.Shift.Systems.ShiftBankingSystem"] = "Round banking shell (salvage multiplier and quota are specced in ShiftPhaseRules)",
	["ServerScriptService.Features.Shift.Data.ShiftAnalyticsConstants"] = "static analytics vocabulary and limits (no logic; exercised by ShiftAnalyticsUtils.spec)",
	["ServerScriptService.Features.Shift.Systems.ShiftAnalyticsSystem"] = "AnalyticsService/Players/ByteNet/Workspace shell (payloads, tokens, variant, platform and attempts are specced)",
	["ServerScriptService.Features.Shift.Systems.ShiftAnalyticsWatchSystem"] = "signal/attribute subscription shell (every decision is specced in ShiftAnalyticsUtils and the trackers)",
	["ServerScriptService.Features.Shift.ShiftServiceServer"] = "Players/RunService/service-orchestration shell (phase, vote, results and snapshot rules are specced)",
	["ServerScriptService.Features.Shift.Systems.ShiftTripSystem"] = "Players/Queue-signal/teleport shell (ShiftCrewTracker, ShiftCardUtils and DepotContractUtils are specced)",
	["ReplicatedStorage.Client.Features.Shift.State.ShiftStore"] = "Charm computed facade over the shift world entry (decoding is specced in ShiftSnapshotUtils)",
	["ReplicatedStorage.Client.Features.Shift.ShiftServiceClient"] = "HUD registration + Charm/ByteNet shell (the server decides)",
	["ReplicatedStorage.Shared.Features.Shift.Data.ShiftAssets"] = "asset id slots; registers the uploaded sounds at load (no decisions)",
	["ReplicatedStorage.Client.Features.Shift.Systems.ShiftFeedbackSystem"] = "Sound/Camera/Charm shell (cue choices are specced in ShiftCueUtils)",
	["ReplicatedStorage.Client.UI.React.Hooks.useServerClock"] = "React hook — re-renders on the server clock (no logic)",
	["ReplicatedStorage.Client.UI.React.Screens.Shift.ShiftHudPanel"] = "React UI component (layout only; story in ShiftHudPanel.story; values specced in ShiftHudViewModel)",
	["ReplicatedStorage.Client.UI.React.Screens.Shift.ShiftHud"] = "React HUD widget wiring stores to ShiftHudPanel (view models specced)",
	["ReplicatedStorage.Client.UI.React.Screens.Shift.ShiftTimeCard"] = "presentational React component (story in ShiftHudPanel.story)",
	["ReplicatedStorage.Client.UI.React.Screens.Shift.ShiftClearancePanel"] = "presentational React component (story in ShiftHudPanel.story)",
	["ReplicatedStorage.Client.UI.React.Screens.Shift.ShiftCrewRoster"] = "presentational React component (roster specced in ShiftCrewViewModel; story in ShiftHudPanel.story)",
	["ReplicatedStorage.Client.UI.React.Screens.Shift.ShiftHotbar"] = "presentational React component (slots specced in ShiftHudViewModel.hotbar; story in ShiftHudPanel.story)",
	["ReplicatedStorage.Client.UI.React.Screens.Shift.ShiftClockOutSlip"] = "presentational React component (story in ShiftHudPanel.story)",
	["ReplicatedStorage.Client.UI.React.Screens.Shift.ShiftStoryFixtures"] = "story fixtures (static sample data)",
	["ReplicatedStorage.Client.UI.React.Screens.Shift.ShiftMobileButtons"] = "React HUD widget: stores to the touch arc and client-service calls (show/hide, VACUUM/LOAD, lit and usable buttons, LOAD readiness and the phone/tablet arc specced in ShiftHudViewModel.mobileButtons / buttons / loadReady / hidden / arcFor)",
	["ReplicatedStorage.Client.Features.Shift.Systems.ShiftPromptSystem"] = "ProximityPromptService/Instance shell (the chip's words are specced in ShiftHudViewModel.prompt, the bookkeeping in ShiftPromptStore)",
	["ReplicatedStorage.Client.UI.React.Screens.Shift.ShiftPromptChip"] = "React HUD widget (words, fill and hidden rule specced in ShiftHudViewModel.prompt)",
	["ReplicatedStorage.Client.UI.React.Screens.Shift.ShiftKeyHints"] = "presentational React component (hints specced in ShiftHudViewModel.keyHints / showHints)",
	["ReplicatedStorage.Client.UI.React.Screens.Shift.ShiftReviewPanel"] = "presentational React component (review specced in ShiftReviewViewModel; story in ShiftReviewPanel.story)",
	["ReplicatedStorage.Client.UI.React.Screens.Shift.ShiftReviewScreen"] = "React scene screen wiring ShiftStore to ShiftReviewPanel (no logic)",
	["ReplicatedStorage.Client.UI.React.Screens.Shift.ShiftReviewTab"] = "React HUD widget reopening the review scene (no logic)",
	["ReplicatedStorage.Client.UI.React.Screens.Shift.ShiftScene"] = "scene registration (declarative, no logic)",
	["ServerScriptService.Features.Shift.Systems.ShiftVoteSystem"] = "RequestHandler/ByteNet vote shell (the vote decisions are specced in ShiftVoteRules)",
	-- Cleanup Crew: Depot
	["ReplicatedStorage.Shared.Features.Depot.Data.DepotTypes"] = "type definitions only (no runtime logic)",
	["ReplicatedStorage.Shared.Features.Depot.Data.DepotConstants"] = "static names, place table, contracts and card texts (no logic)",
	["ServerScriptService.Features.Depot.Data.DepotLayoutConstants"] = "authored layout data; validated by DepotLayoutRules.spec",
	["ReplicatedStorage.Shared.Features.Depot.Net.DepotEvents"] = "ByteNet packet definitions (no logic)",
	["ServerScriptService.Features.Depot.Systems.DepotBuildSystem"] = "Instance builder (the layout is validated by the specced DepotLayoutRules)",
	["ServerScriptService.Features.Depot.DepotServiceServer"] = "Players/RunService/ByteNet/Queue-signal shell (layout rules, contract utils and the result card are specced)",
	["ReplicatedStorage.Client.Features.Depot.DepotServiceClient"] = "ByteNet/HUD registration/RunService shell (DepotStore is specced)",
	["ReplicatedStorage.Client.UI.React.Screens.Depot.DepotCardPanel"] = "presentational React component (card lines specced in DepotCardViewModel; story in DepotCardPanel.story)",
	["ReplicatedStorage.Client.UI.React.Screens.Depot.DepotCard"] = "React HUD widget wiring DepotStore to DepotCardPanel (lines specced in DepotCardViewModel, scale in WorldBillboardViewModel)",
	["ReplicatedStorage.Client.UI.React.Screens.Depot.DepotBoardPanel"] = "presentational React component (board specced in DepotBoardViewModel; story in DepotBoardPanel.story)",
	["ReplicatedStorage.Client.UI.React.Screens.Depot.DepotBoardScreen"] = "React scene screen wiring DepotStore to DepotBoardPanel (no logic)",
	["ReplicatedStorage.Client.UI.React.Screens.Depot.DepotScene"] = "scene registration (declarative, no logic)",
	["ReplicatedStorage.Client.UI.React.Screens.Depot.DepotPad"] = "React HUD widget wiring QueueStore to DepotPadPanel (card specced in DepotPadViewModel)",
	["ReplicatedStorage.Client.Features.Depot.Systems.DepotBillboardSystem"] = "CollectionService/RunService/React-root shell (signs specced in DepotWorldViewModel; roots in UIBillboards)",
	["ReplicatedStorage.Client.UI.React.Screens.World.DepotTruckTag"] = "presentational React component (tag specced in DepotWorldViewModel; story in DepotWorld.story)",
	["ReplicatedStorage.Client.UI.React.Screens.World.DepotWorkOrderBoard"] = "presentational React component (work order specced in DepotWorldViewModel; story in DepotWorld.story)",
	["ReplicatedStorage.Client.UI.React.Screens.World.DepotResultBoard"] = "presentational React component (review card specced in DepotWorldViewModel; story in DepotWorld.story)",
	["ReplicatedStorage.Client.UI.React.Screens.Depot.DepotPadPanel"] = "presentational React component (story in DepotPadPanel.story)",
	-- Cleanup Crew: the paper UI kit (M3 UI)
	["ReplicatedStorage.Client.UI.React.Screens.Paper.UIPaperConstants"] = "static palette, fonts and sizes (no logic; inkColor is a frozen lookup)",
	["ReplicatedStorage.Client.UI.React.Screens.Paper.PaperLabel"] = "presentational React component (story in PaperKit.story)",
	["ReplicatedStorage.Client.UI.React.Screens.Paper.PaperTexture"] = "presentational React component (the texture choice is specced in PaperTextureViewModel)",
	["ReplicatedStorage.Client.UI.React.Screens.Paper.PaperSheet"] = "presentational React component (story in PaperKit.story)",
	["ReplicatedStorage.Client.UI.React.Screens.Paper.PaperStamp"] = "presentational React component (story in PaperKit.story)",
	["ReplicatedStorage.Client.UI.React.Screens.Paper.StickyNote"] = "presentational React component (story in PaperKit.story)",
	["ReplicatedStorage.Client.UI.React.Screens.World.WorldBillboard"] = "presentational React wrapper (fit and screen scale specced in WorldBillboardViewModel)",
	["ReplicatedStorage.Client.UI.React.Screens.Paper.CorkBoard"] = "presentational React component (story in PaperKit.story; texture choice specced in PaperTextureViewModel)",
	["ReplicatedStorage.Client.UI.React.Screens.Paper.PaperTag"] = "presentational React component (story in PaperKit.story; texture choice specced in PaperTextureViewModel)",
	["ReplicatedStorage.Client.UI.React.Screens.Paper.KeyChip"] = "presentational React component (story in PaperKit.story)",
	["ReplicatedStorage.Client.UI.React.Screens.Depot.DepotHub"] = "reactive illustrated depot HUD",
	["ReplicatedStorage.Client.UI.React.Screens.Depot.DepotHubScreen"] = "React guide/gear/settings screen; decisions specced in DepotHubViewModel",
	["ReplicatedStorage.Client.UI.React.Screens.Depot.DepotHubScene"] = "declarative registration for the specced hub pages",
	["ReplicatedStorage.Client.UI.React.Screens.Paper.PaperPropIcon"] = "native GUI vector renderer; source shapes specced in PaperPropViewModel",
	["ReplicatedStorage.Client.UI.React.Screens.Paper.PaperPortrait"] = "React thumbnail lifecycle shell; source userId specced in ShiftReviewViewModel",
	["ReplicatedStorage.Client.UI.React.Screens.Paper.PaperAwardIcon"] = "native award renderer; title/shape mapping specced in ShiftReviewViewModel",
	["ReplicatedStorage.Client.UI.React.Screens.Paper.PaperButton"] = "presentational React component (story in PaperKit.story)",
	["ReplicatedStorage.Client.UI.React.Screens.Paper.usePaperLayout"] = "React hook over the viewport (the decision is the specced ShiftPlatformRules.detect)",
	["ReplicatedStorage.Client.UI.React.Screens.Paper.usePaperViewport"] = "React hook over the viewport (no logic)",
	["ReplicatedStorage.Client.UI.React.Screens.Paper.usePaperHudScale"] = "React hook over the viewport (the scale maths is specced in PaperHudScaleViewModel)",
	["ReplicatedStorage.Client.UI.React.Screens.Paper.PaperHudFrame"] = "presentational React wrapper (scale and top shift specced in PaperHudScaleViewModel)",
	["ReplicatedStorage.Client.UI.React.Screens.Paper.usePaperMotion"] = "React hook — RenderStepped easing over a binding (no logic)",
	["ReplicatedStorage.Client.UI.React.Screens.Paper.PaperToastStack"] = "React HUD widget (layout specced in PaperToastViewModel; story in PaperToastStack.story)",
	-- Cleanup Crew: catch screens (M3 UI)
	["ReplicatedStorage.Client.UI.React.Screens.Catch.CatchOverlay"] = "React HUD widget (CCTV lines specced in CatchViewModel)",
	["ReplicatedStorage.Client.UI.React.Screens.Catch.CatchCctvPanel"] = "presentational React component (story in CatchCctvPanel.story)",
	["ReplicatedStorage.Client.UI.React.Screens.Catch.CatchRehiredCard"] = "React HUD widget (notice specced in CatchViewModel)",
	["ReplicatedStorage.Client.UI.React.Screens.Catch.CatchRehiredPanel"] = "presentational React component (story in CatchRehiredPanel.story)",
	["ReplicatedStorage.Client.UI.React.Screens.Catch.useSpectateTarget"] = "React hook polling DeathServiceClient:spectating() (no logic)",
}

--[=[
	The inverse of `assertAllSpecsCovered`: errors if any first-party non-spec module UNDER a scanned
	root lacks a `<name>.spec` sibling and is not in `EXEMPT_MODULES`. Turns the project's
	"write the spec first" convention (docs/testing.md) from prose into a failing test — a new service
	or util that ships without a spec fails the suite instead of silently going uncovered.

	Only modules under the roots are checked (vendored package trees live elsewhere and are never
	roots), so no package-exclusion pass is needed here.
	@param roots { Instance } -- The scanned test roots (SpecRoots.get())
]=]
function SpecRoots.assertAllModulesSpecced(roots: { Instance })
	local missing: { string } = {}
	local seen: { [Instance]: boolean } = {}

	for _, root in roots do
		for _, descendant in root:GetDescendants() do
			if not descendant:IsA("ModuleScript") or seen[descendant] then
				continue
			end
			seen[descendant] = true

			local name = descendant.Name
			-- Skip spec modules themselves, the UI Labs harness modules, and the intentional exemptions.
			-- A `*.story` builds a component with fixture props so a human can look at it, and a
			-- `*.storybook` is just the list of folders to scan for those — neither holds logic a unit
			-- test could assert that the component's own spec doesn't. Both are skipped by NAME rather
			-- than exempted one by one, so adding a story never means editing this file (the same
			-- treatment `.spec` siblings get).
			if
				name:match("%.spec$")
				or name:match("%.story$")
				or name:match("%.storybook$")
				or EXEMPT_MODULES[descendant:GetFullName()]
			then
				continue
			end

			local parent = descendant.Parent
			local sibling = parent and parent:FindFirstChild(`{name}.spec`)
			if not (sibling and sibling:IsA("ModuleScript")) then
				table.insert(missing, descendant:GetFullName())
			end
		end
	end

	if #missing > 0 then
		table.sort(missing)
		error(
			`{#missing} module(s) have no .spec sibling and are not exempt: `
				.. table.concat(missing, ", ")
				.. ". Add a <name>.spec.luau next to each (write the spec first — see docs/testing.md), "
				.. "or, if a unit test would be tautological, add it to SpecRoots' EXEMPT_MODULES with a reason."
		)
	end
end

return SpecRoots
