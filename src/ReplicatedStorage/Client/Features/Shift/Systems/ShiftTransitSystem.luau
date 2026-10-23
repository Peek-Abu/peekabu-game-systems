--!strict
--[=[
	ShiftTransitSystem: the client half of the load screen (the server half is the server's ShiftTransitSystem). Every
	TRANSIT_CHECK_INTERVAL it reads this player's hold from ShiftTransitStore.snapshot and decides what the screen
	shows (ShiftTransitRules.cover, written to ShiftTransitStore's covered and slip flags):

	- held: the route slip, from the moment the hold is published. Once the hold is built it streams the area around
	  its spot in (Player:RequestStreamAroundAsync) and checks the rest (ShiftTransitRules.verdict): the new office's
	  model (its LayoutSeed attribute), the character on its spot, the lighting preset applied (OfficeAtmosphereSystem
	  against OfficeAtmosphereUtils.preset). Then the scene must hold still (ShiftTransitRules.scene complete and the
	  office's lights, tagged OccupantConstants.LIGHT_TAG, no longer streaming in) for TRANSIT_SETTLE_SECONDS and
	  TRANSIT_SETTLE_FRAMES frames (the longer COLD settle when the camera has moved more than TRANSIT_COLD_DISTANCE
	  since the slip went up: the first arrival from the depot), so the engine's own light has caught up before the
	  reveal. How far along it is (ShiftTransitRules.progress) goes to ShiftTransitStore.progress for the loading bar.
	  When ready, or out of
	  time (logged with what it still waited for), it reports ready for that hold (ShiftEvents.TransitReady), stamps
	  ARRIVED for TRANSIT_ARRIVED_SECONDS, then clears.
	- booting: plain black until the first shift and transit sync, at most TRANSIT_BOOT_SECONDS.
	- a respawn during a running shift (after a catch): a black blink of TRANSIT_BLINK_SECONDS, no slip.
	- an office entrance's teleport (ShiftEvents.EntranceFade from OfficeEntranceSystem): black from the cover packet
	  until the uncover packet (at most ENTRANCE_COVER_SECONDS), fading over the packet's seconds
	  (ShiftTransitStore.fadeSeconds; any other cover resets it to the transit's own fades).

	Spec-exempt shell (Players, streaming, Workspace, ByteNet, RunService); the decisions are the specced
	ShiftTransitRules, the decoding the specced ShiftTransitUtils.

	@class ShiftTransitSystem
]=]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Logger = require(ReplicatedStorage.Shared.Core.Logger)
local OccupantConstants = require(ReplicatedStorage.Shared.Features.Occupant.Data.OccupantConstants)
local ShiftConstants = require(ReplicatedStorage.Shared.Features.Shift.Data.ShiftConstants)
local ShiftEvents = require(ReplicatedStorage.Shared.Features.Shift.Net.ShiftEvents)
local ShiftTypes = require(ReplicatedStorage.Shared.Features.Shift.Data.ShiftTypes)
local ShiftTransitUtils = require(ReplicatedStorage.Shared.Features.Shift.Utils.ShiftTransitUtils)
local OfficeAtmosphereSystem = require(ReplicatedStorage.Client.Features.Office.Systems.OfficeAtmosphereSystem)
local OfficeAtmosphereUtils = require(ReplicatedStorage.Client.Features.Office.Utils.OfficeAtmosphereUtils)
local ShiftStore = require(ReplicatedStorage.Client.Features.Shift.State.ShiftStore)
local ShiftTransitRules = require(ReplicatedStorage.Client.Features.Shift.Rules.ShiftTransitRules)
local ShiftTransitStore = require(ReplicatedStorage.Client.Features.Shift.State.ShiftTransitStore)

local log = Logger.new("ShiftTransitSystem")

-- How often the hold is checked (s).
local CHECK_INTERVAL = 0.1
-- An entrance's cover lifts by itself this long after it went up if the uncover never arrives (s).
local ENTRANCE_COVER_SECONDS = 4

export type ShiftTransitState = {
	cover: ShiftTypes.TransitCover,
	readyFor: number,
	waitingFor: string,
	shown: number,
	timeouts: number,
}

local stoppers: { () -> () } = {}
-- The last hold this client reported ready for (0: none).
local readyFor = 0
-- The hold the slip is up for, and since when (os.clock()).
local shownId = 0
local shownAt = 0
-- Holds whose area has been streamed in (or whose request finished, ok or not), and those requested.
local streamed: { [number]: boolean } = {}
local streaming: { [number]: boolean } = {}
local arrivedUntil = 0
local blinkUntil: number? = nil
-- An office entrance's black cover runs until this os.clock() time (nil: none).
local entranceUntil: number? = nil
local bootUntil = 0
local synced = false
local waitingFor = ""
local counters = { shown = 0, timeouts = 0 }
-- The settle (ShiftTransitRules): since when (os.clock()) and for how many frames the held scene has been complete and
-- unchanged (nil: it is not), and the office light count it was complete with.
local settledSince: number? = nil
local settledFrames = 0
local settledLights = -1
-- Where the camera was when the slip went up for the shown hold (the cold check).
local shownFrom: Vector3? = nil

local function rootPosition(): Vector3?
	local character = Players.LocalPlayer.Character
	if character == nil then
		return nil
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	return if root ~= nil and root:IsA("BasePart") then root.Position else nil
end

-- Whether the office built with `seed` is here (any workspace model carrying it); true when the hold names none.
local function seedSeen(seed: number?): boolean
	if seed == nil then
		return true
	end
	for _, child in Workspace:GetChildren() do
		if child:GetAttribute("LayoutSeed") == seed then
			return true
		end
	end
	return false
end

local function lit(): boolean
	local expected = OfficeAtmosphereUtils.preset(ShiftStore.snapshot(), Players.LocalPlayer.UserId)
	return OfficeAtmosphereSystem.getState().preset == expected
end

local function stream(hold: ShiftTypes.TransitHold)
	local spot = hold.spot
	if spot == nil or streaming[hold.id] then
		return
	end
	streaming[hold.id] = true
	task.spawn(function()
		local ok, err = pcall(function()
			Players.LocalPlayer:RequestStreamAroundAsync(spot, ShiftConstants.TRANSIT_STREAM_TIMEOUT)
		end)
		if not ok then
			log:warn(`streaming in the truck failed: {err}`)
		end
		streamed[hold.id] = true
	end)
end

local function step()
	local now = os.clock()
	local transitSnapshot = ShiftTransitStore.snapshot()
	if not synced and transitSnapshot ~= nil and ShiftStore.snapshot() ~= nil then
		synced = true
	end
	local hold = ShiftTransitUtils.holdOf(transitSnapshot, Players.LocalPlayer.UserId)
	local pending = hold ~= nil and hold.id ~= readyFor
	-- The loading bar's target: nothing yet, the readiness while held, full from the reveal on.
	local progress = 0
	if hold ~= nil and pending then
		if shownId ~= hold.id then
			shownId = hold.id
			shownAt = now
			local camera = Workspace.CurrentCamera
			shownFrom = if camera ~= nil then camera.CFrame.Position else nil
			counters.shown += 1
		end
		if hold.built then
			stream(hold)
		end
		local input: ShiftTransitRules.VerdictInput = {
			hold = hold,
			shownFor = now - shownAt,
			seedSeen = seedSeen(hold.seed),
			position = rootPosition(),
			streamed = streamed[hold.id] == true,
			lit = lit(),
			settledFor = 0,
			settledFrames = 0,
			cold = false,
		}
		local from = shownFrom
		local camera = Workspace.CurrentCamera
		if from ~= nil and camera ~= nil then
			input.cold = (camera.CFrame.Position - from).Magnitude > ShiftConstants.TRANSIT_COLD_DISTANCE
		end
		-- The scene restarts its settle whenever it is incomplete or more of the office's lights stream in.
		local lights = #CollectionService:GetTagged(OccupantConstants.LIGHT_TAG)
		if ShiftTransitRules.scene(input) ~= nil or lights ~= settledLights then
			settledSince = nil
			settledLights = lights
		elseif settledSince == nil then
			settledSince = now
			settledFrames = 0
		end
		local since = settledSince
		if since ~= nil then
			input.settledFor = now - since
			input.settledFrames = settledFrames
		end
		local verdict, reason = ShiftTransitRules.verdict(input)
		waitingFor = reason or ""
		progress = ShiftTransitRules.progress(input)
		if verdict ~= "waiting" then
			if verdict == "timeout" then
				counters.timeouts += 1
				log:warn(`the transit screen timed out waiting for "{reason or "?"}"; revealing anyway`)
			end
			readyFor = hold.id
			ShiftEvents.packets.TransitReady.send(hold.id)
			arrivedUntil = now + ShiftConstants.TRANSIT_ARRIVED_SECONDS
			pending = false
		end
	end
	if not pending then
		settledSince = nil
		settledLights = -1
	end
	local arriving = now < arrivedUntil
	local booting = not synced and now < bootUntil
	local blinking = blinkUntil ~= nil and now < blinkUntil
	-- Any other cover fades at the transit's own pace.
	if (pending or arriving or booting or blinking) and ShiftTransitStore.fadeSeconds() ~= nil then
		ShiftTransitStore.fadeSeconds(nil)
	end
	local blackUntil = blinkUntil
	if entranceUntil ~= nil and (blackUntil == nil or entranceUntil > blackUntil) then
		blackUntil = entranceUntil
	end
	local cover = ShiftTransitRules.cover({
		held = pending or arriving,
		booting = booting,
		blinkUntil = blackUntil,
		now = now,
	})
	local covered = cover ~= "none"
	if ShiftTransitStore.covered() ~= covered then
		ShiftTransitStore.covered(covered)
	end
	local slip = cover == "slip"
	if ShiftTransitStore.slip() ~= slip then
		ShiftTransitStore.slip(slip)
	end
	if ShiftTransitStore.arrived() ~= arriving then
		ShiftTransitStore.arrived(arriving)
	end
	if arriving then
		progress = 1
	end
	if ShiftTransitStore.progress() ~= progress then
		ShiftTransitStore.progress(progress)
	end
end

-- A respawn during a running shift (a catch's rehire): a short black blink hides the camera's jump, no slip.
local function onCharacter()
	local snapshot = ShiftStore.snapshot()
	if snapshot == nil or snapshot.phase ~= "running" then
		return
	end
	if table.find(snapshot.crew, Players.LocalPlayer.UserId) == nil then
		return
	end
	blinkUntil = os.clock() + ShiftConstants.TRANSIT_BLINK_SECONDS
end

-- An office entrance's teleport: black over `seconds` while it moves the player, then back over `seconds`.
local function onEntranceFade(data: { covered: boolean, seconds: number })
	ShiftTransitStore.fadeSeconds(math.clamp(data.seconds, 0, 1))
	entranceUntil = if data.covered then os.clock() + ENTRANCE_COVER_SECONDS else nil
	step()
end

local ShiftTransitSystem = {}

function ShiftTransitSystem.start()
	if #stoppers > 0 then
		return
	end
	bootUntil = os.clock() + ShiftConstants.TRANSIT_BOOT_SECONDS
	local elapsed = CHECK_INTERVAL
	local ticking = RunService.Heartbeat:Connect(function(deltaTime: number)
		settledFrames += 1
		elapsed += deltaTime
		if elapsed >= CHECK_INTERVAL then
			elapsed = 0
			step()
		end
	end)
	local respawning = Players.LocalPlayer.CharacterAdded:Connect(onCharacter)
	local stopFade = ShiftEvents.packets.EntranceFade.listen(onEntranceFade)
	table.insert(stoppers, function()
		ticking:Disconnect()
		respawning:Disconnect()
		stopFade()
	end)
	step()
end

function ShiftTransitSystem.stop()
	for _, stop in stoppers do
		stop()
	end
	table.clear(stoppers)
	table.clear(streamed)
	table.clear(streaming)
	ShiftTransitStore.covered(false)
	ShiftTransitStore.slip(false)
	ShiftTransitStore.arrived(false)
	ShiftTransitStore.progress(0)
	ShiftTransitStore.fadeSeconds(nil)
	entranceUntil = nil
end

function ShiftTransitSystem.getState(): ShiftTransitState
	return {
		cover = ShiftTransitStore.coverOf(ShiftTransitStore.covered(), ShiftTransitStore.slip()),
		readyFor = readyFor,
		waitingFor = waitingFor,
		shown = counters.shown,
		timeouts = counters.timeouts,
	}
end

return ShiftTransitSystem
