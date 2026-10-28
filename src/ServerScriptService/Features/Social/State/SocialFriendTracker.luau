--!strict
--[=[
	SocialFriendTracker: which players in this server are Roblox friends (pairs, both ways). SocialServiceServer fills
	`shared` as players join (Player:IsFriendsWithAsync) and forgets a leaver; Shift's review reads it to mark crew
	lines that played with a friend (the "Friends x2" XP line). It lives in State, not in the service, so Shift can
	read it without depending on Social (Social follows Shift's state for referrals).

	@class SocialFriendTracker
]=]

export type SocialFriendTracker = {
	set: (self: SocialFriendTracker, a: number, b: number, friends: boolean) -> (),
	areFriends: (self: SocialFriendTracker, a: number, b: number) -> boolean,
	-- Whether any of `among` other than `userId` is their friend.
	anyFriend: (self: SocialFriendTracker, userId: number, among: { number }) -> boolean,
	forget: (self: SocialFriendTracker, userId: number) -> (),
}

local SocialFriendTracker = {}

function SocialFriendTracker.new(): SocialFriendTracker
	local links: { [number]: { [number]: true } } = {}

	local function link(a: number, b: number, friends: boolean)
		local known = links[a]
		if friends then
			if known == nil then
				known = {}
				links[a] = known
			end
			known[b] = true
		elseif known ~= nil then
			known[b] = nil
		end
	end

	local tracker: SocialFriendTracker = {
		set = function(_self, a, b, friends)
			link(a, b, friends)
			link(b, a, friends)
		end,

		areFriends = function(_self, a, b)
			local known = links[a]
			return known ~= nil and known[b] == true
		end,

		anyFriend = function(self, userId, among)
			for _, other in among do
				if other ~= userId and self:areFriends(userId, other) then
					return true
				end
			end
			return false
		end,

		forget = function(_self, userId)
			local known = links[userId]
			if known ~= nil then
				for other in known do
					local back = links[other]
					if back ~= nil then
						back[userId] = nil
					end
				end
			end
			links[userId] = nil
		end,
	}
	return tracker
end

-- The server's one tracker.
SocialFriendTracker.shared = SocialFriendTracker.new()

return SocialFriendTracker
