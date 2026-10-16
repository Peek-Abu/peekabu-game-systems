--!strict
--[=[
	OccupantPaSubtitle: the PA's paper subtitle HUD widget (registered by OccupantServiceClient; docs/superpowers/specs/
	2026-10-15-cleanup-crew-manager-behaviours-design.md §5). Reads OccupantPaStore and draws OccupantPaViewModel's
	strip: a torn cream sheet low in the middle of the screen with its band ("PA · ALL STAFF", or the red call-out band)
	and the line in typewriter ink, drawn at the paper HUD's scale. Presentational.

	@class OccupantPaSubtitle
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local ReactCharm = require(ReplicatedStorage.Packages.ReactCharm)
local OccupantPaStore = require(ReplicatedStorage.Client.Features.Occupant.State.OccupantPaStore)
local PaperHudFrame = require(ReplicatedStorage.Client.UI.React.Screens.Paper.PaperHudFrame)
local PaperLabel = require(ReplicatedStorage.Client.UI.React.Screens.Paper.PaperLabel)
local PaperSheet = require(ReplicatedStorage.Client.UI.React.Screens.Paper.PaperSheet)
local UIPaperConstants = require(ReplicatedStorage.Client.UI.React.Screens.Paper.UIPaperConstants)
local usePaperHudScale = require(ReplicatedStorage.Client.UI.React.Screens.Paper.usePaperHudScale)
local OccupantPaViewModel = require(ReplicatedStorage.Client.UI.React.Screens.World.OccupantPaViewModel)

local e = React.createElement

local WIDTH = 680
local HEIGHT = 104
-- How far above the screen's foot the strip sits (clear of the bottom action cards).
local LIFT = 210

local function OccupantPaSubtitle(): React.ReactNode
	local notice = ReactCharm.useAtom(OccupantPaStore.notice)
	local hudScale = usePaperHudScale()
	local view = OccupantPaViewModel.view(notice)
	if view == nil then
		return nil
	end
	local lines: { [string]: React.ReactNode } = {
		line = e(PaperLabel, {
			text = view.text,
			role = "body",
			size = 26,
			align = "center",
			wrapped = true,
		}),
	}
	return e(PaperHudFrame, {
		scale = hudScale.scale,
		children = {
			strip = e(PaperSheet, {
				size = UDim2.fromOffset(WIDTH, HEIGHT),
				position = UDim2.new(0.5, 0, 1, -LIFT),
				anchor = Vector2.new(0.5, 1),
				paper = UIPaperConstants.COLOR.cream,
				tilt = -1,
				torn = true,
				band = view.band,
				bandColor = view.bandColor,
				shadow = true,
				padding = 12,
				children = lines,
			}),
		},
	})
end

return OccupantPaSubtitle
