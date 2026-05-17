--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")

local CharacterEvents = require(ReplicatedStorage.Shared.Events.CharacterEvents)
local CharacterSignals = require(ReplicatedStorage.Client.Signals.CharacterSignals)
local Logger = require(ReplicatedStorage.Shared.Modules.Logger)
local Janitor = require(ReplicatedStorage.Packages.Janitor)

local log = Logger.new("CharacterSelectionServiceClient")

local CharacterSelectionServiceClient = {}
CharacterSelectionServiceClient.dependencies = {} :: { string }

local _janitor = Janitor.new()
local _availableCharacters: { any } = {}

-- ── Public API ───────────────────────────────────────────────────────────────

function CharacterSelectionServiceClient:getAvailableCharacters(): { any }
	return _availableCharacters
end

function CharacterSelectionServiceClient:selectCharacter(characterId: string)
	CharacterEvents.packets.SelectCharacter.send({
		characterId = characterId,
	})
end

-- ── Service Lifecycle ────────────────────────────────────────────────────────
function CharacterSelectionServiceClient.init(_self: any)
	-- Listen for selection result from server
	_janitor:Add(CharacterEvents.packets.SelectionResult.listen(function(data)
		CharacterSignals.SelectionResult:Fire(data)
	end))

	-- Fetch character definitions from server
	task.spawn(function()
		local response = CharacterEvents.queries.GetCharacterData.invoke({
			characterId = nil, -- Request all
		})
		
		if response and response.success then
			local ok, data = pcall(function()
				return HttpService:JSONDecode(response.data)
			end)
			
			if ok and data then
				_availableCharacters = data
				CharacterSignals.CharactersLoaded:Fire(data)
				log:info(`Loaded {#data} character definitions`)
			else
				log:error("Failed to decode character data from server")
			end
		else
			log:error(`Failed to fetch character data: {response and response.error or "Unknown error"}`)
		end
	end)
end

function CharacterSelectionServiceClient.stop(_self: any)
	_janitor:Cleanup()
	table.clear(_availableCharacters)
end

return CharacterSelectionServiceClient
