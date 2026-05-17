--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Roact = require(ReplicatedStorage.Packages.Roact)

local UIConstants = require(ReplicatedStorage.Shared.Classes.Constants.UIConstants)
local TypeConstants = require(ReplicatedStorage.Shared.Classes.Constants.TypeConstants)

local function ElementBadge(props: { element: TypeConstants.ElementType?, size: UDim2, position: UDim2? })
	local element = props.element or TypeConstants.ELEMENTS.NEUTRAL
	local color = UIConstants.getElementColor(element)

	return Roact.createElement("Frame", {
		Size = props.size,
		Position = props.position or UDim2.fromScale(0.5, 0.5),
		AnchorPoint = props.position and Vector2.new(0, 0) or Vector2.new(0.5, 0.5),
		BackgroundColor3 = color,
		BorderSizePixel = 0,
	}, {
		Corner = Roact.createElement("UICorner", { CornerRadius = UDim.new(0, 4) }),
		Label = Roact.createElement("TextLabel", {
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			Text = element:upper(),
			TextColor3 = Color3.fromRGB(255, 255, 255),
			TextSize = 10,
			Font = Enum.Font.GothamBold,
		})
	})
end

return ElementBadge
