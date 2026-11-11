local ServerScriptService = game:GetService("ServerScriptService")

local DepotHubRules = require(script.Parent.DepotHubRules)
local DepotLayoutConstants = require(ServerScriptService.Features.Depot.Data.DepotLayoutConstants)

local FLIP = CFrame.Angles(0, math.pi, 0)

local function near(a, b)
	return (a.Position - b.Position).Magnitude < 1e-3 and a.LookVector:Dot(b.LookVector) > 0.999
end

-- A small valid authored hub: three bays, two spawns, the two required boards.
local function markers()
	return {
		{ kind = "truck", cframe = CFrame.new(20, 0, 48), truck = 2 },
		{ kind = "truck", cframe = CFrame.new(0, 0, 48), truck = 1, capacity = 4, countdown = 10 },
		{ kind = "truck", cframe = CFrame.new(40, 0, 48), truck = 3 },
		{ kind = "spawn", cframe = CFrame.new(10, 0, 20) },
		{ kind = "spawn", cframe = CFrame.new(30, 0, 20) },
		{ kind = "board", cframe = CFrame.new(5, 0, 5), board = "contract" },
		{ kind = "board", cframe = CFrame.new(25, 0, 5), board = "result" },
	}
end

local function bounds()
	return { cframe = CFrame.new(20, 10, 30), size = Vector3.new(80, 20, 80) }
end

local function hasError(errors, fragment)
	for _, message in errors do
		if string.find(message, fragment, 1, true) then
			return true
		end
	end
	return false
end

return function()
	describe("plan (an authored hub's markers)", function()
		it("orders the trucks by their number and fills in the default seats and countdown", function()
			local plan, errors = DepotHubRules.plan(markers(), bounds())
			expect(#errors).to.equal(0)
			expect(#plan.trucks).to.equal(3)
			expect(plan.trucks[1].index).to.equal(1)
			expect(plan.trucks[1].capacity).to.equal(4)
			expect(plan.trucks[1].countdown).to.equal(10)
			expect(plan.trucks[2].index).to.equal(2)
			expect(plan.trucks[2].id).to.equal("truck2")
			expect(plan.trucks[2].capacity).to.equal(DepotLayoutConstants.MAX_CAPACITY)
			expect(plan.trucks[2].countdown).to.equal(DepotLayoutConstants.HUB.DEFAULT_COUNTDOWN)
			expect(near(plan.trucks[3].cframe, CFrame.new(40, 0, 48))).to.equal(true)
		end)

		it("keeps the spawns, the boards and the bounds", function()
			local plan = DepotHubRules.plan(markers(), bounds())
			expect(#plan.spawns).to.equal(2)
			expect(near(plan.boards.contract, CFrame.new(5, 0, 5))).to.equal(true)
			expect(near(plan.boards.result, CFrame.new(25, 0, 5))).to.equal(true)
			expect(plan.boards.crew).to.equal(nil)
			expect(plan.bounds.size).to.equal(Vector3.new(80, 20, 80))
		end)

		it("accepts the optional crew board, time clock and daily sheet", function()
			local list = markers()
			table.insert(list, { kind = "board", cframe = CFrame.new(1, 0, 1), board = "crew" })
			table.insert(list, { kind = "board", cframe = CFrame.new(2, 0, 1), board = "clock" })
			table.insert(list, { kind = "board", cframe = CFrame.new(3, 0, 1), board = "daily" })
			local plan, errors = DepotHubRules.plan(list, bounds())
			expect(#errors).to.equal(0)
			expect(plan.boards.crew ~= nil).to.equal(true)
			expect(plan.boards.clock ~= nil).to.equal(true)
			expect(plan.boards.daily ~= nil).to.equal(true)
		end)

		it("refuses too few trucks, gaps or repeats in their numbers", function()
			local list = markers()
			table.remove(list, 3)
			local plan, errors = DepotHubRules.plan(list, bounds())
			expect(plan).to.equal(nil)
			expect(hasError(errors, "trucks")).to.equal(true)

			list = markers()
			list[3].truck = 4
			_, errors = DepotHubRules.plan(list, bounds())
			expect(hasError(errors, "numbered 1 to 3")).to.equal(true)

			list = markers()
			list[3].truck = 2
			_, errors = DepotHubRules.plan(list, bounds())
			expect(hasError(errors, "numbered 1 to 3")).to.equal(true)
		end)

		it("refuses bad seats or countdowns", function()
			local list = markers()
			list[1].capacity = 0
			list[3].countdown = 999
			local _, errors = DepotHubRules.plan(list, bounds())
			expect(hasError(errors, "seats")).to.equal(true)
			expect(hasError(errors, "countdown")).to.equal(true)
		end)

		it("refuses a hub with no spawn, a missing required board, a repeated or unknown board", function()
			local list = {}
			for _, marker in markers() do
				if marker.kind ~= "spawn" and marker.board ~= "result" then
					table.insert(list, marker)
				end
			end
			table.insert(list, { kind = "board", cframe = CFrame.new(), board = "contract" })
			table.insert(list, { kind = "board", cframe = CFrame.new(), board = "jukebox" })
			local plan, errors = DepotHubRules.plan(list, bounds())
			expect(plan).to.equal(nil)
			expect(hasError(errors, "spawn")).to.equal(true)
			expect(hasError(errors, "result")).to.equal(true)
			expect(hasError(errors, "more than one contract")).to.equal(true)
			expect(hasError(errors, "jukebox")).to.equal(true)
		end)
	end)

	describe("fromLayout (the code-built graybox)", function()
		local origin = CFrame.new(-1000, 1.25, 0)
		local layout = DepotLayoutConstants.LAYOUT

		it("puts each truck, spawn and board where the graybox always had it", function()
			local plan = DepotHubRules.fromLayout(layout, origin)
			expect(#plan.trucks).to.equal(#layout.trucks)
			local first = layout.trucks[1]
			expect(plan.trucks[1].id).to.equal(first.id)
			expect(plan.trucks[1].capacity).to.equal(first.capacity)
			expect(near(plan.trucks[1].cframe, origin * CFrame.new(first.x, 0, first.z))).to.equal(true)
			local spawn = layout.spawns[1]
			expect(near(plan.spawns[1], origin * CFrame.new(spawn.x, 0, spawn.z))).to.equal(true)
			local board = layout.contractBoard
			-- A board marker faces its readers (+z in the graybox), so its sign (on the part's back face) does too.
			expect(near(plan.boards.contract, origin * CFrame.new(board.x, 0, board.z) * FLIP)).to.equal(true)
			expect(plan.boards.clock ~= nil).to.equal(true)
			expect(plan.boards.daily ~= nil).to.equal(true)
		end)

		it("bounds the floor and the walls' height", function()
			local plan = DepotHubRules.fromLayout(layout, origin)
			local floor = layout.floor
			expect(plan.bounds.size.X).to.equal(floor.maxX - floor.minX)
			expect(plan.bounds.size.Z).to.equal(floor.maxZ - floor.minZ)
			expect(plan.bounds.size.Y).to.equal(DepotLayoutConstants.WALL_HEIGHT)
		end)
	end)

	describe("check (no quiet fallback: a broken hub stops the depot)", function()
		it("returns the plan of a playable hub", function()
			local plan = DepotHubRules.check(markers(), bounds(), "Workspace.Hub")
			expect(#plan.trucks).to.equal(3)
		end)

		it("throws one clear message naming the hub, every problem and how to fix it", function()
			local list = markers()
			table.remove(list, 3)
			list[1].capacity = 0
			local ok, message = pcall(DepotHubRules.check, list, bounds(), "Workspace.NightGarage")
			expect(ok).to.equal(false)
			message = tostring(message)
			expect(string.find(message, "Workspace.NightGarage", 1, true) ~= nil).to.equal(true)
			expect(string.find(message, "trucks", 1, true) ~= nil).to.equal(true)
			expect(string.find(message, "seats", 1, true) ~= nil).to.equal(true)
			expect(string.find(message, "DepotTruckBay", 1, true) ~= nil).to.equal(true)
		end)
	end)

	describe("inside", function()
		local box =
			{ cframe = CFrame.new(100, 10, 0) * CFrame.Angles(0, math.rad(30), 0), size = Vector3.new(40, 20, 30) }

		it("is true inside the (turned) box and false outside it", function()
			expect(DepotHubRules.inside(box, box.cframe.Position)).to.equal(true)
			expect(DepotHubRules.inside(box, box.cframe * Vector3.new(19, -9, 14))).to.equal(true)
			expect(DepotHubRules.inside(box, box.cframe * Vector3.new(21, 0, 0))).to.equal(false)
			expect(DepotHubRules.inside(box, box.cframe * Vector3.new(0, 11, 0))).to.equal(false)
		end)
	end)
end
