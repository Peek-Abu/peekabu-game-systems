--!nocheck
-- `--!nocheck` (not `--!strict`): this file requires the PlayerModule, which Roblox inserts at
-- RUNTIME. It is not in the static sourcemap, so luau-lsp reports an unknown require and there is no
-- typed PlayerModule to assert against (the AdminServiceClient/CmdrClient precedent).
-- Only the controls toggle belongs in this file.
--[=[
	InputControlsSystem: turns the local character's movement controls off and on.

	Roblox ships the default player scripts in one of two layouts, and this drives whichever one the
	place runs:
	- **Current** (Input Action System): `StarterPlayer.PlayerModule`, which the engine provisions at
	  runtime and loads on the client through its own `PlayerScriptsLoader`. Nothing is copied into
	  PlayerScripts, the PlayerModule has no public API, and its `ControlModule:Disable()` no longer
	  stops movement (move and jump are read from InputActions, whose controller `Enable` is a stub).
	  Movement is locked by disabling the `InputContexts.CharacterContext` InputContext (move, jump,
	  rotation, click-to-move), which zeroes those actions; the camera's context is left alone.
	- **Legacy**: `PlayerScripts.PlayerModule`, whose `GetControls()` controller has `Enable`/`Disable`.

	Where neither exists (not a real client: the server, a test runner, a story) every call is a
	silent no-op that never yields; a client missing both warns once.

	@class InputControlsSystem
]=]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local StarterPlayer = game:GetService("StarterPlayer")

-- Upper bound on waiting for the legacy PlayerModule, which the engine copies into PlayerScripts on
-- join; a bounded wait never raises the "Infinite yield possible" warning.
local LEGACY_WAIT_SECONDS = 10

local InputControlsSystem = {}

-- "unresolved" -> "resolving" -> "ready" | "unavailable". Resolution runs once per session.
local state = "unresolved"
-- The resolved toggle: `(enabled: boolean) -> ()`.
local toggle = nil
-- The latest requested state, applied when a resolution in flight completes.
local wanted = nil

local function characterContextIn(inputContexts: Instance?)
	local context = if inputContexts ~= nil then inputContexts:FindFirstChild("CharacterContext") else nil
	if context ~= nil and context:IsA("InputContext") then
		return context
	end
	return nil
end

--[=[
	Locates what locks movement: the current layout's
	`StarterPlayer.PlayerModule.InputContexts.CharacterContext` (kind `"inputContext"`, preferred), else
	the legacy `PlayerScripts.PlayerModule` ModuleScript (kind `"playerModule"`). Pure lookup, never
	yields.
	@param starterPlayer Instance
	@param playerScripts Instance?
	@return (Instance?, ("inputContext" | "playerModule")?)
]=]
function InputControlsSystem.findControls(starterPlayer: Instance, playerScripts: Instance?)
	local playerModule = starterPlayer:FindFirstChild("PlayerModule")
	local context =
		characterContextIn(if playerModule ~= nil then playerModule:FindFirstChild("InputContexts") else nil)
	if context ~= nil then
		return context, "inputContext"
	end
	if playerScripts ~= nil then
		local legacy = playerScripts:FindFirstChild("PlayerModule")
		if legacy ~= nil and legacy:IsA("ModuleScript") then
			return legacy, "playerModule"
		end
	end
	return nil, nil
end

local function resolve(player: Player)
	local playerScripts = player:FindFirstChildOfClass("PlayerScripts")
		or player:WaitForChild("PlayerScripts", LEGACY_WAIT_SECONDS)
	local found, kind = InputControlsSystem.findControls(StarterPlayer, playerScripts)
	if found == nil and playerScripts ~= nil then
		playerScripts:WaitForChild("PlayerModule", LEGACY_WAIT_SECONDS)
		found, kind = InputControlsSystem.findControls(StarterPlayer, playerScripts)
	end
	if found == nil then
		warn("[InputControlsSystem] no PlayerModule found; movement controls cannot be toggled")
		return nil
	end
	if kind == "inputContext" then
		return function(enabled: boolean)
			found.Enabled = enabled
			-- Server-authority places drive the character from a per-player clone of the contexts.
			local perPlayer = characterContextIn(player:FindFirstChild("InputContexts"))
			if perPlayer ~= nil then
				perPlayer.Enabled = enabled
			end
		end
	end
	local controller = require(found):GetControls()
	if
		type(controller) ~= "table"
		or type(controller.Enable) ~= "function"
		or type(controller.Disable) ~= "function"
	then
		warn(`[InputControlsSystem] {found:GetFullName()} has no Enable/Disable controls`)
		return nil
	end
	return function(enabled: boolean)
		if enabled then
			controller:Enable()
		else
			controller:Disable()
		end
	end
end

--[=[
	Enables or disables the local character's movement controls. The first call may yield briefly
	(legacy layout only) while the controls are located; calls made meanwhile are coalesced (the
	latest wins). A no-op where there are no controls.
	@param enabled boolean
]=]
function InputControlsSystem.setEnabled(enabled: boolean)
	wanted = enabled
	if state == "ready" then
		toggle(enabled)
		return
	end
	if state ~= "unresolved" then
		return
	end
	local player = if RunService:IsClient() then Players.LocalPlayer else nil
	if player == nil then
		state = "unavailable"
		return
	end
	state = "resolving"
	toggle = resolve(player)
	if toggle == nil then
		state = "unavailable"
		return
	end
	state = "ready"
	toggle(wanted)
end

return InputControlsSystem
