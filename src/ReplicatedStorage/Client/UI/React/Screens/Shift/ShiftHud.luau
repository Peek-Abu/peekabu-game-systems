--!strict
--[=[
    ShiftHud: reads authoritative shift/public state and renders the approved compact paperwork HUD.
    Crew details are disclosed on demand. Physical-pixel sizes preserve readable text in short windows;
    the layout hook selects the phone arrangement. Catch/scare suppression stays on the outer frame.
]=]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local React = require(ReplicatedStorage.Packages.React)
local ReactCharm = require(ReplicatedStorage.Packages.ReactCharm)
local StateSyncConstants = require(ReplicatedStorage.Shared.Features.StateSync.Data.StateSyncConstants)
local InputServiceClient = require(ReplicatedStorage.Client.Features.Input.InputServiceClient)
local OccupantCatchStore = require(ReplicatedStorage.Client.Features.Occupant.State.OccupantCatchStore)
local ShiftStore = require(ReplicatedStorage.Client.Features.Shift.State.ShiftStore)
local StateSyncClientStore = require(ReplicatedStorage.Client.Features.StateSync.State.StateSyncClientStore)
local useServerClock = require(ReplicatedStorage.Client.UI.React.Hooks.useServerClock)
local UIPaperConstants = require(ReplicatedStorage.Client.UI.React.Screens.Paper.UIPaperConstants)
local usePaperHudScale = require(ReplicatedStorage.Client.UI.React.Screens.Paper.usePaperHudScale)
local ShiftCrewViewModel = require(ReplicatedStorage.Client.UI.React.Screens.Shift.ShiftCrewViewModel)
local ShiftCompactHudPanel = require(ReplicatedStorage.Client.UI.React.Screens.Shift.ShiftCompactHudPanel)
local VacuumServiceClient = require(ReplicatedStorage.Client.Features.Vacuum.VacuumServiceClient)
local usePaperViewport = require(ReplicatedStorage.Client.UI.React.Screens.Paper.usePaperViewport)
local ShiftHudViewModel = require(ReplicatedStorage.Client.UI.React.Screens.Shift.ShiftHudViewModel)
local SprintStore = require(ReplicatedStorage.Client.Features.Sprint.State.SprintStore)
local SprintViewModel = require(ReplicatedStorage.Client.UI.React.Screens.Sprint.SprintViewModel)

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

local function ShiftHud(): React.ReactNode
	local snapshot = useAtom(ShiftStore.snapshot)
	local publicPlayers = useAtom(StateSyncClientStore.publicPlayers)
	local scaring = useAtom(OccupantCatchStore.scaring)
	local stamina = useAtom(SprintStore.stamina)
	-- The desktop HUD is drawn scaled to the window; `viewport` is the window in HUD design px.
	local hudScale = usePaperHudScale()
	local actualViewport = usePaperViewport()
	local crewOpen, setCrewOpen = React.useState(false)
	React.useEffect(function()
		setCrewOpen(false)
	end, { if snapshot ~= nil then snapshot.shift else 0 })
	local layout: UIPaperConstants.Layout = hudScale.layout
	local now = useServerClock()
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
	local roster =
		ShiftCrewViewModel.roster(snapshot.crew, publicPlayers, names, snapshot.truck, snapshot.sub == "clockout", now)
	local bindings = keyBindings()
	local panel = e(ShiftCompactHudPanel, {
		view = view,
		roster = roster,
		layout = layout,
		viewport = actualViewport,
		bindings = if UserInputService.KeyboardEnabled then bindings else {},
		stamina = SprintViewModel.bar(stamina, false),
		crewOpen = crewOpen,
		onCrewToggle = function()
			setCrewOpen(function(open: boolean)
				return not open
			end)
		end,
		onToolToggle = function()
			VacuumServiceClient:toggleTool()
		end,
	})
	return e("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Visible = not hidden,
	}, { panel = panel })
end

return ShiftHud
