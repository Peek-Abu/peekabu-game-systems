--!strict
--[=[
	DeathRespawnRules: whether Death respawns a dead player on its own. Pure.

	Only the "auto" policy respawns, and only a player who is not held (kept down on purpose, e.g. knocked
	out for the shift). A character marked to keep its place skips the spawn point (`keepsPlace`).

	@class DeathRespawnRules
]=]

local DeathRespawnRules = {}

--[=[
	True when a dead player should be respawned automatically.
]=]
function DeathRespawnRules.respawns(mode: "auto" | "manual", held: boolean): boolean
	return mode == "auto" and not held
end

--[=[
	True when a new character must stay where it was placed instead of going to the spawn point: its
	DeathConstants.KEEP_PLACE_ATTRIBUTE is true (a game rebuilding a character in place, e.g. a costume swap).
]=]
function DeathRespawnRules.keepsPlace(attribute: unknown): boolean
	return attribute == true
end

return DeathRespawnRules
