--!strict
--[=[
	ShiftPaySystem: pays the crew when the shift's review opens. It follows Shift's state (`ShiftServiceServer.changed`):
	the first time a shift reaches its review (phase "results", any outcome: clock-out or timeout), every crew member
	still present (`source.present`, knocked-out players included, de-duplicated) gets the shift's full pay through
	`pay`: Credits = the shift's pay from ShiftQuotaFormulas.breakdown (Gloom removed x GLEAM_PER_GLOOM plus the banked
	valuables, overtime included) and saved Gloom = floor(cleared x SAVED_GLOOM_PER_CLEARED). Players who left get
	nothing. A reset never reaches "results" and pays nothing; a shift pays once. Each payment runs in its own guard, so
	one failure never skips the rest of the crew.

	`start` takes its source and the payment so the spec drives it without a running shift.

	@class ShiftPaySystem
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Logger = require(ReplicatedStorage.Shared.Core.Logger)
local SignalTyped = require(ReplicatedStorage.Shared.Core.SignalTyped)
local CurrencyConstants = require(ReplicatedStorage.Shared.Features.Currency.Data.CurrencyConstants)
local ShiftConstants = require(ReplicatedStorage.Shared.Features.Shift.Data.ShiftConstants)
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

local log = Logger.new("ShiftPaySystem")

local ShiftPaySystem = {}

--[=[
	What one crew member is paid for `results`: Credits (the breakdown's total pay) and saved Gloom.
]=]
function ShiftPaySystem.amounts(results: ShiftTypes.ShiftResults): CurrencyConstants.Amounts
	local split = ShiftQuotaFormulas.breakdown(results.cleared, results.dust or 0, results.bonus)
	return {
		credits = split.gleam,
		gloom = math.floor(math.max(0, results.cleared) * ShiftConstants.SAVED_GLOOM_PER_CLEARED),
	}
end

--[=[
	Starts paying reviews from `source` through `pay`. Returns the function that stops it.
]=]
function ShiftPaySystem.start(source: Source, pay: Pay): () -> ()
	local paid: { [number]: true } = {}

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
				local ok, granted = xpcall(pay, function(err: unknown): unknown
					log:error(`pay for {userId} in shift {state.shift} failed: {err}`)
					return err
				end, userId, table.clone(amounts))
				if ok and not granted then
					log:warn(`pay for {userId} in shift {state.shift} was not credited (no profile, or nothing to add)`)
				end
			end
		end
	end)
	return function()
		connection:Disconnect()
	end
end

return ShiftPaySystem
