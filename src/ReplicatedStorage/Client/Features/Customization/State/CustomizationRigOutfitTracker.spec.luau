--!strict
--[=[
	Unit tests for CustomizationRigOutfitTracker — the per-rig worn record and its part/socket indexes.
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CustomizationRigOutfitTracker =
	require(ReplicatedStorage.Client.Features.Customization.State.CustomizationRigOutfitTracker)

return function()
	local function part(name, parent)
		local p = Instance.new("Part")
		p.Name = name
		p.Parent = parent
		return p
	end

	local function rig()
		local model = Instance.new("Model")
		local head = part("Head", model)
		local socket = Instance.new("Attachment")
		socket.Name = "Hair"
		socket.Parent = head
		part("Skin Color", model)
		part("Skin Color-Uncovered", head)
		part("Skin Colorful", model) -- not a variant: no "-" separator
		-- An accessory already inside the template must never be indexed as the rig's own.
		local accessory = Instance.new("Accessory")
		accessory.Parent = model
		local handle = part("Handle", accessory)
		local inner = Instance.new("Attachment")
		inner.Name = "Hat"
		inner.Parent = handle
		part("Skin Color", handle)
		return model
	end

	describe("indexes", function()
		it("finds a channel's exact and suffixed parts, outside accessories only", function()
			local model = rig()
			local outfit = CustomizationRigOutfitTracker.new(model)
			local found = CustomizationRigOutfitTracker.partsFor(outfit, "Skin Color")
			expect(#found).to.equal(2)
			model:Destroy()
		end)

		it("caches the lookup", function()
			local model = rig()
			local outfit = CustomizationRigOutfitTracker.new(model)
			expect(CustomizationRigOutfitTracker.partsFor(outfit, "Skin Color")).to.equal(
				CustomizationRigOutfitTracker.partsFor(outfit, "Skin Color")
			)
			model:Destroy()
		end)

		it("finds rig sockets but not attachments inside accessories", function()
			local model = rig()
			local outfit = CustomizationRigOutfitTracker.new(model)
			expect(CustomizationRigOutfitTracker.socket(outfit, "Hair")).to.be.ok()
			expect(CustomizationRigOutfitTracker.socket(outfit, "Hat")).to.equal(nil)
			model:Destroy()
		end)
	end)

	describe("ownership", function()
		it("starts undressed", function()
			local model = rig()
			local outfit = CustomizationRigOutfitTracker.new(model)
			expect(CustomizationRigOutfitTracker.isDressed(outfit)).to.equal(false)
			model:Destroy()
		end)

		it("keeps the version for the same owner and undresses for a new one", function()
			local model = rig()
			local outfit = CustomizationRigOutfitTracker.new(model)
			CustomizationRigOutfitTracker.assign(outfit, 1)
			local worn = outfit.worn
			CustomizationRigOutfitTracker.setWorn(outfit, worn, 3)
			CustomizationRigOutfitTracker.assign(outfit, 1)
			expect(outfit.version).to.equal(3)
			CustomizationRigOutfitTracker.assign(outfit, 2)
			expect(outfit.version).to.equal(CustomizationRigOutfitTracker.UNDRESSED)
			expect(outfit.ownerUserId).to.equal(2)
			-- The record of what is physically on the rig survives the hand-over.
			expect(outfit.worn).to.equal(worn)
			model:Destroy()
		end)
	end)
end
