--!strict
--[=[
	CargoTypes: the Cargo feature's shapes (Cleanup Crew spec §4, "Cargo and carrying"). Types only
	(spec-exempt).

	@class CargoTypes
]=]

export type Category = "trash" | "salvage"

-- How big an item is: its carry weight, its drop noise, and whether it fits a pocket.
export type Size = "tiny" | "light" | "medium" | "heavy" | "bulky"

export type ItemDef = {
	id: string,
	name: string,
	category: Category,
	-- Clearance (trash) or bonus (salvage) when loaded undamaged.
	value: number,
	size: Size,
	throwable: boolean,
	-- Loses one value tier per impact (CargoConstants.FRAGILE_TIERS).
	fragile: boolean,
	-- Pulses a small noise every CargoConstants.RATTLE_INTERVAL while carried (M2: Noise).
	rattly: boolean,
	-- Becomes a pile when dropped (the recycling box).
	spills: boolean,
	-- A very loud drop (the water jug; its slippery puddle is M2).
	splashes: boolean,
	-- Leaves partly block the carrier's view (the office plant; M3 feel).
	blocksView: boolean,
	-- Never spawns in the open: only under a pile or in a desk / locker.
	hidden: boolean,
	-- One greed target is guaranteed per shift, placed deep.
	greed: boolean,
	-- Relative chance in the open-floor roll (0 = never rolled there).
	spawnWeight: number,
	-- Relative chance as desk / locker contents (0 = never).
	deskWeight: number,
	-- Graybox look.
	partSize: Vector3,
	color: Color3,
}

-- A carried or pocketed item as banking sees it: its kind and its value now (after any damage).
export type CargoEntry = {
	kind: string,
	value: number,
}

export type DepositItem = {
	kind: string,
	category: Category,
	value: number,
}

-- What one Load is worth: trash adds to clearance, salvage to bonus (before any overtime multiplier).
export type Deposit = {
	clearance: number,
	bonus: number,
	items: { DepositItem },
}

-- The game's banking callback (Shift): adds the deposit; false refuses it (no shift running). It must not
-- yield: claim, add and destroy run as one step.
export type BankHandler = (player: Player, deposit: Deposit) -> boolean

export type SpawnOptions = {
	-- Spawned invisible and un-interactable (under a pile) until revealed.
	hidden: boolean?,
	-- The value it carries (a scattered pocket item keeps its own); absent = the catalog value.
	value: number?,
}

-- What a swap request does (M2, spec §6.3): take the newest pocketed item into empty hands, or trade a tiny
-- hands item for the oldest pocketed one.
export type SwapAction = "unpocket" | "swap"

return {}
