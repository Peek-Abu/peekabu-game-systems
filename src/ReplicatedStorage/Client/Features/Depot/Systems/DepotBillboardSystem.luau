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
	nothing (DepotWorldViewModel.drawsSharedBoard).

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
local QueueStore = require(ReplicatedStorage.Client.Features.Queue.State.QueueStore)
local StateSyncClientStore = require(ReplicatedStorage.Client.Features.StateSync.State.StateSyncClientStore)
local UIBillboardHost = require(ReplicatedStorage.Client.UI.Layers.UIBillboardHost)
local UIBillboards = require(ReplicatedStorage.Client.UI.Layers.UIBillboards)
local DepotResultBoard = require(ReplicatedStorage.Client.UI.React.Screens.World.DepotResultBoard)
local DepotBoardViewModel = require(ReplicatedStorage.Client.UI.React.Screens.Depot.DepotBoardViewModel)
local DepotTruckTag = require(ReplicatedStorage.Client.UI.React.Screens.World.DepotTruckTag)
local DepotWorkOrderBoard = require(ReplicatedStorage.Client.UI.React.Screens.World.DepotWorkOrderBoard)
local DepotWorldViewModel = require(ReplicatedStorage.Client.UI.React.Screens.World.DepotWorldViewModel)
local WorldBillboard = require(ReplicatedStorage.Client.UI.React.Screens.World.WorldBillboard)

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

local function drawTruck(shell: UIBillboards.WorldShell)
	local truck = shell:GetAttribute(DepotConstants.TRUCK_ATTRIBUTE)
	local capacity = shell:GetAttribute(DepotConstants.CAPACITY_ATTRIBUTE)
	if type(truck) ~= "number" or type(capacity) ~= "number" then
		return
	end
	local pad = DepotWorldViewModel.padFor(QueueStore.snapshot(), truck, StateSyncClientStore.publicPlayers())
	local view = DepotWorldViewModel.truckTag(truck, capacity, pad, Workspace:GetServerTimeNow())
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
