--!strict
--[=[
	adminunban: lifts a user id's ban through Players:UnbanAsync. Admins only.
]=]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AdminBanUtils = require(ReplicatedStorage.Shared.Features.Admin.Utils.AdminBanUtils)

return function(_context: { Executor: Player }, userId: number): string
	local config = AdminBanUtils.unbanConfig(userId)
	if config == nil then
		return "Not unbanned: the user id must be a whole number above 0."
	end
	local ok, err = pcall(function()
		Players:UnbanAsync(config)
	end)
	if not ok then
		return `Unban failed: {tostring(err)}`
	end
	return `Unbanned {userId}.`
end
