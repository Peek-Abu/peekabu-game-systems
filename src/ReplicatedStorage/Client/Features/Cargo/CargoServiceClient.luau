--!strict
--[=[
	CargoServiceClient: the hotbar inventory's input (docs/superpowers/specs/2026-10-16-cleanup-crew-hotbar-inventory-design.md):
	keys 1-5 choose a hotbar slot (1 the vacuum, 2-5 the item slots), the mouse wheel and the gamepad's d-pad left /
	right step through them, and the Shift HUD's hotbar taps call `select`. The engine's own Backpack hotbar is turned
	off (it cannot be styled; the Shift HUD draws the paper one, ShiftHotbar). Button-friendly `drop` and `throw` for the
	touch buttons. Requests only; the server decides. M2: slipping on puddles (CargoSlipSystem).
	CargoFeedbackSystem plays the banking swoop and floaters, the pickup and pocket sounds, and the plant's leaves;
	CargoBillboardSystem draws the price tags near the camera; CargoGrimeVisualSystem dirties grimy valuables and
	CargoLootFeedbackSystem plays the glint, reveal and appraisal moments (the loot loop).

	The wheel is sunk while a shift's hotbar is up (bound above the camera's own wheel zoom), so it steps the hotbar
	instead of zooming; I / O still zoom.

	Drop and throw send Carry's own packets: CarryServiceClient binds them to G / F but has no callable API
	(an open question for the base).

	Spec-exempt shell (Input, ContextActionService, StarterGui, Camera, ByteNet); the stepping is the specced
	CargoInventoryRules.step.

	@class CargoServiceClient
]=]

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")
local Workspace = game:GetService("Workspace")

local CargoConstants = require(ReplicatedStorage.Shared.Features.Cargo.Data.CargoConstants)
local CargoInventoryRules = require(ReplicatedStorage.Shared.Features.Cargo.Rules.CargoInventoryRules)
local CargoSlipSystem = require(ReplicatedStorage.Client.Features.Cargo.Systems.CargoSlipSystem)
local CargoEvents = require(ReplicatedStorage.Shared.Features.Cargo.Net.CargoEvents)
local CarryEvents = require(ReplicatedStorage.Shared.Features.Carry.Net.CarryEvents)
local StateSyncConstants = require(ReplicatedStorage.Shared.Features.StateSync.Data.StateSyncConstants)
local VacuumConstants = require(ReplicatedStorage.Shared.Features.Vacuum.Data.VacuumConstants)
local CarryServiceClient = require(ReplicatedStorage.Client.Features.Carry.CarryServiceClient)
local CargoBillboardSystem = require(ReplicatedStorage.Client.Features.Cargo.Systems.CargoBillboardSystem)
local CargoFeedbackSystem = require(ReplicatedStorage.Client.Features.Cargo.Systems.CargoFeedbackSystem)
local CargoGrimeVisualSystem = require(ReplicatedStorage.Client.Features.Cargo.Systems.CargoGrimeVisualSystem)
local CargoLootFeedbackSystem = require(ReplicatedStorage.Client.Features.Cargo.Systems.CargoLootFeedbackSystem)
local InputActionRegistry = require(ReplicatedStorage.Client.Features.Input.Data.InputActionRegistry)
local InputServiceClient = require(ReplicatedStorage.Client.Features.Input.InputServiceClient)
local StateSyncClientStore = require(ReplicatedStorage.Client.Features.StateSync.State.StateSyncClientStore)

local unbinders: { () -> () } = {}

-- The wheel's ContextActionService binding: above the camera's wheel zoom (Medium), so a wheel step is sunk here.
local WHEEL_ACTION = "CargoHotbarWheel"
local WHEEL_PRIORITY = Enum.ContextActionPriority.High.Value + 1
-- How often (seconds) and how many times turning the engine Backpack off is retried while the CoreGui loads.
local BACKPACK_RETRY = 0.5
local BACKPACK_TRIES = 20

local SLOT_KEYS: { Enum.KeyCode } =
	{ Enum.KeyCode.One, Enum.KeyCode.Two, Enum.KeyCode.Three, Enum.KeyCode.Four, Enum.KeyCode.Five }

-- The hotbar slot the local player has chosen now (the HUD shows the same; 0 = none).
local function chosen(): number
	local entry = StateSyncClientStore.publicPlayers()[StateSyncConstants.publicEntryKey(Players.LocalPlayer.UserId)]
	if entry == nil then
		return 0
	end
	local hands = entry[CargoConstants.PUBLIC_HANDS_FIELD]
	if type(hands) == "number" then
		return hands + 1
	end
	if entry[VacuumConstants.PUBLIC_EQUIPPED_FIELD] == true then
		return CargoConstants.VACUUM_SLOT
	end
	local selected = entry[CargoConstants.PUBLIC_SELECTED_FIELD]
	return if type(selected) == "number" and selected ~= CargoConstants.VACUUM_SLOT then selected else 0
end

-- Turns the engine's Backpack hotbar off; the CoreGui may not be ready at start, so it is retried a few times.
local function hideBackpack()
	task.spawn(function()
		for _ = 1, BACKPACK_TRIES do
			local ok = pcall(function()
				StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
			end)
			if ok then
				return
			end
			task.wait(BACKPACK_RETRY)
		end
	end)
end

export type CargoServiceClient = {
	dependencies: { string },
	init: (self: CargoServiceClient) -> (),
	start: (self: CargoServiceClient) -> (),
	stop: (self: CargoServiceClient) -> (),
	select: (self: CargoServiceClient, slot: number) -> (),
	step: (self: CargoServiceClient, direction: number) -> (),
	drop: (self: CargoServiceClient) -> (),
	throw: (self: CargoServiceClient) -> (),
}

local CargoServiceClient: CargoServiceClient = {
	dependencies = { "InputServiceClient", "CarryServiceClient", "SoundServiceClient", "StateSyncServiceClient" },

	init = function(_self)
		for index, action in CargoConstants.SLOT_ACTIONS do
			if not InputActionRegistry.has(action) then
				InputActionRegistry.register(action, {
					context = "gameplay",
					bindings = { keyboard = { SLOT_KEYS[index] } },
					description = if index == CargoConstants.VACUUM_SLOT
						then "Take out the vacuum"
						else `Hold the item in slot {index}`,
				})
			end
		end
		if not InputActionRegistry.has(CargoConstants.PREVIOUS_SLOT_ACTION) then
			InputActionRegistry.register(CargoConstants.PREVIOUS_SLOT_ACTION, {
				context = "gameplay",
				bindings = { gamepad = { Enum.KeyCode.DPadLeft } },
				description = "Previous hotbar slot",
			})
		end
		if not InputActionRegistry.has(CargoConstants.NEXT_SLOT_ACTION) then
			InputActionRegistry.register(CargoConstants.NEXT_SLOT_ACTION, {
				context = "gameplay",
				bindings = { gamepad = { Enum.KeyCode.DPadRight } },
				description = "Next hotbar slot",
			})
		end
	end,

	start = function(self)
		hideBackpack()
		for index, action in CargoConstants.SLOT_ACTIONS do
			table.insert(
				unbinders,
				InputServiceClient:bind(action, function(phase)
					if phase == "begin" then
						self:select(index)
					end
				end)
			)
		end
		table.insert(
			unbinders,
			InputServiceClient:bind(CargoConstants.PREVIOUS_SLOT_ACTION, function(phase)
				if phase == "begin" then
					self:step(-1)
				end
			end)
		)
		table.insert(
			unbinders,
			InputServiceClient:bind(CargoConstants.NEXT_SLOT_ACTION, function(phase)
				if phase == "begin" then
					self:step(1)
				end
			end)
		)
		ContextActionService:BindActionAtPriority(
			WHEEL_ACTION,
			function(_name: string, state: Enum.UserInputState, input: InputObject): Enum.ContextActionResult
				if state ~= Enum.UserInputState.Change or input.Position.Z == 0 then
					return Enum.ContextActionResult.Pass
				end
				-- Wheel down (towards you) steps right, as Roblox's and most games' hotbars do.
				self:step(if input.Position.Z < 0 then 1 else -1)
				return Enum.ContextActionResult.Sink
			end,
			false,
			WHEEL_PRIORITY,
			Enum.UserInputType.MouseWheel
		)
		table.insert(unbinders, function()
			ContextActionService:UnbindAction(WHEEL_ACTION)
		end)
		CargoSlipSystem.start()
		CargoFeedbackSystem.start()
		CargoBillboardSystem.start()
		CargoGrimeVisualSystem.start()
		CargoLootFeedbackSystem.start()
	end,

	stop = function(_self)
		CargoLootFeedbackSystem.stop()
		CargoGrimeVisualSystem.stop()
		CargoBillboardSystem.stop()
		CargoFeedbackSystem.stop()
		for _, unbind in unbinders do
			unbind()
		end
		table.clear(unbinders)
		CargoSlipSystem.stop()
	end,

	--[=[
		Asks for hotbar slot `slot` (1 the vacuum, 2-5 the item slots). The server checks it (a big item locks them all).
	]=]
	select = function(_self, slot)
		if slot >= 1 and slot <= CargoConstants.HOTBAR_SLOTS then
			CargoEvents.packets.Select.send(slot)
		end
	end,

	--[=[
		Asks for the next (+1) or previous (-1) hotbar slot, wrapping round.
	]=]
	step = function(self, direction)
		self:select(CargoInventoryRules.step(chosen(), direction))
	end,

	drop = function(_self)
		if CarryServiceClient:isCarrying() then
			CarryEvents.packets.Drop.send(true)
		end
	end,

	throw = function(_self)
		local camera = Workspace.CurrentCamera
		if camera ~= nil and CarryServiceClient:isCarrying() then
			CarryEvents.packets.Throw.send(camera.CFrame.LookVector)
		end
	end,
}

return CargoServiceClient
