local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local CameraOcclusionSystem = require(script.Parent.CameraOcclusionSystem)
local CameraConstants = require(ReplicatedStorage.Client.Features.Camera.Data.CameraConstants)
local CameraOccluderConstants = require(ReplicatedStorage.Shared.Features.Camera.Data.CameraOccluderConstants)

-- Far from anything a place builds, so only this spec's parts are hit.
local AT = Vector3.new(0, 4000, 9000)
local RADIUS = CameraConstants.OCCLUSION_RADIUS

return function()
	local box
	beforeEach(function()
		box = Instance.new("Folder")
		box.Name = "CameraOcclusionSpec"
		box.Parent = Workspace
	end)
	afterEach(function()
		box:Destroy()
	end)

	-- A 1-stud-thick wall across +Z, its near face `distance` studs in front of AT.
	local function wall(distance, props)
		local p = Instance.new("Part")
		p.Anchored = true
		p.Size = Vector3.new(20, 20, 1)
		p.CFrame = CFrame.new(AT + Vector3.new(0, 0, distance + 0.5))
		for key, value in props or {} do
			p[key] = value
		end
		p.Parent = box
		return p
	end

	local camera = AT + Vector3.new(0, 0, 12)

	describe("clearance", function()
		it("is the whole distance with nothing in the way", function()
			expect(CameraOcclusionSystem.clearance(AT, camera, {}, nil)).to.be.near(12, 1e-3)
		end)

		it("stops the camera a radius short of an opaque wall", function()
			wall(6)
			expect(CameraOcclusionSystem.clearance(AT, camera, {}, nil)).to.be.near(6 - RADIUS, 1e-2)
		end)

		it("stops at an invisible proxy flagged as an occluder, and passes an unflagged one", function()
			local proxy = wall(5, { Transparency = 1 })
			expect(CameraOcclusionSystem.clearance(AT, camera, {}, nil)).to.be.near(12, 1e-3)
			proxy:SetAttribute(CameraOccluderConstants.ATTRIBUTE, true)
			expect(CameraOcclusionSystem.clearance(AT, camera, {}, nil)).to.be.near(5 - RADIUS, 1e-2)
		end)

		it("looks through non-blocking parts to a wall behind them", function()
			wall(3, { Transparency = 1 })
			wall(4, { CanCollide = false })
			wall(8)
			expect(CameraOcclusionSystem.clearance(AT, camera, {}, nil)).to.be.near(8 - RADIUS, 1e-2)
		end)

		it("ignores the listed instances and anything welded to the subject (a carried item)", function()
			local listed = wall(4)
			expect(CameraOcclusionSystem.clearance(AT, camera, { listed }, nil)).to.be.near(12, 1e-3)
			listed:Destroy()

			local subject = Instance.new("Part")
			subject.Size = Vector3.new(1, 1, 1)
			subject.CFrame = CFrame.new(AT)
			subject.CanCollide = false
			subject.Parent = box
			local carried = wall(2)
			carried.Anchored = false
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = subject
			weld.Part1 = carried
			weld.Parent = subject
			subject.Anchored = true
			expect(CameraOcclusionSystem.clearance(AT, camera, {}, subject)).to.be.near(12, 1e-3)
		end)

		it("is zero for a camera on its focus (first person)", function()
			wall(0.2)
			expect(CameraOcclusionSystem.clearance(AT, AT, {}, nil)).to.equal(0)
		end)
	end)
end
