--!strict
--[=[
	OccupantServiceClient: Mr. Harlow on the client. The catch (Cleanup Crew spec §4 "Catch" step 1): on
	`CatchCam` the camera is held on his face for SNAP_SECONDS (a fixed camera mode above Death's spectate), with
	a shake and a red, drained screen; then Death's spectate takes over. The stretched-grin face and the
	distorted sting are M3. Task 11 adds the light and heartbeat tells (OccupantTellSystem).

	Spec-exempt shell (Camera, Vfx, ByteNet).

	@class OccupantServiceClient
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local OccupantConstants = require(ReplicatedStorage.Shared.Features.Occupant.Data.OccupantConstants)
local OccupantEvents = require(ReplicatedStorage.Shared.Features.Occupant.Net.OccupantEvents)
local CameraServiceClient = require(ReplicatedStorage.Client.Features.Camera.CameraServiceClient)
local VfxServiceClient = require(ReplicatedStorage.Client.Features.Vfx.VfxServiceClient)

local stoppers: { () -> () } = {}
local snaps = 0

local function snap(cframe: CFrame)
	snaps += 1
	local token = CameraServiceClient:pushMode(
		{ kind = "fixed", cframe = cframe, fov = OccupantConstants.CATCH_FOV },
		OccupantConstants.CAMERA_PRIORITY
	)
	CameraServiceClient:addTrauma(OccupantConstants.CATCH_TRAUMA)
	local screen =
		VfxServiceClient:requestScreen({ saturation = -0.7, contrast = 0.3, tint = OccupantConstants.CATCH_TINT })
	task.delay(OccupantConstants.SNAP_SECONDS, function()
		CameraServiceClient:removeMode(token)
		VfxServiceClient:releaseScreen(screen)
	end)
end

export type OccupantServiceClient = {
	dependencies: { string },
	start: (self: OccupantServiceClient) -> (),
	stop: (self: OccupantServiceClient) -> (),
	getState: (self: OccupantServiceClient) -> { [string]: any },
}

local OccupantServiceClient: OccupantServiceClient = {
	dependencies = { "CameraServiceClient", "VfxServiceClient" },

	start = function(_self)
		table.insert(
			stoppers,
			OccupantEvents.packets.CatchCam.listen(function(cframe: CFrame)
				snap(cframe)
			end)
		)
	end,

	stop = function(_self)
		for _, stop in stoppers do
			stop()
		end
		table.clear(stoppers)
	end,

	getState = function(_self)
		return { snaps = snaps }
	end,
}

return OccupantServiceClient
