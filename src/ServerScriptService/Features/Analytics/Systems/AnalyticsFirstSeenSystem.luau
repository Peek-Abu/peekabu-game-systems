--!strict
--[=[
	AnalyticsFirstSeenSystem: the saved, server-only `firstSeen` account slice behind "new vs returning"
	analytics. When a profile loads, an unstamped account (`at == 0`) is stamped with the current time and
	the player is remembered as new for this session; any stamped account (including `BEFORE_TRACKING`,
	what the v3 migration writes on pre-tracking accounts) is returning.

	The slice registers at module load. AnalyticsServiceServer requires this module at the top, and
	ServerHandler requires every `*ServiceServer` before it inits PlayerDataServiceServer, so the slice is in
	the profile template in time. It is deliberately NOT in StateSyncSliceRegistry: clients never see it.

	@class AnalyticsFirstSeenSystem
]=]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Guard = require(ReplicatedStorage.Shared.Core.Guard)
local PlayerDataTypes = require(ReplicatedStorage.Shared.Data.PlayerDataTypes)
local PlayerDataService = require(ServerScriptService.Features.PlayerData.PlayerDataServiceServer)
local PlayerDataSliceSystem = require(ServerScriptService.Features.PlayerData.Systems.PlayerDataSliceSystem)

local BEFORE_TRACKING = 1

local newThisSession: { [number]: boolean } = {}
local stampedAt: { [number]: number } = {}

local function validate(value: PlayerDataTypes.FirstSeen?): (boolean, string?)
	if value == nil then
		return false, "firstSeen must be a table"
	end
	local at = value.at
	if type(at) ~= "number" then
		return false, "firstSeen.at must be a number"
	end
	if at ~= math.floor(at) or at < 0 then
		return false, `firstSeen.at must be a whole number >= 0, got {at}`
	end
	return true
end

local firstSeenSlice = PlayerDataSliceSystem.registerAccount("firstSeen", { at = 0 }, function(account)
	return account.firstSeen
end, validate)

local AnalyticsFirstSeenSystem = {
	BEFORE_TRACKING = BEFORE_TRACKING,
	validate = validate,
}

--[=[
	Unstamped (`at == 0`) is new and takes `now`; anything else keeps its stamp and is returning.
]=]
function AnalyticsFirstSeenSystem.decide(at: number, now: number): (boolean, number)
	if at == 0 then
		return true, now
	end
	return false, at
end

local function stamp(userId: number)
	local isNew = false
	local final = 0
	local ok = firstSeenSlice.mutate(userId, function(slice)
		isNew, final = AnalyticsFirstSeenSystem.decide(slice.at, os.time())
		if isNew then
			slice.at = final
			return true
		end
		return false
	end)
	if ok then
		newThisSession[userId] = isNew
		stampedAt[userId] = final
	end
end

--[=[
	Stamps players as their profiles load (and those already loaded now); forgets them on leave.
	Returns a stopper.
]=]
function AnalyticsFirstSeenSystem.start(): () -> ()
	local loaded = PlayerDataService.profileLoaded:Connect(function(userId: number)
		stamp(userId)
	end)
	local removing = Players.PlayerRemoving:Connect(function(player: Player)
		newThisSession[player.UserId] = nil
		stampedAt[player.UserId] = nil
	end)
	for _, player in Players:GetPlayers() do
		if firstSeenSlice.get(player.UserId) ~= nil then
			stamp(player.UserId)
		end
	end
	return function()
		loaded:Disconnect()
		removing:Disconnect()
	end
end

--[=[
	Whether the account was unstamped when this session's profile loaded; nil before then.
]=]
function AnalyticsFirstSeenSystem.isNew(userId: number): boolean?
	Guard.userId(userId)
	return newThisSession[userId]
end

--[=[
	The unix time the account was first seen; nil before this session's profile loaded.
]=]
function AnalyticsFirstSeenSystem.firstSeenAt(userId: number): number?
	Guard.userId(userId)
	return stampedAt[userId]
end

return AnalyticsFirstSeenSystem
