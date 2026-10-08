--!strict
--[=[
	HudRoot: the single React root element of the `Hud` layer — the composition point for every
	persistent HUD widget. Today that's `VitalsHud` (health/rot/stamina, bottom) and `ExperienceHud`
	(XP/level, top); tomorrow a minimap, hotbar, buff tray, objective tracker slot in here the same way,
	without touching the widgets themselves.

	It is NOT a new layer or ScreenGui — the Hud layer already owns exactly one ReactRoblox root, and a
	root renders exactly one element. HudRoot is simply that one element, so it exists to (a) compose the
	widgets as siblings and (b) own the ONE hide gate for the whole HUD: it reads the scene stack and
	hides everything when a scene asks (the HUD never opens, closes, suppresses, or takes part in Escape
	— it only reads what's open). Each widget owns its own data; HudRoot owns only what's shared.

	@class HudRoot
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local ReactCharm = require(ReplicatedStorage.Packages.ReactCharm)
local UIStore = require(ReplicatedStorage.Client.UI.Scenes.UIStore)
local SceneStack = require(ReplicatedStorage.Client.UI.Scenes.SceneStack)
local FadeGroup = require(ReplicatedStorage.Client.UI.React.Primitives.FadeGroup)
local VitalsHud = require(ReplicatedStorage.Client.UI.React.Screens.Vitals.VitalsHud)
local ExperienceHud = require(ReplicatedStorage.Client.UI.React.Screens.Experience.ExperienceHud)

local e = React.createElement
local useAtom = ReactCharm.useAtom

local COMPONENT_NAME = "HudRoot"

--[=[
	@return React.ReactNode
]=]
local function HudRoot(): React.ReactNode
	local stack = useAtom(UIStore.sceneStack)
	-- Derived from the SUBSCRIBED stack value, not a fresh atom read, so this can never render stale.
	local hidden = SceneStack.hudHiddenIn(stack)

	-- selene: allow(roblox_incorrect_roact_usage)
	return e("Frame", {
		-- `Name` as a prop: this is the ROOT element of the Hud layer's React root, so there is no
		-- parent key to name it by (same case as DebuggerOverlay). A stable Explorer name helps when
		-- inspecting the live HUD.
		Name = COMPONENT_NAME,
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
	}, {
		-- The one hide gate for the whole HUD: FadeGroup fades the widgets in/out instead of snapping.
		fade = e(FadeGroup, { visible = not hidden }, {
			vitals = e(VitalsHud),
			experience = e(ExperienceHud),
		}),
	})
end

return HudRoot
