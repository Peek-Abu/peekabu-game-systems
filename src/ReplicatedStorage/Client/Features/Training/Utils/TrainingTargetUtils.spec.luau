local ReplicatedStorage = game:GetService("ReplicatedStorage")

local TrainingConstants = require(ReplicatedStorage.Shared.Features.Training.Data.TrainingConstants)
local TrainingTargetUtils = require(ReplicatedStorage.Client.Features.Training.Utils.TrainingTargetUtils)

return function()
	local function part(parent: Instance?, position: Vector3?, size: Vector3?)
		local made = Instance.new("Part")
		made.Position = position or Vector3.zero
		made.Size = size or Vector3.new(4, 4, 4)
		made.Parent = parent
		return made
	end

	local function mark(target: Instance, role: string, stopNumber: number?)
		target:SetAttribute(TrainingConstants.ROLE_ATTRIBUTE, role)
		if stopNumber ~= nil then
			target:SetAttribute(TrainingConstants.STOP_ATTRIBUTE, stopNumber)
		end
	end

	describe("marked", function()
		it("finds the map's parts with a role, and only the given stop's when one is named", function()
			local map = Instance.new("Model")
			local door1 = part(map)
			mark(door1, "door", 1)
			local door2 = part(map)
			mark(door2, "door", 2)
			local zone1 = part(map)
			mark(zone1, "zone", 1)

			expect(#TrainingTargetUtils.marked(map, "door")).to.equal(2)
			local found = TrainingTargetUtils.marked(map, "door", 2)
			expect(#found).to.equal(1)
			expect(found[1]).to.equal(door2)
			expect(#TrainingTargetUtils.marked(map, "zone", 2)).to.equal(0)
			map:Destroy()
		end)
	end)

	describe("inside", function()
		it("counts a point in the box, with 4 studs of headroom above and below", function()
			local box = part(nil, Vector3.zero, Vector3.new(4, 4, 4))
			expect(TrainingTargetUtils.inside(box, Vector3.new(1, 0, 1))).to.equal(true)
			expect(TrainingTargetUtils.inside(box, Vector3.new(0, 5, 0))).to.equal(true)
			expect(TrainingTargetUtils.inside(box, Vector3.new(0, 7, 0))).to.equal(false)
			expect(TrainingTargetUtils.inside(box, Vector3.new(3, 0, 0))).to.equal(false)
			box:Destroy()
		end)
	end)

	describe("nearest", function()
		it("picks the closest part, nil for none", function()
			local near = part(nil, Vector3.new(2, 0, 0))
			local far = part(nil, Vector3.new(20, 0, 0))
			expect(TrainingTargetUtils.nearest({ far, near }, Vector3.zero)).to.equal(near)
			expect(TrainingTargetUtils.nearest({}, Vector3.zero)).to.equal(nil)
			near:Destroy()
			far:Destroy()
		end)
	end)

	describe("isTreasureKind", function()
		it("is true only for a salvage cargo id", function()
			expect(TrainingTargetUtils.isTreasureKind("monitor")).to.equal(true)
			expect(TrainingTargetUtils.isTreasureKind("noSuchCargo")).to.equal(false)
			expect(TrainingTargetUtils.isTreasureKind(nil)).to.equal(false)
			expect(TrainingTargetUtils.isTreasureKind(7)).to.equal(false)
		end)
	end)

	describe("doorOpen", function()
		it("is true once one of the stop's doors is marked open", function()
			local map = Instance.new("Model")
			local door = part(map)
			mark(door, "door", 3)
			expect(TrainingTargetUtils.doorOpen(map, 3)).to.equal(false)
			door:SetAttribute("TrainingOpen", true)
			expect(TrainingTargetUtils.doorOpen(map, 3)).to.equal(true)
			expect(TrainingTargetUtils.doorOpen(map, 4)).to.equal(false)
			map:Destroy()
		end)
	end)

	describe("truckBed", function()
		it("is the Truck's TruckBed part, nil without one", function()
			local map = Instance.new("Model")
			expect(TrainingTargetUtils.truckBed(map)).to.equal(nil)
			local truck = Instance.new("Model")
			truck.Name = "Truck"
			truck.Parent = map
			local bed = part(truck)
			bed.Name = "TruckBed"
			expect(TrainingTargetUtils.truckBed(map)).to.equal(bed)
			map:Destroy()
		end)
	end)
end
