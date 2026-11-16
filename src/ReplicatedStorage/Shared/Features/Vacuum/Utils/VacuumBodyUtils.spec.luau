local ReplicatedStorage = game:GetService("ReplicatedStorage")

local VacuumBodyUtils = require(script.Parent.VacuumBodyUtils)
local VacuumConstants = require(ReplicatedStorage.Shared.Features.Vacuum.Data.VacuumConstants)

return function()
	-- A character with a thin UpperTorso, an arm, a hoodie piece worn on the torso, the vacuum's pack and a held Tool.
	local function build()
		local character = Instance.new("Model")
		local function part(name, size, at, parent)
			local p = Instance.new("Part")
			p.Name = name
			p.Size = size
			p.CFrame = at
			p.Anchored = true
			p.Parent = parent or character
			return p
		end
		local function weld(a, b)
			local w = Instance.new("WeldConstraint")
			w.Part0 = a
			w.Part1 = b
			w.Parent = a
		end
		local chest = part("UpperTorso", Vector3.new(0.62, 1.65, 0.6), CFrame.new(0, 3, 0))
		local arm = part("RightUpperArm", Vector3.new(0.2, 0.6, 0.2), CFrame.new(0.5, 3.3, 0))
		local motor = Instance.new("Motor6D")
		motor.Part0 = chest
		motor.Part1 = arm
		motor.Parent = arm
		local clothes = Instance.new("Folder")
		clothes.Name = "Accessories"
		clothes.Parent = character
		local hoodie = part("Hoodie_UpperTorso", Vector3.new(0.92, 0.99, 0.94), CFrame.new(0, 3.2, -0.05), clothes)
		weld(chest, hoodie)
		local pack = Instance.new("Model")
		pack.Name = VacuumConstants.BACKPACK_NAME
		pack.Parent = character
		weld(chest, part("Pack", Vector3.new(1, 1.4, 1), CFrame.new(0, 3, 0.9), pack))
		local tool = Instance.new("Tool")
		tool.Parent = character
		local hidden = part("Hidden", Vector3.new(3, 3, 3), CFrame.new(0, 3, 0), clothes)
		hidden.Transparency = 1
		weld(chest, hidden)
		return character, chest, tool
	end

	it("finds the clothes worn on the torso, never body parts, the pack, the Tool or hidden parts", function()
		local character, chest, tool = build()
		local worn = VacuumBodyUtils.wornOn(character, chest, tool)
		expect(#worn).to.equal(1)
		expect(worn[1].Name).to.equal("Hoodie_UpperTorso")
		character:Destroy()
	end)

	it("measures the visible chest: the torso and its clothes, in the torso's frame", function()
		local character, chest, tool = build()
		local box = VacuumBodyUtils.chestBox(character, chest, tool)
		expect(box.half.X).to.be.near(0.46, 1e-4)
		expect(box.centre.Z - box.half.Z).to.be.near(-0.52, 1e-4)
		-- The pack behind the back is not part of the chest.
		expect(box.centre.Z + box.half.Z < 0.5).to.equal(true)
		character:Destroy()
	end)
end
