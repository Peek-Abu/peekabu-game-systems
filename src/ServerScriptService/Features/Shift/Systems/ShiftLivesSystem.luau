--!strict
--[=[
	ShiftLivesSystem: Gloom lives for one shift. Everyone in the run starts with STARTING_LIVES (shaped by the lives
	modifiers, ShiftLivesRules.starting); each Manager's catch spends one (`spend`); the last keeps the player down and
	out of the round for the shift. Nothing gives a life back. The shift's end releases whoever was knocked out and
	clears the public fields.

	Public player fields: `lives`, `livesMax` for everyone in the run, plus `knockedOut` once out (ShiftConstants.PUBLIC_*).
	A knock-out publishes `lives = 0` and `knockedOut = true`, holds the player's respawn (DeathServiceServer:holdRespawn),
	eliminates them from Round and marks the roster. Kept out of ShiftServiceServer (the service is over its line cap).
	The decisions are the specced ShiftLivesRules and ShiftLivesTracker; the effects are the real services unless a spec
	hands in fakes.

	@class ShiftLivesSystem
]=]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local ShiftConstants = require(ReplicatedStorage.Shared.Features.Shift.Data.ShiftConstants)
local ShiftLivesRules = require(ServerScriptService.Features.Shift.Rules.ShiftLivesRules)
local ShiftLivesTracker = require(ServerScriptService.Features.Shift.State.ShiftLivesTracker)
local DeathServiceServer = require(ServerScriptService.Features.Death.DeathServiceServer)
local RoundServiceServer = require(ServerScriptService.Features.Round.RoundServiceServer)
local StateSyncPublicPlayerStore = require(ServerScriptService.Features.StateSync.State.StateSyncPublicPlayerStore)

type Fields = { [string]: number | boolean }

export type Deps = {
	-- The shift is running (a catch outside a run spends nothing).
	isRunning: () -> boolean,
	-- A knock-out marks the review's roster.
	markOut: (userId: number, name: string) -> (),
	-- Effects; absent = the real ones (specs hand in fakes).
	setFields: ((userId: number, fields: Fields) -> ())?,
	clearField: ((userId: number, field: string) -> ())?,
	hold: ((player: Player) -> ())?,
	release: ((player: Player) -> ())?,
	eliminate: ((player: Player) -> ())?,
	playerById: ((userId: number) -> Player?)?,
	-- Drops a knocked-out player's live character (a rejoin loads a fresh one).
	down: ((player: Player) -> ())?,
	-- Calls `onCharacter` for every character the player gets from now on; returns the function that stops it.
	watch: ((player: Player, onCharacter: () -> ()) -> () -> ())?,
}

export type ShiftLivesSystem = {
	-- A new run: everyone in `players` starts with the starting lives (replacing whatever was kept).
	begin: (self: ShiftLivesSystem, players: { Player }) -> (),
	-- A late joiner gets the starting lives; a player already listed keeps what they have (one who is out, rejoining, is
	-- put straight back out: held, eliminated, their character dropped, and any character that arrives later in the
	-- run dropped too, as the join load usually lands after this). Nothing outside a run.
	admit: (self: ShiftLivesSystem, player: Player) -> (),
	-- One catch. True when it was the player's last life (they are now out); false otherwise, and for an unknown player
	-- or one already out, or outside a run.
	spend: (self: ShiftLivesSystem, player: Player) -> boolean,
	isKnockedOut: (self: ShiftLivesSystem, player: Player) -> boolean,
	-- The shift's end: releases everyone knocked out, clears every public field, forgets the lives.
	clear: (self: ShiftLivesSystem) -> (),
	-- Shapes the starting lives (ShiftLivesRules.starting); returns the function that removes it.
	addModifier: (self: ShiftLivesSystem, modify: (number) -> number) -> () -> (),
}

local function realSetFields(userId: number, fields: Fields)
	StateSyncPublicPlayerStore.set(userId, fields)
end

local function realHold(player: Player)
	DeathServiceServer:holdRespawn(player)
end

local function realRelease(player: Player)
	DeathServiceServer:releaseRespawn(player)
end

local function realEliminate(player: Player)
	RoundServiceServer:eliminate(player)
end

-- Kills the player's character once it has a Humanoid (a character that has just arrived may not yet).
local function realDown(player: Player)
	local character = player.Character
	if character == nil then
		return
	end
	task.spawn(function()
		local humanoid = character:FindFirstChildOfClass("Humanoid") or character:WaitForChild("Humanoid", 5)
		if humanoid ~= nil and humanoid:IsA("Humanoid") and player.Character == character then
			DeathServiceServer:kill(humanoid, "knockedOut")
		end
	end)
end

local function realWatch(player: Player, onCharacter: () -> ()): () -> ()
	local connection = player.CharacterAdded:Connect(function()
		-- A frame for Death to start watching the new character before it is killed.
		task.defer(onCharacter)
	end)
	return function()
		connection:Disconnect()
	end
end

local function realPlayerById(userId: number): Player?
	return Players:GetPlayerByUserId(userId)
end

local ShiftLivesSystem = {}

function ShiftLivesSystem.new(deps: Deps): ShiftLivesSystem
	local setFields: (number, Fields) -> () = deps.setFields or realSetFields
	local clearField: (number, string) -> () = deps.clearField or StateSyncPublicPlayerStore.clearField
	local hold: (Player) -> () = deps.hold or realHold
	local release: (Player) -> () = deps.release or realRelease
	local eliminate: (Player) -> () = deps.eliminate or realEliminate
	local down: (Player) -> () = deps.down or realDown
	local playerById: (number) -> Player? = deps.playerById or realPlayerById
	local watch: (Player, () -> ()) -> () -> () = deps.watch or realWatch

	local tracker = ShiftLivesTracker.new()
	local modifiers: { (number) -> number } = {}
	-- Every userId whose lives fields were published, so the shift's end clears leavers' too.
	local published: { [number]: boolean } = {}
	-- Stops for the watches on rejoined knocked-out players' characters, until the shift's end.
	local watches: { [number]: () -> () } = {}

	local function stopWatching(userId: number)
		local stop = watches[userId]
		if stop ~= nil then
			watches[userId] = nil
			stop()
		end
	end

	local function startingLives(): number
		return ShiftLivesRules.starting(ShiftConstants.STARTING_LIVES, modifiers)
	end

	local function publishLives(userId: number)
		local lives = tracker:get(userId)
		local livesMax = tracker:max(userId)
		if lives == nil or livesMax == nil then
			return
		end
		published[userId] = true
		local fields: Fields = {
			[ShiftConstants.PUBLIC_LIVES] = lives,
			[ShiftConstants.PUBLIC_LIVES_MAX] = livesMax,
		}
		setFields(userId, fields)
	end

	local system: ShiftLivesSystem = {
		begin = function(_self, players)
			local entries: { [number]: number } = {}
			local lives = startingLives()
			for _, player in players do
				entries[player.UserId] = lives
			end
			tracker:reset(entries)
			for userId in entries do
				publishLives(userId)
			end
		end,

		admit = function(_self, player)
			if not deps.isRunning() then
				return
			end
			tracker:admit(player.UserId, startingLives())
			if tracker:isOut(player.UserId) then
				-- Left and came back while out: a new Player object has no hold, and a fresh character is alive.
				local fields: Fields = {
					[ShiftConstants.PUBLIC_LIVES] = 0,
					[ShiftConstants.PUBLIC_LIVES_MAX] = tracker:max(player.UserId) or 0,
					[ShiftConstants.PUBLIC_KNOCKED_OUT] = true,
				}
				published[player.UserId] = true
				setFields(player.UserId, fields)
				hold(player)
				eliminate(player)
				down(player)
				stopWatching(player.UserId)
				watches[player.UserId] = watch(player, function()
					if deps.isRunning() and tracker:isOut(player.UserId) then
						down(player)
					end
				end)
				return
			end
			publishLives(player.UserId)
		end,

		spend = function(_self, player)
			if not deps.isRunning() then
				return false
			end
			local left, knockedOut = tracker:spend(player.UserId)
			if left == nil then
				return false
			end
			if knockedOut ~= true then
				publishLives(player.UserId)
				return false
			end
			local fields: Fields = {
				[ShiftConstants.PUBLIC_LIVES] = 0,
				[ShiftConstants.PUBLIC_KNOCKED_OUT] = true,
			}
			setFields(player.UserId, fields)
			-- Held before the kill that follows, so their death schedules no respawn.
			hold(player)
			eliminate(player)
			deps.markOut(player.UserId, player.DisplayName)
			return true
		end,

		isKnockedOut = function(_self, player)
			return tracker:isOut(player.UserId)
		end,

		clear = function(_self)
			for userId in watches do
				stopWatching(userId)
			end
			for _, userId in tracker:out() do
				local player = playerById(userId)
				if player ~= nil then
					release(player)
				end
				clearField(userId, ShiftConstants.PUBLIC_KNOCKED_OUT)
			end
			for userId in published do
				clearField(userId, ShiftConstants.PUBLIC_LIVES)
				clearField(userId, ShiftConstants.PUBLIC_LIVES_MAX)
			end
			table.clear(published)
			tracker:clear()
		end,

		addModifier = function(_self, modify)
			table.insert(modifiers, modify)
			return function()
				local at = table.find(modifiers, modify)
				if at ~= nil then
					table.remove(modifiers, at)
				end
			end
		end,
	}
	return system
end

return ShiftLivesSystem
