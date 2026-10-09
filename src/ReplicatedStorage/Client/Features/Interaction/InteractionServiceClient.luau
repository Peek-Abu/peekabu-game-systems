--!strict
--[=[
	InteractionServiceClient: makes the server-created interaction prompts answer to the player's
	`interact` Input binding (so a rebind moves the prompt key too). The prompts, their checks and their
	handlers are the server's (InteractionServiceServer).

	Spec-exempt shell (CollectionService, ProximityPrompts); it only copies bindings onto prompts.

	@class InteractionServiceClient
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Observers = require(ReplicatedStorage.Packages.Observers)
local InteractionConstants = require(ReplicatedStorage.Shared.Features.Interaction.Data.InteractionConstants)
local InputServiceClient = require(ReplicatedStorage.Client.Features.Input.InputServiceClient)

local PROMPT_WAIT_SECONDS = 10

local stopObserver: (() -> ())? = nil

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
}

local InteractionServiceClient: InteractionServiceClient = {
	dependencies = { "InputServiceClient" },

	start = function(_self)
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

	stop = function(_self)
		local stop = stopObserver
		if stop ~= nil then
			stop()
			stopObserver = nil
		end
	end,
}

return InteractionServiceClient
