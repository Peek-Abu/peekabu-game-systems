--!strict
--[=[
	VacuumServiceClient: hold to vacuum (Cleanup Crew spec §4). While the `vacuum` action is held (left
	mouse, gamepad R2, or the Shift HUD's touch button through beginVacuum / endVacuum), it re-aims every
	AIM_INTERVAL at the pile the player faces within range (VacuumAimUtils) and keeps Interaction's channel
	on it; letting go stops the channel, and the pile keeps its progress. Nothing is sent while carrying.
	The server decides everything.

	Spec-exempt shell (Input, Camera, CollectionService); the aim is the specced VacuumAimUtils.

	@class VacuumServiceClient
]=]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local VacuumConstants = require(ReplicatedStorage.Shared.Features.Vacuum.Data.VacuumConstants)
local VacuumAimUtils = require(ReplicatedStorage.Client.Features.Vacuum.Utils.VacuumAimUtils)
local CarryServiceClient = require(ReplicatedStorage.Client.Features.Carry.CarryServiceClient)
local InputActionRegistry = require(ReplicatedStorage.Client.Features.Input.Data.InputActionRegistry)
local InputServiceClient = require(ReplicatedStorage.Client.Features.Input.InputServiceClient)
local InteractionServiceClient = require(ReplicatedStorage.Client.Features.Interaction.InteractionServiceClient)

local holding = false
-- N12 hysteresis: the last aimed pile and whether the aim already missed once this hold.
local lastTarget: Instance? = nil
-- Bumped by every beginVacuum so a stale aim loop from a quick release and re-press exits.
local generation = 0
local missed = false
local unbinders: { () -> () } = {}

-- The pile the local player is facing within range, or nil.
local function aimedPile(): Instance?
	local character = Players.LocalPlayer.Character
	local root = if character ~= nil then character:FindFirstChild("HumanoidRootPart") else nil
	local camera = Workspace.CurrentCamera
	if root == nil or not root:IsA("BasePart") or camera == nil then
		return nil
	end
	local piles: { BasePart } = {}
	local positions: { Vector3 } = {}
	for _, pile in CollectionService:GetTagged(VacuumConstants.PILE_TAG) do
		if pile:IsA("BasePart") then
			table.insert(piles, pile)
			table.insert(positions, pile.Position)
		end
	end
	local index = VacuumAimUtils.pick(
		root.Position,
		camera.CFrame.LookVector,
		positions,
		VacuumConstants.RANGE,
		VacuumConstants.AIM_MIN_DOT
	)
	return if index ~= nil then piles[index] else nil
end

export type VacuumServiceClient = {
	dependencies: { string },
	init: (self: VacuumServiceClient) -> (),
	start: (self: VacuumServiceClient) -> (),
	stop: (self: VacuumServiceClient) -> (),
	beginVacuum: (self: VacuumServiceClient) -> (),
	endVacuum: (self: VacuumServiceClient) -> (),
	isVacuuming: (self: VacuumServiceClient) -> boolean,
}

local VacuumServiceClient: VacuumServiceClient = {
	dependencies = { "InputServiceClient", "InteractionServiceClient", "CarryServiceClient" },

	init = function(_self)
		if InputActionRegistry.get(VacuumConstants.ACTION) == nil then
			InputActionRegistry.register(VacuumConstants.ACTION, {
				context = "gameplay",
				bindings = { keyboard = { Enum.UserInputType.MouseButton1 }, gamepad = { Enum.KeyCode.ButtonR2 } },
				description = "Hold to vacuum the pile in front of you",
			})
		end
	end,

	start = function(self)
		table.insert(
			unbinders,
			InputServiceClient:bind(VacuumConstants.ACTION, function(phase)
				if phase == "begin" then
					self:beginVacuum()
				else
					self:endVacuum()
				end
			end)
		)
	end,

	stop = function(self)
		self:endVacuum()
		for _, unbind in unbinders do
			unbind()
		end
		table.clear(unbinders)
	end,

	--[=[
		Starts vacuuming whatever pile the player faces, re-aiming until endVacuum.
	]=]
	beginVacuum = function(_self)
		if holding then
			return
		end
		holding = true
		generation += 1
		local mine = generation
		lastTarget = nil
		missed = false
		task.spawn(function()
			while holding and mine == generation do
				local target = if CarryServiceClient:isCarrying() then nil else aimedPile()
				if target ~= nil then
					lastTarget = target
					missed = false
					InteractionServiceClient:startChannel(target)
				elseif
					lastTarget ~= nil
					and lastTarget.Parent ~= nil
					and not missed
					and not CarryServiceClient:isCarrying()
				then
					-- Aim dropped: keep the channel one more interval so edge flapping does not burn the rate limit.
					missed = true
					InteractionServiceClient:startChannel(lastTarget)
				else
					lastTarget = nil
					missed = false
					InteractionServiceClient:stopChannel()
				end
				task.wait(VacuumConstants.AIM_INTERVAL)
			end
		end)
	end,

	endVacuum = function(_self)
		holding = false
		InteractionServiceClient:stopChannel()
	end,

	isVacuuming = function(_self)
		return holding
	end,
}

return VacuumServiceClient
