--!strict
--[=[
	AnimationLocomotionHumanoidSystem: binds the specced AnimationLocomotionSystem core to a rig's Humanoid.

	The local character is bound by `StarterCharacterScripts/Animate.client.luau` (one copy per character).
	Thin by design: every decision lives in AnimationLocomotionSystem; this adapts Humanoid state events to
	it, watches the kill switch, and owns the lifetime: the returned function unbinds, and callers must
	call it (Animate does, when the character goes) because the Heartbeat connection, like the attribute
	connection, outlives the rig.

	Kill switch: the Workspace attribute `LocomotionEnabled` (unset = enabled).

	May yield: `AnimationPlayerEngineSystem.forCharacter` waits up to 5 s for an Animator.

	Spec-exempt shell (needs a live Humanoid + Animator); the core is specced in AnimationLocomotionSystem.spec.

	@class AnimationLocomotionHumanoidSystem
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local AnimationPlayerEngineSystem =
	require(ReplicatedStorage.Shared.Features.Animation.Systems.AnimationPlayerEngineSystem)
local AnimationRegistry = require(ReplicatedStorage.Shared.Features.Animation.Data.AnimationRegistry)
local Logger = require(ReplicatedStorage.Shared.Core.Logger)
local AnimationLocomotionSystem = require(ReplicatedStorage.Client.Features.Animation.Systems.AnimationLocomotionSystem)

local ENABLED_ATTRIBUTE = "LocomotionEnabled"

local log = Logger.new("AnimationLocomotionHumanoidSystem")

local AnimationLocomotionHumanoidSystem = {}

local function isEnabled(): boolean
	return Workspace:GetAttribute(ENABLED_ATTRIBUTE) ~= false
end

function AnimationLocomotionHumanoidSystem.bind(character: Model): (() -> ())?
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid == nil or not humanoid:IsA("Humanoid") then
		log:warn(`{character.Name} has no Humanoid; locomotion animations disabled for it`)
		return nil
	end
	local player = AnimationPlayerEngineSystem.forCharacter(character)
	if player == nil then
		log:warn("no Animator found; locomotion animations disabled for this rig")
		return nil
	end
	local animator = AnimationLocomotionSystem.new(player)

	-- Warm the locomotion set up front (spec Decision 6): a pose's first play must be a cache hit.
	task.spawn(function()
		local locomotion = AnimationRegistry.domain("locomotion")
		if locomotion == nil then
			return
		end
		player:warm("idle")
		for id in locomotion do
			if id ~= "idle" then
				player:warm(id)
			end
		end
	end)

	animator:setEnabled(isEnabled())
	local connections: { RBXScriptConnection } = {
		Workspace:GetAttributeChangedSignal(ENABLED_ATTRIBUTE):Connect(function()
			animator:setEnabled(isEnabled())
		end),
		humanoid.Running:Connect(function(speed: number)
			animator:handleEvent("running", speed, os.clock())
		end),
		humanoid.Jumping:Connect(function()
			animator:handleEvent("jumping", nil, os.clock())
		end),
		humanoid.FreeFalling:Connect(function()
			animator:handleEvent("freefall", nil, os.clock())
		end),
		humanoid.Climbing:Connect(function(speed: number)
			animator:handleEvent("climbing", speed, os.clock())
		end),
		humanoid.Swimming:Connect(function(speed: number)
			animator:handleEvent("swimming", speed, os.clock())
		end),
		humanoid.Seated:Connect(function()
			animator:handleEvent("seated", nil, os.clock())
		end),
		humanoid.GettingUp:Connect(function()
			animator:handleEvent("gettingUp", nil, os.clock())
		end),
		humanoid.PlatformStanding:Connect(function()
			animator:handleEvent("platformStanding", nil, os.clock())
		end),
		humanoid.Died:Connect(function()
			animator:handleEvent("died", nil, os.clock())
		end),
		-- Applies a freefall that arrived inside the jump window once the window ends.
		RunService.Heartbeat:Connect(function()
			animator:update(os.clock())
		end),
	}

	-- Start at idle (the stock script's "initialize to idle").
	if isEnabled() then
		animator:handleEvent("running", 0, os.clock())
	end

	local bound = true
	return function()
		if not bound then
			return
		end
		bound = false
		for _, connection in connections do
			connection:Disconnect()
		end
		animator:destroy()
	end
end

return AnimationLocomotionHumanoidSystem
