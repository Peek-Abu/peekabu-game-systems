--!strict
--[=[
	DepotSpotSystem: the hub's spots on the server (plan docs/superpowers/plans/2026-11-11-hub-interactables.md). A spot
	is a Studio part with the base Interaction tag and a `depot-spot-*` InteractionKind (DepotSpotConstants.KINDS), so
	the Interaction feature builds its prompt and checks the player's distance; the kinds are registered at require,
	before any tagged part gets its prompt.

	- A use goes through DepotSpotRules.open (a standee only for a real employee, named by its
	  DepotSpotConstants.EMPLOYEE_ATTRIBUTE) and the player is sent DepotEvents.Spot: the client opens what it says.
	- The bell: each bell rests DepotSpotConstants.BELL_COOLDOWN after it rings (DepotSpotRules.bellReady, for
	  everyone), and a ring is sent to every player (DepotEvents.Bell, the bell's position).
	- A standee's prompt names its employee, and any spot with DepotSpotConstants.LABEL_ATTRIBUTE names itself (a Lost &
	  Found locker door), on the prompt's ObjectText, set when its prompt appears.

	Spec-exempt shell (Interaction wiring, ByteNet, Instances); the decisions are the specced DepotSpotRules.

	@class DepotSpotSystem
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Observers = require(ReplicatedStorage.Packages.Observers)
local DepotEvents = require(ReplicatedStorage.Shared.Features.Depot.Net.DepotEvents)
local DepotSpotConstants = require(ReplicatedStorage.Shared.Features.Depot.Data.DepotSpotConstants)
local DepotSpotRules = require(ReplicatedStorage.Shared.Features.Depot.Rules.DepotSpotRules)
local InteractionConstants = require(ReplicatedStorage.Shared.Features.Interaction.Data.InteractionConstants)
local InteractionRegistry = require(ReplicatedStorage.Shared.Features.Interaction.Data.InteractionRegistry)
local InteractionServiceServer = require(ServerScriptService.Features.Interaction.InteractionServiceServer)

local PROMPT_WAIT_SECONDS = 10

for _, spot: DepotSpotRules.Spot in DepotSpotRules.spots() do
	local kind = DepotSpotConstants.KINDS[spot]
	if not InteractionRegistry.has(kind) then
		local prompt = DepotSpotConstants.PROMPTS[spot]
		InteractionRegistry.register(kind, {
			actionText = prompt.action,
			objectText = prompt.object,
			maxDistance = DepotSpotConstants.MAX_DISTANCE,
			cooldown = DepotSpotConstants.USE_COOLDOWN,
		})
	end
end

-- When each bell last rang (os.clock()), by bell. Strong keys, removed when the bell leaves the tag.
local rungAt: { [Instance]: number } = {}

local function positionOf(target: Instance): Vector3?
	if target:IsA("BasePart") then
		return target.Position
	elseif target:IsA("Model") then
		return target:GetPivot().Position
	end
	return nil
end

local function nameStandee(target: Instance): () -> ()
	local alive = true
	task.spawn(function()
		local deadline = os.clock() + PROMPT_WAIT_SECONDS
		while alive and os.clock() < deadline do
			local prompt = target:FindFirstChild(InteractionConstants.PROMPT_NAME, true)
			local label = target:GetAttribute(DepotSpotConstants.LABEL_ATTRIBUTE)
				or target:GetAttribute(DepotSpotConstants.EMPLOYEE_ATTRIBUTE)
			if prompt ~= nil and prompt:IsA("ProximityPrompt") then
				if type(label) == "string" and label ~= "" then
					prompt.ObjectText = label
				end
				return
			end
			task.wait(0.25)
		end
	end)
	return function()
		alive = false
	end
end

local DepotSpotSystem = {}

-- Answers every spot kind; returns the stopper.
function DepotSpotSystem.start(): () -> ()
	for _, spot: DepotSpotRules.Spot in DepotSpotRules.spots() do
		InteractionServiceServer:onInteract(DepotSpotConstants.KINDS[spot], function(player: Player, target: Instance)
			local opened = DepotSpotRules.open(spot, target:GetAttribute(DepotSpotConstants.EMPLOYEE_ATTRIBUTE))
			if opened == nil then
				return
			end
			if opened.spot == "bell" then
				local now = os.clock()
				local at = positionOf(target)
				if at == nil or not DepotSpotRules.bellReady(rungAt[target], now) then
					return
				end
				rungAt[target] = now
				DepotEvents.packets.Bell.sendToAll(at)
				return
			end
			DepotEvents.packets.Spot.sendTo({ spot = opened.spot, employee = opened.employee }, player)
		end)
	end
	local stopObserver = Observers.observeTag(InteractionConstants.TAG, function(target: Instance)
		local kind = target:GetAttribute(InteractionConstants.KIND_ATTRIBUTE)
		local spot = if type(kind) == "string" then DepotSpotRules.spotOf(kind) else nil
		if spot == "standee" or target:GetAttribute(DepotSpotConstants.LABEL_ATTRIBUTE) ~= nil then
			return nameStandee(target)
		elseif spot == "bell" then
			return function()
				rungAt[target] = nil
			end
		end
		return nil
	end)
	return function()
		stopObserver()
		table.clear(rungAt)
	end
end

return DepotSpotSystem
