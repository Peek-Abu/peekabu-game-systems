--!strict
--[=[
	ShiftHudPanel: the approved Shift HUD (Figma 1a normal, 1b quota met, 1c overtime + clock-out) on the paperwork
	look: the clearance folder and finder's fee plate, the clipped crew roster, the punch-clock time card, the carry
	panel and, while the crew clocks out, the stapled clock-out slip under the time card. Full-screen and transparent;
	each piece places itself at its Figma position. Presentational: it draws the views it is given (desktop; the phone
	layout is Task 10 and draws nothing until then).

	@class ShiftHudPanel
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local UIPaperConstants = require(ReplicatedStorage.Client.UI.React.Screens.Paper.UIPaperConstants)
local ShiftCarryPanel = require(ReplicatedStorage.Client.UI.React.Screens.Shift.ShiftCarryPanel)
local ShiftClearancePanel = require(ReplicatedStorage.Client.UI.React.Screens.Shift.ShiftClearancePanel)
local ShiftClockOutSlip = require(ReplicatedStorage.Client.UI.React.Screens.Shift.ShiftClockOutSlip)
local ShiftCrewRoster = require(ReplicatedStorage.Client.UI.React.Screens.Shift.ShiftCrewRoster)
local ShiftCrewViewModel = require(ReplicatedStorage.Client.UI.React.Screens.Shift.ShiftCrewViewModel)
local ShiftHudViewModel = require(ReplicatedStorage.Client.UI.React.Screens.Shift.ShiftHudViewModel)
local ShiftTimeCard = require(ReplicatedStorage.Client.UI.React.Screens.Shift.ShiftTimeCard)

local e = React.createElement

export type ShiftHudPanelProps = {
	view: ShiftHudViewModel.HudView,
	roster: ShiftCrewViewModel.RosterView?,
	layout: UIPaperConstants.Layout,
}

local function ShiftHudPanel(props: ShiftHudPanelProps): React.ReactNode
	if props.layout == "phone" then
		return nil
	end
	local view = props.view
	local layout: UIPaperConstants.Layout = props.layout
	local roster = props.roster
	local clockOut = view.clockOut
	return e("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
	}, {
		clearance = e(ShiftClearancePanel, { view = view, layout = layout }),
		roster = if roster ~= nil then e(ShiftCrewRoster, { roster = roster, layout = layout }) else nil,
		timeCard = e(ShiftTimeCard, { view = view, layout = layout }),
		carry = e(ShiftCarryPanel, { view = view, layout = layout }),
		clockOut = if clockOut ~= nil
			then e(ShiftClockOutSlip, { left = clockOut, truck = view.truck, layout = layout })
			else nil,
	})
end

return ShiftHudPanel
