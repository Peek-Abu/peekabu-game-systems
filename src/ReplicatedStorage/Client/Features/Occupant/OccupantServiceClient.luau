--!strict
--[=[
	OccupantServiceClient: Mr. Harlow on the client. The catch (Cleanup Crew spec §4 "Catch" step 1): on
	`CatchCam` the camera is held on his face for SNAP_SECONDS (a fixed camera mode above Death's spectate), with
	a shake and a red, drained screen; then Death's spectate takes over. The sting and the stretched grin are
	OccupantScareSystem's. At init it registers the catch's HUD widgets: the CCTV overlay while caught (CatchOverlay) and
	the HR "Rehired." card around the respawn (CatchRehiredCard). The light and heartbeat tells run in OccupantTellSystem (lights out on a catch, every light flickering on a
	tier rise). OccupantBillboardSystem draws his cue disc and typed memo. OccupantPresenceSystem plays his footsteps, mutter, cues, chase music, your heartbeat and his voice.

	Spec-exempt shell (Camera, Vfx, ByteNet).

	@class OccupantServiceClient
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local OccupantConstants = require(ReplicatedStorage.Shared.Features.Occupant.Data.OccupantConstants)
local OccupantTypes = require(ReplicatedStorage.Shared.Features.Occupant.Data.OccupantTypes)
local ShiftConstants = require(ReplicatedStorage.Shared.Features.Shift.Data.ShiftConstants)
local OccupantEvents = require(ReplicatedStorage.Shared.Features.Occupant.Net.OccupantEvents)
local CameraServiceClient = require(ReplicatedStorage.Client.Features.Camera.CameraServiceClient)
local VfxServiceClient = require(ReplicatedStorage.Client.Features.Vfx.VfxServiceClient)
local OccupantCatchStore = require(ReplicatedStorage.Client.Features.Occupant.State.OccupantCatchStore)
local OccupantTellSystem = require(ReplicatedStorage.Client.Features.Occupant.Systems.OccupantTellSystem)
local OccupantPresenceSystem = require(ReplicatedStorage.Client.Features.Occupant.Systems.OccupantPresenceSystem)
local OccupantBillboardSystem = require(ReplicatedStorage.Client.Features.Occupant.Systems.OccupantBillboardSystem)
local OccupantScareSystem = require(ReplicatedStorage.Client.Features.Occupant.Systems.OccupantScareSystem)
local CatchOverlay = require(ReplicatedStorage.Client.UI.React.Screens.Catch.CatchOverlay)
local CatchRehiredCard = require(ReplicatedStorage.Client.UI.React.Screens.Catch.CatchRehiredCard)
local HudRegistry = require(ReplicatedStorage.Client.UI.React.Screens.Hud.HudRegistry)

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
	init: (self: OccupantServiceClient) -> (),
	start: (self: OccupantServiceClient) -> (),
	stop: (self: OccupantServiceClient) -> (),
	getState: (self: OccupantServiceClient) -> { [string]: any },
}

local OccupantServiceClient: OccupantServiceClient = {
	dependencies = { "CameraServiceClient", "VfxServiceClient", "SoundServiceClient" },

	init = function(_self)
		if not HudRegistry.has("catchOverlay") then
			HudRegistry.register("catchOverlay", CatchOverlay, ShiftConstants.HUD_ORDER + 5)
		end
		if not HudRegistry.has("catchRehired") then
			HudRegistry.register("catchRehired", CatchRehiredCard, ShiftConstants.HUD_ORDER + 6)
		end
	end,

	start = function(_self)
		table.insert(
			stoppers,
			OccupantEvents.packets.CatchCam.listen(function(cframe: CFrame)
				snap(cframe)
				OccupantScareSystem.snap()
				OccupantCatchStore.snap()
				task.delay(OccupantConstants.SNAP_SECONDS, OccupantCatchStore.endSnap)
			end)
		)
		table.insert(
			stoppers,
			OccupantEvents.packets.CatchReport.listen(function(data: OccupantTypes.CatchReport)
				OccupantCatchStore.setReport(data)
			end)
		)
		table.insert(
			stoppers,
			OccupantEvents.packets.Rehired.listen(function(_back: boolean)
				OccupantCatchStore.rehired(os.clock())
			end)
		)
		table.insert(
			stoppers,
			OccupantEvents.packets.LightsOut.listen(function(position: Vector3)
				OccupantTellSystem.lightsOut(position, os.clock())
				OccupantScareSystem.lightsOut(position)
			end)
		)
		table.insert(
			stoppers,
			OccupantEvents.packets.Flicker.listen(function(_rose: boolean)
				OccupantTellSystem.flickerAll(os.clock())
			end)
		)
		OccupantTellSystem.start()
		table.insert(stoppers, OccupantTellSystem.stop)
		OccupantPresenceSystem.start()
		table.insert(stoppers, OccupantPresenceSystem.stop)
		OccupantBillboardSystem.start()
		table.insert(stoppers, OccupantBillboardSystem.stop)
	end,

	stop = function(_self)
		for _, stop in stoppers do
			stop()
		end
		table.clear(stoppers)
		OccupantCatchStore.clear()
	end,

	getState = function(_self)
		return {
			snaps = snaps,
			presence = OccupantPresenceSystem.getState(),
			scare = OccupantScareSystem.getState(),
			billboards = OccupantBillboardSystem.getState(),
		}
	end,
}

return OccupantServiceClient
