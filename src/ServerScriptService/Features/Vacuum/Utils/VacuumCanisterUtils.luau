--!strict
--[=[
	VacuumCanisterUtils: the canister's maths (Cleanup Crew spec §4): each cleared pile adds one; the pile
	that fills it pops a dust bag and empties it. When several players finish a pile together, the channeler
	with the emptiest canister is credited (ties: the lowest UserId). Pure.

	@class VacuumCanisterUtils
]=]

local VacuumCanisterUtils = {}

--[=[
	The fill after one more pile, and whether that pile popped a dust bag (the fill is then 0).
]=]
function VacuumCanisterUtils.add(fill: number, capacity: number): (number, boolean)
	local nextFill = fill + 1
	if nextFill >= capacity then
		return 0, true
	end
	return nextFill, false
end

--[=[
	Which of the players who finished a pile gets it in their canister; nil when none.
]=]
function VacuumCanisterUtils.creditFor(userIds: { number }, fillOf: (userId: number) -> number): number?
	local best: number? = nil
	local bestFill = math.huge
	for _, userId in userIds do
		local fill = fillOf(userId)
		if fill < bestFill or (fill == bestFill and best ~= nil and userId < best) then
			best = userId
			bestFill = fill
		end
	end
	return best
end

return VacuumCanisterUtils
