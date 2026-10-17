--!strict
--[=[
	DepotPad: the truck queue pad HUD widget (registered by DepotServiceClient). While the local player is aboard a pad
	it reads the queue snapshot, their public truck number, the server clock and the device layout, and draws
	the hub's Next shift card (DepotNextShiftCard) in its aboard state: the truck's countdown, a seat per place and GO!
	to depart now (which replaces the base placeholder pad panel). Names are the crew display names (the view model names an unknown member "Crew"); the card only
	displays, the server decides who is aboard and when the truck leaves. Depart now is the `onDepart` the service
	passes in (components never talk to the server). It draws only where DepotPadViewModel.shown allows: in the depot
	hub (the shift snapshot), not behind the load screen (ShiftTransitStore.covered) and not once the drive card is up
	(DepotStore.card).

	@class DepotPad
]=]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local ReactCharm = require(ReplicatedStorage.Packages.ReactCharm)
local DepotConstants = require(ReplicatedStorage.Shared.Features.Depot.Data.DepotConstants)
local QueueSnapshotUtils = require(ReplicatedStorage.Shared.Features.Queue.Utils.QueueSnapshotUtils)
local StateSyncConstants = require(ReplicatedStorage.Shared.Features.StateSync.Data.StateSyncConstants)
local DepotStore = require(ReplicatedStorage.Client.Features.Depot.State.DepotStore)
local QueueStore = require(ReplicatedStorage.Client.Features.Queue.State.QueueStore)
local ShiftStore = require(ReplicatedStorage.Client.Features.Shift.State.ShiftStore)
local ShiftTransitStore = require(ReplicatedStorage.Client.Features.Shift.State.ShiftTransitStore)
local StateSyncClientStore = require(ReplicatedStorage.Client.Features.StateSync.State.StateSyncClientStore)
local useServerClock = require(ReplicatedStorage.Client.UI.React.Hooks.useServerClock)
local DepotNextShiftCard = require(ReplicatedStorage.Client.UI.React.Screens.Depot.DepotNextShiftCard)
local DepotPadViewModel = require(ReplicatedStorage.Client.UI.React.Screens.Depot.DepotPadViewModel)
local PaperHudFrame = require(ReplicatedStorage.Client.UI.React.Screens.Paper.PaperHudFrame)
local usePaperHudScale = require(ReplicatedStorage.Client.UI.React.Screens.Paper.usePaperHudScale)

local TICK_SECONDS = 0.2

export type DepotPadProps = {
	onDepart: () -> (),
}

local function DepotPad(props: DepotPadProps): React.ReactNode
	local snapshot = ReactCharm.useAtom(QueueStore.snapshot)
	local publicPlayers = ReactCharm.useAtom(StateSyncClientStore.publicPlayers)
	local shift = ReactCharm.useAtom(ShiftStore.snapshot)
	local covered = ReactCharm.useAtom(ShiftTransitStore.covered)
	local card = ReactCharm.useAtom(DepotStore.card)
	-- Drawn scaled to the window on desktop, with the rest of the HUD (PaperHudFrame).
	local hudScale = usePaperHudScale()
	local phone = hudScale.layout == "phone"
	local now = useServerClock(TICK_SECONDS)
	local player = Players.LocalPlayer
	local _, pad = QueueSnapshotUtils.padOf(snapshot, player.UserId)
	if
		pad == nil or not DepotPadViewModel.shown(shift, player.UserId, covered, if card ~= nil then card.kind else nil)
	then
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
	local view =
		DepotPadViewModel.pad(pad, player.UserId, names, if type(truck) == "number" then truck else nil, now, phone)
	if view == nil then
		return nil
	end
	return React.createElement(PaperHudFrame, {
		scale = hudScale.scale,
		children = {
			panel = React.createElement(DepotNextShiftCard, {
				cta = DepotPadViewModel.cta(view, if type(truck) == "number" then truck else nil),
				phone = phone,
				onGo = props.onDepart,
			}),
		},
	})
end

return DepotPad
