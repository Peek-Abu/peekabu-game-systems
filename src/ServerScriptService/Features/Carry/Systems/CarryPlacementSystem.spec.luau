local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")
local CarryConstants = require(ReplicatedStorage.Shared.Features.Carry.Data.CarryConstants)
local Placement = require(ServerScriptService.Features.Carry.Systems.CarryPlacementSystem)
return function()
	-- Far from the play area: a room whose floor top is at y = 1000, a 1-stud wall at z = -5 (its inner face at
	-- z = -4.5), and the ground outside (another structure) at the same height beyond it.
	local BASE = Vector3.new(5000, 1000, 5000)
	local building, outside
	local function block(name, parent, centre, size)
		local part = Instance.new("Part")
		part.Name = name
		part.Anchored = true
		part.Size = size
		part.Position = BASE + centre
		part.Parent = parent
		return part
	end
	beforeEach(function()
		building = Instance.new("Model")
		building.Name = "SpecBuilding"
		block("Floor", building, Vector3.new(0, -0.5, 0), Vector3.new(20, 1, 9))
		block("Wall", building, Vector3.new(0, 6, -5), Vector3.new(20, 12, 1))
		-- A query-only volume (a safe zone) is not a wall.
		local zone = block("Zone", building, Vector3.new(0, 3, -2), Vector3.new(20, 6, 1))
		zone.CanCollide = false
		building.Parent = Workspace
		outside = Instance.new("Model")
		outside.Name = "SpecOutside"
		block("Ground", outside, Vector3.new(0, -0.5, -15), Vector3.new(20, 1, 19))
		outside.Parent = Workspace
	end)
	afterEach(function()
		building:Destroy()
		outside:Destroy()
	end)

	describe("safePoint", function()
		local origin = BASE + Vector3.new(0, 1.5, 0)
		it("keeps a clear target", function()
			local target = BASE + Vector3.new(0, 1.5, -3)
			expect((Placement.safePoint(origin, target, {}, 0.5) - target).Magnitude < 1e-3).to.equal(true)
		end)

		it("stops a target past the wall inside it, short by the margin", function()
			local point = Placement.safePoint(origin, BASE + Vector3.new(0, 1.5, -8), {}, 0.5)
			expect(point.Z - BASE.Z).to.be.near(-4, 1e-3)
		end)

		it("falls back towards the origin when the target has no floor of the origin's building", function()
			-- The floor ends at x = 10: past it is nothing (or someone else's ground).
			local point = Placement.safePoint(origin, BASE + Vector3.new(14, 1.5, 0), {}, 0.5)
			expect(point.X - BASE.X <= 10).to.equal(true)
		end)
	end)

	describe("reaches", function()
		local origin = BASE + Vector3.new(0, 1.5, 0)
		it("accepts a target in clear sight over the origin's floor", function()
			expect(Placement.reaches(origin, BASE + Vector3.new(3, 1.5, -2), {}, 0.5)).to.equal(true)
		end)

		it("refuses a target past the wall, or within the margin of it", function()
			expect(Placement.reaches(origin, BASE + Vector3.new(0, 1.5, -8), {}, 0.5)).to.equal(false)
			expect(Placement.reaches(origin, BASE + Vector3.new(0, 1.5, -4.2), {}, 0.5)).to.equal(false)
		end)

		it("refuses a target off the origin's building floor", function()
			expect(Placement.reaches(origin, BASE + Vector3.new(14, 1.5, 0), {}, 0.5)).to.equal(false)
		end)
	end)

	describe("floorNear", function()
		it("stands a spawned object on the building's floor, never beyond the wall", function()
			local floor = Placement.floorNear(BASE + Vector3.new(0, 1.5, -3), BASE + Vector3.new(0, 1.5, -7), {}, 0.6)
			expect(floor.Position.Y - BASE.Y).to.be.near(0, 1e-3)
			expect(floor.Position.Z - BASE.Z > -4.5).to.equal(true)
		end)
	end)

	describe("ignoreFor", function()
		it("looks through the object being placed and every character", function()
			local target = Instance.new("Part")
			local ignore = Placement.ignoreFor(target)
			expect(ignore[1]).to.equal(target)
			local characters = 0
			for _, player in Players:GetPlayers() do
				if player.Character ~= nil then
					characters += 1
					expect(table.find(ignore, player.Character) ~= nil).to.equal(true)
				end
			end
			expect(#ignore).to.equal(1 + characters)
			target:Destroy()
		end)
	end)

	describe("marginFor", function()
		it("is a part's larger horizontal half-extent plus the wall margin", function()
			local part = Instance.new("Part")
			part.Size = Vector3.new(4, 9, 2)
			expect(Placement.marginFor(part)).to.be.near(2 + CarryConstants.WALL_MARGIN, 1e-6)
			part:Destroy()
		end)

		it("uses a model's extents", function()
			local model = Instance.new("Model")
			local part = Instance.new("Part")
			part.Size = Vector3.new(1, 1, 6)
			part.Parent = model
			expect(Placement.marginFor(model)).to.be.near(3 + CarryConstants.WALL_MARGIN, 1e-3)
			model:Destroy()
		end)
	end)

	describe("placeInside", function()
		local origin = BASE + Vector3.new(0, 1.5, 0)
		it("leaves a clear placement where it is asked to be", function()
			local part = block("Placed", building, Vector3.new(0, 1.5, -3), Vector3.new(1, 1, 1))
			local desired = CFrame.new(BASE + Vector3.new(0, 1.5, -3)) * CFrame.Angles(0, math.rad(30), 0)
			part.CFrame = desired
			Placement.placeInside(origin, part, desired)
			expect((part.Position - desired.Position).Magnitude < 1e-3).to.equal(true)
		end)

		it("pulls a placement through the wall back inside, keeping its rotation", function()
			local part = block("Placed", building, Vector3.new(0, 1.5, -8), Vector3.new(1, 1, 1))
			local desired = CFrame.new(BASE + Vector3.new(0, 1.5, -8)) * CFrame.Angles(0, math.rad(30), 0)
			Placement.placeInside(origin, part, desired)
			expect(part.Position.Z - BASE.Z > -4.5).to.equal(true)
			expect(part.CFrame.LookVector:Dot(desired.LookVector)).to.be.near(1, 1e-4)
		end)
	end)

	describe("guard", function()
		it("pulls a part that crossed the wall back inside and stops its motion into the wall", function()
			local part = block("Thrown", Workspace, Vector3.new(0, 2, -3), Vector3.new(1, 1, 1))
			part.Anchored = false
			local guard = Placement.guard(part, {}, 0.6)
			expect(guard.step()).to.equal(true)
			-- One frame later it is past the wall (no yield in between, so physics does not move it).
			part.Position = BASE + Vector3.new(0, 2, -7)
			part.AssemblyLinearVelocity = Vector3.new(0, 0, -40)
			expect(guard.step()).to.equal(true)
			expect(part.Position.Z - BASE.Z).to.be.near(-3.9, 1e-3)
			expect(part.AssemblyLinearVelocity.Z >= 0).to.equal(true)
			part:Destroy()
		end)

		it("is done once the part is anchored or gone", function()
			local part = block("Resting", Workspace, Vector3.new(0, 2, -3), Vector3.new(1, 1, 1))
			local guard = Placement.guard(part, {}, 0.6)
			expect(guard.step()).to.equal(false)
			part:Destroy()
		end)
	end)
end
