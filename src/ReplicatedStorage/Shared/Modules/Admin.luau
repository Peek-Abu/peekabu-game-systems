--!strict
--[=[
	Admin: the single source of truth for "who is a privileged player".

	Extracted from AdminServiceServer so that every gate reads the SAME allowlist — Cmdr's admin
	command groups and the in-game Service & State Debugger both call `Admin.isAdmin`. Keeping one
	definition means a change here (or a swap to a group-rank / DataStore lookup) instantly covers
	every consumer, with no risk of two gates drifting apart.

	Placement note: this lives in Shared (not server-only) because the debugger CLIENT wants a cheap
	local check to decide whether to even show its overlay. That is a UX gate only — the allowlist is
	not a secret, and the SERVER still re-checks `isAdmin` before answering any debugger packet, so a
	client that forges its way past the local check gets nothing back. Never treat a client-side
	`isAdmin` result as authorization.

	@class Admin
]=]

local RunService = game:GetService("RunService")

--[=[
	Admin allowlist. Add the UserIds you trust here, or replace `isAdmin` with a group-rank /
	DataStore lookup. SECURE BY DEFAULT: in a published server, anyone NOT in this list is denied.
	Studio sessions are always allowed so you can test without editing this list.
]=]
local ADMIN_USER_IDS: { [number]: boolean } = {
	[20661908] = true,
}

local Admin = {}

--[=[
	Returns whether a player is a privileged (admin) player.
	Always true in Studio; otherwise true only for UserIds in the allowlist.
	@param player Player -- The player to check
	@return boolean -- True if the player is an admin (or the session is in Studio)
]=]
function Admin.isAdmin(player: Player): boolean
	if RunService:IsStudio() then
		return true
	end
	return ADMIN_USER_IDS[player.UserId] == true
end

return Admin
