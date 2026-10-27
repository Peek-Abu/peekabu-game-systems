--!strict
--[=[
	WorkOrderRegistry: the daily Work Order catalog, looked up by id and handed out one UTC day at a time. Data-driven:
	a new order is one row in WORK_ORDERS, so adding one never touches the rotation or a caller.

	The rotation is deterministic and shared by every server: the order is `dayIndex(now) % #WORK_ORDERS`, so the whole
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

local WORK_ORDERS: { WorkOrder } = {
	{ id = "clear-the-floor", kind = "piles", target = 40, label = "Clear 40 piles" },
	{ id = "mind-the-cargo", kind = "cargo", target = 8, label = "Bank 8 pieces of cargo" },
	{ id = "overtime-overtime", kind = "salvage", target = 3, label = "Recover 3 pieces of salvage in overtime" },
	{ id = "double-shift", kind = "shifts", target = 2, label = "Work 2 shifts" },
	{ id = "spotless-shift", kind = "piles", target = 60, label = "Clear 60 piles" },
}

local WorkOrderRegistry = {}

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
		if order.target < 1 or order.target ~= math.floor(order.target) then
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
for _, order in WORK_ORDERS do
	table.freeze(order)
end
table.freeze(WORK_ORDERS)

function WorkOrderRegistry.get(id: string): WorkOrder?
	for _, order in WORK_ORDERS do
		if order.id == id then
			return order
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
	return WORK_ORDERS[WorkOrderRegistry.dayIndex(now) % #WORK_ORDERS + 1]
end

return WorkOrderRegistry
