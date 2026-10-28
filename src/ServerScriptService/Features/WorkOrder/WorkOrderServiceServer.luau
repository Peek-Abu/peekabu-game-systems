--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local WorkOrderShared = ReplicatedStorage.Shared.Features.WorkOrder
local Registry = require(WorkOrderShared.Data.WorkOrderRegistry)
local Rules = require(WorkOrderShared.Rules.WorkOrderRules)
local PlayerDataTypes = require(ReplicatedStorage.Shared.Data.PlayerDataTypes)
local Data = require(ServerScriptService.Features.PlayerData.PlayerDataServiceServer)
local Slices = require(ServerScriptService.Features.PlayerData.Systems.PlayerDataSliceSystem)
local Toast = require(ServerScriptService.Features.Toast.ToastServiceServer)
local Currency = require(ServerScriptService.Features.Currency.CurrencyServiceServer)
local slice = Slices.registerAccount("workOrder", { day = 0, progress = 0, claimed = false }, function(account)
	return account.workOrder
end, Rules.validate)
local CREDIT: PlayerDataTypes.CurrencyType = "credits"
local clock: () -> number = os.time
local stoppers: { () -> () } = {}
local function roll(userId: number)
	local now = clock()
	slice.mutate(userId, function(state)
		local nextState = Rules.roll(state, now)
		if state.day == nextState.day then
			return false
		end
		state.day = nextState.day
		state.progress = 0
		state.claimed = false
		return true
	end)
end
export type WorkOrderServiceServer = {
	dependencies: { string },
	init: (self: WorkOrderServiceServer) -> (),
	stop: (self: WorkOrderServiceServer) -> (),
	get: (self: WorkOrderServiceServer, userId: number) -> PlayerDataTypes.WorkOrder?,
	record: (self: WorkOrderServiceServer, player: Player, kind: Registry.Kind, amount: number) -> boolean,
	_setClock: (self: WorkOrderServiceServer, nextClock: (() -> number)?) -> (),
}
local Service: WorkOrderServiceServer = {
	dependencies = { "PlayerDataServiceServer", "CurrencyServiceServer", "ToastServiceServer" },
	init = function(_self)
		local connection = Data.profileLoaded:Connect(roll)
		table.insert(stoppers, function()
			connection:Disconnect()
		end)
		for _, player in Players:GetPlayers() do
			roll(player.UserId)
		end
	end,
	stop = function(_self)
		for _, stop in stoppers do
			stop()
		end
		table.clear(stoppers)
	end,
	get = function(_self, userId)
		local state = slice.get(userId)
		return if state then Rules.roll(state, clock()) else nil
	end,
	record = function(_self, player, kind, amount)
		-- Only server gameplay calls this method; there is deliberately no client progress packet.
		if amount <= 0 or amount >= math.huge or amount ~= math.floor(amount) then
			return false
		end
		local now = clock()
		local order = Registry.orderFor(now)
		if kind ~= order.kind then
			return false
		end
		local stored = slice.get(player.UserId)
		if stored == nil then
			return false
		end
		local preview = Rules.roll(stored, now)
		if preview.claimed then
			return false
		end
		local completes = preview.progress + amount >= order.target
		local operations: { Data.TransactionOperation } = {
			slice.op(player.UserId, function(state)
				local current = Rules.roll(state, now)
				if current.claimed then
					return false
				end
				-- Reward ops were prepared from this snapshot; reject a changed snapshot instead of mispaying.
				if current.progress ~= preview.progress then
					return false
				end
				state.day = current.day
				state.progress = math.min(order.target, current.progress + amount)
				state.claimed = completes
				return true
			end),
		}
		if completes then
			table.insert(
				operations,
				Currency:currencyOp(player.UserId, function(wallet)
					wallet[CREDIT] = (wallet[CREDIT] or 0) + Registry.REWARD_CREDITS
					return true
				end)
			)
		end
		local committed = Data:transaction(operations)
		if committed and typeof(player) == "Instance" and player.Parent == Players then
			local message =
				Rules.feedback(preview.progress, math.min(order.target, preview.progress + amount), completes, order)
			if message then
				local ok, err = pcall(function()
					Toast:send(player, { text = message, duration = if completes then 4 else 2 })
				end)
				if not ok then
					warn(`Work order feedback failed after commit: {err}`)
				end
			end
		end
		return committed
	end,
	_setClock = function(_self, nextClock)
		clock = nextClock or os.time
	end,
}
return Service
