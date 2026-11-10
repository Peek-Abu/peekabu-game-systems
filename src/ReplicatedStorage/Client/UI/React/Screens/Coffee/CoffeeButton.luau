--!strict
--[=[
	CoffeeButton: Coffee for the crew in the shift HUD (owner 11-08; 30 minutes, owner 11-10). Small and quiet, right
	side under the Today tracker (phone: top right): a lilac "2x PAY" button while coffee is offered
	(CoffeeRules.offered); while someone's coffee runs, a gold badge with a sparkle and the countdown,
	"2x PAY · ICE · 24:10" (CoffeeRules.badgeText). Either press opens the 99 R$ / 250 Gleam choice (CoffeeChoice;
	buying while coffee runs adds 30 minutes). No pulsing, no unasked pop-ups. Presentational (exempt; what shows is the specced CoffeeRules, the press is CoffeeServiceClient's).

	@class CoffeeButton
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local CoffeeConstants = require(ReplicatedStorage.Shared.Features.Coffee.Data.CoffeeConstants)
local Toon = ReplicatedStorage.Client.UI.React.Screens.Toon
local ToonButton = require(Toon.ToonButton)
local ToonPill = require(Toon.ToonPill)
local ToonSparkle = require(Toon.ToonSparkle)

local e = React.createElement

export type CoffeeButtonProps = {
	phone: boolean,
	-- Coffee is offered (show the buy button), or the running coffee's badge text (the countdown).
	offered: boolean,
	badge: string?,
	-- Opens the 99 R$ / 250 Gleam choice; nil during training (the badge still shows).
	onPress: (() -> ())?,
}

local function CoffeeButton(props: CoffeeButtonProps): React.ReactNode
	local phone = props.phone
	local position = if phone then UDim2.new(1, -14, 0, 92) else UDim2.new(1, -24, 0, 330)
	local anchor = Vector2.new(1, 0)
	local badge = props.badge
	local onPress = props.onPress
	if badge ~= nil then
		return e("Frame", {
			AnchorPoint = anchor,
			Position = position,
			Size = if phone then UDim2.fromOffset(230, 40) else UDim2.fromOffset(380, 56),
			BackgroundTransparency = 1,
		}, {
			badge = e(ToonPill, {
				text = badge,
				meaning = "gold",
				icon = "credits",
				textSize = if phone then 14 else 21,
				small = phone,
				size = UDim2.fromScale(1, 1),
			}),
			sparkles = e(ToonSparkle, {
				spots = {
					{ position = UDim2.fromOffset(if phone then 8 else 14, -6), size = if phone then 12 else 20 },
					{ position = UDim2.new(1, -18, 0, -8), size = if phone then 10 else 16 },
				},
				zIndex = 4,
			}),
			-- The whole badge buys 30 more minutes.
			press = if onPress ~= nil
				then e("TextButton", {
					Size = UDim2.fromScale(1, 1),
					BackgroundTransparency = 1,
					Text = "",
					ZIndex = 5,
					[React.Event.Activated] = onPress,
				})
				else nil,
		})
	end
	if not props.offered or onPress == nil then
		return nil
	end
	return e(ToonButton, {
		variant = "lilac",
		layout = "inline",
		icon = "credits",
		text = CoffeeConstants.TEXT.button,
		textSize = if phone then 14 else 22,
		small = true,
		anchor = anchor,
		position = position,
		size = if phone then UDim2.fromOffset(130, 38) else UDim2.fromOffset(200, 54),
		onActivated = onPress,
	})
end

return CoffeeButton
