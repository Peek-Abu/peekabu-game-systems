local HideBodySystem = require(script.Parent.HideBodySystem)

return function()
	-- A character with one part and one decal, not in the world, on a stand-in player.
	local function body()
		local model = Instance.new("Model")
		local part = Instance.new("Part")
		part.Parent = model
		local decal = Instance.new("Decal")
		decal.Parent = part
		return { Character = model }, model, part, decal
	end

	describe("setShown", function()
		it("hides every part and decal of the body from its own camera, and shows them back", function()
			local player, model, part, decal = body()
			HideBodySystem.setShown(player, false)
			expect(part.LocalTransparencyModifier).to.equal(1)
			expect(decal.LocalTransparencyModifier).to.equal(1)
			HideBodySystem.setShown(player, true)
			expect(part.LocalTransparencyModifier).to.equal(0)
			expect(decal.LocalTransparencyModifier).to.equal(0)
			model:Destroy()
		end)

		it("shows back what it hid even after it left the character", function()
			local player, model, part, decal = body()
			HideBodySystem.setShown(player, false)
			-- Put away meanwhile (a Tool moved to the Backpack): no longer in the character.
			part.Parent = nil
			HideBodySystem.setShown(player, true)
			expect(part.LocalTransparencyModifier).to.equal(0)
			expect(decal.LocalTransparencyModifier).to.equal(0)
			part:Destroy()
			model:Destroy()
		end)

		it("does nothing to a player without a character", function()
			HideBodySystem.setShown({ Character = nil }, false)
			HideBodySystem.setShown({ Character = nil }, true)
		end)
	end)
end
