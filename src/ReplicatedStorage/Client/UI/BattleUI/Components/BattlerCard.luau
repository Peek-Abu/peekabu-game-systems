--!strict
--[=[
	BattlerCard - Displays a battler with HP bar, name, and status.
	Clickable for target selection.
	@class BattlerCard
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Roact = require(ReplicatedStorage.Packages.Roact)

local HPBar = require(script.Parent.HPBar)
local StatusIcon = require(script.Parent.StatusIcon)

local BattlerCard = Roact.Component:extend("BattlerCard")

function BattlerCard:init()
	self:setState({
		isHovered = false,
	})
end

function BattlerCard:render()
	local battler = self.props.battler
	local isEnemy = self.props.isEnemy or false
	local isClickable = self.props.onClick ~= nil
	local isHovered = self.state.isHovered
	
	if not battler then
		return nil
	end
	
	local bgColor = if isEnemy then
		Color3.fromRGB(80, 40, 40)
	else
		Color3.fromRGB(40, 60, 100)
	
	local hoverColor = if isEnemy then
		Color3.fromRGB(120, 50, 50)
	else
		Color3.fromRGB(50, 80, 140)
	
	local props = {
		Name = battler.itemType or "Battler",
		Position = self.props.position,
		Size = UDim2.new(0, 200, 0, 140),
		BackgroundColor3 = if isHovered and isClickable then hoverColor else bgColor,
		BackgroundTransparency = 0.1,
		BorderSizePixel = 0,
		[Roact.Event.Activated] = isClickable and self.props.onClick or nil,
		[Roact.Event.MouseEnter] = isClickable and function()
			self:setState({ isHovered = true })
		end or nil,
		[Roact.Event.MouseLeave] = isClickable and function()
			self:setState({ isHovered = false })
		end or nil,
	}
	
	-- Only set AutoButtonColor for TextButton
	if isClickable then
		props.AutoButtonColor = false
	end
	
	return Roact.createElement(if isClickable then "TextButton" else "Frame", props, {
		UICorner = Roact.createElement("UICorner", {
			CornerRadius = UDim.new(0, 12),
		}),
		
		UIStroke = Roact.createElement("UIStroke", {
			Color = if isEnemy 
				then Color3.fromRGB(200, 100, 100) 
				else Color3.fromRGB(100, 150, 255),
			Thickness = if isHovered and isClickable then 3 else 2,
			Transparency = 0.3,
		}),
		
		-- Battler name
		Name = Roact.createElement("TextLabel", {
			Position = UDim2.new(0, 10, 0, 10),
			Size = UDim2.new(1, -20, 0, 25),
			BackgroundTransparency = 1,
			Text = battler.itemType or "Unknown",
			TextColor3 = Color3.fromRGB(255, 255, 255),
			TextSize = 16,
			Font = Enum.Font.GothamBold,
			TextXAlignment = Enum.TextXAlignment.Left,
		}),
		
		-- HP Bar
		HPBar = Roact.createElement(HPBar, {
			position = UDim2.new(0, 10, 0, 40),
			size = UDim2.new(1, -20, 0, 24),
			currentHp = battler.currentHp or 100,
			maxHp = battler.maxHp or 100,
		}),
		
		-- Status effects + active buffs
		StatusContainer = Roact.createElement("Frame", {
			Position = UDim2.new(0, 10, 0, 70),
			Size = UDim2.new(1, -20, 0, 60),
			BackgroundTransparency = 1,
		}, self:renderIndicators(battler.statusEffects or {}, battler.activeBuffs or {})),
		
		-- Click hint
		ClickHint = isClickable and isHovered and Roact.createElement("TextLabel", {
			Position = UDim2.new(0, 0, 1, -25),
			Size = UDim2.new(1, 0, 0, 20),
			BackgroundTransparency = 1,
			Text = "🎯 Click to Target",
			TextColor3 = Color3.fromRGB(255, 255, 100),
			TextSize = 12,
			Font = Enum.Font.GothamBold,
		}) or nil,
	})
end

function BattlerCard:renderIndicators(statusEffects: {string}, activeBuffs: {any})
	local elements = {}
	local idx = 0
	
	-- Status effects (debuffs)
	for _, status in statusEffects do
		idx += 1
		elements[`Status{idx}`] = Roact.createElement(StatusIcon, {
			status = status,
			position = UDim2.new(0, (idx - 1) * 42, 0, 0),
		})
	end
	
	-- Active buffs (green icons with hover tooltip)
	for _, buff in activeBuffs do
		idx += 1
		elements[`Buff{idx}`] = Roact.createElement(StatusIcon, {
			status = buff.name or "Buff",
			buffDesc = buff.desc,
			isBuff = true,
			position = UDim2.new(0, (idx - 1) * 42, 0, 0),
		})
	end
	
	return elements
end

return BattlerCard
