--!strict
--[=[
	OccupantFeedbackUtils: the decisions behind Mr. Harlow's voice and presence (Cleanup Crew spec §4 "Tells" and
	"Voice"). Which line he says for a cue (never the same twice running), which gibberish clip voices a line
	(a stable hash, so a line always sounds the same), whether a line is spoken at all ("*sigh*" is an action),
	how much of a line the typewriter shows, which sounds his mode changes make for this client (a "hm?" when he
	investigates, a sting when he spots someone, the chase music while he chases you, a sigh when he gives up),
	and how often his footsteps fall. Pure.

	@class OccupantFeedbackUtils
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CargoTypes = require(ReplicatedStorage.Shared.Features.Cargo.Data.CargoTypes)
local OccupantConstants = require(ReplicatedStorage.Shared.Features.Occupant.Data.OccupantConstants)

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
	How many of a line's `total` characters the typewriter shows `elapsed` seconds in at `rate` per second.
]=]
function OccupantFeedbackUtils.reveal(total: number, elapsed: number, rate: number): number
	if rate <= 0 then
		return total
	end
	return math.clamp(math.floor(elapsed * rate), 0, total)
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
	if afterMode ~= beforeMode then
		if afterMode == "investigate" then
			table.insert(list, "curious")
		elseif afterMode == "chase" then
			table.insert(list, "spotted")
		elseif afterMode == "patrol" and (beforeMode == "search" or beforeMode == "investigate") then
			table.insert(list, "giveUp")
		end
	end
	if isMine and not wasMine then
		table.insert(list, "chaseStart")
	elseif wasMine and not isMine then
		table.insert(list, "chaseEnd")
	end
	return list
end

--[=[
	Seconds between his footsteps at `speed` (studs/s); nil when he is (nearly) standing still.
]=]
function OccupantFeedbackUtils.footstepInterval(speed: number): number?
	if speed < OccupantConstants.STEP_MIN_SPEED then
		return nil
	end
	return math.clamp(OccupantConstants.STRIDE / speed, OccupantConstants.STEP_MIN, OccupantConstants.STEP_MAX)
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

-- The crew's toast when someone is caught (Figma 1f): "Alex was caught! Back in 0:08." The m:ss formatting is a
-- third copy (Shift's notices and the client's clock have theirs); Shared cannot require the client one.
function OccupantFeedbackUtils.caughtText(name: string, seconds: number): string
	local whole = math.max(0, math.ceil(seconds))
	return `{name} was caught! Back in {string.format("%d:%02d", whole // 60, whole % 60)}.`
end

return OccupantFeedbackUtils
