--!strict
--[=[
	BattleWorldUI - Root component for world-space battle UI (Billboards, Floating Text).
	
	This replaces the imperative BattleUIUtils with a declarative Roact tree.
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Roact = require(ReplicatedStorage.Packages.Roact)

local BattleSignals = require(ReplicatedStorage.Client.Signals.BattleSignals)
local BattleServiceClient = require(ReplicatedStorage.Client.Services.BattleService.BattleServiceClient)
local BattleBillboardApp = require(script.Parent.Components.BattleBillboardApp)
local BattleActionPromptApp = require(script.Parent.Components.BattleActionPromptApp)
local BattleUIUtils = require(script.Parent.BattleUIUtils)
local MoveData = require(ReplicatedStorage.Shared.Data.MoveData)
local UIConstants = require(ReplicatedStorage.Shared.Classes.Constants.UIConstants)

local BattleWorldUI = Roact.Component:extend("BattleWorldUI")

function BattleWorldUI:init()
	local current = BattleServiceClient:getCurrentBattle()
	
	self:setState({
		isInBattle = current ~= nil,
		allies = current and current.allies or {},
		enemies = current and current.enemies or {},
		activeActorIndex = BattleServiceClient:getActiveActorIndex() or Roact.None,
		promptingAction = BattleServiceClient:getCurrentPrompt() or Roact.None,
	})
	
	self._connections = {}
end

function BattleWorldUI:didMount()
	table.insert(self._connections, BattleSignals.BattleStarted:Connect(function(data)
		self:setState({
			isInBattle = true,
			allies = data.allies or {},
			enemies = data.enemies or {},
			-- Preserve existing actor/prompt if they were set via init() from persistent service state
			activeActorIndex = self.state.activeActorIndex,
			promptingAction = self.state.promptingAction,
		})
	end))

	table.insert(self._connections, BattleSignals.StateChanged:Connect(function(data)
		if data.allies then self:setState({ allies = data.allies }) end
		if data.enemies then self:setState({ enemies = data.enemies }) end
	end))

	table.insert(self._connections, BattleSignals.ActionPrompted:Connect(function(data)
		self:setState({
			promptingAction = data, -- { battlerIndex, availableMoves }
			activeActorIndex = data.battlerIndex,
		})
	end))

	table.insert(self._connections, BattleSignals.MoveStarted:Connect(function(data)
		self:setState({
			activeActorIndex = data.actorIndex,
			promptingAction = Roact.None,
		})
	end))

	table.insert(self._connections, BattleSignals.ActionExecuted:Connect(function(data)
		self:setState({ activeActorIndex = Roact.None })
		self:handleActionOutcome(data)
	end))

	table.insert(self._connections, BattleSignals.BattleEnded:Connect(function()
		self:setState({
			isInBattle = false,
			allies = {},
			enemies = {},
			activeActorIndex = Roact.None,
			promptingAction = Roact.None,
		})
	end))
end

function BattleWorldUI:willUnmount()
	for _, conn in self._connections do
		conn:Disconnect()
	end
end

function BattleWorldUI:resolveModel(battler: any, index: number): Model?
	return BattleServiceClient:getModelForIndex(index)
end

function BattleWorldUI:handleActionOutcome(data: any)
	local targetBattler = self:getBattlerByIndex(data.targetIndex)
	local targetModel = targetBattler and self:resolveModel(targetBattler, data.targetIndex)
	
	local actorBattler = self:getBattlerByIndex(data.actorIndex)
	local actorModel = actorBattler and self:resolveModel(actorBattler, data.actorIndex)

	local dmgColor = Color3.fromRGB(210, 210, 210)
	if data.actionType == "status" then
		dmgColor = UIConstants.getStatusColor(data.moveName)
	elseif data.moveName then
		local info = MoveData[data.moveName]
		if info then dmgColor = UIConstants.getElementColor(info.element) end
	end

	local qte = data.qteResult or ""
	if qte:find("Dodge") then
		BattleUIUtils.spawnFloatingText(targetModel, "DODGE", Color3.fromRGB(80, 220, 255))
	elseif qte:find("Parry") then
		BattleUIUtils.spawnFloatingText(targetModel, "PARRY", Color3.fromRGB(120, 180, 255))
	elseif not data.hit then
		BattleUIUtils.spawnFloatingText(targetModel, "MISS", Color3.fromRGB(170, 170, 170))
	elseif data.damage and data.damage > 0 then
		BattleUIUtils.spawnFloatingText(targetModel, tostring(data.damage), dmgColor)
	end

	if data.healing and data.healing > 0 then
		BattleUIUtils.spawnFloatingText(actorModel, `+{data.healing}`, Color3.fromRGB(80, 225, 80))
	end
	if data.statusApplied and data.statusApplied ~= "" then
		local sColor = UIConstants.getStatusColor(data.statusApplied)
		BattleUIUtils.spawnFloatingText(targetModel, data.statusApplied .. "!", sColor, 6)
	end
end

function BattleWorldUI:getBattlerByIndex(index: number): any?
	local allies = self.state.allies or {}
	local enemies = self.state.enemies or {}
	local allyCount = #allies
	if index <= allyCount then
		return allies[index]
	else
		return enemies[index - allyCount]
	end
end

function BattleWorldUI:render()
	if not self.state.isInBattle then return nil end

	local allies = self.state.allies or {}
	local enemies = self.state.enemies or {}
	local children = {}
	
	-- Render Billboards for Allies
	for i, battler in ipairs(allies) do
		local model = self:resolveModel(battler, i)
		if model then
			local attachPart = model:FindFirstChild("Head") or model:FindFirstChild("HumanoidRootPart")
			if attachPart then
				children["AllyBillboard_"..i] = Roact.createElement(BattleBillboardApp, {
					battler      = battler,
					adornee      = attachPart,
					isActiveTurn = self.state.activeActorIndex == i,
					studsOffset  = attachPart.Name == "Head" and Vector3.new(0, 1.5, 0) or Vector3.new(0, 4.0, 0),
				})
			end
		end
	end

	-- Render Billboards for Enemies
	local allyOffset = #allies
	for i, battler in ipairs(enemies) do
		local globalIdx = allyOffset + i
		local model = self:resolveModel(battler, globalIdx)
		if model then
			local attachPart = model:FindFirstChild("Head") or model:FindFirstChild("HumanoidRootPart")
			if attachPart then
				children["EnemyBillboard_"..i] = Roact.createElement(BattleBillboardApp, {
					battler      = battler,
					adornee      = attachPart,
					isActiveTurn = self.state.activeActorIndex == globalIdx,
					studsOffset  = attachPart.Name == "Head" and Vector3.new(0, 1.5, 0) or Vector3.new(0, 4.0, 0),
				})
			end
		end
	end

	-- Render Action Prompt if active
	local prompt = self.state.promptingAction
	if prompt and prompt ~= Roact.None then
		local activeBattler = allies[prompt.battlerIndex]
		if activeBattler then
			local model = self:resolveModel(activeBattler, prompt.battlerIndex)
			if model then
				local hrp = model:FindFirstChild("HumanoidRootPart")
				if hrp then
					-- Create target selection entries
					local enemyEntries = {}
					for ei, enemy in ipairs(enemies) do
						table.insert(enemyEntries, {
							battler = enemy,
							enemyIdx = ei,
						})
					end

					children["ActionPrompt"] = Roact.createElement(BattleActionPromptApp, {
						adornee = hrp,
						availableMoves = prompt.availableMoves,
						enemyEntries = enemyEntries,
						onSubmit = function()
							self:setState({ promptingAction = Roact.None })
						end,
					})
				end
			end
		end
	end

	return Roact.createElement("Folder", { Name = "BattleWorldUI" }, children)
end

return BattleWorldUI
