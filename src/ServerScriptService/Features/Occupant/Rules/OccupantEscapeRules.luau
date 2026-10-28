--!strict
--[=[
	OccupantEscapeRules: who the Manager stopped tracking in one think. A player he chased (`target`) or stared down in
	a hiding spot (`quarry`) is lost once neither field names them any more. A chase that turns into a stare at their
	spot keeps them (target → quarry). OccupantServiceServer fires `escaped` for a lost player still hidden after the
	think's effects (a catch evicts them first), which is the Hide and Squeak badge. Pure.

	@class OccupantEscapeRules
]=]

-- The two mind fields this reads (OccupantTypes.Mind).
export type Tracking = { target: number?, quarry: number? }

local OccupantEscapeRules = {}

local function tracks(mind: Tracking, userId: number): boolean
	return mind.target == userId or mind.quarry == userId
end

-- The userIds tracked in `before` and no longer in `after`, each once.
function OccupantEscapeRules.lost(before: Tracking, after: Tracking): { number }
	local lost: { number } = {}
	for _, userId in { before.target, before.quarry } do
		if userId ~= nil and not tracks(after, userId) and table.find(lost, userId) == nil then
			table.insert(lost, userId)
		end
	end
	return lost
end

return OccupantEscapeRules
