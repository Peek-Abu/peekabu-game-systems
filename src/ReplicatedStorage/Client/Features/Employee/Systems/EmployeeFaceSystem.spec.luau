local ReplicatedStorage = game:GetService("ReplicatedStorage")

local EmployeeConstants = require(ReplicatedStorage.Shared.Features.Employee.Data.EmployeeConstants)
local EmployeeFaceSystem = require(script.Parent.EmployeeFaceSystem)

return function()
	local function makeEmployee()
		local model = Instance.new("Model")
		model:SetAttribute(EmployeeConstants.NAME_ATTRIBUTE, "Pippa")
		local plate = Instance.new("MeshPart") -- a SurfaceAppearance only parents to MeshParts
		plate.Name = EmployeeConstants.FACE_PLATE
		plate.Parent = model
		local current = Instance.new("SurfaceAppearance")
		current.Name = EmployeeConstants.FACE_APPEARANCE
		current.Parent = plate
		local faces = Instance.new("Folder")
		faces.Name = EmployeeConstants.FACES_FOLDER
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
			local model, plate = makeEmployee()
			expect(EmployeeFaceSystem.apply(model, "Worried")).to.equal(true)
			local appearances = faceOf(plate)
			expect(#appearances).to.equal(1)
			expect(appearances[1].Name).to.equal(EmployeeConstants.FACE_APPEARANCE)
			expect(appearances[1]:GetAttribute(EmployeeConstants.FACE_ATTRIBUTE)).to.equal("Worried")
			-- The source stays in the Faces folder for the next swap.
			expect(model[EmployeeConstants.FACES_FOLDER]:FindFirstChild("Worried")).to.be.ok()
			model:Destroy()
		end)

		it("does not rebuild the face when it is already showing", function()
			local model, plate = makeEmployee()
			EmployeeFaceSystem.apply(model, "Content")
			local first = plate:FindFirstChild(EmployeeConstants.FACE_APPEARANCE)
			EmployeeFaceSystem.apply(model, "Content")
			expect(plate:FindFirstChild(EmployeeConstants.FACE_APPEARANCE)).to.equal(first)
			model:Destroy()
		end)

		it("refuses a model without a face plate or the face", function()
			local model = Instance.new("Model")
			expect(EmployeeFaceSystem.apply(model, "Happy")).to.equal(false)
			local employee, plate = makeEmployee()
			employee[EmployeeConstants.FACES_FOLDER].Happy:Destroy()
			expect(EmployeeFaceSystem.apply(employee, "Happy")).to.equal(false)
			expect(#faceOf(plate)).to.equal(1)
			model:Destroy()
			employee:Destroy()
		end)
	end)

	describe("bind", function()
		it("follows the replicated face attribute until released", function()
			local model, plate = makeEmployee()
			model:SetAttribute(EmployeeConstants.FACE_ATTRIBUTE, "Happy")
			local release = EmployeeFaceSystem.bind(model)
			expect(plate[EmployeeConstants.FACE_APPEARANCE]:GetAttribute(EmployeeConstants.FACE_ATTRIBUTE)).to.equal(
				"Happy"
			)
			model:SetAttribute(EmployeeConstants.FACE_ATTRIBUTE, "Worried")
			task.wait()
			expect(plate[EmployeeConstants.FACE_APPEARANCE]:GetAttribute(EmployeeConstants.FACE_ATTRIBUTE)).to.equal(
				"Worried"
			)
			release()
			model:SetAttribute(EmployeeConstants.FACE_ATTRIBUTE, "Content")
			task.wait()
			expect(plate[EmployeeConstants.FACE_APPEARANCE]:GetAttribute(EmployeeConstants.FACE_ATTRIBUTE)).to.equal(
				"Worried"
			)
			model:Destroy()
		end)

		it("re-shows the current face from a face set the server swapped in", function()
			local model, plate = makeEmployee()
			model:SetAttribute(EmployeeConstants.FACE_ATTRIBUTE, "Happy")
			local release = EmployeeFaceSystem.bind(model)
			local before = plate[EmployeeConstants.FACE_APPEARANCE]
			model[EmployeeConstants.FACES_FOLDER]:Destroy()
			local swapped = Instance.new("Folder")
			for _, face in { "Happy", "Worried", "Content" } do
				local appearance = Instance.new("SurfaceAppearance")
				appearance.Name = face
				appearance:SetAttribute("Skin", "Special")
				appearance.Parent = swapped
			end
			swapped.Name = EmployeeConstants.FACES_FOLDER
			swapped.Parent = model
			task.wait()
			local after = plate[EmployeeConstants.FACE_APPEARANCE]
			expect(after).never.to.equal(before)
			expect(after:GetAttribute("Skin")).to.equal("Special")
			expect(after:GetAttribute(EmployeeConstants.FACE_ATTRIBUTE)).to.equal("Happy")
			release()
			model:Destroy()
		end)

		it("puts the face back on a FacePlate that streams back in with the authored face", function()
			-- StreamingEnabled: another player's FacePlate streams out and back in as a fresh copy of the server's
			-- plate, wearing the authored face, while the attribute has not changed.
			local model, plate = makeEmployee()
			model:SetAttribute(EmployeeConstants.FACE_ATTRIBUTE, "Content")
			local release = EmployeeFaceSystem.bind(model)
			plate:Destroy()
			local streamed = Instance.new("MeshPart")
			streamed.Name = EmployeeConstants.FACE_PLATE
			local authored = Instance.new("SurfaceAppearance")
			authored.Name = EmployeeConstants.FACE_APPEARANCE
			authored.Parent = streamed
			streamed.Parent = model
			task.wait()
			local appearances = faceOf(streamed)
			expect(#appearances).to.equal(1)
			expect(appearances[1]:GetAttribute(EmployeeConstants.FACE_ATTRIBUTE)).to.equal("Content")
			release()
			model:Destroy()
		end)

		it("shows the face on a FacePlate that arrives after bind, however late", function()
			local model, plate = makeEmployee()
			plate.Parent = nil
			model:SetAttribute(EmployeeConstants.FACE_ATTRIBUTE, "Worried")
			local release = EmployeeFaceSystem.bind(model)
			task.wait()
			plate.Parent = model
			task.wait()
			local appearances = faceOf(plate)
			expect(#appearances).to.equal(1)
			expect(appearances[1]:GetAttribute(EmployeeConstants.FACE_ATTRIBUTE)).to.equal("Worried")
			release()
			model:Destroy()
		end)

		it("stops watching for a returning FacePlate once released", function()
			local model, plate = makeEmployee()
			model:SetAttribute(EmployeeConstants.FACE_ATTRIBUTE, "Content")
			local release = EmployeeFaceSystem.bind(model)
			release()
			plate:Destroy()
			local streamed = Instance.new("MeshPart")
			streamed.Name = EmployeeConstants.FACE_PLATE
			local authored = Instance.new("SurfaceAppearance")
			authored.Name = EmployeeConstants.FACE_APPEARANCE
			authored.Parent = streamed
			streamed.Parent = model
			task.wait()
			expect(streamed[EmployeeConstants.FACE_APPEARANCE]).to.equal(authored)
			model:Destroy()
		end)

		it("ignores an unknown face value", function()
			local model, plate = makeEmployee()
			local before = plate[EmployeeConstants.FACE_APPEARANCE]
			model:SetAttribute(EmployeeConstants.FACE_ATTRIBUTE, "Angry")
			local release = EmployeeFaceSystem.bind(model)
			expect(plate[EmployeeConstants.FACE_APPEARANCE]).to.equal(before)
			release()
			model:Destroy()
		end)
	end)
end
