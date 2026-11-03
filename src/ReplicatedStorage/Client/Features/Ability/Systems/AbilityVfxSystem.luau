--!strict
--[=[
	AbilityVfxSystem: the abilities' world effects on every client, read from the server's character attributes (so
	everyone sees the same thing; nothing here is sent back):

	- AbilityActive = "letsGo" appearing: Pippa's star ring at her feet. The boost itself draws nothing on the
	  runners (owner, 2026-11-03: the speed trail "looks simulator esque" and was removed).
	- AbilityActive = "pottedPlant" appearing or going: the leaf puff at Prickles' feet (in, and popping out).

	And the ability sounds (AbilityAssets), 3D on the character's root: Let's Go! as Pippa's effect begins (the effect,
	so it plays whatever her clip does), and each clip-timed sound (Cappy's phone, Prickles into and out of the pot) as
	its clip starts on the character's Animator, faded over CUT_FADE when that clip is cut short; a clip that ends on
	its own lets the tail ring.

	Functional looks (AbilityVfxConstants); real polish is a later phase. Spec-exempt shell (VfxBurstSystem, live
	characters).

	@class AbilityVfxSystem
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Observers = require(ReplicatedStorage.Packages.Observers)
local AbilityAssets = require(ReplicatedStorage.Shared.Features.Ability.Data.AbilityAssets)
local AbilityConstants = require(ReplicatedStorage.Shared.Features.Ability.Data.AbilityConstants)
local AnimationRegistry = require(ReplicatedStorage.Shared.Features.Animation.Data.AnimationRegistry)
local VfxBurstRegistry = require(ReplicatedStorage.Shared.Features.Vfx.Data.VfxBurstRegistry)
local AbilityVfxConstants = require(ReplicatedStorage.Client.Features.Ability.Data.AbilityVfxConstants)
local VfxBurstSystem = require(ReplicatedStorage.Client.Features.Vfx.Systems.VfxBurstSystem)
local SoundServiceClient = require(ReplicatedStorage.Client.Features.Sound.SoundServiceClient)

local C = AbilityVfxConstants

-- Registered at load: VfxBurstSystem refuses an unknown burst.
for id, preset in C.PRESETS do
	if not VfxBurstRegistry.has(id) then
		VfxBurstRegistry.register(id, preset)
	end
end

local AbilityVfxSystem = {}

local played = 0

-- A clip that plays a sound from its first frame, by the clip's asset id: the sound and the clip's own length.
type ClipSound = { sound: string, seconds: number }
local clipSounds: { [string]: ClipSound } = {}
for key, sound in AbilityAssets.CLIP_SOUNDS do
	local def = AnimationRegistry.get(key)
	if def ~= nil then
		clipSounds[def.assetId] = { sound = sound, seconds = (def.durationMs or 0) / 1000 }
	end
end
-- A clip counts as cut short when it stops more than this many seconds before its own end.
local CUT_SLACK = 0.15

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

-- The character's root, for a sound that follows it.
local function rootOf(character: Model): BasePart?
	local root = character:FindFirstChild("HumanoidRootPart")
	return if root ~= nil and root:IsA("BasePart") then root else nil
end

-- Plays each clip-timed ability sound as its clip starts on `character`; returns the cleanup.
local function watchClips(character: Model): () -> ()
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local animator = if humanoid ~= nil then humanoid:FindFirstChildOfClass("Animator") else nil
	if animator == nil then
		return function() end
	end
	local connection = animator.AnimationPlayed:Connect(function(track: AnimationTrack)
		local entry = clipSounds[track.Animation.AnimationId]
		local root = rootOf(character)
		if entry == nil or root == nil then
			return
		end
		local handle = SoundServiceClient:play(entry.sound, { at = root })
		if handle == nil then
			return
		end
		local started = os.clock()
		track.Stopped:Once(function()
			-- Cut short (moving, busy hands, a popped plant): fade, never stop dead. Ended on its own: let it ring.
			if os.clock() - started < entry.seconds - CUT_SLACK then
				handle:stop(AbilityAssets.CUT_FADE)
			end
		end)
	end)
	return function()
		connection:Disconnect()
	end
end

-- Follows one character's ability attributes for as long as it exists.
local function watch(character: Model): () -> ()
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
			local root = rootOf(character)
			if root ~= nil then
				SoundServiceClient:play(AbilityAssets.LETS_GO, { at = root })
			end
		elseif now == "pottedPlant" or was == "pottedPlant" then
			burstAt(character, "abilityPlantPuff")
		end
	end
	local ability = character:GetAttributeChangedSignal(AbilityConstants.ACTIVE_ATTRIBUTE):Connect(syncActive)
	local stopClips = watchClips(character)
	return function()
		ability:Disconnect()
		stopClips()
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
