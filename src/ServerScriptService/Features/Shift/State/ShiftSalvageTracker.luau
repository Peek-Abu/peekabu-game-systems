--!strict
--[=[
	ShiftSalvageTracker: optional-salvage attempts (Cleanup Crew spec §1: "do players voluntarily go back for optional
	salvage after the quota?"). The watch opens an attempt when a player picks up salvage after the quota outside the
	loading bay (ShiftAnalyticsUtils.isSalvageAttempt). This tracker keeps them:
	- one open attempt per item; a teammate picking up that item opens nothing;
	- a player whose open attempt's kind comes back into their hands under a new item id (unpocket, swap, their own
	  scattered item) keeps that attempt, re-keyed, so pockets never duplicate one;
	- every close removes the attempt, so it closes exactly once: banked (that player loads that kind) or failed
	  (dropped, thrown, caught, left, unbanked at the shift's end);
	- how many attempts each player opened this shift (shift_ended's value).

	@class ShiftSalvageTracker
]=]

local ServerScriptService = game:GetService("ServerScriptService")

local ShiftAnalyticsUtils = require(ServerScriptService.Features.Shift.Utils.ShiftAnalyticsUtils)

type AttemptOutcome = ShiftAnalyticsUtils.AttemptOutcome

export type Attempt = {
	itemId: number,
	userId: number,
	kind: string,
	-- Where the item came from ("open", "pile", "desk", "scatter").
	source: string,
	-- Seconds from the quota being met to the pick-up.
	sinceQuota: number,
	-- Set when the attempt closes.
	outcome: AttemptOutcome?,
}

export type ShiftSalvageTracker = {
	open: (
		self: ShiftSalvageTracker,
		itemId: number,
		userId: number,
		kind: string,
		source: string,
		sinceQuota: number
	) -> boolean,
	resolveItem: (self: ShiftSalvageTracker, itemId: number, outcome: AttemptOutcome) -> Attempt?,
	resolveBanked: (self: ShiftSalvageTracker, userId: number, kinds: { string }) -> { Attempt },
	resolvePlayer: (self: ShiftSalvageTracker, userId: number, outcome: AttemptOutcome) -> { Attempt },
	resolveAll: (self: ShiftSalvageTracker, outcome: AttemptOutcome) -> { Attempt },
	openCount: (self: ShiftSalvageTracker) -> number,
	attemptsBy: (self: ShiftSalvageTracker, userId: number) -> number,
	clear: (self: ShiftSalvageTracker) -> (),
}

local ShiftSalvageTracker = {}

function ShiftSalvageTracker.new(): ShiftSalvageTracker
	-- Open attempts, oldest first.
	local pending: { Attempt } = {}
	local counts: { [number]: number } = {}

	-- Removes the attempt at `index` and closes it with `outcome`.
	local function take(index: number, outcome: AttemptOutcome): Attempt?
		local attempt = table.remove(pending, index)
		if attempt ~= nil then
			attempt.outcome = outcome
		end
		return attempt
	end

	local tracker: ShiftSalvageTracker = {
		open = function(_self, itemId, userId, kind, source, sinceQuota)
			for _, attempt in pending do
				if attempt.itemId == itemId then
					return false
				end
				if attempt.userId == userId and attempt.kind == kind then
					-- The same kind back in the same hands (unpocket, swap, a scattered pick-up): one attempt.
					attempt.itemId = itemId
					return false
				end
			end
			table.insert(pending, {
				itemId = itemId,
				userId = userId,
				kind = kind,
				source = source,
				sinceQuota = sinceQuota,
				outcome = nil,
			})
			counts[userId] = (counts[userId] or 0) + 1
			return true
		end,

		resolveItem = function(_self, itemId, outcome)
			for index, attempt in pending do
				if attempt.itemId == itemId then
					return take(index, outcome)
				end
			end
			return nil
		end,

		resolveBanked = function(_self, userId, kinds)
			local closed: { Attempt } = {}
			for _, kind in kinds do
				for index, attempt in pending do
					if attempt.userId == userId and attempt.kind == kind then
						local attemptClosed = take(index, "banked")
						if attemptClosed ~= nil then
							table.insert(closed, attemptClosed)
						end
						break
					end
				end
			end
			return closed
		end,

		resolvePlayer = function(_self, userId, outcome)
			local closed: { Attempt } = {}
			for index = #pending, 1, -1 do
				if pending[index].userId == userId then
					local attemptClosed = take(index, outcome)
					if attemptClosed ~= nil then
						table.insert(closed, 1, attemptClosed)
					end
				end
			end
			return closed
		end,

		resolveAll = function(_self, outcome)
			local closed: { Attempt } = {}
			while #pending > 0 do
				local attemptClosed = take(1, outcome)
				if attemptClosed ~= nil then
					table.insert(closed, attemptClosed)
				end
			end
			return closed
		end,

		openCount = function(_self)
			return #pending
		end,

		attemptsBy = function(_self, userId)
			return counts[userId] or 0
		end,

		clear = function(_self)
			table.clear(pending)
			table.clear(counts)
		end,
	}
	return tracker
end

return ShiftSalvageTracker
