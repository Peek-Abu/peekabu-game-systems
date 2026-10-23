--!nonstrict
-- AddSpikeTemplates.CommandBar.luau: adds the spike's extra pieces to ArtKits["odd-hours-b1"] (spike-match plan, Task 4).
-- Run in Roblox Studio (Edit, Shift place) through the Studio MCP / command bar, AFTER AssembleKit.CommandBar.luau (that
-- script rebuilds the kit folder from scratch, so run this one again after it). Idempotent: replaces only its own keys.
-- Sources are clones of Workspace.ClaudeMockRoom parts (already-uploaded Icey Labs art), so no upload is needed.
-- Templates may not carry lights (ArtKitRules.validateTemplate): lights hang on named Attachments the code fills
-- (OfficeConstants.ACCENT_LIGHTS) or, for the troffer, the code adds the SurfaceLight itself.
--
--   building/troffer        CeilingPanel (Neon + troffer Texture), SurfaceLight stripped, OfficeLightEmitter = true
--   furniture/rug           Rug (Fabric + rug Decal on top)
--   furniture/windowBay     c_windowbay + c_blinds_full (opaque night glass, blinds on the room side, front -Z)
--   furniture/column        2 x 13 x 2 OH_Plaster column with an oak-coloured skirt (as the spike's columns)
--   furniture/receptionGlow ReceptionPanel (OH_Plaster) with the warm ReceptionGlow behind it; Attachment GlowLight
--   furniture/floorLamp     (existing) gains Attachment LampLight under the shade
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local KIT = ReplicatedStorage.Assets.CleanupCrew.ArtKits["odd-hours-b1"]
local MOCK = workspace.ClaudeMockRoom
local SKIRT_COLOR = Color3.fromRGB(41, 33, 28)

local function find(name, pred)
	for _, d in MOCK:GetDescendants() do
		if d.Name == name and (pred == nil or pred(d)) then
			return d
		end
	end
	error("ClaudeMockRoom has no " .. name)
end

local function strip(inst)
	for _, d in inst:GetDescendants() do
		if d:IsA("Light") or d:IsA("Script") or d:IsA("LocalScript") or d:IsA("JointInstance") or d:IsA("Constraint") then
			d:Destroy()
		end
	end
end

-- Clone `parts` keeping their placement relative to `parts[1]` (with that part's yaw undone when `unrotate`), then seat
-- the whole model bottom-centred at the origin, as validateTemplate demands.
local function fromParts(key, parts, unrotate)
	local m = Instance.new("Model")
	m.Name = key
	local ref = parts[1].CFrame
	if not unrotate then
		ref = CFrame.new(ref.Position)
	end
	for _, src in parts do
		local c = src:Clone()
		strip(c)
		c.Anchored = true
		c.CFrame = ref:ToObjectSpace(src.CFrame)
		c.Parent = m
	end
	local box, size = m:GetBoundingBox()
	local shift = Vector3.new(box.Position.X, box.Position.Y - size.Y / 2, box.Position.Z)
	for _, c in m:GetChildren() do
		c.CFrame = c.CFrame - shift
	end
	return m, size
end

local function finish(m, size, fit)
	m.WorldPivot = CFrame.identity
	m:SetAttribute("BaseSize", size)
	m:SetAttribute("RuntimeApproved", true)
	m:SetAttribute("FrontAxis", "NegativeZ")
	if fit then
		m:SetAttribute("FitMode", fit)
	end
	return m
end

local function put(family, m)
	local folder = KIT[family]
	local old = folder:FindFirstChild(m.Name)
	if old then
		old:Destroy()
	end
	m.Parent = folder
end

local function attachment(parent, name, position)
	local a = Instance.new("Attachment")
	a.Name = name
	a.Position = position
	a.Parent = parent
	return a
end

local report = {}

-- troffer (building, Stretch: the code sizes it to the panel)
do
	local src = find("CeilingPanel", function(d)
		return d:FindFirstChildOfClass("SurfaceLight") ~= nil
	end)
	local m, size = fromParts("troffer", { src }, true)
	m:FindFirstChildWhichIsA("BasePart"):SetAttribute("OfficeLightEmitter", true)
	put("building", finish(m, size, "Stretch"))
end

-- rug (furniture, Uniform)
do
	local m, size = fromParts("rug", { find("Rug") }, true)
	put("furniture", finish(m, size))
end

-- windowBay: the mesh as imported faces -Z (KIT_MAP); in the mock it is turned 180 so its front (blinds) faces the
-- room. Undoing that yaw puts the blinds on -Z, the template front.
do
	local bay = find("c_windowbay")
	local blinds
	for _, c in bay.Parent:GetChildren() do
		if c.Name == "c_blinds_full" and (c.Position - bay.Position).Magnitude < 1 then
			blinds = c
		end
	end
	assert(blinds, "no c_blinds_full beside the first c_windowbay")
	local m, size = fromParts("windowBay", { bay, blinds }, true)
	put("furniture", finish(m, size))
end

-- column: plaster shaft and a skirt, like the spike's columns (box 2 x 2, floor to the 13-stud ceiling)
do
	local m = Instance.new("Model")
	m.Name = "column"
	local function part(name, size, y, material, variant, color)
		local p = Instance.new("Part")
		p.Name = name
		p.Anchored = true
		p.Size = size
		p.CFrame = CFrame.new(0, y, 0)
		p.Material = material
		p.MaterialVariant = variant or ""
		p.Color = color or Color3.new(1, 1, 1)
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		p.Parent = m
	end
	part("Shaft", Vector3.new(2, 13, 2), 6.5, Enum.Material.Plaster, "OH_Plaster")
	part("Skirt", Vector3.new(2.8, 0.6, 2.8), 0.3, Enum.Material.SmoothPlastic, nil, SKIRT_COLOR)
	put("furniture", finish(m, Vector3.new(2.8, 13, 2.8)))
end

-- receptionGlow: the plaster panel in front (-Z), the warm glow card behind it; the code hangs the light on GlowLight
do
	local panel, glow = find("ReceptionPanel"), find("ReceptionGlow")
	local m, size = fromParts("receptionGlow", { panel, glow }, true)
	-- the glow card sits behind the panel (+Z in the mock's frame); the light goes just in front of the glow card
	local g = m:FindFirstChild("ReceptionGlow")
	attachment(g, "GlowLight", Vector3.new(0, 0, -0.5))
	put("furniture", finish(m, size))
end

-- floorLamp: an attachment under the shade (top 15 % of the lamp) for LampLight
do
	local lamp = KIT.furniture:FindFirstChild("floorLamp")
	assert(lamp, "kit has no floorLamp (run AssembleKit first)")
	local mesh = lamp:FindFirstChildWhichIsA("BasePart")
	local old = mesh:FindFirstChild("LampLight")
	if old then
		old:Destroy()
	end
	attachment(mesh, "LampLight", Vector3.new(0, mesh.Size.Y * 0.35, 0))
end

local Rules = require(ReplicatedStorage.Shared.Features.Art.Rules.ArtKitRules:Clone())
for _, pair in { { "building", "troffer" }, { "furniture", "rug" }, { "furniture", "windowBay" }, { "furniture", "column" }, { "furniture", "receptionGlow" }, { "furniture", "floorLamp" } } do
	local t = KIT[pair[1]][pair[2]]
	table.insert(
		report,
		("%-14s %-9s valid=%s size=%s fit=%s"):format(
			pair[2],
			pair[1],
			tostring(Rules.validateTemplate(t, pair[1])),
			tostring(t:GetAttribute("BaseSize")),
			tostring(t:GetAttribute("FitMode") or "Uniform")
		)
	)
end
print(table.concat(report, "\n"))
return table.concat(report, "\n")
