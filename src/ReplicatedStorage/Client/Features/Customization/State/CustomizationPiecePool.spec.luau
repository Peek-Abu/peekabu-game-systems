--!strict
--[=[
	Unit tests for CustomizationPiecePool — parked cosmetic sets keyed by id.
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CustomizationPiecePool = require(ReplicatedStorage.Client.Features.Customization.State.CustomizationPiecePool)

return function()
	local container

	beforeEach(function()
		container = Instance.new("Folder")
	end)

	afterEach(function()
		container:Destroy()
	end)

	local function piece()
		local accessory = Instance.new("Accessory")
		local handle = Instance.new("Part")
		handle.Name = "Handle"
		handle.Transparency = 0.25
		handle.Parent = accessory
		local a0 = Instance.new("Attachment")
		a0.Parent = handle
		local constraint = Instance.new("RigidConstraint")
		constraint.Attachment0 = a0
		constraint.Parent = handle
		return accessory
	end

	it("misses on an empty pool", function()
		local pool = CustomizationPiecePool.new(container)
		expect(CustomizationPiecePool.take(pool, "Hair10")).to.equal(nil)
		expect(pool.misses).to.equal(1)
	end)

	it("returns the same set it was given", function()
		local pool = CustomizationPiecePool.new(container)
		local set = { piece() }
		CustomizationPiecePool.release(pool, "Hair10", set)
		expect(CustomizationPiecePool.take(pool, "Hair10")).to.equal(set)
		expect(pool.hits).to.equal(1)
		expect(CustomizationPiecePool.take(pool, "Hair10")).to.equal(nil)
	end)

	it("keys by id", function()
		local pool = CustomizationPiecePool.new(container)
		CustomizationPiecePool.release(pool, "Hair10", { piece() })
		expect(CustomizationPiecePool.take(pool, "Hair11")).to.equal(nil)
	end)

	it("parks: strips constraints, anchors, keeps transparency, stays parented", function()
		local pool = CustomizationPiecePool.new(container)
		local accessory = piece()
		CustomizationPiecePool.release(pool, "Hair10", { accessory })
		local handle = accessory:FindFirstChild("Handle")
		expect(accessory.Parent).to.equal(container)
		expect(handle:FindFirstChildOfClass("RigidConstraint")).to.equal(nil)
		expect(handle.Anchored).to.equal(true)
		expect(handle.Transparency).to.equal(0.25)
		expect(handle.Position.Y).to.equal(CustomizationPiecePool.PARKED_CFRAME.Position.Y)
	end)

	it("destroys the oldest set over the cap", function()
		local pool = CustomizationPiecePool.new(container, 2)
		local first, second, third = { piece() }, { piece() }, { piece() }
		CustomizationPiecePool.release(pool, "Hair10", first)
		CustomizationPiecePool.release(pool, "Hair10", second)
		CustomizationPiecePool.release(pool, "Hair10", third)
		expect(first[1].Parent).to.equal(nil)
		expect(pool.parked).to.equal(2)
		expect(CustomizationPiecePool.take(pool, "Hair10")).to.equal(third)
		expect(CustomizationPiecePool.take(pool, "Hair10")).to.equal(second)
	end)

	it("destroy clears every parked piece", function()
		local pool = CustomizationPiecePool.new(container)
		local set = { piece() }
		CustomizationPiecePool.release(pool, "Hair10", set)
		CustomizationPiecePool.destroy(pool)
		expect(set[1].Parent).to.equal(nil)
		expect(pool.parked).to.equal(0)
	end)
end
