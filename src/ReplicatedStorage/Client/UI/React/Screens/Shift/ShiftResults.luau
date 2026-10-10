--!strict
--[=[
	ShiftResults: the results widget (registered by ShiftServiceClient). While the crew votes it draws
	ShiftResultsPanel; a click writes ShiftStore.myVote, which ShiftServiceClient sends (components never
	talk to the server).

	@class ShiftResults
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local ReactCharm = require(ReplicatedStorage.Packages.ReactCharm)
local ShiftStore = require(ReplicatedStorage.Client.Features.Shift.State.ShiftStore)
local useServerClock = require(ReplicatedStorage.Client.UI.React.Hooks.useServerClock)
local ShiftHudViewModel = require(ReplicatedStorage.Client.UI.React.Screens.Shift.ShiftHudViewModel)
local ShiftResultsPanel = require(ReplicatedStorage.Client.UI.React.Screens.Shift.ShiftResultsPanel)

local e = React.createElement
local useAtom = ReactCharm.useAtom

local function ShiftResults(): React.ReactNode
	local snapshot = useAtom(ShiftStore.snapshot)
	local myVote = useAtom(ShiftStore.myVote)
	local now = useServerClock()
	local view = ShiftHudViewModel.results(snapshot, now)
	if view == nil then
		return nil
	end
	return e(ShiftResultsPanel, {
		view = view,
		myVote = myVote,
		onVote = function(choice)
			ShiftStore.myVote(choice)
		end,
	})
end

return ShiftResults
