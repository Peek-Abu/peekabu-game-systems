--!strict
--[=[
	SocialAskCard: the favorite/like ask on a met contract's review (SocialServiceClient decides when). FAVORITE opens
	Roblox's favorite prompt; NOT NOW closes it. Nothing is paid for either (Roblox's rules), and the words never
	promise anything.

	@class SocialAskCard
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local Toon = ReplicatedStorage.Client.UI.React.Screens.Toon
local Surface = require(Toon.ToonSurface)
local Text = require(Toon.ToonText)
local Button = require(Toon.ToonButton)
local Icon = require(Toon.ToonIcon)
local Style = require(Toon.UIToonConstants)

local e = React.createElement

export type Props = {
	phone: boolean,
	onFavorite: () -> (),
	onDismiss: () -> (),
}

local TITLE = "Having fun?"
local BODY = "Tap FAVORITE to find Odd Hours fast. A thumbs up helps us too!"

local function SocialAskCard(props: Props): React.ReactNode
	local phone = props.phone
	local content: { [string]: React.ReactNode } = {
		icon = e(Icon, {
			icon = "heart",
			position = UDim2.fromOffset(-10, -12),
			size = UDim2.fromOffset(if phone then 36 else 48, if phone then 36 else 48),
			rotation = -12,
			zIndex = 3,
		}),
		title = e(Text, {
			text = TITLE,
			font = "body",
			color = Style.COLOR.white,
			textSize = if phone then 18 else 24,
			position = UDim2.fromOffset(if phone then 32 else 44, 6),
			size = UDim2.new(1, if phone then -44 else -56, 0, if phone then 22 else 28),
			fit = true,
		}),
		body = e(Text, {
			text = BODY,
			font = "body",
			color = Style.COLOR.white,
			textSize = if phone then 13 else 17,
			wrapped = true,
			fit = true,
			position = UDim2.fromOffset(12, if phone then 30 else 38),
			size = UDim2.new(1, -24, 0, if phone then 34 else 44),
		}),
		favorite = e(Button, {
			variant = "gleam",
			text = "FAVORITE",
			textSize = if phone then 14 else 18,
			icon = "heart",
			layout = "inline",
			small = true,
			position = UDim2.new(0, 12, 1, if phone then -40 else -52),
			size = UDim2.new(0.55, -16, 0, if phone then 32 else 40),
			onActivated = props.onFavorite,
		}),
		later = e(Button, {
			variant = "secondary",
			text = "NOT NOW",
			textSize = if phone then 13 else 16,
			small = true,
			sound = "back",
			position = UDim2.new(0.55, 4, 1, if phone then -40 else -52),
			size = UDim2.new(0.45, -16, 0, if phone then 32 else 40),
			onActivated = props.onDismiss,
		}),
	}
	return e("Frame", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, if phone then -12 else -24, 0, if phone then 12 else 24),
		Size = if phone then UDim2.fromOffset(260, 120) else UDim2.fromOffset(360, 160),
		BackgroundTransparency = 1,
		ZIndex = 50,
	}, {
		card = e(Surface, {
			hue = "grape",
			pattern = "bubbles",
			radius = 16,
			size = UDim2.fromScale(1, 1),
			children = content,
		}),
	})
end

return SocialAskCard
