--!strict
--[=[
	TrainingHallSystem: the Training hall's look on this client, from the stop the server publishes (the `training`
	world entry, TrainingConstants.WORLD_ENTRY). Fun, then dark, then scary, then safe:

	- Stop 3 ("quiet"): the screen darkens and greys (a Vfx screen request, so it reads dark whatever the place's
	  lighting), the hall's "light" parts go out one by one, in their ORDER, LIGHT_STEP apart (their lights
	  off, a Neon part to plain plastic), and the "creep" patches of Gloom fade and grow in, in ORDER.
	- Stop 4 ("hide"): red and dark (a second, redder screen request on top), and the hiding furniture glows red (a
	  Highlight), so the way to hide is plain. (Tutorial v3: no hall signs; Pippa's lines and the goal bar say it.)
	  Mr. Harlow's two doors (staffDoor, exitDoor) creak as they swing open and slam shut (their TrainingSwingOpen
	  attribute, set by the server's TrainingHarlowSystem; 3D at the door); as the STAFF door opens the dark lifts (his
	  light spills in; the red stays), so the player can watch him pass. Once he has gone (`setClear`): the relief
	  sting, the glow turns green, the red and the dark lift, and the hall's lights pop back on one by one, in ORDER.
	- Stop 5 ("done"): every light pops back on, the Gloom fades away, the glow goes, and a happy sound plays.

	The hall's "light" parts are the training's own (not OfficeLight-tagged), so nothing else switches them.
	`apply(stop)` is idempotent; `clear` puts the hall back as authored.

	Spec-exempt shell (Instances, tweens, sounds); the stop is the server's (TrainingStopRules).

	@class TrainingHallSystem
]=]

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local HideConstants = require(ReplicatedStorage.Shared.Features.Hide.Data.HideConstants)
local TrainingConstants = require(ReplicatedStorage.Shared.Features.Training.Data.TrainingConstants)
local SoundServiceClient = require(ReplicatedStorage.Client.Features.Sound.SoundServiceClient)
local TrainingAssets = require(ReplicatedStorage.Client.Features.Training.Data.TrainingAssets)
local UISoundSystem = require(ReplicatedStorage.Client.Features.UI.Systems.UISoundSystem)
local VfxServiceClient = require(ReplicatedStorage.Client.Features.Vfx.VfxServiceClient)

type Saved = { material: Enum.Material, lights: { Light } }
type Creep = { part: BasePart, transparency: number, size: Vector3 }

local STOP_QUIET = 3
local STOP_HIDE = 4
local STOP_DONE = 5
local GLOW = TrainingConstants.GUIDE.danger
local CLEAR_GLOW = TrainingConstants.GUIDE.clear

local shown = 0
-- The player got away at the shown stop (the desk's glow is green, the red is off).
local cleared = false
local saved: { [BasePart]: Saved } = {}
local creeps: { Creep } = {}
local glows: { Highlight } = {}
-- Bumped by every apply, so a light-out sequence from an older stop stops.
local generation = 0
-- The dark screen at stops 3-4 and the hide stop's red on top (Vfx screen requests), while they are held.
local darkToken: number? = nil
local dangerToken: number? = nil
-- The door listeners (one per Harlow door), while the hall is shown.
local doorWatch: { RBXScriptConnection } = {}
-- Seconds between two lights popping back on at the all-clear.
local POP_STEP = 0.18

local function danger(on: boolean)
	local token = dangerToken
	if on and token == nil then
		local shade = TrainingConstants.DANGER_SCREEN
		dangerToken = VfxServiceClient:requestScreen({ saturation = shade.saturation, tint = shade.tint })
	elseif not on and token ~= nil then
		VfxServiceClient:releaseScreen(token)
		dangerToken = nil
	end
end

local function dark(on: boolean)
	local token = darkToken
	if on and token == nil then
		local shade = TrainingConstants.DARK_SCREEN
		darkToken = VfxServiceClient:requestScreen({
			brightness = shade.brightness,
			saturation = shade.saturation,
			tint = shade.tint,
		})
	elseif not on and token ~= nil then
		VfxServiceClient:releaseScreen(token)
		darkToken = nil
	end
end

local function map(): Model?
	for _, tagged in CollectionService:GetTagged(TrainingConstants.MAP_TAG) do
		if tagged:IsA("Model") then
			return tagged
		end
	end
	return nil
end

local function parts(model: Model, role: string): { BasePart }
	local found: { BasePart } = {}
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") and part:GetAttribute(TrainingConstants.ROLE_ATTRIBUTE) == role then
			table.insert(found, part)
		end
	end
	table.sort(found, function(a, b)
		local x, y =
			a:GetAttribute(TrainingConstants.ORDER_ATTRIBUTE), b:GetAttribute(TrainingConstants.ORDER_ATTRIBUTE)
		return (if type(x) == "number" then x else 0) < (if type(y) == "number" then y else 0)
	end)
	return found
end

local function lightsOf(part: BasePart): { Light }
	local lights: { Light } = {}
	for _, child in part:GetDescendants() do
		if child:IsA("Light") then
			table.insert(lights, child)
		end
	end
	return lights
end

local function lightOut(part: BasePart)
	if saved[part] ~= nil then
		return
	end
	local lights = lightsOf(part)
	saved[part] = { material = part.Material, lights = lights }
	for _, light in lights do
		light.Enabled = false
	end
	if part.Material == Enum.Material.Neon then
		part.Material = Enum.Material.SmoothPlastic
	end
end

local function lightsOn()
	for part, state in saved do
		part.Material = state.material
		for _, light in state.lights do
			light.Enabled = true
		end
	end
	table.clear(saved)
end

local function hideCreep(model: Model)
	if #creeps > 0 then
		return
	end
	for _, part in parts(model, "creep") do
		table.insert(creeps, { part = part, transparency = part.Transparency, size = part.Size })
		part.Transparency = 1
	end
end

local function creepIn(mine: number)
	for index, creep in creeps do
		task.delay((index - 1) * TrainingConstants.LIGHT_STEP, function()
			if mine ~= generation then
				return
			end
			creep.part.Size = creep.size * Vector3.new(0.2, 1, 0.2)
			TweenService:Create(
				creep.part,
				TweenInfo.new(TrainingConstants.CREEP_SECONDS, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
				{ Transparency = creep.transparency, Size = creep.size }
			):Play()
		end)
	end
end

local function creepOut()
	for _, creep in creeps do
		TweenService:Create(creep.part, TweenInfo.new(1), { Transparency = 1 }):Play()
	end
end

local function glow(model: Model, on: boolean)
	for _, highlight in glows do
		highlight:Destroy()
	end
	table.clear(glows)
	if not on then
		return
	end
	local color = if cleared then CLEAR_GLOW else GLOW
	for _, part in model:GetDescendants() do
		if CollectionService:HasTag(part, HideConstants.FURNITURE_TAG) then
			local highlight = Instance.new("Highlight")
			highlight.FillColor = color
			highlight.FillTransparency = 0.75
			highlight.OutlineColor = color
			highlight.DepthMode = Enum.HighlightDepthMode.Occluded
			highlight.Adornee = part
			highlight.Parent = part
			table.insert(glows, highlight)
		end
	end
end

-- His doors' sounds: a creak as one swings open, a slam as it shuts (the STAFF door's close is softer).
local function watchDoors(model: Model)
	if #doorWatch > 0 then
		return
	end
	for _, role in { "staffDoor", "exitDoor" } do
		for _, door in parts(model, role) do
			table.insert(
				doorWatch,
				door:GetAttributeChangedSignal("TrainingSwingOpen"):Connect(function()
					local open = door:GetAttribute("TrainingSwingOpen") == true
					-- His light spills in: the dark lifts (the red stays), so the player sees him walk past.
					if open and role == "staffDoor" and shown == STOP_HIDE then
						dark(false)
					end
					SoundServiceClient:playOneShot(if open then TrainingAssets.CREAK else TrainingAssets.SLAM, {
						at = door,
						volumeScale = if not open and role == "staffDoor" then 0.5 else 1,
					})
				end)
			)
		end
	end
end

local function unwatchDoors()
	for _, connection in doorWatch do
		connection:Disconnect()
	end
	table.clear(doorWatch)
end

-- The all-clear: the hall's lights pop back on one by one, in ORDER.
local function popOn(model: Model, mine: number)
	for index, part in parts(model, "light") do
		task.delay((index - 1) * POP_STEP, function()
			if mine ~= generation or not cleared then
				return
			end
			local state = saved[part]
			if state == nil then
				return
			end
			part.Material = state.material
			for _, light in state.lights do
				light.Enabled = true
			end
			saved[part] = nil
		end)
	end
end

local TrainingHallSystem = {}

--[=[
	Shows the hall for stop `stop` (1-5).
]=]
function TrainingHallSystem.apply(stop: number)
	local model = map()
	if model == nil or stop == shown then
		return
	end
	local before = shown
	shown = stop
	cleared = false
	generation += 1
	local mine = generation
	hideCreep(model)
	watchDoors(model)
	if stop >= STOP_QUIET and stop < STOP_DONE and before < STOP_QUIET then
		for index, part in parts(model, "light") do
			task.delay((index - 1) * TrainingConstants.LIGHT_STEP, function()
				-- Stop 4 keeps the dark; only the run's end (or a clear) turns the lights back on.
				if shown >= STOP_QUIET and shown < STOP_DONE then
					lightOut(part)
				end
			end)
		end
		creepIn(mine)
	end
	glow(model, stop == STOP_HIDE)
	dark(stop >= STOP_QUIET and stop < STOP_DONE)
	danger(stop == STOP_HIDE and not cleared)
	if stop >= STOP_DONE then
		lightsOn()
		creepOut()
		UISoundSystem.play("done")
	end
end

--[=[
	The player got away at stop `stop` (the server's CLEAR_ENTRY): at the hide stop the desk's glow turns green, the
	red lifts and a small all-clear sound plays, once.
]=]
function TrainingHallSystem.setClear(stop: number?)
	local now = stop ~= nil and stop == shown and shown == STOP_HIDE
	if now == cleared then
		return
	end
	cleared = now
	local model = map()
	if model ~= nil then
		glow(model, shown == STOP_HIDE)
	end
	danger(shown == STOP_HIDE and not cleared)
	if cleared then
		SoundServiceClient:playOneShot(TrainingAssets.RELIEF)
		dark(false)
		if model ~= nil then
			popOn(model, generation)
		end
	end
end

--[=[
	Puts the hall back as it was built.
]=]
function TrainingHallSystem.clear()
	generation += 1
	shown = 0
	cleared = false
	unwatchDoors()
	lightsOn()
	dark(false)
	danger(false)
	local model = map()
	if model ~= nil then
		glow(model, false)
	end
	for _, creep in creeps do
		creep.part.Transparency = creep.transparency
		creep.part.Size = creep.size
	end
	table.clear(creeps)
end

return TrainingHallSystem
