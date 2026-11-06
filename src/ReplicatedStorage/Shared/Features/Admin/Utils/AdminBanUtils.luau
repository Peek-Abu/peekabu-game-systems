--!strict
--[=[
	AdminBanUtils: builds the Players:BanAsync / UnbanAsync configs the admin ban commands send (Roblox Ban API: the
	ban covers every place of the experience, and its alt-account detection stays on). Whole days, 0 = permanent. The
	reason is shown to the banned player (Roblox filters it; at most MAX_REASON characters). Pure.

	@class AdminBanUtils
]=]

export type BanConfig = {
	UserIds: { number },
	ApplyToUniverse: boolean,
	Duration: number,
	DisplayReason: string,
	PrivateReason: string,
	ExcludeAltAccounts: boolean,
}

export type UnbanConfig = { UserIds: { number }, ApplyToUniverse: boolean }

local DAY = 86400

local AdminBanUtils = {
	-- The Ban API's limit on the reason shown to the player.
	MAX_REASON = 400,
}

local function validUserId(userId: number): boolean
	return userId >= 1 and userId == math.floor(userId)
end

--[=[
	The ban for `userId`, `days` long (0 = permanent), with `reason` shown to them; nil and why for a bad input.
]=]
function AdminBanUtils.config(userId: number, days: number, reason: string): (BanConfig?, string?)
	if not validUserId(userId) then
		return nil, "the user id must be a whole number above 0"
	end
	if days < 0 or days ~= math.floor(days) then
		return nil, "days must be a whole number, 0 for a permanent ban"
	end
	local trimmed = string.match(reason, "^%s*(.-)%s*$") or ""
	if trimmed == "" then
		return nil, "a reason is needed (the player sees it)"
	end
	if #trimmed > AdminBanUtils.MAX_REASON then
		return nil, `the reason is longer than {AdminBanUtils.MAX_REASON} characters`
	end
	return {
		UserIds = { userId },
		ApplyToUniverse = true,
		Duration = if days == 0 then -1 else days * DAY,
		DisplayReason = trimmed,
		PrivateReason = trimmed,
		ExcludeAltAccounts = false,
	}
end

--[=[
	The unban for `userId`; nil for a bad id.
]=]
function AdminBanUtils.unbanConfig(userId: number): UnbanConfig?
	if not validUserId(userId) then
		return nil
	end
	return { UserIds = { userId }, ApplyToUniverse = true }
end

return AdminBanUtils
