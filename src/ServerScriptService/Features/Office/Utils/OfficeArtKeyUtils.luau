--!strict
--[=[
	OfficeArtKeyUtils: which art template does a piece of office furniture use? `candidates` lists the keys to try
	in order (a marker's own `art` override, the default key's room-type variant, the default key) and `attachFirst`
	attaches the first that has a template, so a kit that lacks the variant falls back to the plain art and a place
	without the kit falls back to greybox. A piece the map's own kit lacks falls back to the default kit
	(ArtKitRegistry.DEFAULT_KIT): `attachFirst` tries every key in the resolved kit, then every key again in the
	default kit, so a restyling kit only needs the pieces it changes. Pure apart from the attach call.

	@class OfficeArtKeyUtils
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local ArtVisualSystem = require(ServerScriptService.Features.Art.Systems.ArtVisualSystem)
local ArtKitRegistry = require(ReplicatedStorage.Shared.Features.Art.Data.ArtKitRegistry)
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
	Attaches the first of `keys` that resolves to a template to `root`, trying the root's own kit first and then the
	default kit; nil when none does (greybox stays).
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
	if art.resolveKit(root) ~= ArtKitRegistry.DEFAULT_KIT then
		for _, key in keys do
			local visual = art.attach(root, family, key, ArtKitRegistry.DEFAULT_KIT)
			if visual ~= nil then
				return visual
			end
		end
	end
	return nil
end

return OfficeArtKeyUtils
