--!strict
--[=[
	ToonStamp: a rubber stamp pressed onto a card ("OWNED" on something you have, "HIRED!" on an ID card): the kit's
	double-ring image and the word across it, tilted, in one hue, a little see-through like ink on paper.
	Presentational (exempt; story in ToonShopKit.story).

	@class ToonStamp
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local UIAssets = require(ReplicatedStorage.Client.Features.UI.Data.UIAssets)
local UIToonConstants = require(ReplicatedStorage.Client.UI.React.Screens.Toon.UIToonConstants)

local e = React.createElement

export type ToonStampProps = {
	text: string,
	size: number,
	position: UDim2?,
	anchor: Vector2?,
	hue: UIToonConstants.Hue?,
	tilt: number?,
	zIndex: number?,
}

local function ToonStamp(props: ToonStampProps): React.ReactNode
	local color = UIToonConstants.shade(props.hue or "mint").lo
	local size = props.size
	return e("Frame", {
		AnchorPoint = props.anchor,
		Position = props.position,
		Size = UDim2.fromOffset(size, size),
		Rotation = props.tilt or -14,
		BackgroundTransparency = 1,
		ZIndex = props.zIndex,
	}, {
		ring = e("ImageLabel", {
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			Image = UIAssets.toon.stamp,
			ImageColor3 = color,
			ImageTransparency = 0.1,
			ZIndex = (props.zIndex or 1),
		}),
		-- The word is a band across the ring, in the same ink (a stamp has no stroke or drop).
		band = e("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(1.12, 0.3),
			BackgroundColor3 = color,
			BackgroundTransparency = 0.1,
			BorderSizePixel = 0,
			ZIndex = (props.zIndex or 1) + 1,
		}, {
			corner = e("UICorner", { CornerRadius = UDim.new(0, math.floor(size * 0.05)) }),
			word = e("TextLabel", {
				Size = UDim2.fromScale(1, 1),
				BackgroundTransparency = 1,
				Text = props.text,
				FontFace = UIToonConstants.FONT.display,
				TextScaled = true,
				TextColor3 = UIToonConstants.COLOR.white,
				ZIndex = (props.zIndex or 1) + 2,
			}, {
				pad = e("UIPadding", {
					PaddingLeft = UDim.new(0.08, 0),
					PaddingRight = UDim.new(0.08, 0),
					PaddingTop = UDim.new(0.12, 0),
					PaddingBottom = UDim.new(0.08, 0),
				}),
			}),
		}),
	})
end

return ToonStamp
