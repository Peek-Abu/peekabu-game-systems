--!strict
--[=[
	VacuumBodyFormulas: the holder's body as the vacuum hold must see it (owner plan A+B+C, 2026-11-16: hands went
	INSIDE the body). Pure.

	- `box`: the chest as a player sees it, the union of the torso part and every clothing piece worn on it (Cappy's
	  hoodie is a separate piece round a thin torso part; every guard used to measure the bare part only).
	- `pivot`: the point between the two paws (owner plan C; shipped off, VacuumMotionConstants.turnAboutPaws: turning
	  about it fought the left paw's reach guard and doubled the turn to aim ahead, vacuum harness 2026-11-16).
	- `follow`: the move that keeps a held point with the chest's sway and turn (the idle swayed Cappy's chest 0.28 stud
	  and 13 degrees under hands pinned to the root), never its tilt or height.

	@class VacuumBodyFormulas
]=]

-- A piece of the body: its frame (in the space the box is wanted in) and its size.
export type Piece = { at: CFrame, size: Vector3 }
export type Box = { centre: Vector3, half: Vector3 }

local VacuumBodyFormulas = {}

--[=[
	The axis-aligned box round every piece (each measured by its eight corners).
]=]
function VacuumBodyFormulas.box(pieces: { Piece }): Box
	local low, high = Vector3.one * math.huge, -Vector3.one * math.huge
	for _, piece in pieces do
		local half = piece.size / 2
		for _, x in { -1, 1 } do
			for _, y in { -1, 1 } do
				for _, z in { -1, 1 } do
					local corner = piece.at * Vector3.new(half.X * x, half.Y * y, half.Z * z)
					low = low:Min(corner)
					high = high:Max(corner)
				end
			end
		end
	end
	return { centre = (low + high) / 2, half = (high - low) / 2 }
end

--[=[
	The wand's turning point: midway between the right paw's grip and the left paw's (the right paw's alone without a
	left paw).
]=]
function VacuumBodyFormulas.pivot(right: Vector3, left: Vector3?): Vector3
	return if left ~= nil then (right + left) / 2 else right
end

--[=[
	The move (root space) that carries a point held to the chest along with the chest's SWAY and TURN from its rest pose
	(`rest`, the pose the hold was planned in) to where it is (`now`): its shift across the floor and its turn about the
	vertical, through the chest (the left shoulder rides the same chest, so its reach to the wand is kept exactly),
	never its tilt or height (the idle's standing lean, followed whole, tipped the wand into the floor and took the
	left paw off it: vacuum harness 2026-11-16). `share` of the way (0: none, 1: all of it).
]=]
function VacuumBodyFormulas.follow(rest: CFrame, now: CFrame, share: number): CFrame
	local shift = now.Position - rest.Position
	local look = (now.Rotation * rest.Rotation:Inverse()).LookVector
	local yaw = if math.abs(look.X) + math.abs(look.Z) > 1e-6 then math.atan2(-look.X, -look.Z) else 0
	local pivot = rest.Position
	local delta = CFrame.new(pivot + Vector3.new(shift.X, 0, shift.Z)) * CFrame.Angles(0, yaw, 0) * CFrame.new(-pivot)
	if share >= 1 then
		return delta
	end
	return CFrame.new():Lerp(delta, math.max(share, 0))
end

return VacuumBodyFormulas
