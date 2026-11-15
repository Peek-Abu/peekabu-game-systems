--!strict
--[=[
	ShiftTransitScreen: the transit screen's root, mounted on the Overlay layer by ShiftServiceClient (above the HUD and
	every panel). Draws ShiftTransitPanel from ShiftTransitStore (the cover, the welcome card on a first join to the hub, the ARRIVED stamp, the loading bar's progress, the slip's lines through
	ShiftTransitViewModel; while leaving on a teleport, the trip's slip or the homeward card) at the screen's scale (ShiftTransitViewModel.fit).

	@class ShiftTransitScreen
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local ReactCharm = require(ReplicatedStorage.Packages.ReactCharm)
local ShiftTransitStore = require(ReplicatedStorage.Client.Features.Shift.State.ShiftTransitStore)
local UIPreloadStore = require(ReplicatedStorage.Client.Features.UI.State.UIPreloadStore)
local ShiftTransitPanel = require(ReplicatedStorage.Client.UI.React.Screens.Shift.ShiftTransitPanel)
local ShiftTransitViewModel = require(ReplicatedStorage.Client.UI.React.Screens.Shift.ShiftTransitViewModel)
local usePaperViewport = require(ReplicatedStorage.Client.UI.React.Screens.Paper.usePaperViewport)

local function ShiftTransitScreen(): React.ReactNode
	local covered = ReactCharm.useAtom(ShiftTransitStore.covered)
	local slip = ReactCharm.useAtom(ShiftTransitStore.slip)
	local welcome = ReactCharm.useAtom(ShiftTransitStore.welcome)
	local mascot = ReactCharm.useAtom(UIPreloadStore.screenReady)
	local arrived = ReactCharm.useAtom(ShiftTransitStore.arrived)
	local snapshot = ReactCharm.useAtom(ShiftTransitStore.snapshot)
	local progress = ReactCharm.useAtom(ShiftTransitStore.progress)
	local fadeSeconds = ReactCharm.useAtom(ShiftTransitStore.fadeSeconds)
	local leaving = ReactCharm.useAtom(ShiftTransitStore.leaving)
	local viewport = usePaperViewport()
	local view: ShiftTransitViewModel.SlipView? = nil
	local greeting: ShiftTransitViewModel.WelcomeView? = nil
	if covered and leaving ~= nil then
		-- Leaving on a teleport: the arrival's own card, so the place being left hands over to it seamlessly.
		if leaving.home then
			greeting = ShiftTransitViewModel.homeward()
		else
			view = ShiftTransitViewModel.leavingSlip(leaving)
		end
	elseif covered and slip then
		view = ShiftTransitViewModel.slip(snapshot, arrived)
	elseif covered and welcome then
		greeting = ShiftTransitViewModel.welcome(arrived)
	end
	local props: ShiftTransitPanel.ShiftTransitPanelProps = {
		cover = ShiftTransitStore.coverOf(covered, slip, welcome),
		view = view,
		welcome = greeting,
		mascot = mascot,
		scale = ShiftTransitViewModel.fit(viewport),
		progress = progress,
		fadeSeconds = fadeSeconds,
	}
	return React.createElement(ShiftTransitPanel, props)
end

return ShiftTransitScreen
