--!strict
--[=[
	AnalyticsFirstSeenSystem: the saved, server-only `firstSeen` account slice behind "new vs returning"
	analytics. When a profile loads, an unstamped account (`at == 0`) is stamped with the current time and
	the player is remembered as new for this session; any stamped account is returning. There is no migration:
	the profile's Reconcile backfills `{ at = 0 }` into every existing profile, so an account that last played
	before this shipped reads as new once (its first session after the update), then keeps its stamp.

	The slice registers at module load. AnalyticsServiceServer requires this module at the top, and
	ServerHandler requires every `*ServiceServer` before it inits PlayerDataServiceServer, so the slice is in
	the profile template in time. It is deliberately NOT in StateSyncSliceRegistry: clients never see it.

	@class AnalyticsFirstSeenSystem
]=]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Logger = require(ReplicatedStorage.Shared.Core.Logger)
local Guard = require(ReplicatedStorage.Shared.Core.Guard)
local PlayerDataTypes = require(ReplicatedStorage.Shared.Data.PlayerDataTypes)
local PlayerDataService = require(ServerScriptService.Features.PlayerData.PlayerDataServiceServer)
local PlayerDataSliceSystem = require(ServerScriptService.Features.PlayerData.Systems.PlayerDataSliceSystem)

local log = Logger.new("AnalyticsFirstSeenSystem")

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

-- mutate() returns false both for "the mutator changed nothing" (a returning player) and for a refused
-- write (PlayerDataServiceServer.luau:697-806), so `ran` tells them apart: a returning player is recorded
-- even though mutate() returns false; a new player is recorded only when the write was accepted.
local function stamp(userId: number)
	local ran = false
	local isNew = false
	local final = 0
	local ok = firstSeenSlice.mutate(userId, function(slice)
		ran = true
		isNew, final = AnalyticsFirstSeenSystem.decide(slice.at, os.time())
		if isNew then
			slice.at = final
			return true
		end
		return false
	end)
	if ran and (ok or not isNew) then
		newThisSession[userId] = isNew
		stampedAt[userId] = final
	else
		log:warn(`firstSeen stamp for userId {userId} was not written; the player stays unknown this session`)
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
