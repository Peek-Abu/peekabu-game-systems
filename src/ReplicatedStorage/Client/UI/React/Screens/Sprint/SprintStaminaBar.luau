--!strict
--[=[
	SprintStaminaBar: the small stamina bar (docs/superpowers/specs/2026-10-15-cleanup-crew-chase-kit-design.md §3): a
	strip of taped cream paper just under the middle of the screen, inked teal, stamp red when low; it shows only while
	the bar is not full (no number: nothing to read mid-chase).

	A HUD widget: it reads SprintStore and draws what SprintViewModel.bar decides.

	@class SprintStaminaBar
]=]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local ReactCharm = require(ReplicatedStorage.Packages.ReactCharm)
local DeathConstants = require(ReplicatedStorage.Shared.Features.Death.Data.DeathConstants)
local StateSyncConstants = require(ReplicatedStorage.Shared.Features.StateSync.Data.StateSyncConstants)
local OccupantCatchStore = require(ReplicatedStorage.Client.Features.Occupant.State.OccupantCatchStore)
local SprintStore = require(ReplicatedStorage.Client.Features.Sprint.State.SprintStore)
local StateSyncClientStore = require(ReplicatedStorage.Client.Features.StateSync.State.StateSyncClientStore)
local UIPaperConstants = require(ReplicatedStorage.Client.UI.React.Screens.Paper.UIPaperConstants)
local SprintViewModel = require(ReplicatedStorage.Client.UI.React.Screens.Sprint.SprintViewModel)

local e = React.createElement
local useAtom = ReactCharm.useAtom

local COLOR = UIPaperConstants.COLOR
local WIDTH = 140
local HEIGHT = 12
local INSET = 2

local function SprintStaminaBar(): React.ReactNode
	local stamina = useAtom(SprintStore.stamina)
	local publicPlayers = useAtom(StateSyncClientStore.publicPlayers)
	local scaring = useAtom(OccupantCatchStore.scaring)
	local player = Players.LocalPlayer
	local me = if player ~= nil then publicPlayers[StateSyncConstants.publicEntryKey(player.UserId)] else nil
	local caught = me ~= nil and me[DeathConstants.PUBLIC_FIELD] == true
	local view = SprintViewModel.bar(stamina, scaring or caught)
	if view == nil then
		return nil
	end
	return e("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0.5, 56),
		Size = UDim2.fromOffset(WIDTH, HEIGHT),
		Rotation = -1,
		BackgroundColor3 = COLOR.cream,
		BackgroundTransparency = 0.1,
		BorderSizePixel = 0,
	}, {
		stroke = e("UIStroke", { Color = COLOR.ink, Thickness = 1.5, Transparency = 0.2 }),
		fill = e("Frame", {
			Position = UDim2.fromOffset(INSET, INSET),
			Size = UDim2.new(view.fill, -INSET * 2 * view.fill, 1, -INSET * 2),
			BackgroundColor3 = if view.low then COLOR.stamp else COLOR.companyTeal,
			BorderSizePixel = 0,
		}),
	})
end

return SprintStaminaBar
