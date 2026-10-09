--[=[
	The registry is a module singleton that persists across a Studio test session, so ids here are
	"spec-*" and registered behind `has` guards; refusal tests use fresh ids and assert nothing landed.
]=]

local InputActionRegistry = require(script.Parent.InputActionRegistry)

local function ensure(id, def)
	if not InputActionRegistry.has(id) then
		InputActionRegistry.register(id, def)
	end
end

local function def(overrides)
	local base = {
		context = "gameplay",
		bindings = { keyboard = { Enum.KeyCode.G }, gamepad = { Enum.KeyCode.ButtonY } },
		description = "spec action",
	}
	for key, value in overrides or {} do
		base[key] = value
	end
	return base
end

return function()
	it("registers and returns an action", function()
		ensure("spec-good", def())
		local got = InputActionRegistry.get("spec-good")
		expect(got).to.be.ok()
		expect(got.context).to.equal("gameplay")
		expect(table.find(InputActionRegistry.ids(), "spec-good")).to.be.ok()
	end)

	it("lists ids sorted", function()
		ensure("spec-b", def())
		ensure("spec-a", def())
		local ids = InputActionRegistry.ids()
		expect(table.find(ids, "spec-a") < table.find(ids, "spec-b")).to.equal(true)
	end)

	it("returns nil for an unknown id", function()
		expect(InputActionRegistry.get("spec-missing")).to.equal(nil)
		expect(InputActionRegistry.has("spec-missing")).to.equal(false)
	end)

	it("rejects a duplicate id", function()
		ensure("spec-dup", def())
		expect(function()
			InputActionRegistry.register("spec-dup", def())
		end).to.throw()
	end)

	it("rejects an unknown context", function()
		expect(function()
			InputActionRegistry.register("spec-bad-context", def({ context = "nowhere" }))
		end).to.throw()
		expect(InputActionRegistry.has("spec-bad-context")).to.equal(false)
	end)

	it("rejects an action with no bindings at all", function()
		expect(function()
			InputActionRegistry.register("spec-unbound", def({ bindings = {} }))
		end).to.throw()
		expect(InputActionRegistry.has("spec-unbound")).to.equal(false)
	end)

	it("rejects a keyboard key in the gamepad list", function()
		expect(function()
			InputActionRegistry.register("spec-mixed", def({ bindings = { gamepad = { Enum.KeyCode.E } } }))
		end).to.throw()
		expect(InputActionRegistry.has("spec-mixed")).to.equal(false)
	end)

	it("rejects a gamepad button in the keyboard list", function()
		expect(function()
			InputActionRegistry.register("spec-mixed-2", def({ bindings = { keyboard = { Enum.KeyCode.ButtonA } } }))
		end).to.throw()
		expect(InputActionRegistry.has("spec-mixed-2")).to.equal(false)
	end)

	it("accepts mouse buttons in the keyboard list", function()
		ensure("spec-mouse", def({ bindings = { keyboard = { Enum.UserInputType.MouseButton2 } } }))
		expect(InputActionRegistry.get("spec-mouse")).to.be.ok()
	end)

	it("rejects a non-mouse UserInputType in the keyboard list", function()
		expect(function()
			InputActionRegistry.register("spec-touch", def({ bindings = { keyboard = { Enum.UserInputType.Touch } } }))
		end).to.throw()
		expect(InputActionRegistry.has("spec-touch")).to.equal(false)
	end)

	it("registerDefaults registers the base actions once and is safe to repeat", function()
		InputActionRegistry.registerDefaults()
		InputActionRegistry.registerDefaults()
		expect(InputActionRegistry.get("interact")).to.be.ok()
		expect(InputActionRegistry.get("sprint")).to.be.ok()
	end)
end
