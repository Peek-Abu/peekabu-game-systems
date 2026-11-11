local Server = game:GetService("ServerScriptService").Features.Depot
local Build = require(script.Parent.DepotBuildSystem)
local Layout = require(Server.Data.DepotLayoutConstants).LAYOUT
return function()
	local built
	afterEach(function()
		if built then
			built.model:Destroy()
			built = nil
		end
	end)
	describe("physical enclosure", function()
		it("builds a reachable tagged weekly time clock beside the contract board", function()
			built = Build.build(Layout, CFrame.new(50000, 0, 0), {})
			local clock = built.model:FindFirstChild("WeeklyTimeClock", true)
			expect(clock ~= nil).to.equal(true)
			expect(clock:GetAttribute("InteractionKind")).to.equal("TimecardClock")
			-- Its sign is drawn by the client in the game's kit (owner 11-11), not server text.
			expect(clock:FindFirstChild("ClockFace")).to.equal(nil)
			local clockSign = built.model:FindFirstChild("ClockSign", true)
			expect(clockSign ~= nil).to.equal(true)
			expect(game:GetService("CollectionService"):HasTag(clockSign, "DepotClockSign")).to.equal(true)
			local sheet = built.model:FindFirstChild("DailyWorkOrderSheet", true)
			expect(sheet ~= nil).to.equal(true)
			expect(sheet:GetAttribute("InteractionKind")).to.equal("DailyWorkOrder")
			local dailySign = built.model:FindFirstChild("DailySign", true)
			expect(dailySign ~= nil).to.equal(true)
			expect(game:GetService("CollectionService"):HasTag(dailySign, "DepotDailySign")).to.equal(true)
		end)
		it("builds collidable visible ceiling geometry", function()
			built = Build.build(Layout, CFrame.new(50000, 0, 0), {})
			local ceiling = built.model:FindFirstChild("Ceiling", true)
			expect(ceiling ~= nil).to.equal(true)
			expect(ceiling.CanCollide).to.equal(true)
			expect(ceiling.Transparency).to.equal(0)
		end)
		it("uses physical surfaces for contract/results and keeps truck tags camera-facing", function()
			built = Build.build(Layout, CFrame.new(50000, 0, 0), {})
			local contract = built.model:FindFirstChild("ContractSign", true)
			local result = built.model:FindFirstChild("ResultSign", true)
			expect(contract:IsA("SurfaceGui")).to.equal(true)
			expect(result:IsA("SurfaceGui")).to.equal(true)
			expect(contract.AlwaysOnTop).to.equal(false)
			expect(contract.Adornee).to.equal(built.contractBoard)
			expect(built.model:FindFirstChild("PadTag", true):IsA("BillboardGui")).to.equal(true)
		end)
	end)
	describe("garage floor", function()
		it("stands clear of the place's Baseplate (top at y = 0), so the two never z-fight", function()
			local Constants = require(Server.Data.DepotLayoutConstants)
			-- The depot's real origin, moved far along z so the spec never meets a live depot.
			local origin = CFrame.new(0, 0, 50000) * Constants.ORIGIN
			built = Build.build(Layout, origin, {})
			local lowest = math.huge
			for _, part in built.model.Floor:GetDescendants() do
				if part:IsA("BasePart") then
					lowest = math.min(lowest, part.Position.Y - part.Size.Y / 2)
				end
			end
			expect(lowest > 0).to.equal(true)
		end)
		it("lays collidable concrete slabs in warm greys over a darker joint bed", function()
			built = Build.build(Layout, CFrame.new(50000, 0, 0), {})
			local floor = built.model:FindFirstChild("Floor")
			expect(floor ~= nil).to.equal(true)
			local base = floor:FindFirstChild("Base")
			local slabs = floor:FindFirstChild("Slabs"):GetChildren()
			expect(#slabs > 20).to.equal(true)
			local brightest = 0
			for _, slab in slabs do
				expect(slab.Material).to.equal(Enum.Material.Concrete)
				expect(slab.CanCollide).to.equal(true)
				expect(slab.Color.R >= slab.Color.B).to.equal(true)
				-- Every slab tops out at the floor plane (y = 0 in the depot's space).
				expect(slab.Position.Y + slab.Size.Y / 2).to.be.near(0, 1e-3)
				brightest = math.max(brightest, slab.Color.R + slab.Color.G + slab.Color.B)
			end
			expect(base.CanCollide).to.equal(true)
			expect(base.Position.Y + base.Size.Y / 2 < 0).to.equal(true)
			expect(base.Color.R + base.Color.G + base.Color.B < brightest).to.equal(true)
		end)
		it("paints the round oil stains as flat, non-colliding discs", function()
			built = Build.build(Layout, CFrame.new(50000, 0, 0), {})
			local stains = 0
			for _, part in built.model.FloorMarkings:GetChildren() do
				if string.sub(part.Name, 1, 5) == "Stain" then
					stains += 1
					expect(part.Shape).to.equal(Enum.PartType.Cylinder)
					expect(part.Transparency > 0).to.equal(true)
					-- A cylinder's axis is its X: laid flat, that axis points up.
					expect(math.abs(part.CFrame.RightVector.Y)).to.be.near(1, 1e-3)
				end
			end
			expect(stains >= 2).to.equal(true)
		end)
	end)
	describe("hub lighting", function()
		it("hangs a lit strip over each board (the crew board too) as well as over the trucks", function()
			built = Build.build(Layout, CFrame.new(50000, 0, 0), {})
			local lights = built.model:FindFirstChild("Lights")
			expect(lights ~= nil).to.equal(true)
			local boardLights = 0
			for _, fixture in lights:GetChildren() do
				expect(fixture:FindFirstChildOfClass("PointLight") ~= nil).to.equal(true)
				expect(fixture.CanCollide).to.equal(false)
				if fixture.Name == "BoardLight" then
					boardLights += 1
					local lamp = fixture.Position - CFrame.new(50000, 0, 0).Position
					local crew = Layout.crewBoard
					local near = math.abs(lamp.X - Layout.contractBoard.x) < 1
						or math.abs(lamp.X - Layout.resultBoard.x) < 1
						or (crew ~= nil and math.abs(lamp.X - crew.x) < 1)
					expect(near).to.equal(true)
				end
			end
			expect(boardLights).to.equal(if Layout.crewBoard ~= nil then 3 else 2)
		end)
	end)
	describe("floor bays", function()
		it("paints thin, non-colliding bays, ramp hazard bands and lanes, with a BAY n stencil per truck", function()
			built = Build.build(Layout, CFrame.new(50000, 0, 0), {})
			local markings = built.model:FindFirstChild("FloorMarkings")
			expect(markings ~= nil).to.equal(true)
			local texts = {}
			local parts = 0
			for _, part in markings:GetChildren() do
				expect(part:IsA("BasePart")).to.equal(true)
				parts += 1
				expect(part.CanCollide).to.equal(false)
				expect(part.CanQuery).to.equal(false)
				expect(part.CanTouch).to.equal(false)
				expect(part.Anchored).to.equal(true)
				-- Thin along its shortest side (a laid-flat disc's thickness is its X).
				expect(math.min(part.Size.X, part.Size.Y, part.Size.Z) <= 0.06).to.equal(true)
				local gui = part:FindFirstChildOfClass("SurfaceGui")
				if gui ~= nil then
					expect(gui.Face).to.equal(Enum.NormalId.Top)
					table.insert(texts, gui:FindFirstChildOfClass("TextLabel").Text)
				end
			end
			table.sort(texts)
			expect(#texts).to.equal(#Layout.trucks)
			expect(texts[1]).to.equal("BAY 1")
			expect(texts[#texts]).to.equal(`BAY {#Layout.trucks}`)
			expect(parts > #Layout.trucks * 10).to.equal(true)
		end)
	end)
	describe("a Studio-built hub's plan", function()
		local turn = CFrame.Angles(0, math.rad(90), 0)
		local function plan()
			local base = CFrame.new(60000, 0, 0)
			return {
				trucks = {
					{ id = "truck1", index = 1, capacity = 6, countdown = 15, cframe = base * turn },
					{
						id = "truck2",
						index = 2,
						capacity = 4,
						countdown = 12,
						cframe = base * CFrame.new(0, 0, 30) * turn,
					},
					{
						id = "truck3",
						index = 3,
						capacity = 6,
						countdown = 15,
						cframe = base * CFrame.new(0, 0, 60) * turn,
					},
				},
				spawns = { base * CFrame.new(-30, 0, 0) },
				boards = {
					contract = base * CFrame.new(-40, 0, 10),
					result = base * CFrame.new(-40, 0, 30),
				},
				bounds = { cframe = base, size = Vector3.new(100, 30, 100) },
			}
		end

		it("builds no room of its own (the hub brings it)", function()
			built = Build.buildPlan(plan(), {})
			expect(built.model:FindFirstChild("Walls")).to.equal(nil)
			expect(built.model:FindFirstChild("Ceiling")).to.equal(nil)
			expect(built.model:FindFirstChild("Floor")).to.equal(nil)
		end)

		it("stands each truck bed on its bay, turned with it, as a queue pad with its seats", function()
			local spots = plan()
			built = Build.buildPlan(spots, {})
			expect(#built.trucks).to.equal(3)
			local second = built.trucks[2]
			expect(second.index).to.equal(2)
			expect(second.pad:GetAttribute("QueueCapacity")).to.equal(4)
			expect(game:GetService("CollectionService"):HasTag(second.pad, "QueuePad")).to.equal(true)
			local bottom = second.pad.CFrame * CFrame.new(0, -second.pad.Size.Y / 2, 0)
			expect((bottom.Position - spots.trucks[2].cframe.Position).Magnitude < 1e-3).to.equal(true)
			expect(second.pad.CFrame.LookVector:Dot(spots.trucks[2].cframe.LookVector) > 0.999).to.equal(true)
		end)

		it(
			"faces each board's sign toward the board spot's readers, and leaves out the boards it has no spot for",
			function()
				local spots = plan()
				built = Build.buildPlan(spots, {})
				-- Signs are drawn on the part's back face: the part's +Z points where the spot looks.
				local back = built.contractBoard.CFrame.LookVector * -1
				expect(back:Dot(spots.boards.contract.LookVector) > 0.999).to.equal(true)
				expect(built.model:FindFirstChild("CrewBoard", true)).to.equal(nil)
				expect(built.model:FindFirstChild("WeeklyTimeClock", true)).to.equal(nil)
				expect(built.model:FindFirstChild("DailyWorkOrderSheet", true)).to.equal(nil)
			end
		)
	end)
end
