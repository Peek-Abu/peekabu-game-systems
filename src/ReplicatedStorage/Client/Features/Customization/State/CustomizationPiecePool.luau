--!strict
--[=[
	CustomizationPiecePool: spare cosmetic pieces, kept in the world and capped, keyed by cosmetic id (R4 spec,
	Section 1). Take first, clone only on a miss.

	A cosmetic is one or more Accessory pieces (shoes are a Left and a Right), so the pool stores whole
	SETS: one entry is every piece of one copy of a cosmetic.

	Parked like the puppets: anchored and moved far away under the pool's container, never unparented
	or destroyed (cloning a cosmetic costs ms, and a destroy burst hitches — R4 spike measurements).
	Released pieces lose their binding constraints, so nothing still ties a parked piece to a rig.
	Transparency is never touched: the art's own transparency must come back intact.

	@class CustomizationPiecePool
]=]

export type CustomizationPiecePool = {
	container: Instance,
	cap: number,
	sets: { [string]: { { Accessory } } },
	parked: number,
	hits: number,
	misses: number,
}

local CustomizationPiecePool = {}

CustomizationPiecePool.DEFAULT_CAP = 16
CustomizationPiecePool.PARKED_CFRAME = CFrame.new(0, 50000, 0)

--[=[
	@param container Instance -- where parked pieces live (a Folder in Workspace at runtime)
	@param cap number? -- spare sets kept per cosmetic id (default 16)
	@return CustomizationPiecePool
]=]
function CustomizationPiecePool.new(container: Instance, cap: number?): CustomizationPiecePool
	local limit = cap or CustomizationPiecePool.DEFAULT_CAP
	assert(limit >= 1, "PiecePool cap must be >= 1")
	return { container = container, cap = limit, sets = {}, parked = 0, hits = 0, misses = 0 }
end

--[=[
	A parked set for `id`, or nil (the caller clones fresh art). The pieces are still anchored and
	parked; the caller binds them.
	@param pool CustomizationPiecePool
	@param id string
	@return { Accessory }?
]=]
function CustomizationPiecePool.take(pool: CustomizationPiecePool, id: string): { Accessory }?
	local sets = pool.sets[id]
	local set = if sets ~= nil then table.remove(sets) else nil
	if set == nil then
		pool.misses += 1
		return nil
	end
	pool.hits += 1
	pool.parked -= 1
	return set
end

--[=[
	Parks a set of `id`'s pieces. Over the cap, the oldest parked set is destroyed.
	@param pool CustomizationPiecePool
	@param id string
	@param pieces { Accessory }
]=]
function CustomizationPiecePool.release(pool: CustomizationPiecePool, id: string, pieces: { Accessory })
	for _, piece in pieces do
		for _, descendant in piece:GetDescendants() do
			if descendant:IsA("RigidConstraint") then
				descendant:Destroy()
			elseif descendant:IsA("BasePart") then
				descendant.Anchored = true
			end
		end
		local handle = piece:FindFirstChild("Handle")
		if handle ~= nil and handle:IsA("BasePart") then
			handle.CFrame = CustomizationPiecePool.PARKED_CFRAME
		end
		piece.Parent = pool.container
	end
	local sets = pool.sets[id]
	if sets == nil then
		sets = {}
		pool.sets[id] = sets
	end
	table.insert(sets, pieces)
	pool.parked += 1
	while #sets > pool.cap do
		local oldest = table.remove(sets, 1)
		pool.parked -= 1
		if oldest ~= nil then
			for _, piece in oldest do
				piece:Destroy()
			end
		end
	end
end

--[=[
	Destroys every parked piece. The container belongs to the caller.
	@param pool CustomizationPiecePool
]=]
function CustomizationPiecePool.destroy(pool: CustomizationPiecePool)
	for _, sets in pool.sets do
		for _, set in sets do
			for _, piece in set do
				piece:Destroy()
			end
		end
	end
	table.clear(pool.sets)
	pool.parked = 0
end

return CustomizationPiecePool
