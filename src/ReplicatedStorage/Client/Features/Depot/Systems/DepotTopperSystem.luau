--!strict
--[=[
	DepotTopperSystem: dresses the hub's stations on this client (owner 11-12, kit mock round 2 #1, ideas #5;
	DepotSpotConstants.TOPPER, DepotTopperRules, DepotTopperConstants). For every topper anchor (a part tagged
	TOPPER.TAG naming its station) and for the time clock's and daily sheet's sign shells (built by the server; their
	toppers stand on top of them):
	- the topper: a kit plate with the station's rendered icon and one word (DepotTopper) on a SurfaceGui, lit a little
	  by the room, with a backing behind its plate so it is never see-through;
	- a warm light pool on the floor under it (a SpotLight pointing down);
	- the station's lane: a flat strip in its colour on the floor in front, with chevrons pointing at the station.
	Everything is local, inert and cosmetic (nothing collides, queries, touches or replicates).

	Spec-exempt shell (Instances, React roots); the geometry is the specced DepotTopperRules.

	@class DepotTopperSystem
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Observers = require(ReplicatedStorage.Packages.Observers)
local React = require(ReplicatedStorage.Packages.React)
local DepotConstants = require(ReplicatedStorage.Shared.Features.Depot.Data.DepotConstants)
local DepotSpotConstants = require(ReplicatedStorage.Shared.Features.Depot.Data.DepotSpotConstants)
local DepotTopperRules = require(ReplicatedStorage.Shared.Features.Depot.Rules.DepotTopperRules)
local DepotTopperConstants = require(ReplicatedStorage.Client.Features.Depot.Data.DepotTopperConstants)
local UIBillboardHost = require(ReplicatedStorage.Client.UI.Layers.UIBillboardHost)
local UIBillboards = require(ReplicatedStorage.Client.UI.Layers.UIBillboards)
local DepotTopper = require(ReplicatedStorage.Client.UI.React.Screens.World.DepotTopper)
local UIToonConstants = require(ReplicatedStorage.Client.UI.React.Screens.Toon.UIToonConstants)

local TOPPER = DepotSpotConstants.TOPPER
local LANE = TOPPER.LANE
local POOL = TOPPER.POOL
local CANVAS = TOPPER.PLATE * TOPPER.PIXELS_PER_STUD
local BACKING_DEPTH = 0.08
-- How see-through the lane paint is (a little, so the floor's grain shows through).
local LANE_TRANSPARENCY = 0.15
local LANE_PIXELS_PER_STUD = 50

local roots = UIBillboards.new(UIBillboardHost.factory)

local function inert(part: BasePart)
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Locked = true
end

local function folder(): Folder
	local found = Workspace:FindFirstChild("DepotToppers")
	if found ~= nil and found:IsA("Folder") then
		return found
	end
	local made = Instance.new("Folder")
	made.Name = "DepotToppers"
	made.Parent = Workspace
	return made
end

-- The floor under `point` (the highest thing a ray down meets, ignoring the toppers and characters); nil if none.
local function floorUnder(point: Vector3, ignore: { Instance }): number?
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = ignore
	local hit = Workspace:Raycast(point + Vector3.new(0, 2, 0), Vector3.new(0, -LANE.PROBE, 0), params)
	return if hit ~= nil then hit.Position.Y else nil
end

-- One chevron (two bars meeting at a point) pointing up the lane's gui, at `y` (0..1 down the lane).
local function chevron(index: number, y: number, color: Color3): React.ReactNode
	local function bar(side: number): React.ReactNode
		return React.createElement("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5 + side * 0.17, 0.5),
			Size = UDim2.fromScale(0.42, 0.16),
			Rotation = side * 38,
			BackgroundColor3 = color,
			BorderSizePixel = 0,
		}, { corner = React.createElement("UICorner", { CornerRadius = UDim.new(1, 0) }) })
	end
	return React.createElement("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, y),
		Size = UDim2.new(0.8, 0, 0, 40),
		BackgroundTransparency = 1,
		LayoutOrder = index,
	}, { left = bar(-1), right = bar(1) })
end

-- The lane in front of a station: a flat strip in its colour, chevrons pointing back at the station.
local function lane(anchor: CFrame, shade: UIToonConstants.Shade, start: number?, length: number?, parent: Instance)
	local ignore: { Instance } = { parent }
	for _, player in game:GetService("Players"):GetPlayers() do
		local character = player.Character
		if character ~= nil then
			table.insert(ignore, character)
		end
	end
	local probeAt, probeSize = DepotTopperRules.lane(anchor, anchor.Position.Y, start, length)
	-- The floor under the far end of the lane (well clear of the station itself).
	local farEnd = probeAt.Position + probeAt.LookVector * (probeSize.Z / 2)
	local floorY = floorUnder(farEnd, ignore)
	if floorY == nil then
		return
	end
	local at, size = DepotTopperRules.lane(anchor, floorY, start, length)
	local strip = Instance.new("Part")
	strip.Name = "StationLane"
	inert(strip)
	strip.Size = size
	strip.CFrame = at
	strip.Color = shade.base
	strip.Material = Enum.Material.SmoothPlastic
	strip.Transparency = LANE_TRANSPARENCY
	strip.Parent = parent
	local gui = Instance.new("SurfaceGui")
	gui.Name = "Chevrons"
	gui.Face = Enum.NormalId.Top
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = LANE_PIXELS_PER_STUD
	gui.LightInfluence = 1
	gui.Parent = strip
	local marks: { [string]: React.ReactNode } = {}
	for index = 1, LANE.CHEVRONS do
		marks[`c{index}`] = chevron(index, (index - 0.5) / LANE.CHEVRONS, shade.hi)
	end
	roots.show(gui, React.createElement("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1 }, marks))
end

-- Dresses one topper at `at` (its canvas centre, facing the readers) for `stationKey`; returns its cleanup.
local function dress(stationKey: string, at: CFrame, start: number?, length: number?): () -> ()
	local station = DepotTopperConstants.STATIONS[stationKey]
	if station == nil then
		return function() end
	end
	local shade = UIToonConstants.shade(station.hue)
	local group = Instance.new("Folder")
	group.Name = `Topper_{stationKey}`
	group.Parent = folder()
	local canvas = Instance.new("Part")
	canvas.Name = "TopperCanvas"
	inert(canvas)
	canvas.Transparency = 1
	canvas.Size = Vector3.new(TOPPER.PLATE.X, TOPPER.PLATE.Y, 0.05)
	canvas.CFrame = at
	canvas.Parent = group
	-- The backing: a slab behind the plate body (the gui is drawn on the front face only).
	local body = TOPPER.PLATE.Y * TOPPER.BODY_SHARE
	local backing = Instance.new("Part")
	backing.Name = "TopperBacking"
	inert(backing)
	backing.Size = Vector3.new(TOPPER.PLATE.X - 0.2, body - 0.15, BACKING_DEPTH)
	backing.CFrame = at * CFrame.new(0, -TOPPER.PLATE.Y / 2 + body / 2 + 0.08, BACKING_DEPTH / 2 + 0.03)
	backing.Color = UIToonConstants.COLOR.ink
	backing.Material = Enum.Material.SmoothPlastic
	backing.Parent = group
	local gui = Instance.new("SurfaceGui")
	gui.Name = "Topper"
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
	gui.CanvasSize = CANVAS
	gui.LightInfluence = 0.35
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Parent = canvas
	roots.show(gui, React.createElement(DepotTopper, { station = station }))
	-- The light pool: a warm spot pointing down from the topper to the floor.
	local floorY = floorUnder(at.Position, { group })
	local light = Instance.new("SpotLight")
	light.Face = Enum.NormalId.Bottom
	light.Color = POOL.COLOR
	light.Brightness = POOL.BRIGHTNESS
	light.Angle = POOL.ANGLE
	light.Range = DepotTopperRules.poolRange(at.Position.Y, floorY or at.Position.Y - POOL.MIN_RANGE)
	light.Shadows = false
	light.Parent = canvas
	lane(at, shade, start, length, group)
	return function()
		for _, descendant in group:GetDescendants() do
			if descendant:IsA("SurfaceGui") then
				roots.hide(descendant)
			end
		end
		group:Destroy()
	end
end

local function number(value: unknown): number?
	return if type(value) == "number" and value == value and value >= 0 then value else nil
end

local DepotTopperSystem = {}

-- Dresses every topper anchor and the clock and daily sign shells; returns the stopper.
function DepotTopperSystem.start(): () -> ()
	local stopAnchors = Observers.observeTag(TOPPER.TAG, function(instance: Instance)
		if not instance:IsA("BasePart") then
			return nil
		end
		local key = instance:GetAttribute(TOPPER.ATTRIBUTE)
		if type(key) ~= "string" then
			return nil
		end
		instance.Transparency = 1
		return dress(
			key,
			instance.CFrame,
			number(instance:GetAttribute(TOPPER.LANE_START_ATTRIBUTE)),
			number(instance:GetAttribute(TOPPER.LANE_LENGTH_ATTRIBUTE))
		)
	end)
	local function onShell(stationKey: string): (instance: Instance) -> (() -> ())?
		return function(instance: Instance)
			if not instance:IsA("SurfaceGui") then
				return nil
			end
			local part = instance.Adornee or instance.Parent
			if part == nil or not part:IsA("BasePart") then
				return nil
			end
			return dress(stationKey, DepotTopperRules.onShell(part.CFrame, part.Size, instance.Face), nil, nil)
		end
	end
	local tags = DepotConstants.BILLBOARD_TAGS
	local stopClock = Observers.observeTag(tags.clock, onShell("clock"))
	local stopDaily = Observers.observeTag(tags.daily, onShell("daily"))
	return function()
		stopAnchors()
		stopClock()
		stopDaily()
		roots.teardown()
	end
end

return DepotTopperSystem
