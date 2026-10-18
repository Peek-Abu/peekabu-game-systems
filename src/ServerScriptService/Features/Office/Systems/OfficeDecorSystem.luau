--!strict
--[=[
	OfficeDecorSystem: the office at night (Cleanup Crew spec §7 "dim, buzzing fluorescents (some flickering),
	emergency-exit glow, monitors glowing blue"; ambient dread). Built once, after the graybox, into one folder: a
	glowing green EXIT sign over each doorway out of the loading bay, a monitor glowing blue on every desk, the
	elevator's doors and floor lamp in reception, and the invisible sound emitters the client's ambience plays from
	(tag OfficeAmbient, attribute AmbientKind: a phone on every desk, a typist at every other desk, the elevator).
	Props and chairs are non-colliding; table/cabinet proxies support their loot physically; the table is tagged as a
	hiding spot (Hide), and so is each tall supply cabinet (solid; a secure spot, inside it). The flickering and
	sounds are client side.

	Instance specs cover kit dressing, fallback, tabletop bounds and preserved ambiance; OfficeLayoutRules validates placement.

	@class OfficeDecorSystem
]=]

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local ArtVisualSystem = require(ServerScriptService.Features.Art.Systems.ArtVisualSystem)

local ArtTypes = require(ReplicatedStorage.Shared.Features.Art.Data.ArtTypes)

local OfficeServer = ServerScriptService.Features.Office
local OfficeDecorConstants = require(ReplicatedStorage.Shared.Features.Office.Data.OfficeDecorConstants)
local HideConstants = require(ReplicatedStorage.Shared.Features.Hide.Data.HideConstants)
local OfficeConstants = require(OfficeServer.Data.OfficeConstants)
local OfficeTypes = require(OfficeServer.Data.OfficeTypes)
local OfficeLayoutUtils = require(OfficeServer.Utils.OfficeLayoutUtils)

-- Art-only furniture that is also a hiding spot, by its art key (under a table; inside a supply cabinet).
local HIDE_KINDS: { [string]: HideConstants.FurnitureKind } = { breakTable = "table", supplyCabinet = "cabinet" }
-- Art-only furniture that stands solid (the rest are see-through props).
local SOLID: { [string]: boolean } = { filingCabinet = true, breakTable = true, supplyCabinet = true }

local function part(name: string, size: Vector3, cframe: CFrame, color: Color3, parent: Instance): Part
	local created = Instance.new("Part")
	created.Name = name
	created.Size = size
	created.CFrame = cframe
	created.Color = color
	created.Material = Enum.Material.SmoothPlastic
	created.Anchored = true
	created.CanCollide = false
	created.CanQuery = false
	created.CanTouch = false
	created.CastShadow = false
	created.Parent = parent
	return created
end

local function glow(on: BasePart, color: Color3, range: number, brightness: number)
	local point = Instance.new("PointLight")
	point.Color = color
	point.Range = range
	point.Brightness = brightness
	point.Parent = on
end

local function exitSign(at: CFrame, parent: Instance, art: ArtVisualSystem.Controller)
	local sign = part("ExitSign", OfficeDecorConstants.EXIT_SIGN_SIZE, at, OfficeDecorConstants.EXIT_COLOR, parent)
	sign.Material = Enum.Material.Neon
	art.attach(sign, "building", "exitSign")
	for _, face in { Enum.NormalId.Front, Enum.NormalId.Back } do
		local surface = Instance.new("SurfaceGui")
		surface.Face = face
		surface.LightInfluence = 0
		surface.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		surface.PixelsPerStud = 50
		local label = Instance.new("TextLabel")
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundTransparency = 1
		label.Text = "EXIT"
		label.Font = Enum.Font.Oswald
		label.TextScaled = true
		label.TextColor3 = Color3.new(1, 1, 1)
		label.Parent = surface
		surface.Parent = sign
	end
	glow(
		sign,
		OfficeDecorConstants.EXIT_COLOR,
		OfficeDecorConstants.EXIT_LIGHT_RANGE,
		OfficeDecorConstants.EXIT_LIGHT_BRIGHTNESS
	)
end

local function monitor(deskTop: CFrame, parent: Instance, art: ArtVisualSystem.Controller)
	local size = OfficeConstants.DECOR_MONITOR_SIZE
	-- Towards the desk's back edge. The monitor art carries its display face on art-local -Z
	-- (the +Z face shows rear vents), so the proxy stays unrotated and the screen faces the
	-- -Z sitter; the fallback Screen below already faces -Z the same way.
	local case =
		part("Monitor", size, deskTop * CFrame.new(0, size.Y / 2, 0.6), OfficeDecorConstants.MONITOR_CASE_COLOR, parent)
	local screen = part(
		"Screen",
		Vector3.new(size.X - 0.2, size.Y - 0.2, 0.05),
		deskTop * CFrame.new(0, size.Y / 2, 0.6 - size.Z / 2 - 0.03),
		OfficeDecorConstants.MONITOR_COLOR,
		parent
	)
	screen.Material = Enum.Material.Neon
	if art.attach(case, "cargo", "monitor") ~= nil then
		screen.Transparency = 1
	end
	glow(
		screen,
		OfficeDecorConstants.MONITOR_COLOR,
		OfficeDecorConstants.MONITOR_LIGHT_RANGE,
		OfficeDecorConstants.MONITOR_LIGHT_BRIGHTNESS
	)
end

local function emitter(kind: OfficeDecorConstants.AmbientKind, position: Vector3, parent: Instance)
	local spot = part(`Ambient ({kind})`, Vector3.new(1, 1, 1), CFrame.new(position), Color3.new(0, 0, 0), parent)
	spot.Transparency = 1
	spot:SetAttribute(OfficeDecorConstants.AMBIENT_KIND_ATTRIBUTE, kind)
	CollectionService:AddTag(spot, OfficeDecorConstants.AMBIENT_TAG)
end

local function elevator(origin: CFrame, parent: Instance, art: ArtVisualSystem.Controller)
	local point = OfficeDecorConstants.ELEVATOR_POINT
	local door = OfficeDecorConstants.ELEVATOR_DOOR_SIZE
	local front = part(
		"ElevatorFront",
		OfficeConstants.ELEVATOR_FRONT_SIZE,
		origin * CFrame.new(point) * CFrame.Angles(0, math.pi / 2, 0),
		OfficeDecorConstants.ELEVATOR_COLOR,
		parent
	)
	local visual = art.attach(front, "furniture", "elevatorFront")
	front.Transparency = 1
	for _, side in { -1, 1 } do
		local panel = part(
			"ElevatorDoor",
			door,
			origin * CFrame.new(point.X, point.Y, point.Z + side * door.Z / 2),
			OfficeDecorConstants.ELEVATOR_COLOR,
			parent
		)
		panel.Material = Enum.Material.Metal
		if visual ~= nil then
			panel.Transparency = 1
		end
	end
	local lamp = part(
		"ElevatorLamp",
		OfficeDecorConstants.ELEVATOR_LAMP_SIZE,
		origin * CFrame.new(point.X, point.Y + door.Y / 2 + 0.6, point.Z),
		OfficeDecorConstants.ELEVATOR_LAMP_COLOR,
		parent
	)
	lamp.Material = Enum.Material.Neon
	emitter("elevator", (origin * CFrame.new(point.X + 1, point.Y, point.Z)).Position, parent)
end

-- Optional additions have no graybox fallback: only approved art creates visible dressing.
local function artOnly(
	key: string,
	family: ArtTypes.Family,
	size: Vector3,
	floor: CFrame,
	deskId: string,
	parent: Instance,
	art: ArtVisualSystem.Controller
)
	local root = part(key, size, floor * CFrame.new(0, size.Y / 2, 0), OfficeConstants.DESK_COLOR, parent)
	root.Transparency = 1
	root.CanCollide = SOLID[key] == true
	root.CanQuery = root.CanCollide
	root:SetAttribute("OfficeArtKey", key)
	root:SetAttribute("OfficeDeskMarker", deskId)
	if art.attach(root, family, key) == nil then
		root:Destroy()
		return
	end
	if key == "officeChair" then
		CollectionService:AddTag(root, OfficeDecorConstants.CHAIR_TAG)
	end
	-- The table is a hiding spot (Hide): under it; the supply cabinet too: inside it.
	local hideKind = HIDE_KINDS[key]
	if hideKind ~= nil then
		root:SetAttribute(HideConstants.FURNITURE_KIND_ATTRIBUTE, hideKind)
		CollectionService:AddTag(root, HideConstants.FURNITURE_TAG)
	end
end

local function dressDesk(
	desk: OfficeTypes.Marker,
	index: number,
	origin: CFrame,
	parent: Instance,
	art: ArtVisualSystem.Controller
)
	local top = origin
		* CFrame.new(desk.x, OfficeConstants.DESK_SIZE.Y, desk.z)
		* CFrame.Angles(0, desk.rotation or 0, 0)
	local function prop(key: string, x: number, z: number)
		local size = OfficeConstants.DESK_PROP_SIZES[key]
		artOnly(
			key,
			"props",
			size,
			top * CFrame.new(x, 0, z) * CFrame.Angles(0, if key == "paperTray" then 0 else math.pi, 0),
			desk.id,
			parent,
			art
		)
	end
	-- Two side work areas leave the central monitor and keyboard legible. Variants rotate larger paper props.
	prop("mug", -2.08, -1.12)
	prop("stationeryCup", 1.95, -1.12)
	if index % 2 == 1 then
		prop("folder", -1.85, 0.65)
		prop("paperTray", 1.85, 0.65)
	else
		prop("paperStack", -1.85, 0.65)
		prop("bookStack", 1.85, 0.65)
	end
end

local function chairAt(layout: OfficeTypes.Layout, desk: OfficeTypes.Marker, origin: CFrame): CFrame?
	local room = OfficeLayoutUtils.room(layout, desk.room)
	local candidates = {
		-- officeChair art seats toward its CFrame LookVector: at turn 0 the backrest sits on the
		-- +Z side (live Studio screenshot 2026-10-13), so each side needs the half-turn more than
		-- the naive orientation to face the sitter toward the desk.
		{ x = 0, z = -3.05, turn = math.pi },
		{ x = 0, z = 3.05, turn = 0 },
		{ x = -4.05, z = 0, turn = -math.pi / 2 },
		{ x = 4.05, z = 0, turn = math.pi / 2 },
	}
	local sizes: { [string]: Vector3? } = {
		desk = OfficeConstants.DESK_SIZE,
		locker = OfficeConstants.LOCKER_SIZE,
		shelf = OfficeConstants.SHELF_SIZE,
		counter = OfficeConstants.COUNTER_SIZE,
		table = OfficeConstants.TABLE_SIZE,
		cabinet = OfficeConstants.CABINET_SIZE,
		closet = OfficeConstants.CLOSET_SIZE,
	}
	for _, candidate in candidates do
		local offset = CFrame.Angles(0, desk.rotation or 0, 0)
			:VectorToWorldSpace(Vector3.new(candidate.x, 0, candidate.z))
		local x, z = desk.x + offset.X, desk.z + offset.Z
		local half = 1.14
		local clear = room == nil
			or (
				x - half > room.minX + 0.2
				and x + half < room.maxX - 0.2
				and z - half > room.minZ + 0.2
				and z + half < room.maxZ - 0.2
			)
		if clear then
			for _, other in layout.markers do
				local size = sizes[other.kind]
				if other.id ~= desk.id and size ~= nil then
					if
						math.abs(x - other.x)
							< half + (if math.abs(math.sin(other.rotation or 0)) > 0.5 then size.Z else size.X) / 2
						and math.abs(z - other.z)
							< half + (if math.abs(math.sin(other.rotation or 0)) > 0.5 then size.X else size.Z) / 2
					then
						clear = false
						break
					end
				end
			end
		end
		if clear then
			for _, door in layout.doors do
				if door.a == desk.room or door.b == desk.room then
					-- Keep a walkable approach around every doorway, including a four-exit room.
					if
						math.abs(x - door.x) < door.width / 2 + half
						and math.abs(z - door.z) < door.width / 2 + half
					then
						clear = false
						break
					end
				end
			end
		end
		if clear then
			return origin * CFrame.new(x, 0, z) * CFrame.Angles(0, candidate.turn + (desk.rotation or 0), 0)
		end
	end
	-- A future tightly packed layout may have no clear candidate; omit art rather than clip through a wall.
	return nil
end

local OfficeDecorSystem = {}

--[=[
	Builds the night decor for `layout` at `origin` into one folder under `parent`, and returns it.
]=]
function OfficeDecorSystem.build(
	layout: OfficeTypes.Layout,
	origin: CFrame,
	parent: Instance,
	visuals: ArtVisualSystem.Controller?
): Folder
	local art = visuals or ArtVisualSystem
	local folder = Instance.new("Folder")
	folder.Name = OfficeDecorConstants.DECOR_FOLDER
	-- Parent before attachments so kit selection follows this map ancestry.
	folder.Parent = parent
	local start = OfficeLayoutUtils.room(layout, layout.startRoom)
	if start ~= nil then
		for _, door in layout.doors do
			if door.a == layout.startRoom or door.b == layout.startRoom then
				local edge = OfficeLayoutUtils.doorEdge(start, door)
				local turn = if edge == "minX" or edge == "maxX"
					then CFrame.Angles(0, math.rad(90), 0)
					else CFrame.identity
				exitSign(origin * CFrame.new(door.x, OfficeDecorConstants.EXIT_SIGN_HEIGHT, door.z) * turn, folder, art)
			end
		end
	end
	local lift = OfficeDecorConstants.EMITTER_LIFT
	for index, desk in OfficeLayoutUtils.markersOf(layout, "desk") do
		local deskTop = origin
			* CFrame.new(desk.x, OfficeConstants.DESK_SIZE.Y, desk.z)
			* CFrame.Angles(0, desk.rotation or 0, 0)
		local furniture = parent:FindFirstChild("Furniture")
		if furniture ~= nil then
			for _, proxy in furniture:GetChildren() do
				if proxy:GetAttribute("OfficeMarkerId") == desk.id then
					-- Replace the earlier desktop monitor once; retain keyboard/mouse dressing.
					for _, name in { "Monitor", "MonitorScreen", "MonitorBase", "MonitorNeck" } do
						local old = proxy:FindFirstChild(name)
						if old ~= nil then
							old:Destroy()
						end
					end
					local keyboard = proxy:FindFirstChild("Keyboard")
					if keyboard ~= nil and keyboard:IsA("BasePart") then
						local oldSize, oldFrame = keyboard.Size, keyboard.CFrame
						keyboard.Size = OfficeConstants.DECOR_KEYBOARD_SIZE
						keyboard.CFrame = deskTop
							* CFrame.new(-0.45, keyboard.Size.Y / 2, -0.6)
							* CFrame.Angles(0, math.pi, 0)
						if art.attach(keyboard, "props", "keyboard") ~= nil then
							for _, child in proxy:GetChildren() do
								if child.Name == "Keycap" or child.Name == "SpaceBar" then
									child:Destroy()
								end
							end
						else
							keyboard.Size, keyboard.CFrame = oldSize, oldFrame
						end
					end
					local mouse = proxy:FindFirstChild("Mouse")
					if mouse ~= nil and mouse:IsA("BasePart") then
						local oldSize, oldFrame = mouse.Size, mouse.CFrame
						mouse.Size = OfficeConstants.DECOR_MOUSE_SIZE
						mouse.CFrame = deskTop
							* CFrame.new(1.05, mouse.Size.Y / 2, -0.65)
							* CFrame.Angles(0, math.pi, 0)
						if art.attach(mouse, "props", "mouse") == nil then
							mouse.Size, mouse.CFrame = oldSize, oldFrame
						end
					end
				end
			end
		end
		monitor(deskTop, folder, art)
		dressDesk(desk, index, origin, folder, art)
		local chairFloor = chairAt(layout, desk, origin)
		if chairFloor ~= nil then
			artOnly("officeChair", "furniture", OfficeConstants.OFFICE_CHAIR_SIZE, chairFloor, desk.id, folder, art)
		end
		emitter("phone", (deskTop * CFrame.new(1.5, lift, 0)).Position, folder)
		if index % OfficeDecorConstants.TYPING_EVERY == 1 then
			emitter("typing", (deskTop * CFrame.new(-1, lift, 0)).Position, folder)
		end
	end
	-- Sparse art-only furniture: corner filing cabinets and meeting/break tables with lootable
	-- tops. No graybox fallback: a missing kit leaves the room as it was (see `artOnly`).
	for _, marker in OfficeLayoutUtils.markersOf(layout, "cabinet") do
		artOnly(
			"filingCabinet",
			"cargo",
			OfficeConstants.CABINET_SIZE,
			origin * CFrame.new(marker.x, 0, marker.z) * CFrame.Angles(0, marker.rotation or 0, 0),
			marker.id,
			folder,
			art
		)
	end
	-- The tall supply cabinets: solid, and a secure hiding spot (Hide). No art, no cabinet (`artOnly`).
	for _, marker in OfficeLayoutUtils.markersOf(layout, "closet") do
		artOnly(
			"supplyCabinet",
			"furniture",
			OfficeConstants.CLOSET_SIZE,
			origin * CFrame.new(marker.x, 0, marker.z) * CFrame.Angles(0, marker.rotation or 0, 0),
			marker.id,
			folder,
			art
		)
	end
	for _, marker in OfficeLayoutUtils.markersOf(layout, "table") do
		artOnly(
			"breakTable",
			"furniture",
			OfficeConstants.TABLE_SIZE,
			origin * CFrame.new(marker.x, 0, marker.z) * CFrame.Angles(0, marker.rotation or 0, 0),
			marker.id,
			folder,
			art
		)
	end
	elevator(origin, folder, art)
	folder.Parent = parent
	return folder
end

return OfficeDecorSystem
