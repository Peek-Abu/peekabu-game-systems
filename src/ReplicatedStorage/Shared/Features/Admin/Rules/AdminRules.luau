--!strict
--[=[
	AdminRules: the single source of truth for "who is a privileged player".

	Extracted from AdminServiceServer so that every gate reads the SAME allowlist — Cmdr's admin
	command groups and the in-game Service & State Debugger both call `AdminRules.isAdmin`. Keeping one
	definition means a change here (or a swap to a group-rank / DataStore lookup) instantly covers
	every consumer, with no risk of two gates drifting apart.

	Placement note: this lives in Shared (not server-only) because the debugger CLIENT wants a cheap
	local check to decide whether to even show its overlay. That is a UX gate only — the allowlist is
	not a secret, and the SERVER still re-checks `isAdmin` before answering any debugger packet, so a
	client that forges its way past the local check gets nothing back. Never treat a client-side
	`isAdmin` result as authorization.

	@class AdminRules
]=]

local RunService = game:GetService("RunService")

--[=[
	AdminRules allowlist. Add the UserIds you trust here, or replace `isAdmin` with a group-rank /
	DataStore lookup. SECURE BY DEFAULT: in a published server, anyone NOT in this list is denied.
	Studio sessions are always allowed so you can test without editing this list.
]=]
local ADMIN_USER_IDS: { [number]: boolean } = {
	[20661908] = true,
}

local AdminRules = {}

--[=[
	Pure admin decision: true if the session is Studio, else true only for a UserId in the allowlist.
	Split out from `isAdmin` so BOTH branches (Studio bypass AND the allowlist) are deterministically
	testable without depending on the runtime's `RunService:IsStudio()` — the TestEZ suite runs in
	Open Cloud (not Studio), where `IsStudio()` is false. `allowlist` defaults to the real
	`ADMIN_USER_IDS`; tests pass a synthetic one so coverage isn't coupled to the live admin list.
	(Mirrors the pure-core split in `CurrencyConstants.validateSync` / `PlayerDataMigrationSystem._applyWith`.)
	@param userId number -- The player's UserId
	@param isStudio boolean -- Whether the session is a Studio session
	@param allowlist { [number]: boolean }? -- Override the admin allowlist (tests only)
	@return boolean
]=]
function AdminRules.isAdminForSession(userId: number, isStudio: boolean, allowlist: { [number]: boolean }?): boolean
	if isStudio then
		return true
	end
	return (allowlist or ADMIN_USER_IDS)[userId] == true
end

--[=[
	Returns whether a player is a privileged (admin) player.
	Always true in Studio; otherwise true only for UserIds in the allowlist.
	@param player Player -- The player to check
	@return boolean -- True if the player is an admin (or the session is in Studio)
]=]
function AdminRules.isAdmin(player: Player): boolean
	return AdminRules.isAdminForSession(player.UserId, RunService:IsStudio())
end

return AdminRules
