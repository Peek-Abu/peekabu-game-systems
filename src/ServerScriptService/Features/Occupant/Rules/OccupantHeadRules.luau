--!strict
--[=[
	OccupantHeadRules: whom a freeze kind's head looks at (Bramble's owl head; the freeze variants note, variant B).
	Even while frozen its head turns to the kid it is after, so the crew can see who it comes for next.

	- The target is the brain's chase or search target when it has one, else the nearest crew member it saw or heard
	  (`noticed`); never a hidden one (`base`).
	- After `swapSeconds` (HEAD_SWAP_SECONDS, 10) of non-stop watching it swaps to another crew member: the nearest one
	  that is not hidden and not the one it looks at; alone, it keeps the same kid. The 10 s then start again. When the
	  watching stops it goes back to the base target and the clock resets.

	- The lunge: on the check the watching stops, the kid the head held (a swapped one too) is the one it goes for
	  (`lunge`; the brain's chase target, OccupantWatchRules.lunge), unless they hid, are knocked down or are gone.

	The server owns the choice (OccupantWatchSystem publishes it as a rig attribute); the client only turns the head.
	Pure: no function changes the head it is given.

	@class OccupantHeadRules
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local OccupantConstants = require(ReplicatedStorage.Shared.Features.Occupant.Data.OccupantConstants)

-- One crew member: where, whether hidden, and whether the monster saw or heard them lately.
export type Member = {
	userId: number,
	position: Vector3,
	hidden: boolean,
	noticed: boolean,
	-- Knocked down (Death): never lunged at.
	downed: boolean?,
}

export type Input = {
	-- The monster's position.
	position: Vector3,
	-- The brain's chase or search target (nil in any other mode).
	brainTarget: number?,
	crew: { Member },
	-- Whether it is watched (frozen) right now.
	watched: boolean,
	now: number,
	-- Non-stop watching before a swap (default HEAD_SWAP_SECONDS).
	swapSeconds: number?,
}

-- Whom it looks at, whom it swapped to (while the watching lasts), and since when the current 10 s count.
export type Head = {
	target: number?,
	swapped: number?,
	watchedSince: number?,
}

local OccupantHeadRules = {}

function OccupantHeadRules.newHead(): Head
	return {}
end

local function find(input: Input, userId: number?): Member?
	for _, member in input.crew do
		if member.userId == userId then
			return member
		end
	end
	return nil
end

local function visible(input: Input, userId: number?): boolean
	local member = find(input, userId)
	return member ~= nil and not member.hidden
end

-- The nearest crew member passing `keep` (by distance, then by UserId for a tie).
local function nearest(input: Input, keep: (Member) -> boolean): number?
	local best: Member? = nil
	local bestDistance = math.huge
	for _, member in input.crew do
		if keep(member) then
			local distance = (member.position - input.position).Magnitude
			if best == nil or distance < bestDistance or (distance == bestDistance and member.userId < best.userId) then
				best = member
				bestDistance = distance
			end
		end
	end
	return if best ~= nil then best.userId else nil
end

--[=[
	The target before any swap: the brain's target when it is a crew member who is not hidden, else the nearest
	noticed crew member who is not hidden.
]=]
function OccupantHeadRules.base(input: Input): number?
	local brainTarget = input.brainTarget
	if brainTarget ~= nil and visible(input, brainTarget) then
		return brainTarget
	end
	return nearest(input, function(member: Member): boolean
		return member.noticed and not member.hidden
	end)
end

--[=[
	Whom it swaps to from `current`: the nearest crew member who is not hidden and is not `current`; `current` itself
	when there is nobody else.
]=]
function OccupantHeadRules.swapFrom(current: number?, input: Input): number?
	local other = nearest(input, function(member: Member): boolean
		return not member.hidden and member.userId ~= current
	end)
	return other or current
end

--[=[
	The head after this check (see the class doc).
]=]
function OccupantHeadRules.advance(head: Head, input: Input): Head
	if not input.watched then
		return { target = OccupantHeadRules.base(input) }
	end
	local now = input.now
	local since = head.watchedSince or now
	local swapped = head.swapped
	if swapped ~= nil and not visible(input, swapped) then
		swapped = nil
	end
	local target = swapped or OccupantHeadRules.base(input)
	if now >= since + (input.swapSeconds or OccupantConstants.HEAD_SWAP_SECONDS) then
		target = OccupantHeadRules.swapFrom(target, input)
		swapped = target
		since = now
	end
	return { target = target, swapped = swapped, watchedSince = since }
end

--[=[
	Whom it lunges at as the watching stops: the target `before` held, when it was watched (`wasWatched`) and is not now,
	and that target is a crew member who is not hidden and not knocked down; else nil.
]=]
function OccupantHeadRules.lunge(before: Head, input: Input, wasWatched: boolean): number?
	if not wasWatched or input.watched then
		return nil
	end
	local member = find(input, before.target)
	if member == nil or member.hidden or member.downed == true then
		return nil
	end
	return member.userId
end

return OccupantHeadRules
