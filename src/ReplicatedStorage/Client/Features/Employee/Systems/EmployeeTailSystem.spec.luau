local ReplicatedStorage = game:GetService("ReplicatedStorage")

local EmployeeConstants = require(ReplicatedStorage.Shared.Features.Employee.Data.EmployeeConstants)
local EmployeeTailSystem = require(script.Parent.EmployeeTailSystem)

return function()
	local function part(model, name, cframe, size)
		local p = Instance.new("Part")
		p.Name = name
		p.Anchored = true
		p.Size = size or Vector3.new(1, 1, 1)
		p.CFrame = cframe
		p.Parent = model
		return p
	end

	-- A character with a 3-link tail (Tail R1..R3 + the R4 end marker) hanging behind LowerTorso.
	local function makeCharacter(position, withTail)
		local model = Instance.new("Model")
		local root = part(model, "HumanoidRootPart", CFrame.new(position))
		model.PrimaryPart = root
		local lower = part(model, "LowerTorso", CFrame.new(position + Vector3.new(0, 1, 0)))
		part(model, "LeftUpperLeg", CFrame.new(position + Vector3.new(-0.4, 0.3, 0)), Vector3.new(0.5, 0.8, 0.5))
		part(model, "RightUpperLeg", CFrame.new(position + Vector3.new(0.4, 0.3, 0)), Vector3.new(0.5, 0.8, 0.5))
		part(model, "LeftFoot", CFrame.new(position + Vector3.new(-0.4, -0.9, 0)), Vector3.new(0.5, 0.2, 0.7))
		part(model, "RightFoot", CFrame.new(position + Vector3.new(0.4, -0.9, 0)), Vector3.new(0.5, 0.2, 0.7))
		local bones = {}
		if withTail ~= false then
			for n = 1, 4 do
				local bone = Instance.new("Bone")
				bone.Name = "TailR" .. n .. "Bone"
				bone.CFrame = CFrame.new(0, -0.2 - 0.4 * (n - 1), 0.6)
				bone:SetAttribute(EmployeeConstants.OUTFIT_BONE_ATTRIBUTE, true)
				bone.Parent = lower
				bones[n] = bone
			end
		end
		return model, root, lower, bones
	end

	local function isIdentity(cframe)
		return cframe.Position.Magnitude < 1e-6 and cframe.LookVector:Dot(Vector3.new(0, 0, -1)) > 0.999999
	end

	local function moveBody(model, offset)
		for _, p in model:GetChildren() do
			if p:IsA("BasePart") then
				p.CFrame += offset
			end
		end
	end

	local FOCUS = Vector3.new(0, 0, 10)

	describe("step", function()
		it("swings the tail links of a nearby character when the body moves", function()
			local tails = EmployeeTailSystem.new()
			local model, _, _, bones = makeCharacter(Vector3.zero)
			local untrack = tails.track(model)
			tails.step(1 / 30, FOCUS)
			moveBody(model, Vector3.new(0, 0, -1))
			for _ = 1, 3 do
				tails.step(1 / 30, FOCUS)
			end
			expect(isIdentity(bones[1].Transform) and isIdentity(bones[2].Transform)).to.equal(false)
			expect(isIdentity(bones[4].Transform)).to.equal(true)
			expect(tails.getState().active).to.equal(1)
			untrack()
			model:Destroy()
		end)

		it("leaves far characters at rest", function()
			local tails = EmployeeTailSystem.new()
			local model, _, _, bones = makeCharacter(Vector3.zero)
			local untrack = tails.track(model)
			local far = Vector3.new(EmployeeConstants.TAIL_RADIUS + 50, 0, 0)
			tails.step(1 / 30, far)
			moveBody(model, Vector3.new(0, 0, -1))
			tails.step(1 / 30, far)
			for n = 1, 3 do
				expect(isIdentity(bones[n].Transform)).to.equal(true)
			end
			expect(tails.getState().active).to.equal(0)
			untrack()
			model:Destroy()
		end)

		it("ignores bones the outfit fit did not add, and characters without a tail", function()
			local tails = EmployeeTailSystem.new()
			local model, _, lower = makeCharacter(Vector3.zero, false)
			local stray = Instance.new("Bone")
			stray.Name = "TailR1Bone"
			stray.Parent = lower
			local untrack = tails.track(model)
			tails.step(1 / 30, FOCUS)
			moveBody(model, Vector3.new(0, 0, -1))
			tails.step(1 / 30, FOCUS)
			expect(isIdentity(stray.Transform)).to.equal(true)
			expect(tails.getState().active).to.equal(0)
			untrack()
			model:Destroy()
		end)

		it("picks up a tail fitted after tracking began", function()
			local tails = EmployeeTailSystem.new()
			local model, _, lower = makeCharacter(Vector3.zero, false)
			local untrack = tails.track(model)
			local first
			for n = 1, 3 do
				local bone = Instance.new("Bone")
				bone.Name = "TailL" .. n .. "Bone"
				bone.CFrame = CFrame.new(0, -0.2 - 0.4 * (n - 1), 0.6)
				bone:SetAttribute(EmployeeConstants.OUTFIT_BONE_ATTRIBUTE, true)
				bone.Parent = lower
				first = first or bone
			end
			tails.step(1 / 30, FOCUS)
			moveBody(model, Vector3.new(0, 0, -1))
			tails.step(1 / 30, FOCUS)
			expect(isIdentity(first.Transform)).to.equal(false)
			untrack()
			model:Destroy()
		end)

		it("leaves a hiding character's tail to the hide pose", function()
			local tails = EmployeeTailSystem.new(function()
				return true
			end)
			local model, _, _, bones = makeCharacter(Vector3.zero)
			local untrack = tails.track(model)
			tails.step(1 / 30, FOCUS)
			moveBody(model, Vector3.new(0, 0, -1))
			tails.step(1 / 30, FOCUS)
			expect(isIdentity(bones[1].Transform)).to.equal(true)
			untrack()
			model:Destroy()
		end)
	end)

	describe("SmartBone outfits", function()
		local CollectionService = game:GetService("CollectionService")

		it("hands the tails of an outfit that asks for SmartBone over to it, and our spring leaves them", function()
			local tails = EmployeeTailSystem.new()
			local model, _, lower, bones = makeCharacter(Vector3.zero)
			local folder = Instance.new("Folder")
			folder.Name = EmployeeConstants.OUTFIT_FOLDER
			folder:SetAttribute(EmployeeConstants.TAIL_PHYSICS_ATTRIBUTE, EmployeeConstants.TAIL_PHYSICS_SMARTBONE)
			folder.Parent = model
			local untrack = tails.track(model)
			tails.step(1 / 30, FOCUS)
			expect(CollectionService:HasTag(lower, EmployeeConstants.SMARTBONE_TAG)).to.equal(true)
			moveBody(model, Vector3.new(0, 0, -1))
			tails.step(1 / 30, FOCUS)
			expect(isIdentity(bones[1].Transform)).to.equal(true)
			expect(tails.getState().active).to.equal(0)
			untrack()
			expect(CollectionService:HasTag(lower, EmployeeConstants.SMARTBONE_TAG)).to.equal(false)
			model:Destroy()
		end)
	end)

	describe("track", function()
		it("puts the tail back at rest when released", function()
			local tails = EmployeeTailSystem.new()
			local model, _, _, bones = makeCharacter(Vector3.zero)
			local untrack = tails.track(model)
			tails.step(1 / 30, FOCUS)
			moveBody(model, Vector3.new(0, 0, -1))
			tails.step(1 / 30, FOCUS)
			untrack()
			for n = 1, 3 do
				expect(isIdentity(bones[n].Transform)).to.equal(true)
			end
			expect(tails.getState().tracked).to.equal(0)
			model:Destroy()
		end)
	end)
end
