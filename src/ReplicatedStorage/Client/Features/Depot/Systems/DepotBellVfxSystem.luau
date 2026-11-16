--!strict
--[=[
	DepotBellVfxSystem: the shift bell's ring on this client (launch VFX 2026-11-16, owner pick B; DepotSpotSystem calls
	`play` on every DepotEvents.Bell, as it swings the bell). One gold ring bursts from the bell's cup (a camera-facing
	BillboardGui, a full-colour image with its edge baked in, so it reads on the hub's dark walls and its yellow floor
	lines), a big "DING!" pops above it, gold soap bubbles float up and a short warm glow lights the bell (skipped on
	low graphics). The glow's PointLight is made at brightness 0, fades up, holds and fades back to 0 before it is
	removed (owner: never snap a light; DepotBellFormulas.glow). One RenderStepped connection drives it all until
	DepotBellFormulas.duration(), then everything is destroyed. Client-local instances.

	Spec-exempt shell (Instances, RunService); the shapes over time are the specced DepotBellFormulas.

	@class DepotBellVfxSystem
]=]

local GuiService = game:GetService("GuiService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local DepotBellFormulas = require(ReplicatedStorage.Client.Features.Depot.Utils.DepotBellFormulas)
local VfxAssets = require(ReplicatedStorage.Shared.Features.Vfx.Data.VfxAssets)
local VfxConstants = require(ReplicatedStorage.Shared.Features.Vfx.Data.VfxConstants)

local T = DepotBellFormulas.TUNING
local GOLD = VfxConstants.PALETTE.gleam
local GOLD_LIGHT = VfxConstants.PALETTE.gleamLight
local GOLD_DEEP = VfxConstants.PALETTE.gleamDeep
-- The Gloom ink: the word's outline (the UI's ink).
local INK = Color3.fromRGB(30, 15, 58)

type Billboard = { host: Part, gui: BillboardGui, image: ImageLabel }

local DepotBellVfxSystem = {}

local function host(folder: Folder, at: Vector3): Part
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Transparency = 1
	part.Size = Vector3.new(0.2, 0.2, 0.2)
	part.CFrame = CFrame.new(at)
	part.Parent = folder
	return part
end

local function billboard(folder: Folder, at: Vector3, texture: string): Billboard
	local part = host(folder, at)
	local gui = Instance.new("BillboardGui")
	gui.LightInfluence = 0
	gui.Enabled = false
	gui.Adornee = part
	gui.Parent = part
	local image = Instance.new("ImageLabel")
	image.BackgroundTransparency = 1
	image.Image = texture
	image.AnchorPoint = Vector2.new(0.5, 0.5)
	image.Position = UDim2.fromScale(0.5, 0.5)
	image.Size = UDim2.fromScale(1, 1)
	image.Parent = gui
	return { host = part, gui = gui, image = image }
end

local function bubbles(folder: Folder, at: Vector3)
	local attachment = Instance.new("Attachment")
	attachment.Parent = host(folder, at)
	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = VfxAssets.TEXTURES.bubble
	emitter.Color = ColorSequence.new(GOLD, GOLD_LIGHT)
	emitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(0.2, 0.55),
		NumberSequenceKeypoint.new(1, 0.4),
	})
	emitter.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(0.8, 0.1),
		NumberSequenceKeypoint.new(1, 1),
	})
	emitter.Lifetime = NumberRange.new(1.1, 1.5)
	emitter.Speed = NumberRange.new(2.5, 4)
	emitter.SpreadAngle = Vector2.new(50, 50)
	emitter.Acceleration = Vector3.new(0, 1.5, 0)
	emitter.Drag = 1.5
	emitter.LightEmission = 0.4
	emitter.LightInfluence = 0
	emitter.Rate = 0
	emitter.Parent = attachment
	emitter:Emit(T.bubbles)
end

local function word(folder: Folder, at: Vector3): (Part, TextLabel, UIStroke)
	local part = host(folder, at)
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromScale(T.wordStuds, T.wordStuds * 0.4)
	gui.LightInfluence = 0
	gui.Adornee = part
	gui.Parent = part
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Text = T.wordText
	label.Font = Enum.Font.LuckiestGuy
	label.TextScaled = true
	label.TextColor3 = Color3.new(1, 1, 1)
	label.AnchorPoint = Vector2.new(0.5, 0.5)
	label.Position = UDim2.fromScale(0.5, 0.5)
	label.Size = UDim2.fromScale(0, 0)
	label.Parent = gui
	local stroke = Instance.new("UIStroke")
	stroke.Color = INK
	stroke.Thickness = 4
	stroke.Parent = label
	local gradient = Instance.new("UIGradient")
	gradient.Color = ColorSequence.new(GOLD_LIGHT, GOLD_DEEP)
	gradient.Rotation = 90
	gradient.Parent = label
	return part, label, stroke
end

--[=[
	Plays the ring at `cup` (world space: the bell's cup, where the rings start).
]=]
function DepotBellVfxSystem.play(cup: Vector3)
	local folder = Instance.new("Folder")
	folder.Name = "BellRing"
	local waves: { Billboard } = {}
	for _ in T.waves do
		table.insert(waves, billboard(folder, cup, VfxAssets.TEXTURES.bellWave))
	end
	local light: PointLight? = nil
	if UserSettings():GetService("UserGameSettings").SavedQualityLevel.Value > VfxConstants.LIGHT_MIN_QUALITY then
		local made = Instance.new("PointLight")
		made.Color = GOLD
		made.Range = T.glowRange
		made.Brightness = 0
		made.Parent = host(folder, cup)
		light = made
	end
	local wordPart: Part?, label: TextLabel?, stroke: UIStroke? = nil, nil, nil
	if T.word then
		wordPart, label, stroke = word(folder, cup + Vector3.new(0, T.wordLift, 0))
	end
	folder.Parent = Workspace
	bubbles(folder, cup)
	local calm = GuiService.ReducedMotionEnabled
	local started = os.clock()
	local connection: RBXScriptConnection
	connection = RunService.RenderStepped:Connect(function()
		local elapsed = os.clock() - started
		for index, wave in waves do
			local shape = DepotBellFormulas.wave(index, elapsed)
			wave.gui.Enabled = shape.live
			wave.gui.Size = UDim2.fromScale(shape.studs, shape.studs)
			wave.image.ImageTransparency = shape.transparency
		end
		if light ~= nil then
			light.Brightness = DepotBellFormulas.glow(elapsed)
		end
		if wordPart ~= nil and label ~= nil and stroke ~= nil then
			local shape = DepotBellFormulas.word(elapsed)
			label.Size = UDim2.fromScale(shape.scale, shape.scale)
			label.Rotation = if calm then 0 else shape.rotation
			label.TextTransparency = shape.transparency
			stroke.Transparency = shape.transparency
			wordPart.CFrame = CFrame.new(cup + Vector3.new(0, T.wordLift + shape.rise, 0))
		end
		if elapsed >= DepotBellFormulas.duration() + 1.5 or folder.Parent == nil then
			connection:Disconnect()
			folder:Destroy()
		end
	end)
end

return DepotBellVfxSystem
