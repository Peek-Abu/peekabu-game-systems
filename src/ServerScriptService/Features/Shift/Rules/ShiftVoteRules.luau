--!strict
--[=[
	ShiftVoteRules: the results vote (spec §3 step 7): Another shift or Back to depot. Only players still in
	the server count. A strict majority decides at once; otherwise the vote waits until everyone has voted or
	the time is up, then the larger side wins and a tie (or no votes at all) keeps working: another shift.
	Pure.

	@class ShiftVoteRules
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ShiftTypes = require(ReplicatedStorage.Shared.Features.Shift.Data.ShiftTypes)

type Vote = ShiftTypes.Vote

local ShiftVoteRules = {}

-- A vote from the wire, or nil when it is not one of the two choices.
function ShiftVoteRules.parse(value: unknown): Vote?
	if value == "another" then
		return "another"
	elseif value == "depot" then
		return "depot"
	end
	return nil
end

-- Votes for each side among `present` (UserIds still in the server).
function ShiftVoteRules.tally(votes: { [number]: Vote }, present: { number }): (number, number)
	local another = 0
	local depot = 0
	for _, userId in present do
		local vote = votes[userId]
		if vote == "another" then
			another += 1
		elseif vote == "depot" then
			depot += 1
		end
	end
	return another, depot
end

-- The decision, or nil while the vote is still open.
function ShiftVoteRules.decide(votes: { [number]: Vote }, present: { number }, timedOut: boolean): Vote?
	local another, depot = ShiftVoteRules.tally(votes, present)
	if another * 2 > #present then
		return "another"
	end
	if depot * 2 > #present then
		return "depot"
	end
	local everyone = #present > 0 and another + depot >= #present
	if not everyone and not timedOut then
		return nil
	end
	return if depot > another then "depot" else "another"
end

return ShiftVoteRules
