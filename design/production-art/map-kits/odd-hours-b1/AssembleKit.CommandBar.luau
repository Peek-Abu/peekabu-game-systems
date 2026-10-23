--!nonstrict
-- AssembleKit.CommandBar.luau: rebuilds ReplicatedStorage.Assets.CleanupCrew.ArtKits["odd-hours-b1"] from scratch.
-- Run in Roblox Studio (Edit) through the Studio MCP / command bar. Idempotent. Art never goes in Rojo.
-- The kit holds ONLY what it restyles: ArtVisualSystem/OfficeArtKeyUtils fall back to "client-office-slate" for the rest
-- (cargo, props, exitSign, elevatorFront...). Keys whose art is not uploaded yet are reported "pending" and skipped, so
-- re-run after adding their ids to IDS (and MaterialVariants OH_Vinyl / OH_Lino to MaterialService).
-- IDS rows: asset name = { meshModelId, colorDecalId, normalDecalId, roughDecalId } (decal ids resolve to image ids via
-- InsertService:LoadAsset, as real/make_real.lua does). Source: scratchpad real/ASSET_IDS.json.
local InsertService = game:GetService("InsertService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MaterialService = game:GetService("MaterialService")

local KIT_ID = "odd-hours-b1"
local IDS = {
	c_desk_nodivider = {"74890171416031", "81026453399291", "78612349455668", "93828460741235"}, -- the mock-room desk without the privacy divider (replaces c_desk)
	c_chair = {"76140780685205", "133451549732406", "133440041678773", "133033333497328"},
	c_lockers = {"80348717249179", "83914590869498", "76034031473396", "103555969898410"},
	c_bookshelf = {"82298001439367", "138256636385004", "112643864130260", "102527266813417"},
	c_coffeebar = {"132077928644424", "114564127840208", "105239782834012", "135619444545380"},
	c_whiteboard = {"118580116232249", "139612551418445", "139848401389723", "129193650114914"},
	c_coffeetable = {"139831089082474", "120065143131395", "70575868156789", "116682359580652"},
	c_conftable = {"96816971294905", "119581097720904", "105267504195568", "127420197846667"},
	c_reception = {"87200857409958", "94530506233427", "73069489773295", "76265971690392"},
	c_partition = {"75231876449467", "131020134159766", "93713792168899", "125883291514418"},
	r_sofa = {"124968857530240", "84653768321845", "102146299160876", "71207426089835"},
	r_vending = {"127404994422146", "125808383942442", "", ""},
	r_cooler = {"134681770334714", "136030881720355", "", ""},
	c_cooler = {"108596742667007", "103321218912569", "109448148261759", "73288486972551"},
	c_copier = {"138748993668815", "84171327524635", "91368005682771", "114226177333107"},
	c_floorlamp = {"95651966049736", "124184606900788", "127187492992288", "138101632058476"},
	r_planter = {"115416560681395", "111221186483756", "", ""},
	r_bin = {"88852446542319", "72314166956685", "", ""},
	d_artframe = {"136440655171491", "136441719676120", "128938219647868", "71438920533630"},
	d_wallscreen = {"111518569613272", "118710875443055", "83652445222925", "102071716819086"},
	d_sconce = {"95782564886770", "113321291672262", "129301370669287", "73769983264894"},
	d_wallclock = {"129091527121534", "106825833040150", "112018453094246", "110202766440781"},
	r_deskplant = {"101911962938936", "112018184525997", "", ""},
	-- Task 2 meshes (uploaded in Task 4). Colour/normal/rough are DECAL ids; they resolve to image ids at run time.
	t2_serverRack = {"76858453551547", "79134697329536", "108106230649311", "105815688686484"},
	t2_doorLeaf = {"128086321055290", "126343314525764", "76384627646625", "70500544549300"},
	t2_doorLeafGlass = {"121018102259344", "135379141376361", "135630238974539", "77112399835962"},
	t2_supplyCabinet = {"88586894738036", "126150657377347", "139489244266070", "95122457736870"},
	t2_stairwellSign = {"103288430156868", "133644663294809", "73965497346519", "113065990472125"},
}
local TROFFER_DECAL = "125363236292378" -- "surf troffer color"
local DESK_SIZE = Vector3.new(5, 3, 3) * 1.65 -- OfficeConstants.DESK_SIZE
local HUG_FREE_MIN = Vector3.new(3.6, 4.2, 4.3) -- HideConstants.HUG_FREE_MIN
-- HideConstants.FURNITURE.desk free box as fractions of the desk (min, max), centre-origin.
local DESK_FREE_FRAC = { min = Vector3.new(-0.428, -0.5, -0.5), max = Vector3.new(0.19, 0.4233, 0.3933) }

-- Mesh-based templates: { key, family, asset row, FrontAxis (which way the mesh faces as imported; checked by eye), fit }
local MESH = {
	{ "desk", "furniture", "c_desk_nodivider", "NegativeZ", "Stretch" },
	{ "officeChair", "furniture", "c_chair", "NegativeZ" },
	{ "locker", "furniture", "c_lockers", "NegativeZ" },
	{ "shelf", "furniture", "c_bookshelf", "NegativeZ" },
	{ "kitchenCounter", "furniture", "c_coffeebar", "NegativeZ" },
	{ "corkboard", "furniture", "c_whiteboard", "NegativeZ" },
	{ "breakTable", "furniture", "c_coffeetable", "NegativeZ" },
	{ "conferenceTable", "furniture", "c_conftable", "NegativeZ" },
	{ "receptionDesk", "furniture", "c_reception", "NegativeZ" },
	{ "partition", "furniture", "c_partition", "NegativeZ" },
	{ "sofa", "furniture", "r_sofa", "NegativeZ" },
	{ "vending", "furniture", "r_vending", "NegativeZ" },
	{ "waterCooler", "furniture", "c_cooler", "NegativeZ" },
	{ "copier", "furniture", "c_copier", "NegativeZ" },
	{ "floorLamp", "furniture", "c_floorlamp", "NegativeZ" },
	{ "planter", "furniture", "r_planter", "NegativeZ" },
	{ "wasteBin", "furniture", "r_bin", "NegativeZ" },
	{ "artFrame", "furniture", "d_artframe", "NegativeZ" },
	{ "wallScreen", "furniture", "d_wallscreen", "NegativeZ" },
	{ "sconce", "furniture", "d_sconce", "NegativeZ" },
	{ "wallClock", "furniture", "d_wallclock", "NegativeZ" },
	{ "deskPlant", "furniture", "r_deskplant", "NegativeZ" },
	-- Task 2 (uploaded in Task 4):
	{ "serverRack", "furniture", "t2_serverRack", "NegativeZ" },
	{ "supplyCabinet", "furniture", "t2_supplyCabinet", "NegativeZ" },
	{ "stairwellSign", "furniture", "t2_stairwellSign", "NegativeZ" },
	{ "doorLeaf", "building", "t2_doorLeaf", "NegativeZ", "Stretch" },
	{ "doorLeafGlass", "building", "t2_doorLeafGlass", "NegativeZ", "Stretch" },
}

-- Held keys: not built; the slate kit covers them through the attachFirst fallback. Delete the entry to turn one on.
local HELD = {
	locker = "held: bank of lockers != single searchable locker",
}

local report = {}
local deskResult
local function note(key, family, status, detail)
	table.insert(report, { key = key, family = family, status = status, detail = detail })
end

-- ---------------------------------------------------------------- asset loading (parallel)
local meshCache, imageCache = {}, {}
local function loadAll()
	local jobs = {}
	for name, row in IDS do
		table.insert(jobs, { "mesh", name, row[1] })
		for i = 2, 4 do
			if row[i] ~= "" then
				table.insert(jobs, { "image", name .. "#" .. i, row[i] })
			end
		end
	end
	table.insert(jobs, { "image", "troffer", TROFFER_DECAL })
	local nextJob, active = 1, 0
	local function work()
		active += 1
		while nextJob <= #jobs do
			local job = jobs[nextJob]
			nextJob += 1
			local ok, m = pcall(InsertService.LoadAsset, InsertService, tonumber(job[3]))
			if ok then
				if job[1] == "mesh" then
					-- every MeshPart of the import (a multi-object FBX also brings LED_* / Glass pieces)
					local list = {}
					for _, d in m:GetDescendants() do
						if d:IsA("MeshPart") then
							table.insert(list, d)
						end
					end
					for _, mp in list do
						mp.Parent = nil
					end
					if #list > 0 then
						meshCache[job[2]] = list
					end
				else
					local d = m:FindFirstChildWhichIsA("Decal", true)
					if d then
						imageCache[job[2]] = d.Texture
					end
				end
				m:Destroy()
			end
		end
		active -= 1
	end
	for _ = 1, 8 do
		task.spawn(work)
	end
	while active > 0 do
		task.wait(0.1)
	end
end

-- ---------------------------------------------------------------- builders
local function newModel(key)
	local m = Instance.new("Model")
	m.Name = key
	return m
end
local function part(parent, name, size, y, material, variant, color)
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
	p.Parent = parent
	return p
end
local function finish(m, size, fit, front)
	m.WorldPivot = CFrame.identity
	m:SetAttribute("BaseSize", size)
	m:SetAttribute("RuntimeApproved", true)
	m:SetAttribute("FrontAxis", front or "NegativeZ")
	if fit then
		m:SetAttribute("FitMode", fit)
	end
	return m
end
local function hasVariant(name)
	return MaterialService:FindFirstChild(name) ~= nil
end

local function slab(key, size, material, variant, color)
	local m = newModel(key)
	part(m, "Slab", size, size.Y / 2, material, variant, color)
	return finish(m, size, "Stretch")
end

local function buildWall()
	local m = newModel("wallSolid")
	local W, H, T = 8, 8, 0.44
	part(m, "Plaster", Vector3.new(W, H, 0.40), H / 2, Enum.Material.Plaster, "OH_Plaster")
	part(m, "DadoRail", Vector3.new(W, 0.28, T), 3.2, Enum.Material.Wood, "OH_Oak")
	part(m, "Skirting", Vector3.new(W, 0.5, T), 0.25, Enum.Material.SmoothPlastic, nil, Color3.fromRGB(41, 33, 28))
	return finish(m, Vector3.new(W, H, T), "Stretch")
end

local function buildFluorescent()
	local m = newModel("fluorescent")
	part(m, "Housing", Vector3.new(3.5, 0.18, 1), 0.15, Enum.Material.Metal, nil, Color3.fromRGB(205, 205, 208))
	local panel =
		part(m, "Diffuser", Vector3.new(3.3, 0.06, 0.8), 0.03, Enum.Material.Neon, nil, Color3.fromRGB(215, 208, 192))
	local img = imageCache.troffer
	if img then
		local d = Instance.new("Decal")
		d.Name = "TrofferFace"
		d.Face = Enum.NormalId.Bottom
		d.Texture = img
		d.Parent = panel
	end
	return finish(m, Vector3.new(3.5, 0.24, 1), "Stretch")
end

-- Multi-object meshes: the main piece carries the SurfaceAppearance; LED_* pieces become Neon (their own colour, no
-- texture) and `Glass` becomes Material Glass at 0.5. validateTemplate rejects lights, so the blue point light asked for
-- on the middle LED cannot live in the template: an Attachment "LedLight" marks the spot instead.
local LED_COLORS = {
	LED_Green = Color3.fromRGB(40, 220, 70),
	LED_Amber = Color3.fromRGB(255, 160, 20),
	LED_Blue = Color3.fromRGB(40, 110, 255),
}
local function buildMesh(spec)
	local key, asset, front, fit = spec[1], spec[3], spec[4], spec[5]
	local row = IDS[asset]
	if not row then
		return nil, "no asset id yet (" .. asset .. ")"
	end
	local list = meshCache[asset]
	if not list then
		return nil, "model " .. row[1] .. " failed to load"
	end
	local main
	for _, p in list do
		if not (string.sub(p.Name, 1, 4) == "LED_" or p.Name == "Glass") then
			main = p
			break
		end
	end
	if not main then
		return nil, "model " .. row[1] .. " has no main mesh"
	end
	local m = newModel(key)
	local size = main.Size
	-- Uploaded meshes are bbox-centred: sit the main box on the pivot's floor (extra pieces keep their offset from it).
	-- No yaw is baked in (a rotated part makes Stretch fit refuse non-uniform scale); the facing is declared through
	-- FrontAxis. The FBX 180-degree yaw is already inside the imported part offsets (LEDs sit at -Z, X mirrored).
	for _, src in list do
		local mp = src:Clone()
		for _, c in mp:GetChildren() do
			c:Destroy()
		end
		mp.Anchored = true
		mp.CFrame = CFrame.new(0, size.Y / 2, 0) * main.CFrame:ToObjectSpace(src.CFrame)
		if src == main then
			mp.Name = key
			local sa = Instance.new("SurfaceAppearance")
			sa.ColorMap = imageCache[asset .. "#2"] or ""
			sa.NormalMap = imageCache[asset .. "#3"] or ""
			sa.RoughnessMap = imageCache[asset .. "#4"] or ""
			sa.Parent = mp
		elseif LED_COLORS[src.Name] then
			mp.Material = Enum.Material.Neon
			mp.Color = LED_COLORS[src.Name]
			if src.Name == "LED_Amber" then -- the middle LED
				local a = Instance.new("Attachment")
				a.Name = "LedLight"
				a.Parent = mp
			end
		elseif src.Name == "Glass" then
			mp.Material = Enum.Material.Glass
			mp.Transparency = 0.5
			mp.Color = Color3.fromRGB(150, 185, 195)
		end
		mp.Parent = m
	end
	return finish(m, size, fit, front)
end

-- ---------------------------------------------------------------- measuring (scratch clones, always cleaned up)
local SCRATCH = Vector3.new(6000, 400, 6000)
local function scratch(template, scale)
	local c = template:Clone()
	local f = Instance.new("Folder")
	f.Name = "KitAssembleScratch"
	c.Parent = f
	for _, p in c:GetDescendants() do
		if p:IsA("BasePart") then
			p.Size = p.Size * scale
			p.Position = p.Position * scale + SCRATCH
			p.CanQuery = true
			p.CanCollide = true
			p.Anchored = true
			if p:IsA("MeshPart") then
				p.CollisionFidelity = Enum.CollisionFidelity.PreciseConvexDecomposition
			end
		end
	end
	f.Parent = workspace
	return f
end

local function worktopY(template)
	local f = scratch(template, Vector3.one)
	local size = template:GetAttribute("BaseSize")
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { f }
	local buckets, best, bestN = {}, nil, 0
	for ix = 1, 7 do
		for iz = 1, 5 do
			local x = -size.X / 2 + size.X * (ix - 0.5) / 7
			local z = -size.Z / 2 + size.Z * (iz - 0.5) / 5
			local hit = workspace:Raycast(SCRATCH + Vector3.new(x, size.Y + 2, z), Vector3.new(0, -size.Y - 3, 0), params)
			if hit then
				local y = math.floor((hit.Position.Y - SCRATCH.Y) / 0.05 + 0.5) * 0.05
				buckets[y] = (buckets[y] or 0) + 1
				if buckets[y] > bestN then
					best, bestN = y, buckets[y]
				end
			end
		end
	end
	f:Destroy()
	return best, bestN
end

local function measureDesk(template)
	local base = template:GetAttribute("BaseSize")
	local scale = DESK_SIZE / base
	-- Exact-geometry test: every face of the desk's mesh (through an EditableMesh) as an axis-aligned box, scaled to
	-- DESK_SIZE, floor-up. GetPartBoundsInBox on one big MeshPart answers with the part's bounds, so it can never see a
	-- knee-hole; the face boxes can (exact for the desk's flat panels, conservative on rounded edges).
	local mp = template:FindFirstChildWhichIsA("MeshPart")
	local em = game:GetService("AssetService"):CreateEditableMeshAsync(Content.fromUri(mp.MeshId))
	local tris = {}
	for _, fid in em:GetFaces() do
		local lo, hi
		for _, vid in em:GetFaceVertices(fid) do
			local p = em:GetPosition(vid) * scale + Vector3.new(0, DESK_SIZE.Y / 2, 0)
			lo = lo and lo:Min(p) or p
			hi = hi and hi:Max(p) or p
		end
		table.insert(tris, { lo, hi })
	end
	local function free(centre, size)
		local a, b = centre - size / 2 + Vector3.one * 0.01, centre + size / 2 - Vector3.one * 0.01
		for _, t in tris do
			local lo, hi = t[1], t[2]
			if lo.X < b.X and hi.X > a.X and lo.Y < b.Y and hi.Y > a.Y and lo.Z < b.Z and hi.Z > a.Z then
				return false
			end
		end
		return true
	end
	local out = { scale = scale }
	-- 1) the gameplay free box (HideConstants.FURNITURE.desk.free) at DESK_SIZE, floor-up.
	local fmin, fmax = DESK_FREE_FRAC.min * DESK_SIZE, DESK_FREE_FRAC.max * DESK_SIZE
	out.gameplayBoxSize = fmax - fmin
	out.gameplayBoxFree =
		free(Vector3.new((fmin.X + fmax.X) / 2, (fmin.Y + fmax.Y) / 2 + DESK_SIZE.Y / 2, (fmin.Z + fmax.Z) / 2), fmax - fmin)
	-- 2) every placement of a HUG_FREE_MIN box under the desk (floor-up).
	local count, lo, hi, zlo, zhi = 0, math.huge, -math.huge, math.huge, -math.huge
	for x = -DESK_SIZE.X / 2 + HUG_FREE_MIN.X / 2, DESK_SIZE.X / 2 - HUG_FREE_MIN.X / 2 + 0.001, 0.25 do
		for z = -DESK_SIZE.Z / 2 + HUG_FREE_MIN.Z / 2, DESK_SIZE.Z / 2 - HUG_FREE_MIN.Z / 2 + 0.001, 0.05 do
			if free(Vector3.new(x, HUG_FREE_MIN.Y / 2, z), HUG_FREE_MIN) then
				count += 1
				lo, hi = math.min(lo, x), math.max(hi, x)
				zlo, zhi = math.min(zlo, z), math.max(zhi, z)
			end
		end
	end
	out.hugPlacements = count
	if count > 0 then
		out.hugRange = ("x %.2f..%.2f z %.2f..%.2f"):format(lo, hi, zlo, zhi)
	end
	-- 3) the biggest free box with the desk's full front: scan heights for a 3.6 x 4.3 footprint.
	local maxH = 0
	for h = 3, 5, 0.1 do
		local found = false
		for x = -DESK_SIZE.X / 2 + HUG_FREE_MIN.X / 2, DESK_SIZE.X / 2 - HUG_FREE_MIN.X / 2 + 0.001, 0.25 do
			for z = -DESK_SIZE.Z / 2 + HUG_FREE_MIN.Z / 2, DESK_SIZE.Z / 2 - HUG_FREE_MIN.Z / 2 + 0.001, 0.1 do
				if free(Vector3.new(x, h / 2, z), Vector3.new(HUG_FREE_MIN.X, h, HUG_FREE_MIN.Z)) then
					found = true
					break
				end
			end
			if found then
				break
			end
		end
		if found then
			maxH = h
		end
	end
	out.maxHeightAtHugFootprint = maxH
	return out
end

-- ---------------------------------------------------------------- run
local ok, err = pcall(function()
	loadAll()

	local assets = ReplicatedStorage:FindFirstChild("Assets") or Instance.new("Folder")
	assets.Name = "Assets"
	assets.Parent = ReplicatedStorage
	local crew = assets:FindFirstChild("CleanupCrew") or Instance.new("Folder")
	crew.Name = "CleanupCrew"
	crew.Parent = assets
	local kits = crew:FindFirstChild("ArtKits") or Instance.new("Folder")
	kits.Name = "ArtKits"
	kits.Parent = crew
	local old = kits:FindFirstChild(KIT_ID)
	if old then
		old:Destroy()
	end
	local kit = Instance.new("Folder")
	kit.Name = KIT_ID
	local groups = {}
	for _, fam in { "building", "furniture" } do
		local g = Instance.new("Folder")
		g.Name = fam
		g.Parent = kit
		groups[fam] = g
	end

	local templates = {} -- key -> { model, family }
	local function add(key, family, model, detail)
		model.Parent = groups[family]
		templates[key] = { model = model, family = family }
		note(key, family, "built", detail or "")
	end

	-- building surfaces
	add("floorTile", "building", slab("floorTile", Vector3.new(4, 0.092, 4), Enum.Material.Fabric, "OH_Carpet"), "OH_Carpet")
	add(
		"floorTile_hallway",
		"building",
		slab("floorTile_hallway", Vector3.new(4, 0.092, 4), Enum.Material.Fabric, "OH_Carpet", Color3.new(0.75, 0.75, 0.78)),
		"OH_Carpet tinted 0.75,0.75,0.78"
	)
	add("ceilingTile", "building", slab("ceilingTile", Vector3.new(4, 0.1, 4), Enum.Material.Concrete, "OH_Ceiling"), "OH_Ceiling")
	add("wallSolid", "building", buildWall(), "OH_Plaster body + OH_Oak dado rail at 3.2 + dark skirting")
	add(
		"fluorescent",
		"building",
		buildFluorescent(),
		imageCache.troffer and "metal housing + Neon diffuser + surf troffer decal" or "troffer decal failed to load"
	)
	if hasVariant("OH_Vinyl") then
		add("floorTile_server", "building", slab("floorTile_server", Vector3.new(4, 0.092, 4), Enum.Material.Plastic, "OH_Vinyl"), "OH_Vinyl")
	else
		note("floorTile_server", "building", "pending", "MaterialVariant OH_Vinyl not in MaterialService yet (Task 4)")
	end
	if hasVariant("OH_Lino") then
		add("floorTile_breakout", "building", slab("floorTile_breakout", Vector3.new(4, 0.092, 4), Enum.Material.Plastic, "OH_Lino"), "OH_Lino")
	else
		note("floorTile_breakout", "building", "pending", "MaterialVariant OH_Lino not in MaterialService yet (Task 4)")
	end

	-- mesh pieces
	for _, spec in MESH do
		local key, family = spec[1], spec[2]
		local model, why
		if not HELD[key] then
			model, why = buildMesh(spec)
		end
		if HELD[key] then
			note(key, family, "held", HELD[key])
		elseif model then
			add(key, family, model, "asset " .. spec[3] .. " model " .. IDS[spec[3]][1])
		elseif IDS[spec[3]] then
			note(key, family, "failed", why)
		else
			note(key, family, "pending", why)
		end
	end

	-- kitchenCounter worktop height
	local kc = templates.kitchenCounter
	if kc then
		local y, n = worktopY(kc.model)
		if y and y > 0 then
			kc.model:SetAttribute("SupportSurfaceY", y)
			for _, r in ipairs(report) do
				if r.key == "kitchenCounter" then
					r.detail ..= (" SupportSurfaceY=%.2f (%d/35 rays)"):format(y, n)
				end
			end
		end
	end

	kit.Parent = kits

	-- validation on a fresh clone of the rules (Edit caches requires across calls)
	local okRules, Rules = pcall(function()
		return require(ReplicatedStorage.Shared.Features.Art.Rules.ArtKitRules:Clone())
	end)
	for _, r in ipairs(report) do
		local t = templates[r.key]
		if t then
			if okRules then
				r.valid = Rules.validateTemplate(t.model, t.family)
			else
				r.valid = "rules require failed: " .. tostring(Rules)
			end
			r.size = t.model:GetAttribute("BaseSize")
			r.front = t.model:GetAttribute("FrontAxis")
			r.fit = t.model:GetAttribute("FitMode") or "Uniform"
		end
	end

	if templates.desk then
		local okM, res = pcall(measureDesk, templates.desk.model)
		deskResult = okM and res or ("desk measure failed: " .. tostring(res))
	end
end)

for _, f in workspace:GetChildren() do
	if f.Name == "KitAssembleScratch" then
		f:Destroy()
	end
end

local lines = { ok and "ASSEMBLE OK" or ("ASSEMBLE ERROR: " .. tostring(err)) }
local built, pending, failed, invalid, held = 0, 0, 0, 0, 0
for _, r in ipairs(report) do
	if r.status == "built" then
		built += 1
		if r.valid ~= true then
			invalid += 1
		end
	elseif r.status == "pending" then
		pending += 1
	elseif r.status == "held" then
		held += 1
	else
		failed += 1
	end
	table.insert(
		lines,
		("%-20s %-9s %-8s valid=%s size=%s front=%s fit=%s | %s"):format(
			r.key,
			r.family,
			r.status,
			tostring(r.valid),
			tostring(r.size),
			tostring(r.front),
			tostring(r.fit),
			r.detail
		)
	)
end
table.insert(lines, ("built %d (invalid %d), pending %d, held %d, failed %d"):format(built, invalid, pending, held, failed))
local d = deskResult
if type(d) == "string" then
	table.insert(lines, d)
elseif d then
	table.insert(
		lines,
		("desk scale to DESK_SIZE=%s; gameplay free box %s free=%s; HUG_FREE_MIN placements=%d (%s); max free height at HUG footprint=%.1f"):format(
			tostring(d.scale),
			tostring(d.gameplayBoxSize),
			tostring(d.gameplayBoxFree),
			d.hugPlacements,
			d.hugRange or "none",
			d.maxHeightAtHugFootprint
		)
	)
end
print(table.concat(lines, "\n"))
return table.concat(lines, "\n")
