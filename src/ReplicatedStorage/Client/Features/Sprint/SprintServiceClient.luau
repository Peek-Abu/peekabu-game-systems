--!strict
--[=[
	SprintServiceClient: the local side of sprinting (docs/superpowers/specs/2026-10-15-cleanup-crew-chase-kit-design.md
	§3). Holding the base Input action `sprint` (Shift / L3), or the phone's SPRINT button (`setHeld`), tells the server
	the key is held; the server decides whether that sprints and sets the speed. The server's Stamina packet (to this
	player only) and the Player's Sprinting attribute feed SprintStore; the shift HUD draws the stamina bar from it (ShiftCompactHudPanel, over the
	hotbar).

	Spec-exempt shell (Input, ByteNet, attributes); the decisions are the server's specced SprintRules and
	SprintStaminaFormulas, the bar's the specced SprintViewModel.

	@class SprintServiceClient
]=]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SprintConstants = require(ReplicatedStorage.Shared.Features.Sprint.Data.SprintConstants)
local SprintEvents = require(ReplicatedStorage.Shared.Features.Sprint.Net.SprintEvents)
local InputServiceClient = require(ReplicatedStorage.Client.Features.Input.InputServiceClient)
local SprintStore = require(ReplicatedStorage.Client.Features.Sprint.State.SprintStore)

local player = Players.LocalPlayer
local stoppers: { () -> () } = {}
-- What holds the sprint: the key, and the phone button.
local keyHeld = false
local buttonHeld = false
local sent = false
-- The last stamina the server sent (0-1; nil until the first, which reads as a full bar).
local lastStamina: number? = nil

local function send()
	local held = keyHeld or buttonHeld
	if held ~= sent then
		sent = held
		SprintEvents.packets.Sprint.send(held)
	end
end

local function mirror()
	SprintStore.apply(lastStamina, player:GetAttribute(SprintConstants.SPRINTING_ATTRIBUTE))
end

export type SprintServiceClient = {
	dependencies: { string },
	init: (self: SprintServiceClient) -> (),
	start: (self: SprintServiceClient) -> (),
	stop: (self: SprintServiceClient) -> (),
	getState: (self: SprintServiceClient) -> { [string]: any },
	setHeld: (self: SprintServiceClient, held: boolean) -> (),
}

local SprintServiceClient: SprintServiceClient = {
	dependencies = { "InputServiceClient" },

	init = function(_self) end,

	start = function(_self)
		local unbind = InputServiceClient:bind(SprintConstants.ACTION, function(phase)
			keyHeld = phase == "begin"
			send()
		end)
		local stopStamina = SprintEvents.packets.Stamina.listen(function(percent: number)
			lastStamina = percent / 100
			mirror()
		end)
		local sprinting = player:GetAttributeChangedSignal(SprintConstants.SPRINTING_ATTRIBUTE):Connect(mirror)
		table.insert(stoppers, function()
			unbind()
			stopStamina()
			sprinting:Disconnect()
		end)
		mirror()
	end,

	stop = function(_self)
		for _, stop in stoppers do
			stop()
		end
		table.clear(stoppers)
		keyHeld = false
		buttonHeld = false
		send()
	end,

	--[=[
		The phone's SPRINT button: held (true) or let go (false).
	]=]
	setHeld = function(_self, held)
		buttonHeld = held
		send()
	end,

	getState = function(_self)
		return { held = sent, stamina = SprintStore.stamina(), sprinting = SprintStore.sprinting() }
	end,
}

return SprintServiceClient
