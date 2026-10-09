local InputBindingRules = require(script.Parent.InputBindingRules)

local function entry(token, name, sink)
	return { token = token, name = name, sink = sink }
end

local ACTIONS = {
	interact = {
		context = "gameplay",
		bindings = { keyboard = { Enum.KeyCode.E }, gamepad = { Enum.KeyCode.ButtonX } },
		description = "",
	},
	fire = {
		context = "gameplay",
		bindings = { keyboard = { Enum.UserInputType.MouseButton1 }, gamepad = { Enum.KeyCode.ButtonR2 } },
		description = "",
	},
	confirm = {
		context = "ui",
		bindings = { keyboard = { Enum.KeyCode.E, Enum.KeyCode.Return }, gamepad = { Enum.KeyCode.ButtonA } },
		description = "",
	},
}

local function lookup(id)
	return ACTIONS[id]
end

local IDS = { "confirm", "fire", "interact" }

return function()
	describe("isGamepadKey", function()
		it("accepts gamepad buttons, d-pad and thumbsticks", function()
			expect(InputBindingRules.isGamepadKey(Enum.KeyCode.ButtonA)).to.equal(true)
			expect(InputBindingRules.isGamepadKey(Enum.KeyCode.DPadUp)).to.equal(true)
			expect(InputBindingRules.isGamepadKey(Enum.KeyCode.Thumbstick1)).to.equal(true)
		end)

		it("rejects keyboard keys and mouse buttons", function()
			expect(InputBindingRules.isGamepadKey(Enum.KeyCode.E)).to.equal(false)
			expect(InputBindingRules.isGamepadKey(Enum.UserInputType.MouseButton1)).to.equal(false)
		end)
	end)

	describe("reachable", function()
		it("is just the base context on an empty stack", function()
			local set = InputBindingRules.reachable({}, "gameplay")
			expect(set.gameplay).to.equal(true)
		end)

		it("includes every context down to and including the first sinking one", function()
			local set = InputBindingRules.reachable({ entry(1, "vehicle", false), entry(2, "ui", true) }, "gameplay")
			expect(set.ui).to.equal(true)
			expect(set.vehicle).to.equal(nil)
			expect(set.gameplay).to.equal(nil)
		end)

		it("keeps lower contexts reachable when nothing sinks", function()
			local set = InputBindingRules.reachable({ entry(1, "vehicle", false) }, "gameplay")
			expect(set.vehicle).to.equal(true)
			expect(set.gameplay).to.equal(true)
		end)
	end)

	describe("actionsFor", function()
		it("finds the gameplay action for a key while gameplay is reachable", function()
			local found = InputBindingRules.actionsFor(Enum.KeyCode.E, IDS, lookup, {}, { gameplay = true })
			expect(#found).to.equal(1)
			expect(found[1]).to.equal("interact")
		end)

		it("finds the ui action instead while only ui is reachable", function()
			local found = InputBindingRules.actionsFor(Enum.KeyCode.E, IDS, lookup, {}, { ui = true })
			expect(#found).to.equal(1)
			expect(found[1]).to.equal("confirm")
		end)

		it("matches mouse buttons and gamepad buttons", function()
			local reach = { gameplay = true }
			expect(InputBindingRules.actionsFor(Enum.UserInputType.MouseButton1, IDS, lookup, {}, reach)[1]).to.equal(
				"fire"
			)
			expect(InputBindingRules.actionsFor(Enum.KeyCode.ButtonX, IDS, lookup, {}, reach)[1]).to.equal("interact")
		end)

		it("returns nothing for an unbound key", function()
			expect(#InputBindingRules.actionsFor(Enum.KeyCode.Q, IDS, lookup, {}, { gameplay = true })).to.equal(0)
		end)

		it("uses an override instead of the default for that device only", function()
			local overrides = { interact = { keyboard = { Enum.KeyCode.F } } }
			local reach = { gameplay = true }
			expect(#InputBindingRules.actionsFor(Enum.KeyCode.E, IDS, lookup, overrides, reach)).to.equal(0)
			expect(InputBindingRules.actionsFor(Enum.KeyCode.F, IDS, lookup, overrides, reach)[1]).to.equal("interact")
			-- The gamepad binding was not overridden, so it still works.
			expect(InputBindingRules.actionsFor(Enum.KeyCode.ButtonX, IDS, lookup, overrides, reach)[1]).to.equal(
				"interact"
			)
		end)

		it("returns every matching action in id order", function()
			local found = InputBindingRules.actionsFor(Enum.KeyCode.E, IDS, lookup, {}, { gameplay = true, ui = true })
			expect(#found).to.equal(2)
			expect(found[1]).to.equal("confirm")
			expect(found[2]).to.equal("interact")
		end)
	end)

	describe("effective", function()
		it("merges an override over the default per device", function()
			local merged = InputBindingRules.effective(ACTIONS.interact.bindings, { keyboard = { Enum.KeyCode.F } })
			expect(merged.keyboard[1]).to.equal(Enum.KeyCode.F)
			expect(merged.gamepad[1]).to.equal(Enum.KeyCode.ButtonX)
		end)

		it("is the default when there is no override", function()
			local merged = InputBindingRules.effective(ACTIONS.interact.bindings, nil)
			expect(merged.keyboard[1]).to.equal(Enum.KeyCode.E)
		end)
	end)
end
