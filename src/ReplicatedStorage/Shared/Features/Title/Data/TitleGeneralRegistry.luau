--!strict
--[=[
	TitleGeneralRegistry: the seed domain of the titles registry (titles design spec, Decision 1) — the ids that
	have a consumer TODAY (admin grants via the titleaward command). Quest/guild titles arrive with
	those systems as their own domains plus one row in TitleRegistry.DOMAIN_MODULES.

	Adding a title = one entry here (or in a future domain module). Because profiles store only
	ids, reshaping an entry is migration-free; RETIRING one is deletion — the slice validators
	tolerate unknown ids precisely so a retired title never freezes a save (titles design spec,
	Decision 2).

	@class TitleGeneralRegistry
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TitleTypes = require(ReplicatedStorage.Shared.Features.Title.Data.TitleTypes)

local function entry(id: string, displayName: string, color: Color3): TitleTypes.TitleDef
	local def: TitleTypes.TitleDef = {
		id = id,
		displayName = displayName,
		color = color,
	}
	return table.freeze(def)
end

local TitleGeneralRegistry: TitleTypes.TitleDomain = table.freeze({
	veteran = entry("veteran", "Veteran", Color3.fromRGB(255, 170, 0)),
	champion = entry("champion", "Champion", Color3.fromRGB(200, 80, 255)),
	guildmaster = entry("guildmaster", "Guild Master", Color3.fromRGB(85, 170, 255)),
})

return TitleGeneralRegistry
