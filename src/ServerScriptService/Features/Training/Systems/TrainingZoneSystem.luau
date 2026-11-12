--!strict
--[=[
	TrainingZoneSystem: the hub's Training bay as a zone (owner 11-12). A part tagged TrainingConstants.ZONE_TAG (a
	flat, invisible floor part covering the bay) keeps a pool of one-seat queue pads, each exactly the zone's size
	and place, invisible and untouchable (TrainingConstants.ZONE_PAD_TAG, made queue pads by the caller's
	`configure`). Queue puts a player on at most one pad and a one-seat pad takes one player, so every player in
	the bay boards their own pad: their own countdown and their own reserved training server, all at the same time.

	Every ZONE_TICK_SECONDS it counts the pads in use (a player on it, a countdown, or used within
	ZONE_IDLE_SECONDS: a party whose teleport fails comes back to the pad it left from) and the players in the bay on
	no pad yet, and adds or removes pads as the specced TrainingZoneRules says. Only empty pads are removed.

	Spec-exempt shell (Instances, Players, Queue); the decisions are the specced TrainingZoneRules.

	@class TrainingZoneSystem
]=]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")

local QueueConstants = require(ReplicatedStorage.Shared.Features.Queue.Data.QueueConstants)
local TrainingConstants = require(ReplicatedStorage.Shared.Features.Training.Data.TrainingConstants)
local QueuePadRules = require(ServerScriptService.Features.Queue.Rules.QueuePadRules)
local QueueServiceServer = require(ServerScriptService.Features.Queue.QueueServiceServer)
local TrainingZoneRules = require(ServerScriptService.Features.Training.Rules.TrainingZoneRules)

local TrainingZoneSystem = {}

-- The players standing in `zone` (living, by their HumanoidRootPart), measured like a queue pad.
local function playersIn(zone: BasePart): { Player }
	local inside: { Player } = {}
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local humanoid = if character ~= nil then character:FindFirstChildOfClass("Humanoid") else nil
		local root = if character ~= nil then character:FindFirstChild("HumanoidRootPart") else nil
		if
			humanoid ~= nil
			and humanoid.Health > 0
			and root ~= nil
			and root:IsA("BasePart")
			and QueuePadRules.isAboard(zone.CFrame, zone.Size, root.Position, QueueConstants.ABOARD_HEIGHT)
		then
			table.insert(inside, player)
		end
	end
	return inside
end

--[=[
	Starts the pool for `zone`; `configure` makes a fresh pad a one-seat training queue pad (it adds the Queue tag).
	@return () -> () -- stops: removes every pad it made
]=]
function TrainingZoneSystem.start(zone: BasePart, configure: (pad: BasePart) -> ()): () -> ()
	local pool: { BasePart } = {}
	-- When each pad last had a player on it or a countdown (nil: never).
	local lastBusy: { [BasePart]: number } = {}
	local clock = 0

	local function make()
		local pad = Instance.new("Part")
		pad.Name = "TrainingZonePad"
		pad.Anchored = true
		pad.CanCollide = false
		pad.CanQuery = false
		pad.CanTouch = false
		pad.CastShadow = false
		pad.Transparency = 1
		pad.Size = zone.Size
		pad.CFrame = zone.CFrame
		CollectionService:AddTag(pad, TrainingConstants.ZONE_PAD_TAG)
		configure(pad)
		pad.Parent = zone
		table.insert(pool, pad)
	end

	local function tick()
		local now = os.clock()
		local busy, idle = 0, 0
		local empty: { BasePart } = {}
		for _, pad in pool do
			local inUse = #QueueServiceServer.pads:membersOf(pad) > 0 or QueueServiceServer.pads:endsAtOf(pad) ~= nil
			if inUse then
				lastBusy[pad] = now
			end
			if TrainingZoneRules.idle(inUse, lastBusy[pad], now, TrainingConstants.ZONE_IDLE_SECONDS) then
				idle += 1
				table.insert(empty, pad)
			else
				busy += 1
			end
		end
		local waiting = 0
		for _, player in playersIn(zone) do
			if QueueServiceServer:padOf(player) == nil then
				waiting += 1
			end
		end
		local delta = TrainingZoneRules.plan(busy, idle, waiting, TrainingConstants.ZONE_MAX_PADS)
		for _ = 1, delta do
			make()
		end
		-- Remove the newest empty pads first (the oldest pads keep the lowest queue ids).
		for i = #empty, #empty + delta + 1, -1 do
			local pad = empty[i]
			local index = table.find(pool, pad)
			if index ~= nil then
				table.remove(pool, index)
			end
			lastBusy[pad] = nil
			pad:Destroy()
		end
	end

	tick()
	local connection = RunService.Heartbeat:Connect(function(deltaTime: number)
		clock += deltaTime
		if clock >= TrainingConstants.ZONE_TICK_SECONDS then
			clock = 0
			tick()
		end
	end)
	return function()
		connection:Disconnect()
		for _, pad in pool do
			pad:Destroy()
		end
		table.clear(pool)
		table.clear(lastBusy)
	end
end

return TrainingZoneSystem
