--!strict
--[=[
	ShiftReviewScreen: the performance review scene's screen (ShiftScene). Reads the snapshot and the local player's
	vote from ShiftStore, the device layout, the server clock and the viewport, and draws ShiftReviewPanel from
	ShiftReviewViewModel, scaled to the viewport. A vote writes ShiftStore.myVote, which ShiftServiceClient sends
	(components never talk to the server). No logic of its own.

	@class ShiftReviewScreen
]=]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local React = require(ReplicatedStorage.Packages.React)
local ReactCharm = require(ReplicatedStorage.Packages.ReactCharm)
local ShiftTypes = require(ReplicatedStorage.Shared.Features.Shift.Data.ShiftTypes)
local ShiftStore = require(ReplicatedStorage.Client.Features.Shift.State.ShiftStore)
local useServerClock = require(ReplicatedStorage.Client.UI.React.Hooks.useServerClock)
local UIPaperConstants = require(ReplicatedStorage.Client.UI.React.Screens.Paper.UIPaperConstants)
local usePaperLayout = require(ReplicatedStorage.Client.UI.React.Screens.Paper.usePaperLayout)
local ShiftReviewPanel = require(ReplicatedStorage.Client.UI.React.Screens.Shift.ShiftReviewPanel)
local ShiftReviewViewModel = require(ReplicatedStorage.Client.UI.React.Screens.Shift.ShiftReviewViewModel)

local e = React.createElement
local useAtom = ReactCharm.useAtom

local function readViewport(): Vector2
	local camera = Workspace.CurrentCamera
	return if camera ~= nil then camera.ViewportSize else Vector2.new(1920, 1080)
end

local function useViewport(): Vector2
	local viewport, setViewport = React.useState(readViewport)
	React.useEffect(function(): () -> ()
		local camera = Workspace.CurrentCamera
		if camera == nil then
			return function() end
		end
		local connection = camera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
			setViewport(readViewport())
		end)
		return function()
			connection:Disconnect()
		end
	end, {})
	return viewport
end

local function vote(choice: ShiftTypes.Vote)
	ShiftStore.myVote(choice)
end

local function ShiftReviewScreen(): React.ReactNode
	local snapshot = useAtom(ShiftStore.snapshot)
	local myVote = useAtom(ShiftStore.myVote)
	local layout: UIPaperConstants.Layout = usePaperLayout()
	local now = useServerClock()
	local viewport = useViewport()
	local phone = layout == "phone"
	local view = ShiftReviewViewModel.review(snapshot, myVote, Players.LocalPlayer.UserId, now, phone)
	if view == nil then
		return nil
	end
	local props: ShiftReviewPanel.ShiftReviewPanelProps = {
		view = view,
		layout = layout,
		scale = ShiftReviewViewModel.fit(viewport, phone),
		onVote = vote,
	}
	return e(ShiftReviewPanel, props)
end

return ShiftReviewScreen
