--!strict
--[=[
	CalloutServiceServer: pings and stickers (design §8; plan 2026-10-25 step 5).

	A player asks for a sticker (one of their 4 sticker slots, from the Cosmetic outfit, owned) or a ping (a known
	ping at a spot within CalloutConstants.PING_RANGE of their body). Rate-limited per player (CalloutRules.allowed);
	an allowed callout is told to every client (CalloutEvents.Shown): a shift server holds only its crew, and in the
	depot everyone is close by. Stickers and pings work in shifts and in the depot; stickers make no sound.

	`deps` is a test seam: the outfit, what the player owns, where their body is, the clock and the broadcast.

	@class CalloutServiceServer
]=]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Janitor = require(ReplicatedStorage.Packages.Janitor)
local Logger = require(ReplicatedStorage.Shared.Core.Logger)
local CalloutConstants = require(ReplicatedStorage.Shared.Features.Callout.Data.CalloutConstants)
local CalloutEvents = require(ReplicatedStorage.Shared.Features.Callout.Net.CalloutEvents)
local CalloutRequestRules = require(ReplicatedStorage.Shared.Features.Callout.Rules.CalloutRequestRules)
local CalloutRules = require(ReplicatedStorage.Shared.Features.Callout.Rules.CalloutRules)
local CosmeticTypes = require(ReplicatedStorage.Shared.Features.Cosmetic.Data.CosmeticTypes)
local RequestHandler = require(ServerScriptService.Core.Net.RequestHandler)
local CosmeticServiceServer = require(ServerScriptService.Features.Cosmetic.CosmeticServiceServer)

export type Deps = {
	outfitOf: (player: Player) -> CosmeticTypes.Outfit?,
	owns: (player: Player, id: string) -> boolean,
	bodyAt: (player: Player) -> Vector3?,
	now: () -> number,
	broadcast: (shown: CalloutConstants.Shown) -> (),
}

local log = Logger.new("CalloutServiceServer")
local janitor = Janitor.new()
local recent: { [Player]: { number } } = {}

local defaults: Deps = {
	outfitOf = function(player)
		return CosmeticServiceServer:outfitOf(player.UserId)
	end,
	owns = function(player, id)
		return CosmeticServiceServer:owns(player.UserId, id)
	end,
	bodyAt = function(player)
		local character = player.Character
		local root = if character ~= nil then character:FindFirstChild("HumanoidRootPart") else nil
		return if root ~= nil and root:IsA("BasePart") then root.Position else nil
	end,
	now = os.clock,
	broadcast = function(shown)
		local at = shown.at or Vector3.zero
		CalloutEvents.packets.Shown.sendToAll({
			userId = shown.userId,
			kind = shown.kind,
			id = shown.id,
			x = at.X,
			y = at.Y,
			z = at.Z,
		})
	end,
}
local deps: Deps = defaults

local function calloutImpl(player: Player, request: CalloutRequestRules.Request): (boolean, string?)
	local times = recent[player]
	if times == nil then
		times = {}
		recent[player] = times
	end
	local now = deps.now()
	if not CalloutRules.allowed(times, now) then
		return false, "too soon"
	end
	local shown: CalloutConstants.Shown
	if request.kind == "sticker" then
		local outfit = deps.outfitOf(player)
		if outfit == nil then
			return false, "not loaded"
		end
		local id, refusal = CalloutRules.sticker(outfit.stickers, request.slot, function(item: string): boolean
			return deps.owns(player, item)
		end)
		if id == nil then
			return false, refusal
		end
		shown = { userId = player.UserId, kind = "sticker", id = id }
	else
		local ok, refusal = CalloutRules.ping(request.id, request.at, deps.bodyAt(player))
		if not ok then
			return false, refusal
		end
		shown = { userId = player.UserId, kind = "ping", id = request.id, at = request.at }
	end
	CalloutRules.remember(times, now)
	deps.broadcast(shown)
	return true, nil
end

local onRequest = RequestHandler.wrap({
	name = "CalloutRequest",
	rateLimit = { maxRequests = 10, windowSeconds = 10 },
	handler = function(payload: unknown, player: Player)
		local request, reason = CalloutRequestRules.parse(payload)
		if request == nil then
			log:warn(`bad callout Request from {player.Name}: {reason or "?"}`)
			return
		end
		local ok, refusal = calloutImpl(player, request)
		if not ok then
			log:debug(`callout refused for {player.Name}: {refusal or "?"}`)
		end
	end,
})

export type CalloutServiceServer = {
	dependencies: { string },
	init: (self: CalloutServiceServer) -> (),
	stop: (self: CalloutServiceServer) -> (),
	callout: (self: CalloutServiceServer, player: Player, request: CalloutRequestRules.Request) -> (boolean, string?),
	getState: (self: CalloutServiceServer) -> { [string]: any },
	-- TEST SEAMS
	_setDeps: (replacement: Deps?) -> (),
	_onRequest: (payload: unknown, player: Player) -> any,
}

local CalloutServiceServer: CalloutServiceServer = {
	dependencies = { "CosmeticServiceServer" },

	init = function(_self)
		janitor:Add(
			CalloutEvents.packets.Request.listen(function(payload: unknown, player: Player?)
				if player then
					onRequest(payload, player)
				end
			end),
			true
		)
		janitor:Add(
			Players.PlayerRemoving:Connect(function(player: Player)
				recent[player] = nil
			end),
			"Disconnect"
		)
	end,

	stop = function(_self)
		janitor:Cleanup()
	end,

	callout = function(_self, player, request)
		return calloutImpl(player, request)
	end,

	getState = function(_self)
		local count = 0
		for _ in recent do
			count += 1
		end
		return { players = count }
	end,

	_setDeps = function(replacement)
		deps = replacement or defaults
		table.clear(recent)
	end,

	_onRequest = onRequest,
}

return CalloutServiceServer
