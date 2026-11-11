--!strict
--[=[
	DepotHub: the depot hub's HUD widget (registered by DepotServiceClient). Reads the shift snapshot (never shown over a
	crew's shift), the travel card (hidden under it), the player's published rank, their Credits (the `credits` balance),
	the daily reward slice on the server clock, the contract board's contract and whether they are aboard a truck,
	and draws DepotHubPanel in the V1 kit. JOBS / the Tonight card / GO! (when not aboard) open the contract board;
	INVENTORY opens the Inventory, SHOP the Shop; GUIDE and SETTINGS push the hub pages; INVITE FRIENDS / JOIN GROUP call SocialServiceClient (SocialPerksPanel, hidden under the open clipboard); the clipboard is a CLIPBOARD tile under SHOP and the invite row sits under the Tonight card (owner 11-08, layout A; no clipboard before training is done, DepotHubViewModel.clipboardShown); the gift asks to claim (`onClaimGift`, from the service: components
	never talk to the server). Aboard a truck the Next shift card is the queue pad's (DepotPad). Values are specced in
	DepotHubViewModel (off a truck, the small Find a truck tab instead of the Next shift card, hidden while a prompt is up).

	@class DepotHub
]=]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local TimecardPanel = require(script.Parent.DepotTimecardPanel)
local TimecardRules = require(ReplicatedStorage.Shared.Features.Timecard.Rules.TimecardRules)
local TimecardService = require(ReplicatedStorage.Client.Features.Timecard.TimecardServiceClient)
local WorkOrderRules = require(ReplicatedStorage.Shared.Features.WorkOrder.Rules.WorkOrderRules)
local WorkOrderRegistry = require(ReplicatedStorage.Shared.Features.WorkOrder.Data.WorkOrderRegistry)
local Company = require(ReplicatedStorage.Client.Features.UI.State.UICompanyStore)
local TimecardMomentStore = require(ReplicatedStorage.Client.Features.Timecard.State.TimecardMomentStore)
local ReactCharm = require(ReplicatedStorage.Packages.ReactCharm)
local DepotConstants = require(ReplicatedStorage.Shared.Features.Depot.Data.DepotConstants)
local QueueSnapshotUtils = require(ReplicatedStorage.Shared.Features.Queue.Utils.QueueSnapshotUtils)
local InventoryViewModel = require(script.Parent.Parent.Inventory.InventoryViewModel)
local ShopViewModel = require(script.Parent.Parent.Shop.ShopViewModel)
local ShopStore = require(ReplicatedStorage.Client.Features.Shop.State.ShopStore)
local CurrencyUtils = require(ReplicatedStorage.Shared.Features.Currency.Utils.CurrencyUtils)
local DepotStore = require(ReplicatedStorage.Client.Features.Depot.State.DepotStore)
local QueueStore = require(ReplicatedStorage.Client.Features.Queue.State.QueueStore)
local ShiftStore = require(ReplicatedStorage.Client.Features.Shift.State.ShiftStore)
local ShiftPromptStore = require(ReplicatedStorage.Client.Features.Shift.State.ShiftPromptStore)
local SocialService = require(ReplicatedStorage.Client.Features.Social.SocialServiceClient)
local StateSyncClientStore = require(ReplicatedStorage.Client.Features.StateSync.State.StateSyncClientStore)
local SceneStack = require(ReplicatedStorage.Client.UI.Scenes.SceneStack)
local useServerClock = require(ReplicatedStorage.Client.UI.React.Hooks.useServerClock)
local DepotHubPanel = require(ReplicatedStorage.Client.UI.React.Screens.Depot.DepotHubPanel)
local VM = require(ReplicatedStorage.Client.UI.React.Screens.Depot.DepotHubViewModel)
local PaperHudFrame = require(ReplicatedStorage.Client.UI.React.Screens.Paper.PaperHudFrame)
local usePaperHudScale = require(ReplicatedStorage.Client.UI.React.Screens.Paper.usePaperHudScale)
local RankViewModel = require(ReplicatedStorage.Client.UI.React.Screens.Rank.RankViewModel)
local SocialPerksPanel = require(ReplicatedStorage.Client.UI.React.Screens.Social.SocialPerksPanel)
local ToonStyleViewModel = require(ReplicatedStorage.Client.UI.React.Screens.Toon.ToonStyleViewModel)
local TrainingRules = require(ReplicatedStorage.Shared.Features.Training.Rules.TrainingRules)

export type DepotHubProps = {
	onClaimGift: () -> (),
}

-- The contract the depot's board shows (its shell carries the id), or nil before the board has streamed in.
local function boardContract(): string?
	for _, shell in CollectionService:GetTagged(DepotConstants.BILLBOARD_TAGS.contract) do
		local id = shell:GetAttribute(DepotConstants.CONTRACT_KEYS.id)
		if type(id) == "string" then
			return id
		end
	end
	return nil
end

local function openBoard()
	DepotStore.openBoard(boardContract() or DepotConstants.CONTRACTS[1].id)
	SceneStack.push(DepotConstants.BOARD_SCENE)
end

local function DepotHub(props: DepotHubProps): React.ReactNode
	local snapshot = ReactCharm.useAtom(ShiftStore.snapshot)
	local card = ReactCharm.useAtom(DepotStore.card)
	local publicPlayers = ReactCharm.useAtom(StateSyncClientStore.publicPlayers)
	local currency = ReactCharm.useAtom(StateSyncClientStore.currency)
	local daily = ReactCharm.useAtom(StateSyncClientStore.dailyReward)
	local queue = ReactCharm.useAtom(QueueStore.snapshot)
	local now = useServerClock(1)
	local timecard = ReactCharm.useAtom(StateSyncClientStore.timecard)
	local workOrder = ReactCharm.useAtom(StateSyncClientStore.workOrder)
	local clipboardOpen = ReactCharm.useAtom(Company.visible)
	local clipboardTab = ReactCharm.useAtom(Company.selectedTab)
	local pinned = ReactCharm.useAtom(Company.pinned)
	local punchFeedback = ReactCharm.useAtom(TimecardService.feedback)
	local punchPending = ReactCharm.useAtom(TimecardService.pending)
	local stamp = ReactCharm.useAtom(TimecardMomentStore.stamp)
	local social = ReactCharm.useAtom(StateSyncClientStore.social)
	local training = ReactCharm.useAtom(StateSyncClientStore.training)
	-- An interaction prompt is up: the Find a truck tab steps aside (owner 11-11).
	local promptUp = ReactCharm.useAtom(ShiftPromptStore.shown) ~= nil
	local scale = usePaperHudScale()
	local player = Players.LocalPlayer
	if not VM.visible(snapshot, player.UserId) or card ~= nil then
		return nil
	end
	local phone = scale.layout == "phone"
	local showClipboard = VM.clipboardShown(TrainingRules.isNew(training))
	local status = TimecardRules.status(timecard, now)
	-- The invite row under the Tonight card (design px; phone: under the right column).
	local socialAt = if phone then UDim2.new(1, -234, 0, 288) else UDim2.new(1, -520, 0, 364)
	local socialSize = if phone then UDim2.fromOffset(220, 34) else UDim2.fromOffset(336, 48)
	local rank = RankViewModel.rankOf(publicPlayers, player.UserId)
	local _, pad = QueueSnapshotUtils.padOf(queue, player.UserId)
	return React.createElement(PaperHudFrame, {
		scale = scale.scale,
		children = {
			calendar = React.createElement(TimecardPanel, {
				phone = phone,
				open = clipboardOpen,
				button = false,
				view = if clipboardTab == "workOrder" then "workOrder" else "timecard",
				pinned = pinned,
				onPin = Company.togglePin,
				onTimecard = function()
					Company.select("timecard")
				end,
				now = now,
				kind = WorkOrderRegistry.orderFor(now).kind,
				status = status,
				progress = WorkOrderRules.roll(workOrder, now).progress,
				target = WorkOrderRegistry.orderFor(now).target,
				order = WorkOrderRegistry.orderFor(now).label,
				claimed = WorkOrderRules.roll(workOrder, now).claimed,
				feedback = punchFeedback,
				pending = punchPending,
				stamp = stamp,
				onToggle = function()
					Company.toggle()
				end,
				onWorkOrder = function()
					Company.select("workOrder")
				end,
				onClose = function()
					Company.close()
				end,
				onPunch = function()
					TimecardService:punch()
				end,
			}),
			hub = React.createElement(DepotHubPanel, {
				phone = phone,
				userId = player.UserId,
				profile = VM.profile(player.DisplayName, rank),
				credits = ToonStyleViewModel.grouped(CurrencyUtils.getCurrencyAmount(currency, "credits")),
				gift = VM.gift(daily, now),
				tonight = VM.tonight(boardContract()),
				cta = nil,
				findTruck = VM.findTruck(pad ~= nil, promptUp),
				newJobs = rank == nil or rank.xp == 0,
				onJobs = openBoard,
				onInventory = function()
					SceneStack.push(InventoryViewModel.SCENE)
				end,
				onShop = function()
					ShopStore.open(nil)
					SceneStack.push(ShopViewModel.SCENE)
				end,
				onGuide = function()
					SceneStack.push(VM.scene("guide"))
				end,
				onSettings = function()
					SceneStack.push(VM.scene("settings"))
				end,
				onGift = props.onClaimGift,
				onGo = openBoard,
				clipboardBadge = status.canPunch,
				onClipboard = if showClipboard
					then function()
						Company.open(nil)
					end
					else nil,
			}),
			social = if clipboardOpen
				then nil
				else React.createElement(SocialPerksPanel, {
					phone = phone,
					showGroup = not social.groupPaid,
					position = socialAt,
					size = socialSize,
					onInvite = function()
						SocialService:invite()
					end,
					onJoinGroup = function()
						SocialService:joinGroup()
					end,
				}),
		},
	})
end

return DepotHub
