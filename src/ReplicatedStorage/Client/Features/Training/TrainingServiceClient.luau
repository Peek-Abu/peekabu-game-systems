--!strict
--[=[
	TrainingServiceClient: training on this client (tutorial design v2).

	- In the hub: the Training pad signs and the new-player arrow (TrainingHubSystem), from this player's synced
	  "training" slice (TrainingRules.isNew), and the after-training tour when the server sends it (TrainingEvents.Tour).
	- On a player's first run (training's or a shift's): the hotbar tour when the server sends it
	  (TrainingEvents.Hotbar): the vacuum's slot, then the power button.
	- On a training run: the hall's signs, lights out, creeping Gloom and glowing desk (TrainingHallSystem), from the
	  stop in the `training` world entry; the hall is put back when the entry goes.

	@class TrainingServiceClient
]=]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Charm = require(ReplicatedStorage.Packages.Charm)
local PlayerDataTypes = require(ReplicatedStorage.Shared.Data.PlayerDataTypes)
local WorldTypes = require(ReplicatedStorage.Shared.Data.WorldTypes)
local StateSyncConstants = require(ReplicatedStorage.Shared.Features.StateSync.Data.StateSyncConstants)
local TrainingConstants = require(ReplicatedStorage.Shared.Features.Training.Data.TrainingConstants)
local VacuumConstants = require(ReplicatedStorage.Shared.Features.Vacuum.Data.VacuumConstants)
local TrainingEvents = require(ReplicatedStorage.Shared.Features.Training.Net.TrainingEvents)
local TrainingRules = require(ReplicatedStorage.Shared.Features.Training.Rules.TrainingRules)
local StateSyncClientStore = require(ReplicatedStorage.Client.Features.StateSync.State.StateSyncClientStore)
local TrainingHallSystem = require(ReplicatedStorage.Client.Features.Training.Systems.TrainingHallSystem)
local TrainingHubSystem = require(ReplicatedStorage.Client.Features.Training.Systems.TrainingHubSystem)
local TrainingSpotlightSystem = require(ReplicatedStorage.Client.Features.Training.Systems.TrainingSpotlightSystem)

local stoppers: { () -> () } = {}

local function onWorld(world: WorldTypes.WorldMap)
	local stop = world[TrainingConstants.WORLD_ENTRY]
	if type(stop) == "number" then
		TrainingHallSystem.apply(stop)
	else
		TrainingHallSystem.clear()
	end
end

-- Whether this player's vacuum is out (their public entry), which ends the hotbar tour's vacuum step.
local function vacuumOut(): boolean
	local entry = StateSyncClientStore.publicPlayers()[StateSyncConstants.publicEntryKey(Players.LocalPlayer.UserId)]
	return entry ~= nil and entry[VacuumConstants.PUBLIC_EQUIPPED_FIELD] == true
end

local function onTraining(training: PlayerDataTypes.Training?)
	TrainingHubSystem.setNew(TrainingRules.isNew(training))
end

export type TrainingServiceClient = {
	dependencies: { string },
	start: (self: TrainingServiceClient) -> (),
	stop: (self: TrainingServiceClient) -> (),
}

local TrainingServiceClient: TrainingServiceClient = {
	dependencies = { "StateSyncServiceClient", "UIServiceClient" },

	start = function(_self)
		TrainingHubSystem.start()
		table.insert(stoppers, TrainingHubSystem.stop)
		table.insert(stoppers, Charm.subscribe(StateSyncClientStore.training, onTraining))
		onTraining(StateSyncClientStore.training())
		table.insert(stoppers, Charm.subscribe(StateSyncClientStore.world, onWorld))
		onWorld(StateSyncClientStore.world())
		table.insert(
			stoppers,
			TrainingEvents.packets.Tour.listen(function(_value: boolean)
				TrainingHubSystem.tour()
			end)
		)
		table.insert(
			stoppers,
			TrainingEvents.packets.Hotbar.listen(function(_value: boolean)
				TrainingSpotlightSystem.point({
					{
						kind = "gui",
						tag = TrainingConstants.SPOTLIGHT_TAGS.vacuum,
						line = TrainingConstants.TEXT.tourVacuum,
						seconds = TrainingConstants.HOTBAR_SECONDS,
						done = vacuumOut,
					},
					{
						kind = "gui",
						tag = TrainingConstants.SPOTLIGHT_TAGS.power,
						line = TrainingConstants.TEXT.tourPower,
						seconds = TrainingConstants.HOTBAR_SECONDS,
					},
				})
			end)
		)
	end,

	stop = function(_self)
		for _, stop in stoppers do
			stop()
		end
		table.clear(stoppers)
		TrainingHallSystem.clear()
		TrainingSpotlightSystem.clear()
	end,
}

return TrainingServiceClient
