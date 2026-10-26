--!strict
--[=[
	PolicyServiceServer: per-player Roblox PolicyService lookup, cached for the session, fail-closed on
	`ArePaidRandomItemsRestricted` (design: docs/superpowers/specs/2026-10-25-odd-hours-lockers-design.md).

	If `PolicyService:GetPolicyInfoForPlayerAsync` throws or omits the boolean flag, the player is treated as
	restricted (`true`) so a paid random Locker can never open when policy state is unknown.

	@class PolicyServiceServer
]=]

local Players = game:GetService("Players")
local PolicyService = game:GetService("PolicyService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Janitor = require(ReplicatedStorage.Packages.Janitor)
local Logger = require(ReplicatedStorage.Shared.Core.Logger)

export type Fetcher = (player: Player) -> { [string]: unknown }

local log = Logger.new("PolicyServiceServer")
local janitor = Janitor.new()

local function defaultFetcher(player: Player): { [string]: unknown }
	return PolicyService:GetPolicyInfoForPlayerAsync(player)
end

local fetcher: Fetcher = defaultFetcher
local cache: { [number]: boolean } = {}
local overrides: { [number]: boolean } = {}

local function checkImpl(player: Player): boolean
	local forced = overrides[player.UserId]
	if forced ~= nil then
		return forced
	end
	local cached = cache[player.UserId]
	if cached ~= nil then
		return cached
	end
	local ok, info = pcall(fetcher, player)
	if not ok or type(info) ~= "table" then
		log:warn(`GetPolicyInfoForPlayerAsync failed for {player.Name}; failing closed (restricted)`)
		return true
	end
	local flag = info.ArePaidRandomItemsRestricted
	if type(flag) ~= "boolean" then
		log:warn(`ArePaidRandomItemsRestricted missing for {player.Name}; failing closed (restricted)`)
		return true
	end
	cache[player.UserId] = flag
	return flag
end

export type PolicyServiceServer = {
	dependencies: { string },
	init: (self: PolicyServiceServer) -> (),
	stop: (self: PolicyServiceServer) -> (),
	paidRandomItemsRestricted: (self: PolicyServiceServer, player: Player) -> boolean,
	setRestricted: (self: PolicyServiceServer, userId: number, restricted: boolean?) -> (),
	getState: (self: PolicyServiceServer) -> { [string]: any },
	-- TEST SEAM: replace the PolicyService fetcher (nil restores the real one) and clear the session cache.
	_setFetcher: (replacement: Fetcher?) -> (),
}

local PolicyServiceServer: PolicyServiceServer = {
	dependencies = {},

	init = function(_self)
		janitor:Add(
			Players.PlayerRemoving:Connect(function(player: Player)
				cache[player.UserId] = nil
				overrides[player.UserId] = nil
			end),
			"Disconnect"
		)
	end,

	stop = function(_self)
		janitor:Cleanup()
		table.clear(cache)
		table.clear(overrides)
	end,

	paidRandomItemsRestricted = function(_self, player)
		return checkImpl(player)
	end,

	setRestricted = function(_self, userId, restricted)
		if restricted == nil then
			overrides[userId] = nil
		else
			overrides[userId] = restricted
		end
	end,

	getState = function(_self)
		local cachedCount = 0
		for _ in cache do
			cachedCount += 1
		end
		return { cached = cachedCount }
	end,

	_setFetcher = function(replacement)
		fetcher = replacement or defaultFetcher
		table.clear(cache)
		table.clear(overrides)
	end,
}

return PolicyServiceServer
