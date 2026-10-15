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
		it("hangs a lit strip over each board as well as over the trucks", function()
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
					local near = math.abs(lamp.X - Layout.contractBoard.x) < 1
						or math.abs(lamp.X - Layout.resultBoard.x) < 1
					expect(near).to.equal(true)
				end
			end
			expect(boardLights).to.equal(2)
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
end
