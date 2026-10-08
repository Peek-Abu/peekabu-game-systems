--!strict
--[=[
	CustomizationPublishSystem: decides WHEN a player's active look goes onto their public-slice entry (the entry every
	other client dresses that player's puppet from). Split out of CustomizationServiceServer, which builds one
	with its slice reads and calls `publish` after every validated appearance write.

	- `publish`: copy the active look into the entry with a bumped version (StateSyncPublicPlayerStore keeps the version
	  climbing for the server's lifetime). A no-op while no profile is loaded.
	- `onBodySpawn`: backfill missing defaults, then publish when something is new: the entry's first look (no
	  entry, or the version-0 vitals placeholder), a backfill that filled something, or a slot switch. A plain
	  respawn publishes nothing. "First look" is read from the ENTRY, never from local bookkeeping: a leave
	  removes the entry, and a rejoin to the same server must publish again (found in staging: rejoiners were
	  drawn bald and barefoot).
	- `onProfileLoaded`: the body can spawn before the profile loads (the client's Ready does not wait for data;
	  a same-server rejoin waits on the old session's lock), so the profile's arrival publishes while the entry is
	  still the placeholder. No entry yet means the coming spawn publishes.

	@class CustomizationPublishSystem
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local PlayerDataTypes = require(ReplicatedStorage.Shared.Data.PlayerDataTypes)
local StateSyncPublicPlayerStore = require(ServerScriptService.Features.StateSync.State.StateSyncPublicPlayerStore)

export type Deps = {
	appearance: (userId: number) -> PlayerDataTypes.Appearance?, -- the active look, nil while no profile
	fillDefaults: (userId: number) -> boolean, -- backfill missing defaults; true when something was filled
	activeSlot: (userId: number) -> number?,
}

export type Publisher = {
	deps: Deps,
	lastPublishedSlot: { [number]: number? }, -- the slot each user's last publish came from (slot switches)
}

local CustomizationPublishSystem = {}

function CustomizationPublishSystem.new(deps: Deps): Publisher
	return { deps = deps, lastPublishedSlot = {} }
end

local function hasPublishedLook(userId: number): boolean
	local entry = StateSyncPublicPlayerStore.get(userId)
	return entry ~= nil and entry.appearanceVersion > 0
end

--[=[
	@param publisher Publisher
	@param userId number
]=]
function CustomizationPublishSystem.publish(publisher: Publisher, userId: number)
	local appearance = publisher.deps.appearance(userId)
	if appearance == nil then
		return
	end
	StateSyncPublicPlayerStore.publish(userId, appearance)
	publisher.lastPublishedSlot[userId] = publisher.deps.activeSlot(userId)
end

--[=[
	@param publisher Publisher
	@param userId number
]=]
function CustomizationPublishSystem.onBodySpawn(publisher: Publisher, userId: number)
	local filled = publisher.deps.fillDefaults(userId)
	local activeSlot = publisher.deps.activeSlot(userId)
	local slotChanged = activeSlot ~= nil and activeSlot ~= publisher.lastPublishedSlot[userId]
	if not hasPublishedLook(userId) or filled or slotChanged then
		CustomizationPublishSystem.publish(publisher, userId)
	end
end

--[=[
	@param publisher Publisher
	@param userId number
]=]
function CustomizationPublishSystem.onProfileLoaded(publisher: Publisher, userId: number)
	if StateSyncPublicPlayerStore.get(userId) ~= nil and not hasPublishedLook(userId) then
		CustomizationPublishSystem.onBodySpawn(publisher, userId)
	end
end

--[=[
	TEST SEAM: forgets the slot bookkeeping.
	@param publisher Publisher
]=]
function CustomizationPublishSystem.reset(publisher: Publisher)
	table.clear(publisher.lastPublishedSlot)
end

return CustomizationPublishSystem
