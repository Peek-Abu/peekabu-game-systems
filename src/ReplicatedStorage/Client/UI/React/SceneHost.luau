--!strict
--[=[
	SceneHost: the layer view that turns the scene stack into mounted screens. One SceneHost is the React
	root of a scene-hosting layer (the `Panel` layer this phase); it subscribes to the scene stack and
	renders every screen the active scenes declare for ITS layer, so a scene "opens" simply by being on
	the stack.

	This is the mechanism the whole panel class needs: `SceneStack` decides WHAT is open (pure), and this
	renders it. The screen list comes from the specced `SceneStack.screensFor`, keyed by scene + screen
	key so React RECONCILES across stack changes instead of the old game's destroy-all-and-rebuild. Stack
	order becomes ZIndex — the top scene's screens draw over suspended ones beneath (which stay mounted,
	preserving their state).

	Presentational shell over the specced selection; exempt from spec-first (needs a renderer). Only the
	`Panel` layer is hosted for now — Wheel/Overlay get a SceneHost when a scene actually targets them
	(no consumer, no mechanism).

	@class SceneHost
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local ReactCharm = require(ReplicatedStorage.Packages.ReactCharm)
local UIStore = require(ReplicatedStorage.Client.UI.Scenes.UIStore)
local SceneStack = require(ReplicatedStorage.Client.UI.Scenes.SceneStack)
local UIRenderCounters = require(ReplicatedStorage.Client.UI.UIRenderCounters)

local e = React.createElement
local useAtom = ReactCharm.useAtom

local COMPONENT_NAME = "SceneHost"

-- The suspended-scene input blocker sits above its OWN screen and nothing else: the layer sets
-- `ZIndexBehavior.Sibling` (UILayerHost), so this only ever competes with the one screen it is wrapped
-- with, never with the scenes stacked above. Max ZIndex so it stays on top of any ladder a screen
-- declares internally without this host having to know what that ladder is.
local BLOCKER_ZINDEX = 2147483647

export type SceneHostProps = {
	layer: string,
}

--[=[
	@param props SceneHostProps
	@return React.ReactNode
]=]
local function SceneHost(props: SceneHostProps): React.ReactNode
	local stack = useAtom(UIStore.sceneStack)

	-- Tally renders (no dependency array) so the F4 UI tab shows the host reacting to the stack.
	React.useEffect(function()
		UIRenderCounters.tick(COMPONENT_NAME)
	end)

	-- Derived from the SUBSCRIBED stack, so it can never render a stale set of screens.
	local hosted = SceneStack.screensFor(stack, props.layer)
	-- The ACTIVE scene, from the same subscribed value the screens are derived from. Everything below it
	-- is suspended, and a suspended scene must be inert: stacking is ZIndex only, and ZIndex does not
	-- gate input in Roblox — a plain Frame or Label never sinks a click, so without a blocker every
	-- button on a buried screen stays live under the one on top (press B then I, and the Bank's DEPOSIT
	-- ALL is still clickable through any gap in the Inventory).
	local topScene = stack[#stack]
	local children: { [string]: React.ReactNode } = {}
	for index, entry in hosted do
		-- Each screen fills the layer, keyed by scene+screen so React reconciles; ZIndex = stack position
		-- so the top scene draws over suspended ones (which stay mounted, keeping their state).
		local wrapped: { [string]: React.ReactNode } = {
			screen = e(entry.screen.component),
		}
		if entry.scene ~= topScene then
			-- Visually preserved, input-inert: an `Active` Frame sinks input rather than passing it
			-- through, and carries no visual of its own (fully transparent), so the suspended screen still
			-- shows through beneath the active one exactly as before.
			wrapped.suspendedBlocker = e("Frame", {
				Active = true,
				Size = UDim2.fromScale(1, 1),
				BackgroundTransparency = 1,
				ZIndex = BLOCKER_ZINDEX,
			})
		end
		children[`{entry.scene}:{entry.screen.key}`] = e("Frame", {
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			ZIndex = index,
		}, wrapped)
	end

	-- selene: allow(roblox_incorrect_roact_usage)
	return e("Frame", {
		-- `Name` as a prop: this is the ROOT element of the layer's React root (same case as HudRoot).
		Name = COMPONENT_NAME,
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
	}, children)
end

return SceneHost
