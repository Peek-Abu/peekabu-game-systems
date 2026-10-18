--!strict
--[=[
	CameraOccluderConstants: the contract between whatever builds the world and the camera's occlusion pass
	(CameraOcclusionSystem). Static data (spec-exempt).

	The engine's Poppercam only treats an opaque (Transparency < 0.25), colliding part as a wall. A game that draws its
	geometry as non-colliding art over an invisible collision proxy (Cleanup Crew's ArtVisualSystem) sets ATTRIBUTE = true
	on the proxy, so the camera stops at it as if it were the art. Shared: the server builds the proxies, the client reads
	the flag.

	@class CameraOccluderConstants
]=]

return table.freeze({
	-- Boolean attribute on a BasePart: true = the camera treats it as solid, whatever its Transparency.
	ATTRIBUTE = "CameraOccluder",
})
