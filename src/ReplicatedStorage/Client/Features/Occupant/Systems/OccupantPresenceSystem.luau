--!strict
--[=[
	OccupantPresenceSystem: how Mr. Harlow sounds on this client (Cleanup Crew spec §4 "Tells": "heartbeat when he
	is near but hasn't seen you; 3D footsteps and muttering through walls; '!' + sting + chase music when he spots
	you; a sigh when he gives up"; "Voice": "pitched, distorted gibberish plus a speech bubble with the line").
	- A muttering loop on his head. (His footsteps are FootstepServiceClient's, played as his feet land.)
	- His mode changes (OccupantFeedbackUtils.cues): a "hm?" when he investigates, the sting whenever a chase starts
	  (2D when it is on you, however it started, positional otherwise), the chase bed (the `harlowChase` music slot)
	  while he chases you, a sigh when he gives up.
	- Your heartbeat, on the beat OccupantTellRules.beatPeriod sets: the near heartbeat, and racing at CHASE_BEAT for as
	  long as he chases you (the chase bed's beat; OccupantTellSystem pulses the screen with it).
	- The chase sounds are kept warm while this client runs: one silent, never-played Sound per chase cue stays in
	  SoundService (preloaded through ContentProvider), so a fresh play is loaded at once. Measured 2026-10-16: a cold
	  sting took 0.23 s to load (0.88 s long, so a quarter of it was lost), a warm one 0.
	- His voice: each new line on his model (OccupantConstants.LINE_ATTRIBUTE) plays one uploaded gibberish clip chosen
	  per line (OccupantFeedbackUtils.clipFor); "*sigh*" is not voiced. The words are never shown: no text over his head
	  (2026-10-16: the tells stay diegetic).
	Reads only replicated state: his tagged model, its mode/target and line attributes. Pending sounds
	(OccupantAssets) are skipped silently and counted.

	Spec-exempt shell (Sound, Instances, RunService); the choices are the specced OccupantFeedbackUtils and
	OccupantTellRules.

	@class OccupantPresenceSystem
]=]

local CollectionService = game:GetService("CollectionService")
local ContentProvider = game:GetService("ContentProvider")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")

local OccupantShared = ReplicatedStorage.Shared.Features.Occupant
local Logger = require(ReplicatedStorage.Shared.Core.Logger)
local OccupantAssets = require(OccupantShared.Data.OccupantAssets)
local OccupantConstants = require(OccupantShared.Data.OccupantConstants)
local OccupantTellRules = require(OccupantShared.Rules.OccupantTellRules)
local OccupantFeedbackUtils = require(OccupantShared.Utils.OccupantFeedbackUtils)
local SoundRegistry = require(ReplicatedStorage.Shared.Features.Sound.Data.SoundRegistry)
local SoundTypes = require(ReplicatedStorage.Shared.Features.Sound.Data.SoundTypes)
local SoundServiceClient = require(ReplicatedStorage.Client.Features.Sound.SoundServiceClient)

type Harlow = {
	model: Model,
	root: BasePart,
	head: BasePart,
}

export type OccupantPresenceState = {
	present: boolean,
	mode: string?,
	chasingMe: boolean,
	music: boolean,
	counters: { [string]: number },
}

local log = Logger.new("OccupantPresenceSystem")

local current: Harlow? = nil
local mutter: SoundServiceClient.SoundHandle? = nil
local speechConnection: RBXScriptConnection? = nil
local connection: RBXScriptConnection? = nil
local lastMode: string? = nil
local lastMine = false
local ownsMusic = false
local beatClock = 0
local counters = { beats = 0, lines = 0, cues = 0, played = 0, pending = 0, stings = 0, preloaded = 0 }
-- The sounds a chase depends on, kept loaded (`warm`) so none starts late.
local PRELOAD: { string } = { "harlowSpotted", "harlowChase", "harlowHeartbeat" }
local warm: { Sound } = {}

local function play(id: string, options: SoundTypes.PlayOptions?): SoundServiceClient.SoundHandle?
	if OccupantAssets.SOUNDS[id] == nil then
		log:warn(`"{id}" is not an OccupantAssets sound`)
		return nil
	end
	if not SoundRegistry.has(id) then
		counters.pending += 1
		return nil
	end
	counters.played += 1
	return SoundServiceClient:play(id, options)
end

local function find(): Harlow?
	for _, instance in CollectionService:GetTagged(OccupantConstants.TAG) do
		if instance:IsA("Model") then
			local root = instance:FindFirstChild("HumanoidRootPart")
			local head = instance:FindFirstChild("Head")
			if root ~= nil and root:IsA("BasePart") and head ~= nil and head:IsA("BasePart") then
				return { model = instance, root = root, head = head }
			end
		end
	end
	return nil
end

local function setMusic(on: boolean)
	if on and not ownsMusic then
		if SoundRegistry.has("harlowChase") then
			ownsMusic = true
			SoundServiceClient:playMusic("harlowChase")
		else
			counters.pending += 1
		end
	elseif not on and ownsMusic then
		ownsMusic = false
		SoundServiceClient:playMusic(nil)
	end
end

-- A new line on his model: counted and, when it is words, voiced with one gibberish clip (never shown); a cleared
-- line ("") does nothing.
local function onSpeech(model: Model)
	local value = model:GetAttribute(OccupantConstants.LINE_ATTRIBUTE)
	local text = if type(value) == "string" then value else ""
	if text == "" then
		return
	end
	counters.lines += 1
	local harlow = current
	if harlow == nil or not OccupantFeedbackUtils.voiced(text) then
		return
	end
	local uploaded: { string } = {}
	for _, id in OccupantAssets.GIBBERISH do
		if SoundRegistry.has(id) then
			table.insert(uploaded, id)
		end
	end
	local index = OccupantFeedbackUtils.clipFor(text, #uploaded)
	if index == nil then
		counters.pending += 1
		return
	end
	play(uploaded[index], { at = harlow.head })
end

local function preload()
	if #warm > 0 then
		return
	end
	local sounds: { Instance } = {}
	for _, id in PRELOAD do
		local def = OccupantAssets.SOUNDS[id]
		if def ~= nil and def.assetId ~= OccupantAssets.PENDING then
			-- Silent and never played: it only holds the asset in memory.
			local sound = Instance.new("Sound")
			sound.Name = `{id}Warm`
			sound.SoundId = def.assetId
			sound.Volume = 0
			sound.Parent = SoundService
			table.insert(warm, sound)
			table.insert(sounds, sound)
		end
	end
	task.spawn(function()
		ContentProvider:PreloadAsync(sounds, function(_contentId: string, status: Enum.AssetFetchStatus)
			if status == Enum.AssetFetchStatus.Success then
				counters.preloaded += 1
			end
		end)
	end)
end

local function release()
	for _, sound in warm do
		sound:Destroy()
	end
	table.clear(warm)
end

local function attach(harlow: Harlow)
	preload()
	current = harlow
	lastMode = nil
	lastMine = false
	mutter = play("harlowMutter", { at = harlow.head })
	local model = harlow.model
	speechConnection = model:GetAttributeChangedSignal(OccupantConstants.LINE_ATTRIBUTE):Connect(function()
		onSpeech(model)
	end)
end

local function detach()
	local loop = mutter
	if loop ~= nil then
		loop:stop(0.3)
	end
	mutter = nil
	local listening = speechConnection
	if listening ~= nil then
		listening:Disconnect()
	end
	speechConnection = nil
	current = nil
	lastMode = nil
	lastMine = false
	setMusic(false)
end

-- `cue` is an OccupantFeedbackUtils.PresenceCue (typed string: iterating the cue list widens it).
local function onCue(cue: string, harlow: Harlow, mine: boolean)
	counters.cues += 1
	if cue == "curious" then
		play("harlowCurious", { at = harlow.head })
	elseif cue == "spotted" then
		counters.stings += 1
		if mine then
			play("harlowSpotted")
		else
			play("harlowSpotted", { at = harlow.head, volumeScale = 0.6 })
		end
	elseif cue == "giveUp" then
		play("harlowSigh", { at = harlow.head })
	elseif cue == "chaseStart" then
		setMusic(true)
	elseif cue == "chaseEnd" then
		setMusic(false)
	end
end

local function stepHeartbeat(harlow: Harlow, mode: string?, mine: boolean, deltaTime: number)
	local character = Players.LocalPlayer.Character
	local root = if character ~= nil then character:FindFirstChild("HumanoidRootPart") else nil
	if root == nil or not root:IsA("BasePart") then
		beatClock = 0
		return
	end
	local distance = (root.Position - harlow.root.Position).Magnitude
	local period = OccupantTellRules.beatPeriod(distance, mode, mine)
	if period == nil then
		beatClock = 0
		return
	end
	beatClock += deltaTime
	if beatClock >= period then
		beatClock = 0
		counters.beats += 1
		local closeness = if mine then 1 else 1 - math.clamp(distance / OccupantConstants.HEARTBEAT_RANGE, 0, 1)
		play("harlowHeartbeat", { volumeScale = 0.6 + 0.6 * closeness })
	end
end

-- The Harlow this client follows: the attached one while his model exists, else a freshly found one (attached).
local function ensure(): Harlow?
	local attached = current
	if attached ~= nil and attached.model.Parent ~= nil then
		return attached
	end
	if attached ~= nil then
		detach()
	end
	local fresh = find()
	if fresh ~= nil then
		attach(fresh)
	end
	return fresh
end

local function step(deltaTime: number)
	local harlow = ensure()
	if harlow == nil then
		return
	end
	local modeValue = harlow.model:GetAttribute(OccupantConstants.MODE_ATTRIBUTE)
	local mode = if type(modeValue) == "string" then modeValue else nil
	local mine = mode == "chase"
		and harlow.model:GetAttribute(OccupantConstants.TARGET_ATTRIBUTE) == Players.LocalPlayer.UserId
	for _, cue in OccupantFeedbackUtils.cues(lastMode, mode, lastMine, mine) do
		onCue(cue, harlow, mine)
	end
	lastMode = mode
	lastMine = mine
	stepHeartbeat(harlow, mode, mine, deltaTime)
end

local OccupantPresenceSystem = {}

function OccupantPresenceSystem.start()
	if connection ~= nil then
		return
	end
	connection = RunService.Heartbeat:Connect(step)
end

function OccupantPresenceSystem.stop()
	local running = connection
	if running ~= nil then
		running:Disconnect()
		connection = nil
	end
	detach()
	release()
end

function OccupantPresenceSystem.getState(): OccupantPresenceState
	return {
		present = current ~= nil,
		mode = lastMode,
		chasingMe = lastMine,
		music = ownsMusic,
		counters = table.clone(counters),
	}
end

return OccupantPresenceSystem
