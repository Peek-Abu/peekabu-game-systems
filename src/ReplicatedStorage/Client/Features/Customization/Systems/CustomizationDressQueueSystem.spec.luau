--!strict
--[=[
	Unit tests for CustomizationDressQueueSystem — newest-wins jobs, stale drops, the frame budget. The dress callback
	is a recorder, so no Instances are mutated.
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CustomizationClient = ReplicatedStorage.Client.Features.Customization
local CustomizationDressQueueSystem = require(CustomizationClient.Systems.CustomizationDressQueueSystem)
local CustomizationOutfitDiffUtils = require(CustomizationClient.Utils.CustomizationOutfitDiffUtils)
local CustomizationRigOutfitTracker = require(CustomizationClient.State.CustomizationRigOutfitTracker)

return function()
	local models = {}

	afterEach(function()
		for _, model in models do
			model:Destroy()
		end
		table.clear(models)
	end)

	local function outfitFor(owner)
		local model = Instance.new("Model")
		table.insert(models, model)
		local outfit = CustomizationRigOutfitTracker.new(model)
		CustomizationRigOutfitTracker.assign(outfit, owner)
		return outfit
	end

	local function look(hairId)
		return CustomizationOutfitDiffUtils.target({
			cosmetics = { hair = { id = hairId, colors = {} } },
			accessories = {},
			body = {},
			headType = "Uncovered",
			surfaces = {},
		})
	end

	local function recorder()
		local calls = {}
		local function dress(outfit, ops)
			table.insert(calls, { outfit = outfit, ops = ops })
		end
		return calls, dress
	end

	it("dresses a rig and records the target as worn", function()
		local queue = CustomizationDressQueueSystem.new()
		local outfit = outfitFor(1)
		local target = look("Hair10")
		CustomizationDressQueueSystem.request(queue, outfit, 1, 1, target)
		local calls, dress = recorder()
		expect(CustomizationDressQueueSystem.step(queue, dress)).to.equal(1)
		expect(#calls).to.equal(1)
		expect(outfit.worn).to.equal(target)
		expect(outfit.version).to.equal(1)
		expect(CustomizationRigOutfitTracker.isDressed(outfit)).to.equal(true)
	end)

	-- The stale-job race (spec Section 4): a second change lands before the first ran.
	it("dresses once, to the newest version, when a change arrives before the job ran", function()
		local queue = CustomizationDressQueueSystem.new()
		local outfit = outfitFor(1)
		CustomizationDressQueueSystem.request(queue, outfit, 1, 1, look("Hair10"))
		local second = look("Hair11")
		CustomizationDressQueueSystem.request(queue, outfit, 1, 2, second)
		local calls, dress = recorder()
		CustomizationDressQueueSystem.step(queue, dress)
		expect(#calls).to.equal(1)
		expect(calls[1].ops[1].mount.id).to.equal("Hair11")
		expect(outfit.version).to.equal(2)
		expect(CustomizationDressQueueSystem.size(queue)).to.equal(0)
	end)

	it("ignores an older or equal version", function()
		local queue = CustomizationDressQueueSystem.new()
		local outfit = outfitFor(1)
		CustomizationDressQueueSystem.request(queue, outfit, 1, 3, look("Hair10"))
		CustomizationDressQueueSystem.request(queue, outfit, 1, 2, look("Hair11"))
		expect(CustomizationDressQueueSystem.pendingVersion(queue, outfit)).to.equal(3)
		local _, dress = recorder()
		CustomizationDressQueueSystem.step(queue, dress)
		CustomizationDressQueueSystem.request(queue, outfit, 1, 3, look("Hair11"))
		expect(CustomizationDressQueueSystem.size(queue)).to.equal(0)
	end)

	it("drops a job whose rig changed hands before it ran", function()
		local queue = CustomizationDressQueueSystem.new()
		local outfit = outfitFor(1)
		CustomizationDressQueueSystem.request(queue, outfit, 1, 1, look("Hair10"))
		CustomizationRigOutfitTracker.assign(outfit, 2)
		local calls, dress = recorder()
		CustomizationDressQueueSystem.step(queue, dress)
		expect(#calls).to.equal(0)
		expect(queue.dropped).to.equal(1)
		expect(CustomizationRigOutfitTracker.isDressed(outfit)).to.equal(false)
	end)

	it("computes the diff when the job runs, against what the rig wears then", function()
		local queue = CustomizationDressQueueSystem.new()
		local outfit = outfitFor(1)
		local calls, dress = recorder()
		CustomizationDressQueueSystem.request(queue, outfit, 1, 1, look("Hair10"))
		CustomizationDressQueueSystem.step(queue, dress)
		CustomizationDressQueueSystem.request(queue, outfit, 1, 2, look("Hair11"))
		CustomizationDressQueueSystem.step(queue, dress)
		local ops = calls[2].ops
		expect(ops[1].kind).to.equal("removeCosmetic")
		expect(ops[2].kind).to.equal("addCosmetic")
	end)

	it("cancel forgets a rig's pending job", function()
		local queue = CustomizationDressQueueSystem.new()
		local outfit = outfitFor(1)
		CustomizationDressQueueSystem.request(queue, outfit, 1, 1, look("Hair10"))
		CustomizationDressQueueSystem.cancel(queue, outfit)
		expect(CustomizationDressQueueSystem.size(queue)).to.equal(0)
		expect(CustomizationDressQueueSystem.pendingVersion(queue, outfit)).to.equal(nil)
	end)

	it("stops at the budget but always makes progress", function()
		local queue = CustomizationDressQueueSystem.new(2)
		for owner = 1, 5 do
			CustomizationDressQueueSystem.request(queue, outfitFor(owner), owner, 1, look("Hair10"))
		end
		-- Every clock read advances 1 ms: the first job always runs, the budget stops the rest.
		local t = 0
		local function clock()
			t += 0.001
			return t
		end
		local _, dress = recorder()
		expect(CustomizationDressQueueSystem.step(queue, dress, clock)).to.equal(2)
		expect(CustomizationDressQueueSystem.size(queue)).to.equal(3)
		-- A frame whose first job alone blows the budget still runs that one.
		local function slow()
			t += 1
			return t
		end
		expect(CustomizationDressQueueSystem.step(queue, dress, slow)).to.equal(1)
	end)

	it("keeps request order across rigs", function()
		local queue = CustomizationDressQueueSystem.new()
		local first, second = outfitFor(1), outfitFor(2)
		CustomizationDressQueueSystem.request(queue, first, 1, 1, look("Hair10"))
		CustomizationDressQueueSystem.request(queue, second, 2, 1, look("Hair10"))
		CustomizationDressQueueSystem.request(queue, first, 1, 2, look("Hair11")) -- replaces in place, keeps its turn
		local calls, dress = recorder()
		CustomizationDressQueueSystem.step(queue, dress)
		expect(calls[1].outfit).to.equal(first)
		expect(calls[2].outfit).to.equal(second)
	end)
end
