--!strict
--[=[
	CharacterSelectionServiceServer - Tracks each player's selected character.
	
	When a player selects a character, they are morphed into that character's
	model for overworld exploration. This selection is also used when battles
	start (proximity or command-based).
	
	@class CharacterSelectionServiceServer
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Players = game:GetService("Players")

local CharacterDefinitions = require(ServerScriptService.Modules.Battle.Characters.CharacterDefinitions)
local CharacterModelManager = require(ServerScriptService.Modules.Battle.CharacterModelManager)
local CharacterEvents = require(ReplicatedStorage.Shared.Events.CharacterEvents)
local Logger = require(ReplicatedStorage.Shared.Modules.Logger)
local HttpService = game:GetService("HttpService")
local RequestHandler = require(ServerScriptService.Modules.RequestHandler)

local log = Logger.new("CharacterSelectionServiceServer")

local CharacterSelectionServiceServer = {}
CharacterSelectionServiceServer.dependencies = {} :: { string }

-- Player UserId → selected character ID
local selectedCharacters: { [number]: string } = {}

-- ══════════════════════════════════════════════════════════════════════════════
-- PUBLIC API
-- ══════════════════════════════════════════════════════════════════════════════

--- Get the character ID a player has selected (nil if none).
function CharacterSelectionServiceServer.getSelectedCharacter(userId: number): string?
	return selectedCharacters[userId]
end

--- Select a character for a player. Morphs their avatar into the character model.
--- Returns true on success.
function CharacterSelectionServiceServer.selectCharacter(player: Player, characterId: string): (boolean, string?)
	characterId = string.upper(characterId)

	local charDef = CharacterDefinitions.getCharacterById(characterId)
	if not charDef then
		local allIds = CharacterDefinitions.getAllCharacterIds()
		return false, `Unknown character "{characterId}". Available: {table.concat(allIds, ", ")}`
	end

	selectedCharacters[player.UserId] = characterId

	-- Morph the player's avatar into this character
	local success = CharacterModelManager.morphPlayer(player, characterId)
	if success then
		log:info(`{player.Name} selected {charDef.name}`)
	else
		log:warn(`{player.Name} selected {charDef.name} but morph failed (model may be missing)`)
	end

	return true, nil
end

--- Get all available character IDs for selection.
function CharacterSelectionServiceServer.getAvailableCharacters(): { { id: string, name: string, title: string, element: string } }
	local list = {}
	for _, char in CharacterDefinitions.ALL_CHARACTERS do
		table.insert(list, {
			id = char.id,
			name = char.name,
			title = char.title,
			element = char.element,
		})
	end
	return list
end

-- ══════════════════════════════════════════════════════════════════════════════
-- LIFECYCLE
-- ══════════════════════════════════════════════════════════════════════════════

function CharacterSelectionServiceServer.init(_self: any)
	-- Listen for character selection requests from clients
	CharacterEvents.packets.SelectCharacter.listen(function(data, player)
		local success, err = CharacterSelectionServiceServer.selectCharacter(player, data.characterId)
		CharacterEvents.packets.SelectionResult.sendTo({
			success = success,
			characterId = string.upper(data.characterId),
			errorMessage = err,
		}, player)
	end)

	CharacterEvents.queries.GetCharacterData.listen(RequestHandler.wrap({
		name = "GetCharacterData",
		rateLimit = { maxRequests = 20, windowSeconds = 2 },
		audit = false,
		handler = function(data: { characterId: string? }, player: Player)
			if data.characterId then
				local char = CharacterDefinitions.getCharacterById(data.characterId)
				if char then
					return {
						success = true,
						data = HttpService:JSONEncode({
							id = char.id,
							name = char.name,
							title = char.title,
							element = char.element,
						}),
					}
				else
					return { success = false, error = "Character not found", data = "{}" }
				end
			else
				local chars = CharacterSelectionServiceServer.getAvailableCharacters()
				return {
					success = true,
					data = HttpService:JSONEncode(chars),
				}
			end
		end,
	}))

	-- Clean up when player leaves
	Players.PlayerRemoving:Connect(function(player)
		selectedCharacters[player.UserId] = nil
	end)
end

return CharacterSelectionServiceServer
