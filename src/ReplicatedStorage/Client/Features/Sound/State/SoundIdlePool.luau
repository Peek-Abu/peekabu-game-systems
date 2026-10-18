--!strict
--[=[
	SoundIdlePool: the one-shot voices that finished playing, kept per place they play from (a foot, a pile, the 2D
	SoundService), so the next one-shot there re-points an existing Sound instead of creating one
	(SoundServiceClient:playOneShot). Most recently released first; at most `cap` idle voices per place (a refused
	voice is the caller's to destroy). Plain bookkeeping over opaque keys and items.

	@class SoundIdlePool
]=]

export type SoundIdlePool<K, T> = {
	-- An idle voice for `place` (removed from the pool), or nil.
	take: (self: SoundIdlePool<K, T>, place: K) -> T?,
	-- Keeps `voice` for `place`; false when `place` already holds `cap` idle voices.
	put: (self: SoundIdlePool<K, T>, place: K, voice: T, cap: number) -> boolean,
	-- Drops `voice` if it is idle at `place` (it was destroyed).
	remove: (self: SoundIdlePool<K, T>, place: K, voice: T) -> (),
	-- Drops every idle voice of `place` and returns them (to destroy).
	forget: (self: SoundIdlePool<K, T>, place: K) -> { T },
	-- The places holding at least one idle voice.
	places: (self: SoundIdlePool<K, T>) -> { K },
	-- Idle voices at `place`, or in all when nil.
	count: (self: SoundIdlePool<K, T>, place: K?) -> number,
}

local SoundIdlePool = {}

function SoundIdlePool.new<K, T>(): SoundIdlePool<K, T>
	local idle: { [K]: { T } } = {}

	local pool: SoundIdlePool<K, T> = {
		take = function(_self, place)
			local list = idle[place]
			if list == nil then
				return nil
			end
			local voice = table.remove(list)
			if #list == 0 then
				idle[place] = nil
			end
			return voice
		end,

		put = function(_self, place, voice, cap)
			local list = idle[place]
			if list == nil then
				list = {}
				idle[place] = list
			end
			if table.find(list, voice) ~= nil then
				return true
			end
			if #list >= cap then
				return false
			end
			table.insert(list, voice)
			return true
		end,

		remove = function(_self, place, voice)
			local list = idle[place]
			if list == nil then
				return
			end
			local index = table.find(list, voice)
			if index ~= nil then
				table.remove(list, index)
			end
			if #list == 0 then
				idle[place] = nil
			end
		end,

		forget = function(_self, place)
			local list = idle[place]
			idle[place] = nil
			return if list ~= nil then list else {}
		end,

		places = function(_self)
			local found: { K } = {}
			for place in idle do
				table.insert(found, place)
			end
			return found
		end,

		count = function(_self, place)
			if place ~= nil then
				local list = idle[place]
				return if list ~= nil then #list else 0
			end
			local total = 0
			for _, list in idle do
				total += #list
			end
			return total
		end,
	}
	return pool
end

return SoundIdlePool
