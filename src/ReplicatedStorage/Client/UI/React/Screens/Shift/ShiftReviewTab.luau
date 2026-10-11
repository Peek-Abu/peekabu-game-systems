--!strict
--[=[
	ShiftReviewTab: the HUD widget that reopens the performance review (registered by ShiftServiceClient). While the
	crew votes and the review scene is off the stack (Escape closed it), a manila "PERFORMANCE REVIEW · OPEN" tab sits
	bottom-centre; pressing it pushes the scene again. Whether it shows is ShiftReviewViewModel.reopen. No logic of its
	own.

	@class ShiftReviewTab
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local ReactCharm = require(ReplicatedStorage.Packages.ReactCharm)
local ShiftConstants = require(ReplicatedStorage.Shared.Features.Shift.Data.ShiftConstants)
local ShiftStore = require(ReplicatedStorage.Client.Features.Shift.State.ShiftStore)
local SceneStack = require(ReplicatedStorage.Client.UI.Scenes.SceneStack)
local UIStore = require(ReplicatedStorage.Client.UI.Scenes.UIStore)
local PaperButton = require(ReplicatedStorage.Client.UI.React.Screens.Paper.PaperButton)
local UIPaperConstants = require(ReplicatedStorage.Client.UI.React.Screens.Paper.UIPaperConstants)
local usePaperLayout = require(ReplicatedStorage.Client.UI.React.Screens.Paper.usePaperLayout)
local ShiftReviewViewModel = require(ReplicatedStorage.Client.UI.React.Screens.Shift.ShiftReviewViewModel)

local e = React.createElement
local useAtom = ReactCharm.useAtom

-- Button size and text per layout (desktop 360x64, phone 260x48: a >= 48 px touch target).
local SIZE: { [UIPaperConstants.Layout]: { size: Vector2, text: number } } = table.freeze({
	desktop = { size = Vector2.new(360, 64), text = 24 },
	phone = { size = Vector2.new(260, 48), text = 16 },
})

local function reopen()
	SceneStack.push(ShiftConstants.REVIEW_SCENE)
end

local function ShiftReviewTab(): React.ReactNode
	local snapshot = useAtom(ShiftStore.snapshot)
	local stack = useAtom(UIStore.sceneStack)
	local layout: UIPaperConstants.Layout = usePaperLayout()
	local text = ShiftReviewViewModel.reopen(snapshot, stack)
	if text == nil then
		return nil
	end
	local look = SIZE[layout]
	return e(PaperButton, {
		text = text,
		variant = "primary",
		onActivated = reopen,
		anchor = Vector2.new(0.5, 1),
		position = UDim2.new(0.5, 0, 1, -UIPaperConstants.SAFE[layout].bottom),
		size = UDim2.fromOffset(look.size.X, look.size.Y),
		textSize = look.text,
	})
end

return ShiftReviewTab
