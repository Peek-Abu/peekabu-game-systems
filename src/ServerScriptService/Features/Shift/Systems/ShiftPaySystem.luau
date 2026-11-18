--!strict
--[=[
	ShiftPaySystem: pays the crew when the shift's review opens. It follows Shift's state (`ShiftServiceServer.changed`):
	the first time a shift reaches its review (phase "results", any outcome: clock-out or timeout), every crew member
	still present (`source.present`, knocked-out players included, de-duplicated) gets the shift's full pay through
	`pay`: Credits = the shift's pay from ShiftQuotaFormulas.breakdown (Gloom removed x CREDITS_PER_GLOOM plus the banked
	valuables, overtime included), times the review's `payScale` (Coffee for the crew), and saved Gloom = floor(cleared x SAVED_GLOOM_PER_CLEARED), times
	the same `payScale` (owner 11-15: coffee doubles the Gloom you keep too), rounded down. Players who left get
	nothing. A reset never reaches "results" and pays nothing; a shift pays once. Each payment runs in its own guard, so
	one failure never skips the rest of the crew. A refused or failed payment retries up to 5 times, 1 s apart, while the
	player is still present.

	`start` takes its source and the payment so the spec drives it without a running shift.

	@class ShiftPaySystem
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Logger = require(ReplicatedStorage.Shared.Core.Logger)
local SignalTyped = require(ReplicatedStorage.Shared.Core.SignalTyped)
local CurrencyConstants = require(ReplicatedStorage.Shared.Features.Currency.Data.CurrencyConstants)
local ShiftTypes = require(ReplicatedStorage.Shared.Features.Shift.Data.ShiftTypes)
local ShiftQuotaFormulas = require(ReplicatedStorage.Shared.Features.Shift.Utils.ShiftQuotaFormulas)

export type Source = {
	changed: SignalTyped.Signal<ShiftTypes.ShiftState>,
	-- The shift's review, once built (nil before it and after a reset).
	results: () -> ShiftTypes.ShiftResults?,
	-- The crew members still in the server.
	present: () -> { number },
}

export type Pay = (userId: number, amounts: CurrencyConstants.Amounts) -> boolean

-- Schedules `fn` after `seconds` (task.delay-shaped; the spec injects its own).
export type Wait = (seconds: number, fn: () -> ()) -> unknown

local MAX_ATTEMPTS = 5
local RETRY_SECONDS = 1

local log = Logger.new("ShiftPaySystem")

local ShiftPaySystem = {}

--[=[
	What one crew member is paid for `results`: Credits (the breakdown's total pay) and saved Gloom.
]=]
function ShiftPaySystem.amounts(results: ShiftTypes.ShiftResults): CurrencyConstants.Amounts
	local split = ShiftQuotaFormulas.breakdown(results.cleared, results.dust or 0, results.bonus)
	local scale = results.payScale or 1
	return {
		credits = math.floor(split.credits * scale),
		gloom = math.floor(ShiftQuotaFormulas.savedGloom(results.cleared) * scale),
	}
end

-- One payment attempt; a refusal (profile locked by a transaction, or still loading) or a throw retries while the player
-- is still in the game (`stillPaying`). A success ends the retries.
local function payWithRetry(
	label: string,
	userId: number,
	amounts: CurrencyConstants.Amounts,
	attempt: number,
	pay: Pay,
	stillPaying: (userId: number) -> boolean,
	schedule: Wait
)
	local ok, granted = xpcall(pay, function(err: unknown): unknown
		log:error(`pay for {userId} in {label} failed (attempt {attempt}): {err}`)
		return err
	end, userId, table.clone(amounts))
	if ok and granted then
		return
	end
	if attempt >= MAX_ATTEMPTS then
		log:warn(`pay for {userId} in {label} was never credited after {attempt} attempts (profile busy or not loaded)`)
		return
	end
	schedule(RETRY_SECONDS, function()
		if not stillPaying(userId) then
			return
		end
		payWithRetry(label, userId, amounts, attempt + 1, pay, stillPaying, schedule)
	end)
end

local function totalOf(amounts: CurrencyConstants.Amounts): number
	local total = 0
	for _, amount in amounts do
		total += amount
	end
	return total
end

--[=[
	Pays `amounts` once to each of `userIds` (de-duplicated) through `pay`, with the same retries as a shift's pay while
	`stillPaying(userId)` holds (the Night Shift week bonus). `label` names the payment in the logs. Nothing for a zero
	amount.
]=]
function ShiftPaySystem.payAll(
	label: string,
	userIds: { number },
	amounts: CurrencyConstants.Amounts,
	pay: Pay,
	stillPaying: (userId: number) -> boolean,
	wait: Wait?
)
	if totalOf(amounts) <= 0 then
		return
	end
	local schedule: Wait = wait or task.delay
	local seen: { [number]: true } = {}
	for _, userId in userIds do
		if not seen[userId] then
			seen[userId] = true
			payWithRetry(label, userId, table.clone(amounts), 1, pay, stillPaying, schedule)
		end
	end
end

--[=[
	Starts paying reviews from `source` through `pay`. Returns the function that stops it.
]=]
function ShiftPaySystem.start(source: Source, pay: Pay, wait: Wait?): () -> ()
	local paid: { [number]: true } = {}
	local stopped = false

	local function stillPaying(userId: number): boolean
		return not stopped and table.find(source.present(), userId) ~= nil
	end

	local connection = source.changed:Connect(function(state: ShiftTypes.ShiftState)
		if state.phase ~= "results" or paid[state.shift] then
			return
		end
		local results = source.results()
		if results == nil then
			return
		end
		paid[state.shift] = true
		ShiftPaySystem.payAll(
			`shift {state.shift}`,
			source.present(),
			ShiftPaySystem.amounts(results),
			pay,
			stillPaying,
			wait
		)
	end)
	return function()
		stopped = true
		connection:Disconnect()
	end
end

return ShiftPaySystem
