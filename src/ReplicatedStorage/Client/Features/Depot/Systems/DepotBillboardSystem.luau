--!strict
--[=[
	DepotBillboardSystem: draws the depot's world signs on this client (Figma World UI 2a). The server builds each sign
	as an empty tagged shell (DepotBuildSystem); this watches the tags (UIBillboardHost.watch) and keeps one React root
	per shell (UIBillboards). Truck tags (W1): the crew and the countdown come from Queue's state-synced snapshot and each
	player's public `truck` field; every TICK_SECONDS each tag is rebuilt (DepotWorldViewModel.truckTag) and rendered
	only when a drawn line changed (`sameTag`), so the countdown re-renders once a second and nothing remounts.

	Spec-exempt shell (CollectionService, RunService, React roots); the decisions are the specced DepotWorldViewModel and
	the UIBillboards core.

	@class DepotBillboardSystem
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local React = require(ReplicatedStorage.Packages.React)
local DepotConstants = require(ReplicatedStorage.Shared.Features.Depot.Data.DepotConstants)
local QueueStore = require(ReplicatedStorage.Client.Features.Queue.State.QueueStore)
local StateSyncClientStore = require(ReplicatedStorage.Client.Features.StateSync.State.StateSyncClientStore)
local UIBillboardHost = require(ReplicatedStorage.Client.UI.Layers.UIBillboardHost)
local UIBillboards = require(ReplicatedStorage.Client.UI.Layers.UIBillboards)
local DepotTruckTag = require(ReplicatedStorage.Client.UI.React.Screens.World.DepotTruckTag)
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
local trucks: { [BillboardGui]: true } = {}
-- The tag each truck shell last rendered, so an unchanged tag is skipped.
local drawn: { [BillboardGui]: DepotWorldViewModel.TruckTagView } = {}
local stoppers: { () -> () } = {}

local function sign(design: Vector2, child: React.ReactNode): React.ReactNode
	return e(WorldBillboard, { design = design, sizing = "studs" }, { sign = child })
end

local function drawTruck(shell: BillboardGui)
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

local function count(set: { [BillboardGui]: true }): number
	local total = 0
	for _ in set do
		total += 1
	end
	return total
end

local function watch(tag: string, refresh: (shell: BillboardGui) -> (), removed: ((shell: BillboardGui) -> ())?)
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
	table.clear(drawn)
end

function DepotBillboardSystem.getState(): DepotBillboardState
	return { mounted = roots.count(), trucks = count(trucks), reviews = 0 }
end

return DepotBillboardSystem
