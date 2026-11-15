--!strict
--[=[
	VacuumAirSystem: the air a sucking vacuum gulps (P1 v2 2026-11-15; visual only, on this machine). The owner turned
	down v1's straight streaks ("random lines going sideways into vacuum") and asked for suction-game air, so the air is
	now a swirl (VacuumAirFormulas):

	- Wind ribbons: a few soft lilac ribbons (Trails on moving Attachments) that spiral in from a ring ahead of the floor
	  head, tightening and rushing into its mouth, each reborn at the ring as it arrives.
	- Vortex rings (the VacuumVfxConstants `vacuumAir` funnel): lilac hoops that shrink as they ride into the mouth,
	  with dust motes in the draft.
	- Goo blobs (`tear`, from VacuumPullSystem while a pile is sucked): violet Gloom blobs that tear off the pile, swell,
	  and swirl into the nozzle, stretching along their flight, one ink outline round them all.

	`step` runs every frame for every holder (VacuumMotionSystem): while its vacuum sucks (VacuumMotionSystem's active)
	the air flows into its floor head (VacuumFeelFormulas.airFlow), else the ribbons stop and the air in flight fades.

	Spec-exempt shell (Instances, VfxFunnelSystem); the shapes are the specced VacuumAirFormulas and
	VacuumFeelFormulas.airFlow.

	@class VacuumAirSystem
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local VacuumConstants = require(ReplicatedStorage.Shared.Features.Vacuum.Data.VacuumConstants)
local VacuumAirFormulas = require(ReplicatedStorage.Client.Features.Vacuum.Utils.VacuumAirFormulas)
local VacuumFeelFormulas = require(ReplicatedStorage.Client.Features.Vacuum.Utils.VacuumFeelFormulas)
local VfxBurstSystem = require(ReplicatedStorage.Client.Features.Vfx.Systems.VfxBurstSystem)
local VfxFunnelSystem = require(ReplicatedStorage.Client.Features.Vfx.Systems.VfxFunnelSystem)

local AIR = "vacuumAir"
local STRENGTH = 1

-- The Gloom & Gleam tokens (game-vfx-design §8).
local LILAC = Color3.fromRGB(180, 139, 255)
local PORCELAIN = Color3.fromRGB(250, 246, 236)
local GRAPE = Color3.fromRGB(123, 63, 242)
local INK = Color3.fromRGB(30, 15, 58)

-- Wind ribbons: how many (fewer on low graphics), each trip's length (s) and jitter, the ribbon's width (studs) at
-- the ring, and how many times it goes round on the way in.
local RIBBONS, RIBBONS_LOW = 6, 3
local RIBBON_LIFE, RIBBON_JITTER = 0.6, 0.15
local RIBBON_WIDTH = 0.32
local RIBBON_TURNS = 1.1
-- The ring the ribbons are born on, as a share of the funnel's radius.
local RIBBON_RING = 0.75
local GOLDEN = 2.39996

-- Goo blobs: their full size (studs), trip length (s) and jitter, the ring they swirl in from, and turns.
local BLOB_SIZE = 0.6
local BLOB_LIFE, BLOB_JITTER = 0.55, 0.12
local BLOB_RING = 0.7
local BLOB_TURNS = 0.7
local MAX_BLOBS = 12

type Ribbon = {
	a0: Attachment,
	a1: Attachment,
	trail: Trail,
	born: number,
	life: number,
	phase: number,
	last: Vector3?,
}

type Stream = {
	funnel: VfxFunnelSystem.Funnel?,
	host: Part,
	ribbons: { Ribbon },
}

type Blob = {
	part: Part,
	mesh: SpecialMesh,
	from: Vector3,
	sink: () -> Vector3?,
	lastSink: Vector3,
	born: number,
	life: number,
	phase: number,
	last: Vector3?,
}

local streams: { [Model]: Stream } = {}
local blobs: { Blob } = {}
local folder: Folder? = nil
local gooModel: Model? = nil
local connection: RBXScriptConnection? = nil
local random = Random.new()

local VacuumAirSystem = {}

local function localFolder(): Folder
	local existing = folder
	if existing ~= nil and existing.Parent == Workspace then
		return existing
	end
	local made = Instance.new("Folder")
	made.Name = "VacuumAir"
	made.Parent = Workspace
	folder = made
	return made
end

local function inertPart(name: string): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored, part.CanCollide, part.CanQuery, part.CanTouch = true, false, false, false
	part.CastShadow = false
	part.Size = Vector3.one
	return part
end

-- `character`'s held floor head, or nil while its wand is stowed.
local function headOf(character: Model): BasePart?
	local tool = character:FindFirstChild(VacuumConstants.TOOL_NAME)
	local head = if tool ~= nil and tool:IsA("Tool") then tool:FindFirstChild(VacuumConstants.FLOOR_HEAD_NAME) else nil
	return if head ~= nil and head:IsA("BasePart") then head else nil
end

-- A ribbon's width offset at `position` moving by `motion`: across its flight as the camera sees it.
local function across(position: Vector3, motion: Vector3, width: number): Vector3
	local camera = Workspace.CurrentCamera
	local view = if camera ~= nil then position - camera.CFrame.Position else Vector3.zAxis
	local side = view:Cross(motion)
	if side.Magnitude < 1e-5 then
		side = Vector3.yAxis
	end
	return side.Unit * (width / 2)
end

local function newRibbon(host: Part, index: number, now: number, count: number): Ribbon
	local a0 = Instance.new("Attachment")
	a0.Name = `Ribbon{index}A`
	a0.Parent = host
	local a1 = Instance.new("Attachment")
	a1.Name = `Ribbon{index}B`
	a1.Parent = host
	local trail = Instance.new("Trail")
	trail.Attachment0 = a0
	trail.Attachment1 = a1
	trail.Lifetime = 0.2
	trail.MinLength = 0.02
	trail.FaceCamera = true
	trail.LightEmission = 0.25
	trail.LightInfluence = 0
	trail.Color = ColorSequence.new(PORCELAIN, LILAC)
	trail.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.1),
		NumberSequenceKeypoint.new(0.5, 0.35),
		NumberSequenceKeypoint.new(1, 1),
	})
	trail.WidthScale = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(1, 0.15),
	})
	trail.Parent = host
	return {
		a0 = a0,
		a1 = a1,
		trail = trail,
		-- Staggered so the ribbons arrive one after another, never all at once.
		born = now - RIBBON_LIFE * (index - 1) / count,
		life = RIBBON_LIFE,
		phase = index * GOLDEN,
		last = nil,
	}
end

local function newStream(): Stream
	local host = inertPart("VacuumAirHost")
	host.Transparency = 1
	host.CFrame = CFrame.identity
	host.Parent = localFolder()
	local count = if VfxBurstSystem.quality() <= 3 then RIBBONS_LOW else RIBBONS
	local ribbons: { Ribbon } = {}
	local now = os.clock()
	for index = 1, count do
		table.insert(ribbons, newRibbon(host, index, now, count))
	end
	return { funnel = VfxFunnelSystem.funnel(AIR), host = host, ribbons = ribbons }
end

local function placeRibbon(ribbon: Ribbon, source: Vector3, sink: Vector3, radius: number, now: number)
	local age = now - ribbon.born
	local reborn = false
	if age >= ribbon.life then
		ribbon.born = now
		ribbon.life = RIBBON_LIFE + random:NextNumber(-RIBBON_JITTER, RIBBON_JITTER)
		ribbon.phase += GOLDEN
		age = 0
		reborn = true
	end
	local u = VacuumAirFormulas.travel(age, ribbon.life)
	local position = VacuumAirFormulas.spiral(source, sink, radius * RIBBON_RING, u, ribbon.phase, RIBBON_TURNS)
	local last = ribbon.last
	local motion = if last ~= nil and not reborn then position - last else sink - source
	-- Thinner as it closes on the mouth.
	local width = RIBBON_WIDTH * (0.35 + 0.65 * (1 - u))
	local offset = across(position, motion, width)
	ribbon.a0.Position = position + offset
	ribbon.a1.Position = position - offset
	if reborn then
		-- A ribbon reborn at the ring must not draw a line back from the mouth.
		ribbon.trail:Clear()
	end
	ribbon.last = position
end

local function endStream(stream: Stream)
	local funnel = stream.funnel
	if funnel ~= nil then
		funnel:stop()
	end
	for _, ribbon in stream.ribbons do
		ribbon.trail.Enabled = false
	end
	local host = stream.host
	task.delay(0.3, function()
		host:Destroy()
	end)
end

--[=[
	One frame of `character`'s air: swirling into its floor head while `active` (and its wand is out), else stopped.
]=]
function VacuumAirSystem.step(character: Model, root: BasePart?, active: boolean)
	local head = if active and root ~= nil then headOf(character) else nil
	local stream = streams[character]
	if head == nil or root == nil then
		if stream ~= nil then
			endStream(stream)
			streams[character] = nil
		end
		return
	end
	local flowing = stream or newStream()
	streams[character] = flowing
	local source, sink, radius = VacuumFeelFormulas.airFlow(head.CFrame, head.Size, root.Position)
	local funnel = flowing.funnel
	if funnel ~= nil then
		funnel:aim(source, sink, radius, STRENGTH)
	end
	local now = os.clock()
	for _, ribbon in flowing.ribbons do
		placeRibbon(ribbon, source, sink, radius, now)
	end
end

local function goo(): Model
	local existing = gooModel
	if existing ~= nil and existing.Parent ~= nil then
		return existing
	end
	local model = Instance.new("Model")
	model.Name = "VacuumGoo"
	-- One ink outline round every blob (a Highlight outlines the whole model).
	local outline = Instance.new("Highlight")
	outline.FillTransparency = 1
	outline.OutlineColor = INK
	outline.OutlineTransparency = 0
	outline.DepthMode = Enum.HighlightDepthMode.Occluded
	outline.Adornee = model
	outline.Parent = model
	model.Parent = localFolder()
	gooModel = model
	return model
end

local function stepBlobs(dt: number)
	local now = os.clock()
	for index = #blobs, 1, -1 do
		local blob = blobs[index]
		local age = now - blob.born
		local sink = blob.sink() or blob.lastSink
		blob.lastSink = sink
		if age >= blob.life then
			blob.part:Destroy()
			table.remove(blobs, index)
		else
			local u = VacuumAirFormulas.travel(age, blob.life)
			local position = VacuumAirFormulas.spiral(blob.from, sink, BLOB_RING, u, blob.phase, BLOB_TURNS)
			local last = blob.last
			local motion = if last ~= nil then position - last else sink - blob.from
			local along, thin = VacuumAirFormulas.blob(motion.Magnitude / math.max(dt, 1e-3))
			local size = BLOB_SIZE * VacuumAirFormulas.blobSize(u)
			blob.mesh.Scale = Vector3.new(thin, thin, along) * size
			blob.part.CFrame = if motion.Magnitude > 1e-4
				then CFrame.lookAt(position, position + motion)
				else CFrame.new(position)
			blob.last = position
		end
	end
	if #blobs == 0 and connection ~= nil then
		connection:Disconnect()
		connection = nil
	end
end

--[=[
	A blob of goo tears off a pile at `from` and swirls into the nozzle `sink()` gives (followed as it moves; its last
	place once it gives none).
]=]
function VacuumAirSystem.tear(from: Vector3, sink: () -> Vector3?)
	local first = sink()
	if first == nil or #blobs >= MAX_BLOBS then
		return
	end
	local part = inertPart("GooBlob")
	part.Color = GRAPE
	part.Material = Enum.Material.SmoothPlastic
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Scale = Vector3.zero
	mesh.Parent = part
	part.CFrame = CFrame.new(from)
	part.Parent = goo()
	table.insert(blobs, {
		part = part,
		mesh = mesh,
		from = from,
		sink = sink,
		lastSink = first,
		born = os.clock(),
		life = BLOB_LIFE + random:NextNumber(-BLOB_JITTER, BLOB_JITTER),
		phase = random:NextNumber(0, 2 * math.pi),
		last = nil,
	})
	if connection == nil then
		connection = RunService.RenderStepped:Connect(stepBlobs)
	end
end

--[=[
	`character` is gone (or no longer held): its air stops.
]=]
function VacuumAirSystem.forget(character: Model)
	local stream = streams[character]
	if stream ~= nil then
		endStream(stream)
		streams[character] = nil
	end
end

function VacuumAirSystem.forgetAll()
	for _, stream in streams do
		endStream(stream)
	end
	table.clear(streams)
	for _, blob in blobs do
		blob.part:Destroy()
	end
	table.clear(blobs)
	if connection ~= nil then
		connection:Disconnect()
		connection = nil
	end
end

return VacuumAirSystem
