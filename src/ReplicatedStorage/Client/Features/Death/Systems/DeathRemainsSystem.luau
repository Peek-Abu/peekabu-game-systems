--!strict
--[=[
	DeathRemainsSystem: destroys, on this client, a character a player no longer has.

	The server destroys a player's old character when they respawn or leave, but a client only sees that
	character leave the DataModel (Parent nil): `Destroying` never fires there, so every client-side cleanup
	tied to the character's or its Animator's `Destroying` (Animate's locomotion binding, the memoized
	AnimationPlayer per Animator, ...) never runs, and the whole old model stays alive on every client after
	every death. Measured in Studio: each respawn kept the previous character alive on the client; destroying
	it on the client freed it.

	Once a character has left the DataModel and is nobody's current character, this destroys it, so the same
	cleanups run on the client as on the server. A character the server only parents away for a moment while
	it is still the player's character is left alone.

	@class DeathRemainsSystem
]=]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Observers = require(ReplicatedStorage.Packages.Observers)

local DeathRemainsSystem = {}

local function isCurrentCharacter(character: Model): boolean
	return Players:GetPlayerFromCharacter(character) ~= nil
end

--[=[
	Destroys `character` if it has left the DataModel and `isCurrent` says it is nobody's character.
	@param character Model
	@param isCurrent (Model) -> boolean -- whether it is still a player's current character
	@return boolean -- true when it was destroyed
]=]
function DeathRemainsSystem.reap(character: Model, isCurrent: (character: Model) -> boolean): boolean
	if character:IsDescendantOf(game) or isCurrent(character) then
		return false
	end
	character:Destroy()
	return true
end

--[=[
	Reaps every player's character once it is removed. Deferred, so other removal handlers see the model
	before it is destroyed. Stopping it destroys nothing (the observer's cleanup runs, but those
	characters are still in the DataModel).
	@return () -> () -- stops watching
]=]
function DeathRemainsSystem.start(): () -> ()
	return Observers.observeCharacter(function(player: Player, character: Model)
		return function()
			task.defer(function()
				if DeathRemainsSystem.reap(character, isCurrentCharacter) or character:IsDescendantOf(game) then
					return
				end
				-- Removed, but `player.Character` has not moved on yet: reap it once it does.
				local connection: RBXScriptConnection
				connection = player:GetPropertyChangedSignal("Character"):Connect(function()
					if DeathRemainsSystem.reap(character, isCurrentCharacter) then
						connection:Disconnect()
					end
				end)
			end)
		end
	end)
end

return DeathRemainsSystem
