--!strict
--[=[
	DepotBoardScreen: the contract board scene's screen (DepotScene). Reads the open contract and the last shift from
	DepotStore and the device layout, and draws DepotBoardPanel from DepotBoardViewModel, scaled to the viewport.
	CLOSE takes the scene off the stack (Escape pops it through UIServiceClient); DepotServiceClient clears the store's
	board once the scene has left the stack. No logic of its own.

	@class DepotBoardScreen
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local React = require(ReplicatedStorage.Packages.React)
local ReactCharm = require(ReplicatedStorage.Packages.ReactCharm)
local DepotConstants = require(ReplicatedStorage.Shared.Features.Depot.Data.DepotConstants)
local DepotStore = require(ReplicatedStorage.Client.Features.Depot.State.DepotStore)
local SceneStack = require(ReplicatedStorage.Client.UI.Scenes.SceneStack)
local UIPaperConstants = require(ReplicatedStorage.Client.UI.React.Screens.Paper.UIPaperConstants)
local usePaperLayout = require(ReplicatedStorage.Client.UI.React.Screens.Paper.usePaperLayout)
local DepotBoardPanel = require(ReplicatedStorage.Client.UI.React.Screens.Depot.DepotBoardPanel)
local DepotBoardViewModel = require(ReplicatedStorage.Client.UI.React.Screens.Depot.DepotBoardViewModel)

local e = React.createElement
local useAtom = ReactCharm.useAtom

local function readViewport(): Vector2
	local camera = Workspace.CurrentCamera
	return if camera ~= nil then camera.ViewportSize else Vector2.new(1920, 1080)
end

local function useViewport(): Vector2
	local viewport, setViewport = React.useState(readViewport)
	React.useEffect(function(): () -> ()
		local camera = Workspace.CurrentCamera
		if camera == nil then
			return function() end
		end
		local connection = camera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
			setViewport(readViewport())
		end)
		return function()
			connection:Disconnect()
		end
	end, {})
	return viewport
end

local function close()
	SceneStack.remove(DepotConstants.BOARD_SCENE)
end

local function DepotBoardScreen(): React.ReactNode
	local board = useAtom(DepotStore.board)
	local lastShift = useAtom(DepotStore.lastShift)
	local layout: UIPaperConstants.Layout = usePaperLayout()
	local viewport = useViewport()
	local phone = layout == "phone"
	local props: DepotBoardPanel.DepotBoardPanelProps = {
		view = DepotBoardViewModel.board(board, lastShift, phone),
		layout = layout,
		scale = DepotBoardViewModel.fit(viewport, phone),
		onClose = close,
	}
	return e(DepotBoardPanel, props)
end

return DepotBoardScreen
