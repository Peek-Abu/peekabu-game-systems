--!strict
--[=[
	VfxBurstSystem: plays code-built particle bursts (VfxBurstRegistry) on this client.

	- `play(id, at, options?)` — a one-shot burst at a CFrame or point: a rig (an Attachment on Terrain with one
	  emitter per layer, set up once) is taken from VfxEmitterPool, moved there, and each layer Emits its count
	  (thinned by graphics quality, VfxFormulas.burstCount) after its delay; an optional warm light rises in 0.03 s and
	  fades over its seconds. The rig goes back to the pool when its last particle has died. `options.scale` sizes the
	  particles and their speed (a bigger pile throws further); `options.amount` scales the counts.
	- `configure(emitter, layer)`, `quality()`, `burst(id)` — the layer setup, the graphics level and the warned
	  lookup the streams share (VfxFunnelSystem pours the `rate` layers).
	- `polished()` — false while the Workspace attribute VfxConstants.LEGACY_ATTRIBUTE is true: features then play
	  their pre-polish particles (the A/B switch).

	Everything is world-space and played on every client that sees the moment (observers included), skipped beyond
	the burst's maxDistance from the camera. Screen-space effects are not this system's. `preload()` starts loading the
	textures when a feature starts, so no first burst is blank.

	Spec-exempt shell (Instances, TweenService, RunService); the budget and the maths are the specced
	VfxBurstRegistry, VfxFormulas and VfxEmitterPool.

	@class VfxBurstSystem
]=]

local ContentProvider = game:GetService("ContentProvider")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local VfxShared = ReplicatedStorage.Shared.Features.Vfx
local Logger = require(ReplicatedStorage.Shared.Core.Logger)
local VfxTypes = require(VfxShared.Data.VfxTypes)
local VfxAssets = require(VfxShared.Data.VfxAssets)
local VfxConstants = require(VfxShared.Data.VfxConstants)
local VfxBurstRegistry = require(VfxShared.Data.VfxBurstRegistry)
local VfxFormulas = require(VfxShared.Utils.VfxFormulas)
local VfxEmitterPool = require(ReplicatedStorage.Client.Features.Vfx.State.VfxEmitterPool)

type Burst = VfxTypes.Burst
type BurstLayer = VfxTypes.BurstLayer
type BurstLight = VfxTypes.BurstLight

type Rig = {
	anchor: Attachment,
	emitters: { ParticleEmitter },
	scale: number,
	-- Bumped every play: a stale return-to-pool timer sees a different value and leaves the rig alone.
	generation: number,
}

export type PlayOptions = {
	scale: number?,
	amount: number?,
}

export type VfxBurstState = {
	polished: boolean,
	playing: number,
	idle: number,
	lights: number,
	counters: { [string]: number },
}

local log = Logger.new("VfxBurstSystem")

local MAX_LIGHTS = 6

local burstPool = VfxEmitterPool.new(VfxConstants.POOL_CAPACITY, function(rig: Rig)
	rig.anchor:Destroy()
end)
local playing: { [Rig]: boolean } = {}
local warned: { [string]: boolean } = {}
local lights = 0
local counters = { played = 0, skipped = 0, unknown = 0 }
local preloaded = false

local function quality(): number
	return UserSettings():GetService("UserGameSettings").SavedQualityLevel.Value
end

local function cameraDistance(position: Vector3): number
	local camera = Workspace.CurrentCamera
	return if camera ~= nil then (camera.CFrame.Position - position).Magnitude else 0
end

local function scaled(sequence: NumberSequence, scale: number): NumberSequence
	if scale == 1 then
		return sequence
	end
	local points: { NumberSequenceKeypoint } = {}
	for _, point in sequence.Keypoints do
		table.insert(points, NumberSequenceKeypoint.new(point.Time, point.Value * scale, point.Envelope * scale))
	end
	return NumberSequence.new(points)
end

local function configure(emitter: ParticleEmitter, layer: BurstLayer)
	emitter.Texture = layer.texture
	emitter.Color = layer.color
	emitter.Size = layer.size
	emitter.Transparency = layer.transparency
	emitter.Lifetime = layer.lifetime
	emitter.Speed = layer.speed
	emitter.SpreadAngle = layer.spread or Vector2.zero
	emitter.EmissionDirection = layer.direction or Enum.NormalId.Top
	emitter.Acceleration = layer.acceleration or Vector3.zero
	emitter.Drag = layer.drag or 0
	emitter.Rotation = layer.rotation or NumberRange.new(0)
	emitter.RotSpeed = layer.rotSpeed or NumberRange.new(0)
	emitter.Squash = layer.squash or NumberSequence.new(0)
	emitter.LightEmission = layer.lightEmission or 0
	emitter.LightInfluence = layer.lightInfluence or 1
	emitter.Brightness = layer.brightness or 1
	emitter.ZOffset = layer.zOffset or 0
	emitter.Orientation = layer.orientation or Enum.ParticleOrientation.FacingCamera
	emitter.Rate = 0
end

local function buildRig(id: string, burst: Burst): Rig
	local anchor = Instance.new("Attachment")
	anchor.Name = `VfxBurst_{id}`
	local emitters: { ParticleEmitter } = {}
	for index, layer in burst.layers do
		local emitter = Instance.new("ParticleEmitter")
		emitter.Name = `Layer{index}`
		configure(emitter, layer)
		emitter.Enabled = false
		emitter.Parent = anchor
		table.insert(emitters, emitter)
	end
	anchor.Parent = Workspace.Terrain
	return { anchor = anchor, emitters = emitters, scale = 1, generation = 0 }
end

local function rescale(rig: Rig, burst: Burst, scale: number)
	if rig.scale == scale then
		return
	end
	for index, layer in burst.layers do
		local emitter = rig.emitters[index]
		emitter.Size = scaled(layer.size, scale)
		emitter.Speed = NumberRange.new(layer.speed.Min * scale, layer.speed.Max * scale)
	end
	rig.scale = scale
end

-- One warm light: up in 0.03 s, down over its seconds, then gone. Never destroyed while lit.
local function flash(parent: Attachment, light: BurstLight)
	local level = quality()
	if (level > 0 and level <= VfxConstants.LIGHT_MIN_QUALITY) or lights >= MAX_LIGHTS then
		return
	end
	lights += 1
	local point = Instance.new("PointLight")
	point.Color = light.color
	point.Range = light.range
	point.Shadows = false
	point.Brightness = 0
	point.Parent = parent
	TweenService:Create(point, TweenInfo.new(0.03), { Brightness = light.brightness }):Play()
	task.delay(0.03, function()
		TweenService:Create(
			point,
			TweenInfo.new(light.seconds, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ Brightness = 0 }
		):Play()
	end)
	task.delay(0.05 + light.seconds, function()
		lights -= 1
		point:Destroy()
	end)
end

local function getBurst(id: string): Burst?
	local burst = VfxBurstRegistry.get(id)
	if burst == nil then
		counters.unknown += 1
		if not warned[id] then
			warned[id] = true
			log:warn(`unknown vfx burst "{id}"`)
		end
	end
	return burst
end

local VfxBurstSystem = {}

--[=[
	Sets an emitter up as a burst layer (every property the layer names, the engine's default for the rest).
]=]
function VfxBurstSystem.configure(emitter: ParticleEmitter, layer: BurstLayer)
	configure(emitter, layer)
end

--[=[
	This client's graphics quality level (0 = Automatic, else 1..10).
]=]
function VfxBurstSystem.quality(): number
	return quality()
end

--[=[
	The registered burst `id`, or nil (counted and warned once per id).
]=]
function VfxBurstSystem.burst(id: string): Burst?
	return getBurst(id)
end

--[=[
	Starts loading every particle texture (once, in the background), so a burst's first play is not blank while its
	texture downloads. Features call it when they start.
]=]
function VfxBurstSystem.preload()
	if preloaded then
		return
	end
	preloaded = true
	local ids: { string } = {}
	-- Iterating the frozen record types its values as unknown; each is checked back to a string.
	for _, id in VfxAssets.TEXTURES do
		if type(id) == "string" then
			table.insert(ids, id)
		end
	end
	task.spawn(function()
		ContentProvider:PreloadAsync(ids)
	end)
end

--[=[
	Whether features play the polished bursts (true) or their pre-polish particles (the A/B switch is on).
]=]
function VfxBurstSystem.polished(): boolean
	return Workspace:GetAttribute(VfxConstants.LEGACY_ATTRIBUTE) ~= true
end

--[=[
	Plays burst `id` at `at` (a CFrame orients the layers' emission direction; a point emits along world +Y).
	False for an unknown id or one too far from the camera.
]=]
function VfxBurstSystem.play(id: string, at: CFrame | Vector3, options: PlayOptions?): boolean
	local burst = getBurst(id)
	if burst == nil then
		return false
	end
	local cframe = if typeof(at) == "CFrame" then at else CFrame.new(at)
	if cameraDistance(cframe.Position) > (burst.maxDistance or VfxConstants.DEFAULT_BURST_DISTANCE) then
		counters.skipped += 1
		return false
	end
	local scale = if options ~= nil and options.scale ~= nil then math.max(options.scale, 0.05) else 1
	local amount = if options ~= nil and options.amount ~= nil then math.max(options.amount, 0) else 1
	local rig = burstPool:acquire(id, function()
		return buildRig(id, burst)
	end)
	rig.generation += 1
	local generation = rig.generation
	rig.anchor.Parent = Workspace.Terrain
	rig.anchor.WorldCFrame = cframe
	rescale(rig, burst, scale)
	local level = quality()
	for index, layer in burst.layers do
		local count = layer.count
		if count ~= nil then
			local emitter = rig.emitters[index]
			local emitCount = VfxFormulas.burstCount(count * amount, level)
			local delay = layer.delay or 0
			if delay > 0 then
				task.delay(delay, function()
					if rig.generation == generation and emitter.Parent ~= nil then
						emitter:Emit(emitCount)
					end
				end)
			else
				emitter:Emit(emitCount)
			end
		end
	end
	local light = burst.light
	if light ~= nil then
		flash(rig.anchor, light)
	end
	playing[rig] = true
	counters.played += 1
	task.delay(VfxBurstRegistry.tail(burst) + 0.1, function()
		if rig.generation == generation and playing[rig] then
			playing[rig] = nil
			burstPool:release(id, rig)
		end
	end)
	return true
end

--[=[
	Ends every burst at once (the client shutting the system down): every live rig is destroyed.
]=]
function VfxBurstSystem.stop()
	for rig in playing do
		rig.anchor:Destroy()
	end
	table.clear(playing)
	burstPool:clear()
end

function VfxBurstSystem.getState(): VfxBurstState
	local live = 0
	for _ in playing do
		live += 1
	end
	return {
		polished = VfxBurstSystem.polished(),
		playing = live,
		idle = burstPool:idle(),
		lights = lights,
		counters = table.clone(counters),
	}
end

return VfxBurstSystem
