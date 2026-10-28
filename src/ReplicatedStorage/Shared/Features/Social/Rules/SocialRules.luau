--!strict
--[=[
	SocialRules: the `social` account slice's rules (Odd Hours social perks). Pure.

	- `fresh` / `validate`: the slice's default and its data-layer validator.
	- `launchData` / `referrerFrom`: an invite's LaunchData names the inviter; on join the referrer is read back from
	  it, never the player themselves.
	- `canRecordReferrer`: a referrer is recorded only for a player who has never finished a shift.
	- `referralOwed` / `inviterPayable`: the referral pays the referred player once, the inviter up to REFERRAL_CAP.
	- `shouldAsk`: the favorite/like ask, after a met contract, spaced ASK_SPACING, never once it is a favorite.

	@class SocialRules
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PlayerDataTypes = require(ReplicatedStorage.Shared.Data.PlayerDataTypes)
local SocialConstants = require(ReplicatedStorage.Shared.Features.Social.Data.SocialConstants)

type Social = PlayerDataTypes.Social

local function isWhole(value: unknown): boolean
	return type(value) == "number" and value >= 0 and value == math.floor(value)
end

local function userIdOf(value: unknown): number?
	if type(value) == "number" and value >= 1 and value == math.floor(value) then
		return value
	end
	return nil
end

local SocialRules = {}

function SocialRules.fresh(): Social
	return { groupPaid = false, referredBy = 0, referralPaid = false, referrals = 0, askedAt = 0 }
end

function SocialRules.validate(state: Social): (boolean, string?)
	local groupPaid: unknown = state.groupPaid
	local referralPaid: unknown = state.referralPaid
	if type(groupPaid) ~= "boolean" or type(referralPaid) ~= "boolean" then
		return false, "social.groupPaid and referralPaid must be booleans"
	end
	if not isWhole(state.referredBy) or not isWhole(state.referrals) or not isWhole(state.askedAt) then
		return false, "social.referredBy, referrals and askedAt must be whole numbers of at least 0"
	end
	return true, nil
end

-- The LaunchData an invite from `userId` carries.
function SocialRules.launchData(userId: number): string
	return `{SocialConstants.LAUNCH_PREFIX}{userId}`
end

-- The inviter named by a join's LaunchData; nil when it names nobody else.
function SocialRules.referrerFrom(launchData: string?, selfId: number): number?
	local prefix = SocialConstants.LAUNCH_PREFIX
	if launchData == nil or string.sub(launchData, 1, #prefix) ~= prefix then
		return nil
	end
	local found = userIdOf(tonumber(string.sub(launchData, #prefix + 1)))
	return if found ~= selfId then found else nil
end

-- Whether a referrer may be recorded: none yet, never paid, and no shift finished (`xp` is the rank's XP).
function SocialRules.canRecordReferrer(state: Social, xp: number): boolean
	return state.referredBy == 0 and not state.referralPaid and xp == 0
end

-- Whether the referred player's own referral pay-out is still owed.
function SocialRules.referralOwed(state: Social): boolean
	return state.referredBy ~= 0 and not state.referralPaid
end

-- Whether the inviter may still be paid for a friend.
function SocialRules.inviterPayable(inviter: Social): boolean
	return inviter.referrals < SocialConstants.REFERRAL_CAP
end

-- Whether to show the favorite/like ask now: after a met contract, not a favorite, ASK_SPACING since the last ask.
function SocialRules.shouldAsk(state: Social, now: number, met: boolean, favorited: boolean): boolean
	return met and not favorited and now - state.askedAt >= SocialConstants.ASK_SPACING
end

return SocialRules
