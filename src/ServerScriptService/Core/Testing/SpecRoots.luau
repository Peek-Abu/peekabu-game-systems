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
	- `StarterPlayer.PlayerModule` — the same default scripts in Roblox's current (Input Action
	  System) layout, which the engine provisions directly under StarterPlayer at runtime and loads
	  from there instead of copying into PlayerScripts. Not ours either.
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
	-- own runtime-provisioned default (under StarterPlayerScripts in the legacy layout, directly under
	-- StarterPlayer in the current one), not ours or Wally's.
	local excludedFolders: { Instance } = {}
	for _, name in { "Packages", "ServerPackages", "DevPackages" } do
		local folder = ReplicatedStorage:FindFirstChild(name) or ServerScriptService:FindFirstChild(name)
		if folder then
			table.insert(excludedFolders, folder)
		end
	end
	for _, parent in { StarterPlayer.StarterPlayerScripts, StarterPlayer } do
		local playerModule = parent:FindFirstChild("PlayerModule")
		if playerModule then
			table.insert(excludedFolders, playerModule)
		end
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

-- The modules allowed without a spec sibling, each with its reason: SpecExemptionsReplicated and
-- SpecExemptionsServer, joined (split by realm so neither list is over the file-length cap).
local EXEMPT_MODULES: { [string]: string } = table.clone(require(script.Parent.SpecExemptionsReplicated))
for name, reason in require(script.Parent.SpecExemptionsServer) do
	EXEMPT_MODULES[name] = reason
end

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
				.. "or, if a unit test would be tautological, add it to SpecExemptionsReplicated or SpecExemptionsServer (Core/Testing) with a reason."
		)
	end
end

return SpecRoots
