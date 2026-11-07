--!strict
--[=[
	TrainingServiceClient: training on this client (tutorial design v2).

	- In the hub: the Training pad signs and the new-player arrow (TrainingHubSystem), from this player's synced
	  "training" slice (TrainingRules.isNew), and the after-training tour when the server sends it (TrainingEvents.Tour).
	- On a training run: the hall's signs, lights out, creeping Gloom and glowing desk (TrainingHallSystem), from the
	  stop in the `training` world entry; the hall is put back when the entry goes.

	@class TrainingServiceClient
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Charm = require(ReplicatedStorage.Packages.Charm)
local PlayerDataTypes = require(ReplicatedStorage.Shared.Data.PlayerDataTypes)
local WorldTypes = require(ReplicatedStorage.Shared.Data.WorldTypes)
local TrainingConstants = require(ReplicatedStorage.Shared.Features.Training.Data.TrainingConstants)
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
