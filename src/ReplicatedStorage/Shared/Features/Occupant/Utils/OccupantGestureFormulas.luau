--!strict
--[=[
	OccupantGestureFormulas: the Manager's procedural gestures (docs/superpowers/specs/2026-10-15-cleanup-crew-manager-
	behaviours-design.md §1–§3, §6), laid over whatever his clips play on each joint (OccupantGestureSystem multiplies
	these offsets onto the Motor6D Transforms every step):

	- "swivel": the head turns on the long neck to the ambush point (`yawTo` aims it, from the UpperTorso);
	- "peek": the stare's check, bending down to look under the furniture;
	- "under": the sit-in, his head tipping down beside his knees, upside down, under the desk;
	- "" lets go.

	`pose` is a gesture's joint offsets, `progress` its eased settle (quad out) over its seconds (GESTURE_RELEASE for
	""), `blend` moves from one set of offsets to another, and `tilt` is the catch's head roll (with a small shiver),
	layered on the Neck. Pure.

	@class OccupantGestureFormulas
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local OccupantConstants = require(ReplicatedStorage.Shared.Features.Occupant.Data.OccupantConstants)

export type Offsets = { [string]: CFrame? }

local function rotation(degrees: Vector3): CFrame
	return CFrame.Angles(math.rad(degrees.X), math.rad(degrees.Y), math.rad(degrees.Z))
end

local OccupantGestureFormulas = {}

--[=[
	Which gesture he shows: the swivel while his head is turned to an ambush point (`swivelling`), "under" while a
	sit-in tips his head down (and through a catch from there: `sitIn`), "peek" while a stare checks (and through a catch
	from there: `stared`), else none.
]=]
function OccupantGestureFormulas.gestureFor(
	mode: string,
	phase: string?,
	swivelling: boolean,
	sitIn: boolean,
	stared: boolean
): string
	if swivelling then
		return "swivel"
	end
	if mode == "work" and (phase == "tip" or phase == "tipHold") then
		return "under"
	end
	if mode == "stare" and phase == "check" then
		return "peek"
	end
	if mode == "catch" then
		return if sitIn then "under" elseif stared then "peek" else ""
	end
	return ""
end

function OccupantGestureFormulas.pose(gesture: string, yaw: number): Offsets
	local offsets: Offsets = {}
	if gesture == "swivel" then
		offsets.Neck = CFrame.Angles(0, yaw, 0)
		return offsets
	end
	local def = OccupantConstants.GESTURES[gesture]
	if def ~= nil then
		for joint, degrees in def.joints do
			offsets[joint] = rotation(degrees)
		end
	end
	return offsets
end

function OccupantGestureFormulas.progress(gesture: string, elapsed: number): number
	local def = OccupantConstants.GESTURES[gesture]
	local seconds = if def ~= nil then def.seconds else OccupantConstants.GESTURE_RELEASE
	local t = if seconds > 0 then math.clamp(elapsed / seconds, 0, 1) else 1
	return 1 - (1 - t) * (1 - t)
end

function OccupantGestureFormulas.blend(from: Offsets, to: Offsets, alpha: number): Offsets
	local weight = math.clamp(alpha, 0, 1)
	local result: Offsets = {}
	for joint, start in from do
		if start ~= nil then
			result[joint] = start:Lerp(to[joint] or CFrame.identity, weight)
		end
	end
	for joint, finish in to do
		if finish ~= nil and from[joint] == nil then
			result[joint] = CFrame.new():Lerp(finish, weight)
		end
	end
	return result
end

--[=[
	The yaw (radians, about the torso's up) that turns the torso's forward (-Z) toward `target`.
]=]
function OccupantGestureFormulas.yawTo(torso: CFrame, target: Vector3): number
	local offset = torso:PointToObjectSpace(target)
	if Vector3.new(offset.X, 0, offset.Z).Magnitude < 1e-4 then
		return 0
	end
	return math.atan2(-offset.X, -offset.Z)
end

--[=[
	The catch's head roll `elapsed` seconds in (eased to TILT_DEGREES over TILT_SECONDS); `shiver` adds a small tremble.
]=]
function OccupantGestureFormulas.tilt(elapsed: number, shiver: boolean): CFrame
	local t = math.clamp(elapsed / OccupantConstants.TILT_SECONDS, 0, 1)
	local eased = 1 - (1 - t) * (1 - t)
	local degrees = OccupantConstants.TILT_DEGREES * eased
	if shiver then
		degrees += math.sin(elapsed * 40) * OccupantConstants.TILT_SHIVER * t
	end
	return CFrame.Angles(0, 0, math.rad(degrees))
end

return OccupantGestureFormulas
