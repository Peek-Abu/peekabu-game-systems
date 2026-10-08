--!strict
--[=[
	Unit tests for ReplicationPuppetPool — owner affinity, the least-recently-used spare, the idle cap, and the
	per-frame build budget. Uses a minimal in-memory template (Humanoid + HumanoidRootPart).
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ReplicationPuppetPool = require(script.Parent.ReplicationPuppetPool)
local CustomizationOutfitDiffUtils =
	require(ReplicatedStorage.Client.Features.Customization.Utils.CustomizationOutfitDiffUtils)
local CustomizationRigOutfitTracker =
	require(ReplicatedStorage.Client.Features.Customization.State.CustomizationRigOutfitTracker)

return function()
	local template, container

	beforeEach(function()
		template = Instance.new("Model")
		Instance.new("Humanoid").Parent = template
		local root = Instance.new("Part")
		root.Name = "HumanoidRootPart"
		root.Parent = template
		container = Instance.new("Folder")
	end)

	afterEach(function()
		template:Destroy()
		container:Destroy()
	end)

	-- Player stand-in: Players cannot be constructed in a spec.
	local function player(userId)
		return { UserId = userId, Name = `user{userId}`, DisplayName = `User {userId}` }
	end

	-- Acquires across frames, so the one-build-per-frame budget never gets in the way.
	local function acquire(pool, userId)
		ReplicationPuppetPool.beginFrame(pool)
		return ReplicationPuppetPool.acquire(pool, player(userId))
	end

	it("builds a puppet with an outfit assigned to its owner, undressed", function()
		local pool = ReplicationPuppetPool.new(template, container)
		local puppet = acquire(pool, 7)
		expect(puppet).to.be.ok()
		expect(puppet.outfit.ownerUserId).to.equal(7)
		expect(CustomizationRigOutfitTracker.isDressed(puppet.outfit)).to.equal(false)
		expect(puppet.model.Parent).to.equal(container)
		expect(puppet.model.Name).to.equal("user7")
		expect(puppet.humanoid.DisplayName).to.equal("User 7")
	end)

	it("builds at most one puppet per frame", function()
		local pool = ReplicationPuppetPool.new(template, container)
		ReplicationPuppetPool.beginFrame(pool)
		expect(ReplicationPuppetPool.acquire(pool, player(1))).to.be.ok()
		expect(ReplicationPuppetPool.acquire(pool, player(2))).to.equal(nil)
	end)

	it("gives a returning owner their own rig back, still dressed", function()
		local pool = ReplicationPuppetPool.new(template, container)
		local puppet = acquire(pool, 7)
		local other = acquire(pool, 8)
		CustomizationRigOutfitTracker.setWorn(puppet.outfit, CustomizationOutfitDiffUtils.empty(), 3)
		ReplicationPuppetPool.release(pool, other) -- the older idle rig: a spare would be this one, not 7's
		ReplicationPuppetPool.release(pool, puppet)
		local back = acquire(pool, 7)
		expect(back).to.equal(puppet)
		expect(back.outfit.version).to.equal(3)
		expect(pool.affinityHits).to.equal(1)
	end)

	it("hands the least-recently-used spare to a new owner, undressed", function()
		local pool = ReplicationPuppetPool.new(template, container)
		local first = acquire(pool, 1)
		local second = acquire(pool, 2)
		CustomizationRigOutfitTracker.setWorn(first.outfit, CustomizationOutfitDiffUtils.empty(), 1)
		ReplicationPuppetPool.release(pool, first)
		ReplicationPuppetPool.release(pool, second)
		local reused = acquire(pool, 3)
		expect(reused).to.equal(first)
		expect(reused.outfit.ownerUserId).to.equal(3)
		expect(CustomizationRigOutfitTracker.isDressed(reused.outfit)).to.equal(false)
		-- 1's affinity is gone with the rig: they get the remaining spare (or a build), never 3's.
		expect(acquire(pool, 1)).to.equal(second)
	end)

	it("destroys the least-recently-used idle puppet over the cap", function()
		local pool = ReplicationPuppetPool.new(template, container, 2)
		local a, b, c = acquire(pool, 1), acquire(pool, 2), acquire(pool, 3)
		ReplicationPuppetPool.release(pool, a)
		ReplicationPuppetPool.release(pool, b)
		ReplicationPuppetPool.release(pool, c)
		expect(#pool.idle).to.equal(2)
		expect(a.model.Parent).to.equal(nil)
		expect(pool.byOwner[1]).to.equal(nil)
		expect(pool.byOwner[3]).to.equal(c)
	end)

	it("defaults the idle cap to 16", function()
		expect(ReplicationPuppetPool.new(template, container).maxIdle).to.equal(16)
	end)
end
