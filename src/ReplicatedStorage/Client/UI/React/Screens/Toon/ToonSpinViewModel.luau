--!strict
--[=[
	ToonSpinViewModel: the maths of a player spinning a preview model (owner, 2026-11-14: spin characters, skins and
	vacuums in the shop and inventory previews yourself). The model turns with a mouse or finger drag across its
	frame, keeps coasting a little after a flick and slows to a stop, and turns while a controller stick is pushed.
	`angle` is the model's yaw in degrees (positive = the front turns to the screen's right), kept within one turn.
	Pure: every call returns a new state. ToonViewport reads the input and turns the model (never the camera or the
	platform) by the angle about its own root (`turn`), with the camera fitted once to `around`.

	@class ToonSpinViewModel
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local EmployeePoseFormulas = require(ReplicatedStorage.Shared.Features.Employee.Utils.EmployeePoseFormulas)

local ToonSpinViewModel = {}

export type State = {
	angle: number,
	-- Degrees per second while coasting after a flick (0 while held or at rest).
	velocity: number,
	dragging: boolean,
}

-- Degrees the model turns for a drag across the whole width of its frame.
ToonSpinViewModel.DRAG_TURN = 180
-- Degrees per second with the stick pushed all the way.
ToonSpinViewModel.STICK_SPEED = 160
-- How far the stick must be pushed (0-1) before it turns the model.
ToonSpinViewModel.STICK_DEAD = 0.2
-- The fastest a flick sets the model coasting (degrees per second).
ToonSpinViewModel.MAX_COAST = 540
-- How quickly coasting slows (per second), and the speed it stops below.
local COAST_DRAG = 4
local MIN_COAST = 5

local function wrap(angle: number): number
	return (angle + 180) % 360 - 180
end

--[=[
	The box a camera fits so a model turning round the upright axis through `root` stays whole and centred at every
	angle (owner, 2026-11-14: the model must turn about its own centre, never drift off-centre): square round the axis,
	as wide as the box's furthest corner from it, the same height.
]=]
function ToonSpinViewModel.around(bounds: EmployeePoseFormulas.Bounds, root: Vector3): EmployeePoseFormulas.Bounds
	local reach = 0
	for _, x in { bounds.min.X, bounds.max.X } do
		for _, z in { bounds.min.Z, bounds.max.Z } do
			reach = math.max(reach, Vector2.new(x - root.X, z - root.Z).Magnitude)
		end
	end
	return {
		min = Vector3.new(root.X - reach, bounds.min.Y, root.Z - reach),
		max = Vector3.new(root.X + reach, bounds.max.Y, root.Z + reach),
	}
end

-- How far a preview's clips can carry the model and its props round its root (EmployeePreviewSystem.reachOf): the
-- furthest sideways, and the highest and lowest (studs from the root).
export type Reach = { radius: number, top: number, bottom: number }

--[=[
	The box a spinning preview's camera is fitted to ONCE (owner, 2026-11-14: no zoom while you look at an item): the
	model at rest round its root (`around`), grown to everywhere its clips and props reach at any angle (`reach`,
	measured over the whole idle, fidget and menu reaction). It never shrinks below the rest pose.
]=]
function ToonSpinViewModel.reach(
	bounds: EmployeePoseFormulas.Bounds,
	root: Vector3,
	reach: Reach?
): EmployeePoseFormulas.Bounds
	local rest = ToonSpinViewModel.around(bounds, root)
	if reach == nil then
		return rest
	end
	local r = math.max(rest.max.X - root.X, reach.radius)
	return {
		min = Vector3.new(root.X - r, math.min(rest.min.Y, root.Y + reach.bottom), root.Z - r),
		max = Vector3.new(root.X + r, math.max(rest.max.Y, root.Y + reach.top), root.Z + r),
	}
end

--[=[
	`home` (a model's pivot at rest) turned `degrees` round the upright axis through `root`.
]=]
function ToonSpinViewModel.turn(home: CFrame, root: Vector3, degrees: number): CFrame
	local axis = Vector3.new(root.X, 0, root.Z)
	return CFrame.new(axis) * CFrame.Angles(0, math.rad(degrees), 0) * CFrame.new(-axis) * home
end

function ToonSpinViewModel.new(): State
	return { angle = 0, velocity = 0, dragging = false }
end

--[=[
	The pointer moved `dx` pixels in `dt` seconds across a frame `width` pixels wide.
]=]
function ToonSpinViewModel.drag(state: State, dx: number, width: number, dt: number): State
	if width <= 0 then
		return { angle = state.angle, velocity = 0, dragging = true }
	end
	local turn = dx / width * ToonSpinViewModel.DRAG_TURN
	return {
		angle = wrap(state.angle + turn),
		-- The last move's speed: a drag that stopped before letting go does not coast.
		velocity = if dt > 0 then turn / dt else 0,
		dragging = true,
	}
end

--[=[
	The pointer let go: the model coasts at the last move's speed (capped).
]=]
function ToonSpinViewModel.release(state: State): State
	local cap = ToonSpinViewModel.MAX_COAST
	return { angle = state.angle, velocity = math.clamp(state.velocity, -cap, cap), dragging = false }
end

--[=[
	One frame of `dt` seconds with the stick at `stick` (-1 to 1, 0 = none): the stick turns the model, else a flick
	coasts and slows. A held drag does not move on its own.
]=]
function ToonSpinViewModel.step(state: State, dt: number, stick: number): State
	if state.dragging then
		return state
	end
	local dead = ToonSpinViewModel.STICK_DEAD
	if math.abs(stick) > dead then
		local push = math.sign(stick) * (math.min(math.abs(stick), 1) - dead) / (1 - dead)
		return {
			angle = wrap(state.angle + push * ToonSpinViewModel.STICK_SPEED * dt),
			velocity = 0,
			dragging = false,
		}
	end
	if state.velocity == 0 then
		return state
	end
	local velocity = state.velocity * math.exp(-COAST_DRAG * dt)
	return {
		angle = wrap(state.angle + state.velocity * dt),
		velocity = if math.abs(velocity) < MIN_COAST then 0 else velocity,
		dragging = false,
	}
end

return ToonSpinViewModel
