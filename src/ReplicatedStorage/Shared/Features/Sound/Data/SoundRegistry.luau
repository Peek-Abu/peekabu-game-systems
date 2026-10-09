--!strict
--[=[
	SoundRegistry: the catalog of sounds by id — the ONE home of sound asset ids (the CI asset-id gate
	allows them only in a feature's Data/ folder).

	`register` is a developer-error contract (the ItemRegistry precedent): it validates and asserts
	loudly at boot, including on a second registration of the same id. A game registers its sounds from
	one Data module required at boot on both realms (the server validates ids before sending them).

	@class SoundRegistry
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SoundData = ReplicatedStorage.Shared.Features.Sound.Data
local SoundTypes = require(SoundData.SoundTypes)
local SoundConstants = require(SoundData.SoundConstants)

type SoundDef = SoundTypes.SoundDef

local definitions: { [string]: SoundDef } = {}

local SoundRegistry = {}

--[=[
	Registers a new sound. Asserts: the id is new; the asset id is canonical; the group is known; the
	volume is within 0..10; a pitch range is positive and min <= max; maxConcurrent is a positive
	integer; rollOffMaxDistance is positive.
	@param id string
	@param def SoundDef
]=]
function SoundRegistry.register(id: string, def: SoundDef)
	assert(definitions[id] == nil, `sound "{id}" is already registered`)
	assert(
		type(def.assetId) == "string" and string.match(def.assetId, "^rbxassetid://%d+$") ~= nil,
		`sound "{id}": assetId must be rbxassetid://<digits>`
	)
	assert(table.find(SoundConstants.GROUPS, def.group) ~= nil, `sound "{id}": unknown group "{def.group}"`)
	assert(def.volume >= 0 and def.volume <= 10, `sound "{id}": volume must be within 0..10`)
	local pitch = def.pitch
	if pitch ~= nil then
		assert(pitch.min > 0 and pitch.min <= pitch.max, `sound "{id}": pitch needs 0 < min <= max`)
	end
	local maxConcurrent = def.maxConcurrent
	if maxConcurrent ~= nil then
		assert(maxConcurrent >= 1 and maxConcurrent % 1 == 0, `sound "{id}": maxConcurrent must be a positive integer`)
	end
	local rollOff = def.rollOffMaxDistance
	if rollOff ~= nil then
		assert(rollOff > 0, `sound "{id}": rollOffMaxDistance must be positive`)
	end
	definitions[id] = def
end

function SoundRegistry.get(id: string): SoundDef?
	return definitions[id]
end

function SoundRegistry.has(id: string): boolean
	return definitions[id] ~= nil
end

function SoundRegistry.ids(): { string }
	local ids: { string } = {}
	for id in definitions do
		table.insert(ids, id)
	end
	table.sort(ids)
	return ids
end

return SoundRegistry
