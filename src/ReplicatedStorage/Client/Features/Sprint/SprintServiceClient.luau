--!strict
--[=[
	SprintServiceClient: the local side of sprinting (docs/superpowers/specs/2026-10-15-cleanup-crew-chase-kit-design.md
	§3). Holding the base Input action `sprint` (Shift / L3), or the phone's SPRINT button (`setHeld`), tells the server
	the key is held; the server decides whether that sprints and sets the speed. The Player's SprintStamina / Sprinting
	attributes feed SprintStore; the shift HUD draws the stamina slip from it (SprintStaminaSlip, tucked against the
	equipment cards).

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

local function send()
	local held = keyHeld or buttonHeld
	if held ~= sent then
		sent = held
		SprintEvents.packets.Sprint.send(held)
	end
end

local function mirror()
	SprintStore.apply(
		player:GetAttribute(SprintConstants.STAMINA_ATTRIBUTE),
		player:GetAttribute(SprintConstants.SPRINTING_ATTRIBUTE)
	)
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
		local stamina = player:GetAttributeChangedSignal(SprintConstants.STAMINA_ATTRIBUTE):Connect(mirror)
		local sprinting = player:GetAttributeChangedSignal(SprintConstants.SPRINTING_ATTRIBUTE):Connect(mirror)
		table.insert(stoppers, function()
			unbind()
			stamina:Disconnect()
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
