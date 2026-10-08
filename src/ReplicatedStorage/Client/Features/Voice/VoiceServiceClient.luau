--!strict
--[=[
	VoiceServiceClient (R5 spec 2026-10-05 §2.3): spatial voice on client-built bodies, the CP3 route.

	- An `AudioListener` on the current camera, wired to an `AudioDeviceOutput` (the speakers).
	- Each OTHER player's replicated `VoiceInput` is wired to an `AudioEmitter` on their puppet's `Head`, with
	  the approved falloff (full to 10 studs, silent at 80). VoiceWiringTracker decides when; this shell does it.
	  Never on the local rig — you never hear yourself.
	- Puppets come and go through ReplicationServiceClient's `bodySpawned` / `bodyDespawned`; a
	  pooled puppet reused by another player is despawn → spawn, so an emitter never carries over.
	- The speaking icon is the ENGINE's: ReplicationRigTracker sets each remote player's `Character` to their puppet
	  (CP12 T5a). Text bubbles are off (spec decision 1) through the project file
	  (default.project.json turns the TextChatService bubble-chat configuration off); the voice icon shares
	  that billboard and stays (CP12 T5c).

	Spec-exempt shell (audio Instances, signals); its core VoiceWiringTracker is specced.

	@class VoiceServiceClient
]=]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Janitor = require(ReplicatedStorage.Packages.Janitor)
local Logger = require(ReplicatedStorage.Shared.Core.Logger)
local CharacterReplicationService = require(ReplicatedStorage.Client.Features.Replication.ReplicationServiceClient)
local VoiceWiringTracker = require(ReplicatedStorage.Client.Features.Voice.State.VoiceWiringTracker)

local INPUT_NAME = "VoiceInput"

type Live = { emitter: AudioEmitter, wire: Wire }

local log = Logger.new("VoiceServiceClient")
local janitor = Janitor.new()
local localPlayer = Players.LocalPlayer
local wiring = VoiceWiringTracker.new()
local live: { [number]: Live } = {}
local playerConnections: { [Player]: { RBXScriptConnection } } = {}
local listener: AudioListener? = nil

local function apply(actions: { VoiceWiringTracker.Action })
	for _, action in actions do
		if action.kind == "unwire" then
			local current = live[action.userId]
			if current ~= nil then
				current.wire:Destroy()
				current.emitter:Destroy()
				live[action.userId] = nil
			end
		else
			local emitter = Instance.new("AudioEmitter")
			emitter.Name = "VoiceEmitter"
			emitter:SetDistanceAttenuation(VoiceWiringTracker.FALLOFF)
			emitter.Parent = action.head
			local wire = Instance.new("Wire")
			wire.SourceInstance = action.input
			wire.TargetInstance = emitter
			wire.Parent = emitter
			live[action.userId] = { emitter = emitter, wire = wire }
		end
	end
end

local function inputOf(player: Player): Instance?
	local input = player:FindFirstChild(INPUT_NAME)
	return if input ~= nil and input:IsA("AudioDeviceInput") then input else nil
end

local function headOf(rig: Model): BasePart?
	local head = rig:FindFirstChild("Head")
	return if head ~= nil and head:IsA("BasePart") then head else nil
end

local function onBodySpawned(player: Player, rig: Model)
	if player ~= localPlayer then
		apply(VoiceWiringTracker.setHead(wiring, player.UserId, headOf(rig)))
	end
end

local function onBodyDespawned(player: Player, rig: Model)
	local head = headOf(rig)
	if player ~= localPlayer and head ~= nil then
		apply(VoiceWiringTracker.clearHead(wiring, player.UserId, head))
	end
end

local function watchPlayer(player: Player)
	if player == localPlayer or playerConnections[player] ~= nil then
		return
	end
	local userId = player.UserId
	local function syncInput()
		apply(VoiceWiringTracker.setInput(wiring, userId, inputOf(player)))
	end
	playerConnections[player] = { player.ChildAdded:Connect(syncInput), player.ChildRemoved:Connect(syncInput) }
	syncInput()
	local rig = CharacterReplicationService:getRig(player)
	if rig ~= nil then
		onBodySpawned(player, rig)
	end
end

-- CP10: a leaver's wiring must go on leave, or a rejoin (a NEW Player) is wired twice.
local function unwatchPlayer(player: Player)
	local connections = playerConnections[player]
	if connections ~= nil then
		for _, connection in connections do
			connection:Disconnect()
		end
		playerConnections[player] = nil
	end
	apply(VoiceWiringTracker.remove(wiring, player.UserId))
end

local function buildListener(): AudioListener
	local newListener = Instance.new("AudioListener")
	newListener.Name = "VoiceListener"
	local output = Instance.new("AudioDeviceOutput")
	output.Parent = newListener
	local wire = Instance.new("Wire")
	wire.SourceInstance = newListener
	wire.TargetInstance = output
	wire.Parent = newListener
	return newListener
end

-- A listener whose Parent is nil is unplaced or was destroyed with its camera (a destroyed instance's Parent
-- is locked), so it is rebuilt rather than re-parented. The janitor key destroys the old one.
local function placeListener()
	local camera = Workspace.CurrentCamera
	if camera == nil then
		return
	end
	local current = listener
	if current == nil or current.Parent == nil then
		local fresh = buildListener()
		listener = fresh
		janitor:Add(fresh, "Destroy", "Listener")
		fresh.Parent = camera
	else
		current.Parent = camera
	end
end

export type VoiceServiceClient = {
	dependencies: { string },
	init: (self: VoiceServiceClient) -> (),
	start: (self: VoiceServiceClient) -> (),
	stop: (self: VoiceServiceClient) -> (),
	getState: (self: VoiceServiceClient) -> { wired: number, emitters: number, listener: boolean },
}

local VoiceServiceClient: VoiceServiceClient = {
	dependencies = { "ReplicationServiceClient" },

	init = function(_self)
		log:debug("VoiceServiceClient initialized")
	end,

	start = function(_self)
		placeListener()
		janitor:Add(Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(placeListener), "Disconnect")

		janitor:Add(CharacterReplicationService.bodySpawned:Connect(onBodySpawned), "Disconnect")
		janitor:Add(CharacterReplicationService.bodyDespawned:Connect(onBodyDespawned), "Disconnect")
		janitor:Add(Players.PlayerAdded:Connect(watchPlayer), "Disconnect")
		janitor:Add(Players.PlayerRemoving:Connect(unwatchPlayer), "Disconnect")
		for _, player in Players:GetPlayers() do
			watchPlayer(player)
		end
	end,

	stop = function(_self)
		janitor:Cleanup()
		for player in playerConnections do
			unwatchPlayer(player)
		end
		listener = nil
	end,

	getState = function(_self)
		local emitters = 0
		for _ in live do
			emitters += 1
		end
		local current = listener
		return {
			wired = VoiceWiringTracker.wiredCount(wiring),
			emitters = emitters,
			listener = current ~= nil and current.Parent ~= nil,
		}
	end,
}

return VoiceServiceClient
