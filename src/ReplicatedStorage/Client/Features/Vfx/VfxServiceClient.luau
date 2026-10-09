--!strict
--[=[
	VfxServiceClient: effect recipes, screen effects and atmosphere on this client (design:
	docs/superpowers/specs/2026-10-09-vfx-design.md).

	- `play(id, at)` — clones the recipe's template onto an anchor at `at` (a CFrame, Vector3, part or
	  attachment), bursts / runs its emitters and lights, plays its sound and shakes the camera by
	  distance; cleans itself up.
	- `requestScreen(request)` → token, `updateScreen(token, request)`, `releaseScreen(token)` — combined
	  blur / colour correction / depth of field, eased each frame.
	- `setAtmosphere(id?, fade?)` — blends Lighting to a preset, or back to the place's own values.
	- Owns the UI's `blur` suppression seam and listens for the server's VfxEvents.

	Spec-exempt shell (Instances, Lighting, RunService, ByteNet); the rules live in VfxFormulas, the
	registries and VfxScreenTracker.

	@class VfxServiceClient
]=]

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local VfxShared = ReplicatedStorage.Shared.Features.Vfx
local Logger = require(ReplicatedStorage.Shared.Core.Logger)
local VfxTypes = require(VfxShared.Data.VfxTypes)
local VfxConstants = require(VfxShared.Data.VfxConstants)
local VfxRecipeRegistry = require(VfxShared.Data.VfxRecipeRegistry)
local VfxAtmosphereRegistry = require(VfxShared.Data.VfxAtmosphereRegistry)
local VfxFormulas = require(VfxShared.Utils.VfxFormulas)
local VfxEvents = require(VfxShared.Net.VfxEvents)
local VfxScreenTracker = require(ReplicatedStorage.Client.Features.Vfx.State.VfxScreenTracker)
local SoundServiceClient = require(ReplicatedStorage.Client.Features.Sound.SoundServiceClient)
local CameraServiceClient = require(ReplicatedStorage.Client.Features.Camera.CameraServiceClient)
local UISuppression = require(ReplicatedStorage.Client.UI.Suppression.UISuppression)

type ScreenState = VfxTypes.ScreenState
type AtmosphereValues = VfxTypes.AtmosphereValues

export type PlayAt = CFrame | Vector3 | BasePart | Attachment

local log = Logger.new("VfxServiceClient")

local screens = VfxScreenTracker.new()
local screenApplied: ScreenState = VfxFormulas.combineScreen({})
local blurEffect: BlurEffect? = nil
local colorEffect: ColorCorrectionEffect? = nil
local depthEffect: DepthOfFieldEffect? = nil

-- The place's own Lighting values (captured at start), the values currently applied, and the blend.
local atmosphereBase: AtmosphereValues? = nil
local atmosphereFrom: AtmosphereValues? = nil
local atmosphereTo: AtmosphereValues? = nil
local atmosphereElapsed = 0
local atmosphereFade = 0
local atmosphereId: string? = nil

local warnedTemplates: { [string]: boolean } = {}
local counters = { played = 0, unknown = 0, missingTemplates = 0 }
local connection: RBXScriptConnection? = nil

local function readLighting(): AtmosphereValues
	return {
		clockTime = Lighting.ClockTime,
		brightness = Lighting.Brightness,
		exposure = Lighting.ExposureCompensation,
		ambient = Lighting.Ambient,
		outdoorAmbient = Lighting.OutdoorAmbient,
		fogColor = Lighting.FogColor,
		fogStart = Lighting.FogStart,
		fogEnd = Lighting.FogEnd,
	}
end

local function writeLighting(values: AtmosphereValues)
	Lighting.ClockTime = values.clockTime
	Lighting.Brightness = values.brightness
	Lighting.ExposureCompensation = values.exposure
	Lighting.Ambient = values.ambient
	Lighting.OutdoorAmbient = values.outdoorAmbient
	Lighting.FogColor = values.fogColor
	Lighting.FogStart = values.fogStart
	Lighting.FogEnd = values.fogEnd
end

local function templateFolder(name: string): Instance?
	local assets = ReplicatedStorage:FindFirstChild(VfxConstants.ASSETS_FOLDER)
	local folder = if assets ~= nil then assets:FindFirstChild(VfxConstants.TEMPLATE_FOLDER) else nil
	return if folder ~= nil then folder:FindFirstChild(name) else nil
end

-- An Attachment to hang the effect on, and the world position it sits at.
local function anchorFor(at: PlayAt): (Attachment, Vector3)
	local anchor = Instance.new("Attachment")
	anchor.Name = "VfxAnchor"
	if typeof(at) == "CFrame" then
		anchor.WorldCFrame = at
		anchor.Parent = Workspace.Terrain
	elseif typeof(at) == "Vector3" then
		anchor.WorldPosition = at
		anchor.Parent = Workspace.Terrain
	elseif at:IsA("Attachment") then
		anchor.Parent = at
	else
		anchor.Parent = at
	end
	return anchor, anchor.WorldPosition
end

-- Starts every emitter and light under the anchor; returns how long until the last particle has died.
local function ignite(anchor: Attachment, lifetime: number): number
	local tail = lifetime
	for _, descendant in anchor:GetDescendants() do
		if descendant:IsA("ParticleEmitter") then
			tail = math.max(tail, descendant.Lifetime.Max)
			local count = descendant:GetAttribute(VfxConstants.EMIT_COUNT_ATTRIBUTE)
			if type(count) == "number" and count > 0 then
				descendant.Enabled = false
				descendant:Emit(count)
			else
				descendant.Enabled = true
				task.delay(lifetime, function()
					descendant.Enabled = false
				end)
				tail = math.max(tail, lifetime + descendant.Lifetime.Max)
			end
		elseif descendant:IsA("Light") then
			descendant.Enabled = true
			task.delay(lifetime, function()
				descendant.Enabled = false
			end)
		end
	end
	return tail
end

local function ensureScreenEffects(): (BlurEffect, ColorCorrectionEffect, DepthOfFieldEffect)?
	local camera = Workspace.CurrentCamera
	if camera == nil then
		return nil
	end
	local blur = blurEffect
	if blur == nil or blur.Parent ~= camera then
		blur = Instance.new("BlurEffect")
		blur.Name = "VfxBlur"
		blur.Size = 0
		blur.Parent = camera
		blurEffect = blur
	end
	local color = colorEffect
	if color == nil or color.Parent ~= camera then
		color = Instance.new("ColorCorrectionEffect")
		color.Name = "VfxColor"
		color.Parent = camera
		colorEffect = color
	end
	local depth = depthEffect
	if depth == nil or depth.Parent ~= camera then
		depth = Instance.new("DepthOfFieldEffect")
		depth.Name = "VfxDepth"
		depth.FarIntensity = 0
		depth.NearIntensity = 0
		depth.Parent = camera
		depthEffect = depth
	end
	return blur, color, depth
end

local function stepScreen(dt: number)
	local target = VfxFormulas.combineScreen(screens:list())
	local alpha = 1 - math.exp(-VfxConstants.SCREEN_SHARPNESS * dt)
	screenApplied = VfxFormulas.lerpScreen(screenApplied, target, alpha)
	local blur, color, depth = ensureScreenEffects()
	if blur == nil or color == nil or depth == nil then
		return
	end
	blur.Size = screenApplied.blur
	blur.Enabled = screenApplied.blur > 0.05
	color.Brightness = screenApplied.brightness
	color.Contrast = screenApplied.contrast
	color.Saturation = screenApplied.saturation
	color.TintColor = screenApplied.tint
	depth.FarIntensity = screenApplied.depthOfField
	depth.Enabled = screenApplied.depthOfField > 0.005
end

local function stepAtmosphere(dt: number)
	local from, to = atmosphereFrom, atmosphereTo
	if from == nil or to == nil then
		return
	end
	atmosphereElapsed += dt
	local alpha = if atmosphereFade > 0 then atmosphereElapsed / atmosphereFade else 1
	writeLighting(VfxFormulas.blendAtmosphere(from, to, alpha))
	if alpha >= 1 then
		atmosphereFrom = nil
		atmosphereTo = nil
	end
end

export type VfxServiceClient = {
	dependencies: { string },
	start: (self: VfxServiceClient) -> (),
	stop: (self: VfxServiceClient) -> (),
	getState: (self: VfxServiceClient) -> { [string]: any },

	play: (self: VfxServiceClient, id: string, at: PlayAt) -> boolean,
	requestScreen: (self: VfxServiceClient, request: VfxTypes.ScreenRequest) -> number,
	updateScreen: (self: VfxServiceClient, token: number, request: VfxTypes.ScreenRequest) -> boolean,
	releaseScreen: (self: VfxServiceClient, token: number) -> boolean,
	setAtmosphere: (self: VfxServiceClient, id: string?, fade: number?) -> boolean,
}

local VfxServiceClient: VfxServiceClient = {
	dependencies = { "SoundServiceClient", "CameraServiceClient" },

	--[=[
		Captures the place's Lighting as the atmosphere base, starts the per-frame easing, takes over the
		UI `blur` seam, and listens for server requests.
	]=]
	start = function(self)
		atmosphereBase = readLighting()
		connection = RunService.RenderStepped:Connect(function(dt)
			stepScreen(dt)
			stepAtmosphere(dt)
		end)

		local blurToken: number? = nil
		UISuppression.registerHandler("blur", {
			engage = function()
				blurToken = self:requestScreen({ blur = VfxConstants.UI_BLUR_SIZE })
			end,
			disengage = function()
				local token = blurToken
				if token ~= nil then
					self:releaseScreen(token)
					blurToken = nil
				end
			end,
		})

		VfxEvents.packets.PlayRecipe.listen(function(data)
			self:play(data.id, data.cframe)
		end)
		VfxEvents.packets.SetAtmosphere.listen(function(data)
			self:setAtmosphere(data.id, data.fade)
		end)
	end,

	stop = function(_self)
		local current = connection
		if current ~= nil then
			current:Disconnect()
			connection = nil
		end
		local base = atmosphereBase
		if base ~= nil then
			writeLighting(base)
		end
	end,

	--[=[
		Plays a registered recipe at `at`. False (and a warning) for an unknown id; a missing template
		still plays the recipe's sound and shake, and warns once.
	]=]
	play = function(_self, id, at)
		local recipe = VfxRecipeRegistry.get(id)
		if recipe == nil then
			counters.unknown += 1
			log:warn(`unknown vfx recipe "{id}"`)
			return false
		end
		local anchor, position = anchorFor(at)
		local template = templateFolder(recipe.template)
		if template ~= nil then
			for _, child in template:GetChildren() do
				child:Clone().Parent = anchor
			end
		elseif not warnedTemplates[recipe.template] then
			warnedTemplates[recipe.template] = true
			counters.missingTemplates += 1
			log:warn(`vfx template "{recipe.template}" not found under ReplicatedStorage.Assets.Vfx`)
		end
		local tail = ignite(anchor, recipe.lifetime)
		task.delay(tail, function()
			anchor:Destroy()
		end)

		local sound = recipe.sound
		if sound ~= nil then
			SoundServiceClient:play(sound, { at = position })
		end
		local trauma, radius = recipe.trauma, recipe.shakeRadius
		local camera = Workspace.CurrentCamera
		if trauma ~= nil and radius ~= nil and camera ~= nil then
			local distance = (camera.CFrame.Position - position).Magnitude
			CameraServiceClient:addTrauma(VfxFormulas.traumaAtDistance(trauma, distance, radius))
		end
		counters.played += 1
		return true
	end,

	requestScreen = function(_self, request)
		return screens:add(request)
	end,

	updateScreen = function(_self, token, request)
		return screens:update(token, request)
	end,

	releaseScreen = function(_self, token)
		return screens:remove(token)
	end,

	--[=[
		Blends Lighting to a registered preset (or back to the place's own values with nil) over `fade`
		seconds. False for an unknown id.
	]=]
	setAtmosphere = function(_self, id, fade)
		local base = atmosphereBase
		if base == nil then
			base = readLighting()
			atmosphereBase = base
		end
		local preset = nil
		if id ~= nil then
			preset = VfxAtmosphereRegistry.get(id)
			if preset == nil then
				log:warn(`unknown atmosphere "{id}"`)
				return false
			end
		end
		atmosphereFrom = readLighting()
		atmosphereTo = VfxFormulas.resolveAtmosphere(base, preset)
		atmosphereElapsed = 0
		atmosphereFade = fade or VfxConstants.DEFAULT_ATMOSPHERE_FADE
		atmosphereId = id
		return true
	end,

	getState = function(_self)
		return {
			screenRequests = #screens:list(),
			blur = screenApplied.blur,
			atmosphere = atmosphereId or "base",
			counters = table.clone(counters),
		}
	end,
}

return VfxServiceClient
