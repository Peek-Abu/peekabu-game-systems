--!strict
--[=[
    ShiftHud: reads authoritative shift/public state and renders the compact V1 HUD (ShiftCompactHudPanel).
    Crew details are disclosed on demand. Physical-pixel sizes preserve readable text in short windows;
    the layout hook selects the phone arrangement. Catch/scare suppression stays on the outer frame. While the crew
    clocks out, the clock-out board (ShiftClockOutBoard) sits under the Gloom meter.
    It does not follow the clock: the time-driven texts (the shift clock, a caught member's "back in", the board's
    truck countdown) tick inside their own small components, so the HUD re-renders only when its stores change.
]=]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local React = require(ReplicatedStorage.Packages.React)
local ReactCharm = require(ReplicatedStorage.Packages.ReactCharm)
local StateSyncConstants = require(ReplicatedStorage.Shared.Features.StateSync.Data.StateSyncConstants)
local InputServiceClient = require(ReplicatedStorage.Client.Features.Input.InputServiceClient)
local OccupantCatchStore = require(ReplicatedStorage.Client.Features.Occupant.State.OccupantCatchStore)
local ShiftStore = require(ReplicatedStorage.Client.Features.Shift.State.ShiftStore)
local StateSyncClientStore = require(ReplicatedStorage.Client.Features.StateSync.State.StateSyncClientStore)
local UIPaperConstants = require(ReplicatedStorage.Client.UI.React.Screens.Paper.UIPaperConstants)
local usePaperHudScale = require(ReplicatedStorage.Client.UI.React.Screens.Paper.usePaperHudScale)
local ShiftCrewViewModel = require(ReplicatedStorage.Client.UI.React.Screens.Shift.ShiftCrewViewModel)
local ShiftCompactHudPanel = require(ReplicatedStorage.Client.UI.React.Screens.Shift.ShiftCompactHudPanel)
local ShiftClockOutBoard = require(ReplicatedStorage.Client.UI.React.Screens.Shift.ShiftClockOutBoard)
local ShiftClockOutViewModel = require(ReplicatedStorage.Client.UI.React.Screens.Shift.ShiftClockOutViewModel)
local CargoServiceClient = require(ReplicatedStorage.Client.Features.Cargo.CargoServiceClient)
local usePaperViewport = require(ReplicatedStorage.Client.UI.React.Screens.Paper.usePaperViewport)
local ShiftHudViewModel = require(ReplicatedStorage.Client.UI.React.Screens.Shift.ShiftHudViewModel)
local SprintStore = require(ReplicatedStorage.Client.Features.Sprint.State.SprintStore)
local SprintViewModel = require(ReplicatedStorage.Client.UI.React.Screens.Sprint.SprintViewModel)
local ToonBar = require(ReplicatedStorage.Client.UI.React.Screens.Toon.ToonBar)

local e = React.createElement
local useAtom = ReactCharm.useAtom

-- Each hint action's keyboard bindings, read fresh so a rebind shows on the next render.
local function keyBindings(): ShiftHudViewModel.KeyBindings
	local bindings: ShiftHudViewModel.KeyBindings = {}
	for _, action in ShiftHudViewModel.HINT_ACTIONS do
		local found = InputServiceClient:bindingsFor(action)
		bindings[action] = if found ~= nil then found.keyboard else nil
	end
	return bindings
end

-- The stamina bar's fill: the one piece of the HUD that reads the stamina, so a sprint's ~20 stamina steps a second
-- re-render this bar alone rather than the whole HUD (ShiftHud follows only SprintStore.shown, to lay out around it).
local function StaminaBar(): React.ReactNode
	local view = SprintViewModel.bar(useAtom(SprintStore.stamina), false)
	if view == nil then
		return nil
	end
	return e(ToonBar, {
		kind = if view.low then "load" else "stamina",
		fill = view.fill,
		size = UDim2.fromScale(1, 1),
	})
end

local function ShiftHud(): React.ReactNode
	local snapshot = useAtom(ShiftStore.snapshot)
	local publicPlayers = useAtom(StateSyncClientStore.publicPlayers)
	local scaring = useAtom(OccupantCatchStore.scaring)
	local staminaShown = useAtom(SprintStore.shown)
	-- The desktop HUD is drawn scaled to the window; `viewport` is the window in HUD design px.
	local hudScale = usePaperHudScale()
	local actualViewport = usePaperViewport()
	local crewOpen, setCrewOpen = React.useState(false)
	React.useEffect(function()
		setCrewOpen(false)
	end, { if snapshot ~= nil then snapshot.shift else 0 })
	local layout: UIPaperConstants.Layout = hudScale.layout
	-- The clock as of this render: the static texts' time. The ticking ones read it themselves (ShiftCountdown).
	local now = Workspace:GetServerTimeNow()
	local player = Players.LocalPlayer
	local me = if player ~= nil then publicPlayers[StateSyncConstants.publicEntryKey(player.UserId)] else nil
	-- The panel is drawn (and hidden with a prop) rather than unmounted while hidden, so its stamps keep their state
	-- and do not pop again when the scare beat or the catch ends.
	local hidden = ShiftHudViewModel.hidden(me, scaring)
	local view = ShiftHudViewModel.hud(snapshot, me, now, false)
	if view == nil or snapshot == nil then
		return nil
	end
	local names: { [number]: string } = {}
	for _, userId in snapshot.crew do
		local member = Players:GetPlayerByUserId(userId)
		if member ~= nil then
			names[userId] = member.DisplayName
		end
	end
	local roster = ShiftCrewViewModel.roster(
		snapshot.crew,
		publicPlayers,
		names,
		snapshot.truck,
		snapshot.sub == "clockout",
		now,
		snapshot.punched
	)
	local bindings = keyBindings()
	local panel = e(ShiftCompactHudPanel, {
		view = view,
		roster = roster,
		layout = layout,
		viewport = actualViewport,
		myId = player.UserId,
		bindings = if UserInputService.KeyboardEnabled then bindings else {},
		stamina = if staminaShown then e(StaminaBar) else nil,
		live = true,
		crewOpen = crewOpen,
		onCrewToggle = function()
			setCrewOpen(function(open: boolean)
				return not open
			end)
		end,
		onSelect = function(slot: number)
			CargoServiceClient:select(slot)
		end,
	})
	-- While the crew clocks out: who is out and the truck's countdown, under the Gloom meter.
	local board = ShiftClockOutViewModel.board(snapshot, player.UserId)
	return e("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Visible = not hidden,
	}, {
		panel = panel,
		clockOut = if board ~= nil then e(ShiftClockOutBoard, { view = board, phone = layout == "phone" }) else nil,
	})
end

return ShiftHud
