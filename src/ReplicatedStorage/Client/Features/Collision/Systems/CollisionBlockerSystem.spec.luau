--!strict
--[=[
	Unit tests for CollisionBlockerSystem (R6 spec 2026-10-08 §4, §5): capsule build and weld, the parked-root
	offset, despawn and reuse, the range band with change-only writes, the 10 Hz check, the self-collider,
	and debug view. Real Parts on a fake rig with an anchored root.
]=]

local PhysicsService = game:GetService("PhysicsService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local CollisionConstants = require(ReplicatedStorage.Shared.Features.Collision.Data.CollisionConstants)
local CollisionBlockerSystem = require(script.Parent.CollisionBlockerSystem)

return function()
	local C = CollisionConstants
	local rigs

	beforeAll(function()
		-- CollisionServiceServer registers these in a real session; a test session may not boot services.
		for _, name in { C.PUPPET_GROUP, C.SELF_GROUP } do
			if not PhysicsService:IsCollisionGroupRegistered(name) then
				PhysicsService:RegisterCollisionGroup(name)
			end
		end
	end)

	beforeEach(function()
		rigs = {}
	end)

	afterEach(function()
		for _, model in rigs do
			model:Destroy()
		end
	end)

	local function rig(at)
		local model = Instance.new("Model")
		model.Name = "CollisionSpecRig"
		local root = Instance.new("Part")
		root.Name = "HumanoidRootPart"
		root.Anchored = true
		root.CanCollide = false
		root.Size = Vector3.new(2, 2, 1)
		root.CFrame = at
		root.Parent = model
		model.Parent = Workspace
		table.insert(rigs, model)
		return model, root
	end

	local function capsuleParts(model, group)
		local out = {}
		for _, child in model:GetChildren() do
			if child:IsA("BasePart") and child.CollisionGroup == group then
				table.insert(out, child)
			end
		end
		return out
	end

	it("welds three non-solid, frictionless, query-free parts to a puppet's root", function()
		local state = CollisionBlockerSystem.new(false)
		local model, root = rig(CFrame.new(0, 100, 0))
		expect(CollisionBlockerSystem.addPuppet(state, model)).to.equal(true)
		local parts = capsuleParts(model, C.PUPPET_GROUP)
		expect(#parts).to.equal(3)
		for _, part in parts do
			expect(part.CanCollide).to.equal(false)
			expect(part.CanQuery).to.equal(false)
			expect(part.CanTouch).to.equal(false)
			expect(part.Massless).to.equal(true)
			expect(part.Anchored).to.equal(false)
			expect(part.Transparency).to.equal(1)
			expect(part.CustomPhysicalProperties.Friction).to.equal(0)
			local weld = part:FindFirstChildOfClass("WeldConstraint")
			expect(weld).to.be.ok()
			expect(weld.Part0).to.equal(root)
			expect(weld.Part1).to.equal(part)
		end
		expect(CollisionBlockerSystem.counts(state).puppets).to.equal(1)
	end)

	it("refuses a rig with no root", function()
		local state = CollisionBlockerSystem.new(false)
		local model = Instance.new("Model")
		model.Parent = Workspace
		table.insert(rigs, model)
		expect(CollisionBlockerSystem.addPuppet(state, model)).to.equal(false)
		expect(CollisionBlockerSystem.addSelf(state, model)).to.equal(false)
		expect(#model:GetChildren()).to.equal(0)
	end)

	it("keeps its offset when a root built while parked moves", function()
		local state = CollisionBlockerSystem.new(false)
		local model, root = rig(CFrame.new(0, 50000, 0))
		CollisionBlockerSystem.addPuppet(state, model)
		root.CFrame = CFrame.new(10, 50, -10)
		local tops = 0
		for _, part in capsuleParts(model, C.PUPPET_GROUP) do
			expect(math.abs(part.Position.X - 10) < 0.01).to.equal(true)
			expect(math.abs(part.Position.Z + 10) < 0.01).to.equal(true)
			if math.abs(part.Position.Y - 50 - (C.TOP - C.RADIUS)) < 0.01 then
				tops += 1
			end
		end
		expect(tops).to.equal(1)
	end)

	it("destroys a puppet's capsule on despawn", function()
		local state = CollisionBlockerSystem.new(false)
		local model = rig(CFrame.new(5, 0, 0))
		CollisionBlockerSystem.addPuppet(state, model)
		CollisionBlockerSystem.updateRange(state, Vector3.zero)
		CollisionBlockerSystem.remove(state, model)
		expect(#capsuleParts(model, C.PUPPET_GROUP)).to.equal(0)
		expect(state.puppets[model]).to.equal(nil)
		expect(state.solid[model]).to.equal(nil)
	end)

	it("despawn then spawn on the same model, or adding twice, leaves exactly one capsule", function()
		local state = CollisionBlockerSystem.new(false)
		local model = rig(CFrame.new(5, 0, 0))
		CollisionBlockerSystem.addPuppet(state, model)
		CollisionBlockerSystem.remove(state, model)
		CollisionBlockerSystem.addPuppet(state, model)
		expect(#capsuleParts(model, C.PUPPET_GROUP)).to.equal(3)
		CollisionBlockerSystem.addPuppet(state, model)
		expect(#capsuleParts(model, C.PUPPET_GROUP)).to.equal(3)
	end)

	it("flips solid only when crossing the band, writing CanCollide only on change", function()
		local state = CollisionBlockerSystem.new(false)
		local model, root = rig(CFrame.new(30, 0, 0))
		CollisionBlockerSystem.addPuppet(state, model)
		CollisionBlockerSystem.updateRange(state, Vector3.zero)
		expect(state.writes).to.equal(0)

		root.CFrame = CFrame.new(19, 0, 0)
		CollisionBlockerSystem.updateRange(state, Vector3.zero)
		expect(state.writes).to.equal(1)
		expect(state.solid[model]).to.be.ok()
		for _, part in capsuleParts(model, C.PUPPET_GROUP) do
			expect(part.CanCollide).to.equal(true)
		end

		root.CFrame = CFrame.new(21.5, 0, 0)
		CollisionBlockerSystem.updateRange(state, Vector3.zero)
		CollisionBlockerSystem.updateRange(state, Vector3.zero)
		expect(state.writes).to.equal(1)

		root.CFrame = CFrame.new(23, 0, 0)
		CollisionBlockerSystem.updateRange(state, Vector3.zero)
		expect(state.writes).to.equal(2)
		expect(state.solid[model]).to.equal(nil)
		for _, part in capsuleParts(model, C.PUPPET_GROUP) do
			expect(part.CanCollide).to.equal(false)
		end
	end)

	it("checks the range at most ten times a second", function()
		local state = CollisionBlockerSystem.new(false)
		local model = rig(CFrame.new(10, 0, 0))
		CollisionBlockerSystem.addPuppet(state, model)
		CollisionBlockerSystem.step(state, 0.06, Vector3.zero)
		expect(state.writes).to.equal(0)
		CollisionBlockerSystem.step(state, 0.06, Vector3.zero)
		expect(state.writes).to.equal(1)
	end)

	it("builds the self-collider solid, massless, in the self group, and replaces it on respawn", function()
		local state = CollisionBlockerSystem.new(false)
		local first = rig(CFrame.new(0, 0, 0))
		expect(CollisionBlockerSystem.addSelf(state, first)).to.equal(true)
		local parts = capsuleParts(first, C.SELF_GROUP)
		expect(#parts).to.equal(3)
		for _, part in parts do
			expect(part.CanCollide).to.equal(true)
			expect(part.Massless).to.equal(true)
		end

		local second = rig(CFrame.new(0, 0, 0))
		CollisionBlockerSystem.addSelf(state, second)
		expect(#capsuleParts(first, C.SELF_GROUP)).to.equal(0)
		expect(#capsuleParts(second, C.SELF_GROUP)).to.equal(3)

		CollisionBlockerSystem.remove(state, second)
		expect(state.own).to.equal(nil)
		expect(#capsuleParts(second, C.SELF_GROUP)).to.equal(0)
	end)

	it("debug view shows existing and new capsules and hides them again", function()
		local state = CollisionBlockerSystem.new(false)
		local a = rig(CFrame.new(5, 0, 0))
		CollisionBlockerSystem.addPuppet(state, a)
		CollisionBlockerSystem.setDebug(state, true)
		local b = rig(CFrame.new(8, 0, 0))
		CollisionBlockerSystem.addPuppet(state, b)
		for _, model in { a, b } do
			for _, part in capsuleParts(model, C.PUPPET_GROUP) do
				expect(math.abs(part.Transparency - C.DEBUG_TRANSPARENCY) < 1e-4).to.equal(true)
				expect(math.abs(part.Color.R - C.PUPPET_COLOR.R) < 1e-3).to.equal(true)
				expect(math.abs(part.Color.G - C.PUPPET_COLOR.G) < 1e-3).to.equal(true)
				expect(math.abs(part.Color.B - C.PUPPET_COLOR.B) < 1e-3).to.equal(true)
			end
		end
		CollisionBlockerSystem.setDebug(state, false)
		for _, part in capsuleParts(a, C.PUPPET_GROUP) do
			expect(part.Transparency).to.equal(1)
		end
	end)

	it("clear removes every capsule", function()
		local state = CollisionBlockerSystem.new(false)
		local a = rig(CFrame.new(5, 0, 0))
		local me = rig(CFrame.new(0, 0, 0))
		CollisionBlockerSystem.addPuppet(state, a)
		CollisionBlockerSystem.addSelf(state, me)
		CollisionBlockerSystem.clear(state)
		expect(#capsuleParts(a, C.PUPPET_GROUP)).to.equal(0)
		expect(#capsuleParts(me, C.SELF_GROUP)).to.equal(0)
		expect(CollisionBlockerSystem.counts(state).puppets).to.equal(0)
		expect(state.own).to.equal(nil)
	end)
end
