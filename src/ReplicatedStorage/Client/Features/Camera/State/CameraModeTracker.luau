--!strict
--[=[
	CameraModeTracker: the camera mode stack. A push returns a token; the top is the entry with the
	highest priority, the most recent winning ties. Removing by token lets systems come and go in any
	order (spectating ends while a cutscene is still up, and so on).

	@class CameraModeTracker
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CameraTypes = require(ReplicatedStorage.Client.Features.Camera.Data.CameraTypes)

type ModeDef = CameraTypes.ModeDef
type ModeEntry = CameraTypes.ModeEntry

export type CameraModeTracker = {
	push: (self: CameraModeTracker, def: ModeDef, priority: number) -> number,
	remove: (self: CameraModeTracker, token: number) -> boolean,
	top: (self: CameraModeTracker) -> ModeEntry?,
	count: (self: CameraModeTracker) -> number,
}

local CameraModeTracker = {}

function CameraModeTracker.new(): CameraModeTracker
	-- In push order; `top` scans it, which is fine for the handful of modes ever stacked at once.
	local entries: { ModeEntry } = {}
	local nextToken = 0

	local tracker: CameraModeTracker = {
		push = function(_self, def, priority)
			nextToken += 1
			table.insert(entries, { token = nextToken, priority = priority, def = def })
			return nextToken
		end,

		remove = function(_self, token)
			for index, entry in entries do
				if entry.token == token then
					table.remove(entries, index)
					return true
				end
			end
			return false
		end,

		top = function(_self)
			local best: ModeEntry? = nil
			for _, entry in entries do
				-- `>=`: a later entry wins a tie, since entries are in push order.
				if best == nil or entry.priority >= best.priority then
					best = entry
				end
			end
			return best
		end,

		count = function(_self)
			return #entries
		end,
	}
	return tracker
end

return CameraModeTracker
