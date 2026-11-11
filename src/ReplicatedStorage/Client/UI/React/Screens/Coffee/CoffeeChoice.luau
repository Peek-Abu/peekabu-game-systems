--!strict
--[=[
	CoffeeChoice: how to pay for Coffee for the crew (owner 11-10). A small cream panel under the coffee button (phone:
	under it at the top right) with the grape title band and its X, the line "2x pay for 30 minutes", and two buttons:
	"99 R$" (lilac; Roblox's purchase prompt) and "250" with the Gleam coin (gleam). The hub's coffee machine shows it centred with its own line. Presentational (exempt; the
	Gleam buy is the server's, checked by the specced CoffeeRules.payGleam).

	@class CoffeeChoice
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local CoffeeConstants = require(ReplicatedStorage.Shared.Features.Coffee.Data.CoffeeConstants)
local Toon = ReplicatedStorage.Client.UI.React.Screens.Toon
local ToonButton = require(Toon.ToonButton)
local ToonPanel = require(Toon.ToonPanel)
local ToonText = require(Toon.ToonText)

local e = React.createElement

export type CoffeeChoiceProps = {
	phone: boolean,
	-- Robux: nil when the product cannot be bought (only Gleam is offered).
	onRobux: (() -> ())?,
	onGleam: () -> (),
	onClose: () -> (),
	-- The player has under 250 Gleam (CoffeeRules.affords): the Gleam button greys out (a press plays the error
	-- sound) and the line says so (CoffeeRules.shortLine). The server checks again either way.
	short: boolean,
	shortLine: string,
	-- Where it sits: by default under the coffee button (the HUD); the hub's coffee machine centres it.
	position: UDim2?,
	anchor: Vector2?,
	-- Its line when the player is not short (default CoffeeConstants.TEXT.choiceLine).
	line: string?,
}

local function CoffeeChoice(props: CoffeeChoiceProps): React.ReactNode
	local phone = props.phone
	local width = if phone then 250 else 360
	local band = if phone then 52 else 66
	local buttonHeight = if phone then 40 else 56
	local textSize = if phone then 16 else 24
	local onRobux = props.onRobux
	local children: { [string]: React.ReactNode } = {
		line = e(ToonText, {
			text = if props.short then props.shortLine else props.line or CoffeeConstants.TEXT.choiceLine,
			textSize = if phone then 15 else 22,
			font = "body",
			align = "center",
			fit = true,
			anchor = Vector2.new(0.5, 0),
			position = UDim2.new(0.5, 0, 0, band + (if phone then 8 else 12)),
			size = UDim2.new(1, -24, 0, if phone then 22 else 30),
		}),
		gleam = e(ToonButton, {
			variant = "gleam",
			layout = "inline",
			icon = "gleam",
			text = string.format(CoffeeConstants.TEXT.gleam, CoffeeConstants.GLEAM_PRICE),
			textSize = textSize,
			small = true,
			anchor = Vector2.new(if onRobux ~= nil then 0 else 0.5, 1),
			position = if onRobux ~= nil then UDim2.new(0.52, 0, 1, -14) else UDim2.new(0.5, 0, 1, -14),
			size = UDim2.new(0.44, 0, 0, buttonHeight),
			disabled = props.short,
			onActivated = props.onGleam,
		}),
	}
	if onRobux ~= nil then
		children.robux = e(ToonButton, {
			variant = "lilac",
			layout = "inline",
			text = CoffeeConstants.TEXT.robux,
			textSize = textSize,
			small = true,
			anchor = Vector2.new(1, 1),
			position = UDim2.new(0.48, 0, 1, -14),
			size = UDim2.new(0.44, 0, 0, buttonHeight),
			onActivated = onRobux,
		})
	end
	return e(ToonPanel, {
		size = Vector2.new(width, if phone then 170 else 220),
		anchor = props.anchor or Vector2.new(1, 0),
		position = props.position or if phone then UDim2.new(1, -14, 0, 138) else UDim2.new(1, -24, 0, 396),
		pop = true,
		header = {
			title = CoffeeConstants.TEXT.choiceTitle,
			height = band,
			titleSize = if phone then 20 else 26,
		},
		onClose = props.onClose,
		zIndex = 6,
		children = children,
	})
end

return CoffeeChoice
