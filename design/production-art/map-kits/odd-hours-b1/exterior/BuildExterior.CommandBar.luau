--!nolint
-- Odd Hours B1 office EXTERIOR set (the approved look spike, promoted). Studio art, not Rojo.
-- Paste into the Studio command bar (Edit) of the Shift place. Idempotent: deletes and rebuilds Workspace.OfficeExterior
-- and deletes the old Workspace.ClaudeExteriorSpike, all in ONE ChangeHistory step (Ctrl+Z restores the previous state).
-- The set wraps the generated office again (EXTERIOR_OFFSET = 0): its closed podium stands 2 studs outside the
-- interior keep-out (world x 961..1294, z -52..203, y < 17), and the entrances are short teleport hops. The code
-- builds the truck, the door hit boxes and the ooze at OfficeConstants.OUTSIDE; this art lines up with those numbers.
-- Builds in "exterior space" (front = -Z) and every part is shifted by EXTERIOR_OFFSET (zero today).
-- The new set is built under a temporary name and checked against the keep-out BEFORE the old set is destroyed: a
-- part inside the keep-out fails the build, removes the half-built set and leaves the place as it was.
-- Creates/updates MaterialVariants OH_ExtStone / OH_ExtPanel (reusing the approved OH_ maps, no uploads).
-- Never touches Lighting (the exterior atmosphere is code: OfficeAtmosphereConstants).

local CHS = game:GetService("ChangeHistoryService")
local MS = game:GetService("MaterialService")

------------------------------------------------------------------ shared numbers
-- Copied from src/ServerScriptService/Features/Office/Data/OfficeConstants.luau (OUTSIDE, layout space) and ORIGIN.
-- If those change, change them here and rebuild; the asserts below refuse a set that no longer lines up.
local ORIGIN = Vector3.new(1000, 1, 0) -- OfficeConstants.ORIGIN (world = layout + ORIGIN)
local OUTSIDE = {
	EXTERIOR_OFFSET = Vector3.zero,
	yard = { minX = -164, maxX = 322, minZ = -321, maxZ = -57 },
	carpark = { minX = -164, maxX = -44, minZ = -57, maxZ = 230 },
	TRUCK_CENTRE = Vector2.new(168, -276),
	DOCK_OUTSIDE = { x = 168, z = -64, yaw = 0 },
	LOBBY_OUTSIDE = { x = -62, z = 152, yaw = math.pi / 2 },
	DOCK_DOOR_WIDTH = 14,
}
local OFFSET = OUTSIDE.EXTERIOR_OFFSET -- every part is built in exterior space and moved by this

local NAME = "OfficeExterior"
-- The generated office's volume (world; every room fits here over 120 seeds). No exterior part may enter it.
local KEEP = { x0 = 961, x1 = 1294, z0 = -52, z1 = 203, yTop = 17 }

------------------------------------------------------------------ key numbers (exterior space = world - OFFSET)
local PLAZA_Y = 1.36 -- lobby plaza / rotunda floor top
local GROUND = 1 -- asphalt top = interior floor top (dock and lobby are at grade)
-- shell: 3 thick, inner face 2 studs outside the keep-out
local WX0, WX1 = 956, 959 -- west wall
local EX0, EX1 = 1296, 1299 -- east wall
local SZ0, SZ1 = -57, -54 -- south (front) wall
local NZ0, NZ1 = 205, 208 -- north wall
local POD_TOP = 31 -- podium wall top (parapet coping above)
local ROOF_Y = 27 -- podium roof slab 27..28 (above the keep-out)
local TOWER_BASE = 28
-- facade moon washes (SurfaceLight panels): band height (0 = none) and brightness scale. With the proposed
-- "officeExterior" atmosphere preset the towers read on their own, so these stay few and dim.
local MOON_BAND = 45
local MOON_SCALE = 0.8
-- dock (front, -Z)
local DOCK_X = 1168
local DOCK_W, DOCK_H = OUTSIDE.DOCK_DOOR_WIDTH, 12
local DOCKBLK = { x0 = 1110, x1 = 1230, z0 = -64, z1 = SZ0, top = 24 }
-- lobby (west, -X)
local LOBBY_Z = 152
local LOBBY_W, LOBBY_H = 14, 13
local ROT_C = Vector3.new(WX0, 0, LOBBY_Z) -- rotunda centre on the wall's outer face
local ROT_R = 18
-- site
-- truck: the code parks it at OUTSIDE.TRUCK_CENTRE, rear/ramp toward the dock door
local TRUCK_Z = OUTSIDE.TRUCK_CENTRE.Y - OFFSET.Z -- the code's truck (yaw pi: ramp toward the dock)
local RAMP_Z = TRUCK_Z + 12 -- its ramp foot: about 200 studs of open yard from the dock door
local PAD = { x0 = DOCK_X - 24, x1 = DOCK_X + 24, z0 = TRUCK_Z - 22, z1 = RAMP_Z + 10 } -- lit truck pad
local SITE = { -- fence line = OUTSIDE.yard (front) + OUTSIDE.carpark (west), in exterior space
	x0 = ORIGIN.X + OUTSIDE.yard.minX, x1 = ORIGIN.X + OUTSIDE.yard.maxX,
	z0 = OUTSIDE.yard.minZ - OFFSET.Z, z1 = OUTSIDE.carpark.maxZ - OFFSET.Z,
}
-- the art must line up with the code's numbers
assert(DOCK_X == ORIGIN.X + OUTSIDE.DOCK_OUTSIDE.x and DOCKBLK.z0 + OFFSET.Z == OUTSIDE.DOCK_OUTSIDE.z, "dock door misaligned")
assert(math.abs(WX0 - ROT_R - (ORIGIN.X + OUTSIDE.LOBBY_OUTSIDE.x)) < 0.5 and LOBBY_Z + OFFSET.Z == OUTSIDE.LOBBY_OUTSIDE.z, "lobby doors misaligned")
assert(DOCK_X == ORIGIN.X + OUTSIDE.TRUCK_CENTRE.X, "truck pad misaligned")
assert(SITE.x0 == ORIGIN.X + OUTSIDE.carpark.minX, "car park misaligned")
-- the podium's inner faces stand outside the keep-out (with OFFSET zero the podium wraps the office)
assert(WX1 + OFFSET.X <= KEEP.x0 and EX0 + OFFSET.X >= KEEP.x1 and SZ1 + OFFSET.Z <= KEEP.z0 and NZ0 + OFFSET.Z >= KEEP.z1, "podium inside the keep-out")
assert(ROOF_Y >= KEEP.yTop, "podium roof inside the keep-out")

-- only after the asserts pass is the recording opened; the new set is built under a temporary name and the old set is
-- destroyed only once the new one has passed the keep-out check (section 9)
local recording = nil
pcall(function() recording = CHS:TryBeginRecording("Build " .. NAME) end)

local TEMP_NAME = NAME .. "_Building"
local stale = workspace:FindFirstChild(TEMP_NAME)
if stale then stale:Destroy() end
local ROOT = Instance.new("Model")
ROOT.Name = TEMP_NAME
ROOT.Parent = workspace
local ROAD = { z0 = TRUCK_Z - 9, z1 = TRUCK_Z + 9, x0 = PAD.x1 } -- access road: east gate -> truck pad

local rng = Random.new(5150)

------------------------------------------------------------------ materials
local function variant(name, base, src, spt)
	local v = MS:FindFirstChild(name)
	if not v then v = Instance.new("MaterialVariant") v.Name = name end
	v.BaseMaterial = base
	v.StudsPerTile = spt
	local s = MS:FindFirstChild(src)
	if s then v.ColorMap = s.ColorMap v.NormalMap = s.NormalMap v.RoughnessMap = s.RoughnessMap end
	v.Parent = MS
end
variant("OH_ExtStone", Enum.Material.Concrete, "OH_Plaster", 22) -- smooth cast stone (tinted per part)
variant("OH_ExtPanel", Enum.Material.Slate, "OH_Ceiling", 14) -- precast panel grid for podium/dock
-- tidy the earlier test variants if present
for _, n in ipairs({ "OHX_TestStone", "OHX_TestPanel", "OHX_TestEmpty" }) do
	local t = MS:FindFirstChild(n) if t then t:Destroy() end
end

local function C(r, g, b) return Color3.fromRGB(r, g, b) end
local M = {
	stone = { Material = Enum.Material.Concrete, MaterialVariant = "OH_ExtStone", Color = C(200, 194, 182) },
	stoneMid = { Material = Enum.Material.Concrete, MaterialVariant = "OH_ExtStone", Color = C(160, 155, 146) },
	stoneDark = { Material = Enum.Material.Concrete, MaterialVariant = "OH_ExtStone", Color = C(98, 95, 90) },
	panel = { Material = Enum.Material.Slate, MaterialVariant = "OH_ExtPanel", Color = C(156, 152, 144) },
	dockPanel = { Material = Enum.Material.Slate, MaterialVariant = "OH_ExtPanel", Color = C(140, 138, 134) },
	nightGlass = { Material = Enum.Material.Glass, Color = C(22, 28, 44), Reflectance = 0.22 },
	ribbonGlass = { Material = Enum.Material.Glass, Color = C(18, 22, 34), Reflectance = 0.2 },
	lobbyGlass = { Material = Enum.Material.Glass, Color = C(255, 226, 190), Transparency = 0.6 },
	metal = { Material = Enum.Material.Metal, Color = C(78, 82, 86) },
	darkMetal = { Material = Enum.Material.Metal, Color = C(42, 44, 48) },
	rollerDoor = { Material = Enum.Material.CorrodedMetal, Color = C(120, 118, 110) },
	asphalt = { Material = Enum.Material.Asphalt, Color = C(52, 52, 56) },
	road = { Material = Enum.Material.Asphalt, Color = C(60, 60, 64) },
	puddle = { Material = Enum.Material.SmoothPlastic, Color = C(28, 28, 34) }, -- glossy: catches local-light highlights (a mirror only reflects the black sky)
	concrete = { Material = Enum.Material.Concrete, Color = C(118, 116, 112) },
	dockPad = { Material = Enum.Material.Concrete, Color = C(96, 94, 90), Reflectance = 0.04 },
	plaza = { Material = Enum.Material.Marble, Color = C(150, 144, 134), Reflectance = 0.08 },
	lobbyFloor = { Material = Enum.Material.Marble, Color = C(214, 204, 188), Reflectance = 0.12 },
	oak = { Material = Enum.Material.Wood, MaterialVariant = "OH_Oak", Color = C(255, 255, 255) },
	plaster = { Material = Enum.Material.Plaster, MaterialVariant = "OH_Plaster", Color = C(255, 244, 228) },
	whiteLine = { Material = Enum.Material.SmoothPlastic, Color = C(176, 176, 168) },
	yellowLine = { Material = Enum.Material.SmoothPlastic, Color = C(196, 156, 40) },
	safety = { Material = Enum.Material.SmoothPlastic, Color = C(222, 174, 36) },
	black = { Material = Enum.Material.SmoothPlastic, Color = C(24, 24, 26) },
	rubber = { Material = Enum.Material.Rubber, Color = C(26, 26, 28) },
	hedge = { Material = Enum.Material.LeafyGrass, Color = C(34, 58, 38) },
	topiary = { Material = Enum.Material.LeafyGrass, Color = C(30, 54, 36) },
	pine = { Material = Enum.Material.LeafyGrass, Color = C(22, 38, 30) },
	pineDark = { Material = Enum.Material.LeafyGrass, Color = C(16, 30, 24) },
	trunk = { Material = Enum.Material.Wood, Color = C(52, 40, 32) },
	grass = { Material = Enum.Material.Grass, Color = C(30, 40, 30) },
	soil = { Material = Enum.Material.Ground, Color = C(40, 34, 28) },
	dumpGreen = { Material = Enum.Material.Metal, Color = C(46, 66, 50) },
	dumpBlue = { Material = Enum.Material.Metal, Color = C(44, 54, 72) },
	cardboard = { Material = Enum.Material.Cardboard, Color = C(150, 116, 78) },
	lampNeon = { Material = Enum.Material.Neon, Color = C(255, 172, 92) },
	pathNeon = { Material = Enum.Material.Neon, Color = C(255, 196, 132) },
	ringNeon = { Material = Enum.Material.Neon, Color = C(255, 190, 120) },
	winLit = { Material = Enum.Material.Neon, Color = C(206, 140, 70) },
	winDim = { Material = Enum.Material.Neon, Color = C(120, 78, 42) },
	blind = { Material = Enum.Material.SmoothPlastic, Color = C(70, 50, 34) },
	redLens = { Material = Enum.Material.Neon, Color = C(150, 20, 20) },
	tyre = { Material = Enum.Material.Rubber, Color = C(20, 20, 22) },
	invisible = { Transparency = 1 },
}

local SODIUM = C(255, 170, 90)
local WARM = C(255, 196, 136)
local LOBBY_WARM = C(255, 188, 118)
local MOON = C(150, 170, 235) -- cool fill standing in for moonlight on the facades

------------------------------------------------------------------ chunked building
local CHUNK = nil
local SUB, SUB_N = nil, 0
local function begin(name)
	CHUNK = Instance.new("Folder")
	CHUNK.Name = name
	SUB = nil
end
local function flush()
	CHUNK.Parent = ROOT
	CHUNK = nil
	task.wait()
end
-- big chunks are split into sub-folders so no single parent write is huge
local function sub()
	if SUB == nil or SUB_N >= 250 then
		SUB = Instance.new("Folder")
		SUB.Name = "part" .. tostring(#CHUNK:GetChildren() + 1)
		SUB.Parent = CHUNK
		SUB_N = 0
	end
	SUB_N += 1
	return SUB
end

local function mk(name, size, cf, mat, parent)
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.CFrame = cf + OFFSET
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for k, v in pairs(mat or M.concrete) do p[k] = v end
	p.Parent = parent or CHUNK
	return p
end
local function box(name, x0, x1, y0, y1, z0, z1, mat, parent)
	local lx, hx = math.min(x0, x1), math.max(x0, x1)
	local ly, hy = math.min(y0, y1), math.max(y0, y1)
	local lz, hz = math.min(z0, z1), math.max(z0, z1)
	return mk(name, Vector3.new(hx - lx, hy - ly, hz - lz), CFrame.new((lx + hx) / 2, (ly + hy) / 2, (lz + hz) / 2), mat, parent)
end
-- vertical cylinder standing on y0
local function vcyl(name, x, z, y0, h, d, mat, parent)
	local p = mk(name, Vector3.new(h, d, d), CFrame.new(x, y0 + h / 2, z) * CFrame.Angles(0, 0, math.pi / 2), mat, parent)
	p.Shape = Enum.PartType.Cylinder
	return p
end
local function ball(name, pos, d, mat, parent)
	local p = mk(name, Vector3.new(d, d, d), CFrame.new(pos), mat, parent)
	p.Shape = Enum.PartType.Ball
	return p
end
local function noCollide(p)
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	return p
end
-- light anchor (invisible) with a light child
local function lightAt(cf, kind, props, parent)
	local a = noCollide(mk("LightAnchor", Vector3.new(0.2, 0.2, 0.2), cf, M.invisible, parent))
	local l = Instance.new(kind)
	for k, v in pairs(props) do l[k] = v end
	l.Parent = a
	return a
end
local function point(pos, b, r, col, shadows, parent)
	return lightAt(CFrame.new(pos), "PointLight", { Brightness = b, Range = r, Color = col, Shadows = shadows or false }, parent)
end
-- spot pointing along dir
local function spot(pos, dir, b, r, ang, col, shadows, parent)
	return lightAt(CFrame.lookAt(pos, pos + dir), "SpotLight", { Brightness = b, Range = r, Angle = ang, Color = col, Face = Enum.NormalId.Front, Shadows = shadows or false }, parent)
end

------------------------------------------------------------------ 1. ground
begin("Ground")
do
	-- asphalt inside the fence, minus the building footprint (never under the interior)
	local A = M.asphalt
	local fx0, fx1, fz0, fz1 = WX0, EX1, SZ0, NZ1
	box("Asphalt_S", SITE.x0, SITE.x1, 0, GROUND, SITE.z0, fz0, A)
	box("Asphalt_N", SITE.x0, SITE.x1, 0, GROUND, fz1, SITE.z1, A)
	box("Asphalt_W", SITE.x0, fx0, 0, GROUND, fz0, fz1, A)
	box("Asphalt_E", fx1, SITE.x1, 0, GROUND, fz0, fz1, A)
	-- grass and soil outside the fence
	local G = M.grass
	box("Grass_S", 640, 1520, 0, GROUND - 0.1, -380, SITE.z0, G)
	box("Grass_N", 640, 1520, 0, GROUND - 0.1, SITE.z1, 440, G)
	box("Grass_W", 640, SITE.x0, 0, GROUND - 0.1, SITE.z0, SITE.z1, G)
	box("Grass_E", SITE.x1, 1520, 0, GROUND - 0.1, SITE.z0, SITE.z1, G)
	-- access road along the front, out through the east gate into the woods
	box("Road", ROAD.x0, 1520, 0, GROUND + 0.06, ROAD.z0, ROAD.z1, M.road)
	local mid = (ROAD.z0 + ROAD.z1) / 2
	for x = ROAD.x0 + 8, 1500, 14 do box("RoadDash", x, x + 6, GROUND + 0.06, GROUND + 0.1, mid - 0.25, mid + 0.25, M.yellowLine) end
	box("RoadEdgeN", ROAD.x0, 1520, GROUND + 0.06, GROUND + 0.1, ROAD.z1 - 0.8, ROAD.z1 - 0.4, M.whiteLine)
	box("RoadEdgeS", ROAD.x0, 1520, GROUND + 0.06, GROUND + 0.1, ROAD.z0 + 0.4, ROAD.z0 + 0.8, M.whiteLine)
	-- the truck's own pad: lighter concrete, yellow edge, bay lines
	box("TruckPad", PAD.x0, PAD.x1, 0, GROUND + 0.05, PAD.z0, PAD.z1, M.dockPad)
	for _, e in ipairs({ { PAD.x0, PAD.x0 + 0.6, PAD.z0, PAD.z1 }, { PAD.x1 - 0.6, PAD.x1, PAD.z0, PAD.z1 }, { PAD.x0, PAD.x1, PAD.z0, PAD.z0 + 0.6 }, { PAD.x0, PAD.x1, PAD.z1 - 0.6, PAD.z1 } }) do
		box("PadEdge", e[1], e[2], GROUND + 0.05, GROUND + 0.08, e[3], e[4], M.yellowLine)
	end
	box("PadBayL", DOCK_X - 9.6, DOCK_X - 9, GROUND + 0.05, GROUND + 0.08, TRUCK_Z - 16, RAMP_Z + 4, M.whiteLine)
	box("PadBayR", DOCK_X + 9, DOCK_X + 9.6, GROUND + 0.05, GROUND + 0.08, TRUCK_Z - 16, RAMP_Z + 4, M.whiteLine)
	-- sidewalks hugging the building (not in front of the dock: that stays at grade)
	local SW = M.concrete
	box("Walk_W", WX0 - 8, WX0, 0, GROUND + 0.3, SZ0 - 8, NZ1 + 8, SW)
	box("Walk_S_W", WX0 - 8, DOCKBLK.x0 - 6, 0, GROUND + 0.3, SZ0 - 8, SZ0, SW)
	box("Walk_S_E", DOCKBLK.x1 + 14, EX1 + 8, 0, GROUND + 0.3, SZ0 - 8, SZ0, SW)
	box("Walk_E", EX1, EX1 + 6, 0, GROUND + 0.3, SZ0, NZ1, SW)
	box("Walk_N", WX0, EX1, 0, GROUND + 0.3, NZ1, NZ1 + 6, SW)
	-- dock apron pad (lighter concrete) with yellow hatching
	box("DockPad", DOCKBLK.x0 - 6, DOCKBLK.x1 + 14, 0, GROUND + 0.04, -112, DOCKBLK.z0, M.dockPad)
	for i = 0, 8 do
		local z = -70 - i * 4.5
		mk("Hatch", Vector3.new(0.6, 0.04, 9), CFrame.new(DOCKBLK.x0 - 2, GROUND + 0.06, z) * CFrame.Angles(0, math.rad(45), 0), M.yellowLine)
	end
	box("DockLaneL", DOCK_X - 10, DOCK_X - 9.4, GROUND + 0.04, GROUND + 0.07, -112, DOCKBLK.z0, M.yellowLine)
	box("DockLaneR", DOCK_X + 9.4, DOCK_X + 10, GROUND + 0.04, GROUND + 0.07, -112, DOCKBLK.z0, M.yellowLine)
	box("DockStop", DOCK_X - 10, DOCK_X + 10, GROUND + 0.04, GROUND + 0.07, -71.4, -70.8, M.yellowLine)
	-- lobby plaza and its floor through the wall
	box("LobbyPlaza", 912, WX0, 0, PLAZA_Y, LOBBY_Z - 34, LOBBY_Z + 34, M.plaza)
	box("LobbyRamp", 904, 912, 0, GROUND + 0.16, LOBBY_Z - 8, LOBBY_Z + 8, M.plaza)
end
flush()

begin("Markings")
do
	local W = M.whiteLine
	local y0, y1 = GROUND, GROUND + 0.04
	-- west car park: one row of stalls facing the building, aisle beyond
	local function stalls(z0, z1)
		for z = z0, z1, 10 do box("StallLine", 902, 920, y0, y1, z - 0.2, z + 0.2, W) end
	end
	stalls(-40, 110)
	stalls(186, 216)
	box("StallHeadW", 919.6, 920, y0, y1, -40, 110, W)
	box("StallHeadW2", 919.6, 920, y0, y1, 186, 216, W)
	-- a wheel stop in each stall
	for z = -35, 105, 10 do box("WheelStop", 916.5, 918, GROUND, GROUND + 0.5, z - 3, z + 3, M.concrete) end
	-- front car park: one row backing onto the road, west of the dock
	for x = 966, 1096, 10 do box("StallLineF", x - 0.2, x + 0.2, y0, y1, -140, -122, W) end
	box("StallHeadF", 966, 1096, y0, y1, -122.4, -122, W)
	-- arrows / crossing to the lobby
	for i = 0, 5 do box("Zebra", 884, 902, y0, y1, LOBBY_Z - 6 + i * 2.4, LOBBY_Z - 5 + i * 2.4, W) end
	-- puddles (wet night): flat reflective discs, slightly irregular
	local P = {
		{ 1146, -92, 14, 8 }, { 1188, -104, 10, 6 }, { 1132, -76, 7, 5 }, { 1205, -84, 12, 7 }, { 1160, -124, 16, 7 },
		{ 1060, -100, 11, 6 }, { 1010, -128, 9, 5 }, { 935, -20, 12, 7 }, { 930, 60, 9, 6 }, { 888, 120, 14, 8 },
		{ 905, 186, 10, 6 }, { 1240, -120, 13, 6 }, { 1290, -100, 9, 5 }, { 1176, -168, 18, 6 }, { 1150, -214, 12, 5 }, { 1190, -250, 10, 6 },
	}
	for _, p in ipairs(P) do
		for k = 0, 1 do
			local dx, dz = rng:NextNumber(-2, 2), rng:NextNumber(-2, 2)
			local s = 1 - k * 0.22
			local d = mk("Puddle", Vector3.new(0.04, p[4] * s, p[3] * s), CFrame.new(p[1] + dx, GROUND + 0.08 + k * 0.004, p[2] + dz) * CFrame.Angles(0, rng:NextNumber(0, math.pi), math.pi / 2), M.puddle)
			d.Shape = Enum.PartType.Cylinder
			noCollide(d)
		end
	end
end
flush()

------------------------------------------------------------------ 2. podium shell
-- a wall along X (south/north) or Z (west/east) with rectangular holes {a0, a1, y0, y1}
local function wallRun(name, along, a0, a1, y0, y1, t0, t1, holes, mat)
	table.sort(holes, function(p, q) return p[1] < q[1] end)
	local function piece(u0, u1, v0, v1)
		if u1 - u0 < 0.01 or v1 - v0 < 0.01 then return end
		if along == "x" then box(name, u0, u1, v0, v1, t0, t1, mat) else box(name, t0, t1, v0, v1, u0, u1, mat) end
	end
	local u = a0
	for _, h in ipairs(holes) do
		piece(u, h[1], y0, y1)
		piece(h[1], h[2], y0, h[3])
		piece(h[1], h[2], h[4], y1)
		u = h[2]
	end
	piece(u, a1, y0, y1)
end

begin("Podium")
do
	local P = M.panel
	wallRun("WallS", "x", WX0, EX1, 0, POD_TOP, SZ0, SZ1, {}, P) -- closed: the podium has no inside
	wallRun("WallN", "x", WX0, EX1, 0, POD_TOP, NZ0, NZ1, {}, P)
	wallRun("WallW", "z", SZ1, NZ0, 0, POD_TOP, WX0, WX1, {}, P)
	wallRun("WallE", "z", SZ1, NZ0, 0, POD_TOP, EX0, EX1, {}, P)
	box("Roof", WX1, EX0, ROOF_Y, ROOF_Y + 1, SZ1, NZ0, M.stoneDark)
	-- base course, cornice, reveal lines (all just proud of the panel walls)
	local function band(name, y0, y1, out, mat)
		box(name, WX0 - out, EX1 + out, y0, y1, SZ0 - out, SZ0, mat)
		box(name, WX0 - out, EX1 + out, y0, y1, NZ1, NZ1 + out, mat)
		box(name, WX0 - out, WX0, y0, y1, SZ0, NZ1, mat)
		box(name, EX1, EX1 + out, y0, y1, SZ0, NZ1, mat)
	end
	-- base course skips the two doorways
	box("BaseS1", WX0 - 0.6, DOCK_X - DOCK_W / 2, 0, 3, SZ0 - 0.6, SZ0, M.stoneDark)
	box("BaseS2", DOCK_X + DOCK_W / 2, EX1 + 0.6, 0, 3, SZ0 - 0.6, SZ0, M.stoneDark)
	box("BaseN", WX0 - 0.6, EX1 + 0.6, 0, 3, NZ1, NZ1 + 0.6, M.stoneDark)
	box("BaseW1", WX0 - 0.6, WX0, 0, 3, SZ0, LOBBY_Z - LOBBY_W / 2, M.stoneDark)
	box("BaseW2", WX0 - 0.6, WX0, 0, 3, LOBBY_Z + LOBBY_W / 2, NZ1, M.stoneDark)
	box("BaseE", EX1, EX1 + 0.6, 0, 3, SZ0, NZ1, M.stoneDark)
	band("Cornice", POD_TOP, POD_TOP + 1.5, 1.2, M.stone)
	band("Reveal", 16.8, 17.3, 0.35, M.stoneDark)
	-- stone pilasters every ~24 studs on the visible faces (west + south), skipping doorways
	local function pil(x, z, alongX)
		if alongX then box("Pilaster", x - 1.5, x + 1.5, 0, POD_TOP, SZ0 - 1, SZ0, M.stone)
		else box("Pilaster", WX0 - 1, WX0, 0, POD_TOP, z - 1.5, z + 1.5, M.stone) end
	end
	for x = WX0 + 1.5, EX1 - 1, 24 do
		if math.abs(x - DOCK_X) > 30 and not (x > DOCKBLK.x0 - 2 and x < DOCKBLK.x1 + 2) then pil(x, 0, true) end
	end
	pil(EX1 - 1.5, 0, true)
	for z = SZ0 + 1.5, NZ1 - 1, 24 do
		if math.abs(z - LOBBY_Z) > 30 then pil(0, z, false) end
	end
	pil(0, NZ1 - 1.5, false)
	-- ribbon of opaque night glass high on the podium (reads as a second storey; never shows inside)
	local function ribbonS(x0, x1)
		box("RibbonGlass", x0, x1, 19.5, 25.5, SZ0 - 0.3, SZ0, M.ribbonGlass)
	end
	ribbonS(WX0 + 4, DOCKBLK.x0 - 4)
	ribbonS(DOCKBLK.x1 + 4, EX1 - 4)
	box("RibbonGlassW1", WX0 - 0.3, WX0, 19.5, 25.5, SZ0 + 4, LOBBY_Z - 28, M.ribbonGlass)
	box("RibbonGlassW2", WX0 - 0.3, WX0, 19.5, 25.5, LOBBY_Z + 28, NZ1 - 4, M.ribbonGlass)
	-- rooftop plant
	for _, b in ipairs({ { 990, -30, 14, 10, 6 }, { 1270, 180, 12, 16, 7 }, { 1095, 175, 20, 10, 5 }, { 985, 60, 10, 10, 4 } }) do
		box("RoofPlant", b[1] - b[3] / 2, b[1] + b[3] / 2, ROOF_Y + 1, ROOF_Y + 1 + b[5], b[2] - b[4] / 2, b[2] + b[4] / 2, M.metal)
		vcyl("RoofFan", b[1], b[2], ROOF_Y + 1 + b[5], 1, math.min(b[3], b[4]) * 0.6, M.darkMetal)
	end
end
flush()

------------------------------------------------------------------ 3. dock block (lower block in front of the towers)
begin("Dock")
do
	local D = DOCKBLK
	local x0d, x1d = DOCK_X - DOCK_W / 2, DOCK_X + DOCK_W / 2
	local yTop = GROUND + DOCK_H
	box("DockBlockL", D.x0, x0d, 0, D.top, D.z0, D.z1, M.dockPanel)
	box("DockBlockR", x1d, D.x1, 0, D.top, D.z0, D.z1, M.dockPanel)
	box("DockBlockHead", x0d, x1d, yTop, D.top, D.z0, D.z1, M.dockPanel)
	box("DockCoping", D.x0 - 0.8, D.x1 + 0.8, D.top, D.top + 1.2, D.z0 - 0.8, D.z1, M.stone)
	box("DockBase", D.x0 - 0.4, x0d, 0, 2.5, D.z0 - 0.4, D.z0, M.stoneDark)
	box("DockBase", x1d, D.x1 + 0.4, 0, 2.5, D.z0 - 0.4, D.z0, M.stoneDark)
	-- inner reveal of the doorway (lined in dark metal so the tunnel reads as a door frame)
	box("DoorBack", x0d, x1d, GROUND, yTop, D.z0 + 0.6, D.z1, M.darkMetal) -- fills the opening behind the curtain
	-- roller door housing and guide rails
	box("RollerHousing", x0d - 1, x1d + 1, yTop + 0.2, yTop + 2.6, D.z0 - 1.6, D.z0, M.metal)
	-- the roller door, rolled DOWN: its front face is the dock door plane (OUTSIDE.DOCK_OUTSIDE), with a thin warm
	-- gap of light under it where the ooze seeps out
	box("RollerCurtain", x0d + 0.3, x1d - 0.3, GROUND + 0.35, yTop, D.z0, D.z0 + 0.4, M.rollerDoor)
	for y = GROUND + 1.6, yTop - 0.6, 1.25 do box("RollerRib", x0d + 0.3, x1d - 0.3, y, y + 0.18, D.z0 - 0.08, D.z0, M.metal) end
	box("RollerBottomBar", x0d + 0.3, x1d - 0.3, GROUND + 0.35, GROUND + 0.75, D.z0 - 0.15, D.z0 + 0.4, M.darkMetal)
	box("UnderDoorGlow", x0d + 0.6, x1d - 0.6, GROUND, GROUND + 0.35, D.z0 + 0.1, D.z0 + 0.5, M.lampNeon)
	spot(Vector3.new(DOCK_X, GROUND + 0.6, D.z0 + 0.2), Vector3.new(0, -0.25, -1), 2.5, 14, 120, WARM, false)
	box("GuideRailL", x0d + 0.3, x0d + 0.8, GROUND, yTop, D.z0 + 0.3, D.z0 + 0.8, M.metal)
	box("GuideRailR", x1d - 0.8, x1d - 0.3, GROUND, yTop, D.z0 + 0.3, D.z0 + 0.8, M.metal)
	-- yellow/black door guards and rubber bumpers
	for _, x in ipairs({ x0d - 0.9, x1d + 0.9 }) do
		box("DoorGuard", x - 0.6, x + 0.6, GROUND, GROUND + 9, D.z0 - 1, D.z0, M.safety)
		for k = 0, 3 do box("GuardStripe", x - 0.62, x + 0.62, GROUND + 1 + k * 2.2, GROUND + 1.8 + k * 2.2, D.z0 - 1.02, D.z0 - 0.98, M.black) end
		box("Bumper", x - 0.8, x + 0.8, GROUND + 1, GROUND + 3.2, D.z0 - 1.6, D.z0, M.rubber)
	end
	-- canopy over the door with tie rods
	box("Canopy", x0d - 5, x1d + 5, yTop + 4, yTop + 4.6, D.z0 - 7, D.z0, M.darkMetal)
	box("CanopyFascia", x0d - 5, x1d + 5, yTop + 3.4, yTop + 4.6, D.z0 - 7.2, D.z0 - 6.8, M.metal)
	for _, x in ipairs({ x0d - 4, x1d + 4 }) do
		local a, b = Vector3.new(x, yTop + 4.6, D.z0 - 6.6), Vector3.new(x, yTop + 10, D.z0)
		mk("TieRod", Vector3.new(0.25, 0.25, (b - a).Magnitude), CFrame.lookAt((a + b) / 2, b), M.darkMetal)
	end
	-- warm spill: under-canopy downlight, light from inside the door, a glow strip in the header
	spot(Vector3.new(DOCK_X, yTop + 3.9, D.z0 - 3.5), Vector3.new(0, -1, -0.25), 4, 28, 80, SODIUM, true)
	box("CanopyLens", DOCK_X - 3, DOCK_X + 3, yTop + 3.7, yTop + 4, D.z0 - 4, D.z0 - 3, M.lampNeon)
	point(Vector3.new(DOCK_X, GROUND + 2, D.z0 - 2), 2, 16, WARM, false) -- warm pool on the apron in front of the door
	-- sodium floods on the dock parapet washing the apron and the truck
	for _, x in ipairs({ D.x0 + 22, D.x1 - 22 }) do
		box("FloodHead", x - 1.2, x + 1.2, D.top + 1.2, D.top + 2.6, D.z0 - 1.6, D.z0 + 0.4, M.darkMetal)
		spot(Vector3.new(x, D.top + 1.6, D.z0 - 1.8), Vector3.new((DOCK_X - x) * 0.012, -1, -0.9), 4, 55, 75, SODIUM, true)
	end
	-- wall packs either side
	local function wallpack(x, y)
		box("WallPack", x - 0.9, x + 0.9, y - 0.6, y + 0.6, D.z0 - 1, D.z0, M.darkMetal)
		box("WallPackLens", x - 0.7, x + 0.7, y - 0.65, y - 0.55, D.z0 - 0.9, D.z0 - 0.1, M.lampNeon)
		spot(Vector3.new(x, y - 0.8, D.z0 - 0.6), Vector3.new(0, -1, -0.45), 4, 32, 95, SODIUM, false)
	end
	wallpack(D.x0 + 12, 17)
	wallpack(D.x1 - 8, 17)
	-- bollards
	for _, x in ipairs({ x0d - 4, x1d + 4, 1185 }) do
		vcyl("Bollard", x, D.z0 - 3, GROUND, 4, 1, M.safety)
		vcyl("BollardCap", x, D.z0 - 3, GROUND + 4, 0.2, 1.1, M.black)
	end
	-- man door with stoop, steps and rail (facade door: locked, never opens)
	local mx = 1200
	box("ManDoorFrame", mx - 2.6, mx + 2.6, GROUND + 3, GROUND + 11.6, D.z0 - 0.3, D.z0, M.darkMetal)
	box("ManDoor", mx - 2, mx + 2, GROUND + 3.2, GROUND + 11, D.z0 - 0.45, D.z0 - 0.3, M.metal)
	box("ManDoorHandle", mx + 1.2, mx + 1.6, GROUND + 6.8, GROUND + 7.1, D.z0 - 0.75, D.z0 - 0.45, M.darkMetal)
	box("Stoop", mx - 4, mx + 4, GROUND, GROUND + 3, D.z0 - 5, D.z0, M.concrete)
	for k = 0, 2 do
		box("Step", mx - 9 - k * 1.2, mx - 4, GROUND, GROUND + 3 - (k + 1) * 0.75, D.z0 - 5, D.z0 - 1.5, M.metal)
	end
	box("RailPostA", mx + 3.6, mx + 3.9, GROUND + 3, GROUND + 6.5, D.z0 - 4.9, D.z0 - 4.6, M.darkMetal)
	box("RailPostB", mx - 3.9, mx - 3.6, GROUND + 3, GROUND + 6.5, D.z0 - 4.9, D.z0 - 4.6, M.darkMetal)
	box("RailTop", mx - 3.9, mx + 3.9, GROUND + 6.3, GROUND + 6.6, D.z0 - 4.9, D.z0 - 4.6, M.darkMetal)
	do
		local a, b = Vector3.new(mx - 13.8, GROUND + 3.6, D.z0 - 4.75), Vector3.new(mx - 3.75, GROUND + 6.45, D.z0 - 4.75)
		mk("StairRail", Vector3.new(0.3, 0.3, (b - a).Magnitude), CFrame.lookAt((a + b) / 2, b), M.darkMetal)
		vcyl("StairPost", mx - 13.6, D.z0 - 4.75, GROUND, 3.8, 0.3, M.darkMetal)
	end
	wallpack(mx, GROUND + 13.5)
	-- utility cabinet with pipes, dumpsters, a couple of cartons
	box("UtilityBox", 1206, 1215, GROUND, GROUND + 9, D.z0 - 5, D.z0, M.metal)
	box("UtilityLid", 1205.6, 1215.4, GROUND + 9, GROUND + 9.4, D.z0 - 5.4, D.z0, M.darkMetal)
	vcyl("Pipe", 1208, D.z0 - 1.5, GROUND + 9.4, 4, 0.8, M.darkMetal)
	vcyl("Pipe", 1212, D.z0 - 1.5, GROUND + 9.4, 3, 0.8, M.darkMetal)
	box("PipeBend", 1207.6, 1212.4, GROUND + 12.4, GROUND + 13.2, D.z0 - 1.9, D.z0 - 1.1, M.darkMetal)
	local function dumpster(x, z, mat, yaw)
		local cf = CFrame.new(x, GROUND, z) * CFrame.Angles(0, math.rad(yaw or 0), 0)
		mk("Dumpster", Vector3.new(9, 5, 5.5), cf * CFrame.new(0, 2.8, 0), mat)
		mk("DumpsterLid", Vector3.new(9.2, 0.3, 5.9), cf * CFrame.new(0, 5.6, 0) * CFrame.Angles(math.rad(6), 0, 0), M.darkMetal)
		for _, dx in ipairs({ -3.8, 3.8 }) do mk("Caster", Vector3.new(0.8, 0.6, 0.8), cf * CFrame.new(dx, 0.3, 0), M.rubber) end
	end
	dumpster(1222.5, D.z0 - 3.4, M.dumpGreen)
	dumpster(1230, -72, M.dumpGreen, 90)
	dumpster(1120, D.z0 - 3.4, M.dumpBlue)
	box("Carton", 1127, 1130.5, GROUND, GROUND + 3, D.z0 - 8, D.z0 - 4.5, M.cardboard)
	mk("Carton", Vector3.new(2.6, 2.4, 2.6), CFrame.new(1131.5, GROUND + 1.2, D.z0 - 7) * CFrame.Angles(0, math.rad(20), 0), M.cardboard)
end
flush()

------------------------------------------------------------------ 4. towers (oversized, above the podium)
local function tower(name, x0, x1, z0, z1, yTop, litP, opts)
	opts = opts or {}
	local yb = TOWER_BASE
	box(name .. "Core", x0, x1, yb, yTop, z0, z1, M.nightGlass)
	local STOREY = 12
	local faces = {
		{ along = "x", a0 = x0, a1 = x1, w = z0, n = -1 },
		{ along = "x", a0 = x0, a1 = x1, w = z1, n = 1 },
		{ along = "z", a0 = z0, a1 = z1, w = x0, n = -1 },
		{ along = "z", a0 = z0, a1 = z1, w = x1, n = 1 },
	}
	for fi, f in ipairs(faces) do
		if not (opts.skip and opts.skip[fi]) then
			local function fbox(nm, u0, u1, v0, v1, d0, d1, mat)
				local w0, w1 = f.w + f.n * d0, f.w + f.n * d1
				if f.along == "x" then return box(nm, u0, u1, v0, v1, w0, w1, mat, sub()) end
				return box(nm, w0, w1, v0, v1, u0, u1, mat, sub())
			end
			local span = f.a1 - f.a0 - 8
			local nb = math.max(1, math.floor(span / 7 + 0.5))
			local bay = span / nb
			local u0 = f.a0 + 4
			for j = 1, nb - 1 do
				local u = u0 + j * bay
				local major = (j % 3 == 0)
				fbox("Fin", u - (major and 0.9 or 0.5), u + (major and 0.9 or 0.5), yb, yTop, 0, major and 1.6 or 0.9, major and M.stone or M.stoneMid)
			end
			local ns = math.floor((yTop - yb) / STOREY)
			for k = 1, ns do
				local y = yb + k * STOREY
				if y < yTop - 1 then fbox("Spandrel", f.a0 + 4, f.a1 - 4, y - 0.8, y + 0.8, 0, 0.6, M.stoneMid) end
			end
			for j = 0, nb - 1 do
				for k = 0, ns - 1 do
					local r = rng:NextNumber()
					if r < litP then
						local uc = u0 + (j + 0.5) * bay
						local v0, v1 = yb + k * STOREY + 0.8, yb + (k + 1) * STOREY - 0.8
						local lit = r < litP * 0.7
						fbox("WinLit", uc - bay / 2 + 0.5, uc + bay / 2 - 0.5, v0 + 0.3, v1 - 0.3, 0, 0.12, lit and M.winLit or M.winDim)
						-- half-drawn blinds: a few slats across the top of the lit pane
						local nsl = rng:NextInteger(1, 2)
						for s = 1, nsl do
							local ys = v1 - 0.3 - s * 1.6
							fbox("Blind", uc - bay / 2 + 0.5, uc + bay / 2 - 0.5, ys, ys + 0.7, 0.12, 0.2, M.blind)
						end
					end
				end
			end
		end
	end
	-- stone corner piers that run past the roof line, and a crown with a setback plant room
	for _, c in ipairs({ { x0, z0 }, { x1, z0 }, { x0, z1 }, { x1, z1 } }) do
		box(name .. "Pier", c[1] - 3, c[1] + 3, yb, yTop + 6, c[2] - 3, c[2] + 3, M.stone, sub())
	end
	box(name .. "Crown", x0 - 1, x1 + 1, yTop, yTop + 3, z0 - 1, z1 + 1, M.stone, sub())
	box(name .. "Penthouse", x0 + 8, x1 - 8, yTop + 3, yTop + 10, z0 + 8, z1 - 8, M.panel, sub())
	-- a red aviation light on the tallest corner
	box(name .. "Beacon", x1 - 3.5, x1 - 2.5, yTop + 6, yTop + 7, z0 - 0.5, z0 + 0.5, M.redLens, sub())
end

-- moon/sodium "wash": an invisible panel `dist` in front of a facade with a SurfaceLight facing it.
-- Lighting is night-dark on purpose (interior look); the exterior reads through its own light, as in the concept.
local function washPanel(center, normal, w, h, dist, b, r, col)
	local pos = center + normal * dist
	local a = noCollide(mk("WashPanel", Vector3.new(w, h, 0.2), CFrame.lookAt(pos, center), M.invisible))
	local l = Instance.new("SurfaceLight")
	l.Face = Enum.NormalId.Front
	l.Brightness = b
	l.Range = r
	l.Angle = 70
	l.Color = col
	l.Parent = a
	return a
end
-- stacked moon washes up a tower face (30-stud bands, so every storey gets light)
local function moonFace(cx, cz, normal, w, y0, y1, b)
	-- one band per MOON_BAND studs from the top down (the lower storeys get the car-park light)
	if MOON_BAND <= 0 then return end
	for y = y1 - MOON_BAND, y0 + 40, -MOON_BAND do washPanel(Vector3.new(cx, y + MOON_BAND / 2, cz), normal, w, MOON_BAND, 22, b * MOON_SCALE, 40, MOON) end
end
-- cool "moonlit" rim on a crown: three spots above and in front, pointing down at it
local function rim(cx, cz, yTop, normal)
	for _, dx in ipairs({ 0 }) do
		local side = Vector3.new(-normal.Z, 0, normal.X) * dx
		local target = Vector3.new(cx, yTop, cz) + side
		spot(target + normal * 40 + Vector3.new(0, 40, 0), (target - (target + normal * 40 + Vector3.new(0, 40, 0))).Unit, 1.5, 60, 90, MOON, false)
	end
end

local S, W = Vector3.new(0, 0, -1), Vector3.new(-1, 0, 0)
local TW = { x0 = 1044, x1 = 1138, z0 = -26, z1 = 96, top = 166 }
local TE = { x0 = 1198, x1 = 1284, z0 = -18, z1 = 110, top = 150 }
local TN = { x0 = 966, x1 = 1040, z0 = 112, z1 = 196, top = 130 }
local PY = { x0 = 1138, x1 = 1198, z0 = -36, z1 = 10, top = 180 }

begin("TowerW")
tower("TowerW", TW.x0, TW.x1, TW.z0, TW.z1, TW.top, 0.05)
moonFace((TW.x0 + TW.x1) / 2, TW.z0, S, TW.x1 - TW.x0, TOWER_BASE, TW.top, 0.8)
moonFace(TW.x0, (TW.z0 + TW.z1) / 2, W, TW.z1 - TW.z0, TOWER_BASE, TW.top, 0.8)
rim((TW.x0 + TW.x1) / 2, TW.z0, TW.top, S)
flush()
begin("TowerE")
tower("TowerE", TE.x0, TE.x1, TE.z0, TE.z1, TE.top, 0.05)
moonFace((TE.x0 + TE.x1) / 2, TE.z0, S, TE.x1 - TE.x0, TOWER_BASE, TE.top, 0.8)
rim((TE.x0 + TE.x1) / 2, TE.z0, TE.top, S)
flush()
begin("TowerNW")
tower("TowerNW", TN.x0, TN.x1, TN.z0, TN.z1, TN.top, 0.06)
moonFace(TN.x0, (TN.z0 + TN.z1) / 2, W, TN.z1 - TN.z0, TOWER_BASE, TN.top, 0.8)
moonFace((TN.x0 + TN.x1) / 2, TN.z0, S, TN.x1 - TN.x0, TOWER_BASE, TN.top, 0.8)
rim(TN.x0, (TN.z0 + TN.z1) / 2, TN.top, W)
flush()

begin("Pylon")
do
	-- central stone pylon with the deco panel (the concept's centre mass), rising straight off the podium
	local px0, px1, pz0, pz1, ptop = PY.x0, PY.x1, PY.z0, PY.z1, PY.top
	box("Pylon", px0, px1, TOWER_BASE, ptop, pz0, pz1, M.stone)
	box("PylonCrown1", px0 - 1.5, px1 + 1.5, ptop, ptop + 3, pz0 - 1.5, pz1 + 1.5, M.stone)
	box("PylonCrown2", px0 + 6, px1 - 6, ptop + 3, ptop + 9, pz0 + 4, pz1 - 4, M.stoneMid)
	local cx = (px0 + px1) / 2
	local function frame(hw, y0, y1, t, out)
		box("DecoFrame", cx - hw, cx + hw, y1 - t, y1, pz0 - out, pz0, M.stone)
		box("DecoFrame", cx - hw, cx + hw, y0, y0 + t, pz0 - out, pz0, M.stone)
		box("DecoFrame", cx - hw, cx - hw + t, y0, y1, pz0 - out, pz0, M.stone)
		box("DecoFrame", cx + hw - t, cx + hw, y0, y1, pz0 - out, pz0, M.stone)
	end
	frame(22, 44, 170, 2, 1.2)
	frame(17, 48, 164, 1.2, 0.7)
	box("DecoNotch", cx - 10, cx + 10, 164, 168, pz0 - 0.9, pz0, M.stone)
	box("DecoNotch", cx - 5, cx + 5, 168, 172, pz0 - 1.2, pz0, M.stone)
	box("DecoPanel", cx - 15.8, cx + 15.8, 49.2, 162.8, pz0 - 0.2, pz0, M.stoneMid)
	-- low shoulder where the pylon meets the podium, with a ribbon of dark glass
	box("PylonShoulder", px0 - 4, px1 + 4, TOWER_BASE, 42, pz0 - 6, pz0, M.panel)
	box("ShoulderCornice", px0 - 5, px1 + 5, 42, 43.5, pz0 - 7, pz0, M.stone)
	box("ShoulderRibbon", px0, px1, 32, 39, pz0 - 6.3, pz0 - 6, M.ribbonGlass)
	box("ShoulderLit", cx + 8, cx + 18, 33, 38, pz0 - 6.4, pz0 - 6.3, M.winLit)
	for _, x in ipairs({ px0 + 2.5, px1 - 2.5 }) do box("PylonFin", x - 1.5, x + 1.5, 43.5, ptop, pz0 - 2, pz0, M.stone) end
	-- warm uplights on the shoulder grazing the deco panel (concept's lit centre)
	for _, x in ipairs({ cx - 14, cx + 14 }) do
		box("UplightCan", x - 1, x + 1, 43.5, 44.5, pz0 - 5, pz0 - 3, M.darkMetal)
		spot(Vector3.new(x, 44.6, pz0 - 4), Vector3.new(0, 1, 0.06), 8, 60, 26, SODIUM, false)
	end
	spot(Vector3.new(cx, 44.6, pz0 - 6), Vector3.new(0, 1, 0.1), 6, 60, 40, SODIUM, false)
	moonFace(cx, pz0, S, px1 - px0, 100, ptop, 0.5)
	rim(cx, pz0, ptop, S)
	-- warm wash low on the podium faces (the car-park sodium bouncing up the walls)
	washPanel(Vector3.new((WX0 + DOCKBLK.x0) / 2, 14, SZ0), S, DOCKBLK.x0 - WX0, 26, 18, 0.5, 34, SODIUM)
	washPanel(Vector3.new((DOCKBLK.x1 + EX1) / 2, 14, SZ0), S, EX1 - DOCKBLK.x1, 26, 18, 0.5, 34, SODIUM)
	washPanel(Vector3.new(DOCK_X, 12, DOCKBLK.z0), S, DOCKBLK.x1 - DOCKBLK.x0, 22, 18, 0.5, 34, SODIUM)
	washPanel(Vector3.new(WX0, 14, (SZ0 + LOBBY_Z) / 2 - 10), W, LOBBY_Z - SZ0 - 40, 26, 18, 0.5, 34, SODIUM)
	washPanel(Vector3.new(WX0, 14, (LOBBY_Z + NZ1) / 2 + 12), W, NZ1 - LOBBY_Z - 30, 26, 18, 0.4, 34, SODIUM)
	-- moon on the podium's upper band and cornice
	washPanel(Vector3.new((WX0 + EX1) / 2, 30, SZ0), S, EX1 - WX0, 16, 24, 0.35, 34, MOON)
	washPanel(Vector3.new(WX0, 30, (SZ0 + NZ1) / 2), W, NZ1 - SZ0, 16, 24, 0.35, 34, MOON)
end
flush()

------------------------------------------------------------------ 5. lobby rotunda (west face)
begin("Lobby")
do
	local cx, cz = ROT_C.X, ROT_C.Z
	local R = ROT_R
	local GY = PLAZA_Y
	local TOP = 24
	-- glass drum: 14 segments over the half circle facing -X, door gap in the middle
	local N = 14
	for i = 0, N - 1 do
		local a0 = -math.pi / 2 + i * math.pi / N
		local a1 = a0 + math.pi / N
		local am = (a0 + a1) / 2
		local d = Vector3.new(-math.cos(am), 0, math.sin(am))
		local pos = Vector3.new(cx, GY + (TOP - GY) / 2, cz) + d * R
		local width = 2 * R * math.sin(math.pi / N / 2) + 0.15
		local isDoor = (i == N / 2 - 1 or i == N / 2)
		local cf = CFrame.lookAt(pos, pos + d)
		if isDoor then
			-- closed glass door leaf (the pair's centre is the LOBBY_OUTSIDE door) and the transom over it
			mk("LobbyDoorLeaf", Vector3.new(width - 0.3, 10 - 0.6, 0.25), cf * CFrame.new(0, -(TOP - GY) / 2 + (10 - 0.6) / 2, 0), M.lobbyGlass)
			mk("LobbyDoorStile", Vector3.new(0.3, 10 - 0.6, 0.35), cf * CFrame.new((width - 0.3) / 2 * (i == N / 2 and -1 or 1), -(TOP - GY) / 2 + (10 - 0.6) / 2, 0), M.darkMetal)
			mk("Transom", Vector3.new(width, TOP - (GY + 10), 0.4), cf * CFrame.new(0, (TOP - GY) / 2 - (TOP - (GY + 10)) / 2, 0), M.lobbyGlass)
			mk("DoorHead", Vector3.new(width, 0.6, 0.8), cf * CFrame.new(0, -(TOP - GY) / 2 + 10, 0), M.darkMetal)
		else
			mk("DrumGlass", Vector3.new(width, TOP - GY, 0.4), cf, M.lobbyGlass)
		end
		-- mullion on each joint
		local dj = Vector3.new(-math.cos(a0), 0, math.sin(a0))
		local pj = Vector3.new(cx, GY + (TOP - GY) / 2, cz) + dj * R
		mk("Mullion", Vector3.new(0.35, TOP - GY, 0.6), CFrame.lookAt(pj, pj + dj), M.darkMetal)
	end
	local function disc(name, r, y0, y1, mat)
		local p = mk(name, Vector3.new(y1 - y0, r * 2, r * 2), CFrame.new(cx, (y0 + y1) / 2, cz) * CFrame.Angles(0, 0, math.pi / 2), mat)
		p.Shape = Enum.PartType.Cylinder
		return p
	end
	assert(TOP >= 17, "rotunda roof must be above the keep-out")
	disc("DrumRoof", R + 0.6, TOP, TOP + 1, M.stoneMid)
	disc("Canopy", R + 9, TOP + 2.5, TOP + 5.5, M.stone)
	disc("CanopySoffit", R + 8.6, TOP + 2.2, TOP + 2.5, M.stoneMid)
	disc("CanopyBand", R + 9.3, TOP + 3.4, TOP + 4.4, M.stoneMid)
	-- under-canopy warm downlights (ring of small lenses + 4 spots)
	for i = 0, 9 do
		local a = -math.pi / 2 + (i + 0.5) * math.pi / 10
		local d = Vector3.new(-math.cos(a), 0, math.sin(a))
		local p = Vector3.new(cx, TOP + 2.1, cz) + d * (R + 5.5)
		mk("CanopyLens", Vector3.new(1.2, 0.15, 1.2), CFrame.new(p), M.pathNeon)
		if i % 3 == 1 then spot(p - Vector3.new(0, 0.3, 0), Vector3.new(0, -1, 0), 1.8, 24, 70, LOBBY_WARM, false) end
	end
	-- columns in front of the drum
	for _, deg in ipairs({ -62, -26, 26, 62 }) do
		local a = math.rad(deg)
		local d = Vector3.new(-math.cos(a), 0, math.sin(a))
		local p = Vector3.new(cx, 0, cz) + d * (R + 6)
		vcyl("ColumnBase", p.X, p.Z, GY, 1.2, 4.4, M.stoneMid)
		vcyl("Column", p.X, p.Z, GY, TOP + 2.2 - GY, 3.4, M.stone)
		vcyl("ColumnCap", p.X, p.Z, TOP + 0.6, 1.6, 4.2, M.stoneMid)
	end
	-- inside: warm oak feature wall on the shell either side of the opening, polished floor, two ring lights
	box("LobbyFloor", cx - R, cx, GY, GY + 0.02, cz - R, cz + R, M.lobbyFloor)
	box("OakWallL", cx - 0.4, cx, GY, TOP, cz - R, cz - LOBBY_W / 2 - 0.5, M.oak)
	box("OakWallR", cx - 0.4, cx, GY, TOP, cz + LOBBY_W / 2 + 0.5, cz + R, M.oak)
	box("PortalFrame", cx - 0.8, cx, GY, GY + LOBBY_H + 1.2, cz - LOBBY_W / 2 - 0.6, cz - LOBBY_W / 2, M.stone)
	box("PortalFrame", cx - 0.8, cx, GY, GY + LOBBY_H + 1.2, cz + LOBBY_W / 2, cz + LOBBY_W / 2 + 0.6, M.stone)
	box("PortalHead", cx - 0.8, cx, GY + LOBBY_H, GY + LOBBY_H + 1.2, cz - LOBBY_W / 2 - 0.6, cz + LOBBY_W / 2 + 0.6, M.stone)
	-- the inner doors (exterior dressing; the wall behind is solid)
	box("InnerDoors", cx - 0.3, cx, GY, GY + LOBBY_H, cz - LOBBY_W / 2, cz + LOBBY_W / 2, M.oak)
	box("InnerDoorSplit", cx - 0.4, cx - 0.3, GY, GY + LOBBY_H, cz - 0.15, cz + 0.15, M.darkMetal)
	local function ring(rx, ry, rz, r, n)
		for i = 0, n - 1 do
			local phi = i / n * math.pi * 2
			local p = Vector3.new(rx + r * math.cos(phi), ry, rz + r * math.sin(phi))
			local t = Vector3.new(-math.sin(phi), 0, math.cos(phi))
			noCollide(mk("RingLight", Vector3.new(0.35, 0.35, 2 * math.pi * r / n + 0.1), CFrame.lookAt(p, p + t), M.ringNeon))
		end
		-- hanger wires
		for i = 0, 2 do
			local phi = i / 3 * math.pi * 2
			local p = Vector3.new(rx + r * math.cos(phi), (ry + TOP) / 2, rz + r * math.sin(phi))
			noCollide(mk("Hanger", Vector3.new(0.08, TOP - ry, 0.08), CFrame.new(p), M.darkMetal))
		end
	end
	ring(cx - 8, 19, cz, 6.2, 28)
	ring(cx - 8, 15.5, cz, 4.2, 20)
	point(Vector3.new(cx - 8, 16, cz), 3.5, 30, LOBBY_WARM, true)
	point(Vector3.new(cx - R - 3, 4, cz), 1.6, 18, LOBBY_WARM, false) -- spill onto the plaza
	-- a low reception counter inside the drum (no faces, nobody at it)
	box("Counter", cx - 6, cx - 3, GY, GY + 3.6, cz + 7, cz + 12, M.oak)
	box("CounterTop", cx - 6.3, cx - 2.7, GY + 3.6, GY + 3.9, cz + 6.7, cz + 12.3, M.stone)
	box("CounterGlow", cx - 6.05, cx - 5.95, GY + 0.3, GY + 0.5, cz + 7.1, cz + 11.9, M.pathNeon)
	-- welcome screen (blank glow; the anomaly would put text on it)
	box("WelcomeScreen", cx - 0.6, cx - 0.4, GY + 6, GY + 10, cz - R + 1.5, cz - R + 6.5, M.winDim)
end
flush()

begin("Landscape")
do
	local GY = PLAZA_Y
	-- planter beds flanking the plaza approach, with hedges and cone topiaries
	local function topiary(x, z, y0, h, d)
		local tiers = 9
		for i = 0, tiers - 1 do
			local f = 1 - i / tiers
			vcyl("Topiary", x, z, y0 + i * h / tiers * 0.9, h / tiers * 1.2, d * f + 0.3, M.topiary)
		end
		ball("TopiaryTip", Vector3.new(x, y0 + h * 0.95, z), 0.9, M.topiary)
	end
	local function planter(x0, x1, z0, z1, tops)
		box("PlanterWall", x0, x1, GY, GY + 2.4, z0, z1, M.stoneMid)
		box("PlanterSoil", x0 + 0.5, x1 - 0.5, GY + 2.4, GY + 2.5, z0 + 0.5, z1 - 0.5, M.soil)
		box("Hedge", x0 + 0.6, x1 - 0.6, GY + 2.4, GY + 4.4, z0 + 0.6, z1 - 0.6, M.hedge)
		for _, t in ipairs(tops) do topiary(t[1], t[2], GY + 4.2, t[3], t[4]) end
	end
	planter(914, 924, LOBBY_Z - 25, LOBBY_Z - 11, { { 919, LOBBY_Z - 21, 9, 4 }, { 919, LOBBY_Z - 15, 7, 3.2 } })
	planter(914, 924, LOBBY_Z + 11, LOBBY_Z + 25, { { 919, LOBBY_Z + 15, 7, 3.2 }, { 919, LOBBY_Z + 21, 9, 4 } })
	planter(942, 954, LOBBY_Z - 33, LOBBY_Z - 26, { { 948, LOBBY_Z - 29.5, 10, 4.2 } })
	planter(942, 954, LOBBY_Z + 26, LOBBY_Z + 33, { { 948, LOBBY_Z + 29.5, 10, 4.2 } })
	-- low path lights along the approach and the building walk
	local function pathLight(x, z)
		box("PathLightPost", x - 0.35, x + 0.35, GY, GY + 2.2, z - 0.35, z + 0.35, M.darkMetal)
		box("PathLightLens", x - 0.4, x + 0.4, GY + 2.2, GY + 2.7, z - 0.4, z + 0.4, M.pathNeon)
		box("PathLightCap", x - 0.5, x + 0.5, GY + 2.7, GY + 2.9, z - 0.5, z + 0.5, M.darkMetal)
		point(Vector3.new(x, GY + 2.5, z), 1.1, 9, WARM, false)
	end
	for _, z in ipairs({ LOBBY_Z - 9, LOBBY_Z + 9 }) do
		for _, x in ipairs({ 905, 928 }) do pathLight(x, z) end
	end
	for _, z in ipairs({ -40, 24, 88, 196 }) do pathLight(WX0 - 7.4, z) end
	-- hedges along the west walk
	for z = -44, 100, 32 do box("LotHedge", 921, 925, GROUND, GROUND + 2.6, z + 6, z + 26, M.hedge) end
end
flush()

------------------------------------------------------------------ 6. car park lights, wall packs, cars
begin("SiteLights")
do
	local function pole(x, z, armDir)
		vcyl("PoleBase", x, z, GROUND, 1.6, 2.2, M.concrete)
		vcyl("Pole", x, z, GROUND + 1.6, 22, 0.7, M.darkMetal)
		local ad = armDir or Vector3.new(1, 0, 0)
		local top = Vector3.new(x, GROUND + 23.2, z)
		local head = top + ad * 3.2
		mk("PoleArm", Vector3.new(0.4, 0.4, 3.4), CFrame.lookAt((top + head) / 2, head), M.darkMetal)
		mk("PoleHead", Vector3.new(2.2, 0.7, 3.6), CFrame.lookAt(head, head + ad), M.darkMetal)
		mk("PoleLens", Vector3.new(1.8, 0.1, 3), CFrame.lookAt(head - Vector3.new(0, 0.4, 0), head - Vector3.new(0, 0.4, 0) + ad), M.lampNeon)
		spot(head - Vector3.new(0, 0.6, 0), Vector3.new(0, -1, 0), 6, 60, 120, SODIUM, true)
	end
	pole(898, -30, Vector3.new(1, 0, 0))
	pole(898, 70, Vector3.new(1, 0, 0))
	pole(898, 200, Vector3.new(1, 0, 0))
	pole(1010, -117, Vector3.new(0, 0, 1))
	pole(1090, -117, Vector3.new(0, 0, 1))
	pole(1262, -112, Vector3.new(0, 0, 1))
	pole(896, 135, Vector3.new(1, 0, 0))
	-- the walk: sodium poles beside (never on) the straight line truck -> dock, then the truck pad
	for z = -110, RAMP_Z + 20, -50 do pole(DOCK_X - 26, z, Vector3.new(1, 0, 0)) end
	pole(PAD.x1 + 3, PAD.z1 - 4, Vector3.new(-1, 0, 0))
	pole(PAD.x0 - 3, PAD.z0 + 6, Vector3.new(1, 0, 0))
	-- wall packs on the podium (west, south, east and north)
	local function wp(pos, out)
		local cf = CFrame.lookAt(pos, pos + out)
		mk("WallPack", Vector3.new(1.8, 1.2, 1), cf * CFrame.new(0, 0, -0.5), M.darkMetal)
		mk("WallPackLens", Vector3.new(1.4, 0.1, 0.8), cf * CFrame.new(0, -0.62, -0.5), M.lampNeon)
		spot(pos + out * 0.6 - Vector3.new(0, 0.8, 0), Vector3.new(out.X * 0.45, -1, out.Z * 0.45), 4, 32, 95, SODIUM, false)
	end
	for _, z in ipairs({ -26, 46, 94, 196 }) do wp(Vector3.new(WX0, 14, z), Vector3.new(-1, 0, 0)) end
	for _, x in ipairs({ 990, 1062, 1268 }) do wp(Vector3.new(x, 14, SZ0), Vector3.new(0, 0, -1)) end
	wp(Vector3.new(EX1, 14, 40), Vector3.new(1, 0, 0))
end
flush()

begin("Cars")
do
	local function car(x, z, yaw, body)
		local cf = CFrame.new(x, GROUND, z) * CFrame.Angles(0, math.rad(yaw), 0)
		mk("CarBody", Vector3.new(6.4, 2.2, 14), cf * CFrame.new(0, 2.1, 0), body)
		mk("CarCabin", Vector3.new(5.6, 2.1, 7), cf * CFrame.new(0, 4.2, 0.6), body)
		mk("CarGlass", Vector3.new(5.7, 1.6, 7.1), cf * CFrame.new(0, 4.25, 0.6), M.nightGlass)
		mk("CarRoof", Vector3.new(5.4, 0.3, 5.6), cf * CFrame.new(0, 5.3, 0.6), body)
		for _, w in ipairs({ { -2.9, -4.4 }, { 2.9, -4.4 }, { -2.9, 4.4 }, { 2.9, 4.4 } }) do
			local p = mk("Wheel", Vector3.new(1, 2.6, 2.6), cf * CFrame.new(w[1], 1.3, w[2]), M.tyre)
			p.Shape = Enum.PartType.Cylinder
		end
		mk("TailLight", Vector3.new(1.4, 0.5, 0.12), cf * CFrame.new(-2.2, 2.6, 7.02), M.redLens)
		mk("TailLight", Vector3.new(1.4, 0.5, 0.12), cf * CFrame.new(2.2, 2.6, 7.02), M.redLens)
		mk("Headlight", Vector3.new(1.4, 0.5, 0.12), cf * CFrame.new(-2.2, 2.4, -7.02), M.metal)
		mk("Headlight", Vector3.new(1.4, 0.5, 0.12), cf * CFrame.new(2.2, 2.4, -7.02), M.metal)
	end
	-- nose toward the building in the west row; one in the front row
	car(909, 35, -90, { Material = Enum.Material.SmoothPlastic, Color = C(58, 66, 80) })
	car(1031, -131, 180, { Material = Enum.Material.SmoothPlastic, Color = C(120, 116, 108) })
end
flush()

------------------------------------------------------------------ 7. the truck: built by code (OUTSIDE.TRUCK_CENTRE); only its pad is art

------------------------------------------------------------------ 8. boundary: fence, gate + booth, invisible wall, pines
begin("Fence")
do
	local H = 9
	local function fenceRun(ax, az, bx, bz, gap)
		local a, b = Vector3.new(ax, 0, az), Vector3.new(bx, 0, bz)
		local len = (b - a).Magnitude
		local dir = (b - a).Unit
		local n = math.floor(len / 10)
		for i = 0, n do
			local p = a + dir * (len * i / n)
			local skip = gap and gap(p)
			if not skip then
				box("FencePost", p.X - 0.25, p.X + 0.25, GROUND, GROUND + H, p.Z - 0.25, p.Z + 0.25, M.darkMetal, sub())
			end
			if i < n then
				local q = a + dir * (len * (i + 1) / n)
				local m = (p + q) / 2
				q = a + dir * (len * math.min(i + 2, n) / n)
				m = (p + q) / 2
				if i % 2 == 0 and not (gap and (gap(p) or gap(m) or gap(q))) then
					local seg = (q - p).Magnitude
					local cf = CFrame.lookAt(m, q)
					mk("FenceMesh", Vector3.new(0.1, H - 0.6, seg), cf * CFrame.new(0, GROUND + (H - 0.6) / 2, 0), { Material = Enum.Material.DiamondPlate, Color = C(54, 58, 62), Transparency = 0.72 }, sub())
					mk("FenceRail", Vector3.new(0.18, 0.18, seg), cf * CFrame.new(0, GROUND + H - 0.2, 0), M.darkMetal, sub())
				end
			end
		end
	end
	local gate = function(p) return math.abs(p.X - SITE.x1) < 1 and p.Z > ROAD.z0 - 2 and p.Z < ROAD.z1 + 2 end
	fenceRun(SITE.x0, SITE.z0, SITE.x1, SITE.z0)
	fenceRun(SITE.x1, SITE.z0, SITE.x1, SITE.z1, gate)
	fenceRun(SITE.x1, SITE.z1, SITE.x0, SITE.z1)
	fenceRun(SITE.x0, SITE.z1, SITE.x0, SITE.z0)
	-- gate: boom barrier (down) and a security booth
	local gx = SITE.x1
	box("GatePier", gx - 1, gx + 1, GROUND, GROUND + 10, ROAD.z1 + 1, ROAD.z1 + 3, M.stoneMid)
	box("GatePier", gx - 1, gx + 1, GROUND, GROUND + 10, ROAD.z0 - 3, ROAD.z0 - 1, M.stoneMid)
	box("BoomPost", gx - 0.8, gx + 0.8, GROUND, GROUND + 4, ROAD.z1 - 1.5, ROAD.z1, M.metal)
	for k = 0, 7 do
		local z0 = ROAD.z1 - 1.5 - (k + 1) * 2
		box("Boom", gx - 0.3, gx + 0.3, GROUND + 3.4, GROUND + 3.9, z0, z0 + 2, (k % 2 == 0) and { Material = Enum.Material.SmoothPlastic, Color = C(170, 40, 34) } or M.whiteLine)
	end
	local bx, bz = gx - 14, ROAD.z1 + 10
	box("BoothBase", bx - 5, bx + 5, GROUND, GROUND + 0.6, bz - 4, bz + 4, M.concrete)
	box("BoothWallN", bx - 4.5, bx + 4.5, GROUND + 0.6, GROUND + 9, bz + 3.3, bz + 3.8, M.panel)
	box("BoothWallE", bx + 4, bx + 4.5, GROUND + 0.6, GROUND + 9, bz - 3.8, bz + 3.8, M.panel)
	box("BoothSill", bx - 4.5, bx + 4.5, GROUND + 0.6, GROUND + 4, bz - 3.8, bz - 3.3, M.panel)
	box("BoothWallW", bx - 4.5, bx - 4, GROUND + 0.6, GROUND + 9, bz - 3.8, bz + 3.8, M.panel)
	box("BoothGlass", bx - 4, bx + 4, GROUND + 4, GROUND + 8.4, bz - 3.7, bz - 3.4, M.lobbyGlass)
	box("BoothRoof", bx - 5.5, bx + 5.5, GROUND + 9, GROUND + 9.8, bz - 4.8, bz + 4.8, M.darkMetal)
	box("BoothTV", bx + 1, bx + 3.6, GROUND + 4.6, GROUND + 6.4, bz + 2.4, bz + 3.2, M.black) -- off (anomaly: on)
	box("BoothDesk", bx - 3.8, bx + 3.8, GROUND + 0.6, GROUND + 3.6, bz + 1.6, bz + 3.3, M.oak)
	point(Vector3.new(bx, GROUND + 7.5, bz), 0.9, 12, WARM, false)
	box("BoothLamp", bx - 1, bx + 1, GROUND + 8.7, GROUND + 8.9, bz - 1, bz + 1, M.pathNeon)
	-- invisible boundary (keeps players inside the fence, also across the gate)
	for _, w in ipairs({
		{ SITE.x0 - 1, SITE.x1 + 1, SITE.z0 - 1, SITE.z0 }, { SITE.x0 - 1, SITE.x1 + 1, SITE.z1, SITE.z1 + 1 },
		{ SITE.x0 - 1, SITE.x0, SITE.z0, SITE.z1 }, { SITE.x1, SITE.x1 + 1, SITE.z0, SITE.z1 },
	}) do
		local p = box("BoundaryWall", w[1], w[2], 0, 90, w[3], w[4], M.invisible, sub())
		p.CanQuery = false
		p.CastShadow = false
	end
end
flush()

local function pines(name, list)
	begin(name)
	SUB = nil
	for _, t in ipairs(list) do
		local x, z, h, d = t[1], t[2], t[3], t[4]
		local P = CHUNK
		vcyl("Trunk", x, z, GROUND - 0.5, h * 0.3, 1.6, M.trunk, P)
		local tiers = 5
		for i = 0, tiers - 1 do
			local f = 1 - i / tiers
			local y0 = GROUND + h * 0.12 + i * (h * 0.85 / tiers)
			vcyl("PineTier", x, z, y0, h * 0.85 / tiers * 1.25, d * f + 1, (i % 2 == 1) and M.pineDark or M.pine, P)
		end
	end
	flush()
end
do
	-- two or three staggered rows just outside the fence; a few inside at the corners
	local list = {}
	local function addRow(ax, az, bx, bz, off, outward, spacing, avoid)
		local a, b = Vector3.new(ax, 0, az), Vector3.new(bx, 0, bz)
		local len = (b - a).Magnitude
		local dir = (b - a).Unit
		for s = 0, len, spacing do
			local p = a + dir * (s + rng:NextNumber(-3, 3)) + outward * (off + rng:NextNumber(-3, 3))
			if not (avoid and avoid(p)) then
				table.insert(list, { p.X, p.Z, rng:NextNumber(34, 58), rng:NextNumber(11, 16) })
			end
		end
	end
	local road = function(p) return p.X > SITE.x1 - 2 and p.Z > ROAD.z0 - 12 and p.Z < ROAD.z1 + 12 end
	for _, row in ipairs({ { 10, 15 }, { 26, 17 } }) do
		addRow(SITE.x0 - 30, SITE.z0, SITE.x1 + 30, SITE.z0, row[1], Vector3.new(0, 0, -1), row[2])
		addRow(SITE.x0 - 30, SITE.z1, SITE.x1 + 30, SITE.z1, row[1], Vector3.new(0, 0, 1), row[2])
		addRow(SITE.x0, SITE.z0, SITE.x0, SITE.z1, row[1], Vector3.new(-1, 0, 0), row[2])
		addRow(SITE.x1, SITE.z0, SITE.x1, SITE.z1, row[1], Vector3.new(1, 0, 0), row[2], road)
	end
	-- the road leaves through the woods: line it
	for x = SITE.x1 + 10, 1460, 18 do
		table.insert(list, { x + rng:NextNumber(-3, 3), ROAD.z1 + 10 + rng:NextNumber(0, 6), rng:NextNumber(36, 56), rng:NextNumber(11, 15) })
		table.insert(list, { x + rng:NextNumber(-3, 3), ROAD.z0 - 10 - rng:NextNumber(0, 6), rng:NextNumber(36, 56), rng:NextNumber(11, 15) })
	end
	-- a few inside the fence at the empty corners
	for _, p in ipairs({ { 860, 222 }, { 845, 205 }, { 1310, 222 }, { 1312, 200 } }) do
		table.insert(list, { p[1], p[2], rng:NextNumber(30, 44), rng:NextNumber(10, 13) })
	end
	-- split into chunks of ~60 trees
	local i = 1
	local n = 0
	while i <= #list do
		n += 1
		local part = {}
		for k = i, math.min(i + 59, #list) do table.insert(part, list[k]) end
		pines("Pines" .. n, part)
		i += 60
	end
end

------------------------------------------------------------------ 9. keep-out check, then swap in the new set
local count, lights = 0, 0
local offenders = {}
for _, d in ipairs(ROOT:GetDescendants()) do
	if d:IsA("Light") then lights += 1 end
	if d:IsA("BasePart") then
		count += 1
		-- world AABB of the (possibly rotated) box against the keep-out (touching its faces is allowed)
		local cf, sz = d.CFrame, d.Size
		local ex = math.abs(cf.RightVector.X) * sz.X + math.abs(cf.UpVector.X) * sz.Y + math.abs(cf.LookVector.X) * sz.Z
		local ey = math.abs(cf.RightVector.Y) * sz.X + math.abs(cf.UpVector.Y) * sz.Y + math.abs(cf.LookVector.Y) * sz.Z
		local ez = math.abs(cf.RightVector.Z) * sz.X + math.abs(cf.UpVector.Z) * sz.Y + math.abs(cf.LookVector.Z) * sz.Z
		local q, e = cf.Position, 0.01
		if q.X + ex / 2 > KEEP.x0 + e and q.X - ex / 2 < KEEP.x1 - e and q.Z + ez / 2 > KEEP.z0 + e and q.Z - ez / 2 < KEEP.z1 - e and q.Y - ey / 2 < KEEP.yTop - e then
			table.insert(offenders, d:GetFullName())
		end
	end
end
if #offenders > 0 then
	ROOT:Destroy()
	if recording then pcall(function() CHS:FinishRecording(recording, Enum.FinishRecordingOperation.Cancel) end) end
	error(("OfficeExterior NOT built: %d part(s) inside the keep-out, the old set is untouched: %s"):format(#offenders, table.concat(offenders, ", ", 1, math.min(#offenders, 12))))
end
for _, n in ipairs({ NAME, "ClaudeExteriorSpike" }) do
	local old = workspace:FindFirstChild(n)
	if old then old:Destroy() end
end
ROOT.Name = NAME
ROOT:SetAttribute("PartCount", count)
ROOT:SetAttribute("LightCount", lights)
ROOT:SetAttribute("Source", "design/production-art/map-kits/odd-hours-b1/exterior/BuildExterior.CommandBar.luau")

if recording then pcall(function() CHS:FinishRecording(recording, Enum.FinishRecordingOperation.Commit) end) end
local msg = ("OfficeExterior built: %d parts, %d lights, 0 keep-out hits"):format(count, lights)
print(msg)
return msg
