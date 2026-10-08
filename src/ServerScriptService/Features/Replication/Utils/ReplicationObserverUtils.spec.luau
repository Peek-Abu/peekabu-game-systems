local ServerScriptService = game:GetService("ServerScriptService")
local ReplicationFanoutSystem = require(ServerScriptService.Features.Replication.Systems.ReplicationFanoutSystem)
local ReplicationObserverUtils = require(ServerScriptService.Features.Replication.Utils.ReplicationObserverUtils)

-- A ready, live body (slot = userId) and its fake player.
local function addBody(bodies, players, userId, position)
	local body = ReplicationFanoutSystem.newBody(userId, userId, 0, position or Vector3.zero)
	body.ready = true
	body.alive = true
	bodies[userId] = body
	players[userId] = { UserId = userId, Name = `P{userId}` }
	return body
end

local function userIdsOf(list)
	local ids = {}
	for _, player in list do
		table.insert(ids, player.UserId)
	end
	table.sort(ids)
	return ids
end

return function()
	describe("observersOf", function()
		it("lists the ready viewers that have the body loaded", function()
			local bodies, players = {}, {}
			addBody(bodies, players, 1)
			addBody(bodies, players, 2).relevant[1] = true
			addBody(bodies, players, 3)
			local ids = userIdsOf(ReplicationObserverUtils.observersOf(bodies, players, 1))
			expect(#ids).to.equal(1)
			expect(ids[1]).to.equal(2)
		end)

		it("never lists the body's own player (its relevant set holds itself)", function()
			local bodies, players = {}, {}
			addBody(bodies, players, 1)
			expect(#ReplicationObserverUtils.observersOf(bodies, players, 1)).to.equal(0)
		end)

		it("skips a viewer that is not ready or has no player", function()
			local bodies, players = {}, {}
			addBody(bodies, players, 1)
			local unready = addBody(bodies, players, 2)
			unready.relevant[1] = true
			unready.ready = false
			addBody(bodies, players, 3).relevant[1] = true
			players[3] = nil
			expect(#ReplicationObserverUtils.observersOf(bodies, players, 1)).to.equal(0)
		end)
	end)

	describe("observersNear", function()
		it("lists the ready, live bodies within the radius", function()
			local bodies, players = {}, {}
			addBody(bodies, players, 1, Vector3.new(0, 0, 0))
			addBody(bodies, players, 2, Vector3.new(50, 0, 0))
			addBody(bodies, players, 3, Vector3.new(700, 0, 0))
			local ids = userIdsOf(ReplicationObserverUtils.observersNear(bodies, players, Vector3.zero, 600))
			expect(#ids).to.equal(2)
			expect(ids[1]).to.equal(1)
			expect(ids[2]).to.equal(2)
		end)

		it("skips bodies that are not live or not ready", function()
			local bodies, players = {}, {}
			addBody(bodies, players, 1).alive = false
			addBody(bodies, players, 2).ready = false
			expect(#ReplicationObserverUtils.observersNear(bodies, players, Vector3.zero, 600)).to.equal(0)
		end)
	end)

	describe("sendToObservers", function()
		it("sends to the observers plus the body's player and returns the count", function()
			local bodies, players = {}, {}
			addBody(bodies, players, 1)
			addBody(bodies, players, 2).relevant[1] = true
			addBody(bodies, players, 3)
			local sent = {}
			local packet = {
				sendTo = function(data, target)
					table.insert(sent, { data = data, target = target })
				end,
			}
			expect(ReplicationObserverUtils.sendToObservers(bodies, players, players[1], packet, "spark")).to.equal(2)
			expect(#sent).to.equal(2)
			expect(sent[1].data).to.equal("spark")
			local targets = {}
			for _, entry in sent do
				table.insert(targets, entry.target)
			end
			local ids = userIdsOf(targets)
			expect(ids[1]).to.equal(1)
			expect(ids[2]).to.equal(2)
		end)

		it("skips the body's own player while its client is not ready", function()
			local bodies, players = {}, {}
			addBody(bodies, players, 1).ready = false
			addBody(bodies, players, 2).relevant[1] = true
			local sent = {}
			local packet = {
				sendTo = function(_data, target)
					table.insert(sent, target)
				end,
			}
			expect(ReplicationObserverUtils.sendToObservers(bodies, players, players[1], packet, "spark")).to.equal(1)
			expect(#sent).to.equal(1)
			expect(sent[1].UserId).to.equal(2)
		end)
	end)
end
