--!nocheck
-- Odd Hours: Shift place, Edit only. Builds Workspace.YardDressing (Y3b + Y4): the uploaded yard props, the grass verges,
-- the critters (tagged for OfficeCritterSystem), moths and fireflies, and the yard's sound emitters (OfficeAmbient +
-- AmbientKind, replacing the yard-sounds check's Play-only stand-ins). It also marks every OfficeExterior puddle
-- FootstepSurface = "puddle". Idempotent: rebuilds the folder each run, as one ChangeHistory step (Ctrl+Z undoes it).
-- It never touches OfficeExterior's parts except the puddles' attribute.
--
-- Keep clear (checked below, the build fails if any prop breaks it): the walk x 1158..1178 from the dock to the ramp,
-- the size-B truck x 1155.7..1180.3, z -299.2..-256.8, and a 3-stud circle round the time clock at (1154, -266).
-- Uploaded meshes face -Z with X mirrored (the FBX yaw), bbox-centred; each prop is sat on its ground height.
-- Move a placed prop by its parts' CFrames, never Model:PivotTo with a fresh CFrame: the imported MeshParts carry a
-- rotated PivotOffset, so a pivot set from scratch tips the prop over.
local CHS = game:GetService("ChangeHistoryService")
local CS = game:GetService("CollectionService")
local InsertService = game:GetService("InsertService")

local GROUND, PLAZA_Y, DOCK_PAD = 1, 1.36, 1.04
-- asset name -> { meshModelId, colorDecalId, normalDecalId, roughDecalId }; variants share the mesh and normal/rough.
local IDS = {
	barrier = { "107059430327819", "79841143876258", "126318193742699", "101427770107594" },
	bench = { "99129171058320", "127541960898299", "79650145156260", "78270077375260" },
	bush = { "114571124724181", "95821687539559", "92007558861805", "90480410491905" },
	cone = { "140123719893363", "108089628903286", "139056808647485", "119755604015542" },
	crate = { "115108966153333", "135899822188897", "107554063448886", "88629089768109" },
	dumpster = { "114997248879558", "77020746587484", "140365030432984", "115402919982042" },
	grasstuft = { "111453906114963", "137200269164953", "135835380441757", "133928926463275" },
	litterbin = { "87243277234466", "112008270790963", "112108794306893", "89632921209144" },
	pallet = { "89472207242261", "85356196337483", "111069891457077", "102075710834044" },
	trolley = { "129292713286698", "110050424738913", "108391649396107", "118079193200125" },
	vending = { "78850651177438", "112699350030878", "102946587953183", "138497350541945" },
	wheeliebin = { "98844215820757", "76792255976618", "109145701732022", "104131614731105" },
	wheeliebin_blue = { "", "74551611307593", "", "" },
	wheeliebin_grey = { "", "99262432947391", "", "" },
}
local SPRITES = { firefly = "117088947509602", moth = "104684850183899" } -- decal ids, resolved to images below

-- ------------------------------------------------------------------ loading
local meshCache, imageCache = {}, {}
local function loadAll()
	local jobs = {}
	for name, row in IDS do
		if row[1] ~= "" then
			table.insert(jobs, { "mesh", name, row[1] })
		end
		for i = 2, 4 do
			if row[i] ~= "" then
				table.insert(jobs, { "image", name .. "#" .. i, row[i] })
			end
		end
	end
	for name, id in SPRITES do
		if id ~= "" then
			table.insert(jobs, { "image", "sprite#" .. name, id })
		end
	end
	local nextJob, active = 1, 0
	local function work()
		active += 1
		while nextJob <= #jobs do
			local job = jobs[nextJob]
			nextJob += 1
			local ok, m = pcall(InsertService.LoadAsset, InsertService, tonumber(job[3]))
			if ok then
				if job[1] == "mesh" then
					local list = {}
					for _, d in m:GetDescendants() do
						if d:IsA("MeshPart") then
							table.insert(list, d)
						end
					end
					for _, mp in list do
						mp.Parent = nil
					end
					meshCache[job[2]] = list
				else
					local d = m:FindFirstChildWhichIsA("Decal", true)
					if d then
						imageCache[job[2]] = d.Texture
					end
				end
				m:Destroy()
			else
				warn("load failed", job[2], job[3])
			end
		end
		active -= 1
	end
	for _ = 1, 8 do
		task.spawn(work)
	end
	repeat
		task.wait(0.1)
	until active == 0
end

-- ------------------------------------------------------------------ building
local ROOT
local placed = {} -- { model, keepClear }
local HAZARD_ON = Color3.fromRGB(255, 150, 30)

-- One prop: a Model of the uploaded pieces, the biggest one textured, sat on `baseY` at (x, z) facing `dir`.
-- `tex` picks a colour variant (its own colour map, the mesh's normal/rough).
local function prop(parent, mesh, tex, x, z, dir, baseY, opts)
	opts = opts or {}
	local list = meshCache[mesh]
	assert(list and #list > 0, "mesh not loaded: " .. mesh)
	local main
	for _, p in list do
		if not (p.Name == "Glass" or p.Name == "Glow" or p.Name == "Hazard") then
			if not main or p.Size.Magnitude > main.Size.Magnitude then
				main = p
			end
		end
	end
	local m = Instance.new("Model")
	m.Name = opts.name or mesh
	local at = Vector3.new(x, (baseY or GROUND) + main.Size.Y / 2, z)
	local cf = CFrame.lookAt(at, at + (dir or Vector3.new(0, 0, -1)))
	for _, src in list do
		local mp = src:Clone()
		for _, c in mp:GetChildren() do
			c:Destroy()
		end
		mp.Anchored = true
		mp.CFrame = cf * main.CFrame:ToObjectSpace(src.CFrame)
		if src == main then
			mp.Name = mesh
			local sa = Instance.new("SurfaceAppearance")
			sa.ColorMap = imageCache[(tex or mesh) .. "#2"] or ""
			sa.NormalMap = imageCache[mesh .. "#3"] or ""
			sa.RoughnessMap = imageCache[mesh .. "#4"] or ""
			sa.Parent = mp
			mp.CollisionFidelity = Enum.CollisionFidelity.Box
			mp.CanCollide = opts.collide ~= false
		elseif src.Name == "Glass" then
			-- tinted see-through plastic: Material Glass reflects so much it washes out the drinks behind it
			mp.Material = Enum.Material.SmoothPlastic
			mp.Transparency = 0.82
			mp.Color = Color3.fromRGB(170, 205, 215)
			mp.CanCollide = false
		elseif src.Name == "Glow" then
			mp.Material = Enum.Material.Neon
			mp.Color = Color3.fromRGB(205, 180, 135)
			mp.CanCollide = false
		elseif src.Name == "Hazard" then
			mp.Material = Enum.Material.SmoothPlastic
			mp.Color = Color3.fromRGB(120, 70, 20)
			if opts.hazard then
				-- Blinking corner lights with no code: a glow particle at each lamp, one every 0.8 s, 0.45 s long.
				-- The lamps sit at this piece's corners (front pair wide at -Z, back pair at x +-2.2 at +Z).
				local hz = mp.Size
				for _, at in
					{
						Vector3.new(hz.X / 2 - 0.25, 0, -hz.Z / 2 + 0.2),
						Vector3.new(-hz.X / 2 + 0.25, 0, -hz.Z / 2 + 0.2),
						Vector3.new(2.2, 0, hz.Z / 2 - 0.12),
						Vector3.new(-2.2, 0, hz.Z / 2 - 0.12),
					}
				do
					local a = Instance.new("Attachment")
					a.Name = "HazardLamp"
					a.Position = at
					a.Parent = mp
					local e = Instance.new("ParticleEmitter")
					e.Name = "HazardBlink"
					e.Texture = imageCache["sprite#firefly"] or ""
					e.Color = ColorSequence.new(HAZARD_ON)
					e.LightEmission = 1
					e.LightInfluence = 0
					e.Size = NumberSequence.new(1.1)
					e.Transparency = NumberSequence.new(0.05)
					e.Lifetime = NumberRange.new(0.45)
					e.Rate = 1.25
					e.Speed = NumberRange.new(0)
					e.LockedToPart = true
					e.ZOffset = 0.3
					e.Parent = a
				end
			end
			mp.CanCollide = false
		end
		if opts.collide == false then
			mp.CanCollide = false
			mp.CanQuery = false
			mp.CanTouch = false
		end
		mp.Parent = m
		if src == main then
			m.PrimaryPart = mp
		end
	end
	m.Parent = parent
	table.insert(placed, { m, opts.keepClear ~= false })
	return m
end

local function folder(name, parent)
	local f = Instance.new("Folder")
	f.Name = name
	f.Parent = parent or ROOT
	return f
end

local function invisible(name, size, cf, parent)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Transparency = 1
	p.Parent = parent
	return p
end

local function emitter(kind, centre, size, parent)
	local p = invisible("Emitter_" .. kind, size, CFrame.new(centre), parent)
	p:SetAttribute("AmbientKind", kind)
	CS:AddTag(p, "OfficeAmbient")
	return p
end

local function critter(parent, mesh, kind, x, z, face, baseY, flee, drop)
	local m =
		prop(parent, mesh, nil, x, z, face, baseY, { collide = false, name = "Critter_" .. kind, keepClear = false })
	m:SetAttribute("CritterKind", kind)
	m:SetAttribute("FleeDirection", flee)
	if drop then
		m:SetAttribute("FleeDrop", drop)
	end
	CS:AddTag(m, "OfficeCritter")
	return m
end

local function particles(name, size, cf, parent, sprite, props)
	local p = invisible(name, size, cf, parent)
	local e = Instance.new("ParticleEmitter")
	e.Name = name
	e.Texture = imageCache["sprite#" .. sprite] or ""
	for k, v in props do
		e[k] = v
	end
	e.Parent = p
	return p
end

-- ------------------------------------------------------------------ the set
local function build()
	local W, E, S, N = Vector3.new(-1, 0, 0), Vector3.new(1, 0, 0), Vector3.new(0, 0, -1), Vector3.new(0, 0, 1)
	local rng = Random.new(1105)

	-- Dock apron: dumpster (lid propped open on its -X half), three wheelie bins, pallets, crates, the drinks machine.
	local dock = folder("Dock")
	local dumpster = prop(dock, "dumpster", nil, 1106, -70.6, S, DOCK_PAD)
	prop(dock, "wheeliebin", "wheeliebin", 1136, -68, Vector3.new(0.1, 0, -1).Unit, DOCK_PAD)
	prop(dock, "wheeliebin", "wheeliebin_blue", 1139.2, -68.3, S, DOCK_PAD)
	prop(dock, "wheeliebin", "wheeliebin_grey", 1142.4, -67.9, Vector3.new(-0.12, 0, -1).Unit, DOCK_PAD)
	for i, h in { 0, 0.62, 1.24 } do
		prop(dock, "pallet", nil, 1236 + (i - 2) * 0.15, -86, Vector3.new(math.sin(i * 0.07), 0, -1).Unit, DOCK_PAD + h)
	end
	for i, h in { 0, 0.62 } do
		prop(dock, "pallet", nil, 1236.3, -92.6, Vector3.new(math.sin(-i * 0.09), 0, -1).Unit, DOCK_PAD + h)
	end
	prop(dock, "crate", nil, 1231.4, -88, S, DOCK_PAD)
	prop(dock, "crate", nil, 1231.5, -88.1, Vector3.new(0.2, 0, -1).Unit, DOCK_PAD + 1.15)
	prop(dock, "crate", nil, 1229.2, -90.6, Vector3.new(0.5, 0, -1).Unit, DOCK_PAD)
	prop(dock, "crate", nil, 1236, -84.7 + 0.2, S, DOCK_PAD + 1.86)
	local vend = prop(dock, "vending", nil, 1243, -66.2, S, DOCK_PAD)
	local glow = vend:FindFirstChild("Glow")
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 226, 180)
	light.Brightness = 1.2
	light.Range = 12
	light.Shadows = false
	light.Parent = glow or vend.PrimaryPart

	-- The walk's edges (never on it): cones, a barricade, a lone trolley.
	local walk = folder("Walk")
	prop(walk, "cone", nil, 1185, -118, S)
	prop(walk, "cone", nil, 1187.6, -121.2, Vector3.new(0.6, 0, -1).Unit)
	prop(walk, "cone", nil, 1185.8, -124.6, S)
	prop(walk, "cone", nil, 1150.5, -181, Vector3.new(-0.4, 0, -1).Unit)
	prop(walk, "barrier", nil, 1183.4, -196, W)
	prop(walk, "trolley", nil, 1149, -238, Vector3.new(0.5, 0, 1).Unit)

	-- Grass verges along the walk (grass footstep layer) with tufts, bushes and fireflies.
	local verge = folder("Verges")
	for _, v in { { 1128, 1136, -245, -120 }, { 1186, 1194, -245, -132 } } do
		local g = Instance.new("Part")
		g.Name = "Verge"
		g.Anchored = true
		g.Material = Enum.Material.Grass
		g.Color = Color3.fromRGB(34, 46, 32)
		g.Size = Vector3.new(v[2] - v[1], 0.16, v[4] - v[3])
		g.CFrame = CFrame.new((v[1] + v[2]) / 2, GROUND - 0.02, (v[3] + v[4]) / 2)
		g.Parent = verge
		for _ = 1, 9 do
			local x, z = rng:NextNumber(v[1] + 0.8, v[2] - 0.8), rng:NextNumber(v[3] + 1, v[4] - 1)
			local a = rng:NextNumber(0, math.pi * 2)
			prop(
				verge,
				"grasstuft",
				nil,
				x,
				z,
				Vector3.new(math.cos(a), 0, math.sin(a)),
				GROUND + 0.06,
				{ collide = false, keepClear = false }
			)
		end
		particles(
			"Fireflies",
			Vector3.new(v[2] - v[1], 2, v[4] - v[3]),
			CFrame.new((v[1] + v[2]) / 2, GROUND + 2.5, (v[3] + v[4]) / 2),
			verge,
			"firefly",
			{
				Color = ColorSequence.new(Color3.fromRGB(215, 255, 120)),
				LightEmission = 1,
				Size = NumberSequence.new({
					NumberSequenceKeypoint.new(0, 0),
					NumberSequenceKeypoint.new(0.2, 0.28),
					NumberSequenceKeypoint.new(0.8, 0.28),
					NumberSequenceKeypoint.new(1, 0),
				}),
				Transparency = NumberSequence.new({
					NumberSequenceKeypoint.new(0, 1),
					NumberSequenceKeypoint.new(0.3, 0.1),
					NumberSequenceKeypoint.new(0.5, 0.6),
					NumberSequenceKeypoint.new(0.7, 0.1),
					NumberSequenceKeypoint.new(1, 1),
				}),
				Lifetime = NumberRange.new(4, 7),
				Rate = 2.5,
				Speed = NumberRange.new(0.3, 0.8),
				SpreadAngle = Vector2.new(180, 180),
				RotSpeed = NumberRange.new(0, 0),
				Acceleration = Vector3.new(0, 0.15, 0),
				Drag = 0.6,
				LightInfluence = 0,
			}
		)
	end
	prop(verge, "bush", nil, 1131.5, -151, Vector3.new(0.3, 0, -1).Unit, GROUND + 0.06)
	prop(verge, "bush", nil, 1132.5, -223, Vector3.new(-0.6, 0, -1).Unit, GROUND + 0.06)
	prop(verge, "bush", nil, 1190.5, -226, Vector3.new(0.8, 0, -1).Unit, GROUND + 0.06)

	-- Moths round two walk poles and the pad's east pole (not the leaningLamp pole: they would not lean with it).
	local moths = folder("Moths")
	for _, at in { Vector3.new(1145.2, 23.2, -110), Vector3.new(1145.2, 23.2, -210), Vector3.new(1191.8, 23.2, -258) } do
		particles("Moths", Vector3.new(3, 2, 3), CFrame.new(at), moths, "moth", {
			Color = ColorSequence.new(Color3.fromRGB(255, 236, 200)),
			LightEmission = 0.3,
			Size = NumberSequence.new(0.32),
			Lifetime = NumberRange.new(1.2, 2.4),
			Rate = 5,
			Speed = NumberRange.new(2, 4),
			SpreadAngle = Vector2.new(180, 180),
			Rotation = NumberRange.new(0, 360),
			RotSpeed = NumberRange.new(-260, 260),
			Drag = 2,
			Orientation = Enum.ParticleOrientation.FacingCamera,
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 1),
				NumberSequenceKeypoint.new(0.15, 0),
				NumberSequenceKeypoint.new(0.85, 0),
				NumberSequenceKeypoint.new(1, 1),
			}),
		})
	end

	-- West car park (noses toward the building, the carTicking blockout car at z 35 stays) and the front row.
	local cars = folder("Cars")
	if IDS.car then -- the cars and critters are placed once their meshes are approved and uploaded
		prop(cars, "car", "car", 910, -15, E)
		prop(cars, "car", "car_slate", 910, 15, E, nil, { hazard = true, name = "car_hazards" })
		prop(cars, "car", "car_red", 910, 65, E)
		prop(cars, "car", "car", 910, 95, E)
		prop(cars, "car", "car_slate", 1061, -131, N)
	end

	-- Gate booth: a little radio on the desk (the boothRadio emitter sits in it).
	local booth = folder("Booth")
	local radio = Instance.new("Part")
	radio.Name = "Radio"
	radio.Anchored = true
	radio.Material = Enum.Material.SmoothPlastic
	radio.Color = Color3.fromRGB(70, 46, 34)
	radio.Size = Vector3.new(1.4, 0.8, 0.6)
	radio.CFrame = CFrame.new(1305.5, GROUND + 3.6 + 0.4, -254.4)
	radio.Parent = booth
	local dial = Instance.new("Part")
	dial.Name = "RadioDial"
	dial.Anchored = true
	dial.CanCollide = false
	dial.Material = Enum.Material.Neon
	dial.Color = Color3.fromRGB(255, 190, 110)
	dial.Size = Vector3.new(0.5, 0.18, 0.05)
	dial.CFrame = radio.CFrame * CFrame.new(0.3, 0.12, -0.32)
	dial.Parent = booth

	-- Plaza: a picnic bench and a plain litter bin.
	local plaza = folder("Plaza")
	-- the free strip between the two planters (z 178..186): the planters, hedges and topiaries fill the rest
	prop(plaza, "bench", nil, 932, 181.5, N, PLAZA_Y)
	prop(plaza, "litterbin", nil, 938.6, 182, S, PLAZA_Y)

	-- Critters (dressing only): the cat on the dumpster's closed lid half, the raccoon in its open half, crows on the
	-- south fence rail behind the truck pad.
	local crit = folder("Critters")
	if IDS.cat then
		local d = dumpster.PrimaryPart
		local base = d.Position.Y - d.Size.Y / 2
		-- the mesh is X-mirrored: the propped-open lid half is the dumpster's world -X half here
		critter(crit, "cat", "cat", d.Position.X + 2.3, d.Position.Z + 0.3, S, base + 5.62, W, 5.62)
		critter(crit, "raccoon", "raccoon", d.Position.X - 2.4, d.Position.Z - 0.6, S, base + 5.0, S)
		for i, x in { 1139, 1144.5, 1150 } do
			critter(crit, "crow", "crow", x, -321, Vector3.new(0.2 * (i - 2), 0, 1).Unit, GROUND + 8.9, S)
		end
	end

	-- Sound emitters (yard design doc, Y3b table): placed with the props.
	local se = folder("SoundEmitters")
	local ext = workspace:FindFirstChild("OfficeExterior")
	local siteLights = ext and ext:FindFirstChild("SiteLights")
	if siteLights then
		for _, l in siteLights:GetDescendants() do
			if l:IsA("Light") and l.Parent:IsA("BasePart") then
				emitter("lampBuzz", l.Parent.Position, Vector3.new(1, 1, 1), se)
			end
		end
	end
	local vp = vend.PrimaryPart
	emitter("vendingHum", vp.Position, vp.Size, se).CFrame = vp.CFrame
	emitter("boothRadio", radio.Position, Vector3.new(1, 1, 1), se)
	emitter("roadSide", Vector3.new(1425, 2, -276), Vector3.new(190, 4, 18), se)
	emitter("farCar", Vector3.new(1425, 2, -276), Vector3.new(190, 4, 18), se)
	emitter("owl", Vector3.new(1080, 22, -345), Vector3.new(480, 10, 20), se)
	emitter("owl", Vector3.new(815, 22, -46), Vector3.new(20, 10, 540), se)
	emitter("owl", Vector3.new(1345, 22, 0), Vector3.new(20, 10, 400), se)
	emitter("fenceRattle", Vector3.new(1079, 5, -321), Vector3.new(486, 6, 1), se)
	emitter("fenceRattle", Vector3.new(836, 5, -46), Vector3.new(1, 6, 551), se)
	emitter("fenceRattle", Vector3.new(1322, 5, -150), Vector3.new(1, 6, 330), se)
	emitter("canRoll", Vector3.new(1100, 1, -95), Vector3.new(30, 1, 20), se)
	emitter("canRoll", Vector3.new(965, 1, -100), Vector3.new(40, 1, 60), se)
	emitter("canRoll", Vector3.new(1233, 1, -82), Vector3.new(16, 1, 14), se)

	-- Puddles: the footstep puddle layer.
	local puddles = 0
	if ext then
		for _, p in ext:GetDescendants() do
			if p:IsA("BasePart") and p.Name == "Puddle" then
				p:SetAttribute("FootstepSurface", "puddle")
				p.CanQuery = true -- the footsteps' downward ray skips CanQuery-off parts
				puddles += 1
			end
		end
	end
	return puddles
end

-- ------------------------------------------------------------------ checks
local function bounds(m)
	local cf, size = m:GetBoundingBox()
	return cf.Position - size / 2, cf.Position + size / 2
end
local function checkClear()
	local bad = {}
	for _, row in placed do
		local m, keep = row[1], row[2]
		if keep then
			local lo, hi = bounds(m)
			local function hits(x0, x1, z0, z1)
				return hi.X > x0 and lo.X < x1 and hi.Z > z0 and lo.Z < z1
			end
			if hits(1158, 1178, -256.8, -64) or hits(1155.7, 1180.3, -299.2, -256.8) then
				table.insert(bad, m.Name .. " on the walk / truck")
			end
			local cx = math.clamp(1154, lo.X, hi.X)
			local cz = math.clamp(-266, lo.Z, hi.Z)
			if (Vector2.new(cx, cz) - Vector2.new(1154, -266)).Magnitude < 3 then
				table.insert(bad, m.Name .. " by the time clock")
			end
		end
	end
	return bad
end

-- ------------------------------------------------------------------ run
local rec = CHS:TryBeginRecording("PlaceYardDressing")
local ok, result = pcall(function()
	loadAll()
	local old = workspace:FindFirstChild("YardDressing")
	ROOT = Instance.new("Folder")
	ROOT.Name = "YardDressing_Building"
	ROOT.Parent = workspace
	local puddles = build()
	local bad = checkClear()
	assert(#bad == 0, "keep-clear broken: " .. table.concat(bad, "; "))
	local parts, lights = 0, 0
	for _, d in ROOT:GetDescendants() do
		if d:IsA("BasePart") then
			parts += 1
		elseif d:IsA("Light") then
			lights += 1
		end
	end
	if old then
		old:Destroy()
	end
	ROOT.Name = "YardDressing"
	return string.format(
		"YardDressing: %d parts, %d lights, %d props, %d puddles marked",
		parts,
		lights,
		#placed,
		puddles
	)
end)
if not ok then
	if ROOT then
		ROOT:Destroy()
	end
	if rec then
		CHS:FinishRecording(rec, Enum.FinishRecordingOperation.Cancel)
	end
	error(result)
end
if rec then
	CHS:FinishRecording(rec, Enum.FinishRecordingOperation.Commit)
end
print(result)
return result
