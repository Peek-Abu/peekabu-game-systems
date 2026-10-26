--!strict
--[=[
	LockerServiceClient: the Lost & Found Lockers on the client (design:
	docs/superpowers/specs/2026-10-25-odd-hours-lockers-design.md).

	- Sends `OpenRequest` and (when restricted from paid random items) `BuyRequest`.
	- Keeps the server's `restricted` flag and last refusal in `LockerStore`.
	- When `LockerEvents.Opened` arrives, registers and opens the stage-1 opening scene (`LockerOpeningScreen`); when
	  the opening finishes (or is skipped), pushes the rolled item into `CosmeticRevealStore` so `RevealScreen` shows
	  it with its rarity fanfare (and duplicate refund ribbon if already owned).

	@class LockerServiceClient
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

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

type LockerId = LockerTypes.LockerId

local stoppers: { () -> () } = {}

local function finishOpeningImpl()
	local outcome = LockerStore.finishOpening()
	SceneStack.remove(LockerViewModel.OPENING_SCENE)
	if outcome ~= nil then
		CosmeticRevealStore.push({
			ids = { outcome.item },
			source = "locker",
			duplicate = outcome.duplicate,
			refund = outcome.refund,
			currency = if outcome.locker == "gleam" then "gleam" else "gloom",
		})
	end
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
	finishOpening: (self: LockerServiceClient) -> (),
}

local LockerServiceClient: LockerServiceClient = {
	dependencies = {},

	init = function(_self)
		ensureScene()
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

	finishOpening = function(_self)
		finishOpeningImpl()
	end,
}

return LockerServiceClient
