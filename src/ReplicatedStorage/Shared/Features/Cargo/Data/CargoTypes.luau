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
	-- The reference price: a trash item's fixed value, a valuable's typical (mid-range) value. A valuable's real
	-- value is rolled from valueMin..valueMax (CargoAppraisalFormulas) and scaled by depth, jackpot, damage and grime.
	value: number,
	-- A valuable's base range before depth (trash: both equal `value`).
	valueMin: number,
	valueMax: number,
	-- A rare richer variant of this kind (nil = none).
	jackpot: Jackpot?,
	-- Spawns grimy: pays a fraction of its value until vacuumed clean, and reads "$???" until appraised.
	grimy: boolean,
	-- Small enough to hide under a dust pile (buried loot).
	buriable: boolean,
	size: Size,
	throwable: boolean,
	-- Loses one value tier per impact (CargoConstants.FRAGILE_TIERS).
	fragile: boolean,
	-- Pulses a small noise every CargoConstants.RATTLE_INTERVAL while carried (M2: Noise).
	rattly: boolean,
	-- Becomes a pile after a deliberate throw lands off the truck (the recycling box).
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

-- A valuable's rare variant: its name prefix once appraised ("Gold-trim"), how often it is rolled, and its value
-- multiplier.
export type Jackpot = { name: string, chance: number, multiplier: number }

-- A rolled valuable before it is in the world: its base (true) value, after depth and any jackpot, and the jackpot's
-- name when it hit.
export type AppraisalRoll = { base: number, variant: string? }

-- A valuable's grime and appraisal state, as the item's attributes carry it (and a pocket entry keeps it):
-- `clean` 0 (fully grimy) to 1, `appraised` once its value is revealed (sticky), `sealed` once its grime is locked
-- (picked up while dirty: never cleaned again; absent = not sealed).
export type Appraisal = { base: number, variant: string?, clean: number, appraised: boolean, sealed: boolean? }

-- Visual-only server snapshot; never consulted for authoritative category or value.
export type VisualIdentity = { kitId: string, proxySize: Vector3, rotation: CFrame }

-- A carried or pocketed item as banking sees it: its kind and its value now (after any damage).
export type CargoEntry = {
	kind: string,
	value: number,
	visual: VisualIdentity?,
	-- A valuable's grime and appraisal (nil for trash).
	appraisal: Appraisal?,
}

export type DepositItem = {
	kind: string,
	category: Category,
	value: number,
	visual: VisualIdentity?,
	appraisal: Appraisal?,
}

-- What one Load is worth: trash adds to clearance, salvage to bonus (before any overtime multiplier).
export type Deposit = {
	clearance: number,
	bonus: number,
	items: { DepositItem },
}

-- The game's banking callback (Shift): adds the deposit and returns true plus the bonus it actually credited
-- (after any overtime multiplier; absent = deposit.bonus), or false to refuse it (no shift running). It must not
-- yield: claim, add and destroy run as one step.
export type BankHandler = (player: Player, deposit: Deposit) -> (boolean, number?)

export type SpawnOptions = {
	-- Visual-only override; otherwise inherited from the spawn parent ArtKitId ancestry.
	artKit: string?,
	-- Spawned invisible and un-interactable (under a pile) until revealed.
	hidden: boolean?,
	-- The value it carries (a scattered pocket item keeps its own); absent = the catalog value. Ignored for a grimy
	-- kind, whose value always follows its appraisal.
	value: number?,
	-- A grimy kind's base value and state (a planned roll, or a pocketed item's own); absent = a fresh, fully grimy
	-- item at the catalog value.
	appraisal: Appraisal?,
	-- Where it came from, for analytics: "desk" (searched) or "scatter" (a caught or leaving player's pockets);
	-- absent = "pile" when hidden, else "open".
	source: string?,
}

-- What a swap request does (M2, spec §6.3): take the newest pocketed item into empty hands, or trade a tiny
-- hands item for the oldest pocketed one.
export type SwapAction = "unpocket" | "swap"

return {}
