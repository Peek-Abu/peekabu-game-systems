--!strict
--[=[
	TrainingTrailSystem: the training guide in the world (tutorial v3), on the local client only. While the player is
	on a training stop it draws:
	- a floor trail of chevrons (Beams with the uploaded chevron texture, scrolling toward the goal) from just ahead of
	  the player's feet to what the guide points at, along a PathfindingService path (a straight line when there is
	  none), re-pathed as the player moves (TrainingTrailUtils);
	- a bobbing arrow over the target (a BillboardGui, always on top) and a ring on the floor under it.
	Gold on calm stops, red at the hide stop (TrainingGuideRules.tone). Off a run, the hub can hand it a goal of its own
	(`setHub`: the Training pad, TrainingHubSystem), drawn the same way in gold. The target follows TrainingGuideRules.target
	from what this system sees of the player (the stop's door open, the treasure carried, hidden at the hide stop),
	which it also hands to TrainingCoachStore so Pippa's line follows. The targets are found in the Training map by
	its parts' attributes and in the run's spawned piles and cargo by their tags.

	Spec-exempt shell (Instances, PathfindingService, RenderStepped); the maths is the specced TrainingTrailUtils and
	the choices the specced TrainingGuideRules.

	@class TrainingTrailSystem
]=]

local CollectionService = game:GetService("CollectionService")
local PathfindingService = game:GetService("PathfindingService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local CargoConstants = require(ReplicatedStorage.Shared.Features.Cargo.Data.CargoConstants)
local CargoRegistry = require(ReplicatedStorage.Shared.Features.Cargo.Data.CargoRegistry)
local CarryConstants = require(ReplicatedStorage.Shared.Features.Carry.Data.CarryConstants)
local HideConstants = require(ReplicatedStorage.Shared.Features.Hide.Data.HideConstants)
local TrainingConstants = require(ReplicatedStorage.Shared.Features.Training.Data.TrainingConstants)
local TrainingGuideRules = require(ReplicatedStorage.Shared.Features.Training.Rules.TrainingGuideRules)
local VacuumConstants = require(ReplicatedStorage.Shared.Features.Vacuum.Data.VacuumConstants)
local HideStore = require(ReplicatedStorage.Client.Features.Hide.State.HideStore)
local TrainingCoachStore = require(ReplicatedStorage.Client.Features.Training.State.TrainingCoachStore)
local TrainingTrailUtils = require(ReplicatedStorage.Client.Features.Training.Utils.TrainingTrailUtils)

local GUIDE = TrainingConstants.GUIDE
local FOLDER_NAME = "TrainingGuide"
-- How far ahead of the feet the trail starts (studs), and the shortest leg kept.
local START_AHEAD = 2.5
local MIN_LEG = 1
-- The most legs drawn (a path rarely has more corners).
local MAX_LEGS = 12

local folder: Folder? = nil
local beams: { Beam } = {}
local attachments: { Attachment } = {}
local anchor: Part? = nil
local arrow: BillboardGui? = nil
local arrowImage: ImageLabel? = nil
local ring: Part? = nil
local stepping: RBXScriptConnection? = nil
local stop: number? = nil
-- The hub's goal (a floor point), used only off a run.
local hubGoal: Vector3? = nil
local hiddenHere = false
local legs: { TrainingTrailUtils.Leg } = {}
local lastFrom: Vector3? = nil
local lastAt = -math.huge
local pathing = false
-- The target, looked up TARGET_SECONDS apart (it scans the map), and when it was last looked up.
local TARGET_SECONDS = 0.1
local target: Vector3? = nil
local targetAt = -math.huge

local function rootOf(): BasePart?
	local player = Players.LocalPlayer
	local character = if player ~= nil then player.Character else nil
	local root = if character ~= nil then character:FindFirstChild("HumanoidRootPart") else nil
	return if root ~= nil and root:IsA("BasePart") then root else nil
end

-- The floor under the player (a ray down, the character and the guide left out); a guess under the root without one.
local function floorUnder(root: BasePart): Vector3
	local params = RaycastParams.new()
	local character = root.Parent
	local ignore: { Instance } = {}
	if character ~= nil then
		table.insert(ignore, character)
	end
	if folder ~= nil then
		table.insert(ignore, folder)
	end
	params.FilterDescendantsInstances = ignore
	params.FilterType = Enum.RaycastFilterType.Exclude
	local hit = Workspace:Raycast(root.Position, Vector3.new(0, -12, 0), params)
	return if hit ~= nil then hit.Position else root.Position - Vector3.new(0, 3, 0)
end

local function mapOf(): Model?
	for _, tagged in CollectionService:GetTagged(TrainingConstants.MAP_TAG) do
		if tagged:IsA("Model") then
			return tagged
		end
	end
	return nil
end

-- The map's parts with `role` (and `stopNumber` when given).
local function marked(map: Model, role: string, stopNumber: number?): { BasePart }
	local found: { BasePart } = {}
	for _, part in map:GetDescendants() do
		if
			part:IsA("BasePart")
			and part:GetAttribute(TrainingConstants.ROLE_ATTRIBUTE) == role
			and (stopNumber == nil or part:GetAttribute(TrainingConstants.STOP_ATTRIBUTE) == stopNumber)
		then
			table.insert(found, part)
		end
	end
	return found
end

local function inside(box: BasePart, position: Vector3): boolean
	local localPoint = box.CFrame:PointToObjectSpace(position)
	local half = box.Size / 2
	return math.abs(localPoint.X) <= half.X
		and math.abs(localPoint.Y) <= half.Y + 4
		and math.abs(localPoint.Z) <= half.Z
end

local function inZone(map: Model, stopNumber: number, position: Vector3): boolean
	for _, zone in marked(map, "zone", stopNumber) do
		if inside(zone, position) then
			return true
		end
	end
	return false
end

local function nearest(parts: { BasePart }, from: Vector3): BasePart?
	local best: BasePart? = nil
	local bestDistance = math.huge
	for _, part in parts do
		local distance = (part.Position - from).Magnitude
		if distance < bestDistance then
			best, bestDistance = part, distance
		end
	end
	return best
end

-- The run's live parts tagged `tag` inside the stop's zone.
local function liveInZone(map: Model, stopNumber: number, tag: string): { BasePart }
	local found: { BasePart } = {}
	for _, tagged in CollectionService:GetTagged(tag) do
		if tagged:IsA("BasePart") and tagged:IsDescendantOf(Workspace) and inZone(map, stopNumber, tagged.Position) then
			table.insert(found, tagged)
		end
	end
	return found
end

local function isTreasure(part: BasePart): boolean
	local id = part:GetAttribute(CargoConstants.ID_ATTRIBUTE)
	local def = if type(id) == "string" then CargoRegistry.get(id) else nil
	return def ~= nil and def.category == "salvage"
end

-- The stop's treasure, carried or not: the cargo the local player holds, else the one in the zone.
local function treasureOf(map: Model, stopNumber: number): (BasePart?, boolean)
	local player = Players.LocalPlayer
	local userId = if player ~= nil then player.UserId else 0
	for _, tagged in CollectionService:GetTagged(CarryConstants.TAG) do
		if
			tagged:IsA("BasePart")
			and isTreasure(tagged)
			and tagged:GetAttribute(CarryConstants.CARRIED_BY_ATTRIBUTE) == userId
		then
			return tagged, true
		end
	end
	local loose: { BasePart } = {}
	for _, part in liveInZone(map, stopNumber, CarryConstants.TAG) do
		if isTreasure(part) then
			table.insert(loose, part)
		end
	end
	local root = rootOf()
	return if root ~= nil then nearest(loose, root.Position) else loose[1], false
end

local function doorOpen(map: Model, stopNumber: number): boolean
	for _, door in marked(map, "door", stopNumber) do
		if door:GetAttribute("TrainingOpen") == true then
			return true
		end
	end
	return false
end

local function truckBed(map: Model): BasePart?
	local truck = map:FindFirstChild("Truck")
	local bed = if truck ~= nil then truck:FindFirstChild("TruckBed") else nil
	return if bed ~= nil and bed:IsA("BasePart") then bed else nil
end

-- What the guide points at now, as a floor point (nil = nothing), and what it sees of the player.
local function targetNow(map: Model, stopNumber: number, from: Vector3): (Vector3?, TrainingGuideRules.Situation)
	local treasure, carrying = nil, false
	if TrainingConstants.STOPS[stopNumber] ~= nil and TrainingConstants.STOPS[stopNumber].id == "treasure" then
		treasure, carrying = treasureOf(map, stopNumber)
	end
	if HideStore.hidden() ~= nil and TrainingGuideRules.tone(stopNumber) == "danger" then
		hiddenHere = true
	end
	local situation: TrainingGuideRules.Situation = {
		stopDone = doorOpen(map, stopNumber),
		carrying = carrying,
		hidden = hiddenHere,
	}
	local kind = TrainingGuideRules.target(stopNumber, situation)
	local part: BasePart? = nil
	if kind == "pile" then
		part = nearest(liveInZone(map, stopNumber, VacuumConstants.PILE_TAG), from)
	elseif kind == "treasure" then
		part = treasure
	elseif kind == "truck" then
		part = truckBed(map)
	elseif kind == "desk" then
		part = nearest(liveInZone(map, stopNumber, HideConstants.FURNITURE_TAG), from)
	elseif kind == "next" then
		part = marked(map, "stop", stopNumber + 1)[1]
	end
	if part == nil then
		return nil, situation
	end
	-- The floor under the target (its bottom face; a desk's front edge is where you crouch in).
	local floor = part.Position - Vector3.new(0, part.Size.Y / 2, 0)
	return floor, situation
end

local function newAttachment(): Attachment
	local attachment = Instance.new("Attachment")
	attachment.Name = "TrainingTrail"
	attachment.Parent = Workspace.Terrain
	table.insert(attachments, attachment)
	return attachment
end

local function newBeam(): Beam
	local beam = Instance.new("Beam")
	beam.Name = "TrainingTrail"
	beam.Texture = GUIDE.chevron
	beam.TextureMode = Enum.TextureMode.Static
	beam.TextureLength = GUIDE.chevronLength
	beam.TextureSpeed = GUIDE.speed / GUIDE.chevronLength
	beam.Width0 = GUIDE.width
	beam.Width1 = GUIDE.width
	beam.FaceCamera = false
	beam.LightEmission = 0.35
	beam.LightInfluence = 0
	beam.Brightness = 1.6
	beam.Transparency = NumberSequence.new(0)
	beam.Segments = 1
	beam.Attachment0 = newAttachment()
	beam.Attachment1 = newAttachment()
	beam.Enabled = false
	beam.Parent = folder
	table.insert(beams, beam)
	return beam
end

local function build()
	local root = Instance.new("Folder")
	root.Name = FOLDER_NAME
	root.Parent = Workspace
	folder = root
	for _ = 1, MAX_LEGS do
		newBeam()
	end
	local holder = Instance.new("Part")
	holder.Name = "TrainingMarker"
	holder.Anchored = true
	holder.CanCollide = false
	holder.CanQuery = false
	holder.CanTouch = false
	holder.Transparency = 1
	holder.Size = Vector3.new(0.2, 0.2, 0.2)
	holder.Parent = root
	anchor = holder
	local gui = Instance.new("BillboardGui")
	gui.Name = "Arrow"
	gui.AlwaysOnTop = true
	gui.LightInfluence = 0
	gui.Size = UDim2.fromOffset(GUIDE.arrowSize, math.floor(GUIDE.arrowSize * 1.29))
	gui.Adornee = holder
	gui.Enabled = false
	gui.Parent = holder
	local image = Instance.new("ImageLabel")
	image.BackgroundTransparency = 1
	image.Size = UDim2.fromScale(1, 1)
	image.Image = GUIDE.arrow
	image.Parent = gui
	arrow, arrowImage = gui, image
	local disc = Instance.new("Part")
	disc.Name = "TrainingRing"
	disc.Shape = Enum.PartType.Cylinder
	disc.Anchored = true
	disc.CanCollide = false
	disc.CanQuery = false
	disc.CanTouch = false
	disc.CastShadow = false
	disc.Material = Enum.Material.Neon
	disc.Transparency = 1
	disc.Size = Vector3.new(0.08, GUIDE.ring, GUIDE.ring)
	disc.Parent = root
	ring = disc
end

-- Lays one leg flat on the floor: its attachments face up so the ribbon lies down, chevrons pointing along it.
local function place(beam: Beam, leg: TrainingTrailUtils.Leg, color: Color3)
	local lift = Vector3.new(0, GUIDE.lift, 0)
	local direction = leg.to - leg.from
	local flat = Vector3.new(direction.X, 0, direction.Z)
	local along = if flat.Magnitude > 1e-3 then flat.Unit else Vector3.new(0, 0, -1)
	local a0, a1 = beam.Attachment0, beam.Attachment1
	if a0 == nil or a1 == nil then
		return
	end
	-- The attachment's up (secondary axis) is the ribbon's width: lying along the floor, across the leg.
	local across = along:Cross(Vector3.yAxis)
	a0.WorldCFrame = CFrame.fromMatrix(leg.from + lift, along, across)
	a1.WorldCFrame = CFrame.fromMatrix(leg.to + lift, along, across)
	beam.Color = ColorSequence.new(color)
	beam.Enabled = true
end

local function hideAll()
	for _, beam in beams do
		beam.Enabled = false
	end
	if arrow ~= nil then
		arrow.Enabled = false
	end
	if ring ~= nil then
		ring.Transparency = 1
	end
end

-- Asks for a path from `from` to `to` (in the background); a straight line until it comes back, or when it fails.
local function repath(from: Vector3, to: Vector3)
	legs = TrainingTrailUtils.trimStart(TrainingTrailUtils.segments({ from, to }, MIN_LEG), START_AHEAD)
	if pathing then
		return
	end
	pathing = true
	task.spawn(function()
		local path = PathfindingService:CreatePath({ AgentRadius = 1.5, AgentHeight = 5, AgentCanJump = false })
		local ok = pcall(function()
			path:ComputeAsync(from, to)
		end)
		pathing = false
		if not ok or path.Status ~= Enum.PathStatus.Success then
			return
		end
		local points: { Vector3 } = {}
		for _, waypoint in path:GetWaypoints() do
			table.insert(points, waypoint.Position)
		end
		table.insert(points, to)
		legs = TrainingTrailUtils.trimStart(TrainingTrailUtils.segments(points, MIN_LEG), START_AHEAD)
	end)
end

local function step()
	local at = stop
	local root = rootOf()
	if root == nil then
		hideAll()
		return
	end
	local feet = floorUnder(root)
	local now = os.clock()
	local goal: Vector3? = nil
	local color = GUIDE.calm
	if at ~= nil then
		local map = mapOf()
		if map == nil then
			hideAll()
			return
		end
		if now - targetAt >= TARGET_SECONDS then
			targetAt = now
			local found, situation = targetNow(map, at, feet)
			target = found
			TrainingCoachStore.setSituation(situation)
		end
		goal = target
		if TrainingGuideRules.tone(at) == "danger" then
			color = GUIDE.danger
		end
	else
		goal = hubGoal
	end
	if goal == nil then
		hideAll()
		return
	end
	if TrainingTrailUtils.repath(lastFrom, feet, lastAt, now, GUIDE.repathDistance, GUIDE.repathSeconds) then
		lastFrom, lastAt = feet, now
		repath(feet, goal)
	end
	for index, beam in beams do
		local leg = legs[index]
		if leg ~= nil then
			place(beam, leg, color)
		else
			beam.Enabled = false
		end
	end
	local holder, gui, image, disc = anchor, arrow, arrowImage, ring
	if holder ~= nil and gui ~= nil and image ~= nil and disc ~= nil then
		local lift = GUIDE.arrowHeight + TrainingTrailUtils.bob(now, GUIDE.bob, GUIDE.bobSpeed)
		holder.CFrame = CFrame.new(goal + Vector3.new(0, lift, 0))
		image.ImageColor3 = color
		gui.Enabled = true
		local pulse = 1 + 0.08 * math.sin(now * GUIDE.bobSpeed * 1.5)
		disc.Size = Vector3.new(0.08, GUIDE.ring * pulse, GUIDE.ring * pulse)
		disc.CFrame = CFrame.new(goal + Vector3.new(0, GUIDE.lift, 0)) * CFrame.Angles(0, 0, math.rad(90))
		disc.Color = color
		disc.Transparency = 0.55
	end
end

local TrainingTrailSystem = {}

-- Draws while there is something to follow (a run's stop, else the hub's goal); stops and hides otherwise.
local function refresh()
	local wanted = stop ~= nil or hubGoal ~= nil
	if wanted and folder == nil then
		build()
	end
	if wanted and not stepping then
		stepping = RunService.RenderStepped:Connect(step)
	elseif not wanted then
		local connection = stepping
		stepping = nil
		if connection then
			connection:Disconnect()
		end
		hideAll()
	end
end

-- Forgets the drawn path (the goal changed).
local function forget()
	lastFrom = nil
	legs = {}
end

--[=[
	Follows the run's stop (nil off a run: the guide hides, or follows the hub's goal).
]=]
function TrainingTrailSystem.setStop(value: number?)
	if value ~= stop then
		hiddenHere = false
		forget()
		target = nil
		targetAt = -math.huge
	end
	stop = value
	refresh()
end

--[=[
	The hub's goal, a floor point (nil: none). Shown only off a run.
]=]
function TrainingTrailSystem.setHub(point: Vector3?)
	local previous = hubGoal
	if point == nil or previous == nil or (point - previous).Magnitude > 0.5 then
		forget()
	end
	hubGoal = point
	refresh()
end

--[=[
	Removes everything it made.
]=]
function TrainingTrailSystem.teardown()
	hubGoal = nil
	TrainingTrailSystem.setStop(nil)
	for _, attachment in attachments do
		attachment:Destroy()
	end
	table.clear(attachments)
	table.clear(beams)
	local root = folder
	folder, anchor, arrow, arrowImage, ring = nil, nil, nil, nil, nil
	if root ~= nil then
		root:Destroy()
	end
end

return TrainingTrailSystem
