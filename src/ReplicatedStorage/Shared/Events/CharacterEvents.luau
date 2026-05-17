--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ByteNet = require(ReplicatedStorage.Packages.ByteNetMax)

--[=[
	Network events for character selection.
	@class CharacterEvents
]=]
return ByteNet.defineNamespace("Character", function()
	return {
		packets = {
			-- Client requests to select a character
			SelectCharacter = ByteNet.definePacket({
				name = "SelectCharacter",
				value = ByteNet.struct({
					characterId = ByteNet.string,
				}),
			}),

			-- Server confirms selection (or sends error)
			SelectionResult = ByteNet.definePacket({
				name = "SelectionResult",
				value = ByteNet.struct({
					success = ByteNet.bool,
					characterId = ByteNet.string,
					errorMessage = ByteNet.optional(ByteNet.string),
				}),
			}),
		},
		queries = {
			-- Client requests character definitions
			GetCharacterData = ByteNet.defineQuery({
				name = "GetCharacterData",
				request = ByteNet.struct({
					characterId = ByteNet.optional(ByteNet.string),
				}),
				response = ByteNet.struct({
					success = ByteNet.bool,
					data = ByteNet.string, -- JSON-encoded
					error = ByteNet.optional(ByteNet.string),
				}),
			}),
		},
		structs = {},
	}
end)
