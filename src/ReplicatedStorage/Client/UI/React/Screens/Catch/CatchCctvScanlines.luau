--!strict
--[=[
	CatchCctvScanlines: the CCTV feed's surface under CatchCctvPanel: the night wash (reaching `bleed` above the panel
	so it covers the whole screen), the line strip tiled once per `gap`, the lens's dark edges, and the faint band that
	rolls down now and then (RollBand, none with Reduced Motion; its timing is the specced CatchViewModel.rollBand).
	Split out of CatchCctvPanel. Presentational (exempt).

	@class CatchCctvScanlines
]=]

local GuiService = game:GetService("GuiService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local React = require(ReplicatedStorage.Packages.React)
local UIAssets = require(ReplicatedStorage.Client.Features.UI.Data.UIAssets)
local OccupantAssets = require(ReplicatedStorage.Shared.Features.Occupant.Data.OccupantAssets)
local CatchViewModel = require(ReplicatedStorage.Client.UI.React.Screens.Catch.CatchViewModel)
local Toon = ReplicatedStorage.Client.UI.React.Screens.Toon
local UIToonConstants = require(Toon.UIToonConstants)

local e = React.createElement

local COLOR = UIToonConstants.COLOR
-- The feed's own light: scanlines and brackets in white, a night wash at 25%, the carrying line at 85%; the lens's
-- dark edges in the night shade at 55%, the rolling band a faint white.
local FEED = COLOR.white
local WASH = UIToonConstants.shade("night").lo
local SCAN_TRANSPARENCY = 0.93
local WASH_TRANSPARENCY = 0.75
local LENS_TRANSPARENCY = 0.45
local BAND_TRANSPARENCY = 0.94

-- The faint band that rolls down the feed every few seconds (CatchViewModel.rollBand), hidden while it rests and
-- always with Reduced Motion on. It owns its per-frame binding, so the panel never re-renders for it.
local function RollBand(): React.ReactNode
	local top, setTop = React.useBinding(CatchViewModel.rollBand(os.clock(), GuiService.ReducedMotionEnabled))
	React.useEffect(function(): () -> ()
		local connection = RunService.RenderStepped:Connect(function()
			setTop(CatchViewModel.rollBand(os.clock(), GuiService.ReducedMotionEnabled))
		end)
		return function()
			connection:Disconnect()
		end
	end, {})
	return e("Frame", {
		Position = top:map(function(value: number?): UDim2
			return UDim2.fromScale(0, value or 0)
		end),
		Visible = top:map(function(value: number?): boolean
			return value ~= nil
		end),
		Size = UDim2.fromScale(1, CatchViewModel.ROLL_HEIGHT),
		BackgroundColor3 = FEED,
		BackgroundTransparency = BAND_TRANSPARENCY,
		BorderSizePixel = 0,
	}, {
		-- Soft at both edges, brightest through the middle.
		fade = e("UIGradient", {
			Rotation = 90,
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 1),
				NumberSequenceKeypoint.new(0.5, 0),
				NumberSequenceKeypoint.new(1, 1),
			}),
		}),
	})
end

-- The feed's surface: the night wash, the line strip repeated once per `gap` (sharp on any screen shape), the lens's
-- dark edges, and the rolling band.
local function CatchCctvScanlines(gap: number, bleed: number): React.ReactNode
	return e("Frame", {
		-- The wash covers the whole screen, top bar included: it reaches `bleed` above the panel.
		Position = UDim2.fromOffset(0, -bleed),
		Size = UDim2.new(1, 0, 1, bleed),
		ZIndex = 0,
		BackgroundColor3 = WASH,
		BackgroundTransparency = WASH_TRANSPARENCY,
		BorderSizePixel = 0,
		ClipsDescendants = true,
	}, {
		lines = e("ImageLabel", {
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			Image = UIAssets.cctv.scanlines,
			ImageColor3 = FEED,
			ImageTransparency = SCAN_TRANSPARENCY,
			ScaleType = Enum.ScaleType.Tile,
			TileSize = CatchViewModel.scanTile(gap),
		}),
		lens = e("ImageLabel", {
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			Image = OccupantAssets.IMAGES.dreadVignette,
			ImageColor3 = WASH,
			ImageTransparency = LENS_TRANSPARENCY,
			ScaleType = Enum.ScaleType.Stretch,
		}),
		band = e(RollBand),
	})
end

return CatchCctvScanlines
