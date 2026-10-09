--!strict
--[=[
	DebuggerServiceClient: owns the F4 debug overlay and its subscription to the server stream.

	Responsibilities:
	- Toggle the overlay on F4 (admin-gated locally for UX; the server re-checks `isAdmin` before it
	  streams anything, so a forged local bypass gets no data).
	- On open, send `SetSubscription(true)` so the server begins streaming; on close, send `false`.
	- Apply inbound `Snapshot` packets into the `serverSnapshot` atom the overlay reads reactively.
	- Render the React overlay into the shared `Debug` UI layer (see UILayers). The layer owns the
	  root — including the `ResetOnSpawn = false` handling that keeps it alive across respawns and slot
	  switches — so this service no longer news its own ScreenGui or holds a ReactRoblox root.

	@class DebuggerServiceClient
]=]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local React = require(ReplicatedStorage.Packages.React)
local Janitor = require(ReplicatedStorage.Packages.Janitor)
local Logger = require(ReplicatedStorage.Shared.Core.Logger)
local AdminRules = require(ReplicatedStorage.Shared.Features.Admin.Rules.AdminRules)
local DebuggerEvents = require(ReplicatedStorage.Shared.Features.Debugger.Net.DebuggerEvents)
local DebuggerStore = require(ReplicatedStorage.Client.Features.Debugger.State.DebuggerStore)
local DebuggerOverlay = require(ReplicatedStorage.Client.UI.React.Debugger.DebuggerOverlay)
local UIRoot = require(ReplicatedStorage.Client.UI.Layers.UIRoot)

local log = Logger.new("DebuggerServiceClient")

local TOGGLE_KEY = Enum.KeyCode.F4

-- Module-level state (mirrors StateSyncServiceClient's convention).
local janitor = Janitor.new()

-- Tells the server to start/stop streaming to us.
local function setSubscribed(subscribed: boolean)
	DebuggerEvents.packets.SetSubscription.send(subscribed)
end

export type DebuggerServiceClient = {
	dependencies: { string },
	-- Whether the overlay has been rendered into the Debug layer. The layer (UILayers) owns the
	-- actual root and its lifecycle; this is only bookkeeping for getState/idempotent start.
	_rendered: boolean,
	init: (self: DebuggerServiceClient) -> (),
	start: (self: DebuggerServiceClient) -> (),
	stop: (self: DebuggerServiceClient) -> (),
	getState: (self: DebuggerServiceClient) -> { [string]: any },
}

local DebuggerServiceClient: DebuggerServiceClient = {
	dependencies = {},
	_rendered = false,

	--[=[
		Subscribes to inbound snapshots and wires the F4 toggle.
		@param self DebuggerServiceClient -- The service instance
	]=]
	init = function(_self)
		-- Inbound snapshots → the reactive atom the overlay reads. Trust-boundary narrowing: the
		-- packet value is `unknown` (see DebuggerEvents), so shape-guard before the single documented
		-- cast, exactly as StateSyncServiceClient guards charm-sync payloads.
		janitor:Add(
			DebuggerEvents.packets.Snapshot.listen(function(payload)
				if type(payload) ~= "table" then
					log:warn("Ignoring non-table snapshot payload:", typeof(payload))
					return
				end
				DebuggerStore.serverSnapshot(payload :: DebuggerEvents.Snapshot)
			end),
			true
		)

		-- F4 toggles the overlay. `gameProcessed` is honored so pressing F4 while typing in the Cmdr
		-- console (or any focused TextBox) doesn't also open the debugger.
		janitor:Add(
			UserInputService.InputBegan:Connect(function(input: InputObject, gameProcessed: boolean)
				if gameProcessed then
					return
				end
				if input.KeyCode ~= TOGGLE_KEY then
					return
				end
				if not AdminRules.isAdmin(Players.LocalPlayer) then
					return
				end
				local nextVisible = not DebuggerStore.visible()
				DebuggerStore.visible(nextVisible)
				setSubscribed(nextVisible)
			end),
			"Disconnect"
		)
	end,

	--[=[
		Renders the overlay into the shared Debug layer. The overlay reads `visible` and renders
		nothing while closed, so it stays mounted across F4 toggles; UILayers keeps the layer root
		alive across respawns and slot switches. Idempotent — re-rendering the same element reconciles.
		@param self DebuggerServiceClient -- The service instance
	]=]
	start = function(self)
		local render = UIRoot.acquire("Debug")
		render(React.createElement(DebuggerOverlay))
		self._rendered = true
		log:debug("Debugger overlay rendered into the Debug layer")
	end,

	--[=[
		Unsubscribes and releases connections. Does NOT tear down the Debug layer root — the layer
		persists for the client session (owned by UILayers), and the overlay renders nothing while
		hidden, so there is nothing to unmount here.
		@param self DebuggerServiceClient -- The service instance
	]=]
	stop = function(self)
		-- Make sure the server stops streaming to us if we were open.
		if DebuggerStore.visible() then
			DebuggerStore.visible(false)
			setSubscribed(false)
		end

		janitor:Cleanup()
		self._rendered = false
	end,

	--[=[
		Returns the current state of the service for debugging (it appears in its own service panel).
		@return { [string]: any } -- Service state
	]=]
	getState = function(self)
		return {
			visible = DebuggerStore.visible(),
			rendered = self._rendered,
		}
	end,
}

return DebuggerServiceClient
