--!strict
--[=[
	OfficeVariationRules: every per-run choice of the office (which props stay, desk clutter, light moods, doors
	left open, floor dressing, exterior anomalies), all pure functions of the shift seed. A nil seed is the authored
	boot layout: everything on, nothing extra.

	@class OfficeVariationRules
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local OfficeConstants = require(ServerScriptService.Features.Office.Data.OfficeConstants)
local OfficeTypes = require(ServerScriptService.Features.Office.Data.OfficeTypes)
local OfficeAnomalyConstants = require(ReplicatedStorage.Shared.Features.Office.Data.OfficeAnomalyConstants)
local OfficeSeedUtils = require(ReplicatedStorage.Shared.Features.Office.Utils.OfficeSeedUtils)

type AnomalyId = OfficeAnomalyConstants.AnomalyId

export type LightMood = "normal" | "dim" | "dark"
export type Dressing = "stain" | "paper"

local DOOR_OPEN_CHANCE = 0.3
local DIM_FROM = 0.6
local DARK_FROM = 0.9
local STAIN_BELOW = 0.2
local PAPER_BELOW = 0.4
local ONE_ANOMALY_CHANCE = 0.65
-- Evaluation order of desk items (folder is decided before paperStack, so a kept folder blocks the paper stack).
local CLUTTER_ORDER = { "mug", "stationeryCup", "folder", "paperTray", "paperStack", "bookStack" }
local STEADY_ROOMS: { [string]: boolean } = { storage = true, server = true, reception = true }

local OfficeVariationRules = {}

--[=[
	Whether a dressing prop stays this run.
	@param seed number? -- the shift's layout seed (nil: authored layout)
	@param markerId string
	@param art string -- the marker's art key
	@return boolean
]=]
function OfficeVariationRules.keepProp(seed: number?, markerId: string, art: string): boolean
	if seed == nil then
		return true
	end
	local chance = OfficeConstants.PROP_CHANCE[art] or 1
	return OfficeSeedUtils.hash01(seed, "prop:" .. markerId) < chance
end

--[=[
	The items on a desk this run. A nil seed keeps the authored rule: mug and stationery cup on every desk, an odd
	desk adds folder and paper tray, an even one paper stack and book stack. The desk's number is the trailing
	integer of its id ("<room>.desk.<n>"), 1-based; an id without one counts as even.
	@param seed number? -- the shift's layout seed
	@param deskId string
	@return { string } -- item keys, in OfficeDecorSystem's placement order
]=]
function OfficeVariationRules.deskClutter(seed: number?, deskId: string): { string }
	if seed == nil then
		local n = tonumber(string.match(deskId, "(%d+)$")) or 0
		if n % 2 == 1 then
			return { "mug", "stationeryCup", "folder", "paperTray" }
		end
		return { "mug", "stationeryCup", "paperStack", "bookStack" }
	end
	local kept: { string } = {}
	local hasFolder = false
	for _, item in CLUTTER_ORDER do
		local keep = OfficeSeedUtils.hash01(seed, `clutter:{deskId}:{item}`) < OfficeConstants.DESK_CLUTTER_CHANCE[item]
		if item == "folder" and keep then
			hasFolder = true
		end
		if item == "paperStack" and hasFolder then
			keep = false
		end
		if keep then
			table.insert(kept, item)
		end
	end
	return kept
end

--[=[
	A room's light this run: normal for the authored layout and for halls, storage, server and reception; else
	60% normal, 30% dim, 10% dark.
	@param seed number? -- the shift's layout seed
	@param roomId string
	@param roomType OfficeTypes.RoomType? -- nil for halls and non-kit rooms
	@return LightMood
]=]
function OfficeVariationRules.lightMood(seed: number?, roomId: string, roomType: OfficeTypes.RoomType?): LightMood
	if seed == nil or roomType == nil or STEADY_ROOMS[roomType] then
		return "normal"
	end
	local roll = OfficeSeedUtils.hash01(seed, "light:" .. roomId)
	if roll < DIM_FROM then
		return "normal"
	elseif roll < DARK_FROM then
		return "dim"
	end
	return "dark"
end

--[=[
	Whether a door starts the run open.
	@param seed number? -- the shift's layout seed
	@param doorId string
	@return boolean
]=]
function OfficeVariationRules.doorStartsOpen(seed: number?, doorId: string): boolean
	if seed == nil then
		return false
	end
	return OfficeSeedUtils.hash01(seed, "door:" .. doorId) < DOOR_OPEN_CHANCE
end

--[=[
	Which free markers get a stain or a paper scatter (20% each, else nothing).
	@param seed number? -- the shift's layout seed
	@param freeMarkerIds { string }
	@return { [string]: Dressing }
]=]
function OfficeVariationRules.dressing(seed: number?, freeMarkerIds: { string }): { [string]: Dressing }
	local result: { [string]: Dressing } = {}
	if seed == nil then
		return result
	end
	for _, id in freeMarkerIds do
		local roll = OfficeSeedUtils.hash01(seed, "dress:" .. id)
		if roll < STAIN_BELOW then
			result[id] = "stain"
		elseif roll < PAPER_BELOW then
			result[id] = "paper"
		end
	end
	return result
end

--[=[
	The run's exterior anomalies: one (65%) or two, never repeated.
	@param seed number? -- the shift's layout seed
	@return { AnomalyId }
]=]
function OfficeVariationRules.anomalies(seed: number?): { AnomalyId }
	local picked: { AnomalyId } = {}
	if seed == nil then
		return picked
	end
	local pool: { AnomalyId } = {}
	for _, id in OfficeAnomalyConstants.IDS do
		table.insert(pool, id)
	end
	local count = if OfficeSeedUtils.hash01(seed, "anomaly:count") < ONE_ANOMALY_CHANCE then 1 else 2
	for n = 1, count do
		local index = math.floor(OfficeSeedUtils.hash01(seed, "anomaly:pick" .. n) * #pool) + 1
		local id = table.remove(pool, index)
		if id ~= nil then
			table.insert(picked, id)
		end
	end
	return picked
end

return OfficeVariationRules
