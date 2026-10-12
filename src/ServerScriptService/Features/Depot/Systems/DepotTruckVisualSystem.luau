--!strict
-- Original company truck; gameplay bed stays authoritative and keeps its full boarding footprint.
local TEAL = Color3.fromRGB(28, 88, 76)
local IVORY = Color3.fromRGB(220, 210, 180)
local RUBBER = Color3.fromRGB(28, 35, 37)
local STEEL = Color3.fromRGB(130, 146, 147)
local AMBER = Color3.fromRGB(230, 169, 55)
local DepotTruckVisualSystem = {}
function DepotTruckVisualSystem.build(bed: BasePart, parent: Instance)
	local top = bed.Size.Y / 2
	local halfDepth = bed.Size.Z / 2
	local width = math.min(9.6, bed.Size.X * 0.8)
	local function part(name: string, size: Vector3, position: Vector3, color: Color3): Part
		local p = Instance.new("Part")
		p.Name = name
		p.Size = size
		p.CFrame = bed.CFrame * CFrame.new(position)
		p.Color = color
		p.Anchored = true
		p.CanCollide = false
		p.CanTouch = false
		p.CanQuery = false
		p.Material = Enum.Material.SmoothPlastic
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		p.Parent = parent
		return p
	end
	-- Solid cabin outside the queue footprint; bonnet gives a distinct front silhouette.
	local cab = part("TruckCab", Vector3.new(width, 4.5, 4.5), Vector3.new(0, top + 2.25, halfDepth + 2.25), IVORY)
	cab.CanCollide = true
	cab.CanQuery = true
	part("CabRoof", Vector3.new(width + 0.3, 0.3, 4.7), Vector3.new(0, top + 4.65, halfDepth + 2.25), TEAL)
	part("Bonnet", Vector3.new(width, 1.3, 1.5), Vector3.new(0, top + 0.8, halfDepth + 5.25), TEAL)
	part(
		"Windshield",
		Vector3.new(width - 0.8, 1.65, 0.06),
		Vector3.new(0, top + 3.3, halfDepth + 4.52),
		Color3.fromRGB(38, 65, 74)
	)
	part("Bumper", Vector3.new(width + 0.4, 0.4, 0.45), Vector3.new(0, top + 0.1, halfDepth + 6.2), STEEL)
	part("Grille", Vector3.new(3.2, 0.45, 0.07), Vector3.new(0, top + 0.85, halfDepth + 6.04), RUBBER)
	for _, side in { -1, 1 } do
		part(
			"Headlamp",
			Vector3.new(1.3, 0.5, 0.1),
			Vector3.new(side * (width / 2 - 1), top + 1.05, halfDepth + 6.04),
			IVORY
		)
		part(
			"SideWindow",
			Vector3.new(0.06, 1.6, 3),
			Vector3.new(side * (width / 2 + 0.02), top + 3.3, halfDepth + 2.25),
			Color3.fromRGB(38, 65, 74)
		)
		part(
			"DoorStripe",
			Vector3.new(0.06, 0.6, 3.8),
			Vector3.new(side * (width / 2 + 0.03), top + 1.7, halfDepth + 2.25),
			TEAL
		)
		part(
			"Mirror",
			Vector3.new(0.3, 0.7, 0.5),
			Vector3.new(side * (width / 2 + 0.5), top + 3.3, halfDepth + 3.9),
			RUBBER
		)
		part(
			"DoorHandle",
			Vector3.new(0.12, 0.12, 0.6),
			Vector3.new(side * (width / 2 + 0.08), top + 2.45, halfDepth + 0.9),
			STEEL
		)
		part(
			"BedRail",
			Vector3.new(0.25, 0.7, bed.Size.Z),
			Vector3.new(side * (bed.Size.X / 2 + 0.15), top + 0.45, 0),
			IVORY
		)
		for _, z in { -halfDepth + 3, halfDepth + 2.6 } do
			local x = side * (if z > halfDepth then width / 2 + 0.1 else bed.Size.X / 2 + 0.45)
			local wheel = part("Tire", Vector3.new(2.3, 0.65, 2.3), Vector3.new(x, 1.15 - bed.Size.Y / 2, z), RUBBER)
			-- Roblox cylinders use local X as the axle; all offsets are relative to the bed.
			wheel.Shape = Enum.PartType.Cylinder
			wheel.Size = Vector3.new(0.65, 2.3, 2.3)
			part("WheelArch", Vector3.new(0.85, 0.35, 3), Vector3.new(x, 2.6 - bed.Size.Y / 2, z), TEAL)
			for _, endSign in { -1, 1 } do
				local shoulder = part(
					"WheelArchShoulder",
					Vector3.new(0.85, 0.3, 0.9),
					Vector3.new(x, 2.2 - bed.Size.Y / 2, z + endSign * 1.2),
					TEAL
				)
				shoulder.CFrame *= CFrame.Angles(math.rad(endSign * 50), 0, 0)
			end
			local hub = part(
				"WheelHub",
				Vector3.new(0.07, 1.15, 1.15),
				Vector3.new(x + side * 0.36, 1.15 - bed.Size.Y / 2, z),
				STEEL
			)
			hub.Shape = Enum.PartType.Cylinder
		end
	end
	-- Two shallow physical treads support the office's higher banking deck; neither is tagged as queue space.
	for step = 1, 2 do
		local treadHeight = bed.Size.Y * (3 - step) / 3
		local tread = part(
			"BoardingStep",
			Vector3.new(7, treadHeight, 1),
			Vector3.new(0, treadHeight / 2 - bed.Size.Y / 2, -halfDepth - 0.5 - (step - 1)),
			STEEL
		)
		tread.CanCollide = true
		tread.CanQuery = true
	end
	part("TailSafetyStripe", Vector3.new(7, 0.07, 0.12), Vector3.new(0, top + 0.04, -halfDepth + 0.1), AMBER)
end
return DepotTruckVisualSystem
