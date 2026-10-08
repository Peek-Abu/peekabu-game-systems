--!strict
--[=[
	ReplicationVisibilityTracker: which bodies a viewer has loaded (spec §6.5, C6: distance only in this phase; plan R2
	Task 5).

	A body enters within 600 studs and leaves past 630: the 30-stud hysteresis keeps a viewer walking along
	the edge from flapping (each flap is a reliable enter/leave message and a public-slice change). The set
	doubles as the viewer's relevant set for public data, so it changes ONLY on enter/leave — movement
	inside the set never touches it. Squared distances; a NaN position never changes membership.

	Pure.

	@class ReplicationVisibilityTracker
]=]

local ReplicationVisibilityTracker = {}

local RELEVANT_STUDS = 600
local RELEASE_STUDS = 630
local RELEVANT_SQUARED = RELEVANT_STUDS * RELEVANT_STUDS
local RELEASE_SQUARED = RELEASE_STUDS * RELEASE_STUDS

ReplicationVisibilityTracker.RELEVANT_STUDS = RELEVANT_STUDS
ReplicationVisibilityTracker.RELEASE_STUDS = RELEASE_STUDS

export type Set = {
	members: { [number]: boolean }, -- by slot
	count: number,
}

export type Change = "entered" | "left"

function ReplicationVisibilityTracker.new(): Set
	return { members = {}, count = 0 }
end

function ReplicationVisibilityTracker.update(set: Set, viewer: Vector3, slot: number, position: Vector3): Change?
	local offset = position - viewer
	local squared = offset:Dot(offset)
	if set.members[slot] then
		if squared > RELEASE_SQUARED then
			set.members[slot] = nil
			set.count -= 1
			return "left"
		end
	elseif squared <= RELEVANT_SQUARED then
		set.members[slot] = true
		set.count += 1
		return "entered"
	end
	return nil
end

function ReplicationVisibilityTracker.remove(set: Set, slot: number): boolean
	if set.members[slot] then
		set.members[slot] = nil
		set.count -= 1
		return true
	end
	return false
end

function ReplicationVisibilityTracker.has(set: Set, slot: number): boolean
	return set.members[slot] == true
end

return ReplicationVisibilityTracker
