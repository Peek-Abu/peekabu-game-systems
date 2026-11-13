--!strict
--[=[
	UIPreloadRules: what the client loads behind the first load screen, in what order, and when the screen may lift.
	Without it the engine fetches art the first time something shows it: a face swap draws a blank white face, and the
	shop's and the inventory's pictures and 3D cards pop in.

	The order (owner, 2026-11-12: faces first, then the shop and the inventory):
	0. the load screen's own pictures (`screen`), so the welcome card is whole while the rest loads;
	1. each employee's face sets (`faces:<Name>`: every Folder under the template named Faces..., its skins' sets too);
	2. the UI's pictures (`images`: icons, photos, stickers; UIAssets);
	3. each employee's whole model (`character:<Name>`: meshes, textures, the uniform);
	4. the wardrobe (`outfits`, `accessories`, `badges`): skins' clothes, loaded on after the screen lifts.
	The first three are essential: the screen waits for them, at most ESSENTIAL_TIMEOUT seconds, so one slow asset
	never keeps a player out of the game. Pure.

	@class UIPreloadRules
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local EmployeeRegistry = require(ReplicatedStorage.Shared.Features.Employee.Data.EmployeeRegistry)

local UIPreloadRules = {}

-- The name of the load screen's own batch (loaded first; UIPreloadStore.screenReady follows it).
UIPreloadRules.SCREEN_BATCH = "screen"

-- The longest the first load screen waits for the essential art before the game shows anyway (s).
UIPreloadRules.ESSENTIAL_TIMEOUT = 12

-- One PreloadAsync call: Instances (loaded with every descendant) or asset id strings.
export type Batch = {
	name: string,
	items: { Instance | string },
	essential: boolean,
}

local ASSET_ID = "^rbxassetid://%d+$"

-- The wardrobe folders under the art folder, by batch name, in load order.
local WARDROBE: { { name: string, folder: string } } = {
	{ name = "outfits", folder = "Outfits" },
	{ name = "accessories", folder = "Accessories" },
	{ name = "badges", folder = "LanyardBadges" },
}

--[=[
	Every asset id (rbxassetid://n) in the lists of strings `lists`, once each, sorted. Empty slots ("", a pending
	upload) and other strings are skipped.
]=]
function UIPreloadRules.imageIds(lists: { { string } }): { string }
	local found: { [string]: boolean } = {}
	local ids: { string } = {}
	for _, list in lists do
		for _, id in list do
			if not found[id] and string.match(id, ASSET_ID) ~= nil then
				found[id] = true
				table.insert(ids, id)
			end
		end
	end
	table.sort(ids)
	return ids
end

local function byName(a: Instance, b: Instance): boolean
	return a.Name < b.Name
end

-- The character templates under the art folder's Characters, sorted by name.
local function characters(art: Instance): { Instance }
	local folder = art:FindFirstChild("Characters")
	local list: { Instance } = {}
	if folder == nil then
		return list
	end
	for _, child in folder:GetChildren() do
		if child:IsA("Model") then
			table.insert(list, child)
		end
	end
	table.sort(list, byName)
	return list
end

-- A character's face sets: every Folder under it whose name starts with "Faces".
local function faceSets(character: Instance): { Instance }
	local sets: { Instance } = {}
	for _, descendant in character:GetDescendants() do
		if descendant:IsA("Folder") and string.sub(descendant.Name, 1, 5) == "Faces" then
			table.insert(sets, descendant)
		end
	end
	table.sort(sets, byName)
	return sets
end

--[=[
	The batches to load, in order, from the CleanupCrew art folder `art` (nil: none in this place) and the UI's picture
	ids `images` (`imageIds`), the load screen's own art `screen` (ids or Instances) first. Batches with nothing in them are left
	out.
]=]
function UIPreloadRules.batches(art: Instance?, images: { string }, screen: { Instance | string }?): { Batch }
	local batches: { Batch } = {}
	if screen ~= nil and #screen > 0 then
		local items: { Instance | string } = {}
		for _, id in screen do
			table.insert(items, id)
		end
		table.insert(batches, { name = UIPreloadRules.SCREEN_BATCH, items = items, essential = true })
	end
	local roster: { Instance } = {}
	if art ~= nil then
		roster = characters(art)
	end
	for _, character in roster do
		local sets = faceSets(character)
		if #sets > 0 then
			local items: { Instance | string } = {}
			for _, set in sets do
				table.insert(items, set)
			end
			table.insert(batches, { name = `faces:{character.Name}`, items = items, essential = true })
		end
	end
	if #images > 0 then
		local items: { Instance | string } = {}
		for _, id in images do
			table.insert(items, id)
		end
		table.insert(batches, { name = "images", items = items, essential = true })
	end
	for _, character in roster do
		table.insert(batches, { name = `character:{character.Name}`, items = { character }, essential = true })
	end
	if art ~= nil then
		for _, entry in WARDROBE do
			local folder = art:FindFirstChild(entry.folder)
			if folder ~= nil then
				table.insert(batches, { name = entry.name, items = { folder }, essential = false })
			end
		end
	end
	return batches
end

--[=[
	Everything one look (an employee in a skin) needs loaded to draw at once: the template, the skin's body, piece and
	style palettes (set as TextureIDs at runtime, so the template alone never fetches them), its accessories and its
	outfit from the art folder `art`. Pieces the art does not have are skipped; nil art gives nothing.
]=]
function UIPreloadRules.lookArt(
	art: Instance?,
	employee: string,
	skin: EmployeeRegistry.SkinDef?
): { Instance | string }
	local items: { Instance | string } = {}
	if art == nil then
		return items
	end
	local characters = art:FindFirstChild("Characters")
	local template = if characters ~= nil then characters:FindFirstChild(employee) else nil
	if template ~= nil then
		table.insert(items, template)
	end
	if skin == nil then
		return items
	end
	local accessories = art:FindFirstChild("Accessories")
	for _, name in skin.accessories do
		local piece = if accessories ~= nil then accessories:FindFirstChild(name) else nil
		if piece ~= nil then
			table.insert(items, piece)
		end
	end
	local outfitName = skin.outfit
	local outfits = art:FindFirstChild("Outfits")
	local outfit = if outfitName ~= nil and outfits ~= nil then outfits:FindFirstChild(outfitName) else nil
	if outfit ~= nil then
		table.insert(items, outfit)
	end
	local palettes: { string } = {}
	if skin.paletteTextureId ~= nil then
		table.insert(palettes, skin.paletteTextureId)
	end
	local pieces: { [string]: string } = skin.piecePalettes or {}
	for _, id in pieces do
		table.insert(palettes, id)
	end
	local styles: { EmployeeRegistry.StyleDef } = skin.styles or {}
	for _, style in styles do
		if style.paletteTextureId ~= nil then
			table.insert(palettes, style.paletteTextureId)
		end
	end
	for _, id in UIPreloadRules.imageIds({ palettes }) do
		table.insert(items, id)
	end
	return items
end

-- The load bar's fill: the share of the `total` essential batches done (1 when there are none).
function UIPreloadRules.progress(done: number, total: number): number
	if total <= 0 then
		return 1
	end
	return math.clamp(done / total, 0, 1)
end

-- Whether the first load screen may lift: every essential batch done, or ESSENTIAL_TIMEOUT seconds `elapsed`.
function UIPreloadRules.ready(done: number, total: number, elapsed: number): boolean
	return done >= total or elapsed >= UIPreloadRules.ESSENTIAL_TIMEOUT
end

return UIPreloadRules
