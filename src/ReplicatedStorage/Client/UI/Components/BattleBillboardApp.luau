--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Roact = require(ReplicatedStorage.Packages.Roact)
local UIConstants = require(ReplicatedStorage.Shared.Classes.Constants.UIConstants)

local BUFF_COLOR = Color3.fromRGB(80, 160, 255)

local function getHPColor(ratio: number): Color3
	if ratio > 0.5 then
		return Color3.fromRGB(60, 210, 80)
	elseif ratio > 0.25 then
		return Color3.fromRGB(240, 190, 50)
	else
		return Color3.fromRGB(220, 60, 60)
	end
end

local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local StatusChip = require(script.Parent.StatusChip)
local BattleBillboardApp = Roact.Component:extend("BattleBillboardApp")

function BattleBillboardApp:init()
	self:setState({
		hoveredChip = nil, -- { text = string, desc = string? }
	})
	self.mousePos, self.updateMousePos = Roact.createBinding(UDim2.fromOffset(0, 0))
end

function BattleBillboardApp:didMount()
	self.runServiceConn = RunService.RenderStepped:Connect(function()
		if self.state.hoveredChip then
			local mousePos = UserInputService:GetMouseLocation()
			self.updateMousePos(UDim2.fromOffset(mousePos.X + 15, mousePos.Y + 15))
		end
	end)
end

function BattleBillboardApp:willUnmount()
	if self.runServiceConn then
		self.runServiceConn:Disconnect()
		self.runServiceConn = nil
	end
end

function BattleBillboardApp:render()
	local props = self.props
	local state = self.state

	local adornee = props.adornee
	local isAlly = props.battler.isAlly
	local curHp = props.battler.currentHp or props.battler.maxHp or 100
	local maxHp = props.battler.maxHp or 100
	local ratio = maxHp > 0 and math.clamp(curHp / maxHp, 0, 1) or 1
	local characterId = props.battler.characterId or "?"
	local isActiveTurn = props.isActiveTurn or false
	
	local statuses = props.battler.statusEffects or {}
	local durations = props.battler.statusDurations or {}
	local buffs = props.battler.activeBuffs or {}

	-- Build status chips
	local chipElements = {
		Layout = Roact.createElement("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 3),
		}),
	}
	
	local shown = 0
	for i, statusName in ipairs(statuses) do
		if shown >= 4 then break end
		local color = UIConstants.getStatusColor(statusName)
		local rounds = durations[statusName] or 0
		local desc = rounds > 0 and `{rounds} Round{rounds == 1 and "" or "s"} Remaining` or "Status ailment"
		chipElements["Status_"..i] = self:renderChip(statusName, color, desc)
		shown += 1
	end
	
	for i, buff in ipairs(buffs) do
		if shown >= 4 then break end
		local bName = type(buff) == "table" and (buff.name or "?") or tostring(buff)
		local bDesc = type(buff) == "table" and buff.desc or nil
		
		if type(buff) == "table" and buff.duration and buff.duration > 0 then
			local bRounds = `{buff.duration} Round{buff.duration == 1 and "" or "s"} Remaining`
			bDesc = bDesc and `{bDesc}\n{bRounds}` or bRounds
		end
		
		chipElements["Buff_"..i] = self:renderChip(bName, BUFF_COLOR, bDesc)
		shown += 1
	end

	return Roact.createFragment({
		Billboard = Roact.createElement("BillboardGui", {
			Active = true,
			Adornee = adornee,
			Size = UDim2.fromOffset(210, 64),
			SizeOffset = Vector2.new(0, 0.5),
			StudsOffset = props.studsOffset or Vector3.new(0, 1.5, 0),
			AlwaysOnTop = false,
			MaxDistance = 80,
			ClipsDescendants = false,
			ResetOnSpawn = false,
		}, {
			BG = Roact.createElement("Frame", {
				Size = UDim2.fromOffset(210, 64),
				BackgroundColor3 = Color3.fromRGB(12, 12, 18),
				BackgroundTransparency = 0.18,
				BorderSizePixel = 0,
			}, {
				Corner = Roact.createElement("UICorner", { CornerRadius = UDim.new(0, 8) }),
				Stroke = Roact.createElement("UIStroke", {
					Color = isAlly and Color3.fromRGB(80, 160, 255) or Color3.fromRGB(255, 100, 80),
					Thickness = 1.5,
					Transparency = 0.4,
				}),
				
				NameLabel = Roact.createElement("TextLabel", {
					Size = UDim2.fromOffset(200, 18),
					Position = UDim2.fromOffset(6, 5),
					BackgroundTransparency = 1,
					Text = characterId,
					TextColor3 = isAlly and Color3.fromRGB(110, 200, 255) or Color3.fromRGB(255, 130, 110),
					TextSize = 13,
					Font = Enum.Font.GothamBold,
					TextXAlignment = Enum.TextXAlignment.Left,
				}),
				
				TurnIndicator = Roact.createElement("Frame", {
					Size = UDim2.fromOffset(54, 15),
					Position = UDim2.fromOffset(152, 4),
					BackgroundColor3 = Color3.fromRGB(255, 215, 0),
					BackgroundTransparency = isActiveTurn and 0.65 or 1,
					BorderSizePixel = 0,
				}, {
					Corner = Roact.createElement("UICorner", { CornerRadius = UDim.new(0, 4) }),
					Label = Roact.createElement("TextLabel", {
						Size = UDim2.fromOffset(54, 15),
						BackgroundTransparency = 1,
						Text = "▶ TURN",
						TextColor3 = Color3.fromRGB(30, 20, 5),
						TextSize = 10,
						Font = Enum.Font.GothamBold,
						TextTransparency = isActiveTurn and 0 or 1,
					})
				}),
				
				HPBarBG = Roact.createElement("Frame", {
					Size = UDim2.fromOffset(200, 13),
					Position = UDim2.fromOffset(5, 27),
					BackgroundColor3 = Color3.fromRGB(75, 75, 88),
					BorderSizePixel = 0,
				}, {
					Corner = Roact.createElement("UICorner", { CornerRadius = UDim.new(0, 3) }),
					Fill = Roact.createElement("Frame", {
						Size = UDim2.fromOffset(math.floor(200 * ratio), 13),
						BackgroundColor3 = getHPColor(ratio),
						BorderSizePixel = 0,
					}, {
						Corner = Roact.createElement("UICorner", { CornerRadius = UDim.new(0, 3) })
					}),
					Label = Roact.createElement("TextLabel", {
						Size = UDim2.fromOffset(196, 13),
						Position = UDim2.fromOffset(2, 0),
						ZIndex = 2,
						BackgroundTransparency = 1,
						Text = `{math.max(0, math.floor(curHp))}/{math.floor(maxHp)}`,
						TextColor3 = Color3.fromRGB(255, 255, 255),
						TextSize = 9,
						Font = Enum.Font.GothamBold,
						TextStrokeColor3 = Color3.fromRGB(0, 0, 0),
						TextStrokeTransparency = 0.35,
						TextXAlignment = Enum.TextXAlignment.Right,
					})
				}),
				
				StatusRow = Roact.createElement("Frame", {
					Size = UDim2.fromOffset(200, 16),
					Position = UDim2.fromOffset(5, 46),
					BackgroundTransparency = 1,
					ClipsDescendants = false,
				}, chipElements)
			})
		}),
		
		Tooltip = self:renderTooltip()
	})
end

function BattleBillboardApp:renderChip(text: string, color: Color3, desc: string?)
	return Roact.createElement(StatusChip, {
		text = text,
		color = color,
		onHoverEnter = function()
			self:setState({
				hoveredChip = { text = text, desc = desc }
			})
		end,
		onHoverLeave = function()
			if self.state.hoveredChip and self.state.hoveredChip.text == text then
				self:setState({ hoveredChip = Roact.None })
			end
		end,
	})
end

function BattleBillboardApp:renderTooltip()
	local hover = self.state.hoveredChip
	if not hover then return nil end

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
				Color = Color3.fromRGB(100, 150, 255),
				Thickness = 1,
				Transparency = 0.5,
			}),
			Padding = Roact.createElement("UIPadding", {
				PaddingTop = UDim.new(0, 8),
				PaddingBottom = UDim.new(0, 8),
				PaddingLeft = UDim.new(0, 10),
				PaddingRight = UDim.new(0, 10),
			}),
			Layout = Roact.createElement("UIListLayout", {
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0, 4),
			}),
			Title = Roact.createElement("TextLabel", {
				AutomaticSize = Enum.AutomaticSize.XY,
				BackgroundTransparency = 1,
				Text = hover.text,
				TextColor3 = Color3.fromRGB(230, 240, 255),
				TextSize = 14,
				Font = Enum.Font.GothamBold,
				LayoutOrder = 1,
			}),
			Desc = hover.desc and Roact.createElement("TextLabel", {
				AutomaticSize = Enum.AutomaticSize.Y,
				Size = UDim2.fromOffset(180, 0),
				BackgroundTransparency = 1,
				Text = hover.desc,
				TextColor3 = Color3.fromRGB(180, 190, 210),
				TextSize = 12,
				Font = Enum.Font.Gotham,
				TextWrapped = true,
				TextXAlignment = Enum.TextXAlignment.Left,
				LayoutOrder = 2,
			}) or nil
		})
	})
end

return BattleBillboardApp
