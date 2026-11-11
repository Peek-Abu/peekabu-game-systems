--!strict
--[=[
	DepotSpotSystem: the hub's spots on this client (plan docs/superpowers/plans/2026-11-11-hub-interactables.md). The
	server answers a spot's prompt with DepotEvents.Spot, checked again here (DepotSpotRules.decode), and this opens it:

	- the Supply Counter opens the Shop; a standee opens the Shop on that employee's page;
	- the coffee machine, the crew wall and the rank chart push their scenes (DepotSpotScene);
	- the radio moves to the next station (DepotStore.nextStation; OfficeAtmosphereSystem plays it) and toasts its name.

	A ring of a shift bell (DepotEvents.Bell, to everyone) plays the bell sound at the bell.

	Spec-exempt shell (ByteNet, scene stack, Sound); the decisions are the specced DepotSpotRules and DepotStore.

	@class DepotSpotSystem
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DepotEvents = require(ReplicatedStorage.Shared.Features.Depot.Net.DepotEvents)
local DepotSpotConstants = require(ReplicatedStorage.Shared.Features.Depot.Data.DepotSpotConstants)
local DepotSpotRules = require(ReplicatedStorage.Shared.Features.Depot.Rules.DepotSpotRules)
local DepotStore = require(ReplicatedStorage.Client.Features.Depot.State.DepotStore)
local ShopStore = require(ReplicatedStorage.Client.Features.Shop.State.ShopStore)
local SoundServiceClient = require(ReplicatedStorage.Client.Features.Sound.SoundServiceClient)
local ToastStore = require(ReplicatedStorage.Client.Features.Toast.State.ToastStore)
local SceneStack = require(ReplicatedStorage.Client.UI.Scenes.SceneStack)
local ShopViewModel = require(ReplicatedStorage.Client.UI.React.Screens.Shop.ShopViewModel)
-- Registers the sounds (the bell) and the spot scenes.
require(ReplicatedStorage.Client.Features.Depot.Data.DepotAssets)
require(ReplicatedStorage.Client.UI.React.Screens.Depot.DepotSpotScene)

local SCENES = DepotSpotConstants.SCENES
local RADIO_TOAST_SECONDS = 2.5

local DepotSpotSystem = {}

-- The spot scenes, so the depot can take them down when the player leaves the hub.
DepotSpotSystem.SCENES = { SCENES.coffee, SCENES.crew, SCENES.rank }

local function open(opened: DepotSpotRules.Opened)
	local spot = opened.spot
	if spot == "shop" then
		ShopStore.open(nil)
		SceneStack.push(ShopViewModel.SCENE)
	elseif spot == "standee" then
		ShopStore.open(opened.employee)
		SceneStack.push(ShopViewModel.SCENE)
	elseif spot == "coffee" then
		SceneStack.push(SCENES.coffee)
	elseif spot == "crew" then
		SceneStack.push(SCENES.crew)
	elseif spot == "rank" then
		SceneStack.push(SCENES.rank)
	elseif spot == "radio" then
		local station = DepotStore.nextStation()
		ToastStore.push(`Radio: {station.name}`, "info", RADIO_TOAST_SECONDS, os.clock())
	end
end

-- Listens for spot uses and bell rings; returns the stopper.
function DepotSpotSystem.start(): () -> ()
	local stopSpot = DepotEvents.packets.Spot.listen(function(value: { spot: string, employee: string })
		local opened = DepotSpotRules.decode(value)
		if opened ~= nil then
			open(opened)
		end
	end)
	local stopBell = DepotEvents.packets.Bell.listen(function(at: Vector3)
		SoundServiceClient:playOneShot(DepotSpotConstants.BELL_SOUND, { at = at })
	end)
	return function()
		stopSpot()
		stopBell()
	end
end

return DepotSpotSystem
