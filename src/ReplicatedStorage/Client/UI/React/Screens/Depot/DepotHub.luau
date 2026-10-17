--!strict
--[=[
	DepotHub: the depot hub's HUD widget (registered by DepotServiceClient). Reads the shift snapshot (never shown over a
	crew's shift), the travel card (hidden under it), the player's published rank, their Gleam (the `coins` balance),
	the daily reward slice on the server clock, the contract board's contract and whether they are aboard a truck,
	and draws DepotHubPanel in the V1 kit. JOBS / the Tonight card / GO! (when not aboard) open the contract board;
	LOCKER, GUIDE and SETTINGS push the hub pages; the gift asks to claim (`onClaimGift`, from the service: components
	never talk to the server). Aboard a truck the Next shift card is the queue pad's (DepotPad). Values are specced in
	DepotHubViewModel and DepotPadViewModel.

	@class DepotHub
]=]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local ReactCharm = require(ReplicatedStorage.Packages.ReactCharm)
local DepotConstants = require(ReplicatedStorage.Shared.Features.Depot.Data.DepotConstants)
local QueueSnapshotUtils = require(ReplicatedStorage.Shared.Features.Queue.Utils.QueueSnapshotUtils)
local CurrencyUtils = require(ReplicatedStorage.Shared.Features.Currency.Utils.CurrencyUtils)
local DepotStore = require(ReplicatedStorage.Client.Features.Depot.State.DepotStore)
local QueueStore = require(ReplicatedStorage.Client.Features.Queue.State.QueueStore)
local ShiftStore = require(ReplicatedStorage.Client.Features.Shift.State.ShiftStore)
local StateSyncClientStore = require(ReplicatedStorage.Client.Features.StateSync.State.StateSyncClientStore)
local SceneStack = require(ReplicatedStorage.Client.UI.Scenes.SceneStack)
local useServerClock = require(ReplicatedStorage.Client.UI.React.Hooks.useServerClock)
local DepotHubPanel = require(ReplicatedStorage.Client.UI.React.Screens.Depot.DepotHubPanel)
local DepotPadViewModel = require(ReplicatedStorage.Client.UI.React.Screens.Depot.DepotPadViewModel)
local VM = require(ReplicatedStorage.Client.UI.React.Screens.Depot.DepotHubViewModel)
local PaperHudFrame = require(ReplicatedStorage.Client.UI.React.Screens.Paper.PaperHudFrame)
local usePaperHudScale = require(ReplicatedStorage.Client.UI.React.Screens.Paper.usePaperHudScale)
local RankViewModel = require(ReplicatedStorage.Client.UI.React.Screens.Rank.RankViewModel)
local ToonStyleViewModel = require(ReplicatedStorage.Client.UI.React.Screens.Toon.ToonStyleViewModel)

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
	local scale = usePaperHudScale()
	local player = Players.LocalPlayer
	if not VM.visible(snapshot, player.UserId) or card ~= nil then
		return nil
	end
	local phone = scale.layout == "phone"
	local rank = RankViewModel.rankOf(publicPlayers, player.UserId)
	local _, pad = QueueSnapshotUtils.padOf(queue, player.UserId)
	return React.createElement(PaperHudFrame, {
		scale = scale.scale,
		children = {
			hub = React.createElement(DepotHubPanel, {
				phone = phone,
				profile = VM.profile(player.DisplayName, rank),
				gleam = ToonStyleViewModel.grouped(CurrencyUtils.getCurrencyAmount(currency, "coins")),
				gift = VM.gift(daily, now),
				tonight = VM.tonight(boardContract()),
				cta = if pad == nil then DepotPadViewModel.cta(nil, nil) else nil,
				newJobs = rank == nil or rank.xp == 0,
				onJobs = openBoard,
				onLocker = function()
					SceneStack.push(VM.scene("gear"))
				end,
				onGuide = function()
					SceneStack.push(VM.scene("guide"))
				end,
				onSettings = function()
					SceneStack.push(VM.scene("settings"))
				end,
				onGift = props.onClaimGift,
				onGo = openBoard,
			}),
		},
	})
end

return DepotHub
