local UIPreloadStore = require(script.Parent.UIPreloadStore)

return function()
	describe("UIPreloadStore", function()
		afterEach(function()
			UIPreloadStore.reset()
		end)

		it("starts empty and not ready", function()
			expect(UIPreloadStore.progress()).to.equal(0)
			expect(UIPreloadStore.ready()).to.equal(false)
		end)

		it("holds what the preload writes until reset", function()
			UIPreloadStore.progress(0.5)
			UIPreloadStore.ready(true)
			expect(UIPreloadStore.progress()).to.equal(0.5)
			expect(UIPreloadStore.ready()).to.equal(true)
			UIPreloadStore.reset()
			expect(UIPreloadStore.progress()).to.equal(0)
			expect(UIPreloadStore.ready()).to.equal(false)
		end)
	end)
end
