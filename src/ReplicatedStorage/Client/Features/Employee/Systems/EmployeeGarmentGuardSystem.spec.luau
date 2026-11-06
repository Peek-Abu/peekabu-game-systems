local ReplicatedStorage = game:GetService("ReplicatedStorage")

local EmployeeConstants = require(ReplicatedStorage.Shared.Features.Employee.Data.EmployeeConstants)
local EmployeeGarmentGuardSystem = require(script.Parent.EmployeeGarmentGuardSystem)

return function()
	local COOLDOWN = EmployeeConstants.GARMENT_REWRAP_COOLDOWN
	-- Only plugins may set CageMeshId: the cages are told apart by name, and the fake loader answers per name.
	local BODY_CAGE = "BodyCage"
	local GARMENT_CAGE = "GarmentCage"

	-- Wraps must sit on MeshParts. A character with a caged UpperTorso, a root, and (optionally) one layered garment.
	local function makeCharacter(withGarment)
		local model = Instance.new("Model")
		local root = Instance.new("Part")
		root.Name = "HumanoidRootPart"
		root.Anchored = true
		root.Parent = model
		model.PrimaryPart = root
		local torso = Instance.new("MeshPart")
		torso.Name = "UpperTorso"
		torso.Parent = model
		local target = Instance.new("WrapTarget")
		target.Name = BODY_CAGE
		target.Parent = torso
		local layer = nil
		if withGarment then
			local accessory = Instance.new("Accessory")
			local handle = Instance.new("MeshPart")
			handle.Name = "Handle"
			handle.Parent = accessory
			layer = Instance.new("WrapLayer")
			layer.Name = GARMENT_CAGE
			layer.Parent = handle
			accessory.Parent = model
		end
		return model, root, torso, layer
	end

	-- Cage meshes are "loaded" when the test says so.
	local function loader(loaded)
		return function(cage)
			return if loaded[cage.Name] then Enum.AssetFetchStatus.Success else Enum.AssetFetchStatus.Loading
		end
	end

	-- Steps through one re-wrap: the step that turns the layer off, then the next that turns it back on.
	local function rewrapCount(guard)
		return guard.getState().rewraps
	end

	describe("spawn", function()
		it("re-wraps a garment once its and the body's cage meshes have loaded", function()
			local loaded = {}
			local guard = EmployeeGarmentGuardSystem.new(loader(loaded))
			local model, _, _, layer = makeCharacter(true)
			local untrack = guard.track(model, 0)
			guard.step(0.1)
			expect(rewrapCount(guard)).to.equal(0)
			expect(layer.Enabled).to.equal(true)
			loaded[BODY_CAGE] = true
			guard.step(0.2)
			expect(rewrapCount(guard)).to.equal(0)
			loaded[GARMENT_CAGE] = true
			guard.step(0.3)
			expect(layer.Enabled).to.equal(false)
			guard.step(0.4)
			expect(layer.Enabled).to.equal(true)
			expect(rewrapCount(guard)).to.equal(1)
			untrack()
			model:Destroy()
		end)

		it("re-wraps after the load timeout even if a cage never reports loaded", function()
			local guard = EmployeeGarmentGuardSystem.new(loader({}))
			local model, _, _, layer = makeCharacter(true)
			local untrack = guard.track(model, 0)
			guard.step(EmployeeConstants.GARMENT_LOAD_TIMEOUT - 0.1)
			expect(rewrapCount(guard)).to.equal(0)
			guard.step(EmployeeConstants.GARMENT_LOAD_TIMEOUT + 0.1)
			guard.step(EmployeeConstants.GARMENT_LOAD_TIMEOUT + 0.2)
			expect(layer.Enabled).to.equal(true)
			expect(rewrapCount(guard)).to.equal(1)
			untrack()
			model:Destroy()
		end)

		it("waits again for a garment put on later (a skin equipped)", function()
			local loaded = { [BODY_CAGE] = true }
			local guard = EmployeeGarmentGuardSystem.new(loader(loaded))
			local model = makeCharacter(false)
			local untrack = guard.track(model, 0)
			guard.step(0.1)
			expect(guard.getState().garments).to.equal(0)
			local accessory = Instance.new("Accessory")
			local handle = Instance.new("MeshPart")
			handle.Name = "Handle"
			handle.Parent = accessory
			local layer = Instance.new("WrapLayer")
			layer.Name = GARMENT_CAGE
			layer.Parent = handle
			accessory.Parent = model
			-- Signals are deferred: DescendantAdded reaches the guard at the next resumption point, as a frame would.
			task.wait()
			guard.step(0.2)
			expect(guard.getState().garments).to.equal(1)
			expect(rewrapCount(guard)).to.equal(0)
			loaded[GARMENT_CAGE] = true
			guard.step(0.3)
			guard.step(0.4)
			expect(rewrapCount(guard)).to.equal(1)
			untrack()
			model:Destroy()
		end)
	end)

	describe("triggers", function()
		-- A tracked garment whose spawn re-wrap is already done.
		local function settled()
			local guard = EmployeeGarmentGuardSystem.new(loader({ [BODY_CAGE] = true, [GARMENT_CAGE] = true }))
			local model, root, torso, layer = makeCharacter(true)
			local untrack = guard.track(model, 0)
			guard.step(0.1)
			guard.step(0.2)
			expect(rewrapCount(guard)).to.equal(1)
			return guard, model, root, torso, layer, untrack
		end

		it("re-wraps when the camera fade on the body ends", function()
			local guard, model, _, torso, layer, untrack = settled()
			torso.LocalTransparencyModifier = 0.6
			guard.step(1)
			expect(rewrapCount(guard)).to.equal(1)
			torso.LocalTransparencyModifier = 0
			guard.step(2)
			expect(layer.Enabled).to.equal(false)
			guard.step(2.1)
			expect(layer.Enabled).to.equal(true)
			expect(rewrapCount(guard)).to.equal(2)
			untrack()
			model:Destroy()
		end)

		it("re-wraps after a big move (a teleport), not after an ordinary step", function()
			local guard, model, root, _, _, untrack = settled()
			root.CFrame = CFrame.new(0, 0, 1)
			guard.step(1)
			guard.step(1.1)
			expect(rewrapCount(guard)).to.equal(1)
			root.CFrame = CFrame.new(0, 0, 1 + EmployeeConstants.GARMENT_MOVE_JUMP + 1)
			guard.step(2)
			guard.step(2.1)
			expect(rewrapCount(guard)).to.equal(2)
			untrack()
			model:Destroy()
		end)

		it("re-wraps a garment at most once per cooldown", function()
			local guard, model, root, torso, _, untrack = settled()
			local far = EmployeeConstants.GARMENT_MOVE_JUMP + 1
			torso.LocalTransparencyModifier = 0.5
			guard.step(1)
			torso.LocalTransparencyModifier = 0
			root.CFrame = CFrame.new(0, 0, far)
			guard.step(2)
			guard.step(2.05)
			root.CFrame = CFrame.new(0, 0, 2 * far)
			guard.step(2 + COOLDOWN / 2)
			guard.step(2 + COOLDOWN / 2 + 0.05)
			expect(rewrapCount(guard)).to.equal(2)
			root.CFrame = CFrame.new(0, 0, 3 * far)
			guard.step(2 + COOLDOWN + 0.1)
			guard.step(2 + COOLDOWN + 0.2)
			expect(rewrapCount(guard)).to.equal(3)
			untrack()
			model:Destroy()
		end)
	end)

	describe("track", function()
		it("does nothing for a character without garments", function()
			local guard = EmployeeGarmentGuardSystem.new(loader({}))
			local model, root = makeCharacter(false)
			local untrack = guard.track(model, 0)
			root.CFrame = CFrame.new(0, 0, 100)
			guard.step(20)
			guard.step(21)
			expect(rewrapCount(guard)).to.equal(0)
			expect(guard.getState().tracked).to.equal(1)
			untrack()
			expect(guard.getState().tracked).to.equal(0)
			model:Destroy()
		end)

		it("leaves a garment wrapped when released mid re-wrap", function()
			local guard = EmployeeGarmentGuardSystem.new(loader({ [BODY_CAGE] = true, [GARMENT_CAGE] = true }))
			local model, _, _, layer = makeCharacter(true)
			local untrack = guard.track(model, 0)
			guard.step(0.1)
			expect(layer.Enabled).to.equal(false)
			untrack()
			expect(layer.Enabled).to.equal(true)
			model:Destroy()
		end)
	end)
end
