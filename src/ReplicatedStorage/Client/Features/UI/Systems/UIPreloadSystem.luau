--!strict
--[=[
	UIPreloadSystem: loads the art the first screens show behind the first load screen (UIPreloadRules picks what and in
	what order: faces, the UI's pictures and the skins' palettes, the characters, then the wardrobe). Each batch is one
	ContentProvider:PreloadAsync call, run one after another on their own thread; a failed batch is logged and skipped.
	UIPreloadStore gets the bar's progress after each essential batch and `ready` once they are all in, or after
	UIPreloadRules.ESSENTIAL_TIMEOUT seconds whatever is left (the rest keeps loading). Each batch's load time is logged,
	so a slow join is visible in the output. Once every batch is done it warms the crew cards: every employee in every
skin, in the "crew" pose the Shop's and the Inventory's cards use, built one a frame into EmployeePreviewSystem's
cache (EmployeePreviewSystem.warm), so the first open of those screens clones its cards.

	`start` takes optional stand-ins (the art folder, the image ids, the loader, the timeout, the warm-up) for specs; the place's own
	are ReplicatedStorage.Assets.CleanupCrew, UIAssets' pictures plus every skin palette in EmployeeRegistry, and
	ContentProvider:PreloadAsync.

	@class UIPreloadSystem
]=]

local ContentProvider = game:GetService("ContentProvider")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Logger = require(ReplicatedStorage.Shared.Core.Logger)
local EmployeePoseRegistry = require(ReplicatedStorage.Shared.Features.Employee.Data.EmployeePoseRegistry)
local EmployeePoseRules = require(ReplicatedStorage.Shared.Features.Employee.Rules.EmployeePoseRules)
local EmployeeRegistry = require(ReplicatedStorage.Shared.Features.Employee.Data.EmployeeRegistry)
local EmployeePreviewSystem = require(ReplicatedStorage.Client.Features.Employee.Systems.EmployeePreviewSystem)
local UIAssets = require(ReplicatedStorage.Client.Features.UI.Data.UIAssets)
local UIPreloadRules = require(ReplicatedStorage.Client.Features.UI.Rules.UIPreloadRules)
local UIPreloadStore = require(ReplicatedStorage.Client.Features.UI.State.UIPreloadStore)

local log = Logger.new("UIPreloadSystem")

export type Options = {
	art: Instance?,
	images: { string }?,
	-- The load screen's own pictures, loaded first.
	screen: { Instance | string }?,
	preload: ((items: { Instance | string }) -> ())?,
	timeout: number?,
	-- Runs once every batch is done; returns its cancel.
	warm: (() -> () -> ())?,
}

export type UIPreloadState = {
	done: number,
	total: number,
	elapsed: number,
	timedOut: boolean,
	-- Each finished batch's load time (s), by batch name.
	seconds: { [string]: number },
}

local generation = 0
local cancelWarm: (() -> ())? = nil
local running = false
local state: UIPreloadState = { done = 0, total = 0, elapsed = 0, timedOut = false, seconds = {} }
local startedAt = 0

-- The place's art folder (ReplicatedStorage.Assets.CleanupCrew), or nil.
local function placeArt(): Instance?
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	return if assets ~= nil then assets:FindFirstChild("CleanupCrew") else nil
end

local function values(map: { [string]: string }): { string }
	local list: { string } = {}
	for _, id in map do
		table.insert(list, id)
	end
	return list
end

-- The UI's pictures (UIAssets) and every skin's body, style and piece palette (EmployeeRegistry): a skin sets those
-- TextureIDs at runtime, so loading the templates alone never fetches them.
local function placeImages(): { string }
	local lists: { { string } } = {}
	local icons: { string } = {}
	for _, id in UIAssets.toonIcons do
		table.insert(icons, id)
	end
	table.insert(lists, icons)
	table.insert(lists, values(UIAssets.toonPhotos))
	table.insert(lists, values(UIAssets.stickers))
	table.insert(lists, values(UIAssets.toon))
	local paper: { string } = {}
	for _, texture in UIAssets.paper do
		table.insert(paper, texture.id)
	end
	table.insert(lists, paper)
	local palettes: { string } = {}
	for _, name in EmployeeRegistry.names() do
		local def = EmployeeRegistry.get(name)
		if def ~= nil then
			for _, skin in def.skins do
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
			end
		end
	end
	table.insert(lists, palettes)
	return UIPreloadRules.imageIds(lists)
end

-- The welcome card's own art (ShiftTransitPanel's greeting): Pippa's model (drawn waving on it) and the goo of its tip
-- plate.
local function placeScreen(art: Instance?): { Instance | string }
	local items: { Instance | string } = {}
	local characters = if art ~= nil then art:FindFirstChild("Characters") else nil
	local pippa = if characters ~= nil then characters:FindFirstChild("Pippa") else nil
	if pippa ~= nil then
		table.insert(items, pippa)
	end
	for _, id in UIPreloadRules.imageIds({ { UIAssets.toon.poolTile, UIAssets.toon.gooEnds } }) do
		table.insert(items, id)
	end
	return items
end

--[=[
	One batch through ContentProvider:PreloadAsync. An image id goes in on an ImageLabel: PreloadAsync fails a bare
	image id string (measured 2026-11-13: every one "could not load"), but loads the image an ImageLabel names. A
	content id the art leaves empty is not a failure.
]=]
local function placePreload(items: { Instance | string })
	local list: { Instance } = {}
	local labels: { ImageLabel } = {}
	for _, item in items do
		if typeof(item) == "string" then
			local label = Instance.new("ImageLabel")
			label.Image = item
			table.insert(labels, label)
			table.insert(list, label)
		else
			table.insert(list, item)
		end
	end
	ContentProvider:PreloadAsync(list, function(contentId: string, status: Enum.AssetFetchStatus)
		if status == Enum.AssetFetchStatus.Failure and contentId ~= "" then
			log:warn(`could not load {contentId}`)
		end
	end)
	for _, label in labels do
		label:Destroy()
	end
end

-- Every employee in every skin, in the pose their Shop and Inventory cards use ("crew"), warmed into the preview cache.
local function placeWarm(): () -> ()
	local looks: { EmployeePreviewSystem.Look } = {}
	for _, name in EmployeeRegistry.names() do
		local def = EmployeeRegistry.get(name)
		if def ~= nil then
			local pose = EmployeePoseRules.select(EmployeePoseRegistry.get(name), "crew", {})
			table.insert(looks, { employee = name, pose = pose })
			for key in def.skins do
				table.insert(looks, { employee = name, skin = key, pose = pose })
			end
		end
	end
	return EmployeePreviewSystem.warm(looks, ReplicatedStorage)
end

local UIPreloadSystem = {}

function UIPreloadSystem.start(options: Options?)
	if running then
		return
	end
	running = true
	generation += 1
	local mine = generation
	local given: Options = options or {}
	local art = if given.art ~= nil then given.art else placeArt()
	local batches = UIPreloadRules.batches(art, given.images or placeImages(), given.screen or placeScreen(art))
	local preload = given.preload or placePreload
	local timeout = given.timeout or UIPreloadRules.ESSENTIAL_TIMEOUT
	local total = 0
	for _, batch in batches do
		if batch.essential then
			total += 1
		end
	end
	startedAt = os.clock()
	state = { done = 0, total = total, elapsed = 0, timedOut = false, seconds = {} }
	UIPreloadStore.progress(UIPreloadRules.progress(0, total))

	local function finish(timedOut: boolean)
		if mine ~= generation or UIPreloadStore.ready() then
			return
		end
		state.elapsed = os.clock() - startedAt
		state.timedOut = timedOut
		UIPreloadStore.ready(true)
		if timedOut then
			log:warn(`the art was not all in after {timeout}s ({state.done}/{total} batches); showing the game anyway`)
		else
			log:info(`the essential art is in after {string.format("%.2f", state.elapsed)}s`)
		end
	end

	task.delay(timeout, finish, true)
	task.spawn(function()
		if total == 0 then
			finish(false)
		end
		for _, batch in batches do
			if mine ~= generation then
				return
			end
			local began = os.clock()
			local ok, err = pcall(preload, batch.items)
			if mine ~= generation then
				return
			end
			state.seconds[batch.name] = os.clock() - began
			if not ok then
				log:warn(`preloading {batch.name} failed: {err}`)
			end
			if batch.essential then
				state.done += 1
				UIPreloadStore.progress(UIPreloadRules.progress(state.done, total))
				if UIPreloadRules.ready(state.done, total, 0) then
					finish(false)
				end
			end
		end
		if mine == generation then
			cancelWarm = (given.warm or placeWarm)()
		end
	end)
end

function UIPreloadSystem.stop()
	generation += 1
	running = false
	local cancel = cancelWarm
	if cancel ~= nil then
		cancel()
		cancelWarm = nil
	end
end

function UIPreloadSystem.getState(): UIPreloadState
	return {
		done = state.done,
		total = state.total,
		elapsed = if UIPreloadStore.ready() then state.elapsed else os.clock() - startedAt,
		timedOut = state.timedOut,
		seconds = table.clone(state.seconds),
	}
end

return UIPreloadSystem
