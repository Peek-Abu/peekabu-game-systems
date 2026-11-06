--!strict
--[=[
	InputMovementLockTracker: who is holding the local character's movement locked. Each owner (a menu's suppression,
	hiding, the film camera, the rehire hold) locks and unlocks under its own name, and movement is free only when
	nobody holds it, so one owner letting go never frees a player another still holds (hiding with a menu open).
	Locking twice under one name counts once.

	@class InputMovementLockTracker
]=]

export type InputMovementLockTracker = {
	set: (self: InputMovementLockTracker, owner: string, locked: boolean) -> (),
	isLocked: (self: InputMovementLockTracker) -> boolean,
	owners: (self: InputMovementLockTracker) -> { string },
}

local InputMovementLockTracker = {}

function InputMovementLockTracker.new(): InputMovementLockTracker
	local holding: { [string]: true } = {}

	local tracker: InputMovementLockTracker = {
		set = function(_self, owner, locked)
			if locked then
				holding[owner] = true
			else
				holding[owner] = nil
			end
		end,

		isLocked = function(_self)
			return next(holding) ~= nil
		end,

		owners = function(_self)
			local list: { string } = {}
			for owner in holding do
				table.insert(list, owner)
			end
			table.sort(list)
			return list
		end,
	}
	return tracker
end

return InputMovementLockTracker
