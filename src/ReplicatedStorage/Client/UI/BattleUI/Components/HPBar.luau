--!strict
--[=[
	HPBar - Animated HP bar with current/max display.
	@class HPBar
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Roact = require(ReplicatedStorage.Packages.Roact)

local HPBar = Roact.Component:extend("HPBar")

function HPBar:render()
	local currentHp = self.props.currentHp or 100
	local maxHp = self.props.maxHp or 100
	local hpPercent = math.clamp(currentHp / maxHp, 0, 1)
	
	-- Color based on HP percentage
	local barColor = if hpPercent > 0.5 then
		Color3.fromRGB(80, 200, 100) -- Green
	elseif hpPercent > 0.25 then
		Color3.fromRGB(255, 200, 50) -- Yellow
	else
		Color3.fromRGB(255, 80, 80) -- Red
	
	return Roact.createElement("Frame", {
		Name = "HPBar",
		Position = self.props.position or UDim2.new(0, 0, 0, 0),
		Size = self.props.size or UDim2.new(1, 0, 0, 24),
		BackgroundColor3 = Color3.fromRGB(40, 40, 50),
		BorderSizePixel = 0,
	}, {
		UICorner = Roact.createElement("UICorner", {
			CornerRadius = UDim.new(0, 6),
		}),
		
		-- HP fill
		Fill = Roact.createElement("Frame", {
			Size = UDim2.new(hpPercent, 0, 1, 0),
			BackgroundColor3 = barColor,
			BorderSizePixel = 0,
		}, {
			UICorner = Roact.createElement("UICorner", {
				CornerRadius = UDim.new(0, 6),
			}),
		}),
		
		-- HP text
		HPText = Roact.createElement("TextLabel", {
			Size = UDim2.new(1, 0, 1, 0),
			BackgroundTransparency = 1,
			Text = `{currentHp}/{maxHp} HP`,
			TextColor3 = Color3.fromRGB(255, 255, 255),
			TextSize = 14,
			Font = Enum.Font.GothamBold,
			TextStrokeTransparency = 0.5,
			ZIndex = 2,
		}),
	})
end

return HPBar
