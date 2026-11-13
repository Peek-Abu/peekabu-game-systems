local UIPreloadSystem = require(script.Parent.UIPreloadSystem)
local UIPreloadStore = require(script.Parent.Parent.State.UIPreloadStore)

local function art()
	local root = Instance.new("Folder")
	root.Name = "CleanupCrew"
	local characters = Instance.new("Folder")
	characters.Name = "Characters"
	characters.Parent = root
	local pippa = Instance.new("Model")
	pippa.Name = "Pippa"
	pippa.Parent = characters
	local faces = Instance.new("Folder")
	faces.Name = "Faces"
	faces.Parent = pippa
	local outfits = Instance.new("Folder")
	outfits.Name = "Outfits"
	outfits.Parent = root
	return root
end

return function()
	describe("UIPreloadSystem", function()
		afterEach(function()
			UIPreloadSystem.stop()
			UIPreloadStore.reset()
		end)

		it("loads every batch in order and is ready with a full bar", function()
			local root = art()
			local loaded = {}
			UIPreloadSystem.start({
				art = root,
				images = { "rbxassetid://1" },
				preload = function(items)
					table.insert(loaded, items)
				end,
			})
			-- faces:Pippa, images, character:Pippa, outfits
			expect(#loaded).to.equal(4)
			expect(loaded[1][1].Name).to.equal("Faces")
			expect(loaded[2][1]).to.equal("rbxassetid://1")
			expect(loaded[3][1].Name).to.equal("Pippa")
			expect(loaded[4][1].Name).to.equal("Outfits")
			expect(UIPreloadStore.ready()).to.equal(true)
			expect(UIPreloadStore.progress()).to.equal(1)
			local state = UIPreloadSystem.getState()
			expect(state.done).to.equal(3)
			expect(state.total).to.equal(3)
			expect(state.timedOut).to.equal(false)
			root:Destroy()
		end)

		it("keeps going when a batch fails", function()
			local root = art()
			local calls = 0
			UIPreloadSystem.start({
				art = root,
				images = {},
				preload = function()
					calls += 1
					if calls == 1 then
						error("asset fetch failed")
					end
				end,
			})
			expect(calls).to.equal(3)
			expect(UIPreloadStore.ready()).to.equal(true)
			root:Destroy()
		end)

		it("is ready anyway when the essential art takes too long", function()
			local root = art()
			UIPreloadSystem.start({
				art = root,
				images = {},
				timeout = 0.05,
				preload = function()
					task.wait(1)
				end,
			})
			expect(UIPreloadStore.ready()).to.equal(false)
			task.wait(0.15)
			expect(UIPreloadStore.ready()).to.equal(true)
			expect(UIPreloadStore.progress() < 1).to.equal(true)
			expect(UIPreloadSystem.getState().timedOut).to.equal(true)
			root:Destroy()
		end)

		it("starts once", function()
			local root = art()
			local calls = 0
			local options = {
				art = root,
				images = {},
				preload = function()
					calls += 1
				end,
			}
			UIPreloadSystem.start(options)
			UIPreloadSystem.start(options)
			expect(calls).to.equal(3)
			root:Destroy()
		end)
	end)
end
