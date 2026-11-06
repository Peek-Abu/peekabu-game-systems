--!strict
--[=[
	SocialConstants: the social perks' tuning (Odd Hours, plan docs/superpowers/plans/2026-10-28-social-perks.md).
	Static data (spec-exempt). Every number is a one-line edit.

	@class SocialConstants
]=]

return table.freeze({
	-- The Roblox group whose members get the one-time perk (Icey Labs).
	GROUP_ID = 189923277,
	GROUP_GLEAM = 100,
	-- A referred player's first finished shift pays them and their inviter this much, the inviter for at most
	-- REFERRAL_CAP friends.
	REFERRAL_GLEAM = 50,
	REFERRAL_CAP = 5,
	-- Seconds between two favorite/like asks.
	ASK_SPACING = 3 * 86400,
	-- Seconds after a player is back in the hub with their review card before the one Roblox prompt (event RSVP or
	-- notifications, SocialPromptSystem): time to read the board first.
	PROMPT_DELAY = 6,
	-- An invite's LaunchData: this prefix and the inviter's userId.
	LAUNCH_PREFIX = "ref:",
	-- Requests per player per window (the group check and the ask mark).
	REQUEST_RATE = table.freeze({ maxRequests = 4, windowSeconds = 10 }),
	-- Player-facing words (kid reading level); the server adds the "+N Gleam".
	TEXT = table.freeze({
		groupPaid = "Thanks for joining Icey Labs!",
		referralInvitee = "Your friend invited you!",
		referralInviter = "Your friend finished a shift!",
		invitePrompt = "Come clean up the Gloom with me!",
	}),
})
