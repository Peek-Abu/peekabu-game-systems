--!strict
--[=[
	ShiftServiceClient: the shift on the client. Registers the placeholder Shift widgets in the HUD during init
	(before the UI starts), and sends the local player's results vote whenever ShiftStore.myVote changes
	(clearing it when results end). It also reports this device's platform once (ShiftPlatformRules, analytics only). Starts ShiftFeedbackSystem (the shift's horns, stings, ticking layer and countdown) and
	registers the sticky-note and stamp toast styles. Reads go through ShiftStore.

	Spec-exempt shell (Charm subscriptions, ByteNet); decoding is the specced ShiftSnapshotUtils.

	@class ShiftServiceClient
]=]

local GuiService = game:GetService("GuiService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local ShiftShared = ReplicatedStorage.Shared.Features.Shift
local Charm = require(ReplicatedStorage.Packages.Charm)
local ShiftConstants = require(ShiftShared.Data.ShiftConstants)
local ShiftTypes = require(ShiftShared.Data.ShiftTypes)
local ShiftEvents = require(ShiftShared.Net.ShiftEvents)
local ShiftPlatformRules = require(ShiftShared.Rules.ShiftPlatformRules)
local ToastRegistry = require(ReplicatedStorage.Shared.Features.Toast.Data.ToastRegistry)
local VacuumServiceClient = require(ReplicatedStorage.Client.Features.Vacuum.VacuumServiceClient)
local ShiftStore = require(ReplicatedStorage.Client.Features.Shift.State.ShiftStore)
local ShiftFeedbackSystem = require(ReplicatedStorage.Client.Features.Shift.Systems.ShiftFeedbackSystem)
local HudRegistry = require(ReplicatedStorage.Client.UI.React.Screens.Hud.HudRegistry)
local ShiftHud = require(ReplicatedStorage.Client.UI.React.Screens.Shift.ShiftHud)
local ShiftMobileButtons = require(ReplicatedStorage.Client.UI.React.Screens.Shift.ShiftMobileButtons)
local ShiftResults = require(ReplicatedStorage.Client.UI.React.Screens.Shift.ShiftResults)

local unsubscribers: { () -> () } = {}

-- Tells the server this device's platform once (analytics only; the server accepts ShiftPlatformRules' codes).
local function reportPlatform()
	local camera = Workspace.CurrentCamera
	local viewport = if camera ~= nil then camera.ViewportSize else Vector2.zero
	local platform: ShiftTypes.Platform = ShiftPlatformRules.detect({
		touch = UserInputService.TouchEnabled,
		keyboard = UserInputService.KeyboardEnabled,
		gamepad = UserInputService.GamepadEnabled,
		tenFoot = GuiService:IsTenFootInterface(),
		shortSide = math.min(viewport.X, viewport.Y),
	})
	local code = ShiftPlatformRules.code(platform)
	if code > 0 then
		ShiftEvents.packets.Platform.send(code)
	end
end

-- Registered at load (before the first toast arrives) so ToastStack can draw them.
for name, style in ShiftConstants.TOAST_STYLES do
	if not ToastRegistry.has(name) then
		ToastRegistry.register(name, style)
	end
end

export type ShiftServiceClient = {
	dependencies: { string },
	init: (self: ShiftServiceClient) -> (),
	start: (self: ShiftServiceClient) -> (),
	stop: (self: ShiftServiceClient) -> (),
	get: (self: ShiftServiceClient) -> ShiftTypes.ShiftSnapshot?,
	vote: (self: ShiftServiceClient, choice: ShiftTypes.Vote) -> (),
}

local ShiftServiceClient: ShiftServiceClient = {
	dependencies = {
		"StateSyncServiceClient",
		"VacuumServiceClient",
		"CargoServiceClient",
		"SoundServiceClient",
		"CameraServiceClient",
	},

	init = function(_self)
		if not HudRegistry.has("shiftHud") then
			HudRegistry.register("shiftHud", ShiftHud, ShiftConstants.HUD_ORDER)
		end
		if not HudRegistry.has("shiftResults") then
			HudRegistry.register("shiftResults", ShiftResults, ShiftConstants.HUD_ORDER + 1)
		end
		if not HudRegistry.has("shiftMobile") then
			HudRegistry.register("shiftMobile", ShiftMobileButtons, ShiftConstants.HUD_ORDER + 2)
		end
	end,

	start = function(_self)
		task.delay(ShiftConstants.PLATFORM_REPORT_DELAY, reportPlatform)
		table.insert(
			unsubscribers,
			Charm.subscribe(ShiftStore.myVote, function(choice: string?)
				if choice ~= nil then
					ShiftEvents.packets.Vote.send(choice)
				end
			end)
		)
		table.insert(
			unsubscribers,
			Charm.subscribe(ShiftStore.snapshot, function(current: ShiftTypes.ShiftSnapshot?)
				if current == nil or current.phase ~= "running" then
					-- A held touch Vacuum button can be destroyed with the shift; never leave the hold on.
					VacuumServiceClient:endVacuum()
				end
				local inResults = current ~= nil and current.phase == "results"
				if not inResults and ShiftStore.myVote() ~= nil then
					ShiftStore.myVote(nil)
				end
			end)
		)
		ShiftFeedbackSystem.start()
	end,

	stop = function(_self)
		ShiftFeedbackSystem.stop()
		for _, unsubscribe in unsubscribers do
			unsubscribe()
		end
		table.clear(unsubscribers)
	end,

	get = function(_self)
		return ShiftStore.snapshot()
	end,

	vote = function(_self, choice)
		ShiftStore.myVote(choice)
	end,
}

return ShiftServiceClient
