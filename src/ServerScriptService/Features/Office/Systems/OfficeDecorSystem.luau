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
	Art keys: each piece tries its marker's `art` key, then the default key's room-type variant, then the default key
	(OfficeArtKeyUtils), so a `table` marker with art "conferenceTable" gets that template and keeps the table's hiding
	and collision. `prop` markers are art-only dressing (sofa, vending machine, wall frame...): a transparent proxy sized
	OfficeConstants.PROP_SIZES[art], solid when over a stud tall, destroyed when no template resolves; the wall-mounted
	ones (PROP_WALL_HEIGHT) hang at that height, non-colliding. Every Attachment of an attached prop or art-only piece
	named in OfficeConstants.ACCENT_LIGHTS (a floor lamp's LampLight) gets that accent's point light
	(OfficeLightingUtils.accentFor).

	The EXIT sign, monitor, ambient emitter and elevator front are built by OfficeDecorFixtureSystem, and a desk's chair
	spot by OfficeChairUtils (both split out of this file).

	Instance specs cover kit dressing, fallback, tabletop bounds and preserved ambiance; OfficeLayoutRules validates placement.

	@class OfficeDecorSystem
]=]

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local ArtVisualSystem = require(ServerScriptService.Features.Art.Systems.ArtVisualSystem)

local ArtTypes = require(ReplicatedStorage.Shared.Features.Art.Data.ArtTypes)
local CameraOccluderConstants = require(ReplicatedStorage.Shared.Features.Camera.Data.CameraOccluderConstants)

local OfficeServer = ServerScriptService.Features.Office
local OfficeDecorConstants = require(ReplicatedStorage.Shared.Features.Office.Data.OfficeDecorConstants)
local HideConstants = require(ReplicatedStorage.Shared.Features.Hide.Data.HideConstants)
local OccupantConstants = require(ReplicatedStorage.Shared.Features.Occupant.Data.OccupantConstants)
local OfficeConstants = require(OfficeServer.Data.OfficeConstants)
local OfficeTypes = require(OfficeServer.Data.OfficeTypes)
local OfficeLayoutUtils = require(OfficeServer.Utils.OfficeLayoutUtils)
local OfficeDoorUtils = require(OfficeServer.Utils.OfficeDoorUtils)
local OfficeSurfaceUtils = require(OfficeServer.Utils.OfficeSurfaceUtils)
local OfficeArtKeyUtils = require(OfficeServer.Utils.OfficeArtKeyUtils)
local OfficeLightingUtils = require(OfficeServer.Utils.OfficeLightingUtils)
local OfficeVariationRules = require(OfficeServer.Rules.OfficeVariationRules)
local OfficeKitRules = require(OfficeServer.Rules.OfficeKitRules)
local OfficeBuildPaceTracker = require(OfficeServer.State.OfficeBuildPaceTracker)
local OfficeChairUtils = require(OfficeServer.Utils.OfficeChairUtils)
local OfficeDecorFixtureSystem = require(OfficeServer.Systems.OfficeDecorFixtureSystem)

-- Desk dressing was laid out on a 5x3 top; its spots move with the real top (the props keep their size).
local DESK_SPREAD = OfficeDecorFixtureSystem.DESK_SPREAD
local part = OfficeDecorFixtureSystem.part
local exitSign = OfficeDecorFixtureSystem.exitSign
local monitor = OfficeDecorFixtureSystem.monitor
local emitter = OfficeDecorFixtureSystem.emitter
local elevator = OfficeDecorFixtureSystem.elevator

-- A solid floor prop shorter than this never counts as a camera occluder.
local LOW_PROP_HEIGHT = 3

-- Art-only furniture that stands solid (the rest are see-through props).
local SOLID: { [string]: boolean } = { filingCabinet = true, breakTable = true, supplyCabinet = true }

-- Templates may not carry lights (ArtKitRules): an accent part holds an Attachment named in ACCENT_LIGHTS for the code
-- to hang that accent's shadowless glow on.
local function accentLights(visual: Instance)
	for _, descendant in visual:GetDescendants() do
		local accent = if descendant:IsA("Attachment") then OfficeLightingUtils.accentFor(descendant.Name) else nil
		if accent ~= nil then
			local light = Instance.new("PointLight")
			light.Color = accent.color
			light.Range = accent.range
			light.Brightness = accent.brightness
			light.Shadows = false
			light.Parent = descendant
		end
	end
end

-- Optional additions have no graybox fallback: only approved art creates visible dressing. `key` is the piece's
-- default art key (it also decides collision); `override` and `roomType` pick other templates first. `hideKind` is
-- the Hide furniture kind its marker's kind makes it (the caller decides), kept only when a hider fits.
local function artOnly(
	key: string,
	family: ArtTypes.Family,
	size: Vector3,
	floor: CFrame,
	deskId: string,
	parent: Instance,
	art: ArtVisualSystem.Controller,
	override: string?,
	roomType: string?,
	hideKind: HideConstants.FurnitureKind?
)
	local root = part(key, size, floor * CFrame.new(0, size.Y / 2, 0), OfficeConstants.DESK_COLOR, parent)
	root.Transparency = 1
	root.CanCollide = SOLID[key] == true
	root.CanQuery = root.CanCollide
	root:SetAttribute("OfficeDeskMarker", deskId)
	local visual, attached =
		OfficeArtKeyUtils.attachFirst(art, root, family, OfficeArtKeyUtils.candidates(key, override, roomType))
	if visual == nil or attached == nil then
		root:Destroy()
		return
	end
	-- The key that actually attached (a restyled table records its own art key, not the default).
	root:SetAttribute("OfficeArtKey", attached)
	accentLights(visual)
	if key == "officeChair" then
		CollectionService:AddTag(root, OfficeDecorConstants.CHAIR_TAG)
	end
	-- Furniture hides only when the hider fits in the free space under it (a low coffee table does not; a taller table
	-- art would make the break table a hiding spot again).
	if hideKind ~= nil and OfficeSurfaceUtils.canHideUnder(hideKind, size) then
		root:SetAttribute(HideConstants.FURNITURE_KIND_ATTRIBUTE, hideKind)
		CollectionService:AddTag(root, HideConstants.FURNITURE_TAG)
	end
end

-- How far above the proxy's top the perch point sits, so a camera ray to it never ends inside the prop's top face.
local PERCH_LIFT = 0.5

--[=[
	Tags a perch point on top of `proxy` (B4, OfficeKitRules.isPerch): an invisible, anchored, non-colliding,
	non-queried part PERCH_LIFT over the centre of its top face, tagged OccupantConstants.PERCH_TAG
	(OccupantWatchSystem.perches reads it). A child of the proxy, so it goes with it. OfficeBuildSystem tags its lockers
	and shelves through OfficeDecorSystem.perchOn.
]=]
local function perchOn(proxy: BasePart)
	local perch = Instance.new("Part")
	perch.Name = "Perch"
	perch.Size = Vector3.one
	perch.Transparency = 1
	perch.Anchored = true
	perch.CanCollide = false
	perch.CanQuery = false
	perch.CanTouch = false
	perch.CastShadow = false
	perch.CFrame = proxy.CFrame * CFrame.new(0, proxy.Size.Y / 2 + PERCH_LIFT, 0)
	CollectionService:AddTag(perch, OccupantConstants.PERCH_TAG)
	perch.Parent = proxy
end

-- An art-only dressing prop: a `prop` marker names its template (`art`) and is sized by PROP_SIZES.
local function propAt(
	marker: OfficeTypes.Marker,
	roomType: string?,
	origin: CFrame,
	parent: Instance,
	art: ArtVisualSystem.Controller
)
	local key = marker.art
	if key == nil then
		error(`prop marker "{marker.id}" has no art key`)
	end
	-- Optional on purpose: the map may lack this key (a Vector3 index result cannot be compared with nil).
	local size: Vector3? = OfficeConstants.PROP_SIZES[key]
	if size == nil then
		error(`prop marker "{marker.id}" names art "{key}" with no PROP_SIZES entry`)
	end
	local wallHeight = OfficeConstants.PROP_WALL_HEIGHT[key]
	local onDesk = OfficeConstants.PROP_DESK_TOP[key] == true
	local frame = origin * CFrame.new(marker.x, 0, marker.z) * CFrame.Angles(0, marker.rotation or 0, 0)
	if onDesk then
		-- A desk-top prop: the marker is its desk's centre; it stands on the desktop at DESK_PLANT_OFFSET.
		frame = frame * CFrame.new(OfficeConstants.DESK_PLANT_OFFSET + Vector3.new(0, OfficeConstants.DESK_SIZE.Y, 0))
	end
	local root = part(
		key,
		size,
		frame * CFrame.new(0, if wallHeight ~= nil then wallHeight else size.Y / 2, 0),
		OfficeConstants.DESK_COLOR,
		parent
	)
	root.Transparency = 1
	-- Wall hangings are out of reach and never block: only floor props over a stud tall are solid.
	root.CanCollide = wallHeight == nil and not onDesk and size.Y > 1
	root.CanQuery = root.CanCollide
	root:SetAttribute("OfficeMarkerId", marker.id)
	if wallHeight ~= nil then
		root:SetAttribute("ArtWallMounted", true)
	end
	if OfficeKitRules.isPerch(marker) then
		perchOn(root)
	end
	local visual, attached =
		OfficeArtKeyUtils.attachFirst(art, root, "furniture", OfficeArtKeyUtils.candidates(key, nil, roomType))
	if visual == nil or attached == nil then
		root:Destroy()
		return
	end
	root:SetAttribute("OfficeArtKey", attached)
	accentLights(visual)
	-- A low floor prop (a bin) is no camera occluder: the camera would stop short of it instead of clearing it.
	if root.CanCollide and size.Y < LOW_PROP_HEIGHT then
		root:SetAttribute(CameraOccluderConstants.ATTRIBUTE, nil)
	end
end

local function dressDesk(
	desk: OfficeTypes.Marker,
	items: { string },
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
	-- Two side work areas leave the central monitor and keyboard legible. Each item keeps its own slot.
	local slots: { [string]: { number } } = {
		mug = { -2.08, -1.12 },
		stationeryCup = { 1.95, -1.12 },
		folder = { -1.85, 0.65 },
		paperStack = { -1.85, 0.65 },
		paperTray = { 1.85, 0.65 },
		bookStack = { 1.85, 0.65 },
	}
	for _, key in items do
		local slot = slots[key]
		if slot ~= nil then
			prop(key, slot[1] * DESK_SPREAD.X, slot[2] * DESK_SPREAD.Z)
		end
	end
end

local OfficeDecorSystem = {}

-- The perch point on top of a perch proxy (see the local `perchOn`), for OfficeBuildSystem's lockers and shelves.
OfficeDecorSystem.perchOn = perchOn

--[=[
	Builds one lit EXIT sign (the kit's `exitSign` art for `roomType`, a neon fallback reading EXIT on both faces, and
	its glow) at `at` under `parent`, and returns it. The decor hangs one over each start-room door; OfficeGroundsSystem
	hangs one over each entrance's inside exit.
]=]
OfficeDecorSystem.exitSign = exitSign

--[=[
	Builds the night decor for `layout` at `origin` into one folder under `parent`, and returns it. A `seed` varies
	which dressing props stay and each desk's clutter; nil is the authored layout.
]=]
function OfficeDecorSystem.build(
	layout: OfficeTypes.Layout,
	origin: CFrame,
	parent: Instance,
	visuals: ArtVisualSystem.Controller?,
	seed: number?
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
				exitSign(
					origin * CFrame.new(door.x, OfficeDecorConstants.EXIT_SIGN_HEIGHT, door.z) * turn,
					folder,
					art,
					OfficeArtKeyUtils.roomType(start)
				)
			end
		end
	end
	local lift = OfficeDecorConstants.EMITTER_LIFT
	for index, desk in OfficeLayoutUtils.markersOf(layout, "desk") do
		-- Only a plain office desk gets office dressing; a desk restyled by its art (the School's lunch table,
		-- project table, cot) is dressed by its own art.
		if desk.art ~= nil then
			continue
		end
		local deskTop = origin
			* CFrame.new(desk.x, OfficeConstants.DESK_SIZE.Y, desk.z)
			* CFrame.Angles(0, desk.rotation or 0, 0)
		local deskRoomType = OfficeArtKeyUtils.roomType(OfficeLayoutUtils.room(layout, desk.room))
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
							* CFrame.new(-0.45 * DESK_SPREAD.X, keyboard.Size.Y / 2, -0.6 * DESK_SPREAD.Z)
							* CFrame.Angles(0, math.pi, 0)
						if
							OfficeArtKeyUtils.attachFirst(
								art,
								keyboard,
								"props",
								OfficeArtKeyUtils.candidates("keyboard", nil, deskRoomType)
							) ~= nil
						then
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
							* CFrame.new(1.05 * DESK_SPREAD.X, mouse.Size.Y / 2, -0.65 * DESK_SPREAD.Z)
							* CFrame.Angles(0, math.pi, 0)
						if
							OfficeArtKeyUtils.attachFirst(
								art,
								mouse,
								"props",
								OfficeArtKeyUtils.candidates("mouse", nil, deskRoomType)
							) == nil
						then
							mouse.Size, mouse.CFrame = oldSize, oldFrame
						end
					end
				end
			end
		end
		monitor(deskTop, folder, art, deskRoomType)
		-- A nil seed keeps the authored boot dressing (global desk parity); a seed varies it per desk.
		local items = if seed == nil
			then (if index % 2 == 1
				then { "mug", "stationeryCup", "folder", "paperTray" }
				else { "mug", "stationeryCup", "paperStack", "bookStack" })
			else OfficeVariationRules.deskClutter(seed, desk.id)
		dressDesk(desk, items, origin, folder, art)
		local chairFloor = OfficeChairUtils.chairAt(layout, desk, origin)
		if chairFloor ~= nil then
			artOnly(
				"officeChair",
				"furniture",
				OfficeConstants.OFFICE_CHAIR_SIZE,
				chairFloor,
				desk.id,
				folder,
				art,
				nil,
				deskRoomType
			)
		end
		emitter("phone", (deskTop * CFrame.new(1.5 * DESK_SPREAD.X, lift, 0)).Position, folder)
		if index % OfficeDecorConstants.TYPING_EVERY == 1 then
			emitter("typing", (deskTop * CFrame.new(-1 * DESK_SPREAD.X, lift, 0)).Position, folder)
		end
		OfficeBuildPaceTracker.step()
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
			art,
			marker.art,
			OfficeArtKeyUtils.roomType(OfficeLayoutUtils.room(layout, marker.room))
		)
		OfficeBuildPaceTracker.step()
	end
	-- The tall supply cabinets: solid, and a secure hiding spot (Hide): inside it. Every closet marker hides, whatever
	-- art restyles it (a School stall or equipment closet), so OfficeLayoutRules.checkHideSpots counts what players can
	-- really hide in. No art, no cabinet (`artOnly`).
	for _, marker in OfficeLayoutUtils.markersOf(layout, "closet") do
		artOnly(
			"supplyCabinet",
			"furniture",
			OfficeLayoutUtils.markerSize(marker) or OfficeConstants.CLOSET_SIZE,
			origin * CFrame.new(marker.x, 0, marker.z) * CFrame.Angles(0, marker.rotation or 0, 0),
			marker.id,
			folder,
			art,
			marker.art,
			OfficeArtKeyUtils.roomType(OfficeLayoutUtils.room(layout, marker.room)),
			"cabinet"
		)
		OfficeBuildPaceTracker.step()
	end
	-- A table is a hiding spot (Hide): under it, but only with the default art: a restyled table (the conference
	-- table) has no measured hug space under it. The break table's own proxy leaves no room either (canHideUnder).
	for _, marker in OfficeLayoutUtils.markersOf(layout, "table") do
		local restyled = marker.art ~= nil and marker.art ~= "breakTable"
		artOnly(
			"breakTable",
			"furniture",
			OfficeLayoutUtils.markerSize(marker) or OfficeConstants.TABLE_SIZE,
			origin * CFrame.new(marker.x, 0, marker.z) * CFrame.Angles(0, marker.rotation or 0, 0),
			marker.id,
			folder,
			art,
			marker.art,
			OfficeArtKeyUtils.roomType(OfficeLayoutUtils.room(layout, marker.room)),
			if restyled then nil else "table"
		)
		OfficeBuildPaceTracker.step()
	end
	for _, marker in OfficeLayoutUtils.markersOf(layout, "prop") do
		if OfficeVariationRules.keepProp(seed, marker.id, marker.art or "") then
			propAt(marker, OfficeArtKeyUtils.roomType(OfficeLayoutUtils.room(layout, marker.room)), origin, folder, art)
		end
		OfficeBuildPaceTracker.step()
	end
	-- On the layout's elevator facade; the authored boot layout keeps ELEVATOR_POINT; a generated map with no
	-- elevator facade (the School) has none.
	local elevatorFrame = OfficeDoorUtils.elevatorFrameFor(layout, origin)
	if elevatorFrame ~= nil then
		elevator(elevatorFrame, folder, art)
	end
	folder.Parent = parent
	return folder
end

return OfficeDecorSystem
