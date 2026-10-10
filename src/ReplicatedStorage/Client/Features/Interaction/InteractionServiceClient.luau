--!strict
--[=[
	InteractionServiceClient: makes the server-created interaction prompts answer to the player's
	`interact` Input binding (so a rebind moves the prompt key too). The prompts, their checks and their
	handlers are the server's (InteractionServiceServer).

	Spec-exempt shell (CollectionService, ProximityPrompts); it only copies bindings onto prompts.

	@class InteractionServiceClient
]=]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Observers = require(ReplicatedStorage.Packages.Observers)
local InteractionConstants = require(ReplicatedStorage.Shared.Features.Interaction.Data.InteractionConstants)
local InteractionEvents = require(ReplicatedStorage.Shared.Features.Interaction.Net.InteractionEvents)
local InputServiceClient = require(ReplicatedStorage.Client.Features.Input.InputServiceClient)

local PROMPT_WAIT_SECONDS = 10

local stopObserver: (() -> ())? = nil
local stopCharacterWatch: (() -> ())? = nil
local channelTarget: Instance? = nil
local lastSentAt = 0

-- The first KeyCode in a binding list (a mouse button cannot key a prompt), or nil.
local function firstKeyCode(list: { Enum.KeyCode | Enum.UserInputType }?): Enum.KeyCode?
	if list == nil then
		return nil
	end
	for _, key in list do
		if key.EnumType == Enum.KeyCode then
			return Enum.KeyCode:FromName(key.Name)
		end
	end
	return nil
end

local function applyBindings(prompt: ProximityPrompt)
	local bindings = InputServiceClient:bindingsFor("interact")
	if bindings == nil then
		return
	end
	local keyboard = firstKeyCode(bindings.keyboard)
	if keyboard ~= nil then
		prompt.KeyboardKeyCode = keyboard
	end
	local gamepad = bindings.gamepad
	if gamepad ~= nil and gamepad[1] ~= nil then
		prompt.GamepadKeyCode = gamepad[1]
	end
end

export type InteractionServiceClient = {
	dependencies: { string },
	start: (self: InteractionServiceClient) -> (),
	stop: (self: InteractionServiceClient) -> (),
	startChannel: (self: InteractionServiceClient, target: Instance) -> (),
	stopChannel: (self: InteractionServiceClient) -> (),
}

local InteractionServiceClient: InteractionServiceClient = {
	dependencies = { "InputServiceClient" },

	start = function(_self)
		-- A new character ends any held channel (the server dropped it with the old one).
		local characterAdded = Players.LocalPlayer.CharacterAdded:Connect(function()
			channelTarget = nil
		end)
		stopCharacterWatch = function()
			characterAdded:Disconnect()
		end
		stopObserver = Observers.observeTag(InteractionConstants.TAG, function(target: Instance)
			local alive = true
			task.spawn(function()
				-- The server parents the prompt under the object's root part; it may replicate a moment later.
				local deadline = os.clock() + PROMPT_WAIT_SECONDS
				while alive and os.clock() < deadline do
					local prompt = target:FindFirstChild(InteractionConstants.PROMPT_NAME, true)
					if prompt ~= nil and prompt:IsA("ProximityPrompt") then
						applyBindings(prompt)
						return
					end
					task.wait(0.25)
				end
			end)
			return function()
				alive = false
			end
		end)
	end,

	--[=[
		Starts channeling `target` (the game decides when: aim + hold). Call it every frame while
		held: a repeat for the same target is re-sent at most every CHANNEL_RESEND_INTERVAL, so a channel the
		server ended (complete, out of range, death, reset) resumes while the button is still held.
	]=]
	startChannel = function(_self, target)
		local now = os.clock()
		if channelTarget == target and now - lastSentAt < InteractionConstants.CHANNEL_RESEND_INTERVAL then
			return
		end
		channelTarget = target
		lastSentAt = now
		InteractionEvents.packets.ChannelStart.send(target)
	end,

	stopChannel = function(_self)
		if channelTarget == nil then
			return
		end
		channelTarget = nil
		InteractionEvents.packets.ChannelStop.send(true)
	end,

	stop = function(_self)
		local stop = stopObserver
		if stop ~= nil then
			stop()
			stopObserver = nil
		end
		local stopWatch = stopCharacterWatch
		if stopWatch ~= nil then
			stopWatch()
			stopCharacterWatch = nil
		end
	end,
}

return InteractionServiceClient
