--!strict
--[=[
	ChatWheelButtons: on touch screens only, one round "talk" HUD button on the right edge (clear of the stick, the jump
	button and Roblox's corners), phone Layout 2 (owner pick 11-15: chat and emotes share one button). Tapping opens
	the chat wheel (as T does); the wheel's EMOTES button swaps to the emote wheel and back (ChatWheelScreen /
	EmoteWheelScreen `onSwap`). Presentational (exempt): the callback opens the wheel.

	@class ChatWheelButtons
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local React = require(ReplicatedStorage.Packages.React)
local Toon = ReplicatedStorage.Client.UI.React.Screens.Toon
local ToonButton = require(Toon.ToonButton)

local e = React.createElement

export type ChatWheelButtonsProps = {
	onTalk: () -> (),
}

local SIZE = 64

local function ChatWheelButtons(props: ChatWheelButtonsProps): React.ReactNode
	if not UserInputService.TouchEnabled then
		return nil
	end
	return e("Frame", {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -12, 0.42, 0),
		Size = UDim2.fromOffset(SIZE, SIZE),
		BackgroundTransparency = 1,
	}, {
		talk = e(ToonButton, {
			variant = "sky",
			icon = "stickers",
			radius = SIZE // 2,
			size = UDim2.fromOffset(SIZE, SIZE),
			onActivated = props.onTalk,
		}),
	})
end

return ChatWheelButtons
