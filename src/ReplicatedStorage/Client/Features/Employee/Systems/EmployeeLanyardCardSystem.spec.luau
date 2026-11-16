local EmployeeLanyardCardSystem = require(script.Parent.EmployeeLanyardCardSystem)

return function()
	describe("mountInfoCard", function()
		it("mounts nothing on a lanyard without a badge", function()
			local character = Instance.new("Model")
			local folder = Instance.new("Folder")
			folder.Parent = character
			local handle = {
				folder = folder,
				badgeTurn = CFrame.identity,
				scale = 1,
				destroy = function() end,
			}
			EmployeeLanyardCardSystem.mountInfoCard(character, handle, 1, "Tester")
			expect(#folder:GetChildren()).to.equal(0)
			character:Destroy()
		end)
	end)
end
