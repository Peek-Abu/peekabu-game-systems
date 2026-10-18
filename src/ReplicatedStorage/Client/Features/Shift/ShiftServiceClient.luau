--!strict
--[=[
	ShiftServiceClient: the shift on the client. Registers the Shift widgets in the HUD during init (before the UI
	starts), and sends the local player's results vote whenever ShiftStore.myVote changes (clearing it when results
	end). Pushes the performance review scene (ShiftScene) when results begin and removes it when they end; the
	ShiftReviewTab widget reopens it after Escape while the vote runs. It also reports this device's platform once (ShiftPlatformRules, analytics only). Starts ShiftFeedbackSystem (the shift's horns, stings, ticking layer and countdown) and
	registers the sticky-note and stamp toast styles, and swaps the base toast stack for the paper one
	(PaperToastStack: sticky notes top-right, stamps centre; ToastServiceClient:setDefaultWidget(false)). Starts
	ShiftPromptSystem (the Interaction prompts drawn on paper) and registers the prompt chip; the chip and the phone
	action arc are registered wrapped with ShiftPromptSystem.press as a prop, so neither component requires this
	service (which requires them). Reads go through ShiftStore.

	Spec-exempt shell (Charm subscriptions, ByteNet); decoding is the specced ShiftSnapshotUtils.

	@class ShiftServiceClient
]=]

local GuiService = game:GetService("GuiService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local ShiftShared = ReplicatedStorage.Shared.Features.Shift
local Charm = require(ReplicatedStorage.Packages.Charm)
local React = require(ReplicatedStorage.Packages.React)
local ShiftConstants = require(ShiftShared.Data.ShiftConstants)
local ShiftTypes = require(ShiftShared.Data.ShiftTypes)
local ShiftEvents = require(ShiftShared.Net.ShiftEvents)
local ShiftPlatformRules = require(ShiftShared.Rules.ShiftPlatformRules)
local ToastRegistry = require(ReplicatedStorage.Shared.Features.Toast.Data.ToastRegistry)
local VacuumServiceClient = require(ReplicatedStorage.Client.Features.Vacuum.VacuumServiceClient)
local ShiftStore = require(ReplicatedStorage.Client.Features.Shift.State.ShiftStore)
local ShiftFeedbackSystem = require(ReplicatedStorage.Client.Features.Shift.Systems.ShiftFeedbackSystem)
local ShiftPromptSystem = require(ReplicatedStorage.Client.Features.Shift.Systems.ShiftPromptSystem)
local HudRegistry = require(ReplicatedStorage.Client.UI.React.Screens.Hud.HudRegistry)
local ShiftHud = require(ReplicatedStorage.Client.UI.React.Screens.Shift.ShiftHud)
local ShiftMobileButtons = require(ReplicatedStorage.Client.UI.React.Screens.Shift.ShiftMobileButtons)
local ShiftPromptChip = require(ReplicatedStorage.Client.UI.React.Screens.Shift.ShiftPromptChip)
local ShiftReviewTab = require(ReplicatedStorage.Client.UI.React.Screens.Shift.ShiftReviewTab)
local SceneStack = require(ReplicatedStorage.Client.UI.Scenes.SceneStack)
-- Registers the review scene at load.
require(ReplicatedStorage.Client.UI.React.Screens.Shift.ShiftScene)
local PaperToastStack = require(ReplicatedStorage.Client.UI.React.Screens.Paper.PaperToastStack)
local ToastServiceClient = require(ReplicatedStorage.Client.Features.Toast.ToastServiceClient)

local unsubscribers: { () -> () } = {}
-- Whether this client is in a shift's results (the review scene was pushed for them).
local reviewing = false

-- The HUD widgets that press the shown prompt, given the press as a prop (module-level, so their identity is stable).
local function PromptChipWidget(): React.ReactNode
	return React.createElement(ShiftPromptChip, { onPress = ShiftPromptSystem.press })
end

local function MobileButtonsWidget(): React.ReactNode
	return React.createElement(ShiftMobileButtons, { onPrompt = ShiftPromptSystem.press })
end

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

-- Ends a touch vacuum hold outside a running shift, clears the vote after results, and pushes the review scene when
-- results begin (removing it when they end).
local function onSnapshot(current: ShiftTypes.ShiftSnapshot?)
	if current == nil or current.phase ~= "running" then
		-- A held touch Vacuum button can be destroyed with the shift; never leave the hold on.
		VacuumServiceClient:endVacuum()
	end
	local inResults = current ~= nil and current.phase == "results"
	if not inResults and ShiftStore.myVote() ~= nil then
		ShiftStore.myVote(nil)
	end
	if inResults and not reviewing then
		SceneStack.push(ShiftConstants.REVIEW_SCENE)
	elseif not inResults and reviewing then
		SceneStack.remove(ShiftConstants.REVIEW_SCENE)
	end
	reviewing = inResults
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
		"ToastServiceClient",
	},

	init = function(_self)
		-- The paper toasts replace the base rounded stack (Figma 1f).
		ToastServiceClient:setDefaultWidget(false)
		if not HudRegistry.has("paperToasts") then
			HudRegistry.register("paperToasts", PaperToastStack.Widget, 1000)
		end
		if not HudRegistry.has("shiftHud") then
			HudRegistry.register("shiftHud", ShiftHud, ShiftConstants.HUD_ORDER)
		end
		if not HudRegistry.has("shiftReviewTab") then
			HudRegistry.register("shiftReviewTab", ShiftReviewTab, ShiftConstants.HUD_ORDER + 1)
		end
		if not HudRegistry.has("shiftMobile") then
			HudRegistry.register("shiftMobile", MobileButtonsWidget, ShiftConstants.HUD_ORDER + 2)
		end
		if not HudRegistry.has("shiftPrompt") then
			HudRegistry.register("shiftPrompt", PromptChipWidget, ShiftConstants.HUD_ORDER + 3)
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
		-- Run once with the current snapshot too, so a client that starts during results still gets the review.
		table.insert(unsubscribers, Charm.subscribe(ShiftStore.snapshot, onSnapshot))
		onSnapshot(ShiftStore.snapshot())
		ShiftFeedbackSystem.start()
		table.insert(unsubscribers, ShiftPromptSystem.start())
	end,

	stop = function(_self)
		ShiftFeedbackSystem.stop()
		for _, unsubscribe in unsubscribers do
			unsubscribe()
		end
		table.clear(unsubscribers)
		SceneStack.remove(ShiftConstants.REVIEW_SCENE)
		reviewing = false
	end,

	get = function(_self)
		return ShiftStore.snapshot()
	end,

	vote = function(_self, choice)
		ShiftStore.myVote(choice)
	end,
}

return ShiftServiceClient
