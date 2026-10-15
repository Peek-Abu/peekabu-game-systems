--!strict
--[=[
	AnimationCarrySurfaceUtils: where a palm goes on an item's REAL surface (AnimationTypes.CarryItem's probe), never
	on the box round it: under its bottom (`support`), on its lower side (`cup`), flat on its face toward the carrier
	(`face`), and the top of it (`top`, for a handle-less item hung from the fist). Each searches from where the hold
	wants the palm in toward the middle (and under / up and down a little) and takes the first spot squarely facing
	the palm, else the squarest that still faces it. Contacts are palm frames in the item's box space: UpVector into
	the item, LookVector the fingers.

	@class AnimationCarrySurfaceUtils
]=]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local AnimationTypes = require(ReplicatedStorage.Shared.Features.Animation.Data.AnimationTypes)

type Item = AnimationTypes.CarryItem

-- A palm's support: found within this fraction of the item's height from its bottom (at most SUPPORT_BAND_MAX), on a
-- surface facing down at least SUPPORT_FACING (the cosine from straight down); SUPPORT_FLAT counts as flat enough to
-- rest on. Searched in SUPPORT_STEPS toward the middle at each of SUPPORT_DEPTHS depths under it. The palm faces into
-- it, tilted at most PALM_TILT from straight up (or square to a pushed face).
local SUPPORT_BAND = 0.4
local SUPPORT_BAND_MAX = 0.6
local SUPPORT_FACING = 0.3
local SUPPORT_FLAT = 0.7
local SUPPORT_STEPS = 6
local SUPPORT_DEPTHS = 3
-- Cupping a lower side (a sack too tall to ride on its bottom, a pot too narrow to get under): how squarely the side
-- must face out (flat enough; at least).
local CUP_FLAT = 0.55
local CUP_FACING = 0.4
local PALM_TILT = math.rad(60)
-- A pushed face: found facing the carrier at least PUSH_FACING (FACE_FLAT counts as square), at the wanted height
-- and each of FACE_RISES above and below it.
local PUSH_FACING = 0.5
local FACE_FLAT = 0.85
local FACE_RISES = { 0, 0.15, -0.15, 0.3, -0.3 }
-- A pushing palm's centre stays at least this far inside the face's top and bottom.
local FACE_EDGE = 0.3
-- How far a pushing hand's fingers turn in from straight up (tan of the angle: 1 is 45 degrees).
local PUSH_TURN_IN = 1

local AnimationCarrySurfaceUtils = {}

-- A palm frame at `at`: facing `up` (into the item), fingers as near `fingers` as that allows.
local function palmAt(at: Vector3, up: Vector3, fingers: Vector3): CFrame
	local along = fingers - up * fingers:Dot(up)
	local look = if along.Magnitude > 1e-6 then along.Unit else up:Cross(Vector3.xAxis).Unit
	return CFrame.fromMatrix(at, up:Cross(-look), up, -look)
end

-- `up` turned toward `limit` until it is within `max` radians of it.
local function tiltLimited(up: Vector3, limit: Vector3, max: number): Vector3
	local angle = math.acos(math.clamp(up:Dot(limit), -1, 1))
	if angle <= max then
		return up
	end
	local axis = limit:Cross(up)
	if axis.Magnitude < 1e-6 then
		return limit
	end
	return CFrame.fromAxisAngle(axis.Unit, max):VectorToWorldSpace(limit)
end

-- The best of the surface points the probe finds from `origins` along `along`: the first (in order) facing `axis` at
-- least `flat`, else the one facing it most, at least `least`. The palm faces into it, tilted at most PALM_TILT
-- off `axis`, fingers toward `fingers`.
local function pick(
	item: Item,
	origins: { Vector3 },
	along: Vector3,
	axis: Vector3,
	flat: number,
	least: number,
	fingers: Vector3
): CFrame?
	local best: Vector3? = nil
	local bestNormal = Vector3.zero
	local bestFacing = least
	for _, from in origins do
		local hit, normal = item.probe(from, along)
		if hit ~= nil and normal ~= nil then
			local facing = normal:Dot(-axis)
			if facing >= flat then
				return palmAt(hit, tiltLimited(-normal, axis, PALM_TILT), fingers)
			elseif facing >= bestFacing then
				best, bestNormal, bestFacing = hit, normal, facing
			end
		end
	end
	return if best ~= nil then palmAt(best, tiltLimited(-bestNormal, axis, PALM_TILT), fingers) else nil
end

--[=[
	The palm frame (box space) supporting `item` from below near (`x`, `z`): on the real bottom surface found by the
	probe, within the lower part of the item. Tried from (`x`, `z`) further under, then in toward the middle: the first
	spot flat enough to rest on (a box's bottom, a sack's flat base), else the flattest that still faces down (a round
	bottom's curve). Palm up into it, fingers forward. Nil when nothing faces down there.
]=]
function AnimationCarrySurfaceUtils.support(item: Item, x: number, z: number): CFrame?
	local size = item.size
	local band = math.min(size.Y * SUPPORT_BAND, SUPPORT_BAND_MAX) + 0.5
	local origins: { Vector3 } = {}
	for step = 0, SUPPORT_STEPS do
		for deeper = 0, SUPPORT_DEPTHS - 1 do
			local depth = z - (z + size.Z / 2) * 0.5 * deeper / math.max(SUPPORT_DEPTHS - 1, 1)
			table.insert(origins, Vector3.new(x * (1 - 0.85 * step / SUPPORT_STEPS), -size.Y / 2 - 0.5, depth))
		end
	end
	return pick(item, origins, Vector3.new(0, band, 0), Vector3.yAxis, SUPPORT_FLAT, SUPPORT_FACING, -Vector3.zAxis)
end

--[=[
	The palm frame (box space) cupping `item`'s `side` (1 right, -1 left) at height `y`, from `z` further under: the
	real side surface found by the probe from outside, the first spot facing out squarely enough, else the squarest.
	Palm in (tilted up where the side curves under), fingers forward.
]=]
function AnimationCarrySurfaceUtils.cup(item: Item, side: number, y: number, z: number): CFrame?
	local size = item.size
	local origins: { Vector3 } = {}
	for deeper = 0, SUPPORT_DEPTHS - 1 do
		local depth = z - (z + size.Z / 2) * 0.5 * deeper / math.max(SUPPORT_DEPTHS - 1, 1)
		table.insert(origins, Vector3.new(side * (size.X / 2 + 0.5), y, depth))
	end
	return pick(
		item,
		origins,
		Vector3.new(-side * (size.X + 1), 0, 0),
		Vector3.new(-side, 0, 0),
		CUP_FLAT,
		CUP_FACING,
		-Vector3.zAxis
	)
end

--[=[
	The palm frame (box space) flat on `item`'s face toward the carrier (+Z) near (`x`, `y`), for `side`'s hand (1
	right, -1 left): found by the probe, tried from there in toward the middle and a little up and down; the first spot
	facing the carrier squarely, else the squarest. Palm into it, fingers up and turned in (the way hands push a box:
	the forearms angle in, so the wrists bend less and the forearms roll less than fingers straight up need).
]=]
function AnimationCarrySurfaceUtils.face(item: Item, x: number, y: number, side: number): CFrame?
	local size = item.size
	-- Never so near the top or bottom edge that the palm hangs off it.
	local edge = math.min(FACE_EDGE, size.Y / 4)
	local origins: { Vector3 } = {}
	for _, rise in FACE_RISES do
		local height = math.clamp(y + rise, -size.Y / 2 + edge, size.Y / 2 - edge)
		for step = 0, SUPPORT_STEPS do
			table.insert(origins, Vector3.new(x * (1 - 0.85 * step / SUPPORT_STEPS), height, size.Z / 2 + 0.5))
		end
	end
	local fingers = Vector3.new(-side * PUSH_TURN_IN, 1, 0).Unit
	return pick(item, origins, Vector3.new(0, 0, -(size.Z + 1)), -Vector3.zAxis, FACE_FLAT, PUSH_FACING, fingers)
end

--[=[
	The top of the item's real surface above its middle (box space), else the box's top.
]=]
function AnimationCarrySurfaceUtils.top(item: Item): Vector3
	local size = item.size
	local hit = item.probe(Vector3.new(0, size.Y / 2 + 0.5, 0), Vector3.new(0, -(size.Y + 1), 0))
	return hit or Vector3.new(0, size.Y / 2, 0)
end

return table.freeze(AnimationCarrySurfaceUtils)
