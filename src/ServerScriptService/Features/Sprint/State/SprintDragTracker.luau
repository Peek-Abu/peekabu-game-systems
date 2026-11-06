--!strict
--[=[
	SprintDragTracker: each player's speed drag (vacuuming: VacuumConstants.VACUUMING_WALK_SCALE), a scale below 1 on
	top of every speed, like a boost (SprintBoostTracker) but held only while its cause lasts. It is kept per body: a
	new character's WalkSpeed starts plain, so a drag set on the old body never counts on it. `set` returns the scale
	the live WalkSpeed had and the one it should have now (nil when nothing changed), for the service's rescale.

	@class SprintDragTracker
]=]

type Drag = { humanoid: Humanoid, scale: number }

export type SprintDragTracker = {
	set: (self: SprintDragTracker, userId: number, humanoid: Humanoid, scale: number) -> (number?, number?),
	scaleOf: (self: SprintDragTracker, userId: number, humanoid: Humanoid?) -> number,
	clear: (self: SprintDragTracker, userId: number) -> (),
}

local SprintDragTracker = {}

function SprintDragTracker.new(): SprintDragTracker
	local drags: { [number]: Drag } = {}

	local tracker: SprintDragTracker = {
		set = function(self, userId, humanoid, scale)
			if scale <= 0 then
				return nil, nil
			end
			local before = self:scaleOf(userId, humanoid)
			drags[userId] = { humanoid = humanoid, scale = scale }
			if before == scale then
				return nil, nil
			end
			return before, scale
		end,

		scaleOf = function(_self, userId, humanoid)
			local current = drags[userId]
			return if current ~= nil and humanoid ~= nil and current.humanoid == humanoid then current.scale else 1
		end,

		clear = function(_self, userId)
			drags[userId] = nil
		end,
	}
	return tracker
end

return SprintDragTracker
