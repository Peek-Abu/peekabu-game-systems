--!strict
--[=[
	CoinCounter: one container's coin balance — the icon and "JAKU | 2,000" readout above a plate, off
	the authored `Banker`'s `CoinCounter`.

	One per side, because the whole point of the bank screen is that there are two balances and moving
	between them is the task. A single shared readout would hide exactly the number the player is acting
	on.

	The authored counter also carries an `AddCurrency` label ("+ 2,000") — a transient gain flash. It is
	NOT built here: nothing drives it, and a number that only ever appears during an animation that does
	not exist yet is dead art. It belongs with a currency-change feed, not with a balance readout.

	Presentational: the amount is a prop.

	@class CoinCounter
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local Tokens = require(ReplicatedStorage.Client.UI.React.Tokens)
local UIAssets = require(ReplicatedStorage.Client.Features.UI.Data.UIAssets)
local CurrencyConstants = require(ReplicatedStorage.Shared.Features.Currency.Data.CurrencyConstants)
local CurrencyUtils = require(ReplicatedStorage.Shared.Features.Currency.Utils.CurrencyUtils)

local e = React.createElement

-- Inside the counter, off the authored rects.
local ICON_POSITION = UDim2.fromScale(0.068, 0.184)
local ICON_SIZE = UDim2.fromScale(0.166, 0.713)
local LABEL_POSITION = UDim2.fromScale(0.282, 0.172)
local LABEL_SIZE = UDim2.fromScale(0.594, 0.741)
local LABEL_COLOR = Color3.fromRGB(255, 233, 219)

export type CoinCounterProps = {
	currencyType: CurrencyConstants.CurrencyType,
	amount: number,
	position: UDim2,
	size: UDim2,
	-- The rung this component sits on in the CALLER's screen-level ladder. Passed rather than defaulted:
	-- an unset ZIndex is 1, which is the same rung the screens give their full-screen vignette, and React
	-- children come from a DICTIONARY whose order is undefined — so which of the two drew on top was left
	-- to a hash walk (the hazard ItemDetail already documents having been bitten by).
	zIndex: number?,
}

--[=[
	@param props CoinCounterProps
	@return React.ReactNode
]=]
local function CoinCounter(props: CoinCounterProps): React.ReactNode
	local definition = CurrencyConstants.getCurrencyDefinition(props.currencyType)
	return e("Frame", {
		Position = props.position,
		Size = props.size,
		BackgroundTransparency = 1,
		ZIndex = props.zIndex,
	}, {
		icon = e("ImageLabel", {
			Position = ICON_POSITION,
			Size = ICON_SIZE,
			BackgroundTransparency = 1,
			Image = UIAssets.bank.coinIcon,
			ScaleType = Enum.ScaleType.Fit,
		}),
		label = e("TextLabel", {
			Position = LABEL_POSITION,
			Size = LABEL_SIZE,
			BackgroundTransparency = 1,
			Font = Tokens.font.bold,
			TextScaled = true,
			TextColor3 = LABEL_COLOR,
			TextXAlignment = Enum.TextXAlignment.Left,
			-- Grouping is CurrencyUtils.formatCurrency's job, not this component's: it already does the
			-- reverse-group-threes trick, it is specced, and a second copy here is exactly the drift this
			-- port exists to remove. Called WITHOUT a currencyType, because that appends the emoji icon
			-- and the authored readout draws the coin as a sprite beside the text instead.
			Text = `{string.upper(definition.name)} | {CurrencyUtils.formatCurrency(props.amount)}`,
		}),
	})
end

return CoinCounter
