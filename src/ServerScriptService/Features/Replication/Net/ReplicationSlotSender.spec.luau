--[=[
	Unit tests for ReplicationSlotSender: the slot entry's shape, and who a broadcast reaches. A recording
	packet stands in for ByteNet, so no real players are needed.
]=]

local ReplicationSlotSender = require(script.Parent.ReplicationSlotSender)

local function body(userId, ready)
	return { slot = 4, userId = userId, generation = 3, epoch = { value = 7 }, ready = ready }
end

return function()
	describe("entryOf", function()
		it("carries the slot, the owner, the generation, the epoch value and the active flag", function()
			local entry = ReplicationSlotSender.entryOf(body(-41, true), false)
			expect(entry.slot).to.equal(4)
			expect(entry.userId).to.equal(-41)
			expect(entry.generation).to.equal(3)
			expect(entry.epoch).to.equal(7)
			expect(entry.active).to.equal(false)
		end)
	end)

	describe("broadcast", function()
		it("reaches every ready viewer that is a connected player, and no one else", function()
			local sent = {}
			local packet = {
				sendTo = function(entry, player)
					table.insert(sent, { entry = entry, player = player })
				end,
			}
			local bodies = { [-1] = body(-1, true), [-2] = body(-2, false), [-3] = body(-3, true) }
			local players = { [-1] = "playerOne", [-2] = "playerTwo" } -- -3 has no player: left mid-tick
			ReplicationSlotSender.broadcast(packet, body(-9, true), true, bodies, players)
			expect(#sent).to.equal(1)
			expect(sent[1].player).to.equal("playerOne")
			expect(sent[1].entry.userId).to.equal(-9)
			expect(sent[1].entry.active).to.equal(true)
		end)

		it("sends a release with active = false", function()
			local sent = {}
			local packet = {
				sendTo = function(entry)
					table.insert(sent, entry)
				end,
			}
			ReplicationSlotSender.broadcast(packet, body(-9, true), false, { [-1] = body(-1, true) }, { [-1] = "p" })
			expect(sent[1].active).to.equal(false)
		end)
	end)
end
