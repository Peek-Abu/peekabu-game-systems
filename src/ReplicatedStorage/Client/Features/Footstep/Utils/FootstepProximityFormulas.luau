--!strict
--[=[
	FootstepProximityFormulas: a footstep set's optional proximity gate (FootstepTypes.Proximity). A set with a gate is
	silent while the listener is farther than `silentBeyond` studs, and from that distance in every step is suddenly
	loud and quick (x `loudVolume`, x `quickPitch`), with no fade between: Bramble's steps (owner 11-13, "quiet as a
	bat until pretty close and then his footsteps suddenly sound loud and quick"). A set with no gate is unchanged.
	The scale multiplies the gait's (FootstepGaitFormulas). Pure.

	@class FootstepProximityFormulas
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local FootstepTypes = require(ReplicatedStorage.Client.Features.Footstep.Data.FootstepTypes)

type Proximity = FootstepTypes.Proximity
type GaitScale = FootstepTypes.GaitScale

local UNCHANGED: GaitScale = table.freeze({ volume = 1, pitch = 1 })
local SILENT: GaitScale = table.freeze({ volume = 0, pitch = 1 })

local FootstepProximityFormulas = {}

--[=[
	The volume and pitch multipliers for a step heard `distance` studs from the listener (math.huge when there is no
	listener), under `gate` (nil: no gate).
]=]
function FootstepProximityFormulas.scale(gate: Proximity?, distance: number): GaitScale
	if gate == nil then
		return UNCHANGED
	end
	if distance > gate.silentBeyond then
		return SILENT
	end
	return { volume = gate.loudVolume, pitch = gate.quickPitch }
end

return FootstepProximityFormulas
