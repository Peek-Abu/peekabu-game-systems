--!strict
--[=[
	AbilityVfxSystem: the abilities' world effects on every client, read from the server's character attributes (so
	everyone sees the same thing; nothing here is sent back):

	- SpeedBoostUntil (Sprint's speed boost): a gold trail behind that runner until the boost ends.
	- AbilityActive = "letsGo" appearing: Pippa's star ring at her feet.
	- AbilityActive = "pottedPlant" appearing or going: the leaf puff at Prickles' feet (in, and popping out).

	Functional looks (AbilityVfxConstants); real polish is a later phase. Spec-exempt shell (VfxBurstSystem, Trails,
	live characters).

	@class AbilityVfxSystem
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Observers = require(ReplicatedStorage.Packages.Observers)
local AbilityConstants = require(ReplicatedStorage.Shared.Features.Ability.Data.AbilityConstants)
local SprintConstants = require(ReplicatedStorage.Shared.Features.Sprint.Data.SprintConstants)
local VfxBurstRegistry = require(ReplicatedStorage.Shared.Features.Vfx.Data.VfxBurstRegistry)
local AbilityVfxConstants = require(ReplicatedStorage.Client.Features.Ability.Data.AbilityVfxConstants)
local VfxBurstSystem = require(ReplicatedStorage.Client.Features.Vfx.Systems.VfxBurstSystem)

local C = AbilityVfxConstants

-- Registered at load: VfxBurstSystem refuses an unknown burst.
for id, preset in C.PRESETS do
	if not VfxBurstRegistry.has(id) then
		VfxBurstRegistry.register(id, preset)
	end
end

local AbilityVfxSystem = {}

local played = 0

local function feetOf(character: Model): Vector3?
	local root = character:FindFirstChild("HumanoidRootPart")
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if root == nil or not root:IsA("BasePart") or humanoid == nil then
		return nil
	end
	return root.Position - Vector3.new(0, humanoid.HipHeight + root.Size.Y / 2 - 0.2, 0)
end

local function burstAt(character: Model, id: string)
	local feet = feetOf(character)
	if feet ~= nil then
		played += 1
		VfxBurstSystem.play(id, feet)
	end
end

-- The trail on `character` while its boost lasts; returns its cleanup.
local function trail(character: Model): () -> ()
	local root = character:FindFirstChild("HumanoidRootPart")
	if root == nil or not root:IsA("BasePart") then
		return function() end
	end
	local half = C.TRAIL_HEIGHT / 2
	local top = Instance.new("Attachment")
	top.Name = C.TRAIL_NAME
	top.Position = Vector3.new(0, half, 0)
	top.Parent = root
	local bottom = Instance.new("Attachment")
	bottom.Name = C.TRAIL_NAME
	bottom.Position = Vector3.new(0, -half, 0)
	bottom.Parent = root
	local streak = Instance.new("Trail")
	streak.Name = C.TRAIL_NAME
	streak.Attachment0 = top
	streak.Attachment1 = bottom
	streak.Color = C.TRAIL_COLOR
	streak.Transparency = C.TRAIL_TRANSPARENCY
	streak.Lifetime = C.TRAIL_LIFETIME
	streak.LightEmission = 0.4
	streak.LightInfluence = 0.2
	streak.FaceCamera = true
	streak.Parent = root
	return function()
		streak:Destroy()
		top:Destroy()
		bottom:Destroy()
	end
end

-- Follows one character's ability attributes for as long as it exists.
local function watch(character: Model): () -> ()
	local endTrail: (() -> ())? = nil
	local trailToken = 0
	local function syncTrail()
		local untilAt = character:GetAttribute(SprintConstants.BOOST_UNTIL_ATTRIBUTE)
		local remaining = if type(untilAt) == "number" then untilAt - Workspace:GetServerTimeNow() else 0
		trailToken += 1
		local token = trailToken
		if remaining > 0 then
			if endTrail == nil then
				endTrail = trail(character)
			end
			task.delay(remaining, function()
				if token == trailToken then
					local stop = endTrail
					endTrail = nil
					if stop ~= nil then
						stop()
					end
				end
			end)
		else
			local stop = endTrail
			endTrail = nil
			if stop ~= nil then
				stop()
			end
		end
	end
	local active = character:GetAttribute(AbilityConstants.ACTIVE_ATTRIBUTE)
	local function syncActive()
		local now = character:GetAttribute(AbilityConstants.ACTIVE_ATTRIBUTE)
		local was = active
		active = now
		if now == was then
			return
		end
		if now == "letsGo" then
			burstAt(character, "abilityLetsGo")
		elseif now == "pottedPlant" or was == "pottedPlant" then
			burstAt(character, "abilityPlantPuff")
		end
	end
	syncTrail()
	local boost = character:GetAttributeChangedSignal(SprintConstants.BOOST_UNTIL_ATTRIBUTE):Connect(syncTrail)
	local ability = character:GetAttributeChangedSignal(AbilityConstants.ACTIVE_ATTRIBUTE):Connect(syncActive)
	return function()
		boost:Disconnect()
		ability:Disconnect()
		trailToken += 1
		local stop = endTrail
		endTrail = nil
		if stop ~= nil then
			stop()
		end
	end
end

--[=[
	Starts following every character (the local one included). Returns the stop.
]=]
function AbilityVfxSystem.start(): () -> ()
	return Observers.observeCharacter(function(_player: Player, character: Model)
		return watch(character)
	end)
end

function AbilityVfxSystem.played(): number
	return played
end

return AbilityVfxSystem
