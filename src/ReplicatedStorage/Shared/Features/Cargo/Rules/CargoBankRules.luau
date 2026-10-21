--!strict
--[=[
	CargoBankRules: loading at the truck (Cleanup Crew spec §4 "Banking", §6.4). `onBed` says whether a
	point in the bed part's object space is in the truck bed; `deposit` says what the hands item and the
	pockets are worth: trash adds to clearance, salvage to bonus. Pure; the claim that stops a double count
	is CargoClaimTracker.

	@class CargoBankRules
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CargoConstants = require(ReplicatedStorage.Shared.Features.Cargo.Data.CargoConstants)
local CargoTypes = require(ReplicatedStorage.Shared.Features.Cargo.Data.CargoTypes)

type CargoEntry = CargoTypes.CargoEntry
type Deposit = CargoTypes.Deposit

local CargoBankRules = {}

--[=[
	True when `localPoint` (a HumanoidRootPart position in the bed's object space) is over the bed's
	footprint (plus BED_TOLERANCE) and no higher than BED_HEIGHT above its top.
]=]
function CargoBankRules.onBed(localPoint: Vector3, bedSize: Vector3): boolean
	local half = bedSize / 2
	local tolerance = CargoConstants.BED_TOLERANCE
	return math.abs(localPoint.X) <= half.X + tolerance
		and math.abs(localPoint.Z) <= half.Z + tolerance
		and localPoint.Y >= -half.Y - tolerance
		and localPoint.Y <= half.Y + CargoConstants.BED_HEIGHT
end

-- Server-side reach to the nearest point on the bed footprint, including the corners.
function CargoBankRules.canLoad(localPoint: Vector3, bedSize: Vector3): boolean
	local half = bedSize / 2
	local dx = math.max(0, math.abs(localPoint.X) - half.X)
	local dz = math.max(0, math.abs(localPoint.Z) - half.Z)
	return dx * dx + dz * dz <= CargoConstants.LOAD_REACH * CargoConstants.LOAD_REACH
		and localPoint.Y >= -half.Y - CargoConstants.BED_TOLERANCE
		and localPoint.Y <= half.Y + CargoConstants.BED_HEIGHT
end

-- Automatic deposits require a bottom resting on the bed, not a flight over it.
function CargoBankRules.landedOnBed(localPoint: Vector3, itemSize: Vector3, bedSize: Vector3): boolean
	return math.abs(localPoint.X) <= bedSize.X / 2
		and math.abs(localPoint.Z) <= bedSize.Z / 2
		and math.abs(localPoint.Y - itemSize.Y / 2 - bedSize.Y / 2) <= CargoConstants.LANDING_TOLERANCE
end

--[=[
	What loading `hands` (may be nil) and `pockets` is worth. Nil with a reason for an empty load or a kind
	the catalog does not know.
]=]
function CargoBankRules.deposit(
	hands: CargoEntry?,
	pockets: { CargoEntry },
	lookup: (kind: string) -> CargoTypes.ItemDef?
): (Deposit?, string?)
	local entries: { CargoEntry } = {}
	if hands ~= nil then
		table.insert(entries, hands)
	end
	for _, entry in pockets do
		table.insert(entries, entry)
	end
	local deposit: Deposit = { clearance = 0, bonus = 0, items = {} }
	for _, entry in entries do
		local def = lookup(entry.kind)
		if def == nil then
			return nil, `unknown cargo "{entry.kind}"`
		end
		local value = math.max(0, entry.value)
		if def.category == "trash" then
			deposit.clearance += value
		else
			deposit.bonus += value
		end
		table.insert(deposit.items, {
			kind = entry.kind,
			category = def.category,
			value = value,
			visual = entry.visual,
			appraisal = entry.appraisal,
			overtime = if entry.overtime == true then true else nil,
		})
	end
	if #deposit.items == 0 then
		return nil, "nothing to load"
	end
	return deposit, nil
end

return CargoBankRules
