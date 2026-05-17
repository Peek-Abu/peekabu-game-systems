--!strict
--[=[
	StatusIcon - A single status effect icon with hover tooltip.
	@class StatusIcon
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Roact = require(ReplicatedStorage.Packages.Roact)

local StatusIcon = Roact.Component:extend("StatusIcon")

-- Status effect display config: color, abbreviation, description
local STATUS_DISPLAY = {
	Burn = {
		color = Color3.fromRGB(255, 100, 50),
		abbr = "BRN",
		desc = "Burn: Takes 1/16 maxHP damage each round (5 rounds)",
	},
	Poison = {
		color = Color3.fromRGB(160, 80, 220),
		abbr = "PSN",
		desc = "Poison: Takes 1/8 maxHP damage each round (5 rounds)",
	},
	Paralysis = {
		color = Color3.fromRGB(255, 220, 50),
		abbr = "PAR",
		desc = "Paralysis: 25% chance to skip turn (3 rounds)",
	},
	Scorch = {
		color = Color3.fromRGB(255, 60, 20),
		abbr = "SCH",
		desc = "Scorch: +15% Fire damage taken (4 rounds)",
	},
}

local DEFAULT_DISPLAY = {
	color = Color3.fromRGB(150, 150, 150),
	abbr = "???",
	desc = "Unknown status effect",
}

function StatusIcon:init()
	self:setState({ hovered = false })
end

function StatusIcon:render()
	local status = self.props.status
	local isBuff = self.props.isBuff
	local buffDesc = self.props.buffDesc

	-- Determine display properties
	local color, abbr, desc
	if isBuff then
		-- Buff: green-tinted, use first few chars of name as abbreviation
		color = Color3.fromRGB(60, 180, 100)
		-- Create a short abbreviation from the buff name
		-- e.g. "Attack +10%" -> "ATK", "Speed +10%" -> "SPD"
		if string.find(status, "Attack") then
			abbr = "ATK"
		elseif string.find(status, "Speed") then
			abbr = "SPD"
		elseif string.find(status, "Defense") then
			abbr = "DEF"
		else
			abbr = string.sub(status, 1, 3):upper()
		end
		desc = buffDesc or status
	else
		-- Status effect: use lookup table
		local display = STATUS_DISPLAY[status] or DEFAULT_DISPLAY
		color = display.color
		abbr = display.abbr
		if abbr == "???" then
			abbr = string.sub(status, 1, 3):upper()
		end
		desc = display.desc or status
	end

	return Roact.createElement("TextButton", {
		Position = self.props.position,
		Size = UDim2.new(0, 38, 0, 30),
		BackgroundColor3 = color,
		BackgroundTransparency = 0.2,
		BorderSizePixel = 0,
		Text = "",
		AutoButtonColor = false,
		[Roact.Event.MouseEnter] = function()
			self:setState({ hovered = true })
		end,
		[Roact.Event.MouseLeave] = function()
			self:setState({ hovered = false })
		end,
	}, {
		UICorner = Roact.createElement("UICorner", {
			CornerRadius = UDim.new(0, 6),
		}),
		Label = Roact.createElement("TextLabel", {
			Size = UDim2.new(1, 0, 1, 0),
			BackgroundTransparency = 1,
			Text = abbr,
			TextColor3 = Color3.fromRGB(255, 255, 255),
			TextSize = 11,
			Font = Enum.Font.GothamBold,
		}),
		-- Tooltip (visible on hover)
		Tooltip = self.state.hovered and Roact.createElement("TextLabel", {
			Position = UDim2.new(0.5, 0, 1, 4),
			AnchorPoint = Vector2.new(0.5, 0),
			Size = UDim2.new(0, 180, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundColor3 = Color3.fromRGB(30, 30, 40),
			BackgroundTransparency = 0.05,
			BorderSizePixel = 0,
			Text = desc,
			TextColor3 = Color3.fromRGB(220, 220, 220),
			TextSize = 11,
			Font = Enum.Font.Gotham,
			TextWrapped = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			ZIndex = 20,
		}, {
			UICorner = Roact.createElement("UICorner", {
				CornerRadius = UDim.new(0, 6),
			}),
			UIPadding = Roact.createElement("UIPadding", {
				PaddingLeft = UDim.new(0, 6),
				PaddingRight = UDim.new(0, 6),
				PaddingTop = UDim.new(0, 4),
				PaddingBottom = UDim.new(0, 4),
			}),
		}) or nil,
	})
end

return StatusIcon
