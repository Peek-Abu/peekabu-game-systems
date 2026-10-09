--!strict
--[=[
	DeathSpectateRules: who a dead player can watch, and cycling between them. Pure (the client feeds it
	the public-player map).

	@class DeathSpectateRules
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PublicPlayerTypes = require(ReplicatedStorage.Shared.Data.PublicPlayerTypes)

local DeathSpectateRules = {}

--[=[
	The userIds a viewer may spectate: every public player except the viewer whose `deadField` is not
	true and who passes `filter`, sorted.
]=]
function DeathSpectateRules.candidates(
	public: PublicPlayerTypes.PublicPlayerMap,
	viewerUserId: number,
	deadField: string,
	filter: ((userId: number) -> boolean)?
): { number }
	local list: { number } = {}
	for key, entry in public do
		local userId = tonumber(key)
		if userId ~= nil and userId ~= viewerUserId and entry[deadField] ~= true then
			if filter == nil or filter(userId) then
				table.insert(list, userId)
			end
		end
	end
	table.sort(list)
	return list
end

--[=[
	The next target: `direction` 1 / -1 moves (wrapping), 0 keeps the current one if it is still a
	candidate. Falls back to the first candidate; nil when there are none.
]=]
function DeathSpectateRules.step(candidates: { number }, current: number?, direction: number): number?
	if #candidates == 0 then
		return nil
	end
	local index = if current ~= nil then table.find(candidates, current) else nil
	if index == nil then
		return candidates[1]
	end
	local nextIndex = ((index - 1 + direction) % #candidates) + 1
	return candidates[nextIndex]
end

return DeathSpectateRules
