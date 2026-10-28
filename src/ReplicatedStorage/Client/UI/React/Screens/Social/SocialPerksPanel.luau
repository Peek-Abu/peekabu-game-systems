--!strict
--[=[
	SocialPerksPanel: the hub's social row, under the Today tracker: INVITE FRIENDS (Roblox's invite) and, until the
	one-time perk is paid, JOIN GROUP +100 (the Icey Labs group). Both are callbacks; the hub hands in
	SocialServiceClient's.

	@class SocialPerksPanel
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local SocialConstants = require(ReplicatedStorage.Shared.Features.Social.Data.SocialConstants)
local Button = require(ReplicatedStorage.Client.UI.React.Screens.Toon.ToonButton)

local e = React.createElement

export type Props = {
	phone: boolean,
	-- The group perk is still unpaid.
	showGroup: boolean,
	onInvite: () -> (),
	onJoinGroup: () -> (),
}

local GAP = 8

local function SocialPerksPanel(props: Props): React.ReactNode
	local phone = props.phone
	local textSize = if phone then 13 else 17
	local half = UDim2.new(0.5, -GAP / 2, 1, 0)
	return e("Frame", {
		-- Under the Today tracker (CompanyWorkOrderTracker's hub spot: 840,134 300x132; phone 410,62 220x84).
		Position = if phone then UDim2.fromOffset(410, 154) else UDim2.fromOffset(840, 280),
		Size = if phone then UDim2.fromOffset(220, 38) else UDim2.fromOffset(300, 48),
		BackgroundTransparency = 1,
	}, {
		invite = e(Button, {
			variant = "sky",
			text = "INVITE FRIENDS",
			textSize = textSize,
			icon = "heart",
			layout = "inline",
			small = true,
			size = if props.showGroup then half else UDim2.fromScale(1, 1),
			onActivated = props.onInvite,
		}),
		group = if props.showGroup
			then e(Button, {
				variant = "gleam",
				text = `JOIN GROUP +{SocialConstants.GROUP_GLEAM}`,
				textSize = textSize,
				icon = "gleam",
				layout = "inline",
				small = true,
				position = UDim2.new(0.5, GAP / 2, 0, 0),
				size = half,
				onActivated = props.onJoinGroup,
			})
			else nil,
	})
end

return SocialPerksPanel
