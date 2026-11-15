local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CargoConstants = require(ReplicatedStorage.Shared.Features.Cargo.Data.CargoConstants)
local HideRules = require(ReplicatedStorage.Shared.Features.Hide.Rules.HideRules)
local ShiftHelperViewModel = require(script.Parent.ShiftHelperViewModel)

local function prompt(extra)
	local value = { id = 1, action = "Search", object = "Desk", key = "E", hold = 0 }
	for key, item in extra or {} do
		value[key] = item
	end
	return value
end

local function hidePrompt(extra)
	local value = { id = 7, action = "Hide under", noun = "desk", key = "C", hold = 0 }
	for key, item in extra or {} do
		value[key] = item
	end
	return value
end

local function input(extra)
	local value = { danger = false, now = 100, hudHidden = false }
	for key, item in extra or {} do
		value[key] = item
	end
	return value
end

return function()
	describe("helper", function()
		it("is nil with nothing to do here", function()
			expect(ShiftHelperViewModel.helper(input())).to.equal(nil)
		end)

		it("is nil while the HUD is hidden (the scare beat, or caught)", function()
			expect(ShiftHelperViewModel.helper(input({ prompt = prompt(), hudHidden = true }))).to.equal(nil)
		end)

		it("shows the shown prompt's action as one short word", function()
			local view = ShiftHelperViewModel.helper(input({ prompt = prompt() }))
			expect(view.kind).to.equal("prompt")
			expect(view.label).to.equal("SEARCH")
			expect(view.ready).to.equal(false)
			expect(view.warn).to.equal(false)
		end)

		it("reads BANK, lit, at the truck's Load prompt", function()
			local view = ShiftHelperViewModel.helper(
				input({ prompt = prompt({ action = "Load", kind = CargoConstants.LOAD_KIND }) })
			)
			expect(view.label).to.equal("BANK")
			expect(view.ready).to.equal(true)
		end)

		it("shows HIDE at a hiding spot", function()
			local view = ShiftHelperViewModel.helper(input({ hidePrompt = hidePrompt() }))
			expect(view.kind).to.equal("hide")
			expect(view.label).to.equal("HIDE")
		end)

		it("lets the other prompt win over HIDE while there is no danger (a desk to search and hide under)", function()
			local view = ShiftHelperViewModel.helper(input({ prompt = prompt(), hidePrompt = hidePrompt() }))
			expect(view.kind).to.equal("prompt")
		end)

		it("lets HIDE win while he is near (the urgent one)", function()
			local view =
				ShiftHelperViewModel.helper(input({ prompt = prompt(), hidePrompt = hidePrompt(), danger = true }))
			expect(view.kind).to.equal("hide")
			expect(view.label).to.equal("HIDE")
		end)

		it("is LEAVE while hiding, whatever else is around", function()
			local hidden = { spotId = "a", kind = "under", noun = "desk", since = 99 }
			local view = ShiftHelperViewModel.helper(
				input({ hidden = hidden, prompt = prompt(), hidePrompt = hidePrompt(), danger = true })
			)
			expect(view.kind).to.equal("leave")
			expect(view.label).to.equal("LEAVE")
			expect(view.warn).to.equal(false)
		end)

		it("warns (coral) once the stay is cramped", function()
			local hidden = { spotId = "a", kind = "under", noun = "desk", since = 0 }
			local late = 1
			while HideRules.camp(late) == "ok" and late < 600 do
				late += 1
			end
			local view = ShiftHelperViewModel.helper(input({ hidden = hidden, now = late }))
			expect(view.kind).to.equal("leave")
			expect(view.warn).to.equal(true)
		end)

		it("fills while a hold prompt is held, and not for a press", function()
			expect(ShiftHelperViewModel.helper(input({ prompt = prompt() })).fill).to.equal(nil)
			local held = ShiftHelperViewModel.helper(input({ prompt = prompt({ hold = 2, holdStartedAt = 99 }) }))
			expect(held.fill).to.equal(0.5)
			local waiting = ShiftHelperViewModel.helper(input({ hidePrompt = hidePrompt({ hold = 1 }) }))
			expect(waiting.fill).to.equal(0)
		end)
	end)

	describe("word", function()
		it("keeps short actions whole, in capitals", function()
			expect(ShiftHelperViewModel.word("Pick up", nil)).to.equal("PICK UP")
			expect(ShiftHelperViewModel.word("Open", nil)).to.equal("OPEN")
			expect(ShiftHelperViewModel.word("Clock out", nil)).to.equal("CLOCK OUT")
		end)

		it("keeps the last word of a long action, so it fits the round button", function()
			expect(ShiftHelperViewModel.word("Start overtime", nil)).to.equal("OVERTIME")
		end)

		it("names the truck's Load prompt BANK", function()
			expect(ShiftHelperViewModel.word("Load", CargoConstants.LOAD_KIND)).to.equal("BANK")
		end)

		it("never runs past the longest word that fits", function()
			for _, action in { "Pick up", "Search", "Open", "Close", "Enter", "Leave", "Clock out", "Start overtime" } do
				expect(#ShiftHelperViewModel.word(action, nil) <= ShiftHelperViewModel.MAX_LETTERS).to.equal(true)
			end
		end)
	end)
end
