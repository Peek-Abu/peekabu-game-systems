--!strict
--[=[
	ShiftPaySystem: pays the crew when the shift's review opens. It follows Shift's state (`ShiftServiceServer.changed`):
	the first time a shift reaches its review (phase "results", any outcome: clock-out or timeout), every crew member
	still present (`source.present`, knocked-out players included, de-duplicated) gets the shift's full pay through
	`pay`: Credits = the shift's pay from ShiftQuotaFormulas.breakdown (Gloom removed x CREDITS_PER_GLOOM plus the banked
	valuables, overtime included) and saved Gloom = floor(cleared x SAVED_GLOOM_PER_CLEARED). Players who left get
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
	return {
		credits = split.credits,
		gloom = ShiftQuotaFormulas.savedGloom(results.cleared),
	}
end

--[=[
	Starts paying reviews from `source` through `pay`. Returns the function that stops it.
]=]
function ShiftPaySystem.start(source: Source, pay: Pay, wait: Wait?): () -> ()
	local paid: { [number]: true } = {}
	local stopped = false
	local schedule: Wait = wait or task.delay

	local function isPresent(userId: number): boolean
		return table.find(source.present(), userId) ~= nil
	end

	-- One payment attempt; a refusal (profile locked by a transaction, or still loading) or a throw retries while the
	-- player is still in the game. `shift` is paid once per player: a success ends the retries.
	local function payWithRetry(shift: number, userId: number, amounts: CurrencyConstants.Amounts, attempt: number)
		local ok, granted = xpcall(pay, function(err: unknown): unknown
			log:error(`pay for {userId} in shift {shift} failed (attempt {attempt}): {err}`)
			return err
		end, userId, table.clone(amounts))
		if ok and granted then
			return
		end
		if attempt >= MAX_ATTEMPTS then
			log:warn(
				`pay for {userId} in shift {shift} was never credited after {attempt} attempts (profile busy or not loaded)`
			)
			return
		end
		schedule(RETRY_SECONDS, function()
			if stopped or not isPresent(userId) then
				return
			end
			payWithRetry(shift, userId, amounts, attempt + 1)
		end)
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
		local amounts = ShiftPaySystem.amounts(results)
		local total = 0
		for _, amount in amounts do
			total += amount
		end
		if total <= 0 then
			return
		end
		local seen: { [number]: true } = {}
		for _, userId in source.present() do
			if not seen[userId] then
				seen[userId] = true
				payWithRetry(state.shift, userId, table.clone(amounts), 1)
			end
		end
	end)
	return function()
		stopped = true
		connection:Disconnect()
	end
end

return ShiftPaySystem
