--!strict
--[=[
	EmoteVfxSystem: the Legendary emotes' effects on this client, started and ended by EmoteEffectSystem from the
	clip's markers (EmoteEffectRegistry). `start(id, character, value)` returns how to end the effect, or nil.
	- bubbleStream: soap bubbles pour from the BubbleWand's loop, away from her face; ends by letting the last ones
	  drift off.
	- giantBubble: a giant bubble grows from the wand loop round her body and rides her LowerTorso (the clip lifts
	  it), wobbling and shedding small bubbles; ending it pops it (emoteBubblePop), also when the emote is cut short.
	- bubbleLand: a splash of bubbles at her feet.
	- lassoPuff, lassoThrow, dustSwirl, tumbleweed: Big Roundup's dust (the coil shaking out and the yank, the throw,
	  a dust ring orbiting his feet under the spin) and one tumbleweed rolling past in front of him.
	- face: the FacePlate wears the `Faces` folder's expression named by the marker's value; ending it puts the
	  gameplay face (the EmployeeFace attribute) back.
	Everything is client-local (nothing replicates) and sized by the character's scale. Presets and numbers:
	EmoteVfxConstants.

	Spec-exempt shell (Instances, RunService, VfxBurstSystem over live characters); the marker logic is the specced
	EmoteEffectSystem and the numbers the specced EmoteVfxConstants.

	@class EmoteVfxSystem
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local EmployeeConstants = require(ReplicatedStorage.Shared.Features.Employee.Data.EmployeeConstants)
local EmployeeRegistry = require(ReplicatedStorage.Shared.Features.Employee.Data.EmployeeRegistry)
local VfxBurstRegistry = require(ReplicatedStorage.Shared.Features.Vfx.Data.VfxBurstRegistry)
local VfxTypes = require(ReplicatedStorage.Shared.Features.Vfx.Data.VfxTypes)
local EmployeeFaceSystem = require(ReplicatedStorage.Client.Features.Employee.Systems.EmployeeFaceSystem)
local EmoteVfxConstants = require(ReplicatedStorage.Client.Features.Emote.Data.EmoteVfxConstants)
local EmotePropSystem = require(ReplicatedStorage.Client.Features.Emote.Systems.EmotePropSystem)
local VfxBurstSystem = require(ReplicatedStorage.Client.Features.Vfx.Systems.VfxBurstSystem)

-- Registered at load: VfxBurstSystem refuses an unknown burst.
for id, preset in EmoteVfxConstants.PRESETS do
	if not VfxBurstRegistry.has(id) then
		VfxBurstRegistry.register(id, preset)
	end
end

local STREAM = EmoteVfxConstants.STREAM
local GIANT = EmoteVfxConstants.GIANT

local EmoteVfxSystem = {}

local function part(character: Model, name: string): BasePart?
	local found = character:FindFirstChild(name)
	return if found ~= nil and found:IsA("BasePart") then found else nil
end

-- The skin's wand, else the emote's own mounted copy.
local function wand(character: Model): BasePart?
	return EmotePropSystem.findProp(character, "BubbleWand")
end

-- The wand loop's world position.
local function loopOf(wandPart: BasePart): Vector3
	return (wandPart.CFrame * CFrame.new(0, STREAM.loopHeight * wandPart.Size.Y, 0)).Position
end

-- `sequence` with every value and envelope times `scale` (particle sizes follow the character's size).
local function scaled(sequence: NumberSequence, scale: number): NumberSequence
	local points: { NumberSequenceKeypoint } = {}
	for _, point in sequence.Keypoints do
		table.insert(points, NumberSequenceKeypoint.new(point.Time, point.Value * scale, point.Envelope * scale))
	end
	return NumberSequence.new(points)
end

-- An emitter's rate for this client's graphics quality (1..10).
local function rate(high: number, low: number): number
	local level = VfxBurstSystem.quality()
	return low + (high - low) * math.clamp((level - 1) / 9, 0, 1)
end

local function streamLayer(): VfxTypes.BurstLayer
	return {
		texture = STREAM.texture,
		color = STREAM.color,
		size = STREAM.size,
		transparency = STREAM.transparency,
		lifetime = STREAM.lifetime,
		speed = STREAM.speed,
		rate = STREAM.rateHigh,
		spread = STREAM.spread,
		direction = Enum.NormalId.Front,
		acceleration = STREAM.acceleration,
		drag = STREAM.drag,
		rotation = NumberRange.new(0, 360),
		rotSpeed = STREAM.rotSpeed,
		lightInfluence = 0,
	}
end

local function bubbleStream(character: Model): (() -> ())?
	local wandPart = wand(character)
	local head = part(character, "Head")
	if wandPart == nil or head == nil then
		return nil
	end
	local scale = character:GetScale()
	local anchor = Instance.new("Attachment")
	anchor.Name = "EmoteBubbleStream"
	local emitter = Instance.new("ParticleEmitter")
	VfxBurstSystem.configure(emitter, streamLayer())
	emitter.Size = scaled(STREAM.size, scale)
	emitter.Rate = rate(STREAM.rateHigh, STREAM.rateLow)
	emitter.Enabled = true
	emitter.Parent = anchor
	anchor.Parent = wandPart
	-- Aim the stream from her mouth through the loop, every frame (the wand moves with the clip).
	local follow = RunService.RenderStepped:Connect(function()
		if wandPart.Parent == nil then
			return
		end
		local loop = loopOf(wandPart)
		local away = loop - head.Position
		if away.Magnitude > 1e-3 then
			anchor.WorldCFrame = CFrame.lookAt(loop, loop + away)
		end
	end)
	return function()
		follow:Disconnect()
		emitter.Enabled = false
		task.delay(STREAM.lifetime.Max, function()
			anchor:Destroy()
		end)
	end
end

local function giantBubble(character: Model): (() -> ())?
	local lower = part(character, "LowerTorso")
	local wandPart = wand(character)
	if lower == nil then
		return nil
	end
	local scale = character:GetScale()
	local diameter = GIANT.diameter * scale
	local rest = CFrame.new(0, GIANT.lift * scale, 0)
	local from = if wandPart ~= nil then lower.CFrame:ToObjectSpace(CFrame.new(loopOf(wandPart))) else rest

	local ball = Instance.new("Part")
	ball.Name = "EmoteGiantBubble"
	ball.Shape = Enum.PartType.Ball
	ball.Material = Enum.Material.ForceField
	ball.Color = GIANT.shimmer
	ball.CastShadow = false
	ball.CanCollide, ball.CanQuery, ball.CanTouch, ball.Massless, ball.Anchored = false, false, false, true, false
	ball.Size = Vector3.one * 0.2
	ball.CFrame = lower.CFrame * from
	local weld = Instance.new("Weld")
	weld.Part0 = lower
	weld.Part1 = ball
	weld.C0 = from
	weld.Parent = ball

	local face = Instance.new("BillboardGui")
	face.Name = "Face"
	face.Adornee = ball
	face.LightInfluence = 0
	face.Size = UDim2.fromScale(0.2, 0.2)
	local image = Instance.new("ImageLabel")
	image.BackgroundTransparency = 1
	image.Size = UDim2.fromScale(1, 1)
	image.Image = GIANT.texture
	image.Parent = face
	face.Parent = ball

	local shedAnchor = Instance.new("Attachment")
	local shed = Instance.new("ParticleEmitter")
	VfxBurstSystem.configure(shed, streamLayer())
	shed.Shape = Enum.ParticleEmitterShape.Sphere
	shed.ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface
	shed.ShapeInOut = Enum.ParticleEmitterShapeInOut.Outward
	shed.Speed = NumberRange.new(0.5, 1.5)
	shed.Size = scaled(STREAM.size, scale * 0.8)
	shed.Rate = rate(GIANT.shedRate, 2)
	shed.Enabled = false
	shed.Parent = shedAnchor
	shedAnchor.Parent = ball
	ball.Parent = character

	local started = os.clock()
	local step = RunService.RenderStepped:Connect(function()
		local t = os.clock() - started
		local grow = math.clamp(t / GIANT.growSeconds, 0, 1)
		local eased = TweenService:GetValue(grow, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
		local wobble = if grow >= 1
			then GIANT.wobble * math.sin(2 * math.pi * (t - GIANT.growSeconds) / GIANT.wobblePeriod)
			else 0
		local size = math.max(0.2, diameter * eased)
		weld.C0 = from:Lerp(rest, math.clamp(eased, 0, 1))
		ball.Size = Vector3.one * size * (1 + wobble)
		face.Size = UDim2.fromScale(size * (1 + wobble), size * (1 - wobble))
		shed.Enabled = grow >= 1
	end)
	return function()
		step:Disconnect()
		if ball.Parent ~= nil then
			VfxBurstSystem.play("emoteBubblePop", ball.Position, { scale = ball.Size.X / 6.5 })
		end
		ball:Destroy()
	end
end

local function feetOf(character: Model): (Vector3?, BasePart?)
	local root = part(character, "HumanoidRootPart")
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if root == nil or humanoid == nil then
		return nil, nil
	end
	return root.Position - Vector3.new(0, humanoid.HipHeight + root.Size.Y / 2, 0), root
end

local function bubbleLand(character: Model): (() -> ())?
	local feet = feetOf(character)
	if feet ~= nil then
		VfxBurstSystem.play("emoteBubbleLand", feet, { scale = character:GetScale() })
	end
	return nil
end

local function lassoPuff(character: Model): (() -> ())?
	local hand = part(character, "RightHand")
	if hand ~= nil then
		VfxBurstSystem.play("emoteLassoPuff", hand.Position, { scale = character:GetScale() })
	end
	return nil
end

local function lassoThrow(character: Model): (() -> ())?
	local hand = part(character, "RightHand")
	local _, root = feetOf(character)
	if hand ~= nil and root ~= nil then
		VfxBurstSystem.play("emoteLassoThrow", CFrame.lookAt(hand.Position, hand.Position + root.CFrame.LookVector), {
			scale = character:GetScale(),
		})
	end
	return nil
end

local function dustSwirl(character: Model): (() -> ())?
	local feet, root = feetOf(character)
	if feet == nil or root == nil then
		return nil
	end
	local dust = EmoteVfxConstants.DUST_SWIRL
	local scale = character:GetScale()
	local anchor = Instance.new("Attachment")
	anchor.Name = "EmoteDustSwirl"
	local emitter = Instance.new("ParticleEmitter")
	VfxBurstSystem.configure(emitter, {
		texture = dust.texture,
		color = dust.color,
		size = scaled(dust.size, scale),
		transparency = dust.transparency,
		lifetime = dust.lifetime,
		speed = dust.speed,
		rate = dust.rateHigh,
		spread = Vector2.new(30, 30),
		rotation = NumberRange.new(0, 360),
		rotSpeed = NumberRange.new(-40, 40),
		lightInfluence = 0.6,
	})
	emitter.Rate = rate(dust.rateHigh, dust.rateLow)
	emitter.Enabled = true
	emitter.Parent = anchor
	anchor.Parent = root
	local started = os.clock()
	local orbit = RunService.RenderStepped:Connect(function()
		local here = feetOf(character)
		if here == nil then
			return
		end
		local angle = 2 * math.pi * dust.turns * (os.clock() - started)
		local offset = Vector3.new(math.cos(angle), 0, -math.sin(angle)) * dust.radius * scale
		anchor.WorldPosition = here + offset + Vector3.new(0, dust.height * scale, 0)
	end)
	return function()
		orbit:Disconnect()
		emitter.Enabled = false
		task.delay(dust.lifetime.Max, function()
			anchor:Destroy()
		end)
	end
end

local function tumbleweed(character: Model): (() -> ())?
	local feet, root = feetOf(character)
	if feet == nil or root == nil then
		return nil
	end
	local scale = character:GetScale()
	local spec = EmoteVfxConstants.TUMBLEWEED
	local right = root.CFrame.RightVector
	local ahead = root.CFrame.LookVector * 2 * scale
	local start = feet + ahead - right * spec.from * scale + Vector3.new(0, spec.height * scale, 0)
	VfxBurstSystem.play("emoteTumbleweed", CFrame.lookAt(start, start + right), { scale = scale })
	return nil
end

local function face(character: Model, name: string): (() -> ())?
	local plate = part(character, EmployeeConstants.FACE_PLATE)
	local faces = character:FindFirstChild(EmployeeConstants.FACES_FOLDER)
	local source = if faces ~= nil then faces:FindFirstChild(name) else nil
	if plate == nil or source == nil or not source:IsA("SurfaceAppearance") then
		return nil
	end
	local copy = source:Clone()
	copy.Name = EmployeeConstants.FACE_APPEARANCE
	-- Marked, so EmployeeFaceSystem.bind does not take it for a re-replicated authored face and put it back.
	copy:SetAttribute(EmployeeConstants.FACE_ATTRIBUTE, name)
	for _, child in plate:GetChildren() do
		if child:IsA("SurfaceAppearance") then
			child:Destroy()
		end
	end
	copy.Parent = plate
	return function()
		local gameplay: EmployeeRegistry.Face? =
			EmployeeRegistry.toFace(character:GetAttribute(EmployeeConstants.FACE_ATTRIBUTE))
		if gameplay ~= nil then
			EmployeeFaceSystem.apply(character, gameplay, true)
		end
	end
end

--[=[
	Starts effect `id` on `character` (EmoteEffectSystem's `start`); returns how to end it, or nil.
]=]
function EmoteVfxSystem.start(id: string, character: Model, value: string): (() -> ())?
	if id == "bubbleStream" then
		return bubbleStream(character)
	elseif id == "giantBubble" then
		return giantBubble(character)
	elseif id == "bubbleLand" then
		return bubbleLand(character)
	elseif id == "lassoPuff" then
		return lassoPuff(character)
	elseif id == "lassoThrow" then
		return lassoThrow(character)
	elseif id == "dustSwirl" then
		return dustSwirl(character)
	elseif id == "tumbleweed" then
		return tumbleweed(character)
	elseif id == "face" then
		return face(character, value)
	end
	return nil
end

return EmoteVfxSystem
