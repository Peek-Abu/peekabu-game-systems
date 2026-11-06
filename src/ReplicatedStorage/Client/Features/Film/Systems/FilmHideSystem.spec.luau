local FilmHideSystem = require(script.Parent.FilmHideSystem)

local function gui(className, name, parent, enabled)
	local item = Instance.new(className)
	item.Name = name
	item.Enabled = enabled ~= false
	item.Parent = parent
	return item
end

return function()
	describe("FilmHideSystem", function()
		local root, other, system, told

		beforeEach(function()
			root = Instance.new("Folder")
			other = Instance.new("Folder")
			told = {}
			system = FilmHideSystem.new({
				roots = { root, other },
				keep = function(item)
					return item.Name == "Cmdr"
				end,
				onHidden = function(hidden)
					table.insert(told, hidden)
				end,
			})
		end)

		afterEach(function()
			system.show()
			root:Destroy()
			other:Destroy()
		end)

		it("hides every screen and billboard under every root, then brings them back", function()
			local hud = gui("ScreenGui", "Hud", root)
			local part = Instance.new("Part")
			part.Parent = other
			local tag = gui("BillboardGui", "Tag", part)
			system.hide()
			expect(system.isHidden()).to.equal(true)
			expect(hud.Enabled).to.equal(false)
			expect(tag.Enabled).to.equal(false)
			system.show()
			expect(system.isHidden()).to.equal(false)
			expect(hud.Enabled).to.equal(true)
			expect(tag.Enabled).to.equal(true)
		end)

		it("leaves world signs (SurfaceGuis) and kept guis alone", function()
			local sign = gui("SurfaceGui", "Sign", root)
			local console = gui("ScreenGui", "Cmdr", root)
			system.hide()
			expect(sign.Enabled).to.equal(true)
			expect(console.Enabled).to.equal(true)
		end)

		it("keeps a gui that was already off, off", function()
			local closed = gui("ScreenGui", "Closed", root, false)
			system.hide()
			system.show()
			expect(closed.Enabled).to.equal(false)
		end)

		it("hides guis that appear while hidden, and brings them back too", function()
			system.hide()
			local late = gui("BillboardGui", "Late", root)
			-- Signals are deferred: the watcher runs at the next resumption point.
			task.wait()
			expect(late.Enabled).to.equal(false)
			system.show()
			expect(late.Enabled).to.equal(true)
		end)

		it("turns a gui back off if something re-enables it while hidden", function()
			local hud = gui("ScreenGui", "Hud", root)
			system.hide()
			hud.Enabled = true
			task.wait()
			expect(hud.Enabled).to.equal(false)
			system.show()
			expect(hud.Enabled).to.equal(true)
		end)

		it("stops watching once shown", function()
			local hud = gui("ScreenGui", "Hud", root)
			system.hide()
			system.show()
			hud.Enabled = false
			hud.Enabled = true
			local late = gui("ScreenGui", "Late", root)
			task.wait()
			expect(hud.Enabled).to.equal(true)
			expect(late.Enabled).to.equal(true)
		end)

		it("is idempotent and tells its hook each change once", function()
			system.hide()
			system.hide()
			system.show()
			system.show()
			expect(#told).to.equal(2)
			expect(told[1]).to.equal(true)
			expect(told[2]).to.equal(false)
		end)

		it("toggles", function()
			system.toggle()
			expect(system.isHidden()).to.equal(true)
			system.toggle()
			expect(system.isHidden()).to.equal(false)
		end)
	end)
end
