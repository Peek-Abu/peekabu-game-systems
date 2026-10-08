--!strict
--[=[
	Unit tests for ReplicationDiagnosticsSystem.snapshot — the view the tripwire checks. The gate (Workspace
	`Diagnostics`, a 1 Hz thread) is an Instance/scheduler shell, verified in Studio (plan Task 11).
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ReplicationDiagnosticsSystem = require(script.Parent.ReplicationDiagnosticsSystem)
local ReplicationRigTracker = require(ReplicatedStorage.Client.Features.Replication.State.ReplicationRigTracker)
local CustomizationRigOutfitTracker =
	require(ReplicatedStorage.Client.Features.Customization.State.CustomizationRigOutfitTracker)
local CustomizationOutfitDiffUtils =
	require(ReplicatedStorage.Client.Features.Customization.Utils.CustomizationOutfitDiffUtils)

return function()
	local rigs

	local function player(userId)
		return { UserId = userId, Name = `user{userId}`, Character = nil }
	end

	local function puppet(dressed)
		local model = Instance.new("Model")
		table.insert(rigs, model)
		local outfit = CustomizationRigOutfitTracker.new(model)
		if dressed then
			CustomizationRigOutfitTracker.setWorn(outfit, CustomizationOutfitDiffUtils.empty(), 1)
		end
		return { model = model, outfit = outfit }
	end

	local function body(userId, visible, samples)
		return { userId = userId, generation = 1, epoch = 2, visible = visible, samples = { samples = samples } }
	end

	beforeEach(function()
		rigs = {}
	end)

	afterEach(function()
		for _, model in rigs do
			model:Destroy()
		end
	end)

	it("reports each visible body's state and skips hidden ones", function()
		local me, p2, p3 = player(1), player(2), player(3)
		local registry = ReplicationRigTracker.new(1)
		local dressed = puppet(true)
		ReplicationRigTracker.register(registry, p2, dressed.model)
		local view = {
			remote = { bodies = { [4] = body(2, true, { {} }), [5] = body(3, false, {}) } },
			held = { [4] = { puppet = dressed, player = p2 } },
			placed = { [4] = true },
			registry = registry,
			players = { me, p2, p3 },
		}
		local snapshot = ReplicationDiagnosticsSystem.snapshot(view)
		expect(#snapshot.bodies).to.equal(1)
		local b = snapshot.bodies[1]
		expect(b.slot).to.equal(4)
		expect(b.held).to.equal(true)
		expect(b.placed).to.equal(true)
		expect(b.dressed).to.equal(true)
		expect(b.bufferEmpty).to.equal(false)
		expect(b.playerPresent).to.equal(true)
		expect(snapshot.knownUserIds[2]).to.equal(true)
		expect(snapshot.knownUserIds[3]).to.equal(true) -- known even while hidden
		expect(#snapshot.otherUserIds).to.equal(2) -- never the local player
		expect(#snapshot.held).to.equal(1)
		expect(snapshot.held[1].ownerUserId).to.equal(2)
	end)

	it("flags an undressed puppet, an empty buffer and a missing Player", function()
		local registry = ReplicationRigTracker.new(1)
		local undressed = puppet(false)
		local view = {
			remote = { bodies = { [4] = body(2, true, {}) } },
			held = { [4] = { puppet = undressed, player = player(2) } },
			placed = {},
			registry = registry,
			players = { player(1) },
		}
		local b = ReplicationDiagnosticsSystem.snapshot(view).bodies[1]
		expect(b.dressed).to.equal(false)
		expect(b.bufferEmpty).to.equal(true)
		expect(b.playerPresent).to.equal(false)
		expect(b.placed).to.equal(false)
	end)

	it("a remote Character matches only the registry's rig (or nil when there is none)", function()
		local registry = ReplicationRigTracker.new(1)
		local p2, p3 = player(2), player(3)
		local a = puppet(true)
		ReplicationRigTracker.register(registry, p2, a.model)
		p3.Character = a.model -- wrong: the registry holds nothing for 3
		local view =
			{ remote = { bodies = {} }, held = {}, placed = {}, registry = registry, players = { player(1), p2, p3 } }
		local matches = {}
		for _, c in ReplicationDiagnosticsSystem.snapshot(view).characters do
			matches[c.userId] = c.matches
		end
		expect(matches[2]).to.equal(true)
		expect(matches[3]).to.equal(false)
	end)
end
