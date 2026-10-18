--!strict
--[=[
	QueueServiceClient: the queue on this client. Sends Depart now for the local player and registers the
	base's placeholder pad widget (QueuePadStatus: players aboard, countdown, a Depart-now button) during
	init. The widget is deliberately plain: a game's final pad UI is designed and approved in Figma first;
	the game then hides this one with `setDefaultWidget(false)` and reads QueueStore.

	Spec-exempt shell (ByteNet, HUD registration); the state is the specced QueueStore and
	QueueSnapshotUtils.

	@class QueueServiceClient
]=]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local QueueEvents = require(ReplicatedStorage.Shared.Features.Queue.Net.QueueEvents)
local QueueTypes = require(ReplicatedStorage.Shared.Features.Queue.Data.QueueTypes)
local QueueStore = require(ReplicatedStorage.Client.Features.Queue.State.QueueStore)
local HudRegistry = require(ReplicatedStorage.Client.UI.React.Screens.Hud.HudRegistry)
local QueuePadStatus = require(ReplicatedStorage.Client.UI.React.Screens.Hud.QueuePadStatus)

local HUD_KEY = "queuePad"
-- Under the toasts (1000), so a toast is never hidden behind the pad panel.
local HUD_ORDER = 900

local function departNow()
	QueueEvents.packets.Depart.send(true)
end

local function Widget(): React.ReactNode
	return React.createElement(QueuePadStatus, { onDepart = departNow })
end

export type QueueServiceClient = {
	dependencies: { string },
	init: (self: QueueServiceClient) -> (),
	departNow: (self: QueueServiceClient) -> (),
	setDefaultWidget: (self: QueueServiceClient, enabled: boolean) -> (),
	myPad: (self: QueueServiceClient) -> QueueTypes.PadSnapshot?,
	getState: (self: QueueServiceClient) -> { [string]: any },
}

local QueueServiceClient: QueueServiceClient = {
	dependencies = { "StateSyncServiceClient" },

	init = function(_self)
		if not HudRegistry.has(HUD_KEY) then
			HudRegistry.register(HUD_KEY, Widget, HUD_ORDER)
		end
	end,

	--[=[
		Asks the server to depart the local player's pad now (it checks they are aboard an open pad).
	]=]
	departNow = function(_self)
		departNow()
	end,

	--[=[
		Shows or hides the base's placeholder pad widget (a game with its own pad UI turns it off).
	]=]
	setDefaultWidget = function(_self, enabled)
		QueueStore.widgetEnabled(enabled)
	end,

	myPad = function(_self)
		local _, pad = QueueStore.padFor(Players.LocalPlayer.UserId)
		return pad
	end,

	-- Derived, not the raw synced state (the debugger's world view already shows the `queue` entry).
	getState = function(_self)
		return { widget = QueueStore.widgetEnabled() }
	end,
}

return QueueServiceClient
