--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Roact = require(ReplicatedStorage.Packages.Roact)
local MoveData = require(ReplicatedStorage.Shared.Data.MoveData)
local BattleEvents = require(ReplicatedStorage.Shared.Events.BattleEvents)
local UIConstants = require(ReplicatedStorage.Shared.Classes.Constants.UIConstants)

local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local ElementBadge = require(script.Parent.ElementBadge)

local CARDS_PER_PAGE = 5

local BattleActionPromptApp = Roact.Component:extend("BattleActionPromptApp")

function BattleActionPromptApp:init()
	self:setState({
		page = 1,
		selectedMove = nil, -- nil means showing moves. string means showing target select.
		hoveredMove = nil, -- { name = string, info = any }
	})
	self.mousePos, self.updateMousePos = Roact.createBinding(UDim2.fromOffset(0, 0))
end

function BattleActionPromptApp:didMount()
	self.runServiceConn = RunService.RenderStepped:Connect(function()
		if self.state.hoveredMove then
			local mousePos = UserInputService:GetMouseLocation()
			self.updateMousePos(UDim2.fromOffset(mousePos.X + 15, mousePos.Y + 15))
		end
	end)
end

function BattleActionPromptApp:willUnmount()
	if self.runServiceConn then
		self.runServiceConn:Disconnect()
		self.runServiceConn = nil
	end
end

function BattleActionPromptApp:render()
	local props = self.props
	local state = self.state

	local hrp = props.adornee
	local availableMoves = props.availableMoves or {}
	local enemyEntries = props.enemyEntries or {}
	local enemyCount = #enemyEntries

	-- Phase 2: Target Select
	if state.selectedMove then
		return self:renderTargetSelect(hrp, state.selectedMove, enemyEntries)
	end
	
	-- Phase 1: Move List
	local totalMoves = #availableMoves
	local totalPages = math.max(1, math.ceil(totalMoves / CARDS_PER_PAGE))
	local page = math.clamp(state.page, 1, totalPages)
	
	local hasPrev = page > 1
	local hasNext = page < totalPages
	
	local startI = (page - 1) * CARDS_PER_PAGE + 1
	local endI = math.min(startI + CARDS_PER_PAGE - 1, totalMoves)
	local pageCards = {}
	for i = startI, endI do
		table.insert(pageCards, availableMoves[i])
	end
	
	local navCount = (hasPrev and 1 or 0) + (hasNext and 1 or 0)
	local totalSlots = #pageCards + navCount
	local spacing = 3.6 -- Reduced from variable spacing (4.4-5.8) to bring cards closer
	local baseY = 3.2 -- Increased from 3.8 to move above character heads
	
	local children = {
		Tooltip = self:renderTooltip()
	}
	local slot = 0
	
	if hasPrev then
		slot += 1
		children["PrevArrow"] = self:renderNavCard("◄", slot, totalSlots, spacing, baseY, hrp, function()
			self:setState({ page = state.page - 1 })
		end)
	end
	
	for i, moveName in ipairs(pageCards) do
		slot += 1
		children["Move_"..i] = self:renderMoveCard(moveName, slot, totalSlots, spacing, baseY, hrp, function()
			if enemyCount <= 1 then
				BattleEvents.packets.SubmitAction.send({
					actionType = "move",
					moveName = moveName,
					targetIndex = 1,
				})
				if props.onSubmit then props.onSubmit() end
			else
				self:setState({ selectedMove = moveName })
			end
		end)
	end
	
	if hasNext then
		slot += 1
		children["NextArrow"] = self:renderNavCard("►", slot, totalSlots, spacing, baseY, hrp, function()
			self:setState({ page = state.page + 1 })
		end)
	end
	
	return Roact.createFragment(children)
end

function BattleActionPromptApp:renderNavCard(icon: string, slotIndex: number, totalSlots: number, spacing: number, baseY: number, hrp: any, onClick: () -> ())
	local xOffset = (slotIndex - (totalSlots + 1) / 2) * spacing
	local maxExtent = spacing * math.max(totalSlots - 1, 1) / 2
	local normalizedX = math.abs(xOffset) / (maxExtent + 0.001)
	local yOffset = baseY - normalizedX * 4.5 -- Reduced arc depth
	local id = "Nav_" .. icon
	local isHovered = self.state.hoveredMove and self.state.hoveredMove.name == id
	
	return Roact.createElement("BillboardGui", {
		Adornee = hrp,
		Size = UDim2.fromOffset(54, 84),
		StudsOffset = Vector3.new(xOffset, yOffset, 0),
		AlwaysOnTop = false,
		MaxDistance = 80,
		ResetOnSpawn = false,
		Active = true,
	}, {
		Card = Roact.createElement("Frame", {
			Size = UDim2.fromOffset(54, 84),
			BackgroundColor3 = isHovered and Color3.fromRGB(20, 30, 60) or Color3.fromRGB(10, 16, 30),
			BackgroundTransparency = 0.08,
			BorderSizePixel = 0,
		}, {
			Corner = Roact.createElement("UICorner", { CornerRadius = UDim.new(0, 8) }),
			Stroke = Roact.createElement("UIStroke", {
				Color = Color3.fromRGB(100, 140, 220),
				Thickness = 2,
				Transparency = 0.4,
			}),
			Icon = Roact.createElement("TextLabel", {
				Size = UDim2.fromOffset(54, 84),
				BackgroundTransparency = 1,
				Text = icon,
				TextColor3 = Color3.fromRGB(180, 210, 255),
				TextSize = 22,
				Font = Enum.Font.GothamBold,
			}),
			Button = Roact.createElement("TextButton", {
				Size = UDim2.fromOffset(54, 84),
				BackgroundTransparency = 1,
				Text = "",
				ZIndex = 10,
				[Roact.Event.MouseEnter] = function() self:setState({ hoveredMove = { name = id } }) end,
				[Roact.Event.MouseLeave] = function() self:setState({ hoveredMove = Roact.None }) end,
				[Roact.Event.Activated] = onClick,
			})
		})
	})
end

function BattleActionPromptApp:renderMoveCard(moveName: string, slotIndex: number, totalSlots: number, spacing: number, baseY: number, hrp: any, onClick: () -> ())
	local xOffset = (slotIndex - (totalSlots + 1) / 2) * spacing
	local maxExtent = spacing * math.max(totalSlots - 1, 1) / 2
	local normalizedX = math.abs(xOffset) / (maxExtent + 0.001)
	local yOffset = baseY - normalizedX * 5 -- Reduced arc depth
	local id = moveName
	local isHovered = self.state.hoveredMove and self.state.hoveredMove.name == id
	
	local info = MoveData[moveName]
	local elemColor = UIConstants.getElementColor(info and info.element)
	local power = info and info.power or 0
	local category = info and info.category or ""
	local element = info and info.element or "?"
	
	return Roact.createElement("BillboardGui", {
		Adornee = hrp,
		Size = UDim2.fromOffset(130, 84),
		StudsOffset = Vector3.new(xOffset, yOffset, 0),
		AlwaysOnTop = false,
		MaxDistance = 80,
		ResetOnSpawn = false,
		Active = true,
	}, {
		Card = Roact.createElement("Frame", {
			Size = UDim2.fromOffset(130, 84),
			BackgroundColor3 = isHovered and Color3.fromRGB(20, 30, 60) or Color3.fromRGB(10, 16, 30),
			BackgroundTransparency = 0.08,
			BorderSizePixel = 0,
		}, {
			Corner = Roact.createElement("UICorner", { CornerRadius = UDim.new(0, 8) }),
			Stroke = Roact.createElement("UIStroke", {
				Color = elemColor,
				Thickness = 2,
				Transparency = isHovered and 0 or 0.4,
			}),
			Accent = Roact.createElement("Frame", {
				Size = UDim2.fromOffset(130, 4),
				BackgroundColor3 = elemColor,
				BorderSizePixel = 0,
			}, {
				Corner = Roact.createElement("UICorner", { CornerRadius = UDim.new(0, 8) })
			}),
			Title = Roact.createElement("TextLabel", {
				Size = UDim2.fromOffset(122, 24),
				Position = UDim2.fromOffset(4, 8),
				BackgroundTransparency = 1,
				Text = moveName,
				TextColor3 = Color3.fromRGB(235, 235, 255),
				TextSize = 12,
				Font = Enum.Font.GothamBold,
				TextXAlignment = Enum.TextXAlignment.Center,
			}),
			BadgeContainer = Roact.createElement(ElementBadge, {
				element = element,
				size = UDim2.fromOffset(60, 16),
				position = UDim2.fromOffset(35, 34),
			}),
			Footer = Roact.createElement("TextLabel", {
				Size = UDim2.fromOffset(122, 14),
				Position = UDim2.fromOffset(4, 67),
				BackgroundTransparency = 1,
				Text = power > 0 and `PWR {power}` or category,
				TextColor3 = Color3.fromRGB(190, 195, 220),
				TextSize = 9,
				Font = Enum.Font.Gotham,
				TextStrokeColor3 = Color3.fromRGB(0, 0, 0),
				TextStrokeTransparency = 0.5,
				TextXAlignment = Enum.TextXAlignment.Center,
			}),
			Button = Roact.createElement("TextButton", {
				Size = UDim2.fromOffset(130, 84),
				BackgroundTransparency = 1,
				Text = "",
				ZIndex = 10,
				[Roact.Event.MouseEnter] = function() self:setState({ hoveredMove = { name = id, info = info } }) end,
				[Roact.Event.MouseLeave] = function() self:setState({ hoveredMove = Roact.None }) end,
				[Roact.Event.Activated] = onClick,
			})
		})
	})
end

function BattleActionPromptApp:renderTargetSelect(hrp: any, moveName: string, enemyEntries: {any})
	local rowH = 46
	local panelH = #enemyEntries * rowH + 52
	
	local children = {
		Title = Roact.createElement("TextLabel", {
			Size = UDim2.fromOffset(248, 32),
			Position = UDim2.fromOffset(0, 4),
			BackgroundTransparency = 1,
			Text = "🎯 Select Target",
			TextColor3 = Color3.fromRGB(200, 220, 255),
			TextSize = 13,
			Font = Enum.Font.GothamBold,
		}),
		Divider = Roact.createElement("Frame", {
			Size = UDim2.fromOffset(232, 1),
			Position = UDim2.fromOffset(8, 36),
			BackgroundColor3 = Color3.fromRGB(80, 100, 160),
			BackgroundTransparency = 0.5,
			BorderSizePixel = 0,
		})
	}
	
	for i, entry in ipairs(enemyEntries) do
		local name = entry.battler.characterId or `Target {entry.enemyIdx}`
		local id = "Target_"..i
		local isHovered = self.state.hoveredMove and self.state.hoveredMove.name == id
		
		children["TargetBtn_"..i] = Roact.createElement("TextButton", {
			Size = UDim2.fromOffset(232, rowH - 8),
			Position = UDim2.fromOffset(8, 40 + (i - 1) * rowH),
			BackgroundColor3 = isHovered and Color3.fromRGB(90, 35, 35) or Color3.fromRGB(55, 20, 20),
			BorderSizePixel = 0,
			Text = "",
			AutoButtonColor = false,
			[Roact.Event.MouseEnter] = function() self:setState({ hoveredMove = { name = id } }) end,
			[Roact.Event.MouseLeave] = function() self:setState({ hoveredMove = Roact.None }) end,
			[Roact.Event.Activated] = function()
				BattleEvents.packets.SubmitAction.send({
					actionType = "move",
					moveName = moveName,
					targetIndex = entry.enemyIdx,
				})
				if self.props.onSubmit then self.props.onSubmit() end
			end,
		}, {
			Corner = Roact.createElement("UICorner", { CornerRadius = UDim.new(0, 6) }),
			Label = Roact.createElement("TextLabel", {
				Size = UDim2.fromOffset(220, 38),
				Position = UDim2.fromOffset(12, 0),
				BackgroundTransparency = 1,
				Text = name,
				TextColor3 = Color3.fromRGB(255, 130, 110),
				TextSize = 13,
				Font = Enum.Font.GothamBold,
				TextXAlignment = Enum.TextXAlignment.Left,
			})
		})
	end
	
	return Roact.createFragment({
		Billboard = Roact.createElement("BillboardGui", {
			Adornee = hrp,
			Size = UDim2.fromOffset(248, panelH),
			StudsOffset = Vector3.new(0, 1.5, 0),
			AlwaysOnTop = false,
			MaxDistance = 80,
			ResetOnSpawn = false,
			Active = true,
		}, {
			BG = Roact.createElement("Frame", {
				Size = UDim2.fromOffset(248, panelH),
				BackgroundColor3 = Color3.fromRGB(10, 16, 30),
				BackgroundTransparency = 0.08,
				BorderSizePixel = 0,
			}, {
				Corner = Roact.createElement("UICorner", { CornerRadius = UDim.new(0, 10) }),
				Stroke = Roact.createElement("UIStroke", {
					Color = Color3.fromRGB(100, 150, 255),
					Thickness = 2,
					Transparency = 0.35,
				}),
				Content = Roact.createFragment(children)
			})
		})
	})
end

function BattleActionPromptApp:renderTooltip()
	local hover = self.state.hoveredMove
	if not hover or not hover.info then return nil end
	
	local info = hover.info
	local name = hover.name
	local desc = info.description or "No description available."
	local category = info.category or "Physical"
	local element = info.element or "Normal"
	local power = info.power or 0
	local accuracy = info.accuracy or 100

	return Roact.createElement("ScreenGui", {
		ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		DisplayOrder = 100,
		IgnoreGuiInset = true,
	}, {
		Container = Roact.createElement("Frame", {
			Position = self.mousePos,
			AutomaticSize = Enum.AutomaticSize.XY,
			BackgroundColor3 = Color3.fromRGB(15, 18, 25),
			BackgroundTransparency = 0.05,
			BorderSizePixel = 0,
		}, {
			Corner = Roact.createElement("UICorner", { CornerRadius = UDim.new(0, 6) }),
			Stroke = Roact.createElement("UIStroke", {
				Color = UIConstants.getElementColor(element),
				Thickness = 1.5,
				Transparency = 0.3,
			}),
			Padding = Roact.createElement("UIPadding", {
				PaddingTop = UDim.new(0, 10),
				PaddingBottom = UDim.new(0, 10),
				PaddingLeft = UDim.new(0, 12),
				PaddingRight = UDim.new(0, 12),
			}),
			Layout = Roact.createElement("UIListLayout", {
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0, 6),
			}),
			Header = Roact.createElement("Frame", {
				AutomaticSize = Enum.AutomaticSize.XY,
				BackgroundTransparency = 1,
				LayoutOrder = 1,
			}, {
				Layout = Roact.createElement("UIListLayout", {
					FillDirection = Enum.FillDirection.Horizontal,
					SortOrder = Enum.SortOrder.LayoutOrder,
					VerticalAlignment = Enum.VerticalAlignment.Center,
					Padding = UDim.new(0, 10),
				}),
				Title = Roact.createElement("TextLabel", {
					AutomaticSize = Enum.AutomaticSize.XY,
					BackgroundTransparency = 1,
					Text = name,
					TextColor3 = Color3.fromRGB(255, 255, 255),
					TextSize = 16,
					Font = Enum.Font.GothamBold,
					LayoutOrder = 1,
				}),
				Badge = Roact.createElement(ElementBadge, {
					element = element,
					size = UDim2.fromOffset(60, 18),
					LayoutOrder = 2,
				})
			}),
			StatsRow = Roact.createElement("TextLabel", {
				AutomaticSize = Enum.AutomaticSize.XY,
				BackgroundTransparency = 1,
				Text = `Type: {category}  |  Power: {power > 0 and power or "--"}  |  Acc: {accuracy}%`,
				TextColor3 = Color3.fromRGB(180, 200, 255),
				TextSize = 12,
				Font = Enum.Font.GothamBold,
				LayoutOrder = 2,
			}),
			Divider = Roact.createElement("Frame", {
				Size = UDim2.new(1, 0, 0, 1),
				BackgroundColor3 = Color3.fromRGB(80, 100, 160),
				BackgroundTransparency = 0.6,
				BorderSizePixel = 0,
				LayoutOrder = 3,
			}),
			Description = Roact.createElement("TextLabel", {
				AutomaticSize = Enum.AutomaticSize.Y,
				Size = UDim2.fromOffset(250, 0),
				BackgroundTransparency = 1,
				Text = desc,
				TextColor3 = Color3.fromRGB(200, 210, 230),
				TextSize = 13,
				Font = Enum.Font.Gotham,
				TextWrapped = true,
				TextXAlignment = Enum.TextXAlignment.Left,
				LayoutOrder = 4,
			})
		})
	})
end

return BattleActionPromptApp
