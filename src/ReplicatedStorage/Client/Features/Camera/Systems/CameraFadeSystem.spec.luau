local CameraFadeSystem = require(script.Parent.CameraFadeSystem)

return function()
	local made = {}
	afterEach(function()
		for _, instance in made do
			instance:Destroy()
		end
		table.clear(made)
	end)

	-- A character with a body part, a face decal, an accessory (the ears) and something held (the vacuum).
	local function character()
		local model = Instance.new("Model")
		local head = Instance.new("Part")
		head.Name = "Head"
		head.Parent = model
		local face = Instance.new("Decal")
		face.Parent = head
		local accessory = Instance.new("Accessory")
		local handle = Instance.new("Part")
		handle.Name = "Handle"
		handle.Parent = accessory
		accessory.Parent = model
		local held = Instance.new("Model")
		local wand = Instance.new("Part")
		wand.Parent = held
		held.Parent = model
		table.insert(made, model)
		return model, { head, face, handle, wand }
	end

	local function all(pieces, value)
		for _, piece in pieces do
			if math.abs(piece.LocalTransparencyModifier - value) > 1e-6 then
				return false
			end
		end
		return true
	end

	describe("apply", function()
		it("fades every part and decal of the character, accessories and held things included", function()
			local fader = CameraFadeSystem.new()
			local model, pieces = character()
			CameraFadeSystem.apply(fader, model, 0.6)
			expect(all(pieces, 0.6)).to.equal(true)
			expect(fader.written).to.equal(0.6)
		end)

		it("covers parts added while the fade holds", function()
			local fader = CameraFadeSystem.new()
			local model = character()
			CameraFadeSystem.apply(fader, model, 0.5)
			local late = Instance.new("Part")
			late.Parent = model
			CameraFadeSystem.apply(fader, model, 0.5)
			expect(late.LocalTransparencyModifier).to.equal(0.5)
		end)

		it("shows the character again once, when the fade ends", function()
			local fader = CameraFadeSystem.new()
			local model, pieces = character()
			CameraFadeSystem.apply(fader, model, 0.8)
			CameraFadeSystem.apply(fader, model, 0)
			expect(all(pieces, 0)).to.equal(true)
			expect(fader.written).to.equal(0)
		end)

		it("leaves another owner's transparency alone while it has nothing to fade", function()
			local fader = CameraFadeSystem.new()
			local model, pieces = character()
			for _, piece in pieces do
				piece.LocalTransparencyModifier = 1
			end
			CameraFadeSystem.apply(fader, model, 0)
			expect(all(pieces, 1)).to.equal(true)
		end)

		it("shows the previous character when the subject changes", function()
			local fader = CameraFadeSystem.new()
			local first, firstPieces = character()
			local second, secondPieces = character()
			CameraFadeSystem.apply(fader, first, 0.7)
			CameraFadeSystem.apply(fader, second, 0.4)
			expect(all(firstPieces, 0)).to.equal(true)
			expect(all(secondPieces, 0.4)).to.equal(true)
		end)
	end)

	describe("release", function()
		it("shows a faded character again and forgets it", function()
			local fader = CameraFadeSystem.new()
			local model, pieces = character()
			CameraFadeSystem.apply(fader, model, 0.9)
			CameraFadeSystem.release(fader)
			expect(all(pieces, 0)).to.equal(true)
			expect(fader.character).to.equal(nil)
			expect(fader.written).to.equal(0)
		end)
	end)
end
