--!strict
--[=[
	ShiftVoteSystem: the results vote (Cleanup Crew spec §3, §6.5): Another shift or Back to depot. It records
	each crew member's vote (the `Vote` packet through RequestHandler, or ShiftServiceServer:vote), forgets a
	leaver's, and resolves the vote as soon as ShiftVoteRules decides it (everyone present has voted, a majority
	exists, or the vote timed out); the decision goes back to the service (`deps.decided`). The tally feeds the
	`shift` world entry.

	Moved out of ShiftServiceServer before M3 (the service was at the 400-line cap). Spec-exempt shell
	(RequestHandler, ByteNet); the decisions are the specced ShiftVoteRules.

	@class ShiftVoteSystem
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local ShiftTypes = require(ReplicatedStorage.Shared.Features.Shift.Data.ShiftTypes)
local ShiftEvents = require(ReplicatedStorage.Shared.Features.Shift.Net.ShiftEvents)
local RequestHandler = require(ServerScriptService.Core.Net.RequestHandler)
local ShiftVoteRules = require(ServerScriptService.Features.Shift.Rules.ShiftVoteRules)

export type Deps = {
	-- True while the vote is open (the results phase).
	isOpen: () -> boolean,
	-- Whether a player takes part (the crew).
	eligible: (player: Player) -> boolean,
	-- The crew members in the server (`except`: one who is leaving).
	presentIds: (except: number?) -> { number },
	-- Republishes the `shift` world entry (the tally changed).
	publish: () -> (),
	-- The vote is decided (`depot`: Back to depot won, else Another shift): the service acts on it and resets.
	decided: (depot: boolean) -> (),
}

export type ShiftVoteSystem = {
	-- Listens for the `Vote` packet; returns the stopper.
	start: (self: ShiftVoteSystem) -> () -> (),
	vote: (self: ShiftVoteSystem, player: Player, choice: ShiftTypes.Vote) -> boolean,
	forget: (self: ShiftVoteSystem, userId: number) -> (),
	resolve: (self: ShiftVoteSystem, timedOut: boolean, leaving: number?) -> (),
	tally: (self: ShiftVoteSystem) -> (number, number),
	clear: (self: ShiftVoteSystem) -> (),
}

local ShiftVoteSystem = {}

function ShiftVoteSystem.new(deps: Deps): ShiftVoteSystem
	local votes: { [number]: ShiftTypes.Vote } = {}
	local system: ShiftVoteSystem

	local onVote = RequestHandler.wrap({
		name = "ShiftVote",
		rateLimit = { maxRequests = 6, windowSeconds = 5 },
		validate = function(data: string, _player: Player): (boolean, string?, ShiftTypes.Vote?)
			local choice: ShiftTypes.Vote? = ShiftVoteRules.parse(data)
			if not choice then
				return false, "unknown vote", nil
			end
			return true, nil, choice
		end,
		handler = function(_data: string, player: Player, choice: ShiftTypes.Vote?)
			if choice ~= nil then
				system:vote(player, choice)
			end
		end,
	})

	system = {
		start = function(_self)
			return ShiftEvents.packets.Vote.listen(function(data: string, player: Player?)
				if player then
					onVote(data, player)
				end
			end)
		end,

		--[=[
			Records a vote (replacing the player's earlier one) and resolves the vote if it is decided. False
			outside the results or for a player outside the crew.
		]=]
		vote = function(self, player, choice)
			if not deps.isOpen() or not deps.eligible(player) then
				return false
			end
			votes[player.UserId] = choice
			deps.publish()
			self:resolve(false)
			return true
		end,

		forget = function(_self, userId)
			votes[userId] = nil
		end,

		resolve = function(_self, timedOut, leaving)
			local decision = ShiftVoteRules.decide(votes, deps.presentIds(leaving), timedOut)
			if decision ~= nil then
				deps.decided(decision == "depot")
			end
		end,

		tally = function(_self)
			return ShiftVoteRules.tally(votes, deps.presentIds())
		end,

		clear = function(_self)
			table.clear(votes)
		end,
	}
	return system
end

return ShiftVoteSystem
