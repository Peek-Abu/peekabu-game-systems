--!strict
--[=[
	OccupantChaseMusicSystem: the chase music on the chased player's client (round-2 pick B: B minor, 144 bpm, 16 bars,
	five stems from one score; docs: characters/audio/shipped-assets.md). OccupantPresenceSystem calls `begin` when a
	chase starts on you and `finish` when it ends.

	- `begin`: the chase sting (one bar on F dim7 that resolves into the loop's downbeat), then, CHASE_STING_LEAD
	  seconds later, all five stems at once, looped, 2D: intensity 1 (ostinato + low) at full, intensity 2 (motif, ticks,
	  pulse) at the layer OccupantTellRules.chaseLayer gives for his distance, eased (OccupantTellRules.easeLayer) so a
	  jittery distance never pumps the music.
	- The stems stay locked: any stem more than CHASE_STEM_DRIFT seconds off the ostinato's TimePosition is put back on it.
	- Every stem plays DREAD.CHASE_MUSIC_GAIN louder than registered; `beatPosition` gives the dread the beat grid.
	- `finish`: the stems fade out over CHASE_MUSIC_FADE (a chase that ends inside the sting bar never starts them).
	- A chase that flickers off and on inside the sting bar (measured live: three starts in 0.85 s at the edge of his
	  sight) does not stack stings: the bar already sounding carries on, and the stems still start on its downbeat.
	Pending stems (OccupantAssets) are skipped; a pending sting falls back to the library "spotted" sting.

	Spec-exempt shell (Sound handles, RunService); the layer and easing are the specced OccupantTellRules.

	@class OccupantChaseMusicSystem
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local OccupantShared = ReplicatedStorage.Shared.Features.Occupant
local OccupantAssets = require(OccupantShared.Data.OccupantAssets)
local OccupantConstants = require(OccupantShared.Data.OccupantConstants)
local OccupantTellRules = require(OccupantShared.Rules.OccupantTellRules)
local SoundRegistry = require(ReplicatedStorage.Shared.Features.Sound.Data.SoundRegistry)
local SoundServiceClient = require(ReplicatedStorage.Client.Features.Sound.SoundServiceClient)

type SoundHandle = SoundServiceClient.SoundHandle

export type OccupantChaseMusicState = {
	active: boolean,
	stems: number,
	layer: number,
	counters: { [string]: number },
}

type Stem = {
	handle: SoundHandle,
	-- Its registered volume (the layer scales the intensity-2 stems from it).
	volume: number,
	near: boolean,
}

local active = false
-- When the stems start (os.clock()); nil once they have.
local startAt: number? = nil
-- When the last sting started (os.clock()).
local stingAt = -math.huge
local stems: { Stem } = {}
local layer = 0
local distanceOf: () -> number? = function(): number?
	return nil
end
local connection: RBXScriptConnection? = nil
local counters = { chases = 0, stings = 0, relocks = 0, pending = 0 }

local function playStem(id: string, near: boolean)
	if not SoundRegistry.has(id) then
		counters.pending += 1
		return
	end
	local handle = SoundServiceClient:play(id)
	if handle == nil then
		return
	end
	-- The chase plays louder than registered (DREAD.CHASE_MUSIC_GAIN: it was too quiet under his footsteps).
	local volume = handle.sound.Volume * OccupantConstants.DREAD.CHASE_MUSIC_GAIN
	handle.sound.Volume = volume
	if near then
		handle.sound.Volume = volume * layer
	end
	table.insert(stems, { handle = handle, volume = volume, near = near })
end

local function startStems()
	startAt = nil
	for _, id in OccupantAssets.CHASE_STEMS.base do
		playStem(id, false)
	end
	for _, id in OccupantAssets.CHASE_STEMS.near do
		playStem(id, true)
	end
end

local function stopStems(fade: number)
	for _, stem in stems do
		stem.handle:stop(fade)
	end
	table.clear(stems)
end

-- Puts every stem back on the first (the ostinato) when it has drifted.
local function relock()
	local lead = stems[1]
	if lead == nil then
		return
	end
	local length = lead.handle.sound.TimeLength
	local at = lead.handle.sound.TimePosition
	for index = 2, #stems do
		local sound = stems[index].handle.sound
		local drift = math.abs(sound.TimePosition - at)
		-- Across the loop point the two read a whole loop apart, not drifted.
		if drift > OccupantConstants.CHASE_STEM_DRIFT and (length <= 0 or drift < length / 2) then
			sound.TimePosition = at
			counters.relocks += 1
		end
	end
end

local function step(deltaTime: number)
	if not active then
		return
	end
	local distance = distanceOf()
	local target = if distance ~= nil then OccupantTellRules.chaseLayer(distance) else layer
	layer = OccupantTellRules.easeLayer(layer, target, deltaTime)
	local due = startAt
	if due ~= nil and os.clock() >= due then
		startStems()
	end
	for _, stem in stems do
		if stem.near then
			stem.handle.sound.Volume = stem.volume * layer
		end
	end
	relock()
end

local OccupantChaseMusicSystem = {}

function OccupantChaseMusicSystem.start()
	if connection ~= nil then
		return
	end
	connection = RunService.Heartbeat:Connect(step)
end

function OccupantChaseMusicSystem.stop()
	local running = connection
	if running ~= nil then
		running:Disconnect()
		connection = nil
	end
	OccupantChaseMusicSystem.finish(0)
end

--[=[
	A chase on you began: the sting now, the stems a bar later. `distance` reads his distance to you (nil: unknown).
]=]
function OccupantChaseMusicSystem.begin(distance: () -> number?)
	if active then
		return
	end
	active = true
	counters.chases += 1
	distanceOf = distance
	local now = distance()
	layer = if now ~= nil then OccupantTellRules.chaseLayer(now) else 0
	local clock = os.clock()
	if clock - stingAt >= OccupantConstants.CHASE_STING_LEAD then
		local sting = if SoundRegistry.has("harlowChaseSting") then "harlowChaseSting" else "harlowSpotted"
		if SoundRegistry.has(sting) then
			counters.stings += 1
			SoundServiceClient:playOneShot(sting)
		else
			counters.pending += 1
		end
		stingAt = clock
	end
	startAt = stingAt + OccupantConstants.CHASE_STING_LEAD
end

--[=[
	The chase on you ended: the stems fade out over `fade` (default CHASE_MUSIC_FADE).
]=]
function OccupantChaseMusicSystem.finish(fade: number?)
	active = false
	startAt = nil
	stopStems(fade or OccupantConstants.CHASE_MUSIC_FADE)
end

--[=[
	Where the chase music is on its beat grid, in seconds (nil while no chase on you sounds): the ostinato's
	TimePosition once the stems play, else the time since the sting bar began (it is one bar, so its beats line up with
	the loop's). The dread locks the heartbeat to it.
]=]
function OccupantChaseMusicSystem.beatPosition(): number?
	if not active then
		return nil
	end
	local lead = stems[1]
	if lead ~= nil then
		return lead.handle.sound.TimePosition
	end
	return math.max(0, os.clock() - stingAt)
end

function OccupantChaseMusicSystem.getState(): OccupantChaseMusicState
	return { active = active, stems = #stems, layer = layer, counters = table.clone(counters) }
end

return OccupantChaseMusicSystem
