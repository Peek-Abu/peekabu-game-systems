--!strict
--[=[
	QueuePadStatus: the base's placeholder HUD widget for queue pads. Shows QueuePadPanel while the local
	player is aboard a pad, with a countdown that ticks locally against server time. Reads QueueStore; Depart
	now is the `onDepart` the service passes in (components never talk to the server). Hidden when a game
	turns the default widget off.

	@class QueuePadStatus
]=]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local ReactCharm = require(ReplicatedStorage.Packages.ReactCharm)
local QueueSnapshotUtils = require(ReplicatedStorage.Shared.Features.Queue.Utils.QueueSnapshotUtils)
local QueueStore = require(ReplicatedStorage.Client.Features.Queue.State.QueueStore)
local QueuePadPanel = require(ReplicatedStorage.Client.UI.React.Screens.Hud.QueuePadPanel)

local TICK_SECONDS = 0.2

export type QueuePadStatusProps = {
	onDepart: () -> (),
}

local function QueuePadStatus(props: QueuePadStatusProps): React.ReactNode
	local enabled = ReactCharm.useAtom(QueueStore.widgetEnabled)
	local snapshot = ReactCharm.useAtom(QueueStore.snapshot)
	local now, setNow = React.useState(workspace:GetServerTimeNow())
	local _, pad = QueueSnapshotUtils.padOf(snapshot, Players.LocalPlayer.UserId)
	local ticking = pad ~= nil and pad.endsAt ~= nil

	React.useEffect(function(): () -> ()
		local running = ticking
		if running then
			task.spawn(function()
				while running do
					setNow(workspace:GetServerTimeNow())
					task.wait(TICK_SECONDS)
				end
			end)
		end
		return function()
			running = false
		end
	end, { ticking })

	if not enabled or pad == nil then
		return nil
	end
	local endsAt = pad.endsAt
	return React.createElement(QueuePadPanel, {
		aboard = #pad.members,
		capacity = pad.capacity,
		secondsLeft = if endsAt ~= nil then math.max(0, math.ceil(endsAt - now)) else nil,
		departing = pad.departing,
		onDepart = props.onDepart,
	})
end

return QueuePadStatus
