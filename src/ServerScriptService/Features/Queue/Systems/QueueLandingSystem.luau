--!strict
--[=[
	QueueLandingSystem: where travelling players land. A local move (Studio, an unknown place or a
	placeholder role) puts each player at the role's arrival point (`setArrivalPoint`). It is all or
	nothing: with no arrival point for the role (its world is not built in this server), or one that
	errors or gives no CFrame for any player, nobody moves and `move` returns false, so the caller keeps
	the party where it is instead of splitting or stranding it. A player home from a
	return trip (a "return" ticket in their join data, or a local return move) has the payload kept
	(`payloadOf`) and is reported through `onReturned` from the tick once every service has started, so a
	game's listener never misses one.

	Spec-exempt shell (characters, Players, ServiceController phase); the ticket is decoded by the specced
	QueueTeleportRules.

	@class QueueLandingSystem
]=]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Logger = require(ReplicatedStorage.Shared.Core.Logger)
local ServiceController = require(ReplicatedStorage.Shared.Core.ServiceController)
local QueueTypes = require(ReplicatedStorage.Shared.Features.Queue.Data.QueueTypes)

type QueuePayload = QueueTypes.QueuePayload

export type OnReturned = (player: Player, payload: QueuePayload) -> ()

export type QueueLandingSystem = {
	setArrivalPoint: (self: QueueLandingSystem, role: string, resolver: QueueTypes.ArrivalPoint?) -> (),
	move: (self: QueueLandingSystem, players: { Player }, role: string) -> boolean,
	landHome: (self: QueueLandingSystem, player: Player, payload: QueuePayload) -> (),
	step: (self: QueueLandingSystem) -> (),
	payloadOf: (self: QueueLandingSystem, player: Player) -> QueuePayload?,
	forget: (self: QueueLandingSystem, player: Player) -> (),
}

local log = Logger.new("QueueLandingSystem")

local QueueLandingSystem = {}

function QueueLandingSystem.new(onReturned: OnReturned): QueueLandingSystem
	local arrivalPoints: { [string]: QueueTypes.ArrivalPoint } = {}
	local payloads: { [Player]: QueuePayload } = {}
	local pending: { Player } = {}

	local system: QueueLandingSystem
	system = {
		setArrivalPoint = function(_self, role, resolver)
			if resolver ~= nil then
				arrivalPoints[role] = resolver
			else
				arrivalPoints[role] = nil
			end
		end,

		-- A local move: each player to the role's arrival point (their 1-based party index lets a game
		-- spread them out). Every point is resolved before anyone moves. Whether the party moved.
		move = function(_self, players, role)
			local resolver = arrivalPoints[role]
			if resolver == nil then
				return false
			end
			local targets: { CFrame } = {}
			for index, player in players do
				local ok, result = pcall(resolver, player, index)
				if not ok then
					log:error(`arrival point for "{role}" errored: {tostring(result)}`)
					return false
				elseif typeof(result) ~= "CFrame" then
					log:warn(`arrival point for "{role}" gave {player.Name} a {typeof(result)}, not a CFrame`)
					return false
				end
				targets[index] = result
			end
			for index, player in players do
				local character = player.Character
				if character ~= nil then
					character:PivotTo(targets[index])
				end
			end
			return true
		end,

		-- A player home from a return trip: keeps the payload and reports them on the next running tick.
		landHome = function(_self, player, payload)
			payloads[player] = payload
			table.insert(pending, player)
		end,

		step = function(_self)
			if #pending == 0 or ServiceController:getPhase() ~= "running" then
				return
			end
			local list = pending
			pending = {}
			for _, player in list do
				local payload = payloads[player]
				if payload ~= nil and player.Parent == Players then
					onReturned(player, payload)
				end
			end
		end,

		payloadOf = function(_self, player)
			return payloads[player]
		end,

		forget = function(_self, player)
			payloads[player] = nil
		end,
	}
	return system
end

return QueueLandingSystem
