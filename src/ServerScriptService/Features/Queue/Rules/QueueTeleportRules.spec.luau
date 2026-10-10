local HttpService = game:GetService("HttpService")

local QueueTeleportRules = require(script.Parent.QueueTeleportRules)

local function ticket()
	return {
		kind = "depart",
		from = "home",
		role = "away",
		party = { 7, 8 },
		capacity = 4,
		payload = { contract = "c-1", night = 2, hard = true },
	}
end

-- What the arrival server sees: the encoded ticket after a JSON round trip (teleport data is a JSON string).
local function wire(value)
	return HttpService:JSONDecode(HttpService:JSONEncode(QueueTeleportRules.encode(value)))
end

return function()
	describe("retryDelay", function()
		it("backs off over three retries, then gives up", function()
			expect(QueueTeleportRules.retryDelay(1)).to.equal(1)
			expect(QueueTeleportRules.retryDelay(2)).to.equal(2)
			expect(QueueTeleportRules.retryDelay(3)).to.equal(4)
			expect(QueueTeleportRules.retryDelay(4)).to.equal(nil)
			expect(QueueTeleportRules.retryDelay(0)).to.equal(nil)
		end)
	end)

	describe("payload", function()
		it("accepts flat strings, numbers and booleans as a copy", function()
			local original = { a = "x", b = 1, c = true }
			local checked = QueueTeleportRules.payload(original)
			expect(checked.a).to.equal("x")
			expect(checked.b).to.equal(1)
			expect(checked.c).to.equal(true)
			expect(checked).never.to.equal(original)
		end)

		it("treats a missing payload as empty", function()
			expect(next(QueueTeleportRules.payload(nil))).to.equal(nil)
		end)

		it("refuses too many keys and says why", function()
			local big = {}
			for index = 1, 33 do
				big[`k{index}`] = index
			end
			local checked, reason = QueueTeleportRules.payload(big)
			expect(checked).to.equal(nil)
			expect(reason).never.to.equal(nil)
		end)

		it("refuses an overlong string or key", function()
			expect(QueueTeleportRules.payload({ a = string.rep("x", 1001) })).to.equal(nil)
			expect(QueueTeleportRules.payload({ [string.rep("k", 65)] = 1 })).to.equal(nil)
		end)

		it("refuses a nested table, NaN or infinity", function()
			expect(QueueTeleportRules.payload({ a = {} })).to.equal(nil)
			expect(QueueTeleportRules.payload({ a = 0 / 0 })).to.equal(nil)
			expect(QueueTeleportRules.payload({ a = math.huge })).to.equal(nil)
		end)
	end)

	describe("encode / decode", function()
		it("survives the trip as JSON teleport data", function()
			local decoded = QueueTeleportRules.decode(wire(ticket()))
			expect(decoded.kind).to.equal("depart")
			expect(decoded.from).to.equal("home")
			expect(decoded.role).to.equal("away")
			expect(decoded.party[2]).to.equal(8)
			expect(decoded.capacity).to.equal(4)
			expect(decoded.payload.contract).to.equal("c-1")
			expect(decoded.payload.night).to.equal(2)
			expect(decoded.payload.hard).to.equal(true)
		end)

		it("keeps an empty payload and a missing source", function()
			local value = ticket()
			value.payload = {}
			value.from = nil
			value.kind = "return"
			local decoded = QueueTeleportRules.decode(wire(value))
			expect(decoded.kind).to.equal("return")
			expect(decoded.from).to.equal(nil)
			expect(next(decoded.payload)).to.equal(nil)
		end)

		it("rejects data that is not a queue ticket", function()
			expect(QueueTeleportRules.decode(nil)).to.equal(nil)
			expect(QueueTeleportRules.decode("hello")).to.equal(nil)
			expect(QueueTeleportRules.decode({})).to.equal(nil)
			local other = wire(ticket())
			other.v = 99
			expect(QueueTeleportRules.decode(other)).to.equal(nil)
		end)

		it("rejects a forged or broken ticket", function()
			for _, bad in
				{
					{ kind = "steal" },
					{ role = "" },
					{ from = 5 },
					{ capacity = 0 },
					{ capacity = 4.5 },
					{ capacity = 51 },
					{ party = { "7" } },
					{ party = { 7, -8 } },
					{ party = { 7, 8, 9 }, capacity = 2 },
					{ payload = { a = { b = 1 } } },
					{ payload = { a = string.rep("x", 1001) } },
				}
			do
				local forged = wire(ticket())
				for key, item in bad do
					forged[key] = item
				end
				expect(QueueTeleportRules.decode(forged)).to.equal(nil)
			end
		end)

		it("rejects a party that lists a player twice", function()
			local forged = wire(ticket())
			forged.party = { 7, 8, 7 }
			expect(QueueTeleportRules.decode(forged)).to.equal(nil)
		end)

		it("rejects a party that is not a list", function()
			local keyed = wire(ticket())
			keyed.party = { a = 7, b = 8 }
			expect(QueueTeleportRules.decode(keyed)).to.equal(nil)
			local holey = wire(ticket())
			holey.party = { [1] = 7, [3] = 8, [5] = 9 }
			expect(QueueTeleportRules.decode(holey)).to.equal(nil)
		end)
	end)
end
