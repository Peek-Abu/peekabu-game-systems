--!strict
--[=[
	ToonSpinViewModel: the maths of a player spinning a preview model (owner, 2026-11-14: spin characters, skins and
	vacuums in the shop and inventory previews yourself). The model turns with a mouse or finger drag across its
	frame, keeps coasting a little after a flick and slows to a stop, and turns while a controller stick is pushed.
	`angle` is the model's yaw in degrees (positive = the front turns to the screen's right), kept within one turn.
	Pure: every call returns a new state. ToonViewport reads the input and applies the angle.

	@class ToonSpinViewModel
]=]

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
