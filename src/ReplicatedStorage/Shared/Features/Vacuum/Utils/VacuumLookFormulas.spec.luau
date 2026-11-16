local ReplicatedStorage = game:GetService("ReplicatedStorage")

local VacuumLookFormulas = require(script.Parent.VacuumLookFormulas)
local VacuumMotionFormulas = require(script.Parent.VacuumMotionFormulas)
local Constants = require(ReplicatedStorage.Shared.Features.Vacuum.Data.VacuumMotionConstants)

return function()
	describe("re-export", function()
		it("is the very same function under VacuumMotionFormulas' old names", function()
			expect(VacuumMotionFormulas.encodeAim).to.equal(VacuumLookFormulas.encodeAim)
			expect(VacuumMotionFormulas.decodeAim).to.equal(VacuumLookFormulas.decodeAim)
			expect(VacuumMotionFormulas.heading).to.equal(VacuumLookFormulas.heading)
			expect(VacuumMotionFormulas.faceToward).to.equal(VacuumLookFormulas.faceToward)
			expect(VacuumMotionFormulas.relativeYaw).to.equal(VacuumLookFormulas.relativeYaw)
			expect(VacuumMotionFormulas.pointerLook).to.equal(VacuumLookFormulas.pointerLook)
			expect(VacuumMotionFormulas.lookHeading).to.equal(VacuumLookFormulas.lookHeading)
			expect(VacuumMotionFormulas.lookDistance).to.equal(VacuumLookFormulas.lookDistance)
			expect(VacuumMotionFormulas.encodeYaw).to.equal(VacuumLookFormulas.encodeYaw)
			expect(VacuumMotionFormulas.decodeYaw).to.equal(VacuumLookFormulas.decodeYaw)
		end)
	end)

	describe("encodeAim / decodeAim", function()
		it("quantises the look pitch to a byte and back, in whole quanta of degrees", function()
			local byte = VacuumLookFormulas.encodeAim(math.rad(-22))
			expect(byte >= 0 and byte <= 36).to.equal(true)
			expect(VacuumLookFormulas.decodeAim(byte)).to.equal(-20)
			expect(VacuumLookFormulas.decodeAim(VacuumLookFormulas.encodeAim(math.rad(90)))).to.equal(90)
			expect(VacuumLookFormulas.decodeAim(VacuumLookFormulas.encodeAim(math.rad(-200)))).to.equal(-90)
		end)

		it("refuses anything that is not a byte the client can send", function()
			expect(VacuumLookFormulas.decodeAim(37)).to.equal(nil)
			expect(VacuumLookFormulas.decodeAim(-1)).to.equal(nil)
			expect(VacuumLookFormulas.decodeAim(2.5)).to.equal(nil)
			expect(VacuumLookFormulas.decodeAim(0 / 0)).to.equal(nil)
		end)
	end)

	describe("encodeYaw / decodeYaw", function()
		it("sends the look yaw as a byte and reads it back in whole quanta, refusing anything else", function()
			local byte = VacuumLookFormulas.encodeYaw(math.rad(23))
			expect(VacuumLookFormulas.decodeYaw(byte)).to.equal(25)
			expect(VacuumLookFormulas.decodeYaw(VacuumLookFormulas.encodeYaw(math.rad(-200)))).to.equal(-60)
			expect(VacuumLookFormulas.decodeYaw(VacuumLookFormulas.encodeYaw(math.rad(200)))).to.equal(60)
			expect(VacuumLookFormulas.decodeYaw(-1)).to.equal(nil)
			expect(VacuumLookFormulas.decodeYaw(25)).to.equal(nil)
			expect(VacuumLookFormulas.decodeYaw(1.5)).to.equal(nil)
		end)
	end)

	describe("heading / wrapAngle / relativeYaw", function()
		it("reads 0 along -Z and left positive", function()
			expect(VacuumLookFormulas.heading(Vector3.new(0, 0, -1))).to.be.near(0, 1e-9)
			expect(VacuumLookFormulas.heading(Vector3.new(-1, 0, 0))).to.be.near(math.pi / 2, 1e-9)
			expect(VacuumLookFormulas.heading(Vector3.new(1, 0, 0))).to.be.near(-math.pi / 2, 1e-9)
		end)

		it("wraps an angle into -pi..pi", function()
			expect(VacuumLookFormulas.wrapAngle(0)).to.be.near(0, 1e-9)
			expect(VacuumLookFormulas.wrapAngle(3 * math.pi / 2)).to.be.near(-math.pi / 2, 1e-9)
			expect(VacuumLookFormulas.wrapAngle(-3 * math.pi / 2)).to.be.near(math.pi / 2, 1e-9)
		end)

		it("measures where the camera looks left (positive) or right of the body", function()
			local body = Vector3.new(0, 0, -1)
			local left = Vector3.new(-1, -0.3, -1).Unit
			local right = Vector3.new(1, 0, -1).Unit
			expect(VacuumLookFormulas.relativeYaw(left, body)).to.be.near(math.rad(45), 1e-4)
			expect(VacuumLookFormulas.relativeYaw(right, body)).to.be.near(math.rad(-45), 1e-4)
			expect(VacuumLookFormulas.relativeYaw(body, body)).to.be.near(0, 1e-6)
		end)

		it("wraps the angle across the back", function()
			local body = Vector3.new(0, 0, -1)
			local behindLeft = Vector3.new(-0.1, 0, 1).Unit
			local yaw = VacuumLookFormulas.relativeYaw(behindLeft, body)
			expect(yaw > math.rad(170) and yaw <= math.pi).to.equal(true)
		end)
	end)

	describe("faceToward", function()
		it("does not move for no time", function()
			expect(VacuumLookFormulas.faceToward(0.3, 1, 0)).to.equal(0.3)
		end)

		it("turns toward the target, never past it and never faster than its most", function()
			local dt = 1 / 60
			local next = VacuumLookFormulas.faceToward(0, 1, dt)
			expect(next > 0 and next <= 1).to.equal(true)
			expect(next <= Constants.face.maxRate * dt + 1e-9).to.equal(true)
		end)
	end)

	describe("pointerLook (P1: the nozzle follows the mouse)", function()
		-- A body at the origin facing -Z, its floor 3 studs below its root; a camera behind and above it.
		local BODY = CFrame.new(0, 3, 0)
		local FLOOR_Y = 0
		local CAMERA = Vector3.new(0, 10, 12)

		it("takes its pitch from the pointer's ray", function()
			local direction = (Vector3.new(0, 0, -8) - CAMERA).Unit
			local pitch = VacuumLookFormulas.pointerLook(CAMERA, direction, BODY, FLOOR_Y)
			expect(pitch).to.be.near(math.asin(direction.Y), 1e-6)
		end)

		it("turns toward where the pointer meets the floor, seen from the body, not from the camera", function()
			local direction = (Vector3.new(-4, 0, -4) - CAMERA).Unit
			local _, yaw = VacuumLookFormulas.pointerLook(CAMERA, direction, BODY, FLOOR_Y)
			expect(yaw).to.be.near(math.rad(45), 1e-4)
			local _, right =
				VacuumLookFormulas.pointerLook(CAMERA, (Vector3.new(3, 0, -3) - CAMERA).Unit, BODY, FLOOR_Y)
			expect(right).to.be.near(math.rad(-45), 1e-4)
		end)

		it("uses the ray's own heading when it never meets the floor (pointing above the horizon)", function()
			local direction = Vector3.new(-1, 0.2, -1).Unit
			local pitch, yaw = VacuumLookFormulas.pointerLook(CAMERA, direction, BODY, FLOOR_Y)
			expect(pitch > 0).to.equal(true)
			expect(yaw).to.be.near(math.rad(45), 1e-4)
		end)
	end)

	describe("lookHeading / lookDistance", function()
		it("keeps the look's heading within its most either way", function()
			local most = Constants.aim.maxLook
			expect(VacuumLookFormulas.lookHeading(math.rad(20))).to.be.near(math.rad(20), 1e-9)
			expect(VacuumLookFormulas.lookHeading(math.rad(80))).to.be.near(most, 1e-9)
			expect(VacuumLookFormulas.lookHeading(math.rad(-80))).to.be.near(-most, 1e-9)
		end)

		it("eases the look back to straight ahead behind the back", function()
			local most = Constants.aim.maxLook
			expect(VacuumLookFormulas.lookHeading(math.pi)).to.be.near(0, 1e-9)
			expect(VacuumLookFormulas.lookHeading(math.rad(135))).to.be.near(most / 2, 1e-6)
		end)

		it("puts the floor look point between near and far, further as the camera looks up", function()
			local tuning = Constants.aim
			expect(VacuumLookFormulas.lookDistance(math.rad(-89))).to.equal(tuning.near)
			expect(VacuumLookFormulas.lookDistance(math.rad(10))).to.equal(tuning.far)
			local low = VacuumLookFormulas.lookDistance(math.rad(-40))
			local high = VacuumLookFormulas.lookDistance(math.rad(-20))
			expect(low > tuning.near and high > low and high < tuning.far).to.equal(true)
		end)
	end)
end
