--!strict
--[=[
	CargoServiceClient: the `pocket` Input action (Q / D-pad up), and button-friendly `pocket`, `drop` and
	`throw` for the Shift HUD's touch buttons. Requests only; the server decides.

	Drop and throw send Carry's own packets: CarryServiceClient binds them to G / F but has no callable API
	(an open question for the base).

	Spec-exempt shell (Input, Camera, ByteNet).

	@class CargoServiceClient
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local CargoConstants = require(ReplicatedStorage.Shared.Features.Cargo.Data.CargoConstants)
local CargoEvents = require(ReplicatedStorage.Shared.Features.Cargo.Net.CargoEvents)
local CarryEvents = require(ReplicatedStorage.Shared.Features.Carry.Net.CarryEvents)
local CarryServiceClient = require(ReplicatedStorage.Client.Features.Carry.CarryServiceClient)
local InputActionRegistry = require(ReplicatedStorage.Client.Features.Input.Data.InputActionRegistry)
local InputServiceClient = require(ReplicatedStorage.Client.Features.Input.InputServiceClient)

local unbinders: { () -> () } = {}

export type CargoServiceClient = {
	dependencies: { string },
	init: (self: CargoServiceClient) -> (),
	start: (self: CargoServiceClient) -> (),
	stop: (self: CargoServiceClient) -> (),
	pocket: (self: CargoServiceClient) -> (),
	drop: (self: CargoServiceClient) -> (),
	throw: (self: CargoServiceClient) -> (),
}

local CargoServiceClient: CargoServiceClient = {
	dependencies = { "InputServiceClient", "CarryServiceClient" },

	init = function(_self)
		if not InputActionRegistry.has(CargoConstants.POCKET_ACTION) then
			InputActionRegistry.register(CargoConstants.POCKET_ACTION, {
				context = "gameplay",
				bindings = { keyboard = { Enum.KeyCode.Q }, gamepad = { Enum.KeyCode.DPadUp } },
				description = "Pocket a tiny item",
			})
		end
	end,

	start = function(self)
		table.insert(
			unbinders,
			InputServiceClient:bind(CargoConstants.POCKET_ACTION, function(phase)
				if phase == "begin" then
					self:pocket()
				end
			end)
		)
	end,

	stop = function(_self)
		for _, unbind in unbinders do
			unbind()
		end
		table.clear(unbinders)
	end,

	pocket = function(_self)
		if CarryServiceClient:isCarrying() then
			CargoEvents.packets.Pocket.send(true)
		end
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
