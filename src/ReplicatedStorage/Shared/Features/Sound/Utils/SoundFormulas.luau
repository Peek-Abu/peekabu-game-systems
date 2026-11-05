--!strict
--[=[
	SoundFormulas: the Sound feature's pure maths.

	@class SoundFormulas
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SoundTypes = require(ReplicatedStorage.Shared.Features.Sound.Data.SoundTypes)

type SoundPlace = SoundTypes.SoundPlace

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

--[=[
	Where a sound playing at `point` is: Outside when the point is in any of the outdoor `boxes` (edges included), else
	Building. Nil without a point (a 2D sound) or without boxes (the hub, a layout with no grounds): placeless.
]=]
function SoundFormulas.placeOf(point: Vector3?, boxes: { SoundTypes.SoundPlaceBox }): SoundPlace?
	if point == nil or #boxes == 0 then
		return nil
	end
	for _, box in boxes do
		if
			point.X >= box.min.X
			and point.X <= box.max.X
			and point.Y >= box.min.Y
			and point.Y <= box.max.Y
			and point.Z >= box.min.Z
			and point.Z <= box.max.Z
		then
			return "Outside"
		end
	end
	return "Building"
end

--[=[
	The place one play of a sound is in: none for a `heardEverywhere` sound; its pinned `place` wherever it plays (a 2D
	bed pinned to the yard or the office); else where its `point` is (placeOf: 2D or no boxes = placeless).
]=]
function SoundFormulas.placeOfPlay(
	def: { place: SoundPlace?, heardEverywhere: boolean? },
	point: Vector3?,
	boxes: { SoundTypes.SoundPlaceBox }
): SoundPlace?
	if def.heardEverywhere == true then
		return nil
	end
	if def.place ~= nil then
		return def.place
	end
	return SoundFormulas.placeOf(point, boxes)
end

--[=[
	The volume a sound in place `source` plays at for a listener in place `listener`: 1 in the same place, 0 across
	places (the owner's Lethal Company rule: nothing from inside reaches the yard, nor the other way). 1 when either
	is placeless.
]=]
function SoundFormulas.placeGain(source: SoundPlace?, listener: SoundPlace?): number
	if source == nil or listener == nil or source == listener then
		return 1
	end
	return 0
end

return SoundFormulas
