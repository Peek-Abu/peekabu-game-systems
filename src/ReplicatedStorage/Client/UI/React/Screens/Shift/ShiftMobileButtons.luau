--!strict
--[=[
	ShiftMobileButtons: the phone's arc of round action buttons (ShiftActionButton, V1 kit), phone Layout 2 (owner pick
	11-15): the big button at 104 px, VACUUM or THROW (ShiftHudViewModel.buttons); one helper button (76 px, up and left
	of it) that shows only while there is something to do right here, HIDE / LEAVE / SEARCH / PICK UP / OPEN / BANK ...
	(ShiftHelperViewModel: LEAVE while hiding, HIDE first while he is near, else the shown prompt, else HIDE); CROUCH
	right above the Roblox Jump button; SPRINT only while the move stick does not run (SprintConstants.STICK_RUN: a far
	push is the run, SprintStickSystem). Drop is a long press on the held item's hotbar slot (ShiftHotbar). Offsets are
	from the bottom-right corner, so the arc tracks the Jump button; on a larger touch screen the arc moves clear of the
	engine's bigger Jump button (ShiftHudViewModel.arcFor).

	A HUD widget: it reads the shift snapshot, the local player's public entry, the scare beat, the prompts (the
	interaction prompt ShiftPromptStore, the hiding prompt and spot HideStore) and the dread (OccupantDreadStore), and draws
	what the view models decide. The base Input feature has no touch bindings, so the buttons call the client services
	directly: VACUUM holds the vacuum (with a small item in hand it puts the item away first: hotbar slot 1); THROW
	throws; the helper holds the shown prompt through the `onPrompt` prop (ShiftServiceClient registers this widget with
	ShiftPromptSystem.press, so this module never requires the service that registers it), holds the hiding prompt or
	leaves the spot (HideServiceClient). A held button lets go whenever its job changes or it goes away.

	@class ShiftMobileButtons
]=]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local React = require(ReplicatedStorage.Packages.React)
local ReactCharm = require(ReplicatedStorage.Packages.ReactCharm)
local CarryConstants = require(ReplicatedStorage.Shared.Features.Carry.Data.CarryConstants)
local StateSyncConstants = require(ReplicatedStorage.Shared.Features.StateSync.Data.StateSyncConstants)
local CargoServiceClient = require(ReplicatedStorage.Client.Features.Cargo.CargoServiceClient)
local OccupantCatchStore = require(ReplicatedStorage.Client.Features.Occupant.State.OccupantCatchStore)
local OccupantDreadStore = require(ReplicatedStorage.Client.Features.Occupant.State.OccupantDreadStore)
local ShiftPromptStore = require(ReplicatedStorage.Client.Features.Shift.State.ShiftPromptStore)
local ShiftStore = require(ReplicatedStorage.Client.Features.Shift.State.ShiftStore)
local StateSyncClientStore = require(ReplicatedStorage.Client.Features.StateSync.State.StateSyncClientStore)
local VacuumServiceClient = require(ReplicatedStorage.Client.Features.Vacuum.VacuumServiceClient)
local HideServiceClient = require(ReplicatedStorage.Client.Features.Hide.HideServiceClient)
local HideStore = require(ReplicatedStorage.Client.Features.Hide.State.HideStore)
local SprintServiceClient = require(ReplicatedStorage.Client.Features.Sprint.SprintServiceClient)
local CrouchServiceClient = require(ReplicatedStorage.Client.Features.Crouch.CrouchServiceClient)
local CrouchStore = require(ReplicatedStorage.Client.Features.Crouch.State.CrouchStore)
local useServerClock = require(ReplicatedStorage.Client.UI.React.Hooks.useServerClock)
local usePaperViewport = require(ReplicatedStorage.Client.UI.React.Screens.Paper.usePaperViewport)
local ShiftActionButton = require(ReplicatedStorage.Client.UI.React.Screens.Shift.ShiftActionButton)
local ShiftHelperViewModel = require(ReplicatedStorage.Client.UI.React.Screens.Shift.ShiftHelperViewModel)
local ShiftHudViewModel = require(ReplicatedStorage.Client.UI.React.Screens.Shift.ShiftHudViewModel)

local e = React.createElement
local useAtom = ReactCharm.useAtom

-- What pressing (true) and releasing (false) the helper does for the shown interaction prompt.
export type ShiftMobileButtonsProps = {
	onPrompt: ((down: boolean) -> ())?,
}

-- How often a hold's fill and a hiding stay's warning follow the clock.
local HOLD_TICK = 0.05

local function ShiftMobileButtons(props: ShiftMobileButtonsProps?): React.ReactNode
	local snapshot = useAtom(ShiftStore.snapshot)
	local publicPlayers = useAtom(StateSyncClientStore.publicPlayers)
	local scaring = useAtom(OccupantCatchStore.scaring)
	local shownPrompt = useAtom(ShiftPromptStore.shown)
	local hidePrompt = useAtom(HideStore.prompt)
	local hiddenSpot = useAtom(HideStore.hidden)
	local danger = useAtom(OccupantDreadStore.danger)
	local crouching = useAtom(CrouchStore.crouching)
	local hiding = hiddenSpot ~= nil
	local holdRunning = (shownPrompt ~= nil and shownPrompt.holdStartedAt ~= nil)
		or (hidePrompt ~= nil and hidePrompt.holdStartedAt ~= nil)
	local now = useServerClock(HOLD_TICK, holdRunning or hiding)
	local player = Players.LocalPlayer
	local me = if player ~= nil then publicPlayers[StateSyncConstants.publicEntryKey(player.UserId)] else nil
	local onPrompt = if props ~= nil then props.onPrompt else nil
	local hudHidden = ShiftHudViewModel.hidden(me, scaring)
	local view = ShiftHudViewModel.mobileButtons(snapshot, me, UserInputService.TouchEnabled, hudHidden, hiding)
	local helper = if view ~= nil
		then ShiftHelperViewModel.helper({
			prompt = shownPrompt,
			hidePrompt = hidePrompt,
			hidden = hiddenSpot,
			danger = danger,
			now = now,
			hudHidden = hudHidden,
		})
		else nil
	local viewport = usePaperViewport()
	local arc = ShiftHudViewModel.arcFor(math.min(viewport.X, viewport.Y))
	local vacuuming = view ~= nil and view.primary == "VACUUM"
	local carrying = me ~= nil and type(me[CarryConstants.PUBLIC_FIELD]) == "string"
	-- Whether this widget started a vacuum hold that has not ended yet.
	local held = React.useRef(false)
	local beginVacuum = React.useCallback(function()
		if not VacuumServiceClient:equipVacuum() and carrying then
			-- A small item in hand: put it away (the vacuum's slot); the next press vacuums.
			CargoServiceClient:select(1)
			return
		end
		held.current = true
		VacuumServiceClient:beginVacuum()
	end, { carrying })
	local endVacuum = React.useCallback(function()
		if held.current then
			held.current = false
			VacuumServiceClient:endVacuum()
		end
	end, {})
	-- A held VACUUM ends when the big button turns into THROW or the arc goes away (unmounting destroys a held button
	-- before its InputEnded fires).
	React.useEffect(function()
		return endVacuum
	end, { vacuuming })
	-- What the helper holds right now: the interaction prompt, the hiding prompt, or nothing.
	local pressing = React.useRef("none")
	local releaseHelper = React.useCallback(function()
		local was = pressing.current
		pressing.current = "none"
		if was == "prompt" and onPrompt ~= nil then
			onPrompt(false)
		elseif was == "hide" then
			HideServiceClient:press(false)
		end
	end, { onPrompt })
	local helperKey = if helper ~= nil then `{helper.kind}/{helper.label}` else ""
	-- A held helper lets go whenever its job changes (another prompt, the prompt hid, he came near) or it goes away.
	React.useEffect(function()
		return releaseHelper
	end, { helperKey })
	local sprintable = view ~= nil and view.sprint
	-- A held SPRINT lets go whenever the button goes away (unmounting skips its InputEnded).
	React.useEffect(function()
		return function()
			SprintServiceClient:setHeld(false)
		end
	end, { sprintable })
	if view == nil then
		return nil
	end
	-- The big button's label is the view's VACUUM / THROW, read as plain text.
	local primaryLabel: string = view.primary
	local helperButton: React.ReactNode = nil
	if helper ~= nil then
		local kind = helper.kind
		helperButton = e(ShiftActionButton, {
			label = helper.label,
			spot = arc.helper,
			large = false,
			available = true,
			ready = helper.ready,
			warn = helper.warn,
			fill = helper.fill,
			onHoldBegin = if kind == "leave"
				then nil
				else function()
					if pressing.current ~= "none" then
						return
					end
					if kind == "prompt" then
						if onPrompt ~= nil then
							pressing.current = "prompt"
							onPrompt(true)
						end
					else
						pressing.current = "hide"
						HideServiceClient:press(true)
					end
				end,
			onHoldEnd = if kind == "leave" then nil else releaseHelper,
			onActivated = if kind == "leave"
				then function()
					HideServiceClient:leave()
				end
				else nil,
		})
	end
	return e("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
	}, {
		primary = e(ShiftActionButton, {
			label = primaryLabel,
			spot = arc.primary,
			large = true,
			available = view.primaryAvailable,
			ready = false,
			onHoldBegin = if view.primaryAvailable and vacuuming then beginVacuum else nil,
			onHoldEnd = if vacuuming then endVacuum else nil,
			onActivated = if vacuuming
				then nil
				else function()
					CargoServiceClient:throw()
				end,
		}),
		helper = helperButton,
		sprint = if view.sprint
			then e(ShiftActionButton, {
				label = "SPRINT",
				spot = arc.sprint,
				large = false,
				available = true,
				ready = false,
				onHoldBegin = function()
					SprintServiceClient:setHeld(true)
				end,
				onHoldEnd = function()
					SprintServiceClient:setHeld(false)
				end,
			})
			else nil,
		crouch = if view.crouch
			then e(ShiftActionButton, {
				label = "CROUCH",
				spot = arc.crouch,
				large = false,
				available = true,
				ready = crouching,
				onActivated = function()
					CrouchServiceClient:toggle()
				end,
			})
			else nil,
	})
end

return ShiftMobileButtons
