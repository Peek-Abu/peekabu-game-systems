--!strict
--[=[
	DepotWorkOrderBoard: the contract board in the V1 kit at its 600x420 design size (owner 11-12, kit mock round 2 #2:
	numbers and pictures, not sentences): tonight's job as a cream panel on the depth stack under a grape TONIGHT'S JOB
	band (the clipboard render breaking its top-left corner, Gloom dripping from its foot). On it: the map's graded
	photo pinned at a tilt, the client in stroked display type, the Gloom to remove as the Gloom render and a big gold
	number (a range while the viewer is in no truck), and the E key cap with "Read". Presentational; the view is
	DepotWorldViewModel.workOrder.

	@class DepotWorkOrderBoard
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local UIAssets = require(ReplicatedStorage.Client.Features.UI.Data.UIAssets)
local DepotWorldViewModel = require(ReplicatedStorage.Client.UI.React.Screens.World.DepotWorldViewModel)
local Toon = ReplicatedStorage.Client.UI.React.Screens.Toon
local ToonIcon = require(Toon.ToonIcon)
local ToonPanel = require(Toon.ToonPanel)
local ToonSurface = require(Toon.ToonSurface)
local ToonText = require(Toon.ToonText)
local UIToonConstants = require(Toon.UIToonConstants)

local e = React.createElement

export type DepotWorkOrderBoardProps = {
	view: DepotWorldViewModel.WorkOrderView,
}

local BOARD = Vector2.new(600, 420)
-- The panel, inset so the render breaking its corner and its hard drop stay inside the board's canvas.
local PANEL_AT = Vector2.new(48, 40)
local PANEL = Vector2.new(BOARD.X - 2 * PANEL_AT.X + 12, BOARD.Y - PANEL_AT.Y - 22)
local HEADER = 76
local PAD = 26
local PHOTO = Vector2.new(208, 130)
local GLOOM = 86
local KEY = 34
local INK = UIToonConstants.COLOR.ink

local function DepotWorkOrderBoard(props: DepotWorkOrderBoardProps): React.ReactNode
	local view = props.view
	-- Clear of the drips poured from the header's foot.
	local top = HEADER + 30
	local right = PAD + PHOTO.X + 22
	local cap: { [string]: React.ReactNode } = {
		key = e(ToonText, {
			text = view.key,
			textSize = 20,
			size = UDim2.fromScale(1, 1),
			align = "center",
			fit = true,
		}),
	}
	local face: { [string]: React.ReactNode } = {
		photo = e("ImageLabel", {
			Position = UDim2.fromOffset(PAD, top),
			Size = UDim2.fromOffset(PHOTO.X, PHOTO.Y),
			Rotation = -3,
			Image = UIAssets.toonPhotos.officeCard,
			ScaleType = Enum.ScaleType.Crop,
			BorderSizePixel = 0,
			BackgroundColor3 = INK,
		}, {
			corner = e("UICorner", { CornerRadius = UDim.new(0, 12) }),
			stroke = e("UIStroke", { Color = INK, Thickness = 5, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }),
		}),
		client = e(ToonText, {
			text = view.client,
			textSize = 32,
			wrapped = true,
			position = UDim2.fromOffset(right, top - 4),
			size = UDim2.new(1, -right - PAD, 0, 74),
			fit = true,
		}),
		gloom = e(ToonIcon, {
			icon = "gloom",
			position = UDim2.fromOffset(right - 8, top + 70),
			size = UDim2.fromOffset(GLOOM, GLOOM),
		}),
		quota = e(ToonText, {
			text = view.quota,
			meaning = "gold",
			textSize = 64,
			position = UDim2.fromOffset(right + GLOOM - 4, top + 78),
			size = UDim2.new(1, -right - GLOOM - PAD + 4, 0, 72),
			fit = true,
		}),
		key = e(ToonSurface, {
			hue = "cream",
			small = true,
			radius = 9,
			position = UDim2.fromOffset(PAD, top + PHOTO.Y + 26),
			size = UDim2.fromOffset(KEY, KEY),
			children = cap,
		}),
		action = e(ToonText, {
			text = "Read",
			font = "body",
			textSize = 20,
			position = UDim2.fromOffset(PAD + KEY + 12, top + PHOTO.Y + 26),
			size = UDim2.fromOffset(140, KEY - 4),
			fit = true,
		}),
	}
	return e("Frame", {
		Size = UDim2.fromOffset(BOARD.X, BOARD.Y),
		BackgroundTransparency = 1,
	}, {
		order = e(ToonPanel, {
			position = UDim2.fromOffset(PANEL_AT.X, PANEL_AT.Y),
			size = PANEL,
			header = {
				title = view.kicker,
				icon = "jobs",
				height = HEADER,
				titleSize = 36,
				goo = true,
				gooScale = 0.55,
			},
			children = face,
		}),
	})
end

return DepotWorkOrderBoard
