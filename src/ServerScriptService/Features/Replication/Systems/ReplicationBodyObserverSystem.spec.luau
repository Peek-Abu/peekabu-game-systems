--[=[
	ReplicationBodyObserverSystem carries `observeBodies` (moved out of the service shell in R3, unchanged). SignalPlus delivers
	deferred, so each step yields once (`task.wait()`) before asserting.
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local SignalTyped = require(ReplicatedStorage.Shared.Core.SignalTyped)
local ReplicationBodyObserverSystem =
	require(ServerScriptService.Features.Replication.Systems.ReplicationBodyObserverSystem)

local playerA = { UserId = 1, Name = "A" }
local playerB = { UserId = 2, Name = "B" }

-- Observes with a callback that records spawns and counts cleanups.
local function observe(live)
	local spawned, despawned = SignalTyped.new(), SignalTyped.new()
	local record = { calls = {}, cleaned = 0 }
	local disconnect = ReplicationBodyObserverSystem.observe(spawned, despawned, function()
		return live or {}
	end, function(player, epoch)
		table.insert(record.calls, { player = player, epoch = epoch })
		return function()
			record.cleaned += 1
		end
	end)
	return spawned, despawned, record, disconnect
end

return function()
	it("calls back for every live body, then for each later spawn", function()
		local spawned, _, record, disconnect = observe({ { player = playerA, epoch = 3 } })
		task.wait()
		expect(#record.calls).to.equal(1)
		expect(record.calls[1].epoch).to.equal(3)
		spawned:Fire(playerB, 1)
		task.wait()
		expect(#record.calls).to.equal(2)
		expect(record.calls[2].player).to.equal(playerB)
		disconnect()
	end)

	it("runs a body's cleanup when it despawns", function()
		local spawned, despawned, record, disconnect = observe()
		spawned:Fire(playerA, 1)
		task.wait()
		despawned:Fire(playerA, 1)
		task.wait()
		expect(record.cleaned).to.equal(1)
		disconnect()
	end)

	it("cleans up the previous body when the same player spawns again", function()
		local spawned, _, record, disconnect = observe()
		spawned:Fire(playerA, 1)
		spawned:Fire(playerA, 2)
		task.wait()
		expect(#record.calls).to.equal(2)
		expect(record.cleaned).to.equal(1)
		disconnect()
	end)

	it("disconnecting runs every cleanup and stops listening", function()
		local spawned, _, record, disconnect = observe()
		spawned:Fire(playerA, 1)
		task.wait()
		disconnect()
		expect(record.cleaned).to.equal(1)
		spawned:Fire(playerA, 2)
		task.wait()
		expect(#record.calls).to.equal(1)
	end)
end
