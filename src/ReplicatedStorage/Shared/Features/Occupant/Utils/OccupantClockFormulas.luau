--!strict
--[=[
	OccupantClockFormulas: the Manager's clock-head hands (owner picks 2026-11-18, S1: "hands spin on hunt and catch").
	His head is the gold smiling clock from the ODD HOURS logo; its two hands are their own parts on Motor6Ds
	(OccupantAssets.CLOCK_HANDS), modelled at their painted rest (the minute hand on 12, the hour hand on 3).

	A clock is how far the minute hand has wound past rest (`turns`, in whole turns, only ever forward) and how fast it
	winds now (`speed`, turns per second). `targetSpeed` says how fast it should wind: still while he is calm or
	noticing, `huntTurns` while his face is the hunting one (the chase, the sit-in's tip, the stare's check),
	`catchTurns` on the catch. `step` spins up toward that (`spinUp`), winds down (`spinDown`) to a slow `settleTurns`,
	and at that speed stops with the minute hand back on 12. `angles` gives each hand's extra clockwise turn in
	degrees; the hour hand winds one twelfth as fast, like a real clock (so time has moved on when he calms down).
	Pure.

	@class OccupantClockFormulas
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local OccupantConstants = require(ReplicatedStorage.Shared.Features.Occupant.Data.OccupantConstants)

export type Clock = { turns: number, speed: number }

local CLOCK = OccupantConstants.CLOCK

local OccupantClockFormulas = {}

-- Both hands at their painted rest.
local REST: Clock = table.freeze({ turns = 0, speed = 0 })
OccupantClockFormulas.REST = REST

--[=[
	How fast (turns per second) his minute hand should wind in `mode`, showing `face`.
]=]
function OccupantClockFormulas.targetSpeed(mode: string, face: string?): number
	if mode == "catch" then
		return CLOCK.catchTurns
	elseif face == "Hunting" then
		return CLOCK.huntTurns
	end
	return 0
end

--[=[
	The clock `dt` seconds on, winding toward `target` turns per second.
]=]
function OccupantClockFormulas.step(clock: Clock, target: number, dt: number): Clock
	if dt <= 0 then
		return clock
	end
	if target > 0 then
		local speed = if clock.speed < target
			then math.min(clock.speed + CLOCK.spinUp * dt, target)
			else math.max(clock.speed - CLOCK.spinDown * dt, target)
		return { turns = clock.turns + speed * dt, speed = speed }
	end
	-- Winding down: already at rest on a whole turn?
	if clock.speed == 0 and clock.turns % 1 == 0 then
		return clock
	end
	local speed = math.max(clock.speed - CLOCK.spinDown * dt, CLOCK.settleTurns)
	local turns = clock.turns + speed * dt
	local nextWhole = math.floor(clock.turns) + 1
	if speed <= CLOCK.settleTurns and turns >= nextWhole then
		return { turns = nextWhole, speed = 0 }
	end
	return { turns = turns, speed = speed }
end

--[=[
	Each hand's extra clockwise turn past its painted rest, in degrees (0 <= a < 360): minute, hour.
]=]
function OccupantClockFormulas.angles(clock: Clock): (number, number)
	return (clock.turns % 1) * 360, (clock.turns * 30) % 360
end

return OccupantClockFormulas
