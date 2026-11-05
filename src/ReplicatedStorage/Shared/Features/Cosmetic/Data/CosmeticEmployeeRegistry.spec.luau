local CosmeticEmployeeRegistry = require(script.Parent.CosmeticEmployeeRegistry)

return function()
	describe("CosmeticEmployeeRegistry", function()
		it("holds only employees and items that belong to one of them", function()
			local employees = {}
			for _, item in CosmeticEmployeeRegistry do
				if item.kind == "employee" then
					employees[item.id] = true
				end
			end
			for _, item in CosmeticEmployeeRegistry do
				if item.kind ~= "employee" then
					expect(item.employee ~= nil and employees[item.employee] == true).to.equal(true)
				end
				expect(item.kind ~= "sticker" and item.kind ~= "stickerPack" and item.kind ~= "vacuum").to.equal(true)
			end
		end)

		it("lists the employees first", function()
			expect(CosmeticEmployeeRegistry[1].kind).to.equal("employee")
		end)
	end)
end
