--!strict
--[=[
	CatchOverlay: the CCTV HUD widget (registered by OccupantServiceClient). Reads the shift snapshot, every player's
	public entry, the incident report, the server clock and who Death is spectating, builds CatchViewModel.cctv and draws
	CatchCctvPanel while the local player is caught; nothing otherwise (the scare beat stays bare: the local player is not
	`dead`, with a `caughtUntil`, until the throw; a plain death shows nothing). The key chips show the live spectate bindings (the arrow keys by default); the phone's
	"<" / ">" buttons call DeathServiceClient:cycleSpectate.

	@class CatchOverlay
]=]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local React = require(ReplicatedStorage.Packages.React)
local ReactCharm = require(ReplicatedStorage.Packages.ReactCharm)
local DeathConstants = require(ReplicatedStorage.Shared.Features.Death.Data.DeathConstants)
local StateSyncConstants = require(ReplicatedStorage.Shared.Features.StateSync.Data.StateSyncConstants)
local DeathServiceClient = require(ReplicatedStorage.Client.Features.Death.DeathServiceClient)
local InputServiceClient = require(ReplicatedStorage.Client.Features.Input.InputServiceClient)
local OccupantCatchStore = require(ReplicatedStorage.Client.Features.Occupant.State.OccupantCatchStore)
local ShiftStore = require(ReplicatedStorage.Client.Features.Shift.State.ShiftStore)
local StateSyncClientStore = require(ReplicatedStorage.Client.Features.StateSync.State.StateSyncClientStore)
local useServerClock = require(ReplicatedStorage.Client.UI.React.Hooks.useServerClock)
local CatchCctvPanel = require(ReplicatedStorage.Client.UI.React.Screens.Catch.CatchCctvPanel)
local CatchViewModel = require(ReplicatedStorage.Client.UI.React.Screens.Catch.CatchViewModel)
local useSpectateTarget = require(ReplicatedStorage.Client.UI.React.Screens.Catch.useSpectateTarget)
local PaperHudFrame = require(ReplicatedStorage.Client.UI.React.Screens.Paper.PaperHudFrame)
local UIPaperConstants = require(ReplicatedStorage.Client.UI.React.Screens.Paper.UIPaperConstants)
local usePaperHudScale = require(ReplicatedStorage.Client.UI.React.Screens.Paper.usePaperHudScale)
local ShiftHudViewModel = require(ReplicatedStorage.Client.UI.React.Screens.Shift.ShiftHudViewModel)

local e = React.createElement
local useAtom = ReactCharm.useAtom

-- The spectate actions' keyboard bindings, read fresh so a rebind shows on the next render.
local function spectateBindings(): ShiftHudViewModel.KeyBindings
	local bindings: ShiftHudViewModel.KeyBindings = {}
	for _, action in { DeathConstants.SPECTATE_PREV, DeathConstants.SPECTATE_NEXT } do
		local found = InputServiceClient:bindingsFor(action)
		bindings[action] = if found ~= nil then found.keyboard else nil
	end
	return bindings
end

-- The viewport's shorter side, in px (the engine sizes its Jump button by it; the widget re-renders on the clock tick).
local function shortSide(): number
	local camera = Workspace.CurrentCamera
	local viewport = if camera ~= nil then camera.ViewportSize else Vector2.new(844, 390)
	return math.min(viewport.X, viewport.Y)
end

local function cyclePrev()
	DeathServiceClient:cycleSpectate(-1)
end

local function cycleNext()
	DeathServiceClient:cycleSpectate(1)
end

local function CatchOverlay(): React.ReactNode
	local snapshot = useAtom(ShiftStore.snapshot)
	local publicPlayers = useAtom(StateSyncClientStore.publicPlayers)
	local report = useAtom(OccupantCatchStore.report)
	-- Drawn scaled to the window on desktop (its corner pieces, countdown and slip are fixed px), via PaperHudFrame.
	local hudScale = usePaperHudScale()
	local layout: UIPaperConstants.Layout = hudScale.layout
	local now = useServerClock()
	local targetId = useSpectateTarget()
	local player = Players.LocalPlayer
	local me = publicPlayers[StateSyncConstants.publicEntryKey(player.UserId)]
	local target = if targetId ~= nil then publicPlayers[StateSyncConstants.publicEntryKey(targetId)] else nil
	local targetPlayer = if targetId ~= nil then Players:GetPlayerByUserId(targetId) else nil
	local prevKey, nextKey = CatchViewModel.spectateKeys(spectateBindings())
	local view = CatchViewModel.cctv({
		snapshot = snapshot,
		me = me,
		report = report,
		targetName = if targetPlayer ~= nil then targetPlayer.DisplayName else nil,
		target = target,
		now = now,
		prevKey = prevKey,
		nextKey = nextKey,
		phone = layout == "phone",
	})
	if view == nil then
		return nil
	end
	return e(PaperHudFrame, {
		scale = hudScale.scale,
		children = {
			panel = e(CatchCctvPanel, {
				view = view,
				layout = layout,
				onPrev = cyclePrev,
				onNext = cycleNext,
				jump = ShiftHudViewModel.arcFor(shortSide()).jump,
			}),
		},
	})
end

return CatchOverlay
