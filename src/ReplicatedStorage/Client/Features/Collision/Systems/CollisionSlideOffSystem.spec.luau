--!strict
--[=[
	Unit tests for CollisionSlideOffSystem (R6 spec 2026-10-08 §5 step 2): the push off a head, and the
	cases it leaves alone. "My root" is an anchored Part, so its velocity reads back as written.
]=]

local PhysicsService = game:GetService("PhysicsService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local CollisionConstants = require(ReplicatedStorage.Shared.Features.Collision.Data.CollisionConstants)
local CollisionBlockerSystem = require(ReplicatedStorage.Client.Features.Collision.Systems.CollisionBlockerSystem)
local CollisionSlideOffSystem = require(script.Parent.CollisionSlideOffSystem)

return function()
	local C = CollisionConstants
	local HEAD = C.TOP - C.BOTTOM
	local instances

	beforeAll(function()
		for _, name in { C.PUPPET_GROUP, C.SELF_GROUP } do
			if not PhysicsService:IsCollisionGroupRegistered(name) then
				PhysicsService:RegisterCollisionGroup(name)
			end
		end
	end)

	beforeEach(function()
		instances = {}
	end)

	afterEach(function()
		for _, instance in instances do
			instance:Destroy()
		end
	end)

	local function anchoredRoot(position)
		local model = Instance.new("Model")
		local root = Instance.new("Part")
		root.Name = "HumanoidRootPart"
		root.Anchored = true
		root.CanCollide = false
		root.CFrame = CFrame.new(position)
		root.Parent = model
		model.Parent = Workspace
		table.insert(instances, model)
		return model, root
	end

	-- A solid puppet at `theirs` and my root at `mine` moving at `velocity`.
	local function setup(mine, theirs, velocity, solid)
		local state = CollisionBlockerSystem.new(false)
		local puppet = anchoredRoot(theirs)
		CollisionBlockerSystem.addPuppet(state, puppet)
		if solid then
			CollisionBlockerSystem.updateRange(state, mine)
		end
		local _, me = anchoredRoot(mine)
		me.AssemblyLinearVelocity = velocity
		return state, me
	end

	local function nearVector(a, b)
		return (a - b).Magnitude < 1e-3
	end

	it("pushes my feet off a head outward at the slide-off speed", function()
		local state, me = setup(Vector3.new(1, HEAD, 0), Vector3.zero, Vector3.new(0, -2, 0), true)
		expect(CollisionSlideOffSystem.step(state, me)).to.equal(true)
		expect(nearVector(me.AssemblyLinearVelocity, Vector3.new(12, -2, 0))).to.equal(true)
	end)

	it("leaves a faster outward move alone", function()
		local state, me = setup(Vector3.new(1, HEAD, 0), Vector3.zero, Vector3.new(20, 0, 0), true)
		expect(CollisionSlideOffSystem.step(state, me)).to.equal(true)
		expect(nearVector(me.AssemblyLinearVelocity, Vector3.new(20, 0, 0))).to.equal(true)
	end)

	it("ignores a player standing beside me", function()
		local state, me = setup(Vector3.new(1.5, 0, 0), Vector3.zero, Vector3.new(0, 0, -3), true)
		expect(CollisionSlideOffSystem.step(state, me)).to.equal(false)
		expect(nearVector(me.AssemblyLinearVelocity, Vector3.new(0, 0, -3))).to.equal(true)
	end)

	it("ignores me while rising", function()
		local state, me = setup(Vector3.new(1, HEAD, 0), Vector3.zero, Vector3.new(0, 5, 0), true)
		expect(CollisionSlideOffSystem.step(state, me)).to.equal(false)
		expect(nearVector(me.AssemblyLinearVelocity, Vector3.new(0, 5, 0))).to.equal(true)
	end)

	it("ignores a puppet that isn't solid", function()
		local state, me = setup(Vector3.new(1, HEAD, 0), Vector3.zero, Vector3.new(0, -2, 0), false)
		expect(CollisionSlideOffSystem.step(state, me)).to.equal(false)
		expect(nearVector(me.AssemblyLinearVelocity, Vector3.new(0, -2, 0))).to.equal(true)
	end)
end
