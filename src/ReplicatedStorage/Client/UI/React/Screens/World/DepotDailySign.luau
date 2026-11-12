--!strict
--[=[
	DepotDailySign: the hub's daily bonus sheet in the V1 kit at its 300x380 design size (owner 11-12, kit mock round 2
	#2: numbers and pictures, not sentences): a gold kit panel pinned to the wall, tilted a little like a note, under a
	TODAY band with the gift render; today's job as its rendered picture and a big gold count, a mint bar filling as it
	gets done (with the count done), and the Credits it pays on a mint pill; a coral DONE! stamp once it is claimed.
	Presentational; the view is DepotSignViewModel.daily.

	@class DepotDailySign
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local DepotSignViewModel = require(ReplicatedStorage.Client.UI.React.Screens.World.DepotSignViewModel)
local Toon = ReplicatedStorage.Client.UI.React.Screens.Toon
local ToonIcon = require(Toon.ToonIcon)
local ToonPanel = require(Toon.ToonPanel)
local ToonPill = require(Toon.ToonPill)
local ToonText = require(Toon.ToonText)
local UIToonConstants = require(Toon.UIToonConstants)

local e = React.createElement

export type DepotDailySignProps = {
	view: DepotSignViewModel.DailyView,
}

local SIGN = Vector2.new(300, 380)
local PANEL = Vector2.new(264, 340)
local HEADER = 64
local PAD = 22
local JOB = 112
local BAR = 26
local INK = UIToonConstants.COLOR.ink

local function DepotDailySign(props: DepotDailySignProps): React.ReactNode
	local view = props.view
	local top = HEADER + 16
	local mint = UIToonConstants.shade("mint")
	local face: { [string]: React.ReactNode } = {
		job = e(ToonIcon, {
			icon = view.icon,
			position = UDim2.fromOffset(PAD - 4, top),
			size = UDim2.fromOffset(JOB, JOB),
		}),
		count = e(ToonText, {
			text = view.count,
			meaning = "gold",
			textSize = 64,
			align = "center",
			position = UDim2.fromOffset(PAD + JOB - 6, top + 18),
			size = UDim2.new(1, -2 * PAD - JOB + 6, 0, 76),
			fit = true,
		}),
		bar = e("Frame", {
			Position = UDim2.fromOffset(PAD, top + JOB + 12),
			Size = UDim2.new(1, -2 * PAD, 0, BAR),
			BackgroundColor3 = UIToonConstants.shade("night").lo,
			BorderSizePixel = 0,
		}, {
			corner = e("UICorner", { CornerRadius = UDim.new(1, 0) }),
			stroke = e("UIStroke", { Color = INK, Thickness = 4, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }),
			fill = e("Frame", {
				Size = UDim2.fromScale(math.max(view.fill, 0.08), 1),
				BackgroundColor3 = mint.base,
				BorderSizePixel = 0,
				Visible = view.fill > 0,
			}, {
				corner = e("UICorner", { CornerRadius = UDim.new(1, 0) }),
				shine = e("UIGradient", {
					Rotation = 90,
					Color = ColorSequence.new(mint.hi, mint.lo),
				}),
			}),
			label = e(ToonText, {
				text = view.progress,
				textSize = 20,
				align = "center",
				size = UDim2.fromScale(1, 1),
				zIndex = 3,
			}),
		}),
		reward = e(ToonPill, {
			text = view.reward,
			hue = "mint",
			icon = "credits",
			textSize = 26,
			anchor = Vector2.new(0.5, 1),
			position = UDim2.new(0.5, 0, 1, -16),
			size = UDim2.fromOffset(150, 46),
		}),
		stamp = if view.done
			then e(ToonPill, {
				text = "DONE!",
				hue = "coral",
				meaning = "white",
				textSize = 30,
				tilt = -12,
				anchor = Vector2.new(0.5, 0.5),
				position = UDim2.new(0.5, 0, 0, top + JOB / 2),
				size = UDim2.fromOffset(150, 52),
				zIndex = 6,
			})
			else nil,
	}
	return e("Frame", { Size = UDim2.fromOffset(SIGN.X, SIGN.Y), BackgroundTransparency = 1 }, {
		note = e("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(PANEL.X, PANEL.Y),
			Rotation = 2.5,
			BackgroundTransparency = 1,
		}, {
			panel = e(ToonPanel, {
				size = PANEL,
				hue = "gold",
				header = { title = view.title, icon = "gift", height = HEADER, titleSize = 34 },
				children = face,
			}),
		}),
		pin = e("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromOffset(SIGN.X / 2, 16),
			Size = UDim2.fromOffset(22, 22),
			BackgroundColor3 = Color3.fromRGB(220, 60, 60),
			BorderSizePixel = 0,
			ZIndex = 6,
		}, { corner = e("UICorner", { CornerRadius = UDim.new(1, 0) }) }),
	})
end

return DepotDailySign
