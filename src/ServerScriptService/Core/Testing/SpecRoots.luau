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
	- `ReplicatedStorage.Modules` — the OLD game's code. `ReplicatedStorage` is mounted with
	  `$ignoreUnknownInstances`, deliberately, so that Rojo cannot delete the artist-owned `Assets`
	  folder (see the deployment model in AGENTS.md). The same flag means every legacy folder in an
	  art-bearing or reference place also survives a sync — including SmartBone and the old Knit
	  `Packages/_Index` tree, which between them ship 16 `.spec` modules that are not this project's
	  tests. Nothing here is built from `src/`; the cutover deletes these folders by hand.
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
	-- The old game's tree, present in any place synced over the live/reference game and absent from a
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
	["ReplicatedStorage.Shared.Features.Title.Net.TitleEvents"] = "ByteNet packet definitions (no logic)",
	["ReplicatedStorage.Shared.Features.Equipment.Net.EquipmentEvents"] = "ByteNet packet definitions (no logic)",
	["ReplicatedStorage.Shared.Features.Debugger.Net.DebuggerEvents"] = "ByteNet packet definitions (no logic)",
	["ReplicatedStorage.Shared.Features.Animation.Net.AnimationEvents"] = "ByteNet packet definitions (no logic)",
	["ReplicatedStorage.Shared.Features.Bank.Net.BankEvents"] = "ByteNet packet definitions (no logic)",
	["ReplicatedStorage.Shared.Features.Replication.Net.ReplicationEvents"] = "ByteNet packet definitions (no logic)",
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
	["ReplicatedStorage.Client.UI.React.Primitives.Slot"] = "presentational React primitive — the item slot (no logic)",
	["ReplicatedStorage.Client.UI.React.Hooks.useEasedTrail"] = "React hook — Heartbeat easing over bindings; its pure step TrailEasingUtils is specced",
	["ReplicatedStorage.Client.UI.React.SceneHost"] = "React layer view — renders the stack's screens (selection specced in SceneStack.screensFor)",
	["ReplicatedStorage.Client.UI.React.StoryFixtures"] = "sample data for the UI Labs stories — asserting a fixture's contents just restates the fixture",
	["ReplicatedStorage.Client.UI.React.Debugger.DebugPanelScreen"] = "throwaway harness screen proving the SceneHost render path (no logic)",
	["ReplicatedStorage.Client.UI.React.Screens.Hud.HudRoot"] = "React composition root — composes the HUD widgets + hide gate (no logic)",
	["ReplicatedStorage.Client.UI.React.Screens.Vitals.VitalsHud"] = "React HUD widget (health path is a binding; no unit-testable logic)",
	["ReplicatedStorage.Client.UI.React.Screens.Vitals.ResourceBars"] = "presentational React component — the 3 stacked resource bars (no logic)",
	["ReplicatedStorage.Client.UI.React.Screens.Experience.ExperienceHud"] = "React HUD widget (its derivations are specced in VitalsViewModel)",
	["ReplicatedStorage.Client.UI.React.Screens.Experience.ExperienceBar"] = "presentational React component — the XP bar + label (no logic)",
	["ReplicatedStorage.Client.UI.React.Screens.Inventory.InventoryPanel"] = "React panel screen (its filter/sort/search is specced in InventoryViewModel)",
	["ReplicatedStorage.Client.UI.React.Screens.Inventory.EquipmentPaperdoll"] = "presentational equip column — the resolution it renders is specced in InventoryViewModel.equipped",
	["ReplicatedStorage.Client.UI.React.Screens.Containers.ItemActions"] = "presentational action menu — authored plates and labels; the actions themselves are inert until the equipment work wires them",
	["ReplicatedStorage.Client.UI.React.Screens.Containers.SortControl"] = "presentational sort picker — open/closed state only; the sort modes it picks are specced in InventoryViewModel",
	["ReplicatedStorage.Client.UI.React.Screens.Containers.ItemGrid"] = "presentational React component — the item grid (no logic)",
	["ReplicatedStorage.Client.UI.React.Screens.Bank.CurrencyTransfer"] = "presentational currency strip — authored plates and labels; the amount it sends is validated server-side in BankReceiver",
	["ReplicatedStorage.Client.UI.React.Screens.Bank.CoinCounter"] = "presentational balance readout — its formatting is CurrencyUtils.formatCurrency, which is specced",
	["ReplicatedStorage.Client.UI.React.Screens.Bank.BankPanel"] = "React panel screen — its two containers' filter/sort/search is specced in InventoryViewModel and its drop test in DropTargets",
	["ReplicatedStorage.Client.UI.Scenes.BankScene"] = "scene registration (declarative) + the one place the bank panel is joined to its packets",
	["ReplicatedStorage.Client.UI.React.Hooks.useContainerFilters"] = "React hook — useState bundle for one container's filters (needs a renderer); the sort rule it applies is specced in InventoryViewModel",
	["ReplicatedStorage.Client.UI.React.Screens.Containers.ContainerPanel"] = "presentational container plate — fully controlled, owns no state; its filtering is specced in InventoryViewModel and its card placement in DetailPlacement",
	["ReplicatedStorage.Client.UI.React.Screens.Containers.CategoryTabs"] = "presentational React component — the category tabs (no logic)",
	["ReplicatedStorage.Client.UI.React.Screens.Containers.ItemDetail"] = "presentational React component — the item detail panel (no logic)",
	["ReplicatedStorage.Client.UI.Scenes.InventoryScene"] = "scene registration (data; no logic)",
	["ReplicatedStorage.Client.Features.UI.Data.UIAssets"] = "static image-asset registry (no logic)",

	-- Client services: thin, network/Cmdr-bound shells whose behavior only manifests against a live
	-- server; integration-tested in-game rather than unit-tested.
	["ReplicatedStorage.Client.Features.Admin.AdminServiceClient"] = "Cmdr-bound client shell (--!nocheck)",
	["ReplicatedStorage.Client.Features.Animation.AnimationServiceClient"] = "network-bound client shell",
	["ReplicatedStorage.Client.Features.Debugger.DebuggerServiceClient"] = "network-bound client shell",
	["ReplicatedStorage.Client.Features.StateSync.StateSyncServiceClient"] = "network-bound client shell",

	["ServerScriptService.Features.Bank.Net.BankReceiver"] = "packet wiring — every branch needs live ByteNet listeners, a rate limiter and real Players; the transfer RULES it calls are specced in BankServiceServer.spec",

	-- The Instance-touching half of animation playback: every verb needs a live Animator and real
	-- animation assets, which TestEZ cannot fixture. The cache, bookkeeping, and stop-class rules
	-- all live in the pure core and are fully specced in AnimationPlayerSystem.spec.
	["ReplicatedStorage.Shared.Features.Animation.Systems.AnimationPlayerEngineSystem"] = "Animator-touching shell (core is specced)",

	-- The Instance/ReactRoblox factory behind UILayers: news the ScreenGui root (direct PlayerGui
	-- child, ResetOnSpawn=false) and the React root. Needs a live PlayerGui + renderer; the WHEN-to-
	-- create/tear-down bookkeeping is the pure UILayers core, fully specced in UILayers.spec.
	["ReplicatedStorage.Client.UI.Layers.UILayerHost"] = "Instance/ReactRoblox factory shell (UILayers core is specced)",
	["ReplicatedStorage.Client.UI.Layers.UIRoot"] = "trivial shared-singleton wiring (UILayers core is specced)",
	["ReplicatedStorage.Client.UI.Suppression.UISuppression"] = "world-suppression handler shell — the mouse handler touches UserInputService (UIWorldSuppression core is specced)",
	["ReplicatedStorage.Client.Features.UI.UIServiceClient"] = "UI lifecycle shell — stack subscription, the Escape shim, and HUD mounting (the logic it drives is specced)",
	-- The replication harness (trace, lossy link, runner): test infrastructure with no behaviour of its own,
	-- exercised end to end by the acceptance spec.
	["ReplicatedStorage.Shared.Features.Replication.Testing.ReplicationLinkHarness"] = "replication harness; exercised end to end by ReplicationDesignHarness.spec",
	["ReplicatedStorage.Shared.Features.Replication.Testing.ReplicationTraceHarness"] = "replication harness; exercised end to end by ReplicationDesignHarness.spec",
	["ReplicatedStorage.Shared.Features.Replication.Testing.ReplicationRunHarness"] = "replication harness; exercised end to end by ReplicationDesignHarness.spec",

	-- Character replication shells (R2): Players, ByteNet, Instances and Heartbeat wiring only. Their logic
	-- lives in the specced cores beside them (ReplicationUplinkRules, ReplicationUplinkReceiver, ReplicationSlotTracker, ReplicationVisibilityTracker,
	-- ReplicationDownlinkSystem, ReplicationFanoutSystem, StateSyncPublicPlayerStore) and they are verified by the Studio checklist.
	["ServerScriptService.Features.Replication.ReplicationServiceServer"] = "network/Instance shell (cores are specced)",
	["ServerScriptService.Features.Voice.VoiceServiceServer"] = "Players/Instance shell (core VoiceSettingsCheck is specced)",
	["ServerScriptService.Features.Collision.CollisionServiceServer"] = "PhysicsService shell (collision groups; verified by the Studio checklist)",
	["ServerScriptService.Features.Replication.Systems.ReplicationInstanceSystem"] = "Instance shell (rig template, focus parts, spawn point)",
	["ServerScriptService.Features.Replication.Net.ReplicationReceiver"] = "ByteNet wiring shell (handlers are RequestHandler-wrapped)",
	["ReplicatedStorage.Client.Features.Replication.ReplicationServiceClient"] = "network/Instance shell (cores are specced)",
	["ReplicatedStorage.Client.Features.Voice.VoiceServiceClient"] = "audio/Instance shell (core VoiceWiringTracker is specced)",
	["ReplicatedStorage.Client.Features.Collision.CollisionServiceClient"] = "body-API/RunService shell (cores CollisionBlockerSystem and CollisionSlideOffSystem are specced)",
	["ReplicatedStorage.Client.Features.Replication.Systems.ReplicationOwnerRigSystem"] = "Instance shell (needs a live rig, camera and Humanoid)",
	["ReplicatedStorage.Client.Features.Animation.Systems.AnimationLocomotionHumanoidSystem"] = "Humanoid-event adapter (core is specced in AnimationLocomotionSystem.spec)",
	-- R3: plays actions and puppet locomotion on live rigs, behind ByteNet listeners and the camera. Its rules
	-- live in ReplicationActionTracker, ReplicationPuppetLocomotionSystem and ReplicationAnimationRules, which are specced; verified by the Studio checklist.
	["ReplicatedStorage.Client.Features.Replication.Systems.ReplicationRigAnimationSystem"] = "ByteNet/Instance/camera shell (cores are specced)",

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
	["ServerScriptService.Commands.BankDepositCurrency"] = "Cmdr command definition (server impl is specced)",
	["ServerScriptService.Commands.BankDepositItem"] = "Cmdr command definition (server impl is specced)",
	["ServerScriptService.Commands.CustomizationEquipCosmetic"] = "Cmdr command definition (server impl is specced)",
	["ServerScriptService.Commands.CustomizationCheckArt"] = "Cmdr command definition (server impl is specced)",
	["ServerScriptService.Commands.CustomizationSetCosmeticColor"] = "Cmdr command definition (server impl is specced)",
	["ServerScriptService.Commands.CustomizationTuneOffset"] = "Cmdr command definition (ClientRun body CustomizationTuneOffsetSystem is specced)",
	["ServerScriptService.Commands.EquipmentEquipItem"] = "Cmdr command definition (server impl is specced)",
	["ServerScriptService.Commands.CustomizationSetBodyColor"] = "Cmdr command definition (server impl is specced)",
	["ServerScriptService.Commands.CustomizationSetHeadType"] = "Cmdr command definition (server impl is specced)",
	["ServerScriptService.Commands.CustomizationSetSoulColor"] = "Cmdr command definition (server impl is specced)",
	["ServerScriptService.Commands.CustomizationSetSurface"] = "Cmdr command definition (server impl is specced)",
	["ServerScriptService.Commands.CustomizationUnlockCosmetic"] = "Cmdr command definition (server impl is specced)",
	["ServerScriptService.Commands.InventoryGiveItem"] = "Cmdr command definition (server impl is specced)",
	["ServerScriptService.Commands.InventoryRemoveItem"] = "Cmdr command definition (server impl is specced)",
	["ServerScriptService.Commands.ItemRollPreview"] = "Cmdr command definition (server impl is specced)",
	["ServerScriptService.Commands.CurrencySet"] = "Cmdr command definition (server impl is specced)",
	["ServerScriptService.Commands.EquipmentUnequipItem"] = "Cmdr command definition (server impl is specced)",
	["ServerScriptService.Commands.BankWithdrawCurrency"] = "Cmdr command definition (server impl is specced)",
	["ServerScriptService.Commands.BankWithdrawItem"] = "Cmdr command definition (server impl is specced)",
	["ServerScriptService.Commands.TitleAward"] = "Cmdr command definition (server impl is specced)",
	["ServerScriptService.Commands.TitleRevoke"] = "Cmdr command definition (server impl is specced)",
	["ServerScriptService.Commands.TitleEquip"] = "Cmdr command definition (server impl is specced)",

	-- SwitchSlot/UnlockSlot: definitions are declarative arg schemas like the others above. Their
	-- server impls are pure one-line pass-throughs to SlotServiceServer (whose switchSlot/unlockSlot
	-- are themselves specced) plus string formatting of the boolean/reason they return — a unit test
	-- would just re-assert the format string, not exercise any logic of ours.
	["ServerScriptService.Commands.SlotSwitch"] = "Cmdr command definition (thin pass-through impl)",
	["ServerScriptService.Commands.SlotSwitchServer"] = "thin pass-through to SlotServiceServer:switchSlot (specced)",
	["ServerScriptService.Commands.SlotUnlock"] = "Cmdr command definition (thin pass-through impl)",
	["ServerScriptService.Commands.SlotUnlockServer"] = "thin pass-through to SlotServiceServer:unlockSlot (specced)",

	-- GiveXp/InvestStat/RespecStats: definitions are declarative arg schemas like the others above.
	-- Their server impls are thin pass-throughs to StatServiceServer (whose addExperience/invest/
	-- respec are themselves specced) plus string formatting of the values/reason they return — a
	-- unit test would just re-assert the format string, not exercise any logic of ours.
	["ServerScriptService.Commands.StatGiveXp"] = "Cmdr command definition (thin pass-through impl)",
	["ServerScriptService.Commands.StatGiveXpServer"] = "thin pass-through to StatServiceServer:addExperience (specced)",
	["ServerScriptService.Commands.StatInvest"] = "Cmdr command definition (thin pass-through impl)",
	["ServerScriptService.Commands.StatInvestServer"] = "thin pass-through to StatServiceServer:invest (specced)",
	["ServerScriptService.Commands.StatRespec"] = "Cmdr command definition (thin pass-through impl)",
	["ServerScriptService.Commands.StatRespecServer"] = "thin pass-through to StatServiceServer:respec (specced)",
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
