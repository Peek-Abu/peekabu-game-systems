--!strict
--[=[
	OfficeOozeSystem: the Gloom goo that seeps out under the outside dock door and shows how dirty the rolled site is
	(OfficeOozeRules.level): nothing, two puddles, or a spill as wide as the door with streaks down its lower edge.

	Flat goo in the game's Gloom colours (game-vfx-design §8: ink, grape-lo, grape), round blobs and no faces. The
	piles themselves are graybox (VacuumConstants.PILE_KINDS: dust, debris, cables), so there is no pile goo look to
	reuse; the Gloom tokens are the look. Non-colliding, not queried, casts no shadow.

	@class OfficeOozeSystem
]=]

local OfficeConstants = require(script.Parent.Parent.Data.OfficeConstants)
local OfficeTypes = require(script.Parent.Parent.Data.OfficeTypes)
local OfficeOozeRules = require(script.Parent.Parent.Rules.OfficeOozeRules)

local OfficeOozeSystem = {}

local GOO_BASE = Color3.fromRGB(123, 63, 242)
local GOO_DARK = Color3.fromRGB(85, 35, 194)
local GOO_INK = Color3.fromRGB(30, 15, 58)
local THICK = 0.1
-- Stacked blobs rise this much each, so two never fight over the same plane.
local LAYER_STEP = 0.012
-- A streak's face sits this far in front of the door's plane.
local STREAK_OFFSET = 0.2
local STREAK_WIDTH = 0.45

local function goo(model: Model, name: string, size: Vector3, frame: CFrame, color: Color3): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Material = Enum.Material.SmoothPlastic
	part.Color = color
	part.Size = size
	part.CFrame = frame
	part.Parent = model
	return part
end

-- A flat oval on the ground, `across` wide (along the door) and `deep` long (out of it), its middle `out` studs from
-- the door and `side` along it, `layer` blobs up. A cylinder's axis is X, so it is turned up.
local function puddle(
	model: Model,
	door: CFrame,
	side: number,
	out: number,
	across: number,
	deep: number,
	color: Color3,
	layer: number
)
	local frame = door * CFrame.new(side, THICK / 2 + layer * LAYER_STEP, -out) * CFrame.Angles(0, 0, math.pi / 2)
	local part = goo(model, "Puddle", Vector3.new(THICK, across, deep), frame, color)
	part.Shape = Enum.PartType.Cylinder
end

local function streak(model: Model, door: CFrame, side: number, height: number)
	goo(
		model,
		"Streak",
		Vector3.new(STREAK_WIDTH, height, 0.1),
		door * CFrame.new(side, height / 2, -STREAK_OFFSET),
		GOO_BASE
	)
end

--[=[
	Builds the ooze of `level` under `parent` at the door whose ground-centre frame is `doorFrame` (LookVector away from
	the building), for a door `width` studs wide. Nil for "none". "little": 2 puddles reaching 4 studs out at most.
	"lot": a spill as wide as the door reaching 10 studs out, and 3 streaks on the door's lower edge.
]=]
function OfficeOozeSystem.build(
	level: OfficeOozeRules.Level,
	doorFrame: CFrame,
	width: number,
	parent: Instance
): Model?
	if level == "none" then
		return nil
	end
	local model = Instance.new("Model")
	model.Name = "GloomOoze"
	if level == "little" then
		puddle(model, doorFrame, -width * 0.18, 1.7, 3.2, 3.4, GOO_BASE, 0)
		puddle(model, doorFrame, width * 0.15, 1.2, 2.4, 2.4, GOO_DARK, 1)
	else
		local half = width / 2
		-- The dark pool with a brighter skin, a tongue out to 10 studs, and lobes spreading at the sides.
		puddle(model, doorFrame, 0, 4, width, 8, GOO_INK, 0)
		puddle(model, doorFrame, 0, 4, width - 1.5, 6.8, GOO_DARK, 1)
		puddle(model, doorFrame, width * 0.08, 7.2, width * 0.5, 5.6, GOO_INK, 0)
		puddle(model, doorFrame, width * 0.08, 7.2, width * 0.5 - 1.2, 4.4, GOO_BASE, 2)
		puddle(model, doorFrame, -half + 1.8, 3.4, 3.4, 5.4, GOO_BASE, 3)
		puddle(model, doorFrame, half - 2.2, 2.6, 3.6, 4.4, GOO_BASE, 3)
		streak(model, doorFrame, -width * 0.28, 1.5)
		streak(model, doorFrame, width * 0.04, 2.2)
		streak(model, doorFrame, width * 0.3, 1.2)
	end
	model.Parent = parent
	return model
end

--[=[
	Builds the ooze for a site of `gloom` (OfficeOozeRules.level) at the layout's outside dock door, under `parent`
	(the office model, so a rebuild takes it away). `origin` places the layout in the world. Nil when the site is
	clean or the layout has no dock entrance.
]=]
function OfficeOozeSystem.buildAtDock(
	layout: OfficeTypes.Layout,
	origin: CFrame,
	gloom: number,
	parent: Instance
): Model?
	for _, entrance in layout.entrances or {} do
		if entrance.id == "dock" then
			local at = entrance.outside
			local door = origin * CFrame.new(at.x, 0, at.z) * CFrame.Angles(0, at.yaw, 0)
			return OfficeOozeSystem.build(
				OfficeOozeRules.level(gloom),
				door,
				OfficeConstants.OUTSIDE.DOCK_DOOR_WIDTH,
				parent
			)
		end
	end
	return nil
end

return table.freeze(OfficeOozeSystem)
