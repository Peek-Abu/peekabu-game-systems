--!strict
--[=[
	SchoolLayoutRules: whether a generated School is good enough to build. Split out of SchoolLayoutGenerationUtils,
	which keeps rolling until a layout passes. Pure.

	@class SchoolLayoutRules
]=]

local ServerScriptService = game:GetService("ServerScriptService")

local Office = ServerScriptService.Features.Office
local OfficeConstants = require(Office.Data.OfficeConstants)
local OfficeLayoutRules = require(Office.Rules.OfficeLayoutRules)
local OfficeTypes = require(Office.Data.OfficeTypes)
local SchoolConstants = require(ServerScriptService.Features.School.Data.SchoolConstants)

type Layout = OfficeTypes.Layout

local SchoolLayoutRules = {}

--[=[
	Why `layout` is not good enough, or nil: the Office's checks (validate, capacity, route, hide spots, walk), then
	the School's room mix (one gym, one cafeteria, at most one library, one lounge, CLASSROOMS_MIN classrooms).
]=]
function SchoolLayoutRules.problem(layout: Layout): string?
	local ok, errors = OfficeLayoutRules.validate(layout)
	if not ok then
		return `invalid: {table.concat(errors, "; ")}`
	end
	for _, check in
		{
			OfficeLayoutRules.checkCapacity,
			OfficeLayoutRules.checkRoute,
			OfficeLayoutRules.checkHideSpots,
		}
	do
		local passed, reason = check(layout)
		if not passed then
			return reason
		end
	end
	local walked, walkReason =
		OfficeLayoutRules.checkWalk(layout, OfficeConstants.WALK_SPEED * OfficeConstants.MAX_WALK_SECONDS)
	if not walked then
		return walkReason
	end
	local byType: { [string]: number } = {}
	local classrooms = 0
	for _, room in layout.rooms do
		local roomType = room.roomType
		if roomType ~= nil then
			byType[roomType] = (byType[roomType] or 0) + 1
		end
		if room.kit ~= nil and table.find(SchoolConstants.CLASSROOM_KITS, room.kit) ~= nil then
			classrooms += 1
		end
	end
	local gyms, cafeterias, libraries, lounges =
		byType.gym or 0, byType.cafeteria or 0, byType.library or 0, byType.lounge or 0
	if gyms ~= 1 or cafeterias ~= 1 or libraries > 1 or lounges ~= 1 then
		return `{gyms} gyms, {cafeterias} cafeterias, {libraries} libraries, {lounges} lounges`
	end
	if classrooms < SchoolConstants.CLASSROOMS_MIN then
		return `{classrooms} classrooms (wanted {SchoolConstants.CLASSROOMS_MIN})`
	end
	return nil
end

return SchoolLayoutRules
