--!strict
--[=[
	CoffeeButton: Coffee for the crew in the shift HUD (owner 11-08). Small and quiet, right side under the Today
	tracker (phone: top right): a lilac "2x PAY" button while coffee is offered (CoffeeRules.offered), "FREE 2x PAY"
	when the player has a saved coffee; once someone bought it, a gold "2x PAY · <buyer>" badge with a sparkle for the
	rest of the shift. No pulsing, no pop-ups. Presentational (exempt; what shows is the specced CoffeeRules, the press
	is CoffeeServiceClient's).

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
	-- Coffee is offered (show the button), the player has a saved one (FREE), or who bought this shift's (the badge).
	offered: boolean,
	free: boolean,
	buyer: string?,
	onPress: () -> (),
}

local function CoffeeButton(props: CoffeeButtonProps): React.ReactNode
	local phone = props.phone
	local position = if phone then UDim2.new(1, -14, 0, 92) else UDim2.new(1, -24, 0, 330)
	local anchor = Vector2.new(1, 0)
	local buyer = props.buyer
	if buyer ~= nil then
		return e("Frame", {
			AnchorPoint = anchor,
			Position = position,
			Size = if phone then UDim2.fromOffset(170, 40) else UDim2.fromOffset(300, 56),
			BackgroundTransparency = 1,
		}, {
			badge = e(ToonPill, {
				text = `{CoffeeConstants.TEXT.badge} · {buyer}`,
				meaning = "gold",
				icon = "credits",
				textSize = if phone then 15 else 22,
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
		})
	end
	if not props.offered then
		return nil
	end
	local text = if props.free
		then `{CoffeeConstants.TEXT.free} {CoffeeConstants.TEXT.button}`
		else CoffeeConstants.TEXT.button
	return e(ToonButton, {
		variant = if props.free then "gleam" else "lilac",
		layout = "inline",
		icon = "credits",
		text = text,
		textSize = if phone then 14 else 22,
		small = true,
		anchor = anchor,
		position = position,
		size = if phone then UDim2.fromOffset(130, 38) else UDim2.fromOffset(200, 54),
		onActivated = props.onPress,
	})
end

return CoffeeButton
