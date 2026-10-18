--!strict
--[=[
	OfficeDecorSystem: the office at night (Cleanup Crew spec §7 "dim, buzzing fluorescents (some flickering),
	emergency-exit glow, monitors glowing blue"; ambient dread). Built once, after the graybox, into one folder: a
	glowing green EXIT sign over each doorway out of the loading bay, a monitor glowing blue on every desk, the
	elevator's doors and floor lamp in reception, and the invisible sound emitters the client's ambience plays from
	(tag OfficeAmbient, attribute AmbientKind: a phone on every desk, a typist at every other desk, the elevator).
	Non-colliding, non-queryable, so nothing here blocks a path, a ray or a floor probe. The flickering and the
	sounds are client side.

	Spec-exempt shell (Instances); placement comes from the layout the specced OfficeLayoutRules validated.

	@class OfficeDecorSystem
]=]

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local OfficeServer = ServerScriptService.Features.Office
local OfficeDecorConstants = require(ReplicatedStorage.Shared.Features.Office.Data.OfficeDecorConstants)
local OfficeConstants = require(OfficeServer.Data.OfficeConstants)
local OfficeTypes = require(OfficeServer.Data.OfficeTypes)
local OfficeLayoutUtils = require(OfficeServer.Utils.OfficeLayoutUtils)

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

local function exitSign(at: CFrame, parent: Instance)
	local sign = part("ExitSign", OfficeDecorConstants.EXIT_SIGN_SIZE, at, OfficeDecorConstants.EXIT_COLOR, parent)
	sign.Material = Enum.Material.Neon
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

local function monitor(deskTop: CFrame, parent: Instance)
	local size = OfficeDecorConstants.MONITOR_SIZE
	-- Towards the desk's back edge, facing -Z (where a sitter would be).
	local case =
		part("Monitor", size, deskTop * CFrame.new(0, size.Y / 2, 0.6), OfficeDecorConstants.MONITOR_CASE_COLOR, parent)
	local screen = part(
		"Screen",
		Vector3.new(size.X - 0.2, size.Y - 0.2, 0.05),
		case.CFrame * CFrame.new(0, 0, -size.Z / 2 - 0.03),
		OfficeDecorConstants.MONITOR_COLOR,
		parent
	)
	screen.Material = Enum.Material.Neon
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

local function elevator(origin: CFrame, parent: Instance)
	local point = OfficeDecorConstants.ELEVATOR_POINT
	local door = OfficeDecorConstants.ELEVATOR_DOOR_SIZE
	for _, side in { -1, 1 } do
		local panel = part(
			"ElevatorDoor",
			door,
			origin * CFrame.new(point.X, point.Y, point.Z + side * door.Z / 2),
			OfficeDecorConstants.ELEVATOR_COLOR,
			parent
		)
		panel.Material = Enum.Material.Metal
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

local OfficeDecorSystem = {}

--[=[
	Builds the night decor for `layout` at `origin` into one folder under `parent`, and returns it.
]=]
function OfficeDecorSystem.build(layout: OfficeTypes.Layout, origin: CFrame, parent: Instance): Folder
	local folder = Instance.new("Folder")
	folder.Name = OfficeDecorConstants.DECOR_FOLDER
	local start = OfficeLayoutUtils.room(layout, layout.startRoom)
	if start ~= nil then
		for _, door in layout.doors do
			if door.a == layout.startRoom or door.b == layout.startRoom then
				local edge = OfficeLayoutUtils.doorEdge(start, door)
				local turn = if edge == "minX" or edge == "maxX"
					then CFrame.Angles(0, math.rad(90), 0)
					else CFrame.identity
				exitSign(origin * CFrame.new(door.x, OfficeDecorConstants.EXIT_SIGN_HEIGHT, door.z) * turn, folder)
			end
		end
	end
	local lift = OfficeDecorConstants.EMITTER_LIFT
	for index, desk in OfficeLayoutUtils.markersOf(layout, "desk") do
		local deskTop = origin * CFrame.new(desk.x, OfficeConstants.DESK_SIZE.Y, desk.z)
		monitor(deskTop, folder)
		emitter("phone", (deskTop * CFrame.new(1.5, lift, 0)).Position, folder)
		if index % OfficeDecorConstants.TYPING_EVERY == 1 then
			emitter("typing", (deskTop * CFrame.new(-1, lift, 0)).Position, folder)
		end
	end
	elevator(origin, folder)
	folder.Parent = parent
	return folder
end

return OfficeDecorSystem
