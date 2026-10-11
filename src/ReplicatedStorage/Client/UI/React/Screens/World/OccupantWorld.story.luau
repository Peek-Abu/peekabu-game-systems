--!strict
--[=[
	OccupantWorld.story: Mr. Harlow's world signs (Figma World UI 2b, W7 and W8) over the dark office, in Studio's edit
	mode (UI Labs): both cue discs at their design size, and the memo with `Line` typed out (shouted when it ends with
	"!" or is in capitals). Change `Line`, or flip `Retype`, to type it again.

	@class OccupantWorld.story
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local ReactRoblox = require(ReplicatedStorage.Packages.ReactRoblox)
local UILabs = require(ReplicatedStorage.DevPackages.UILabs)
local OccupantConstants = require(ReplicatedStorage.Shared.Features.Occupant.Data.OccupantConstants)
local UIPaperConstants = require(ReplicatedStorage.Client.UI.React.Screens.Paper.UIPaperConstants)
local OccupantCueDisc = require(ReplicatedStorage.Client.UI.React.Screens.World.OccupantCueDisc)
local OccupantMemo = require(ReplicatedStorage.Client.UI.React.Screens.World.OccupantMemo)
local OccupantWorldViewModel = require(ReplicatedStorage.Client.UI.React.Screens.World.OccupantWorldViewModel)
local WorldBillboard = require(ReplicatedStorage.Client.UI.React.Screens.World.WorldBillboard)

local e = React.createElement

local function cue(order: number, glyph: string): React.ReactNode
	local view = OccupantWorldViewModel.cue(glyph)
	if view == nil then
		return nil
	end
	local size = OccupantConstants.CUE_PX
	return e("Frame", {
		LayoutOrder = order,
		Size = UDim2.fromOffset(size.X, size.Y),
		BackgroundTransparency = 1,
	}, {
		billboard = e(
			WorldBillboard,
			{ design = size, sizing = "studs" },
			{ cue = e(OccupantCueDisc, { view = view }) }
		),
	})
end

return UILabs.CreateReactStory({
	react = React,
	reactRoblox = ReactRoblox,
	controls = {
		Line = "Those are COMPANY ASSETS.",
		Retype = false,
	},
}, function(props)
	local line: string = props.controls.Line
	local memo = OccupantWorldViewModel.memo(line)
	local size = OccupantConstants.MEMO_PX
	local memoChildren: { [string]: React.ReactNode } = {}
	if memo ~= nil then
		-- Keyed by Retype, so flipping it remounts the memo and types the same line again.
		memoChildren[if props.controls.Retype then "memoA" else "memoB"] = e(
			WorldBillboard,
			{ design = size, sizing = "pixels" },
			{ memo = e(OccupantMemo, { view = memo }) }
		)
	end
	return e("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = UIPaperConstants.COLOR.office,
		BorderSizePixel = 0,
	}, {
		padding = e("UIPadding", {
			PaddingLeft = UDim.new(0, 60),
			PaddingTop = UDim.new(0, 60),
		}),
		layout = e("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			VerticalAlignment = Enum.VerticalAlignment.Top,
			Padding = UDim.new(0, 60),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
		curious = cue(1, "?"),
		spotted = cue(2, "!"),
		memo = e("Frame", {
			LayoutOrder = 3,
			Size = UDim2.fromOffset(size.X, size.Y),
			BackgroundTransparency = 1,
		}, memoChildren),
	})
end)
