--!strict
--[=[
	MoveButton - Interactive button for selecting moves.
	Displays move name, element type badge, power, and category.
	@class MoveButton
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Roact = require(ReplicatedStorage.Packages.Roact)

local UIConstants = require(ReplicatedStorage.Shared.Classes.Constants.UIConstants)

local CATEGORY_COLOR: { [string]: Color3 } = {
	Physical = Color3.fromRGB(200, 80,  60),
	Magic    = Color3.fromRGB(120, 100, 220),
	Buff     = Color3.fromRGB(70,  180, 120),
	Heal     = Color3.fromRGB(80,  210, 80),
	Status   = Color3.fromRGB(180, 130, 220),
	Special  = Color3.fromRGB(200, 170, 50),
}

local function elementColor(element: string?): Color3
	return UIConstants.getElementColor(element)
end

local MoveButton = Roact.Component:extend("MoveButton")

function MoveButton:init()
	self:setState({ isHovered = false })
end

function MoveButton:render()
	local isSelected = self.props.isSelected or false
	local isHovered  = self.state.isHovered
	local moveInfo   = self.props.moveInfo  -- { element, power, category, description }

	local element  = moveInfo and moveInfo.element  or "Normal"
	local power    = moveInfo and moveInfo.power    or 0
	local category = moveInfo and moveInfo.category or "Physical"
	local desc     = moveInfo and moveInfo.description or ""

	local elemColor = elementColor(element)
	local catColor  = CATEGORY_COLOR[category] or Color3.fromRGB(160, 160, 160)

	local bgColor = if isSelected then
		Color3.fromRGB(35, 55, 100)
	elseif isHovered then
		Color3.fromRGB(30, 50, 90)
	else
		Color3.fromRGB(22, 35, 65)

	return Roact.createElement("TextButton", {
		Name            = self.props.moveName,
		Position        = self.props.position,
		Size            = UDim2.new(1, -20, 0, 62),
		BackgroundColor3 = bgColor,
		BorderSizePixel = 0,
		Text            = "",
		AutoButtonColor = false,
		[Roact.Event.Activated] = self.props.onClick,
		[Roact.Event.MouseEnter] = function() self:setState({ isHovered = true }) end,
		[Roact.Event.MouseLeave] = function() self:setState({ isHovered = false }) end,
	}, {
		UICorner = Roact.createElement("UICorner", { CornerRadius = UDim.new(0, 10) }),

		UIStroke = Roact.createElement("UIStroke", {
			Color       = isSelected and Color3.fromRGB(150, 200, 255) or elemColor,
			Thickness   = isSelected and 2.5 or 1.5,
			Transparency = isSelected and 0 or 0.5,
		}),

		-- Left colour accent bar (element colour)
		AccentBar = Roact.createElement("Frame", {
			Size            = UDim2.new(0, 5, 1, 0),
			BackgroundColor3 = elemColor,
			BorderSizePixel = 0,
		}, {
			UICorner = Roact.createElement("UICorner", { CornerRadius = UDim.new(0, 4) }),
		}),

		-- Move name
		MoveName = Roact.createElement("TextLabel", {
			Position         = UDim2.new(0, 14, 0, 6),
			Size             = UDim2.new(1, -120, 0, 22),
			BackgroundTransparency = 1,
			Text             = self.props.moveName,
			TextColor3       = Color3.fromRGB(240, 240, 255),
			TextSize         = 17,
			Font             = Enum.Font.GothamBold,
			TextXAlignment   = Enum.TextXAlignment.Left,
		}),

		-- Short description
		Desc = Roact.createElement("TextLabel", {
			Position         = UDim2.new(0, 14, 0, 30),
			Size             = UDim2.new(1, -120, 0, 18),
			BackgroundTransparency = 1,
			Text             = desc,
			TextColor3       = Color3.fromRGB(160, 160, 180),
			TextSize         = 11,
			Font             = Enum.Font.Gotham,
			TextXAlignment   = Enum.TextXAlignment.Left,
			TextTruncate     = Enum.TextTruncate.AtEnd,
		}),

		-- Element badge (top-right)
		ElementBadge = Roact.createElement("Frame", {
			Position         = UDim2.new(1, -110, 0, 6),
			Size             = UDim2.new(0, 60, 0, 20),
			BackgroundColor3 = elemColor,
			BorderSizePixel  = 0,
		}, {
			UICorner = Roact.createElement("UICorner", { CornerRadius = UDim.new(0, 5) }),
			Label = Roact.createElement("TextLabel", {
				Size             = UDim2.new(1, 0, 1, 0),
				BackgroundTransparency = 1,
				Text             = element,
				TextColor3       = Color3.fromRGB(255, 255, 255),
				TextSize         = 11,
				Font             = Enum.Font.GothamBold,
			}),
		}),

		-- Category badge (below element)
		CategoryBadge = Roact.createElement("Frame", {
			Position         = UDim2.new(1, -110, 0, 30),
			Size             = UDim2.new(0, 60, 0, 18),
			BackgroundColor3 = catColor,
			BorderSizePixel  = 0,
		}, {
			UICorner = Roact.createElement("UICorner", { CornerRadius = UDim.new(0, 4) }),
			Label = Roact.createElement("TextLabel", {
				Size             = UDim2.new(1, 0, 1, 0),
				BackgroundTransparency = 1,
				Text             = category,
				TextColor3       = Color3.fromRGB(255, 255, 255),
				TextSize         = 10,
				Font             = Enum.Font.GothamBold,
			}),
		}),

		-- Power label (far right)
		PowerLabel = power > 0 and Roact.createElement("TextLabel", {
			Position         = UDim2.new(1, -48, 0, 50),
			Size             = UDim2.new(0, 44, 0, 14),
			BackgroundTransparency = 1,
			Text             = `PWR {power}`,
			TextColor3       = Color3.fromRGB(200, 200, 200),
			TextSize         = 10,
			Font             = Enum.Font.Gotham,
			TextXAlignment   = Enum.TextXAlignment.Right,
		}) or nil,
	})
end

return MoveButton
