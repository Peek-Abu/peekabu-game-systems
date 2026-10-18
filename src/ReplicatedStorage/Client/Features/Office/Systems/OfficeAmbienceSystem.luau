--!strict
--[=[
	OfficeAmbienceSystem: the ambient dread on this client (Cleanup Crew spec §7 "Ambient dread: phones ringing in
	empty rooms, an elevator dinging on its own, typing that stops when you enter"). While a shift runs, every
	AMBIENCE_INTERVAL: when the phone's wait is up, a phone rings on a desk with nobody near it (OfficeAmbienceUtils
	.pick over the OfficeAmbient emitters); the elevator dings on the same rule on its own wait; each typist types
	(a loop) while nobody is near and stops the moment you come within TYPING_STOP_RADIUS, staying quiet
	TYPING_QUIET_SECONDS; and the office bed's sweeteners (a ceiling tick, a pipe knock, a far typewriter key, a lift
	ding...), each kind on its own wait (SWEETENER_EVERY), one variant on a ring SWEETENER_NEAR..FAR studs round the
	camera (OfficeAmbienceUtils.sweetenerAt). Per client, no packets: each player hears their own office. Pending sounds (OfficeAssets)
	are skipped silently and counted.
	No play creates a Sound: the rings and sweeteners are fire-and-forget one-shots (SoundServiceClient:playOneShot,
	the sweeteners on the shared fixed-point anchors), and each emitter gets one idle voice the first time the running
	shift's office shows it (SoundServiceClient:prewarm), which its rings or its typing loop then reuse.

	Spec-exempt shell (Sound, Instances, RunService); the choices are the specced OfficeAmbienceUtils.

	@class OfficeAmbienceSystem
]=]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local OfficeClient = ReplicatedStorage.Client.Features.Office
local OfficeDecorConstants = require(ReplicatedStorage.Shared.Features.Office.Data.OfficeDecorConstants)
local SoundRegistry = require(ReplicatedStorage.Shared.Features.Sound.Data.SoundRegistry)
local OfficeAssets = require(OfficeClient.Data.OfficeAssets)
local OfficeAtmosphereConstants = require(OfficeClient.Data.OfficeAtmosphereConstants)
local OfficeAmbienceUtils = require(OfficeClient.Utils.OfficeAmbienceUtils)
local ShiftStore = require(ReplicatedStorage.Client.Features.Shift.State.ShiftStore)
local SoundServiceClient = require(ReplicatedStorage.Client.Features.Sound.SoundServiceClient)

export type OfficeAmbienceState = {
	typing: number,
	counters: { [string]: number },
}

type Typist = {
	handle: SoundServiceClient.SoundHandle?,
	quietUntil: number,
}

-- A plain map (iterated and cleared). The office is rebuilt every shift, and a client only sees the old
-- emitters leave the DataModel (never Destroying), so stepTypists drops the ones that have gone.
local typists: { [BasePart]: Typist } = {}
local rng = Random.new()
local nextPhone = 0
local nextElevator = 0
-- When each sweetener kind next sounds (os.clock()).
local nextSweetener: { [string]: number } = {}
local connection: RBXScriptConnection? = nil
-- The emitters already given their idle voice (a rebuilt office's old ones are dropped with the typists').
local warmed: { [BasePart]: boolean } = {}
local counters =
	{ phones = 0, elevators = 0, typingStarts = 0, typingStops = 0, sweeteners = 0, pending = 0, warmed = 0 }

local function play(id: string, at: BasePart | Vector3): SoundServiceClient.SoundHandle?
	if not SoundRegistry.has(id) then
		counters.pending += 1
		return nil
	end
	return SoundServiceClient:play(id, { at = at })
end

-- A fire-and-forget ring or sweetener (its voice is reused); false while it is pending.
local function shot(id: string, at: BasePart | Vector3): boolean
	if not SoundRegistry.has(id) then
		counters.pending += 1
		return false
	end
	SoundServiceClient:playOneShot(id, { at = at })
	return true
end

-- Gives each emitter not yet warmed its one idle voice (a ring, or a typist's loop, then reuses it).
local function warm(parts: { BasePart })
	for _, part in parts do
		if not warmed[part] then
			warmed[part] = true
			counters.warmed += SoundServiceClient:prewarm(part, 1)
		end
	end
end

local function emitters(): ({ OfficeAmbienceUtils.Emitter }, { BasePart })
	local list: { OfficeAmbienceUtils.Emitter } = {}
	local parts: { BasePart } = {}
	for _, instance in CollectionService:GetTagged(OfficeDecorConstants.AMBIENT_TAG) do
		local kind = instance:GetAttribute(OfficeDecorConstants.AMBIENT_KIND_ATTRIBUTE)
		if instance:IsA("BasePart") and type(kind) == "string" then
			table.insert(list, { kind = kind, position = instance.Position })
			table.insert(parts, instance)
		end
	end
	return list, parts
end

local function crew(): { Vector3 }
	local positions: { Vector3 } = {}
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local root = if character ~= nil then character:FindFirstChild("HumanoidRootPart") else nil
		if root ~= nil and root:IsA("BasePart") then
			table.insert(positions, root.Position)
		end
	end
	return positions
end

local function silence(typist: Typist)
	local handle = typist.handle
	if handle ~= nil then
		handle:stop(OfficeAtmosphereConstants.TYPING_FADE)
		counters.typingStops += 1
	end
	typist.handle = nil
end

local function silenceAll()
	for _, typist in typists do
		silence(typist)
	end
end

local function schedule(now: number)
	local constants = OfficeAtmosphereConstants
	nextPhone = now + OfficeAmbienceUtils.delay(rng:NextNumber(), constants.PHONE_MIN, constants.PHONE_MAX)
	nextElevator = now + OfficeAmbienceUtils.delay(rng:NextNumber(), constants.ELEVATOR_MIN, constants.ELEVATOR_MAX)
	for kind in OfficeAssets.SWEETENERS do
		local every = constants.SWEETENER_EVERY[kind]
		if every ~= nil then
			nextSweetener[kind] = now + OfficeAmbienceUtils.delay(rng:NextNumber(), every.min, every.max)
		end
	end
end

-- Each sweetener kind whose wait is up sounds one of its variants somewhere round the camera.
local function stepSweeteners(now: number)
	local camera = Workspace.CurrentCamera
	if camera == nil then
		return
	end
	local constants = OfficeAtmosphereConstants
	for kind, ids in OfficeAssets.SWEETENERS do
		local every = constants.SWEETENER_EVERY[kind]
		local due = nextSweetener[kind]
		if every ~= nil and due ~= nil and now >= due and #ids > 0 then
			nextSweetener[kind] = now + OfficeAmbienceUtils.delay(rng:NextNumber(), every.min, every.max)
			local at = OfficeAmbienceUtils.sweetenerAt(
				camera.CFrame.Position,
				rng:NextNumber(),
				rng:NextNumber(),
				constants.SWEETENER_NEAR,
				constants.SWEETENER_FAR
			)
			if shot(ids[OfficeAmbienceUtils.variant(rng:NextNumber(), #ids)], at) then
				counters.sweeteners += 1
			end
		end
	end
end

local function ring(
	kind: string,
	id: string,
	list: { OfficeAmbienceUtils.Emitter },
	parts: { BasePart },
	positions: { Vector3 }
): boolean
	local index =
		OfficeAmbienceUtils.pick(list, kind, positions, OfficeAtmosphereConstants.EMPTY_RADIUS, rng:NextNumber())
	if index == nil then
		return false
	end
	shot(id, parts[index])
	return true
end

local function stepTypists(
	list: { OfficeAmbienceUtils.Emitter },
	parts: { BasePart },
	positions: { Vector3 },
	now: number
)
	local character = Players.LocalPlayer.Character
	local root = if character ~= nil then character:FindFirstChild("HumanoidRootPart") else nil
	local me = if root ~= nil and root:IsA("BasePart") then root.Position else nil
	-- A rebuilt office's old emitters: stop their loop and let the part go.
	for part, typist in typists do
		if not part:IsDescendantOf(Workspace) then
			silence(typist)
			typists[part] = nil
		end
	end
	for part in warmed do
		if not part:IsDescendantOf(Workspace) then
			warmed[part] = nil
		end
	end
	for index, emitter in list do
		if emitter.kind == "typing" then
			local part = parts[index]
			local typist = typists[part]
			if typist == nil then
				typist = { handle = nil, quietUntil = 0 }
				typists[part] = typist
			end
			local distance = if me ~= nil then (me - emitter.position).Magnitude else math.huge
			if OfficeAmbienceUtils.typingStops(distance, OfficeAtmosphereConstants.TYPING_STOP_RADIUS) then
				silence(typist)
				typist.quietUntil = now + OfficeAtmosphereConstants.TYPING_QUIET_SECONDS
			elseif
				typist.handle == nil
				and now >= typist.quietUntil
				and OfficeAmbienceUtils.empty(emitter.position, positions, OfficeAtmosphereConstants.EMPTY_RADIUS)
			then
				typist.handle = play(OfficeAssets.TYPING, part)
				if typist.handle ~= nil then
					counters.typingStarts += 1
				else
					-- Pending: do not retry every tick.
					typist.quietUntil = now + OfficeAtmosphereConstants.TYPING_QUIET_SECONDS
				end
			end
		end
	end
end

local function step()
	local now = os.clock()
	local snapshot = ShiftStore.snapshot()
	if snapshot == nil or snapshot.phase ~= "running" then
		silenceAll()
		schedule(now)
		return
	end
	local list, parts = emitters()
	warm(parts)
	local positions = crew()
	if now >= nextPhone then
		if ring("phone", OfficeAssets.PHONE, list, parts, positions) then
			counters.phones += 1
		end
		nextPhone = now
			+ OfficeAmbienceUtils.delay(
				rng:NextNumber(),
				OfficeAtmosphereConstants.PHONE_MIN,
				OfficeAtmosphereConstants.PHONE_MAX
			)
	end
	if now >= nextElevator then
		if ring("elevator", OfficeAssets.ELEVATOR, list, parts, positions) then
			counters.elevators += 1
		end
		nextElevator = now
			+ OfficeAmbienceUtils.delay(
				rng:NextNumber(),
				OfficeAtmosphereConstants.ELEVATOR_MIN,
				OfficeAtmosphereConstants.ELEVATOR_MAX
			)
	end
	stepTypists(list, parts, positions, now)
	stepSweeteners(now)
end

local OfficeAmbienceSystem = {}

function OfficeAmbienceSystem.start()
	if connection ~= nil then
		return
	end
	schedule(os.clock())
	local elapsed = 0
	connection = RunService.Heartbeat:Connect(function(deltaTime: number)
		elapsed += deltaTime
		if elapsed >= OfficeAtmosphereConstants.AMBIENCE_INTERVAL then
			elapsed = 0
			step()
		end
	end)
end

function OfficeAmbienceSystem.stop()
	local running = connection
	if running ~= nil then
		running:Disconnect()
		connection = nil
	end
	silenceAll()
	table.clear(typists)
	table.clear(warmed)
end

function OfficeAmbienceSystem.getState(): OfficeAmbienceState
	local typing = 0
	for _, typist in typists do
		if typist.handle ~= nil then
			typing += 1
		end
	end
	return { typing = typing, counters = table.clone(counters) }
end

return OfficeAmbienceSystem
