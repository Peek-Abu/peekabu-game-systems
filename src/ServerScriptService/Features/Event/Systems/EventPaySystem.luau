--!strict
--[=[
	EventPaySystem: pays a live event's money when a shift's review opens. It follows Shift's state like ShiftPaySystem:
	the first time a shift reaches "results", every crew member still present (de-duplicated) is paid once through
	`pay`, which works out and writes their share (EventServiceServer:payShift). Nothing is paid in a training run or
	while no event is live. Each payment runs in its own thread (a friend check may yield) and its own guard; a refused
	or failed payment retries up to 5 times, 1 s apart, while the player is still present.

	@class EventPaySystem
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Logger = require(ReplicatedStorage.Shared.Core.Logger)
local SignalTyped = require(ReplicatedStorage.Shared.Core.SignalTyped)
local EventTypes = require(ReplicatedStorage.Shared.Features.Event.Data.EventTypes)
local ShiftTypes = require(ReplicatedStorage.Shared.Features.Shift.Data.ShiftTypes)

export type Source = {
	changed: SignalTyped.Signal<ShiftTypes.ShiftState>,
	results: () -> ShiftTypes.ShiftResults?,
	present: () -> { number },
	training: () -> boolean,
	live: () -> EventTypes.Event?,
}

-- Pays one player their share; true once it is written (or nothing was owed).
export type Pay = (
	userId: number,
	event: EventTypes.Event,
	results: ShiftTypes.ShiftResults,
	crew: { number }
) -> boolean

export type Wait = (seconds: number, fn: () -> ()) -> unknown
-- Runs `fn` in its own thread (task.spawn-shaped; the spec runs it inline).
export type Spawn = (fn: () -> ()) -> ()

local MAX_ATTEMPTS = 5
local RETRY_SECONDS = 1

local log = Logger.new("EventPaySystem")

local EventPaySystem = {}

function EventPaySystem.start(source: Source, pay: Pay, wait: Wait?, spawn: Spawn?): () -> ()
	local paid: { [number]: true } = {}
	local stopped = false
	local schedule: Wait = wait or task.delay
	local run: Spawn = spawn or function(fn: () -> ())
		task.spawn(fn)
	end

	local function isPresent(userId: number): boolean
		return table.find(source.present(), userId) ~= nil
	end

	local function payWithRetry(
		shift: number,
		userId: number,
		event: EventTypes.Event,
		results: ShiftTypes.ShiftResults,
		crew: { number },
		attempt: number
	)
		local ok, granted = xpcall(pay, function(err: unknown): unknown
			log:error(`event pay for {userId} in shift {shift} failed (attempt {attempt}): {err}`)
			return err
		end, userId, event, results, crew)
		if ok and granted then
			return
		end
		if attempt >= MAX_ATTEMPTS then
			log:warn(`event pay for {userId} in shift {shift} was never written after {attempt} attempts`)
			return
		end
		schedule(RETRY_SECONDS, function()
			if stopped or not isPresent(userId) then
				return
			end
			payWithRetry(shift, userId, event, results, crew, attempt + 1)
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
		local event = source.live()
		if event == nil or source.training() then
			return
		end
		local crew: { number } = {}
		for _, userId in source.present() do
			if not table.find(crew, userId) then
				table.insert(crew, userId)
			end
		end
		for _, userId in crew do
			local shared = table.clone(crew)
			run(function()
				payWithRetry(state.shift, userId, event, results, shared, 1)
			end)
		end
	end)
	return function()
		stopped = true
		connection:Disconnect()
	end
end

return EventPaySystem
