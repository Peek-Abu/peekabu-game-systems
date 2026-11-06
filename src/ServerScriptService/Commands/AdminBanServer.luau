--!strict
--[=[
	adminban: bans a user id from the experience through Players:BanAsync (AdminBanUtils builds the config). Admins
	only (the Admins group fails closed in AdminServiceServer). A bad input is answered without calling Roblox.
]=]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AdminBanUtils = require(ReplicatedStorage.Shared.Features.Admin.Utils.AdminBanUtils)

return function(_context: { Executor: Player }, userId: number, days: number, reason: string): string
	local config, problem = AdminBanUtils.config(userId, days, reason)
	if config == nil then
		return `Not banned: {problem or "bad input"}.`
	end
	local ok, err = pcall(function()
		Players:BanAsync(config)
	end)
	if not ok then
		return `Ban failed: {tostring(err)}`
	end
	local length = if days == 0 then "for good" else `for {days} day(s)`
	return `Banned {userId} {length}.`
end
