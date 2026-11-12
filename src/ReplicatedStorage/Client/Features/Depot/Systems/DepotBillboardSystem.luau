--!strict
--[=[
	DepotBillboardSystem: draws the depot's world signs on this client (Figma World UI 2a). The server builds each sign
	as an empty tagged shell (DepotBuildSystem); this watches the tags (UIBillboardHost.watch) and keeps one React root
	per shell (UIBillboards). Truck tags (W1): the crew and the countdown come from Queue's state-synced snapshot and each
	player's public `truck` field; every TICK_SECONDS each tag is rebuilt (DepotWorldViewModel.truckTag) and rendered
	only when a drawn line changed (`sameTag`), so the countdown re-renders once a second and nothing remounts. The contract
	board (W2) draws from its shell's attributes and the local player's truck crew (its CLEAR line is that crew's quota),
	redrawn on the same tick when the crew changes; the result board (W3) draws from its shell's attributes; your review card's shell (W4, in your
	PlayerGui) draws the whole result board with your card and award stickies, and while it exists the shared board draws
	nothing (DepotWorldViewModel.drawsSharedBoard). The crew board draws the weekly crew leaderboard from the
	`crewBoard` world entry (LeaderboardBoardViewModel), checked on the same tick and redrawn only when its words change
	(the countdown moves once a minute). The time clock's sign (DepotClockSign) and the daily bonus sheet (DepotDailySign,
	today's work order, redrawn when the day turns) are drawn in the game's kit too (owner 11-11).

	Spec-exempt shell (CollectionService, RunService, React roots); the decisions are the specced DepotWorldViewModel and
	the UIBillboards core.

	@class DepotBillboardSystem
]=]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local React = require(ReplicatedStorage.Packages.React)
local DepotConstants = require(ReplicatedStorage.Shared.Features.Depot.Data.DepotConstants)
local HostStore = require(ReplicatedStorage.Client.Features.Host.State.HostStore)
local QueueStore = require(ReplicatedStorage.Client.Features.Queue.State.QueueStore)
local StateSyncClientStore = require(ReplicatedStorage.Client.Features.StateSync.State.StateSyncClientStore)
local UIBillboardHost = require(ReplicatedStorage.Client.UI.Layers.UIBillboardHost)
local UIBillboards = require(ReplicatedStorage.Client.UI.Layers.UIBillboards)
local DepotClockSign = require(ReplicatedStorage.Client.UI.React.Screens.World.DepotClockSign)
local DepotDailySign = require(ReplicatedStorage.Client.UI.React.Screens.World.DepotDailySign)
local DepotResultBoard = require(ReplicatedStorage.Client.UI.React.Screens.World.DepotResultBoard)
local DepotBoardViewModel = require(ReplicatedStorage.Client.UI.React.Screens.Depot.DepotBoardViewModel)
local DepotTruckTag = require(ReplicatedStorage.Client.UI.React.Screens.World.DepotTruckTag)
local DepotWorkOrderBoard = require(ReplicatedStorage.Client.UI.React.Screens.World.DepotWorkOrderBoard)
local DepotWorldViewModel = require(ReplicatedStorage.Client.UI.React.Screens.World.DepotWorldViewModel)
local DepotRankBoard = require(ReplicatedStorage.Client.UI.React.Screens.World.DepotRankBoard)
local DepotSignViewModel = require(ReplicatedStorage.Client.UI.React.Screens.World.DepotSignViewModel)
local RankViewModel = require(ReplicatedStorage.Client.UI.React.Screens.Rank.RankViewModel)
local TimecardRules = require(ReplicatedStorage.Shared.Features.Timecard.Rules.TimecardRules)
local WorkOrderRules = require(ReplicatedStorage.Shared.Features.WorkOrder.Rules.WorkOrderRules)
local LeaderboardBoard = require(ReplicatedStorage.Client.UI.React.Screens.Leaderboard.LeaderboardBoard)
local LeaderboardBoardViewModel =
	require(ReplicatedStorage.Client.UI.React.Screens.Leaderboard.LeaderboardBoardViewModel)
local LeaderboardConstants = require(ReplicatedStorage.Shared.Features.Leaderboard.Data.LeaderboardConstants)
local LeaderboardCrewUtils = require(ReplicatedStorage.Shared.Features.Leaderboard.Utils.LeaderboardCrewUtils)
local WorldBillboard = require(ReplicatedStorage.Client.UI.React.Screens.World.WorldBillboard)
local WorkOrderRegistry = require(ReplicatedStorage.Shared.Features.WorkOrder.Data.WorkOrderRegistry)

export type DepotBillboardState = {
	mounted: number,
	trucks: number,
	reviews: number,
}

local e = React.createElement

local TAGS = DepotConstants.BILLBOARD_TAGS
local PX = DepotConstants.BILLBOARD_PX
local TICK_SECONDS = 0.25

local roots = UIBillboards.new(UIBillboardHost.factory)
local trucks: { [UIBillboards.WorldShell]: true } = {}
-- The tag each truck shell last rendered, so an unchanged tag is skipped.
local drawn: { [UIBillboards.WorldShell]: DepotWorldViewModel.TruckTagView } = {}
local stoppers: { () -> () } = {}

local function sign(design: Vector2, child: React.ReactNode): React.ReactNode
	return e(WorldBillboard, { design = design, sizing = "studs" }, { sign = child })
end

-- The host of the truck on Queue pad `padId` (crew hosting), for its tag; nil while nobody hosts it.
local function hostOf(padId: string?): DepotWorldViewModel.TruckHost?
	local snapshot = HostStore.snapshot()
	local truck = if padId ~= nil and snapshot ~= nil then snapshot.trucks[padId] else nil
	if truck == nil then
		return nil
	end
	local player = Players:GetPlayerByUserId(truck.host)
	return { name = if player ~= nil then player.DisplayName else "Crew", locked = truck.locked }
end

local function drawTruck(shell: UIBillboards.WorldShell)
	local truck = shell:GetAttribute(DepotConstants.TRUCK_ATTRIBUTE)
	local capacity = shell:GetAttribute(DepotConstants.CAPACITY_ATTRIBUTE)
	if type(truck) ~= "number" or type(capacity) ~= "number" then
		return
	end
	local pad, padId = DepotWorldViewModel.padFor(QueueStore.snapshot(), truck, StateSyncClientStore.publicPlayers())
	local view = DepotWorldViewModel.truckTag(truck, capacity, pad, Workspace:GetServerTimeNow(), hostOf(padId))
	if DepotWorldViewModel.sameTag(drawn[shell], view) then
		return
	end
	drawn[shell] = view
	roots.show(shell, sign(PX.truck, e(DepotTruckTag, { view = view })))
end

local results: { [UIBillboards.WorldShell]: true } = {}
local reviews: { [UIBillboards.WorldShell]: true } = {}

-- Your review shell (PlayerGui, the same spot and size) draws the whole result board with your card on it; while you
-- have one, the shared board's shell draws nothing, so two signs never z-fight. Without one: the bare board.
local function drawResults()
	local draws = DepotWorldViewModel.drawsSharedBoard(next(reviews) ~= nil)
	for shell in results do
		if draws then
			roots.show(shell, sign(PX.result, e(DepotResultBoard, { title = DepotConstants.RESULT_BOARD_TITLE })))
		else
			roots.hide(shell)
		end
	end
end

local function drawReview(shell: UIBillboards.WorldShell)
	local review = DepotWorldViewModel.review(shell:GetAttributes())
	roots.show(
		shell,
		sign(PX.result, e(DepotResultBoard, { title = DepotConstants.RESULT_BOARD_TITLE, review = review }))
	)
end

local contracts: { [UIBillboards.WorldShell]: true } = {}
-- The local player's truck crew the contract boards last drew (nil: not in a truck; 0 before the first draw).
local drawnCrew: number? = 0

local function myCrew(): number?
	return DepotBoardViewModel.crewOf(QueueStore.snapshot(), Players.LocalPlayer.UserId)
end

local function drawContract(shell: UIBillboards.WorldShell)
	local crew = myCrew()
	drawnCrew = crew
	local view = DepotWorldViewModel.workOrder(shell:GetAttributes(), crew)
	roots.show(shell, if view ~= nil then sign(PX.contract, e(DepotWorkOrderBoard, { view = view })) else nil)
end

local crewBoards: { [UIBillboards.WorldShell]: true } = {}
-- The crew board's words as last drawn (one string), so an unchanged board is not redrawn.
local drawnCrewBoard: string? = nil

local function crewView(): LeaderboardBoardViewModel.View
	local board = LeaderboardCrewUtils.decodeBoard(StateSyncClientStore.world()[LeaderboardConstants.WORLD_ENTRY])
	return LeaderboardBoardViewModel.view(board, Workspace:GetServerTimeNow())
end

local function crewWords(view: LeaderboardBoardViewModel.View): string
	local parts = { view.title, view.subtitle, view.empty or "" }
	for _, row in view.rows do
		table.insert(parts, `{row.rank}|{row.names}|{row.score}`)
	end
	return table.concat(parts, "|")
end

local function drawCrewBoards(force: boolean)
	local view = crewView()
	local words = crewWords(view)
	if not force and words == drawnCrewBoard then
		return
	end
	drawnCrewBoard = words
	for shell in crewBoards do
		roots.show(shell, sign(PX.crew, e(LeaderboardBoard, { view = view })))
	end
end

-- The number-and-picture signs (owner 11-12, kit mock round 2 #2): the time clock's punches, today's bonus job and
-- the rank ladder, each from this player's synced state, redrawn on the tick only when what they show changed (each
-- shell keeps the words it last drew).
local clockSigns: { [UIBillboards.WorldShell]: string } = {}
local dailySigns: { [UIBillboards.WorldShell]: string } = {}
local rankBoards: { [UIBillboards.WorldShell]: string } = {}

local function drawClock(shell: UIBillboards.WorldShell, force: boolean)
	local now = Workspace:GetServerTimeNow()
	local view = DepotSignViewModel.clock(TimecardRules.status(StateSyncClientStore.timecard(), now))
	local words = `{table.concat(view.slots, ",")}|{view.keyEarned}`
	if not force and clockSigns[shell] == words then
		return
	end
	clockSigns[shell] = words
	roots.show(shell, sign(PX.clock, e(DepotClockSign, { view = view })))
end

local function drawDaily(shell: UIBillboards.WorldShell, force: boolean)
	local now = Workspace:GetServerTimeNow()
	local view = DepotSignViewModel.daily(
		WorkOrderRegistry.orderFor(now),
		WorkOrderRules.roll(StateSyncClientStore.workOrder(), now)
	)
	local words = `{view.icon}|{view.count}|{view.progress}|{view.done}`
	if not force and dailySigns[shell] == words then
		return
	end
	dailySigns[shell] = words
	roots.show(shell, sign(PX.daily, e(DepotDailySign, { view = view })))
end

local function drawRank(shell: UIBillboards.WorldShell, force: boolean)
	local rank = RankViewModel.rankOf(StateSyncClientStore.publicPlayers(), Players.LocalPlayer.UserId)
	local view = DepotSignViewModel.ranks(if rank ~= nil then rank.xp else nil)
	local words = tostring(view.you)
	if not force and rankBoards[shell] == words then
		return
	end
	rankBoards[shell] = words
	roots.show(shell, sign(PX.rank, e(DepotRankBoard, { view = view })))
end

local function count(set: { [UIBillboards.WorldShell]: true }): number
	local total = 0
	for _ in set do
		total += 1
	end
	return total
end

local function watch(
	tag: string,
	refresh: (shell: UIBillboards.WorldShell) -> (),
	removed: ((shell: UIBillboards.WorldShell) -> ())?
)
	table.insert(stoppers, UIBillboardHost.watch({ tag = tag, roots = roots, refresh = refresh, removed = removed }))
end

local DepotBillboardSystem = {}

function DepotBillboardSystem.start()
	if #stoppers > 0 then
		return
	end
	watch(TAGS.truck, function(shell)
		trucks[shell] = true
		-- An attribute change redraws even an unchanged tag.
		drawn[shell] = nil
		drawTruck(shell)
	end, function(shell)
		trucks[shell] = nil
		drawn[shell] = nil
	end)
	watch(TAGS.contract, function(shell)
		contracts[shell] = true
		drawContract(shell)
	end, function(shell)
		contracts[shell] = nil
	end)
	watch(TAGS.result, function(shell)
		results[shell] = true
		drawResults()
	end, function(shell)
		results[shell] = nil
	end)
	watch(TAGS.crew, function(shell)
		crewBoards[shell] = true
		drawCrewBoards(true)
	end, function(shell)
		crewBoards[shell] = nil
	end)
	watch(TAGS.clock, function(shell)
		drawClock(shell, true)
	end, function(shell)
		clockSigns[shell] = nil
	end)
	watch(TAGS.rank, function(shell)
		drawRank(shell, true)
	end, function(shell)
		rankBoards[shell] = nil
	end)
	watch(TAGS.daily, function(shell)
		drawDaily(shell, true)
	end, function(shell)
		dailySigns[shell] = nil
	end)
	watch(TAGS.review, function(shell)
		reviews[shell] = true
		drawReview(shell)
		drawResults()
	end, function(shell)
		reviews[shell] = nil
		drawResults()
	end)
	local elapsed = 0
	local ticking = RunService.Heartbeat:Connect(function(deltaTime: number)
		elapsed += deltaTime
		if elapsed < TICK_SECONDS then
			return
		end
		elapsed = 0
		for shell in trucks do
			drawTruck(shell)
		end
		if myCrew() ~= drawnCrew then
			for shell in contracts do
				drawContract(shell)
			end
		end
		if next(crewBoards) ~= nil then
			drawCrewBoards(false)
		end
		for shell in dailySigns do
			drawDaily(shell, false)
		end
		for shell in clockSigns do
			drawClock(shell, false)
		end
		for shell in rankBoards do
			drawRank(shell, false)
		end
	end)
	table.insert(stoppers, function()
		ticking:Disconnect()
	end)
end

function DepotBillboardSystem.stop()
	for _, stop in stoppers do
		stop()
	end
	table.clear(stoppers)
	roots.teardown()
	table.clear(trucks)
	table.clear(clockSigns)
	table.clear(dailySigns)
	table.clear(rankBoards)
	table.clear(results)
	table.clear(reviews)
	table.clear(drawn)
	table.clear(contracts)
	drawnCrew = 0
end

function DepotBillboardSystem.getState(): DepotBillboardState
	return { mounted = roots.count(), trucks = count(trucks), reviews = count(reviews) }
end

return DepotBillboardSystem
