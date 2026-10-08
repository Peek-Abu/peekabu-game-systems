--!strict
--[=[
	UIServiceClient: the single lifecycle owner for the client UI framework.

	ONE service, not three. It does the three things the framework needs a lifecycle for, all of which
	are "UI bootstrapping" and none of which justified its own ServiceController entry:

	1. **Suppression follows the stack** — subscribes to `UIStore.sceneStack` and reconciles
	   `UISuppression` on every change (so opening a scene frees the mouse, closing it restores).
	2. **Scene keys** — Escape (and gamepad B) pops the top scene; a key a scene declared as its
	   `toggleKey` (SceneRegistry) opens or closes that scene. They gate on a focused TextBox rather than
	   `gameProcessed`, because the engine marks Escape processed for its own menu (and so a search box
	   keeps its keystrokes). A future Input system can take these over as keymaps-as-data.
	3. **Mounts the always-on roots** at start — the HUD on the `Hud` layer, the `SceneHost` on `Panel`.

	The shared state it drives lives elsewhere and is required directly (UISuppression, SceneStack,
	UIRoot) — this service owns only the lifecycle, the same split as StateSyncClientStore/StateSyncServiceClient.

	@class UIServiceClient
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local React = require(ReplicatedStorage.Packages.React)
local Charm = require(ReplicatedStorage.Packages.Charm)
local Janitor = require(ReplicatedStorage.Packages.Janitor)
local Logger = require(ReplicatedStorage.Shared.Core.Logger)
local UIStore = require(ReplicatedStorage.Client.UI.Scenes.UIStore)
local SceneStack = require(ReplicatedStorage.Client.UI.Scenes.SceneStack)
local UISuppression = require(ReplicatedStorage.Client.UI.Suppression.UISuppression)
local UIRoot = require(ReplicatedStorage.Client.UI.Layers.UIRoot)
local HudRoot = require(ReplicatedStorage.Client.UI.React.Screens.Hud.HudRoot)
local SceneHost = require(ReplicatedStorage.Client.UI.React.SceneHost)
local SceneRegistry = require(ReplicatedStorage.Client.UI.Scenes.SceneRegistry)

local log = Logger.new("UIServiceClient")

-- Module-level (mirrors the other client shells): subscriptions live here, released in stop().
local janitor = Janitor.new()

--[=[
	Pushes a scene, or closes it if it is already open.

	Keyed off `isActive`, not off `top`: `push` no-ops for a scene already anywhere on the stack, so
	testing only the top made the key DEAD for a scene that is open but suspended (open A, then B, then
	press A's key — the third press fell into the push branch and silently did nothing). Toggling is a question about
	the scene, so it closes the scene itself rather than popping whatever happens to be on top.
	@param scene string -- the registered scene name
]=]
local function toggleScene(scene: string)
	if SceneStack.isActive(scene) then
		SceneStack.remove(scene)
	else
		SceneStack.push(scene)
	end
end

export type UIServiceClient = {
	dependencies: { string },
	_hudMounted: boolean,
	init: (self: UIServiceClient) -> (),
	start: (self: UIServiceClient) -> (),
	stop: (self: UIServiceClient) -> (),
	getState: (self: UIServiceClient) -> { [string]: any },
}

local UIServiceClient: UIServiceClient = {
	dependencies = {},
	_hudMounted = false,

	--[=[
		Wires suppression-follows-the-stack and the scene keys.
		@param self UIServiceClient -- The service instance
	]=]
	init = function(_self)
		-- Reconcile the initial stack (usually empty) so a scene pushed before boot is honored.
		UISuppression.reconcile(UIStore.sceneStack())
		janitor:Add(
			Charm.subscribe(UIStore.sceneStack, function()
				UISuppression.reconcile(UIStore.sceneStack())
			end),
			true
		)

		janitor:Add(
			UserInputService.InputBegan:Connect(function(input: InputObject)
				-- Don't steal keys from a focused text field (the Cmdr console, a search box).
				if UserInputService:GetFocusedTextBox() ~= nil then
					return
				end
				local key = input.KeyCode
				if key == Enum.KeyCode.Escape or key == Enum.KeyCode.ButtonB then
					SceneStack.pop()
					return
				end
				local scene = SceneRegistry.sceneForKey(key)
				if scene ~= nil then
					toggleScene(scene)
				end
			end),
			"Disconnect"
		)
	end,

	--[=[
		Mounts the framework's two always-on roots: the persistent HUD on the `Hud` layer, and the
		`SceneHost` on the `Panel` layer (which renders whatever panel scenes the stack opens). Each layer
		owns its root and respawn survival; the HUD derives its own visibility, and the SceneHost renders
		nothing until a scene is pushed.
		@param self UIServiceClient -- The service instance
	]=]
	start = function(self)
		local hudRender = UIRoot.acquire("Hud")
		hudRender(React.createElement(HudRoot))
		self._hudMounted = true

		local panelRender = UIRoot.acquire("Panel")
		panelRender(React.createElement(SceneHost, { layer = "Panel" }))

		log:debug("HUD and Panel SceneHost mounted")
	end,

	--[=[
		Releases the subscriptions AND the suppression they were driving. The layer roots persist for the
		client session (owned by UILayers), but suppression does not: dropping the subscription without
		reconciling to an empty stack left `UserInputService.ModalEnabled` engaged with no code path
		remaining to release it, which is exactly the leak-across-a-restart ServiceController's contract
		forbids. Reconciling FIRST, while the handlers are still reachable, disengages every handler the
		open scenes had engaged.
		@param self UIServiceClient -- The service instance
	]=]
	stop = function(self)
		UISuppression.reconcile({})
		janitor:Cleanup()
		self._hudMounted = false
	end,

	--[=[
		Surfaces framework state for the debugger's service panel.
		@return { [string]: any } -- Service state
	]=]
	getState = function(self)
		return {
			hudMounted = self._hudMounted,
			sceneDepth = SceneStack.depth(),
			suppression = UISuppression.counts(),
		}
	end,
}

return UIServiceClient
