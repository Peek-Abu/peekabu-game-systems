local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local EmployeeConstants = require(ReplicatedStorage.Shared.Features.Employee.Data.EmployeeConstants)
local EmployeeTailSmartBoneUtils = require(script.Parent.EmployeeTailSmartBoneUtils)

return function()
	local function part(model, name, cframe)
		local p = Instance.new("Part")
		p.Name = name
		p.Anchored = true
		p.CFrame = cframe
		p.Parent = model
		return p
	end

	-- A character wearing an outfit with two 3-link tails (R1..R3, L1..L3, plus the R4 / L4 end markers).
	local function makeCharacter(physics)
		local model = Instance.new("Model")
		local lower = part(model, "LowerTorso", CFrame.new(0, 3, 0))
		for _, name in EmployeeConstants.SMARTBONE_LEG_COLLIDERS do
			part(model, name, CFrame.new(0, 1, 0))
		end
		local folder = Instance.new("Folder")
		folder.Name = EmployeeConstants.OUTFIT_FOLDER
		if physics then
			folder:SetAttribute(EmployeeConstants.TAIL_PHYSICS_ATTRIBUTE, physics)
		end
		folder.Parent = model
		for _, side in { "R", "L" } do
			for n = 1, 4 do
				local bone = Instance.new("Bone")
				bone.Name = "Tail" .. side .. n .. "Bone"
				bone.CFrame = CFrame.new(if side == "R" then 0.5 else -0.5, -0.3 * n, 0.6)
				bone:SetAttribute(EmployeeConstants.OUTFIT_BONE_ATTRIBUTE, true)
				bone.Parent = lower
			end
		end
		return model, lower, folder
	end

	describe("wantsSmartBone", function()
		it("is true only when the fitted outfit asks for SmartBone", function()
			local a = makeCharacter(EmployeeConstants.TAIL_PHYSICS_SMARTBONE)
			local b = makeCharacter(nil)
			expect(EmployeeTailSmartBoneUtils.wantsSmartBone(a)).to.equal(true)
			expect(EmployeeTailSmartBoneUtils.wantsSmartBone(b)).to.equal(false)
			expect(EmployeeTailSmartBoneUtils.wantsSmartBone(Instance.new("Model"))).to.equal(false)
			a:Destroy()
			b:Destroy()
		end)
	end)

	describe("settings", function()
		it("starts from the defaults and lets the outfit's Tail<name> attributes override them", function()
			local _, _, folder = makeCharacter(EmployeeConstants.TAIL_PHYSICS_SMARTBONE)
			folder:SetAttribute("TailDamping", 0.4)
			local s = EmployeeTailSmartBoneUtils.settings(folder)
			expect(s.Damping).to.equal(0.4)
			expect(s.Constraint).to.equal(EmployeeConstants.SMARTBONE_DEFAULTS.Constraint)
			expect(s.Physics).to.equal(nil)
		end)

		it("leaves the per-bone TailBone<name> attributes out of the root part's settings", function()
			local _, _, folder = makeCharacter(EmployeeConstants.TAIL_PHYSICS_SMARTBONE)
			folder:SetAttribute("TailBoneRadius", 0.3)
			local s = EmployeeTailSmartBoneUtils.settings(folder)
			expect(s.BoneRadius).to.equal(nil)
			expect(s.Radius).to.equal(nil)
		end)
	end)

	-- Showstopper's robe (owner 11-17 "Yes lets do smartbone!"): heavy wool needs a bend limit, a cloth radius against
	-- the leg colliders and a ceiling so the skirt never flips up on a jump, on each simulated bone.
	describe("boneSettings", function()
		it("reads the outfit's TailBone<name> attributes, lengths scaled by the character's scale", function()
			local _, _, folder = makeCharacter(EmployeeConstants.TAIL_PHYSICS_SMARTBONE)
			folder:SetAttribute("TailBoneRotationLimit", 25)
			folder:SetAttribute("TailBoneRadius", 0.3)
			folder:SetAttribute("TailBoneYAxisLimits", NumberRange.new(-4, 0.4))
			local s = EmployeeTailSmartBoneUtils.boneSettings(folder, 1.25)
			expect(s.RotationLimit).to.equal(25)
			expect(math.abs(s.Radius - 0.375) < 1e-6).to.equal(true)
			expect(math.abs(s.YAxisLimits.Min + 5) < 1e-6).to.equal(true)
			expect(math.abs(s.YAxisLimits.Max - 0.5) < 1e-6).to.equal(true)
		end)
	end)

	describe("prepare", function()
		it("nests each tail into a bone chain, keeping every bone where it was in the world", function()
			local model, lower = makeCharacter(EmployeeConstants.TAIL_PHYSICS_SMARTBONE)
			local before = lower.TailR3Bone.WorldPosition
			expect(EmployeeTailSmartBoneUtils.prepare(model)).to.equal(true)
			local r1 = lower:FindFirstChild("TailR1Bone")
			expect(r1).to.be.ok()
			local r3 = r1:FindFirstChild("TailR3Bone", true)
			expect(r3).to.be.ok()
			expect((r3.WorldPosition - before).Magnitude < 1e-4).to.equal(true)
			expect(r1:FindFirstChild("TailR4Bone_end", true)).to.be.ok()
			expect(lower:FindFirstChild("TailR2Bone")).to.equal(nil)
			model:Destroy()
		end)

		it("takes the bones away from our own spring (no outfit-bone mark on the chain)", function()
			local model, lower = makeCharacter(EmployeeConstants.TAIL_PHYSICS_SMARTBONE)
			EmployeeTailSmartBoneUtils.prepare(model)
			expect(lower.TailL1Bone:GetAttribute(EmployeeConstants.OUTFIT_BONE_ATTRIBUTE)).to.equal(nil)
			model:Destroy()
		end)

		it("tags the root part for SmartBone with its roots and settings, and its own legs as its colliders", function()
			local model, lower, folder = makeCharacter(EmployeeConstants.TAIL_PHYSICS_SMARTBONE)
			folder:SetAttribute("TailStiffness", 0.7)
			EmployeeTailSmartBoneUtils.prepare(model)
			expect(CollectionService:HasTag(lower, EmployeeConstants.SMARTBONE_TAG)).to.equal(true)
			local roots = string.split(lower:GetAttribute("Roots"), ",")
			table.sort(roots)
			expect(table.concat(roots, ",")).to.equal("TailL1Bone,TailR1Bone")
			expect(lower:GetAttribute("Stiffness")).to.equal(0.7)
			local key = lower:GetAttribute("ColliderKey")
			expect(type(key)).to.equal("string")
			for _, name in EmployeeConstants.SMARTBONE_LEG_COLLIDERS do
				local leg = model[name]
				expect(CollectionService:HasTag(leg, EmployeeConstants.SMARTBONE_COLLIDER_TAG)).to.equal(true)
				expect(leg:GetAttribute("ColliderKey")).to.equal(key)
			end
			EmployeeTailSmartBoneUtils.release(model)
			model:Destroy()
		end)

		it("puts the per-bone settings on every simulated bone below each chain's root, not on the root", function()
			local model, lower, folder = makeCharacter(EmployeeConstants.TAIL_PHYSICS_SMARTBONE)
			folder:SetAttribute("TailBoneRotationLimit", 25)
			EmployeeTailSmartBoneUtils.prepare(model)
			local r1 = lower.TailR1Bone
			expect(r1:GetAttribute("RotationLimit")).to.equal(nil)
			expect(r1:FindFirstChild("TailR2Bone", true):GetAttribute("RotationLimit")).to.equal(25)
			expect(r1:FindFirstChild("TailR3Bone", true):GetAttribute("RotationLimit")).to.equal(25)
			EmployeeTailSmartBoneUtils.release(model)
			model:Destroy()
		end)

		it("gives each character its own collider key, so tails only hit their own legs", function()
			local a = makeCharacter(EmployeeConstants.TAIL_PHYSICS_SMARTBONE)
			local b = makeCharacter(EmployeeConstants.TAIL_PHYSICS_SMARTBONE)
			EmployeeTailSmartBoneUtils.prepare(a)
			EmployeeTailSmartBoneUtils.prepare(b)
			expect(a.LowerTorso:GetAttribute("ColliderKey")).never.to.equal(b.LowerTorso:GetAttribute("ColliderKey"))
			EmployeeTailSmartBoneUtils.release(a)
			EmployeeTailSmartBoneUtils.release(b)
			a:Destroy()
			b:Destroy()
		end)

		it("does nothing for an outfit that doesn't ask for SmartBone, or a character with no tails", function()
			local plain = makeCharacter(nil)
			expect(EmployeeTailSmartBoneUtils.prepare(plain)).to.equal(false)
			expect(CollectionService:HasTag(plain.LowerTorso, EmployeeConstants.SMARTBONE_TAG)).to.equal(false)
			local bare = Instance.new("Model")
			part(bare, "LowerTorso", CFrame.new())
			local folder = Instance.new("Folder")
			folder.Name = EmployeeConstants.OUTFIT_FOLDER
			folder:SetAttribute(EmployeeConstants.TAIL_PHYSICS_ATTRIBUTE, EmployeeConstants.TAIL_PHYSICS_SMARTBONE)
			folder.Parent = bare
			expect(EmployeeTailSmartBoneUtils.prepare(bare)).to.equal(false)
			plain:Destroy()
			bare:Destroy()
		end)
	end)

	describe("release", function()
		it("removes the SmartBone tags from the root part and the legs", function()
			local model, lower = makeCharacter(EmployeeConstants.TAIL_PHYSICS_SMARTBONE)
			EmployeeTailSmartBoneUtils.prepare(model)
			EmployeeTailSmartBoneUtils.release(model)
			expect(CollectionService:HasTag(lower, EmployeeConstants.SMARTBONE_TAG)).to.equal(false)
			expect(CollectionService:HasTag(model.LeftUpperLeg, EmployeeConstants.SMARTBONE_COLLIDER_TAG)).to.equal(
				false
			)
			model:Destroy()
		end)
	end)
end
