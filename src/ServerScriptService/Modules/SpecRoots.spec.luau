--!strict
--[=[
	SpecRoots.spec: verifies the shared test-root list and the orphan-spec guard.

	The "does not throw" case is self-proving: this suite only runs because the runners already
	called `assertAllSpecsCovered` with `get()` — but asserting it here keeps the guarantee even
	if a runner ever drops the guard call.
]=]

local ServerScriptService = game:GetService("ServerScriptService")

local SpecRoots = require(ServerScriptService.Modules.SpecRoots)

return function()
	describe("SpecRoots.get", function()
		it("returns the seven scanned roots as live Instances", function()
			local roots = SpecRoots.get()
			expect(#roots).to.equal(7)
			for _, root in roots do
				expect(typeof(root)).to.equal("Instance")
			end
		end)
	end)

	describe("SpecRoots.assertAllSpecsCovered", function()
		it("does not throw when every spec is under a scanned root", function()
			expect(function()
				SpecRoots.assertAllSpecsCovered(SpecRoots.get())
			end).never.to.throw()
		end)

		it("throws and names orphans when the root list is narrowed", function()
			-- With only one root passed, every spec in the other six roots (including specs in
			-- ReplicatedStorage) is an orphan, so the guard must throw.
			expect(function()
				SpecRoots.assertAllSpecsCovered({ ServerScriptService.Modules })
			end).to.throw()
		end)
	end)

	describe("SpecRoots.assertAllModulesSpecced", function()
		it("passes for the current tree (every module is specced or explicitly exempt)", function()
			-- This is the live enforcement: if a new module ships without a spec sibling and without
			-- an EXEMPT_MODULES entry, this fails — the same check the runners run before the suite.
			expect(function()
				SpecRoots.assertAllModulesSpecced(SpecRoots.get())
			end).never.to.throw()
		end)

		it("throws when a module under the root has no .spec sibling and is not exempt", function()
			-- The real tree has no such module by design, so exercise the negative path with a
			-- synthetic root: a folder holding one bare ModuleScript.
			local folder = Instance.new("Folder")
			local orphan = Instance.new("ModuleScript")
			orphan.Name = "UnspeccedModule"
			orphan.Parent = folder

			expect(function()
				SpecRoots.assertAllModulesSpecced({ folder })
			end).to.throw()

			folder:Destroy()
		end)

		it("accepts a module that has a .spec sibling", function()
			local folder = Instance.new("Folder")
			local mod = Instance.new("ModuleScript")
			mod.Name = "SpeccedModule"
			mod.Parent = folder
			local spec = Instance.new("ModuleScript")
			spec.Name = "SpeccedModule.spec"
			spec.Parent = folder

			expect(function()
				SpecRoots.assertAllModulesSpecced({ folder })
			end).never.to.throw()

			folder:Destroy()
		end)
	end)
end
