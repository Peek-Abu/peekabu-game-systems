--!strict
--[=[
	UIBuildQueueSystem: spreads a screen's heavy builds over frames. A job queued now runs on a later frame; each frame
	runs queued jobs in order until BUDGET seconds are spent (at least one job a frame), so a screen that opens a dozen
	3D cards at once no longer clones every model in the frame it opens (Lobby, 2026-11-15: the Shop's 12 cards were
	one 60-100 ms frame of work after the strap fix; 101-150 ms before it).

	- `enqueue(job)`: queues `job` on the shared queue (drained on Heartbeat, connected only while jobs wait) and
	  returns its cancel. Cancelling a job that already ran, or twice, does nothing.
	- `new(budget, clock?)`: a queue of its own that runs only when `step` is called (the specs drive it by hand).
	  `step` runs one frame's jobs and returns how many ran; `pending` counts the jobs waiting.
	- A job that errors is logged and the queue carries on with the next one.

	@class UIBuildQueueSystem
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Logger = require(ReplicatedStorage.Shared.Core.Logger)

local log = Logger.new("UIBuildQueueSystem")

-- Seconds of queued work a frame may run (after its first job). A card's clone is 2.5-4 ms, so about two a frame.
local BUDGET = 0.004

export type Queue = {
	enqueue: (self: Queue, job: () -> ()) -> () -> (),
	step: (self: Queue) -> number,
	pending: (self: Queue) -> number,
}

type Entry = { job: () -> (), cancelled: boolean }

local UIBuildQueueSystem = {
	BUDGET = BUDGET,
}

function UIBuildQueueSystem.new(budget: number, clock: (() -> number)?): Queue
	local now = clock or os.clock
	local entries: { Entry } = {}
	local waiting = 0

	local queue: Queue = {
		enqueue = function(_self, job)
			local entry: Entry = { job = job, cancelled = false }
			table.insert(entries, entry)
			waiting += 1
			return function()
				-- `cancelled` is also set when the job runs, so only a job still waiting is taken off the count.
				if not entry.cancelled then
					entry.cancelled = true
					waiting -= 1
				end
			end
		end,

		step = function(_self)
			local started = now()
			local ran = 0
			while #entries > 0 do
				local entry = entries[1]
				table.remove(entries, 1)
				if not entry.cancelled then
					waiting -= 1
					-- Ran: a later cancel is a no-op (it is out of the queue).
					entry.cancelled = true
					xpcall(entry.job, function(problem: unknown)
						log:warn(`a queued UI build failed: {problem}`)
					end)
					ran += 1
					if now() - started >= budget then
						break
					end
				end
			end
			return ran
		end,

		pending = function(_self)
			return waiting
		end,
	}
	return queue
end

local shared = UIBuildQueueSystem.new(BUDGET)
local draining: RBXScriptConnection? = nil

function UIBuildQueueSystem.enqueue(job: () -> ()): () -> ()
	local cancel = shared:enqueue(job)
	if draining == nil then
		draining = RunService.Heartbeat:Connect(function()
			shared:step()
			if shared:pending() == 0 then
				local connection = draining
				draining = nil
				if connection ~= nil then
					connection:Disconnect()
				end
			end
		end)
	end
	return cancel
end

return UIBuildQueueSystem
