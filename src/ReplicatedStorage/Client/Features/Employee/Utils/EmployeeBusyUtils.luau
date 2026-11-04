--!strict
--[=[
	EmployeeBusyUtils: whether a character is too busy for an extra move (a sticker toss): knocked out, hiding,
	carrying, vacuuming or dead. The same public state the fidget and the emote props wait on (owner, 2026-11-03).

	- `busy(character)`: the character's knockdown, its player's hiding spot, and their public entry.
	- `entryBusy(entry)`: a public player entry (StateSyncClientStore) carrying, vacuuming or dead.

	@class EmployeeBusyUtils
]=]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CarryConstants = require(ReplicatedStorage.Shared.Features.Carry.Data.CarryConstants)
local DeathConstants = require(ReplicatedStorage.Shared.Features.Death.Data.DeathConstants)
local HideConstants = require(ReplicatedStorage.Shared.Features.Hide.Data.HideConstants)
local ShiftConstants = require(ReplicatedStorage.Shared.Features.Shift.Data.ShiftConstants)
local StateSyncClientStore = require(ReplicatedStorage.Client.Features.StateSync.State.StateSyncClientStore)
local StateSyncConstants = require(ReplicatedStorage.Shared.Features.StateSync.Data.StateSyncConstants)

local EmployeeBusyUtils = {}

function EmployeeBusyUtils.entryBusy(entry: { [string]: any }?): boolean
	return entry ~= nil
		and (
			entry[CarryConstants.PUBLIC_FIELD] ~= nil
			or entry[ShiftConstants.PUBLIC_VACUUMING] == true
			or entry[DeathConstants.PUBLIC_FIELD] == true
		)
end

function EmployeeBusyUtils.busy(character: Model): boolean
	if character:GetAttribute(DeathConstants.KNOCKDOWN_ATTRIBUTE) ~= nil then
		return true
	end
	local player = Players:GetPlayerFromCharacter(character)
	if player == nil then
		return false
	end
	if player:GetAttribute(HideConstants.PLAYER_SPOT_ATTRIBUTE) ~= nil then
		return true
	end
	return EmployeeBusyUtils.entryBusy(
		StateSyncClientStore.publicPlayers()[StateSyncConstants.publicEntryKey(player.UserId)]
	)
end

return EmployeeBusyUtils
