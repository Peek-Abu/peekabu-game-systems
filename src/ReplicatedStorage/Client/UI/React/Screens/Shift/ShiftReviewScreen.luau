--!strict
--[=[
	ShiftReviewScreen: the performance review scene's screen (ShiftScene). Reads the snapshot and the local player's
	vote from ShiftStore, the device layout, the server clock and the viewport, and draws ShiftReviewPanel from
	ShiftReviewViewModel, scaled to the viewport, with the local player's company rank (their public entry,
	RankViewModel.slip over the same review). A vote writes ShiftStore.myVote, which ShiftServiceClient sends
	(components never talk to the server). Over it, the favorite/like ask (SocialAskCard) while SocialAskStore says it
	is up. No logic of its own.

	@class ShiftReviewScreen
]=]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local ReactCharm = require(ReplicatedStorage.Packages.ReactCharm)
local ShiftTypes = require(ReplicatedStorage.Shared.Features.Shift.Data.ShiftTypes)
local ShiftStore = require(ReplicatedStorage.Client.Features.Shift.State.ShiftStore)
local ShiftTransitStore = require(ReplicatedStorage.Client.Features.Shift.State.ShiftTransitStore)
local StateSyncClientStore = require(ReplicatedStorage.Client.Features.StateSync.State.StateSyncClientStore)
local useServerClock = require(ReplicatedStorage.Client.UI.React.Hooks.useServerClock)
local UIPaperConstants = require(ReplicatedStorage.Client.UI.React.Screens.Paper.UIPaperConstants)
local usePaperLayout = require(ReplicatedStorage.Client.UI.React.Screens.Paper.usePaperLayout)
local usePaperViewport = require(ReplicatedStorage.Client.UI.React.Screens.Paper.usePaperViewport)
local ShiftReviewPanel = require(ReplicatedStorage.Client.UI.React.Screens.Shift.ShiftReviewPanel)
local ShiftReviewViewModel = require(ReplicatedStorage.Client.UI.React.Screens.Shift.ShiftReviewViewModel)
local RankViewModel = require(ReplicatedStorage.Client.UI.React.Screens.Rank.RankViewModel)
local SocialService = require(ReplicatedStorage.Client.Features.Social.SocialServiceClient)
local SocialAskStore = require(ReplicatedStorage.Client.Features.Social.State.SocialAskStore)
local SocialAskCard = require(ReplicatedStorage.Client.UI.React.Screens.Social.SocialAskCard)

local e = React.createElement
local useAtom = ReactCharm.useAtom

local function vote(choice: ShiftTypes.Vote)
	ShiftStore.myVote(choice)
end

local function ShiftReviewScreen(): React.ReactNode
	local snapshot = useAtom(ShiftStore.snapshot)
	local myVote = useAtom(ShiftStore.myVote)
	local publicPlayers = useAtom(StateSyncClientStore.publicPlayers)
	local asking = useAtom(SocialAskStore.visible)
	local layout: UIPaperConstants.Layout = usePaperLayout()
	local now = useServerClock()
	local viewport = usePaperViewport()
	local phone = layout == "phone"
	local userId = Players.LocalPlayer.UserId
	local transit = useAtom(ShiftTransitStore.snapshot)
	local view = ShiftReviewViewModel.review(snapshot, myVote, userId, now, phone, transit)
	if view == nil or snapshot == nil then
		return nil
	end
	local rank =
		RankViewModel.slip(RankViewModel.rankOf(publicPlayers, userId), snapshot.results, snapshot.crew, userId)
	local props: ShiftReviewPanel.ShiftReviewPanelProps = {
		view = view,
		layout = layout,
		scale = ShiftReviewViewModel.fit(viewport, phone),
		onVote = vote,
		rank = rank,
	}
	return e(React.Fragment, nil, {
		review = e(ShiftReviewPanel, props),
		ask = if asking
			then e(SocialAskCard, {
				phone = phone,
				onFavorite = function()
					SocialService:favorite()
				end,
				onDismiss = function()
					SocialService:dismissAsk()
				end,
			})
			else nil,
	})
end

return ShiftReviewScreen
