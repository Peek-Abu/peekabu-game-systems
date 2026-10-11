--!strict
--[=[
	DepotPad: the truck queue pad HUD widget (registered by DepotServiceClient). While the local player is aboard a pad
	it reads the queue snapshot, their public truck number, the server clock and the device layout, and draws
	DepotPadPanel (which replaces the base placeholder pad panel). Names are the crew display names (the view model names an unknown member "Crew"); the card only
	displays, the server decides who is aboard and when the truck leaves. Depart now is the `onDepart` the service
	passes in (components never talk to the server).

	@class DepotPad
]=]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local React = require(ReplicatedStorage.Packages.React)
local ReactCharm = require(ReplicatedStorage.Packages.ReactCharm)
local DepotConstants = require(ReplicatedStorage.Shared.Features.Depot.Data.DepotConstants)
local QueueSnapshotUtils = require(ReplicatedStorage.Shared.Features.Queue.Utils.QueueSnapshotUtils)
local StateSyncConstants = require(ReplicatedStorage.Shared.Features.StateSync.Data.StateSyncConstants)
local QueueStore = require(ReplicatedStorage.Client.Features.Queue.State.QueueStore)
local StateSyncClientStore = require(ReplicatedStorage.Client.Features.StateSync.State.StateSyncClientStore)
local useServerClock = require(ReplicatedStorage.Client.UI.React.Hooks.useServerClock)
local DepotPadPanel = require(ReplicatedStorage.Client.UI.React.Screens.Depot.DepotPadPanel)
local DepotPadViewModel = require(ReplicatedStorage.Client.UI.React.Screens.Depot.DepotPadViewModel)
local UIPaperConstants = require(ReplicatedStorage.Client.UI.React.Screens.Paper.UIPaperConstants)
local usePaperLayout = require(ReplicatedStorage.Client.UI.React.Screens.Paper.usePaperLayout)
local ShiftHudViewModel = require(ReplicatedStorage.Client.UI.React.Screens.Shift.ShiftHudViewModel)

local TICK_SECONDS = 0.2

export type DepotPadProps = {
	onDepart: () -> (),
}

-- The viewport shorter side, in px (the engine sizes its Jump button by it; the widget re-renders on the clock tick).
local function shortSide(): number
	local camera = Workspace.CurrentCamera
	local viewport = if camera ~= nil then camera.ViewportSize else Vector2.new(844, 390)
	return math.min(viewport.X, viewport.Y)
end

local function DepotPad(props: DepotPadProps): React.ReactNode
	local snapshot = ReactCharm.useAtom(QueueStore.snapshot)
	local publicPlayers = ReactCharm.useAtom(StateSyncClientStore.publicPlayers)
	local layout: UIPaperConstants.Layout = usePaperLayout()
	local now = useServerClock(TICK_SECONDS)
	local player = Players.LocalPlayer
	local _, pad = QueueSnapshotUtils.padOf(snapshot, player.UserId)
	if pad == nil then
		return nil
	end
	local names: { [number]: string } = {}
	for _, userId in pad.members do
		local member = Players:GetPlayerByUserId(userId)
		if member ~= nil then
			names[userId] = member.DisplayName
		end
	end
	local me = publicPlayers[StateSyncConstants.publicEntryKey(player.UserId)]
	local truck = if me ~= nil then me[DepotConstants.PUBLIC_TRUCK] else nil
	local view = DepotPadViewModel.pad(
		pad,
		player.UserId,
		names,
		if type(truck) == "number" then truck else nil,
		now,
		layout == "phone"
	)
	if view == nil then
		return nil
	end
	return React.createElement(DepotPadPanel, {
		view = view,
		layout = layout,
		onDepart = props.onDepart,
		jump = ShiftHudViewModel.arcFor(shortSide()).jump,
	})
end

return DepotPad
