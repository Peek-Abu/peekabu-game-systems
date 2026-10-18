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
local PaperHudFrame = require(ReplicatedStorage.Client.UI.React.Screens.Paper.PaperHudFrame)
local PaperHudScaleViewModel = require(ReplicatedStorage.Client.UI.React.Screens.Paper.PaperHudScaleViewModel)
local UIPaperConstants = require(ReplicatedStorage.Client.UI.React.Screens.Paper.UIPaperConstants)
local usePaperHudScale = require(ReplicatedStorage.Client.UI.React.Screens.Paper.usePaperHudScale)

local useAtom = ReactCharm.useAtom

local function CatchRehiredCard(): React.ReactNode
	local report = useAtom(OccupantCatchStore.report)
	local rehiredAt = useAtom(OccupantCatchStore.rehiredAt)
	local publicPlayers = useAtom(StateSyncClientStore.publicPlayers)
	-- Drawn scaled to the window on desktop (the 760x600 notice is taller than a short window), via PaperHudFrame.
	local hudScale = usePaperHudScale()
	local layout: UIPaperConstants.Layout = hudScale.layout
	local player = Players.LocalPlayer
	local me = publicPlayers[StateSyncConstants.publicEntryKey(player.UserId)]
	-- The clock re-renders it only around a catch (CatchViewModel.rehiredTicks), not four times a second all shift.
	local now = useServerClock(nil, CatchViewModel.rehiredTicks(report, me, rehiredAt, os.clock()))
	local view = CatchViewModel.rehired({
		report = report,
		me = me,
		name = player.DisplayName,
		rehiredAt = rehiredAt,
		nowServer = now,
		nowClock = os.clock(),
		phone = layout == "phone",
	})
	if view == nil then
		return nil
	end
	return React.createElement(PaperHudFrame, {
		scale = hudScale.scale,
		children = {
			panel = React.createElement(CatchRehiredPanel, {
				view = view,
				layout = layout,
				-- The frame starts below the top bar when scaled; the scrim reaches back up over it.
				bleedTop = PaperHudScaleViewModel.bleed(hudScale.scale),
			}),
		},
	})
end

return CatchRehiredCard
