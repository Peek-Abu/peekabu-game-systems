--!strict
--[=[
	OccupantPresenceSystem: how Mr. Harlow sounds on this client (Cleanup Crew spec §4 "Tells": "heartbeat when he
	is near but hasn't seen you; 3D footsteps and muttering through walls; '!' + sting + chase music when he spots
	you; a sigh when he gives up"; "Voice": "pitched, distorted gibberish plus a speech bubble with the line").
	- His footsteps, paced by his speed (OccupantFeedbackUtils.footstepInterval), and a muttering loop on his head.
	- His mode changes (OccupantFeedbackUtils.cues): a "hm?" when he investigates, the sting when he spots someone
	  (2D when it is you, positional otherwise), the chase music while he chases you, a sigh when he gives up.
	- Your heartbeat, on the beat OccupantTellRules sets (the same rule as M2's red pulse).
	- His voice: each new bubble line types out (MaxVisibleGraphemes, OccupantFeedbackUtils.reveal) and plays one
	  uploaded gibberish clip chosen per line (OccupantFeedbackUtils.clipFor); "*sigh*" is not voiced.
	Reads only replicated state: his tagged model, its mode/target attributes, his speech billboard. Pending sounds
	(OccupantAssets) are skipped silently and counted.

	Spec-exempt shell (Sound, Instances, RunService); the choices are the specced OccupantFeedbackUtils and
	OccupantTellRules.

	@class OccupantPresenceSystem
]=]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

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
	speech: TextLabel?,
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
local stepClock = 0
local beatClock = 0
local revealText = ""
local revealStarted = 0
local revealing = false
local counters = { steps = 0, beats = 0, lines = 0, cues = 0, played = 0, pending = 0 }

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
				local bubble = head:FindFirstChild(OccupantConstants.SPEECH_NAME)
				local label = if bubble ~= nil then bubble:FindFirstChildOfClass("TextLabel") else nil
				return { model = instance, root = root, head = head, speech = label }
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

local function onSpeech(label: TextLabel)
	local text = label.Text
	if text == "" then
		revealing = false
		return
	end
	counters.lines += 1
	revealText = text
	revealStarted = os.clock()
	revealing = true
	label.MaxVisibleGraphemes = 0
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

local function attach(harlow: Harlow)
	current = harlow
	lastMode = nil
	lastMine = false
	stepClock = 0
	mutter = play("harlowMutter", { at = harlow.head })
	local label = harlow.speech
	if label ~= nil then
		speechConnection = label:GetPropertyChangedSignal("Text"):Connect(function()
			onSpeech(label)
		end)
	end
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
	revealing = false
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

local function stepFootsteps(harlow: Harlow, deltaTime: number)
	local velocity = harlow.root.AssemblyLinearVelocity
	local interval = OccupantFeedbackUtils.footstepInterval(Vector3.new(velocity.X, 0, velocity.Z).Magnitude)
	if interval == nil then
		stepClock = 0
		return
	end
	stepClock += deltaTime
	if stepClock >= interval then
		stepClock = 0
		counters.steps += 1
		play("harlowFootstep", { at = harlow.root })
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
	if not OccupantTellRules.heartbeat(distance, mode, mine) then
		beatClock = 0
		return
	end
	beatClock += deltaTime
	if beatClock >= OccupantTellRules.period(distance) then
		beatClock = 0
		counters.beats += 1
		local closeness = 1 - math.clamp(distance / OccupantConstants.HEARTBEAT_RANGE, 0, 1)
		play("harlowHeartbeat", { volumeScale = 0.6 + 0.6 * closeness })
	end
end

local function stepReveal(harlow: Harlow)
	local label = harlow.speech
	if not revealing or label == nil then
		return
	end
	local total = utf8.len(revealText) or #revealText
	local shown = OccupantFeedbackUtils.reveal(total, os.clock() - revealStarted, OccupantConstants.TYPE_RATE)
	if shown >= total then
		label.MaxVisibleGraphemes = -1
		revealing = false
	else
		label.MaxVisibleGraphemes = shown
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
	stepFootsteps(harlow, deltaTime)
	stepHeartbeat(harlow, mode, mine, deltaTime)
	stepReveal(harlow)
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
