--!strict
--[=[
	DepotSpotSystem: the hub's spots on this client (plan docs/superpowers/plans/2026-11-11-hub-interactables.md). The
	server answers a spot's prompt with DepotEvents.Spot, checked again here (DepotSpotRules.decode), and this opens it:

	- the Supply Counter opens the Shop; a standee opens the Shop on that employee's page; a Lost & Found locker door
	  (the Gloom and the Gleam Locker) opens it on the Lockers tab;
	- the coffee machine, the crew wall and the rank chart push their scenes (DepotSpotScene);
	- the radio moves to the next station (DepotStore.nextStation; OfficeAtmosphereSystem plays it) and toasts its name;
	  every radio puffs music notes (DepotAssets.RADIO_NOTES, a flipbook) at the station's rate (none on a quiet one).

	A ring of a shift bell (DepotEvents.Bell, to everyone) plays the bell sound at the bell, swings it (its DepotSwing parts
	about its BellPivot attachment, DepotSpotRules.bellSwing; a local move) and puffs a gold ring wave with sparks.

	Spec-exempt shell (ByteNet, scene stack, Sound, local Instance motion); the decisions are the specced DepotSpotRules and DepotStore.

	@class DepotSpotSystem
]=]

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Charm = require(ReplicatedStorage.Packages.Charm)
local Observers = require(ReplicatedStorage.Packages.Observers)
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local DepotEvents = require(ReplicatedStorage.Shared.Features.Depot.Net.DepotEvents)
local DepotSpotConstants = require(ReplicatedStorage.Shared.Features.Depot.Data.DepotSpotConstants)
local DepotSpotRules = require(ReplicatedStorage.Shared.Features.Depot.Rules.DepotSpotRules)
local DepotStore = require(ReplicatedStorage.Client.Features.Depot.State.DepotStore)
local InteractionConstants = require(ReplicatedStorage.Shared.Features.Interaction.Data.InteractionConstants)
local ShopStore = require(ReplicatedStorage.Client.Features.Shop.State.ShopStore)
local SoundServiceClient = require(ReplicatedStorage.Client.Features.Sound.SoundServiceClient)
local ToastStore = require(ReplicatedStorage.Client.Features.Toast.State.ToastStore)
local SceneStack = require(ReplicatedStorage.Client.UI.Scenes.SceneStack)
local ShopViewModel = require(ReplicatedStorage.Client.UI.React.Screens.Shop.ShopViewModel)
-- Registers the sounds (the bell) and the spot scenes.
local DepotAssets = require(ReplicatedStorage.Client.Features.Depot.Data.DepotAssets)
require(ReplicatedStorage.Client.UI.React.Screens.Depot.DepotSpotScene)

local SCENES = DepotSpotConstants.SCENES
local SWING = DepotSpotConstants.BELL_SWING
local RADIO_TOAST_SECONDS = 2.5
-- Studs: a ring's position is matched to the bell standing this close to it.
local BELL_MATCH = 8
-- The ring wave: this many glowing dashes round a circle, and this many sparks flying off.
local RING_DASHES = 14
local RING_SPARKS = 6

-- The bell that rang at `at`: the tagged bell spot whose pivot is nearest (within BELL_MATCH).
local function bellAt(at: Vector3): Instance?
	local best: Instance? = nil
	local bestDistance = BELL_MATCH
	for _, target in CollectionService:GetTagged(InteractionConstants.TAG) do
		if target:GetAttribute(InteractionConstants.KIND_ATTRIBUTE) == DepotSpotConstants.KINDS.bell then
			local pivot = if target:IsA("Model")
				then target:GetPivot().Position
				elseif target:IsA("BasePart") then target.Position
				else nil
			if pivot ~= nil and (pivot - at).Magnitude < bestDistance then
				best = target
				bestDistance = (pivot - at).Magnitude
			end
		end
	end
	return best
end

-- Bells swinging now, so a ring during a swing restarts it instead of stacking a second one.
local swinging: { [Instance]: number } = {}

-- Swings the bell's DepotSwing parts about its BellPivot attachment (a local move: anchored parts, this client only).
local function swing(bell: Instance)
	local pivot = bell:FindFirstChild(SWING.PIVOT_NAME, true)
	if pivot == nil or not pivot:IsA("Attachment") then
		return
	end
	if swinging[bell] ~= nil then
		swinging[bell] = os.clock()
		return
	end
	local base = pivot.WorldCFrame
	local parts: { [BasePart]: CFrame } = {}
	for _, part in bell:GetDescendants() do
		if part:IsA("BasePart") and part:GetAttribute(SWING.SWING_ATTRIBUTE) == true then
			parts[part] = base:ToObjectSpace(part.CFrame)
		end
	end
	swinging[bell] = os.clock()
	task.spawn(function()
		while true do
			local started = swinging[bell]
			local t = if started ~= nil then os.clock() - started else SWING.SECONDS
			local turn = base * CFrame.Angles(math.rad(DepotSpotRules.bellSwing(t)), 0, 0)
			for part, offset in parts do
				part.CFrame = turn * offset
			end
			if t >= SWING.SECONDS or bell.Parent == nil then
				break
			end
			RunService.RenderStepped:Wait()
		end
		for part, offset in parts do
			part.CFrame = base * offset
		end
		swinging[bell] = nil
	end)
end

-- A gold ring wave from the bell's cup: glowing dashes spreading out flat and fading, and a few sparks flying off.
local function ringWave(at: Vector3)
	local folder = Instance.new("Folder")
	folder.Name = "BellRing"
	local dashes: { { part: Part, angle: number } } = {}
	for index = 1, RING_DASHES + RING_SPARKS do
		local spark = index > RING_DASHES
		local part = Instance.new("Part")
		part.Anchored = true
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part.CastShadow = false
		part.Material = Enum.Material.Neon
		part.Color = SWING.RING_COLOR
		part.Shape = if spark then Enum.PartType.Ball else Enum.PartType.Block
		part.Size = if spark then Vector3.new(0.25, 0.25, 0.25) else Vector3.new(0.9, 0.12, 0.25)
		part.Parent = folder
		local angle = if spark then math.random() * math.pi * 2 else (index / RING_DASHES) * math.pi * 2
		table.insert(dashes, { part = part, angle = angle })
	end
	folder.Parent = Workspace
	task.spawn(function()
		local started = os.clock()
		while true do
			local k = math.clamp((os.clock() - started) / SWING.RING_SECONDS, 0, 1)
			local ease = 1 - (1 - k) ^ 3
			for index, dash in dashes do
				local spark = index > RING_DASHES
				local radius = (if spark then 1.4 else 1) * ease * SWING.RING_SIZE / 2 + 0.6
				local lift = if spark then ease * 2.5 - ease * ease * 1.5 else 0
				local offset = Vector3.new(math.cos(dash.angle) * radius, lift, math.sin(dash.angle) * radius)
				dash.part.CFrame = CFrame.new(at + offset) * CFrame.Angles(0, -dash.angle + math.pi / 2, 0)
				dash.part.Transparency = k
			end
			if k >= 1 then
				break
			end
			RunService.RenderStepped:Wait()
		end
		folder:Destroy()
	end)
end

local DepotSpotSystem = {}

-- The spot scenes, so the depot can take them down when the player leaves the hub.
DepotSpotSystem.SCENES = { SCENES.coffee, SCENES.crew, SCENES.rank }

local function open(opened: DepotSpotRules.Opened)
	local spot = opened.spot
	if spot == "shop" then
		ShopStore.open(nil)
		SceneStack.push(ShopViewModel.SCENE)
	elseif spot == "standee" then
		ShopStore.open(opened.employee)
		SceneStack.push(ShopViewModel.SCENE)
	elseif spot == "coffee" then
		SceneStack.push(SCENES.coffee)
	elseif spot == "crew" then
		SceneStack.push(SCENES.crew)
	elseif spot == "rank" then
		SceneStack.push(SCENES.rank)
	elseif spot == "locker" then
		ShopStore.openTab(DepotSpotConstants.LOCKER_TAB)
		SceneStack.push(ShopViewModel.SCENE)
	elseif spot == "radio" then
		local station = DepotStore.nextStation()
		ToastStore.push(`Radio: {station.name}`, "info", RADIO_TOAST_SECONDS, os.clock())
	end
end

-- The radio's music notes: a flipbook emitter on its RADIO_NOTES.EMITTER_NAME part, bobbing up and swaying, at the
-- station's rate (DepotSpotRules.noteRate: none on a quiet station). Nothing until the notes image is uploaded.
local function noteEmitter(radio: Instance): ParticleEmitter?
	local texture = DepotAssets.RADIO_NOTES
	local body = radio:FindFirstChild(DepotSpotConstants.RADIO_NOTES.EMITTER_NAME, true)
	if texture == nil or body == nil or not body:IsA("BasePart") then
		return nil
	end
	local emitter = Instance.new("ParticleEmitter")
	emitter.Name = "RadioNotes"
	emitter.Texture = texture
	emitter.FlipbookLayout = Enum.ParticleFlipbookLayout.Grid2x2
	emitter.FlipbookMode = Enum.ParticleFlipbookMode.Random
	emitter.Lifetime = NumberRange.new(1.6, 2.2)
	emitter.Speed = NumberRange.new(1.4, 2.0)
	emitter.SpreadAngle = Vector2.new(28, 28)
	emitter.EmissionDirection = Enum.NormalId.Top
	emitter.Acceleration = Vector3.new(0, -0.35, 0)
	emitter.Rotation = NumberRange.new(-20, 20)
	emitter.RotSpeed = NumberRange.new(-40, 40)
	emitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.2),
		NumberSequenceKeypoint.new(0.2, 0.55),
		NumberSequenceKeypoint.new(1, 0.45),
	})
	emitter.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.15, 0),
		NumberSequenceKeypoint.new(0.75, 0),
		NumberSequenceKeypoint.new(1, 1),
	})
	emitter.LightInfluence = 0.3
	emitter.LightEmission = 0.15
	emitter.Rate = DepotSpotRules.noteRate(DepotStore.stationDef())
	emitter.Parent = body
	return emitter
end

-- Listens for spot uses and bell rings; returns the stopper.
function DepotSpotSystem.start(): () -> ()
	local stopSpot = DepotEvents.packets.Spot.listen(function(value: { spot: string, employee: string })
		local opened = DepotSpotRules.decode(value)
		if opened ~= nil then
			open(opened)
		end
	end)
	local stopBell = DepotEvents.packets.Bell.listen(function(at: Vector3)
		SoundServiceClient:playOneShot(DepotSpotConstants.BELL_SOUND, { at = at })
		local bell = bellAt(at)
		if bell ~= nil then
			swing(bell)
			local pivot = bell:FindFirstChild(SWING.PIVOT_NAME, true)
			ringWave(
				if pivot ~= nil and pivot:IsA("Attachment") then pivot.WorldPosition - Vector3.new(0, 1.2, 0) else at
			)
		else
			ringWave(at)
		end
	end)
	local emitters: { [Instance]: ParticleEmitter } = {}
	local stopRadios = Observers.observeTag(InteractionConstants.TAG, function(target: Instance)
		if target:GetAttribute(InteractionConstants.KIND_ATTRIBUTE) ~= DepotSpotConstants.KINDS.radio then
			return nil
		end
		local emitter = noteEmitter(target)
		if emitter == nil then
			return nil
		end
		emitters[target] = emitter
		return function()
			emitters[target] = nil
			emitter:Destroy()
		end
	end)
	local stopStation = Charm.subscribe(DepotStore.station, function()
		local rate = DepotSpotRules.noteRate(DepotStore.stationDef())
		for _, emitter in emitters do
			emitter.Rate = rate
		end
	end)
	return function()
		stopSpot()
		stopBell()
		stopRadios()
		stopStation()
	end
end

return DepotSpotSystem
