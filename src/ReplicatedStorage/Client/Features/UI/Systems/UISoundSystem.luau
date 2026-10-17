--!strict
--[=[
	UISoundSystem: the UI's sounds by tier (UIAssets.soundTiers; which tier is UISoundFormulas'), 2D in the UI group.

	- `play(tier)`: PaperButton plays the hover as the pointer enters and its tier (or the error, disabled) on a press,
	  so a new button sounds right by naming its tier, or by its look's default.
	- Hold prompts (every ProximityPrompt the local player holds with a HoldDuration: searching a desk, clocking out,
	  starting overtime, hiding): the wind-up from hold-begin, stretched to fill the hold (PlaybackSpeed = 1 /
	  HoldDuration), stopped on release; on completion the done sound, or the CTA for the clock out.
	- Every UI sound is kept warm while this client runs (one silent, never-played Sound each, preloaded): they are the
	  sounds heard most, and a cold one lands late.
	Nothing plays outside a running game (a UI Labs story renders PaperButton in edit mode).

	Spec-exempt shell (ProximityPromptService, Sound handles); the choices are the specced UISoundFormulas.

	@class UISoundSystem
]=]

local ContentProvider = game:GetService("ContentProvider")
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")

local InteractionConstants = require(ReplicatedStorage.Shared.Features.Interaction.Data.InteractionConstants)
local ShiftConstants = require(ReplicatedStorage.Shared.Features.Shift.Data.ShiftConstants)
local SoundRegistry = require(ReplicatedStorage.Shared.Features.Sound.Data.SoundRegistry)
local SoundServiceClient = require(ReplicatedStorage.Client.Features.Sound.SoundServiceClient)
local UIAssets = require(ReplicatedStorage.Client.Features.UI.Data.UIAssets)
local UISoundFormulas = require(ReplicatedStorage.Client.Features.UI.Utils.UISoundFormulas)

type Tier = UISoundFormulas.Tier

-- The hold prompts whose completion is a CTA (the important call to action).
local CTA_KINDS: { string } = { ShiftConstants.CLOCK_OUT_KIND }
-- A released hold's wind-up fades this fast (a cut would click).
local HOLD_RELEASE = 0.06

local stoppers: { () -> () } = {}
local warm: { Sound } = {}
local holding: SoundServiceClient.SoundHandle? = nil
local counters = { played = 0, holds = 0, dones = 0, ctas = 0 }

-- The Interaction kind of the object a prompt belongs to (the nearest ancestor's attribute), if any.
local function kindOf(prompt: ProximityPrompt): string?
	local node: Instance? = prompt.Parent
	while node ~= nil do
		local kind = node:GetAttribute(InteractionConstants.KIND_ATTRIBUTE)
		if type(kind) == "string" then
			return kind
		end
		node = node.Parent
	end
	return nil
end

local function playTier(tier: Tier, pitchScale: number?): SoundServiceClient.SoundHandle?
	if not RunService:IsRunning() then
		return nil
	end
	local id = UIAssets.soundTiers[tier]
	if id == nil or not SoundRegistry.has(id) then
		return nil
	end
	counters.played += 1
	return SoundServiceClient:play(id, { pitchScale = pitchScale })
end

local function releaseHold(fade: number)
	local handle = holding
	holding = nil
	if handle ~= nil then
		handle:stop(fade)
	end
end

local function preload()
	local sounds: { Instance } = {}
	for _, def in UIAssets.sounds do
		-- Silent and never played: it only holds the asset in memory.
		local sound = Instance.new("Sound")
		sound.Name = "UISoundWarm"
		sound.SoundId = def.assetId
		sound.Volume = 0
		sound.Parent = SoundService
		table.insert(warm, sound)
		table.insert(sounds, sound)
	end
	task.spawn(function()
		ContentProvider:PreloadAsync(sounds)
	end)
end

local UISoundSystem = {}

--[=[
	Plays the UI sound of `tier` (nothing outside a running game, or while it is pending).
]=]
function UISoundSystem.play(tier: Tier)
	playTier(tier)
end

function UISoundSystem.start()
	if #stoppers > 0 then
		return
	end
	preload()
	local me = Players.LocalPlayer
	local began = ProximityPromptService.PromptButtonHoldBegan:Connect(function(prompt: ProximityPrompt, player: Player)
		if player ~= me then
			return
		end
		local speed = UISoundFormulas.holdSpeed(prompt.HoldDuration)
		if speed == nil then
			return
		end
		releaseHold(0)
		counters.holds += 1
		holding = playTier("hold", speed)
	end)
	local ended = ProximityPromptService.PromptButtonHoldEnded:Connect(
		function(_prompt: ProximityPrompt, player: Player)
			if player == me then
				releaseHold(HOLD_RELEASE)
			end
		end
	)
	local triggered = ProximityPromptService.PromptTriggered:Connect(function(prompt: ProximityPrompt, player: Player)
		if player ~= me or prompt.HoldDuration <= 0 then
			return
		end
		releaseHold(HOLD_RELEASE)
		local tier: Tier = UISoundFormulas.doneTier(kindOf(prompt), CTA_KINDS)
		playTier(tier)
		if tier == "cta" then
			counters.ctas += 1
		else
			counters.dones += 1
		end
	end)
	table.insert(stoppers, function()
		began:Disconnect()
		ended:Disconnect()
		triggered:Disconnect()
		releaseHold(0)
	end)
end

function UISoundSystem.stop()
	for _, stop in stoppers do
		stop()
	end
	table.clear(stoppers)
	for _, sound in warm do
		sound:Destroy()
	end
	table.clear(warm)
end

function UISoundSystem.getState(): { [string]: number }
	return table.clone(counters)
end

return UISoundSystem
