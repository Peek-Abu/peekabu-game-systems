local ReplicatedStorage = game:GetService("ReplicatedStorage")

local OfficeCritterConstants = require(ReplicatedStorage.Client.Features.Office.Data.OfficeCritterConstants)
local OfficeCritterSystem = require(script.Parent.OfficeCritterSystem)

-- A stub critter: one anchored part in a tagged-style Model, standing at `at`, fleeing toward +X.
local function critter(kind, at, props)
	local model = Instance.new("Model")
	model.Name = "Critter_" .. kind
	model:SetAttribute(OfficeCritterConstants.KIND_ATTRIBUTE, kind)
	model:SetAttribute(OfficeCritterConstants.DIRECTION_ATTRIBUTE, Vector3.new(1, 0, 0))
	for k, v in props or {} do
		model:SetAttribute(k, v)
	end
	local p = Instance.new("Part")
	p.Name = "Body"
	p.Anchored = true
	p.Size = Vector3.new(1, 1, 1)
	p.CFrame = CFrame.new(at)
	p.Parent = model
	model.PrimaryPart = p
	model.Parent = workspace
	return model
end

local function near(a, b, eps)
	return (a - b).Magnitude <= (eps or 1e-3)
end

return function()
	local made = {}
	local function track(m)
		table.insert(made, m)
		OfficeCritterSystem.addCritter(m)
		return m
	end

	afterEach(function()
		for _, m in made do
			OfficeCritterSystem.removeCritter(m)
			m:Destroy()
		end
		table.clear(made)
	end)

	describe("nextPhase", function()
		local cat = OfficeCritterConstants.KINDS.cat

		it("stays idle while every player is beyond the kind's near distance", function()
			expect(OfficeCritterSystem.nextPhase("cat", "idle", 3, cat.near + 0.5)).to.equal("idle")
		end)

		it("flees the moment a player comes within the near distance", function()
			expect(OfficeCritterSystem.nextPhase("cat", "idle", 0, cat.near - 0.5)).to.equal("flee")
		end)

		it("is gone once the flee has run its time", function()
			expect(OfficeCritterSystem.nextPhase("cat", "flee", cat.fleeTime - 0.01, 2)).to.equal("flee")
			expect(OfficeCritterSystem.nextPhase("cat", "flee", cat.fleeTime, 2)).to.equal("gone")
		end)

		it("comes back only after its wait, and only with nobody within RETURN_CLEAR", function()
			local clear = OfficeCritterConstants.RETURN_CLEAR
			expect(OfficeCritterSystem.nextPhase("cat", "gone", cat.returnAfter - 0.1, clear + 1)).to.equal("gone")
			expect(OfficeCritterSystem.nextPhase("cat", "gone", cat.returnAfter, clear - 1)).to.equal("gone")
			expect(OfficeCritterSystem.nextPhase("cat", "gone", cat.returnAfter, clear + 1)).to.equal("idle")
		end)

		it("treats no players at all as nobody near", function()
			expect(OfficeCritterSystem.nextPhase("crow", "idle", 1, math.huge)).to.equal("idle")
			expect(OfficeCritterSystem.nextPhase("crow", "gone", 999, math.huge)).to.equal("idle")
		end)
	end)

	describe("fleePose", function()
		local home = CFrame.new(10, 6, 0)
		local dir = Vector3.new(0, 0, -1)

		it("starts at home", function()
			for _, kind in { "cat", "crow", "raccoon" } do
				expect(near(OfficeCritterSystem.fleePose(kind, home, dir, 0, 0).Position, home.Position)).to.equal(true)
			end
		end)

		it("the cat hops, lands `drop` lower and runs along the flee direction, facing it", function()
			local cat = OfficeCritterConstants.KINDS.cat
			local hop = OfficeCritterSystem.fleePose("cat", home, dir, 5, cat.hopTime / 2)
			expect(hop.Position.Y > home.Position.Y).to.equal(true)
			local landed = OfficeCritterSystem.fleePose("cat", home, dir, 5, cat.hopTime)
			expect(math.abs(landed.Position.Y - (home.Position.Y - 5)) < 1e-3).to.equal(true)
			local later = OfficeCritterSystem.fleePose("cat", home, dir, 5, cat.fleeTime)
			expect(later.Position.Z < landed.Position.Z).to.equal(true)
			expect(math.abs(later.Position.Y - (home.Position.Y - 5)) < 1e-3).to.equal(true)
			expect(near(later.LookVector, dir)).to.equal(true)
		end)

		it("the crow climbs while it flies along the flee direction", function()
			local p = OfficeCritterSystem.fleePose("crow", home, dir, 0, 1)
			expect(p.Position.Y > home.Position.Y + 3).to.equal(true)
			expect(p.Position.Z < home.Position.Z - 3).to.equal(true)
		end)

		it("the raccoon only ducks straight down, never travelling", function()
			local r = OfficeCritterConstants.KINDS.raccoon
			local p = OfficeCritterSystem.fleePose("raccoon", home, dir, 0, r.fleeTime)
			expect(math.abs(p.Position.Y - (home.Position.Y - r.duck)) < 1e-3).to.equal(true)
			expect(p.Position.X).to.equal(home.Position.X)
			expect(p.Position.Z).to.equal(home.Position.Z)
		end)
	end)

	describe("stepCritter", function()
		it("flees, hides when gone, and returns to exactly where it was built", function()
			local m = track(critter("crow", Vector3.new(0, 10, 0)))
			local home = m:GetPivot()
			local crow = OfficeCritterConstants.KINDS.crow
			OfficeCritterSystem.stepCritter(m, 100, 3)
			expect(OfficeCritterSystem.phaseOf(m)).to.equal("flee")
			OfficeCritterSystem.stepCritter(m, 100 + crow.fleeTime / 2, 3)
			expect(m:GetPivot().Position.Y > home.Position.Y).to.equal(true)
			OfficeCritterSystem.stepCritter(m, 100 + crow.fleeTime, 3)
			expect(OfficeCritterSystem.phaseOf(m)).to.equal("gone")
			expect(m.Body.LocalTransparencyModifier).to.equal(1)
			-- just past the wait: (100 + fleeTime + returnAfter) - (100 + fleeTime) can round below returnAfter
			OfficeCritterSystem.stepCritter(m, 100 + crow.fleeTime + crow.returnAfter + 0.01, math.huge)
			expect(OfficeCritterSystem.phaseOf(m)).to.equal("idle")
			expect(m.Body.LocalTransparencyModifier).to.equal(0)
			expect(near(m:GetPivot().Position, home.Position)).to.equal(true)
		end)

		it("uses the model's FleeDrop for the cat's landing", function()
			local m = track(critter("cat", Vector3.new(0, 6, 0), { [OfficeCritterConstants.DROP_ATTRIBUTE] = 4 }))
			local cat = OfficeCritterConstants.KINDS.cat
			OfficeCritterSystem.stepCritter(m, 0, 1)
			OfficeCritterSystem.stepCritter(m, cat.hopTime, 1)
			expect(math.abs(m:GetPivot().Position.Y - 2) < 1e-3).to.equal(true)
		end)

		it("idles in place, only turning about its own spot", function()
			local m = track(critter("cat", Vector3.new(5, 6, 5)))
			local home = m:GetPivot()
			for t = 0, 40, 0.5 do
				OfficeCritterSystem.stepCritter(m, t, math.huge)
				expect(near(m:GetPivot().Position, home.Position)).to.equal(true)
			end
			expect(OfficeCritterSystem.phaseOf(m)).to.equal("idle")
		end)

		it("puts a critter back where it was built when it is removed mid-flee", function()
			local m = critter("raccoon", Vector3.new(0, 3, 0))
			OfficeCritterSystem.addCritter(m)
			local home = m:GetPivot()
			OfficeCritterSystem.stepCritter(m, 0, 1)
			OfficeCritterSystem.stepCritter(m, 0.1, 1)
			OfficeCritterSystem.removeCritter(m)
			expect(near(m:GetPivot().Position, home.Position)).to.equal(true)
			expect(m.Body.LocalTransparencyModifier).to.equal(0)
			expect(OfficeCritterSystem.phaseOf(m)).to.equal(nil)
			m:Destroy()
		end)

		it("ignores a model with an unknown kind", function()
			local m = critter("dragon", Vector3.new(0, 3, 0))
			OfficeCritterSystem.addCritter(m)
			expect(OfficeCritterSystem.phaseOf(m)).to.equal(nil)
			OfficeCritterSystem.stepCritter(m, 0, 1)
			expect(OfficeCritterSystem.phaseOf(m)).to.equal(nil)
			m:Destroy()
		end)
	end)
end
