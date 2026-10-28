local System = require(script.Parent.ShiftWorkOrderSystem)
local function signal()
	local callbacks = {}
	return {
		Connect = function(_, fn)
			callbacks[fn] = true
			return {
				Disconnect = function()
					callbacks[fn] = nil
				end,
			}
		end,
		Fire = function(_, ...)
			for fn in callbacks do
				fn(...)
			end
		end,
	}
end
return function()
	describe("ShiftWorkOrderSystem", function()
		local source, calls, stop, player
		beforeEach(function()
			player = { UserId = 7, Parent = workspace }
			source = {
				piles = signal(),
				loaded = signal(),
				changed = signal(),
				eligible = function()
					return true
				end,
				crew = function()
					return { player, player }
				end,
			}
			calls = {}
			stop = System.start(source, function(p, kind, amount)
				table.insert(calls, { player = p, kind = kind, amount = amount })
			end)
		end)
		afterEach(function()
			stop()
		end)
		it("counts each contributor once and accepted loads, never pickups", function()
			source.piles:Fire(Instance.new("Part"), { player, player })
			source.loaded:Fire(player, 4, 3, 2)
			expect(#calls).to.equal(3)
			expect(calls[1].kind).to.equal("piles")
			expect(calls[1].amount).to.equal(1)
			expect(calls[2].kind).to.equal("cargo")
			expect(calls[2].amount).to.equal(4)
			expect(calls[3].kind).to.equal("salvage")
			expect(calls[3].amount).to.equal(2)
		end)
		it("rejects ineligible gameplay and counts a completed shift only once", function()
			source.eligible = function()
				return false
			end
			source.piles:Fire(nil, { player })
			source.loaded:Fire(player, 3, 1, 1)
			expect(#calls).to.equal(0)
			source.changed:Fire({ phase = "running", shift = 1 })
			source.changed:Fire({ phase = "results", shift = 1 })
			source.changed:Fire({ phase = "results", shift = 1 })
			expect(#calls).to.equal(1)
			expect(calls[1].kind).to.equal("shifts")
		end)
		it("disconnects every source on stop", function()
			stop()
			source.loaded:Fire(player, 4, 0, 0)
			source.piles:Fire(nil, { player })
			source.changed:Fire({ phase = "results", shift = 1 })
			expect(#calls).to.equal(0)
		end)
	end)
end
