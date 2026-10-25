--!strict
--[=[
	EmoteServiceServer: plays emotes (Character step 5; owner, 25 Oct: emotes work everywhere, shifts included).

	A player asks for the emote in a slot of their current employee's wheel (EmoteEvents.PlayRequest). The server
	reads the wheel from the Cosmetic outfit (so the emote is theirs and owned), checks the body (EmoteRules: alive,
	not knocked down, not hiding, not carrying, not too soon) and grants the clip as a replicated action
	(AnimationServiceServer:play), so everyone sees it. A StopRequest (the client moved) ends it, and so does a
	knockdown or hiding (the protected emote would otherwise keep its layer). An emote with no clip yet is refused
	("no clip yet": the owner supplies the clips, AnimationEmoteRegistry).

	`deps` is a test seam: the outfit, the body's state, the animation calls and the clock.

	@class EmoteServiceServer
]=]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Janitor = require(ReplicatedStorage.Packages.Janitor)
local Logger = require(ReplicatedStorage.Shared.Core.Logger)
local AnimationRegistry = require(ReplicatedStorage.Shared.Features.Animation.Data.AnimationRegistry)
local CosmeticTypes = require(ReplicatedStorage.Shared.Features.Cosmetic.Data.CosmeticTypes)
local DeathConstants = require(ReplicatedStorage.Shared.Features.Death.Data.DeathConstants)
local EmoteEvents = require(ReplicatedStorage.Shared.Features.Emote.Net.EmoteEvents)
local EmoteRequestRules = require(ReplicatedStorage.Shared.Features.Emote.Rules.EmoteRequestRules)
local EmoteRules = require(ReplicatedStorage.Shared.Features.Emote.Rules.EmoteRules)
local HideConstants = require(ReplicatedStorage.Shared.Features.Hide.Data.HideConstants)
local RequestHandler = require(ServerScriptService.Core.Net.RequestHandler)
local AnimationServiceServer = require(ServerScriptService.Features.Animation.AnimationServiceServer)
local CarryServiceServer = require(ServerScriptService.Features.Carry.CarryServiceServer)
local CosmeticServiceServer = require(ServerScriptService.Features.Cosmetic.CosmeticServiceServer)

export type Body = { alive: boolean, knocked: boolean, hiding: boolean, carrying: boolean }

export type Deps = {
	outfitOf: (player: Player) -> CosmeticTypes.Outfit?,
	bodyOf: (player: Player) -> Body,
	play: (player: Player, key: string) -> (boolean, string?),
	stop: (player: Player, key: string) -> (),
	hasClip: (key: string) -> boolean,
	now: () -> number,
}

local log = Logger.new("EmoteServiceServer")
local janitor = Janitor.new()
-- Per player: when their last emote started and which clip it was.
local last: { [Player]: number } = {}
local playing: { [Player]: string } = {}

local function realBody(player: Player): Body
	local character = player.Character
	local humanoid = if character ~= nil then character:FindFirstChildOfClass("Humanoid") else nil
	return {
		alive = humanoid ~= nil and humanoid.Health > 0,
		knocked = character ~= nil and character:GetAttribute(DeathConstants.KNOCKDOWN_ATTRIBUTE) ~= nil,
		hiding = player:GetAttribute(HideConstants.PLAYER_SPOT_ATTRIBUTE) ~= nil,
		carrying = CarryServiceServer:getCarried(player) ~= nil,
	}
end

local defaults: Deps = {
	outfitOf = function(player)
		return CosmeticServiceServer:outfitOf(player.UserId)
	end,
	bodyOf = realBody,
	play = function(player, key)
		return AnimationServiceServer:play(player, key)
	end,
	stop = function(player, key)
		AnimationServiceServer:stop(player, key)
	end,
	hasClip = function(key)
		return AnimationRegistry.get(key) ~= nil
	end,
	now = os.clock,
}
local deps: Deps = defaults

local function playImpl(player: Player, slot: number): (boolean, string?)
	local outfit = deps.outfitOf(player)
	if outfit == nil then
		return false, "not loaded"
	end
	local emote = EmoteRules.inSlot(outfit.look, slot)
	local key = if emote ~= nil then EmoteRules.clipKey(emote) else ""
	local body = deps.bodyOf(player)
	local now = deps.now()
	local ok, reason = EmoteRules.check({
		emote = emote,
		hasClip = emote ~= nil and deps.hasClip(key),
		alive = body.alive,
		knocked = body.knocked,
		hiding = body.hiding,
		carrying = body.carrying,
		now = now,
		last = last[player],
	})
	if not ok then
		return false, reason
	end
	local played, refusal = deps.play(player, key)
	if not played then
		return false, refusal
	end
	last[player] = now
	playing[player] = key
	return true, nil
end

local function stopImpl(player: Player)
	local key = playing[player]
	if key ~= nil then
		playing[player] = nil
		deps.stop(player, key)
	end
end

local onPlayRequest = RequestHandler.wrap({
	name = "EmotePlayRequest",
	rateLimit = { maxRequests = 6, windowSeconds = 5 },
	handler = function(payload: unknown, player: Player)
		local slot, reason = EmoteRequestRules.parsePlay(payload)
		if slot == nil then
			log:warn(`bad PlayRequest from {player.Name}: {reason or "?"}`)
			return
		end
		local ok, refusal = playImpl(player, slot)
		if not ok then
			log:debug(`emote refused for {player.Name}: {refusal or "?"}`)
		end
	end,
})

local onStopRequest = RequestHandler.wrap({
	name = "EmoteStopRequest",
	rateLimit = { maxRequests = 20, windowSeconds = 5 },
	handler = function(_payload: unknown, player: Player)
		stopImpl(player)
	end,
})

export type EmoteServiceServer = {
	dependencies: { string },
	init: (self: EmoteServiceServer) -> (),
	stop: (self: EmoteServiceServer) -> (),
	play: (self: EmoteServiceServer, player: Player, slot: number) -> (boolean, string?),
	stopEmote: (self: EmoteServiceServer, player: Player) -> (),
	getState: (self: EmoteServiceServer) -> { [string]: any },
	-- TEST SEAMS
	_setDeps: (replacement: Deps?) -> (),
	_onPlayRequest: (payload: unknown, player: Player) -> any,
	_onStopRequest: (payload: unknown, player: Player) -> any,
}

local EmoteServiceServer: EmoteServiceServer = {
	dependencies = { "AnimationServiceServer", "CosmeticServiceServer", "CarryServiceServer" },

	init = function(_self)
		janitor:Add(
			EmoteEvents.packets.PlayRequest.listen(function(payload: unknown, player: Player?)
				if player then
					onPlayRequest(payload, player)
				end
			end),
			true
		)
		janitor:Add(
			EmoteEvents.packets.StopRequest.listen(function(payload: unknown, player: Player?)
				if player then
					onStopRequest(payload, player)
				end
			end),
			true
		)
		-- A knockdown or a hiding spot ends the emote (it is protected, so nothing else would).
		local function watch(player: Player)
			janitor:Add(
				player:GetAttributeChangedSignal(HideConstants.PLAYER_SPOT_ATTRIBUTE):Connect(function()
					stopImpl(player)
				end),
				"Disconnect"
			)
			janitor:Add(
				player.CharacterAdded:Connect(function(character: Model)
					playing[player] = nil
					-- Ends with the character (a destroyed instance drops its connections).
					character:GetAttributeChangedSignal(DeathConstants.KNOCKDOWN_ATTRIBUTE):Connect(function()
						stopImpl(player)
					end)
				end),
				"Disconnect"
			)
		end
		for _, player in Players:GetPlayers() do
			watch(player)
		end
		janitor:Add(Players.PlayerAdded:Connect(watch), "Disconnect")
		janitor:Add(
			Players.PlayerRemoving:Connect(function(player: Player)
				last[player] = nil
				playing[player] = nil
			end),
			"Disconnect"
		)
	end,

	stop = function(_self)
		janitor:Cleanup()
	end,

	play = function(_self, player, slot)
		return playImpl(player, slot)
	end,

	stopEmote = function(_self, player)
		stopImpl(player)
	end,

	getState = function(_self)
		local count = 0
		for _ in playing do
			count += 1
		end
		return { playing = count }
	end,

	-- Swaps `deps` for a spec's (nil restores the real ones); forgets every player either way.
	_setDeps = function(replacement)
		deps = replacement or defaults
		table.clear(last)
		table.clear(playing)
	end,

	_onPlayRequest = onPlayRequest,
	_onStopRequest = onStopRequest,
}

return EmoteServiceServer
