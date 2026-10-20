local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ShiftLivesSystem = require(script.Parent.ShiftLivesSystem)
local ShiftConstants = require(ReplicatedStorage.Shared.Features.Shift.Data.ShiftConstants)

local LIVES = ShiftConstants.PUBLIC_LIVES
local MAX = ShiftConstants.PUBLIC_LIVES_MAX
local OUT = ShiftConstants.PUBLIC_KNOCKED_OUT
local START = ShiftConstants.STARTING_LIVES

local function member(userId)
	return { UserId = userId, DisplayName = `Crew {userId}` }
end

-- A system over fakes: `log.fields[userId]` is the public entry, `log.calls` the effects in order.
local function harness(players)
	local log = { running = true, fields = {}, calls = {}, marked = {}, byId = {} }
	for _, player in players do
		log.byId[player.UserId] = player
	end
	log.system = ShiftLivesSystem.new({
		isRunning = function()
			return log.running
		end,
		markOut = function(userId, name)
			table.insert(log.marked, `{userId}:{name}`)
		end,
		setFields = function(userId, fields)
			local entry = log.fields[userId] or {}
			for key, value in fields do
				entry[key] = value
			end
			log.fields[userId] = entry
		end,
		clearField = function(userId, field)
			if log.fields[userId] ~= nil then
				log.fields[userId][field] = nil
			end
		end,
		down = function(player)
			table.insert(log.calls, `down {player.UserId}`)
		end,
		hold = function(player)
			table.insert(log.calls, `hold {player.UserId}`)
		end,
		release = function(player)
			table.insert(log.calls, `release {player.UserId}`)
		end,
		eliminate = function(player)
			table.insert(log.calls, `eliminate {player.UserId}`)
		end,
		playerById = function(userId)
			return log.byId[userId]
		end,
	})
	log.system:begin(players)
	return log
end

local function spendAll(log, player)
	local result = false
	for _ = 1, START do
		result = log.system:spend(player)
	end
	return result
end

return function()
	describe("begin", function()
		it("gives everyone the starting lives and publishes them", function()
			local log = harness({ member(1), member(2) })
			expect(log.fields[1][LIVES]).to.equal(START)
			expect(log.fields[1][MAX]).to.equal(START)
			expect(log.fields[2][LIVES]).to.equal(START)
		end)

		it("runs the starting lives through the modifiers until they are removed", function()
			local log = harness({ member(1) })
			local remove = log.system:addModifier(function(lives)
				return lives + 2
			end)
			log.system:begin({ member(1) })
			expect(log.fields[1][MAX]).to.equal(START + 2)
			remove()
			log.system:begin({ member(1) })
			expect(log.fields[1][MAX]).to.equal(START)
		end)
	end)

	describe("spend", function()
		it("spends one life and publishes the rest without knocking anyone out", function()
			local log = harness({ member(1) })
			expect(log.system:spend(member(1))).to.equal(false)
			expect(log.fields[1][LIVES]).to.equal(START - 1)
			expect(log.fields[1][OUT]).to.equal(nil)
			expect(#log.calls).to.equal(0)
		end)

		it(
			"knocks the player out on the last life: lives 0, the flag, the hold, the elimination, the roster",
			function()
				local log = harness({ member(1) })
				expect(spendAll(log, member(1))).to.equal(true)
				expect(log.fields[1][LIVES]).to.equal(0)
				expect(log.fields[1][OUT]).to.equal(true)
				expect(log.calls[1]).to.equal("hold 1")
				expect(log.calls[2]).to.equal("eliminate 1")
				expect(log.marked[1]).to.equal("1:Crew 1")
				expect(log.system:isKnockedOut(member(1))).to.equal(true)
			end
		)

		it("is false for an unknown player and for one already out", function()
			local log = harness({ member(1) })
			expect(log.system:spend(member(9))).to.equal(false)
			spendAll(log, member(1))
			expect(log.system:spend(member(1))).to.equal(false)
			expect(#log.marked).to.equal(1)
		end)

		it("is false outside a run and spends nothing", function()
			local log = harness({ member(2) })
			log.running = false
			expect(log.system:spend(member(2))).to.equal(false)
			expect(log.fields[2][LIVES]).to.equal(START)
		end)
	end)

	describe("admit", function()
		it("gives a late joiner the starting lives and leaves a listed player's lives alone", function()
			local log = harness({ member(1) })
			log.system:spend(member(1))
			log.system:admit(member(1))
			expect(log.fields[1][LIVES]).to.equal(START - 1)
			log.system:admit(member(2))
			expect(log.fields[2][LIVES]).to.equal(START)
		end)

		it("puts a knocked-out player who rejoins straight back out", function()
			local log = harness({ member(1) })
			spendAll(log, member(1))
			local before = #log.calls
			log.system:admit(member(1))
			expect(log.calls[before + 1]).to.equal("hold 1")
			expect(log.calls[before + 2]).to.equal("eliminate 1")
			expect(log.calls[before + 3]).to.equal("down 1")
			expect(log.fields[1][OUT]).to.equal(true)
			expect(log.fields[1][LIVES]).to.equal(0)
		end)

		it("does not hold or drop a joiner who has lives", function()
			local log = harness({ member(1) })
			log.system:admit(member(2))
			expect(#log.calls).to.equal(0)
		end)

		it("does nothing outside a run", function()
			local log = harness({ member(1) })
			log.running = false
			log.system:admit(member(2))
			expect(log.fields[2]).to.equal(nil)
		end)
	end)

	describe("clear", function()
		it("releases whoever was knocked out and clears every public field", function()
			local log = harness({ member(1), member(2) })
			spendAll(log, member(1))
			log.system:clear()
			expect(log.calls[#log.calls]).to.equal("release 1")
			for userId = 1, 2 do
				expect(log.fields[userId][LIVES]).to.equal(nil)
				expect(log.fields[userId][MAX]).to.equal(nil)
				expect(log.fields[userId][OUT]).to.equal(nil)
			end
			expect(log.system:isKnockedOut(member(1))).to.equal(false)
		end)

		it("clears a knocked-out player who has left without releasing anyone", function()
			local log = harness({ member(1) })
			spendAll(log, member(1))
			log.byId[1] = nil
			local before = #log.calls
			log.system:clear()
			expect(#log.calls).to.equal(before)
			expect(log.fields[1][OUT]).to.equal(nil)
		end)
	end)
end
