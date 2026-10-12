local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Contact = require(ReplicatedStorage.Shared.Features.Animation.Utils.AnimationCarryContactUtils)
local Cargo = require(ReplicatedStorage.Shared.Features.Cargo.Data.CargoRegistry)
local Styles = require(ReplicatedStorage.Shared.Features.Animation.Data.AnimationCarryRegistry)
return function()
	local left, right = Vector3.new(-1, 1.2, 0), Vector3.new(1, 1.2, 0)
	local function onSurface(point, size)
		return math.abs(math.abs(point.X) - size.X / 2) < 0.001
			or math.abs(math.abs(point.Y) - size.Y / 2) < 0.001
			or math.abs(math.abs(point.Z) - size.Z / 2) < 0.001
	end
	it("plans reachable actual surface contacts for all13 cargo sizes and semantics", function()
		for _, id in Cargo.ids() do
			local size = Cargo.get(id).partSize
			local plan = Contact.plan(size, left, right, 1.64, 1.64, Styles.get(id))
			expect(plan).to.be.ok()
			expect(onSurface(plan.right.Position, size)).to.equal(true)
			expect((plan.offset:PointToWorldSpace(plan.right.Position) - right).Magnitude < 1.64).to.equal(true)
			if plan.left ~= nil then
				expect(onSurface(plan.left.Position, size)).to.equal(true)
				expect((plan.offset:PointToWorldSpace(plan.left.Position) - left).Magnitude < 1.64).to.equal(true)
			end
		end
	end)
	it("uses one hand for bag handles and small salvage, two for furniture", function()
		expect(Contact.plan(Vector3.new(2, 2, 2), left, right, 1.64, 1.64, "handle").left).to.equal(nil)
		expect(Contact.plan(Vector3.new(1, 0.4, 0.8), left, right, 1.64, 1.64, "small").left).to.equal(nil)
		expect(Contact.plan(Vector3.new(3, 3, 3), left, right, 1.64, 1.64, "twoHand").left).to.be.ok()
	end)
	it("does not stretch a short arm to an unreachable caller-owned offset", function()
		expect(Contact.plan(Vector3.new(2, 2, 2), left, right, 0.2, 0.2, "twoHand", CFrame.new(0, 0.5, -4))).to.equal(
			nil
		)
	end)
	it("honors a reachable explicit offset and rejects invalid sizes", function()
		local offset = CFrame.new(0, 0.5, -1.8)
		local plan = Contact.plan(Vector3.new(2, 2, 2), left, right, 1.64, 1.64, "twoHand", offset)
		expect(plan.offset).to.equal(offset)
		expect(Contact.plan(Vector3.new(0, 2, 2), left, right, 1.64, 1.64, "twoHand")).to.equal(nil)
	end)
	it("authored handle targets override box grips only when both arms can reach", function()
		local plan = Contact.plan(Vector3.new(2, 2, 2), left, right, 1.64, 1.64, "twoHand")
		local custom = Contact.withGrips(plan, CFrame.new(0.8, 0.2, 1), nil, left, right, 1.64, 1.64)
		expect(custom.right.Position).to.equal(Vector3.new(0.8, 0.2, 1))
		expect(custom.left).to.equal(nil)
		expect(Contact.withGrips(plan, CFrame.new(0, 0, -10), nil, left, right, 1.64, 1.64)).to.equal(nil)
	end)
end
