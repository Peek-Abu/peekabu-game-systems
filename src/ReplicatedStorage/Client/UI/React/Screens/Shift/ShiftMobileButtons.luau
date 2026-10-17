--!strict
--[=[
	ShiftMobileButtons: the phone's arc of round action buttons around the big VACUUM / BANK button (Figma 1d 9:61,
	1e 9:116): DROP and THROW at 72 px, the big button at 104 px, with >= 16 px between circles, all clear of
	the Roblox Jump button (bottom right) and the thumbstick zone (bottom-left 40%); the hotbar slots are tapped on the
	hotbar (ShiftHotbar). Offsets are from the bottom-right
	corner, so the arc tracks the Jump button; on a larger touch screen the engine's Jump button is bigger, so the arc
	moves clear of it (ShiftHudViewModel.arcFor picks the arc from the viewport's short side).

	A HUD widget: it reads the shift snapshot, the local player's public entry, the scare beat and the touch flag, and
	draws what ShiftHudViewModel.mobileButtons decides (whether the arc shows, VACUUM or BANK, which buttons are
	available or lit). SPRINT (held, any time but while hiding; a load slows it) sits up and left of DROP; it
	holds the sprint through SprintServiceClient. CROUCH (a toggle, any time but while hiding) sits right above the
	Jump button and lights while the player is crouched (CrouchStore: the crouch indicator on a phone); it toggles
	through CrouchServiceClient. The base Input feature has no touch bindings, so the buttons call the Vacuum and Cargo client
	services directly. The big button keeps the hold semantics for VACUUM. As BANK it is usable (and lit) only while the
	truck's Load prompt is shown (ShiftPromptStore, ShiftHudViewModel.loadReady: the engine takes a touch hold only on
	a shown prompt); pressing holds that prompt and releasing lets go, through the `onPrompt` prop (ShiftServiceClient
	registers this widget with ShiftPromptSystem.press, so this module never requires the service that registers it).
	Otherwise BANK is drawn at half opacity and ignores input.

	@class ShiftMobileButtons
]=]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local React = require(ReplicatedStorage.Packages.React)
local ReactCharm = require(ReplicatedStorage.Packages.ReactCharm)
local StateSyncConstants = require(ReplicatedStorage.Shared.Features.StateSync.Data.StateSyncConstants)
local CargoServiceClient = require(ReplicatedStorage.Client.Features.Cargo.CargoServiceClient)
local OccupantCatchStore = require(ReplicatedStorage.Client.Features.Occupant.State.OccupantCatchStore)
local ShiftPromptStore = require(ReplicatedStorage.Client.Features.Shift.State.ShiftPromptStore)
local ShiftStore = require(ReplicatedStorage.Client.Features.Shift.State.ShiftStore)
local StateSyncClientStore = require(ReplicatedStorage.Client.Features.StateSync.State.StateSyncClientStore)
local VacuumServiceClient = require(ReplicatedStorage.Client.Features.Vacuum.VacuumServiceClient)
local HideStore = require(ReplicatedStorage.Client.Features.Hide.State.HideStore)
local SprintServiceClient = require(ReplicatedStorage.Client.Features.Sprint.SprintServiceClient)
local CrouchServiceClient = require(ReplicatedStorage.Client.Features.Crouch.CrouchServiceClient)
local CrouchStore = require(ReplicatedStorage.Client.Features.Crouch.State.CrouchStore)
local UIPaperConstants = require(ReplicatedStorage.Client.UI.React.Screens.Paper.UIPaperConstants)
local usePaperViewport = require(ReplicatedStorage.Client.UI.React.Screens.Paper.usePaperViewport)
local ShiftHudViewModel = require(ReplicatedStorage.Client.UI.React.Screens.Shift.ShiftHudViewModel)

local e = React.createElement
local useAtom = ReactCharm.useAtom

-- What pressing (true) and releasing (false) BANK does: holds and lets go of the shown prompt.
export type ShiftMobileButtonsProps = {
	onPrompt: ((down: boolean) -> ())?,
}

type ButtonProps = {
	label: string,
	spot: ShiftHudViewModel.ArcSpot,
	large: boolean,
	available: boolean,
	ready: boolean,
	onActivated: (() -> ())?,
	onHoldBegin: (() -> ())?,
	onHoldEnd: (() -> ())?,
}

local COLOR = UIPaperConstants.COLOR
-- Figma "Mobile button": night at 72%, a 3 px fluorescent ring at 85%; a ready one is exit green at 95%.
local FILL_TRANSPARENCY = 0.28
local READY_TRANSPARENCY = 0.05
local STROKE_TRANSPARENCY = 0.15
-- An unavailable button draws at half opacity (Figma 0.45) and ignores input.
local DIM = 0.5

-- `transparency` drawn at `opacity` overall.
local function faded(transparency: number, opacity: number): number
	return 1 - (1 - transparency) * opacity
end

local function isPress(input: InputObject): boolean
	return input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1
end

local function ActionButton(props: ButtonProps): React.ReactNode
	local opacity = if props.available then 1 else DIM
	local onHoldBegin = props.onHoldBegin
	local onHoldEnd = props.onHoldEnd
	local onActivated = props.onActivated
	local spot = props.spot
	return e("TextButton", {
		Position = UDim2.new(1, spot.x, 1, spot.y),
		Size = UDim2.fromOffset(spot.size, spot.size),
		AutoButtonColor = false,
		Active = props.available,
		BackgroundColor3 = if props.ready then COLOR.exitGreen else COLOR.night,
		BackgroundTransparency = faded(if props.ready then READY_TRANSPARENCY else FILL_TRANSPARENCY, opacity),
		BorderSizePixel = 0,
		FontFace = UIPaperConstants.FONT.heading,
		TextSize = if props.large then 20 else 15,
		TextColor3 = if props.ready then COLOR.night else COLOR.fluorescent,
		TextTransparency = faded(0, opacity),
		Text = props.label,
		[React.Event.InputBegan] = function(_button: TextButton, input: InputObject)
			if onHoldBegin ~= nil and isPress(input) then
				onHoldBegin()
			end
		end,
		[React.Event.InputEnded] = function(_button: TextButton, input: InputObject)
			if onHoldEnd ~= nil and isPress(input) then
				onHoldEnd()
			end
		end,
		[React.Event.Activated] = function()
			if props.available and onActivated ~= nil then
				onActivated()
			end
		end,
		[React.Event.MouseLeave] = function()
			if onHoldEnd ~= nil then
				onHoldEnd()
			end
		end,
	}, {
		corner = e("UICorner", { CornerRadius = UDim.new(0.5, 0) }),
		stroke = e("UIStroke", {
			Color = COLOR.fluorescent,
			Thickness = 3,
			Transparency = faded(if props.ready then 0 else STROKE_TRANSPARENCY, opacity),
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		}),
	})
end

local function ShiftMobileButtons(props: ShiftMobileButtonsProps?): React.ReactNode
	local snapshot = useAtom(ShiftStore.snapshot)
	local publicPlayers = useAtom(StateSyncClientStore.publicPlayers)
	local scaring = useAtom(OccupantCatchStore.scaring)
	local shownPrompt = useAtom(ShiftPromptStore.shown)
	local hiding = useAtom(HideStore.hidden) ~= nil
	local crouching = useAtom(CrouchStore.crouching)
	local player = Players.LocalPlayer
	local me = if player ~= nil then publicPlayers[StateSyncConstants.publicEntryKey(player.UserId)] else nil
	local onPrompt = if props ~= nil then props.onPrompt else nil
	local view = ShiftHudViewModel.mobileButtons(
		snapshot,
		me,
		UserInputService.TouchEnabled,
		ShiftHudViewModel.hidden(me, scaring),
		ShiftHudViewModel.loadReady(shownPrompt),
		hiding
	)
	local viewport = usePaperViewport()
	local arc = ShiftHudViewModel.arcFor(math.min(viewport.X, viewport.Y))
	local vacuuming = view ~= nil and view.primary == "VACUUM"
	-- Whether this widget started a vacuum hold that has not ended yet.
	local held = React.useRef(false)
	local beginVacuum = React.useCallback(function()
		held.current = true
		VacuumServiceClient:equipVacuum()
		VacuumServiceClient:beginVacuum()
	end, {})
	local endVacuum = React.useCallback(function()
		if held.current then
			held.current = false
			VacuumServiceClient:endVacuum()
		end
	end, {})
	-- Whether this widget is holding the shown prompt through BANK.
	local loading = React.useRef(false)
	local beginLoad = React.useCallback(function()
		if onPrompt ~= nil and not loading.current then
			loading.current = true
			onPrompt(true)
		end
	end, { onPrompt })
	local endLoad = React.useCallback(function()
		if onPrompt ~= nil and loading.current then
			loading.current = false
			onPrompt(false)
		end
	end, { onPrompt })
	-- A held VACUUM ends when the big button turns into BANK or the arc goes away (unmounting destroys a held button
	-- before its InputEnded fires).
	React.useEffect(function()
		return endVacuum
	end, { vacuuming })
	-- A held BANK lets go of its prompt whenever BANK stops being pressable: the prompt hid, the load emptied the
	-- hands (VACUUM again), the HUD hid or the arc went away. Returning nil keeps this widget mounted, so this is
	-- keyed on the state, not on unmount.
	React.useEffect(function()
		return endLoad
	end, { ShiftHudViewModel.loadLive(view) })
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
	-- The big button's label is the view's VACUUM / BANK, read as plain text.
	local primaryLabel: string = view.primary
	local dropProps: ButtonProps = {
		label = "DROP",
		spot = arc.drop,
		large = false,
		available = view.drop,
		ready = false,
		onActivated = function()
			CargoServiceClient:drop()
		end,
	}
	local throwProps: ButtonProps = {
		label = "THROW",
		spot = arc.throw,
		large = false,
		available = view.throw,
		ready = false,
		onActivated = function()
			CargoServiceClient:throw()
		end,
	}
	return e("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
	}, {
		primary = e(ActionButton, {
			label = primaryLabel,
			spot = arc.primary,
			large = true,
			available = view.primaryAvailable,
			ready = view.primaryReady,
			-- BANK's release always goes through, so a hold that began while lit lets go even if the prompt hid.
			onHoldBegin = if not view.primaryAvailable then nil elseif vacuuming then beginVacuum else beginLoad,
			onHoldEnd = if vacuuming then endVacuum else endLoad,
		}),
		drop = if view.drop then e(ActionButton, dropProps) else nil,
		throw = if view.throw then e(ActionButton, throwProps) else nil,
		sprint = if view.sprint
			then e(ActionButton, {
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
			then e(ActionButton, {
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
