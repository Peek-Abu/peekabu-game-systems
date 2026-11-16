-- The vacuum hold validator's measurements (split out of AnimationVacuumHarness): the grip attachments, the hands, how
-- far a paw's wrap point sits from its grip, how deep an arm sits in the torso, and where the floor head is.
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")
local Measure = require(ServerScriptService.Features.Animation.Testing.AnimationVacuumMeasureHarness)

local function part(name, size, cframe, parent)
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = false
	p.Size = size
	p.CFrame = cframe
	p.Parent = parent
	return p
end

return function()
	local folder
	beforeEach(function()
		folder = Instance.new("Folder")
		folder.Name = "VacuumMeasureHarnessSpec"
		folder.Parent = Workspace
	end)
	afterEach(function()
		folder:Destroy()
	end)

	describe("descendant", function()
		it("finds an Attachment by name anywhere inside, and nothing else", function()
			local model = Instance.new("Model")
			local holder = part("Wand", Vector3.one, CFrame.new(), model)
			local grip = Instance.new("Attachment")
			grip.Name = "GripUpper"
			grip.Parent = holder
			expect(Measure.descendant(model, "GripUpper")).to.equal(grip)
			expect(Measure.descendant(model, "Wand")).to.equal(nil)
			expect(Measure.descendant(model, "GripLower")).to.equal(nil)
			model:Destroy()
		end)
	end)

	describe("handOf", function()
		it("returns the side's hand part, or nil when there is none", function()
			local model = Instance.new("Model")
			local hand = part("RightHand", Vector3.one, CFrame.new(), model)
			expect(Measure.handOf(model, "Right")).to.equal(hand)
			expect(Measure.handOf(model, "Left")).to.equal(nil)
			model:Destroy()
		end)
	end)

	describe("onPaw", function()
		it("measures nothing when the hand, wrap or grip is missing", function()
			local distance, inside = Measure.onPaw(nil, Vector3.zero, nil)
			expect(distance).to.equal(nil)
			expect(inside).to.equal(false)
		end)

		it("gives the wrap point's distance to the grip and whether the grip is inside the paw", function()
			local hand = part("RightHand", Vector3.one, CFrame.new(0, 500, 0), folder)
			local wand = part("Wand", Vector3.one, CFrame.new(0, 500, 0), folder)
			local grip = Instance.new("Attachment")
			grip.Position = Vector3.new(0, 0.2, 0)
			grip.Parent = wand
			local distance, inside = Measure.onPaw(hand, Vector3.new(0, 0.2, 0), grip)
			expect(distance).to.be.near(0, 1e-4)
			expect(inside).to.equal(true)
			grip.Position = Vector3.new(0, 1, 0)
			distance, inside = Measure.onPaw(hand, Vector3.new(0, 0.2, 0), grip)
			expect(distance).to.be.near(0.8, 1e-4)
			expect(inside).to.equal(false)
		end)
	end)

	describe("armClip", function()
		it("reads how deep the deepest hand point sits inside a torso ellipsoid, 0 when clear", function()
			local model = Instance.new("Model")
			part("UpperTorso", Vector3.new(2, 2, 2), CFrame.new(), model)
			local hand = part("RightHand", Vector3.one, CFrame.new(), model)
			expect(Measure.armClip(model)).to.be.near(1, 1e-4)
			hand.CFrame = CFrame.new(100, 0, 0)
			expect(Measure.armClip(model)).to.equal(0)
			model:Destroy()
		end)
	end)

	describe("outOf", function()
		it("gives the head's flat distance from the root, nil without a head", function()
			local model = Instance.new("Model")
			part("HumanoidRootPart", Vector3.new(2, 2, 1), CFrame.new(), model)
			local head = part("FloorHead", Vector3.one, CFrame.new(3, 5, 4), model)
			expect(Measure.outOf(model, head)).to.be.near(5, 1e-4)
			expect(Measure.outOf(model, nil)).to.equal(nil)
			model:Destroy()
		end)
	end)

	describe("clearance", function()
		it("gives the head's lowest corner over the floor under the root (root bottom less the hip height)", function()
			local model = Instance.new("Model")
			part("HumanoidRootPart", Vector3.new(2, 2, 1), CFrame.new(0, 10, 0), model)
			local humanoid = Instance.new("Humanoid")
			humanoid.Parent = model
			humanoid.HipHeight = 2
			local head = part("FloorHead", Vector3.one, CFrame.new(0, 8, 0), model)
			expect(Measure.clearance(model, head)).to.be.near(0.5, 1e-4)
			expect(Measure.clearance(model, nil)).to.equal(nil)
			model:Destroy()
		end)
	end)
end
