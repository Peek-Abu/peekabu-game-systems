--!strict
--[=[
	SoundFormulas: the Sound feature's pure maths.

	@class SoundFormulas
]=]

local SoundFormulas = {}

--[=[
	The PlaybackSpeed for one play: `roll` (0..1, clamped) mapped onto the range; 1 without a range.
]=]
function SoundFormulas.pickPitch(range: { min: number, max: number }?, roll: number): number
	if range == nil then
		return 1
	end
	return range.min + (range.max - range.min) * math.clamp(roll, 0, 1)
end

export type Listener = {
	id: number,
	-- Nil when the listener has no character (nothing to hear with).
	position: Vector3?,
}

--[=[
	The ids of the listeners within `radius` of `origin` (inclusive), sorted.
]=]
function SoundFormulas.listenersInRange(origin: Vector3, radius: number, listeners: { Listener }): { number }
	local heard: { number } = {}
	for _, listener in listeners do
		local position = listener.position
		if position ~= nil and (position - origin).Magnitude <= radius then
			table.insert(heard, listener.id)
		end
	end
	table.sort(heard)
	return heard
end

return SoundFormulas
