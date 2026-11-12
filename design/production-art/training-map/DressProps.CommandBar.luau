--[[
	Training map polish, part 2 (owner 11-12: "Island cabinet, truckbed, IslandShelves, Island copier, Desks look like
	defaults / placeholder assets"). Run in Studio Edit in EACH place that holds the TrainingMap; idempotent.

	Reuses the Office kit's uploaded props (design/production-art/map-kits/odd-hours-b1, AssembleKit's IDS: no new
	uploads), loaded by id (InsertService) with their colour/normal/rough maps (decal ids resolved to images).

	- Every Furniture part stays the gameplay collider (HideFurniture tags, sizes, collision, sight blocking) and is
	  made unseen; its look is a Model named "Art" under it (TrainingConstants.ART_NAME; the hide stop's glow lights
	  the art). Hide desks: the Office desk with drawers, stretched to the desk part (the Office's own Stretch fit).
	  Copier: the Office copier. Cabinet: the Office supply cabinet (its collider resized to the cabinet). Island:
	  bookshelves front and back and supply cabinets at the ends, facing out, under an oak top.
	- Office dressing (TrainingMap.Dressing.Props, inert): planters, a water cooler, bins, art frames, a whiteboard, a
	  wall clock and a sofa, against walls and clear of Mr. Harlow's lane and route.
]]

local InsertService = game:GetService("InsertService")

local map = workspace:FindFirstChild("TrainingMap")
assert(map, "no TrainingMap in this place")

-- asset name = { meshModelId, colorDecal, normalDecal, roughDecal } (AssembleKit IDS)
local IDS = {
	t9_desk_drawers = { "83257653345965", "123842368612124", "80606908058150", "78503818022681" },
	t9_desk_drawers_tex = { "", "112922977638343", "71294390694507", "99519507784235" },
	c_bookshelf = { "126189823139386", "77467087166620", "114066087139539", "137947715230076" }, -- v2 (KIT_MAP)
	c_copier = { "138748993668815", "84171327524635", "91368005682771", "114226177333107" },
	t2_supplyCabinet = { "88586894738036", "126150657377347", "139489244266070", "95122457736870" },
	r_planter = { "115416560681395", "111221186483756", "", "" },
	c_cooler = { "108596742667007", "103321218912569", "109448148261759", "73288486972551" },
	r_bin = { "88852446542319", "72314166956685", "", "" },
	d_artframe = { "136440655171491", "136441719676120", "128938219647868", "71438920533630" },
	c_whiteboard = { "118580116232249", "139612551418445", "139848401389723", "129193650114914" },
	d_wallclock = { "129091527121534", "106825833040150", "112018453094246", "110202766440781" },
	r_sofa = { "124968857530240", "84653768321845", "102146299160876", "71207426089835" },
}

local imageCache: { [string]: string } = {}
local function image(id: string): string
	if id == "" then
		return ""
	end
	if imageCache[id] then
		return imageCache[id]
	end
	local resolved = "rbxassetid://" .. id
	local ok, m = pcall(InsertService.LoadAsset, InsertService, tonumber(id))
	if ok and m then
		local d = m:FindFirstChildWhichIsA("Decal", true)
		if d then
			resolved = d.Texture
		end
		m:Destroy()
	end
	imageCache[id] = resolved
	return resolved
end

local function skin(mp: MeshPart, row: { string })
	for _, c in mp:GetChildren() do
		if c:IsA("SurfaceAppearance") then
			c:Destroy()
		end
	end
	local sa = Instance.new("SurfaceAppearance")
	sa.ColorMap = image(row[2])
	sa.NormalMap = image(row[3])
	sa.RoughnessMap = image(row[4])
	sa.Parent = mp
end

local meshCache: { [string]: Model } = {}
-- The asset's meshes as a fresh Model (pivot = the centre of its bounding box, unrotated), skinned.
local function art(name: string): Model
	if not meshCache[name] then
		local row = IDS[name]
		local m = InsertService:LoadAsset(tonumber(row[1]))
		local model = Instance.new("Model")
		model.Name = "Art"
		for _, d in m:GetDescendants() do
			if d:IsA("MeshPart") then
				d.Parent = model
				d.Anchored = true
				d.CanCollide = false
				d.CanQuery = false
				d.CanTouch = false
				-- The desk's drawers carry their own maps (t9_desk_drawers_tex).
				skin(d, if name == "t9_desk_drawers" and d.Name:find("drawer") then IDS.t9_desk_drawers_tex else row)
			end
		end
		m:Destroy()
		local cf = model:GetBoundingBox()
		model.WorldPivot = CFrame.new(cf.Position)
		meshCache[name] = model
	end
	return meshCache[name]:Clone()
end

-- Places `name` so its bounding box fills `size` (stretch) or fits inside it keeping its proportions, standing on
-- the bottom of the box at `frame` (the box's centre; -Z its front).
local function place(name: string, frame: CFrame, size: Vector3, stretch: boolean, parent: Instance): Model
	local model = art(name)
	local _, ext = model:GetBoundingBox()
	local k = if stretch
		then Vector3.new(size.X / ext.X, size.Y / ext.Y, size.Z / ext.Z)
		else Vector3.one * math.min(size.X / ext.X, size.Y / ext.Y, size.Z / ext.Z)
	local pivot = model.WorldPivot
	local fitted = ext * k
	local target = frame * CFrame.new(0, -size.Y / 2 + fitted.Y / 2, 0)
	for _, p in model:GetChildren() do
		if p:IsA("BasePart") then
			local offset = pivot:PointToObjectSpace(p.Position)
			p.Size = p.Size * k
			p.CFrame = target * CFrame.new(offset * k) * (pivot.Rotation:Inverse() * p.CFrame.Rotation)
		end
	end
	model.WorldPivot = target
	model.Parent = parent
	return model
end

local function dress(part: BasePart)
	local oldArt = part:FindFirstChild("Art")
	if oldArt then
		oldArt:Destroy()
	end
	part.Transparency = 1
	return part
end

local furniture = map.Furniture
local made = {}

-- Hide desks: the Office desk, stretched to the desk part (Office: FitMode Stretch).
for _, n in { "HideDesk1", "HideDesk2", "HideDesk3" } do
	local p = dress(furniture[n])
	place("t9_desk_drawers", p.CFrame, p.Size, true, p)
	table.insert(made, n)
end

-- Copier.
do
	local p = dress(furniture.IslandCopier)
	place("c_copier", p.CFrame, p.Size, false, p)
	table.insert(made, "IslandCopier")
end

-- Cabinet: the supply cabinet at 0.75 of its size; the collider follows it, standing where it stood.
do
	local p = dress(furniture.IslandCabinet)
	local size = Vector3.new(4.32, 8, 3.45) * 0.75
	local floorY = p.Position.Y - p.Size.Y / 2
	p.Size = size
	p.CFrame = CFrame.new(p.Position.X, floorY + size.Y / 2, p.Position.Z) * p.CFrame.Rotation
	place("t2_supplyCabinet", p.CFrame, p.Size, false, p)
	table.insert(made, "IslandCabinet")
end

-- Island (owner 11-12: the first one was too compact and clipped): two rows of full-size bookshelves, back to back
-- and side by side, the collider resized to exactly that block (10.32 x 8 x 4.16, standing on the floor where the
-- island stood). The copier and the cabinet stand apart at its south corners.
do
	local p = dress(furniture.IslandShelves)
	local W, H, D = 5.16, 8, 2.08
	local centre = Vector3.new(p.Position.X, 0.5 + H / 2, p.Position.Z)
	p.Size = Vector3.new(2 * W, H, 2 * D)
	p.CFrame = CFrame.new(centre) * p.CFrame.Rotation
	local holder = Instance.new("Model")
	holder.Name = "Art"
	holder.Parent = p
	for _, side in { -1, 1 } do
		for _, x in { -W / 2, W / 2 } do
			local at = p.CFrame * CFrame.new(x, 0, side * D / 2)
			local face = p.CFrame:VectorToWorldSpace(Vector3.new(0, 0, side))
			local m = place("c_bookshelf", CFrame.lookAt(at.Position, at.Position + face), Vector3.new(W, H, D), true, holder)
			m.Name = "Shelf"
		end
	end
	table.insert(made, "IslandShelves")
end

-- The copier and the cabinet move out to the island's south corners (their colliders and art together).
local function moveTo(part: BasePart, x: number, z: number)
	local old = part.CFrame
	local new = CFrame.new(x, old.Position.Y, z) * old.Rotation
	part.CFrame = new
	local partArt = part:FindFirstChild("Art")
	if partArt and partArt:IsA("Model") then
		partArt:PivotTo(new * old:Inverse() * partArt:GetPivot())
	end
end
moveTo(furniture.IslandCopier, -6.5, 1595.5)
moveTo(furniture.IslandCabinet, 6.5, 1595.5)

-- Office dressing round the walls (inert).
local dressing = map:FindFirstChild("Dressing") or Instance.new("Folder")
dressing.Name = "Dressing"
dressing.Parent = map
local oldProps = dressing:FindFirstChild("Props")
if oldProps then
	oldProps:Destroy()
end
local props = Instance.new("Folder")
props.Name = "Props"
props.Parent = dressing

local FLOOR = 0.5
-- A floor prop of `size` box at (x, z) facing `dir`.
local function floorProp(name: string, x: number, z: number, dir: Vector3, size: Vector3)
	local pos = Vector3.new(x, FLOOR + size.Y / 2, z)
	place(name, CFrame.lookAt(pos, pos + dir), size, false, props)
end
-- A wall prop centred at (x, y, z), its back on the wall, facing `dir`.
local function wallProp(name: string, x: number, y: number, z: number, dir: Vector3, size: Vector3)
	local pos = Vector3.new(x, y, z)
	place(name, CFrame.lookAt(pos, pos + dir), size, false, props)
end
local N, S, E, W = Vector3.new(0, 0, 1), Vector3.new(0, 0, -1), Vector3.new(1, 0, 0), Vector3.new(-1, 0, 0)

-- Start of the hall (spawn at z 1506; the hall is x -8..8).
floorProp("r_planter", -6.6, 1502.2, N, Vector3.new(2.6, 4.6, 2.6))
floorProp("c_cooler", 7.1, 1502.5, W, Vector3.new(1.4, 5, 1.5))
wallProp("d_wallclock", 0, 9.4, 1500.12, N, Vector3.new(1.8, 1.8, 0.25))
wallProp("d_artframe", -7.86, 6.6, 1513, E, Vector3.new(4, 3, 0.27))
wallProp("d_artframe", 7.86, 6.6, 1527, W, Vector3.new(4, 3, 0.27))
floorProp("r_bin", 7.0, 1520, W, Vector3.new(1.4, 1.5, 1.4))
-- Stop 2 room and the quiet hall.
wallProp("d_artframe", -7.86, 6.6, 1547, E, Vector3.new(4, 3, 0.27))
floorProp("r_bin", -7.0, 1560, E, Vector3.new(1.4, 1.5, 1.4))
floorProp("r_planter", 6.6, 1577.6, W, Vector3.new(2.4, 4.4, 2.4))
floorProp("r_planter", -6.6, 1577.6, E, Vector3.new(2.4, 4.4, 2.4))
-- Stop 4 room (x -20..20, z 1580..1621): corners, a whiteboard, a clock (Harlow walks z 1612 and the route at z 1590).
floorProp("r_planter", -18, 1582.6, N, Vector3.new(2.8, 5, 2.8))
floorProp("r_planter", 18, 1582.6, N, Vector3.new(2.8, 5, 2.8))
floorProp("c_whiteboard", -18.6, 1597, E, Vector3.new(6.4, 6.1, 1.9))
wallProp("d_wallclock", 0, 9.6, 1620.38, S, Vector3.new(1.8, 1.8, 0.25))
wallProp("d_artframe", 19.36, 6.6, 1603, W, Vector3.new(4, 3, 0.27))
floorProp("t2_supplyCabinet", 18.2, 1616.5, W, Vector3.new(3.24, 6, 2.6))
-- The way-out room (stop 5, x 20..32, z 1580..1597).
floorProp("r_sofa", 30.3, 1590.5, W, Vector3.new(7.64, 3.5, 3.62))
floorProp("r_planter", 30.2, 1595.4, W, Vector3.new(2.4, 4.4, 2.4))
floorProp("c_cooler", 30.9, 1582.2, W, Vector3.new(1.4, 5, 1.5))

return "dressed " .. table.concat(made, ",") .. "; props " .. #props:GetChildren()
