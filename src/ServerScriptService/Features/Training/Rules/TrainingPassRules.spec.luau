local ReplicatedStorage = game:GetService("ReplicatedStorage")

local TrainingConstants = require(ReplicatedStorage.Shared.Features.Training.Data.TrainingConstants)
local TrainingPassRules = require(script.Parent.TrainingPassRules)

local PASS = TrainingConstants.PASS

-- In through the STAFF door, along the room, out through the exit door.
local LANE = {
	Vector3.new(10, 0, 0),
	Vector3.new(0, 0, 0),
	Vector3.new(-10, 0, 0),
	Vector3.new(-20, 0, 0),
	Vector3.new(-30, 0, 0),
}

local function sense(fields)
	local s = { now = 0, arrived = false, spotted = false, hunting = false, missing = false, player = nil }
	for key, value in fields or {} do
		s[key] = value
	end
	return s
end

local function kinds(commands)
	local list = {}
	for _, command in commands do
		table.insert(list, command.kind)
	end
	return table.concat(list, ",")
end

-- A pass that has opened the STAFF door and walked in to lane point 1.
local function walking()
	local pass = TrainingPassRules.new()
	TrainingPassRules.begin(pass, 0)
	TrainingPassRules.step(pass, sense({ now = PASS.enter }), LANE)
	return pass
end

return function()
	describe("begin", function()
		it("opens the STAFF door and waits a beat before he comes in", function()
			local pass = TrainingPassRules.new()
			expect(pass.phase).to.equal("offstage")
			expect(kinds(TrainingPassRules.begin(pass, 5))).to.equal("openStaff")
			expect(kinds(TrainingPassRules.step(pass, sense({ now = 5 + PASS.enter / 2 }), LANE))).to.equal("")
			local commands = TrainingPassRules.step(pass, sense({ now = 5 + PASS.enter }), LANE)
			expect(kinds(commands)).to.equal("walk")
			expect(commands[1].position).to.equal(LANE[1])
		end)

		it("does nothing once a pass is under way", function()
			local pass = walking()
			expect(kinds(TrainingPassRules.begin(pass, 10))).to.equal("")
		end)
	end)

	describe("walking the lane", function()
		it("walks to the next point when he arrives", function()
			local pass = walking()
			local commands = TrainingPassRules.step(pass, sense({ now = 3, arrived = true, player = LANE[4] }), LANE)
			expect(kinds(commands)).to.equal("walk")
			expect(commands[1].position).to.equal(LANE[2])
		end)

		it("waits while he is still walking", function()
			local pass = walking()
			expect(kinds(TrainingPassRules.step(pass, sense({ now = 3 }), LANE))).to.equal("")
		end)

		it("stops at the lane point nearest the player, turns to face them, then walks on", function()
			local pass = walking()
			local player = Vector3.new(0, 0, 6)
			TrainingPassRules.step(pass, sense({ now = 3, arrived = true, player = player }), LANE)
			local commands = TrainingPassRules.step(pass, sense({ now = 4, arrived = true, player = player }), LANE)
			expect(kinds(commands)).to.equal("face")
			expect(commands[1].position).to.equal(player)
			expect(pass.phase).to.equal("pause")
			expect(kinds(TrainingPassRules.step(pass, sense({ now = 4 + PASS.pause / 2, player = player }), LANE))).to.equal(
				""
			)
			local on = TrainingPassRules.step(pass, sense({ now = 4 + PASS.pause, player = player }), LANE)
			expect(kinds(on)).to.equal("walk")
			expect(on[1].position).to.equal(LANE[3])
		end)

		it("stops only once a pass", function()
			local pass = walking()
			local player = Vector3.new(0, 0, 6)
			TrainingPassRules.step(pass, sense({ now = 3, arrived = true, player = player }), LANE)
			TrainingPassRules.step(pass, sense({ now = 4, arrived = true, player = player }), LANE)
			TrainingPassRules.step(pass, sense({ now = 4 + PASS.pause, player = player }), LANE)
			local commands = TrainingPassRules.step(pass, sense({ now = 9, arrived = true, player = player }), LANE)
			expect(kinds(commands)).to.equal("walk")
		end)

		it("opens his exit door as he heads out, and shuts it behind him", function()
			local pass = walking()
			pass.at = #LANE - 1
			pass.paused = true
			local out = TrainingPassRules.step(pass, sense({ now = 10, arrived = true }), LANE)
			expect(kinds(out)).to.equal("openExit,walk")
			expect(out[2].position).to.equal(LANE[#LANE])
			expect(kinds(TrainingPassRules.step(pass, sense({ now = 12, arrived = true }), LANE))).to.equal("closeExit")
			expect(pass.phase).to.equal("closing")
		end)
	end)

	describe("gone", function()
		local function leave(pass, now)
			pass.at = #LANE
			pass.paused = true
			TrainingPassRules.step(pass, sense({ now = now, arrived = true }), LANE)
			return TrainingPassRules.step(pass, sense({ now = now + PASS.slam }), LANE)
		end

		it("parks him offstage and shuts the STAFF door once his exit door has shut", function()
			local pass = walking()
			expect(kinds(leave(pass, 20))).to.equal("park,closeStaff")
			expect(pass.phase).to.equal("gone")
		end)

		it("is a clean pass (the stop is done) only when he caught nobody", function()
			local pass = walking()
			leave(pass, 20)
			expect(TrainingPassRules.clean(pass)).to.equal(true)
			local caught = walking()
			TrainingPassRules.caught(caught)
			leave(caught, 20)
			expect(TrainingPassRules.clean(caught)).to.equal(false)
		end)

		it("after a catch, comes round again once he has gone", function()
			local pass = walking()
			TrainingPassRules.caught(pass)
			leave(pass, 20)
			expect(kinds(TrainingPassRules.step(pass, sense({ now = 20 + PASS.slam + PASS.retry / 2 }), LANE))).to.equal(
				""
			)
			local again = TrainingPassRules.step(pass, sense({ now = 20 + PASS.slam + PASS.retry }), LANE)
			expect(kinds(again)).to.equal("openStaff")
			expect(pass.phase).to.equal("opening")
			expect(pass.caught).to.equal(false)
			expect(pass.paused).to.equal(false)
		end)

		it("stays gone after a clean pass", function()
			local pass = walking()
			leave(pass, 20)
			expect(kinds(TrainingPassRules.step(pass, sense({ now = 99 }), LANE))).to.equal("")
		end)
	end)

	describe("missing", function()
		it("ends the pass if he stays missing, so nobody is stuck", function()
			local pass = walking()
			expect(kinds(TrainingPassRules.step(pass, sense({ now = 3, missing = true }), LANE))).to.equal("")
			expect(kinds(TrainingPassRules.step(pass, sense({ now = 3 + PASS.absent / 2, missing = true }), LANE))).to.equal(
				""
			)
			expect(kinds(TrainingPassRules.step(pass, sense({ now = 3 + PASS.absent, missing = true }), LANE))).to.equal(
				"closeStaff"
			)
			expect(TrainingPassRules.clean(pass)).to.equal(true)
		end)

		it("counts again from zero once he is back", function()
			local pass = walking()
			TrainingPassRules.step(pass, sense({ now = 3, missing = true }), LANE)
			TrainingPassRules.step(pass, sense({ now = 4 }), LANE)
			TrainingPassRules.step(pass, sense({ now = 5, missing = true }), LANE)
			expect(pass.phase).never.to.equal("gone")
			expect(kinds(TrainingPassRules.step(pass, sense({ now = 3 + PASS.absent, missing = true }), LANE))).to.equal(
				""
			)
		end)
	end)

	describe("spotted in the open", function()
		it("chases the player for real", function()
			local pass = walking()
			expect(kinds(TrainingPassRules.step(pass, sense({ now = 3, spotted = true }), LANE))).to.equal("chase")
			expect(pass.phase).to.equal("chase")
		end)

		it("chases from a pause too", function()
			local pass = walking()
			pass.phase = "pause"
			pass.since = 3
			expect(kinds(TrainingPassRules.step(pass, sense({ now = 3.5, spotted = true }), LANE))).to.equal("chase")
		end)

		it("never chases while the doors play (he is not in the room)", function()
			local pass = TrainingPassRules.new()
			TrainingPassRules.begin(pass, 0)
			expect(kinds(TrainingPassRules.step(pass, sense({ now = 0.1, spotted = true }), LANE))).to.equal("")
		end)

		it("once he has stopped hunting a while, walks straight out", function()
			local pass = walking()
			TrainingPassRules.step(pass, sense({ now = 3, spotted = true }), LANE)
			expect(kinds(TrainingPassRules.step(pass, sense({ now = 5, hunting = true }), LANE))).to.equal("")
			expect(kinds(TrainingPassRules.step(pass, sense({ now = 6 }), LANE))).to.equal("")
			local out = TrainingPassRules.step(pass, sense({ now = 6 + PASS.calm }), LANE)
			expect(kinds(out)).to.equal("walk")
			expect(out[1].position).to.equal(LANE[#LANE - 1])
			expect(pass.phase).to.equal("walk")
			expect(pass.paused).to.equal(true)
		end)

		it("a hunt that starts again resets the calm count", function()
			local pass = walking()
			TrainingPassRules.step(pass, sense({ now = 3, spotted = true }), LANE)
			TrainingPassRules.step(pass, sense({ now = 4 }), LANE)
			TrainingPassRules.step(pass, sense({ now = 4.5, hunting = true }), LANE)
			expect(kinds(TrainingPassRules.step(pass, sense({ now = 4 + PASS.calm + 0.1 }), LANE))).to.equal("")
		end)
	end)
end
