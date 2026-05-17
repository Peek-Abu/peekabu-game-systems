--!strict
--[=[
	Client-side signals for character selection events.
	UI components can subscribe to these signals to react to character data changes.
	@class CharacterSignals
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Signal = require(ReplicatedStorage.Packages.Signal)

local CharacterSignals = {}

--[=[
	Fired when character definitions are loaded from the server.
	@param characters {any} -- List of available character definitions
]=]
CharacterSignals.CharactersLoaded = Signal() :: Signal.Signal<{ any }>

--[=[
	Fired when a character selection result is received from the server.
	@param success boolean -- Whether the selection was successful
	@param characterId string -- The ID of the selected character
	@param errorMessage string? -- Error message if selection failed
]=]
CharacterSignals.SelectionResult = Signal() :: Signal.Signal<{ success: boolean, characterId: string, errorMessage: string? }>

return CharacterSignals
