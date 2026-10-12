--!strict
-- Reactive depot shortcuts: never shown over a crew shift or travel card.
local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage.Packages.React)
local ReactCharm = require(ReplicatedStorage.Packages.ReactCharm)
local DepotStore = require(ReplicatedStorage.Client.Features.Depot.State.DepotStore)
local ShiftStore = require(ReplicatedStorage.Client.Features.Shift.State.ShiftStore)
local SceneStack = require(ReplicatedStorage.Client.UI.Scenes.SceneStack)
local PaperButton = require(script.Parent.Parent.Paper.PaperButton)
local PaperPropIcon = require(script.Parent.Parent.Paper.PaperPropIcon)
local PaperHudFrame = require(script.Parent.Parent.Paper.PaperHudFrame)
local usePaperHudScale = require(script.Parent.Parent.Paper.usePaperHudScale)
local VM = require(script.Parent.DepotHubViewModel)
local DepotConstants = require(ReplicatedStorage.Shared.Features.Depot.Data.DepotConstants)
local e = React.createElement
local function icon(kind: "jobs" | "guide" | "gear" | "settings"): React.ReactNode
	return e(PaperPropIcon, { kind = kind })
end
local function DepotHub(): React.ReactNode
	local snapshot = ReactCharm.useAtom(ShiftStore.snapshot)
	local card = ReactCharm.useAtom(DepotStore.card)
	local scale = usePaperHudScale()
	local player = Players.LocalPlayer
	if not VM.visible(snapshot, player.UserId) or card ~= nil then
		return nil
	end
	local phone = scale.layout == "phone"
	local size = VM.cardSize(phone)
	local entries: { { label: string, kind: "jobs" | "guide" | "gear" | "settings", activate: () -> () } } = {
		{
			label = "JOBS",
			kind = "jobs",
			activate = function()
				for _, shell in CollectionService:GetTagged(DepotConstants.BILLBOARD_TAGS.contract) do
					local id = shell:GetAttribute(DepotConstants.CONTRACT_KEYS.id)
					if type(id) == "string" then
						DepotStore.openBoard(id)
						SceneStack.push(DepotConstants.BOARD_SCENE)
						return
					end
				end
			end,
		},
		{
			label = "GUIDE",
			kind = "guide",
			activate = function()
				SceneStack.push(VM.scene("guide"))
			end,
		},
		{
			label = "GEAR",
			kind = "gear",
			activate = function()
				SceneStack.push(VM.scene("gear"))
			end,
		},
		{
			label = "SETTINGS",
			kind = "settings",
			activate = function()
				SceneStack.push(VM.scene("settings"))
			end,
		},
	}
	local nodes: { [string]: React.ReactNode } = {}
	for index, entry in entries do
		nodes[entry.kind] = e(PaperButton, {
			text = entry.label,
			variant = "prop",
			icon = icon(entry.kind),
			onActivated = entry.activate,
			position = UDim2.fromOffset((index - 1) * (size.X + 10), 0),
			size = UDim2.fromOffset(size.X, size.Y),
			textSize = if phone then 14 else 20,
		})
	end
	return e(PaperHudFrame, {
		scale = scale.scale,
		children = {
			nav = e("Frame", {
				AnchorPoint = Vector2.new(1, 0),
				Position = if phone then UDim2.new(1, -48, 0, 6) else UDim2.new(1, -30, 0, 20),
				Size = UDim2.fromOffset(4 * size.X + 30, size.Y),
				BackgroundTransparency = 1,
			}, nodes),
		},
	})
end
return DepotHub
