--!strict
--[=[
	VfxEmitterPool: spare effect rigs kept for reuse, by key (a burst id). A rig is built once (its emitters set up
	once) and handed out again after it has played out, so a busy shift never rebuilds emitters. Up to `capacity`
	idle rigs are kept per key; one released beyond that is destroyed.

	@class VfxEmitterPool
]=]

export type VfxEmitterPool<T> = {
	acquire: (self: VfxEmitterPool<T>, key: string, build: () -> T) -> T,
	release: (self: VfxEmitterPool<T>, key: string, item: T) -> (),
	idle: (self: VfxEmitterPool<T>, key: string?) -> number,
	clear: (self: VfxEmitterPool<T>) -> (),
}

local VfxEmitterPool = {}

function VfxEmitterPool.new<T>(capacity: number, destroy: (T) -> ()): VfxEmitterPool<T>
	local spare: { [string]: { T } } = {}

	local pool: VfxEmitterPool<T> = {
		acquire = function(_self, key, build)
			local list = spare[key]
			local item = if list ~= nil then table.remove(list) else nil
			if item ~= nil then
				return item
			end
			return build()
		end,

		release = function(_self, key, item)
			local list = spare[key]
			if list == nil then
				list = {}
				spare[key] = list
			end
			if table.find(list, item) ~= nil then
				return
			end
			if #list >= capacity then
				destroy(item)
				return
			end
			table.insert(list, item)
		end,

		idle = function(_self, key)
			if key ~= nil then
				local list = spare[key]
				return if list ~= nil then #list else 0
			end
			local total = 0
			for _, list in spare do
				total += #list
			end
			return total
		end,

		clear = function(_self)
			for _, list in spare do
				for _, item in list do
					destroy(item)
				end
			end
			table.clear(spare)
		end,
	}
	return pool
end

return VfxEmitterPool
