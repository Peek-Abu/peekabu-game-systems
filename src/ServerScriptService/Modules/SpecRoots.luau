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
	The roots TestEZ scans. Order matches the historical testLocations lists.
	@return { Instance }
]=]
function SpecRoots.get(): { Instance }
	return {
		ReplicatedStorage.Shared.Modules,
		ReplicatedStorage.Shared.State,
		ReplicatedStorage.Client,
		ServerScriptService.Commands,
		ServerScriptService.Modules,
		ServerScriptService.Services,
		ServerScriptService.State,
	}
end

--[=[
	Errors if any FIRST-PARTY `*.spec` ModuleScript in the built place sits outside the scanned
	roots. Swept containers: everything default.project.json maps source into. Vendored Wally
	package trees (Packages/ServerPackages/DevPackages) are excluded — several dependencies ship
	their own `.spec` files (e.g. evaera_promise, jsdotlua_promise) which are not this project's
	tests and are intentionally never run.
	@param roots { Instance } -- The roots about to be passed to TestBootstrap:run
]=]
function SpecRoots.assertAllSpecsCovered(roots: { Instance })
	local containers: { Instance } = { ReplicatedStorage, ServerScriptService, StarterPlayer }

	-- Vendored package trees to skip. Wally mounts Packages/DevPackages under ReplicatedStorage and
	-- ServerPackages under ServerScriptService (see default.project.json), so probe both containers.
	local packageFolders: { Instance } = {}
	for _, name in { "Packages", "ServerPackages", "DevPackages" } do
		local folder = ReplicatedStorage:FindFirstChild(name) or ServerScriptService:FindFirstChild(name)
		if folder then
			table.insert(packageFolders, folder)
		end
	end

	local orphans: { string } = {}

	for _, container in containers do
		for _, descendant in container:GetDescendants() do
			if not (descendant:IsA("ModuleScript") and descendant.Name:match("%.spec$")) then
				continue
			end
			local vendored = false
			for _, folder in packageFolders do
				if descendant:IsDescendantOf(folder) then
					vendored = true
					break
				end
			end
			if vendored then
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
	-- React UI components — rendered and exercised in-game via the F4 overlay; TestEZ has no
	-- renderer, so a unit test would assert nothing meaningful.
	["ReplicatedStorage.Client.UI.React.Debugger.DebuggerOverlay"] = "React UI component (rendered in-game)",
	["ReplicatedStorage.Client.UI.React.Debugger.LogsPanel"] = "React UI component (rendered in-game)",
	["ReplicatedStorage.Client.UI.React.Debugger.ServicesPanel"] = "React UI component (rendered in-game)",
	["ReplicatedStorage.Client.UI.React.Debugger.StatePanel"] = "React UI component (rendered in-game)",
	["ReplicatedStorage.Client.UI.React.Debugger.TableView"] = "React UI component (rendered in-game)",
	["ReplicatedStorage.Client.UI.React.Debugger.theme"] = "static style tokens (no logic)",
	["ReplicatedStorage.Client.UI.React.Debugger.useDrag"] = "React hook (needs a renderer + pointer input)",

	-- Client services: thin, network/Cmdr-bound shells whose behavior only manifests against a live
	-- server; integration-tested in-game rather than unit-tested.
	["ReplicatedStorage.Client.Services.AdminService.AdminServiceClient"] = "Cmdr-bound client shell (--!nocheck)",
	["ReplicatedStorage.Client.Services.DebuggerService.DebuggerServiceClient"] = "network-bound client shell",
	["ReplicatedStorage.Client.Services.StateSyncService.StateSyncServiceClient"] = "network-bound client shell",

	-- Reactive read facade over already-tested modules (ServiceController, Logger) — no logic of its own.
	["ReplicatedStorage.Client.State.DebuggerState"] = "reactive read facade (no logic of its own)",

	-- Thin typed wrappers over vendored libraries — they add types, not behavior; the one `any` cast
	-- each isolates is the whole point, and there is nothing of ours to assert.
	["ReplicatedStorage.Shared.Modules.SignalTyped"] = "typed wrapper over SignalPlus (no logic)",
	["ServerScriptService.Modules.ProfileStoreTyped"] = "typed wrapper over ProfileStore (no logic)",

	-- Cmdr command DEFINITIONS (declarative arg schemas). Their `*Server` implementations carry the
	-- logic and ARE specced (AddCurrencyServer.spec, etc.).
	["ServerScriptService.Commands.AddCurrency"] = "Cmdr command definition (server impl is specced)",
	["ServerScriptService.Commands.GiveItem"] = "Cmdr command definition (server impl is specced)",
	["ServerScriptService.Commands.RemoveItem"] = "Cmdr command definition (server impl is specced)",
	["ServerScriptService.Commands.SetCurrency"] = "Cmdr command definition (server impl is specced)",

	-- Profile template/registry constants. Candidate for future coverage (registerProfilePath/seal
	-- have real logic), but exercised transitively today by the PlayerDataService/SliceOwner specs.
	["ServerScriptService.Modules.Constants.PlayerDataConstants"] = "profile-template registry (covered transitively)",
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
			-- Skip spec modules themselves and the intentional exemptions.
			if name:match("%.spec$") or EXEMPT_MODULES[descendant:GetFullName()] then
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
