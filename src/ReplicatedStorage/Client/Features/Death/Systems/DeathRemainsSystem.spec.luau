local Workspace = game:GetService("Workspace")

local DeathRemainsSystem = require(script.Parent.DeathRemainsSystem)

return function()
	local made = {}
	afterEach(function()
		for _, instance in made do
			instance:Destroy()
		end
		table.clear(made)
	end)

	local function character()
		local model = Instance.new("Model")
		local part = Instance.new("Part")
		part.Parent = model
		table.insert(made, model)
		return model
	end

	local function never()
		return false
	end

	-- Destroy locks Parent (and Destroying handlers run deferred), so a locked Parent is the synchronous proof.
	local function destroyed(model)
		local holder = Instance.new("Folder")
		table.insert(made, holder)
		return not pcall(function()
			model.Parent = holder
		end)
	end

	describe("reap", function()
		it("destroys a removed character, so cleanup tied to Destroying runs on this client", function()
			local model = character()
			model.Parent = Workspace
			model.Parent = nil

			expect(DeathRemainsSystem.reap(model, never)).to.equal(true)
			expect(destroyed(model)).to.equal(true)
		end)

		it("leaves a character still in the DataModel alone", function()
			local model = character()
			model.Parent = Workspace

			expect(DeathRemainsSystem.reap(model, never)).to.equal(false)
			expect(model.Parent).to.equal(Workspace)
			expect(destroyed(model)).to.equal(false)
		end)

		it("leaves a removed character alone while it is still a player's current character", function()
			local model = character()

			expect(DeathRemainsSystem.reap(model, function(candidate)
				return candidate == model
			end)).to.equal(false)
			expect(destroyed(model)).to.equal(false)
		end)
	end)
end
