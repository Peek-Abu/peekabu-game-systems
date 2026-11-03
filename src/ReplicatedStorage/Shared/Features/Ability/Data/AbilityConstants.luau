--!strict
--[=[
	AbilityConstants: the ability button and its contracts. Static data (spec-exempt).

	@class AbilityConstants
]=]

-- The words a refused use or an ended plant shows (kid reading level). A reason without words shows nothing.
local REASON_WORDS: { [string]: string } = {
	cooldown = "Not ready yet!",
	nothing = "Nothing to find!",
	holding = "Put that down first!",
	airborne = "Land first!",
	moved = "You popped out!",
}

return table.freeze({
	-- The Input action: Q on a keyboard, Y on a gamepad (both free; the phone's arc button calls the client service).
	ACTION = "ability",
	KEYBOARD_KEY = Enum.KeyCode.Q,
	GAMEPAD_KEY = Enum.KeyCode.ButtonY,
	-- Replicated on the Player: when the ability is ready again (server time, Workspace:GetServerTimeNow; 0 = ready).
	READY_AT_ATTRIBUTE = "AbilityReadyAt",
	-- Replicated on the character while an ability's effect runs: its AbilityId (others' clients draw its visuals).
	ACTIVE_ATTRIBUTE = "AbilityActive",
	-- A plant ends once the root has moved this many studs across the floor from where it began.
	PLANT_MOVE_TOLERANCE = 1,
	-- Stealth source names (NpcServiceServer:conceal).
	PLANT_SOURCE = "pottedPlant",
	-- How often the server checks running plants and timed effects.
	TICK = 0.05,
	-- Use / Cancel requests are rate limited per player.
	REQUEST_RATE = table.freeze({ maxRequests = 10, windowSeconds = 5 }),
	REASON_WORDS = table.freeze(REASON_WORDS),
	TOAST_SECONDS = 2,
})
