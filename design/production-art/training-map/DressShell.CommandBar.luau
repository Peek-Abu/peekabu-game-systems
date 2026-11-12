--[[
	Training map polish, part 1 (owner 11-12: "walls are basic with no textures", "Gloom Creep looks like weird
	rectangles"). Run in Studio Edit (command bar or execute_luau) in EACH place that holds the TrainingMap; idempotent
	(rebuilds TrainingMap.Dressing.Shell every run). Changes only looks: every gameplay part keeps its tags, roles,
	size, CFrame and collision.

	- Walls: Office plaster (OH_Plaster when the place has it, else Roblox Plaster) with the Office wallSolid trim, an
	  oak dado rail at 3.2 and a dark skirting board.
	- Floors: Office carpet (OH_Carpet / Carpet), the hall a cooler grey than the rooms. Ceilings: ceiling tile
	  (OH_Ceiling / Concrete) under a T-bar grid every 4 studs.
	- Hall lamps: an Office troffer housing round each Neon diffuser (a child, so lights-out still only dims the
	  diffuser), and a SurfaceLight on any lamp without a light.
	- Doors: the stop doors as violet steel shutters, STAFF as dark-red wood, the exit as violet steel.
	- Gloom creep: each patch part is made unseen and holds round goo blobs (the Office ooze palette, an ink rim
	  under each, no faces); TrainingHallSystem grows the blobs over the floor (TrainingCreepRules).
]]

local MaterialService = game:GetService("MaterialService")

local map = workspace:FindFirstChild("TrainingMap")
assert(map, "no TrainingMap in this place")
local shell = map:FindFirstChild("Shell")
assert(shell, "no TrainingMap.Shell")

local FLOOR_TOP = 0.5
local RAIL_Y = 3.2
local GOO_BASE = Color3.fromRGB(123, 63, 242)
local GOO_DARK = Color3.fromRGB(85, 35, 194)
local GOO_INK = Color3.fromRGB(30, 15, 58)

local function variant(name: string): string
	return if MaterialService:FindFirstChild(name, true) ~= nil then name else ""
end

local dressing = map:FindFirstChild("Dressing") or Instance.new("Folder")
dressing.Name = "Dressing"
dressing.Parent = map
local old = dressing:FindFirstChild("Shell")
if old then
	old:Destroy()
end
local out = Instance.new("Folder")
out.Name = "Shell"
out.Parent = dressing

local function inert(p: BasePart)
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
end

local function block(name: string, size: Vector3, cf: CFrame, material: Enum.Material, color: Color3, parent: Instance?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Material = material
	p.Color = color
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	inert(p)
	p.CastShadow = false
	p.Parent = parent or out
	return p
end

-- Surfaces.
local plaster = variant("OH_Plaster")
local carpet = variant("OH_Carpet")
local ceilingV = variant("OH_Ceiling")
local oak = variant("OH_Oak")
local counts = { walls = 0, floors = 0, ceilings = 0, rails = 0, grid = 0 }

for _, p in shell:GetChildren() do
	if p:IsA("BasePart") then
		local n = p.Name
		if n:find("Dock") and n:find("Floor") then
			-- The truck dock is bare sealed concrete.
			p.Material = Enum.Material.Concrete
			p.MaterialVariant = ""
			p.Color = Color3.fromRGB(120, 118, 124)
			counts.floors += 1
		elseif n:find("Floor") then
			-- OH_Carpet is a Fabric variant (a variant only shows on its own base material).
			p.Material = if carpet ~= "" then Enum.Material.Fabric else Enum.Material.Carpet
			p.MaterialVariant = carpet
			-- The long hall cooler, the rooms warmer (the Office hallway tint vs its rooms).
			p.Color = if n == "Floor" then Color3.fromRGB(150, 150, 160) else Color3.fromRGB(128, 118, 132)
			if carpet ~= "" then
				p.Color = if n == "Floor" then Color3.new(0.75, 0.75, 0.78) else Color3.new(0.68, 0.64, 0.7)
			end
			counts.floors += 1
		elseif n:find("Ceiling") then
			p.Material = Enum.Material.Concrete
			p.MaterialVariant = ceilingV
			p.Color = if ceilingV ~= "" then Color3.new(1, 1, 1) else Color3.fromRGB(205, 202, 196)
			counts.ceilings += 1
			-- T-bar grid on the underside, every 4 studs, both ways.
			local under = p.CFrame * CFrame.new(0, -p.Size.Y / 2 - 0.04, 0)
			for x = -p.Size.X / 2 + 4, p.Size.X / 2 - 0.5, 4 do
				block("TBar", Vector3.new(0.14, 0.08, p.Size.Z), under * CFrame.new(x, 0, 0), Enum.Material.Metal, Color3.fromRGB(226, 224, 218))
				counts.grid += 1
			end
			for z = -p.Size.Z / 2 + 4, p.Size.Z / 2 - 0.5, 4 do
				block("TBar", Vector3.new(p.Size.X, 0.08, 0.14), under * CFrame.new(0, 0, z), Enum.Material.Metal, Color3.fromRGB(226, 224, 218))
				counts.grid += 1
			end
		else
			p.Material = Enum.Material.Plaster
			p.MaterialVariant = plaster
			p.Color = if plaster ~= "" then Color3.fromRGB(255, 244, 228) else Color3.fromRGB(226, 218, 204)
			counts.walls += 1
			-- Trim on full-height walls only (not the lintels over doorways).
			if p.Size.Y >= 10 then
				local long = math.max(p.Size.X, p.Size.Z)
				local alongX = p.Size.X >= p.Size.Z
				local thick = math.min(p.Size.X, p.Size.Z)
				local bottom = p.Position.Y - p.Size.Y / 2
				local base = Vector3.new(p.Position.X, 0, p.Position.Z)
				local function trim(name: string, height: number, depth: number, y: number, mat: Enum.Material, color: Color3, v: string)
					local size = if alongX
						then Vector3.new(long, height, thick + depth)
						else Vector3.new(thick + depth, height, long)
					local t = block(name, size, CFrame.new(base + Vector3.new(0, y, 0)), mat, color)
					t.MaterialVariant = v
				end
				trim("Skirting", 0.5, 0.16, math.max(bottom, FLOOR_TOP) + 0.25, Enum.Material.SmoothPlastic, Color3.fromRGB(46, 40, 52), "")
				trim("DadoRail", 0.28, 0.3, FLOOR_TOP + RAIL_Y, Enum.Material.Wood, if oak ~= "" then Color3.new(1, 1, 1) else Color3.fromRGB(150, 104, 64), oak)
				-- Below the rail a slightly deeper plaster band (the Office wainscot read).
				local band = math.max(bottom, FLOOR_TOP)
				trim("Wainscot", FLOOR_TOP + RAIL_Y - band, 0.04, (band + FLOOR_TOP + RAIL_Y) / 2, Enum.Material.Plaster, Color3.fromRGB(196, 186, 198), plaster)
				counts.rails += 3
			end
		end
	end
end

-- Hall lamps: a troffer housing round each diffuser, and a light under any lamp without one.
local lamps = 0
for _, p in map.Lights:GetChildren() do
	if p:IsA("BasePart") then
		local housing = p:FindFirstChild("Housing")
		if housing then
			housing:Destroy()
		end
		local h = block("Housing", p.Size + Vector3.new(0.5, 0.05, 0.5), p.CFrame * CFrame.new(0, 0.08, 0), Enum.Material.Metal, Color3.fromRGB(196, 196, 200), p)
		h.Name = "Housing"
		p.Color = Color3.fromRGB(255, 244, 214)
		if p:FindFirstChildWhichIsA("Light", true) == nil then
			local light = Instance.new("SurfaceLight")
			light.Face = Enum.NormalId.Bottom
			light.Brightness = 1.4
			light.Range = 16
			light.Angle = 120
			light.Color = Color3.fromRGB(255, 236, 205)
			light.Parent = p
		end
		lamps += 1
	end
end

-- Doors (looks only; they swing or open by CFrame, so no child parts).
for _, d in map.Doors:GetChildren() do
	if d:IsA("BasePart") then
		if d.Name == "StaffDoor" then
			d.Material = Enum.Material.Wood
			d.Color = Color3.fromRGB(120, 36, 40)
		elseif d.Name == "ExitDoor" then
			d.Material = Enum.Material.Metal
			d.Color = Color3.fromRGB(110, 86, 168)
		else
			d.Material = Enum.Material.Metal
			d.Color = Color3.fromRGB(92, 78, 136)
		end
	end
end

-- Oak frames round the two stop doors (dressing, not children: the doors open by CFrame).
for _, n in { "Door1", "Door2" } do
	local d = map.Doors:FindFirstChild(n)
	if d and d:IsA("BasePart") then
		local cf, w, h = d.CFrame, d.Size.X, d.Size.Y
		local oakColor = Color3.fromRGB(122, 84, 52)
		block("DoorFrame", Vector3.new(0.6, h, 1.8), cf * CFrame.new(-w / 2 + 0.3, 0, 0), Enum.Material.Wood, oakColor)
		block("DoorFrame", Vector3.new(0.6, h, 1.8), cf * CFrame.new(w / 2 - 0.3, 0, 0), Enum.Material.Wood, oakColor)
		block("DoorFrame", Vector3.new(w, 0.7, 1.8), cf * CFrame.new(0, h / 2 - 0.35, 0), Enum.Material.Wood, oakColor)
	end
end

-- Gloom creep: round goo blobs under each (now unseen) patch part.
local rng = Random.new(1112)
local blobs = 0
for _, patch in map.Gloom:GetChildren() do
	if patch:IsA("BasePart") and patch:GetAttribute("TrainingRole") == "creep" then
		for _, c in patch:GetChildren() do
			if c:IsA("BasePart") then
				c:Destroy()
			end
		end
		patch.Transparency = 1
		local floorY = -patch.Size.Y / 2 + 0.03
		local hx, hz = patch.Size.X / 2, patch.Size.Z / 2
		-- One big puddle in the middle, then 4-5 smaller ones round it, overlapping like spilled goo.
		local spots = { { 0, 0, math.min(hx, hz) * 1.25 } }
		for k = 1, rng:NextInteger(4, 5) do
			local a = (k / 5) * math.pi * 2 + rng:NextNumber(-0.4, 0.4)
			local r = rng:NextNumber(0.45, 0.8)
			table.insert(spots, { math.cos(a) * hx * r, math.sin(a) * hz * r, rng:NextNumber(0.9, 1.7) })
		end
		for i, s in spots do
			local x, z, d = s[1], s[2], s[3]
			local layer = (i - 1) * 0.012
			local up = CFrame.Angles(0, 0, math.pi / 2)
			local rim = block("GooRim", Vector3.new(0.06, d + 0.3, d + 0.3), patch.CFrame * CFrame.new(x, floorY + layer, z) * up, Enum.Material.SmoothPlastic, GOO_INK, patch)
			rim.Shape = Enum.PartType.Cylinder
			local goo = block("Goo", Vector3.new(0.08, d, d), patch.CFrame * CFrame.new(x, floorY + layer + 0.012, z) * up, Enum.Material.SmoothPlastic, if i == 1 then GOO_DARK else GOO_BASE, patch)
			goo.Shape = Enum.PartType.Cylinder
			goo.Reflectance = 0.08
			-- A wet highlight on the bigger blobs.
			if d > 1.3 then
				local shine = block("Shine", Vector3.new(0.09, d * 0.28, d * 0.18), patch.CFrame * CFrame.new(x - d * 0.18, floorY + layer + 0.02, z - d * 0.15) * up, Enum.Material.Neon, Color3.fromRGB(150, 110, 240), patch)
				shine.Shape = Enum.PartType.Cylinder
				-- A faint glow, so the goo still reads once the hall's lights go out at stop 3.
				shine.Transparency = 0.45
			end
			blobs += 1
		end
	end
end

return string.format(
	"walls %d floors %d ceilings %d trim %d grid %d lamps %d blobs %d | variants plaster=%s carpet=%s ceiling=%s oak=%s",
	counts.walls, counts.floors, counts.ceilings, counts.rails, counts.grid, lamps, blobs,
	plaster, carpet, ceilingV, oak
)
