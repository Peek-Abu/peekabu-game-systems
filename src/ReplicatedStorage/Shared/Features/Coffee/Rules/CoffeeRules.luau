--!strict
--[=[
	CoffeeRules: Coffee for the crew's decisions (30 minutes of shift time, owner 11-10). The `coffee` account slice is
	the buyer's coffee time left (`seconds`) and when that time started (`since`, their place in line). Every purchase
	adds CoffeeConstants.SECONDS (`add`) in the same save as its receipt (exactly once). The time counts down only
	while a real shift runs with players in the server (`runs`), one buyer at a time: the earliest buyer in the server
	(`spender`), so two coffees never stack past 2x. While it runs the crew's Credits pay is doubled; the review pays
	2x for the part of the shift the coffee ran (`payScale`). A coffee costs 99 R$ (the developer product) or
	CoffeeConstants.GLEAM_PRICE Gleam (`affords`, `payGleam`). Pure.

	@class CoffeeRules
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CoffeeConstants = require(ReplicatedStorage.Shared.Features.Coffee.Data.CoffeeConstants)
local PlayerDataTypes = require(ReplicatedStorage.Shared.Data.PlayerDataTypes)
local WorldTypes = require(ReplicatedStorage.Shared.Data.WorldTypes)

-- A crew member who may have coffee time: who, how much is left, and when it started.
export type Candidate = {
	userId: number,
	seconds: number,
	since: number,
}

-- The `coffee` world entry: whose coffee runs now and how many seconds it has left.
export type Badge = {
	buyer: string,
	seconds: number,
}

local CoffeeRules = {}

--[=[
	A new player's slice: no coffee time.
]=]
function CoffeeRules.fresh(): PlayerDataTypes.Coffee
	return { seconds = 0, since = 0 }
end

--[=[
	The data layer's validator: `seconds` is a whole number, 0 or more, and `since` a time, 0 or more.
]=]
function CoffeeRules.validate(value: PlayerDataTypes.Coffee): (boolean, string?)
	local seconds = value.seconds
	if type(seconds) ~= "number" or seconds < 0 or seconds ~= math.floor(seconds) then
		return false, "coffee.seconds must be a whole number, 0 or more"
	end
	local since = value.since
	if type(since) ~= "number" or since < 0 then
		return false, "coffee.since must be a time, 0 or more"
	end
	return true, nil
end

--[=[
	One purchase: adds a coffee's time to `value` (in place). Time already running keeps its start, so a buyer who buys
	again keeps their place in line; new time starts at `now`.
]=]
function CoffeeRules.add(value: PlayerDataTypes.Coffee, now: number)
	if value.seconds <= 0 then
		value.since = now
	end
	value.seconds += CoffeeConstants.SECONDS
end

--[=[
	Takes `seconds` of coffee time off `value` (in place), never below 0; used-up time forgets its start.
]=]
function CoffeeRules.spend(value: PlayerDataTypes.Coffee, seconds: number)
	value.seconds = math.max(0, value.seconds - seconds)
	if value.seconds <= 0 then
		value.since = 0
	end
end

--[=[
	Whether coffee time counts down now: a real shift (not training) is running and the server has players in it.
]=]
function CoffeeRules.runs(phase: string, training: boolean, players: number): boolean
	return phase == "running" and not training and players > 0
end

--[=[
	Whose coffee time is spent: the earliest buyer (the smallest `since`) among those with time left; a tie goes to the
	lower user id. Nil when no one has coffee time.
]=]
function CoffeeRules.spender(candidates: { Candidate }): Candidate?
	local best: Candidate? = nil
	for _, candidate in candidates do
		if candidate.seconds > 0 then
			if
				best == nil
				or candidate.since < best.since
				or (candidate.since == best.since and candidate.userId < best.userId)
			then
				best = candidate
			end
		end
	end
	return best
end

--[=[
	Whether the shift HUD offers the buy button: only while a real shift (not training) runs and no coffee is running
	(while one runs, its badge buys more).
]=]
function CoffeeRules.offered(phase: string, training: boolean, active: boolean): boolean
	return phase == "running" and not training and not active
end

--[=[
	What the shift's Credits pay is multiplied by: 2x for the part of the shift (`ranFor` seconds) the coffee ran
	(`coffeeSeconds`), to the nearest tenth, never past 2x.
]=]
function CoffeeRules.payScale(coffeeSeconds: number, ranFor: number): number
	if coffeeSeconds <= 0 then
		return 1
	end
	local share = if ranFor <= 0 then 1 else math.min(1, coffeeSeconds / ranFor)
	local scale = 1 + (CoffeeConstants.PAY_SCALE - 1) * share
	return math.floor(scale * 10 + 0.5) / 10
end

--[=[
	A pay scale as the review shows it: "2", "1.5".
]=]
function CoffeeRules.scaleText(scale: number): string
	if scale == math.floor(scale) then
		return tostring(math.floor(scale))
	end
	return string.format("%.1f", scale)
end

--[=[
	Seconds as the badge's clock: "24:10" (minutes keep counting past an hour: "90:00").
]=]
function CoffeeRules.clock(seconds: number): string
	local whole = math.max(0, math.floor(seconds))
	return string.format("%d:%02d", whole // 60, whole % 60)
end

--[=[
	Reads the `coffee` world entry; nil when it is absent or not a { buyer, seconds } table.
]=]
function CoffeeRules.badge(raw: WorldTypes.WorldValue?): Badge?
	if type(raw) ~= "table" then
		return nil
	end
	local buyer = raw.buyer
	local seconds = raw.seconds
	if type(buyer) ~= "string" or type(seconds) ~= "number" then
		return nil
	end
	return { buyer = buyer, seconds = seconds }
end

--[=[
	The HUD badge: "2x PAY · ICE · 24:10".
]=]
function CoffeeRules.badgeText(buyer: string, seconds: number): string
	return `{CoffeeConstants.TEXT.badge} · {string.upper(buyer)} · {CoffeeRules.clock(seconds)}`
end

--[=[
	Whether a Gleam `balance` (nil: not loaded) pays for a coffee.
]=]
function CoffeeRules.affords(balance: number?): boolean
	return balance ~= nil and balance >= CoffeeConstants.GLEAM_PRICE
end

--[=[
	The Gleam half of a Gleam purchase (a premium-slice mutator, in place): takes CoffeeConstants.GLEAM_PRICE off, or
	refuses (false) and leaves the balance when it is short.
]=]
function CoffeeRules.payGleam(premium: PlayerDataTypes.Premium): boolean
	if premium.balance < CoffeeConstants.GLEAM_PRICE then
		return false
	end
	premium.balance -= CoffeeConstants.GLEAM_PRICE
	return true
end

--[=[
	The toast for a player who is short of Gleam.
]=]
function CoffeeRules.shortLine(): string
	return string.format(CoffeeConstants.TEXT.short, CoffeeConstants.GLEAM_PRICE)
end

--[=[
	The office PA's line for `buyer`.
]=]
function CoffeeRules.paLine(buyer: string): string
	return string.format(CoffeeConstants.TEXT.pa, buyer)
end

return CoffeeRules
