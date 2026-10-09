--!strict
--[=[
	BadgeServiceServer: awarding Roblox badges by game key (design:
	docs/superpowers/specs/2026-10-09-small-services-design.md).

	`award(player, key)` returns at once and works in the background: a badge known owned is skipped;
	otherwise ownership is checked once (UserHasBadgeAsync) and the badge awarded (AwardBadgeAsync) with a
	few retries. One award per player and key is in flight at a time. `awarded(player, key)` fires on a new
	award. `has(player, key)` yields for a first check and then reads the cache.

	Spec-exempt shell (BadgeService, Players); the bookkeeping is the specced BadgeAwardTracker and the
	catalogue BadgeRegistry.

	@class BadgeServiceServer
]=]

local BadgeService = game:GetService("BadgeService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Observers = require(ReplicatedStorage.Packages.Observers)
local Logger = require(ReplicatedStorage.Shared.Core.Logger)
local SignalTyped = require(ReplicatedStorage.Shared.Core.SignalTyped)
local BadgeRegistry = require(ReplicatedStorage.Shared.Features.Badge.Data.BadgeRegistry)
local BadgeAwardTracker = require(ServerScriptService.Features.Badge.State.BadgeAwardTracker)

local ATTEMPTS = 3
local RETRY_SECONDS = 2

local log = Logger.new("BadgeServiceServer")
local tracker = BadgeAwardTracker.new()
local awarded: SignalTyped.Signal<Player, string> = SignalTyped.new()
local counters = { awarded = 0, failed = 0 }
local stoppers: { () -> () } = {}

-- Runs a BadgeService call with retries; nil when every attempt failed.
local function attempt(label: string, call: () -> boolean): boolean?
	for try = 1, ATTEMPTS do
		local ok, result = pcall(call)
		if ok then
			return result
		end
		log:warn(`{label} failed (attempt {try}): {result}`)
		if try < ATTEMPTS then
			task.wait(RETRY_SECONDS)
		end
	end
	return nil
end

local function checkOwned(player: Player, key: string, badgeId: number): boolean?
	local known = tracker:owned(player.UserId, key)
	if known ~= nil then
		return known
	end
	local owned = attempt(`UserHasBadgeAsync({key})`, function()
		return BadgeService:UserHasBadgeAsync(player.UserId, badgeId)
	end)
	if owned ~= nil then
		tracker:setOwned(player.UserId, key, owned)
	end
	return owned
end

export type BadgeServiceServer = {
	dependencies: { string },
	awarded: SignalTyped.Signal<Player, string>,
	start: (self: BadgeServiceServer) -> (),
	stop: (self: BadgeServiceServer) -> (),
	award: (self: BadgeServiceServer, player: Player, key: string) -> (),
	has: (self: BadgeServiceServer, player: Player, key: string) -> boolean,
	getState: (self: BadgeServiceServer) -> { [string]: any },
}

local BadgeServiceServer: BadgeServiceServer = {
	dependencies = {},
	awarded = awarded,

	start = function(_self)
		table.insert(
			stoppers,
			Observers.observePlayer(function(player: Player)
				return function()
					tracker:forget(player.UserId)
				end
			end)
		)
	end,

	stop = function(_self)
		for _, stop in stoppers do
			stop()
		end
		table.clear(stoppers)
	end,

	--[=[
		Awards a registered badge in the background (no-op when it is owned or already being awarded).
		Throws for an unregistered key.
	]=]
	award = function(_self, player, key)
		local def = BadgeRegistry.get(key)
		assert(def ~= nil, `badge "{key}" is not registered`)
		if tracker:owned(player.UserId, key) == true or not tracker:begin(player.UserId, key) then
			return
		end
		task.spawn(function()
			local owned = checkOwned(player, key, def.badgeId)
			if owned == false and player.Parent ~= nil then
				local done = attempt(`AwardBadgeAsync({key})`, function()
					return BadgeService:AwardBadgeAsync(player.UserId, def.badgeId)
				end)
				if done == true then
					tracker:setOwned(player.UserId, key, true)
					counters.awarded += 1
					awarded:Fire(player, key)
				else
					counters.failed += 1
				end
			end
			tracker:finish(player.UserId, key)
		end)
	end,

	--[=[
		Whether the player owns the badge (yields for the first check; false when it cannot be checked).
	]=]
	has = function(_self, player, key)
		local def = BadgeRegistry.get(key)
		assert(def ~= nil, `badge "{key}" is not registered`)
		return checkOwned(player, key, def.badgeId) == true
	end,

	getState = function(_self)
		return { badges = BadgeRegistry.keys(), counters = table.clone(counters) }
	end,
}

return BadgeServiceServer
