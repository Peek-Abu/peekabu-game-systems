--!strict
--[=[
	DepotFocusOutlineSystem: a soft outline on the hub station this player is looking at (owner 11-12, ideas #6: only
	while you look at it, never always on). The prompt system already picks the one interactable the camera aims at
	and shows its prompt (ShiftPromptStore.shown); when that is a hub station (DepotTopperRules.station) its model wears
	one Highlight in the station's colour (DepotTopperConstants), fading in over OUTLINE.FADE seconds, hidden by walls,
	gone as soon as the prompt goes. One Highlight for the whole hub. Local and cosmetic.

	Spec-exempt shell (a Highlight, a tween); what it wraps is the specced DepotTopperRules.outlineOf.

	@class DepotFocusOutlineSystem
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Charm = require(ReplicatedStorage.Packages.Charm)
local DepotSpotConstants = require(ReplicatedStorage.Shared.Features.Depot.Data.DepotSpotConstants)
local DepotTopperRules = require(ReplicatedStorage.Shared.Features.Depot.Rules.DepotTopperRules)
local DepotTopperConstants = require(ReplicatedStorage.Client.Features.Depot.Data.DepotTopperConstants)
local ShiftPromptStore = require(ReplicatedStorage.Client.Features.Shift.State.ShiftPromptStore)
local UIToonConstants = require(ReplicatedStorage.Client.UI.React.Screens.Toon.UIToonConstants)

local OUTLINE = DepotSpotConstants.TOPPER.OUTLINE

local DepotFocusOutlineSystem = {}

-- Outlines the hub station the shown prompt belongs to; returns the stopper.
function DepotFocusOutlineSystem.start(): () -> ()
	local highlight = Instance.new("Highlight")
	highlight.Name = "DepotFocusOutline"
	highlight.DepthMode = Enum.HighlightDepthMode.Occluded
	highlight.FillTransparency = 1
	highlight.OutlineTransparency = 1
	highlight.Enabled = false
	highlight.Parent = Workspace
	local fade: Tween? = nil
	local function show(adornee: Instance?, color: Color3?)
		if fade ~= nil then
			fade:Cancel()
			fade = nil
		end
		if adornee == nil or color == nil then
			highlight.Enabled = false
			highlight.Adornee = nil
			highlight.OutlineTransparency = 1
			return
		end
		if highlight.Adornee ~= adornee then
			highlight.OutlineTransparency = 1
		end
		highlight.Adornee = adornee
		highlight.OutlineColor = color
		highlight.Enabled = true
		local tween = TweenService:Create(
			highlight,
			TweenInfo.new(OUTLINE.FADE, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ OutlineTransparency = OUTLINE.TRANSPARENCY }
		)
		fade = tween
		tween:Play()
	end
	local stop = Charm.subscribe(ShiftPromptStore.shown, function(view: ShiftPromptStore.PromptView?)
		local target = if view ~= nil then view.target else nil
		local key = if view ~= nil then DepotTopperRules.station(view.kind) else nil
		local station = if key ~= nil then DepotTopperConstants.STATIONS[key] else nil
		if target == nil or station == nil then
			show(nil, nil)
			return
		end
		show(DepotTopperRules.outlineOf(target), UIToonConstants.shade(station.hue).hi)
	end)
	return function()
		stop()
		if fade ~= nil then
			fade:Cancel()
		end
		highlight:Destroy()
	end
end

return DepotFocusOutlineSystem
