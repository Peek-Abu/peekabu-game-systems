--!strict
--[=[
	Unit tests for ReplicationRigCheck.unattachedParts: every unanchored part of the rig must be joined to the root
	through enabled joints, or it falls off the client-built body at spawn (found in staging: the rig's old
	foot boots had a weld with an empty Part1).
]=]

local ReplicationRigCheck = require(script.Parent.ReplicationRigCheck)

return function()
	local function part(name: string, parent: Instance): Part
		local p = Instance.new("Part")
		p.Name = name
		p.Parent = parent
		return p
	end

	local function weld(a: BasePart, b: BasePart?, parent: Instance): WeldConstraint
		local w = Instance.new("WeldConstraint")
		w.Part0 = a
		w.Part1 = b
		w.Parent = parent
		return w
	end

	local function rig(): (Model, Part)
		local model = Instance.new("Model")
		local root = part("HumanoidRootPart", model)
		return model, root
	end

	local function names(parts: { BasePart }): { string }
		local out = {}
		for _, p in parts do
			table.insert(out, p.Name)
		end
		table.sort(out)
		return out
	end

	it("finds nothing when every part is joined to the root", function()
		local model, root = rig()
		local torso = part("Torso", model)
		local trim = part("Trim", torso)
		weld(root, torso, root)
		weld(torso, trim, trim)
		expect(#ReplicationRigCheck.unattachedParts(model, root)).to.equal(0)
		model:Destroy()
	end)

	it("reports a group welded only to itself, with an empty Part1 on the link", function()
		local model, root = rig()
		local foot = part("Foot", model)
		weld(root, foot, root)
		local bootA = part("BootA", foot)
		local bootB = part("BootB", foot)
		weld(bootA, bootB, bootA)
		weld(bootA, nil, bootA) -- the broken link to the foot
		expect(table.concat(names(ReplicationRigCheck.unattachedParts(model, root)), ",")).to.equal("BootA,BootB")
		model:Destroy()
	end)

	it("treats a disabled joint as no joint", function()
		local model, root = rig()
		local arm = part("Arm", model)
		weld(root, arm, root).Enabled = false
		expect(table.concat(names(ReplicationRigCheck.unattachedParts(model, root)), ",")).to.equal("Arm")
		model:Destroy()
	end)

	it("follows Motor6D joints and RigidConstraint attachments", function()
		local model, root = rig()
		local leg = part("Leg", model)
		local motor = Instance.new("Motor6D")
		motor.Part0 = root
		motor.Part1 = leg
		motor.Parent = root
		local pad = part("Pad", leg)
		local a0 = Instance.new("Attachment")
		a0.Parent = leg
		local a1 = Instance.new("Attachment")
		a1.Parent = pad
		local rigid = Instance.new("RigidConstraint")
		rigid.Attachment0 = a0
		rigid.Attachment1 = a1
		rigid.Parent = pad
		expect(#ReplicationRigCheck.unattachedParts(model, root)).to.equal(0)
		model:Destroy()
	end)

	it("follows a hinge whose attachment sits under a Bone", function()
		local model, root = rig()
		local cape = part("Cape", model)
		local bone = Instance.new("Bone")
		bone.Parent = root
		local a0 = Instance.new("Attachment")
		a0.Parent = bone
		local a1 = Instance.new("Attachment")
		a1.Parent = cape
		local hinge = Instance.new("HingeConstraint")
		hinge.Attachment0 = a0
		hinge.Attachment1 = a1
		hinge.Parent = cape
		expect(#ReplicationRigCheck.unattachedParts(model, root)).to.equal(0)
		model:Destroy()
	end)

	it("ignores anchored parts, which cannot fall", function()
		local model, root = rig()
		part("Marker", model).Anchored = true
		expect(#ReplicationRigCheck.unattachedParts(model, root)).to.equal(0)
		model:Destroy()
	end)

	it("names a part by its path inside the rig", function()
		local model, root = rig()
		local foot = part("Foot", model)
		weld(root, foot, root)
		part("Boot", foot)
		expect(ReplicationRigCheck.describe(model, ReplicationRigCheck.unattachedParts(model, root))).to.equal(
			"Foot.Boot"
		)
		model:Destroy()
	end)
end
