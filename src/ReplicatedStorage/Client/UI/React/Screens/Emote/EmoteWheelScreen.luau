--!strict
--[=[
	EmoteWheelScreen: the in-game emote wheel (hold B): the current employee's 4 slots round a night ring, the
	employee's face in the middle with their name. The slot the pointer (mouse or right stick) leans toward lights up
	and is written to EmoteWheelStore (letting go of B plays it); a click or tap plays a slot at once (`onPick`).
	Empty slots say so; an emote whose clip is not made yet wears a "Soon" flag (it does not play). A click outside
	the ring closes it (`onClose`). Drawn at the game's one UI scale. Exempt (input and stores; decisions in
	EmoteWheelViewModel).

	@class EmoteWheelScreen
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local React = require(ReplicatedStorage.Packages.React)
local ReactCharm = require(ReplicatedStorage.Packages.ReactCharm)
local CosmeticRules = require(ReplicatedStorage.Shared.Features.Cosmetic.Rules.CosmeticRules)
local EmoteWheelStore = require(ReplicatedStorage.Client.Features.Emote.State.EmoteWheelStore)
local StateSyncClientStore = require(ReplicatedStorage.Client.Features.StateSync.State.StateSyncClientStore)
local Toon = ReplicatedStorage.Client.UI.React.Screens.Toon
local ToonButton = require(Toon.ToonButton)
local ToonFlag = require(Toon.ToonFlag)
local ToonText = require(Toon.ToonText)
local ToonViewport = require(Toon.ToonViewport)
local UIToonConstants = require(Toon.UIToonConstants)
local PaperHudFrame = require(script.Parent.Parent.Paper.PaperHudFrame)
local PaperHudScaleViewModel = require(script.Parent.Parent.Paper.PaperHudScaleViewModel)
local usePaperLayout = require(script.Parent.Parent.Paper.usePaperLayout)
local usePaperViewport = require(script.Parent.Parent.Paper.usePaperViewport)
local VM = require(script.Parent.EmoteWheelViewModel)

local e = React.createElement

local COLOR = UIToonConstants.COLOR

export type EmoteWheelScreenProps = {
	onPick: (slot: number) -> (),
	onClose: () -> (),
	-- Fixed data instead of the stores (a story).
	preview: VM.View?,
	viewport: Vector2?,
}

type Nodes = { [string]: React.ReactNode }

-- The right stick's lean that counts as pointing (0-1).
local STICK_DEAD = 0.4

local function EmoteWheelScreen(props: EmoteWheelScreenProps): React.ReactNode
	local liveViewport = usePaperViewport()
	local phone = usePaperLayout() == "phone"
	local loadout = ReactCharm.useAtom(StateSyncClientStore.loadout)
	local entitlements = ReactCharm.useAtom(StateSyncClientStore.entitlements)
	local hovered = ReactCharm.useAtom(EmoteWheelStore.hovered)

	local view = props.preview
		or VM.view(loadout, function(id: string): boolean
			return CosmeticRules.owns(entitlements, id)
		end)
	local viewport = props.viewport or liveViewport
	local scale = PaperHudScaleViewModel.scale(viewport, if phone then "phone" else "desktop")
	local radius = if phone then 120 else 190
	local slotSize = Vector2.new(if phone then 130 else 200, if phone then 56 else 82)
	local count = #view.slots

	-- The pointer: the mouse's offset from the screen's centre, or the right stick's lean.
	React.useEffect(function(): () -> ()
		local function fromMouse()
			local mouse = UserInputService:GetMouseLocation()
			local centre = workspace.CurrentCamera.ViewportSize / 2
			EmoteWheelStore.hover(VM.pick((mouse - centre) / scale, count, radius * 0.35))
		end
		local moved = UserInputService.InputChanged:Connect(function(input: InputObject)
			if input.UserInputType == Enum.UserInputType.MouseMovement then
				fromMouse()
			elseif input.KeyCode == Enum.KeyCode.Thumbstick2 then
				local lean = Vector2.new(input.Position.X, -input.Position.Y)
				EmoteWheelStore.hover(VM.pick(lean, count, STICK_DEAD))
			end
		end)
		return function()
			moved:Disconnect()
		end
	end, { count, scale, radius })

	local nodes: Nodes = {
		-- The ring: a night disc with an ink rim and a lighter inner track.
		ring = e("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(radius * 2 + slotSize.Y, radius * 2 + slotSize.Y),
			BackgroundColor3 = UIToonConstants.shade("night").base,
			BackgroundTransparency = 0.15,
			ZIndex = 1,
		}, {
			corner = e("UICorner", { CornerRadius = UDim.new(0.5, 0) }),
			stroke = e("UIStroke", { Color = COLOR.ink, Thickness = 6 }),
		}),
		middle = e("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(radius * 0.9, radius * 0.9),
			BackgroundColor3 = UIToonConstants.shade("grape").base,
			ZIndex = 2,
		}, {
			corner = e("UICorner", { CornerRadius = UDim.new(0.5, 0) }),
			stroke = e("UIStroke", { Color = COLOR.ink, Thickness = 5 }),
			face = e(ToonViewport, {
				employee = view.employee,
				framing = "head",
				context = "profile",
				position = UDim2.fromScale(0.15, 0.04),
				size = UDim2.fromScale(0.7, 0.7),
				zIndex = 3,
			}),
			name = e(ToonText, {
				text = string.upper(view.employee),
				textSize = if phone then 16 else 24,
				anchor = Vector2.new(0.5, 1),
				position = UDim2.new(0.5, 0, 1, -(if phone then 8 else 14)),
				size = UDim2.new(0.9, 0, 0, if phone then 18 else 28),
				align = "center",
				fit = true,
				zIndex = 4,
			}),
		}),
		hint = e(ToonText, {
			text = if phone then "Tap an emote" else "Let go of B on an emote, or click it",
			font = "body",
			color = COLOR.white,
			textSize = if phone then 14 else 20,
			anchor = Vector2.new(0.5, 0),
			position = UDim2.new(0.5, 0, 0.5, radius + slotSize.Y),
			size = UDim2.fromOffset(500, 28),
			align = "center",
			zIndex = 2,
		}),
	}
	for _, slot in view.slots do
		local at = VM.position(slot.slot, count, radius)
		local lit = hovered == slot.slot and not slot.empty
		nodes[`slot{slot.slot}`] = e(ToonButton, {
			variant = if slot.empty then "secondary" elseif lit then "gleam" else "grape",
			text = if slot.empty then "Empty" else slot.name,
			textSize = if phone then 15 else 24,
			selected = lit,
			disabled = slot.empty,
			anchor = Vector2.new(0.5, 0.5),
			position = UDim2.new(0.5, at.X, 0.5, at.Y),
			size = UDim2.fromOffset(slotSize.X, slotSize.Y),
			zIndex = 5,
			onActivated = function()
				if not slot.empty then
					props.onPick(slot.slot)
				end
			end,
		})
		nodes[`key{slot.slot}`] = e(ToonText, {
			text = tostring(slot.slot),
			textSize = if phone then 14 else 20,
			anchor = Vector2.new(0.5, 0.5),
			position = UDim2.new(0.5, at.X - slotSize.X / 2, 0.5, at.Y - slotSize.Y / 2),
			size = UDim2.fromOffset(28, 28),
			align = "center",
			zIndex = 7,
		})
		if slot.comingSoon then
			nodes[`soon{slot.slot}`] = e(ToonFlag, {
				text = "Soon",
				hue = "coral",
				tilt = 6,
				textSize = if phone then 11 else 15,
				anchor = Vector2.new(1, 0.5),
				position = UDim2.new(0.5, at.X + slotSize.X / 2 + 10, 0.5, at.Y - slotSize.Y / 2),
				size = UDim2.fromOffset(if phone then 52 else 76, if phone then 20 else 26),
				zIndex = 8,
			})
		end
	end

	return e("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
	}, {
		-- A click outside the ring closes it.
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

return EmoteWheelScreen
