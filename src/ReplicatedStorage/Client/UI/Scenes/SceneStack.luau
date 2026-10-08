--!strict
--[=[
	SceneStack: push / pop / replace over the reactive scene stack (UIStore.sceneStack).

	The old game declared a `ContextStack` and never used it, so closing was per-panel and there was no
	generic back. This is the stack, for real. It holds SCENE NAMES; order encodes suspension — the top
	is the active scene, everything below is suspended (still on the stack, behind). Escape pops one.

	Pure bookkeeping over the atom and the registry: it decides WHAT is open and in what order. It does
	NOT mount screens or apply suppression — those are DERIVED from this atom (a layer view renders the
	active scenes' screens; UIWorldSuppression applies the union), so this module stays fully specced
	with no Instance or React contact.

	@class SceneStack
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local UIStore = require(ReplicatedStorage.Client.UI.Scenes.UIStore)
local SceneRegistry = require(ReplicatedStorage.Client.UI.Scenes.SceneRegistry)

local sceneStack = UIStore.sceneStack

--[=[
	One screen to render, tagged with the scene that declared it (so a layer view can key it uniquely
	and know its stack position).
]=]
export type HostedScreen = {
	scene: string,
	screen: SceneRegistry.SceneScreen,
}

local SceneStack = {}

local function assertRegistered(name: string)
	if not SceneRegistry.has(name) then
		error(`SceneStack: "{name}" is not a registered scene (register it in SceneRegistry first)`, 3)
	end
end

--[=[
	Pushes a scene onto the stack, making it the active (top) scene and suspending the one below. A
	no-op if the scene is already on the stack — a scene is never stacked twice. Errors on an
	unregistered name so a typo fails loudly instead of opening nothing.
	@param name string -- A registered scene name
]=]
function SceneStack.push(name: string)
	assertRegistered(name)
	local stack = sceneStack()
	if table.find(stack, name) ~= nil then
		return -- already active; do not stack twice
	end
	local updated = table.clone(stack)
	table.insert(updated, name)
	sceneStack(updated)
end

--[=[
	Pops the top scene, revealing the one beneath. A no-op on an empty stack. This is what Escape does.
]=]
function SceneStack.pop()
	local stack = sceneStack()
	if #stack == 0 then
		return
	end
	local updated = table.clone(stack)
	table.remove(updated)
	sceneStack(updated)
end

--[=[
	Removes `name` from wherever it sits on the stack, active or suspended. A no-op if it is not on the
	stack at all. This is what a scene's own close button calls: `pop` closes whatever is on TOP, which
	is a different question and the wrong one for a control that belongs to one specific scene.
	@param name string -- a scene name; unregistered names simply are not on the stack
]=]
function SceneStack.remove(name: string)
	local stack = sceneStack()
	local index = table.find(stack, name)
	if index == nil then
		return
	end
	local updated = table.clone(stack)
	table.remove(updated, index)
	sceneStack(updated)
end

--[=[
	Replaces the top scene with `name` (pop the top, if any, then push). If `name` is already on the
	stack below, it is left in place rather than duplicated. Errors on an unregistered name.
	@param name string -- A registered scene name
]=]
function SceneStack.replace(name: string)
	assertRegistered(name)
	local stack = sceneStack()
	local updated = table.clone(stack)
	if #updated > 0 then
		table.remove(updated)
	end
	if table.find(updated, name) == nil then
		table.insert(updated, name)
	end
	sceneStack(updated)
end

--[=[
	The active (top) scene name, or nil when nothing is open.
	@return string?
]=]
function SceneStack.top(): string?
	local stack = sceneStack()
	return stack[#stack]
end

--[=[
	How many scenes are on the stack.
	@return number
]=]
function SceneStack.depth(): number
	return #sceneStack()
end

--[=[
	Whether a scene is anywhere on the stack (active or suspended).
	@param name string
	@return boolean
]=]
function SceneStack.isActive(name: string): boolean
	return table.find(sceneStack(), name) ~= nil
end

--[=[
	Whether a scene is on the stack but not the top (i.e. behind another scene).
	@param name string
	@return boolean
]=]
function SceneStack.isSuspended(name: string): boolean
	return SceneStack.isActive(name) and SceneStack.top() ~= name
end

--[=[
	Whether ANY open scene asks for the persistent HUD to be hidden. The HUD reads this to derive its
	own visibility — nothing reaches in and toggles the HUD.

	Checks the whole stack, not just the top: a scene that hides the HUD keeps hiding it while another
	scene sits on top of it (closing the top one shouldn't flash the HUD back).
	@return boolean
]=]
function SceneStack.hudHidden(): boolean
	return SceneStack.hudHiddenIn(sceneStack())
end

--[=[
	The same question against a GIVEN stack. React callers use this with the value they subscribed to
	(`useAtom(UIStore.sceneStack)`), so the render derives from the subscribed value rather than
	re-reading the atom — no chance of rendering a stale answer.
	@param stack { string } -- an ordered list of scene names
	@return boolean
]=]
function SceneStack.hudHiddenIn(stack: { string }): boolean
	-- The TOPMOST scene with a `hud` opinion decides; a scene with none (`hud == nil`) defers to the one
	-- below it. So the active screen controls the HUD when it cares, but a scene can also OVERRIDE a
	-- lower scene that hid it (e.g. an overlay declaring `hud = "visible"`). Nothing opining → visible.
	for index = #stack, 1, -1 do
		local def = SceneRegistry.get(stack[index])
		if def ~= nil and def.hud ~= nil then
			return def.hud == "hidden"
		end
	end
	return false
end

--[=[
	Collects the screens targeting `layer` across the whole stack, in stack order (bottom → top), each
	tagged with its scene. A layer view (SceneHost) renders this list — keyed by scene + screen key — so
	the top scene's screens draw last (on top) and React reconciles instead of rebuilding. Pure over the
	given stack + the registry; a name with no registered def, or with no screens on this layer, simply
	contributes nothing.
	@param stack { string } -- an ordered list of scene names
	@param layer string -- the layer to collect screens for
	@return { HostedScreen } -- ordered screens for the layer, each with its scene name
]=]
function SceneStack.screensFor(stack: { string }, layer: string): { HostedScreen }
	local result: { HostedScreen } = {}
	for index = 1, #stack do
		local def = SceneRegistry.get(stack[index])
		if def ~= nil then
			for _, screen in def.screens do
				if screen.layer == layer then
					table.insert(result, { scene = stack[index], screen = screen })
				end
			end
		end
	end
	return result
end

return SceneStack
