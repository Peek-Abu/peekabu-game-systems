--!strict
--[=[
	WorkOrderRegistry: the daily Work Order catalog, looked up by id and handed out one UTC day at a time. Data-driven:
	new basic orders are rows in WORK_ORDERS. Historical UTC days retain LEGACY_ORDERS so saved progress keeps its target.

	The rotation is deterministic and shared by every server: the day selects from its applicable catalog, so the whole
	UTC day gets one order, the next day moves on, and a cycle shows every order once before any repeats. The catalog is
	checked at load (`check`): at least one order, non-empty unique ids and labels, a known kind, a positive whole
	target.

	@class WorkOrderRegistry
]=]

export type Kind = "piles" | "cargo" | "salvage" | "shifts"

export type WorkOrder = {
	id: string,
	kind: Kind,
	target: number,
	label: string,
}

local DAY_SECONDS = 86400

-- The counters a shift reports, so every target below is something the server can measure.
local KINDS: { [string]: boolean } = {
	piles = true,
	cargo = true,
	salvage = true,
	shifts = true,
}

local LEGACY_ORDERS: { WorkOrder } = {
	{ id = "clear-the-floor", kind = "piles", target = 40, label = "Clear 40 piles" },
	{ id = "mind-the-cargo", kind = "cargo", target = 8, label = "Bank 8 pieces of cargo" },
	{ id = "overtime-overtime", kind = "salvage", target = 3, label = "Recover 3 pieces of salvage in overtime" },
	{ id = "double-shift", kind = "shifts", target = 2, label = "Work 2 shifts" },
	{ id = "spotless-shift", kind = "piles", target = 60, label = "Clear 60 piles" },
}

-- Activate at the next UTC reset; old saved days must keep the targets that gave them meaning.
local BASIC_START_DAY = 20754 --2026-10-28UTC
local WORK_ORDERS: { WorkOrder } = {
	{ id = "daily-clear-small", kind = "piles", target = 8, label = "Help clear 8 piles" },
	{ id = "daily-load", kind = "cargo", target = 4, label = "Bank 4 pieces of cargo" },
	{ id = "daily-shift", kind = "shifts", target = 1, label = "Work 1 shift" },
	{ id = "daily-clear-room", kind = "piles", target = 12, label = "Help clear 12 piles" },
}

local WorkOrderRegistry = {
	-- Tunable MVP completion payout.
	REWARD_CREDITS = 100,
}

-- Whether `orders` is a usable catalog (see the header).
function WorkOrderRegistry.check(orders: { WorkOrder }): boolean
	if #orders == 0 then
		return false
	end
	local seen: { [string]: boolean } = {}
	for _, order in orders do
		if order.id == "" or seen[order.id] == true then
			return false
		end
		if order.label == "" or KINDS[order.kind] ~= true then
			return false
		end
		if order.target < 1 or order.target >= math.huge or order.target ~= math.floor(order.target) then
			return false
		end
		seen[order.id] = true
	end
	return true
end

assert(
	WorkOrderRegistry.check(WORK_ORDERS),
	"WorkOrderRegistry: the catalog is malformed (see WorkOrderRegistry.check)"
)
assert(WorkOrderRegistry.check(LEGACY_ORDERS), "WorkOrderRegistry: legacy catalog invalid")
for _, pool in { WORK_ORDERS, LEGACY_ORDERS } do
	for _, order in pool do
		table.freeze(order)
	end
	table.freeze(pool)
end

function WorkOrderRegistry.get(id: string): WorkOrder?
	for _, pool in { WORK_ORDERS, LEGACY_ORDERS } do
		for _, order in pool do
			if order.id == id then
				return order
			end
		end
	end
	return nil
end

-- Every order, in catalog order (a copy).
function WorkOrderRegistry.all(): { WorkOrder }
	return table.clone(WORK_ORDERS)
end

-- The UTC day `now` falls in, counted from the Unix epoch: the rotation step, and the key a stored completion is
-- checked against.
function WorkOrderRegistry.dayIndex(now: number): number
	return math.floor(now / DAY_SECONDS)
end

-- The order for `now`'s UTC day; every server and every client agrees without talking to each other.
function WorkOrderRegistry.orderFor(now: number): WorkOrder
	local day = WorkOrderRegistry.dayIndex(now)
	local pool = if day < BASIC_START_DAY then LEGACY_ORDERS else WORK_ORDERS
	return pool[day % #pool + 1]
end

return WorkOrderRegistry
