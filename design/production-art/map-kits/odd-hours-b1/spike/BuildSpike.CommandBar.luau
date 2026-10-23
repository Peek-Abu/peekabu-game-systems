--!nolint
-- THROWAWAY FEEL SPIKE (Odd Hours office slice, mock-room build style).
-- Paste into the Studio command bar (Edit). Idempotent: deletes and rebuilds Workspace.ClaudeSpike.
-- Reuses Workspace.ClaudeMockRoom parts (CeilingPanel, Rug, ReceptionPanel/Glow, c_windowbay, c_monitor2)
-- and ReplicatedStorage.Assets.CleanupCrew.ArtKits["odd-hours-b1"] templates (bottom-centred pivots, front = -Z).
-- Not production code. Never saves or publishes.

local SPIKE_NAME = "ClaudeSpike"
local old = workspace:FindFirstChild(SPIKE_NAME)
if old then old:Destroy() end

local MOCK = workspace:FindFirstChild("ClaudeMockRoom")
assert(MOCK, "ClaudeMockRoom missing (spike clones its panels/rug/window bay/monitor)")
local KIT = game:GetService("ReplicatedStorage").Assets.CleanupCrew.ArtKits["odd-hours-b1"]

------------------------------------------------------------------ parameters
local FLOOR_Y, CEIL_Y = 10, 23 -- floor top / ceiling bottom (13 tall, like the mock room)
local BASE_Y, TOP_Y = 9, 24 -- walls run 9..24 so floors and ceilings butt into them (camera enclosure)
local WALL_T = 0.5 -- each space owns a 0.5 slab; spaces sit 1 stud apart, so a shared wall is 1 thick
local DOOR_W, DOOR_H = 6.8, 9.4 -- rough opening; oak casing 0.35 eats into it -> ~6.1 x 9.05 clear
local CASE = 0.35
local WAIN_H, WAIN_D = 3, 0.3
local RAIL_Y, RAIL_H, RAIL_D = 13.1, 0.25, 0.5
local SKIRT_H, SKIRT_D = 0.6, 0.4 -- skirt 0.1 proud of the wainscot (mock's was coplanar = z-fight)

local WARM_FILL = Color3.fromRGB(255, 232, 205)
local LAMP_COL = Color3.fromRGB(255, 168, 90)
local GLOW_COL = Color3.fromRGB(255, 200, 140)
local LED_COL = Color3.fromRGB(110, 165, 255)

-- per-space light amounts (same warm colour everywhere; only the amount changes)
local LIGHT = {
	room = { panelB = 0.22, fillB = 1.7, fillR = 11.5 },
	conf = { panelB = 0.22, fillB = 1.5, fillR = 11.5 },
	hall = { panelB = 0.2, fillB = 1.3, fillR = 12 },
	server = { panelB = 0.12, fillB = 0.6, fillR = 10 },
	store = { panelB = 0.15, fillB = 0.8, fillR = 10 },
}

------------------------------------------------------------------ mock-room reference parts
local function mockFind(name, pred)
	for _, c in ipairs(MOCK:GetDescendants()) do
		if c.Name == name and (not pred or pred(c)) then return c end
	end
	error("mock part not found: " .. name)
end
local PANEL_LIT = mockFind("CeilingPanel", function(c) return c:FindFirstChildOfClass("SurfaceLight") ~= nil end)
local PANEL_OFF = mockFind("CeilingPanel", function(c) return c:FindFirstChildOfClass("SurfaceLight") == nil end)
local RUG = mockFind("Rug")
local REC_PANEL = mockFind("ReceptionPanel")
local REC_GLOW = mockFind("ReceptionGlow")
local WINDOW_BAY = mockFind("c_windowbay")
local BLINDS = mockFind("c_blinds_full")
local MONITOR = mockFind("c_monitor2")
local GLASS_REF = mockFind("ConfGlassZ")
local FRAME_REF = mockFind("ConfFrame")
local GRID_REF = mockFind("Grid")

local root = Instance.new("Folder")
root.Name = SPIKE_NAME
root.Parent = workspace

------------------------------------------------------------------ helpers
local MAT = {
	plaster = { Material = Enum.Material.Plaster, MaterialVariant = "OH_Plaster", Color = Color3.new(1, 1, 1) },
	oak = { Material = Enum.Material.Wood, MaterialVariant = "OH_Oak", Color = Color3.new(1, 1, 1) },
	rail = { Material = Enum.Material.Wood, Color = Color3.fromRGB(110, 80, 56) },
	skirt = { Material = Enum.Material.SmoothPlastic, Color = Color3.fromRGB(150, 112, 80) },
	ceiling = { Material = Enum.Material.Concrete, MaterialVariant = "OH_Ceiling", Color = Color3.new(1, 1, 1) },
	carpet = { Material = Enum.Material.Fabric, MaterialVariant = "OH_Carpet", Color = Color3.new(1, 1, 1) },
	hallcarpet = { Material = Enum.Material.Fabric, MaterialVariant = "OH_Carpet", Color = Color3.fromRGB(191, 191, 198) },
	lino = { Material = Enum.Material.Plastic, MaterialVariant = "OH_Lino", Color = Color3.new(1, 1, 1) },
	vinyl = { Material = Enum.Material.Plastic, MaterialVariant = "OH_Vinyl", Color = Color3.new(1, 1, 1) },
	frame = { Material = FRAME_REF.Material, Color = FRAME_REF.Color },
	grid = { Material = GRID_REF.Material, Color = GRID_REF.Color },
	darkglass = { Material = Enum.Material.SmoothPlastic, Color = Color3.fromRGB(20, 26, 40) },
	glass = { Material = GLASS_REF.Material, Color = GLASS_REF.Color, Transparency = GLASS_REF.Transparency },
}

local function mk(parent, name, size, cf, mat)
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.CFrame = cf
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for k, v in pairs(mat or MAT.plaster) do p[k] = v end
	p.Parent = parent
	return p
end

-- axis-aligned box from ranges
local function box(parent, name, x0, x1, y0, y1, z0, z1, mat)
	local lx, hx = math.min(x0, x1), math.max(x0, x1)
	local lz, hz = math.min(z0, z1), math.max(z0, z1)
	return mk(parent, name, Vector3.new(hx - lx, y1 - y0, hz - lz), CFrame.new((lx + hx) / 2, (y0 + y1) / 2, (lz + hz) / 2), mat)
end

local function yawFor(v) return math.atan2(-v.X, -v.Z) end -- template front is -Z

local function tmpl(name)
	local t = KIT.furniture:FindFirstChild(name) or KIT.building:FindFirstChild(name)
	assert(t, "template missing: " .. name)
	return t
end

local function anchorAll(inst)
	for _, d in ipairs(inst:GetDescendants()) do
		if d:IsA("BasePart") then d.Anchored = true end
	end
end

local function placeCF(name, cf, parent)
	local m = tmpl(name):Clone()
	m:PivotTo(cf)
	anchorAll(m)
	m.Parent = parent
	return m
end

local function place(name, x, z, yawDeg, parent, y)
	return placeCF(name, CFrame.new(x, y or FLOOR_Y, z) * CFrame.Angles(0, math.rad(yawDeg or 0), 0), parent)
end

local function fill(parent, x, y, z, b, r, col)
	local a = mk(parent, "LightAnchor", Vector3.new(0.2, 0.2, 0.2), CFrame.new(x, y, z), { Transparency = 1 })
	a.CanCollide = false
	a.CanQuery = false
	a.CanTouch = false
	a.CastShadow = false
	local l = Instance.new("PointLight")
	l.Brightness = b
	l.Range = r
	l.Color = col or WARM_FILL
	l.Shadows = true
	l.Parent = a
	return a
end

local function panel(parent, x, z, lit, b, rotated)
	local p = (lit and PANEL_LIT or PANEL_OFF):Clone()
	p.Anchored = true
	p.CFrame = CFrame.new(x, 22.9, z) * (rotated and CFrame.Angles(0, math.pi / 2, 0) or CFrame.new())
	local sl = p:FindFirstChildOfClass("SurfaceLight")
	if sl then sl.Brightness = b end
	p.Parent = parent
	return p
end

------------------------------------------------------------------ layout
-- Interiors (floor-plan rectangles). Neighbouring spaces are exactly 1 stud apart (the shared wall).
local SPACES = {
	{ id = "Reception", x0 = 452, x1 = 480, z0 = -614, z1 = -586, floor = "carpet", light = "room" },
	{ id = "MainHall", x0 = 481, x1 = 600, z0 = -607, z1 = -593, floor = "hallcarpet", light = "hall", hall = "x" },
	{ id = "Junction", x0 = 556, x1 = 576, z0 = -613, z1 = -608, floor = "hallcarpet", light = "hall", hall = "j" },
	{ id = "SideHall", x0 = 561, x1 = 571, z0 = -674, z1 = -614, floor = "hallcarpet", light = "hall", hall = "z" },
	{ id = "OpenPlan", x0 = 484, x1 = 544, z0 = -592, z1 = -548, floor = "carpet", light = "room", columns = true },
	{ id = "Conference", x0 = 545, x1 = 567, z0 = -592, z1 = -574, floor = "carpet", light = "conf" },
	{ id = "Breakout", x0 = 568, x1 = 600, z0 = -592, z1 = -566, floor = "lino", light = "room" },
	{ id = "ServerRoom", x0 = 540, x1 = 560, z0 = -640, z1 = -622, floor = "vinyl", light = "server" },
	{ id = "Storage", x0 = 572, x1 = 584, z0 = -640, z1 = -628, floor = "vinyl", light = "store" },
}
local SP = {}
for _, s in ipairs(SPACES) do SP[s.id] = s end

-- Openings sit on a 1-stud gap [g, g+1] of a plane ("z" = wall runs along X, "x" = wall runs along Z).
local OPENINGS = {
	{ plane = "x", g = 480, c = -600, w = 14, h = 13, kind = "open" }, -- Reception <-> MainHall (full width)
	{ plane = "z", g = -608, c = 566, w = 20, h = 13, kind = "open" }, -- MainHall <-> Junction bay (20 x 20 junction)
	{ plane = "z", g = -614, c = 566, w = 10, h = 13, kind = "open" }, -- Junction <-> SideHall
	{ plane = "z", g = -593, c = 494, w = DOOR_W, h = DOOR_H, kind = "door", door = "doorLeaf", open = true, swing = 1 }, -- OpenPlan W door
	{ plane = "z", g = -593, c = 530, w = DOOR_W, h = DOOR_H, kind = "door", door = "doorLeafGlass", open = true, swing = 1 }, -- OpenPlan E door
	{ plane = "z", g = -593, c = 556, w = 22, h = 13, kind = "glass", doorC = 561 }, -- Conference glass front
	{ plane = "z", g = -593, c = 584, w = DOOR_W, h = DOOR_H, kind = "door", door = "doorLeaf", open = true, swing = 1 }, -- Breakout
	{ plane = "x", g = 560, c = -631, w = DOOR_W, h = DOOR_H, kind = "door", door = "doorLeaf", open = false }, -- Server
	{ plane = "x", g = 571, c = -634, w = DOOR_W, h = DOOR_H, kind = "door", door = "doorLeaf", open = false }, -- Storage
}
-- window bays (dark opaque glass, never shows outside)
local WINDOWS = { MainHall = { E = true }, OpenPlan = { S = true } }

local function near(a, b) return math.abs(a - b) < 0.01 end

-- side descriptor: run along `along` over [a0,a1]; interior face at f; inward normal sign n
local function sideInfo(s, side)
	if side == "N" then return { along = "x", a0 = s.x0, a1 = s.x1, f = s.z0, n = 1, plane = "z", g = s.z0 - 1 } end
	if side == "S" then return { along = "x", a0 = s.x0, a1 = s.x1, f = s.z1, n = -1, plane = "z", g = s.z1 } end
	if side == "W" then return { along = "z", a0 = s.z0, a1 = s.z1, f = s.x0, n = 1, plane = "x", g = s.x0 - 1 } end
	return { along = "z", a0 = s.z0, a1 = s.z1, f = s.x1, n = -1, plane = "x", g = s.x1 }
end

-- box in side coords: u along the run, d = depth into the room from the face (negative = into the wall)
local function sbox(parent, si, name, u0, u1, d0, d1, y0, y1, mat)
	local w0, w1 = si.f + si.n * d0, si.f + si.n * d1
	if si.along == "x" then return box(parent, name, u0, u1, y0, y1, w0, w1, mat) end
	return box(parent, name, w0, w1, y0, y1, u0, u1, mat)
end

local function inwardVec(si)
	return si.along == "x" and Vector3.new(0, 0, si.n) or Vector3.new(si.n, 0, 0)
end

local function sidePoint(si, u, d, y)
	if si.along == "x" then return Vector3.new(u, y, si.f + si.n * d) end
	return Vector3.new(si.f + si.n * d, y, u)
end

-- subtract opening intervals from [lo,hi]
local function freeIntervals(lo, hi, holes)
	table.sort(holes, function(a, b) return a[1] < b[1] end)
	local out, cur = {}, lo
	for _, h in ipairs(holes) do
		if h[1] > cur then table.insert(out, { cur, math.min(h[1], hi) }) end
		cur = math.max(cur, h[2])
	end
	if cur < hi then table.insert(out, { cur, hi }) end
	local res = {}
	for _, iv in ipairs(out) do if iv[2] - iv[1] > 0.01 then table.insert(res, iv) end end
	return res
end

local function openingsFor(si)
	local list = {}
	for _, o in ipairs(OPENINGS) do
		if o.plane == si.plane and near(o.g, si.g) then table.insert(list, o) end
	end
	return list
end

-- wall-mounted template (art, clock, sconce, screen): centre height cy
local function wallMount(name, s, side, u, cy, parent)
	local si = sideInfo(s, side)
	local bs = tmpl(name):GetAttribute("BaseSize")
	local pos = sidePoint(si, u, bs.Z / 2 + 0.01, cy - bs.Y / 2)
	return placeCF(name, CFrame.new(pos) * CFrame.Angles(0, yawFor(inwardVec(si)), 0), parent)
end

-- floor template backed against a wall, clearing the wainscot rail (0.55)
local function againstWall(name, s, side, u, parent, gap)
	local si = sideInfo(s, side)
	local bs = tmpl(name):GetAttribute("BaseSize")
	local pos = sidePoint(si, u, bs.Z / 2 + (gap or 0.55), FLOOR_Y)
	return placeCF(name, CFrame.new(pos) * CFrame.Angles(0, yawFor(inwardVec(si)), 0), parent)
end

------------------------------------------------------------------ shell: floor, ceiling, grid, walls, trim
local function buildWalls(s, folder)
	for _, side in ipairs({ "N", "S", "W", "E" }) do
		local si = sideInfo(s, side)
		if WINDOWS[s.id] and WINDOWS[s.id][side] then
			-- mock-room window bay: backing wall, dark GlassN, sill, header, c_windowbay every 6
			sbox(folder, si, "WindowBacking", si.a0 - WALL_T, si.a1 + WALL_T, -0.7, -0.2, BASE_Y, TOP_Y, MAT.plaster)
			sbox(folder, si, "GlassN", si.a0, si.a1, -0.1, 0.1, 11.5, 21.8, MAT.darkglass)
			sbox(folder, si, "Sill", si.a0, si.a1, -0.7, 0.5, FLOOR_Y, 11.5, MAT.plaster)
			sbox(folder, si, "Header", si.a0, si.a1, -0.7, 0.5, 21.8, CEIL_Y, MAT.plaster)
			local n = math.floor((si.a1 - si.a0) / 6)
			local mid = (si.a0 + si.a1) / 2
			for i = 0, n - 1 do
				local u = mid + (i - (n - 1) / 2) * 6
				local wb = WINDOW_BAY:Clone()
				wb.Anchored = true
				wb.CFrame = CFrame.new(sidePoint(si, u, 0.03, 16.65)) * CFrame.Angles(0, yawFor(inwardVec(si)), 0)
				wb.Parent = folder
				local bl = BLINDS:Clone() -- mock-room blinds sit 0.575 in front of the glass plane
				bl.Anchored = true
				bl.CFrame = CFrame.new(sidePoint(si, u, 0.575, 16.765)) * CFrame.Angles(0, yawFor(inwardVec(si)), 0)
				bl.Parent = folder
			end
		else
			local ops = openingsFor(si)
			local holes = {}
			for _, o in ipairs(ops) do table.insert(holes, { o.c - o.w / 2, o.c + o.w / 2 }) end
			-- continuous plaster pieces, extended by the wall thickness at both ends (corners overlap)
			for _, iv in ipairs(freeIntervals(si.a0 - WALL_T, si.a1 + WALL_T, table.clone(holes))) do
				sbox(folder, si, "Wall" .. side, iv[1], iv[2], -WALL_T, 0, BASE_Y, TOP_Y, MAT.plaster)
			end
			for _, o in ipairs(ops) do
				if o.h < 13 then
					sbox(folder, si, "Header" .. side, o.c - o.w / 2, o.c + o.w / 2, -WALL_T, 0, FLOOR_Y + o.h, TOP_Y, MAT.plaster)
				end
			end
			-- trim runs: X-runs take the full span; Z-runs stop short of the corner by their depth
			for _, iv in ipairs(freeIntervals(si.a0, si.a1, table.clone(holes))) do
				local function run(name, d, y0, y1, mat)
					local u0, u1 = iv[1], iv[2]
					if si.along == "z" then
						if near(u0, si.a0) then u0 += d end
						if near(u1, si.a1) then u1 -= d end
					end
					if u1 - u0 > 0.05 then sbox(folder, si, name, u0, u1, 0, d, y0, y1, mat) end
				end
				run("Wainscot" .. side, WAIN_D, FLOOR_Y, FLOOR_Y + WAIN_H, MAT.oak)
				run("Rail" .. side, RAIL_D, RAIL_Y - RAIL_H / 2, RAIL_Y + RAIL_H / 2, MAT.rail)
				run("Skirt" .. side, SKIRT_D, FLOOR_Y, FLOOR_Y + SKIRT_H, MAT.skirt)
			end
		end
	end
end

local function buildShell(s, folder)
	box(folder, "Floor", s.x0, s.x1, BASE_Y, FLOOR_Y, s.z0, s.z1, MAT[s.floor])
	box(folder, "Ceiling", s.x0, s.x1, CEIL_Y, TOP_Y, s.z0, s.z1, MAT.ceiling)
	-- ceiling grid strips every 4 (mock: 0.15 x 0.08 at Y 22.96)
	local x = s.x0 + 4
	while x < s.x1 - 0.5 do
		mk(folder, "Grid", Vector3.new(0.15, 0.08, s.z1 - s.z0), CFrame.new(x, 22.96, (s.z0 + s.z1) / 2), MAT.grid)
		x += 4
	end
	local z = s.z0 + 4
	while z < s.z1 - 0.5 do
		mk(folder, "Grid", Vector3.new(s.x1 - s.x0, 0.08, 0.15), CFrame.new((s.x0 + s.x1) / 2, 22.96, z), MAT.grid)
		z += 4
	end
	buildWalls(s, folder)
end

-- opening connectors: threshold floor, ceiling strip, casing / pilasters / framed glass, doors
local function gapBox(o, folder, name, u0, u1, p0, p1, y0, y1, mat)
	if o.plane == "z" then return box(folder, name, u0, u1, y0, y1, o.g + p0, o.g + p1, mat) end
	return box(folder, name, o.g + p0, o.g + p1, y0, y1, u0, u1, mat)
end

local function doorCF(o, open, swing)
	local yaw = o.plane == "z" and 0 or math.pi / 2
	local cf = (o.plane == "z" and CFrame.new(o.c, FLOOR_Y, o.g + 0.5) or CFrame.new(o.g + 0.5, FLOOR_Y, o.c)) * CFrame.Angles(0, yaw, 0)
	if not open then return cf end
	local hinge = (cf * CFrame.new(2.95, 0, 0)).Position -- doorLeaf hinge at local +X (KIT_MAP)
	return CFrame.new(hinge) * CFrame.Angles(0, yaw + (swing or 1) * math.pi / 2, 0) * CFrame.new(-2.95, 0, 0)
end

local function buildOpening(o, folder)
	local u0, u1 = o.c - o.w / 2, o.c + o.w / 2
	gapBox(o, folder, "Threshold", u0, u1, 0, 1, BASE_Y, FLOOR_Y, MAT.hallcarpet)
	if o.h >= 13 then gapBox(o, folder, "CeilingStrip", u0, u1, 0, 1, CEIL_Y, TOP_Y, MAT.ceiling) end
	if o.kind == "door" then
		gapBox(o, folder, "Casing", u0, u0 + CASE, -CASE, 1 + CASE, FLOOR_Y, FLOOR_Y + o.h, MAT.oak)
		gapBox(o, folder, "Casing", u1 - CASE, u1, -CASE, 1 + CASE, FLOOR_Y, FLOOR_Y + o.h, MAT.oak)
		gapBox(o, folder, "Casing", u0, u1, -CASE, 1 + CASE, FLOOR_Y + o.h - CASE, FLOOR_Y + o.h, MAT.oak)
		placeCF(o.door, doorCF(o, o.open, o.swing), folder)
	elseif o.kind == "open" then
		gapBox(o, folder, "Pilaster", u0, u0 + 0.6, -0.35, 1.35, FLOOR_Y, CEIL_Y, MAT.plaster)
		gapBox(o, folder, "Pilaster", u1 - 0.6, u1, -0.35, 1.35, FLOOR_Y, CEIL_Y, MAT.plaster)
	elseif o.kind == "glass" then
		-- mock-room framed glass: dark ConfFrame mullions (0.4 x 13 x 0.4) every ~6, header rail, glass door bay
		local d0, d1 = o.doorC - DOOR_W / 2, o.doorC + DOOR_W / 2
		gapBox(o, folder, "ConfFrameEnd", u0, u0 + 0.6, -0.35, 1.35, FLOOR_Y, CEIL_Y, MAT.frame)
		gapBox(o, folder, "ConfFrameEnd", u1 - 0.6, u1, -0.35, 1.35, FLOOR_Y, CEIL_Y, MAT.frame)
		local posts = { d0 + 0.2, d1 - 0.2 }
		local function spanPosts(a, b)
			local n = math.max(1, math.ceil((b - a) / 6.2))
			for i = 1, n - 1 do table.insert(posts, a + (b - a) * i / n) end
		end
		spanPosts(u0 + 0.6, d0)
		spanPosts(d1, u1 - 0.6)
		for _, p in ipairs(posts) do gapBox(o, folder, "ConfFrame", p - 0.2, p + 0.2, 0.3, 0.7, FLOOR_Y, CEIL_Y, MAT.frame) end
		gapBox(o, folder, "ConfHeaderRail", u0, u1, 0.2, 0.8, 22.5, CEIL_Y, MAT.frame)
		gapBox(o, folder, "ConfBaseRail", u0 + 0.6, d0, 0.25, 0.75, FLOOR_Y, FLOOR_Y + 0.35, MAT.frame)
		gapBox(o, folder, "ConfBaseRail", d1, u1 - 0.6, 0.25, 0.75, FLOOR_Y, FLOOR_Y + 0.35, MAT.frame)
		gapBox(o, folder, "ConfGlass", u0 + 0.6, d0, 0.4, 0.6, FLOOR_Y + 0.35, 22.5, MAT.glass)
		gapBox(o, folder, "ConfGlass", d1, u1 - 0.6, 0.4, 0.6, FLOOR_Y + 0.35, 22.5, MAT.glass)
		gapBox(o, folder, "ConfDoorHeader", d0, d1, 0.2, 0.8, FLOOR_Y + DOOR_H - 0.4, FLOOR_Y + DOOR_H, MAT.frame)
		gapBox(o, folder, "ConfGlassTransom", d0 + 0.4, d1 - 0.4, 0.4, 0.6, FLOOR_Y + DOOR_H, 22.5, MAT.glass)
		local leaf = placeCF("doorLeafGlass", doorCF({ plane = o.plane, g = o.g, c = o.doorC }, false), folder)
	end
end

------------------------------------------------------------------ lighting per space
local function roomPanels(s, folder, prof, allLit)
	local W, D = s.x1 - s.x0, s.z1 - s.z0
	local nx, nz = math.max(1, math.floor(W / 12 + 0.5)), math.max(1, math.floor(D / 10 + 0.5))
	local cx, cz = (s.x0 + s.x1) / 2, (s.z0 + s.z1) / 2
	for i = 0, nx - 1 do
		for j = 0, nz - 1 do
			local lit = allLit or ((i + 2 * j) % 3 ~= 1)
			panel(folder, cx + (i - (nx - 1) / 2) * 12, cz + (j - (nz - 1) / 2) * 10, lit, prof.panelB)
		end
	end
end

local function sconce(s, side, u, folder)
	wallMount("sconce", s, side, u, 17.5, folder)
end

------------------------------------------------------------------ desks
local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Include

local function deskTop(desk, x, z)
	rayParams.FilterDescendantsInstances = { desk }
	local r = workspace:Raycast(Vector3.new(x, 30, z), Vector3.new(0, -25, 0), rayParams)
	return r and r.Position.Y or (FLOOR_Y + 4.95)
end

local function workstation(folder, x, z, yawDeg, plant)
	local yaw = math.rad(yawDeg)
	local base = CFrame.new(x, FLOOR_Y, z) * CFrame.Angles(0, yaw, 0)
	local desk = placeCF("desk", base, folder)
	placeCF("officeChair", base * CFrame.new(0, 0, -3.6) * CFrame.Angles(0, math.pi, 0), folder)
	local mpos = (base * CFrame.new(0.4, 0, 0.9)).Position
	local top = deskTop(desk, mpos.X, mpos.Z)
	local mon = MONITOR:Clone()
	mon.Anchored = true
	mon.CFrame = CFrame.new(mpos.X, top + mon.Size.Y / 2, mpos.Z) * CFrame.Angles(0, yaw, 0)
	local pl = mon:FindFirstChildWhichIsA("PointLight", true)
	if pl then pl.Brightness = 0.7 pl.Range = 6 end
	mon.Parent = folder
	if plant then
		local ppos = (base * CFrame.new(3.4, 0, 1.2)).Position
		placeCF("deskPlant", CFrame.new(ppos.X, deskTop(desk, ppos.X, ppos.Z), ppos.Z), folder)
	end
	return desk, top
end

local function pod(folder, px, pz)
	workstation(folder, px - 4.4, pz - 3.2, 0, true)
	workstation(folder, px + 4.4, pz - 3.2, 0, false)
	workstation(folder, px - 4.4, pz + 3.2, 180, false)
	workstation(folder, px + 4.4, pz + 3.2, 180, true)
	place("partition", px - 3, pz, 0, folder)
	place("partition", px + 3, pz, 0, folder)
	place("wasteBin", px - 9.8, pz - 2, 0, folder)
end

local function rug(folder, x, z, sx, sz)
	local r = RUG:Clone()
	r.Anchored = true
	r.Size = Vector3.new(sx, 0.1, sz)
	r.CFrame = CFrame.new(x, FLOOR_Y + 0.05, z)
	r.Parent = folder
	return r
end

------------------------------------------------------------------ build
local folders = {}
for _, s in ipairs(SPACES) do
	local f = Instance.new("Folder")
	f.Name = s.id
	f.Parent = root
	folders[s.id] = f
	buildShell(s, f)
	task.wait()
end
local conn = Instance.new("Folder")
conn.Name = "Openings"
conn.Parent = root
for _, o in ipairs(OPENINGS) do buildOpening(o, conn) end
task.wait()

-- Reception -------------------------------------------------------
do
	local s, f, P = SP.Reception, folders.Reception, LIGHT.room
	roomPanels(s, f, P, true)
	place("receptionDesk", 459, -600, -90, f)
	-- mock reception glow wall behind the desk (west wall)
	local si = sideInfo(s, "W")
	local g = REC_GLOW:Clone() g.Anchored = true
	g.CFrame = CFrame.new(sidePoint(si, -600, 0.2, 16.5)) * CFrame.Angles(0, yawFor(inwardVec(si)), 0)
	g.Parent = f
	local pnl = REC_PANEL:Clone() pnl.Anchored = true
	pnl.CFrame = CFrame.new(sidePoint(si, -600, 0.45, 16.5)) * CFrame.Angles(0, yawFor(inwardVec(si)), 0)
	pnl.Parent = f
	fill(f, 455, 14, -600, 1.6, 11, GLOW_COL)
	wallMount("wallClock", s, "W", -600, 21.2, f)
	-- seating north, sofa south, planters in corners
	againstWall("sofa", s, "N", 468, f)
	place("breakTable", 468, -606.5, 0, f)
	rug(f, 468, -607.5, 12, 9)
	wallMount("artFrame", s, "N", 468, 17.8, f)
	place("floorLamp", 461.5, -611.6, 0, f)
	fill(f, 461.5, 15.8, -611.6, 1.6, 11, LAMP_COL)
	againstWall("sofa", s, "S", 468, f)
	wallMount("artFrame", s, "S", 468, 17.8, f)
	for _, u in ipairs({ 455, 477.5 }) do
		againstWall("planter", s, "N", u, f)
		againstWall("planter", s, "S", u, f)
	end
	for _, p in ipairs({ { 462, -608 }, { 474, -608 }, { 462, -592 }, { 474, -592 } }) do
		fill(f, p[1], 14, p[2], P.fillB, P.fillR)
	end
end
task.wait()

-- Main hall, junction, side hall ------------------------------------
do
	local s, f, P = SP.MainHall, folders.MainHall, LIGHT.hall
	for x = 485, 597, 8 do panel(f, x, -600, true, P.panelB) end
	local k = 0
	for x = 489, 589, 16 do
		local side = (k % 2 == 0) and "N" or "S"
		fill(f, x, 15, side == "N" and -604 or -596, P.fillB, P.fillR)
		local holes = {}
		for _, o in ipairs(openingsFor(sideInfo(s, side))) do table.insert(holes, { o.c - o.w / 2 - 1, o.c + o.w / 2 + 1 }) end
		local ok = true
		for _, h in ipairs(holes) do if x > h[1] and x < h[2] then ok = false end end
		if ok then sconce(s, side, x, f) end
		k += 1
	end
	wallMount("artFrame", s, "N", 500, 17.5, f)
	wallMount("artFrame", s, "N", 536, 17.5, f)
	wallMount("wallClock", s, "N", 517, 20.6, f)
	againstWall("sofa", s, "N", 517, f) -- waiting bench
	againstWall("planter", s, "N", 484.5, f)
	againstWall("planter", s, "N", 552, f)
	wallMount("artFrame", s, "S", 512, 17.5, f)
	againstWall("planter", s, "S", 541, f)
	wallMount("artFrame", s, "N", 590, 17.5, f)
	againstWall("planter", s, "N", 597, f)
	againstWall("planter", s, "S", 597, f)

	local j, jf = SP.Junction, folders.Junction
	panel(jf, 561, -610.5, true, P.panelB)
	panel(jf, 571, -610.5, true, P.panelB)
	fill(jf, 566, 15, -610, P.fillB, P.fillR)
	againstWall("planter", j, "N", 573.6, jf)
	againstWall("waterCooler", j, "N", 558.5, jf)

	local sh, sf = SP.SideHall, folders.SideHall
	for z = -618, -670, -8 do panel(sf, 566, z, true, P.panelB, true) end
	local kk = 0
	for z = -618, -666, -16 do
		local side = (kk % 2 == 0) and "W" or "E"
		fill(sf, side == "W" and 563 or 569, 15, z, P.fillB, P.fillR)
		local ok = true
		for _, o in ipairs(openingsFor(sideInfo(sh, side))) do
			if z > o.c - o.w / 2 - 1 and z < o.c + o.w / 2 + 1 then ok = false end
		end
		if ok then sconce(sh, side, z, sf) end
		kk += 1
	end
	wallMount("wallClock", sh, "W", -643, 20.6, sf)
	wallMount("artFrame", sh, "E", -655, 17.5, sf)
	wallMount("artFrame", sh, "W", -662, 17.5, sf)
	wallMount("artFrame", sh, "N", 566, 17.5, sf)
	againstWall("planter", sh, "N", 563.4, sf)
	againstWall("planter", sh, "N", 568.6, sf)
end
task.wait()

-- Open plan ---------------------------------------------------------
do
	local s, f, P = SP.OpenPlan, folders.OpenPlan, LIGHT.room
	roomPanels(s, f, P, false)
	for _, x in ipairs({ 504, 524 }) do box(f, "Column", x - 1, x + 1, FLOOR_Y, CEIL_Y, -569.5, -567.5, MAT.plaster) end
	pod(f, 497, -579)
	pod(f, 527, -579)
	pod(f, 497, -558)
	-- stand-up corner: rug, standing whiteboard (legs on the floor), two chairs
	rug(f, 527, -558, 14, 10)
	place("corkboard", 527, -550.4, 0, f)
	place("officeChair", 524, -558, 180, f)
	place("officeChair", 530, -558, 180, f)
	againstWall("copier", s, "W", -566, f)
	againstWall("shelf", s, "W", -556, f)
	againstWall("planter", s, "E", -553, f)
	againstWall("planter", s, "N", 540, f)
	wallMount("artFrame", s, "E", -580, 17.5, f)
	wallMount("wallClock", s, "N", 512, 20.6, f)
	for _, p in ipairs({ { 492, -583 }, { 514, -583 }, { 537, -583 }, { 492, -558 }, { 514, -560 }, { 537, -560 }, { 514, -570 } }) do
		fill(f, p[1], 14, p[2], P.fillB, P.fillR)
	end
end
task.wait()

-- Conference --------------------------------------------------------
do
	local s, f, P = SP.Conference, folders.Conference, LIGHT.conf
	roomPanels(s, f, P, true)
	place("conferenceTable", 556, -582.5, 0, f)
	for _, x in ipairs({ 551, 556, 561 }) do
		place("officeChair", x, -586.9, 180, f)
		place("officeChair", x, -578.1, 0, f)
	end
	wallMount("wallScreen", s, "S", 556, 16.5, f)
	againstWall("planter", s, "W", -577, f)
	fill(f, 550, 14, -583, P.fillB, P.fillR)
	fill(f, 562, 14, -583, P.fillB, P.fillR)
	fill(f, 556, 16, -575.5, 0.7, 6, Color3.fromRGB(110, 165, 255)) -- wall screen accent
end
task.wait()

-- Breakout ----------------------------------------------------------
do
	local s, f, P = SP.Breakout, folders.Breakout, LIGHT.room
	roomPanels(s, f, P, false)
	againstWall("kitchenCounter", s, "S", 580, f)
	againstWall("kitchenCounter", s, "S", 588, f)
	againstWall("vending", s, "E", -572, f)
	fill(f, 597, 15, -572, 0.7, 6, Color3.fromRGB(150, 200, 255)) -- vending front glow
	againstWall("waterCooler", s, "E", -577.2, f)
	againstWall("planter", s, "E", -589, f)
	againstWall("sofa", s, "W", -580, f)
	place("breakTable", 576, -580, 90, f)
	rug(f, 576, -580, 10, 12)
	place("floorLamp", 570.4, -585.6, 0, f)
	fill(f, 570.4, 15.8, -585.6, 1.6, 11, LAMP_COL)
	place("breakTable", 590, -582, 0, f)
	place("sofa", 590, -586.2, 180, f)
	wallMount("artFrame", s, "W", -580, 17.8, f)
	wallMount("wallClock", s, "S", 584, 20.6, f)
	for _, p in ipairs({ { 576, -585 }, { 592, -585 }, { 584, -573 } }) do fill(f, p[1], 14, p[2], P.fillB, P.fillR) end
end
task.wait()

-- Server room -------------------------------------------------------
do
	local s, f, P = SP.ServerRoom, folders.ServerRoom, LIGHT.server
	roomPanels(s, f, P, false)
	for _, u in ipairs({ -636.6, -634.2, -631.8, -629.4 }) do
		local r = againstWall("serverRack", s, "W", u, f)
		local att = r:FindFirstChild("LedLight", true)
		if att then
			local l = Instance.new("PointLight")
			l.Brightness = 0.4
			l.Range = 6
			l.Color = LED_COL
			l.Parent = att
		end
	end
	againstWall("supplyCabinet", s, "N", 554, f)
	fill(f, 551, 14, -631, P.fillB, P.fillR)
end

-- Storage -----------------------------------------------------------
do
	local s, f, P = SP.Storage, folders.Storage, LIGHT.store
	roomPanels(s, f, P, true)
	againstWall("supplyCabinet", s, "E", -637.5, f)
	againstWall("supplyCabinet", s, "E", -632.9, f)
	againstWall("shelf", s, "N", 576, f)
	fill(f, 577, 14, -634, P.fillB, P.fillR)
end
task.wait()

------------------------------------------------------------------ Studio-only spawn into the reception
local spawnScript = Instance.new("Script")
spawnScript.Name = "ClaudeSpikeSpawn"
spawnScript.RunContext = Enum.RunContext.Server
spawnScript.Source = [[
-- THROWAWAY: drops the player into Workspace.ClaudeSpike's reception when playtesting in Studio.
local RunService = game:GetService("RunService")
if not RunService:IsStudio() then return end
local Players = game:GetService("Players")
local TARGET = CFrame.new(472, 13.5, -600) * CFrame.Angles(0, math.rad(-90), 0) -- facing east, down the main hall
local function onCharacter(char)
	task.spawn(function()
		for _, w in ipairs({ 0.5, 1, 1.5 }) do -- re-pivot over ~3 s in case the game's own spawn runs after us
			task.wait(w)
			if char.Parent then char:PivotTo(TARGET) end
		end
	end)
end
local function onPlayer(p)
	p.CharacterAdded:Connect(onCharacter)
	if p.Character then onCharacter(p.Character) end
end
Players.PlayerAdded:Connect(onPlayer)
for _, p in ipairs(Players:GetPlayers()) do onPlayer(p) end
]]
spawnScript.Parent = root

local n = 0
for _, d in ipairs(root:GetDescendants()) do if d:IsA("BasePart") then n += 1 end end
print(("ClaudeSpike built: %d parts"):format(n))
return n
