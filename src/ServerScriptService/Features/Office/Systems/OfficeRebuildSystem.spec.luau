local ServerScriptService = game:GetService("ServerScriptService")

local OfficeRebuildSystem = require(script.Parent.OfficeRebuildSystem)
local OfficeLayoutConstants = require(ServerScriptService.Features.Office.Data.OfficeLayoutConstants)
local OfficeFurniturePlacementUtils = require(ServerScriptService.Features.Office.Utils.OfficeFurniturePlacementUtils)
local OfficeLayoutGenerationUtils = require(ServerScriptService.Features.Office.Utils.OfficeLayoutGenerationUtils)

local LAYOUT = OfficeLayoutConstants.LAYOUT

return function()
	describe("fitted", function()
		it("never adds markers", function()
			local layout = OfficeFurniturePlacementUtils.normalize(LAYOUT)
			expect(#OfficeRebuildSystem.fitted(layout).markers <= #layout.markers).to.equal(true)
		end)
	end)

	describe("generateLayout", function()
		it("generates the office from the seed it was given when generation succeeds", function()
			for seed = 1, 3 do
				local layout, used = OfficeRebuildSystem.generateLayout(seed, "office")
				expect(used).to.equal(seed)
				local direct = OfficeLayoutGenerationUtils.generate(LAYOUT, seed)
				expect(#layout.rooms).to.equal(#direct.rooms)
				expect(#layout.markers).to.equal(#direct.markers)
				task.wait()
			end
		end)

		it("generates the school too", function()
			local layout, used = OfficeRebuildSystem.generateLayout(2, "school")
			expect(used).to.equal(2)
			expect(#layout.rooms > 0).to.equal(true)
		end)
	end)

	describe("checkGenerated", function()
		it("raises for a broken layout", function()
			expect(function()
				OfficeRebuildSystem.checkGenerated({ rooms = {}, doors = {}, markers = {}, route = {} })
			end).to.throw()
		end)
	end)

	describe("teardown", function()
		it("destroys the instance, its folders and their children", function()
			local root = Instance.new("Model")
			local folder = Instance.new("Folder")
			folder.Parent = root
			local inner = Instance.new("Part")
			inner.Parent = folder
			local loose = Instance.new("Part")
			loose.Parent = root
			root.Parent = workspace
			OfficeRebuildSystem.teardown(root)
			expect(root.Parent).to.equal(nil)
			expect(folder.Parent).to.equal(nil)
			expect(inner.Parent).to.equal(nil)
			expect(loose.Parent).to.equal(nil)
		end)
	end)
end
