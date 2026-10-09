--!strict
--[=[
	SpecRoots.spec: verifies the shared test-root list and the orphan-spec guard.

	The "does not throw" case is self-proving: this suite only runs because the runners already
	called `assertAllSpecsCovered` with `get()` — but asserting it here keeps the guarantee even
	if a runner ever drops the guard call.
]=]

local ServerScriptService = game:GetService("ServerScriptService")
local StarterPlayer = game:GetService("StarterPlayer")

local SpecRoots = require(ServerScriptService.Core.Testing.SpecRoots)

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
				SpecRoots.assertAllSpecsCovered({ ServerScriptService.Features })
			end).to.throw()
		end)

		it("does not flag a `.spec`-named module under StarterPlayerScripts.PlayerModule", function()
			-- Roblox auto-provisions a default PlayerModule under StarterPlayerScripts at runtime
			-- (camera/control scripts), independent of what's in the built place. Its nested
			-- CommonUtils folder contains modules that happen to end in `.spec` (CameraWrapper,
			-- ConnectionUtil) despite not being TestEZ specs — this must never be treated as an
			-- orphan. Handle both cases: a real PlayerModule may already exist in this environment,
			-- or this may be a from-scratch build without one.
			local playerScripts = StarterPlayer.StarterPlayerScripts
			local playerModule = playerScripts:FindFirstChild("PlayerModule")
			local createdPlayerModule = false
			if not playerModule then
				playerModule = Instance.new("Folder")
				playerModule.Name = "PlayerModule"
				playerModule.Parent = playerScripts
				createdPlayerModule = true
			end

			local fakeSpec = Instance.new("ModuleScript")
			fakeSpec.Name = "CameraWrapper.spec"
			fakeSpec.Parent = playerModule

			expect(function()
				SpecRoots.assertAllSpecsCovered(SpecRoots.get())
			end).never.to.throw()

			fakeSpec:Destroy()
			if createdPlayerModule then
				playerModule:Destroy()
			end
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
