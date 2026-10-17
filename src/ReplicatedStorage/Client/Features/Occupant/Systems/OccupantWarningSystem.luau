--!strict
--[=[
	OccupantWarningSystem: the Manager's staged warning signs on this client (docs/superpowers/specs/2026-10-15-cleanup-
	crew-manager-behaviours-design.md §1, §5). Every TELL_INTERVAL, by the stage OccupantTellRules.stage gives for the
	local player's distance to him:

	- far: a pen click from him every PEN_CLICK seconds (his footsteps carry this far too: FootstepServiceClient);
	- mid: the lights near him flicker (OccupantTellSystem);
	- near and the chase: the heartbeat, the dread loop and the screen's mood are OccupantDreadSystem's;
	- chase: the sting and the chase music (OccupantPresenceSystem, OccupantChaseMusicSystem).

	Also his desk (positional): the chair as he sits down (OccupantTellRules.sat), his typing while he sits
	(OccupantTellRules.typing: a loop on his head that stops dead the moment it ends, e.g. in the ambush, whose own
	sound plays then), and his chair swivelling as he rises out of the ambush (OccupantTellRules.rose: our layer plus the
	two library layers of that mix, OccupantAssets.SWIVEL), and the ambush's intake as his head turns to something he
	noticed anywhere (OccupantTellRules.alerted, the `alert` mode). The slow turns (behaviours design §11): his neck's
	creak as one starts (stopped short with it), and the porcelain crack on the jerk; these are checked every frame, so
	the crack lands on the same frame as the chase sting. No PA since 2026-10-16. And the hider's reveal: while he looks under their spot or tips his head under their
	desk, their camera draws back into the spot and follows his face (OccupantTellRules.revealed). Reads only
	replicated state. Pending sounds are skipped silently and counted.

	Spec-exempt shell (Sound, Instances, RunService); the choices are the specced OccupantTellRules.

	@class OccupantWarningSystem
]=]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local OccupantAssets = require(ReplicatedStorage.Shared.Features.Occupant.Data.OccupantAssets)
local OccupantConstants = require(ReplicatedStorage.Shared.Features.Occupant.Data.OccupantConstants)
local OccupantTellRules = require(ReplicatedStorage.Shared.Features.Occupant.Rules.OccupantTellRules)
local SoundRegistry = require(ReplicatedStorage.Shared.Features.Sound.Data.SoundRegistry)
local SoundTypes = require(ReplicatedStorage.Shared.Features.Sound.Data.SoundTypes)
local CameraServiceClient = require(ReplicatedStorage.Client.Features.Camera.CameraServiceClient)
local HideConstants = require(ReplicatedStorage.Shared.Features.Hide.Data.HideConstants)
local SoundServiceClient = require(ReplicatedStorage.Client.Features.Sound.SoundServiceClient)

export type OccupantWarningState = {
	stage: string,
	typing: boolean,
	counters: { [string]: number },
}

local rng = Random.new()
local connection: RBXScriptConnection? = nil
local typing: SoundServiceClient.SoundHandle? = nil
-- The slow turn's creak while it sounds, and the phase the per-frame turn sounds last saw.
local creak: SoundServiceClient.SoundHandle? = nil
local turnPhase = ""
-- How fast a cut-short creak fades (s).
local CREAK_CUT = 0.08
local lastPhase = ""
local lastMode: string? = nil
local stage: string = "none"
local nextClick = 0
-- The hider's reveal camera while it shows (CameraServiceClient's token).
local reveal: number? = nil
local counters = {
	reveals = 0,
	clicks = 0,
	typingStarts = 0,
	typingStops = 0,
	ambushes = 0,
	turns = 0,
	sits = 0,
	swivels = 0,
	creaks = 0,
	creakCuts = 0,
	cracks = 0,
	pending = 0,
}

local function play(id: string, options: SoundTypes.PlayOptions?): SoundServiceClient.SoundHandle?
	if not SoundRegistry.has(id) then
		counters.pending += 1
		return nil
	end
	return SoundServiceClient:play(id, options)
end

-- The chair swivelling under him: our layer, and each library layer from its own start, cut where the mix cut it.
local function swivel(head: BasePart)
	counters.swivels += 1
	play("deskSwivel", { at = head })
	for _, layer in OccupantAssets.SWIVEL do
		local handle = play(layer.id, { at = head })
		if handle ~= nil then
			handle.sound.TimePosition = layer.start
			task.delay(layer.stopAt, function()
				handle:stop(layer.fade)
			end)
		end
	end
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

-- The hider's reveal: from where they huddle (their root, deeper in the spot than the peek camera), it follows his face
-- (OccupantTellRules.revealed).
local function setReveal(head: BasePart?, on: boolean)
	local token = reveal
	if on and token == nil and head ~= nil then
		local character = Players.LocalPlayer.Character
		local root = if character ~= nil then character:FindFirstChild("HumanoidRootPart") else nil
		local eye = if root ~= nil and root:IsA("BasePart")
			then root.Position
			else workspace.CurrentCamera.CFrame.Position
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

local function step()
	local now = os.clock()
	local model, head = harlow()
	if model == nil or head == nil then
		setReveal(nil, false)
		stopTyping()
		lastPhase = ""
		lastMode = nil
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
	if OccupantTellRules.sat(lastPhase, phase) then
		counters.sits += 1
		play("harlowSit", { at = head })
	end
	if phase == "ambush" and lastPhase ~= "ambush" then
		counters.ambushes += 1
		play("harlowAmbush", { at = head })
	elseif OccupantTellRules.rose(lastPhase, phase) then
		swivel(head)
	end
	if OccupantTellRules.alerted(lastMode, mode, phase) then
		counters.turns += 1
		play("harlowAmbush", { at = head })
	end
	lastPhase = phase
	lastMode = mode
	local me = Players.LocalPlayer
	local hiding = type(me:GetAttribute(HideConstants.PLAYER_SPOT_ATTRIBUTE)) == "string"
	local onMe = model:GetAttribute(OccupantConstants.TARGET_ATTRIBUTE) == me.UserId
	setReveal(head, OccupantTellRules.revealed(mode, phase, onMe, hiding))
	-- The stage for this player.
	local character = Players.LocalPlayer.Character
	local root = if character ~= nil then character:FindFirstChild("HumanoidRootPart") else nil
	if root == nil or not root:IsA("BasePart") then
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
end

local function stopCreak(fade: number)
	local sound = creak
	creak = nil
	if sound ~= nil then
		sound:stop(fade)
	end
end

-- Every frame: the slow turn's creak and the jerk's crack (behaviours design §11), on the frame the phase replicates.
local function turnSounds()
	local model, head = harlow()
	local value = if model ~= nil then model:GetAttribute(OccupantConstants.PHASE_ATTRIBUTE) else nil
	local phase = if type(value) == "string" then value else ""
	if phase == turnPhase then
		return
	end
	if OccupantTellRules.cutShort(turnPhase, phase) then
		counters.creakCuts += 1
		stopCreak(CREAK_CUT)
	end
	if head ~= nil and OccupantTellRules.slowTurned(turnPhase, phase) then
		stopCreak(0)
		counters.creaks += 1
		creak = play("harlowCreak", { at = head })
	end
	if head ~= nil and OccupantTellRules.jerked(turnPhase, phase) then
		counters.cracks += 1
		play("harlowCrack", { at = head })
	end
	turnPhase = phase
end

local OccupantWarningSystem = {}

function OccupantWarningSystem.start()
	if connection ~= nil then
		return
	end
	local elapsed = 0
	connection = RunService.Heartbeat:Connect(function(deltaTime: number)
		turnSounds()
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
	stopCreak(0)
	turnPhase = ""
	setReveal(nil, false)
	lastPhase = ""
	lastMode = nil
	stage = "none"
end

function OccupantWarningSystem.getState(): OccupantWarningState
	return { stage = stage, typing = typing ~= nil, counters = table.clone(counters) }
end

return OccupantWarningSystem
