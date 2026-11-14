--!strict
--[=[
	UIStore: the client-side reactive state for the UI framework itself.

	Distinct from StateSyncClientStore (the server-mirrored DOMAIN state — inventory, stats, …). UIStore holds
	UI-only state that never round-trips to the server: the scene stack, and whether a scene has freed the
	mouse. Screens and the HUD read it via `useAtom` to DERIVE what is visible; nothing sets
	`.Visible`/`.Enabled` by hand (a CI gate enforces that). SceneStack is the only writer of the stack,
	UISuppression's mouse handler the only writer of `mouseFreed`.

	Adding UI-local state later (a panel's category/sort/search/tooltip target) means declaring another
	atom here — never a subscription-less singleton like the old game's five `*UIState` modules.

	@class UIStore
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Charm = require(ReplicatedStorage.Packages.Charm)

-- The scene stack: an ordered list of active scene NAMES, top of stack = last element. The single
-- source of truth for what UI is open. SceneStack mutates it (immutably — Charm needs a new table to
-- detect the change); the SceneRegistry resolves each name to its screens + suppression.
local sceneStack = Charm.atom({} :: { string }) -- type the atom's empty initial value

-- Whether a scene on the stack asked for the mouse (UISuppression's mouse handler engages it). SceneHost renders
-- the engine's Modal button while it is true, which is what frees a cursor locked by first person or shift lock.
local mouseFreed = Charm.atom(false)

-- Where the Inventory opens next (the reveal's "Add to wheel!" / "Use stickers!"): an employee's page on a page tab
-- with an item picked, or (no employee) the top-level "wheel" tab. The Inventory scene reads it once as it opens and
-- clears it, so a plain open still starts on the Crew tab.
export type InventoryAt = { employee: string?, tab: string, item: string? }
local noTarget: InventoryAt? = nil
local inventoryAt = Charm.atom(noTarget)

local UIStore = {
	sceneStack = sceneStack,
	mouseFreed = mouseFreed,
	inventoryAt = inventoryAt,
}

return UIStore
