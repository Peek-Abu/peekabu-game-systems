--!strict
--[=[
	TipServiceServer: one-line tips for a player's firsts (the first catch, the overtime offer, the first ability
	use). `first(player, id)` shows the TipRegistry line as a sticky note once per account, unless the player turned
	tips off (the Tips setting). It owns the server-only "tips" account slice (TipRules validates it): the tip is
	marked seen before it is sent, so a refused write shows nothing rather than repeating it later.

	Spec-exempt shell (the data layer, Setting and Toast); the decision is the specced TipRules, the lines the specced
	TipRegistry.

	@class TipServiceServer
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Logger = require(ReplicatedStorage.Shared.Core.Logger)
local PlayerDataTypes = require(ReplicatedStorage.Shared.Data.PlayerDataTypes)
local ShiftConstants = require(ReplicatedStorage.Shared.Features.Shift.Data.ShiftConstants)
local TipRegistry = require(ReplicatedStorage.Shared.Features.Tip.Data.TipRegistry)
local TipRules = require(ReplicatedStorage.Shared.Features.Tip.Rules.TipRules)
local PlayerDataSliceSystem = require(ServerScriptService.Features.PlayerData.Systems.PlayerDataSliceSystem)
local SettingServiceServer = require(ServerScriptService.Features.Setting.SettingServiceServer)
local ToastServiceServer = require(ServerScriptService.Features.Toast.ToastServiceServer)

local tipsSlice = PlayerDataSliceSystem.registerAccount("tips", { seen = {} }, function(account)
	return account.tips
end, TipRules.validate)

local log = Logger.new("TipServiceServer")
local counters = { shown = 0, skipped = 0 }

export type TipServiceServer = {
	dependencies: { string },
	getState: (self: TipServiceServer) -> { [string]: any },
	first: (self: TipServiceServer, player: Player, id: string) -> boolean,
}

local TipServiceServer: TipServiceServer = {
	dependencies = { "PlayerDataServiceServer", "SettingServiceServer", "ToastServiceServer" },

	--[=[
		Shows tip `id` to `player` if it is their first time and tips are on. True when the tip was shown.
	]=]
	first = function(_self, player, id)
		local enabled = SettingServiceServer:get(player.UserId, TipRegistry.SETTING) ~= false
		local tips: PlayerDataTypes.Tips? = tipsSlice.get(player.UserId)
		if tips == nil or not TipRules.shouldShow(tips, id, enabled) then
			counters.skipped += 1
			return false
		end
		local marked = tipsSlice.mutate(player.UserId, function(slice)
			if slice.seen[id] == true then
				return false
			end
			slice.seen[id] = true
			return true
		end)
		local text = TipRegistry.text(id)
		if not marked or text == nil then
			counters.skipped += 1
			return false
		end
		counters.shown += 1
		log:debug(`tip "{id}" for {player.UserId}`)
		return ToastServiceServer:send(player, {
			text = text,
			style = ShiftConstants.TOAST_STICKY,
			duration = TipRegistry.SECONDS,
		})
	end,

	getState = function(_self)
		return { counters = table.clone(counters) }
	end,
}

return TipServiceServer
