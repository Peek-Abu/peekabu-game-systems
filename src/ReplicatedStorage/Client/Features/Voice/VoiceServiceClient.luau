--!strict
--[=[
	VoiceServiceClient: wires the voices this client may hear (design:
	docs/superpowers/specs/2026-10-09-voice-design.md).

	- An `AudioListener` on the current camera, wired to an `AudioDeviceOutput` (the speakers).
	- For every OTHER player, VoiceRoutingRules (from the public `dead` / `radio` fields) picks the route;
	  VoiceWiringTracker turns input, head and route changes into actions:
	  `spatial` → an `AudioEmitter` with the falloff on their character's Head (heard by the listener);
	  `radio` → an `AudioEqualizer` (band-limited) into the speakers; `direct` → straight into the speakers.
	- The server's access lists already decide who is audible; this only shapes how.

	Spec-exempt shell (audio Instances, Players); the decisions are VoiceRoutingRules and VoiceWiringTracker.

	@class VoiceServiceClient
]=]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Charm = require(ReplicatedStorage.Packages.Charm)
local Observers = require(ReplicatedStorage.Packages.Observers)
local DeathConstants = require(ReplicatedStorage.Shared.Features.Death.Data.DeathConstants)
local StateSyncConstants = require(ReplicatedStorage.Shared.Features.StateSync.Data.StateSyncConstants)
local VoiceConstants = require(ReplicatedStorage.Shared.Features.Voice.Data.VoiceConstants)
local VoiceRoutingRules = require(ReplicatedStorage.Shared.Features.Voice.Rules.VoiceRoutingRules)
local VoiceWiringTracker = require(ReplicatedStorage.Client.Features.Voice.State.VoiceWiringTracker)
local StateSyncClientStore = require(ReplicatedStorage.Client.Features.StateSync.State.StateSyncClientStore)

local localPlayer = Players.LocalPlayer
local tracker = VoiceWiringTracker.new()
-- The instances made for each wired speaker, destroyed together on unwire.
local live: { [number]: { Instance } } = {}
local listener: AudioListener? = nil
local output: AudioDeviceOutput? = nil
local stoppers: { () -> () } = {}

local function wire(source: Instance, target: Instance, parent: Instance)
	local link = Instance.new("Wire")
	link.SourceInstance = source
	link.TargetInstance = target
	link.Parent = parent
end

local function speakersOutput(): AudioDeviceOutput
	local current = output
	if current ~= nil and current.Parent ~= nil then
		return current
	end
	local fresh = Instance.new("AudioDeviceOutput")
	fresh.Name = "VoiceOutput"
	fresh.Parent = localPlayer
	output = fresh
	return fresh
end

local function apply(actions: { VoiceWiringTracker.Action })
	for _, action in actions do
		if action.kind == "unwire" then
			local made = live[action.userId]
			if made ~= nil then
				for _, instance in made do
					instance:Destroy()
				end
			end
			live[action.userId] = nil
		elseif action.route == "spatial" and action.head ~= nil then
			local emitter = Instance.new("AudioEmitter")
			emitter.Name = "VoiceEmitter"
			emitter:SetDistanceAttenuation(VoiceConstants.FALLOFF)
			emitter.Parent = action.head
			wire(action.input, emitter, emitter)
			live[action.userId] = { emitter }
		elseif action.route == "radio" then
			local equalizer = Instance.new("AudioEqualizer")
			equalizer.Name = "VoiceRadio"
			equalizer.LowGain = VoiceConstants.RADIO_LOW_GAIN
			equalizer.MidGain = VoiceConstants.RADIO_MID_GAIN
			equalizer.HighGain = VoiceConstants.RADIO_HIGH_GAIN
			equalizer.Parent = localPlayer
			wire(action.input, equalizer, equalizer)
			wire(equalizer, speakersOutput(), equalizer)
			live[action.userId] = { equalizer }
		else
			local fader = Instance.new("AudioFader")
			fader.Name = "VoiceDirect"
			fader.Parent = localPlayer
			wire(action.input, fader, fader)
			wire(fader, speakersOutput(), fader)
			live[action.userId] = { fader }
		end
	end
end

local function inputOf(player: Player): Instance?
	local input = player:FindFirstChild(VoiceConstants.INPUT_NAME)
	return if input ~= nil and input:IsA("AudioDeviceInput") then input else nil
end

local function headOf(character: Model?): BasePart?
	local head = if character ~= nil then character:FindFirstChild("Head") else nil
	return if head ~= nil and head:IsA("BasePart") then head else nil
end

-- Re-derives every remote player's route from the public map.
local function syncRoutes()
	local public = StateSyncClientStore.publicPlayers()
	local me = VoiceRoutingRules.infoFrom(
		public[StateSyncConstants.publicEntryKey(localPlayer.UserId)],
		DeathConstants.PUBLIC_FIELD,
		VoiceConstants.RADIO_FIELD
	)
	for _, player in Players:GetPlayers() do
		if player ~= localPlayer then
			local them = VoiceRoutingRules.infoFrom(
				public[StateSyncConstants.publicEntryKey(player.UserId)],
				DeathConstants.PUBLIC_FIELD,
				VoiceConstants.RADIO_FIELD
			)
			apply(tracker:setRoute(player.UserId, VoiceRoutingRules.route(me, them, VoiceConstants.DEAD_HEAR_LIVING)))
		end
	end
end

local function placeListener()
	local camera = Workspace.CurrentCamera
	if camera == nil then
		return
	end
	local current = listener
	if current ~= nil and current.Parent ~= nil then
		current.Parent = camera
		return
	end
	local fresh = Instance.new("AudioListener")
	fresh.Name = "VoiceListener"
	wire(fresh, speakersOutput(), fresh)
	fresh.Parent = camera
	listener = fresh
end

export type VoiceServiceClient = {
	dependencies: { string },
	start: (self: VoiceServiceClient) -> (),
	stop: (self: VoiceServiceClient) -> (),
	getState: (self: VoiceServiceClient) -> { [string]: any },
}

local VoiceServiceClient: VoiceServiceClient = {
	dependencies = { "StateSyncServiceClient" },

	start = function(_self)
		placeListener()
		local cameraChanged = Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(placeListener)
		table.insert(stoppers, function()
			cameraChanged:Disconnect()
		end)

		table.insert(
			stoppers,
			Observers.observePlayer(function(player: Player)
				if player == localPlayer then
					return nil
				end
				local userId = player.UserId
				local function syncInput()
					apply(tracker:setInput(userId, inputOf(player)))
				end
				local added = player.ChildAdded:Connect(syncInput)
				local removed = player.ChildRemoved:Connect(syncInput)
				syncInput()
				syncRoutes()
				return function()
					added:Disconnect()
					removed:Disconnect()
					apply(tracker:remove(userId))
				end
			end)
		)
		table.insert(
			stoppers,
			Observers.observeCharacter(function(player: Player, character: Model)
				if player == localPlayer then
					return nil
				end
				apply(tracker:setHead(player.UserId, headOf(character)))
				return function()
					apply(tracker:setHead(player.UserId, nil))
				end
			end)
		)
		table.insert(stoppers, Charm.subscribe(StateSyncClientStore.publicPlayers, syncRoutes))
		syncRoutes()
	end,

	stop = function(_self)
		for _, stop in stoppers do
			stop()
		end
		table.clear(stoppers)
		for userId in live do
			apply(tracker:remove(userId))
		end
	end,

	getState = function(_self)
		return { wired = tracker:wiredCount(), listener = listener ~= nil and listener.Parent ~= nil }
	end,
}

return VoiceServiceClient
