--!strict
--[=[
	ToonBurst: the spiky deal badge (+20% bonus on a Gleam bundle, a real sale's -30%): the kit's burst image tinted
	in a hue over a hard ink drop, a short word on top, tilted and slowly turning like a sticker. Presentational
	(exempt; story in ToonShopKit.story).

	@class ToonBurst
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local UIAssets = require(ReplicatedStorage.Client.Features.UI.Data.UIAssets)
local ToonText = require(ReplicatedStorage.Client.UI.React.Screens.Toon.ToonText)
local UIToonConstants = require(ReplicatedStorage.Client.UI.React.Screens.Toon.UIToonConstants)

local e = React.createElement

export type ToonBurstProps = {
	text: string,
	-- A small second line under the word ("BONUS").
	sub: string?,
	size: number,
	position: UDim2?,
	anchor: Vector2?,
	hue: UIToonConstants.Hue?,
	tilt: number?,
	zIndex: number?,
}

local function ToonBurst(props: ToonBurstProps): React.ReactNode
	local shade = UIToonConstants.shade(props.hue or "coral")
	local size = props.size
	-- The drop, the burst, then the words (explicit order: siblings at one ZIndex draw in any order).
	local z = props.zIndex or 1
	local word = math.floor(size * 0.26)
	local nodes: { [string]: React.ReactNode } = {
		drop = e("ImageLabel", {
			Position = UDim2.fromOffset(0, 4),
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			Image = UIAssets.toon.burst,
			ImageColor3 = UIToonConstants.COLOR.ink,
			ZIndex = z,
		}),
		body = e("ImageLabel", {
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			Image = UIAssets.toon.burst,
			ImageColor3 = shade.base,
			ZIndex = z + 1,
		}),
		word = e(ToonText, {
			text = props.text,
			textSize = word,
			anchor = Vector2.new(0.5, 0.5),
			position = UDim2.fromScale(0.5, if props.sub ~= nil then 0.44 else 0.5),
			size = UDim2.new(0.74, 0, 0, word + 6),
			align = "center",
			fit = true,
			zIndex = z + 2,
		}),
	}
	if props.sub ~= nil then
		nodes.sub = e(ToonText, {
			text = props.sub,
			textSize = math.floor(word * 0.5),
			anchor = Vector2.new(0.5, 0),
			position = UDim2.fromScale(0.5, 0.6),
			size = UDim2.new(0.6, 0, 0, math.floor(word * 0.5) + 4),
			align = "center",
			fit = true,
			zIndex = z + 2,
		})
	end
	return e("Frame", {
		AnchorPoint = props.anchor,
		Position = props.position,
		Size = UDim2.fromOffset(size, size),
		Rotation = props.tilt or 12,
		BackgroundTransparency = 1,
		ZIndex = props.zIndex,
	}, nodes)
end

return ToonBurst
