--!strict
--[=[
	DepotIdleRules: the timing of the hub stations' small idle motions (owner 11-11, ideas sheet #3: "every station does
	something on its own"; DepotSpotConstants.IDLE). When a motion next happens, the radio's hop on the beat, a locker
	door's rattle, the bell's little sway, the time clock's second hand and a dropped can's fall.

	@class DepotIdleRules
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DepotSpotConstants = require(ReplicatedStorage.Shared.Features.Depot.Data.DepotSpotConstants)

local IDLE = DepotSpotConstants.IDLE

local DepotIdleRules = {}

--[=[
	When motion `kind` next happens after `now`: `roll` (0..1) of the way through its interval (IDLE.INTERVALS); now for
	a motion that always runs.
]=]
function DepotIdleRules.nextAt(now: number, kind: string, roll: number): number
	local range = IDLE.INTERVALS[kind]
	if range == nil then
		return now
	end
	return now + range[1] + (range[2] - range[1]) * math.clamp(roll, 0, 1)
end

--[=[
	How far the radio is off its shelf (studs) `t` seconds into the music, `beat` seconds a beat: a quick hop at the
	start of each beat, still for the rest of it.
]=]
function DepotIdleRules.bounce(t: number, beat: number): number
	local phase = (t % beat) / beat
	local share = IDLE.BOUNCE.SHARE
	if phase >= share then
		return 0
	end
	return IDLE.BOUNCE.APEX * math.sin(math.pi * phase / share)
end

--[=[
	A locker door's turn (degrees) `t` seconds into a rattle: a fast jiggle dying away, then still.
]=]
function DepotIdleRules.rattle(t: number): number
	local r = IDLE.RATTLE
	if t <= 0 or t > r.SECONDS then
		return 0
	end
	return r.DEGREES * math.sin(2 * math.pi * r.FREQUENCY * t) * math.exp(-r.DAMPING * t)
end

--[=[
	The bell's little sway (degrees) `t` seconds after a nudge, coming to rest at SWAY.SECONDS.
]=]
function DepotIdleRules.sway(t: number): number
	local w = IDLE.SWAY
	if t <= 0 or t >= w.SECONDS then
		return 0
	end
	return w.DEGREES * math.sin(2 * math.pi * w.FREQUENCY * t) * (1 - t / w.SECONDS)
end

--[=[
	The time clock's second hand (degrees about its face, clockwise negative) at `seconds`: one 6-degree step a second.
]=]
function DepotIdleRules.tick(seconds: number): number
	local step = math.floor(seconds % 60)
	return if step == 0 then 0 else -6 * step
end

--[=[
	How far a dropped can has fallen (studs) `t` seconds after it drops, stopping at the tray (FALL.DISTANCE).
]=]
function DepotIdleRules.fall(t: number): number
	return math.min(IDLE.FALL.DISTANCE, 0.5 * IDLE.FALL.GRAVITY * math.max(0, t) ^ 2)
end

--[=[
	Whether the can has landed `t` seconds after it dropped.
]=]
function DepotIdleRules.fallDone(t: number): boolean
	return DepotIdleRules.fall(t) >= IDLE.FALL.DISTANCE
end

--[=[
	A vended item `t` seconds after its turn comes (IDLE.VEND; owner 11-12: the machine dropped a spinning can): first
	nudged `forward` off its shelf over PUSH_SECONDS, then falling `fallen` studs under FALL.GRAVITY to the tray `drop`
	studs below, tipping forward `tip` degrees as it falls (never a spin); `done` once it lies in the tray.
]=]
function DepotIdleRules.vend(t: number, drop: number): (number, number, number, boolean)
	local VEND = IDLE.VEND
	local push = math.clamp(t / VEND.PUSH_SECONDS, 0, 1)
	local forward = VEND.PUSH * (1 - (1 - push) ^ 2)
	if t < VEND.PUSH_SECONDS then
		return forward, 0, 0, false
	end
	local falling = t - VEND.PUSH_SECONDS
	local height = math.max(0, drop)
	local fallen = math.min(height, 0.5 * IDLE.FALL.GRAVITY * falling * falling)
	local share = if height > 0 then fallen / height else 1
	return VEND.PUSH, fallen, VEND.TIP * share, fallen >= height
end

return DepotIdleRules
