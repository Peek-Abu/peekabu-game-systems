--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")

local Roact = require(ReplicatedStorage.Packages.Roact)
local CharacterSignals = require(ReplicatedStorage.Client.Signals.CharacterSignals)
local UIConstants = require(ReplicatedStorage.Shared.Classes.Constants.UIConstants)

local CharacterSelectUI = Roact.Component:extend("CharacterSelectUI")

function CharacterSelectUI:init()
	self:setState({
		characters = {} :: { any },
		selectedId = nil :: string?,
		visible = true,
	})

	local CharacterSelectionService = require(ReplicatedStorage.Client.Services.CharacterSelectionService.CharacterSelectionServiceClient)
	self:setState({ characters = CharacterSelectionService:getAvailableCharacters() })

	-- Connect to signals
	self._charListen = CharacterSignals.CharactersLoaded:Connect(function(chars)
		self:setState({ characters = chars })
	end)

	self._resultListen = CharacterSignals.SelectionResult:Connect(function(data)
		if data.success then
			self:setState({ selectedId = data.characterId, visible = false })
		end
	end)
end

function CharacterSelectUI:willUnmount()
	if self._charListen then self._charListen:Disconnect() end
	if self._resultListen then self._resultListen:Disconnect() end
end

function CharacterSelectUI:_buildCharacterCard(char: any, index: number)
	local isSelected = self.state.selectedId == char.id
	local elementColor = UIConstants.getElementColor(char.element)

	return Roact.createElement("TextButton", {
		Size = UDim2.new(0, 160, 0, 200),
		BackgroundColor3 = if isSelected then Color3.fromRGB(60, 90, 60) else Color3.fromRGB(35, 35, 50),
		BorderSizePixel = 0,
		AutoButtonColor = true,
		LayoutOrder = index,
		[Roact.Event.Activated] = function()
			local CharacterSelectionService = require(ReplicatedStorage.Client.Services.CharacterSelectionService.CharacterSelectionServiceClient)
			CharacterSelectionService:selectCharacter(char.id)
		end,
	}, {
		UICorner = Roact.createElement("UICorner", { CornerRadius = UDim.new(0, 10) }),

		UIStroke = Roact.createElement("UIStroke", {
			Color = if isSelected then Color3.fromRGB(100, 255, 100) else elementColor,
			Thickness = if isSelected then 2 else 1,
			Transparency = if isSelected then 0 else 0.5,
		}),

		CharName = Roact.createElement("TextLabel", {
			Position = UDim2.new(0, 0, 0, 120),
			Size = UDim2.new(1, 0, 0, 28),
			BackgroundTransparency = 1,
			Text = char.name,
			TextColor3 = Color3.fromRGB(255, 255, 255),
			TextSize = 20,
			Font = Enum.Font.GothamBold,
		}),

		Title = Roact.createElement("TextLabel", {
			Position = UDim2.new(0, 0, 0, 148),
			Size = UDim2.new(1, 0, 0, 20),
			BackgroundTransparency = 1,
			Text = char.title,
			TextColor3 = Color3.fromRGB(180, 180, 200),
			TextSize = 13,
			Font = Enum.Font.Gotham,
		}),

		Element = Roact.createElement("TextLabel", {
			Position = UDim2.new(0, 0, 0, 170),
			Size = UDim2.new(1, 0, 0, 20),
			BackgroundTransparency = 1,
			Text = char.element,
			TextColor3 = elementColor,
			TextSize = 12,
			Font = Enum.Font.GothamBold,
		}),

		-- Placeholder portrait area
		Portrait = Roact.createElement("Frame", {
			Position = UDim2.new(0.5, -45, 0, 10),
			Size = UDim2.new(0, 90, 0, 100),
			BackgroundColor3 = elementColor,
			BackgroundTransparency = 0.7,
		}, {
			UICorner = Roact.createElement("UICorner", { CornerRadius = UDim.new(0, 8) }),
			Initial = Roact.createElement("TextLabel", {
				Size = UDim2.new(1, 0, 1, 0),
				BackgroundTransparency = 1,
				Text = string.sub(char.name, 1, 1),
				TextColor3 = Color3.fromRGB(255, 255, 255),
				TextSize = 40,
				Font = Enum.Font.GothamBold,
			}),
		}),
	})
end

function CharacterSelectUI:render()
	if not self.state.visible then
		return nil
	end

	local cards = {}
	cards["UIGridLayout"] = Roact.createElement("UIGridLayout", {
		CellSize = UDim2.new(0, 160, 0, 200),
		CellPadding = UDim2.new(0, 12, 0, 12),
		SortOrder = Enum.SortOrder.LayoutOrder,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
	})

	for i, char in self.state.characters do
		cards[char.id] = self:_buildCharacterCard(char, i)
	end

	return Roact.createElement("ScreenGui", {
		ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	}, {
		Backdrop = Roact.createElement("Frame", {
			Size = UDim2.new(1, 0, 1, 0),
			BackgroundColor3 = Color3.fromRGB(10, 10, 20),
			BackgroundTransparency = 0.3,
		}),

		Container = Roact.createElement("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0.5, 0, 0.5, 0),
			Size = UDim2.new(0, 720, 0, 500),
			BackgroundColor3 = Color3.fromRGB(20, 20, 35),
			BackgroundTransparency = 0.1,
		}, {
			UICorner = Roact.createElement("UICorner", { CornerRadius = UDim.new(0, 16) }),

			UIStroke = Roact.createElement("UIStroke", {
				Color = Color3.fromRGB(80, 80, 120),
				Thickness = 2,
			}),

			Title = Roact.createElement("TextLabel", {
				Position = UDim2.new(0, 0, 0, 15),
				Size = UDim2.new(1, 0, 0, 40),
				BackgroundTransparency = 1,
				Text = "Choose Your Fighter",
				TextColor3 = Color3.fromRGB(255, 255, 255),
				TextSize = 28,
				Font = Enum.Font.GothamBold,
			}),

			CardContainer = Roact.createElement("ScrollingFrame", {
				Position = UDim2.new(0, 20, 0, 65),
				Size = UDim2.new(1, -40, 1, -80),
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				ScrollBarThickness = 4,
				ScrollBarImageColor3 = Color3.fromRGB(100, 100, 150),
				AutomaticCanvasSize = Enum.AutomaticSize.Y,
				ScrollingDirection = Enum.ScrollingDirection.Y,
			}, cards),
		}),
	})
end

return CharacterSelectUI
