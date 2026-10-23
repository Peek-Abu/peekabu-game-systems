--!strict
--[=[
	OfficeOozeRules: how dirty the rolled site looks from the yard. The dock's ooze (OfficeOozeSystem) shows the
	site's Gloom in three steps: the thirds of the economy's 730-1495 site range.

	@class OfficeOozeRules
]=]

export type Level = "none" | "little" | "lot"

-- The site's Gloom where the ooze starts (a third of 730-1495) and where it becomes a lot (two thirds).
local LITTLE_FROM = 985
local LOT_FROM = 1240

local OfficeOozeRules = {}

--[=[
	How much ooze a site of `gloom` shows: "none" below 985, "little" below 1240, else "lot".
]=]
function OfficeOozeRules.level(gloom: number): Level
	if gloom < LITTLE_FROM then
		return "none"
	elseif gloom < LOT_FROM then
		return "little"
	end
	return "lot"
end

return table.freeze(OfficeOozeRules)
