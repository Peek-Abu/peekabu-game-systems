--!strict
--[=[
	CameraEffectTracker: the camera effects' live state — the shake trauma and the active FOV kicks —
	advanced by `step(dt)` once a frame. The maths lives in CameraMotionFormulas.

	@class CameraEffectTracker
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CameraClient = ReplicatedStorage.Client.Features.Camera
local CameraTypes = require(CameraClient.Data.CameraTypes)
local CameraMotionFormulas = require(CameraClient.Utils.CameraMotionFormulas)

export type CameraEffectTracker = {
	addTrauma: (self: CameraEffectTracker, amount: number) -> (),
	kickFov: (self: CameraEffectTracker, amount: number, duration: number) -> (),
	step: (self: CameraEffectTracker, dt: number) -> (),
	trauma: (self: CameraEffectTracker) -> number,
	fovOffset: (self: CameraEffectTracker) -> number,
	activeKicks: (self: CameraEffectTracker) -> number,
	reset: (self: CameraEffectTracker) -> (),
}

local CameraEffectTracker = {}

--[=[
	@param traumaDecay number -- trauma lost per second
]=]
function CameraEffectTracker.new(traumaDecay: number): CameraEffectTracker
	local trauma = 0
	local kicks: { CameraTypes.FovKick } = {}

	local tracker: CameraEffectTracker = {
		addTrauma = function(_self, amount)
			trauma = CameraMotionFormulas.addTrauma(trauma, amount)
		end,

		kickFov = function(_self, amount, duration)
			if duration > 0 then
				table.insert(kicks, { amount = amount, duration = duration, elapsed = 0 })
			end
		end,

		step = function(_self, dt)
			trauma = CameraMotionFormulas.decayTrauma(trauma, dt, traumaDecay)
			for index = #kicks, 1, -1 do
				local kick = kicks[index]
				kick.elapsed += dt
				if kick.elapsed >= kick.duration then
					table.remove(kicks, index)
				end
			end
		end,

		trauma = function(_self)
			return trauma
		end,

		fovOffset = function(_self)
			local total = 0
			for _, kick in kicks do
				total += CameraMotionFormulas.fovKickValue(kick)
			end
			return total
		end,

		activeKicks = function(_self)
			return #kicks
		end,

		reset = function(_self)
			trauma = 0
			table.clear(kicks)
		end,
	}
	return tracker
end

return CameraEffectTracker
