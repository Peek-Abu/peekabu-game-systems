local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ShiftTimeClockSystem = require(script.Parent.ShiftTimeClockSystem)
local ShiftConstants = require(ReplicatedStorage.Shared.Features.Shift.Data.ShiftConstants)
local InteractionRegistry = require(ReplicatedStorage.Shared.Features.Interaction.Data.InteractionRegistry)

-- A clock facing -Z (into the box) at the origin, and a fake player whose root stands at `offset` in its space.
local function scene(offset)
	local folder = Instance.new("Folder")
	local clock = Instance.new("Part")
	clock.CFrame = CFrame.new(50, 7, 20)
	clock.Parent = folder
	local character = Instance.new("Model")
	local root = Instance.new("Part")
	root.Name = "HumanoidRootPart"
	root.CFrame = clock.CFrame * CFrame.new(offset)
	root.Parent = character
	character.Parent = folder
	return folder, clock, { UserId = 9031, DisplayName = "Clock Spec", Character = character }
end

local function harness(carrying, crew)
	local log = { clockedOut = {} }
	log.system = ShiftTimeClockSystem.new({
		clockOut = function(player)
			table.insert(log.clockedOut, player)
			return true
		end,
		carrying = function()
			return carrying == true
		end,
		eligible = function()
			return crew ~= false
		end,
	})
	return log
end

return function()
	it("registers Clock out as a held prompt with a short reach", function()
		local def = InteractionRegistry.get(ShiftConstants.CLOCK_OUT_KIND)
		expect(def).to.be.ok()
		expect(def.actionText).to.equal("Clock out")
		expect(def.holdDuration).to.equal(ShiftConstants.CLOCK_OUT_HOLD)
		expect(def.maxDistance).to.equal(ShiftConstants.PAPERWORK_DISTANCE)
	end)

	describe("reaches", function()
		it("is true in front of the clock with empty hands", function()
			local folder, clock, player = scene(Vector3.new(0, -1.2, -2.5))
			expect(ShiftTimeClockSystem.reaches(player, clock, false)).to.equal(true)
			folder:Destroy()
		end)

		it("is false while carrying, from outside the reach, or without a character", function()
			local folder, clock, player = scene(Vector3.new(0, -1.2, -2.5))
			expect(ShiftTimeClockSystem.reaches(player, clock, true)).to.equal(false)
			expect(ShiftTimeClockSystem.reaches({ Character = nil }, clock, false)).to.equal(false)
			folder:Destroy()
			local far, farClock, farPlayer = scene(Vector3.new(0, -4, -9))
			expect(ShiftTimeClockSystem.reaches(farPlayer, farClock, false)).to.equal(false)
			far:Destroy()
		end)
	end)

	describe("punch", function()
		it("clocks out a crew member who reaches the clock", function()
			local folder, clock, player = scene(Vector3.new(1, -1, -3))
			local log = harness(false)
			expect(log.system.punch(player, clock)).to.equal(true)
			expect(log.clockedOut[1]).to.equal(player)
			folder:Destroy()
		end)

		it("refuses a crew member carrying cargo, even right at the clock", function()
			local folder, clock, player = scene(Vector3.new(0, -1, -2))
			local log = harness(true)
			expect(log.system.punch(player, clock)).to.equal(false)
			expect(#log.clockedOut).to.equal(0)
			folder:Destroy()
		end)

		it("refuses a player outside the crew, even right at the clock", function()
			local folder, clock, player = scene(Vector3.new(1, -1, -3))
			local log = harness(false, false)
			expect(log.system.punch(player, clock)).to.equal(false)
			expect(#log.clockedOut).to.equal(0)
			folder:Destroy()
		end)

		it("refuses a trigger from beside the ramp, outside the box", function()
			local folder, clock, player = scene(Vector3.new(3, -4, -12))
			local log = harness(false)
			expect(log.system.punch(player, clock)).to.equal(false)
			expect(#log.clockedOut).to.equal(0)
			folder:Destroy()
		end)
	end)
end
