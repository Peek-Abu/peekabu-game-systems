--!strict
--[=[
	OccupantDreadSystem: the Manager's proximity dread on this client (2026-10-17 feedback: "getting chased doesn't
	feel scary"; "him nearby should have screen effects or heartbeats or both, and to chase too"). Every frame, from
	replicated state only (his tagged model's mode / target / phase, the players' characters, the local HideSpotId,
	the shift snapshot), it reads the stage, his proximity (line of sight re-cast every SIGHT_INTERVAL) and the chase
	closeness (OccupantDreadFormulas), eases the look toward its target, and plays it:

	- your heartbeat (harlowHeartbeat): slow and quiet at the edge of his range, faster and louder as he closes, louder
	  still when he hunts, locked to the chase music's beat (OccupantChaseMusicSystem.beatPosition) while he chases you,
	  loud while you hide near him;
	- the dread loop (harlowDread, 2D) while he is near, hunting, or near a crewmate's chase (the chase music replaces it
	  in your own chase);
	- the screen: desaturated and, on each beat, a soft red pulse (VfxServiceClient), plus the vignette, the grain and
	  the beat's edge fringe (OccupantDreadTracker -> DreadOverlay); eased back while a camera frames his face
	  (OccupantFaceLightSystem.framing, OccupantDreadFormulas.framed) so it never crushes it;
	- in your chase, a held FOV squeeze (CameraServiceClient:setFovOffset), and while he sees or chases you, a camera
	  shake on his footfalls (FootstepServiceClient:onStep; the cameraShake setting scales it);
	- the mix: an EqualizerSoundEffect on the Ambient group and on every other Music-group sound (the overtime ticking)
	  ducks them and muffles their highs: harder in a chase, hardest with him close or while you hide near him. His
	  own sounds, the chase stems and the dread loop are never touched.

	Nothing in the depot hub or outside a running shift; a spectator gets only the crew look. Reduce motion (the
	engine's ReducedMotionEnabled, DREAD.REDUCE_MOTION or `setReduceMotion`) drops the squeeze, the fringe, the beat
	flashing and the grain's jitter. Pending sounds are skipped and counted. Every number is OccupantConstants.DREAD.

	Spec-exempt shell (Sound, Camera, Vfx, raycasts, RunService); the decisions are the specced OccupantDreadFormulas.

	@class OccupantDreadSystem
]=]

local CollectionService = game:GetService("CollectionService")
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local Workspace = game:GetService("Workspace")

local OccupantShared = ReplicatedStorage.Shared.Features.Occupant
local OccupantClient = ReplicatedStorage.Client.Features.Occupant
local OccupantAssets = require(OccupantShared.Data.OccupantAssets)
local OccupantConstants = require(OccupantShared.Data.OccupantConstants)
local OccupantTypes = require(OccupantShared.Data.OccupantTypes)
local OccupantTellRules = require(OccupantShared.Rules.OccupantTellRules)
local OccupantDreadFormulas = require(OccupantShared.Utils.OccupantDreadFormulas)
local OccupantChaseMusicSystem = require(OccupantClient.Systems.OccupantChaseMusicSystem)
local OccupantDreadTracker = require(OccupantClient.State.OccupantDreadTracker)
local OccupantFaceLightSystem = require(OccupantClient.Systems.OccupantFaceLightSystem)
local DepotAtmosphereUtils = require(ReplicatedStorage.Client.Features.Depot.Utils.DepotAtmosphereUtils)
local HideConstants = require(ReplicatedStorage.Shared.Features.Hide.Data.HideConstants)
local SoundRegistry = require(ReplicatedStorage.Shared.Features.Sound.Data.SoundRegistry)
local ShiftStore = require(ReplicatedStorage.Client.Features.Shift.State.ShiftStore)
local CameraServiceClient = require(ReplicatedStorage.Client.Features.Camera.CameraServiceClient)
local DeathServiceClient = require(ReplicatedStorage.Client.Features.Death.DeathServiceClient)
local FootstepServiceClient = require(ReplicatedStorage.Client.Features.Footstep.FootstepServiceClient)
local SoundServiceClient = require(ReplicatedStorage.Client.Features.Sound.SoundServiceClient)
local VfxServiceClient = require(ReplicatedStorage.Client.Features.Vfx.VfxServiceClient)

type DreadLook = OccupantTypes.DreadLook
type DreadStage = OccupantTypes.DreadStage

export type OccupantDreadState = {
	stage: DreadStage,
	proximity: number,
	sight: number,
	crew: number,
	hidden: boolean,
	-- How far the screen is eased back for a camera on his face (0..1).
	framing: number,
	reduceMotion: boolean,
	look: DreadLook,
	eqs: number,
	counters: { [string]: number },
}

local DREAD = OccupantConstants.DREAD
-- The camera FOV offset's owner, and the EQ's name on each sound or group it ducks.
local FOV_OWNER = "OccupantDread"
local EQ_NAME = "OccupantDreadEq"
-- Below this a look value counts as off (the screen request, the loop and the EQs are released).
local OFF = 0.01
-- How often the other Music-group sounds are looked for (s).
local SCAN_INTERVAL = 0.5
-- Sounds the duck never touches: the dread loop and the chase stems (its own Music-group sounds).
local OWN: { [string]: boolean } = { harlowDread = true }
for _, list in { OccupantAssets.CHASE_STEMS.base, OccupantAssets.CHASE_STEMS.near } do
	for _, id in list do
		OWN[id] = true
	end
end

local WHITE = Color3.new(1, 1, 1)

local connection: RBXScriptConnection? = nil
local stopSteps: (() -> ())? = nil
local look: DreadLook = OccupantDreadFormulas.ZERO
-- How far the screen is eased back for a camera on his face (0..1; OccupantFaceLightSystem.framing, eased).
local framing = 0
local stage: DreadStage = "none"
local proximity = 0
local crew = 0
local hidden = false
local sight = 1
local sightTarget = 1
local nextSight = 0
local nextScan = 0
local lastBeatAt = -math.huge
local beatPeriod = 1
local lastMusicBeat = -1
local reduceFlag = DREAD.REDUCE_MOTION
local screenToken: number? = nil
local dreadLoop: SoundServiceClient.SoundHandle? = nil
local dreadBase = 0
local eqs: { [Instance]: EqualizerSoundEffect? } = {}
local counters = { beats = 0, musicBeats = 0, shakes = 0, stages = 0, loops = 0, pending = 0, sightRays = 0 }
local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude
rayParams.IgnoreWater = true

local function reduceMotion(): boolean
	return reduceFlag or GuiService.ReducedMotionEnabled
end

local function harlowModel(): Model?
	for _, instance in CollectionService:GetTagged(OccupantConstants.TAG) do
		if instance:IsA("Model") then
			return instance
		end
	end
	return nil
end

local function rootOf(model: Model?): BasePart?
	local root = if model ~= nil then model:FindFirstChild("HumanoidRootPart") else nil
	return if root ~= nil and root:IsA("BasePart") then root else nil
end

local function characterRoot(userId: number): BasePart?
	local player = Players:GetPlayerByUserId(userId)
	return if player ~= nil then rootOf(player.Character) else nil
end

-- Whether this client is on a running shift, out of the depot hub.
local function onShift(): boolean
	local snapshot = ShiftStore.snapshot()
	return snapshot ~= nil
		and snapshot.phase == "running"
		and not DepotAtmosphereUtils.inHub(snapshot, Players.LocalPlayer.UserId)
end

-- Clear line of sight from the camera to his head (his body, the listener and you never block it).
local function castSight(head: BasePart, harlow: Model, listener: BasePart)
	local camera = Workspace.CurrentCamera
	if camera == nil then
		return
	end
	counters.sightRays += 1
	local ignore: { Instance } = { harlow, listener }
	local mine = Players.LocalPlayer.Character
	if mine ~= nil then
		table.insert(ignore, mine)
	end
	rayParams.FilterDescendantsInstances = ignore
	local from = camera.CFrame.Position
	local hit = Workspace:Raycast(from, head.Position - from, rayParams)
	sightTarget = if hit == nil then 1 else 0
end

local function beat()
	lastBeatAt = os.clock()
	if look.heart < OFF then
		return
	end
	if not SoundRegistry.has("harlowHeartbeat") then
		counters.pending += 1
		return
	end
	counters.beats += 1
	SoundServiceClient:play("harlowHeartbeat", { volumeScale = look.heart * DREAD.HEART_GAIN })
end

-- `slow`: his slow turn or stare (behaviours design §11.2) beats faster.
local function stepHeartbeat(now: number, slow: boolean)
	if stage == "chase" then
		beatPeriod = OccupantConstants.CHASE_BEAT
		local position = OccupantChaseMusicSystem.beatPosition()
		if position == nil then
			return
		end
		local index = OccupantDreadFormulas.musicBeat(position)
		if index ~= lastMusicBeat then
			lastMusicBeat = index
			counters.musicBeats += 1
			beat()
		end
		return
	end
	lastMusicBeat = -1
	local period = OccupantDreadFormulas.beatPeriod(stage, proximity, slow)
	if period == nil then
		return
	end
	beatPeriod = period
	if now - lastBeatAt >= period then
		beat()
	end
end

local function setLoop(level: number)
	local loop = dreadLoop
	if level < OFF then
		if loop ~= nil then
			loop:stop(DREAD.DREAD_FADE)
			dreadLoop = nil
		end
		return
	end
	if loop ~= nil then
		loop.sound.Volume = dreadBase * level
		return
	end
	if not SoundRegistry.has("harlowDread") then
		counters.pending += 1
		return
	end
	local started = SoundServiceClient:play("harlowDread")
	if started == nil then
		return
	end
	counters.loops += 1
	dreadLoop = started
	dreadBase = started.sound.Volume
	started.sound.Volume = dreadBase * level
end

local function releaseEqs()
	for _, eq in eqs do
		if eq ~= nil then
			eq:Destroy()
		end
	end
	table.clear(eqs)
end

local function eqFor(target: Instance): EqualizerSoundEffect
	local existing = eqs[target]
	if existing ~= nil and existing.Parent == target then
		return existing
	end
	local eq = Instance.new("EqualizerSoundEffect")
	eq.Name = EQ_NAME
	-- After any other effect on the group (the results duck), so the two simply stack.
	eq.Priority = 10
	eq.Parent = target
	eqs[target] = eq
	return eq
end

-- The duck and muffle on the Ambient group and on every other Music-group sound.
local function setMix(now: number)
	local low, mid, high = OccupantDreadFormulas.eq(look.duck, look.muffle)
	if low > -0.05 and high > -0.05 then
		releaseEqs()
		return
	end
	local ambient = SoundService:FindFirstChild("Ambient")
	if ambient ~= nil and ambient:IsA("SoundGroup") then
		eqFor(ambient)
	end
	if now >= nextScan then
		nextScan = now + SCAN_INTERVAL
		for _, child in SoundService:GetChildren() do
			if
				child:IsA("Sound")
				and not OWN[child.Name]
				and child.Volume > 0
				and child.SoundGroup ~= nil
				and child.SoundGroup.Name == "Music"
			then
				eqFor(child)
			end
		end
	end
	for target, eq in eqs do
		if eq == nil or target.Parent == nil or eq.Parent ~= target then
			eqs[target] = nil
			continue
		end
		eq.LowGain, eq.MidGain, eq.HighGain = low, mid, high
	end
end

local function setScreen(shown: DreadLook, pulse: number)
	local red = if reduceMotion() then shown.red * DREAD.REDUCED_RED else shown.red * pulse
	local active = shown.desaturate > OFF or red > OFF
	local token = screenToken
	if not active then
		if token ~= nil then
			VfxServiceClient:releaseScreen(token)
			screenToken = nil
		end
		return
	end
	local request = {
		tint = WHITE:Lerp(DREAD.PULSE_TINT, math.clamp(red, 0, 1)),
		saturation = -shown.desaturate,
		contrast = 0.06 * shown.vignette,
	}
	if token == nil then
		screenToken = VfxServiceClient:requestScreen(request)
	else
		VfxServiceClient:updateScreen(token, request)
	end
end

local function clearAll()
	look = OccupantDreadFormulas.ZERO
	framing = 0
	stage = "none"
	proximity = 0
	crew = 0
	hidden = false
	lastMusicBeat = -1
	setLoop(0)
	releaseEqs()
	local token = screenToken
	if token ~= nil then
		VfxServiceClient:releaseScreen(token)
		screenToken = nil
	end
	CameraServiceClient:setFovOffset(FOV_OWNER, 0)
	OccupantDreadTracker.clear()
end

local function step(dt: number)
	local now = os.clock()
	local me = Players.LocalPlayer
	local harlow = harlowModel()
	local harlowRoot = rootOf(harlow)
	local spectated = DeathServiceClient:spectating()
	local listener = if spectated ~= nil then characterRoot(spectated) else rootOf(me.Character)
	local active = onShift() and harlow ~= nil and harlowRoot ~= nil and listener ~= nil
	local mode: string? = nil
	local phase: string? = nil
	local target = 0
	local distance = math.huge
	crew = 0
	if active and harlow ~= nil and harlowRoot ~= nil and listener ~= nil then
		local modeValue = harlow:GetAttribute(OccupantConstants.MODE_ATTRIBUTE)
		local phaseValue = harlow:GetAttribute(OccupantConstants.PHASE_ATTRIBUTE)
		local targetValue = harlow:GetAttribute(OccupantConstants.TARGET_ATTRIBUTE)
		mode = if type(modeValue) == "string" then modeValue else nil
		phase = if type(phaseValue) == "string" then phaseValue else nil
		target = if type(targetValue) == "number" then targetValue else 0
		distance = (listener.Position - harlowRoot.Position).Magnitude
		local head = harlow:FindFirstChild("Head")
		if now >= nextSight and head ~= nil and head:IsA("BasePart") and distance < DREAD.RANGE_FAR then
			nextSight = now + DREAD.SIGHT_INTERVAL
			castSight(head, harlow, listener)
		end
		if mode == "chase" and target ~= 0 and target ~= me.UserId then
			local chased = characterRoot(target)
			if chased ~= nil then
				crew = OccupantDreadFormulas.crewWeight((chased.Position - listener.Position).Magnitude)
			end
		end
	end
	sight += (sightTarget - sight) * math.clamp(dt / DREAD.SIGHT_EASE, 0, 1)
	proximity = if distance < math.huge then OccupantDreadFormulas.proximity(distance, sight) else 0
	hidden = spectated == nil and type(me:GetAttribute(HideConstants.PLAYER_SPOT_ATTRIBUTE)) == "string"
	local nextStage: DreadStage = OccupantDreadFormulas.stage({
		active = active,
		spectating = spectated ~= nil,
		mode = mode,
		phase = phase,
		target = target,
		me = me.UserId,
		proximity = proximity,
		crew = crew,
	})
	if nextStage ~= stage then
		counters.stages += 1
		stage = nextStage
	end
	local closeness = if stage == "chase" then OccupantTellRules.chaseLayer(distance) else 0
	local reduced = reduceMotion()
	-- His slow turn or stare (behaviours design §11.2): the aware look at full strength, the music near-silent.
	local slow = OccupantDreadFormulas.slow(mode, phase)
	local aim = OccupantDreadFormulas.reduce(
		OccupantDreadFormulas.target(stage, proximity, closeness, crew, hidden and stage ~= "none", slow),
		reduced
	)
	look = OccupantDreadFormulas.ease(look, aim, dt)
	if mode == "catch" and target == me.UserId then
		-- The jumpscare camera sets its own FOV: the chase's squeeze lets go at once rather than narrowing it.
		look.squeeze = 0
	end

	-- A camera on his face (the catch, the reveal): the screen eases back so it does not crush his lit face.
	local frameAim = if OccupantFaceLightSystem.framing() then 1 else 0
	framing += (frameAim - framing) * (1 - math.exp(-DREAD.FACE_EASE * dt))
	local shown = OccupantDreadFormulas.framed(look, framing)

	stepHeartbeat(now, slow)
	local pulse = OccupantDreadFormulas.pulse(now - lastBeatAt, beatPeriod)
	setScreen(shown, pulse)
	OccupantDreadTracker.set({
		vignette = shown.vignette,
		grain = shown.grain,
		edge = if reduced then 0 else shown.edge * pulse,
		still = reduced,
	})
	CameraServiceClient:setFovOffset(FOV_OWNER, if look.squeeze > OFF then -look.squeeze else 0)
	setLoop(look.dread)
	setMix(now)
end

-- One of his footfalls landed: while he sees or chases you, close, the camera shakes (the cameraShake setting scales it).
local function onStep(model: Model, _record: unknown)
	if not CollectionService:HasTag(model, OccupantConstants.TAG) or reduceMotion() then
		return
	end
	local spectated = DeathServiceClient:spectating()
	local listener = if spectated ~= nil then characterRoot(spectated) else rootOf(Players.LocalPlayer.Character)
	local root = rootOf(model)
	if listener == nil or root == nil then
		return
	end
	local trauma = OccupantDreadFormulas.footfallTrauma(stage, (listener.Position - root.Position).Magnitude)
	if trauma > 0 then
		counters.shakes += 1
		CameraServiceClient:addTrauma(trauma)
	end
end

local OccupantDreadSystem = {}

function OccupantDreadSystem.start()
	if connection ~= nil then
		return
	end
	connection = RunService.Heartbeat:Connect(step)
	stopSteps = FootstepServiceClient:onStep(onStep)
end

function OccupantDreadSystem.stop()
	local running = connection
	if running ~= nil then
		running:Disconnect()
		connection = nil
	end
	local unsubscribe = stopSteps
	if unsubscribe ~= nil then
		unsubscribe()
		stopSteps = nil
	end
	clearAll()
end

--[=[
	Accessibility: on drops the FOV squeeze, the edge fringe, the beat flashing and the grain's jitter (the engine's
	ReducedMotionEnabled does the same). For a settings toggle to call.
]=]
function OccupantDreadSystem.setReduceMotion(on: boolean)
	reduceFlag = on
end

function OccupantDreadSystem.getState(): OccupantDreadState
	local count = 0
	for _ in eqs do
		count += 1
	end
	return {
		stage = stage,
		proximity = proximity,
		sight = sight,
		crew = crew,
		hidden = hidden,
		framing = framing,
		reduceMotion = reduceMotion(),
		look = table.clone(look),
		eqs = count,
		counters = table.clone(counters),
	}
end

return OccupantDreadSystem
