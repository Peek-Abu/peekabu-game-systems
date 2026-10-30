--!strict
--[=[
	EmployeeStageFormulas: the maths of the 3D preview stage (EmployeeStageSystem; owner, 2026-10-29: a shop or
	inventory emote preview shows the real effects, which a ViewportFrame cannot draw).

	- `camera(bounds, rect, screen, fov, front)`: a camera frame (vertical field of view `fov` degrees, the screen `screen`
	  pixels) that shows the model, whose box in `front`'s space is `bounds`, from its front (`front`.LookVector), its
	  centre on the centre of the window `rect` (pixels, the screen's top-left at 0, 0) and FILL of the window's height
	  (or width, whichever is tighter) on the model. The camera looks straight back along the model's front and is slid
	  sideways, so the model lands off the screen's centre without being seen at an angle.
	- `wall(camera, screen, fov, distance)`: the frame and size of a wall `distance` studs ahead of the camera, facing it,
	  that fills the whole screen (the menu's backdrop is drawn on it, so the screen looks as before).
	- `LIGHTING`: the Lighting the stage is shown under (owner, 2026-10-29: under the place's own, a skin read dark at
	  night and washed out under its Bloom): flat and bright like the old ViewportFrame previews, with no shadows, fog
	  or sky light, so it looks the same in every place at every time of day and is right from the first frame.
	- `restore(saved, now)`: which Lighting values to put back when the stage closes: each saved value whose property
	  still holds the stage's (one the place changed meanwhile, e.g. its time of day, is kept).

	@class EmployeeStageFormulas
]=]

export type Bounds = { min: Vector3, max: Vector3 }
export type Rect = { position: Vector2, size: Vector2 }

-- The share of the window the model fills; a little room round it.
local FILL = 0.82
-- The wall is drawn this much larger than the screen, so no edge ever shows.
local WALL_MARGIN = 1.02

export type LightValue = number | boolean | Color3

-- Lighting properties (all writable by a LocalScript) and the stage's values.
local lighting: { [string]: LightValue } = {
	ClockTime = 14,
	Brightness = 1.5,
	Ambient = Color3.fromRGB(165, 160, 170),
	OutdoorAmbient = Color3.fromRGB(165, 160, 170),
	ExposureCompensation = 0,
	EnvironmentDiffuseScale = 0,
	EnvironmentSpecularScale = 0.3,
	GlobalShadows = false,
	FogStart = 100000,
	FogEnd = 100000,
}
local LIGHTING = table.freeze(lighting)

local EmployeeStageFormulas = {
	FILL = FILL,
	LIGHTING = LIGHTING,
}

-- Equal as Lighting reads them back (float32: a written 1.5 or a colour can come back a hair off).
local function same(a: LightValue?, b: LightValue?): boolean
	if type(a) == "number" and type(b) == "number" then
		return math.abs(a - b) < 1e-3
	elseif typeof(a) == "Color3" and typeof(b) == "Color3" then
		return math.abs(a.R - b.R) < 1 / 255 and math.abs(a.G - b.G) < 1 / 255 and math.abs(a.B - b.B) < 1 / 255
	end
	return a == b
end

function EmployeeStageFormulas.restore(
	saved: { [string]: LightValue },
	now: { [string]: LightValue }
): { [string]: LightValue }
	local back: { [string]: LightValue } = {}
	for name, value in saved do
		if same(now[name], LIGHTING[name]) then
			back[name] = value
		end
	end
	return back
end

function EmployeeStageFormulas.camera(bounds: Bounds, rect: Rect, screen: Vector2, fov: number, front: CFrame): CFrame
	local t = math.tan(math.rad(fov) / 2)
	local aspect = screen.X / screen.Y
	local size = bounds.max - bounds.min
	local byHeight = size.Y * screen.Y / (2 * t * FILL * rect.size.Y)
	local byWidth = size.X * screen.X / (2 * t * aspect * FILL * rect.size.X)
	local distance = math.max(byHeight, byWidth)
	local centre = front:PointToWorldSpace((bounds.min + bounds.max) / 2)
	local look = CFrame.lookAt(Vector3.zero, -front.LookVector, front.UpVector)
	local middle = rect.position + rect.size / 2
	local nx = (middle.X / screen.X - 0.5) * 2
	local ny = (0.5 - middle.Y / screen.Y) * 2
	local position = centre
		+ front.LookVector * distance
		- look.RightVector * (nx * t * aspect * distance)
		- look.UpVector * (ny * t * distance)
	return CFrame.new(position) * look
end

function EmployeeStageFormulas.wall(camera: CFrame, screen: Vector2, fov: number, distance: number): (CFrame, Vector2)
	local height = 2 * distance * math.tan(math.rad(fov) / 2) * WALL_MARGIN
	local centre = camera.Position + camera.LookVector * distance
	return CFrame.lookAt(centre, centre - camera.LookVector, camera.UpVector),
		Vector2.new(height * screen.X / screen.Y, height)
end

return table.freeze(EmployeeStageFormulas)
