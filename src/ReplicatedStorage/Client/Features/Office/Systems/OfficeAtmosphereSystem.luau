--!strict
--[=[
	OfficeAtmosphereSystem: the office's light and air on this client (Cleanup Crew spec §7 "The office at night:
	dim, buzzing fluorescents (some flickering)"; "Overtime: lighting shifts dim red"). Follows ShiftStore's
	snapshot: blends Lighting to OfficeAtmosphereUtils.preset (night, darker per tier, lighter on Harlow's break,
	dim red in overtime; the depot's warm evening while the local player is in the hub); in overtime a red screen
	tint and red ceiling lights; the office bed (its four looped beds, OfficeAssets.BED) while the local player's crew
	is in a shift, and the hub's record (DepotAssets.HUB_THEME, the music slot) while they are in the hub. It is the
	one owner of Lighting and of the place's bed, so the hub and the office never fight over them. Every ATMOSPHERE_INTERVAL the broken lights near the
	camera (OfficeLightUtils) blink, with a zap as a burst of blinks starts (OfficeLightUtils.zaps: once per burst, spaced
	per tube and across tubes). It changes only a light's Color, Transparency and
	lamp (PointLight or SurfaceLight) Color/Brightness; M2's OccupantTellSystem owns Material and Light.Enabled, so the two compose.
	Outdoors (the camera inside a Workspace.CleanupCrewOffice.Outdoors box, polled every OUTDOOR_POLL in a shift) it
	blends to the moonlit officeExterior look (red in overtime) and hushes the hum; `expected()` names the preset the
	camera should show now. Registers the office and depot presets with Vfx at load. Pending sounds (OfficeAssets) are silent. While the transit
	screen covers the view (ShiftTransitStore.covered) a preset is applied at once, not blended, and one still blending
	when the cover comes up is finished at once, so the screen reveals the right light.

	Spec-exempt shell (Lighting via Vfx, Instances, Sound, Charm, RunService); the choices are the specced
	OfficeAtmosphereUtils and OfficeLightUtils.

	@class OfficeAtmosphereSystem
]=]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local OfficeClient = ReplicatedStorage.Client.Features.Office
local Charm = require(ReplicatedStorage.Packages.Charm)
local DepotAssets = require(ReplicatedStorage.Client.Features.Depot.Data.DepotAssets)
local DepotAtmosphereConstants = require(ReplicatedStorage.Client.Features.Depot.Data.DepotAtmosphereConstants)
local DepotAtmosphereUtils = require(ReplicatedStorage.Client.Features.Depot.Utils.DepotAtmosphereUtils)
local OccupantConstants = require(ReplicatedStorage.Shared.Features.Occupant.Data.OccupantConstants)
local ShiftTypes = require(ReplicatedStorage.Shared.Features.Shift.Data.ShiftTypes)
local SoundRegistry = require(ReplicatedStorage.Shared.Features.Sound.Data.SoundRegistry)
local VfxAtmosphereRegistry = require(ReplicatedStorage.Shared.Features.Vfx.Data.VfxAtmosphereRegistry)
local OfficeAssets = require(OfficeClient.Data.OfficeAssets)
local OfficeAtmosphereConstants = require(OfficeClient.Data.OfficeAtmosphereConstants)
local OfficeAtmosphereUtils = require(OfficeClient.Utils.OfficeAtmosphereUtils)
local OfficeLightUtils = require(OfficeClient.Utils.OfficeLightUtils)
local ShiftStore = require(ReplicatedStorage.Client.Features.Shift.State.ShiftStore)
local ShiftTransitStore = require(ReplicatedStorage.Client.Features.Shift.State.ShiftTransitStore)
local SoundServiceClient = require(ReplicatedStorage.Client.Features.Sound.SoundServiceClient)
local VfxServiceClient = require(ReplicatedStorage.Client.Features.Vfx.VfxServiceClient)

-- Registered at load: setAtmosphere refuses an unknown preset.
for _, presets in { OfficeAtmosphereConstants.PRESETS, DepotAtmosphereConstants.PRESETS } do
	for id, preset in presets do
		if not VfxAtmosphereRegistry.has(id) then
			VfxAtmosphereRegistry.register(id, preset)
		end
	end
end

export type OfficeAtmosphereState = {
	preset: string,
	overtime: boolean,
	hum: boolean,
	hub: boolean,
	dimNow: number,
	counters: { [string]: number },
}

type LightBase = {
	color: Color3,
	brightness: number,
	transparency: number,
}

-- Each light's own look (captured the first time this client touches it), and which are dimmed now. The office is
-- rebuilt every shift, so a light leaving the game is forgotten (its tag's removed signal) rather than kept, with its
-- destroyed part, for the rest of the session.
local bases: { [BasePart]: LightBase } = {}
local dimmed: { [BasePart]: boolean } = {}
-- When each tube last began a blink and last zapped, and when any tube last zapped (OfficeLightUtils.zaps).
local lastBlink: { [BasePart]: number } = {}
local lastZap: { [BasePart]: number } = {}
local lastAnyZap: number? = nil

local applied = false
local currentPreset: string? = nil
local overtimeOn = false
local overtimeToken: number? = nil
local humOn = false
local hubOn = false
local outsideNow = false
local stoppers: { () -> () } = {}
local counters = { presets = 0, blinks = 0, zaps = 0, pending = 0 }

local function baseOf(light: BasePart): LightBase
	local existing = bases[light]
	if existing ~= nil then
		return existing
	end
	local point = light:FindFirstChildWhichIsA("Light")
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
	local point = light:FindFirstChildWhichIsA("Light")
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

-- The office bed: each looped bed in its own ambience layer (named by its id), so they run on their own lengths.
local function setHum(on: boolean)
	if on == humOn then
		return
	end
	humOn = on
	for _, id in OfficeAssets.BED do
		if not on then
			SoundServiceClient:setAmbience(id, nil)
		elseif SoundRegistry.has(id) then
			SoundServiceClient:setAmbience(id, id)
		else
			counters.pending += 1
		end
	end
end

-- The hub's record while the local player is in the depot (the music slot: never on while a chase could play).
local function setHub(on: boolean)
	if on == hubOn then
		return
	end
	hubOn = on
	if not on then
		SoundServiceClient:playMusic(nil)
	elseif SoundRegistry.has(DepotAssets.HUB_THEME) then
		SoundServiceClient:playMusic(DepotAssets.HUB_THEME)
	else
		counters.pending += 1
	end
end

-- The outdoor boxes the server built (Workspace.CleanupCrewOffice.Outdoors: one invisible part per ground). None when
-- the layout has no grounds (an authored layout, the hub).
local function outdoorBoxes(): { { min: Vector3, max: Vector3 } }
	local boxes: { { min: Vector3, max: Vector3 } } = {}
	local office = Workspace:FindFirstChild("CleanupCrewOffice")
	local folder = if office ~= nil then office:FindFirstChild("Outdoors") else nil
	if folder == nil then
		return boxes
	end
	for _, part in folder:GetChildren() do
		if part:IsA("BasePart") then
			local center, half = part.CFrame.Position, part.Size / 2
			table.insert(boxes, { min = center - half, max = center + half })
		end
	end
	return boxes
end

-- Whether the camera is outdoors now; only ever true in a shift (the hub is the depot's evening).
local function cameraOutside(snapshot: ShiftTypes.ShiftSnapshot?): boolean
	local camera = Workspace.CurrentCamera
	if camera == nil or snapshot == nil or DepotAtmosphereUtils.inHub(snapshot, Players.LocalPlayer.UserId) then
		return false
	end
	return OfficeAtmosphereUtils.outdoors(camera.CFrame.Position, outdoorBoxes())
end

-- Applies the snapshot's look with the camera's current indoors/outdoors. `fade` is the blend when not covered.
local function apply(snapshot: ShiftTypes.ShiftSnapshot?, fade: number)
	local userId = Players.LocalPlayer.UserId
	local outside = cameraOutside(snapshot)
	outsideNow = outside
	local preset = OfficeAtmosphereUtils.preset(snapshot, userId, outside)
	if not applied or preset ~= currentPreset then
		applied = true
		currentPreset = preset
		counters.presets += 1
		local covered = ShiftTransitStore.covered()
		VfxServiceClient:setAtmosphere(preset, if covered then 0 else fade)
	end
	setOvertime(OfficeAtmosphereUtils.overtime(snapshot, userId))
	setHum(OfficeAtmosphereUtils.hum(snapshot, userId, outside))
	setHub(DepotAtmosphereUtils.inHub(snapshot, userId))
end

local function onSnapshot(snapshot: ShiftTypes.ShiftSnapshot?)
	apply(snapshot, OfficeAtmosphereConstants.FADE)
end

local function restore(light: BasePart)
	local base = baseOf(light)
	light.Transparency = base.transparency
	local point = light:FindFirstChildWhichIsA("Light")
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
	-- Fill anchors (invisible, OfficeLightFill) are not tubes: they stay out of the blink pool.
	local list: { BasePart } = {}
	local positions: { Vector3 } = {}
	for _, light in lights() do
		if light:GetAttribute("OfficeLightFill") ~= true then
			table.insert(list, light)
			table.insert(positions, light.Position)
		end
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
		local point = light:FindFirstChildWhichIsA("Light")
		if point ~= nil then
			point.Brightness = base.brightness * factor
		end
		-- A fully transparent light (an invisible anchor or an art proxy root) never gets a visible dim slab.
		if base.transparency < 1 then
			light.Transparency = if dim then OfficeAtmosphereConstants.BROKEN_TRANSPARENCY else base.transparency
		end
		if dim and not dimmed[light] then
			counters.blinks += 1
			if OfficeLightUtils.zaps(now, lastBlink[light], lastZap[light], lastAnyZap) then
				lastZap[light] = now
				lastAnyZap = now
				counters.zaps += 1
				if SoundRegistry.has(OfficeAssets.ZAP) then
					-- At the tube's spot (it never moves): a shared fixed-point voice, not one made per broken tube.
					SoundServiceClient:playOneShot(OfficeAssets.ZAP, { at = light.Position })
				else
					counters.pending += 1
				end
			end
			lastBlink[light] = now
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
	-- The cover is up: finish any blend at once (nothing behind the screen should still be fading).
	table.insert(
		stoppers,
		Charm.subscribe(ShiftTransitStore.covered, function(covered: boolean)
			local preset = currentPreset
			if covered and preset ~= nil then
				VfxServiceClient:setAtmosphere(preset, 0)
			end
		end)
	)
	local removed = CollectionService:GetInstanceRemovedSignal(OccupantConstants.LIGHT_TAG)
		:Connect(function(instance: Instance)
			if instance:IsA("BasePart") then
				bases[instance] = nil
				dimmed[instance] = nil
				lastBlink[instance] = nil
				lastZap[instance] = nil
			end
		end)
	table.insert(stoppers, function()
		removed:Disconnect()
	end)
	local elapsed = 0
	local outdoorElapsed = 0
	local connection = RunService.Heartbeat:Connect(function(deltaTime: number)
		outdoorElapsed += deltaTime
		if outdoorElapsed >= OfficeAtmosphereConstants.OUTDOOR_POLL then
			outdoorElapsed = 0
			-- The teleport fade hides the switch, so a short blend; only a change re-applies.
			local snapshot = ShiftStore.snapshot()
			if cameraOutside(snapshot) ~= outsideNow then
				apply(snapshot, OfficeAtmosphereConstants.OUTDOOR_FADE)
			end
		end
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
	table.clear(lastBlink)
	table.clear(lastZap)
	lastAnyZap = nil
	setOvertime(false)
	setHum(false)
	setHub(false)
	VfxServiceClient:setAtmosphere(nil, 0)
	applied = false
	currentPreset = nil
	outsideNow = false
end

-- The preset this client should be showing now (the snapshot and where the camera is), for ShiftTransitSystem.lit().
function OfficeAtmosphereSystem.expected(): string
	local snapshot = ShiftStore.snapshot()
	return OfficeAtmosphereUtils.preset(snapshot, Players.LocalPlayer.UserId, cameraOutside(snapshot))
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
		hub = hubOn,
		dimNow = blinking,
		counters = table.clone(counters),
	}
end

return OfficeAtmosphereSystem
