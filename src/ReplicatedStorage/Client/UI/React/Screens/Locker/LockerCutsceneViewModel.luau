--!strict
--[=[
	LockerCutsceneViewModel: the Locker opening's 3D cutscene worked out as pure numbers: the timeline (`openingDuration`),
	how each rarity plays its opening (`RARITY_FX`) and where the camera, employee, key and door are at any moment
	(`cutscenePose`). Split out of LockerViewModel, which re-exports all of it (callers keep using LockerViewModel).

	@class LockerCutsceneViewModel
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CosmeticTypes = require(ReplicatedStorage.Shared.Features.Cosmetic.Data.CosmeticTypes)
local LockerTypes = require(ReplicatedStorage.Shared.Features.Locker.Data.LockerTypes)

type LockerId = LockerTypes.LockerId
type Rarity = CosmeticTypes.Rarity

export type CutsceneBeat = "establishing" | "approach" | "key_turn" | "rattle" | "burst_open"

-- How a rarity plays its opening (owner picks 11-16: the rarer the prize, the longer the hold before the burst, the
-- harder the rattle and the more and brighter the lights).
export type RarityFx = {
	-- Seconds the shut door rattles, light leaking out, between the key turn and the burst.
	hold: number,
	-- Light shafts leaking from the door's seams.
	lights: number,
	-- The leak's and the burst's light brightness.
	brightness: number,
	-- How far the rattling door jumps open, in degrees.
	rattleDeg: number,
	-- Camera shake at the height of the rattle, in studs.
	shake: number,
	-- Neon rays at the burst.
	rays: number,
	-- How opaque the burst's colour flash gets (0..1).
	flash: number,
	-- The prize chime's layers at the burst (sound ids, LockerAssets).
	chime: { string },
}

export type CutscenePose = {
	beat: CutsceneBeat,
	camPos: Vector3,
	camLook: Vector3,
	fov: number,
	employeeCFrame: CFrame,
	keyCFrame: CFrame,
	keyRollDeg: number,
	doorDeg: number,
	glow: boolean,
	flashTransparency: number,
	-- 0..1: how bright the light leaks out round the shut door (the rattle beat; 1 at the burst).
	leak: number,
	-- 0..1: the leaking light's colour, plain white (0) to the prize's rarity colour (1): white through the hold, the
	-- rarity showing through in the last GLIMPSE_SECONDS before the door opens (owner 11-16).
	leakTint: number,
}

-- Each rarity's prize chime is its own in-house sting (owner rarity-ladder pick 2026-11-17: one orchestral family in F
-- major growing from Common up, Odd a ghostly B minor; LockerAssets). Legendary keeps its two library layers for now:
-- a grander Legendary sting is pending the owner's OK.
local RARITY_FX: { [Rarity]: RarityFx } = {
	default = {
		hold = 0.5,
		lights = 2,
		brightness = 2,
		rattleDeg = 1.5,
		shake = 0,
		rays = 3,
		flash = 0.55,
		chime = { "lockerCommon" },
	},
	uncommon = {
		hold = 0.5,
		lights = 2,
		brightness = 2,
		rattleDeg = 1.5,
		shake = 0,
		rays = 3,
		flash = 0.55,
		chime = { "lockerUncommon" },
	},
	rare = {
		hold = 0.8,
		lights = 3,
		brightness = 3,
		rattleDeg = 2.5,
		shake = 0.02,
		rays = 5,
		flash = 0.65,
		chime = { "lockerRare" },
	},
	epic = {
		hold = 1.2,
		lights = 5,
		brightness = 4.5,
		rattleDeg = 4,
		shake = 0.06,
		rays = 7,
		flash = 0.8,
		chime = { "lockerEpic" },
	},
	legendary = {
		hold = 1.7,
		lights = 8,
		brightness = 7,
		rattleDeg = 6,
		shake = 0.12,
		rays = 10,
		flash = 0.88,
		chime = { "lockerChimeHigh", "lockerChimeAura" },
	},
	odd = {
		hold = 1.7,
		lights = 8,
		brightness = 7,
		rattleDeg = 6,
		shake = 0.12,
		rays = 10,
		flash = 0.88,
		chime = { "lockerOdd" },
	},
}

-- The fixed beats, in seconds; the rattle's hold sits between the key turn and the burst.
local ESTABLISH_SECONDS = 0.8
local APPROACH_SECONDS = 0.9
local KEY_SECONDS = 1.0
local BURST_SECONDS = 0.8
-- The rarity's colour shows through the seams this long before the door opens (owner 11-16: "half a second before
-- the actual locker opens you get a small glimpse of the rarity leaking through").
local GLIMPSE_SECONDS = 0.5
-- How long the leak takes to turn from white to the rarity's colour.
local GLIMPSE_BLEND = 0.15

local Cutscene = {
	BURST_SECONDS = BURST_SECONDS,
	GLIMPSE_SECONDS = GLIMPSE_SECONDS,
	RARITY_FX = RARITY_FX,
}

-- The whole opening's length for a prize of `rarity` (about 4 seconds for Uncommon).
function Cutscene.openingDuration(rarity: Rarity): number
	return ESTABLISH_SECONDS + APPROACH_SECONDS + KEY_SECONDS + RARITY_FX[rarity].hold + BURST_SECONDS
end

--[=[
	The 3D cutscene at `alpha` (0..1 of `Cutscene.openingDuration(rarity)`) for `lockerId`'s Locker (the Gleam Locker sits at
	-X, every other one at +X). Beats: establishing, approach (the key floats in from screen right, away from the
	employee, who only idles: owner 11-16), key_turn,
	rattle (the shut door jumps against its latch, harder and longer the rarer the prize, light in the prize's colour
	leaking round it) and burst_open. Both doors hinge on their -X edge, so the employee waits on the latch side (+X),
	facing the keyhole, and every shot comes from the hinge side: the employee is never between the camera and what it
	looks at (owner check 11-16: the camera sat behind, then inside, the employee's head). `doorDeg` swings the door
	out toward the camera.
]=]
function Cutscene.cutscenePose(lockerId: LockerId, alpha: number, rarity: Rarity?): CutscenePose
	local tier: Rarity = rarity or "uncommon"
	local fx = RARITY_FX[tier]
	local seconds = math.clamp(alpha, 0, 1) * Cutscene.openingDuration(tier)
	local lx = if lockerId == "gleam" then -6.5 else 6.5
	local kx = lx + 0.15
	local keyHole = Vector3.new(kx, 5.2, 3.42)
	local keyFront = Vector3.new(kx, 5.2, 2.25)
	local keyIn = Vector3.new(kx, 5.2, 3.08)
	-- A step aside and back from the latch seam, so the leaking light shows and the burst shot keeps them out of frame
	-- (Play check 11-16).
	local empPos = Vector3.new(lx + 3.4, 3.1, -0.2)
	-- Where the key floats in from: the hinge side (-X), which is screen right in every shot, never the employee.
	local keyStart = Vector3.new(kx - 4.5, 6.4, 0.5)
	local hidden = Vector3.new(kx, -100, 0)

	local rattleAt = ESTABLISH_SECONDS + APPROACH_SECONDS + KEY_SECONDS
	local burstAt = rattleAt + fx.hold

	local beat: CutsceneBeat
	local camPos: Vector3
	local camLook: Vector3
	local fov: number
	local keyPos = hidden
	local keyRollDeg = 0
	local doorDeg = 0
	local glow = false
	local flashTransparency = 1
	local leak = 0
	local leakTint = 0

	if seconds < ESTABLISH_SECONDS then
		beat = "establishing"
		local t = seconds / ESTABLISH_SECONDS
		camPos = Vector3.new(lx - 5.5, 6.6, -9.5):Lerp(Vector3.new(lx - 3.2, 6.0, -6.5), t)
		camLook = Vector3.new(lx - 1, 5.6, 4):Lerp(Vector3.new(lx + 0.5, 5.2, 3.5), t)
		fov = 50 - 4 * t
	elseif seconds < ESTABLISH_SECONDS + APPROACH_SECONDS then
		beat = "approach"
		local t = (seconds - ESTABLISH_SECONDS) / APPROACH_SECONDS
		camPos = Vector3.new(lx - 3.2, 6.0, -6.5):Lerp(Vector3.new(lx - 2.2, 5.6, -3.0), t)
		camLook = Vector3.new(lx + 0.5, 5.2, 3.5):Lerp(keyHole, t)
		fov = 46 - 4 * t
		keyPos = keyStart:Lerp(keyFront, t * t * (3 - 2 * t))
	elseif seconds < rattleAt then
		beat = "key_turn"
		local t = (seconds - ESTABLISH_SECONDS - APPROACH_SECONDS) / KEY_SECONDS
		-- Far enough back that the key and the lock read together (Play check 11-16: the key filled a third of the screen).
		camPos = Vector3.new(kx - 2.0, 5.7, -0.6):Lerp(Vector3.new(kx - 1.6, 5.5, 0.3), t)
		camLook = keyHole
		fov = 40
		if t < 0.45 then
			keyPos = keyFront:Lerp(keyIn, t / 0.45)
		else
			local turn = (t - 0.45) / 0.55
			keyPos = keyIn
			keyRollDeg = math.sin(turn * math.pi * 0.5) * 90
		end
	elseif seconds < burstAt then
		beat = "rattle"
		local t = (seconds - rattleAt) / fx.hold
		-- Builds up: a faint, gentle rattle that grows to the rarity's full shake and glow.
		local grow = 0.25 + 0.75 * t ^ 1.5
		-- From the hinge side, so the employee stands clear of the latch seam where the light leaks (Play check 11-16).
		camPos = Vector3.new(lx - 1.3, 5.6, -5.2):Lerp(Vector3.new(lx - 1.1, 5.7, -4.2), t)
		camLook = Vector3.new(lx, 5.1, 4.0)
		fov = 44
		keyPos = keyIn
		keyRollDeg = 90
		-- The door jumps open against its latch and falls back (0 or more: never into the locker's body).
		doorDeg = fx.rattleDeg * grow * (0.5 + 0.5 * math.sin(seconds * math.pi * 2 * 9))
		leak = grow
		leakTint = math.clamp((seconds - (burstAt - GLIMPSE_SECONDS)) / GLIMPSE_BLEND, 0, 1)
		local shake = fx.shake * grow
		camPos += Vector3.new(math.sin(seconds * 71) * shake, math.sin(seconds * 53 + 1.3) * shake, 0)
	else
		beat = "burst_open"
		local t = math.min(1, (seconds - burstAt) / BURST_SECONDS)
		local swing = 1 - (1 - math.min(1, t * 1.25)) ^ 3
		doorDeg = 115 * swing
		glow = true
		leak = 1
		leakTint = 1
		keyPos = Vector3.new(kx, 5.2, -100)
		camPos = Vector3.new(lx - 0.4, 5.7, -4.2):Lerp(Vector3.new(lx - 0.15, 5.45, -3.0), t)
		camLook = Vector3.new(lx, 5.0, 5.0)
		fov = 44 - 8 * t
		if t > 0.55 then
			local burst = (t - 0.55) / 0.45
			flashTransparency = math.clamp(1 - math.sin(burst * math.pi) * fx.flash, 1 - fx.flash, 1)
		end
	end

	local employeeCFrame = CFrame.lookAt(empPos, Vector3.new(kx, empPos.Y, keyHole.Z))
	local keyCFrame = CFrame.lookAt(keyPos, keyPos + Vector3.new(0, 0, 1)) * CFrame.Angles(0, 0, math.rad(keyRollDeg))

	return {
		beat = beat,
		camPos = camPos,
		camLook = camLook,
		fov = fov,
		employeeCFrame = employeeCFrame,
		keyCFrame = keyCFrame,
		keyRollDeg = keyRollDeg,
		doorDeg = doorDeg,
		glow = glow,
		flashTransparency = flashTransparency,
		leak = leak,
		leakTint = leakTint,
	}
end

return Cutscene
