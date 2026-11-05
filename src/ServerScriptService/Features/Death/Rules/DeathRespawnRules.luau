--!strict
--[=[
	DeathRespawnRules: whether Death respawns a dead player on its own. Pure.

	Only the "auto" policy respawns, and only a player who is not held (kept down on purpose, e.g. knocked
	out for the shift). A character marked to keep its place skips the spawn point (`keepsPlace`). A character
	already replaced or removed when Death gets to it is not watched (`watches`).

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

--[=[
	True when Death should watch a new character: it is still the player's character (`current`) and still in the
	world (`inWorld`). The character observer runs deferred, so a character rebuilt right after it spawned arrives
	already destroyed, its Humanoid gone with it; that one is skipped, not waited on and warned about.
]=]
function DeathRespawnRules.watches(current: boolean, inWorld: boolean): boolean
	return current and inWorld
end

return DeathRespawnRules
