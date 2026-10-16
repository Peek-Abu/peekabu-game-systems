--!strict
--[=[
	OccupantWarningSystem: the Manager's staged warning signs on this client (docs/superpowers/specs/2026-10-15-cleanup-
	crew-manager-behaviours-design.md §1, §5). Every TELL_INTERVAL, by the stage OccupantTellRules.stage gives for the
	local player's distance to him:

	- far: a pen click from him every PEN_CLICK seconds (his footsteps carry this far too: OccupantPresenceSystem);
	- mid: the lights near him flicker (OccupantTellSystem), and every PA_GAP seconds a PA_CHANCE roll plays the PA
	  chime with a corporate line on the paper subtitle (OccupantPaStore; per client, like the office's ambience);
	- near: the dread swell, louder the closer he is (pending slot; the heartbeat is OccupantPresenceSystem's);
	- chase: the sting and the chase music (OccupantPresenceSystem).

	Also his typing while he sits at a desk (OccupantTellRules.typing: a loop on his head that stops dead the moment it
	ends, e.g. in the ambush, whose own sound plays then), and the server's PA call-out (`callout`: the chime and the
	named line, for everyone). And the hider's reveal: while he looks under their spot or tips his head under their
	desk, their camera draws back into the spot and follows his face (OccupantTellRules.revealed). Reads only
	replicated state. Pending sounds are skipped silently and counted.

	Spec-exempt shell (Sound, Instances, RunService); the choices are the specced OccupantTellRules.

	@class OccupantWarningSystem
]=]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local OccupantConstants = require(ReplicatedStorage.Shared.Features.Occupant.Data.OccupantConstants)
local OccupantTellRules = require(ReplicatedStorage.Shared.Features.Occupant.Rules.OccupantTellRules)
local ShiftAssets = require(ReplicatedStorage.Shared.Features.Shift.Data.ShiftAssets)
local SoundRegistry = require(ReplicatedStorage.Shared.Features.Sound.Data.SoundRegistry)
local SoundTypes = require(ReplicatedStorage.Shared.Features.Sound.Data.SoundTypes)
local OccupantPaStore = require(ReplicatedStorage.Client.Features.Occupant.State.OccupantPaStore)
local CameraServiceClient = require(ReplicatedStorage.Client.Features.Camera.CameraServiceClient)
local HideConstants = require(ReplicatedStorage.Shared.Features.Hide.Data.HideConstants)
local SoundServiceClient = require(ReplicatedStorage.Client.Features.Sound.SoundServiceClient)

export type OccupantWarningState = {
	stage: string,
	typing: boolean,
	counters: { [string]: number },
}

-- The PA chime (Shift's overtime warning chime: the office PA).
local CHIME = ShiftAssets.CUE_SOUNDS.warning

local rng = Random.new()
local connection: RBXScriptConnection? = nil
local typing: SoundServiceClient.SoundHandle? = nil
local dread: SoundServiceClient.SoundHandle? = nil
local dreadBase = 0
-- The dread swell was asked for this near stage (a pending slot is asked once, not every tick).
local dreadAsked = false
local lastPhase = ""
local stage: string = "none"
local nextClick = 0
local nextPa = 0
-- The hider's reveal camera while it shows (CameraServiceClient's token).
local reveal: number? = nil
local counters =
	{ reveals = 0, clicks = 0, pa = 0, callouts = 0, typingStarts = 0, typingStops = 0, ambushes = 0, pending = 0 }

local function play(id: string, options: SoundTypes.PlayOptions?): SoundServiceClient.SoundHandle?
	if not SoundRegistry.has(id) then
		counters.pending += 1
		return nil
	end
	return SoundServiceClient:play(id, options)
end

local function within(range: OccupantConstants.Range): number
	return rng:NextNumber(range.min, range.max)
end

local function harlow(): (Model?, BasePart?)
	for _, instance in CollectionService:GetTagged(OccupantConstants.TAG) do
		local head = instance:FindFirstChild("Head")
		if instance:IsA("Model") and head ~= nil and head:IsA("BasePart") then
			return instance, head
		end
	end
	return nil, nil
end

local function stopTyping()
	local loop = typing
	typing = nil
	if loop ~= nil then
		-- Stops dead.
		loop:stop(0)
		counters.typingStops += 1
	end
end

local function setDread(closeness: number?)
	local loop = dread
	if closeness == nil then
		dreadAsked = false
		if loop ~= nil then
			loop:stop(OccupantConstants.DREAD_FADE)
			dread = nil
		end
		return
	end
	if loop == nil and not dreadAsked then
		dreadAsked = true
		loop = play("harlowDread")
		dread = loop
		dreadBase = if loop ~= nil then loop.sound.Volume else 0
	end
	if loop ~= nil then
		loop.sound.Volume = dreadBase * (0.3 + 0.7 * math.clamp(closeness, 0, 1))
	end
end

-- The hider's reveal: from just behind where their peek camera is, it follows his face (OccupantTellRules.revealed).
local function setReveal(head: BasePart?, on: boolean)
	local token = reveal
	if on and token == nil and head ~= nil then
		local camera = workspace.CurrentCamera
		local eye = camera.CFrame.Position - camera.CFrame.LookVector * OccupantConstants.REVEAL_BACK
		counters.reveals += 1
		reveal = CameraServiceClient:pushMode({
			kind = "custom",
			update = function(_dt: number): (CFrame, number?)
				return CFrame.lookAt(eye, head.Position), OccupantConstants.REVEAL_FOV
			end,
		}, OccupantConstants.REVEAL_PRIORITY)
	elseif not on and token ~= nil then
		CameraServiceClient:removeMode(token)
		reveal = nil
	end
end

local function paLine(now: number)
	local lines = OccupantConstants.PA_LINES
	counters.pa += 1
	play(CHIME)
	OccupantPaStore.show(lines[rng:NextInteger(1, #lines)], false, now + OccupantConstants.PA_SECONDS)
end

local function step()
	local now = os.clock()
	OccupantPaStore.expire(now)
	local model, head = harlow()
	if model == nil or head == nil then
		setReveal(nil, false)
		stopTyping()
		setDread(nil)
		lastPhase = ""
		stage = "none"
		return
	end
	local modeValue = model:GetAttribute(OccupantConstants.MODE_ATTRIBUTE)
	local phaseValue = model:GetAttribute(OccupantConstants.PHASE_ATTRIBUTE)
	local mode = if type(modeValue) == "string" then modeValue else nil
	local phase = if type(phaseValue) == "string" then phaseValue else ""
	-- His typing, and the ambush.
	if OccupantTellRules.typing(mode, phase) then
		if typing == nil then
			typing = play("harlowTyping", { at = head })
			if typing ~= nil then
				counters.typingStarts += 1
			end
		end
	else
		stopTyping()
	end
	if phase == "ambush" and lastPhase ~= "ambush" then
		counters.ambushes += 1
		play("harlowAmbush", { at = head })
	end
	lastPhase = phase
	local me = Players.LocalPlayer
	local hiding = type(me:GetAttribute(HideConstants.PLAYER_SPOT_ATTRIBUTE)) == "string"
	local onMe = model:GetAttribute(OccupantConstants.TARGET_ATTRIBUTE) == me.UserId
	setReveal(head, OccupantTellRules.revealed(mode, phase, onMe, hiding))
	-- The stage for this player.
	local character = Players.LocalPlayer.Character
	local root = if character ~= nil then character:FindFirstChild("HumanoidRootPart") else nil
	if root == nil or not root:IsA("BasePart") then
		setDread(nil)
		stage = "none"
		return
	end
	local distance = (root.Position - head.Position).Magnitude
	local mine = model:GetAttribute(OccupantConstants.TARGET_ATTRIBUTE) == Players.LocalPlayer.UserId
	local nextStage = OccupantTellRules.stage(distance, mode, mine)
	if nextStage ~= stage then
		stage = nextStage
		-- The first pen click comes soon after he is within earshot, then every PEN_CLICK.
		nextClick = now + rng:NextNumber(1, 3)
	end
	if stage == "far" and now >= nextClick then
		nextClick = now + within(OccupantConstants.PEN_CLICK)
		counters.clicks += 1
		play("harlowCurious", { at = head, volumeScale = 0.7 })
	end
	if stage == "mid" and now >= nextPa then
		nextPa = now + within(OccupantConstants.PA_GAP)
		if rng:NextNumber() < OccupantConstants.PA_CHANCE then
			paLine(now)
		end
	end
	setDread(if stage == "near" then 1 - distance / OccupantConstants.STAGE_NEAR else nil)
end

local OccupantWarningSystem = {}

function OccupantWarningSystem.start()
	if connection ~= nil then
		return
	end
	nextPa = os.clock() + within(OccupantConstants.PA_GAP) / 2
	local elapsed = 0
	connection = RunService.Heartbeat:Connect(function(deltaTime: number)
		elapsed += deltaTime
		if elapsed >= OccupantConstants.TELL_INTERVAL then
			elapsed = 0
			step()
		end
	end)
end

function OccupantWarningSystem.stop()
	local running = connection
	if running ~= nil then
		running:Disconnect()
		connection = nil
	end
	stopTyping()
	setDread(nil)
	setReveal(nil, false)
	OccupantPaStore.clear()
	lastPhase = ""
	stage = "none"
end

--[=[
	The server's PA call-out: the chime and the named line on the subtitle.
]=]
function OccupantWarningSystem.callout(line: string)
	counters.callouts += 1
	play(CHIME)
	OccupantPaStore.show(line, true, os.clock() + OccupantConstants.PA_SECONDS)
end

function OccupantWarningSystem.getState(): OccupantWarningState
	return { stage = stage, typing = typing ~= nil, counters = table.clone(counters) }
end

return OccupantWarningSystem
