--!strict
--[=[
	OccupantGestureFormulas: the Manager's procedural gestures (docs/superpowers/specs/2026-10-15-cleanup-crew-manager-
	behaviours-design.md §1–§3, §6), laid over whatever his clips play on each joint (OccupantGestureSystem multiplies
	these offsets onto the Motor6D Transforms every step):

	- "swivel": the head turns on the long neck to the ambush point (`yawTo` aims it, from the UpperTorso);
	- "peek": the stare's check, bending down to look under the furniture;
	- "under": the sit-in, his head tipping down beside his knees, upside down, under the desk;
	- "perch": a perch kind's owl crouch up on a perch, and "drop" its keyed leap, squash and rise off one (B4);
	  `legDrop` / `crouchDrop` say how far a crouch lowers the hips and `jointAt` follows one joint along a keyed path,
	  so the server keeps the feet on the top and on the floor;
	- "" lets go.

	`pose` is a gesture's joint offsets, `progress` its eased settle (quad out) over its seconds (GESTURE_RELEASE for
	""), `blend` moves from one set of offsets to another, and `tilt` is the catch's head roll (with a small shiver),
	layered on the Neck. A keyed gesture (OccupantConstants.Gesture `keys`: the peek and the sit-in) follows a path
	instead (`along`: its offsets and how far back his body is drawn, `t` of the way; `exit` the path back to rest), shaped
	so his head never passes through the furniture. `overlaps` tells whether two boxes meet (OccupantClearanceSystem).
	Pure.

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
	from there: `stared`; "peekMirror" from the spot's other side, `mirrored`), else none.
]=]
function OccupantGestureFormulas.gestureFor(
	mode: string,
	phase: string?,
	swivelling: boolean,
	sitIn: boolean,
	stared: boolean,
	mirrored: boolean?,
	landing: boolean?
): string
	local peek = if mirrored == true then "peekMirror" else "peek"
	-- A perch kind up on a perch, and dropping off one (B4).
	if mode == "perch" then
		return "perch"
	end
	if landing == true then
		return "drop"
	end
	if swivelling then
		-- The slow turns (behaviours design §11): slowly through the turn and the stare, a whip through the jerk.
		if phase == "slowTurn" or phase == "staring" then
			return "slowSwivel"
		elseif phase == "jerk" then
			return "whip"
		end
		return "swivel"
	end
	if mode == "work" and (phase == "tip" or phase == "tipHold") then
		return "under"
	end
	if mode == "stare" and phase == "check" then
		return peek
	end
	if mode == "catch" then
		return if sitIn then "under" elseif stared then peek else ""
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

local function rotations(joints: { [string]: Vector3 }): Offsets
	local offsets: Offsets = {}
	for joint, degrees in joints do
		offsets[joint] = rotation(degrees)
	end
	return offsets
end

local function smooth(t: number): number
	local x = math.clamp(t, 0, 1)
	return x * x * (3 - 2 * x)
end

-- A point on a keyed path: the joints (degrees) and how far back.
export type Waypoint = { back: number, joints: { [string]: Vector3 } }

local REST: Waypoint = { back = 0, joints = {} }

--[=[
	The pose `t` (0..1) of the way along `keys` from `start` (default rest): the joint offsets and how far back his body
	is drawn (studs). Each key is reached at its `at`, smoothstepped from the one before; past the last, the last.
]=]
function OccupantGestureFormulas.along(
	keys: { OccupantConstants.GestureKey },
	t: number,
	start: Waypoint?
): (Offsets, number)
	local previous: Waypoint = start or REST
	local previousAt = 0
	for _, key in keys do
		if t <= key.at then
			local span = key.at - previousAt
			local alpha = smooth(if span > 0 then (t - previousAt) / span else 1)
			local offsets = OccupantGestureFormulas.blend(rotations(previous.joints), rotations(key.joints), alpha)
			return offsets, previous.back + (key.back - previous.back) * alpha
		end
		previous = { back = key.back, joints = key.joints }
		previousAt = key.at
	end
	return rotations(previous.joints), previous.back
end

--[=[
	One joint's rotation (degrees) `t` (0..1) of the way along `keys`, from rest: the same smoothstepped path `along`
	takes (a joint a key leaves out is at rest there). The server follows the drop's legs with it.
]=]
function OccupantGestureFormulas.jointAt(keys: { OccupantConstants.GestureKey }, t: number, joint: string): Vector3
	local previous: Vector3 = Vector3.zero
	local previousAt = 0
	for _, key in keys do
		local value: Vector3 = key.joints[joint] or Vector3.zero
		if t <= key.at then
			local span = key.at - previousAt
			local alpha = smooth(if span > 0 then (t - previousAt) / span else 1)
			return previous:Lerp(value, alpha)
		end
		previous = value
		previousAt = key.at
	end
	return previous
end

--[=[
	How far (studs) a leg of a `thigh` and a `shin` (hip to knee, knee to ankle), hanging straight at rest, lowers the
	hip when the hip swings the thigh `hip` degrees forward and the knee folds the shin `knee` degrees (negative: back).
]=]
function OccupantGestureFormulas.legDrop(thigh: number, shin: number, hip: number, knee: number): number
	return thigh * (1 - math.cos(math.rad(hip))) + shin * (1 - math.cos(math.rad(hip + knee)))
end

--[=[
	The leg drop of a pose (its LeftHip and LeftKnee; the poses bend both legs alike): how far the root comes down so
	the feet stay where they stood.
]=]
function OccupantGestureFormulas.crouchDrop(thigh: number, shin: number, joints: { [string]: Vector3 }): number
	-- (The table's type says every key is there; a pose may leave either out.)
	local hip: Vector3? = joints.LeftHip
	local knee: Vector3? = joints.LeftKnee
	return OccupantGestureFormulas.legDrop(
		thigh,
		shin,
		if hip ~= nil then hip.X else 0,
		if knee ~= nil then knee.X else 0
	)
end

--[=[
	A keyed gesture's path in and its seconds (nil for a plain blend).
]=]
function OccupantGestureFormulas.keyed(gesture: string): ({ OccupantConstants.GestureKey }?, number)
	local def = OccupantConstants.GESTURES[gesture]
	if def == nil then
		return nil, OccupantConstants.GESTURE_RELEASE
	end
	return def.keys, def.seconds
end

--[=[
	The path back to rest out of a keyed gesture, its seconds and where it starts (the last key); nil for any other.
]=]
function OccupantGestureFormulas.exit(gesture: string): ({ OccupantConstants.GestureKey }?, number, Waypoint)
	local def = OccupantConstants.GESTURES[gesture]
	local keys = if def ~= nil then def.keys else nil
	if def == nil or def.exit == nil or keys == nil or #keys == 0 then
		return nil, 0, REST
	end
	local last = keys[#keys]
	return def.exit, def.exitSeconds or OccupantConstants.GESTURE_RELEASE, { back = last.back, joints = last.joints }
end

export type Box = { cframe: CFrame, size: Vector3 }

--[=[
	Whether two boxes meet (separating axes), each shrunk by `margin` studs a side first, so a touch is not a meeting.
]=]
function OccupantGestureFormulas.overlaps(a: Box, b: Box, margin: number): boolean
	local axes = { a.cframe.RightVector, a.cframe.UpVector, a.cframe.LookVector }
	local others = { b.cframe.RightVector, b.cframe.UpVector, b.cframe.LookVector }
	for _, axis in others do
		table.insert(axes, axis)
	end
	for i = 1, 3 do
		for j = 4, 6 do
			local cross = axes[i]:Cross(axes[j])
			if cross.Magnitude > 1e-4 then
				table.insert(axes, cross.Unit)
			end
		end
	end
	local function radius(box: Box, axis: Vector3): number
		local half = box.size / 2 - Vector3.one * margin
		local x, y, z = math.max(half.X, 0), math.max(half.Y, 0), math.max(half.Z, 0)
		local frame = box.cframe
		return math.abs(frame.RightVector:Dot(axis)) * x
			+ math.abs(frame.UpVector:Dot(axis)) * y
			+ math.abs(frame.LookVector:Dot(axis)) * z
	end
	local between = b.cframe.Position - a.cframe.Position
	for _, axis in axes do
		if math.abs(between:Dot(axis)) > radius(a, axis) + radius(b, axis) then
			return false
		end
	end
	return true
end

-- The gestures that share one turn fraction (a whip carries a slow turn on from where it got to).
local TURNING: { [string]: boolean } = { slowSwivel = true, whip = true }

--[=[
	Whether `gesture` is a slow turn's (behaviours design §11): its pose is `turnPose` at a carried turn fraction.
]=]
function OccupantGestureFormulas.turning(gesture: string): boolean
	return TURNING[gesture] == true
end

--[=[
	The turn fraction (0..1) `dt` seconds on from `turned` at `gesture`'s pace (its seconds for a whole turn).
]=]
function OccupantGestureFormulas.advance(turned: number, gesture: string, dt: number): number
	local def = OccupantConstants.GESTURES[gesture]
	local seconds = if def ~= nil then def.seconds else OccupantConstants.GESTURE_RELEASE
	if seconds <= 0 then
		return 1
	end
	return math.clamp(turned + dt / seconds, 0, 1)
end

local function smoother(t: number): number
	local x = math.clamp(t, 0, 1)
	return x * x * x * (x * (x * 6 - 15) + 10)
end

--[=[
	A slow turn's pose `turned` (0..1) of the way to `total` (radians, the yaw to the target from his lower body): the
	head's yaw smootherstepped, his waist taking SLOW_WAIST_SHARE of it (all of that by SLOW_WAIST_LEAD of the turn) and
	the neck the rest, so his shoulders come round first and the smile last.
]=]
function OccupantGestureFormulas.turnPose(total: number, turned: number): Offsets
	local lead = OccupantConstants.SLOW_WAIST_LEAD
	local waist = total * OccupantConstants.SLOW_WAIST_SHARE * smooth(if lead > 0 then turned / lead else 1)
	local head = total * smoother(turned)
	local offsets: Offsets = {}
	offsets.Waist = CFrame.Angles(0, waist, 0)
	offsets.Neck = CFrame.Angles(0, head - waist, 0)
	return offsets
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
