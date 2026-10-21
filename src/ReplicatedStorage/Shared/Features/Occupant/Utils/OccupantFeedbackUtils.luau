--!strict
--[=[
	OccupantFeedbackUtils: the decisions behind Mr. Harlow's voice and presence (Cleanup Crew spec §4 "Tells" and
	"Voice"). Which line he says for a cue (never the same twice running), which gibberish clip voices a line
	(a stable hash, so a line always sounds the same), whether a line is spoken at all ("*sigh*" is an action),
	which sounds his mode changes make for this client (a "hm?" when he
	investigates, a sting when he spots someone, the chase bed while he chases you, a sigh when he gives up;
	his footsteps are the Footstep feature's). Every chase on you starts with the sting, however it starts
	(2026-10-16: a chase switched from a crewmate onto you used to start silently). Pure.

	@class OccupantFeedbackUtils
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CargoTypes = require(ReplicatedStorage.Shared.Features.Cargo.Data.CargoTypes)

export type PresenceCue = "curious" | "spotted" | "giveUp" | "chaseStart" | "chaseEnd"

local OccupantFeedbackUtils = {}

--[=[
	A line from `lines` by `roll` (0..1), skipping `last` when there is another; nil for no lines.
]=]
function OccupantFeedbackUtils.pickLine(lines: { string }, roll: number, last: string?): string?
	if #lines == 0 then
		return nil
	end
	local pool: { string } = {}
	for _, line in lines do
		if line ~= last then
			table.insert(pool, line)
		end
	end
	if #pool == 0 then
		pool = lines
	end
	local index = math.clamp(math.floor(math.clamp(roll, 0, 1) * #pool) + 1, 1, #pool)
	return pool[index]
end

--[=[
	Which of `count` gibberish clips voices `line` (1..count, the same every time); nil when count < 1.
]=]
function OccupantFeedbackUtils.clipFor(line: string, count: number): number?
	if count < 1 then
		return nil
	end
	local hash = 0
	for index = 1, #line do
		hash = (hash * 31 + string.byte(line, index)) % 1000003
	end
	return hash % count + 1
end

--[=[
	Whether a line is spoken: words are, an *action* in asterisks is not, nor an empty bubble.
]=]
function OccupantFeedbackUtils.voiced(line: string): boolean
	if line == "" then
		return false
	end
	return not (string.sub(line, 1, 1) == "*" and string.sub(line, -1) == "*")
end

--[=[
	The sounds one change of his mode makes for this client. `wasMine` / `isMine`: he was / is chasing you.
]=]
function OccupantFeedbackUtils.cues(
	beforeMode: string?,
	afterMode: string?,
	wasMine: boolean,
	isMine: boolean
): { PresenceCue }
	local list: { PresenceCue } = {}
	local changed = afterMode ~= beforeMode
	-- A chase starting on you always stings, even when he was already chasing someone else.
	local onYou = isMine and not wasMine
	if afterMode == "chase" and (changed or onYou) then
		table.insert(list, "spotted")
	elseif changed and afterMode == "investigate" then
		table.insert(list, "curious")
	elseif changed and afterMode == "patrol" and (beforeMode == "search" or beforeMode == "investigate") then
		table.insert(list, "giveUp")
	end
	if onYou then
		table.insert(list, "chaseStart")
	elseif wasMine and not isMine then
		table.insert(list, "chaseEnd")
	end
	return list
end

--[=[
	The names of what a caught player dropped: the hands item, then the pockets; empty hands and unknown kinds skipped.
]=]
function OccupantFeedbackUtils.droppedNames(
	hands: string?,
	pockets: { string },
	lookup: (kind: string) -> CargoTypes.ItemDef?
): { string }
	local names: { string } = {}
	local function add(kind: string?)
		local def = if kind ~= nil then lookup(kind) else nil
		if def ~= nil then
			table.insert(names, def.name)
		end
	end
	add(hands)
	for _, kind in pockets do
		add(kind)
	end
	return names
end

-- The crew's toast when a catch leaves someone a life (a hit: knocked down, up again in a moment, so there is no
-- "back in" time): "Alex got caught!".
function OccupantFeedbackUtils.hitText(name: string): string
	return `{name} got caught!`
end

-- The crew's toast when someone's last life is spent: "Alex is out for the shift".
function OccupantFeedbackUtils.outText(name: string): string
	return `{name} is out for the shift`
end

return OccupantFeedbackUtils
