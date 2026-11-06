--!strict
--[=[
	TipRules: the "tips" account slice's shape (which tips the player has seen) and whether a tip shows now.

	@class TipRules
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PlayerDataTypes = require(ReplicatedStorage.Shared.Data.PlayerDataTypes)
local TipRegistry = require(ReplicatedStorage.Shared.Features.Tip.Data.TipRegistry)

local TipRules = {}

--[=[
	The data layer's validator for the "tips" slice: `seen` maps tip ids to true.
]=]
function TipRules.validate(value: PlayerDataTypes.Tips?): (boolean, string?)
	if value == nil or type(value) ~= "table" then
		return false, "tips must be a table"
	end
	local seen = value.seen
	if type(seen) ~= "table" then
		return false, "tips.seen must be a table"
	end
	for key, mark in seen do
		if type(key) ~= "string" then
			return false, "tips.seen keys must be strings"
		end
		if mark ~= true then
			return false, `tips.seen.{key} must be true`
		end
	end
	return true
end

--[=[
	A known tip shows once, and only while the player has tips on.
]=]
function TipRules.shouldShow(tips: PlayerDataTypes.Tips, id: string, enabled: boolean): boolean
	return enabled and TipRegistry.has(id) and tips.seen[id] ~= true
end

return TipRules
