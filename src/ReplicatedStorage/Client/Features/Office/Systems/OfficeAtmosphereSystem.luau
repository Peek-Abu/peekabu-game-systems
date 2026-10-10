--!strict
--[=[
	OfficeAtmosphereSystem: the office's light and air on this client (Cleanup Crew spec §7 "The office at night:
	dim, buzzing fluorescents (some flickering)"; "Overtime: lighting shifts dim red"). Follows ShiftStore's
	snapshot: blends Lighting to OfficeAtmosphereUtils.preset (night, darker per tier, lighter on Harlow's break,
	dim red in overtime; the place's own lighting outside a shift); in overtime a red screen tint and red ceiling
	lights; the fluorescent hum while the office is in a shift. Every ATMOSPHERE_INTERVAL the broken lights near the
	camera (OfficeLightUtils) blink, with a zap as each dims. It changes only a light's Color, Transparency and
	PointLight Color/Brightness; M2's OccupantTellSystem owns Material and PointLight.Enabled, so the two compose.
	Registers the office presets with Vfx at load. Pending sounds (OfficeAssets) are silent.

	Spec-exempt shell (Lighting via Vfx, Instances, Sound, Charm, RunService); the choices are the specced
	OfficeAtmosphereUtils and OfficeLightUtils.

	@class OfficeAtmosphereSystem
]=]

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local OfficeClient = ReplicatedStorage.Client.Features.Office
local Charm = require(ReplicatedStorage.Packages.Charm)
local OccupantConstants = require(ReplicatedStorage.Shared.Features.Occupant.Data.OccupantConstants)
local ShiftTypes = require(ReplicatedStorage.Shared.Features.Shift.Data.ShiftTypes)
local SoundRegistry = require(ReplicatedStorage.Shared.Features.Sound.Data.SoundRegistry)
local VfxAtmosphereRegistry = require(ReplicatedStorage.Shared.Features.Vfx.Data.VfxAtmosphereRegistry)
local OfficeAssets = require(OfficeClient.Data.OfficeAssets)
local OfficeAtmosphereConstants = require(OfficeClient.Data.OfficeAtmosphereConstants)
local OfficeAtmosphereUtils = require(OfficeClient.Utils.OfficeAtmosphereUtils)
local OfficeLightUtils = require(OfficeClient.Utils.OfficeLightUtils)
local ShiftStore = require(ReplicatedStorage.Client.Features.Shift.State.ShiftStore)
local SoundServiceClient = require(ReplicatedStorage.Client.Features.Sound.SoundServiceClient)
local VfxServiceClient = require(ReplicatedStorage.Client.Features.Vfx.VfxServiceClient)

-- Registered at load: setAtmosphere refuses an unknown preset.
for id, preset in OfficeAtmosphereConstants.PRESETS do
	if not VfxAtmosphereRegistry.has(id) then
		VfxAtmosphereRegistry.register(id, preset)
	end
end

export type OfficeAtmosphereState = {
	preset: string,
	overtime: boolean,
	hum: boolean,
	dimNow: number,
	counters: { [string]: number },
}

type LightBase = {
	color: Color3,
	brightness: number,
	transparency: number,
}

-- Each light's own look (captured the first time this client touches it), and which are dimmed now. Plain maps:
-- the lights are built once with the office and never replaced, and `dimmed` is iterated and cleared.
local bases: { [BasePart]: LightBase } = {}
local dimmed: { [BasePart]: boolean } = {}

local applied = false
local currentPreset: string? = nil
local overtimeOn = false
local overtimeToken: number? = nil
local humOn = false
local stoppers: { () -> () } = {}
local counters = { presets = 0, zaps = 0, pending = 0 }

local function baseOf(light: BasePart): LightBase
	local existing = bases[light]
	if existing ~= nil then
		return existing
	end
	local point = light:FindFirstChildOfClass("PointLight")
	local created: LightBase = {
		color = light.Color,
		brightness = if point ~= nil then point.Brightness else 0,
		transparency = light.Transparency,
	}
	bases[light] = created
	return created
end

local function lights(): { BasePart }
	local list: { BasePart } = {}
	for _, instance in CollectionService:GetTagged(OccupantConstants.LIGHT_TAG) do
		if instance:IsA("BasePart") then
			table.insert(list, instance)
		end
	end
	return list
end

local function paint(light: BasePart, red: boolean)
	-- Capture the light's built look BEFORE painting it red: paint is the only Color writer here, so every later
	-- baseOf (the restore at overtime's end, stepBroken) sees the built colour, never the overtime red.
	local base = baseOf(light)
	local color = if red then OfficeAtmosphereConstants.OVERTIME_LIGHT_COLOR else base.color
	light.Color = color
	local point = light:FindFirstChildOfClass("PointLight")
	if point ~= nil then
		point.Color = color
	end
end

local function setOvertime(on: boolean)
	if on == overtimeOn then
		return
	end
	overtimeOn = on
	for _, light in lights() do
		paint(light, on)
	end
	local token = overtimeToken
	if on and token == nil then
		overtimeToken = VfxServiceClient:requestScreen({
			tint = OfficeAtmosphereConstants.OVERTIME_TINT,
			saturation = OfficeAtmosphereConstants.OVERTIME_SATURATION,
		})
	elseif not on and token ~= nil then
		VfxServiceClient:releaseScreen(token)
		overtimeToken = nil
	end
end

local function setHum(on: boolean)
	if on == humOn then
		return
	end
	humOn = on
	if not on then
		SoundServiceClient:setAmbience(OfficeAtmosphereConstants.HUM_LAYER, nil)
	elseif SoundRegistry.has(OfficeAssets.HUM) then
		SoundServiceClient:setAmbience(OfficeAtmosphereConstants.HUM_LAYER, OfficeAssets.HUM)
	else
		counters.pending += 1
	end
end

local function onSnapshot(snapshot: ShiftTypes.ShiftSnapshot?)
	local preset = OfficeAtmosphereUtils.preset(snapshot)
	if not applied or preset ~= currentPreset then
		applied = true
		currentPreset = preset
		counters.presets += 1
		VfxServiceClient:setAtmosphere(preset, OfficeAtmosphereConstants.FADE)
	end
	setOvertime(OfficeAtmosphereUtils.overtime(snapshot))
	setHum(OfficeAtmosphereUtils.hum(snapshot))
end

local function restore(light: BasePart)
	local base = baseOf(light)
	light.Transparency = base.transparency
	local point = light:FindFirstChildOfClass("PointLight")
	if point ~= nil then
		point.Brightness = base.brightness
	end
end

-- The broken lights near the camera blink; any that left the radius are restored.
local function stepBroken()
	local camera = Workspace.CurrentCamera
	if camera == nil then
		return
	end
	local now = os.clock()
	local list = lights()
	local positions: { Vector3 } = {}
	for index, light in list do
		positions[index] = light.Position
	end
	local near: { [BasePart]: boolean } = {}
	local center = camera.CFrame.Position
	local radius = OfficeAtmosphereConstants.BROKEN_RADIUS
	for _, index in OfficeLightUtils.nearbyBroken(positions, center, radius, OfficeAtmosphereConstants.BROKEN_FRACTION) do
		local light = list[index]
		near[light] = true
		local base = baseOf(light)
		local factor = OfficeLightUtils.glow(now, OfficeLightUtils.hash(light.Position) * 100)
		local dim = factor < 1
		local point = light:FindFirstChildOfClass("PointLight")
		if point ~= nil then
			point.Brightness = base.brightness * factor
		end
		light.Transparency = if dim then OfficeAtmosphereConstants.BROKEN_TRANSPARENCY else base.transparency
		if dim and not dimmed[light] then
			counters.zaps += 1
			if SoundRegistry.has(OfficeAssets.ZAP) then
				SoundServiceClient:play(OfficeAssets.ZAP, { at = light })
			else
				counters.pending += 1
			end
		end
		dimmed[light] = dim
	end
	for light in dimmed do
		if not near[light] then
			restore(light)
			dimmed[light] = nil
		end
	end
end

local OfficeAtmosphereSystem = {}

function OfficeAtmosphereSystem.start()
	if #stoppers > 0 then
		return
	end
	onSnapshot(ShiftStore.snapshot())
	table.insert(stoppers, Charm.subscribe(ShiftStore.snapshot, onSnapshot))
	local elapsed = 0
	local connection = RunService.Heartbeat:Connect(function(deltaTime: number)
		elapsed += deltaTime
		if elapsed >= OfficeAtmosphereConstants.ATMOSPHERE_INTERVAL then
			elapsed = 0
			stepBroken()
		end
	end)
	table.insert(stoppers, function()
		connection:Disconnect()
	end)
end

function OfficeAtmosphereSystem.stop()
	for _, stop in stoppers do
		stop()
	end
	table.clear(stoppers)
	for light in dimmed do
		restore(light)
	end
	table.clear(dimmed)
	setOvertime(false)
	setHum(false)
	VfxServiceClient:setAtmosphere(nil, 0)
	applied = false
	currentPreset = nil
end

function OfficeAtmosphereSystem.getState(): OfficeAtmosphereState
	local blinking = 0
	for _, dim in dimmed do
		if dim then
			blinking += 1
		end
	end
	return {
		preset = currentPreset or "place",
		overtime = overtimeOn,
		hum = humOn,
		dimNow = blinking,
		counters = table.clone(counters),
	}
end

return OfficeAtmosphereSystem
