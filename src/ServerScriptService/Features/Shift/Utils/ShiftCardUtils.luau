--!strict
--[=[
	ShiftCardUtils: the result card that rides the return teleport to the depot (Cleanup Crew spec §3 steps 1
	and 7, §6.5 "the depot result card comes through the return teleport"). `encode` flattens a performance
	review into a Queue payload (flat keys, 27 at most, under Queue's 32); `decode` is the depot's trust
	boundary: teleport data travels through the client, so a wrong version, a wrong type anywhere or a crew
	count without its lines reads as no card, numbers are clamped to whole 0..MAX_NUMBER and text is cut to
	MAX_TEXT characters; `lines` is what the depot's board shows. Pure.

	Wire keys: v, client, shift, outcome, quota, cleared, bonus, salvage, piles, catches, met, crew, awards,
	c<i>n / c<i>b (crew line i: name, banked; i <= 4), a<i>t / a<i>n (award i: title, name; i <= 3).

	@class ShiftCardUtils
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local QueueTypes = require(ReplicatedStorage.Shared.Features.Queue.Data.QueueTypes)
local ShiftTypes = require(ReplicatedStorage.Shared.Features.Shift.Data.ShiftTypes)

type QueuePayload = QueueTypes.QueuePayload

export type CardLine = {
	name: string,
	banked: number,
}

export type ResultCard = {
	client: string,
	shift: number,
	outcome: string,
	quota: number,
	cleared: number,
	bonus: number,
	salvage: number,
	piles: number,
	catches: number,
	quotaMet: boolean,
	crew: { CardLine },
	awards: { ShiftTypes.Award },
}

-- What the review does not know: whose contract it was and which shift on that server.
export type CardInfo = {
	client: string,
	shift: number,
}

local VERSION = 1
local MAX_CREW = 4
local MAX_AWARDS = 3
local MAX_TEXT = 40
local MAX_NUMBER = 1000000

local OUTCOME_TEXT: { [string]: string } = {
	clockout = "Clocked out",
	timeout = "Time's up",
	abandoned = "Everyone left",
}

-- At most MAX_TEXT characters, cut on a character boundary; invalid UTF-8 reads "?".
local function cut(value: string): string
	if utf8.len(value) == nil then
		return "?"
	end
	local stop = utf8.offset(value, MAX_TEXT + 1)
	if stop == nil then
		return value
	end
	return string.sub(value, 1, stop - 1)
end

local function text(value: unknown): string?
	if type(value) ~= "string" then
		return nil
	end
	return cut(value)
end

-- A whole number clamped to 0..MAX_NUMBER; nil for anything that is not a number (NaN included).
local function count(value: unknown): number?
	if type(value) ~= "number" or value ~= value then
		return nil
	end
	return math.clamp(math.floor(value), 0, MAX_NUMBER)
end

local ShiftCardUtils = {}

function ShiftCardUtils.encode(results: ShiftTypes.ShiftResults, info: CardInfo): QueuePayload
	local payload: QueuePayload = {
		v = VERSION,
		client = cut(info.client),
		shift = info.shift,
		outcome = cut(results.outcome),
		quota = results.quota,
		cleared = results.cleared,
		bonus = results.bonus,
		salvage = results.salvage,
		piles = results.piles,
		catches = results.catches,
		met = results.quotaMet,
	}
	local crew = math.min(#results.crew, MAX_CREW)
	payload.crew = crew
	for index = 1, crew do
		local line = results.crew[index]
		payload[`c{index}n`] = cut(line.name)
		payload[`c{index}b`] = line.banked
	end
	local awards = math.min(#results.awards, MAX_AWARDS)
	payload.awards = awards
	for index = 1, awards do
		local award = results.awards[index]
		payload[`a{index}t`] = cut(award.title)
		payload[`a{index}n`] = cut(award.name)
	end
	return payload
end

function ShiftCardUtils.decode(payload: QueuePayload?): ResultCard?
	if payload == nil or payload.v ~= VERSION then
		return nil
	end
	local met = payload.met
	if type(met) ~= "boolean" then
		return nil
	end
	local client = text(payload.client)
	local outcome = text(payload.outcome)
	local shift = count(payload.shift)
	local quota = count(payload.quota)
	local cleared = count(payload.cleared)
	local bonus = count(payload.bonus)
	local salvage = count(payload.salvage)
	local piles = count(payload.piles)
	local catches = count(payload.catches)
	local crewCount = count(payload.crew)
	local awardCount = count(payload.awards)
	if
		client == nil
		or outcome == nil
		or shift == nil
		or quota == nil
		or cleared == nil
		or bonus == nil
		or salvage == nil
		or piles == nil
		or catches == nil
		or crewCount == nil
		or awardCount == nil
		or crewCount > MAX_CREW
		or awardCount > MAX_AWARDS
	then
		return nil
	end
	local crew: { CardLine } = {}
	for index = 1, crewCount do
		local name = text(payload[`c{index}n`])
		local banked = count(payload[`c{index}b`])
		if name == nil or banked == nil then
			return nil
		end
		table.insert(crew, { name = name, banked = banked })
	end
	local awards: { ShiftTypes.Award } = {}
	for index = 1, awardCount do
		local title = text(payload[`a{index}t`])
		local name = text(payload[`a{index}n`])
		if title == nil or name == nil then
			return nil
		end
		table.insert(awards, { title = title, name = name })
	end
	return {
		client = client,
		shift = shift,
		outcome = outcome,
		quota = quota,
		cleared = cleared,
		bonus = bonus,
		salvage = salvage,
		piles = piles,
		catches = catches,
		quotaMet = met,
		crew = crew,
		awards = awards,
	}
end

function ShiftCardUtils.lines(card: ResultCard): { string }
	local lines: { string } = {
		`{card.client} - shift {card.shift}`,
		OUTCOME_TEXT[card.outcome] or card.outcome,
		`Cleared {card.cleared} / {card.quota} - {if card.quotaMet then "QUOTA MET" else "quota missed"}`,
		`Finder's fee {card.bonus}`,
		`Salvage {card.salvage} | Piles {card.piles} | Caught {card.catches}`,
	}
	for _, line in card.crew do
		table.insert(lines, `{line.name}: banked {line.banked}`)
	end
	for _, award in card.awards do
		table.insert(lines, `{award.title}: {award.name}`)
	end
	return lines
end

return ShiftCardUtils
