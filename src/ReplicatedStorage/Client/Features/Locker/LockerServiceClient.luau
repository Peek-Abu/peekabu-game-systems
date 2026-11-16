--!strict
--[=[
	LockerServiceClient: the Lost & Found Lockers on the client (design:
	docs/superpowers/specs/2026-10-25-odd-hours-lockers-design.md).

	- Sends `OpenRequest` and (when restricted from paid random items) `BuyRequest`.
	- Keeps the server's `restricted` flag and last refusal in `LockerStore`.
	- When `LockerEvents.Opened` arrives, registers and opens the stage-1 opening scene (`LockerOpeningScreen`); when
	  the opening finishes (or is skipped), pushes the rolled item into `CosmeticRevealStore` so `RevealScreen` shows
	  it with its rarity fanfare (and duplicate refund ribbon if already owned).
	- Ducks the hub music (an EqualizerSoundEffect on the Music group, like the shift's results duck) while an opening
	  plays and its reveal is up (LockerViewModel.musicDucked), then eases it back: the track never stops (owner 11-16).
	- The opening scene leaving the stack any other way (Escape or gamepad B pops it, the depot closing removes it) settles
	  the opening the same way, so the reveal still shows and the Shop (hidden while an opening plays) comes back
	  (owner check 11-16: Esc mid-opening lost the reveal and left the Shop blank with the HUD hidden).

	@class LockerServiceClient
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local Charm = require(ReplicatedStorage.Packages.Charm)
local React = require(ReplicatedStorage.Packages.React)
local CosmeticRegistry = require(ReplicatedStorage.Shared.Features.Cosmetic.Data.CosmeticRegistry)
local CosmeticTypes = require(ReplicatedStorage.Shared.Features.Cosmetic.Data.CosmeticTypes)
local Locker = ReplicatedStorage.Shared.Features.Locker
local LockerEvents = require(Locker.Net.LockerEvents)
local LockerRequestRules = require(Locker.Rules.LockerRequestRules)
local LockerRules = require(Locker.Rules.LockerRules)
local LockerTypes = require(Locker.Data.LockerTypes)
local CosmeticRevealStore = require(ReplicatedStorage.Client.Features.Cosmetic.State.CosmeticRevealStore)
local LockerStore = require(ReplicatedStorage.Client.Features.Locker.State.LockerStore)
local LockerViewModel = require(ReplicatedStorage.Client.UI.React.Screens.Locker.LockerViewModel)
local SceneRegistry = require(ReplicatedStorage.Client.UI.Scenes.SceneRegistry)
local SceneStack = require(ReplicatedStorage.Client.UI.Scenes.SceneStack)
local UIStore = require(ReplicatedStorage.Client.UI.Scenes.UIStore)

type LockerId = LockerTypes.LockerId

local stoppers: { () -> () } = {}

local musicDuck: EqualizerSoundEffect? = nil

-- Eases the Music group down (on) or back up and away (off).
local function setMusicDucked(on: boolean)
	local current = musicDuck
	if on then
		if current ~= nil then
			return
		end
		local group = SoundService:FindFirstChild("Music")
		if group == nil or not group:IsA("SoundGroup") then
			return
		end
		local duck = Instance.new("EqualizerSoundEffect")
		duck.Name = "LockerDuck"
		duck.LowGain = 0
		duck.MidGain = 0
		duck.HighGain = 0
		duck.Parent = group
		musicDuck = duck
		local level = LockerViewModel.MUSIC_DUCK_DB
		TweenService:Create(
			duck,
			TweenInfo.new(LockerViewModel.MUSIC_DUCK_IN),
			{ LowGain = level, MidGain = level, HighGain = level }
		):Play()
	elseif current ~= nil then
		musicDuck = nil
		local up = TweenService:Create(
			current,
			TweenInfo.new(LockerViewModel.MUSIC_DUCK_OUT),
			{ LowGain = 0, MidGain = 0, HighGain = 0 }
		)
		up.Completed:Once(function()
			current:Destroy()
		end)
		up:Play()
	end
end

local function syncMusic()
	setMusicDucked(LockerViewModel.musicDucked(LockerStore.opening(), CosmeticRevealStore.current()))
end

-- Ends the opening in progress (if any) and queues its reveal.
local function settleOpening()
	local outcome = LockerStore.finishOpening()
	if outcome ~= nil then
		CosmeticRevealStore.push(LockerViewModel.revealOf(outcome))
	end
end

local function finishOpeningImpl()
	settleOpening()
	SceneStack.remove(LockerViewModel.OPENING_SCENE)
end

local function ensureScene()
	if SceneRegistry.has(LockerViewModel.OPENING_SCENE) then
		return
	end
	local LockerOpeningScreen = require(ReplicatedStorage.Client.UI.React.Screens.Locker.LockerOpeningScreen)
	SceneRegistry.register({
		name = LockerViewModel.OPENING_SCENE,
		screens = {
			{
				layer = "Panel",
				key = "lockerOpening",
				component = function()
					return React.createElement(LockerOpeningScreen, {
						onFinish = finishOpeningImpl,
					})
				end,
			},
		},
		suppress = { mouse = true },
		hud = "hidden",
		-- No menu swipe as the cutscene starts: the Open button already played the buy (owner pick B, 11-16).
		quietOpen = true,
	})
end

local function rarityOf(value: string, itemId: string): CosmeticTypes.Rarity
	local item = CosmeticRegistry.get(itemId)
	if item ~= nil then
		return item.rarity
	end
	if value == "uncommon" or value == "rare" or value == "epic" or value == "legendary" or value == "odd" then
		return value
	end
	return "default"
end

export type LockerServiceClient = {
	dependencies: { string },
	init: (self: LockerServiceClient) -> (),
	stop: (self: LockerServiceClient) -> (),
	requestOpen: (self: LockerServiceClient, lockerId: LockerId) -> (),
	requestBuy: (self: LockerServiceClient, lockerId: LockerId, itemId: string) -> (),
	-- Buys one key to `lockerId` with the live event's money (the answer comes back as a Refused result).
	requestKey: (self: LockerServiceClient, lockerId: LockerId) -> (),
	finishOpening: (self: LockerServiceClient) -> (),
}

local LockerServiceClient: LockerServiceClient = {
	dependencies = {},

	init = function(_self)
		ensureScene()
		table.insert(stoppers, Charm.subscribe(LockerStore.opening, syncMusic))
		table.insert(stoppers, Charm.subscribe(CosmeticRevealStore.current, syncMusic))
		table.insert(
			stoppers,
			Charm.subscribe(UIStore.sceneStack, function(stack: { string })
				if LockerStore.opening() ~= nil and table.find(stack, LockerViewModel.OPENING_SCENE) == nil then
					settleOpening()
				end
			end)
		)
		table.insert(
			stoppers,
			LockerEvents.packets.Status.listen(function(data: { restricted: boolean })
				LockerStore.setRestricted(data.restricted)
			end)
		)
		table.insert(
			stoppers,
			LockerEvents.packets.Refused.listen(function(data: { locker: string, reason: string })
				LockerStore.setResult({ locker = data.locker, reason = data.reason })
			end)
		)
		table.insert(
			stoppers,
			LockerEvents.packets.Opened.listen(function(data: {
				locker: string,
				item: string,
				rarity: string,
				duplicate: boolean,
				refund: number,
				guaranteed: boolean,
				pity: number,
			})
				local locker = LockerRules.get(data.locker)
				if locker == nil then
					return
				end
				LockerStore.startOpening({
					locker = locker.id,
					item = data.item,
					rarity = rarityOf(data.rarity, data.item),
					duplicate = data.duplicate,
					refund = data.refund,
					guaranteed = data.guaranteed,
					pity = data.pity,
				})
				if not SceneStack.isActive(LockerViewModel.OPENING_SCENE) then
					SceneStack.push(LockerViewModel.OPENING_SCENE)
				end
			end)
		)
	end,

	stop = function(_self)
		for _, stop in stoppers do
			stop()
		end
		table.clear(stoppers)
		setMusicDucked(false)
	end,

	requestOpen = function(_self, lockerId)
		if LockerRules.get(lockerId) == nil then
			return
		end
		LockerStore.setResult(nil)
		LockerEvents.packets.OpenRequest.send(LockerRequestRules.buildOpen(lockerId))
	end,

	requestBuy = function(_self, lockerId, itemId)
		if LockerRules.get(lockerId) == nil or CosmeticRegistry.get(itemId) == nil then
			return
		end
		LockerStore.setResult(nil)
		LockerEvents.packets.BuyRequest.send(LockerRequestRules.buildBuy(lockerId, itemId))
	end,

	requestKey = function(_self, lockerId)
		if LockerRules.get(lockerId) == nil then
			return
		end
		LockerStore.setResult(nil)
		LockerEvents.packets.KeyRequest.send(LockerRequestRules.buildKey(lockerId))
	end,

	finishOpening = function(_self)
		finishOpeningImpl()
	end,
}

return LockerServiceClient
