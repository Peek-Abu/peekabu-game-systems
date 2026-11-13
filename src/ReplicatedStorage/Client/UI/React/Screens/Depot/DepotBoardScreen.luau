--!strict
--[=[
	DepotBoardScreen: the places menu scene's screen (DepotScene; p1-places-menu). Reads the open contract and the last
	shift from DepotStore, the reader's truck crew from QueueStore, its host from HostStore, the truck's place pick from
	the world entry (DepotMapRules.decode), the reader's bought places and Credits from the synced profile, and the
	device layout, and draws DepotBoardPanel from DepotBoardViewModel, scaled to the viewport. A host's tap on an open
	place picks it (DepotPlaceSender.pick); anyone's tap on a card shows its detail; BUY takes two taps (the first asks
	SURE? for DepotPlaceConstants.CONFIRM_SECONDS, the second sends DepotPlaceSender.buy; short of Credits, the
	button offers the Gleam for the rest at the Shop's rate and sends that as the agreed most). The LOCKER and GUIDE tabs (and
	READ THE BRIEF) swap the board for that hub page. CLOSE and FIND A TRUCK take the scene off the stack (Escape pops
	it through UIServiceClient); DepotServiceClient clears the store's board once the scene has left the stack.

	@class DepotBoardScreen
]=]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local ReactCharm = require(ReplicatedStorage.Packages.ReactCharm)
local CurrencyConstants = require(ReplicatedStorage.Shared.Features.Currency.Data.CurrencyConstants)
local DepotConstants = require(ReplicatedStorage.Shared.Features.Depot.Data.DepotConstants)
local DepotPlaceConstants = require(ReplicatedStorage.Shared.Features.Depot.Data.DepotPlaceConstants)
local DepotMapRules = require(ReplicatedStorage.Shared.Features.Depot.Rules.DepotMapRules)
local HostSnapshotUtils = require(ReplicatedStorage.Shared.Features.Host.Utils.HostSnapshotUtils)
local QueueSnapshotUtils = require(ReplicatedStorage.Shared.Features.Queue.Utils.QueueSnapshotUtils)
local ShiftTypes = require(ReplicatedStorage.Shared.Features.Shift.Data.ShiftTypes)
local DepotPlaceSender = require(ReplicatedStorage.Client.Features.Depot.Net.DepotPlaceSender)
local DepotStore = require(ReplicatedStorage.Client.Features.Depot.State.DepotStore)
local HostStore = require(ReplicatedStorage.Client.Features.Host.State.HostStore)
local QueueStore = require(ReplicatedStorage.Client.Features.Queue.State.QueueStore)
local StateSyncClientStore = require(ReplicatedStorage.Client.Features.StateSync.State.StateSyncClientStore)
local SceneStack = require(ReplicatedStorage.Client.UI.Scenes.SceneStack)
local UIPaperConstants = require(ReplicatedStorage.Client.UI.React.Screens.Paper.UIPaperConstants)
local usePaperLayout = require(ReplicatedStorage.Client.UI.React.Screens.Paper.usePaperLayout)
local usePaperViewport = require(ReplicatedStorage.Client.UI.React.Screens.Paper.usePaperViewport)
local DepotBoardPanel = require(ReplicatedStorage.Client.UI.React.Screens.Depot.DepotBoardPanel)
local DepotBoardViewModel = require(ReplicatedStorage.Client.UI.React.Screens.Depot.DepotBoardViewModel)
local DepotHubViewModel = require(ReplicatedStorage.Client.UI.React.Screens.Depot.DepotHubViewModel)
local InventoryViewModel = require(ReplicatedStorage.Client.UI.React.Screens.Inventory.InventoryViewModel)

local e = React.createElement
local useAtom = ReactCharm.useAtom

type MapId = ShiftTypes.MapId

local CREDITS: CurrencyConstants.CurrencyType = "credits"

local function close()
	SceneStack.remove(DepotConstants.BOARD_SCENE)
end

-- The Jobs menu's other tabs (and READ THE BRIEF): leave the board for that hub page.
local function openTab(tab: DepotBoardPanel.Tab)
	SceneStack.remove(DepotConstants.BOARD_SCENE)
	-- The Locker tab is the Inventory now (the vacuum and the crew live there).
	SceneStack.push(if tab == "locker" then InventoryViewModel.SCENE else DepotHubViewModel.scene("guide"))
end

local function DepotBoardScreen(): React.ReactNode
	local board = useAtom(DepotStore.board)
	local lastShift = useAtom(DepotStore.lastShift)
	local queue = useAtom(QueueStore.snapshot)
	local hosts = useAtom(HostStore.snapshot)
	local world = useAtom(StateSyncClientStore.world)
	local owned = useAtom(StateSyncClientStore.places)
	local currency = useAtom(StateSyncClientStore.currency)
	local premium = useAtom(StateSyncClientStore.premium)
	local none: MapId? = nil
	local viewing, setViewing = React.useState(none)
	local confirming, setConfirming = React.useState(none)
	-- The SURE? waits CONFIRM_SECONDS, then goes back to BUY.
	React.useEffect(function(): (() -> ())?
		if confirming == nil then
			return nil
		end
		local thread = task.delay(DepotPlaceConstants.CONFIRM_SECONDS, function()
			setConfirming(nil)
		end)
		return function()
			task.cancel(thread)
		end
	end, { confirming })
	local me = Players.LocalPlayer.UserId
	local crew = DepotBoardViewModel.crewOf(queue, me)
	local padId = QueueSnapshotUtils.padOf(queue, me)
	local hostId = if padId ~= nil then HostSnapshotUtils.hostOf(hosts, padId) else nil
	local role: DepotBoardViewModel.Role = DepotBoardViewModel.roleOf(padId, hostId, me)
	local picked: MapId? = if role ~= "none"
		then DepotMapRules.mapOf(DepotMapRules.decode(world[DepotConstants.MAP_WORLD_ENTRY]), padId)
		else nil
	local credits = if currency ~= nil then currency[CREDITS] or 0 else 0
	local layout: UIPaperConstants.Layout = usePaperLayout()
	local viewport = usePaperViewport()
	local phone = layout == "phone"
	local places: DepotBoardViewModel.PlacesInput = {
		owned = owned,
		picked = picked,
		viewing = viewing,
		role = role,
		credits = credits,
		gleam = premium.balance,
		confirming = confirming,
	}
	local props: DepotBoardPanel.DepotBoardPanelProps = {
		view = DepotBoardViewModel.board(board, lastShift, phone, crew, places),
		layout = layout,
		scale = DepotBoardViewModel.fit(viewport, phone),
		onClose = close,
		onTab = openTab,
		onPick = function(map: MapId)
			setViewing(map)
			DepotPlaceSender.pick(map)
		end,
		onView = function(map: MapId)
			setViewing(map)
		end,
		onBuy = function(map: MapId, gleam: number)
			if confirming == map then
				setConfirming(nil)
				DepotPlaceSender.buy(map, gleam)
			else
				setConfirming(map)
			end
		end,
	}
	return e(DepotBoardPanel, props)
end

return DepotBoardScreen
