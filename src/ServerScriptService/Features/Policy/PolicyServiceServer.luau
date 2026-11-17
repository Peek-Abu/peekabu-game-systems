--!strict
--[=[
	PolicyServiceServer: per-player Roblox PolicyService lookup, cached for the session, fail-closed on
	`ArePaidRandomItemsRestricted` (design: docs/superpowers/specs/2026-10-25-odd-hours-lockers-design.md).

	If `PolicyService:GetPolicyInfoForPlayerAsync` throws or omits the boolean flag, the player is treated as
	restricted (`true`) so a paid random Locker can never open when policy state is unknown.

	Studio only: the Workspace attribute `DevPaidRandomRestricted` (true / false) plays a player from a country that
	restricts paid random items (or one that does not) over what PolicyService says, so the Shop and Lockers can be
	checked as such a player. Changing it during Play fires `devChanged` (the Locker re-sends every player's flag).
	Ignored outside Studio.

	@class PolicyServiceServer
]=]

local Players = game:GetService("Players")
local PolicyService = game:GetService("PolicyService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Janitor = require(ReplicatedStorage.Packages.Janitor)
local Logger = require(ReplicatedStorage.Shared.Core.Logger)
local SignalTyped = require(ReplicatedStorage.Shared.Core.SignalTyped)

export type Fetcher = (player: Player) -> { [string]: unknown }

local log = Logger.new("PolicyServiceServer")
local janitor = Janitor.new()

local function defaultFetcher(player: Player): { [string]: unknown }
	return PolicyService:GetPolicyInfoForPlayerAsync(player)
end

local DEV_RESTRICTED_ATTRIBUTE = "DevPaidRandomRestricted"

local fetcher: Fetcher = defaultFetcher
-- nil: ask RunService (the test seam sets true / false).
local studioOverride: boolean? = nil
local devChanged: SignalTyped.Signal<> = SignalTyped.new()
local cache: { [number]: boolean } = {}
local overrides: { [number]: boolean } = {}

local function isStudio(): boolean
	if studioOverride ~= nil then
		return studioOverride
	end
	return RunService:IsStudio()
end

-- The Studio switch's value, or nil when unset, not a boolean, or outside Studio.
local function devSwitch(): boolean?
	if not isStudio() then
		return nil
	end
	local value = workspace:GetAttribute(DEV_RESTRICTED_ATTRIBUTE)
	return if type(value) == "boolean" then value else nil
end

local function checkImpl(player: Player): boolean
	local forced = overrides[player.UserId]
	if forced ~= nil then
		return forced
	end
	local dev = devSwitch()
	if dev ~= nil then
		return dev
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
	-- The Studio-only Workspace switch (see the class doc).
	DEV_RESTRICTED_ATTRIBUTE: string,
	-- Fires when the Studio switch changes during Play.
	devChanged: SignalTyped.Signal<>,
	init: (self: PolicyServiceServer) -> (),
	stop: (self: PolicyServiceServer) -> (),
	paidRandomItemsRestricted: (self: PolicyServiceServer, player: Player) -> boolean,
	setRestricted: (self: PolicyServiceServer, userId: number, restricted: boolean?) -> (),
	getState: (self: PolicyServiceServer) -> { [string]: any },
	-- TEST SEAM: replace the PolicyService fetcher (nil restores the real one) and clear the session cache.
	_setFetcher: (replacement: Fetcher?) -> (),
	-- TEST SEAM: force the Studio check (nil restores RunService:IsStudio()).
	_setStudio: (value: boolean?) -> (),
}

local PolicyServiceServer: PolicyServiceServer = {
	dependencies = {},
	DEV_RESTRICTED_ATTRIBUTE = DEV_RESTRICTED_ATTRIBUTE,
	devChanged = devChanged,

	init = function(_self)
		if isStudio() then
			janitor:Add(
				workspace:GetAttributeChangedSignal(DEV_RESTRICTED_ATTRIBUTE):Connect(function()
					log:info(`{DEV_RESTRICTED_ATTRIBUTE} = {tostring(devSwitch())} (Studio)`)
					devChanged:Fire()
				end),
				"Disconnect"
			)
		end
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

	_setStudio = function(value)
		studioOverride = value
	end,
}

return PolicyServiceServer
