--!strict
--[=[
	DealBanner: a one-time deal in the shop's Featured banner spot (owner-approved mock, 11-09). A gold (Legendary) or
	mint (New Hire) surface with the coral "ONE-TIME DEAL" ribbon, the big name, its line, the employees it can give
	LIVE in their Legendary skins on the right, the mint price button ("R$ 399", or a disabled "Soon" until the
	product exists), the coral "-45%" flag, "1 per player" under it, and a small "Next" button when there is more than
	one thing for the spot. Presentational (exempt; values in DealViewModel).

	@class DealBanner
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local DealConstants = require(ReplicatedStorage.Shared.Features.Deal.Data.DealConstants)
local Toon = ReplicatedStorage.Client.UI.React.Screens.Toon
local ToonButton = require(Toon.ToonButton)
local ToonFlag = require(Toon.ToonFlag)
local ToonSurface = require(Toon.ToonSurface)
local ToonText = require(Toon.ToonText)
local ToonViewport = require(Toon.ToonViewport)
local UIToonConstants = require(Toon.UIToonConstants)
local VM = require(script.Parent.DealViewModel)

local e = React.createElement

local COLOR = UIToonConstants.COLOR
local DEPTH = UIToonConstants.DEPTH

type Nodes = { [string]: React.ReactNode }

export type DealBannerProps = {
	banner: VM.Banner,
	phone: boolean,
	textSize: number,
	headingSize: number,
	size: UDim2,
	onBuy: () -> (),
	-- Shown when the spot has more than one thing to show.
	onNext: (() -> ())?,
}

local function DealBanner(props: DealBannerProps): React.ReactNode
	local banner = props.banner
	local phone = props.phone
	local size = props.textSize
	local nameSize = math.floor(props.headingSize * (if phone then 1 else 1.3))
	local pad = if phone then 12 else 28
	local faces: Nodes = {
		list = e("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Right,
			VerticalAlignment = Enum.VerticalAlignment.Bottom,
			Padding = UDim.new(0, if phone then -24 else -60),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	}
	for index, face in banner.faces do
		faces[face.employee] = e(ToonViewport, {
			employee = face.employee,
			skin = face.skinKey,
			framing = "full",
			size = UDim2.fromScale(1 / math.max(2, #banner.faces) + 0.12, 1),
			layoutOrder = index,
		})
	end
	local face: Nodes = {
		heroes = e("Frame", {
			AnchorPoint = Vector2.new(1, 1),
			Position = UDim2.fromScale(1, 1),
			Size = UDim2.fromScale(0.6, 1.05),
			BackgroundTransparency = 1,
			ZIndex = 2,
		}, faces),
		ribbon = e(ToonFlag, {
			text = DealConstants.TEXT.ribbon,
			hue = "coral",
			tilt = -5,
			textSize = if phone then 13 else 24,
			position = UDim2.fromOffset(pad, if phone then 10 else 26),
			size = UDim2.fromOffset(if phone then 140 else 280, if phone then 26 else 44),
			zIndex = 4,
		}),
		name = e(ToonText, {
			text = banner.name,
			textSize = nameSize,
			position = UDim2.fromOffset(pad, if phone then 40 else 84),
			size = UDim2.new(0.62, 0, 0, nameSize + 8),
			fit = true,
			zIndex = 4,
		}),
		line = e(ToonText, {
			text = banner.line,
			font = "body",
			color = COLOR.ink,
			textSize = size,
			position = UDim2.fromOffset(pad, (if phone then 40 else 84) + nameSize + 10),
			size = UDim2.new(0.5, 0, 0, size * 2 + 6),
			wrapped = true,
			fit = true,
			alignY = "top",
			zIndex = 4,
		}),
		buy = e(ToonButton, {
			variant = "primary",
			text = banner.price,
			textSize = if phone then 18 else 36,
			disabled = not banner.buyable,
			sound = "cta",
			anchor = Vector2.new(0, 1),
			position = UDim2.new(0, pad, 1, -(if phone then 34 else 70)),
			size = UDim2.new(0.4, 0, 0, if phone then 44 else 90),
			onActivated = props.onBuy,
			zIndex = 4,
		}),
		off = e(ToonFlag, {
			text = banner.off,
			hue = "coral",
			tilt = 8,
			textSize = if phone then 16 else 32,
			anchor = Vector2.new(0, 1),
			position = UDim2.new(0.4, pad - 14, 1, -(if phone then 64 else 136)),
			size = UDim2.fromOffset(if phone then 66 else 124, if phone then 30 else 54),
			zIndex = 5,
		}),
		once = e(ToonText, {
			text = DealConstants.TEXT.once,
			font = "body",
			color = COLOR.ink,
			textSize = size - 4,
			anchor = Vector2.new(0, 1),
			position = UDim2.new(0, pad, 1, -(if phone then 10 else 24)),
			size = UDim2.new(0.6, 0, 0, size),
			fit = true,
			zIndex = 4,
		}),
	}
	local onNext = props.onNext
	if onNext ~= nil then
		face.next = e(ToonButton, {
			variant = "night",
			text = "Next",
			textSize = if phone then 13 else 22,
			small = true,
			anchor = Vector2.new(1, 0),
			position = UDim2.new(1, -pad, 0, if phone then 10 else 24),
			size = UDim2.fromOffset(if phone then 64 else 110, if phone then 28 else 46),
			onActivated = onNext,
			zIndex = 6,
		})
	end
	local hue: UIToonConstants.Hue = if banner.id == "pickLegendary" then "gold" else "mint"
	return e("Frame", {
		Size = props.size,
		BackgroundTransparency = 1,
	}, {
		glow = e(ToonSurface, {
			hue = hue,
			radius = 32,
			pattern = "rings",
			size = UDim2.new(1, 0, 1, -DEPTH.drop),
			children = face,
		}),
	})
end

return DealBanner
