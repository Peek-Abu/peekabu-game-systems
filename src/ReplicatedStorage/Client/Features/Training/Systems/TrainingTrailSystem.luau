--!strict
--[=[
	TrainingTrailSystem: the training guide in the world (tutorial v3), on the local client only. While the player is
	on a training stop it draws:
	- a floor trail of chevrons (Beams with the uploaded chevron texture, scrolling toward the goal) from just ahead of
	  the player's feet to what the guide points at, along a PathfindingService path (a straight line when there is
	  none), re-pathed as the player moves (TrainingTrailUtils). Its points sit on the floor found by a ray that
	  skips characters, parts nothing collides with and small props, at steady heights (TrainingTrailUtils.steady:
	  bumps and rounding never make it twitch), and the old path stays drawn until a new one comes back;
	- a bobbing arrow over the target (a BillboardGui, always on top) and a ring on the floor under it.
	Gold on calm stops, red at the hide stop (TrainingGuideRules.tone). Off a run, the hub can hand it a goal of its own
	(`setHub`: the Training pad, TrainingHubSystem), drawn the same way in gold. The target follows TrainingGuideRules.target
	from what this system sees of the player (the stop's door open, the treasure carried, hidden at the hide stop),
	which it also hands to TrainingCoachStore so Pippa's line follows. The targets are found in the Training map by
	its parts' attributes and in the run's spawned piles and cargo by their tags.

	Spec-exempt shell (Instances, PathfindingService, RenderStepped); the maths is the specced TrainingTrailUtils,
	the choices the specced TrainingGuideRules, and finding the target in the map the specced TrainingTargetUtils
	(split out of this file).

	@class TrainingTrailSystem
]=]

local PathfindingService = game:GetService("PathfindingService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local TrainingConstants = require(ReplicatedStorage.Shared.Features.Training.Data.TrainingConstants)
local TrainingGuideRules = require(ReplicatedStorage.Shared.Features.Training.Rules.TrainingGuideRules)
local TrainingCoachStore = require(ReplicatedStorage.Client.Features.Training.State.TrainingCoachStore)
local TrainingTargetUtils = require(ReplicatedStorage.Client.Features.Training.Utils.TrainingTargetUtils)
local TrainingTrailUtils = require(ReplicatedStorage.Client.Features.Training.Utils.TrainingTrailUtils)

local GUIDE = TrainingConstants.GUIDE
local FOLDER_NAME = "TrainingGuide"
-- How far ahead of the feet the trail starts (studs), and the shortest leg kept.
local START_AHEAD = 2.5
local MIN_LEG = 1
-- The most legs drawn (a path rarely has more corners).
local MAX_LEGS = 12
-- The floor ray skips parts smaller than this on every side (props, piles, cargo) and tries this many times.
local SMALL_PART = 1.5
local FLOOR_TRIES = 6
-- A floor height change under this is a bump, not a step (studs).
local STEADY_TOLERANCE = 0.75

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
-- The last stop the player escaped at (the server's CLEAR_ENTRY): that stop counts as done.
local clearStop: number? = nil
-- What the guide last saw of the player (TrainingGuideRules.Situation), for the trail's colour.
local seen: TrainingGuideRules.Situation = { stopDone = false, carrying = false, hidden = false }
-- The trail's kept floor height (TrainingTrailUtils.steady).
local level: number? = nil
local legs: { TrainingTrailUtils.Leg } = {}
local lastFrom: Vector3? = nil
local lastAt = -math.huge
local pathing = false
-- The target, looked up TARGET_SECONDS apart (it scans the map), and when it was last looked up.
local TARGET_SECONDS = 0.1
local target: Vector3? = nil
local targetAt = -math.huge

local rootOf = TrainingTargetUtils.rootOf
local mapOf = TrainingTargetUtils.mapOf

-- The floor under `position`: a ray down that skips every character, the guide itself, parts nothing collides with
-- and small props (a pile, a mug, a desk lamp), so the trail lies on the real floor. A guess 3 studs under without one.
local function floorAt(position: Vector3): Vector3
	local params = RaycastParams.new()
	local ignore: { Instance } = {}
	for _, player in Players:GetPlayers() do
		if player.Character ~= nil then
			table.insert(ignore, player.Character)
		end
	end
	if folder ~= nil then
		table.insert(ignore, folder)
	end
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.RespectCanCollide = true
	for _ = 1, FLOOR_TRIES do
		params.FilterDescendantsInstances = ignore
		local hit = Workspace:Raycast(position + Vector3.new(0, 3, 0), Vector3.new(0, -15, 0), params)
		if hit == nil then
			break
		end
		local part = hit.Instance
		if not part:IsA("BasePart") or part:IsA("Terrain") then
			return hit.Position
		end
		local size = part.Size
		if math.max(size.X, size.Y, size.Z) >= SMALL_PART then
			return hit.Position
		end
		table.insert(ignore, part)
	end
	return position - Vector3.new(0, 3, 0)
end

local function floorUnder(root: BasePart): Vector3
	return floorAt(root.Position)
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

-- The points on the floor at steady heights, then the legs from them (the start trimmed ahead of the feet).
local function legsThrough(points: { Vector3 }): { TrainingTrailUtils.Leg }
	local settled: { Vector3 } = {}
	for _, point in points do
		local height = TrainingTrailUtils.steady(level, floorAt(point).Y, STEADY_TOLERANCE)
		level = height
		table.insert(settled, Vector3.new(point.X, height, point.Z))
	end
	return TrainingTrailUtils.trimStart(TrainingTrailUtils.segments(settled, MIN_LEG), START_AHEAD)
end

-- Asks for a path from `from` to `to` (in the background). The drawn path stays until it comes back (a straight line
-- only when nothing is drawn yet, or when the path fails), so the trail does not jump between the two.
local function repath(from: Vector3, to: Vector3)
	if #legs == 0 then
		legs = legsThrough({ from, to })
	end
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
			legs = legsThrough({ from, to })
			return
		end
		local points: { Vector3 } = {}
		for _, waypoint in path:GetWaypoints() do
			table.insert(points, waypoint.Position)
		end
		table.insert(points, to)
		legs = legsThrough(points)
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
			local found, situation = TrainingTargetUtils.targetNow(map, at, feet, hiddenHere, clearStop)
			hiddenHere = situation.hidden
			target = found
			seen = situation
			TrainingCoachStore.setSituation(situation)
		end
		goal = target
		if TrainingGuideRules.trailTone(at, seen) == "danger" then
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
	level = nil
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
	The last stop the player escaped at (the server's CLEAR_ENTRY; nil: none): that stop counts as done, so the guide
	moves on and Pippa says he is gone.
]=]
function TrainingTrailSystem.setClear(value: number?)
	if value ~= clearStop then
		clearStop = value
		targetAt = -math.huge
	end
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
