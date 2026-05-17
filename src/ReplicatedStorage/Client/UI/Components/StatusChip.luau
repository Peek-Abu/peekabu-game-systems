--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Roact = require(ReplicatedStorage.Packages.Roact)

local UIConstants = require(ReplicatedStorage.Shared.Classes.Constants.UIConstants)

local function StatusChip(props: {
	text: string,
	color: Color3?,
	onHoverEnter: () -> (),
	onHoverLeave: () -> (),
})
	local color = props.color or UIConstants.getStatusColor(props.text)

	return Roact.createElement("TextButton", {
		Size = UDim2.fromOffset(44, 14),
		BackgroundColor3 = color,
		BorderSizePixel = 0,
		Text = "",
		AutoButtonColor = false,
		[Roact.Event.MouseEnter] = props.onHoverEnter,
		[Roact.Event.MouseLeave] = props.onHoverLeave,
	}, {
		Corner = Roact.createElement("UICorner", { CornerRadius = UDim.new(0, 3) }),
		Label = Roact.createElement("TextLabel", {
			Size = UDim2.fromOffset(44, 14),
			BackgroundTransparency = 1,
			Text = props.text:upper(),
			TextColor3 = Color3.fromRGB(255, 255, 255),
			TextSize = 8,
			Font = Enum.Font.GothamBold,
			TextStrokeTransparency = 0.4,
		})
	})
end

return StatusChip
