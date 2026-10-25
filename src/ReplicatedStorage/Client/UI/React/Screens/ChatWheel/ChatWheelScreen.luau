--!strict
--[=[
	ChatWheelScreen: the chat wheel (hold T; design §8 and the Chat wheel concept): the six pings on a ring round a
	"Hold T to talk" button, the player's 4 sticker slots at the corners. What the pointer (mouse or right stick)
	leans toward lights up and is written to CalloutWheelStore (letting go of T sends it); a click or tap sends at once
	(`onPick`). Empty sticker slots show "+" (stickers come from the Shop and skins; Inventory > Chat wheel puts them
	in slots). A click outside closes it. Drawn at the game's one UI scale. Exempt (input and stores; decisions in
	ChatWheelViewModel).

	@class ChatWheelScreen
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local React = require(ReplicatedStorage.Packages.React)
local ReactCharm = require(ReplicatedStorage.Packages.ReactCharm)
local CosmeticRules = require(ReplicatedStorage.Shared.Features.Cosmetic.Rules.CosmeticRules)
local CalloutWheelStore = require(ReplicatedStorage.Client.Features.Callout.State.CalloutWheelStore)
local StateSyncClientStore = require(ReplicatedStorage.Client.Features.StateSync.State.StateSyncClientStore)
local Toon = ReplicatedStorage.Client.UI.React.Screens.Toon
local ToonButton = require(Toon.ToonButton)
local ToonText = require(Toon.ToonText)
local UIToonConstants = require(Toon.UIToonConstants)
local PaperHudFrame = require(script.Parent.Parent.Paper.PaperHudFrame)
local PaperHudScaleViewModel = require(script.Parent.Parent.Paper.PaperHudScaleViewModel)
local usePaperLayout = require(script.Parent.Parent.Paper.usePaperLayout)
local usePaperViewport = require(script.Parent.Parent.Paper.usePaperViewport)
local VM = require(script.Parent.ChatWheelViewModel)

local e = React.createElement

local COLOR = UIToonConstants.COLOR

export type ChatWheelScreenProps = {
	onPick: (pick: VM.Pick) -> (),
	onClose: () -> (),
	-- Fixed data instead of the stores (a story).
	preview: VM.View?,
	viewport: Vector2?,
}

type Nodes = { [string]: React.ReactNode }

local STICK_DEAD = 0.35

-- A picture over a word, for a button's face.
local function face(image: string?, word: string, textSize: number, art: number): Nodes
	return {
		picture = if image ~= nil
			then e("ImageLabel", {
				AnchorPoint = Vector2.new(0.5, 0),
				Position = UDim2.new(0.5, 0, 0, 4),
				Size = UDim2.fromOffset(art, art),
				BackgroundTransparency = 1,
				Image = image,
				ScaleType = Enum.ScaleType.Fit,
				ZIndex = 3,
			})
			else nil,
		word = e(ToonText, {
			text = word,
			textSize = textSize,
			anchor = Vector2.new(0.5, 1),
			position = UDim2.new(0.5, 0, 1, -10),
			size = UDim2.new(1, -8, 0, textSize + 4),
			align = "center",
			fit = true,
			zIndex = 4,
		}),
	}
end

local function same(a: VM.Pick?, b: VM.Pick): boolean
	if a == nil or a.kind ~= b.kind then
		return false
	end
	if a.kind == "ping" and b.kind == "ping" then
		return a.id == b.id
	elseif a.kind == "sticker" and b.kind == "sticker" then
		return a.slot == b.slot
	end
	return false
end

local function ChatWheelScreen(props: ChatWheelScreenProps): React.ReactNode
	local liveViewport = usePaperViewport()
	local phone = usePaperLayout() == "phone"
	local loadout = ReactCharm.useAtom(StateSyncClientStore.loadout)
	local entitlements = ReactCharm.useAtom(StateSyncClientStore.entitlements)
	local hovered = ReactCharm.useAtom(CalloutWheelStore.hovered)

	local view = props.preview
		or VM.view(loadout, function(id: string): boolean
			return CosmeticRules.owns(entitlements, id)
		end)
	local viewport = props.viewport or liveViewport
	local scale = PaperHudScaleViewModel.scale(viewport, if phone then "phone" else "desktop")
	local ring = if phone then 105 else 175
	local pingSize = if phone then 84 else 130
	local reach = if phone then 170 else 285
	local stickerSize = if phone then 92 else 140

	React.useEffect(function(): () -> ()
		local moved = UserInputService.InputChanged:Connect(function(input: InputObject)
			if input.UserInputType == Enum.UserInputType.MouseMovement then
				local centre = workspace.CurrentCamera.ViewportSize / 2
				local offset = (UserInputService:GetMouseLocation() - centre) / scale
				CalloutWheelStore.hover(VM.pick(offset, view.pings, ring * 0.3, (ring + reach) / 2))
			elseif input.KeyCode == Enum.KeyCode.Thumbstick2 then
				local lean = Vector2.new(input.Position.X, -input.Position.Y)
				-- A light lean picks a ping, a full one a sticker corner.
				CalloutWheelStore.hover(VM.pick(lean, view.pings, STICK_DEAD, 0.9))
			end
		end)
		return function()
			moved:Disconnect()
		end
	end, { scale, ring, reach, #view.pings })

	local nodes: Nodes = {
		disc = e("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(reach * 2.2, reach * 2.2),
			BackgroundColor3 = UIToonConstants.shade("grape").lo,
			BackgroundTransparency = 0.1,
			ZIndex = 1,
		}, {
			corner = e("UICorner", { CornerRadius = UDim.new(0.5, 0) }),
			stroke = e("UIStroke", { Color = COLOR.ink, Thickness = 6 }),
		}),
		middle = e("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(ring * 0.95, ring * 0.95),
			BackgroundColor3 = UIToonConstants.shade("grape").base,
			ZIndex = 2,
		}, {
			corner = e("UICorner", { CornerRadius = UDim.new(0.5, 0) }),
			stroke = e("UIStroke", { Color = COLOR.ink, Thickness = 5 }),
			word = e(ToonText, {
				text = if phone then "Tap one" else "Hold T to talk",
				textSize = if phone then 16 else 26,
				anchor = Vector2.new(0.5, 0.5),
				position = UDim2.fromScale(0.5, 0.5),
				size = UDim2.fromScale(0.8, 0.5),
				align = "center",
				wrapped = true,
				fit = true,
				zIndex = 3,
			}),
		}),
	}
	for index, ping in view.pings do
		local at = VM.pingPosition(index, #view.pings, ring)
		local pick: VM.Pick = { kind = "ping", id = ping.id }
		local lit = same(hovered, pick)
		nodes[`ping{ping.id}`] = e(ToonButton, {
			variant = if ping.id == "manager" then "danger" elseif lit then "gleam" else "secondary",
			selected = lit,
			radius = math.floor(pingSize / 2),
			anchor = Vector2.new(0.5, 0.5),
			position = UDim2.new(0.5, at.X, 0.5, at.Y),
			size = UDim2.fromOffset(pingSize, pingSize),
			content = face(ping.image, ping.word, if phone then 11 else 17, math.floor(pingSize * 0.5)),
			zIndex = 5,
			onActivated = function()
				props.onPick(pick)
			end,
		})
	end
	for _, slot in view.stickers do
		local at = VM.stickerPosition(slot.slot, reach * 0.8)
		local pick: VM.Pick = { kind = "sticker", slot = slot.slot }
		local lit = not slot.empty and same(hovered, pick)
		nodes[`sticker{slot.slot}`] = e(ToonButton, {
			variant = if slot.empty then "night" elseif lit then "gleam" else "primary",
			selected = lit,
			disabled = slot.empty,
			anchor = Vector2.new(0.5, 0.5),
			position = UDim2.new(0.5, at.X, 0.5, at.Y),
			size = UDim2.fromOffset(stickerSize, stickerSize),
			text = if slot.empty then "+" else nil,
			textSize = if phone then 30 else 48,
			content = if slot.empty
				then nil
				else face(slot.image, slot.name, if phone then 12 else 18, math.floor(stickerSize * 0.6)),
			zIndex = 5,
			onActivated = function()
				if not slot.empty then
					props.onPick(pick)
				end
			end,
		})
	end

	return e("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
	}, {
		dim = e("TextButton", {
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = COLOR.ink,
			BackgroundTransparency = 0.55,
			Text = "",
			AutoButtonColor = false,
			[React.Event.Activated] = function()
				props.onClose()
			end,
		}),
		scaled = e(PaperHudFrame, {
			scale = scale,
			children = {
				wheel = e("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1 }, nodes),
			},
		}),
	})
end

return ChatWheelScreen
