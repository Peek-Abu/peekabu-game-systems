--!strict
--[=[
	DeathRespawnRules: whether Death respawns a dead player on its own. Pure.

	Only the "auto" policy respawns, and only a player who is not held (kept down on purpose, e.g. knocked
	out for the shift).

	@class DeathRespawnRules
]=]

local DeathRespawnRules = {}

--[=[
	True when a dead player should be respawned automatically.
]=]
function DeathRespawnRules.respawns(mode: "auto" | "manual", held: boolean): boolean
	return mode == "auto" and not held
end

return DeathRespawnRules
