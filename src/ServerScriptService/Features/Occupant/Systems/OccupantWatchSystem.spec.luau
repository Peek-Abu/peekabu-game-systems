local ReplicatedStorage = game:GetService("ReplicatedStorage")

local OccupantWatchSystem = require(script.Parent.OccupantWatchSystem)
local C = require(ReplicatedStorage.Shared.Features.Occupant.Data.OccupantConstants)

-- A bare rig: a 2-stud root at y 5 (hip height 2), a head at y 7.5, and the kind attribute when given.
local function rig(kind)
	local model = Instance.new("Model")
	local root = Instance.new("Part")
	root.Name = "HumanoidRootPart"
	root.Size = Vector3.new(2, 2, 1)
	root.Position = Vector3.new(0, 5, 0)
	root.Parent = model
	local head = Instance.new("Part")
	head.Name = "Head"
	head.Size = Vector3.new(1, 1, 1)
	head.Position = Vector3.new(0, 7.5, 0)
	head.Parent = model
	local humanoid = Instance.new("Humanoid")
	humanoid.HipHeight = 2
	humanoid.Parent = model
	if kind ~= nil then
		model:SetAttribute(C.KIND_ATTRIBUTE, kind)
	end
	return { model = model, humanoid = humanoid, root = root, head = head }
end

return function()
	describe("parseReport", function()
		it("keeps a finite camera with a unit look", function()
			local position, look = OccupantWatchSystem.parseReport({
				position = Vector3.new(1, 2, 3),
				look = Vector3.new(0, 0, 4),
			})
			expect(position).to.equal(Vector3.new(1, 2, 3))
			expect(look.Magnitude).to.be.near(1, 1e-6)
			expect(look.Z).to.be.near(1, 1e-6)
		end)

		it("refuses a zero look, NaN or infinity", function()
			local nan = 0 / 0
			expect(OccupantWatchSystem.parseReport({ position = Vector3.zero, look = Vector3.zero })).to.equal(nil)
			expect(OccupantWatchSystem.parseReport({ position = Vector3.new(nan, 0, 0), look = Vector3.zAxis })).to.equal(
				nil
			)
			expect(OccupantWatchSystem.parseReport({ position = Vector3.zero, look = Vector3.new(math.huge, 0, 0) })).to.equal(
				nil
			)
		end)
	end)

	describe("points", function()
		it("is its head, chest and knees", function()
			local body = rig("bramble")
			local points = OccupantWatchSystem.points(body)
			expect(#points).to.equal(3)
			expect(points[1]).to.equal(body.head.Position)
			expect(points[2]).to.equal(body.root.Position)
			-- Halfway down the legs: the root's bottom (y 4) less half the hip height.
			expect(points[3].Y).to.be.near(3, 1e-6)
			body.model:Destroy()
		end)
	end)

	describe("freezes", function()
		it("is only for a kind with the freeze twist: never Harlow", function()
			local bramble = rig("bramble")
			local harlow = rig("harlow")
			local bare = rig(nil)
			expect(OccupantWatchSystem.freezes(bramble.model)).to.equal(true)
			expect(OccupantWatchSystem.freezes(harlow.model)).to.equal(false)
			expect(OccupantWatchSystem.freezes(bare.model)).to.equal(false)
			bramble.model:Destroy()
			harlow.model:Destroy()
			bare.model:Destroy()
		end)
	end)

	describe("freezeFor", function()
		it("has no freeze for a rig it is not watching (Harlow's senses stay untouched)", function()
			local harlow = rig(nil)
			expect(OccupantWatchSystem.freezeFor(harlow.model)).to.equal(nil)
			harlow.model:Destroy()
		end)
	end)
end
