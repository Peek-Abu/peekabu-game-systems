--!nocheck
--[=[
	Unit tests for the UIWorldSuppression core — the refcounted union of what scenes suppress.

	The core takes an injectable scene resolver and warn function, so it runs with no Instances and no
	renderer; the real handlers (mouse/blur, touching UserInputService/Lighting) live in the exempt
	UISuppression shell. These tests pin the composition behaviour: two scenes requesting the same
	capability engage it ONCE, and it only releases when the last one goes away.
]=]

local UIWorldSuppression = require(script.Parent.UIWorldSuppression)

local function resolverFor(records)
	return function(name)
		return records[name]
	end
end

local function spyHandler()
	local spy = { engaged = 0, disengaged = 0 }
	spy.handler = {
		engage = function()
			spy.engaged += 1
		end,
		disengage = function()
			spy.disengaged += 1
		end,
	}
	return spy
end

return function()
	describe("reconcile with handlers", function()
		it("engages a handled capability when a scene requests it", function()
			local core = UIWorldSuppression.new(resolverFor({ Inv = { mouse = true } }), function() end)
			local mouse = spyHandler()
			core.registerHandler("mouse", mouse.handler)
			core.reconcile({ "Inv" })
			expect(mouse.engaged).to.equal(1)
			expect(mouse.disengaged).to.equal(0)
		end)

		it("composes: two scenes requesting the same capability engage it once", function()
			local core = UIWorldSuppression.new(
				resolverFor({ A = { mouse = true }, B = { mouse = true } }),
				function() end
			)
			local mouse = spyHandler()
			core.registerHandler("mouse", mouse.handler)
			core.reconcile({ "A" })
			core.reconcile({ "A", "B" })
			expect(mouse.engaged).to.equal(1) -- still only once
			expect(core.counts().mouse).to.equal(2)
			core.reconcile({ "A" }) -- pop B — still requested by A
			expect(mouse.disengaged).to.equal(0)
			core.reconcile({}) -- pop A — now released
			expect(mouse.disengaged).to.equal(1)
		end)

		it("disengages once the capability is no longer requested", function()
			local core = UIWorldSuppression.new(resolverFor({ A = { blur = true } }), function() end)
			local blur = spyHandler()
			core.registerHandler("blur", blur.handler)
			core.reconcile({ "A" })
			core.reconcile({})
			expect(blur.engaged).to.equal(1)
			expect(blur.disengaged).to.equal(1)
		end)

		it("counts the number of requesting scenes", function()
			local core = UIWorldSuppression.new(
				resolverFor({ A = { mouse = true }, B = { mouse = true }, C = {} }),
				function() end
			)
			core.reconcile({ "A", "B", "C" })
			expect(core.counts().mouse).to.equal(2)
		end)

		it("ignores scenes with no suppression record", function()
			local core = UIWorldSuppression.new(function()
				return nil
			end, function() end)
			expect(function()
				core.reconcile({ "X" })
			end).never.to.throw()
			expect(next(core.counts())).to.equal(nil)
		end)
	end)

	describe("unhandled capabilities", function()
		it("warns exactly once for a declared-but-unhandled capability", function()
			local warned = {}
			local core = UIWorldSuppression.new(resolverFor({ A = { movement = true } }), function(message)
				table.insert(warned, message)
			end)
			core.reconcile({ "A" })
			core.reconcile({}) -- release
			core.reconcile({ "A" }) -- request again
			expect(#warned).to.equal(1)
		end)
	end)

	describe("late handler registration", function()
		it("adopts a capability that is already active", function()
			local core = UIWorldSuppression.new(resolverFor({ A = { cameraState = "PanelOpen" } }), function() end)
			core.reconcile({ "A" }) -- cameraState requested, no handler yet (warns once)
			local camera = spyHandler()
			core.registerHandler("cameraState", camera.handler)
			expect(camera.engaged).to.equal(1) -- adopts the active state at registration
		end)

		it("does not engage a handler for an inactive capability", function()
			local core = UIWorldSuppression.new(function()
				return nil
			end, function() end)
			local mouse = spyHandler()
			core.registerHandler("mouse", mouse.handler)
			expect(mouse.engaged).to.equal(0)
		end)
	end)
end
