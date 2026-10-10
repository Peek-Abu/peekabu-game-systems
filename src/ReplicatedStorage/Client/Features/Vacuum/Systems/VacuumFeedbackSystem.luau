--!strict
--[=[
	VacuumFeedbackSystem: how vacuuming feels on this client (Cleanup Crew spec §7 "Vacuuming: suction particles
	into the nozzle, pile shrinks, rising whine, pop + sparkle, canister fills"; "Canister full: chime, dust bag
	pops out"). For every pile (Observers on PILE_TAG):
	- while anyone channels it (ChannelCount > 0): dust particles stream from the pile to the nearest vacuumer's
	  hand (re-aimed every frame) and a whine loops at the pile, its pitch and volume rising with ChannelProgress
	  (VacuumFeedbackFormulas.whine);
	- when it disappears after being vacuumed (VacuumFeedbackFormulas.cleared on its peak progress): a pop and a
	  sparkle burst where it was. The pile's shrinking is the server's (M1).
	Your own canister field ticks as it fills and chimes, with a pop at your feet, when it empties into a dust bag
	(VacuumFeedbackFormulas.canisterCue; only while a shift runs). Client-local instances; pending sounds
	(VacuumAssets) are skipped silently and counted.

	Spec-exempt shell (Instances, particles, Sound, Charm, RunService); the decisions are the specced
	VacuumFeedbackFormulas.

	@class VacuumFeedbackSystem
]=]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Charm = require(ReplicatedStorage.Packages.Charm)
local Observers = require(ReplicatedStorage.Packages.Observers)
local Logger = require(ReplicatedStorage.Shared.Core.Logger)
local InteractionConstants = require(ReplicatedStorage.Shared.Features.Interaction.Data.InteractionConstants)
local PublicPlayerTypes = require(ReplicatedStorage.Shared.Data.PublicPlayerTypes)
local SoundRegistry = require(ReplicatedStorage.Shared.Features.Sound.Data.SoundRegistry)
local SoundTypes = require(ReplicatedStorage.Shared.Features.Sound.Data.SoundTypes)
local StateSyncConstants = require(ReplicatedStorage.Shared.Features.StateSync.Data.StateSyncConstants)
local VacuumAssets = require(ReplicatedStorage.Shared.Features.Vacuum.Data.VacuumAssets)
local VacuumConstants = require(ReplicatedStorage.Shared.Features.Vacuum.Data.VacuumConstants)
local VacuumFeedbackFormulas = require(ReplicatedStorage.Client.Features.Vacuum.Utils.VacuumFeedbackFormulas)
local ShiftStore = require(ReplicatedStorage.Client.Features.Shift.State.ShiftStore)
local SoundServiceClient = require(ReplicatedStorage.Client.Features.Sound.SoundServiceClient)
local StateSyncClientStore = require(ReplicatedStorage.Client.Features.StateSync.State.StateSyncClientStore)

type PileFeel = {
	pile: BasePart,
	position: Vector3,
	progress: number,
	peak: number,
	count: number,
	activeAt: number,
	whine: SoundServiceClient.SoundHandle?,
	anchor: Attachment?,
	emitter: ParticleEmitter?,
}

export type VacuumFeedbackState = {
	piles: number,
	counters: { [string]: number },
}

local log = Logger.new("VacuumFeedbackSystem")

local active: { [BasePart]: PileFeel } = {}
local counters = { pops = 0, fills = 0, fulls = 0, played = 0, pending = 0 }
local stoppers: { () -> () } = {}
local lastFill: number? = nil

local function play(id: string, options: SoundTypes.PlayOptions?): SoundServiceClient.SoundHandle?
	if VacuumAssets.SOUNDS[id] == nil then
		log:warn(`"{id}" is not a VacuumAssets sound`)
		return nil
	end
	if not SoundRegistry.has(id) then
		counters.pending += 1
		return nil
	end
	counters.played += 1
	return SoundServiceClient:play(id, options)
end

local function readNumber(instance: Instance, name: string): number
	local value = instance:GetAttribute(name)
	return if type(value) == "number" then value else 0
end

-- The nearest vacuumer's hand (or root) to a pile, or nil.
local function vacuumerPoint(origin: Vector3): Vector3?
	local points: { Vector3 } = {}
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local hand = if character ~= nil
			then character:FindFirstChild("RightHand") or character:FindFirstChild("HumanoidRootPart")
			else nil
		if hand ~= nil and hand:IsA("BasePart") then
			table.insert(points, hand.Position)
		end
	end
	local index = VacuumFeedbackFormulas.nearest(origin, points, VacuumConstants.VACUUMER_RANGE)
	return if index ~= nil then points[index] else nil
end

local function startSuction(feel: PileFeel)
	if feel.emitter ~= nil then
		return
	end
	local anchor = Instance.new("Attachment")
	anchor.Name = "VacuumSuction"
	anchor.Parent = Workspace.Terrain
	anchor.WorldPosition = feel.position
	local emitter = Instance.new("ParticleEmitter")
	emitter.Color = ColorSequence.new(VacuumConstants.SUCTION_COLOR)
	emitter.Size = NumberSequence.new(VacuumConstants.SUCTION_SIZE, 0)
	emitter.Transparency = NumberSequence.new(0.2, 1)
	emitter.Lifetime = NumberRange.new(VacuumConstants.SUCTION_LIFETIME)
	emitter.Rate = VacuumConstants.SUCTION_RATE
	emitter.SpreadAngle = Vector2.new(20, 20)
	emitter.EmissionDirection = Enum.NormalId.Top
	emitter.LightEmission = 0.2
	emitter.Parent = anchor
	feel.anchor = anchor
	feel.emitter = emitter
end

local function stopSuction(feel: PileFeel)
	local anchor = feel.anchor
	local emitter = feel.emitter
	if emitter ~= nil then
		emitter.Enabled = false
	end
	if anchor ~= nil then
		task.delay(VacuumConstants.SUCTION_LIFETIME, function()
			anchor:Destroy()
		end)
	end
	feel.anchor = nil
	feel.emitter = nil
	local whine = feel.whine
	if whine ~= nil then
		whine:stop(0.15)
	end
	feel.whine = nil
end

-- Reads the pile's channel attributes and updates its suction and whine.
local function update(feel: PileFeel)
	feel.progress = readNumber(feel.pile, InteractionConstants.CHANNEL_PROGRESS_ATTRIBUTE)
	feel.count = readNumber(feel.pile, InteractionConstants.CHANNEL_COUNT_ATTRIBUTE)
	feel.peak = math.max(feel.peak, feel.progress)
	feel.position = feel.pile.Position
	if feel.count <= 0 then
		stopSuction(feel)
		return
	end
	feel.activeAt = os.clock()
	startSuction(feel)
	if feel.whine == nil and SoundRegistry.has(VacuumAssets.WHINE) then
		feel.whine = play(VacuumAssets.WHINE, { at = feel.pile })
	end
	local whine = feel.whine
	local def = SoundRegistry.get(VacuumAssets.WHINE)
	if whine ~= nil and def ~= nil then
		local pitch, volume = VacuumFeedbackFormulas.whine(feel.progress)
		whine.sound.PlaybackSpeed = pitch
		whine.sound.Volume = def.volume * volume
	end
end

local function pop(position: Vector3)
	counters.pops += 1
	play(VacuumAssets.POP, { at = position })
	local anchor = Instance.new("Attachment")
	anchor.Name = "VacuumSparkle"
	anchor.Parent = Workspace.Terrain
	anchor.WorldPosition = position
	local emitter = Instance.new("ParticleEmitter")
	emitter.Color = ColorSequence.new(VacuumConstants.SPARKLE_COLOR)
	emitter.Size = NumberSequence.new(0.5, 0)
	emitter.Lifetime = NumberRange.new(VacuumConstants.SPARKLE_LIFETIME)
	emitter.Speed = NumberRange.new(VacuumConstants.SPARKLE_SPEED * 0.5, VacuumConstants.SPARKLE_SPEED)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.LightEmission = 1
	emitter.Enabled = false
	emitter.Parent = anchor
	emitter:Emit(VacuumConstants.SPARKLE_COUNT)
	task.delay(VacuumConstants.SPARKLE_LIFETIME + 0.1, function()
		anchor:Destroy()
	end)
end

local function observePile(instance: Instance): (() -> ())?
	if not instance:IsA("BasePart") then
		return nil
	end
	local pile: BasePart = instance
	local feel: PileFeel = {
		pile = pile,
		position = pile.Position,
		progress = 0,
		peak = 0,
		count = 0,
		activeAt = -math.huge,
	}
	active[pile] = feel
	update(feel)
	local onChange = function()
		update(feel)
	end
	local progressChanged = pile:GetAttributeChangedSignal(InteractionConstants.CHANNEL_PROGRESS_ATTRIBUTE)
		:Connect(onChange)
	local countChanged = pile:GetAttributeChangedSignal(InteractionConstants.CHANNEL_COUNT_ATTRIBUTE):Connect(onChange)
	return function()
		progressChanged:Disconnect()
		countChanged:Disconnect()
		active[pile] = nil
		local vacuumed = VacuumFeedbackFormulas.cleared(feel.peak, os.clock() - feel.activeAt)
		stopSuction(feel)
		if vacuumed then
			pop(feel.position)
		end
	end
end

-- Points every running suction stream at its vacuumer's hand.
local function aim()
	for _, feel in active do
		local anchor = feel.anchor
		local emitter = feel.emitter
		if anchor ~= nil and emitter ~= nil then
			local target = vacuumerPoint(feel.position)
			if target ~= nil then
				-- Top (+Y) emission, turned to face the hand: lookAt points -Z at it, the X turn brings +Y round.
				anchor.WorldCFrame = CFrame.lookAt(feel.position, target) * CFrame.Angles(-math.pi / 2, 0, 0)
				local distance = (target - feel.position).Magnitude
				emitter.Speed = NumberRange.new(distance / VacuumConstants.SUCTION_LIFETIME)
			end
		end
	end
end

local function myFill(map: PublicPlayerTypes.PublicPlayerMap): number
	local me = map[StateSyncConstants.publicEntryKey(Players.LocalPlayer.UserId)]
	local value = if me ~= nil then me[VacuumConstants.PUBLIC_FIELD] else nil
	return if type(value) == "number" then value else 0
end

local function onPublic(map: PublicPlayerTypes.PublicPlayerMap)
	local fill = myFill(map)
	local before = lastFill
	lastFill = fill
	if before == nil then
		return
	end
	local snapshot = ShiftStore.snapshot()
	local running = snapshot ~= nil and snapshot.phase == "running"
	local cue = VacuumFeedbackFormulas.canisterCue(before, fill, VacuumConstants.CANISTER_CAPACITY, running)
	if cue == "fill" then
		counters.fills += 1
		play("canisterTick")
	elseif cue == "full" then
		counters.fulls += 1
		play("canisterChime")
		local character = Players.LocalPlayer.Character
		local root = if character ~= nil then character:FindFirstChild("HumanoidRootPart") else nil
		if root ~= nil and root:IsA("BasePart") then
			play("dustBagPop", { at = root.Position })
		end
	end
end

local VacuumFeedbackSystem = {}

function VacuumFeedbackSystem.start()
	if #stoppers > 0 then
		return
	end
	table.insert(stoppers, Observers.observeTag(VacuumConstants.PILE_TAG, observePile))
	lastFill = myFill(StateSyncClientStore.publicPlayers())
	table.insert(stoppers, Charm.subscribe(StateSyncClientStore.publicPlayers, onPublic))
	local connection = RunService.RenderStepped:Connect(aim)
	table.insert(stoppers, function()
		connection:Disconnect()
	end)
end

function VacuumFeedbackSystem.stop()
	for _, stop in stoppers do
		stop()
	end
	table.clear(stoppers)
	for _, feel in active do
		stopSuction(feel)
	end
	table.clear(active)
	lastFill = nil
end

function VacuumFeedbackSystem.getState(): VacuumFeedbackState
	local streaming = 0
	for _, feel in active do
		if feel.emitter ~= nil then
			streaming += 1
		end
	end
	return { piles = streaming, counters = table.clone(counters) }
end

return VacuumFeedbackSystem
