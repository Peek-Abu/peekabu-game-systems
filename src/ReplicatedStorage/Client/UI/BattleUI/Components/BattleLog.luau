--!strict
--[=[
	BattleLog - Displays recent battle messages with auto-scroll.
	@class BattleLog
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Roact = require(ReplicatedStorage.Packages.Roact)

local BattleLog = Roact.Component:extend("BattleLog")

-- Determine text color based on message content
local function getMessageColor(message: string): Color3
	-- Results
	if string.find(message, "Victory") then
		return Color3.fromRGB(255, 215, 0)
	elseif string.find(message, "Defeat") then
		return Color3.fromRGB(200, 80, 80)
	end
	-- Combat
	if string.find(message, "MISS") then
		return Color3.fromRGB(140, 140, 140)
	elseif string.find(message, "PARRIED") then
		return Color3.fromRGB(100, 220, 255)
	elseif string.find(message, "parried") then
		return Color3.fromRGB(120, 200, 230)
	end
	-- Damage
	if string.find(message, "dmg") or string.find(message, "damage") then
		return Color3.fromRGB(255, 120, 120)
	end
	-- Healing / Buffs
	if string.find(message, "healed") or string.find(message, "restored") or string.find(message, "Healed") then
		return Color3.fromRGB(100, 255, 130)
	end
	-- Buff applied
	if string.find(message, "Attack %+") or string.find(message, "Speed %+") or string.find(message, "Defense %+") then
		return Color3.fromRGB(100, 200, 255)
	end
	-- Buff / status expired
	if string.find(message, "faded") or string.find(message, "wore off") or string.find(message, "ends") then
		return Color3.fromRGB(160, 160, 180)
	end
	-- Status effects applied
	if string.find(message, "paralyzed") or string.find(message, "can't move") then
		return Color3.fromRGB(255, 220, 50)
	elseif string.find(message, "Burn") or string.find(message, "burned") then
		return Color3.fromRGB(255, 130, 60)
	elseif string.find(message, "Poison") or string.find(message, "poisoned") then
		return Color3.fromRGB(180, 100, 255)
	elseif string.find(message, "Scorch") then
		return Color3.fromRGB(255, 80, 40)
	end
	-- Passive / special triggers
	if string.find(message, "activates") or string.find(message, "transforms") then
		return Color3.fromRGB(255, 200, 80)
	end
	-- QTE
	if string.find(message, "QTE") then
		return Color3.fromRGB(255, 200, 100)
	end
	return Color3.fromRGB(210, 210, 210)
end

function BattleLog:init()
	self.scrollRef = Roact.createRef()
end

function BattleLog:didUpdate(prevProps)
	-- Auto-scroll to bottom when new messages arrive
	if self.scrollRef:getValue() then
		local scroll = self.scrollRef:getValue()
		if #(self.props.messages or {}) > #(prevProps.messages or {}) then
			task.defer(function()
				if scroll and scroll.Parent then
					scroll.CanvasPosition = Vector2.new(0, scroll.AbsoluteCanvasSize.Y)
				end
			end)
		end
	end
end

function BattleLog:render()
	local messages = self.props.messages or {}
	local logEntries = {}

	logEntries["UIListLayout"] = Roact.createElement("UIListLayout", {
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, 2),
	})

	for i, message in messages do
		logEntries[`Log{i}`] = Roact.createElement("TextLabel", {
			Size = UDim2.new(1, -10, 0, 20),
			BackgroundTransparency = 1,
			Text = message,
			TextColor3 = getMessageColor(message),
			TextSize = 13,
			Font = Enum.Font.Gotham,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Top,
			TextWrapped = true,
			AutomaticSize = Enum.AutomaticSize.Y,
			LayoutOrder = i,
		})
	end

	return Roact.createElement("Frame", {
		Name = "BattleLog",
		Position = self.props.position or UDim2.new(1, -320, 0, 20),
		Size = UDim2.new(0, 300, 0, 200),
		BackgroundColor3 = Color3.fromRGB(20, 20, 30),
		BackgroundTransparency = 0.2,
		BorderSizePixel = 0,
		ZIndex = 2,
	}, {
		UICorner = Roact.createElement("UICorner", {
			CornerRadius = UDim.new(0, 12),
		}),

		UIStroke = Roact.createElement("UIStroke", {
			Color = Color3.fromRGB(60, 60, 80),
			Thickness = 1,
			Transparency = 0.5,
		}),

		Title = Roact.createElement("TextLabel", {
			Size = UDim2.new(1, 0, 0, 30),
			BackgroundTransparency = 1,
			Text = "Battle Log",
			TextColor3 = Color3.fromRGB(200, 200, 255),
			TextSize = 16,
			Font = Enum.Font.GothamBold,
			TextXAlignment = Enum.TextXAlignment.Left,
			Position = UDim2.new(0, 10, 0, 5),
		}),

		ScrollContainer = Roact.createElement("ScrollingFrame", {
			Position = UDim2.new(0, 5, 0, 35),
			Size = UDim2.new(1, -10, 1, -40),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ScrollBarThickness = 4,
			ScrollBarImageColor3 = Color3.fromRGB(100, 100, 150),
			CanvasSize = UDim2.new(0, 0, 0, #messages * 22),
			AutomaticCanvasSize = Enum.AutomaticSize.Y,
			ScrollingDirection = Enum.ScrollingDirection.Y,
			[Roact.Ref] = self.scrollRef,
		}, logEntries),
	})
end

return BattleLog
