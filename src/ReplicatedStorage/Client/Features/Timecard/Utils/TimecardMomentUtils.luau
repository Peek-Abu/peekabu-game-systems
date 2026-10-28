--!strict
--[=[
	TimecardMomentUtils: what a change to the local player's card means for the screen. `moment` finds today's new
	punch between two replicated cards (both rolled to `now`, so last week's punch on the same weekday is not
	today's) and what it paid, read the same way the server's TimecardCalendarFormulas.punch pays it. `banner` is the
	line under the stamp. `shouldGreet` says when the hub opens the clipboard by itself: once a UTC day, in the hub,
	on the real (synced) card, with no other screen up, and only while today is still free. Pure.

	@class TimecardMomentUtils
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PlayerDataTypes = require(ReplicatedStorage.Shared.Data.PlayerDataTypes)
local TimecardConstants = require(ReplicatedStorage.Shared.Features.Timecard.Data.TimecardConstants)
local TimecardCalendarFormulas = require(ReplicatedStorage.Shared.Features.Timecard.Utils.TimecardCalendarFormulas)

export type Moment = {
	-- Today's day number (Monday = 1), the punch's count on the card and what it paid.
	day: number,
	count: number,
	reward: TimecardCalendarFormulas.Milestone?,
	paycheque: boolean,
	-- Unique per punch (the week and the day): keys the stamp so each punch animates fresh.
	id: string,
}

export type GreetInput = {
	synced: boolean,
	inHub: boolean,
	busy: boolean,
	canPunch: boolean,
	greeted: number?,
	day: number,
}

local TimecardMomentUtils = {}

--[=[
	Today's punch if `after` holds it and `before` did not; nil otherwise.
]=]
function TimecardMomentUtils.moment(
	before: PlayerDataTypes.Timecard,
	after: PlayerDataTypes.Timecard,
	now: number
): Moment?
	local old = TimecardCalendarFormulas.roll(before, now)
	local new = TimecardCalendarFormulas.roll(after, now)
	local today = TimecardCalendarFormulas.dayOfWeek(now)
	if table.find(new.punched, today) == nil or table.find(old.punched, today) ~= nil then
		return nil
	end
	local count = #new.punched
	local filled = count == TimecardConstants.PUNCHES_TO_FILL
	return {
		day = today,
		count = count,
		reward = if count == TimecardConstants.KEY_PUNCH then "key" elseif filled then "stars" else nil,
		paycheque = filled and new.weeks > 0 and new.weeks % TimecardConstants.PAYCHEQUE_WEEKS == 0,
		id = `{new.week}:{today}`,
	}
end

--[=[
	The line under the stamp: what the punch paid, else how far the next reward is.
]=]
function TimecardMomentUtils.banner(moment: Moment): string
	if moment.reward == "key" then
		return `DAY {moment.count}! +{TimecardConstants.KEY_REWARD} GLOOM KEY`
	end
	if moment.reward == "stars" then
		local gleam = `CARD FULL! +{TimecardConstants.STAR_REWARD} {string.upper(TimecardConstants.STAR_LABEL)}`
		return if moment.paycheque then `{gleam} +{TimecardConstants.PAYCHEQUE_CREDITS} CREDITS` else gleam
	end
	if moment.count < TimecardConstants.KEY_PUNCH then
		return `DAY {moment.count}! {TimecardConstants.KEY_PUNCH - moment.count} MORE FOR A GLOOM KEY`
	end
	if moment.count < TimecardConstants.PUNCHES_TO_FILL then
		local left = TimecardConstants.PUNCHES_TO_FILL - moment.count
		return `DAY {moment.count}! {left} MORE FOR {TimecardConstants.STAR_REWARD} {string.upper(
			TimecardConstants.STAR_LABEL
		)}`
	end
	return "BONUS DAY! CARD IS FULL"
end

--[=[
	Whether the hub should open the Timecard by itself now (see the class note).
]=]
function TimecardMomentUtils.shouldGreet(input: GreetInput): boolean
	return input.synced and input.inHub and not input.busy and input.canPunch and input.greeted ~= input.day
end

return TimecardMomentUtils
