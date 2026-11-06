local ServerScriptService = game:GetService("ServerScriptService")

local OccupantStageSystem = require(script.Parent.OccupantStageSystem)
local OccupantBrainRules = require(ServerScriptService.Features.Occupant.Rules.OccupantBrainRules)

-- A stand-in rig: a model whose root sits 4.6 above the floor, with a 2 x 2 x 1 root.
local function makeRig()
	local model = Instance.new("Model")
	local root = Instance.new("Part")
	root.Name = "HumanoidRootPart"
	root.Size = Vector3.new(2, 2, 1)
	root.Anchored = true
	root.CFrame = CFrame.new(50, 4.6, 50)
	root.Parent = model
	model.PrimaryPart = root
	local humanoid = Instance.new("Humanoid")
	humanoid.HipHeight = 3.6
	humanoid.Parent = model
	return { model = model, root = root, humanoid = humanoid, head = root }
end

local function makeCaller(position)
	local part = Instance.new("Part")
	part.Size = Vector3.new(2, 2, 1)
	part.CFrame = CFrame.lookAt(position, position + Vector3.new(1, 0, 0))
	return part
end

local function request(rig, action, extra)
	local value = {
		rig = rig,
		mind = OccupantBrainRules.newMind(1, 1, 0),
		caller = makeCaller(Vector3.new(10, 2.2, 10)),
		callerHip = 1.2,
		action = action,
	}
	for key, item in extra or {} do
		value[key] = item
	end
	return value
end

return function()
	describe("OccupantStageSystem", function()
		local rig

		beforeEach(function()
			OccupantStageSystem.reset()
			rig = makeRig()
		end)

		afterEach(function()
			OccupantStageSystem.reset()
			rig.model:Destroy()
		end)

		it("is unstaged until told", function()
			expect(OccupantStageSystem.intent(Vector3.zero)).to.equal(nil)
			expect(OccupantStageSystem.takeChase()).to.equal(nil)
		end)

		it("freezes and frees him", function()
			local ok = OccupantStageSystem.command(request(rig, "freeze"))
			expect(ok).to.equal(true)
			expect(OccupantStageSystem.intent(Vector3.zero).kind).to.equal("idle")
			OccupantStageSystem.command(request(rig, "free"))
			expect(OccupantStageSystem.intent(Vector3.zero)).to.equal(nil)
		end)

		it("sends him walking or running to the caller", function()
			OccupantStageSystem.command(request(rig, "rush"))
			local intent = OccupantStageSystem.intent(Vector3.new(50, 4.6, 50))
			expect(intent.kind).to.equal("goTo")
			expect(intent.run).to.equal(true)
			expect(intent.position).to.equal(Vector3.new(10, 2.2, 10))
		end)

		it("moves him onto the caller's floor and freezes him", function()
			OccupantStageSystem.command(request(rig, "here"))
			-- The caller's feet: 2.2 - 1.2 - 1 = 0; his root 3.6 + 1 above them.
			expect((rig.root.Position - Vector3.new(10, 4.6, 10)).Magnitude < 1e-3).to.equal(true)
			expect(OccupantStageSystem.intent(rig.root.Position).kind).to.equal("idle")
		end)

		it("queues a chase once, and needs a player for it", function()
			local ok = OccupantStageSystem.command(request(rig, "chase"))
			expect(ok).to.equal(false)
			OccupantStageSystem.command(request(rig, "freeze"))
			ok = OccupantStageSystem.command(request(rig, "chase", { target = { UserId = 7, DisplayName = "Runner" } }))
			expect(ok).to.equal(true)
			expect(OccupantStageSystem.intent(Vector3.zero)).to.equal(nil)
			expect(OccupantStageSystem.takeChase()).to.equal(7)
			expect(OccupantStageSystem.takeChase()).to.equal(nil)
		end)

		it("calms him with a new mind and unstages him", function()
			OccupantStageSystem.command(request(rig, "freeze"))
			local ok, _, nextMind = OccupantStageSystem.command(request(rig, "calm"))
			expect(ok).to.equal(true)
			expect(nextMind).to.be.ok()
			expect(OccupantStageSystem.intent(Vector3.zero)).to.equal(nil)
		end)
	end)
end
