--[=[
	Unit tests for the UIBillboards core: one React root per world shell, rendered in place, destroyed once on hide.
	The factory is a spy, so no renderer or Instance tree is needed; UIBillboardHost is the exempt real factory.
]=]

local UIBillboards = require(script.Parent.UIBillboards)

local function shellNamed(name)
	local shell = Instance.new("BillboardGui")
	shell.Name = name
	return shell
end

-- A spy factory: records every root made and every render / unmount / destroy, in order.
local function spyFactory()
	local record = { made = {}, events = {} }
	local factory = function(shell)
		local name = shell.Name
		table.insert(record.made, name)
		return {
			render = function(element)
				table.insert(record.events, `render:{name}:{tostring(element)}`)
			end,
			unmount = function()
				table.insert(record.events, `unmount:{name}`)
			end,
			destroy = function()
				table.insert(record.events, `destroy:{name}`)
			end,
		}
	end
	return factory, record
end

return function()
	describe("show", function()
		it("makes no root until a shell is shown", function()
			local factory, record = spyFactory()
			local roots = UIBillboards.new(factory)
			expect(#record.made).to.equal(0)
			expect(roots.count()).to.equal(0)
		end)

		it("makes a root on the first show and renders into it", function()
			local factory, record = spyFactory()
			local roots = UIBillboards.new(factory)
			roots.show(shellNamed("A"), "one")
			expect(#record.made).to.equal(1)
			expect(record.events[1]).to.equal("render:A:one")
			expect(roots.count()).to.equal(1)
		end)

		it("renders into the same root on every later show, never mounting twice", function()
			local factory, record = spyFactory()
			local roots = UIBillboards.new(factory)
			local shell = shellNamed("A")
			roots.show(shell, "one")
			roots.show(shell, "two")
			roots.show(shell, "three")
			expect(#record.made).to.equal(1)
			expect(record.events[2]).to.equal("render:A:two")
			expect(record.events[3]).to.equal("render:A:three")
			expect(roots.count()).to.equal(1)
		end)

		it("keeps one root per shell", function()
			local factory, record = spyFactory()
			local roots = UIBillboards.new(factory)
			roots.show(shellNamed("A"), "a")
			roots.show(shellNamed("B"), "b")
			expect(#record.made).to.equal(2)
			expect(roots.count()).to.equal(2)
		end)
	end)

	describe("hide", function()
		it("destroys a hidden shell's root and forgets it", function()
			local factory, record = spyFactory()
			local roots = UIBillboards.new(factory)
			local shell = shellNamed("A")
			roots.show(shell, "one")
			roots.hide(shell)
			expect(record.events[2]).to.equal("unmount:A")
			expect(record.events[3]).to.equal("destroy:A")
			expect(roots.count()).to.equal(0)
			-- Shown again later, it gets a fresh root.
			roots.show(shell, "two")
			expect(#record.made).to.equal(2)
		end)

		it("ignores a shell it never showed", function()
			local factory, record = spyFactory()
			local roots = UIBillboards.new(factory)
			roots.hide(shellNamed("A"))
			expect(#record.events).to.equal(0)
		end)

		it("destroys a root exactly once, even when hide runs again while it unmounts", function()
			local record = { destroyed = 0 }
			local roots
			local shell = shellNamed("A")
			roots = UIBillboards.new(function(_shell)
				return {
					render = function() end,
					-- The unmount re-enters hide, the way a Destroying handler can.
					unmount = function()
						roots.hide(shell)
					end,
					destroy = function()
						record.destroyed += 1
					end,
				}
			end)
			roots.show(shell, "one")
			roots.hide(shell)
			roots.hide(shell)
			expect(record.destroyed).to.equal(1)
			expect(roots.count()).to.equal(0)
		end)
	end)

	describe("teardown", function()
		it("destroys every root on teardown, in the order they were made", function()
			local factory, record = spyFactory()
			local roots = UIBillboards.new(factory)
			roots.show(shellNamed("A"), "a")
			roots.show(shellNamed("B"), "b")
			roots.teardown()
			expect(record.events[3]).to.equal("unmount:A")
			expect(record.events[4]).to.equal("destroy:A")
			expect(record.events[5]).to.equal("unmount:B")
			expect(record.events[6]).to.equal("destroy:B")
			expect(roots.count()).to.equal(0)
		end)

		it("is safe to call twice", function()
			local factory, record = spyFactory()
			local roots = UIBillboards.new(factory)
			roots.show(shellNamed("A"), "a")
			roots.teardown()
			roots.teardown()
			expect(#record.events).to.equal(3)
		end)
	end)
end
