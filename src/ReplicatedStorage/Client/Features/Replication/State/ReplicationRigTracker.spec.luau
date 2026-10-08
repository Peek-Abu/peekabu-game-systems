--!strict
--[=[
	Unit tests for ReplicationRigTracker — lookups, the body signals, and the remote `Character` rules (R5 spec §2.1):
	set on register, cleared on unregister only if it still points at that rig, never touched for the local
	player, and a stale unregister is a no-op. Players cannot be constructed in a spec: stand-in tables.
]=]

local ReplicationRigTracker = require(script.Parent.ReplicationRigTracker)

return function()
	local LOCAL_ID = 1
	local registry, models

	local function player(userId)
		return { UserId = userId, Name = `user{userId}`, Character = nil }
	end

	local function model(name)
		local m = Instance.new("Model")
		m.Name = name
		table.insert(models, m)
		return m
	end

	beforeEach(function()
		registry = ReplicationRigTracker.new(LOCAL_ID)
		models = {}
	end)

	afterEach(function()
		for _, m in models do
			m:Destroy()
		end
	end)

	it("register maps both ways, sets a remote player's Character, and fires spawned", function()
		local p, a = player(2), model("A")
		local fired = {}
		registry.spawned:Connect(function(who, rig)
			table.insert(fired, { who, rig })
		end)
		ReplicationRigTracker.register(registry, p, a)
		-- SignalPlus fires listeners with task.defer: yield once before counting.
		task.wait()
		expect(ReplicationRigTracker.rigFor(registry, 2)).to.equal(a)
		expect(ReplicationRigTracker.userIdFor(registry, a)).to.equal(2)
		expect(p.Character).to.equal(a)
		expect(#fired).to.equal(1)
		expect(fired[1][1]).to.equal(p)
		expect(fired[1][2]).to.equal(a)
	end)

	it("never touches the local player's Character (OwnerRig owns it)", function()
		local me, rig = player(LOCAL_ID), model("Mine")
		ReplicationRigTracker.register(registry, me, rig)
		expect(me.Character).to.equal(nil)
		ReplicationRigTracker.unregister(registry, me, rig)
		expect(ReplicationRigTracker.rigFor(registry, LOCAL_ID)).to.equal(nil)
	end)

	it("unregister clears both lookups and the Character, and fires despawned", function()
		local p, a = player(2), model("A")
		local fired = 0
		registry.despawned:Connect(function()
			fired += 1
		end)
		ReplicationRigTracker.register(registry, p, a)
		ReplicationRigTracker.unregister(registry, p, a)
		task.wait()
		expect(ReplicationRigTracker.rigFor(registry, 2)).to.equal(nil)
		expect(ReplicationRigTracker.userIdFor(registry, a)).to.equal(nil)
		expect(p.Character).to.equal(nil)
		expect(fired).to.equal(1)
	end)

	it("a stale unregister (an older rig) is a no-op: the newer rig and Character stay", function()
		local p, a, b = player(2), model("A"), model("B")
		local fired = 0
		registry.despawned:Connect(function()
			fired += 1
		end)
		ReplicationRigTracker.register(registry, p, a)
		ReplicationRigTracker.register(registry, p, b)
		ReplicationRigTracker.unregister(registry, p, a)
		task.wait()
		expect(ReplicationRigTracker.rigFor(registry, 2)).to.equal(b)
		expect(p.Character).to.equal(b)
		expect(fired).to.equal(0)
	end)

	-- Review focus 1: a pooled puppet released by player 2, reused by player 3, then a late unregister for 2.
	it("a reused puppet keeps its new owner's lookups and Character after a late unregister", function()
		local p2, p3, a = player(2), player(3), model("A")
		ReplicationRigTracker.register(registry, p2, a)
		ReplicationRigTracker.unregister(registry, p2, a)
		ReplicationRigTracker.register(registry, p3, a)
		ReplicationRigTracker.unregister(registry, p2, a) -- late and stale
		expect(ReplicationRigTracker.rigFor(registry, 3)).to.equal(a)
		expect(ReplicationRigTracker.userIdFor(registry, a)).to.equal(3)
		expect(p3.Character).to.equal(a)
		expect(p2.Character).to.equal(nil)
	end)

	it("unregister leaves a Character that points somewhere else alone", function()
		local p, a, other = player(2), model("A"), model("Other")
		ReplicationRigTracker.register(registry, p, a)
		p.Character = other
		ReplicationRigTracker.unregister(registry, p, a)
		expect(p.Character).to.equal(other)
	end)
end
