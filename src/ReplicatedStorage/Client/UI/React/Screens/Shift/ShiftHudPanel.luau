--!strict
--[=[
	ShiftHudPanel: the approved Shift HUD (Figma 1a normal, 1b quota met, 1c overtime + clock-out) on the paperwork
	look: the clearance folder and finder's fee plate, the clipped crew roster, the punch-clock time card and, while the crew clocks out, the stapled clock-out slip under the time card. Full-screen and transparent;
	each piece places itself at its Figma position, anchored to its screen edge. On phone (Figma 1d, 1e; 844x390) every
	piece draws its compact form inside the phone safe area, clear of the thumbstick (bottom left) and the Jump button
	(bottom right); the action buttons are ShiftMobileButtons, a separate HUD widget. The desktop key hints row
	(ShiftKeyHints) is drawn when `hints` is given. The live HUD is ShiftCompactHudPanel (its hotbar is ShiftHotbar);
	this full-size layout is kept for its pieces. Presentational: it draws the views it is given.

	@class ShiftHudPanel
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local UIPaperConstants = require(ReplicatedStorage.Client.UI.React.Screens.Paper.UIPaperConstants)
local ShiftClearancePanel = require(ReplicatedStorage.Client.UI.React.Screens.Shift.ShiftClearancePanel)
local ShiftClockOutSlip = require(ReplicatedStorage.Client.UI.React.Screens.Shift.ShiftClockOutSlip)
local ShiftCrewRoster = require(ReplicatedStorage.Client.UI.React.Screens.Shift.ShiftCrewRoster)
local ShiftCrewViewModel = require(ReplicatedStorage.Client.UI.React.Screens.Shift.ShiftCrewViewModel)
local ShiftHudViewModel = require(ReplicatedStorage.Client.UI.React.Screens.Shift.ShiftHudViewModel)
local ShiftKeyHints = require(ReplicatedStorage.Client.UI.React.Screens.Shift.ShiftKeyHints)
local ShiftTimeCard = require(ReplicatedStorage.Client.UI.React.Screens.Shift.ShiftTimeCard)

local e = React.createElement

export type ShiftHudPanelProps = {
	view: ShiftHudViewModel.HudView,
	roster: ShiftCrewViewModel.RosterView?,
	layout: UIPaperConstants.Layout,
	-- The desktop key hints row; nil draws none.
	hints: { ShiftHudViewModel.HintView }?,
	-- How far the centred pieces move right of the left column (ShiftHudViewModel.centreShift); 0 when nil.
	centreShift: number?,
}

local function ShiftHudPanel(props: ShiftHudPanelProps): React.ReactNode
	local view = props.view
	local layout: UIPaperConstants.Layout = props.layout
	local roster = props.roster
	local clockOut = view.clockOut
	local hints = props.hints
	return e("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
	}, {
		clearance = e(ShiftClearancePanel, { view = view, layout = layout }),
		roster = if roster ~= nil then e(ShiftCrewRoster, { roster = roster, layout = layout }) else nil,
		timeCard = e(ShiftTimeCard, { view = view, layout = layout, centreShift = props.centreShift }),
		clockOut = if clockOut ~= nil
			then e(ShiftClockOutSlip, {
				left = clockOut,
				truck = view.truck,
				layout = layout,
				centreShift = props.centreShift,
			})
			else nil,
		hints = if hints ~= nil then e(ShiftKeyHints, { hints = hints }) else nil,
	})
end

return ShiftHudPanel
