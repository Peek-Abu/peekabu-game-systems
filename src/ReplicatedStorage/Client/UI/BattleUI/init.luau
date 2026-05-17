--!strict
--[=[
	Battle UI - Complete battle interface with state display, action selection, and QTE interactions.
	
	Features:
	- HP bars with animations
	- Team/enemy battler display
	- Move selection with target picking
	- QTE timing bars and button prompts
	- Battle log with auto-scroll
	- Victory/defeat screens
	
	@class BattleUI
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Roact = require(ReplicatedStorage.Packages.Roact)

-- Only require these if not in story mode (checked in init)
local BattleSignals
local BattleEvents

-- Sub-components
local HPBar = require(script.Components.HPBar)
local BattlerCard = require(script.Components.BattlerCard)
local MoveButton = require(script.Components.MoveButton)
local QTEPrompt = require(script.Components.QTEPrompt)
local BattleLog = require(script.Components.BattleLog)
local MoveData = require(ReplicatedStorage.Shared.Data.MoveData)

local BattleUI = Roact.Component:extend("BattleUI")

function BattleUI:init()
	self:setState({
		-- Battle state
        isInBattle = self.props.isInBattle or false,
		battleResult = self.props.battleResult or nil, -- "VICTORY" | "DEFEAT" | nil
		
		-- Battlers
        allies = self.props.allies or {},
        enemies = self.props.enemies or {},
		
		-- Action prompt
		isPromptingAction = self.props.isPromptingAction or false,
		availableMoves = self.props.availableMoves or {},
		selectedMove = nil,
		selectingTarget = false,
		
		-- QTE
		qteActive = false,
		qteType = nil,
		qteStartTime = 0,
		qteDuration = 0,
		qteWindowStart = 0,
		qteWindowEnd = 0,
		
		-- Battle log
		battleLog = self.props.battleLog or {},
	})
	
	self._connections = {}
	
	-- Skip signal connections in story mode
	if self.props.storyMode then
		return
	end
	
	-- Load signals only when needed (not in story mode)
	if not BattleSignals then
		BattleSignals = require(ReplicatedStorage.Client.Signals.BattleSignals)
		BattleEvents = require(ReplicatedStorage.Shared.Events.BattleEvents)
	end
	
	-- Battle start
	table.insert(self._connections, BattleSignals.BattleStarted:Connect(function(data)
		self:setState({
			-- Battle state
			isInBattle = true,
			battleResult = Roact.None,
			
			-- Battlers
			allies = data.allies or {},
			enemies = data.enemies or {},
			
			-- Don't reset isPromptingAction here - ActionPrompted will set it
			-- Reset other prompts
			selectedMove = Roact.None,
			selectingTarget = false,
			
			-- Reset QTE
			qteActive = false,
			qteType = nil,
			qteStartTime = 0,
			qteDuration = 0,
			qteWindowStart = 0,
			qteWindowEnd = 0,
			
			-- Fresh log
			battleLog = {},
		})
	end))
	
	-- Action prompt
	table.insert(self._connections, BattleSignals.ActionPrompted:Connect(function(data)
		self:setState({
			isPromptingAction = true,
			availableMoves = data.availableMoves or {},
			selectedMove = nil,
			selectingTarget = false,
		})
	end))
	
	-- Reaction/QTE prompt - DISABLED: reactions are now animation-based with keyboard input (Q/E)
	-- No UI should show - players time their dodge/parry based on attack animations
	-- table.insert(self._connections, BattleSignals.ReactionPrompted:Connect(function(data)
	-- 	self:setState({
	-- 		qteActive = true,
	-- 		qteType = data.reactionType,
	-- 		qteStartTime = tick(),
	-- 		qteDuration = data.duration or 2,
	-- 		qteWindowStart = data.windowStart or 0.3,
	-- 		qteWindowEnd = data.windowEnd or 0.7,
	-- 	})
	-- 	self:addLog(`QTE: {data.reactionType}!`)
	-- end))
	
	-- Server-sent log entries (status applied, buffs, passives, etc.)
	table.insert(self._connections, BattleSignals.BattleLog:Connect(function(data)
		self:addLog(data.message)
	end))
	
	-- State change (HP updates, etc.)
	table.insert(self._connections, BattleSignals.StateChanged:Connect(function(data)
		if data.allies then
			self:setState({ allies = data.allies })
		end
		if data.enemies then
			self:setState({ enemies = data.enemies })
		end
	end))
	
	-- Battle end
	table.insert(self._connections, BattleSignals.BattleEnded:Connect(function(data)
		local endResult = data.result
		self:setState({
			battleResult = endResult, -- "VICTORY" or "DEFEAT"
			isPromptingAction = false,
			qteActive = false,
		})
		self:addLog(endResult == "VICTORY" and "Victory!" or "Defeat...")
		
		-- Auto-close after 3 seconds, but only if still showing same result
		task.delay(3, function()
			-- Only close if we're still showing the same battle result
			-- (prevents closing if a new battle started)
			if self.state.battleResult == endResult then
				self:setState({ isInBattle = false, battleResult = Roact.None, allies = {}, enemies = {}, battleLog = {} })
			end
		end)
	end))
end

function BattleUI:addLog(message: string)
	local log = table.clone(self.state.battleLog)
	table.insert(log, message)
	-- Keep last 25 messages (scrollable)
	if #log > 25 then
		table.remove(log, 1)
	end
	self:setState({ battleLog = log })
end

function BattleUI:willUnmount()
	for _, connection in self._connections do
		connection:Disconnect()
	end
end

function BattleUI:render()
	if not self.state.isInBattle then
		return nil
	end

	local children = {
		-- Background overlay
		Overlay = Roact.createElement("Frame", {
			Size = UDim2.new(1, 0, 1, 0),
			BackgroundColor3 = Color3.fromRGB(0, 0, 0),
			BackgroundTransparency = 0.85,
			BorderSizePixel = 0,
		}),
		
		-- Vignette effect (darker edges)
		Vignette = Roact.createElement("ImageLabel", {
			Size = UDim2.new(1, 0, 1, 0),
			BackgroundTransparency = 1,
			Image = "rbxasset://textures/ui/VignetteGui.png",
			ImageTransparency = 0.5,
			ScaleType = Enum.ScaleType.Slice,
			SliceCenter = Rect.new(0, 0, 0, 0),
		}),

		-- Top: Enemy team
		EnemyTeam = self:renderTeam("Enemies", self.state.enemies, UDim2.new(0.5, -200, 0, 20)),

		-- Bottom: Ally team
		AllyTeam = self:renderTeam("Your Team", self.state.allies, UDim2.new(0.5, -200, 1, -220)),

		-- Battle log (top-right)
		BattleLog = Roact.createElement(BattleLog, {
			messages = self.state.battleLog,
			position = UDim2.new(1, -320, 0, 20),
		}),

		-- Action prompt (center-bottom)
		ActionPrompt = self.state.isPromptingAction and self:renderActionPrompt(),

		-- QTE prompt DISABLED - reactions are animation-based with keyboard input (Q/E)
		-- QTEPrompt = self.state.qteActive and Roact.createElement(QTEPrompt, {...})

		-- Victory/Defeat screen
		ResultScreen = self.state.battleResult and self:renderResultScreen(),
	}
	
	-- In story mode, return Frame instead of ScreenGui
	if self.props.storyMode then
		return Roact.createElement("Frame", {
			Name = "BattleUI",
			Size = UDim2.new(1, 0, 1, 0),
			BackgroundTransparency = 1,
		}, children)
	end
	
	return Roact.createElement("ScreenGui", {
		Name = "BattleUI",
		ResetOnSpawn = false,
		Enabled = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		DisplayOrder = 10,
	}, children)
end

function BattleUI:renderTeam(teamName: string, battlers: {any}, position: UDim2)
	local battlerCards = {}
	
	for i, battler in battlers do
		battlerCards[`Battler{i}`] = Roact.createElement(BattlerCard, {
			battler = battler,
			position = UDim2.new(0, (i - 1) * 210, 0, 40),
			isEnemy = teamName == "Enemies",
			onClick = self.state.selectingTarget and function()
				self:selectTarget(i)
			end or nil,
		})
	end
	
	return Roact.createElement("Frame", {
		Name = teamName,
		Position = position,
		Size = UDim2.new(0, 400, 0, 180),
		BackgroundTransparency = 1,
	}, {
		Label = Roact.createElement("TextLabel", {
			Size = UDim2.new(1, 0, 0, 30),
			BackgroundTransparency = 1,
			Text = teamName,
			TextColor3 = if teamName == "Enemies" 
				then Color3.fromRGB(255, 100, 100) 
				else Color3.fromRGB(100, 200, 255),
			TextSize = 20,
			Font = Enum.Font.GothamBold,
			TextXAlignment = Enum.TextXAlignment.Left,
		}),
		
		BattlerContainer = Roact.createElement("Frame", {
			Position = UDim2.new(0, 0, 0, 35),
			Size = UDim2.new(1, 0, 1, -35),
			BackgroundTransparency = 1,
		}, battlerCards),
	})
end

function BattleUI:renderActionPrompt()
	local moveButtons = {}
	local rowH = 72  -- 62px button + 10px gap

	for i, moveName in self.state.availableMoves do
		local moveInfo = MoveData[moveName]  -- nil for unknown moves = graceful fallback
		moveButtons[`Move{i}`] = Roact.createElement(MoveButton, {
			moveName   = moveName,
			moveInfo   = moveInfo,
			position   = UDim2.new(0, 10, 0, (i - 1) * rowH + 10),
			isSelected = self.state.selectedMove == moveName,
			onClick = function()
				self:selectMove(moveName)
			end,
		})
	end

	local title = if self.state.selectingTarget
		then `🎯 Select Target for {self.state.selectedMove}`
		else "⚔️ Choose Your Move"

	local panelH = math.min(#self.state.availableMoves * rowH + 80, 380)

	return Roact.createElement("Frame", {
		Name             = "ActionPrompt",
		AnchorPoint      = Vector2.new(0.5, 1),
		Position         = UDim2.new(0.5, 0, 1, 0),
		Size             = UDim2.new(0, 520, 0, panelH),
		BackgroundColor3 = Color3.fromRGB(18, 20, 32),
		BackgroundTransparency = 0.05,
		BorderSizePixel  = 0,
		ZIndex           = 5,
	}, {
		UICorner = Roact.createElement("UICorner", {
			CornerRadius = UDim.new(0, 16),
		}),

		UIStroke = Roact.createElement("UIStroke", {
			Color        = Color3.fromRGB(100, 150, 255),
			Thickness    = 2,
			Transparency = 0.4,
		}),

		Title = Roact.createElement("TextLabel", {
			Size             = UDim2.new(1, 0, 0, 56),
			BackgroundTransparency = 1,
			Text             = title,
			TextColor3       = Color3.fromRGB(240, 240, 255),
			TextSize         = 21,
			Font             = Enum.Font.GothamBold,
		}),

		MovesContainer = Roact.createElement("ScrollingFrame", {
			Position             = UDim2.new(0, 0, 0, 56),
			Size                 = UDim2.new(1, 0, 1, -56),
			BackgroundTransparency = 1,
			BorderSizePixel      = 0,
			ScrollBarThickness   = 4,
			ScrollBarImageColor3 = Color3.fromRGB(100, 100, 150),
			CanvasSize           = UDim2.new(0, 0, 0, #self.state.availableMoves * rowH + 10),
			ScrollingDirection   = Enum.ScrollingDirection.Y,
		}, moveButtons),
	})
end

function BattleUI:renderResultScreen()
	local isVictory = self.state.battleResult == "VICTORY"
	
	return Roact.createElement("Frame", {
		Name = "ResultScreen",
		Size = UDim2.new(1, 0, 1, 0),
		BackgroundColor3 = Color3.fromRGB(0, 0, 0),
		BackgroundTransparency = 0.5,
		BorderSizePixel = 0,
		ZIndex = 100,
	}, {
		ResultCard = Roact.createElement("Frame", {
			Position = UDim2.new(0.5, -300, 0.5, -150),
			Size = UDim2.new(0, 600, 0, 300),
			BackgroundColor3 = if isVictory 
				then Color3.fromRGB(50, 150, 80) 
				else Color3.fromRGB(150, 50, 50),
			BorderSizePixel = 0,
		}, {
			UICorner = Roact.createElement("UICorner", {
				CornerRadius = UDim.new(0, 20),
			}),
			
			Title = Roact.createElement("TextLabel", {
				Size = UDim2.new(1, 0, 0, 100),
				BackgroundTransparency = 1,
				Text = if isVictory then "🎉 VICTORY!" else "💀 DEFEAT",
				TextColor3 = Color3.fromRGB(255, 255, 255),
				TextSize = 48,
				Font = Enum.Font.GothamBold,
			}),

			Message = Roact.createElement("TextLabel", {
				Position = UDim2.new(0, 0, 0, 100),
				Size = UDim2.new(1, 0, 1, -100),
				BackgroundTransparency = 1,
				Text = if isVictory 
					then "You won the battle!" 
					else "Better luck next time...",
				TextColor3 = Color3.fromRGB(255, 255, 255),
				TextSize = 24,
				Font = Enum.Font.Gotham,
			}),
		}),
	})
end

-- Action submission methods
function BattleUI:selectMove(moveName: string)
	self:setState({
		selectedMove = moveName,
		selectingTarget = true,
	})
end

function BattleUI:selectTarget(targetIndex: number)
	if not self.state.selectedMove then return end

	BattleEvents.packets.SubmitAction.send({
		actionType = "move",
		moveName = self.state.selectedMove,
		targetIndex = targetIndex,
	})

	self:setState({
		isPromptingAction = false,
		selectedMove = nil,
		selectingTarget = false,
	})
end

function BattleUI:submitReaction(accuracy: number)
	BattleEvents.packets.SubmitReaction.send({
		reactionType = self.state.qteType,
		accuracy = accuracy,
		timeDelta = tick() - self.state.qteStartTime,
	})

	self:setState({
		qteActive = false,
	})
end

return BattleUI
