--!strict
--[=[
	ShiftFeedbackSystem: how the shift sounds and feels on this client (Cleanup Crew spec §7 table: quota met
	"truck horn", tier up, overtime "ticking music layer", clock out "horn honks"; the shift's start and end). It
	watches ShiftStore's snapshot: ShiftCueUtils says which moments just happened, and each plays its sound
	(ShiftAssets.CUE_SOUNDS) and camera kick. Overtime keeps the ticking layer on (a SoundServiceClient ambience
	slot); a clock-out countdown ticks every second, louder for the last COUNTDOWN_LOUD. The stamps and sticky
	notes are toasts the server sends (ShiftNoticeUtils); the lights' flicker is Harlow's tells. A pending sound
	(ShiftAssets) is skipped silently and counted.

	Spec-exempt shell (Sound, Camera, Charm, RunService); the choices are the specced ShiftCueUtils.

	@class ShiftFeedbackSystem
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
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

local counters = { cues = 0, played = 0, pending = 0, ticks = 0 }
local stoppers: { () -> () } = {}
local last: ShiftTypes.ShiftSnapshot? = nil
local ticking = false
local lastSecond: number? = nil

-- Plays a Shift sound if it is uploaded; a pending one is counted, an undeclared one is a developer error.
local function play(id: string, volumeScale: number?)
	if ShiftAssets.SOUNDS[id] == nil then
		log:warn(`"{id}" is not a ShiftAssets sound`)
		return
	end
	if not SoundRegistry.has(id) then
		counters.pending += 1
		return
	end
	counters.played += 1
	SoundServiceClient:play(id, { volumeScale = volumeScale })
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
	for _, cue in ShiftCueUtils.cues(last, current) do
		counters.cues += 1
		local id = ShiftAssets.CUE_SOUNDS[cue]
		if id ~= nil then
			play(id)
		end
		kick(cue)
	end
	last = current
	setTicking(ShiftCueUtils.ticking(current))
end

-- The clock-out countdown: one tick per whole second, louder at the end.
local function stepCountdown()
	local second = ShiftCueUtils.countdown(ShiftStore.snapshot(), Workspace:GetServerTimeNow())
	if second == lastSecond then
		return
	end
	lastSecond = second
	if second ~= nil and second > 0 then
		counters.ticks += 1
		local loud = second <= ShiftConstants.COUNTDOWN_LOUD
		play(ShiftAssets.COUNTDOWN_TICK, if loud then ShiftConstants.COUNTDOWN_LOUD_SCALE else 1)
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
