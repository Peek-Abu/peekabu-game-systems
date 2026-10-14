--!strict
--[=[
	RankFormulas: the company rank's maths (Cleanup Crew "Clearance Level"). Pure, shared so the server's award and the
	results card's breakdown are the same numbers.

	- `levelFor` / `progress`: where an XP total sits on RankRegistry's ladder.
	- `entriesOf`: the crew lines of a published review (ShiftTypes.ShiftResults) as RankTypes.CrewEntry.
	- `factsFor`: one player's shift, from the crew's entries, whether the quota was met and the crew still present at
	  the end.
	- `award`: the XP lines for those facts (RankConstants.XP).

	"Extracted" means still with the crew when the shift ended and never caught by the Manager; a caught player gets no
	extraction bonus (nor the whole-crew one) and an incident report line instead.

	@class RankFormulas
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RankConstants = require(ReplicatedStorage.Shared.Features.Rank.Data.RankConstants)
local RankRegistry = require(ReplicatedStorage.Shared.Features.Rank.Data.RankRegistry)
local RankTypes = require(ReplicatedStorage.Shared.Features.Rank.Data.RankTypes)
local ShiftTypes = require(ReplicatedStorage.Shared.Features.Shift.Data.ShiftTypes)

type CrewEntry = RankTypes.CrewEntry

type Level = RankTypes.Level
type ShiftFacts = RankTypes.ShiftFacts

local RankFormulas = {}

-- The highest level `xp` reaches.
function RankFormulas.levelFor(xp: number): Level
	local reached = RankRegistry.get(1)
	assert(reached ~= nil, "RankFormulas: the ladder has no level 1")
	for _, level in RankRegistry.all() do
		if xp >= level.xp then
			reached = level
		end
	end
	return reached
end

function RankFormulas.progress(xp: number): RankTypes.Progress
	local level = RankFormulas.levelFor(xp)
	local nextLevel = RankRegistry.get(level.level + 1)
	if nextLevel == nil then
		return { level = level, next = nil, xp = xp, into = xp - level.xp, span = 0, fill = 1 }
	end
	local span = nextLevel.xp - level.xp
	local into = xp - level.xp
	return {
		level = level,
		next = nextLevel,
		xp = xp,
		into = into,
		span = span,
		fill = math.clamp(into / span, 0, 1),
	}
end

-- A published review's crew lines as crew entries (absent counts read 0).
function RankFormulas.entriesOf(results: ShiftTypes.ShiftResults): { CrewEntry }
	local entries: { CrewEntry } = {}
	for _, line in results.crew do
		table.insert(entries, {
			userId = line.userId,
			caught = line.caught,
			items = line.items or 0,
			overtimeSalvage = line.overtimeSalvage or 0,
		})
	end
	return entries
end

-- `userId`'s shift facts, or nil when they are not in `crew`. `present`: the crew still there at the end.
function RankFormulas.factsFor(crew: { CrewEntry }, quotaMet: boolean, present: { number }, userId: number): ShiftFacts?
	local mine: CrewEntry? = nil
	local everyone = #crew > 0
	for _, line in crew do
		if line.userId == userId then
			mine = line
		end
		if line.caught > 0 or table.find(present, line.userId) == nil then
			everyone = false
		end
	end
	if mine == nil then
		return nil
	end
	local caught = mine.caught > 0
	return {
		worked = true,
		quotaMet = quotaMet,
		items = mine.items,
		overtimeSalvage = mine.overtimeSalvage,
		extracted = not caught and table.find(present, userId) ~= nil,
		caught = caught,
		crewExtracted = everyone,
	}
end

-- The XP lines for one shift, in display order, and their total. Nothing for a shift not worked.
function RankFormulas.award(facts: ShiftFacts): RankTypes.Award
	local xp = RankConstants.XP
	local labels = RankConstants.LABELS
	local lines: { RankTypes.AwardLine } = {}
	local function add(key: RankTypes.AwardKey, amount: number)
		if amount > 0 then
			table.insert(lines, { key = key, label = labels[key], xp = amount })
		end
	end
	if facts.worked then
		add("shiftWorked", xp.shiftWorked)
		add("quotaMet", if facts.quotaMet then xp.quotaMet else 0)
		add("items", math.min(math.max(facts.items, 0), xp.itemCap) * xp.perItem)
		add("overtimeSalvage", if facts.overtimeSalvage > 0 then xp.overtimeSalvage else 0)
		if not facts.caught then
			add("extracted", if facts.extracted then xp.extracted else 0)
			add("crewExtracted", if facts.crewExtracted then xp.crewExtracted else 0)
		end
	end
	local total = 0
	for _, line in lines do
		total += line.xp
	end
	return { total = total, lines = lines, incident = facts.worked and facts.caught }
end

return RankFormulas
