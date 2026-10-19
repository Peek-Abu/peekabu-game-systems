local ReplicatedStorage = game:GetService("ReplicatedStorage")

local EmployeeRegistry = require(ReplicatedStorage.Shared.Features.Employee.Data.EmployeeRegistry)
local EmployeeLocomotionUtils = require(script.Parent.EmployeeLocomotionUtils)
local CrouchConstants = require(ReplicatedStorage.Shared.Features.Crouch.Data.CrouchConstants)
local CarryConstants = require(ReplicatedStorage.Shared.Features.Carry.Data.CarryConstants)

local function defWith(locomotion, scale)
	local base = EmployeeRegistry.get("Pippa")
	local copy = table.clone(base)
	copy.locomotion = locomotion
	copy.scale = scale or 1
	return copy
end

return function()
	describe("fromDef", function()
		it("maps idle/walk/run to the employee's clips and scales strides by their planted speeds", function()
			local config = EmployeeLocomotionUtils.fromDef(defWith({
				idle = "a",
				walk = "b",
				run = "c",
				walkPlantedSpeed = 1.5,
				runPlantedSpeed = 2,
				minRate = 0.5,
				walkMaxRate = 2.5,
				runMaxRate = 3,
			}))
			expect(config).to.be.ok()
			expect(config.poseIds.idle).to.equal("a")
			expect(config.poseIds.walk).to.equal("b")
			expect(config.poseIds.run).to.equal("c")
			expect(config.walkScale).to.equal(1.5)
			expect(config.runScale).to.equal(2)
			expect(config.minRate).to.equal(0.5)
			expect(config.walkMaxRate).to.equal(2.5)
			expect(config.runMaxRate).to.equal(3)
			-- The walk/run switch stays the base's (no override).
			expect(config.walkRunThreshold).to.equal(nil)
		end)

		it("plants the strides at the employee's scale (longer legs cover more ground per step)", function()
			local config = EmployeeLocomotionUtils.fromDef(defWith({
				idle = "a",
				walk = "b",
				run = "c",
				walkPlantedSpeed = 1.2,
				runPlantedSpeed = 1.6,
				minRate = 0.5,
				walkMaxRate = 2.5,
				runMaxRate = 3,
			}, 1.25))
			expect(config.walkScale).to.be.near(1.5, 1e-6)
			expect(config.runScale).to.be.near(2, 1e-6)
		end)

		it("maps the crouch clips and plants the crouch stride at the employee's scale", function()
			local config = EmployeeLocomotionUtils.fromDef(defWith({
				idle = "a",
				walk = "b",
				run = "c",
				crouchIdle = "d",
				crouchWalk = "e",
				walkPlantedSpeed = 1.2,
				runPlantedSpeed = 1.6,
				crouchWalkPlantedSpeed = 1.3,
				minRate = 0.5,
				walkMaxRate = 2.5,
				runMaxRate = 3,
				crouchWalkMaxRate = 2,
			}, 1.25))
			expect(config.poseIds.crouchidle).to.equal("d")
			expect(config.poseIds.crouchwalk).to.equal("e")
			expect(config.crouchScale).to.be.near(1.625, 1e-6)
			expect(config.crouchMaxRate).to.equal(2)
		end)

		it("leaves the crouch out for an employee without crouch clips (it stays standing)", function()
			local config = EmployeeLocomotionUtils.fromDef(defWith({
				idle = "a",
				walk = "b",
				run = "c",
				walkPlantedSpeed = 1.2,
				runPlantedSpeed = 1.6,
				minRate = 0.5,
				walkMaxRate = 2.5,
				runMaxRate = 3,
			}))
			expect(config.poseIds.crouchidle).to.equal(nil)
			expect(config.poseIds.crouchwalk).to.equal(nil)
			expect(config.crouchScale).to.equal(nil)
		end)

		it("returns nil for an employee without its own locomotion (stock clips)", function()
			expect(EmployeeLocomotionUtils.fromDef(defWith(nil))).to.equal(nil)
		end)
	end)

	describe("forName", function()
		it("resolves Pippa's set from the character attribute value", function()
			local config = EmployeeLocomotionUtils.forName("Pippa")
			expect(config).to.be.ok()
			expect(config.poseIds.walk).to.equal("pippawalk")
			expect(config.poseIds.crouchidle).to.equal("pippacrouchidle")
			expect(config.poseIds.crouchwalk).to.equal("pippacrouchwalk")
		end)

		it("returns nil for a missing, unknown or non-string name", function()
			expect(EmployeeLocomotionUtils.forName(nil)).to.equal(nil)
			expect(EmployeeLocomotionUtils.forName("Nobody")).to.equal(nil)
			expect(EmployeeLocomotionUtils.forName(7)).to.equal(nil)
		end)
	end)

	describe("Pippa's crouch walk", function()
		it("plants at the crouch speed (feet slide under 10 %)", function()
			local config = EmployeeLocomotionUtils.forName("Pippa")
			expect(config).to.be.ok()
			expect(config.crouchScale).to.be.ok()
			expect(config.crouchMaxRate).to.be.ok()
			local planted = config.crouchScale * config.crouchMaxRate
			expect(CrouchConstants.CROUCH_SPEED / planted <= 1.1).to.equal(true)
		end)

		it("keeps a loaded crouch above the minimum rate (no backward slide)", function()
			local config = EmployeeLocomotionUtils.forName("Pippa")
			expect(config).to.be.ok()
			expect(config.crouchScale).to.be.ok()
			-- The slowest any load makes a crouch: Carry's speed floor.
			local slowest = CrouchConstants.CROUCH_SPEED * CarryConstants.MIN_SPEED_MULTIPLIER
			expect(slowest / config.crouchScale >= config.minRate).to.equal(true)
		end)
	end)
end
