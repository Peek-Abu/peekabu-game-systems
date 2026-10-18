--!strict
--[=[
	InteractionChannelSystem: runs every channel. Each tick it re-checks every channeler (a living
	character, in range, the target enabled and still in the world, the game's canChannel), advances
	progress through InteractionChannelTracker, mirrors it onto the target's ChannelProgress /
	ChannelCount attributes, and calls the kind's onComplete once when a target reaches full.

	Spec-exempt shell (Players, Instances, attributes); the bookkeeping is the specced
	InteractionChannelTracker and the per-player check is the specced InteractionRules.

	@class InteractionChannelSystem
]=]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")

local InteractionData = ReplicatedStorage.Shared.Features.Interaction.Data
local Logger = require(ReplicatedStorage.Shared.Core.Logger)
local InteractionConstants = require(InteractionData.InteractionConstants)
local InteractionRegistry = require(InteractionData.InteractionRegistry)
local InteractionRules = require(ServerScriptService.Features.Interaction.Rules.InteractionRules)
local InteractionChannelTracker = require(ServerScriptService.Features.Interaction.State.InteractionChannelTracker)

export type ChannelHandler = {
	-- Asked when a player starts and every tick after; false refuses or ends their channel. Must not yield.
	canChannel: ((player: Player, target: Instance) -> boolean)?,
	-- Once, when progress reaches full; `players` are everyone on the target at that moment. Runs on its
	-- own thread, so it may yield.
	onComplete: (players: { Player }, target: Instance) -> (),
}

export type InteractionChannelSystem = {
	start: (self: InteractionChannelSystem, player: Player, target: Instance) -> (boolean, string?),
	stop: (self: InteractionChannelSystem, player: Player) -> (),
	reset: (self: InteractionChannelSystem, target: Instance) -> (),
	step: (self: InteractionChannelSystem, dt: number) -> (),
}

local log = Logger.new("InteractionChannelSystem")

local function rootPartOf(target: Instance): BasePart?
	if target:IsA("BasePart") then
		return target
	end
	if target:IsA("Model") then
		return target.PrimaryPart or target:FindFirstChildWhichIsA("BasePart", true)
	end
	return nil
end

local function kindOf(target: Instance): string?
	local kind = target:GetAttribute(InteractionConstants.CHANNEL_KIND_ATTRIBUTE)
	return if type(kind) == "string" and InteractionRegistry.hasChannel(kind) then kind else nil
end

local InteractionChannelSystem = {}

function InteractionChannelSystem.new(handlers: { [string]: ChannelHandler }): InteractionChannelSystem
	local tracker = InteractionChannelTracker.new()
	local idOf: { [Instance]: number } = {}
	setmetatable(idOf, { __mode = "k" })
	local targetById: { [number]: Instance } = {}
	local nextId = 0

	local function idFor(target: Instance): number
		local id = idOf[target]
		if id == nil then
			nextId += 1
			id = nextId
			idOf[target] = id
		end
		targetById[id] = target
		return id
	end

	-- Whether `player` may channel `target` right now; the reason when not.
	local function allowed(player: Player, target: Instance): (boolean, string?)
		local kind = kindOf(target)
		local def = if kind ~= nil then InteractionRegistry.getChannel(kind) else nil
		local handler = if kind ~= nil then handlers[kind] else nil
		local root = rootPartOf(target)
		if kind == nil or def == nil or handler == nil or root == nil or not target:IsDescendantOf(Workspace) then
			return false, "not a channel"
		end
		local character = player.Character
		local humanoid = if character ~= nil then character:FindFirstChildOfClass("Humanoid") else nil
		local playerRoot = if character ~= nil then character:FindFirstChild("HumanoidRootPart") else nil
		local alive = humanoid ~= nil and humanoid.Health > 0 and playerRoot ~= nil and playerRoot:IsA("BasePart")
		local distance = if playerRoot ~= nil and playerRoot:IsA("BasePart")
			then (playerRoot.Position - root.Position).Magnitude
			else math.huge
		local ok, reason = InteractionRules.check({
			hasCharacter = alive,
			distance = distance,
			maxDistance = def.maxDistance or InteractionConstants.DEFAULT_MAX_DISTANCE,
			tolerance = InteractionConstants.DISTANCE_TOLERANCE,
			enabled = target:GetAttribute(InteractionConstants.ENABLED_ATTRIBUTE) ~= false,
			cooldownRemaining = 0,
		})
		if not ok then
			return false, reason
		end
		local canChannel = handler.canChannel
		if canChannel ~= nil then
			local called, result = pcall(canChannel, player, target)
			if not called then
				log:error(`channel "{kind}" canChannel failed: {result}`)
				return false, "refused by game"
			end
			if not result then
				return false, "refused by game"
			end
		end
		return true, nil
	end

	local function publish(targetId: number)
		local target: Instance? = targetById[targetId]
		if target == nil then
			return
		end
		local count = #tracker:channelers(targetId)
		local progress = tracker:progress(targetId)
		target:SetAttribute(InteractionConstants.CHANNEL_PROGRESS_ATTRIBUTE, if progress > 0 then progress else nil)
		target:SetAttribute(InteractionConstants.CHANNEL_COUNT_ATTRIBUTE, if count > 0 then count else nil)
	end

	local system: InteractionChannelSystem
	system = {
		start = function(_self, player, target)
			local ok, reason = allowed(player, target)
			if not ok then
				return false, reason
			end
			local previous = tracker:stop(player.UserId)
			local targetId = idFor(target)
			tracker:start(player.UserId, targetId)
			if previous ~= nil and previous ~= targetId then
				publish(previous)
			end
			publish(targetId)
			return true, nil
		end,

		stop = function(_self, player)
			local previous = tracker:stop(player.UserId)
			if previous ~= nil then
				publish(previous)
			end
		end,

		reset = function(_self, target)
			local targetId = idOf[target]
			if targetId == nil then
				return
			end
			tracker:reset(targetId)
			publish(targetId)
		end,

		step = function(_self, dt)
			for _, targetId in tracker:activeTargets() do
				local target: Instance? = targetById[targetId]
				for _, userId in tracker:channelers(targetId) do
					local player = Players:GetPlayerByUserId(userId)
					if player == nil or target == nil or not (allowed(player, target)) then
						tracker:stop(userId)
					end
				end
				local kind = if target ~= nil then kindOf(target) else nil
				local def = if kind ~= nil then InteractionRegistry.getChannel(kind) else nil
				if target == nil or kind == nil or def == nil or not target:IsDescendantOf(Workspace) then
					-- Destroyed or no longer a channel: forget it so the id map does not hold it.
					tracker:reset(targetId)
					targetById[targetId] = nil
					if target ~= nil then
						idOf[target] = nil
						target:SetAttribute(InteractionConstants.CHANNEL_PROGRESS_ATTRIBUTE, nil)
						target:SetAttribute(InteractionConstants.CHANNEL_COUNT_ATTRIBUTE, nil)
					end
					continue
				end
				local done = tracker:advance(targetId, dt, def.duration)
				publish(targetId)
				if done ~= nil then
					-- Completed: forget the target (its progress is reset and published as nil).
					targetById[targetId] = nil
					idOf[target] = nil
					local players: { Player } = {}
					for _, userId in done do
						local player = Players:GetPlayerByUserId(userId)
						if player ~= nil then
							table.insert(players, player)
						end
					end
					task.spawn(function()
						local ok, err = pcall(function()
							handlers[kind].onComplete(players, target)
						end)
						if not ok then
							log:error(`channel "{kind}" onComplete failed: {err}`)
						end
					end)
				end
			end
		end,
	}
	return system
end

return InteractionChannelSystem
