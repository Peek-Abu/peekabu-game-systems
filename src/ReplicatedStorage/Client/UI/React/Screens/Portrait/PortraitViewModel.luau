--!strict
--[=[
	PortraitViewModel: the decisions behind CharacterPortrait.
	- `parts` / `camera`: the framing presets (head, bust, upper body with the ears, full figure): which parts to frame, and the camera that
	  fits exactly those parts' box in a frame of the given aspect, seen a little from the right and above (a
	  three-quarter view reads rounder than straight on), with a margin per preset.
	- `grow`: a live (animated) full figure is fitted at its rest pose; its reveal or idle can lift an arm, an ear or a
	  hop out of that box, which the camera would cut. `grow` is the box that also takes in what the figure reaches now
	  (never smaller), or nil while it stays inside; ToonViewport re-fits the camera to it (owner, 2026-11-12: a hire
	  is never cut off).
	- `lighting`: the viewport's one directional light and ambient for the V1 Gloom & Gleam kit: a warm key from the
	  front, above and the camera's left over lilac shadows (the kit grades shadows violet), lifted more on a dark
	  plate so the character never sinks into it.
	- `missing`: what a frame with no character drawn shows: nothing through ERROR_GRACE (a respawn or a stream-in
	  fills it in that time), then PortraitError's loud error tile. There are no per-skin stand-in photos.

	@class PortraitViewModel
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local EmployeeShared = ReplicatedStorage.Shared.Features.Employee
local EmployeePoseFormulas = require(EmployeeShared.Utils.EmployeePoseFormulas)

-- head: the face (a small ring); bust: head and chest, ear tips cut (a ring clips them anyway); upper: head, ears and
-- chest, for a frame that is not clipped round, where a cut ear would read as a mistake; full: the whole figure.
export type Framing = "head" | "bust" | "upper" | "full"
-- The plate the portrait sits on: a light (cream, gold) or a dark (night, grape) one.
export type Tone = "light" | "dark"
export type Camera = { cframe: CFrame, fov: number }
export type Lighting = { ambient: Color3, color: Color3, direction: Vector3 }

-- `extend`: how far below the framed parts the frame reaches, as a fraction of their height (a bust is the head
-- plus the chest under it: a chibi's torso part is nearly as tall as the whole body, so it cannot be framed by it).
-- Heads and busts frame the head itself, not the ears: a bunny's ears are as tall as her head, and framing them
-- shrinks the face to a dot in a small ring; their tips leave the frame, as in a photo.
type Preset = { parts: { string }?, margin: number, extend: number }

local HEAD = table.freeze({ "Head", "FacePlate" })
local EARS = table.freeze({ "Head", "FacePlate", "LeftEar", "RightEar" })

local PRESETS: { [Framing]: Preset } = {
	head = { parts = HEAD, margin = 1.12, extend = 0.15 },
	bust = { parts = HEAD, margin = 1, extend = 0.55 },
	upper = { parts = EARS, margin = 1.04, extend = 0.3 },
	full = { parts = nil, margin = 1.05, extend = 0 },
}

-- A long lens: little perspective distortion on a chibi's big head.
local FOV = 30
-- The camera sits this far round to the character's right and this far above the box's centre (degrees).
local YAW = 20
local PITCH = 8

local LIGHTING: { [Tone]: Lighting } = {
	light = {
		ambient = Color3.fromRGB(176, 162, 214),
		color = Color3.fromRGB(255, 242, 220),
		direction = Vector3.new(-0.55, -1, 0.75),
	},
	dark = {
		ambient = Color3.fromRGB(196, 180, 236),
		color = Color3.fromRGB(255, 236, 205),
		direction = Vector3.new(-0.55, -1, 0.75),
	},
}

local PortraitViewModel = {}

-- The parts a framing fits (nil = every visible part).
function PortraitViewModel.parts(framing: Framing): { string }?
	return PRESETS[framing].parts
end

--[=[
	The camera that fits `bounds` (the framed parts' box, rig at the origin facing -Z, reaching down by the preset's
	`extend`) in a frame `aspect` wide per unit high: every corner inside the view with the preset's margin.
]=]
-- `turn` (degrees, default 0) swings the camera round the model on top of the usual angle (180 = from behind).
function PortraitViewModel.camera(
	bounds: EmployeePoseFormulas.Bounds,
	framing: Framing,
	aspect: number,
	turn: number?
): Camera
	local ratio = if aspect > 0 then aspect else 1
	local preset = PRESETS[framing]
	local low = bounds.min - Vector3.new(0, (bounds.max.Y - bounds.min.Y) * preset.extend, 0)
	local box: EmployeePoseFormulas.Bounds = { min = low, max = bounds.max }
	local centre = (box.min + box.max) / 2
	local yaw, pitch = math.rad(YAW + (turn or 0)), math.rad(PITCH)
	local away = Vector3.new(math.sin(yaw) * math.cos(pitch), math.sin(pitch), -math.cos(yaw) * math.cos(pitch))
	local facing = CFrame.lookAt(Vector3.zero, -away)
	local margin = preset.margin
	local tanV = math.tan(math.rad(FOV) / 2) / margin
	local tanH = tanV * ratio
	local distance = 0
	for _, x in { box.min.X, box.max.X } do
		for _, y in { box.min.Y, box.max.Y } do
			for _, z in { box.min.Z, box.max.Z } do
				local offset = facing:VectorToObjectSpace(Vector3.new(x, y, z) - centre)
				-- -Z is forward in camera space: a corner nearer the camera (offset.Z > 0) needs more distance.
				distance =
					math.max(distance, math.abs(offset.Y) / tanV + offset.Z, math.abs(offset.X) / tanH + offset.Z)
			end
		end
	end
	return { cframe = CFrame.lookAt(centre + away * distance, centre), fov = FOV }
end

-- How far (studs) a moving figure may poke past its fitted box before the camera widens: the frame's margin hides it,
-- and the camera never twitches for a fidget.
local GROW_SLACK = 0.05

function PortraitViewModel.grow(
	fitted: EmployeePoseFormulas.Bounds,
	seen: EmployeePoseFormulas.Bounds
): EmployeePoseFormulas.Bounds?
	local low = fitted.min:Min(seen.min)
	local high = fitted.max:Max(seen.max)
	local out = (fitted.min - low):Max(high - fitted.max)
	if math.max(out.X, out.Y, out.Z) <= GROW_SLACK then
		return nil
	end
	return { min = low, max = high }
end

function PortraitViewModel.lighting(tone: Tone): Lighting
	return LIGHTING[tone]
end

-- Seconds a frame may stay blank before it shows the error: long enough for a respawn or a stream-in.
PortraitViewModel.ERROR_GRACE = 3

-- What a portrait frame shows: the character when it is drawn, else nothing until it has been missing for
-- ERROR_GRACE seconds, then the error.
function PortraitViewModel.missing(shown: boolean, waited: number): "view" | "wait" | "error"
	if shown then
		return "view"
	end
	return if waited >= PortraitViewModel.ERROR_GRACE then "error" else "wait"
end

return PortraitViewModel
