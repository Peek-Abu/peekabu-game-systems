--!strict
--[=[
	DebuggerServiceClient: owns the F4 debug overlay and its subscription to the server stream.

	Responsibilities:
	- Toggle the overlay on F4 (admin-gated locally for UX; the server re-checks `isAdmin` before it
	  streams anything, so a forged local bypass gets no data).
	- On open, send `SetSubscription(true)` so the server begins streaming; on close, send `false`.
	- Apply inbound `Snapshot` packets into the `serverSnapshot` atom the overlay reads reactively.
	- Mount/unmount the React overlay via the framework lifecycle (a `ReactRoblox.createRoot` into a
	  private Folder under PlayerGui, torn down in `stop()`).

	@class DebuggerServiceClient
]=]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local React = require(ReplicatedStorage.Packages.React)
local ReactRoblox = require(ReplicatedStorage.Packages.ReactRoblox)
local Janitor = require(ReplicatedStorage.Packages.Janitor)
local Logger = require(ReplicatedStorage.Shared.Modules.Logger)
local Admin = require(ReplicatedStorage.Shared.Modules.Admin)
local DebuggerEvents = require(ReplicatedStorage.Shared.Events.DebuggerEvents)
local DebuggerState = require(ReplicatedStorage.Client.State.DebuggerState)
local DebuggerOverlay = require(ReplicatedStorage.Client.UI.React.Debugger.DebuggerOverlay)

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
	_root: ReactRoblox.RootType?,
	-- The host Folder React renders into. Tracked so stop() can destroy it — unmount() tears down
	-- the React tree but leaves this Instance parented under PlayerGui, so an untracked container
	-- would leak (a fresh one accumulates on every start()).
	_container: Instance?,
	init: (self: DebuggerServiceClient) -> (),
	start: (self: DebuggerServiceClient) -> (),
	stop: (self: DebuggerServiceClient) -> (),
	getState: (self: DebuggerServiceClient) -> { [string]: any },
}

local DebuggerServiceClient: DebuggerServiceClient = {
	dependencies = {},
	_root = nil,
	_container = nil,

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
				DebuggerState.serverSnapshot(payload :: DebuggerEvents.Snapshot)
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
				if not Admin.isAdmin(Players.LocalPlayer) then
					return
				end
				local nextVisible = not DebuggerState.visible()
				DebuggerState.visible(nextVisible)
				setSubscribed(nextVisible)
			end),
			"Disconnect"
		)
	end,

	--[=[
		Mounts the React overlay into PlayerGui. It reads `visible` and renders nothing while closed.
		@param self DebuggerServiceClient -- The service instance
	]=]
	start = function(self)
		local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")

		local container = Instance.new("Folder") -- React's private root, sibling of the HUD/Cmdr roots
		container.Name = "ReactDebuggerRoot"
		container.Parent = playerGui

		local root = ReactRoblox.createRoot(container)
		root:render(React.createElement(DebuggerOverlay))
		self._root = root
		self._container = container
		log:debug("Debugger overlay mounted")
	end,

	--[=[
		Unsubscribes, tears down the React tree, and releases connections.
		@param self DebuggerServiceClient -- The service instance
	]=]
	stop = function(self)
		-- Make sure the server stops streaming to us if we were open.
		if DebuggerState.visible() then
			DebuggerState.visible(false)
			setSubscribed(false)
		end

		janitor:Cleanup()

		if self._root then
			self._root:unmount()
			self._root = nil
		end

		-- Destroy the host Folder AFTER unmounting the React tree (unmount doesn't remove it), so a
		-- stop()/start() cycle doesn't orphan an empty ReactDebuggerRoot under PlayerGui.
		if self._container then
			self._container:Destroy()
			self._container = nil
		end
	end,

	--[=[
		Returns the current state of the service for debugging (it appears in its own service panel).
		@return { [string]: any } -- Service state
	]=]
	getState = function(self)
		return {
			visible = DebuggerState.visible(),
			mounted = self._root ~= nil,
		}
	end,
}

return DebuggerServiceClient
