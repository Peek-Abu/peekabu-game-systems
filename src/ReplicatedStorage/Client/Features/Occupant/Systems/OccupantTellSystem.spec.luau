local System = require(script.Parent.OccupantTellSystem)
return function()
	local root, controller
	beforeEach(function()
		root = Instance.new("Part")
		root.Transparency = 1
		root.Material = Enum.Material.Neon
		root.Parent = workspace
		controller = System.newLightController(0)
	end)
	afterEach(function()
		controller.clear()
		root:Destroy()
	end)
	local function fixture()
		local art = Instance.new("Model")
		art.Parent = root
		local panel = Instance.new("Part")
		panel.Material = Enum.Material.Neon
		panel.Color = Color3.fromRGB(240, 220, 160)
		panel.Parent = art
		local housing = Instance.new("Part")
		housing.Material = Enum.Material.Metal
		housing.Color = Color3.fromRGB(100, 110, 120)
		housing.Parent = art
		local light = Instance.new("SurfaceLight")
		light.Brightness = 2.4
		light.Parent = panel
		local disabled = Instance.new("PointLight")
		disabled.Brightness = 0.7
		disabled.Enabled = false
		disabled.Parent = housing
		return panel, housing, light, disabled
	end
	it("dims imported emitting panels and all light classes while preserving the housing", function()
		local panel, housing, light, disabled = fixture()
		local bright, metal = panel.Color, housing.Color
		controller.setLit(root, false)
		expect(light.Brightness).to.equal(0)
		expect(light.Enabled).to.equal(false)
		expect(panel.Color.R < bright.R * 0.2).to.equal(true)
		expect(panel.Material).to.equal(Enum.Material.SmoothPlastic)
		expect(housing.Color).to.equal(metal)
		expect(housing.Material).to.equal(Enum.Material.Metal)
		controller.setLit(root, true)
		expect(panel.Color).to.equal(bright)
		expect(panel.Material).to.equal(Enum.Material.Neon)
		expect(light.Brightness).to.be.near(2.4, 0.001)
		expect(light.Enabled).to.equal(true)
		expect(disabled.Enabled).to.equal(false)
	end)
	it("restores original state and cancels a fade when cleared", function()
		controller.clear()
		controller = System.newLightController(0.2)
		local panel, housing, light, disabled = fixture()
		local color = panel.Color
		controller.setLit(root, false)
		controller.clear()
		expect(panel.Color).to.equal(color)
		expect(panel.Material).to.equal(Enum.Material.Neon)
		expect(light.Brightness).to.be.near(2.4, 0.001)
		expect(light.Enabled).to.equal(true)
		expect(disabled.Brightness).to.be.near(0.7, 0.001)
		expect(disabled.Enabled).to.equal(false)
		task.wait(0.25)
		expect(panel.Color).to.equal(color)
		expect(light.Brightness).to.be.near(2.4, 0.001)
		expect(housing.Material).to.equal(Enum.Material.Metal)
	end)
	it("handles a fixture destroyed during its fade", function()
		controller.clear()
		controller = System.newLightController(0.2)
		fixture()
		controller.setLit(root, false)
		root:Destroy()
		controller.clear()
		task.wait(0.25)
	end)
	it("lets a later flicker cancel the prior fade and settle at the latest state", function()
		controller.clear()
		controller = System.newLightController(0.05)
		local panel, _, light = fixture()
		local color = panel.Color
		controller.setLit(root, false)
		controller.setLit(root, true)
		task.wait(0.1)
		expect(light.Enabled).to.equal(true)
		expect(math.abs(light.Brightness - 2.4) < 0.001).to.equal(true)
		expect(
			(Vector3.new(panel.Color.R, panel.Color.G, panel.Color.B) - Vector3.new(color.R, color.G, color.B)).Magnitude
				< 0.001
		).to.equal(true)
	end)
	it("releases a destroyed emitter during an active fixture fade", function()
		controller.clear()
		controller = System.newLightController(0.05)
		local panel, _, light = fixture()
		controller.setLit(root, false)
		panel:Destroy()
		controller.setLit(root, true)
		controller.clear()
		task.wait(0.1)
		expect(light.Parent).to.equal(nil)
	end)
end
