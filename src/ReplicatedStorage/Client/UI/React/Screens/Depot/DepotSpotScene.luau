--!strict
--[=[
	DepotSpotScene: registers the hub spots' scenes (plan docs/superpowers/plans/2026-11-11-hub-interactables.md), each
	on the Panel layer with the mouse freed and the HUD hidden; DepotSpotSystem pushes them when a spot is used, and the
	X / CLOSE (or Escape) takes them off the stack:

	- coffee: the coffee choice (CoffeeChoice) in the middle of the screen with the hub's line, paid through
	  CoffeeServiceClient (the server checks the Gleam; the coffee time is spent on the next shift);
	- crew wall: the weekly crew board (LeaderboardBoard, from the `crewBoard` world entry) big, with CLOSE;
	- rank chart: DepotRankChart from your published XP (RankServiceClient).

	Declarative (registers at require); the words are the specced view models and CoffeeRules.

	@class DepotSpotScene
]=]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local React = require(ReplicatedStorage.Packages.React)
local ReactCharm = require(ReplicatedStorage.Packages.ReactCharm)
local CoffeeConstants = require(ReplicatedStorage.Shared.Features.Coffee.Data.CoffeeConstants)
local CoffeeRules = require(ReplicatedStorage.Shared.Features.Coffee.Rules.CoffeeRules)
local DepotSpotConstants = require(ReplicatedStorage.Shared.Features.Depot.Data.DepotSpotConstants)
local LeaderboardConstants = require(ReplicatedStorage.Shared.Features.Leaderboard.Data.LeaderboardConstants)
local LeaderboardCrewUtils = require(ReplicatedStorage.Shared.Features.Leaderboard.Utils.LeaderboardCrewUtils)
local CoffeeServiceClient = require(ReplicatedStorage.Client.Features.Coffee.CoffeeServiceClient)
local CoffeeStore = require(ReplicatedStorage.Client.Features.Coffee.State.CoffeeStore)
local RankServiceClient = require(ReplicatedStorage.Client.Features.Rank.RankServiceClient)
local StateSyncClientStore = require(ReplicatedStorage.Client.Features.StateSync.State.StateSyncClientStore)
local SceneRegistry = require(ReplicatedStorage.Client.UI.Scenes.SceneRegistry)
local SceneStack = require(ReplicatedStorage.Client.UI.Scenes.SceneStack)
local Screens = ReplicatedStorage.Client.UI.React.Screens
local CoffeeChoice = require(Screens.Coffee.CoffeeChoice)
local DepotRankChart = require(Screens.Depot.DepotRankChart)
local DepotRankChartViewModel = require(Screens.Depot.DepotRankChartViewModel)
local LeaderboardBoard = require(Screens.Leaderboard.LeaderboardBoard)
local LeaderboardBoardViewModel = require(Screens.Leaderboard.LeaderboardBoardViewModel)
local ToonButton = require(Screens.Toon.ToonButton)
local usePaperLayout = require(Screens.Paper.usePaperLayout)
local usePaperViewport = require(Screens.Paper.usePaperViewport)

local e = React.createElement
local SCENES = DepotSpotConstants.SCENES
-- The crew board's design size (LeaderboardBoard) and the room under it for CLOSE.
local BOARD = Vector2.new(720, 560)
local CLOSE_ROOM = 84

local function closer(scene: string): () -> ()
	return function()
		SceneStack.remove(scene)
	end
end

local function CoffeeScreen(): React.ReactNode
	local premium = ReactCharm.useAtom(StateSyncClientStore.premium)
	local robux = ReactCharm.useAtom(CoffeeStore.robux)
	local close = closer(SCENES.coffee)
	return e(CoffeeChoice, {
		phone = usePaperLayout() == "phone",
		position = UDim2.fromScale(0.5, 0.45),
		anchor = Vector2.new(0.5, 0.5),
		line = DepotSpotConstants.COFFEE_LINE,
		onRobux = if CoffeeConstants.PRODUCT_ID ~= nil
			then function()
				close()
				CoffeeServiceClient:buyRobux()
			end
			else nil,
		robuxText = CoffeeRules.robuxText(robux),
		onGleam = function()
			close()
			CoffeeServiceClient:buyGleam()
		end,
		onClose = close,
		short = not CoffeeRules.affords(premium.balance),
		shortLine = CoffeeRules.shortLine(),
	})
end

local function CrewWallScreen(): React.ReactNode
	local world = ReactCharm.useAtom(StateSyncClientStore.world)
	local viewport = usePaperViewport()
	local board = LeaderboardCrewUtils.decodeBoard(world[LeaderboardConstants.WORLD_ENTRY])
	local view = LeaderboardBoardViewModel.view(board, Workspace:GetServerTimeNow())
	local scale = math.min(1, viewport.X * 0.92 / BOARD.X, viewport.Y * 0.92 / (BOARD.Y + CLOSE_ROOM))
	return e("Frame", {
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(BOARD.X, BOARD.Y + CLOSE_ROOM),
	}, {
		scale = e("UIScale", { Scale = scale }),
		board = e("Frame", {
			BackgroundTransparency = 1,
			Size = UDim2.fromOffset(BOARD.X, BOARD.Y),
		}, { board = e(LeaderboardBoard, { view = view }) }),
		close = e(ToonButton, {
			variant = "grape",
			text = "CLOSE",
			textSize = 30,
			anchor = Vector2.new(0.5, 1),
			position = UDim2.fromScale(0.5, 1),
			size = UDim2.fromOffset(240, 66),
			onActivated = closer(SCENES.crew),
		}),
	})
end

local function RankChartScreen(): React.ReactNode
	local phone = usePaperLayout() == "phone"
	local viewport = usePaperViewport()
	-- Re-read when the published players change (a rank landing while the chart is open).
	ReactCharm.useAtom(StateSyncClientStore.publicPlayers)
	local rank = RankServiceClient:rankOf(Players.LocalPlayer.UserId)
	return e(DepotRankChart, {
		view = DepotRankChartViewModel.chart(if rank ~= nil then rank.xp else nil),
		phone = phone,
		scale = DepotRankChartViewModel.fit(viewport, phone),
		onClose = closer(SCENES.rank),
	})
end

local function register(name: string, key: string, component: () -> React.ReactNode)
	if not SceneRegistry.has(name) then
		SceneRegistry.register({
			name = name,
			screens = { { layer = "Panel", key = key, component = component } },
			suppress = { mouse = true },
			hud = "hidden",
		})
	end
end

register(SCENES.coffee, "coffee", CoffeeScreen)
register(SCENES.crew, "crewWall", CrewWallScreen)
register(SCENES.rank, "rankChart", RankChartScreen)

return {}
