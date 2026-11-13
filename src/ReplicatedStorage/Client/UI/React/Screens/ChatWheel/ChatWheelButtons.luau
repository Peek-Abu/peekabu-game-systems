--!strict
--[=[
	ChatWheelButtons: on touch screens only, two round HUD buttons on the right edge (clear of the stick, the jump
	button and Roblox's corners): Emotes (the emote wheel, as B does) and Chat (the chat wheel, as T does). Tapping
	opens the wheel; a slot is then tapped to send. Presentational (exempt): the callbacks open the wheels.

	@class ChatWheelButtons
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local React = require(ReplicatedStorage.Packages.React)
local Toon = ReplicatedStorage.Client.UI.React.Screens.Toon
local ToonButton = require(Toon.ToonButton)

local e = React.createElement

export type ChatWheelButtonsProps = {
	onEmotes: () -> (),
	onChat: () -> (),
}

local SIZE = 64
local GAP = 12

local function ChatWheelButtons(props: ChatWheelButtonsProps): React.ReactNode
	if not UserInputService.TouchEnabled then
		return nil
	end
	return e("Frame", {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -12, 0.42, 0),
		Size = UDim2.fromOffset(SIZE, SIZE * 2 + GAP),
		BackgroundTransparency = 1,
	}, {
		emotes = e(ToonButton, {
			variant = "grape",
			icon = "pippaHappy",
			radius = SIZE // 2,
			size = UDim2.fromOffset(SIZE, SIZE),
			onActivated = props.onEmotes,
		}),
		chat = e(ToonButton, {
			variant = "sky",
			icon = "stickers",
			radius = SIZE // 2,
			position = UDim2.fromOffset(0, SIZE + GAP),
			size = UDim2.fromOffset(SIZE, SIZE),
			onActivated = props.onChat,
		}),
	})
end

return ChatWheelButtons
