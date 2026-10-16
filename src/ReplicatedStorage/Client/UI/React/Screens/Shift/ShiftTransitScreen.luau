--!strict
--[=[
	ShiftTransitScreen: the transit screen's root, mounted on the Overlay layer by ShiftServiceClient (above the HUD and
	every panel). Draws ShiftTransitPanel from ShiftTransitStore (the cover, the ARRIVED stamp, the slip's lines through
	ShiftTransitViewModel) at the screen's scale (WorldBillboardViewModel.screenScale).

	@class ShiftTransitScreen
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local ReactCharm = require(ReplicatedStorage.Packages.ReactCharm)
local ShiftTransitStore = require(ReplicatedStorage.Client.Features.Shift.State.ShiftTransitStore)
local ShiftTransitPanel = require(ReplicatedStorage.Client.UI.React.Screens.Shift.ShiftTransitPanel)
local ShiftTransitViewModel = require(ReplicatedStorage.Client.UI.React.Screens.Shift.ShiftTransitViewModel)
local usePaperViewport = require(ReplicatedStorage.Client.UI.React.Screens.Paper.usePaperViewport)
local WorldBillboardViewModel = require(ReplicatedStorage.Client.UI.React.Screens.World.WorldBillboardViewModel)

local function ShiftTransitScreen(): React.ReactNode
	local covered = ReactCharm.useAtom(ShiftTransitStore.covered)
	local slip = ReactCharm.useAtom(ShiftTransitStore.slip)
	local arrived = ReactCharm.useAtom(ShiftTransitStore.arrived)
	local snapshot = ReactCharm.useAtom(ShiftTransitStore.snapshot)
	local viewport = usePaperViewport()
	local props: ShiftTransitPanel.ShiftTransitPanelProps = {
		cover = ShiftTransitStore.coverOf(covered, slip),
		view = if covered and slip then ShiftTransitViewModel.slip(snapshot, arrived) else nil,
		scale = WorldBillboardViewModel.screenScale(viewport),
	}
	return React.createElement(ShiftTransitPanel, props)
end

return ShiftTransitScreen
