--!strict
--[=[
	Unit tests for CustomizationRigLookSystem — undoable edits to a rig's own parts. In-memory parts only; the place art
	is never needed (a missing pattern is the "restore" path).
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CustomizationRigLookSystem =
	require(ReplicatedStorage.Client.Features.Customization.Systems.CustomizationRigLookSystem)
local CustomizationRigOutfitTracker =
	require(ReplicatedStorage.Client.Features.Customization.State.CustomizationRigOutfitTracker)

return function()
	local model

	beforeEach(function()
		model = Instance.new("Model")
	end)

	afterEach(function()
		model:Destroy()
	end)

	describe("setColor", function()
		it("sets, then restores the authored colour on nil", function()
			local part = Instance.new("Part")
			part.Color = Color3.fromRGB(10, 20, 30)
			part.Parent = model
			CustomizationRigLookSystem.setColor(part, { r = 200, g = 0, b = 0 })
			expect(part.Color).to.equal(Color3.fromRGB(200, 0, 0))
			CustomizationRigLookSystem.setColor(part, { r = 0, g = 200, b = 0 })
			CustomizationRigLookSystem.setColor(part, nil)
			expect(part.Color).to.equal(Color3.fromRGB(10, 20, 30))
		end)
	end)

	describe("setVisibility", function()
		it("hides a subtree, then restores each part's own authored transparency", function()
			local root = Instance.new("Part")
			root.Transparency = 0.2
			root.Parent = model
			local child = Instance.new("Part")
			child.Transparency = 0.7
			child.Parent = root
			local decal = Instance.new("Decal")
			decal.Transparency = 0.4
			decal.Parent = child
			CustomizationRigLookSystem.setVisibility(root, false)
			expect(root.Transparency).to.equal(1)
			expect(decal.Transparency).to.equal(1)
			CustomizationRigLookSystem.setVisibility(root, true)
			expect(child.Transparency).to.equal(0)
			CustomizationRigLookSystem.setVisibility(root, nil)
			expect(root.Transparency).to.be.near(0.2)
			expect(child.Transparency).to.be.near(0.7)
			expect(decal.Transparency).to.be.near(0.4)
		end)
	end)

	describe("setSurface", function()
		it("puts the rig's authored surface back when the channel is cleared", function()
			local part = Instance.new("MeshPart")
			part.Name = "Backpack Color 1"
			part.Parent = model
			local authored = Instance.new("SurfaceAppearance")
			authored.Name = "Authored"
			authored.Parent = part
			local outfit = CustomizationRigOutfitTracker.new(model)
			-- Capture happens on first touch; then stand in for an applied pattern.
			CustomizationRigLookSystem.setSurface(outfit, { part = "Backpack Color 1", artFolder = "NoSuchFolder" })
			authored:Destroy()
			local applied = Instance.new("SurfaceAppearance")
			applied:SetAttribute("VentureCosmetic", true)
			applied.Parent = part
			CustomizationRigLookSystem.setSurface(outfit, { part = "Backpack Color 1", artFolder = "NoSuchFolder" })
			local now = part:FindFirstChildOfClass("SurfaceAppearance")
			expect(now).to.be.ok()
			expect(now.Name).to.equal("Authored")
			expect(now:GetAttribute("VentureCosmetic")).to.equal(nil)
		end)

		it("never removes a surface it did not apply", function()
			local part = Instance.new("MeshPart")
			part.Name = "Backpack Color 1"
			part.Parent = model
			local own = Instance.new("SurfaceAppearance")
			own.Parent = part
			CustomizationRigLookSystem.setSurface(
				CustomizationRigOutfitTracker.new(model),
				{ part = "Backpack Color 1", artFolder = "NoSuchFolder" }
			)
			expect(own.Parent).to.equal(part)
		end)
	end)

	describe("findArt", function()
		it("is nil for a folder the art root does not have", function()
			expect(CustomizationRigLookSystem.findArt("NoSuchFolder", "Anything")).to.equal(nil)
		end)
	end)
end
