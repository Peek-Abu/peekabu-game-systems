--!strict
--[=[
	ReplicationViewCheck (R5 spec 2026-10-05 §1.2): checks that what this client SHOWS matches what the server
	says it should see. Pure — the caller builds a Snapshot (ReplicationDiagnosticsSystem) and passes the time.

	Every condition here is a bug, never a state to heal: a body in view with no placed puppet past its
	allowance, a player with no slot-table entry, an orphaned or duplicated puppet, a remote `Character`
	that disagrees with the registry. A condition becomes an EPISODE once it has held past the allowance for
	its reason; the episode ends when the condition clears. Callers log one line per start and per end.

	A reason change restarts the allowance (no Player → not dressed is a new wait, not a continuation).
	`unknownPlayer` counts from the first check that saw the player; a player who leaves is forgotten, so a
	rejoin starts fresh.

	@class ReplicationViewCheck
]=]

local ReplicationViewCheck = {}

export type Check = "missing" | "unknownPlayer" | "orphan" | "duplicate" | "characterMismatch"

export type BodyView = {
	slot: number,
	userId: number,
	generation: number,
	epoch: number,
	held: boolean,
	placed: boolean,
	dressed: boolean,
	bufferEmpty: boolean,
	playerPresent: boolean,
}

export type HeldView = { slot: number, ownerUserId: number }

export type CharacterView = { userId: number, matches: boolean }

export type Snapshot = {
	otherUserIds: { number },
	knownUserIds: { [number]: boolean },
	bodies: { BodyView }, -- visible bodies only
	held: { HeldView },
	characters: { CharacterView },
}

export type Episode = {
	check: Check,
	key: string,
	reason: string,
	detail: string,
	startedAt: number,
	endedAt: number?,
}

type Pending = { check: Check, reason: string, detail: string, since: number }

export type Tripwire = {
	pending: { [string]: Pending },
	open: { [string]: Episode },
	firstSeen: { [number]: number },
	counts: { [string]: number },
	checks: number,
}

-- Seconds a condition may hold before it is an episode, by reason.
local ALLOWANCE: { [string]: number } = {
	noPlayer = 3, -- the Player object has not replicated to this client yet
	notHeld = 0.5, -- the pool has not given it a puppet (it builds one per frame)
	undressed = 1.5, -- the dressed rule parks it; the default look lands after 1 s
	emptyBuffer = 2, -- just respawned: hidden until the first new-epoch sample
	notPlaced = 0.5,
	noSlotEntry = 3,
	noBody = 0.5,
	ownerMismatch = 0.5,
	twoPuppets = 0,
	characterMismatch = 0.5,
}
ReplicationViewCheck.ALLOWANCE = ALLOWANCE

--[=[
	@return Tripwire
]=]
function ReplicationViewCheck.new(): Tripwire
	return { pending = {}, open = {}, firstSeen = {}, counts = {}, checks = 0 }
end

local function missingReason(body: BodyView): string?
	if not body.playerPresent then
		return "noPlayer"
	elseif not body.held then
		return "notHeld"
	elseif not body.dressed then
		return "undressed"
	elseif body.bufferEmpty then
		return "emptyBuffer"
	elseif not body.placed then
		return "notPlaced"
	end
	return nil
end

--[=[
	Runs every check against `snapshot` at `now` (seconds, any monotonic clock).
	@return { Episode } -- episodes that started this check
	@return { Episode } -- episodes that ended this check (with `endedAt`)
]=]
function ReplicationViewCheck.check(tripwire: Tripwire, snapshot: Snapshot, now: number): ({ Episode }, { Episode })
	tripwire.checks += 1
	local seen: { [string]: Pending } = {}
	local function hold(check: Check, key: string, reason: string, detail: string, since: number?)
		local fullKey = `{check}:{key}`
		local previous = tripwire.pending[fullKey]
		local start = if previous ~= nil and previous.reason == reason then previous.since else (since or now)
		seen[fullKey] = { check = check, reason = reason, detail = detail, since = start }
	end

	local bodyBySlot: { [number]: BodyView } = {}
	for _, body in snapshot.bodies do
		bodyBySlot[body.slot] = body
		local reason = missingReason(body)
		if reason ~= nil then
			hold(
				"missing",
				tostring(body.slot),
				reason,
				`slot {body.slot} user {body.userId} gen {body.generation} epoch {body.epoch}`
			)
		end
	end

	local present: { [number]: boolean } = {}
	for _, userId in snapshot.otherUserIds do
		present[userId] = true
		local first = tripwire.firstSeen[userId]
		if first == nil then
			first = now
			tripwire.firstSeen[userId] = now
		end
		if not snapshot.knownUserIds[userId] then
			hold("unknownPlayer", tostring(userId), "noSlotEntry", `user {userId}`, first)
		end
	end
	for userId in tripwire.firstSeen do
		if not present[userId] then
			tripwire.firstSeen[userId] = nil
		end
	end

	local slotsByOwner: { [number]: { number } } = {}
	for _, entry in snapshot.held do
		local body = bodyBySlot[entry.slot]
		if body == nil then
			hold("orphan", tostring(entry.slot), "noBody", `slot {entry.slot} owner {entry.ownerUserId}`)
		elseif body.userId ~= entry.ownerUserId then
			hold(
				"orphan",
				tostring(entry.slot),
				"ownerMismatch",
				`slot {entry.slot} owner {entry.ownerUserId} body user {body.userId}`
			)
		end
		local slots = slotsByOwner[entry.ownerUserId] or {}
		table.insert(slots, entry.slot)
		slotsByOwner[entry.ownerUserId] = slots
	end
	for owner, slots in slotsByOwner do
		if #slots > 1 then
			table.sort(slots)
			hold("duplicate", tostring(owner), "twoPuppets", `user {owner} slots {table.concat(slots, ",")}`)
		end
	end

	for _, character in snapshot.characters do
		if not character.matches then
			hold("characterMismatch", tostring(character.userId), "characterMismatch", `user {character.userId}`)
		end
	end

	local started: { Episode } = {}
	local ended: { Episode } = {}
	for key, pending in seen do
		if tripwire.open[key] == nil and now - pending.since >= (ALLOWANCE[pending.reason] or 0) then
			local episode: Episode = {
				check = pending.check,
				key = key,
				reason = pending.reason,
				detail = pending.detail,
				startedAt = pending.since,
				endedAt = nil,
			}
			tripwire.open[key] = episode
			tripwire.counts[pending.check] = (tripwire.counts[pending.check] or 0) + 1
			table.insert(started, episode)
		end
	end
	for key, episode in tripwire.open do
		if seen[key] == nil then
			tripwire.open[key] = nil
			episode.endedAt = now
			table.insert(ended, episode)
		end
	end
	tripwire.pending = seen
	return started, ended
end

--[=[
	One log line: check, reason, detail, and the duration once it has ended.
	@param episode Episode
	@return string
]=]
function ReplicationViewCheck.describe(episode: Episode): string
	local endedAt = episode.endedAt
	local duration = if endedAt ~= nil then string.format(" · lasted %.1f s", endedAt - episode.startedAt) else ""
	return `{episode.check} ({episode.reason}) {episode.detail}{duration}`
end

--[=[
	For F4: how many checks ran, episodes per check so far, and the open episodes.
	@param tripwire Tripwire
]=]
function ReplicationViewCheck.getState(
	tripwire: Tripwire
): { checks: number, counts: { [string]: number }, open: { string } }
	local open: { string } = {}
	for _, episode in tripwire.open do
		table.insert(open, ReplicationViewCheck.describe(episode))
	end
	table.sort(open)
	return { checks = tripwire.checks, counts = table.clone(tripwire.counts), open = open }
end

return ReplicationViewCheck
