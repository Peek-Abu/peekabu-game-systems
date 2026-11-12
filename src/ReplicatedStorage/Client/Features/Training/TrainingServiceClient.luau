--!strict
--[=[
	TrainingServiceClient: training on this client (tutorial design v2).

	- In the hub: the Training pad signs and the new-player arrow (TrainingHubSystem), from this player's synced
	  "training" slice (TrainingRules.isNew), and the after-training tour when the server sends it (TrainingEvents.Tour).
	- On a player's first run (training's or a shift's): the hotbar tour when the server sends it
	  (TrainingEvents.Hotbar): the vacuum's slot, then a run the player must do (hold Shift / RUN), then the power
	  button, which passes only when they really use their crew move (TrainingGuideRules.ranEnough / powerUsed). On a
	  training run the steps after the vacuum follow the server's STEP_ENTRY (TrainingStepRules: suck up the Gloom,
	  then run, then the power, in that order; the server decides when each is done).
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
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Charm = require(ReplicatedStorage.Packages.Charm)
local PlayerDataTypes = require(ReplicatedStorage.Shared.Data.PlayerDataTypes)
local WorldTypes = require(ReplicatedStorage.Shared.Data.WorldTypes)
local StateSyncConstants = require(ReplicatedStorage.Shared.Features.StateSync.Data.StateSyncConstants)
local TrainingConstants = require(ReplicatedStorage.Shared.Features.Training.Data.TrainingConstants)
local VacuumConstants = require(ReplicatedStorage.Shared.Features.Vacuum.Data.VacuumConstants)
local TrainingEvents = require(ReplicatedStorage.Shared.Features.Training.Net.TrainingEvents)
local TrainingGuideRules = require(ReplicatedStorage.Shared.Features.Training.Rules.TrainingGuideRules)
local TrainingRules = require(ReplicatedStorage.Shared.Features.Training.Rules.TrainingRules)
local AbilityStore = require(ReplicatedStorage.Client.Features.Ability.State.AbilityStore)
local SprintStore = require(ReplicatedStorage.Client.Features.Sprint.State.SprintStore)
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
	local rawClear = world[TrainingConstants.CLEAR_ENTRY]
	local clear = if type(rawClear) == "number" then rawClear else nil
	TrainingHubSystem.setRun(type(stop) == "number")
	if type(stop) == "number" then
		TrainingHallSystem.apply(stop)
		TrainingHallSystem.setClear(clear)
		TrainingTrailSystem.setStop(stop)
		TrainingTrailSystem.setClear(clear)
		TrainingCoachStore.setStop(stop)
	else
		TrainingHallSystem.clear()
		TrainingTrailSystem.setStop(nil)
		TrainingTrailSystem.setClear(nil)
		-- The run's entry goes when the player picks on the finish screen (or its wait runs out): the screen goes too.
		TrainingCoachStore.reset()
	end
end

-- Whether this player's vacuum is out (their public entry), which ends the hotbar tour's vacuum step.
local function vacuumOut(): boolean
	local entry = StateSyncClientStore.publicPlayers()[StateSyncConstants.publicEntryKey(Players.LocalPlayer.UserId)]
	return entry ~= nil and entry[VacuumConstants.PUBLIC_EQUIPPED_FIELD] == true
end

-- The hotbar tour: the vacuum's slot; a run they must do (Shift, the left stick, or the phone's SPRINT button,
-- ShiftMobileButtons); their power, which they must really use (skipped for an employee with none).
-- The finish screen's HUD order: above every other widget (the paper toasts are 1000, the hide chip 1010).
local TRAINING_FINISH_HUD_ORDER = 2000

-- The training run's first-stop step on now (the server's STEP_ENTRY), or nil outside a training run.
local function stepNow(): string?
	local value = StateSyncClientStore.world()[TrainingConstants.STEP_ENTRY]
	return if type(value) == "string" then value else nil
end

local function runLineNow(): string
	return if UserInputService.KeyboardEnabled
		then TrainingConstants.TEXT.tourRun
		elseif UserInputService.TouchEnabled then TrainingConstants.TEXT.tourRunTouch
		else TrainingConstants.TEXT.tourRunPad
end

-- A training run's tour: the vacuum's slot, then each step the server is on, in its order (owner 11-12: a step can
-- never be skipped); each tip stays until the server moves past its step.
local function trainingTour(): { TrainingSpotlightSystem.Step }
	local function past(order: { string }): () -> boolean
		return function()
			local step = stepNow()
			return step == nil or table.find(order, step) == nil
		end
	end
	local steps: { TrainingSpotlightSystem.Step } = {
		{
			kind = "gui",
			tag = TrainingConstants.SPOTLIGHT_TAGS.vacuum,
			line = TrainingConstants.TEXT.tourVacuum,
			seconds = TrainingConstants.HOTBAR_SECONDS,
			done = vacuumOut,
		},
		{ kind = "do", tag = "", line = TrainingConstants.TEXT.tourGloom, mustDo = true, done = past({ "gloom" }) },
		{ kind = "do", tag = "", line = runLineNow(), mustDo = true, done = past({ "gloom", "run" }) },
	}
	if AbilityStore.abilityId() ~= nil then
		table.insert(steps, {
			kind = "gui",
			tag = TrainingConstants.SPOTLIGHT_TAGS.power,
			line = TrainingConstants.TEXT.tourPower,
			mustDo = true,
			done = past({ "gloom", "run", "power" }),
		})
	end
	return steps
end

local function hotbarTour(): { TrainingSpotlightSystem.Step }
	if stepNow() ~= nil then
		return trainingTour()
	end
	local sprinted = 0
	local lastCheck: number? = nil
	local startReady = AbilityStore.readyAt()
	local steps: { TrainingSpotlightSystem.Step } = {
		{
			kind = "gui",
			tag = TrainingConstants.SPOTLIGHT_TAGS.vacuum,
			line = TrainingConstants.TEXT.tourVacuum,
			seconds = TrainingConstants.HOTBAR_SECONDS,
			done = vacuumOut,
		},
	}
	local runLine = runLineNow()
	table.insert(steps, {
		kind = "do",
		tag = "",
		line = runLine,
		mustDo = true,
		done = function()
			local now = os.clock()
			local last = lastCheck
			if last ~= nil and SprintStore.sprinting() then
				sprinted += now - last
			end
			lastCheck = now
			return TrainingGuideRules.ranEnough(sprinted)
		end,
	})
	if AbilityStore.abilityId() ~= nil then
		table.insert(steps, {
			kind = "gui",
			tag = TrainingConstants.SPOTLIGHT_TAGS.power,
			line = TrainingConstants.TEXT.tourPower,
			mustDo = true,
			done = function()
				return TrainingGuideRules.powerUsed(
					startReady,
					AbilityStore.readyAt(),
					Workspace:GetServerTimeNow(),
					AbilityStore.active()
				)
			end,
		})
	end
	return steps
end

-- Pippa's last run line: a new one holds the spotlight tour aside (TrainingGuideRules.tourHeld), so a tour step never
-- hides a stop line (owner, 11-10: "Run! Hold Shift" covered every stop line until the player sprinted).
local lastLine: string? = nil
local function onCoachLine()
	local now = os.clock()
	-- The first-run tips belong to the first stop: once the player moves on they end and never come back.
	local stop = TrainingCoachStore.stop()
	if stop ~= nil and not TrainingGuideRules.tourLasts(stop) and TrainingSpotlightSystem.active() then
		TrainingSpotlightSystem.clear()
	end
	local line = if TrainingCoachStore.stop() ~= nil then TrainingCoachStore.line(now) else nil
	local text = if line ~= nil then line.text else nil
	if TrainingGuideRules.lineChanged(lastLine, text) then
		TrainingSpotlightSystem.hold(now + TrainingConstants.COACH_HOLD)
	end
	lastLine = text
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
			-- Over the whole HUD (its dim covers every widget, toasts included): the registry order is the stacking order.
			HudRegistry.register("trainingFinish", TrainingFinish, TRAINING_FINISH_HUD_ORDER)
		end
	end,

	start = function(_self)
		TrainingHubSystem.start()
		table.insert(stoppers, TrainingHubSystem.stop)
		table.insert(stoppers, Charm.subscribe(StateSyncClientStore.training, onTraining))
		onTraining(StateSyncClientStore.training())
		table.insert(stoppers, Charm.subscribe(StateSyncClientStore.world, onWorld))
		onWorld(StateSyncClientStore.world())
		table.insert(stoppers, Charm.subscribe(TrainingCoachStore.stop, onCoachLine))
		table.insert(stoppers, Charm.subscribe(TrainingCoachStore.situation, onCoachLine))
		table.insert(stoppers, Charm.subscribe(TrainingCoachStore.said, onCoachLine))
		onCoachLine()
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
				TrainingSpotlightSystem.point(hotbarTour())
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
