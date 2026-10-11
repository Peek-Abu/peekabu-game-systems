--!strict
--[=[
	ShiftHud: the Shift HUD widget (registered by ShiftServiceClient). Reads the shift snapshot, every player's public
	entry, the scare beat and the server clock, builds the HUD and crew roster views, and draws ShiftHudPanel while a
	shift runs. The HUD goes dark during the scare beat and while the local player is caught (the CCTV takes the
	screen). On desktop with a keyboard it also passes the key hints row, read from the live Input bindings, and the
	pocket key for the carry panel's caption.

	@class ShiftHud
]=]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local React = require(ReplicatedStorage.Packages.React)
local ReactCharm = require(ReplicatedStorage.Packages.ReactCharm)
local StateSyncConstants = require(ReplicatedStorage.Shared.Features.StateSync.Data.StateSyncConstants)
local InputServiceClient = require(ReplicatedStorage.Client.Features.Input.InputServiceClient)
local OccupantCatchStore = require(ReplicatedStorage.Client.Features.Occupant.State.OccupantCatchStore)
local ShiftStore = require(ReplicatedStorage.Client.Features.Shift.State.ShiftStore)
local StateSyncClientStore = require(ReplicatedStorage.Client.Features.StateSync.State.StateSyncClientStore)
local useServerClock = require(ReplicatedStorage.Client.UI.React.Hooks.useServerClock)
local UIPaperConstants = require(ReplicatedStorage.Client.UI.React.Screens.Paper.UIPaperConstants)
local usePaperLayout = require(ReplicatedStorage.Client.UI.React.Screens.Paper.usePaperLayout)
local ShiftCrewViewModel = require(ReplicatedStorage.Client.UI.React.Screens.Shift.ShiftCrewViewModel)
local ShiftHudPanel = require(ReplicatedStorage.Client.UI.React.Screens.Shift.ShiftHudPanel)
local ShiftHudViewModel = require(ReplicatedStorage.Client.UI.React.Screens.Shift.ShiftHudViewModel)

local e = React.createElement
local useAtom = ReactCharm.useAtom

-- Each hint action's keyboard bindings, read fresh so a rebind shows on the next render.
local function keyBindings(): ShiftHudViewModel.KeyBindings
	local bindings: ShiftHudViewModel.KeyBindings = {}
	for _, action in ShiftHudViewModel.HINT_ACTIONS do
		local found = InputServiceClient:bindingsFor(action)
		bindings[action] = if found ~= nil then found.keyboard else nil
	end
	return bindings
end

local function ShiftHud(): React.ReactNode
	local snapshot = useAtom(ShiftStore.snapshot)
	local publicPlayers = useAtom(StateSyncClientStore.publicPlayers)
	local scaring = useAtom(OccupantCatchStore.scaring)
	local layout: UIPaperConstants.Layout = usePaperLayout()
	local now = useServerClock()
	local player = Players.LocalPlayer
	local me = if player ~= nil then publicPlayers[StateSyncConstants.publicEntryKey(player.UserId)] else nil
	local view = ShiftHudViewModel.hud(snapshot, me, now, ShiftHudViewModel.hidden(me, scaring))
	if view == nil or snapshot == nil then
		return nil
	end
	local names: { [number]: string } = {}
	for _, userId in snapshot.crew do
		local member = Players:GetPlayerByUserId(userId)
		if member ~= nil then
			names[userId] = member.DisplayName
		end
	end
	local roster =
		ShiftCrewViewModel.roster(snapshot.crew, publicPlayers, names, snapshot.truck, snapshot.sub == "clockout", now)
	local bindings = keyBindings()
	return e(ShiftHudPanel, {
		view = view,
		roster = roster,
		layout = layout,
		hints = if ShiftHudViewModel.showHints(layout, UserInputService.KeyboardEnabled)
			then ShiftHudViewModel.keyHints(bindings)
			else nil,
		pocketKey = ShiftHudViewModel.pocketKey(bindings),
	})
end

return ShiftHud
