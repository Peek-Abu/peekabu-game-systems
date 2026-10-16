local System = require(script.Parent.VacuumToolSystem)
local Constants = require(game.ReplicatedStorage.Shared.Features.Vacuum.Data.VacuumConstants)
return function()
	describe("vacuum Tool", function()
		it("creates a visible, non-droppable Tool without gameplay scripts", function()
			local tool = System.create()
			expect(tool:IsA("Tool")).to.equal(true)
			expect(tool.CanBeDropped).to.equal(false)
			expect(tool.RequiresHandle).to.equal(true)
			expect(tool:GetAttribute(Constants.TOOL_ATTRIBUTE)).to.equal(true)
			local handle = tool:FindFirstChild("Handle")
			expect(handle:IsA("BasePart")).to.equal(true)
			for _, child in tool:GetDescendants() do
				if child:IsA("BasePart") then
					expect(child.Massless).to.equal(true)
					expect(child.CanCollide).to.equal(false)
				end
				expect(child:IsA("LuaSourceContainer")).to.equal(false)
			end
			tool:Destroy()
		end)
		it("builds the hand wand with a hose inlet, held as a hanging hand holds it when unmeasured", function()
			local tool = System.create()
			expect(tool:FindFirstChild("FloorHead")).to.be.ok()
			expect(tool.Handle:FindFirstChild("HoseInlet")).to.be.ok()
			expect(tool.Grip).to.equal(CFrame.Angles(-math.pi / 2, 0, 0))
			local stranger = Instance.new("Model")
			local fitted = System.create(stranger)
			expect(fitted.Grip).to.equal(CFrame.Angles(-math.pi / 2, 0, 0))
			tool:Destroy()
			fitted:Destroy()
			stranger:Destroy()
		end)
		it("runs the backpack's hose to the wand while a character holds it, and stows it after", function()
			local calls = {}
			local backpack = {
				model = Instance.new("Model"),
				setHeld = function(inlet)
					table.insert(calls, inlet or "stowed")
				end,
				destroy = function() end,
			}
			local tool = System.create(nil, backpack)
			local character = Instance.new("Model")
			Instance.new("Humanoid").Parent = character
			-- Parent-changed handlers run deferred.
			tool.Parent = character
			task.wait()
			expect(calls[#calls]).to.equal(tool.Handle.HoseInlet)
			tool.Parent = nil
			task.wait()
			expect(calls[#calls]).to.equal("stowed")
			expect(#calls).to.equal(2)
			tool:Destroy()
			character:Destroy()
		end)
		it("builds the hand wand in the skin of the backpack it comes off", function()
			local Registry = require(game.ReplicatedStorage.Shared.Features.Vacuum.Data.VacuumSkinRegistry)
			local backpack = {
				model = Instance.new("Model"),
				skin = Registry.get("BrassBellows"),
				setHeld = function() end,
				destroy = function() end,
			}
			local tool = System.create(nil, backpack)
			expect(tool:GetAttribute("VacuumSkin")).to.equal("BrassBellows")
			local plain = System.create()
			expect(plain:GetAttribute("VacuumSkin")).to.equal(Registry.DEFAULT)
			tool:Destroy()
			plain:Destroy()
		end)
		it("does not treat a backpack Tool or an unrelated namesake as equipped", function()
			local character = Instance.new("Model")
			local tool = Instance.new("Tool")
			tool.Name = Constants.TOOL_NAME
			tool.Parent = character
			expect(System.isEquipped(character)).to.equal(false)
			tool:Destroy()
			local vacuum = System.create()
			expect(System.isEquipped(character)).to.equal(false)
			vacuum.Parent = character
			expect(System.isEquipped(character)).to.equal(true)
			vacuum:Destroy()
			character:Destroy()
			expect(System.isEquipped(nil)).to.equal(false)
		end)
	end)
end
