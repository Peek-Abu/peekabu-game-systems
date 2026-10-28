--!strict
--[=[
	TimecardServiceClient: the local player's weekly card as the server last wrote it (the replicated `timecard`
	slice) and the punch request.

	Every decision is the server's. This only reads the slice, rolls the card forward for display on the server
	clock (so a player standing in the hub when the week turns sees the new week before punching), and sends the
	punch when the card says today is still free.

	@class TimecardServiceClient
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local PlayerDataTypes = require(ReplicatedStorage.Shared.Data.PlayerDataTypes)
local Charm = require(ReplicatedStorage.Packages.Charm)
local React = require(ReplicatedStorage.Packages.React)
local ReactCharm = require(ReplicatedStorage.Packages.ReactCharm)
local Players = game:GetService("Players")
local Company = require(ReplicatedStorage.Client.Features.UI.State.UICompanyStore)
local Registry = require(ReplicatedStorage.Shared.Features.WorkOrder.Data.WorkOrderRegistry)
local WorkRules = require(ReplicatedStorage.Shared.Features.WorkOrder.Rules.WorkOrderRules)
local ShiftHudViewModel = require(ReplicatedStorage.Client.UI.React.Screens.Shift.ShiftHudViewModel)
local CatchStore = require(ReplicatedStorage.Client.Features.Occupant.State.OccupantCatchStore)
local StateSyncConstants = require(ReplicatedStorage.Shared.Features.StateSync.Data.StateSyncConstants)
local ShiftStore = require(ReplicatedStorage.Client.Features.Shift.State.ShiftStore)
local HudRegistry = require(ReplicatedStorage.Client.UI.React.Screens.Hud.HudRegistry)
local Tracker = require(ReplicatedStorage.Client.UI.React.Screens.Depot.CompanyWorkOrderTracker)
local TrackerViewModel = require(ReplicatedStorage.Client.UI.React.Screens.Depot.CompanyTrackerViewModel)
local DepotHubViewModel = require(ReplicatedStorage.Client.UI.React.Screens.Depot.DepotHubViewModel)
local DepotStore = require(ReplicatedStorage.Client.Features.Depot.State.DepotStore)
local UIStore = require(ReplicatedStorage.Client.UI.Scenes.UIStore)
local PaperHudFrame = require(ReplicatedStorage.Client.UI.React.Screens.Paper.PaperHudFrame)
local usePaperHudScale = require(ReplicatedStorage.Client.UI.React.Screens.Paper.usePaperHudScale)
local useServerClock = require(ReplicatedStorage.Client.UI.React.Hooks.useServerClock)
local feedback = Charm.atom("")
local pending = Charm.atom(false)
local generation = 0
local stopListening: (() -> ())? = nil
local stopOpening: (() -> ())? = nil
export type Deps = { send: () -> (), delay: (number, () -> ()) -> () }
local TimecardShared = ReplicatedStorage.Shared.Features.Timecard
local TimecardCalendarFormulas = require(TimecardShared.Utils.TimecardCalendarFormulas)
local TimecardEvents = require(TimecardShared.Net.TimecardEvents)
local TimecardRules = require(TimecardShared.Rules.TimecardRules)
local StateSyncClientStore = require(ReplicatedStorage.Client.Features.StateSync.State.StateSyncClientStore)
local TimecardMomentStore = require(ReplicatedStorage.Client.Features.Timecard.State.TimecardMomentStore)
local TimecardMomentSystem = require(ReplicatedStorage.Client.Features.Timecard.Systems.TimecardMomentSystem)

local function tracker(): React.ReactNode
	local pinned = ReactCharm.useAtom(Company.pinned)
	local visible = ReactCharm.useAtom(Company.visible)
	local state = ReactCharm.useAtom(StateSyncClientStore.workOrder)
	local card = ReactCharm.useAtom(StateSyncClientStore.timecard)
	local shift = ReactCharm.useAtom(ShiftStore.snapshot)
	local crewOpen = ReactCharm.useAtom(ShiftStore.crewOpen)
	local publicPlayers = ReactCharm.useAtom(StateSyncClientStore.publicPlayers)
	local scaring = ReactCharm.useAtom(CatchStore.scaring)
	local travel = ReactCharm.useAtom(DepotStore.card)
	local scenes = ReactCharm.useAtom(UIStore.sceneStack)
	local scale = usePaperHudScale()
	local now = useServerClock(1)
	local userId = Players.LocalPlayer.UserId
	local inShift = shift ~= nil
		and shift.phase == "running"
		and shift.sub ~= "clockout"
		and not (scale.layout == "phone" and crewOpen)
		and not ShiftHudViewModel.hidden(publicPlayers[StateSyncConstants.publicEntryKey(userId)], scaring)
		and table.find(shift.crew, userId) ~= nil
	local found: TrackerViewModel.Where? = TrackerViewModel.where({
		pinned = pinned,
		clipboardOpen = visible,
		inHub = DepotHubViewModel.visible(shift, userId),
		hubBusy = travel ~= nil or #scenes > 0,
		inShift = inShift,
	})
	if found == nil then
		return nil
	end
	local where: TrackerViewModel.Where = found
	return React.createElement(PaperHudFrame, {
		scale = scale.scale,
		children = {
			daily = React.createElement(Tracker, {
				phone = scale.layout == "phone",
				where = where,
				lines = TrackerViewModel.lines(
					where,
					TimecardRules.status(card, now),
					WorkRules.roll(state, now),
					Registry.orderFor(now),
					now
				),
				onUnpin = Company.togglePin,
				onOpen = if where == "hub"
					then function()
						Company.open(nil)
					end
					else nil,
			}),
		},
	})
end
local function receiveOpen(timecard: boolean)
	Company.open(if timecard then "timecard" else "workOrder")
end
local defaults: Deps = {
	send = function()
		TimecardEvents.packets.Punch.send(true)
	end,
	delay = function(seconds, callback)
		task.delay(seconds, callback)
	end,
}
local deps = defaults
local function receiveResult(message: string)
	generation += 1
	pending(false)
	feedback(message)
end
export type TimecardServiceClient = {
	feedback: Charm.Atom<string>,
	pending: Charm.Atom<boolean>,
	init: (self: TimecardServiceClient) -> (),
	stop: (self: TimecardServiceClient) -> (),
	_setDeps: (self: TimecardServiceClient, replacement: Deps?) -> (),
	_receiveResult: (self: TimecardServiceClient, message: string) -> (),
	_receiveOpen: (self: TimecardServiceClient, timecard: boolean) -> (),
	dependencies: { string },
	timecard: () -> PlayerDataTypes.Timecard,
	status: (self: TimecardServiceClient) -> TimecardRules.Status,
	secondsUntilWeekEnd: (self: TimecardServiceClient) -> number,
	punch: (self: TimecardServiceClient) -> (),
}

local function now(): number
	return Workspace:GetServerTimeNow()
end

local TimecardServiceClient: TimecardServiceClient = {
	dependencies = { "StateSyncServiceClient" },
	feedback = feedback,
	pending = pending,
	init = function(_self)
		local previous = stopListening
		if previous then
			previous()
		end
		stopListening = TimecardEvents.packets.Result.listen(receiveResult)
		local oldOpen = stopOpening
		if oldOpen then
			oldOpen()
		end
		stopOpening = TimecardEvents.packets.OpenClipboard.listen(receiveOpen)
		TimecardMomentSystem.start()
		if not HudRegistry.has("dailyWorkOrderTracker") then
			HudRegistry.register("dailyWorkOrderTracker", tracker, 70)
		end
	end,
	stop = function(_self)
		local stop = stopListening
		if stop then
			stop()
		end
		stopListening = nil
		local stopOpen = stopOpening
		if stopOpen then
			stopOpen()
		end
		stopOpening = nil
		Company.reset()
		TimecardMomentSystem.stop()
		generation += 1
		pending(false)
		feedback("")
	end,
	_setDeps = function(_self, replacement)
		deps = replacement or defaults
	end,
	_receiveOpen = function(_self, timecard)
		receiveOpen(timecard)
	end,
	_receiveResult = function(_self, message)
		receiveResult(message)
	end,
	timecard = StateSyncClientStore.timecard,

	--[=[
		This week's card, on the server's clock.
	]=]
	status = function(_self)
		return TimecardRules.status(StateSyncClientStore.timecard(), now())
	end,

	--[=[
		Seconds until the card rolls over to a new week (for a "new card in" timer).
	]=]
	secondsUntilWeekEnd = function(_self)
		return math.max(0, TimecardCalendarFormulas.weekEnd(now()) - now())
	end,

	--[=[
		Asks the server to punch today (the slice confirms it).
	]=]
	punch = function(self)
		if not self:status().canPunch or pending() then
			return
		end
		generation += 1
		local request = generation
		pending(true)
		TimecardMomentStore.expect(true)
		feedback("Punching...")
		deps.send()
		deps.delay(10, function()
			if request == generation and pending() then
				pending(false)
				TimecardMomentStore.expect(false)
				feedback("No response. Please try again.")
			end
		end)
	end,
}

return TimecardServiceClient
