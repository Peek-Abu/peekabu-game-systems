local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RoundConstants = require(ReplicatedStorage.Shared.Features.Round.Data.RoundConstants)
local RoundPhaseRules = require(script.Parent.RoundPhaseRules)

local function config(overrides)
	local result = table.clone(RoundConstants.DEFAULT_CONFIG)
	for key, value in overrides or {} do
		result[key] = value
	end
	return result
end

local function counts(present, participants, alive)
	return { present = present, participants = participants or present, alive = alive or participants or present }
end

return function()
	describe("initial", function()
		it("starts in the lobby before any run", function()
			local state = RoundPhaseRules.initial()
			expect(state.phase).to.equal("lobby")
			expect(state.round).to.equal(0)
			expect(state.endsAt).to.equal(nil)
		end)
	end)

	describe("lobby", function()
		it("starts the countdown once enough players are present", function()
			local cfg = config({ minPlayers = 2, countdown = 10, autoStart = true })
			expect(RoundPhaseRules.tick(RoundPhaseRules.initial(), cfg, counts(1), 100)).to.equal(nil)
			local nextState = RoundPhaseRules.tick(RoundPhaseRules.initial(), cfg, counts(2), 100)
			expect(nextState.phase).to.equal("starting")
			expect(nextState.endsAt).to.equal(110)
		end)

		it("waits for startCountdown when autoStart is off (the default)", function()
			local cfg = config()
			expect(RoundPhaseRules.tick(RoundPhaseRules.initial(), cfg, counts(4), 100)).to.equal(nil)
			local nextState = RoundPhaseRules.startCountdown(RoundPhaseRules.initial(), cfg, counts(4), 100)
			expect(nextState.phase).to.equal("starting")
		end)

		it("refuses startCountdown below minPlayers or outside the lobby", function()
			local cfg = config({ minPlayers = 3 })
			expect(RoundPhaseRules.startCountdown(RoundPhaseRules.initial(), cfg, counts(2), 0)).to.equal(nil)
			local running = { phase = "running", round = 1 }
			expect(RoundPhaseRules.startCountdown(running, cfg, counts(5), 0)).to.equal(nil)
		end)
	end)

	describe("starting", function()
		local starting = { phase = "starting", round = 0, endsAt = 110 }

		it("cancels back to the lobby when players drop below minPlayers", function()
			local nextState = RoundPhaseRules.tick(starting, config({ minPlayers = 2 }), counts(1), 105)
			expect(nextState.phase).to.equal("lobby")
			expect(nextState.endsAt).to.equal(nil)
			expect(nextState.round).to.equal(0)
		end)

		it("keeps counting before the end", function()
			expect(RoundPhaseRules.tick(starting, config(), counts(1), 109)).to.equal(nil)
		end)

		it("starts the run (next round number) when the countdown ends", function()
			local nextState = RoundPhaseRules.tick(starting, config({ duration = 60 }), counts(1), 110)
			expect(nextState.phase).to.equal("running")
			expect(nextState.round).to.equal(1)
			expect(nextState.endsAt).to.equal(170)
		end)

		it("runs untimed when there is no duration", function()
			local nextState = RoundPhaseRules.tick(starting, config(), counts(1), 110)
			expect(nextState.phase).to.equal("running")
			expect(nextState.endsAt).to.equal(nil)
		end)
	end)

	describe("startNow", function()
		it("skips the countdown from the lobby or from starting", function()
			local fromLobby = RoundPhaseRules.startNow(RoundPhaseRules.initial(), config(), 5)
			expect(fromLobby.phase).to.equal("running")
			expect(fromLobby.round).to.equal(1)
			local fromStarting =
				RoundPhaseRules.startNow({ phase = "starting", round = 4, endsAt = 50 }, config({ duration = 30 }), 5)
			expect(fromStarting.round).to.equal(5)
			expect(fromStarting.endsAt).to.equal(35)
		end)

		it("refuses while running or showing results", function()
			expect(RoundPhaseRules.startNow({ phase = "running", round = 1 }, config(), 0)).to.equal(nil)
			expect(RoundPhaseRules.startNow({ phase = "results", round = 1 }, config(), 0)).to.equal(nil)
		end)
	end)

	describe("running", function()
		local timed = { phase = "running", round = 2, endsAt = 200 }

		it("ends on timeout", function()
			expect(RoundPhaseRules.tick(timed, config(), counts(2), 199)).to.equal(nil)
			local nextState = RoundPhaseRules.tick(timed, config({ resultsDuration = 8 }), counts(2), 200)
			expect(nextState.phase).to.equal("results")
			expect(nextState.outcome).to.equal(RoundConstants.OUTCOME_TIMEOUT)
			expect(nextState.endsAt).to.equal(208)
			expect(nextState.round).to.equal(2)
		end)

		it("ends abandoned when every participant has left", function()
			local nextState = RoundPhaseRules.tick(timed, config(), counts(3, 0, 0), 150)
			expect(nextState.outcome).to.equal(RoundConstants.OUTCOME_ABANDONED)
		end)

		it("ends wiped when every remaining participant is eliminated", function()
			local nextState = RoundPhaseRules.tick(timed, config(), counts(3, 2, 0), 150)
			expect(nextState.outcome).to.equal(RoundConstants.OUTCOME_WIPED)
		end)

		it("ends with the game's outcome through finish", function()
			local nextState = RoundPhaseRules.finish(timed, config({ resultsDuration = 5 }), 150, "quota")
			expect(nextState.phase).to.equal("results")
			expect(nextState.outcome).to.equal("quota")
			expect(nextState.endsAt).to.equal(155)
		end)

		it("refuses finish outside a run", function()
			expect(RoundPhaseRules.finish(RoundPhaseRules.initial(), config(), 0, "quota")).to.equal(nil)
		end)
	end)

	describe("results", function()
		it("returns to the lobby when the results end, keeping the round count", function()
			local results = { phase = "results", round = 3, endsAt = 50, outcome = "quota" }
			expect(RoundPhaseRules.tick(results, config(), counts(1), 49)).to.equal(nil)
			local nextState = RoundPhaseRules.tick(results, config(), counts(1), 50)
			expect(nextState.phase).to.equal("lobby")
			expect(nextState.round).to.equal(3)
			expect(nextState.outcome).to.equal(nil)
		end)
	end)

	describe("validateConfig", function()
		it("accepts the defaults", function()
			expect(RoundPhaseRules.validateConfig(config())).to.equal(true)
		end)

		it("rejects nonsense values", function()
			expect(RoundPhaseRules.validateConfig(config({ minPlayers = 0 }))).to.equal(false)
			expect(RoundPhaseRules.validateConfig(config({ countdown = -1 }))).to.equal(false)
			expect(RoundPhaseRules.validateConfig(config({ duration = 0 }))).to.equal(false)
			expect(RoundPhaseRules.validateConfig(config({ resultsDuration = -2 }))).to.equal(false)
			expect(RoundPhaseRules.validateConfig(config({ containerCapacity = 1.5 }))).to.equal(false)
		end)
	end)
end
