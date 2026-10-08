--!nocheck
--[=[
	Unit tests for UIStore — the reactive source of truth for what UI is open.

	The sceneStack atom is the single place that answers "what is on screen"; SceneStack mutates it and
	React screens read it via useAtom to DERIVE visibility (never commanded). These assertions pin the
	loading default and the atom round-trip, the same idiom as StateSyncClientStore.spec.
]=]

local UIStore = require(script.Parent.UIStore)

return function()
	-- Reset BEFORE each test, not just after: the sceneStack is a shared singleton, and another spec
	-- file (SceneStack.spec) may have left it non-empty. beforeEach makes each test order-independent.
	beforeEach(function()
		UIStore.sceneStack({})
	end)
	afterEach(function()
		UIStore.sceneStack({}) -- also leave it clean for other specs
	end)

	describe("sceneStack", function()
		it("starts empty (no UI is open at boot)", function()
			expect(type(UIStore.sceneStack())).to.equal("table")
			expect(#UIStore.sceneStack()).to.equal(0)
		end)

		it("round-trips an ordered list of scene names", function()
			UIStore.sceneStack({ "A", "B" })
			local stack = UIStore.sceneStack()
			expect(#stack).to.equal(2)
			expect(stack[1]).to.equal("A")
			expect(stack[2]).to.equal("B")
		end)
	end)
end
