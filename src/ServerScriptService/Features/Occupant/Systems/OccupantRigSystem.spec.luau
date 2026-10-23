local OccupantRigSystem = require(script.Parent.OccupantRigSystem)

return function()
	describe("sweep", function()
		-- Its own list of tagged instances and its own remover: whatever wears the tag in the place is not touched.
		local made = {}
		local function model(name)
			local created = Instance.new("Model")
			created.Name = name
			table.insert(made, created)
			return created
		end
		afterEach(function()
			for _, instance in made do
				instance:Destroy()
			end
			table.clear(made)
		end)

		it("removes every tagged model but the one kept, and counts them", function()
			local kept, twinA, twinB = model("Harlow"), model("Harlow"), model("Harlow")
			local removed = {}
			local count = OccupantRigSystem.sweep(kept, { kept, twinA, twinB }, function(rig)
				table.insert(removed, rig)
			end)
			expect(count).to.equal(2)
			expect(#removed).to.equal(2)
			expect(table.find(removed, kept)).to.equal(nil)
			expect(table.find(removed, twinA) ~= nil).to.equal(true)
			expect(table.find(removed, twinB) ~= nil).to.equal(true)
		end)

		it("removes them all with nothing kept, and skips anything that is not a model", function()
			local rig = model("Harlow")
			local stray = Instance.new("Part")
			table.insert(made, stray)
			local removed = {}
			local count = OccupantRigSystem.sweep(nil, { rig, stray }, function(found)
				table.insert(removed, found)
			end)
			expect(count).to.equal(1)
			expect(removed[1]).to.equal(rig)
		end)

		it("finds nothing to remove in an empty list", function()
			expect(OccupantRigSystem.sweep(nil, {}, function() end)).to.equal(0)
		end)
	end)
end
