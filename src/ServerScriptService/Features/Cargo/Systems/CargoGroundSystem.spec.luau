local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Ground = require(script.Parent.CargoGroundSystem)
local Carry = require(ReplicatedStorage.Shared.Features.Carry.Data.CarryConstants)
return function()
	local parent, part, system, player, landings
	beforeEach(function()
		parent = Instance.new("Folder")
		parent.Parent = workspace
		part = Instance.new("Part")
		part.Size = Vector3.new(2, 4, 2)
		part.CFrame = CFrame.new(30000, 12, 0) * CFrame.Angles(0, 0.7, 0)
		part:SetAttribute("CargoId", 17)
		part:SetAttribute("CarryKind", "recyclingBox")
		part.Parent = parent
		player = { UserId = 9017, Name = "CargoSpecPlayer", DisplayName = "Cargo Spec" }
		landings = {}
		system = Ground.new({
			floorUnder = function(_self, position, _ignore)
				return CFrame.new(position.X, 5, position.Z)
			end,
		}, function(item)
			return { item }
		end, function(placer, item, reason, landed)
			table.insert(landings, { placer = placer, item = item, reason = reason, landed = landed })
		end)
	end)
	afterEach(function()
		system:stop()
		parent:Destroy()
	end)
	describe("released cargo ground lifecycle", function()
		it("rests a drop on the surface without replacing identity or rotating its yaw", function()
			local visual = Instance.new("Model")
			visual.Name = "ArtVisual"
			visual.Parent = part
			local facing = part.CFrame.LookVector
			system:release(part, "drop")
			expect(part.Position.Y).to.equal(7)
			expect(part.CFrame.LookVector:FuzzyEq(facing)).to.equal(true)
			expect(part.Anchored).to.equal(true)
			expect(part.CanCollide).to.equal(false)
			expect(part:GetAttribute("CargoId")).to.equal(17)
			expect(part:GetAttribute("CarryKind")).to.equal("recyclingBox")
			expect(part:FindFirstChild("ArtVisual")).to.equal(visual)
		end)
		it("leaves a deliberate throw airborne until motion has settled", function()
			part.Anchored = false
			part.AssemblyLinearVelocity = Vector3.new(20, 10, 0)
			system:release(part, "throw", player)
			expect(part.Anchored).to.equal(false)
			expect(part.CanCollide).to.equal(true)
			system:step(0.5)
			expect(part.Anchored).to.equal(false)
			part.Position = Vector3.new(30000, 7, 0)
			part.AssemblyLinearVelocity = Vector3.zero
			part.AssemblyAngularVelocity = Vector3.zero
			system:step(0.1)
			system:step(0.3)
			expect(part.Anchored).to.equal(true)
			expect(part.CanCollide).to.equal(false)
			expect(landings[1].landed).to.equal(true)
			expect(landings[1].placer).to.equal(player)
		end)
		it("does not authorize an automatic bank when timeout projects airborne cargo to a surface", function()
			part.Anchored = false
			system:release(part, "throw", player)
			part.AssemblyLinearVelocity = Vector3.new(20, 0, 0)
			system:step(9)
			expect(part.Anchored).to.equal(true)
			expect(landings[1].landed).to.equal(false)
		end)
		it("cancels settling on pickup and never anchors a held object", function()
			part.Anchored = false
			system:release(part, "throw", player)
			part:SetAttribute(Carry.CARRIED_BY_ATTRIBUTE, 123)
			part.CanCollide = false
			system:step(10)
			expect(part.Anchored).to.equal(false)
			expect(part.CanCollide).to.equal(false)
		end)
		it("ignores destruction and safely forgets destroyed thrown objects", function()
			local frame = part.CFrame
			system:release(part, "destroyed")
			expect(part.CFrame).to.equal(frame)
			system:release(part, "throw", player)
			part:Destroy()
			system:step(10)
		end)
		it("stops tracking old throws before the next shift", function()
			part.Anchored = false
			system:release(part, "throw", player)
			system:stop()
			system:step(10)
			expect(part.Anchored).to.equal(false)
		end)
	end)
end
