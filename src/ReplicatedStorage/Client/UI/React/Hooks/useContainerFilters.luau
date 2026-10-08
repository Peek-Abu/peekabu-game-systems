--!strict
--[=[
	useContainerFilters: the browsing state one container's grid needs — active category, search text,
	sort mode and direction — bundled so a screen with TWO containers does not declare seven pieces of
	state twice over.

	Each call is an independent set. That is the point rather than a detail: typing in the bank's search
	box must not refilter the bag beside it, and the authored bank agrees — it builds a separate UI state
	object per side (`InventoryBankUIState` and `BankUIState`) rather than sharing one.

	`setCategory` clears any equip-slot narrowing, because picking a tab means "the whole category", not
	"the one slot I last clicked on the paperdoll". `pickSort` APPLIES `InventoryViewModel.nextSort`
	rather than restating it: the rule is pure and specced there, and it was written out in two components
	before this hook existed.

	@class useContainerFilters
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local InventoryViewModel = require(ReplicatedStorage.Client.UI.React.Screens.Containers.InventoryViewModel)

local NO_SLOT = "" -- equipSlot sentinel; avoids a nilable-state annotation (see the panels)

--[=[
	One container's filter state, ready to hand to a `ContainerPanel`.
	@interface ContainerFilters
	.category string
	.setCategory (string) -> () -- also clears the equip-slot narrowing
	.equipSlot string? -- nil unless narrowed to a single equip slot
	.focusSlot (category: string, slotId: string?) -> () -- point the grid at one slot
	.search string
	.setSearch (string) -> ()
	.sort InventoryViewModel.SortMode
	.ascending boolean
	.pickSort (InventoryViewModel.SortMode) -> ()
]=]
export type ContainerFilters = {
	category: string,
	setCategory: (string) -> (),
	equipSlot: string?,
	focusSlot: (category: string, slotId: string?) -> (),
	search: string,
	setSearch: (string) -> (),
	sort: InventoryViewModel.SortMode,
	ascending: boolean,
	pickSort: (InventoryViewModel.SortMode) -> (),
}

--[=[
	@param defaultCategory string -- the tab a freshly opened container starts on
	@param defaultSort InventoryViewModel.SortMode
	@return ContainerFilters
]=]
local function useContainerFilters(defaultCategory: string, defaultSort: InventoryViewModel.SortMode): ContainerFilters
	local category, setCategoryState = React.useState(defaultCategory)
	local equipSlot, setEquipSlot = React.useState(NO_SLOT)
	local search, setSearch = React.useState("")
	local sort, setSort = React.useState(defaultSort)
	local ascending, setAscending = React.useState(true)

	local filters: ContainerFilters = {
		category = category,
		setCategory = function(kind: string)
			setCategoryState(kind)
			setEquipSlot(NO_SLOT) -- a tab means "the whole category", not one slot
		end,
		equipSlot = if equipSlot ~= NO_SLOT then equipSlot else nil,
		focusSlot = function(kind: string, slotId: string?)
			setCategoryState(kind)
			setEquipSlot(slotId or NO_SLOT)
		end,
		search = search,
		setSearch = setSearch,
		sort = sort,
		ascending = ascending,
		pickSort = function(picked: InventoryViewModel.SortMode)
			-- The rule itself is pure and specced in InventoryViewModel.nextSort; this only applies it.
			-- Annotated: the SortMode union widens to `string` off a multiple return, and the setter's
			-- own union then rejects it (the same widening the currency singletons hit).
			local nextMode: InventoryViewModel.SortMode, nextAscending: boolean =
				InventoryViewModel.nextSort(sort, ascending, picked)
			setSort(nextMode)
			setAscending(nextAscending)
		end,
	}
	return filters
end

return useContainerFilters
