--!strict
--[=[
	ShiftFeedbackSystem: how the shift sounds and feels on this client (Cleanup Crew spec §7 table: quota met (the
	in-house "contract met" jingle since 2026-10-17, was the truck horn), tier up, overtime "ticking music layer", clock
	out "horn honks"; the shift's start and end; the review's results jingle as it opens, ShiftCueUtils.jingle, with the
	music and the beds ducked under it: an EqualizerSoundEffect on the Music and Ambient groups, so the players' own
	group volumes are never touched). It
	watches ShiftStore's snapshot: ShiftCueUtils says which moments just happened, and each plays its sound
	(ShiftAssets.CUE_SOUNDS) and camera kick. Overtime keeps the ticking layer on (a SoundServiceClient ambience
	slot); a crew member's punch plays the punch clock; the truck's countdown honks, then ticks every second for its last
	COUNTDOWN_TICKS, louder for the last COUNTDOWN_LOUD. The stamps and sticky
	notes are toasts the server sends (ShiftNoticeUtils); the lights' flicker is Harlow's tells. A pending sound
	(ShiftAssets) is skipped silently and counted.

	Spec-exempt shell (Sound, Camera, Charm, RunService); the choices are the specced ShiftCueUtils.

	@class ShiftFeedbackSystem
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

export type ShiftFeedbackState = {
	ticking: boolean,
	counters: { [string]: number },
}

local ShiftShared = ReplicatedStorage.Shared.Features.Shift
local Charm = require(ReplicatedStorage.Packages.Charm)
local Logger = require(ReplicatedStorage.Shared.Core.Logger)
local ShiftAssets = require(ShiftShared.Data.ShiftAssets)
local ShiftConstants = require(ShiftShared.Data.ShiftConstants)
local ShiftTypes = require(ShiftShared.Data.ShiftTypes)
local SoundRegistry = require(ReplicatedStorage.Shared.Features.Sound.Data.SoundRegistry)
local ShiftCueUtils = require(ReplicatedStorage.Client.Features.Shift.Utils.ShiftCueUtils)
local ShiftStore = require(ReplicatedStorage.Client.Features.Shift.State.ShiftStore)
local CameraServiceClient = require(ReplicatedStorage.Client.Features.Camera.CameraServiceClient)
local SoundServiceClient = require(ReplicatedStorage.Client.Features.Sound.SoundServiceClient)

local log = Logger.new("ShiftFeedbackSystem")

local counters = { cues = 0, played = 0, pending = 0, ticks = 0, ducks = 0 }
local stoppers: { () -> () } = {}
local last: ShiftTypes.ShiftSnapshot? = nil
local ticking = false
local lastSecond: number? = nil

-- Whether a Shift sound can play: uploaded (a pending one is counted; an undeclared one is a developer error).
local function playable(id: string): boolean
	if ShiftAssets.SOUNDS[id] == nil then
		log:warn(`"{id}" is not a ShiftAssets sound`)
		return false
	end
	if not SoundRegistry.has(id) then
		counters.pending += 1
		return false
	end
	counters.played += 1
	return true
end

-- Plays a Shift sound with a handle (the results jingle, which the duck follows).
local function play(id: string, volumeScale: number?): SoundServiceClient.SoundHandle?
	if not playable(id) then
		return nil
	end
	return SoundServiceClient:play(id, { volumeScale = volumeScale })
end

-- Plays a Shift sound fire-and-forget (a cue, a countdown tick): its voice is reused.
local function shot(id: string, volumeScale: number?)
	if playable(id) then
		SoundServiceClient:playOneShot(id, { volumeScale = volumeScale })
	end
end

-- Ducks the music and the beds under `sound` (the results jingle) until it ends: every band of an EqualizerSoundEffect
-- on each group eases to RESULTS_DUCK_DB, then back to 0 and away.
local function duckUnder(sound: Sound)
	counters.ducks += 1
	local level = ShiftConstants.RESULTS_DUCK_DB
	for _, name in ShiftConstants.RESULTS_DUCK_GROUPS do
		local group = SoundService:FindFirstChild(name)
		if group ~= nil and group:IsA("SoundGroup") then
			local duck = Instance.new("EqualizerSoundEffect")
			duck.Name = "ShiftResultsDuck"
			duck.LowGain = 0
			duck.MidGain = 0
			duck.HighGain = 0
			duck.Parent = group
			local down = { LowGain = level, MidGain = level, HighGain = level }
			TweenService:Create(duck, TweenInfo.new(ShiftConstants.RESULTS_DUCK_IN), down):Play()
			local function release()
				local up = TweenService:Create(
					duck,
					TweenInfo.new(ShiftConstants.RESULTS_DUCK_OUT),
					{ LowGain = 0, MidGain = 0, HighGain = 0 }
				)
				up.Completed:Once(function()
					duck:Destroy()
				end)
				up:Play()
			end
			-- Ended for a jingle that plays out; Destroying for one cut short.
			local ended: RBXScriptConnection? = nil
			local gone: RBXScriptConnection? = nil
			local function once()
				if ended ~= nil then
					ended:Disconnect()
				end
				if gone ~= nil then
					gone:Disconnect()
				end
				ended = nil
				gone = nil
				release()
			end
			ended = sound.Ended:Connect(once)
			gone = sound.Destroying:Connect(once)
		end
	end
end

-- `cue` is a ShiftCueUtils.Cue (typed string: the CUE_SOUNDS index above widens it).
local function kick(cue: string)
	if cue == "quotaMet" then
		CameraServiceClient:kickFov(ShiftConstants.QUOTA_FOV_KICK, ShiftConstants.QUOTA_FOV_SECONDS)
	elseif cue == "tierUp" then
		CameraServiceClient:addTrauma(ShiftConstants.TIER_TRAUMA)
	elseif cue == "overtime" then
		CameraServiceClient:addTrauma(ShiftConstants.OVERTIME_TRAUMA)
	end
end

local function setTicking(on: boolean)
	if on == ticking then
		return
	end
	ticking = on
	if not on then
		SoundServiceClient:setAmbience(ShiftConstants.TICKING_LAYER, nil)
	elseif SoundRegistry.has(ShiftAssets.TICKING) then
		SoundServiceClient:setAmbience(ShiftConstants.TICKING_LAYER, ShiftAssets.TICKING)
	else
		counters.pending += 1
	end
end

local function onSnapshot(current: ShiftTypes.ShiftSnapshot?)
	local jingle = ShiftCueUtils.jingle(last, current)
	if jingle ~= nil then
		local handle = play(ShiftAssets.JINGLE_SOUNDS[jingle])
		if handle ~= nil then
			duckUnder(handle.sound)
		end
	end
	for _, cue in ShiftCueUtils.cues(last, current) do
		counters.cues += 1
		local id = ShiftAssets.CUE_SOUNDS[cue]
		if id ~= nil then
			shot(id)
		end
		kick(cue)
	end
	last = current
	setTicking(ShiftCueUtils.ticking(current))
end

-- The truck's countdown: one tick per whole second for its last seconds, louder at the end (ShiftCueUtils.tickScale).
local function stepCountdown()
	local second = ShiftCueUtils.countdown(ShiftStore.snapshot(), Workspace:GetServerTimeNow())
	if second == lastSecond then
		return
	end
	lastSecond = second
	local scale = ShiftCueUtils.tickScale(second)
	if scale ~= nil then
		counters.ticks += 1
		shot(ShiftAssets.COUNTDOWN_TICK, scale)
	end
end

local ShiftFeedbackSystem = {}

function ShiftFeedbackSystem.start()
	if #stoppers > 0 then
		return
	end
	-- The first snapshot is the baseline: it cues nothing, but the ticking layer matches it.
	last = ShiftStore.snapshot()
	setTicking(ShiftCueUtils.ticking(last))
	table.insert(stoppers, Charm.subscribe(ShiftStore.snapshot, onSnapshot))
	local elapsed = 0
	local connection = RunService.Heartbeat:Connect(function(deltaTime: number)
		elapsed += deltaTime
		if elapsed >= ShiftConstants.FEEDBACK_INTERVAL then
			elapsed = 0
			stepCountdown()
		end
	end)
	table.insert(stoppers, function()
		connection:Disconnect()
	end)
end

function ShiftFeedbackSystem.stop()
	for _, stop in stoppers do
		stop()
	end
	table.clear(stoppers)
	setTicking(false)
	last = nil
	lastSecond = nil
end

function ShiftFeedbackSystem.getState(): ShiftFeedbackState
	return { ticking = ticking, counters = table.clone(counters) }
end

return ShiftFeedbackSystem
