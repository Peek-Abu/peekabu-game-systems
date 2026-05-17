--!strict
--[=[
	Continuous ATB (Active Time Battle) priority queue for battle turn order.
	
	## How It Works
	
	Each battler has a `nextActionTime` that advances by their action interval
	(ACTION_UNIT / speed) each time they act. The queue always serves whoever
	has the smallest nextActionTime next — producing the correct proportional
	action counts: speeds 200:150:100 → actions in a 4:3:2 ratio over time.
	
	## Example
	
	With battlers A=200, B=150, C=100 (intervals: 0.5, 0.667, 1.0):
	- True ATB 9-action cycle: A, B, A, C, B, A, A, B, C (repeating)
	- Action ratio A:B:C = 4:3:2
	
	## Key Concepts
	
	- **ACTION_UNIT**: Abstract "gauge fill" unit (100). Think of it as an ATB bar.
	- **Interval**: Time between actions = ACTION_UNIT / speed
	- **nextActionTime**: Simulation time when this battler acts next
	- **Rescheduling**: After acting, nextActionTime += interval
	
	The queue is built ONCE at battle start and never reset. Battlers are
	continuously rescheduled after each action until the battle ends.
	
	@class ActionAgenda
]=]

local ActionAgenda = {}
ActionAgenda.__index = ActionAgenda

-- ── Constants ─────────────────────────────────────────────────────────────────

-- Abstract "gauge fill" unit. A character with speed S fills the gauge
-- at rate S per time, so they act every ACTION_UNIT/S time units.
-- Think of it like an ATB bar that fills to 100.
local ACTION_UNIT = 100

-- ── Types ─────────────────────────────────────────────────────────────────────

export type AgendaEntry = {
	battler: any,       -- the Battler object
	nextActionTime: number, -- simulation time at which this battler acts next
	interval: number,   -- ACTION_UNIT / speed — fixed per battler
}

export type ActionAgenda = typeof(setmetatable({
	_queue = {} :: { AgendaEntry },
	_currentTime = 0,
}, ActionAgenda))

-- ── Constructor ───────────────────────────────────────────────────────────────

function ActionAgenda.new(): ActionAgenda
	return setmetatable({
		_queue = {},
		_currentTime = 0,
	}, ActionAgenda)
end

-- ── Private helpers ───────────────────────────────────────────────────────────

-- Re-sort the queue by nextActionTime ascending, then speed descending for ties.
function ActionAgenda:_sort()
	table.sort(self._queue, function(a, b)
		if a.nextActionTime ~= b.nextActionTime then
			return a.nextActionTime < b.nextActionTime
		end
		-- Speed tiebreak: faster battler goes first
		return a.battler.speed > b.battler.speed
	end)
end

-- ── Public API ────────────────────────────────────────────────────────────────

--- Initialise the queue with all alive participants.
--- All battlers start with nextActionTime = their first interval
function ActionAgenda:build(allies: { any }, enemies: { any })
	self._queue = {}
	self._currentTime = 0

	local allParticipants: { any } = {}
	for _, b in allies do
		if b:isAlive() then table.insert(allParticipants, b) end
	end
	for _, b in enemies do
		if b:isAlive() then table.insert(allParticipants, b) end
	end

	for _, b in allParticipants do
		local interval = ACTION_UNIT / math.max(1, b.speed)
		table.insert(self._queue, {
			battler = b,
			nextActionTime = interval, -- first action after one interval
			interval = interval,
		})
	end

	self:_sort()
end

--- Re-add a battler to the queue after they have acted.
function ActionAgenda:reschedule(battler: any)
	-- Find the entry for this battler
	for _, entry in self._queue do
		if entry.battler == battler then
			entry.nextActionTime = self._currentTime + entry.interval
			self:_sort()
			return
		end
	end
	-- Battler not in queue — add fresh (e.g. if they were removed and re-added)
	local interval = ACTION_UNIT / math.max(1, battler.speed)
	table.insert(self._queue, {
		battler = battler,
		nextActionTime = self._currentTime + interval,
		interval = interval,
	})
	self:_sort()
end

--- Remove a battler entirely (e.g. they fainted).
function ActionAgenda:remove(battler: any)
	for i = #self._queue, 1, -1 do
		if self._queue[i].battler == battler then
			table.remove(self._queue, i)
		end
	end
end

--- Returns the next battler to act (without consuming the slot).
function ActionAgenda:peek(): AgendaEntry?
	return self._queue[1]
end

--- Consume the front of the queue, advance `_currentTime`, and return the entry.
function ActionAgenda:next(): AgendaEntry?
	if #self._queue == 0 then return nil end

	local entry = self._queue[1]
	-- Advance simulation clock to this battler's action time
	self._currentTime = entry.nextActionTime
	-- Remove from front — caller must call reschedule() after action resolves
	table.remove(self._queue, 1)
	return entry
end

--- Returns true if no battlers are queued.
function ActionAgenda:isEmpty(): boolean
	return #self._queue == 0
end

--- Remove the next queued action belonging to battler (stagger mechanic).
function ActionAgenda:stagger(battler: any): boolean
	for _, entry in self._queue do
		if entry.battler == battler then
			-- Push their next action time forward by one interval
			entry.nextActionTime = entry.nextActionTime + entry.interval
			self:_sort()
			local nextT = math.floor(entry.nextActionTime * 100) / 100
			print(`{battler.itemType} is staggered — next action delayed by {nextT} time units`)
			return true
		end
	end
	return false
end

--- Kept for compatibility: same as stagger() in the continuous model.
function ActionAgenda:removeNextSlotFor(battler: any): boolean
	return self:stagger(battler)
end

--- Debug: return a snapshot of the upcoming action order (up to N entries).
function ActionAgenda:debugPreview(n: number?): string
	local limit = math.min(n or 20, #self._queue)
	local lines = {}
	for i = 1, limit do
		local e = self._queue[i]
		local delayedT = math.floor(e.nextActionTime * 100) / 100
		local intervalR = math.floor(e.interval * 100) / 100
		table.insert(lines, `  [{i}] {e.battler.itemType} @ t={delayedT} (interval={intervalR})`)
	end
	return table.concat(lines, "\n")
end

return ActionAgenda
