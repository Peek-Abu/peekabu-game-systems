local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ShiftHudViewModel = require(ReplicatedStorage.Client.UI.React.Screens.Shift.ShiftHudViewModel)
local AbilityViewModel = require(script.Parent.AbilityViewModel)

local function input(overrides)
	local base = {
		abilityId = "letsGo",
		phase = "running",
		hidden = false,
		readyAt = 0,
		active = nil,
		now = 100,
		touch = false,
		gamepad = false,
		shortSide = 1080,
	}
	for key, value in overrides or {} do
		base[key] = value
	end
	return base
end

return function()
	it("draws nothing without an ability, outside a running shift, or while the HUD is hidden", function()
		local none = input()
		none.abilityId = nil
		expect(AbilityViewModel.button(none)).to.equal(nil)
		expect(AbilityViewModel.button(input({ abilityId = "nope" }))).to.equal(nil)
		expect(AbilityViewModel.button(input({ phase = "lobby" }))).to.equal(nil)
		local noShift = input()
		noShift.phase = nil
		expect(AbilityViewModel.button(noShift)).to.equal(nil)
		expect(AbilityViewModel.button(input({ hidden = true }))).to.equal(nil)
	end)

	it("is ready with the ability's name and icon, keyed Q on a keyboard and Y on a gamepad", function()
		local view = AbilityViewModel.button(input())
		expect(view.name).to.equal("Let's Go!")
		expect(view.icon).to.equal("abilityLetsGo")
		expect(view.ready).to.equal(true)
		expect(view.remaining).to.equal(0)
		expect(view.seconds).to.equal(nil)
		expect(view.key).to.equal("Q")
		expect(AbilityViewModel.button(input({ gamepad = true })).key).to.equal("Y")
	end)

	it("counts the cooldown down in whole seconds, with the sweep still to go", function()
		local view = AbilityViewModel.button(input({ abilityId = "spotIt", readyAt = 130, now = 110 }))
		expect(view.ready).to.equal(false)
		expect(view.seconds).to.equal("20")
		expect(view.remaining).to.equal(0.5)
	end)

	it("lights while its effect runs", function()
		local view =
			AbilityViewModel.button(input({ abilityId = "pottedPlant", active = "pottedPlant", readyAt = 140 }))
		expect(view.active).to.equal(true)
		expect(view.name).to.equal("Potted Plant")
	end)

	it("sits on the phone arc on a touch screen, with no key", function()
		local view = AbilityViewModel.button(input({ touch = true, shortSide = 390 }))
		local arc = ShiftHudViewModel.arcFor(390)
		expect(view.spot.x).to.equal(arc.ability.x)
		expect(view.spot.y).to.equal(arc.ability.y)
		expect(view.key).to.equal(nil)
	end)

	it("sits bottom right on a desktop, clear of the screen edge", function()
		local view = AbilityViewModel.button(input())
		expect(view.spot.x + view.spot.size <= -16).to.equal(true)
		expect(view.spot.y + view.spot.size <= -16).to.equal(true)
	end)
end
