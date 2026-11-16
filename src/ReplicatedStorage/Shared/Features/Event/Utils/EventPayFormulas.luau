--!strict
--[=[
	EventPayFormulas: the event money one player gets for a finished shift (a base, plus the contract, their first
	finished shift of the day and a Roblox friend in the crew), and what leftover money turns into after the event.
	Coffee and the 2x pass never touch it (owner R2). Pure.

	@class EventPayFormulas
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local EventTypes = require(ReplicatedStorage.Shared.Features.Event.Data.EventTypes)

local EventPayFormulas = {}

function EventPayFormulas.payout(pay: EventTypes.Pay, facts: EventTypes.ShiftFacts): EventTypes.Payout
	local total = 0
	local parts: { EventTypes.PayPart } = {}
	local function add(part: EventTypes.PayPart, amount: number, earned: boolean)
		if earned and amount > 0 then
			total += amount
			table.insert(parts, part)
		end
	end
	add("finished", pay.finished, true)
	add("contract", pay.contract, facts.quotaMet)
	add("firstToday", pay.firstToday, facts.firstToday)
	add("friend", pay.friend, facts.withFriend)
	return { total = total, parts = parts }
end

function EventPayFormulas.converted(leftover: number, rate: number): number
	return math.floor(leftover * rate)
end

return EventPayFormulas
