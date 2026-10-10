--!strict
--[=[
	ShiftHud: the Shift HUD widget (registered by ShiftServiceClient). Reads the shift snapshot, the local
	player's public entry and the server clock, and draws ShiftHudPanel while a shift runs.

	@class ShiftHud
]=]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local ReactCharm = require(ReplicatedStorage.Packages.ReactCharm)
local StateSyncConstants = require(ReplicatedStorage.Shared.Features.StateSync.Data.StateSyncConstants)
local ShiftStore = require(ReplicatedStorage.Client.Features.Shift.State.ShiftStore)
local StateSyncClientStore = require(ReplicatedStorage.Client.Features.StateSync.State.StateSyncClientStore)
local useServerClock = require(ReplicatedStorage.Client.UI.React.Hooks.useServerClock)
local ShiftHudPanel = require(ReplicatedStorage.Client.UI.React.Screens.Shift.ShiftHudPanel)
local ShiftHudViewModel = require(ReplicatedStorage.Client.UI.React.Screens.Shift.ShiftHudViewModel)

local e = React.createElement
local useAtom = ReactCharm.useAtom

local function ShiftHud(): React.ReactNode
	local snapshot = useAtom(ShiftStore.snapshot)
	local publicPlayers = useAtom(StateSyncClientStore.publicPlayers)
	local now = useServerClock()
	local player = Players.LocalPlayer
	local me = if player ~= nil then publicPlayers[StateSyncConstants.publicEntryKey(player.UserId)] else nil
	local view = ShiftHudViewModel.hud(snapshot, me, now)
	if view == nil then
		return nil
	end
	return e(ShiftHudPanel, { view = view })
end

return ShiftHud
