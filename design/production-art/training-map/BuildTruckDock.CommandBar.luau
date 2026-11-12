--[[
	Training map polish, part 3 (owner 11-12: the truck bed read as a placeholder). The real company truck is 36 studs
	long, too big for the 16-wide hall, so the stop-2 room gets a loading dock: an opening in its right wall (WallRight
	split round it, a header over it) onto a bay where the truck stands backed up to the hall, its ramp reaching in.
	TrainingSiteSystem builds the truck round the bed at runtime (DepotTruckVisualSystem, as the office does) once the
	bed is full size (16 x 3 x 24).

	Run once per place in Studio Edit, BEFORE DressShell (which then dresses the new walls). Idempotent: it rebuilds
	from the saved WallRight shape (attribute TrainingWallRightSize/CFrame on the first run).

	Gameplay kept: the TruckBed keeps its name, folder and role as the load target; the bay box and the stop-2 zone
	grow to take in the dock (no overlap with stop 1 at z < 1533 or stop 3 at z > 1555).
]]

local map = workspace:FindFirstChild("TrainingMap")
assert(map, "no TrainingMap in this place")
local shell = map.Shell

-- The dock: z 1533..1555 (between the stop-2 doors), x 8.5 (the hall's right wall) .. 50.5; ceiling at 16.5.
local Z0, Z1 = 1533, 1555
local X0, X1 = 8.5, 50.5
local TOP = 16.5
local OPEN0, OPEN1 = 1534, 1554

local right = shell:FindFirstChild("WallRight")
if right then
	right:SetAttribute("TrainingWallRightSize", right:GetAttribute("TrainingWallRightSize") or right.Size)
	right:SetAttribute("TrainingWallRightCFrame", right:GetAttribute("TrainingWallRightCFrame") or right.CFrame)
end
local saved = (right or shell:FindFirstChild("WallRightS")) :: BasePart
local size: Vector3 = saved:GetAttribute("TrainingWallRightSize") or saved.Size
local frame: CFrame = saved:GetAttribute("TrainingWallRightCFrame") or saved.CFrame

for _, n in { "WallRightS", "WallRightN", "DockHeader", "DockFloor", "DockCeiling", "DockSouth", "DockNorth", "DockEnd" } do
	local old = shell:FindFirstChild(n)
	if old and old ~= saved then
		old:Destroy()
	end
end

local function wall(name: string, size: Vector3, cf: CFrame, like: BasePart?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	if like then
		p.Material = like.Material
		p.Color = like.Color
	end
	p.Parent = shell
	return p
end

-- WallRight split round the opening (its own height and place).
local zMin, zMax = frame.Position.Z - size.Z / 2, frame.Position.Z + size.Z / 2
local y, x = frame.Position.Y, frame.Position.X
local s = wall("WallRightS_new", Vector3.new(size.X, size.Y, OPEN0 - zMin), CFrame.new(x, y, (zMin + OPEN0) / 2), saved)
wall("WallRightN", Vector3.new(size.X, size.Y, zMax - OPEN1), CFrame.new(x, y, (OPEN1 + zMax) / 2), saved)
s:SetAttribute("TrainingWallRightSize", size)
s:SetAttribute("TrainingWallRightCFrame", frame)
-- The old wall (WallRight on the first run, the previous WallRightS after) goes; the new south half takes the name.
saved:Destroy()
s.Name = "WallRightS"
-- A header over the opening, from the hall's ceiling up to the dock's.
wall("DockHeader", Vector3.new(size.X, TOP - 12, OPEN1 - OPEN0), CFrame.new(x, (12 + TOP) / 2, (OPEN0 + OPEN1) / 2), s)
local floor = shell:FindFirstChild("Floor") :: BasePart
local ceiling = shell:FindFirstChild("Ceiling") :: BasePart
wall("DockFloor", Vector3.new(X1 - X0, 1, Z1 - Z0), CFrame.new((X0 + X1) / 2, 0, (Z0 + Z1) / 2), floor).Material = Enum.Material.Concrete
wall("DockCeiling", Vector3.new(X1 - X0, 1, Z1 - Z0), CFrame.new((X0 + X1) / 2, TOP + 0.5, (Z0 + Z1) / 2), ceiling)
wall("DockSouth", Vector3.new(X1 - X0, TOP, 1), CFrame.new((X0 + X1) / 2, TOP / 2, Z0 - 0.5), s)
wall("DockNorth", Vector3.new(X1 - X0, TOP, 1), CFrame.new((X0 + X1) / 2, TOP / 2, Z1 + 0.5), s)
wall("DockEnd", Vector3.new(1, TOP, Z1 - Z0 + 2), CFrame.new(X1 + 0.5, TOP / 2, (Z0 + Z1) / 2), s)

-- The bed: full truck size, its open back toward the hall (-X), 1.5 studs into the dock; the cab toward +X.
local bed = map.Truck.TruckBed :: BasePart
bed.Size = Vector3.new(16, 3, 24)
local centre = Vector3.new(X0 + 1.5 + 12, 0.5 + 1.5, (Z0 + Z1) / 2)
bed.CFrame = CFrame.lookAt(centre, centre + Vector3.new(-1, 0, 0))

-- The bay and the stop-2 zone take in the dock.
local function grow(part: BasePart)
	local lo = part.Position - part.Size / 2
	local hi = part.Position + part.Size / 2
	local newLo = Vector3.new(lo.X, lo.Y, lo.Z)
	local newHi = Vector3.new(X1, math.max(hi.Y, TOP), hi.Z)
	part.Size = newHi - newLo
	part.CFrame = CFrame.new((newLo + newHi) / 2)
end
grow(map.Stops.BayBox)
grow(map.Stops.Stop2Zone)

-- Two lamps in the dock (not training "light" parts: they stay on).
local lights = map.Lights
for i, z in { 1539, 1549 } do
	local name = "DockLamp" .. i
	local old = lights:FindFirstChild(name)
	if old then
		old:Destroy()
	end
	local lamp = wall(name, Vector3.new(6, 0.3, 2), CFrame.new(30, TOP - 0.2, z), nil)
	lamp.Parent = lights
	lamp.Material = Enum.Material.Neon
	lamp.Color = Color3.fromRGB(255, 244, 214)
	lamp.CanCollide = false
	local light = Instance.new("SurfaceLight")
	light.Face = Enum.NormalId.Bottom
	light.Brightness = 1.6
	light.Range = 20
	light.Angle = 120
	light.Color = Color3.fromRGB(255, 236, 205)
	light.Parent = lamp
end

return string.format("dock built; bed %s at %s; bay %s; zone %s", tostring(bed.Size), tostring(bed.Position), tostring(map.Stops.BayBox.Size), tostring(map.Stops.Stop2Zone.Size))
