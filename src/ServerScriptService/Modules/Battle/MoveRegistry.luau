--!strict
--[=[
	Move Registry - Central registry for all moves in the game
	
	Automatically loads all move modules from the Moves/ folder and provides
	a simple interface to get moves by name.
	
	Usage:
		local MoveRegistry = require(...)
		local move = MoveRegistry.getMove("Kamehameha")
		local allMoves = MoveRegistry.getAllMoveNames()
	
	@class MoveRegistry
]=]

local MoveRegistry = {}

-- Internal registry mapping move names to their getter functions
local MOVE_REGISTRY: { [string]: () -> any } = {}

-- ══════════════════════════════════════════════════════════════════════════════
-- PUBLIC API
-- ══════════════════════════════════════════════════════════════════════════════

--- Get a move by name
function MoveRegistry.getMove(moveName: string): any?
	local getter = MOVE_REGISTRY[moveName]
	if getter then
		return getter()
	end
	return nil
end

--- Get all registered move names
function MoveRegistry.getAllMoveNames(): {string}
	local names = {}
	for name in pairs(MOVE_REGISTRY) do
		table.insert(names, name)
	end
	table.sort(names)
	return names
end

--- Check if a move exists
function MoveRegistry.hasMove(moveName: string): boolean
	return MOVE_REGISTRY[moveName] ~= nil
end

--- Get the total number of registered moves
function MoveRegistry.getMoveCount(): number
	local count = 0
	for _ in pairs(MOVE_REGISTRY) do
		count = count + 1
	end
	return count
end

-- ══════════════════════════════════════════════════════════════════════════════
-- DYNAMIC MOVE LOADING
-- ══════════════════════════════════════════════════════════════════════════════

-- Recursively load all move modules from a folder
local function loadMovesFromFolder(folder: Instance)
	for _, child in folder:GetChildren() do
		if child:IsA("ModuleScript") then
			local success, moveModule = pcall(require, child)
			if success and type(moveModule) == "table" then
				for name, func in pairs(moveModule) do
					if type(func) == "function" and name:match("^get") then
						local moveName = name:gsub("^get", "")
						MOVE_REGISTRY[moveName] = func
					end
				end
			else
				warn(`[MoveRegistry] Failed to load move module: {child:GetFullName()}`)
			end
		elseif child:IsA("Folder") then
			loadMovesFromFolder(child)
		end
	end
end

-- Load all moves from the Moves folder
local movesFolder = script.Parent:FindFirstChild("Moves")
if movesFolder then
	loadMovesFromFolder(movesFolder)
	print(`[MoveRegistry] Loaded {MoveRegistry.getMoveCount()} moves`)
else
	warn("[MoveRegistry] Moves folder not found!")
end

return MoveRegistry
