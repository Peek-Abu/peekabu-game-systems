--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage.Packages.React)
local VM = require(script.Parent.Parent.Shift.ShiftReviewViewModel)
local COLOR = require(script.Parent.UIPaperConstants).COLOR
local function PaperAwardIcon(props: { title: string }): React.ReactNode
	local nodes: { [string]: React.ReactNode } = {}
	for index, part in VM.shapesForAward(props.title) do
		nodes[tostring(index)] = React.createElement("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale((part.x + part.w / 2) / 64, (part.y + part.h / 2) / 64),
			Size = UDim2.fromScale(part.w / 64, part.h / 64),
			Rotation = part.rotation,
			BackgroundColor3 = COLOR[part.color],
			BorderSizePixel = 0,
			ZIndex = index + 3,
		}, { corner = React.createElement("UICorner", { CornerRadius = UDim.new(part.round / 2, 0) }) })
	end
	return React.createElement("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1 }, nodes)
end
return PaperAwardIcon
