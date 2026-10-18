--!strict
--[=[
	CameraOcclusionSystem: the camera's own wall check, layered over the engine's Poppercam (CameraServiceClient runs it
	each frame, after the engine camera, while the engine drives the view).

	Why the engine's is not enough: Poppercam only stops at opaque, colliding parts, and stops so that the camera's near
	plane touches that surface (the camera itself sits a tenth of a stud inside it); a wall it can see beyond counts only
	as a "soft" limit it may ignore. A world drawn as non-colliding art over invisible collision proxies (Cleanup Crew's
	office) leaves it nothing to see but an opaque core inset in each wall: the camera parks between the core and the art
	skin, both culled from inside, and the screen goes to the void; every desk, locker and cabinet is see-through to it.

	`clearance` sweeps a sphere of CameraConstants.OCCLUSION_RADIUS from the focus toward where the engine put the
	camera and returns how far the camera may stand: at the first part CameraOccluderRules says blocks (an opaque wall,
	or a proxy flagged as one), the sphere's centre a radius short of its surface. It looks through
	what does not block (up to OCCLUSION_MAX_PIERCE parts), the listed instances (the players' characters) and anything
	in the subject's assembly (what a player carries). A sphere that starts inside a part ignores that part (hiding under
	a desk). Pure query: it moves nothing.

	@class CameraOcclusionSystem
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local CameraConstants = require(ReplicatedStorage.Client.Features.Camera.Data.CameraConstants)
local CameraOccluderRules = require(ReplicatedStorage.Client.Features.Camera.Rules.CameraOccluderRules)

local params = RaycastParams.new()
params.FilterType = Enum.RaycastFilterType.Exclude
params.IgnoreWater = true
-- A flagged proxy may be non-colliding to the sweep's eye only through its flag, so every queryable part is looked at
-- and CameraOccluderRules decides.
params.RespectCanCollide = false

local CameraOcclusionSystem = {}

--[=[
	How far from `focus`, toward `camera`, the camera may stand (at most their distance).
]=]
function CameraOcclusionSystem.clearance(
	focus: Vector3,
	camera: Vector3,
	ignore: { Instance },
	subject: BasePart?
): number
	local offset = camera - focus
	local distance = offset.Magnitude
	if distance < 1e-4 then
		return 0
	end
	local subjectRoot = if subject ~= nil then subject.AssemblyRootPart else nil
	params.FilterDescendantsInstances = ignore
	local last = distance
	for _ = 1, CameraConstants.OCCLUSION_MAX_PIERCE do
		local hit = Workspace:Spherecast(focus, CameraConstants.OCCLUSION_RADIUS, offset, params)
		if hit == nil then
			return distance
		end
		local part = hit.Instance
		if part:IsA("BasePart") then
			local sameAssembly = subjectRoot ~= nil and part.AssemblyRootPart == subjectRoot
			if not sameAssembly and CameraOccluderRules.blocks(part) then
				return math.clamp(hit.Distance, 0, distance)
			end
		end
		last = math.clamp(hit.Distance, 0, distance)
		params:AddToFilter(part)
	end
	-- Too much see-through clutter to look past: stop at the last thing found, like the engine's cast limit.
	return last
end

return CameraOcclusionSystem
