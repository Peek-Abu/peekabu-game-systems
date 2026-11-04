--!strict
--[=[
	EmoteLassoSystem: draws Sheriff Prickles' bendy lasso in Big Roundup on this client (owner, 2026-11-03: a beam
	rope and a soft spinning loop instead of the rigid hoop).

	The clip still poses the rigid LassoLoop prop, and EmotePropSystem still shows and hides it from the clip's markers
	(late joiners included). While it shows, this system hides it on this client only (LocalTransparencyModifier, so
	it never fights EmotePropSystem's Transparency) and draws over it: a rope of beams from the hand to the knot, a
	ring of beams through the knot with small balls at its joints, and the brass nozzle at the knot. Every frame the
	chain and ring move by EmoteLassoFormulas on fixed substeps, from the prop's pose. When the prop hides (the coil
	swap, a stop) or the character is released, the drawing goes and the prop's view is given back.

	Every client tracks every character (EmoteServiceClient), so everyone near sees it. Previews (ViewportFrames) are
	not tracked here and keep the rigid loop.

	`deps` is a test seam: the frame signal and where the drawing goes.

	@class EmoteLassoSystem
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local EmoteLassoConstants = require(ReplicatedStorage.Client.Features.Emote.Data.EmoteLassoConstants)
local EmoteLassoFormulas = require(ReplicatedStorage.Client.Features.Emote.Utils.EmoteLassoFormulas)
local EmotePropSystem = require(ReplicatedStorage.Client.Features.Emote.Systems.EmotePropSystem)

local TUNING = EmoteLassoConstants.TUNING
local M, K = TUNING.ropePoints, TUNING.ringPoints

export type Deps = {
	-- Calls back every frame with its seconds; returns the disconnect.
	onFrame: (callback: (dt: number) -> ()) -> () -> (),
	-- Where the drawing's attachments, beams and parts go (attachments need a BasePart).
	container: BasePart,
}

export type EmoteLassoState = {
	tracked: number,
	drawing: number,
}

export type EmoteLassoSystem = {
	-- Starts watching a character; returns the release, which clears its drawing.
	track: (character: Model) -> () -> (),
	getState: () -> EmoteLassoState,
}

-- The instances of one drawn lasso.
type Drawing = {
	ropeAttachments: { Attachment },
	ringAttachments: { Attachment },
	ropeBeams: { Beam },
	ringBeams: { Beam },
	joints: { BasePart },
	nozzle: BasePart,
}

type Record = {
	character: Model,
	state: EmoteLassoFormulas.State,
	accumulated: number,
	drawing: Drawing?,
	-- The prop this client hid, to give back.
	hidden: BasePart?,
}

local function defaultDeps(): Deps
	return {
		onFrame = function(callback)
			local connection = RunService.RenderStepped:Connect(callback)
			return function()
				connection:Disconnect()
			end
		end,
		container = workspace.Terrain,
	}
end

local function newPart(shape: Enum.PartType, color: Color3, material: Enum.Material, parent: Instance): BasePart
	local part = Instance.new("Part")
	part.Name = "EmoteLasso"
	part.Shape = shape
	part.Color = color
	part.Material = material
	part.Anchored, part.CanCollide, part.CanQuery, part.CanTouch, part.CastShadow = true, false, false, false, false
	part.Parent = parent
	return part
end

local function newAttachment(parent: BasePart): Attachment
	local attachment = Instance.new("Attachment")
	attachment.Name = "EmoteLasso"
	attachment.Parent = parent
	return attachment
end

local function newBeam(a0: Attachment, a1: Attachment, parent: Instance): Beam
	local beam = Instance.new("Beam")
	beam.Name = "EmoteLasso"
	beam.Attachment0, beam.Attachment1 = a0, a1
	beam.Color = ColorSequence.new(EmoteLassoConstants.HOSE)
	beam.Transparency = NumberSequence.new(0)
	beam.LightInfluence = 1
	beam.LightEmission = 0
	beam.FaceCamera = true
	beam.Segments = EmoteLassoConstants.BEAM_SEGMENTS
	beam.Parent = parent
	return beam
end

local function build(container: BasePart): Drawing
	local ropeAttachments, ringAttachments, ropeBeams, ringBeams, joints = {}, {}, {}, {}, {}
	for i = 1, M + 1 do
		ropeAttachments[i] = newAttachment(container)
	end
	for i = 1, K do
		ringAttachments[i] = newAttachment(container)
	end
	for i = 1, M do
		ropeBeams[i] = newBeam(ropeAttachments[i], ropeAttachments[i + 1], container)
	end
	for i = 1, K do
		ringBeams[i] = newBeam(ringAttachments[i], ringAttachments[i % K + 1], container)
		-- Small balls hide the seams where the ring's beams meet (none on the rope: its joints are smooth).
		joints[i] = newPart(Enum.PartType.Ball, EmoteLassoConstants.HOSE, Enum.Material.SmoothPlastic, container)
	end
	local nozzle = newPart(Enum.PartType.Cylinder, EmoteLassoConstants.BRASS, Enum.Material.Metal, container)
	return {
		ropeAttachments = ropeAttachments,
		ringAttachments = ringAttachments,
		ropeBeams = ropeBeams,
		ringBeams = ringBeams,
		joints = joints,
		nozzle = nozzle,
	}
end

local function destroy(drawing: Drawing)
	for _, list in { drawing.ropeBeams, drawing.ringBeams } do
		for _, beam in list do
			beam:Destroy()
		end
	end
	for _, list in { drawing.ropeAttachments, drawing.ringAttachments } do
		for _, attachment in list do
			attachment:Destroy()
		end
	end
	for _, joint in drawing.joints do
		joint:Destroy()
	end
	drawing.nozzle:Destroy()
end

-- An attachment at `position` whose X axis (a beam's curve arm) points along `direction`.
local function aim(attachment: Attachment, position: Vector3, direction: Vector3)
	local x = if direction.Magnitude > 1e-4 then direction.Unit else Vector3.xAxis
	local helper = if math.abs(x.Y) < 0.9 then Vector3.yAxis else Vector3.xAxis
	local z = x:Cross(helper).Unit
	attachment.WorldCFrame = CFrame.fromMatrix(position, x, z:Cross(x), z)
end

-- Lays the beams on the chain and ring as Catmull-Rom curves (one-sided at the rope's ends).
local function draw(drawing: Drawing, state: EmoteLassoFormulas.State, scale: number)
	local rope, ring = state.rope, state.ring
	local width = EmoteLassoConstants.WIDTH * scale
	local function ropeTangent(i: number): Vector3
		return rope[math.min(i + 1, M + 1)] - rope[math.max(i - 1, 1)]
	end
	for i = 1, M + 1 do
		aim(drawing.ropeAttachments[i], rope[i], ropeTangent(i))
	end
	for i = 1, M do
		local beam = drawing.ropeBeams[i]
		beam.CurveSize0 = ropeTangent(i).Magnitude / (if i == 1 then 3 else 6)
		beam.CurveSize1 = ropeTangent(i + 1).Magnitude / (if i == M then 3 else 6)
		beam.Width0, beam.Width1 = width, width
	end
	local tangents = table.create(K)
	for i = 1, K do
		tangents[i] = ring[i % K + 1] - ring[(i - 2) % K + 1]
		aim(drawing.ringAttachments[i], ring[i], tangents[i])
	end
	for i = 1, K do
		local beam = drawing.ringBeams[i]
		beam.CurveSize0 = tangents[i].Magnitude / 6
		beam.CurveSize1 = tangents[i % K + 1].Magnitude / 6
		beam.Width0, beam.Width1 = width, width
		local joint = drawing.joints[i]
		joint.Size = Vector3.one * width
		joint.CFrame = CFrame.new(ring[i])
	end
	local knot = rope[M + 1]
	local into = knot - rope[M]
	drawing.nozzle.Size = EmoteLassoConstants.NOZZLE * scale
	-- A cylinder's axis is its X: turned to lie along the rope's last piece.
	drawing.nozzle.CFrame = CFrame.lookAt(knot, knot + (if into.Magnitude > 1e-3 then into.Unit else Vector3.yAxis))
		* CFrame.Angles(0, math.rad(90), 0)
end

local EmoteLassoSystem = {}

function EmoteLassoSystem.new(deps: Deps?): EmoteLassoSystem
	local use = deps or defaultDeps()
	local records: { [Record]: true } = {}
	local tracked = 0
	local disconnect: (() -> ())? = nil

	local function clear(record: Record)
		if record.drawing == nil and record.hidden == nil and not record.state.live then
			return
		end
		local drawing = record.drawing
		record.drawing = nil
		if drawing ~= nil then
			destroy(drawing)
		end
		local hidden = record.hidden
		record.hidden = nil
		if hidden ~= nil then
			hidden.LocalTransparencyModifier = 0
		end
		record.state = EmoteLassoFormulas.newState()
		record.accumulated = 0
	end

	local function update(record: Record, dt: number)
		local character = record.character
		local loop = EmotePropSystem.findProp(character, EmoteLassoConstants.PROP)
		local root = character:FindFirstChild("HumanoidRootPart")
		if loop == nil or root == nil or not root:IsA("BasePart") or loop.Transparency >= 0.5 then
			clear(record)
			return
		end
		if record.hidden ~= loop then
			-- A new copy of the prop (the skin's own replaced the mounted one): give the old one back.
			local old = record.hidden
			if old ~= nil then
				old.LocalTransparencyModifier = 0
			end
			record.hidden = loop
		end
		loop.LocalTransparencyModifier = 1
		local driver = EmoteLassoFormulas.driverOf(loop.CFrame, loop.Size.Y, root.CFrame.LookVector)
		record.accumulated += dt
		local steps = 0
		while record.accumulated >= TUNING.substep and steps < TUNING.maxSubsteps do
			record.state = EmoteLassoFormulas.step(record.state, driver, TUNING.substep, TUNING)
			record.accumulated -= TUNING.substep
			steps += 1
		end
		if steps == TUNING.maxSubsteps then
			-- A long hitch: drop the backlog rather than spiral.
			record.accumulated = 0
		end
		if not record.state.live then
			return
		end
		local drawing = record.drawing or build(use.container)
		record.drawing = drawing
		draw(drawing, record.state, driver.scale)
	end

	local function onFrame(dt: number)
		for record in records do
			update(record, dt)
		end
	end

	return {
		track = function(character)
			local record: Record = {
				character = character,
				state = EmoteLassoFormulas.newState(),
				accumulated = 0,
				drawing = nil,
				hidden = nil,
			}
			records[record] = true
			tracked += 1
			if disconnect == nil then
				disconnect = use.onFrame(onFrame)
			end
			local released = false
			return function()
				if released then
					return
				end
				released = true
				records[record] = nil
				tracked -= 1
				clear(record)
				if next(records) == nil then
					local stop = disconnect
					disconnect = nil
					if stop ~= nil then
						stop()
					end
				end
			end
		end,

		getState = function()
			local drawing = 0
			for record in records do
				if record.drawing ~= nil then
					drawing += 1
				end
			end
			return { tracked = tracked, drawing = drawing }
		end,
	}
end

return EmoteLassoSystem
