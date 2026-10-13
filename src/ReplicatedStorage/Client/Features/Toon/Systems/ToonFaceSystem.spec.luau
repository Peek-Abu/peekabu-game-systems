local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ToonConstants = require(ReplicatedStorage.Shared.Features.Toon.Data.ToonConstants)
local ToonFaceSystem = require(script.Parent.ToonFaceSystem)

return function()
	local function makeToon()
		local model = Instance.new("Model")
		model:SetAttribute(ToonConstants.NAME_ATTRIBUTE, "Pippa")
		local plate = Instance.new("MeshPart") -- a SurfaceAppearance only parents to MeshParts
		plate.Name = ToonConstants.FACE_PLATE
		plate.Parent = model
		local current = Instance.new("SurfaceAppearance")
		current.Name = ToonConstants.FACE_APPEARANCE
		current.Parent = plate
		local faces = Instance.new("Folder")
		faces.Name = ToonConstants.FACES_FOLDER
		faces.Parent = model
		for _, face in { "Happy", "Worried", "Content" } do
			local appearance = Instance.new("SurfaceAppearance")
			appearance.Name = face
			appearance.Parent = faces
		end
		return model, plate
	end

	local function faceOf(plate)
		local appearances = {}
		for _, child in plate:GetChildren() do
			if child:IsA("SurfaceAppearance") then
				table.insert(appearances, child)
			end
		end
		return appearances
	end

	describe("apply", function()
		it("puts a copy of the chosen face on the FacePlate as its only SurfaceAppearance", function()
			local model, plate = makeToon()
			expect(ToonFaceSystem.apply(model, "Worried")).to.equal(true)
			local appearances = faceOf(plate)
			expect(#appearances).to.equal(1)
			expect(appearances[1].Name).to.equal(ToonConstants.FACE_APPEARANCE)
			expect(appearances[1]:GetAttribute(ToonConstants.FACE_ATTRIBUTE)).to.equal("Worried")
			-- The source stays in the Faces folder for the next swap.
			expect(model[ToonConstants.FACES_FOLDER]:FindFirstChild("Worried")).to.be.ok()
			model:Destroy()
		end)

		it("does not rebuild the face when it is already showing", function()
			local model, plate = makeToon()
			ToonFaceSystem.apply(model, "Content")
			local first = plate:FindFirstChild(ToonConstants.FACE_APPEARANCE)
			ToonFaceSystem.apply(model, "Content")
			expect(plate:FindFirstChild(ToonConstants.FACE_APPEARANCE)).to.equal(first)
			model:Destroy()
		end)

		it("refuses a model without a face plate or the face", function()
			local model = Instance.new("Model")
			expect(ToonFaceSystem.apply(model, "Happy")).to.equal(false)
			local toon, plate = makeToon()
			toon[ToonConstants.FACES_FOLDER].Happy:Destroy()
			expect(ToonFaceSystem.apply(toon, "Happy")).to.equal(false)
			expect(#faceOf(plate)).to.equal(1)
			model:Destroy()
			toon:Destroy()
		end)
	end)

	describe("bind", function()
		it("follows the replicated face attribute until released", function()
			local model, plate = makeToon()
			model:SetAttribute(ToonConstants.FACE_ATTRIBUTE, "Happy")
			local release = ToonFaceSystem.bind(model)
			expect(plate[ToonConstants.FACE_APPEARANCE]:GetAttribute(ToonConstants.FACE_ATTRIBUTE)).to.equal("Happy")
			model:SetAttribute(ToonConstants.FACE_ATTRIBUTE, "Worried")
			task.wait()
			expect(plate[ToonConstants.FACE_APPEARANCE]:GetAttribute(ToonConstants.FACE_ATTRIBUTE)).to.equal("Worried")
			release()
			model:SetAttribute(ToonConstants.FACE_ATTRIBUTE, "Content")
			task.wait()
			expect(plate[ToonConstants.FACE_APPEARANCE]:GetAttribute(ToonConstants.FACE_ATTRIBUTE)).to.equal("Worried")
			model:Destroy()
		end)

		it("ignores an unknown face value", function()
			local model, plate = makeToon()
			local before = plate[ToonConstants.FACE_APPEARANCE]
			model:SetAttribute(ToonConstants.FACE_ATTRIBUTE, "Angry")
			local release = ToonFaceSystem.bind(model)
			expect(plate[ToonConstants.FACE_APPEARANCE]).to.equal(before)
			release()
			model:Destroy()
		end)
	end)
end
