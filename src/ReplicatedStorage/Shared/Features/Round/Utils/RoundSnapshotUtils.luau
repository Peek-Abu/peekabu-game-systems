--!strict
--[=[
	RoundSnapshotUtils: turns the replicated `round` world entry (plain data off the wire, typed as a WorldValue)
	back into a typed RoundSnapshot, or nil when it is malformed. The server builds the snapshot (RoundRunTracker); this is
	the client's trust boundary for it.

	@class RoundSnapshotUtils
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PlayerDataTypes = require(ReplicatedStorage.Shared.Data.PlayerDataTypes)
local WorldTypes = require(ReplicatedStorage.Shared.Data.WorldTypes)
local RoundTypes = require(ReplicatedStorage.Shared.Features.Round.Data.RoundTypes)

type Phase = RoundTypes.Phase
type InventoryEntry = PlayerDataTypes.InventoryEntry
type WorldValue = WorldTypes.WorldValue

local function phaseOf(value: WorldValue?): Phase?
	if value == "lobby" then
		return "lobby"
	elseif value == "starting" then
		return "starting"
	elseif value == "running" then
		return "running"
	elseif value == "results" then
		return "results"
	end
	return nil
end

-- A list of numbers; nil (absent) decodes as empty, anything malformed as nil.
local function numberList(value: WorldValue?): { number }?
	local result: { number } = {}
	if value == nil then
		return result
	end
	if type(value) ~= "table" then
		return nil
	end
	for _, item in value do
		if type(item) ~= "number" then
			return nil
		end
		table.insert(result, item)
	end
	return result
end

-- A string-keyed map of numbers; nil (absent) decodes as empty, anything malformed as nil.
local function numberMap(value: WorldValue?): { [string]: number }?
	local result: { [string]: number } = {}
	if value == nil then
		return result
	end
	if type(value) ~= "table" then
		return nil
	end
	for key, item in value do
		if type(key) ~= "string" or type(item) ~= "number" then
			return nil
		end
		result[key] = item
	end
	return result
end

local function attrsOf(value: WorldValue?): ({ [string]: PlayerDataTypes.AttrValue }?, boolean)
	if value == nil then
		return nil, true
	end
	if type(value) ~= "table" then
		return nil, false
	end
	local result: { [string]: PlayerDataTypes.AttrValue } = {}
	for key, item in value do
		if type(key) ~= "string" then
			return nil, false
		end
		if type(item) ~= "number" and type(item) ~= "string" then
			return nil, false
		end
		result[key] = item
	end
	return result, true
end

local function entryOf(value: WorldValue?): InventoryEntry?
	if type(value) ~= "table" then
		return nil
	end
	local itemType = value.itemType
	if type(itemType) ~= "string" then
		return nil
	end
	local quantity = value.quantity
	if type(quantity) == "number" then
		local stack: PlayerDataTypes.StackEntry = { itemType = itemType, quantity = quantity }
		return stack
	end
	local uid = value.uid
	if type(uid) ~= "string" then
		return nil
	end
	local attrs, ok = attrsOf(value.attrs)
	if not ok then
		return nil
	end
	local unique: PlayerDataTypes.UniqueEntry = { itemType = itemType, uid = uid, attrs = attrs }
	return unique
end

local function containersOf(value: WorldValue?): { [string]: { InventoryEntry } }?
	local result: { [string]: { InventoryEntry } } = {}
	if value == nil then
		return result
	end
	if type(value) ~= "table" then
		return nil
	end
	for name, items in value do
		if type(name) ~= "string" or type(items) ~= "table" then
			return nil
		end
		local entries: { InventoryEntry } = {}
		for _, item in items do
			local entry = entryOf(item)
			if entry == nil then
				return nil
			end
			table.insert(entries, entry)
		end
		result[name] = entries
	end
	return result
end

local function scoresOf(value: WorldValue?): { [string]: { [string]: number } }?
	local result: { [string]: { [string]: number } } = {}
	if value == nil then
		return result
	end
	if type(value) ~= "table" then
		return nil
	end
	for key, item in value do
		local scores = numberMap(item)
		if type(key) ~= "string" or scores == nil then
			return nil
		end
		result[key] = scores
	end
	return result
end

local RoundSnapshotUtils = {}

--[=[
	Decodes a replicated snapshot. Absent lists and maps decode as empty; a wrong type anywhere rejects
	the whole value.
	@param value WorldValue? -- the `round` world entry
	@return RoundSnapshot?
]=]
function RoundSnapshotUtils.decode(value: WorldValue?): RoundTypes.RoundSnapshot?
	if type(value) ~= "table" then
		return nil
	end
	-- Annotated and tested with `not` (not `== nil`): comparing an optional singleton union against nil
	-- widens it back to `string`.
	local phase: Phase? = phaseOf(value.phase)
	local round = value.round
	local endsAt = value.endsAt
	local outcome = value.outcome
	if not phase then
		return nil
	end
	if type(round) ~= "number" then
		return nil
	end
	if endsAt ~= nil and type(endsAt) ~= "number" then
		return nil
	end
	if outcome ~= nil and type(outcome) ~= "string" then
		return nil
	end
	local participants = numberList(value.participants)
	local eliminated = numberList(value.eliminated)
	local team = numberMap(value.team)
	local targets = numberMap(value.targets)
	local scores = scoresOf(value.scores)
	local containers = containersOf(value.containers)
	if
		participants == nil
		or eliminated == nil
		or team == nil
		or targets == nil
		or scores == nil
		or containers == nil
	then
		return nil
	end
	local snapshot: RoundTypes.RoundSnapshot = {
		phase = phase,
		round = round,
		endsAt = if type(endsAt) == "number" then endsAt else nil,
		outcome = if type(outcome) == "string" then outcome else nil,
		participants = participants,
		eliminated = eliminated,
		team = team,
		targets = targets,
		scores = scores,
		containers = containers,
	}
	return snapshot
end

return RoundSnapshotUtils
