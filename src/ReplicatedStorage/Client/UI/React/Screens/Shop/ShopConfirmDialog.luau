--!strict
--[=[
	ShopConfirmDialog: the Shop's Yes / No question before a buy (ShopScreen, over a product page): a cream panel that
	pops in over a back that dims (M6), the question (ShopViewModel.product's `confirm`), Yes (sends
	ShopServiceClient:requestBuy with the Gleam the player said yes to and the price they saw; nothing in a preview)
	and No. Split out of ShopScreen. Presentational (exempt).

	@class ShopConfirmDialog
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local ShopPriceRules = require(ReplicatedStorage.Shared.Features.Shop.Rules.ShopPriceRules)
local ShopTypes = require(ReplicatedStorage.Shared.Features.Shop.Data.ShopTypes)
local ShopServiceClient = require(ReplicatedStorage.Client.Features.Shop.ShopServiceClient)
local Toon = ReplicatedStorage.Client.UI.React.Screens.Toon
local ToonButton = require(Toon.ToonButton)
local ToonMotionViewModel = require(Toon.ToonMotionViewModel)
local ToonSurface = require(Toon.ToonSurface)
local ToonText = require(Toon.ToonText)
local UIToonConstants = require(Toon.UIToonConstants)
local ShopScreenBlocks = require(script.Parent.ShopScreenBlocks)
local VM = require(script.Parent.ShopViewModel)

local e = React.createElement

local COLOR = UIToonConstants.COLOR
local MOTION = UIToonConstants.MOTION
-- How dark the back gets behind the Yes / No question (its fill's opacity).
local DIM = 0.6

type Nodes = ShopScreenBlocks.Nodes

export type ShopConfirmDialogProps = {
	product: VM.Product,
	offer: ShopTypes.Offer,
	owns: (id: string) -> boolean,
	balances: VM.Balances,
	preview: ShopScreenBlocks.Preview?,
	size: number,
	phone: boolean,
	-- The pop-in's play (useToonPlay).
	asked: React.Binding<number>,
	setConfirming: (value: boolean) -> (),
	setBuying: (id: string) -> (),
}

local function ShopConfirmDialog(props: ShopConfirmDialogProps): React.ReactNode
	local product = props.product
	local offer = props.offer
	local owns = props.owns
	local balances = props.balances
	local preview = props.preview
	local size = props.size
	local phone = props.phone
	local asked = props.asked
	local setConfirming = props.setConfirming
	local setBuying = props.setBuying
	local dialog: Nodes = {
		question = e(ToonText, {
			text = product.confirm,
			textSize = size + 6,
			meaning = "grape",
			position = UDim2.fromOffset(24, 24),
			size = UDim2.new(1, -48, 0, (size + 6) * 2 + 8),
			wrapped = true,
			fit = true,
			align = "center",
		}),
		yes = e(ToonButton, {
			variant = "primary",
			text = "Yes!",
			textSize = size + 6,
			sound = "cta",
			anchor = Vector2.new(1, 1),
			position = UDim2.new(0.5, -10, 1, -24),
			size = UDim2.new(0.5, -34, 0, if phone then 44 else 70),
			onActivated = function()
				setConfirming(false)
				if preview == nil then
					-- A yes to "Use 30 Gleam" is a yes to at most that much Gleam for the rest.
					local gleam = if product.button.kind == "topup" then product.button.gleam else nil
					-- The price the player saw: the server never charges more.
					local seen = ShopPriceRules.forPlayer(offer, owns, balances.now).price
					setBuying(offer.id)
					ShopServiceClient:requestBuy(offer.id, gleam, seen)
				end
			end,
		}),
		no = e(ToonButton, {
			variant = "secondary",
			text = "No",
			textSize = size + 6,
			sound = "back",
			anchor = Vector2.new(0, 1),
			position = UDim2.new(0.5, 10, 1, -24),
			size = UDim2.new(0.5, -34, 0, if phone then 44 else 70),
			onActivated = function()
				setConfirming(false)
			end,
		}),
	}
	return e("TextButton", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = COLOR.ink,
		BackgroundTransparency = asked:map(function(t: number): number
			return 1 - DIM * math.min(1, t * MOTION.popSeconds / MOTION.dimSeconds)
		end),
		Text = "",
		AutoButtonColor = false,
		ZIndex = 20,
	}, {
		panel = e("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(if phone then 380 else 640, if phone then 170 else 300),
			BackgroundTransparency = 1,
			ZIndex = 21,
		}, {
			pop = e("UIScale", { Scale = asked:map(ToonMotionViewModel.pop) }),
			surface = e(ToonSurface, {
				hue = "cream",
				pattern = "rings",
				radius = 28,
				size = UDim2.fromScale(1, 1),
				children = dialog,
			}),
		}),
	})
end

return ShopConfirmDialog
