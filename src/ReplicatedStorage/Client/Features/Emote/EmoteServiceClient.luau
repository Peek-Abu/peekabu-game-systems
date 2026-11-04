--!strict
--[=[
	EmoteServiceClient: the emote wheel on this client (Character step 5; owner, 25 Oct: hold B, emotes everywhere).

	- Hold the `emoteWheel` action (B, or L1 on a gamepad) to open the wheel (its scene is registered here, at init);
	  let go over a slot
	  to play it. A click or tap on a slot plays it too (`play`), and the phone's HUD button opens the wheel.
	- `play(slot)` asks the server (EmoteEvents.PlayRequest); the server decides and grants the replicated clip.
	- While an emote may be playing, moving or jumping asks the server to stop it (EmoteEvents.StopRequest), once.
	- Every character's emote props show and hide from its clip's markers (EmotePropSystem), and its Legendary
	  emote effects (bubbles, faces) run on them (EmoteEffectSystem, EmoteVfxSystem), started and stopped with this
	  service. Sheriff Prickles' lasso loop is drawn bendy over its clip-posed prop (EmoteLassoSystem).

	Spec-exempt shell (input, RunService, packets); the decisions live in EmoteRules and EmoteWheelViewModel.

	@class EmoteServiceClient
]=]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Janitor = require(ReplicatedStorage.Packages.Janitor)
local Observers = require(ReplicatedStorage.Packages.Observers)
local EmoteConstants = require(ReplicatedStorage.Shared.Features.Emote.Data.EmoteConstants)
local EmoteEvents = require(ReplicatedStorage.Shared.Features.Emote.Net.EmoteEvents)
local EmoteRequestRules = require(ReplicatedStorage.Shared.Features.Emote.Rules.EmoteRequestRules)
local EmoteWheelStore = require(ReplicatedStorage.Client.Features.Emote.State.EmoteWheelStore)
local EmoteEffectSystem = require(ReplicatedStorage.Client.Features.Emote.Systems.EmoteEffectSystem)
local EmoteLassoSystem = require(ReplicatedStorage.Client.Features.Emote.Systems.EmoteLassoSystem)
local EmotePropSystem = require(ReplicatedStorage.Client.Features.Emote.Systems.EmotePropSystem)
local EmoteVfxSystem = require(ReplicatedStorage.Client.Features.Emote.Systems.EmoteVfxSystem)
local InputActionRegistry = require(ReplicatedStorage.Client.Features.Input.Data.InputActionRegistry)
local InputServiceClient = require(ReplicatedStorage.Client.Features.Input.InputServiceClient)
local SceneStack = require(ReplicatedStorage.Client.UI.Scenes.SceneStack)
local React = require(ReplicatedStorage.Packages.React)
local SceneRegistry = require(ReplicatedStorage.Client.UI.Scenes.SceneRegistry)
local EmoteWheelScreen = require(ReplicatedStorage.Client.UI.React.Screens.Emote.EmoteWheelScreen)
local EmoteWheelViewModel = require(ReplicatedStorage.Client.UI.React.Screens.Emote.EmoteWheelViewModel)

-- How long a sent emote is watched for a move that should stop it (longer than any emote clip).
local WATCH_SECONDS = 12

local janitor = Janitor.new()
local props = EmotePropSystem.forWorld()
local effects = EmoteEffectSystem.live(EmoteVfxSystem.start)
local lasso = EmoteLassoSystem.new()
local watching: RBXScriptConnection? = nil

local function unwatch()
	local connection = watching
	if connection ~= nil then
		connection:Disconnect()
		watching = nil
	end
end

-- Watches the body after an emote is asked for: the first move or jump stops it.
local function watchForMove()
	unwatch()
	local character = Players.LocalPlayer.Character
	local humanoid = if character ~= nil then character:FindFirstChildOfClass("Humanoid") else nil
	if humanoid == nil then
		return
	end
	local started = os.clock()
	watching = RunService.Heartbeat:Connect(function()
		if os.clock() - started > WATCH_SECONDS or humanoid.Parent == nil then
			unwatch()
			return
		end
		if humanoid.MoveDirection.Magnitude > EmoteConstants.STOP_INPUT or humanoid.Jump then
			unwatch()
			EmoteEvents.packets.StopRequest.send({})
		end
	end)
end

local function openWheel()
	if not EmoteWheelStore.open() then
		EmoteWheelStore.show()
		SceneStack.push(EmoteWheelViewModel.SCENE)
	end
end

local function closeWheel(): number?
	local slot = EmoteWheelStore.hide()
	SceneStack.remove(EmoteWheelViewModel.SCENE)
	return slot
end

export type EmoteServiceClient = {
	dependencies: { string },
	init: (self: EmoteServiceClient) -> (),
	start: (self: EmoteServiceClient) -> (),
	stop: (self: EmoteServiceClient) -> (),
	play: (self: EmoteServiceClient, slot: number) -> (),
	openWheel: (self: EmoteServiceClient) -> (),
	closeWheel: (self: EmoteServiceClient) -> (),
}

local EmoteServiceClient: EmoteServiceClient = {
	dependencies = { "InputServiceClient" },

	init = function(self)
		-- The wheel scene: over the HUD, the mouse free to pick a slot; a click or tap plays and closes.
		if not SceneRegistry.has(EmoteWheelViewModel.SCENE) then
			SceneRegistry.register({
				name = EmoteWheelViewModel.SCENE,
				screens = {
					{
						layer = "Wheel",
						key = "emoteWheel",
						component = function()
							return React.createElement(EmoteWheelScreen, {
								onPick = function(slot: number)
									closeWheel()
									self:play(slot)
								end,
								onClose = closeWheel,
							})
						end,
					},
				},
				suppress = { mouse = true },
			})
		end
		if not InputActionRegistry.has(EmoteConstants.WHEEL_ACTION) then
			InputActionRegistry.register(EmoteConstants.WHEEL_ACTION, {
				context = "gameplay",
				bindings = { keyboard = { EmoteConstants.WHEEL_KEY }, gamepad = { EmoteConstants.WHEEL_GAMEPAD } },
				description = "Hold to open the emote wheel",
			})
		end
	end,

	start = function(self)
		local unbind = InputServiceClient:bind(EmoteConstants.WHEEL_ACTION, function(phase)
			if phase == "begin" then
				openWheel()
			else
				local slot = closeWheel()
				if slot ~= nil then
					self:play(slot)
				end
			end
		end)
		janitor:Add(unbind, true)
		janitor:Add(unwatch, true)
		janitor:Add(
			Observers.observeCharacter(function(_player: Player, character: Model)
				local releaseProps = props.track(character)
				local releaseEffects = effects.track(character)
				local releaseLasso = lasso.track(character)
				return function()
					releaseLasso()
					releaseEffects()
					releaseProps()
				end
			end),
			true
		)
	end,

	stop = function(_self)
		janitor:Cleanup()
	end,

	play = function(_self, slot)
		EmoteEvents.packets.PlayRequest.send(EmoteRequestRules.buildPlay(slot))
		watchForMove()
	end,

	openWheel = function(_self)
		openWheel()
	end,

	closeWheel = function(_self)
		closeWheel()
	end,
}

return EmoteServiceClient
