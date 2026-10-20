local HideRigUtils = require(script.Parent.HideRigUtils)

local function part(name, parent, cframe)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = Vector3.new(2, 2, 1)
	p.CFrame = cframe or CFrame.new()
	p.Parent = parent
	return p
end

local function motor(name, part0, part1)
	local m = Instance.new("Motor6D")
	m.Name = name
	m.Part0 = part0
	m.Part1 = part1
	m.Parent = part1
	return m
end

local function weld(a, b)
	local w = Instance.new("WeldConstraint")
	w.Part0 = a
	w.Part1 = b
	w.Parent = a
	return w
end

local function find(pieces, name)
	for _, piece in pieces do
		if piece.part == name then
			return piece
		end
	end
	return nil
end

return function()
	local model
	local upper
	beforeEach(function()
		model = Instance.new("Model")
		local root = part("HumanoidRootPart", model)
		local lower = part("LowerTorso", model)
		upper = part("UpperTorso", model)
		motor("Root", root, lower)
		motor("Waist", lower, upper)
	end)
	afterEach(function()
		model:Destroy()
	end)

	it("returns nil without a HumanoidRootPart", function()
		local bare = Instance.new("Model")
		part("Torso", bare)
		expect(HideRigUtils.read(bare)).to.equal(nil)
		bare:Destroy()
	end)

	it("reads every Motor6D as a joint and its Part1 as a jointed piece", function()
		local rig = HideRigUtils.read(model)
		expect(rig.root).to.equal("HumanoidRootPart")
		expect(#rig.joints).to.equal(2)
		expect(rig.joints[1].part0).to.equal("HumanoidRootPart")
		expect(rig.joints[1].part1).to.equal("LowerTorso")
		expect(find(rig.pieces, "HumanoidRootPart")).to.equal(nil)
		expect(find(rig.pieces, "UpperTorso").base).to.equal(nil)
		expect(find(rig.pieces, "LowerTorso").base).to.equal(nil)
	end)

	it("reads a welded part as a rigid piece on its jointed part, at its current offset", function()
		local pack = part("Backpack", model, upper.CFrame * CFrame.new(0, 0, 1))
		weld(upper, pack)
		local rig = HideRigUtils.read(model)
		local piece = find(rig.pieces, "Backpack")
		expect(piece.base).to.equal("UpperTorso")
		expect(piece.offset.Z).to.be.near(1, 1e-6)
		expect(piece.size).to.equal(pack.Size)
	end)

	it("follows a chain of welds back to the jointed body part", function()
		local pack = part("Backpack", model, upper.CFrame * CFrame.new(0, 0, 1))
		weld(upper, pack)
		local pouch = part("Pouch", model, pack.CFrame * CFrame.new(1, 0, 0))
		weld(pack, pouch)
		local piece = find(HideRigUtils.read(model).pieces, "Pouch")
		expect(piece.base).to.equal("UpperTorso")
		expect(piece.offset.X).to.be.near(1, 1e-6)
		expect(piece.offset.Z).to.be.near(1, 1e-6)
	end)

	it("skips a Tool's parts and fully transparent gear", function()
		local tool = Instance.new("Tool")
		tool.Parent = model
		local handle = part("Handle", tool, upper.CFrame)
		weld(upper, handle)
		local ghost = part("Ghost", model, upper.CFrame)
		ghost.Transparency = 1
		weld(upper, ghost)
		local rig = HideRigUtils.read(model)
		expect(find(rig.pieces, "Handle")).to.equal(nil)
		expect(find(rig.pieces, "Ghost")).to.equal(nil)
	end)

	it("suffixes duplicate part names by order, in part and base alike", function()
		local first = part("Plate", model, upper.CFrame)
		local second = part("Plate", model, upper.CFrame * CFrame.new(0, 0, 2))
		weld(upper, first)
		weld(first, second)
		local rig = HideRigUtils.read(model)
		expect(find(rig.pieces, "Plate").base).to.equal("UpperTorso")
		expect(find(rig.pieces, "Plate#2").base).to.equal("UpperTorso")
	end)
end
