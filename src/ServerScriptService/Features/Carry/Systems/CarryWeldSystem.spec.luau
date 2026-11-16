local CarryWeldSystem = require(script.Parent.CarryWeldSystem)

local function part(cframe)
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = true
	p.Massless = false
	p.CFrame = cframe or CFrame.identity
	return p
end

return function()
	describe("attach (no character: the plain hold offset and a weld to the carrier's root)", function()
		it("holds the object at the hold offset, welded to the root, massless and non-colliding", function()
			local playerRoot = part(CFrame.new(10, 3, 0))
			local target = part(CFrame.new(0, 0, 50))
			local offset = CFrame.new(0, 0, -2)
			local weld, contact, saved =
				CarryWeldSystem.attach(nil, target, target, "box", { weight = 1, holdOffset = offset }, nil, playerRoot)

			expect(contact).to.equal(nil)
			expect(weld:IsA("Weld")).to.equal(true)
			expect(weld.Name).to.equal("CarryWeld")
			expect(weld.Part0).to.equal(playerRoot)
			expect(weld.Part1).to.equal(target)
			expect(weld.Parent).to.equal(target)
			expect((target.Position - (playerRoot.CFrame * offset).Position).Magnitude < 1e-4).to.equal(true)
			expect(target.Anchored).to.equal(false)
			expect(target.Massless).to.equal(true)
			expect(target.CanCollide).to.equal(false)
			expect(#saved).to.equal(1)
			expect(saved[1].part).to.equal(target)
			expect(saved[1].massless).to.equal(false)
			expect(saved[1].canCollide).to.equal(true)

			target:Destroy()
			playerRoot:Destroy()
		end)

		it("saves every part of a model, the root included", function()
			local playerRoot = part()
			local model = Instance.new("Model")
			local root = part()
			root.Parent = model
			local extra = part(CFrame.new(1, 0, 0))
			extra.Parent = model
			model.PrimaryPart = root
			local _, _, saved = CarryWeldSystem.attach(nil, model, root, "box", { weight = 0 }, nil, playerRoot)

			expect(#saved).to.equal(2)
			expect(root.Massless).to.equal(true)
			expect(extra.Massless).to.equal(true)
			expect(extra.CanCollide).to.equal(false)

			model:Destroy()
			playerRoot:Destroy()
		end)
	end)

	describe("detach", function()
		it("removes the weld and gives every part its own mass and collision back", function()
			local playerRoot = part()
			local target = part()
			target.CanCollide = false
			target.Massless = true
			local weld, contact, saved =
				CarryWeldSystem.attach(nil, target, target, "box", { weight = 1 }, nil, playerRoot)

			CarryWeldSystem.detach(contact, weld, saved)

			expect(weld.Parent).to.equal(nil)
			expect(target.Massless).to.equal(true)
			expect(target.CanCollide).to.equal(false)

			target:Destroy()
			playerRoot:Destroy()
		end)
	end)
end
