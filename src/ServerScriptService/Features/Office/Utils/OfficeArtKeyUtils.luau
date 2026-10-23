--!strict
--[=[
	OfficeArtKeyUtils: which art template does a piece of office furniture use? `candidates` lists the keys to try
	in order (a marker's own `art` override, the default key's room-type variant, the default key) and `attachFirst`
	attaches the first that has a template, so a kit that lacks the variant falls back to the plain art and a place
	without the kit falls back to greybox. Pure apart from the attach call.

	@class OfficeArtKeyUtils
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local ArtVisualSystem = require(ServerScriptService.Features.Art.Systems.ArtVisualSystem)
local ArtTypes = require(ReplicatedStorage.Shared.Features.Art.Data.ArtTypes)

local OfficeTypes = require(ServerScriptService.Features.Office.Data.OfficeTypes)

local OfficeArtKeyUtils = {}

--[=[
	The room-type segment of a room's art keys: its kit type, "hallway" for a corridor piece, nil for an authored room
	(or no room).
]=]
function OfficeArtKeyUtils.roomType(room: OfficeTypes.Room?): string?
	if room == nil then
		return nil
	elseif room.zone == "hallway" then
		return "hallway"
	end
	return room.roomType
end

--[=[
	The keys to try for a piece, in order: `override`, `<defaultKey>_<roomType>`, `defaultKey`. Nils and
	duplicates are skipped.
]=]
function OfficeArtKeyUtils.candidates(defaultKey: string, override: string?, roomType: string?): { string }
	local keys: { string } = {}
	local function add(key: string?)
		if key ~= nil and not table.find(keys, key) then
			table.insert(keys, key)
		end
	end
	add(override)
	if roomType ~= nil then
		add(`{defaultKey}_{roomType}`)
	end
	add(defaultKey)
	return keys
end

--[=[
	Attaches the first of `keys` that resolves to a template to `root`; nil when none does (greybox stays).
]=]
function OfficeArtKeyUtils.attachFirst(
	art: ArtVisualSystem.Controller,
	root: BasePart,
	family: ArtTypes.Family,
	keys: { string }
): Model?
	for _, key in keys do
		local visual = art.attach(root, family, key)
		if visual ~= nil then
			return visual
		end
	end
	return nil
end

return OfficeArtKeyUtils
