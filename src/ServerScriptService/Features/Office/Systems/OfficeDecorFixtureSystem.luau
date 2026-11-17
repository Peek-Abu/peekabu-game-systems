--!strict
--[=[
	OfficeDecorFixtureSystem: the fixed night-decor fixtures OfficeDecorSystem builds, split out of it: the lit EXIT sign,
	the glowing desk monitor, the invisible ambient sound emitter and the elevator front, with their `part` and `glow`
	helpers and the DESK_SPREAD the desk dressing scales by. Each builds Instances under the parent it is given and tries
	the kit's art first (OfficeArtKeyUtils), keeping a graybox fallback.

	@class OfficeDecorFixtureSystem
]=]

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local ArtVisualSystem = require(ServerScriptService.Features.Art.Systems.ArtVisualSystem)

local OfficeServer = ServerScriptService.Features.Office
local OfficeDecorConstants = require(ReplicatedStorage.Shared.Features.Office.Data.OfficeDecorConstants)
local OfficeConstants = require(OfficeServer.Data.OfficeConstants)
local OfficeArtKeyUtils = require(OfficeServer.Utils.OfficeArtKeyUtils)

-- Desk dressing was laid out on a 5x3 top; its spots move with the real top (the props keep their size).
local DESK_SPREAD = OfficeConstants.DESK_SIZE / Vector3.new(5, 3, 3)

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

local function exitSign(at: CFrame, parent: Instance, art: ArtVisualSystem.Controller, roomType: string?): Part
	local sign = part("ExitSign", OfficeDecorConstants.EXIT_SIGN_SIZE, at, OfficeDecorConstants.EXIT_COLOR, parent)
	sign.Material = Enum.Material.Neon
	OfficeArtKeyUtils.attachFirst(art, sign, "building", OfficeArtKeyUtils.candidates("exitSign", nil, roomType))
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
	return sign
end

local function monitor(deskTop: CFrame, parent: Instance, art: ArtVisualSystem.Controller, roomType: string?)
	local size = OfficeConstants.DECOR_MONITOR_SIZE
	-- Towards the desk's back edge. The monitor art carries its display face on art-local -Z
	-- (the +Z face shows rear vents), so the proxy stays unrotated and the screen faces the
	-- -Z sitter; the fallback Screen below already faces -Z the same way.
	local case = part(
		"Monitor",
		size,
		deskTop * CFrame.new(0, size.Y / 2, 0.6 * DESK_SPREAD.Z),
		OfficeDecorConstants.MONITOR_CASE_COLOR,
		parent
	)
	local screen = part(
		"Screen",
		Vector3.new(size.X - 0.2, size.Y - 0.2, 0.05),
		deskTop * CFrame.new(0, size.Y / 2, 0.6 * DESK_SPREAD.Z - size.Z / 2 - 0.03),
		OfficeDecorConstants.MONITOR_COLOR,
		parent
	)
	screen.Material = Enum.Material.Neon
	if
		OfficeArtKeyUtils.attachFirst(art, case, "cargo", OfficeArtKeyUtils.candidates("monitor", nil, roomType))
		~= nil
	then
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

-- The elevator front on `frame`: local +Z points into the room, X runs along the wall.
local function elevator(frame: CFrame, parent: Instance, art: ArtVisualSystem.Controller)
	local door = OfficeDecorConstants.ELEVATOR_DOOR_SIZE
	local front =
		part("ElevatorFront", OfficeConstants.ELEVATOR_FRONT_SIZE, frame, OfficeDecorConstants.ELEVATOR_COLOR, parent)
	local visual =
		OfficeArtKeyUtils.attachFirst(art, front, "furniture", OfficeArtKeyUtils.candidates("elevatorFront", nil, nil))
	front.Transparency = 1
	for _, side in { -1, 1 } do
		local panel = part(
			"ElevatorDoor",
			Vector3.new(door.Z, door.Y, door.X),
			frame * CFrame.new(side * door.Z / 2, 0, 0),
			OfficeDecorConstants.ELEVATOR_COLOR,
			parent
		)
		panel.Material = Enum.Material.Metal
		if visual ~= nil then
			panel.Transparency = 1
		end
	end
	local lampSize = OfficeDecorConstants.ELEVATOR_LAMP_SIZE
	local lamp = part(
		"ElevatorLamp",
		Vector3.new(lampSize.Z, lampSize.Y, lampSize.X),
		frame * CFrame.new(0, door.Y / 2 + 0.6, 0),
		OfficeDecorConstants.ELEVATOR_LAMP_COLOR,
		parent
	)
	lamp.Material = Enum.Material.Neon
	emitter("elevator", (frame * CFrame.new(0, 0, 1)).Position, parent)
end

local OfficeDecorFixtureSystem = {}

OfficeDecorFixtureSystem.DESK_SPREAD = DESK_SPREAD
OfficeDecorFixtureSystem.part = part
OfficeDecorFixtureSystem.exitSign = exitSign
OfficeDecorFixtureSystem.monitor = monitor
OfficeDecorFixtureSystem.emitter = emitter
OfficeDecorFixtureSystem.elevator = elevator

return OfficeDecorFixtureSystem
