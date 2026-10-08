--!strict
--[=[
	ReplicationBodyObserverSystem: `ReplicationServiceServer:observeBodies` (plan R2 Task 9), moved out of the service
	shell unchanged in R3 to keep the shell under the 400-line cap.

	`observe` runs `callback(player, epoch)` for every live body now (deferred, one thread each) and for every
	body that spawns later; the cleanup a callback returns runs when that body despawns, when the same player
	spawns again, or when the observer is disconnected. The returned function disconnects the observer.

	@class ReplicationBodyObserverSystem
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SignalTyped = require(ReplicatedStorage.Shared.Core.SignalTyped)

export type LiveBody = { player: Player, epoch: number }

local ReplicationBodyObserverSystem = {}

function ReplicationBodyObserverSystem.observe(
	bodySpawned: SignalTyped.Signal<Player, number>,
	bodyDespawned: SignalTyped.Signal<Player, number>,
	liveBodies: () -> { LiveBody },
	callback: (player: Player, epoch: number) -> (() -> ())?
): () -> ()
	local cleanups: { [Player]: () -> () } = {}
	local function spawned(player: Player, epoch: number)
		local previous = cleanups[player]
		if previous ~= nil then
			cleanups[player] = nil
			previous()
		end
		local cleanup = callback(player, epoch)
		if cleanup ~= nil then
			cleanups[player] = cleanup
		end
	end
	local function despawned(player: Player, _epoch: number)
		local cleanup = cleanups[player]
		if cleanup ~= nil then
			cleanups[player] = nil
			cleanup()
		end
	end
	local spawnConnection = bodySpawned:Connect(spawned)
	local despawnConnection = bodyDespawned:Connect(despawned)
	for _, live in liveBodies() do
		task.spawn(spawned, live.player, live.epoch)
	end
	return function()
		spawnConnection:Disconnect()
		despawnConnection:Disconnect()
		for _, cleanup in cleanups do
			cleanup()
		end
		table.clear(cleanups)
	end
end

return ReplicationBodyObserverSystem
