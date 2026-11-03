--!strict
--[=[
	AbilityServiceClient: the local side of employee abilities (docs/superpowers/specs/
	2026-10-29-employee-abilities-design.md). The Input action `ability` (Q, gamepad Y) or the phone's ability button
	(`use`) asks the server (AbilityEvents.Use); the server decides everything. From the server's attributes it keeps
	AbilityStore (the HUD's cooldown ring) and, while the local Potted Plant runs, asks once to end it on any move,
	jump or other action input (AbilityEvents.Cancel), so popping out feels instant; the server ends it on its own
	checks too. Spot It!'s answer (AbilityEvents.Spotted) is drawn by AbilitySpotSystem; every character's ability
	looks by AbilityVfxSystem.

	Spec-exempt shell (Input, ByteNet, attributes, UserInputService); the decisions are the specced AbilityStore and
	the server's AbilityRules.

	@class AbilityServiceClient
]=]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local AbilityAssets = require(ReplicatedStorage.Shared.Features.Ability.Data.AbilityAssets)
local AbilityConstants = require(ReplicatedStorage.Shared.Features.Ability.Data.AbilityConstants)
local AbilityRegistry = require(ReplicatedStorage.Shared.Features.Ability.Data.AbilityRegistry)
local AbilityEvents = require(ReplicatedStorage.Shared.Features.Ability.Net.AbilityEvents)
local EmployeeConstants = require(ReplicatedStorage.Shared.Features.Employee.Data.EmployeeConstants)
local InputActionRegistry = require(ReplicatedStorage.Client.Features.Input.Data.InputActionRegistry)
local InputServiceClient = require(ReplicatedStorage.Client.Features.Input.InputServiceClient)
local React = require(ReplicatedStorage.Packages.React)
local ShiftConstants = require(ReplicatedStorage.Shared.Features.Shift.Data.ShiftConstants)
local AbilityButton = require(ReplicatedStorage.Client.UI.React.Screens.Ability.AbilityButton)
local HudRegistry = require(ReplicatedStorage.Client.UI.React.Screens.Hud.HudRegistry)
local AbilityStore = require(ReplicatedStorage.Client.Features.Ability.State.AbilityStore)
local AbilitySpotSystem = require(ReplicatedStorage.Client.Features.Ability.Systems.AbilitySpotSystem)
local AbilityVfxSystem = require(ReplicatedStorage.Client.Features.Ability.Systems.AbilityVfxSystem)
local SoundServiceClient = require(ReplicatedStorage.Client.Features.Sound.SoundServiceClient)

local player = Players.LocalPlayer
local stoppers: { () -> () } = {}
-- Whether this plant's Cancel has gone (one per plant).
local cancelSent = false
local counters = { used = 0, cancels = 0, spotted = 0 }

-- Inputs that only look around (the camera) never end a plant.
local LOOK_INPUTS: { [Enum.UserInputType]: true } = {
	[Enum.UserInputType.MouseMovement] = true,
	[Enum.UserInputType.MouseButton2] = true,
	[Enum.UserInputType.MouseWheel] = true,
	[Enum.UserInputType.Focus] = true,
	[Enum.UserInputType.Touch] = true,
}
local LOOK_KEYS: { [Enum.KeyCode]: true } = {
	[Enum.KeyCode.Thumbstick2] = true,
}

local function sync()
	local character = player.Character
	AbilityStore.apply(
		player:GetAttribute(AbilityConstants.READY_AT_ATTRIBUTE),
		if character ~= nil then character:GetAttribute(AbilityConstants.ACTIVE_ATTRIBUTE) else nil,
		if character ~= nil then character:GetAttribute(EmployeeConstants.NAME_ATTRIBUTE) else nil
	)
	if AbilityStore.active() ~= "pottedPlant" then
		cancelSent = false
	end
end

local function planted(): boolean
	return AbilityStore.active() == "pottedPlant"
end

-- The ability button's HUD key, drawn just above the shift HUD's own widgets.
local HUD_KEY = "abilityButton"

local function cancelPlant()
	if planted() and not cancelSent then
		cancelSent = true
		counters.cancels += 1
		AbilityEvents.packets.Cancel.send(true)
	end
end

export type AbilityServiceClient = {
	dependencies: { string },
	init: (self: AbilityServiceClient) -> (),
	start: (self: AbilityServiceClient) -> (),
	stop: (self: AbilityServiceClient) -> (),
	getState: (self: AbilityServiceClient) -> { [string]: any },
	use: (self: AbilityServiceClient) -> (),
}

local AbilityServiceClient: AbilityServiceClient = {
	dependencies = { "InputServiceClient", "SoundServiceClient" },

	init = function(self)
		if not InputActionRegistry.has(AbilityConstants.ACTION) then
			InputActionRegistry.register(AbilityConstants.ACTION, {
				context = "gameplay",
				bindings = {
					keyboard = { AbilityConstants.KEYBOARD_KEY },
					gamepad = { AbilityConstants.GAMEPAD_KEY },
				},
				description = "Use your ability",
			})
		end
		if not HudRegistry.has(HUD_KEY) then
			HudRegistry.register(HUD_KEY, function(): React.ReactNode
				return React.createElement(AbilityButton.Widget, {
					onUse = function()
						self:use()
					end,
				})
			end, ShiftConstants.HUD_ORDER + 4)
		end
	end,

	start = function(self)
		local unbind = InputServiceClient:bind(AbilityConstants.ACTION, function(phase)
			if phase == "begin" then
				self:use()
			end
		end)
		local spotted = AbilityEvents.packets.Spotted.listen(function(data: { cargoId: number })
			counters.spotted += 1
			local def = AbilityRegistry.get("spotIt")
			if AbilitySpotSystem.show(data.cargoId, if def ~= nil then def.duration else 5) then
				-- The ping with the glow: 2D, Cappy's ears only.
				SoundServiceClient:play(AbilityAssets.SPOT_PING)
			end
		end)
		local readyChanged = player:GetAttributeChangedSignal(AbilityConstants.READY_AT_ATTRIBUTE):Connect(sync)
		local characterWatch: { RBXScriptConnection } = {}
		local function watch(character: Model?)
			for _, connection in characterWatch do
				connection:Disconnect()
			end
			table.clear(characterWatch)
			if character ~= nil then
				table.insert(
					characterWatch,
					character:GetAttributeChangedSignal(AbilityConstants.ACTIVE_ATTRIBUTE):Connect(sync)
				)
				table.insert(
					characterWatch,
					character:GetAttributeChangedSignal(EmployeeConstants.NAME_ATTRIBUTE):Connect(sync)
				)
			end
			sync()
		end
		local added = player.CharacterAdded:Connect(watch)
		watch(player.Character)
		-- While planted: a move or a jump asks to pop out.
		local frame = RunService.Heartbeat:Connect(function()
			if not planted() or cancelSent then
				return
			end
			local character = player.Character
			local humanoid = if character ~= nil then character:FindFirstChildOfClass("Humanoid") else nil
			if humanoid ~= nil and (humanoid.MoveDirection.Magnitude > 0.1 or humanoid.Jump) then
				cancelPlant()
			end
		end)
		-- While planted: any other action input (not just looking around, not the ability key) asks to pop out.
		local began = UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
			if processed or not planted() then
				return
			end
			if LOOK_INPUTS[input.UserInputType] or LOOK_KEYS[input.KeyCode] then
				return
			end
			if input.KeyCode == AbilityConstants.KEYBOARD_KEY or input.KeyCode == AbilityConstants.GAMEPAD_KEY then
				return
			end
			if input.UserInputType == Enum.UserInputType.Gamepad1 and input.KeyCode == Enum.KeyCode.Thumbstick1 then
				-- The move stick: MoveDirection decides (a tiny drift is not a move).
				return
			end
			cancelPlant()
		end)
		local stopVfx = AbilityVfxSystem.start()
		table.insert(stoppers, function()
			unbind()
			spotted()
			readyChanged:Disconnect()
			added:Disconnect()
			frame:Disconnect()
			began:Disconnect()
			for _, connection in characterWatch do
				connection:Disconnect()
			end
			table.clear(characterWatch)
			stopVfx()
			AbilitySpotSystem.clear()
		end)
	end,

	stop = function(_self)
		for _, stop in stoppers do
			stop()
		end
		table.clear(stoppers)
	end,

	--[=[
		Asks the server to use the ability (the ability key, the phone's button). The server decides; a refusal comes
		back as a toast.
	]=]
	use = function(_self)
		counters.used += 1
		AbilityEvents.packets.Use.send(true)
	end,

	getState = function(_self)
		return {
			readyAt = AbilityStore.readyAt(),
			active = AbilityStore.active(),
			ability = AbilityStore.abilityId(),
			spots = AbilitySpotSystem.shown(),
			vfx = AbilityVfxSystem.played(),
			counters = table.clone(counters),
		}
	end,
}

return AbilityServiceClient
