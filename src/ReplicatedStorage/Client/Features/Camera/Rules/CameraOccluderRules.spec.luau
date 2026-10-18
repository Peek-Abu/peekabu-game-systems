local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CameraOccluderRules = require(script.Parent.CameraOccluderRules)
local CameraOccluderConstants = require(ReplicatedStorage.Shared.Features.Camera.Data.CameraOccluderConstants)

return function()
	local made = {}
	local function part(props)
		local p = Instance.new("Part")
		for key, value in props or {} do
			p[key] = value
		end
		table.insert(made, p)
		return p
	end
	afterEach(function()
		for _, p in made do
			p:Destroy()
		end
		table.clear(made)
	end)

	describe("blocks", function()
		it("an opaque, colliding part blocks the camera (what the engine's Poppercam uses)", function()
			expect(CameraOccluderRules.blocks(part())).to.equal(true)
		end)

		it("a see-through or local-faded part does not", function()
			expect(CameraOccluderRules.blocks(part({ Transparency = 0.5 }))).to.equal(false)
			local faded = part()
			faded.LocalTransparencyModifier = 0.9
			expect(CameraOccluderRules.blocks(faded)).to.equal(false)
		end)

		it("a non-colliding part does not, opaque or not", function()
			expect(CameraOccluderRules.blocks(part({ CanCollide = false }))).to.equal(false)
		end)

		it("an invisible collision proxy flagged as an occluder blocks (it stands for its art skin)", function()
			local proxy = part({ Transparency = 1 })
			proxy:SetAttribute(CameraOccluderConstants.ATTRIBUTE, true)
			expect(CameraOccluderRules.blocks(proxy)).to.equal(true)
			proxy:SetAttribute(CameraOccluderConstants.ATTRIBUTE, false)
			expect(CameraOccluderRules.blocks(proxy)).to.equal(false)
		end)

		it("a truss never blocks (ladders are seen through)", function()
			local truss = Instance.new("TrussPart")
			table.insert(made, truss)
			expect(CameraOccluderRules.blocks(truss)).to.equal(false)
		end)
	end)
end
