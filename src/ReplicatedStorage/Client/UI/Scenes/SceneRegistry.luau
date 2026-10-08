--!strict
--[=[
	SceneRegistry: the declarative catalog of scenes.

	A SCENE is the unit the stack operates on — NOT a screen. It names which screens it shows and in
	which layers, and what it suppresses in the world. This is why the stack holds scenes: `Bank` is one
	scene showing two co-visible container panels, which a flat screen stack cannot express. It also
	subsumes the old game's four hardcoded `ExclusiveSets` groups — mutual exclusion becomes a
	consequence of a scene being one entry on one stack, not a second table that must agree with another.

	Scenes register into this global singleton at load (like the old UIRegistry, but React renders them
	rather than a hand-rolled `Evaluate()`). Real scenes arrive with the screens in later tasks; this
	phase's harness drives registered scenes by name.

	@class SceneRegistry
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local UILayerConstants = require(ReplicatedStorage.Client.UI.Layers.UILayerConstants)

type LayerName = UILayerConstants.LayerName

--[=[
	A screen component. Function components take no props here — screens read reactive state (atoms)
	internally, exactly like DebuggerOverlay — so a scene need only say WHICH component goes WHERE.
]=]
export type ScreenComponent = () -> React.ReactNode

--[=[
	One screen a scene shows: the layer it renders into and its React key within that layer.
]=]
export type SceneScreen = {
	layer: LayerName,
	key: string,
	component: ScreenComponent,
}

--[=[
	What a scene asks the world to suppress while it is on the stack. DATA only — UIWorldSuppression
	applies the UNION across the whole stack, refcounted. Only `mouse` is handled this phase (freeing
	the pointer is UI's own job); every other field is a declared SEAM — the scene may ask for it, but
	the mechanism belongs to a specialist system that registers a handler later (logged once until
	then, never silently no-oped). This is the slottability contract: UI declares, specialists supply.
]=]
export type SuppressionRecord = {
	mouse: boolean?, -- free the pointer for UI (ModalEnabled) — HANDLED this phase
	blur: boolean?, -- a post-processing effect — seam; a future VFX/post-fx system handles it
	movement: boolean?, -- freeze character movement — seam; the Input phase handles it
	cameraState: string?, -- push a camera FSM state — seam; the Camera phase handles it
	characterRotation: "server"?, -- hand rotation authority to the server — seam; the Camera phase
}

--[=[
	A scene definition: a name, the screens it shows, its optional suppression record, and what it
	wants of the persistent HUD.

	`hud` is how a scene hides the always-on HUD (health bar etc.) while it's open — most full panels
	will. It is a DECLARATION, not a command: the HUD reads the stack and derives its own visibility
	(nothing reaches in and toggles it). Defaults to visible when omitted. The HUD is deliberately NOT
	a scene — it never opens, closes, suppresses, or participates in Escape, so putting it on the stack
	would mean a permanent "never pop the bottom" special-case.
]=]
export type SceneDef = {
	name: string,
	screens: { SceneScreen },
	suppress: SuppressionRecord?,
	hud: ("visible" | "hidden")?,
}

local registry: { [string]: SceneDef } = {}

local SceneRegistry = {}

--[=[
	Registers a scene. Errors on a duplicate name — two scenes answering to one name is a bug, not a
	last-write-wins situation (a failure mode the old game's duplicated exclusion tables actually had).
	@param def SceneDef -- The scene definition
]=]
function SceneRegistry.register(def: SceneDef)
	if registry[def.name] ~= nil then
		error(`SceneRegistry: scene "{def.name}" is already registered`, 2)
	end
	registry[def.name] = def
end

--[=[
	Returns a scene definition by name, or nil if unregistered.
	@param name string
	@return SceneDef?
]=]
function SceneRegistry.get(name: string): SceneDef?
	return registry[name]
end

--[=[
	Whether a scene is registered.
	@param name string
	@return boolean
]=]
function SceneRegistry.has(name: string): boolean
	return registry[name] ~= nil
end

return SceneRegistry
