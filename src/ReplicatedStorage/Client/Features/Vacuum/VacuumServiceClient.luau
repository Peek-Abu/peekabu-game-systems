--!strict
--[=[
	VacuumServiceClient: hold to vacuum (Cleanup Crew spec §4). While the `vacuum` action is held (left
	mouse, gamepad R2, or the Shift HUD's touch button through beginVacuum / endVacuum), it re-aims every
	AIM_INTERVAL at the pile the vacuum is on (VacuumTargetRules: the wand's floor head and the body's facing,
	not the camera; the pile already being cleaned is kept while it is in reach) and keeps Interaction's channel
	on it; letting go stops the channel, and the pile keeps its progress. Nothing is sent while carrying.
	The server decides everything. VacuumFeedbackSystem plays the suction, whine, pop and canister sounds.

	Spec-exempt shell (Input, CollectionService); the aim is the specced VacuumTargetRules.

	@class VacuumServiceClient
]=]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local VacuumConstants = require(ReplicatedStorage.Shared.Features.Vacuum.Data.VacuumConstants)
local VacuumTargetRules = require(ReplicatedStorage.Shared.Features.Vacuum.Rules.VacuumTargetRules)
local VacuumFeedbackSystem = require(ReplicatedStorage.Client.Features.Vacuum.Systems.VacuumFeedbackSystem)
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

-- The pile the local player's vacuum is on (VacuumTargetRules: near the wand's floor head, underfoot, or in
-- front of the body; never the camera), keeping `current` while it is in reach; nil when none is.
local function aimedPile(current: Instance?): Instance?
	local character = Players.LocalPlayer.Character
	local root = if character ~= nil then character:FindFirstChild("HumanoidRootPart") else nil
	if character == nil or root == nil or not root:IsA("BasePart") then
		return nil
	end
	local tool = character:FindFirstChild(VacuumConstants.TOOL_NAME)
	local head = if tool ~= nil then tool:FindFirstChild(VacuumConstants.FLOOR_HEAD_NAME) else nil
	local parts: { BasePart } = {}
	local piles: { VacuumTargetRules.Pile } = {}
	local currentIndex: number? = nil
	for _, pile in CollectionService:GetTagged(VacuumConstants.PILE_TAG) do
		if pile:IsA("BasePart") then
			table.insert(parts, pile)
			table.insert(piles, {
				position = pile.Position,
				radius = VacuumTargetRules.radius(pile.Size, pile:GetAttribute(VacuumConstants.BASE_SIZE_ATTRIBUTE)),
			})
			if pile == current then
				currentIndex = #parts
			end
		end
	end
	local index = VacuumTargetRules.pick(
		root.Position,
		root.CFrame.LookVector,
		if head ~= nil and head:IsA("BasePart") then VacuumTargetRules.head(head.CFrame, head.Size) else nil,
		piles,
		VacuumConstants.TARGET,
		currentIndex
	)
	return if index ~= nil then parts[index] else nil
end

local function localTool(): Tool?
	local player = Players.LocalPlayer
	local character = player.Character
	local backpack = player:FindFirstChildOfClass("Backpack")
	local candidate = if character ~= nil then character:FindFirstChild(VacuumConstants.TOOL_NAME) else nil
	if candidate == nil and backpack ~= nil then
		candidate = backpack:FindFirstChild(VacuumConstants.TOOL_NAME)
	end
	return if candidate ~= nil
			and candidate:IsA("Tool")
			and candidate:GetAttribute(VacuumConstants.TOOL_ATTRIBUTE) == true
		then candidate
		else nil
end

local function selected(): boolean
	local tool = localTool()
	local character = Players.LocalPlayer.Character
	return tool ~= nil and character ~= nil and tool.Parent == character
end

export type VacuumServiceClient = {
	dependencies: { string },
	init: (self: VacuumServiceClient) -> (),
	start: (self: VacuumServiceClient) -> (),
	stop: (self: VacuumServiceClient) -> (),
	beginVacuum: (self: VacuumServiceClient) -> (),
	endVacuum: (self: VacuumServiceClient) -> (),
	isVacuuming: (self: VacuumServiceClient) -> boolean,
	equipVacuum: (self: VacuumServiceClient) -> boolean,
	toggleTool: (self: VacuumServiceClient) -> (),
}

local VacuumServiceClient: VacuumServiceClient = {
	dependencies = {
		"InputServiceClient",
		"InteractionServiceClient",
		"CarryServiceClient",
		"SoundServiceClient",
		"StateSyncServiceClient",
	},

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
		VacuumFeedbackSystem.start()
	end,

	stop = function(self)
		self:endVacuum()
		VacuumFeedbackSystem.stop()
		for _, unbind in unbinders do
			unbind()
		end
		table.clear(unbinders)
	end,

	--[=[
		Starts vacuuming whatever pile the player faces, re-aiming until endVacuum.
	]=]
	beginVacuum = function(_self)
		if holding or not selected() then
			return
		end
		holding = true
		generation += 1
		local mine = generation
		lastTarget = nil
		missed = false
		task.spawn(function()
			while holding and mine == generation do
				local target = if CarryServiceClient:isCarrying() or not selected() then nil else aimedPile(lastTarget)
				if target ~= nil then
					lastTarget = target
					missed = false
					InteractionServiceClient:startChannel(target)
				elseif
					lastTarget ~= nil
					and lastTarget.Parent ~= nil
					and not missed
					and not CarryServiceClient:isCarrying()
					and selected()
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

	equipVacuum = function(_self)
		if CarryServiceClient:isCarrying() then
			return false
		end
		local character = Players.LocalPlayer.Character
		local humanoid = if character ~= nil then character:FindFirstChildOfClass("Humanoid") else nil
		local tool = localTool()
		if humanoid == nil or humanoid.Health <= 0 or tool == nil then
			return false
		end
		humanoid:EquipTool(tool)
		return selected()
	end,

	toggleTool = function(self)
		if selected() then
			self:endVacuum()
			local character = Players.LocalPlayer.Character
			local humanoid = if character ~= nil then character:FindFirstChildOfClass("Humanoid") else nil
			if humanoid ~= nil then
				humanoid:UnequipTools()
			end
		else
			self:equipVacuum()
		end
	end,

	isVacuuming = function(_self)
		return holding
	end,
}

return VacuumServiceClient
