--!strict
--[=[
	ReplicationSlotTracker: the replication slot table's identities and the body epoch (spec §6.2, §6.7; plan
	R2 Task 5).

	A slot (1–127, 7 bits on the wire) names a body in every record. A slot is an identity only together
	with its GENERATION (2 bits on the wire): releasing a slot bumps it, so a leaver's late records never
	land on the next owner's body and a viewer rebuilds instead of inheriting (spike CP10 lesson).

	The EPOCH (8 bits; 3 on the wire) is server-owned and bumped on every spawn — join, respawn, slot
	switch. Bumps are at least 250 ms apart; a bump inside that window is refused (the body is already
	fresh).

	Pure.

	@class ReplicationSlotTracker
]=]

local ReplicationSlotTracker = {}

local MAX_SLOT = 127
local EPOCH_SPACING_MS = 250

ReplicationSlotTracker.MAX_SLOT = MAX_SLOT
ReplicationSlotTracker.EPOCH_SPACING_MS = EPOCH_SPACING_MS

export type Slots = {
	used: { [number]: boolean },
	generations: { [number]: number },
}

export type Epoch = {
	value: number,
	lastBumpMs: number,
}

function ReplicationSlotTracker.new(): Slots
	return { used = {}, generations = {} }
end

function ReplicationSlotTracker.claim(slots: Slots): number?
	for slot = 1, MAX_SLOT do
		if not slots.used[slot] then
			slots.used[slot] = true
			return slot
		end
	end
	return nil
end

function ReplicationSlotTracker.release(slots: Slots, slot: number)
	if not slots.used[slot] then
		return
	end
	slots.used[slot] = nil
	slots.generations[slot] = ((slots.generations[slot] or 0) + 1) % 4
end

function ReplicationSlotTracker.generationOf(slots: Slots, slot: number): number
	return slots.generations[slot] or 0
end

function ReplicationSlotTracker.count(slots: Slots): number
	local count = 0
	for _ in slots.used do
		count += 1
	end
	return count
end

function ReplicationSlotTracker.newEpoch(): Epoch
	return { value = 0, lastBumpMs = -math.huge }
end

--[=[
	Bump the body epoch at `nowMs`. False (and unchanged) within 250 ms of the previous bump.
]=]
function ReplicationSlotTracker.bumpEpoch(epoch: Epoch, nowMs: number): boolean
	if nowMs - epoch.lastBumpMs < EPOCH_SPACING_MS then
		return false
	end
	epoch.value = (epoch.value + 1) % 256
	epoch.lastBumpMs = nowMs
	return true
end

return ReplicationSlotTracker
