--!strict
--[=[
	CatchRehiredCard: the "Rehired." HUD widget (registered by OccupantServiceClient). Reads the incident report, when the
	rehire notice arrived (os.clock), the local public entry (its `caughtUntil`) and the server clock, and draws
	CatchRehiredPanel while CatchViewModel.rehired says so: from just before the respawn until a few seconds after it.
	The server clock's tick re-renders it, and os.clock() is sampled on each render for the hold after the respawn.

	@class CatchRehiredCard
]=]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local ReactCharm = require(ReplicatedStorage.Packages.ReactCharm)
local StateSyncConstants = require(ReplicatedStorage.Shared.Features.StateSync.Data.StateSyncConstants)
local OccupantCatchStore = require(ReplicatedStorage.Client.Features.Occupant.State.OccupantCatchStore)
local StateSyncClientStore = require(ReplicatedStorage.Client.Features.StateSync.State.StateSyncClientStore)
local useServerClock = require(ReplicatedStorage.Client.UI.React.Hooks.useServerClock)
local CatchRehiredPanel = require(ReplicatedStorage.Client.UI.React.Screens.Catch.CatchRehiredPanel)
local CatchViewModel = require(ReplicatedStorage.Client.UI.React.Screens.Catch.CatchViewModel)
local UIPaperConstants = require(ReplicatedStorage.Client.UI.React.Screens.Paper.UIPaperConstants)
local usePaperLayout = require(ReplicatedStorage.Client.UI.React.Screens.Paper.usePaperLayout)

local useAtom = ReactCharm.useAtom

local function CatchRehiredCard(): React.ReactNode
	local report = useAtom(OccupantCatchStore.report)
	local rehiredAt = useAtom(OccupantCatchStore.rehiredAt)
	local publicPlayers = useAtom(StateSyncClientStore.publicPlayers)
	local layout: UIPaperConstants.Layout = usePaperLayout()
	local now = useServerClock()
	local player = Players.LocalPlayer
	local view = CatchViewModel.rehired({
		report = report,
		me = publicPlayers[StateSyncConstants.publicEntryKey(player.UserId)],
		name = player.DisplayName,
		rehiredAt = rehiredAt,
		nowServer = now,
		nowClock = os.clock(),
		phone = layout == "phone",
	})
	if view == nil then
		return nil
	end
	return React.createElement(CatchRehiredPanel, { view = view, layout = layout })
end

return CatchRehiredCard
