--!strict
--[=[
	CameraTypes: the types the Camera feature shares. Types only (spec-exempt).

	A ModeDef is a tagged union on `kind` (see the design spec,
	docs/superpowers/specs/2026-10-09-camera-design.md).

	@class CameraTypes
]=]

export type ModeDef =
	{
		-- The engine camera. `firstPerson` locks first person; `subject` spectates (CameraSubject).
		kind: "default",
		firstPerson: boolean?,
		subject: (Humanoid | BasePart)?,
		fov: number?,
	}
	| {
		-- A still shot.
		kind: "fixed",
		cframe: CFrame,
		fov: number?,
	}
	| {
		-- Chase `subject` at `offset` (in the subject's space), smoothed; optionally look at it.
		kind: "follow",
		subject: BasePart,
		offset: CFrame,
		lookAt: boolean?,
		-- Exponential smoothing rate (per second); higher is snappier. Default CameraConstants.FOLLOW_SHARPNESS.
		sharpness: number?,
		fov: number?,
	}
	| {
		-- Anything else: the caller computes the CFrame (and optionally the FOV) each frame.
		kind: "custom",
		update: (dt: number) -> (CFrame, number?),
	}

-- A game-specific additive effect (head bob, sway, lean): an offset applied after the shake.
export type Modifier = (dt: number) -> CFrame

-- One entry on the mode stack (see CameraModeTracker).
export type ModeEntry = {
	token: number,
	priority: number,
	def: ModeDef,
}

-- One active FOV kick (see CameraEffectTracker).
export type FovKick = {
	amount: number,
	duration: number,
	elapsed: number,
}

return {}
