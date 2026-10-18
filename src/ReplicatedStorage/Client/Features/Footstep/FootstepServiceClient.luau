--!strict
--[=[
	FootstepServiceClient: footsteps for every character this client can hear, driven by their feet
	(FootstepEmitterSystem: a step plays the frame a foot lands, only while the character moves on the ground).

	- Who: every player's character (its set: the FootstepSet attribute, else its EmployeeName in lower case when
	  FootstepAssets has that set, else `default`) and every model tagged with a FootstepConstants.TAG_SETS tag (the
	  Manager: `harlow`).
	- Gait: hidden (the player's HideSpotId attribute), crouching (the character's Crouching attribute, CrouchServiceServer's),
	  sprinting (the player's Sprinting attribute, the server's decision); an NPC walks, louder as it speeds up.
	- Roblox's own character sounds (RbxCharacterSounds' running loop, jump, landing, wind, climb, swim, get-up and the
	  "oof"; FootstepConstants.DEFAULT_SOUNDS) are muted on every character this service follows: each is moved into a
	  silent SoundGroup (the engine's script rewrites their Volume, never their SoundGroup), an AudioPlayer one is
	  zeroed. Event-driven: each rig's root is read once and then watched (ChildAdded, and the clip's SoundGroup /
	  Volume), never searched per frame. The game's land, jump and ragdoll body-fall are FootstepLandingSystem's (started here).
	- Every pool's sounds (and the jumps, the land and the body-fall) are kept loaded while this client runs (one silent, never-played Sound per asset in
	  SoundService, preloaded through ContentProvider): a cold first step loaded late, the foot already down. An
	  asset that fails to load drops its warm Sound.
	- getState: the counters and the last RECENT steps (the live sync check reads them). onStep: hear each step as it
	  plays (the Manager's dread shakes the camera on his footfalls).

	Spec-exempt shell (Players, CollectionService, RunService); the decisions are the specced FootstepPlantFormulas,
	FootstepGaitFormulas and FootstepSurfaceUtils.

	@class FootstepServiceClient
]=]

local CollectionService = game:GetService("CollectionService")
local ContentProvider = game:GetService("ContentProvider")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local Workspace = game:GetService("Workspace")

local FootstepAssets = require(ReplicatedStorage.Client.Features.Footstep.Data.FootstepAssets)
local FootstepConstants = require(ReplicatedStorage.Client.Features.Footstep.Data.FootstepConstants)
local FootstepGaitFormulas = require(ReplicatedStorage.Client.Features.Footstep.Utils.FootstepGaitFormulas)
local FootstepEmitterSystem = require(ReplicatedStorage.Client.Features.Footstep.Systems.FootstepEmitterSystem)
local FootstepLandingSystem = require(ReplicatedStorage.Client.Features.Footstep.Systems.FootstepLandingSystem)
local SoundRegistry = require(ReplicatedStorage.Shared.Features.Sound.Data.SoundRegistry)
local EmployeeConstants = require(ReplicatedStorage.Shared.Features.Employee.Data.EmployeeConstants)
local HideConstants = require(ReplicatedStorage.Shared.Features.Hide.Data.HideConstants)
local SprintConstants = require(ReplicatedStorage.Shared.Features.Sprint.Data.SprintConstants)

type Rig = FootstepEmitterSystem.Rig
type GaitInput = FootstepGaitFormulas.GaitInput

-- A model waiting for its rig (its Humanoid, root or feet may replicate a frame late).
type Pending = {
	setName: () -> string,
	gaitInput: () -> GaitInput,
}

local rigs: { [Model]: Rig } = {}
local culled: { [Model]: boolean } = {}
local pending: { [Model]: Pending } = {}
local recent: { FootstepEmitterSystem.StepRecord } = {}
local counters: FootstepEmitterSystem.Counters = { steps = 0, gated = 0, silent = 0 }
local muted = 0
-- Each followed rig's watch on its engine clips (its root's ChildAdded and each clip's mute).
local muting: { [Model]: { RBXScriptConnection } } = {}
local warm: { Sound } = {}
local stoppers: { () -> () } = {}
-- Who hears each step as it plays (onStep): the Manager's dread shakes the camera on his footfalls.
type StepListener = (model: Model, record: FootstepEmitterSystem.StepRecord) -> ()
local listeners: { StepListener } = {}

-- One silent Sound per pooled asset, preloaded, so no step waits for its asset.
local function preload()
	local seen: { [string]: Sound? } = {}
	local sounds: { Instance } = {}
	local function warmOne(assetId: string)
		if seen[assetId] ~= nil then
			return
		end
		local sound = Instance.new("Sound")
		seen[assetId] = sound
		sound.Name = "FootstepWarm"
		sound.SoundId = assetId
		sound.Volume = 0
		sound.Parent = SoundService
		table.insert(warm, sound)
		table.insert(sounds, sound)
	end
	local bodyIds: { string } = { FootstepAssets.LAND, FootstepAssets.BODY_FALL }
	for _, id in FootstepAssets.JUMPS do
		table.insert(bodyIds, id)
	end
	for _, id in bodyIds do
		local def = SoundRegistry.get(id)
		if def ~= nil then
			warmOne(def.assetId)
		end
	end
	for _, set in FootstepAssets.SETS do
		for _, pool in
			{ set.surfaces.default, set.surfaces.carpet, set.surfaces.tile, set.surfaces.wood, set.surfaces.concrete }
		do
			for _, assetId in pool do
				warmOne(assetId)
			end
		end
	end
	task.spawn(function()
		ContentProvider:PreloadAsync(sounds, function(contentId: string, status: Enum.AssetFetchStatus)
			local sound = seen[contentId]
			if sound ~= nil and status == Enum.AssetFetchStatus.Failure then
				local index = table.find(warm, sound)
				if index ~= nil then
					table.remove(warm, index)
				end
				sound:Destroy()
			end
		end)
	end)
end

local function crouching(model: Model): boolean
	return model:GetAttribute(FootstepConstants.CROUCH_ATTRIBUTE) == true
end

local function playerSet(character: Model): string
	local named = character:GetAttribute(FootstepConstants.SET_ATTRIBUTE)
	if type(named) == "string" and FootstepAssets.SETS[named] ~= nil then
		return named
	end
	local employee = character:GetAttribute(EmployeeConstants.NAME_ATTRIBUTE)
	if type(employee) == "string" and FootstepAssets.SETS[string.lower(employee)] ~= nil then
		return string.lower(employee)
	end
	return FootstepConstants.DEFAULT_SET
end

-- The silent group the engine's character sounds are moved into (made on first use).
local silence: SoundGroup? = nil

local function silentGroup(): SoundGroup
	local existing = silence
	if existing ~= nil and existing.Parent ~= nil then
		return existing
	end
	local group = Instance.new("SoundGroup")
	group.Name = "FootstepMutedDefaults"
	group.Volume = 0
	group.Parent = SoundService
	silence = group
	return group
end

-- Mutes one of RbxCharacterSounds' clips (they appear lazily in the root) and keeps it muted.
local function muteClip(clip: Instance, connections: { RBXScriptConnection })
	if table.find(FootstepConstants.DEFAULT_SOUNDS, clip.Name) == nil then
		return
	end
	if clip:IsA("Sound") then
		local sound = clip
		local function apply()
			local group = silentGroup()
			if sound.SoundGroup ~= group then
				sound.SoundGroup = group
				muted += 1
			end
		end
		apply()
		table.insert(connections, sound:GetPropertyChangedSignal("SoundGroup"):Connect(apply))
	elseif clip:IsA("AudioPlayer") then
		local player = clip
		local function apply()
			if player.Volume > 0 then
				player.Volume = 0
				muted += 1
			end
		end
		apply()
		table.insert(connections, player:GetPropertyChangedSignal("Volume"):Connect(apply))
	end
end

local function unwatch(model: Model)
	local connections = muting[model]
	if connections ~= nil then
		for _, connection in connections do
			connection:Disconnect()
		end
		muting[model] = nil
	end
end

-- Mutes the engine's clips in this rig's root now and as they turn up.
local function watchDefaults(model: Model, rig: Rig)
	unwatch(model)
	local connections: { RBXScriptConnection } = {}
	muting[model] = connections
	for _, child in rig.root:GetChildren() do
		muteClip(child, connections)
	end
	table.insert(
		connections,
		rig.root.ChildAdded:Connect(function(child: Instance)
			muteClip(child, connections)
		end)
	)
end

local function follow(model: Model, setName: () -> string, gaitInput: () -> GaitInput)
	if rigs[model] == nil then
		pending[model] = { setName = setName, gaitInput = gaitInput }
	end
end

local function forget(model: Model)
	unwatch(model)
	rigs[model] = nil
	culled[model] = nil
	pending[model] = nil
end

local function followPlayer(player: Player)
	local function onCharacter(character: Model)
		follow(character, function()
			return playerSet(character)
		end, function(): GaitInput
			return {
				hidden = player:GetAttribute(HideConstants.PLAYER_SPOT_ATTRIBUTE) ~= nil,
				crouching = crouching(character),
				sprinting = player:GetAttribute(SprintConstants.SPRINTING_ATTRIBUTE) == true,
			}
		end)
		character.Destroying:Once(function()
			forget(character)
		end)
	end
	if player.Character ~= nil then
		onCharacter(player.Character)
	end
	local added = player.CharacterAdded:Connect(onCharacter)
	local removing = player.CharacterRemoving:Connect(forget)
	table.insert(stoppers, function()
		added:Disconnect()
		removing:Disconnect()
	end)
end

local function followTagged(tag: string, setName: string)
	local function onTagged(instance: Instance)
		if instance:IsA("Model") then
			local model = instance
			follow(model, function()
				local named = model:GetAttribute(FootstepConstants.SET_ATTRIBUTE)
				return if type(named) == "string" and FootstepAssets.SETS[named] ~= nil then named else setName
			end, function(): GaitInput
				return { hidden = false, crouching = crouching(model), sprinting = false }
			end)
		end
	end
	for _, instance in CollectionService:GetTagged(tag) do
		onTagged(instance)
	end
	local added = CollectionService:GetInstanceAddedSignal(tag):Connect(onTagged)
	local removed = CollectionService:GetInstanceRemovedSignal(tag):Connect(function(instance: Instance)
		if instance:IsA("Model") then
			forget(instance)
		end
	end)
	table.insert(stoppers, function()
		added:Disconnect()
		removed:Disconnect()
	end)
end

local function step(dt: number)
	for model, waiting in pending do
		if model.Parent == nil then
			continue
		end
		local rig = FootstepEmitterSystem.new(model, waiting.setName(), waiting.gaitInput)
		if rig ~= nil then
			pending[model] = nil
			rigs[model] = rig
			watchDefaults(model, rig)
		end
	end
	local camera = Workspace.CurrentCamera
	local listener = if camera ~= nil then camera.CFrame.Position else nil
	for model, rig in rigs do
		if model.Parent == nil or rig.root.Parent == nil then
			continue
		end
		local far = listener ~= nil
			and (rig.root.Position - listener).Magnitude
				> rig.set.rollOffMaxDistance + FootstepConstants.CULL_MARGIN
		if far then
			if not culled[model] then
				culled[model] = true
				FootstepEmitterSystem.reset(rig)
			end
			continue
		end
		culled[model] = nil
		for _, record in FootstepEmitterSystem.update(rig, dt, counters) do
			table.insert(recent, record)
			if #recent > FootstepConstants.RECENT then
				table.remove(recent, 1)
			end
			for _, hear in table.clone(listeners) do
				task.spawn(hear, model, record)
			end
		end
	end
end

export type FootstepServiceClient = {
	dependencies: { string },
	init: (self: FootstepServiceClient) -> (),
	start: (self: FootstepServiceClient) -> (),
	stop: (self: FootstepServiceClient) -> (),
	getState: (self: FootstepServiceClient) -> { [string]: any },
	onStep: (self: FootstepServiceClient, listener: StepListener) -> () -> (),
}

local FootstepServiceClient: FootstepServiceClient = {
	dependencies = { "SoundServiceClient" },

	init = function(_self) end,

	start = function(_self)
		preload()
		for _, player in Players:GetPlayers() do
			followPlayer(player)
		end
		local joined = Players.PlayerAdded:Connect(followPlayer)
		table.insert(stoppers, function()
			joined:Disconnect()
		end)
		for tag, setName in FootstepConstants.TAG_SETS do
			followTagged(tag, setName)
		end
		local beat = RunService.Heartbeat:Connect(step)
		table.insert(stoppers, function()
			beat:Disconnect()
		end)
		FootstepLandingSystem.start()
		table.insert(stoppers, FootstepLandingSystem.stop)
	end,

	stop = function(_self)
		for _, stopper in stoppers do
			stopper()
		end
		table.clear(stoppers)
		for model in muting do
			unwatch(model)
		end
		table.clear(rigs)
		table.clear(culled)
		table.clear(pending)
		for _, sound in warm do
			sound:Destroy()
		end
		table.clear(warm)
		local group = silence
		if group ~= nil then
			group:Destroy()
			silence = nil
		end
	end,

	--[=[
		Calls `listener` with the model and its step record each time a followed character's foot lands (a step that
		played). Returns a function that stops listening.
	]=]
	onStep = function(_self, listener)
		table.insert(listeners, listener)
		return function()
			local index = table.find(listeners, listener)
			if index ~= nil then
				table.remove(listeners, index)
			end
		end
	end,

	getState = function(_self)
		local followed = {}
		local waiting = 0
		for _ in pending do
			waiting += 1
		end
		for model, rig in rigs do
			table.insert(
				followed,
				{ model = model.Name, set = rig.setName, speed = rig.speed, culled = culled[model] == true }
			)
		end
		return {
			followed = followed,
			pending = waiting,
			steps = counters.steps,
			gated = counters.gated,
			silent = counters.silent,
			mutedDefault = muted,
			recent = table.clone(recent),
			landing = FootstepLandingSystem.getState(),
		}
	end,
}

return FootstepServiceClient
