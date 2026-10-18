--!strict
--[=[
	QueueArrivalSystem: the arriving side of a reserved server. Each joining player's ticket (read by the
	service from their join data) tells the specced QueueArrivalTracker who is expected, before that player
	is admitted; a ticket whose party does not list its own carrier is ignored (the carrier is a stranger).
	The tracker decides each admission. When the party is complete or the wait runs out, `onArrived` gets
	the crew; with nobody here nothing happens (Roblox shuts an empty server down). A redirected stranger
	goes to `onRedirect`; an expected straggler who comes after the start goes to `onLate`.

	Joins are handled once every service has started (ServiceController phase "running"), so a game's
	`arrived` listener is always connected before the party can be reported.

	Spec-exempt shell (Players, join data only exist after a live teleport).

	@class QueueArrivalSystem
]=]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local ServiceController = require(ReplicatedStorage.Shared.Core.ServiceController)
local QueueConstants = require(ReplicatedStorage.Shared.Features.Queue.Data.QueueConstants)
local QueueTypes = require(ReplicatedStorage.Shared.Features.Queue.Data.QueueTypes)
local QueueArrivalTracker = require(ServerScriptService.Features.Queue.State.QueueArrivalTracker)

type QueueTicket = QueueTypes.QueueTicket

export type Hooks = {
	ticketOf: (player: Player) -> QueueTicket?,
	onArrived: (crew: { Player }, ticket: QueueTicket?) -> (),
	onLate: (player: Player) -> (),
	onRedirect: (player: Player, ticket: QueueTicket?) -> (),
}

export type QueueArrivalSystem = {
	start: (self: QueueArrivalSystem) -> (),
	stop: (self: QueueArrivalSystem) -> (),
	step: (self: QueueArrivalSystem, now: number) -> (),
	getState: (self: QueueArrivalSystem) -> { crew: { number }, closed: boolean },
}

local QueueArrivalSystem = {}

function QueueArrivalSystem.new(hooks: Hooks): QueueArrivalSystem
	local tracker = QueueArrivalTracker.new(QueueConstants.ARRIVAL_TIMEOUT, QueueConstants.DEFAULT_CAPACITY)
	local waiting: { Player } = {}
	local connections: { RBXScriptConnection } = {}

	local function admit(player: Player, now: number)
		-- The ticket counts only for a player it names, and before their own join so they are expected.
		local ticket = hooks.ticketOf(player)
		if ticket ~= nil and ticket.kind == "depart" and table.find(ticket.party, player.UserId) ~= nil then
			tracker:expect(ticket, now)
		end
		local admission = tracker:join(player.UserId, now)
		if admission == "redirect" then
			hooks.onRedirect(player, tracker:ticket())
		elseif admission == "late" then
			hooks.onLate(player)
		end
	end

	local system: QueueArrivalSystem
	system = {
		start = function(_self)
			for _, player in Players:GetPlayers() do
				table.insert(waiting, player)
			end
			table.insert(
				connections,
				Players.PlayerAdded:Connect(function(player)
					table.insert(waiting, player)
				end)
			)
			table.insert(
				connections,
				Players.PlayerRemoving:Connect(function(player)
					local index = table.find(waiting, player)
					if index ~= nil then
						table.remove(waiting, index)
					end
					tracker:leave(player.UserId)
				end)
			)
		end,

		stop = function(_self)
			for _, connection in connections do
				connection:Disconnect()
			end
			table.clear(connections)
		end,

		step = function(_self, now)
			if ServiceController:getPhase() ~= "running" then
				return
			end
			local joining = waiting
			waiting = {}
			for _, player in joining do
				if player.Parent == Players then
					admit(player, now)
				end
			end
			if tracker:ready(now) then
				local crew: { Player } = {}
				for _, userId in tracker:close() do
					local player = Players:GetPlayerByUserId(userId)
					if player ~= nil then
						table.insert(crew, player)
					end
				end
				hooks.onArrived(crew, tracker:ticket())
			end
		end,

		getState = function(_self)
			return { crew = tracker:crew(), closed = tracker:isClosed() }
		end,
	}
	return system
end

return QueueArrivalSystem
