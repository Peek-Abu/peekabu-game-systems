--!nocheck
--[=[
	Unit tests for SceneRegistry — the declarative catalog of scenes.

	A scene names which screens it shows (in which layers) and what it suppresses. The registry is a
	global singleton scenes register into at load; these tests use "RegSpec.*" names, guarded by `has`
	so a re-run in the same Studio session (singletons persist) does not double-register.
]=]

local SceneRegistry = require(script.Parent.SceneRegistry)

local function ensure(def)
	if not SceneRegistry.has(def.name) then
		SceneRegistry.register(def)
	end
end

return function()
	describe("register / get / has", function()
		it("stores a scene and returns it by name", function()
			ensure({ name = "RegSpec.Solo", screens = {} })
			expect(SceneRegistry.has("RegSpec.Solo")).to.equal(true)
			local def = SceneRegistry.get("RegSpec.Solo")
			expect(def).to.be.ok()
			expect(def.name).to.equal("RegSpec.Solo")
		end)

		it("carries screens and an optional suppression record", function()
			ensure({
				name = "RegSpec.Rich",
				screens = { { layer = "Panel", key = "grid", component = function() end } },
				suppress = { mouse = true, blur = true },
			})
			local def = SceneRegistry.get("RegSpec.Rich")
			expect(#def.screens).to.equal(1)
			expect(def.screens[1].layer).to.equal("Panel")
			expect(def.suppress.mouse).to.equal(true)
		end)

		it("returns nil for an unknown scene", function()
			expect(SceneRegistry.get("RegSpec.Nope")).to.equal(nil)
			expect(SceneRegistry.has("RegSpec.Nope")).to.equal(false)
		end)
	end)

	describe("duplicate registration", function()
		it("errors when a name is registered twice", function()
			ensure({ name = "RegSpec.Dup", screens = {} })
			expect(function()
				SceneRegistry.register({ name = "RegSpec.Dup", screens = {} })
			end).to.throw()
		end)
	end)

	describe("toggle keys", function()
		it("finds the scene that declared a toggle key", function()
			ensure({ name = "RegSpec.Keyed", screens = {}, toggleKey = Enum.KeyCode.F9 })
			expect(SceneRegistry.sceneForKey(Enum.KeyCode.F9)).to.equal("RegSpec.Keyed")
		end)

		it("returns nil for a key no scene declared", function()
			expect(SceneRegistry.sceneForKey(Enum.KeyCode.F10)).to.equal(nil)
		end)

		it("refuses a second scene on the same key", function()
			ensure({ name = "RegSpec.Keyed", screens = {}, toggleKey = Enum.KeyCode.F9 })
			expect(function()
				SceneRegistry.register({ name = "RegSpec.KeyClash", screens = {}, toggleKey = Enum.KeyCode.F9 })
			end).to.throw()
			expect(SceneRegistry.has("RegSpec.KeyClash")).to.equal(false)
		end)
	end)
end
