--!strict
--[=[
	TimecardMomentSystem: the Timecard's two moments on this client.

	- **The stamp.** When the replicated card gains today's punch after this client asked for one
	  (TimecardMomentStore.expecting), it shows the stamp (TimecardMomentStore.stamp, drawn by DepotTimecardStamp),
	  plays the punch clock, then the rubber stamp as it lands, then the contract-met fanfare when the punch paid a
	  reward, and takes the stamp down after STAMP_SECONDS. The server already paid; this only shows it.
	- **The greeting.** In the hub, on the real card, with no other screen up (a waiting reveal counts), it opens the
	  clipboard on the Timecard once a UTC day while today is still free (TimecardMomentUtils.shouldGreet), after
	  the hub has stayed free for GREET_SETTLE.

	`start` subscribes to the stores both read; `punched` and `greet` take their effects as deps so specs drive them.

	@class TimecardMomentSystem
]=]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Charm = require(ReplicatedStorage.Packages.Charm)
local PlayerDataTypes = require(ReplicatedStorage.Shared.Data.PlayerDataTypes)
-- Registers the shift's punch clock, stamp and fanfare sounds this reuses.
require(ReplicatedStorage.Shared.Features.Shift.Data.ShiftAssets)
local TimecardRules = require(ReplicatedStorage.Shared.Features.Timecard.Rules.TimecardRules)
local WorkOrderRegistry = require(ReplicatedStorage.Shared.Features.WorkOrder.Data.WorkOrderRegistry)
local TimecardMomentStore = require(ReplicatedStorage.Client.Features.Timecard.State.TimecardMomentStore)
local TimecardMomentUtils = require(ReplicatedStorage.Client.Features.Timecard.Utils.TimecardMomentUtils)
local Company = require(ReplicatedStorage.Client.Features.UI.State.UICompanyStore)
local CosmeticRevealStore = require(ReplicatedStorage.Client.Features.Cosmetic.State.CosmeticRevealStore)
local DepotStore = require(ReplicatedStorage.Client.Features.Depot.State.DepotStore)
local ShiftStore = require(ReplicatedStorage.Client.Features.Shift.State.ShiftStore)
local SoundServiceClient = require(ReplicatedStorage.Client.Features.Sound.SoundServiceClient)
local StateSyncClientStore = require(ReplicatedStorage.Client.Features.StateSync.State.StateSyncClientStore)
local DepotHubViewModel = require(ReplicatedStorage.Client.UI.React.Screens.Depot.DepotHubViewModel)
local SceneStack = require(ReplicatedStorage.Client.UI.Scenes.SceneStack)
local UIStore = require(ReplicatedStorage.Client.UI.Scenes.UIStore)

export type Deps = {
	play: (id: string) -> (),
	delay: (seconds: number, callback: () -> ()) -> (),
	open: () -> (),
}

-- How long the stamp stays up, and when the stamp sound and the fanfare land after the punch clock (the stamp's
-- slam in DepotTimecardStamp takes STAMP_LANDS).
local STAMP_SECONDS = 2.8
local STAMP_LANDS = 0.22
local REWARD_AT = 0.55
-- The hub settles this long (no other screen up) before the greeting opens: the pick closing and the hire reveal
-- that follows it land a moment apart, and the greeting must not slip into that gap.
local GREET_SETTLE = 1.5

local SOUNDS = table.freeze({
	clock = "shiftPunchIn",
	stamp = "shiftStamp",
	reward = "shiftContractMet",
})

local defaults: Deps = {
	play = function(id)
		SoundServiceClient:playOneShot(id)
	end,
	delay = function(seconds, callback)
		task.delay(seconds, callback)
	end,
	open = function()
		Company.open("timecard")
	end,
}

-- The timecard atom's placeholder (taken at require, before the first sync): until the atom holds another table the
-- server's card has not arrived, and the placeholder always says "today is free".
local timecardSeed = StateSyncClientStore.timecard()
local stoppers: { () -> () } = {}
-- Bumped by every sync and by stop, so only the latest scheduled check (of a running system) acts.
local greetRound = 0

local TimecardMomentSystem = {
	SOUNDS = SOUNDS,
	STAMP_SECONDS = STAMP_SECONDS,
	STAMP_LANDS = STAMP_LANDS,
}

--[=[
	Shows today's stamp when `after` gained today's punch that this client asked for. Returns the moment shown.
]=]
function TimecardMomentSystem.punched(
	before: PlayerDataTypes.Timecard,
	after: PlayerDataTypes.Timecard,
	now: number,
	deps: Deps?
): TimecardMomentUtils.Moment?
	local use = deps or defaults
	if not TimecardMomentStore.expecting() then
		return nil
	end
	local moment = TimecardMomentUtils.moment(before, after, now)
	if moment == nil then
		return nil
	end
	TimecardMomentStore.expect(false)
	TimecardMomentStore.show(moment)
	use.play(SOUNDS.clock)
	use.delay(STAMP_LANDS, function()
		use.play(SOUNDS.stamp)
	end)
	if moment.reward ~= nil then
		use.delay(REWARD_AT, function()
			use.play(SOUNDS.reward)
		end)
	end
	use.delay(STAMP_SECONDS, function()
		TimecardMomentStore.clear(moment.id)
	end)
	return moment
end

--[=[
	Opens the Timecard when today's greeting is due. Returns whether it opened.
]=]
function TimecardMomentSystem.greet(input: TimecardMomentUtils.GreetInput, deps: Deps?): boolean
	if not TimecardMomentUtils.shouldGreet(input) then
		return false
	end
	TimecardMomentStore.greet(input.day)
	local use = deps or defaults
	use.open()
	return true
end

local function now(): number
	return Workspace:GetServerTimeNow()
end

local function greetInput(): TimecardMomentUtils.GreetInput
	local card = StateSyncClientStore.timecard()
	local moment = now()
	return {
		synced = card ~= timecardSeed,
		inHub = DepotHubViewModel.visible(ShiftStore.snapshot(), Players.LocalPlayer.UserId),
		busy = DepotStore.card() ~= nil
			or SceneStack.depth() > 0
			or Company.visible()
			or CosmeticRevealStore.current() ~= nil,
		canPunch = TimecardRules.canPunch(card, moment),
		greeted = TimecardMomentStore.greeted(),
		day = WorkOrderRegistry.dayIndex(moment),
	}
end

-- Checks again after GREET_SETTLE and greets only if the hub is still free then.
local function syncGreeting()
	if not TimecardMomentUtils.shouldGreet(greetInput()) then
		return
	end
	greetRound += 1
	local round = greetRound
	task.delay(GREET_SETTLE, function()
		if round == greetRound then
			TimecardMomentSystem.greet(greetInput())
		end
	end)
end

function TimecardMomentSystem.start()
	TimecardMomentSystem.stop()
	table.insert(
		stoppers,
		Charm.subscribe(StateSyncClientStore.timecard, function(after, before)
			TimecardMomentSystem.punched(before, after, now())
		end)
	)
	table.insert(stoppers, Charm.subscribe(StateSyncClientStore.timecard, syncGreeting))
	table.insert(stoppers, Charm.subscribe(ShiftStore.snapshot, syncGreeting))
	table.insert(stoppers, Charm.subscribe(DepotStore.card, syncGreeting))
	table.insert(stoppers, Charm.subscribe(UIStore.sceneStack, syncGreeting))
	table.insert(stoppers, Charm.subscribe(CosmeticRevealStore.current, syncGreeting))
	syncGreeting()
end

function TimecardMomentSystem.stop()
	greetRound += 1
	for _, stop in stoppers do
		stop()
	end
	table.clear(stoppers)
	TimecardMomentStore.reset()
end

return TimecardMomentSystem
