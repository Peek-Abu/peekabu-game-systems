--!strict
--[=[
	ToonViewportPlatform: the round 3D platform a ToonViewport stands its model on (`platform`): a light top, a thin
	ink line at its rim, the side and an ink foot, sized from the model's height and built in the viewport so it is lit
	with the model. Split out of ToonViewport.

	@class ToonViewportPlatform
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local EmployeePoseFormulas = require(ReplicatedStorage.Shared.Features.Employee.Utils.EmployeePoseFormulas)
local UIToonConstants = require(ReplicatedStorage.Client.UI.React.Screens.Toon.UIToonConstants)

-- The platform's colours: its top face and its side.
export type Platform = { top: Color3, side: Color3 }

local ToonViewportPlatform = {}

-- The platform's radius and thickness as shares of the model's height.
local PLATFORM_RADIUS = 0.34
local PLATFORM_HEIGHT = 0.07

-- One flat round slab (a Roblox cylinder lies along X: turned upright), its top face at `topY`.
local function slab(name: string, centre: Vector3, topY: number, radius: number, height: number, color: Color3): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Shape = Enum.PartType.Cylinder
	part.Anchored = true
	part.CanCollide = false
	part.CastShadow = false
	part.Material = Enum.Material.SmoothPlastic
	part.Color = color
	part.Size = Vector3.new(height, radius * 2, radius * 2)
	part.CFrame = CFrame.new(centre.X, topY - height / 2, centre.Z) * CFrame.Angles(0, 0, math.pi / 2)
	return part
end

--[=[
	The platform under the model's feet (the bounds' bottom): a light top, a thin ink line at its rim, the side, and
	an ink foot (the kit's outline and drop, in 3D). Returns it and the bounds grown to hold it.
]=]
function ToonViewportPlatform.platformFor(
	bounds: EmployeePoseFormulas.Bounds,
	colors: Platform
): (Model, EmployeePoseFormulas.Bounds)
	local tall = bounds.max.Y - bounds.min.Y
	local radius = tall * PLATFORM_RADIUS
	local height = tall * PLATFORM_HEIGHT
	local centre = (bounds.min + bounds.max) / 2
	local feet = bounds.min.Y
	local line = height * 0.12
	local model = Instance.new("Model")
	model.Name = "Platform"
	slab("Top", centre, feet, radius, line * 1.5, colors.top).Parent = model
	slab("Rim", centre, feet - line * 1.5, radius * 1.025, line, UIToonConstants.COLOR.ink).Parent = model
	slab("Side", centre, feet - line * 2.5, radius, height - line * 3.5, colors.side).Parent = model
	slab("Foot", centre, feet - height + line, radius * 1.05, line * 1.4, UIToonConstants.COLOR.ink).Parent = model
	local reach = radius * 1.05
	local grown: EmployeePoseFormulas.Bounds = {
		min = Vector3.new(
			math.min(bounds.min.X, centre.X - reach),
			feet - height - line,
			math.min(bounds.min.Z, centre.Z - reach)
		),
		max = Vector3.new(
			math.max(bounds.max.X, centre.X + reach),
			bounds.max.Y,
			math.max(bounds.max.Z, centre.Z + reach)
		),
	}
	return model, grown
end

return ToonViewportPlatform
