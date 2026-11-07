--!strict
--[=[
	TrainingServiceClient: training on this client (tutorial design v2).

	- In the hub: the Training pad signs and the new-player arrow (TrainingHubSystem), from this player's synced
	  "training" slice (TrainingRules.isNew), and the after-training tour when the server sends it (TrainingEvents.Tour).
	- On a player's first run (training's or a shift's): the hotbar tour when the server sends it
	  (TrainingEvents.Hotbar): the vacuum's slot, then the power button.
	- On a training run (tutorial v3): from the stop in the `training` world entry, the hall's lights out, creeping
	  Gloom, red danger screen and glowing desk (TrainingHallSystem), the floor trail, arrow and ring
	  (TrainingTrailSystem), and Pippa's lines and the goal bar (TrainingCoachStore, read by the TrainingGuideHud
	  widget and the HUD); all put back when the entry goes. A catch (TrainingEvents.Caught) plays the catch beat; the
	  finish (TrainingEvents.Finish) shows the finish screen (the TrainingFinish widget).
	- Back in the hub after PLAY AGAIN (TrainingEvents.Again): the arrow to the Training pad.

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
local TrainingTrailSystem = require(ReplicatedStorage.Client.Features.Training.Systems.TrainingTrailSystem)
local TrainingCoachStore = require(ReplicatedStorage.Client.Features.Training.State.TrainingCoachStore)
local HudRegistry = require(ReplicatedStorage.Client.UI.React.Screens.Hud.HudRegistry)
local TrainingFinish = require(ReplicatedStorage.Client.UI.React.Screens.Training.TrainingFinish)
local TrainingGuideHud = require(ReplicatedStorage.Client.UI.React.Screens.Training.TrainingGuideHud)
local ShiftConstants = require(ReplicatedStorage.Shared.Features.Shift.Data.ShiftConstants)

local stoppers: { () -> () } = {}

local function onWorld(world: WorldTypes.WorldMap)
	local stop = world[TrainingConstants.WORLD_ENTRY]
	if type(stop) == "number" then
		TrainingHallSystem.apply(stop)
		TrainingTrailSystem.setStop(stop)
		TrainingCoachStore.setStop(stop)
	else
		TrainingHallSystem.clear()
		TrainingTrailSystem.setStop(nil)
		-- The run's entry goes when the player picks on the finish screen (or its wait runs out): the screen goes too.
		TrainingCoachStore.reset()
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
	init: (self: TrainingServiceClient) -> (),
	start: (self: TrainingServiceClient) -> (),
	stop: (self: TrainingServiceClient) -> (),
}

local TrainingServiceClient: TrainingServiceClient = {
	dependencies = { "StateSyncServiceClient", "UIServiceClient" },

	init = function(_self)
		if not HudRegistry.has("trainingGuide") then
			-- Over the shift HUD and the catch cards, under the finish screen.
			HudRegistry.register("trainingGuide", TrainingGuideHud, ShiftConstants.HUD_ORDER + 8)
		end
		if not HudRegistry.has("trainingFinish") then
			HudRegistry.register("trainingFinish", TrainingFinish, ShiftConstants.HUD_ORDER + 9)
		end
	end,

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
			TrainingEvents.packets.Caught.listen(function(lives: number)
				local now = os.clock()
				TrainingCoachStore.caught(now, lives)
				TrainingCoachStore.say(TrainingConstants.COACH.caught, now, TrainingConstants.CATCH_BEAT.done)
			end)
		)
		table.insert(
			stoppers,
			TrainingEvents.packets.Finish.listen(function(gleam: number)
				TrainingCoachStore.finished(gleam)
			end)
		)
		table.insert(
			stoppers,
			TrainingEvents.packets.Again.listen(function(_value: boolean)
				TrainingHubSystem.again()
			end)
		)
		-- The finish screen's pick, to the server.
		table.insert(
			stoppers,
			Charm.subscribe(TrainingCoachStore.picked, function(value: string?)
				if value == "back" then
					TrainingEvents.packets.Back.send(true)
				elseif value == "again" then
					TrainingEvents.packets.Again.send(true)
				end
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
		TrainingTrailSystem.teardown()
		TrainingCoachStore.reset()
	end,
}

return TrainingServiceClient
