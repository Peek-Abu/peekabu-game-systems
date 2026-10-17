--!strict
--[=[
	OccupantServiceClient: Mr. Harlow on the client. The catch jumpscare (Cleanup Crew spec §4 "Catch" step 1; the
	behaviour set §6, docs/superpowers/specs/2026-10-15-cleanup-crew-manager-behaviours-design.md): on `CatchCam` the
	camera follows his face for SNAP_SECONDS (a custom camera mode above Death's spectate: JUMPSCARE_DISTANCE in front of
	his head, world up, so a face upside down under a desk reads upside down; the packet's still shot when his head is
	gone), with a quick shake and a red, drained screen; then Death's spectate takes over. His head tilts meanwhile
	(OccupantGestureSystem, the server's tilt). The sting and the stretched grin are
	OccupantScareSystem's. At init it registers the catch's HUD widgets: the CCTV overlay while caught (CatchOverlay) and
	the HR "Rehired." card around the respawn (CatchRehiredCard), and the dread's screen layer (DreadOverlay). The light
	tells run in OccupantTellSystem (lights out on a catch, every light flickering on a tier rise). OccupantPresenceSystem
	plays his mutter, cues, the chase sting and bed and his voice. OccupantDreadSystem plays the proximity dread: your
	heartbeat, the dread loop, the screen's mood, the chase's FOV squeeze and footfall shake, and the ambience duck.
	OccupantGestureSystem
	lays his gestures over his joints; OccupantWarningSystem plays the staged warnings and his typing (no PA since
	2026-10-16).

	Spec-exempt shell (Camera, Vfx, ByteNet).

	@class OccupantServiceClient
]=]

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local OccupantConstants = require(ReplicatedStorage.Shared.Features.Occupant.Data.OccupantConstants)
local OccupantTypes = require(ReplicatedStorage.Shared.Features.Occupant.Data.OccupantTypes)
local ShiftConstants = require(ReplicatedStorage.Shared.Features.Shift.Data.ShiftConstants)
local OccupantEvents = require(ReplicatedStorage.Shared.Features.Occupant.Net.OccupantEvents)
local CameraServiceClient = require(ReplicatedStorage.Client.Features.Camera.CameraServiceClient)
local VfxServiceClient = require(ReplicatedStorage.Client.Features.Vfx.VfxServiceClient)
local OccupantCatchStore = require(ReplicatedStorage.Client.Features.Occupant.State.OccupantCatchStore)
local OccupantTellSystem = require(ReplicatedStorage.Client.Features.Occupant.Systems.OccupantTellSystem)
local OccupantChaseMusicSystem = require(ReplicatedStorage.Client.Features.Occupant.Systems.OccupantChaseMusicSystem)
local OccupantPresenceSystem = require(ReplicatedStorage.Client.Features.Occupant.Systems.OccupantPresenceSystem)
local OccupantScareSystem = require(ReplicatedStorage.Client.Features.Occupant.Systems.OccupantScareSystem)
local OccupantGestureSystem = require(ReplicatedStorage.Client.Features.Occupant.Systems.OccupantGestureSystem)
local OccupantWarningSystem = require(ReplicatedStorage.Client.Features.Occupant.Systems.OccupantWarningSystem)
local OccupantDreadSystem = require(ReplicatedStorage.Client.Features.Occupant.Systems.OccupantDreadSystem)
local DreadOverlay = require(ReplicatedStorage.Client.UI.React.Screens.Dread.DreadOverlay)
local CatchOverlay = require(ReplicatedStorage.Client.UI.React.Screens.Catch.CatchOverlay)
local CatchRehiredCard = require(ReplicatedStorage.Client.UI.React.Screens.Catch.CatchRehiredCard)
local HudRegistry = require(ReplicatedStorage.Client.UI.React.Screens.Hud.HudRegistry)

local stoppers: { () -> () } = {}
local snaps = 0

-- His head, to follow for the jumpscare.
local function harlowHead(): BasePart?
	for _, instance in CollectionService:GetTagged(OccupantConstants.TAG) do
		local head = instance:FindFirstChild("Head")
		if head ~= nil and head:IsA("BasePart") then
			return head
		end
	end
	return nil
end

local function snap(cframe: CFrame)
	snaps += 1
	local head = harlowHead()
	local token = CameraServiceClient:pushMode({
		kind = "custom",
		update = function(_dt: number): (CFrame, number?)
			if head == nil or head.Parent == nil then
				return cframe, OccupantConstants.CATCH_FOV
			end
			local face = head.Position
			local eye = (head.CFrame * CFrame.new(0, 0, -OccupantConstants.JUMPSCARE_DISTANCE)).Position
			return CFrame.lookAt(eye, face), OccupantConstants.JUMPSCARE_FOV
		end,
	}, OccupantConstants.CAMERA_PRIORITY)
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
	dependencies = {
		"CameraServiceClient",
		"VfxServiceClient",
		"SoundServiceClient",
		"FootstepServiceClient",
		"DeathServiceClient",
	},

	init = function(_self)
		if not HudRegistry.has("catchOverlay") then
			HudRegistry.register("catchOverlay", CatchOverlay, ShiftConstants.HUD_ORDER + 5)
		end
		if not HudRegistry.has("occupantDread") then
			-- Above the hiding peek's frame (-100), under every other widget.
			HudRegistry.register("occupantDread", DreadOverlay, -90)
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
				OccupantScareSystem.rehired()
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
		OccupantGestureSystem.start()
		table.insert(stoppers, OccupantGestureSystem.stop)
		OccupantWarningSystem.start()
		table.insert(stoppers, OccupantWarningSystem.stop)
		OccupantDreadSystem.start()
		table.insert(stoppers, OccupantDreadSystem.stop)
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
			chaseMusic = OccupantChaseMusicSystem.getState(),
			scare = OccupantScareSystem.getState(),
			gestures = OccupantGestureSystem.getState(),
			warnings = OccupantWarningSystem.getState(),
			dread = OccupantDreadSystem.getState(),
		}
	end,
}

return OccupantServiceClient
