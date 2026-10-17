--!strict
--[=[
	VacuumFeedbackSystem: how vacuuming feels on this client (Cleanup Crew spec §7 "Vacuuming: suction particles
	into the nozzle, pile shrinks, rising whine, pop + sparkle, canister fills"). For every pile, and every grimy valuable being cleaned (Observers on PILE_TAG and GRIME_TAG):
	- while anyone channels it (ChannelCount > 0): dust particles stream from the pile to the nearest vacuumer's
	  floor head (else hand; re-aimed every frame) and a whine loops at the pile, its pitch and volume rising with ChannelProgress
	  (VacuumFeedbackFormulas.whine), winding down (vacuumStop) when the channel stops;
	- when it disappears after being vacuumed (VacuumFeedbackFormulas.cleared on its peak progress): a pop and a
	  sparkle burst where it was. The pile's shrinking is the server's (M1).
	Listeners (`onPop`) hear every pop with the pile's size; `progressNear` says how far the pile at a point is (the
	wand's kick, brace and shimmy, VacuumMotionSystem).
	The canister is a live Gloom gauge (docs/superpowers/specs/2026-10-16-cleanup-crew-gloom-gleam-economy-design.md
	§3.1: no capacity, no dust bags): every backpack's gauge (its dust insert behind the window, VacuumVisualSystem on
	the server) eases toward the crew's Gloom removed as a share of the contract (the shift snapshot's cleared / quota,
	VacuumFeedbackFormulas.gaugeTarget), its lamp lit once the contract is met; the canister ticks as the Gloom rises
	(VacuumFeedbackFormulas.gloomTick; only while a shift runs) and chimes once when the contract is met. The insert is resized and
	its Weld moved locally (never replicated) from the full size and offset the server recorded on them. Client-local instances; pending sounds
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
local SoundRegistry = require(ReplicatedStorage.Shared.Features.Sound.Data.SoundRegistry)
local SoundTypes = require(ReplicatedStorage.Shared.Features.Sound.Data.SoundTypes)
local ShiftTypes = require(ReplicatedStorage.Shared.Features.Shift.Data.ShiftTypes)
local VacuumAssets = require(ReplicatedStorage.Shared.Features.Vacuum.Data.VacuumAssets)
local VacuumConstants = require(ReplicatedStorage.Shared.Features.Vacuum.Data.VacuumConstants)
local VacuumFeedbackFormulas = require(ReplicatedStorage.Client.Features.Vacuum.Utils.VacuumFeedbackFormulas)
local ShiftStore = require(ReplicatedStorage.Client.Features.Shift.State.ShiftStore)
local SoundServiceClient = require(ReplicatedStorage.Client.Features.Sound.SoundServiceClient)

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

type Gauge = { shown: number, drawn: number, part: BasePart? }

export type VacuumFeedbackState = {
	piles: number,
	counters: { [string]: number },
}

local log = Logger.new("VacuumFeedbackSystem")

local active: { [BasePart]: PileFeel } = {}
local counters = { pops = 0, ticks = 0, played = 0, pending = 0 }
local stoppers: { () -> () } = {}
-- The crew's Gloom last seen, and when the canister last ticked.
local lastGloom: number? = nil
local lastTick = 0
-- Whether the contract was met in the last snapshot (the chime plays once, when it is met).
local wasMet = true
-- What every gauge eases toward: the crew's Gloom as a share of the contract.
local gaugeTarget = 0
local gauges: { [number]: Gauge } = {}
-- Who hears a pile pop (its position, and its size across in studs): the wand's kick (VacuumMotionSystem).
local popListeners: { (position: Vector3, size: number) -> () } = {}

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

-- Where a character's suction ends: its held vacuum's floor head, else its hand, else its root.
local function nozzleOf(character: Model): Instance?
	local tool = character:FindFirstChild(VacuumConstants.TOOL_NAME)
	local head = if tool ~= nil then tool:FindFirstChild(VacuumConstants.FLOOR_HEAD_NAME) else nil
	return head or character:FindFirstChild("RightHand") or character:FindFirstChild("HumanoidRootPart")
end

-- The nearest vacuumer's floor head (or hand, or root) to a pile, or nil.
local function vacuumerPoint(origin: Vector3): Vector3?
	local points: { Vector3 } = {}
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local hand = if character ~= nil then nozzleOf(character) else nil
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
		-- The motor winds down from wherever the whine had climbed to.
		local windDown = play(VacuumAssets.STOP, { at = feel.position })
		if windDown ~= nil then
			windDown.sound.PlaybackSpeed = whine.sound.PlaybackSpeed
		end
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

local function pop(position: Vector3, size: number)
	counters.pops += 1
	for _, listener in popListeners do
		task.spawn(listener, position, size)
	end
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
			local base = pile:GetAttribute(VacuumConstants.BASE_SIZE_ATTRIBUTE)
			pop(feel.position, if typeof(base) == "Vector3" then base.Magnitude else pile.Size.Magnitude)
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

-- The gauge target and the canister tick, from the shift snapshot.
local function onShift(snapshot: ShiftTypes.ShiftSnapshot?)
	local running = snapshot ~= nil and snapshot.phase == "running"
	local gloom = if snapshot ~= nil then snapshot.cleared else 0
	gaugeTarget = if snapshot ~= nil then VacuumFeedbackFormulas.gaugeTarget(gloom, snapshot.quota) else 0
	local before = lastGloom
	lastGloom = gloom
	local now = os.clock()
	if before ~= nil and VacuumFeedbackFormulas.gloomTick(before, gloom, running, now, lastTick) then
		lastTick = now
		counters.ticks += 1
		play("canisterTick")
	end
	local met = snapshot ~= nil and snapshot.quotaMet
	if running and met and not wasMet then
		play("canisterChime")
	end
	wasMet = met
end

-- Sizes a backpack's dust insert to `shown` and lights its lamp when full. False when it has no gauge.
local function drawGauge(gauge: Gauge, character: Model?): boolean
	local backpack = if character ~= nil then character:FindFirstChild(VacuumConstants.BACKPACK_NAME) else nil
	local fill = if backpack ~= nil then backpack:FindFirstChild(VacuumConstants.GAUGE_FILL_NAME, true) else nil
	local weld = if fill ~= nil then fill:FindFirstChild(VacuumConstants.GAUGE_WELD_NAME) else nil
	if fill == nil or not fill:IsA("BasePart") or weld == nil or not weld:IsA("Weld") then
		return false
	end
	if gauge.part == fill and math.abs(gauge.drawn - gauge.shown) < 1e-4 then
		return true
	end
	local fullSize = fill:GetAttribute("GaugeFullSize")
	local fullC0 = weld:GetAttribute("GaugeFullC0")
	if typeof(fullSize) ~= "Vector3" or typeof(fullC0) ~= "CFrame" then
		return false
	end
	local height, drop = VacuumFeedbackFormulas.gaugeFill(fullSize.Y, gauge.shown)
	fill.Size = Vector3.new(fullSize.X, math.max(height, 0.001), fullSize.Z)
	fill.Transparency = if height < 0.005 then 1 else 0
	weld.C0 = fullC0 * CFrame.new(0, -drop, 0)
	local lamp = if backpack ~= nil then backpack:FindFirstChild(VacuumConstants.LAMP_NAME, true) else nil
	if lamp ~= nil and lamp:IsA("BasePart") then
		local lit = gauge.shown >= 0.98
		lamp.Material = if lit then Enum.Material.Neon else Enum.Material.SmoothPlastic
		lamp.Color = if lit then VacuumConstants.LAMP_ON_COLOR else VacuumConstants.LAMP_OFF_COLOR
	end
	gauge.part = fill
	gauge.drawn = gauge.shown
	return true
end

local function drawGauges(deltaTime: number)
	for _, player in Players:GetPlayers() do
		if gauges[player.UserId] == nil then
			gauges[player.UserId] = { shown = gaugeTarget, drawn = -1, part = nil }
		end
	end
	for userId, gauge in gauges do
		local player = Players:GetPlayerByUserId(userId)
		if player == nil then
			gauges[userId] = nil
			continue
		end
		gauge.shown = VacuumFeedbackFormulas.gaugeStep(gauge.shown, gaugeTarget, deltaTime, VacuumConstants.GAUGE_RATE)
		if not drawGauge(gauge, player.Character) then
			gauge.part = nil
		end
	end
end

local VacuumFeedbackSystem = {}

function VacuumFeedbackSystem.start()
	if #stoppers > 0 then
		return
	end
	table.insert(stoppers, Observers.observeTag(VacuumConstants.PILE_TAG, observePile))
	-- A grimy valuable being cleaned feels like a pile being vacuumed; it pops when it comes up spotless.
	table.insert(stoppers, Observers.observeTag(VacuumConstants.GRIME_TAG, observePile))
	onShift(ShiftStore.snapshot())
	table.insert(stoppers, Charm.subscribe(ShiftStore.snapshot, onShift))
	local connection = RunService.RenderStepped:Connect(function(deltaTime)
		aim()
		drawGauges(deltaTime)
	end)
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
	table.clear(gauges)
	lastGloom = nil
	gaugeTarget = 0
end

--[=[
	How full every canister's gauge is heading (0..1: the crew's Gloom as a share of the contract): the canister's
	bob grows heavier with it (VacuumMotionSystem).
]=]
function VacuumFeedbackSystem.gaugeShare(): number
	return gaugeTarget
end

--[=[
	Calls `listener` with the position and size (studs across) of every pile (or grimy valuable) that pops on this
	client; returns its disconnect.
]=]
function VacuumFeedbackSystem.onPop(listener: (position: Vector3, size: number) -> ()): () -> ()
	table.insert(popListeners, listener)
	return function()
		local index = table.find(popListeners, listener)
		if index ~= nil then
			table.remove(popListeners, index)
		end
	end
end

--[=[
	The progress (0..1) of the pile (or grimy valuable) being sucked nearest `position` within `range` studs, or nil when
	none is: the vacuum motion layers read how hard the pile at a holder's floor head is (VacuumMotionSystem).
]=]
function VacuumFeedbackSystem.progressNear(position: Vector3, range: number): number?
	local best: number? = nil
	local bestDistance = range
	for _, feel in active do
		if feel.count > 0 then
			local distance = (feel.position - position).Magnitude
			if distance <= bestDistance then
				best = feel.progress
				bestDistance = distance
			end
		end
	end
	return best
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
