local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local OccupantFaceLightSystem = require(script.Parent.OccupantFaceLightSystem)
local OccupantVfxConstants = require(ReplicatedStorage.Client.Features.Occupant.Data.OccupantVfxConstants)

return function()
	local head
	beforeEach(function()
		OccupantFaceLightSystem.clear()
		head = Instance.new("Part")
		head.Name = "Head"
		head.Anchored = true
		head.CFrame = CFrame.new(0, 4000, 9100)
		head.Parent = Workspace
	end)
	afterEach(function()
		OccupantFaceLightSystem.clear()
		head:Destroy()
	end)

	local function lights()
		local found = {}
		for _, child in head:GetDescendants() do
			if child:IsA("PointLight") then
				table.insert(found, child)
			end
		end
		return found
	end

	describe("frame / release", function()
		it("lights his face with a key in front and a rim behind while something frames it", function()
			expect(OccupantFaceLightSystem.framing()).to.equal(false)
			OccupantFaceLightSystem.frame("catch", head)
			expect(OccupantFaceLightSystem.framing()).to.equal(true)
			local found = lights()
			expect(#found).to.equal(2)
			local key, rim
			for _, light in found do
				local attachment = light.Parent
				if attachment.Position.Z < 0 then
					key = light
				else
					rim = light
				end
			end
			expect(key).never.to.equal(nil)
			expect(rim).never.to.equal(nil)
			expect(key.Parent.Position).to.equal(OccupantVfxConstants.FACE_KEY.offset)
			expect(key.Shadows).to.equal(false)
			expect(key.Brightness).to.be.near(OccupantVfxConstants.FACE_KEY.brightness, 1e-4)
			expect(rim.Range).to.be.near(OccupantVfxConstants.FACE_RIM.range, 1e-4)
		end)

		it("keeps one set of lights for two owners, and removes them when the last lets go", function()
			OccupantFaceLightSystem.frame("reveal", head)
			OccupantFaceLightSystem.frame("catch", head)
			expect(#lights()).to.equal(2)
			OccupantFaceLightSystem.release("reveal")
			expect(#lights()).to.equal(2)
			expect(OccupantFaceLightSystem.framing()).to.equal(true)
			OccupantFaceLightSystem.release("catch")
			expect(#lights()).to.equal(0)
			expect(OccupantFaceLightSystem.framing()).to.equal(false)
		end)

		it("moves to a new head (a respawned rig) and ignores a release it never framed", function()
			OccupantFaceLightSystem.release("nobody")
			local other = head:Clone()
			other.Parent = Workspace
			OccupantFaceLightSystem.frame("catch", head)
			OccupantFaceLightSystem.frame("reveal", other)
			expect(#lights()).to.equal(0)
			local count = 0
			for _, child in other:GetDescendants() do
				if child:IsA("PointLight") then
					count += 1
				end
			end
			expect(count).to.equal(2)
			OccupantFaceLightSystem.clear()
			other:Destroy()
		end)

		it("stops framing when his head is gone", function()
			OccupantFaceLightSystem.frame("catch", head)
			head.Parent = nil
			expect(OccupantFaceLightSystem.framing()).to.equal(false)
			head.Parent = Workspace
		end)
	end)
end
