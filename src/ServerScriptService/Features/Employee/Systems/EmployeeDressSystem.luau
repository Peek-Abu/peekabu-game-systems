--!strict
--[=[
	EmployeeDressSystem: dresses a spawned employee character for EmployeeServiceServer. The player's skin goes on
	first (EmployeeSkinSystem; who wears what is the player's Cosmetic loadout), then the company uniform over it
	(EmployeeGearSystem: the employee's `uniform`), whose lanyard and ID card show the player's name and rank. It also
	names the idle and the vacuum the player's look picks on the character, which their owners read (Animate rebinds
	its idle, VacuumServiceServer swaps the pack), so neither needs a rebuild.

	What it dressed is counted in a Tally the service owns (its debugger snapshot and the loadout-swap check read it).

	@class EmployeeDressSystem
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Logger = require(ReplicatedStorage.Shared.Core.Logger)
local CosmeticRegistry = require(ReplicatedStorage.Shared.Features.Cosmetic.Data.CosmeticRegistry)
local VacuumConstants = require(ReplicatedStorage.Shared.Features.Vacuum.Data.VacuumConstants)
local EmployeeConstants = require(ReplicatedStorage.Shared.Features.Employee.Data.EmployeeConstants)
local EmployeeRegistry = require(ReplicatedStorage.Shared.Features.Employee.Data.EmployeeRegistry)
local EmployeeSkinRules = require(ReplicatedStorage.Shared.Features.Employee.Rules.EmployeeSkinRules)
local RankFormulas = require(ReplicatedStorage.Shared.Features.Rank.Utils.RankFormulas)
local CosmeticServiceServer = require(ServerScriptService.Features.Cosmetic.CosmeticServiceServer)
local EmployeeGearSystem = require(ReplicatedStorage.Shared.Features.Employee.Systems.EmployeeGearSystem)
local EmployeeSkinSystem = require(ReplicatedStorage.Shared.Features.Employee.Systems.EmployeeSkinSystem)
local RankServiceServer = require(ServerScriptService.Features.Rank.RankServiceServer)

-- Kept under the service's name so log output is unchanged by the split.
local log = Logger.new("EmployeeServiceServer")

--[=[
	@interface Tally
	.skinned number -- characters dressed in a skin that changed something
	.uniformed number -- characters given a uniform piece
	.skinOf { [number]: string } -- the last skin each player was given
	.worn { [number]: EmployeeSkinRules.Worn } -- what each player's current character was built as (employee, skin
	key and colour style), to tell whether a loadout change needs a new character
]=]
export type Tally = {
	skinned: number,
	uniformed: number,
	skinOf: { [number]: string },
	worn: { [number]: EmployeeSkinRules.Worn },
}

local EmployeeDressSystem = {}

function EmployeeDressSystem.newTally(): Tally
	return { skinned = 0, uniformed = 0, skinOf = {}, worn = {} }
end

local function resolve(path: { string }): Instance?
	local current: Instance? = ReplicatedStorage
	for _, name in path do
		if current == nil then
			return nil
		end
		current = current:FindFirstChild(name)
	end
	return current
end

local function accessorySource(): Instance?
	return resolve(EmployeeConstants.ACCESSORIES_PATH)
end

-- The art-owned skinned outfits a skin can name (EmployeeOutfitSystem).
local function outfitSource(): Instance?
	return resolve(EmployeeConstants.OUTFITS_PATH)
end

-- The player's general account rank level (1..7; level 1 until Rank has loaded it).
function EmployeeDressSystem.rankLevelOf(userId: number)
	local progress = RankServiceServer:progressOf(userId)
	return if progress ~= nil then progress.level else RankFormulas.progress(0).level
end

-- The player's lanyard: their name and their published rank (level 1 until Rank has loaded it).
function EmployeeDressSystem.badgeOf(player: Player): EmployeeGearSystem.Badge
	local level = EmployeeDressSystem.rankLevelOf(player.UserId)
	return {
		holder = player.DisplayName,
		title = level.name,
		band = `RANK: {string.upper(level.name)}`,
		colour = level.lanyard,
	}
end

-- The skin key (EmployeeRegistry `skins`) the player's loadout puts on `employee`: the Cosmetic skin id after the
-- dot (Pippa.OwnerSpecial -> OwnerSpecial); nil before the loadout loads. A skin without art yet falls back to the
-- Default (EmployeeSkinRules.select).
function EmployeeDressSystem.skinKeyOf(userId: number, employee: string): string?
	local look = CosmeticServiceServer:lookOf(userId, employee)
	if look == nil then
		return nil
	end
	return string.match(look.skin, "^[^%.]+%.(.+)$")
end

-- The chosen idle item's key (after the dot) for `employee`: only a non-free idle that fits the worn skin
-- (CosmeticRules.lookFor already drops one that does not); nil = the skin's own idle.
local function idleKeyOf(userId: number, employee: string): string?
	local look = CosmeticServiceServer:lookOf(userId, employee)
	local item = if look ~= nil then CosmeticRegistry.get(look.idle) else nil
	if item == nil or item.source == "default" then
		return nil
	end
	return CosmeticRegistry.keyOf(item.id)
end

-- Names the idle the player's look picks on their character (Animate rebinds its idle when it changes): no rebuild.
function EmployeeDressSystem.markIdle(userId: number, character: Model, employee: string)
	local key = idleKeyOf(userId, employee)
	if character:GetAttribute(EmployeeConstants.IDLE_ATTRIBUTE) ~= key then
		character:SetAttribute(EmployeeConstants.IDLE_ATTRIBUTE, key)
	end
end

-- The colour style the player's loadout picks for `skin` on `employee`, clamped to one the skin has (1 before the
-- loadout loads, or for a skin with no styles).
function EmployeeDressSystem.styleOf(userId: number, employee: string, skin: EmployeeRegistry.SkinDef): number
	local look = CosmeticServiceServer:lookOf(userId, employee)
	return EmployeeSkinRules.styleIndex(skin, if look ~= nil then look.style else nil)
end

-- Names the vacuum the player's outfit wants on their character (VacuumServiceServer wears it, and swaps the pack
-- when it changes); nothing before the loadout loads (Standard Issue).
function EmployeeDressSystem.markVacuum(userId: number, character: Model)
	local outfit = CosmeticServiceServer:outfitOf(userId)
	if outfit ~= nil then
		local key = CosmeticRegistry.keyOf(outfit.vacuum)
		if character:GetAttribute(VacuumConstants.SKIN_ATTRIBUTE) ~= key then
			character:SetAttribute(VacuumConstants.SKIN_ATTRIBUTE, key)
		end
	end
end

-- Dresses a spawned employee character in its player's skin, then the uniform over it (server-side, so it
-- replicates). The skin goes first: its palette is for the body's MeshParts, never the uniform's.
function EmployeeDressSystem.dress(tally: Tally, player: Player, character: Model)
	local name = character:GetAttribute(EmployeeConstants.NAME_ATTRIBUTE)
	local def = if type(name) == "string" then EmployeeRegistry.get(name) else nil
	if def == nil then
		return
	end
	local skin = EmployeeSkinRules.select(def, EmployeeDressSystem.skinKeyOf(player.UserId, def.name))
	if skin == nil then
		log:warn(`{def.name} has no default skin {def.defaultSkin}`)
		return
	end
	local style = EmployeeDressSystem.styleOf(player.UserId, def.name, skin)
	tally.skinOf[player.UserId] = skin.name
	tally.worn[player.UserId] = { employee = def.name, skin = skin.name, style = style }
	-- The skin the outfit asks for (its art may still be the Default's): a preview of the outfit matches on it.
	character:SetAttribute(
		EmployeeConstants.SKIN_ATTRIBUTE,
		EmployeeDressSystem.skinKeyOf(player.UserId, def.name) or skin.name
	)
	character:SetAttribute(EmployeeConstants.STYLE_ATTRIBUTE, style)
	EmployeeDressSystem.markIdle(player.UserId, character, def.name)
	character:SetAttribute(EmployeeConstants.RANK_ATTRIBUTE, EmployeeDressSystem.rankLevelOf(player.UserId).level)
	for _, legacyName in { "PippaVest", "PippaLanyard" } do
		local legacy = character:FindFirstChild(legacyName)
		if legacy ~= nil then
			legacy:Destroy()
		end
	end
	local result = EmployeeSkinSystem.apply(character, skin, accessorySource(), style, outfitSource())
	if skin.outfit ~= nil and not result.outfit then
		log:warn(`{def.name} skin {skin.name}: outfit {skin.outfit} could not be fitted`)
	end
	if result.textured > 0 or result.facesSwapped or result.accessories > 0 or result.outfit then
		tally.skinned += 1
	end
	if EmployeeGearSystem.wear(character, def.uniform, accessorySource()) > 0 then
		tally.uniformed += 1
		EmployeeGearSystem.badge(character, EmployeeDressSystem.badgeOf(player))
	end
end

-- Dresses every character `player` spawns from now on, and the one they have now; one CharacterAdded watch per player
-- in `watches` (the caller disconnects it when they leave).
function EmployeeDressSystem.watch(tally: Tally, watches: { [Player]: RBXScriptConnection }, player: Player)
	local watching: RBXScriptConnection? = watches[player]
	if watching ~= nil then
		return
	end
	watches[player] = player.CharacterAdded:Connect(function(character: Model)
		EmployeeDressSystem.dress(tally, player, character)
	end)
	local character = player.Character
	if character ~= nil then
		EmployeeDressSystem.dress(tally, player, character)
	end
end

return EmployeeDressSystem
