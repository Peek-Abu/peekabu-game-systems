--!nocheck
--[=[
	Unit tests for SceneStack — push/pop/replace over the reactive scene stack.

	The stack holds SCENES, not screens (Bank is one scene showing two co-visible panels). Order
	encodes suspension: the top is active, everything below is suspended. Escape pops one. These tests
	register "StackSpec.*" scenes (guarded by `has` for session re-runs) and reset the atom per test.
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SceneRegistry = require(script.Parent.SceneRegistry)
local UIStore = require(ReplicatedStorage.Client.UI.Scenes.UIStore)
local SceneStack = require(script.Parent.SceneStack)

local function ensure(name)
	if not SceneRegistry.has(name) then
		SceneRegistry.register({ name = name, screens = {} })
	end
end

local function ensureDef(def)
	if not SceneRegistry.has(def.name) then
		SceneRegistry.register(def)
	end
end

return function()
	ensure("StackSpec.A")
	ensure("StackSpec.B")
	ensure("StackSpec.C")
	ensureDef({ name = "StackSpec.Hiding", screens = {}, hud = "hidden" })
	ensureDef({ name = "StackSpec.Showing", screens = {}, hud = "visible" })

	local noop = function()
		return nil
	end
	ensureDef({
		name = "StackSpec.PanelOne",
		screens = { { layer = "Panel", key = "one", component = noop } },
	})
	ensureDef({
		name = "StackSpec.PanelTwo",
		screens = { { layer = "Panel", key = "two", component = noop } },
	})
	-- A scene showing two co-visible screens on different layers (the Bank shape).
	ensureDef({
		name = "StackSpec.MultiLayer",
		screens = {
			{ layer = "Panel", key = "left", component = noop },
			{ layer = "Overlay", key = "over", component = noop },
		},
	})

	beforeEach(function()
		UIStore.sceneStack({})
	end)
	afterEach(function()
		UIStore.sceneStack({}) -- leave the shared stack clean for other spec files
	end)

	describe("push", function()
		it("pushes a scene and makes it the top", function()
			SceneStack.push("StackSpec.A")
			expect(SceneStack.depth()).to.equal(1)
			expect(SceneStack.top()).to.equal("StackSpec.A")
			expect(SceneStack.isActive("StackSpec.A")).to.equal(true)
		end)

		it("suspends the scene below when another is pushed", function()
			SceneStack.push("StackSpec.A")
			SceneStack.push("StackSpec.B")
			expect(SceneStack.depth()).to.equal(2)
			expect(SceneStack.top()).to.equal("StackSpec.B")
			expect(SceneStack.isSuspended("StackSpec.A")).to.equal(true)
			expect(SceneStack.isSuspended("StackSpec.B")).to.equal(false)
		end)

		it("does not stack the same scene twice", function()
			SceneStack.push("StackSpec.A")
			SceneStack.push("StackSpec.A")
			expect(SceneStack.depth()).to.equal(1)
		end)

		it("errors when pushing an unregistered scene", function()
			expect(function()
				SceneStack.push("StackSpec.Ghost")
			end).to.throw()
		end)
	end)

	describe("remove", function()
		it("removes a SUSPENDED scene without disturbing the top", function()
			SceneStack.push("StackSpec.A")
			SceneStack.push("StackSpec.B")
			SceneStack.remove("StackSpec.A")
			expect(SceneStack.depth()).to.equal(1)
			expect(SceneStack.top()).to.equal("StackSpec.B")
			expect(SceneStack.isActive("StackSpec.A")).to.equal(false)
		end)

		it("removes the top scene, revealing the one beneath", function()
			SceneStack.push("StackSpec.A")
			SceneStack.push("StackSpec.B")
			SceneStack.remove("StackSpec.B")
			expect(SceneStack.depth()).to.equal(1)
			expect(SceneStack.top()).to.equal("StackSpec.A")
		end)

		it("removes the middle scene, keeping the order of the rest", function()
			SceneStack.push("StackSpec.A")
			SceneStack.push("StackSpec.B")
			SceneStack.push("StackSpec.C")
			SceneStack.remove("StackSpec.B")
			expect(SceneStack.depth()).to.equal(2)
			expect(SceneStack.top()).to.equal("StackSpec.C")
			expect(SceneStack.isSuspended("StackSpec.A")).to.equal(true)
		end)

		it("is a no-op for a scene that is not on the stack", function()
			SceneStack.push("StackSpec.A")
			SceneStack.remove("StackSpec.B")
			SceneStack.remove("StackSpec.Ghost") -- unregistered: not on the stack, so not an error
			expect(SceneStack.depth()).to.equal(1)
			expect(SceneStack.top()).to.equal("StackSpec.A")
		end)
	end)

	describe("pop", function()
		it("removes the top scene", function()
			SceneStack.push("StackSpec.A")
			SceneStack.push("StackSpec.B")
			SceneStack.pop()
			expect(SceneStack.depth()).to.equal(1)
			expect(SceneStack.top()).to.equal("StackSpec.A")
		end)

		it("is a no-op on an empty stack", function()
			expect(function()
				SceneStack.pop()
			end).never.to.throw()
			expect(SceneStack.depth()).to.equal(0)
		end)
	end)

	describe("replace", function()
		it("swaps the top scene", function()
			SceneStack.push("StackSpec.A")
			SceneStack.push("StackSpec.B")
			SceneStack.replace("StackSpec.C")
			expect(SceneStack.depth()).to.equal(2)
			expect(SceneStack.top()).to.equal("StackSpec.C")
			expect(SceneStack.isActive("StackSpec.B")).to.equal(false)
			expect(SceneStack.isSuspended("StackSpec.A")).to.equal(true)
		end)

		it("pushes when the stack is empty", function()
			SceneStack.replace("StackSpec.A")
			expect(SceneStack.depth()).to.equal(1)
			expect(SceneStack.top()).to.equal("StackSpec.A")
		end)

		it("errors when replacing with an unregistered scene", function()
			expect(function()
				SceneStack.replace("StackSpec.Ghost")
			end).to.throw()
		end)
	end)

	describe("hudHidden", function()
		it("is false when nothing is open", function()
			expect(SceneStack.hudHidden()).to.equal(false)
		end)

		it("is false for a scene that does not ask to hide the HUD", function()
			SceneStack.push("StackSpec.A")
			expect(SceneStack.hudHidden()).to.equal(false)
		end)

		it("is true while a hiding scene is open", function()
			SceneStack.push("StackSpec.Hiding")
			expect(SceneStack.hudHidden()).to.equal(true)
		end)

		it("stays true when a no-opinion scene is pushed over a hiding scene (defers down)", function()
			SceneStack.push("StackSpec.Hiding")
			SceneStack.push("StackSpec.A") -- A has no hud opinion, so it defers to Hiding beneath it
			expect(SceneStack.hudHidden()).to.equal(true)
		end)

		it("a scene declaring hud visible OVERRIDES a hiding scene below it", function()
			SceneStack.push("StackSpec.Hiding")
			SceneStack.push("StackSpec.Showing") -- topmost opinion wins
			expect(SceneStack.hudHidden()).to.equal(false)
		end)

		it("a hiding scene on top still wins over a visible scene below it", function()
			SceneStack.push("StackSpec.Showing")
			SceneStack.push("StackSpec.Hiding")
			expect(SceneStack.hudHidden()).to.equal(true)
		end)

		it("returns to false once the hiding scene closes", function()
			SceneStack.push("StackSpec.Hiding")
			SceneStack.pop()
			expect(SceneStack.hudHidden()).to.equal(false)
		end)
	end)

	describe("screensFor", function()
		it("is empty for an empty stack", function()
			expect(#SceneStack.screensFor({}, "Panel")).to.equal(0)
		end)

		it("returns a scene's screen for the matching layer, tagged with the scene", function()
			local hosted = SceneStack.screensFor({ "StackSpec.PanelOne" }, "Panel")
			expect(#hosted).to.equal(1)
			expect(hosted[1].scene).to.equal("StackSpec.PanelOne")
			expect(hosted[1].screen.key).to.equal("one")
			expect(hosted[1].screen.layer).to.equal("Panel")
		end)

		it("collects across the stack in bottom-to-top order", function()
			local hosted = SceneStack.screensFor({ "StackSpec.PanelOne", "StackSpec.PanelTwo" }, "Panel")
			expect(#hosted).to.equal(2)
			expect(hosted[1].screen.key).to.equal("one") -- bottom first
			expect(hosted[2].screen.key).to.equal("two") -- top last (drawn on top)
		end)

		it("filters to the requested layer only", function()
			local panel = SceneStack.screensFor({ "StackSpec.MultiLayer" }, "Panel")
			local overlay = SceneStack.screensFor({ "StackSpec.MultiLayer" }, "Overlay")
			expect(#panel).to.equal(1)
			expect(panel[1].screen.key).to.equal("left")
			expect(#overlay).to.equal(1)
			expect(overlay[1].screen.key).to.equal("over")
			-- a layer nothing targets is empty
			expect(#SceneStack.screensFor({ "StackSpec.MultiLayer" }, "Wheel")).to.equal(0)
		end)

		it("contributes nothing for an unregistered or screenless scene", function()
			expect(#SceneStack.screensFor({ "StackSpec.Ghost" }, "Panel")).to.equal(0)
			expect(#SceneStack.screensFor({ "StackSpec.A" }, "Panel")).to.equal(0) -- registered, no screens
		end)
	end)

	describe("queries", function()
		it("reports depth, active, suspended, and top consistently", function()
			expect(SceneStack.depth()).to.equal(0)
			expect(SceneStack.top()).to.equal(nil)
			expect(SceneStack.isActive("StackSpec.A")).to.equal(false)

			SceneStack.push("StackSpec.A")
			expect(SceneStack.isSuspended("StackSpec.A")).to.equal(false) -- top is never suspended
		end)
	end)
end
